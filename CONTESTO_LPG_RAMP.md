# Contesto LPG e RAMP — appunti per ripartire

Riassunto di quanto verificato lavorando sul generatore di profili. Serve a far
ripartire una sessione nuova senza rifare l'esplorazione da capo.

**Tutto ciò che è scritto qui è stato verificato** interrogando il database,
l'eseguibile o eseguendo il codice, non dedotto dalla documentazione. Dove una
cosa resta incerta è detto esplicitamente.

Stato: punti 1 e 2 del piano fatti e committati (`b756ed5`, `bcd20f6` sul branch
`42-validation-load-profile-and-temperature-in-lpg`). Restano i punti 3 e 4,
descritti in fondo. Punto di ritorno: tag `pre-italianizzazione-lpg`.

---

## 1. Architettura in due stadi

```
STADIO 1 — Python, in CER_LoadProfiles/
  RAMP  → profili aziende (office, small_industry, retail)
  LPG   → profili famiglie (CHR*)
  ↓ postprocessing: da 1 min a 1 h, energia in kWh
  outputs/csv/profili_tutti.csv          una colonna per utenza

STADIO 2 — MATLAB, radice del progetto
  MAIN.m legge profili_tutti.csv + PV_Generation/ + prezzi zonali
  → bilancio CER, 16 modelli di ripartizione, indici di equità
```

`profili_tutti.csv` è il punto di giunzione: lo leggono `CER_input.txt`, le
schede di `CER_configuration/` e `optimizer_PV.m`.

Moduli Python: `generate_load_profiles.py` (orchestratore), `lpg_runner.py`,
`ramp_runner.py`, `postprocessing.py`, `cer_config_writer.py`.

---

## 2. LPG — come funziona davvero il modello

Non campiona profili statistici: **simula persone che decidono cosa fare**,
minuto per minuto. L'elettricità è il sottoprodotto. La catena:

| Anello | Quantità | Cosa fa |
|---|---:|---|
| Persona | 152 template | età, genere, *living pattern tag* |
| Desiderio | 245 | decade nel tempo; `DecayRate`, `Threshold`, `Weight` |
| Affordance | 294 + 41 sub | l'attività concreta che soddisfa desideri |
| Dispositivo | 342 in 154 cat. | profilo di carico **misurato** |
| Load type | 22 | Electricity, Gas, Warm Water, Space Heating… |
| Casa | 22 house type | converte la domanda nel vettore finale |

Il **peso** dei desideri crea la gerarchia: `Work / Employment (Office 9h)` pesa
100, `School / High School 6h` pesa 1000 (quasi obbligatorio), `Spare Time` pesa 1.
È così che nascono i picchi mattutini e serali senza programmarli.

**I Time Limit sono un gate binario.** La tesi di Pflugradt: *«Alle Time Limits
werden vor der Berechnung in ein Bitarray konvertiert»* — 1 permesso, 0 vietato,
per ogni passo. Sono **oggetti condivisi**: modificarne uno agisce su tutte le 66
famiglie del catalogo insieme. È questo che rende inutile lo scambio di tratti
famiglia per famiglia.

**Il seed conta.** La scelta dell'attività è probabilistica e pesata: due run
dello stesso CHR con seed diversi danno profili diversi. Non è rumore da
eliminare, è la variabilità fra famiglie.

---

## 3. LPG — l'installazione reale

```
venv/Lib/site-packages/pylpg/
  LPG_win/                 155 MB, binari originali
  C1/                      1,4 GB, directory di lavoro "calculation index 1"
    simengine2.exe         motore, v10.10.0.6, .NET 8.0.4 SELF-CONTAINED
    profilegenerator.db3   53 MB, 133 tabelle — schema v10.7.0.a
    calcspec.json          il job scritto a ogni run: il vero contratto
    results/Results/       output in JSON
```

- **Non serve installare .NET**: i binari sono self-contained. Il README del
  progetto che parla di .NET 6 è obsoleto.
