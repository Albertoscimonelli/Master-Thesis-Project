# Validazione dei profili domestici contro ARERA — stato al 2 settembre 2026

Contesto per una sessione che deve analizzare una cartella di CSV ARERA.
Riassume cosa è stato misurato finora sui profili LPG, quali correzioni sono
state testate e **cosa serve dai dati ARERA** per chiudere il lavoro.

Tutti i numeri qui sotto sono stati **misurati eseguendo il codice**, non dedotti.
Dove qualcosa resta ipotesi, è detto esplicitamente.

---

## 1. Il progetto in due righe

Una CER (Comunità Energetica Rinnovabile) con 7 membri: 3 imprese (profili da
RAMP) e 4 famiglie (profili da LPG — Load Profile Generator, modello bottom-up
tedesco). I profili confluiscono in `CER_LoadProfiles/outputs/csv/profili_tutti.csv`,
che MATLAB (`MAIN.m`) usa per il bilancio CER e 16 modelli di ripartizione
dell'energia condivisa.

Le quattro famiglie:

| colonna | etichetta | archetipo LPG |
|---|---|---|
| `household_1` | pensionati | CHR54 Retired Couple, no work |
| `household_2` | coppia_lavoratori | CHR02 Couple, 30-64, with work |
| `household_3` | famiglia_1figlio | CHR03 Family, 1 child, both at work |
| `household_4` | famiglia_3figli | CHR05 Family, 3 children, both with work |

La domanda di ricerca dipende dal fatto che i membri consumino **in momenti
diversi**: Shapley, Nucleolo e VLC si distinguono da una ripartizione volumetrica
solo se le forme dei profili differiscono. Quindi la **forma** conta quanto il
livello, e forse di più.

---

## 2. Il dato ARERA di riferimento che abbiamo già

Da dashboard ARERA *Analisi dei consumi dei clienti domestici*, anno **2024**,
filtro `3 < potenza_impegnata <= 4.5`, `Residente`, tutti i tipi di mercato:

```
prelievo medio annuo: 3.008 kWh

mensile (kWh):
Gen 291  Feb 230  Mar 248  Apr 213  Mag 206  Giu 210
Lug 302  Ago 304  Set 221  Ott 228  Nov 253  Dic 302

fasce: F1 31,71%   F2 30,39%   F3 37,90%
```

**Attenzione, punto critico**: il filtro è `3 <`, quindi **esclude il contratto
da 3 kW**, che è lo standard delle utenze domestiche residenti italiane. Quei
3.008 kWh sono la media del segmento *sopra* lo standard. La classe davvero
pertinente è probabilmente `1.5 < P <= 3`, che non abbiamo ancora.

Due caratteristiche della curva ARERA da tenere a mente:
- **doppio picco**: inverno (Gen 291, Dic 302) *e* estate (Lug 302, **Ago 304**).
  Agosto è il mese più consumato dell'anno — il condizionamento batte le ferie.
- minimo in maggio-giugno (206-210).

---

## 3. Il problema di partenza

Configurazione originale del progetto: house type `HT06` (riscaldamento a gas,
nessun condizionamento) ed `energy_intensity: "Random"`.

```
CHR03, elettricità famiglia          4.777,7 kWh/anno
       elettricità casa                 900,9
       TOTALE POD                     5.678,6      = x1,89 su ARERA
```

E un secondo problema, indipendente: il progetto leggeva **solo** la colonna
`Electricity_HH1`, scartando `Electricity_House`. Quest'ultima non è zero
nemmeno con `HT06`: contiene la pompa di circolazione del riscaldamento (900,9
kWh/anno). Il POD misura la somma delle due.

---

## 4. Le cause dell'eccesso, misurate

### 4.1 `energy_intensity: "Random"` — l'84% dello scarto

`Random` pesca a caso fra le alternative di ogni categoria, che coprono una
forbice enorme (es. `Kitchen Light` esiste a 300/200/150/100/60/20 W).
`DeviceSelectionID` di CHR03 è `No_Selections`: nessun vincolo.

```
CHR03, HT06:   Random 5.678,6 kWh   ->   EnergySaving 3.443,2 kWh   (-39%)
               x1,89 su ARERA            x1,14 su ARERA
```