- **Non esiste la GUI** in questa installazione, solo `simengine2.exe`. La GUI
  (che ha l'editor dei profili di temperatura) sta nel download completo da
  loadprofilegenerator.de.
- La "C" di C1 è l'indice di calcolo: `LPGExecutor(idx, ...)` crea `C{idx}`,
  sandbox indipendente. **Il progetto usa sempre l'indice 1**, quindi le famiglie
  vengono calcolate in stretta sequenza.
- **~2m 24s per famiglia-anno** a risoluzione 1 minuto, di cui ~55 s di
  post-processing. Quattro famiglie ≈ 10 minuti.

### Le 8 azioni della CLI (pyLPG ne usa una)

| Azione | Note |
|---|---|
| `ProcessHouseJob -J <path>` | l'unica che pyLPG invoca |
| `LaunchJsonParallel -d <dir> -cores N -ar <dir>` | parallelismo nativo |
| `CSVImport -i -d -n` | importa un date-based profile |
| `ExportDatabaseObjectsAsJson -t -o` | HouseholdTemplates, ModularHouseholds, HouseholdTraits |
| `ImportDatabaseObjectsAsJson -i -t` | ciclo export → modifica → import |
| `CreatePythonBindings` | rigenera `lpgdata.py` **dentro venv/** |
| `CreateExampleHouseJob`, `ImportHouseholdDefinition` | minori |

Attenzione: l'eseguibile si chiama `simengine2.exe`, **non** `Simulationengine.exe`
come scrive la guida, e il flag è `-JsonPath`/`-J` minuscolo/maiuscolo.

### Output: 59 CalcOption, 2 in uso

Il progetto attiva solo `JsonHouseholdSumFiles` e `BodilyActivityStatistics`, e
legge **una sola colonna**. Ma anche così vengono prodotti ~21 file per run:
`Sum.Gas.House.json`, `Sum.Space Heating.House.json`, `Sum.Warm Water.HH1.json`,
`Sum.Apparent`, `Sum.Reactive`, `Sum.Cold Water`… tutti cancellati da
`_clean_lpg_results()` al run successivo.

Opzioni interessanti non attive: `JsonDeviceProfilesIndividualHouseholds`
(profilo per singolo elettrodomestico → quota di carico spostabile),
`EnableFlexibility` + `FlexibilityEvents`, `TotalsPerLoadtype`,
`CriticalViolations` (desideri insoddisfatti = profilo non credibile),
`LocationsFile`, `ActionsEachTimestep`, `MakePDF`.

`read_all_json_results_in_directory()` legge solo i pattern `Sum.*`,
`BodilyActivityLevel.*`, `CarLocation.*`, `Carstate.*`, `DrivingDistance.*`,
`Soc.*`. Gli altri file vanno letti a mano **prima** della pulizia.

---

## 4. Il catalogo italiano

`CER_LoadProfiles/lpg_db/build_italian_db.py` ricostruisce
`profilegenerator.IT.db3` dall'originale applicando **11 migrazioni**. Il `.db3`
non è versionato (è in `.gitignore`): si versiona lo script.

**Regole**: mai modificare il `.db3` a mano, la build successiva cancellerebbe
tutto. Mai toccare l'originale in `venv/` — lo script verifica per checksum a
ogni esecuzione e fallisce se è cambiato. I GUID sono fissi e deterministici:
due build dalla stessa sorgente danno lo stesso file bit per bit (verificato).

| ID | Cosa |
|---|---|
| `H01` `H02` | Rimuove 6 festività non italiane da Milano (3 greche, Venerdì Santo, Lunedì di Pentecoste, Sa Die de Sa Sardigna) |
| `H03` | Attiva 2 giugno, Ferragosto, Immacolata → calendario a 12 voci |
| `L01` | Lavoro: TL 12 da 08:00–10:00 a 09:00–11:00; TL 14, TL 7 |
| `L02` | Cena: TL 121 → 19:00–21:30, TL 40, 66, 82, 88, 57 |
| `L03` | Pranzo: TL 89 weekend → 12:30–15:00; TL 91, 119, 120, 122 (randomizzazione da 60 a 45 min) |
| `L04` | Scuola tempo normale: TL 44 → 13:30; sveglie TL 113, 114, 131; compiti TL 72 |
| `L05` | Bambini a letto: TL 80, 85, 87 → 21:00 |
| `L06` | Colazione: TL 5, 83, 84 → dalle 07:00 |
| `V01` | Vacanze: 38 famiglie ad agosto, 16 giugno, 7 settembre, 4 studenti ago-set |
| `T01` | Profilo di temperatura di Milano dal TMY PVGIS |

### Il profilo di temperatura

`Milano, Italia - PVGIS TMY 2005-2023`, GUID
`5e1c9a34-7b28-4c61-9f03-6ad82b5e7c19`, 365 medie giornaliere da −0,8 a +29,0 °C.
Sorgente: colonna `T2m` di `lpg_db/dati/tmy_45.464_9.190_2005_2023.csv`, **lo
stesso file che `optimizer_PV.m` usa per la radiazione**.

I 4 profili di serie sono tutti tedeschi e a risoluzione giornaliera. Sono
importabili: la tesi dice che i temperature profile *sono* date-based profile e
condividono quasi tutto il codice. Tre vie: GUI (assente qui), `CSVImport`,
`INSERT` in SQLite (quella usata, verificata).

**Il TMY è un composito** di anni 2005/2007/2010-2013/2018-2021: non è un anno
reale, quindi la regola «stesso anno meteo per LPG e PVGIS» resta insoddisfacibile.
Diventa «stessa fonte climatica», da dichiarare in metodologia.

### Il catalogo, in numeri

| | |
|---|---|
| famiglie predefinite | 66 (`tblModularHouseholds`) |
| tratti | 633 · tag dei tratti 113 |
| affordance | 294 + 41 sub |
| desideri | 245 |
| dispositivi | 342 in 154 categorie |
| profili di carico misurati | 286 |
| time limit | 127, con 268 voci |
| house type | 22 · load type | 22 |
| località | 20 (3 italiane) · profili temperatura 5 |
| living pattern tag | 25 · tag famiglia 19 |
| vacanze | 20 · persone template 152 |

---

## 5. `lpg_runner.py` — cosa fa e cosa è stato corretto

`execute_lpg_single_household()` di pyLPG **non espone tre cose che servono**, per
questo il runner replica il corpo di quella funzione:

- `PathToDatabase` — per usare il catalogo italiano
- `CalcSpec.TemperatureProfile` — pyLPG non lo valorizza mai
- `TargetHeatDemand` / `TargetCoolingDemand` — `make_default_lpg_settings()` li
  mette a 0 e 10000, in conflitto con l'house type scelto; il runner li annulla

Correzioni applicate:

- **Seed deterministico**: `hash()` sulle stringhe è randomizzato a ogni avvio
  dell'interprete (PEP 456), quindi due esecuzioni davano profili diversi. Ora
  `zlib.crc32`. Senza questo nessun confronto A/B è possibile.
- **Colonna elettrica per prefisso esatto**: `"Electricity" in c` collide con
  `Electricity for Heating` e `for Car Charging`. Ora `startswith("Electricity_HH")`.
- **`_risolvi_temperatura()`**: cerca il profilo prima nei binding di `lpgdata`,
  poi **per nome nel database configurato**, e costruisce il `JsonReference` a
  mano (è solo Name + Guid). Evita di rigenerare `lpgdata.py` dentro `venv/`, che
  non è versionato. Interroga il DB solo se il file esiste, perché
  `sqlite3.connect()` lo creerebbe vuoto.
- **Riepilogo dei fallback**: il fallback sintetico era un warning sepolto nel
  log. Ora un `logger.error` finale elenca quali profili sono sintetici.

### I tre modi di definire una famiglia

`ByHouseholdName` (in uso), `ByTemplateName` (persone e tratti estratti a caso
entro il template, con `ForbiddenTraitTags`), `ByPersons` (composizione definita
a mano con `PersonData(Age, Gender, LivingPatternTag, …)`).

`ByTemplateName` darebbe **varianza entro la categoria**, che è l'antidoto al
collasso di forma descritto da Marrasso.

Attenzione: il runner risolve i nomi in `lpgdata.Households`, non in
`HouseholdTemplates`. Coincidono su 61 voci su 62 — **CHR62 è diverso**.

---

## 6. RAMP

RAMP **0.5.0**. Genera i profili delle utenze non domestiche.

- Use case in `CER_LoadProfiles/ramp_inputs/use_cases/<nome>.py`, importati
  dinamicamente da `_import_use_case()`. Attivi: `office`, `small_industry`, `retail`.
- **Due patch di compatibilità** in `ramp_runner.py`, necessarie perché RAMP 0.5.0
  è fermo: `_patch_ramp_numpy2()` (NumPy 2.x non permette `int()` su array 1-D,
  e RAMP fa `int(np.diff(...))` nel metodo `windows()` di `Appliance`) e
  `_patch_ramp_pandas3()`.
- **Seed**: vanno seminati **entrambi** i generatori. `ramp/core/core.py` fa
  `import random` e pesca dalla libreria standard (`uniform`, `randint`, `gauss`,
  `normalvariate`, `choice`), mentre altrove usa `np.random`. Seminare solo numpy
  lasciava scoperta la parte che decide finestre di accensione e durate.
- **Verificato riproducibile**: due run separati danno profili identici bit per
  bit, e nel confronto A/B sulla temperatura le tre imprese hanno scarto
  esattamente 0,0000000000 su 8759 ore.
- RAMP dà **tre forme distinte**, quindi il progetto non soffre del collasso di
  Marrasso sul lato non domestico.

---

## 7. Metriche e strumenti di verifica

### Profildifferenz — `lpg_db/confronta_profili.py`

Metrica dell'autore di LPG: 9 curve medie (3 tipi di giorno × 3 stagioni),
differenza al minuto, quadrata e sommata.

- **Riferimento**: 12.960 = spostamento uniforme di 1 kW su tutta la giornata
  (9 × 1440 × 1). **Si calcola in kW, non in Watt** — usare i Watt gonfia di 10⁶.
- Le soglie 10.000–30.000 (rumore) e 50.000 (differenza reale) della tesi sono
  calibrate su **un intero insediamento**: su poche utenze darebbero un falso
  «nessuna differenza». Vanno usate come ordine di grandezza.
- Su dati orari è una **stima per difetto**: la media oraria appiattisce gli
  spostamenti infraorari.
- Lo script riporta anche tre diagnostiche robuste all'aggregazione oraria:
  ora del picco mattutino, del picco serale, e consumo di agosto.

**L'autoconsumo è una cattiva metrica** per giudicare spostamenti orari: la tesi
mostra che profili molto diversi variano solo fra 21% e 39%, e le variazioni
serali e notturne non vengono catturate affatto (1–2 punti percentuali anche per
grandi cambiamenti). Resta il risultato di interesse, non lo strumento di misura.

### Eterogeneità — due indici che vanno letti insieme

`gini_heterogeneity.m` conta le **etichette**: `G = (1 − Σf²)·m/(m−1)` con
`m` = numero di membri. Vale 1 quando ogni membro è di tipologia distinta.

**Non basta**: aggiungendo la quarta famiglia (CHR05) il valore *scende* da
0,80 a 0,71, perché aggiunge un'altra etichetta `domestico` anche se quella
famiglia consuma diversamente.

`shape_heterogeneity.m` confronta i **ritmi**: normalizza ogni profilo a somma
unitaria (separa il *quanto* dal *quando*) e misura la distanza L1 media fra
tutte le coppie. 0 = stessi ritmi, 2 = mai sovrapposti.

Serve perché Shapley, Nucleolo e VLC si distinguono da una ripartizione
volumetrica **solo se i membri consumano in momenti diversi**. È una
precondizione perché la domanda di ricerca sia rispondibile.

---

## 8. Trappole verificate

- **Il fallback sintetico è silenzioso.** Qualsiasi errore pyLPG viene catturato
  e sostituito con un profilo finto. Un `household_ref` sbagliato non fa fallire
  il run. Ora c'è il riepilogo finale, ma va guardato.
- **Risultati stale.** Se un run muore (tipico: `Access to the path results\Charts
  is denied`), `read_all_json_results_in_directory()` restituisce i dati del run
  precedente **senza errore**. Il filtro sull'anno in `lpg_runner` difende solo
  dal caso «anno diverso».
- **Cartelle ReadOnly.** Il runtime .NET crea le sottocartelle di `results` con
  attributo ReadOnly su Windows e poi non riesce a cancellarle. Il progetto sta
  sotto `desktop/`: se è sincronizzato da OneDrive i lock peggiorano le cose.
- **15 time limit hanno condizioni di temperatura** (`Above 15°C`, `Below 15°C`,
  `Above 25°C`, `above 18°C`, `between −5°C and 0°C`…). Cambiando profilo cambiano
  i giorni in cui quei cancelli si aprono, quindi **la traiettoria stocastica
  diverge**: uno scarto piccolo non è scomponibile in effetto termico e rumore
  senza molte repliche.
- **I nomi dei time limit mentono.** `Lunch Time (11:30-13:00)` conteneva in
  realtà 12:00–14:00 con ±60 min. Leggere sempre `tblTimeLimitEntries`.
- **Voci gerarchiche.** Alcuni time limit hanno voci legate da `ParentEntryID`
  con logica AND/OR (`AnyAll`): un `UPDATE` di gruppo la rompe. Agire per ID di voce.
- **Aggiungere famiglie sempre in coda** a `lpg.households`. I seed dipendono da
  `(label, indice-nel-gruppo)` e restano stabili, ma i **nomi di colonna** sono
  progressivi sulla posizione: inserendo in mezzo, `household_3` diventa un'altra
  famiglia. `align_members_to_users.m` fa il match **per nome** e segnala i
  disallineamenti, quindi non si rompe in silenzio — ma l'etichetta `archetipo`
  nella scheda resterebbe sbagliata.
- **`MAIN.m` riga ~1306**: l'assert del VLC falliva *anche* sui profili originali
  tedeschi. Causa: il VLC converge entro `2·tolAbs` (rilassa i vincoli di
  `relax = tolAbs`) mentre MAIN verificava entro `1·tolAbs`. Corretto in `f362fe1`.

---

## 9. I punti che restano

### Punto 3 — validazione dei domestici (LPG vs ARERA)

Risponde all'obiezione: *perché profili costruiti su dati tedeschi dovrebbero
rappresentare famiglie italiane?*

1. Scaricare ARERA *Analisi dei consumi dei clienti domestici*, ZIP provinciale
   (22–370 MB).
2. Filtrare: provincia della CER, **classe di potenza 3 kW**, **residente**,
   clienti **trattati orari**.
3. Estrarre la curva di prelievo medio orario in un CSV semplice.
4. **Normalizzare entrambe le curve a somma unitaria** — si valida la *forma*,
   non il livello. È il passaggio che si sbaglia più facilmente.
5. Confrontare riusando `curve_medie()` e `diagnostica()` di
   `confronta_profili.py`. Nuovo script `valida_domestici.py`, con figura:
   giornata media sovrapposta, un pannello per stagione.
6. Livello a parte: kWh/anno contro la media ARERA per provincia e classe.

**Se non combacia, si corregge il catalogo, non l'output.** La guida propone un
«fattore orario correttivo»: su un modello bottom-up è sbagliato, perché sistema
la somma e rende i profili individuali meno plausibili — e lo Strato 2 vive
esattamente sulle forme individuali.

Avvertenza: il dato orario ARERA copre solo i clienti *trattati orari*, un
sottoinsieme di cui va verificata la rappresentatività.

### Punto 4 — validazione dei non domestici (RAMP vs GSE)

| Cosa | Fonte |
|---|---|
| *Livello*: quanto consuma un settore, con che potenza | **ARERA ATECO** (solo mensile) |
| *Forma di riferimento* | **profili standard GSE** |
| *Forma effettiva* | **RAMP**, validato contro GSE |

Scaricare da gse.it, area CACER, *Modalità di profilazione dei dati di misura —
profili standard GSE in prelievo e in immissione*. Stesso metodo del punto 3.

**I profili GSE si usano come metro, non come sorgente**: sostituirli a RAMP
renderebbe identici in forma tutti i membri della stessa categoria, ricreando il
collasso di Marrasso. L'argomento a favore resta forte e va scritto in tesi: sono
i profili che il GSE **applica davvero** nel settlement CACER quando un POD non è
trattato orario.

### Nota sui dati ISTAT già scaricati

`~/Downloads/UsoTempo_2023_IT` è il modulo **Volontariato** (37.989 record, 298
variabili). Ha ore di lavoro e scuola aggregate (`orelav`, `giolav`, `orescu`) ma
**non il diario giornaliero** per fascia oraria, che servirebbe per calibrare gli
orari dei pasti. Per quello serve la release del diario.

---

## 10. Numeri di riferimento

Da usare come controllo dopo modifiche.

**Comunità a 7 membri** (`profili_tutti.csv` del 25/08, 3 aziende + 4 famiglie):

```
Gini di eterogeneità (etichette)  0,7143   (4 tipologie su 7 membri)
Eterogeneità di forma (L1)        1,0695
  dentro tipologia                0,9314
  fra tipologie                   1,1248
```

A 6 membri (file del 24/08): Gini 0,8000 · forma 1,0882 · dentro 0,9852 · fra 1,1139.

**Effetto dell'italianizzazione degli orari** (stesso seed, stessi 3 domestici,
catalogo tedesco → italiano):

```
picco mattutino   ore 07 → 08
picco serale      ore 19 → 20
consumo di agosto −43 %
forma, domestici  1,0226 → 0,9852  (−3,7 %)
forma, dom vs impr 1,2332 → 1,2187 (−1,2 %)
```

**Effetto della sola temperatura** (A/B pulito, unica differenza la riga di config):

```
office / small_industry / retail   scarto ESATTAMENTE 0 su 8759 ore
quattro famiglie                   −0,49 % annuo
```

Piccolo per costruzione: `HT06` riscalda a gas e non ha raffrescamento, quindi la
temperatura tocca l'elettrico solo di striscio. Diventa determinante con pompa di
calore o condizionamento (HT07, HT08, HT11, HT16, HT19, HT21).

**Bilancio CER** con i profili attuali: consumo comunità 93.385 kWh, generazione
PV 101.884 kWh, energia condivisa 18.963 kWh, venduta 43.707 kWh.

---

## 11. Comandi utili

```bash
# Ricostruire il catalogo italiano (verifica da sé che l'originale sia intatto)
cd CER_LoadProfiles/lpg_db && ../../venv/Scripts/python build_italian_db.py

# Generare i profili (~10 min con 4 famiglie)
cd CER_LoadProfiles && ../venv/Scripts/python generate_load_profiles.py \
    --config config/simulation_config.yaml

# Confronto A/B fra due generazioni
../venv/Scripts/python lpg_db/confronta_profili.py <base.csv> <confronto.csv>

# Ispezionare il catalogo LPG
cd venv/Lib/site-packages/pylpg/C1 && ./simengine2.exe --help
./simengine2.exe ExportDatabaseObjectsAsJson -t ModularHouseholds -o fam.json

# MATLAB senza finestre
"/c/Program Files/MATLAB/R2024b/bin/matlab.exe" -batch \
  "set(0,'DefaultFigureVisible','off'); MAIN"
```

Per un confronto A/B pulito: generare due volte cambiando **una sola** riga di
configurazione, con lo stesso seed. Un file di qualche giorno prima non vale come
baseline — nel frattempo il codice cambia.