Una sola riga di `config/simulation_config.yaml`. La forma cambia pochissimo
(L1 da 0,196 a 0,185): è una leva sul livello, non sulla forma.

### 4.2 Nessun elettrodomestico a gas — la cottura è tutta elettrica

```
dispositivi domestici con vettore Electricity   222
dispositivi domestici con vettore Gas             0
dispositivi con GasFlowRate valorizzato           0
```

In LPG il gas esiste solo come trasformatore di casa (caldaia, scaldabagno).
Non esiste il piano cottura a gas. Il piano cottura elettrico pesa, con
`EnergySaving`, **21,8-22,9% dell'elettricità domestica** in tutte e quattro le
famiglie (426-761 kWh/anno). In Italia sarebbe in bolletta gas.

### 4.3 Catalogo dispositivi fermo al 2017

Distribuzione `tblDevices.Year`: 13 del 1990, 20 del 2000, 43 del 2010, 43 del
2012, 68 del 2014, 84 del 2015, 3 del 2017, **nessuno dopo**. Contiene una
lampadina a incandescenza da 60 W (263 kWh/anno, fuori commercio UE dal 2012),
un congelatore del 1990, e una pompa di circolazione Wilo a giri fissi da 80 W
(900 kWh/anno osservati, contro i 50-100 di un circolatore moderno imposto dal
regolamento UE 641/2009).

### 4.4 Dotazione da casa unifamiliare tedesca

Con `Random`, CHR03 aveva: tosaerba elettrico 142,9 + cippatrice 139,3 +
tagliasiepi 65,9 = **348 kWh/anno di attrezzi da giardino**, più un tapis
roulant da 208,7. Un POD domestico da 3 kW in una CER è tipicamente un
appartamento.

**Verifica per differenza**: togliendo cottura elettrica (1.228,6) + giardino e
tapis roulant (556,8) dai 4.822,1 kWh del run diagnostico si ottiene **3.036,7
kWh contro i 3.008 di ARERA**. Cioè l'eccesso è interamente attribuibile a voci
identificabili: **è un problema di composizione della famiglia, non di taratura**.

### 4.5 Vacanza d'agosto troppo aggressiva

CHR03 ha `VacationID 18 = "August - 3 weeks"`, dal 1 al 22 agosto: **21 giorni
consecutivi**. Nei giorni di vacanza il consumo scende a ~0,6 kWh/giorno, meno
di quanto assorbe un frigorifero da solo (~0,77) — sembra che vengano spenti
anche i dispositivi autonomi (c'è un flag `TurnOffAutonomous` nello schema, non
verificato). Risultato: agosto al 3,41% dell'anno contro il **10,11% di ARERA**,
lo scarto mensile più grande in assoluto.

### 4.6 Condizionamento sovradimensionato

`HT07.CoolingYearlyTotal = 5000` kWh **termici**, che con COP 3 fanno **1.663
kWh elettrici**. Il consumo reale italiano di un condizionatore è 400-700 kWh
elettrici. E `AdjustYearlyCoolingHours = 0`: a differenza del riscaldamento
(`AdjustYearlyEnergy = 1`, `ReferenceDegreeDays = 4000`), il raffrescamento
**non viene riscalato sul clima** — restano 5.000 ovunque.

### 4.7 I time limit del bucato sono ancora tedeschi

Le migrazioni italiane esistenti (`L01`-`L06`) hanno toccato lavoro, pasti,
scuola, sveglie e messa a letto. **Il bucato no.**

| affordance | time limit | finestra |
|---|---|---|
| `run the dishwasher (triggered)` | `TL 6` | 08:00-20:00 |
| `run the dryer with wet laundry` | `TL 6` | 08:00-20:00 |
| `do laundry at 30°C` | `TL 6` | 08:00-20:00 |
| `do laundry at 60°C` | `TL 81` | 08:00-19:00 |
| `run the dryer, below 15°C` | `TL 106` | 08:00-22:00 |

Aprono tutti alle 08:00 con randomizzazione ±15 min. LPG fa scattare l'attività
appena il cancello si apre, quindi lavatrice, lavastoviglie e asciugatrice si
accavallano subito dopo le 8.

**Attribuzione del picco mattutino** (famiglia 3 figli, ore 09, giorno feriale):

| dispositivo | ore 07 | ore 09 | ore 19 |
|---|---:|---:|---:|
| Dryer Miele T 8626 WP | 0,000 | 0,302 | 0,140 |
| Dishwasher NEFF SD6P1F | 0,000 | 0,189 | 0,064 |
| Washing Machine Bosch WAE 28143 | 0,000 | 0,119 | 0,079 |

Le tre macchine fanno **0,610 kW su 0,824 totali (74%)**, e alle 07:00 sono a
zero esatto. In Italia il bucato si fa prevalentemente la sera, quando la F3
costa meno.

### 4.8 Cena troppo presto

`TL 121 Dinner Time` dopo la migrazione `L02` sta a **19:00-21:30**, e
`TL 66`/`TL 82` aprono già alle 18:30. Tutti e tre i nuclei lavoratori picchiano
alle 19. In Italia si cena alle 20-21.

### 4.9 LPG non ha il vincolo di potenza contrattuale

Non esiste alcun campo, né in `tblHouseTypes` né nel calcspec, che limiti il
prelievo simultaneo. Nel contesto tedesco (allacciamenti trifase) è ragionevole.
Conseguenza sui profili:

**Picchi annui, composizione al minuto:**

```
famiglia 3 figli — 8,34 kW, 15/11/2025 ore 18:35
   Washing Machine Bosch    2.796 W
   Miele DG 1450 (forno)    2.174 W
   Dishwasher NEFF          2.110 W
   Dryer Miele T 8626 WP    1.071 W
                            ─────
                            8.151 W su 8.340

pensionati — 6,07 kW, 11/07/2025 ore 13:59
   Atika LH 2500 G (cippatrice da giardino)  3.361 W
   Miele DG 1450 (forno)                     2.664 W
```

Nota: il picco dei pensionati è la **cippatrice da giardino**. Togliendo gli
attrezzi da giardino quel minuto scenderebbe a ~2,7 kW, dentro un contratto da
3 kW. (Non verificato sul secondo picco più alto.)

---

## 5. Le modifiche testate e i risultati

Tutte le prove: anno 2025, house type `HT07` (gas + condizionamento elettrico),
`EnergySaving`, seed veri del progetto (`_seed_stabile(label, 0)`), catalogo
italiano `profilegenerator.IT.db3` con temperatura Milano da TMY PVGIS.

**Modifiche applicate a una COPIA sperimentale del catalogo** (mai al `.db3` del
progetto, che è rigenerato da `lpg_db/build_italian_db.py`):

- **A)** piano cottura da `Electricity` a `Gas`: 7 dispositivi in
  `tblRealDeviceLoadType` **e** 26 righe in `tblDeviceActionDevices`.
- **B)** `HT07.CoolingYearlyTotal` da 5.000 a **1.400** kWh termici.

### Confronto A/B

| famiglia | baseline `HT07`+`EnergySaving` | variante A+B | Δ |
|---|---:|---:|---:|
| pensionati | 4.275,6 | **2.551,7** | −40,3% |
| coppia lavoratori | 3.880,1 | **2.251,4** | −42,0% |
| famiglia 1 figlio | 5.097,8 | **3.185,2** | −37,5% |
| famiglia 3 figli | 5.399,6 | **3.447,5** | −36,2% |
| **totale** | **18.653,1** | **11.435,7** | **−38,7%** |

Le quattro famiglie ora **scavalcano** i 3.008 kWh di ARERA (due sotto, due
sopra) invece di stare tutte al doppio.

| metrica | baseline | variante |
|---|---|---|
| distanza L1 dalla forma mensile ARERA (aggregato) | 0,376 | **0,194** |
| picco su 3 minuti | 6,58-8,00 kW | 5,65-7,52 kW |
| ore/anno sopra 3 kW | 86-231 | 30-105 |
| classe di potenza implicata | 6/10/10/10 kW | 6/6/10/10 kW |

### Controlli di coerenza superati

- Il calo di elettricità della famiglia **coincide esattamente** con il gas che
  compare in `Sum.Gas.HH1.json`: 525,3 / 430,2 / 714,1 / 753,6 kWh. Nessuna
  riscalatura: i fuochi si accendono le stesse volte, su un altro vettore.
- Il raffrescamento **scala linearmente** con `CoolingYearlyTotal`: la parte di
  casa passa da 1.939 a 740,7 kWh in tutte e quattro, calo di 1.198 contro 1.197
  attesi. Residuo: ~281 kWh di pompa di circolazione + **466 di condizionatore**,
  dentro l'intervallo reale italiano di 400-700.

### Forma mensile della variante contro ARERA (% dell'anno)

| mese | ARERA | variante | scarto |
|---|---:|---:|---:|
| Gen | 9,67% | 7,52% | −2,15 |
| Feb | 7,65% | 6,61% | −1,04 |
| Mar | 8,24% | 7,37% | −0,87 |
| Apr | 7,08% | 7,84% | +0,76 |
| Mag | 6,85% | 8,57% | +1,72 |
| Giu | 6,98% | 10,21% | +3,23 |
| Lug | 10,04% | 12,86% | +2,82 |
| Ago | 10,11% | 8,09% | −2,02 |
| Set | 7,35% | 8,37% | +1,02 |
| Ott | 7,58% | 7,74% | +0,16 |
| Nov | 8,41% | 7,26% | −1,15 |
| Dic | 10,04% | 7,57% | −2,47 |

Restano **inverno troppo leggero** ed **estate ancora troppo pesante**.

### Fasce orarie F1/F2/F3

Calcolate con le fasce ARERA (F1: lun-ven 08-19; F2: lun-ven 07-08 e 19-23,
sab 07-23; F3: il resto, domeniche e festivi nazionali).

| | F1 | F2 | F3 |
|---|---:|---:|---:|
| **ARERA 3-4,5 kW** | **31,71%** | **30,39%** | **37,90%** |
| pensionati | 46,39% | 23,53% | 30,08% |
| coppia lavoratori | 30,24% | 37,31% | 32,45% |
| famiglia 1 figlio | 34,35% | 35,84% | 29,82% |
| famiglia 3 figli | 30,89% | 36,49% | 32,62% |
| **aggregato** | **35,18%** | **33,58%** | **31,24%** |

**Lo scarto principale è su F3: −6,7 punti.** Cause probabili: il bucato che
gira di giorno (§4.7), e un carico di base troppo basso — `EnergySaving` sceglie
un frigorifero `Siemens Kl 20 LA 65 (A+)` da **82,9 kWh/anno**, poco anche per un
A+ reale (150-200) e molto poco per un combinato (250-350). È il rovescio della
medaglia di `EnergySaving`: azzecca il totale ma appiattisce la base.

### Eterogeneità di forma fra le famiglie

Distanza L1 fra le giornate medie feriali normalizzate:

| | pensionati | coppia | 1 figlio | 3 figli |
|---|---:|---:|---:|---:|
| **pensionati** | — | 0,495 | 0,511 | 0,488 |
| **coppia** | 0,495 | — | 0,149 | 0,124 |
| **1 figlio** | 0,511 | 0,149 | — | 0,118 |
| **3 figli** | 0,488 | 0,124 | 0,118 | — |

I pensionati sono nettamente distinti (altopiano diurno con massimo alle 14,
sera bassa). Ma **coppia, 1 figlio e 3 figli hanno praticamente la stessa forma**
(0,118-0,149): cambia l'ampiezza, non gli orari. La causa è che i time limit
sono **oggetti condivisi da tutte le 66 famiglie del catalogo**, quindi lavoro,
scuola e pasti passano dagli stessi cancelli. È il collasso di forma descritto
da Marrasso, ed è un problema per la domanda di ricerca.

---

## 6. Cosa serve dai CSV ARERA

In ordine di importanza.

1. **La classe `1.5 < P <= 3`**, stesso filtro `Residente`, stessa provincia.
   È la classe del contratto standard italiano, che quella già scaricata
   **esclude**. Serve il prelievo medio annuo, il mensile e le fasce. È il vero
   bersaglio della validazione: se la media di quella classe è, poniamo, 2.200
   kWh, allora la variante testata (2.251-3.447) è ancora alta per i nuclei
   piccoli.

2. **Il mensile e le fasce per tutte le classi di potenza**, per capire come
   scala il consumo con la potenza impegnata. Serve a decidere a quale classe
   appartengono davvero i quattro archetipi: oggi per **energia** starebbero
   nella classe 3-4,5 kW, per **potenza** in nessuna classe domestica (§4.9).
   Le due letture non coincidono, e finché non coincidono il confronto per
   classe è mal posto.

3. **La curva oraria**, se presente. Attenzione: il dato orario ARERA copre solo
   i clienti *trattati orari*, un sottoinsieme di cui va verificata la
   rappresentatività. Servirebbe per validare direttamente il picco mattutino
   (§4.7) e quello serale (§4.8), che oggi possiamo controllare solo
   indirettamente tramite le fasce.

4. **Il filtro provinciale** sulla provincia della CER, invece del dato
   nazionale.

5. Un dato che ARERA **non** ha e che serve comunque: il **tasso di diffusione
   dei condizionatori** (fonte ISTAT). Dai soli dati mensili si determina il
   *prodotto* fra quota di famiglie dotate e taglia dell'impianto (~233 kWh
   elettrici per famiglia media), non i due fattori separatamente.

### Regola metodologica da rispettare

**Normalizzare entrambe le curve a somma unitaria prima di confrontarle**: si
valida la *forma* separatamente dal *livello*. È il passaggio che si sbaglia più
facilmente.

E soprattutto: **se non combacia, si corregge il catalogo, non l'output.** Un
«fattore orario correttivo» sistemerebbe la somma rendendo i profili individuali
meno plausibili — e la ripartizione CER vive esattamente sulle forme individuali.

---

## 7. File

**Profili generati** (orari, kWh, formato di `profili_tutti.csv`, 8.760 righe):

```
CER_LoadProfiles/outputs/csv/
  profili_famiglie_HT07_EnergySaving_2025.csv                  baseline
  profili_famiglie_HT07_EnergySaving_2025_dettaglio.csv
  profili_famiglie_HT07_ES_gas_cooling1400_2025.csv            variante A+B
  profili_famiglie_HT07_ES_gas_cooling1400_2025_dettaglio.csv
```

I file `_dettaglio` scompongono ogni famiglia in tre colonne:
`_famiglia_kWh` (elettrodomestici, `Electricity_HH1`), `_casa_kWh` (pompa di
circolazione + condizionatore, `Electricity_House`), `_POD_kWh` (la somma, cioè
quello che misura il contatore).

`profili_tutti.csv` **non è stato modificato**: contiene ancora i profili
originali `HT06` + `Random`, che sono quelli su cui girano i numeri di
riferimento del progetto.

**Codice**: `CER_LoadProfiles/lpg_runner.py` (generazione),
`lpg_db/build_italian_db.py` (catalogo italiano, 11 migrazioni),
`lpg_db/confronta_profili.py` (metrica Profildifferenz).

---

## 8. Trappole verificate, da non ripetere

- **Il fallback sintetico è silenzioso.** Qualsiasi errore pyLPG viene catturato
  e sostituito con un profilo finto, senza far fallire il run.
- **Un run può "riuscire" producendo zero file.** È successo: il motore rifiutava
  il catalogo con `DataIntegrityException` ma lo script usciva con codice 0.
  Controllare sempre che i file esistano, non l'exit code.
- **Il vettore energetico di un dispositivo sta in due tabelle**:
  `tblRealDeviceLoadType` e `tblDeviceActionDevices`. Cambiarne una sola fa
  rifiutare il catalogo.
- **I nomi dei time limit mentono.** `Dinner Time (18:00-21:00)` contiene in
  realtà 19:00-21:30. Leggere sempre `tblTimeLimitEntries`.
- **Voci gerarchiche**: alcuni time limit (es. `TL 106`) hanno voci legate da
  `ParentEntryID` con logica AND/OR. Un `UPDATE` di gruppo le rompe: agire per
  ID di singola voce.
- **Mai modificare `profilegenerator.IT.db3` a mano**: `build_italian_db.py` lo
  rigenera da zero e cancellerebbe tutto. Le modifiche vanno scritte come
  migrazioni; gli esperimenti su una copia.
- **Cambiare le `CalcOptions` perturba la sequenza casuale**: stesso seed, stessa
  configurazione, risultati diversi di circa l'1%.
