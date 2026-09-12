# CER Load Profiles Generator

Generatore di profili di carico elettrico per una Comunita Energetica Rinnovabile (CER), basato su:

- **RAMP** (rampdemand) — profili stocastici per utenze commerciali/industriali (uffici, piccole industrie, negozi)
- **pyLPG** (LoadProfileGenerator) — profili realistici per famiglie residenziali (con fallback sintetico)

## Prerequisiti

- **Python >= 3.10**
- **Runtime .NET 6** (richiesto da pyLPG/LoadProfileGenerator)
  - **Windows**: incluso automaticamente
  - **Linux**: `sudo apt install dotnet-runtime-6.0`
  - **macOS**: `brew install dotnet`

> **Nota**: pyLPG scarica automaticamente i binari di LPG (~500 MB) alla prima esecuzione.
> Se pyLPG non e disponibile, vengono generati profili sintetici di fallback.

## Installazione

```bash
# Crea ambiente virtuale (consigliato)
python -m venv venv

# Attiva (Windows)
venv\Scripts\activate
# Attiva (Linux/macOS)
source venv/bin/activate

# Installa dipendenze
pip install -r requirements.txt
```

## Utilizzo

```bash
# Dalla cartella CER_LoadProfiles/
cd CER_LoadProfiles

# Esecuzione con configurazione di default
python generate_load_profiles.py

# Esecuzione con configurazione personalizzata
python generate_load_profiles.py --config path/to/my_config.yaml
```

### Output tipico

```
GENERAZIONE COMPLETATA
  Profili aziende (RAMP):   3
  Profili famiglie (LPG):   3
  Totale utenti CER:        6
  Anno:                     2025
  Risoluzione output:       1 h (energia in kWh per ora)
  File generati:            4
  Tempo di esecuzione:      36.4 s
```

## Configurazione

Il file `config/simulation_config.yaml` controlla tutti i parametri:

```yaml
simulation:
  year: 2025
  timezone: "Europe/Rome"
  # Risoluzione di output fissa a 1 ora (non configurabile)

ramp:
  date_start: "2025-01-01"
  date_end: "2025-12-31"
  use_cases:
    - name: "office"
      num_users: 1
    - name: "small_industry"
      num_users: 1
    - name: "retail"
      num_users: 1

lpg:
  households:
    - label: "pensionati"
      household_ref: "CHR54_Retired_Couple_no_work"
      count: 1
    - label: "coppia_lavoratori"
      household_ref: "CHR02_Couple_30_64_age_with_work"
      count: 1
    - label: "famiglia_1figlio"
      household_ref: "CHR03_Family_1_child_both_at_work"
      count: 1

output:
  folder: "outputs/csv"
  aggregate_total: true
  individual_profiles: true
```

### Aggiungere un nuovo use case RAMP

1. Crea un file `ramp_inputs/use_cases/nome_use_case.py`
2. Dichiaralo in **una delle due forme** (vedi sotto)
3. Aggiungi il nome in `simulation_config.yaml` sotto `ramp.use_cases`

```python
# forma semplice: un solo comportamento per tutto l'anno
def create_user() -> User: ...

# forma a regimi: il comportamento cambia nel corso dell'anno
REGIMI: dict[str, Callable[[], User]] = {"lezione": ..., "chiusura_estiva": ...}
def regime(giorno: datetime.date) -> str: ...
```

### Lo strato dei regimi di calendario

RAMP 0.5.0 non ha ne' stagionalita' ne' festivita', e non le puo' avere: la
finestra di un `Appliance` e' definita in **minuti del giorno**, non in giorni
dell'anno. Una scuola chiusa da meta' giugno a meta' settembre non e' quindi
rappresentabile con il solo RAMP.

La forma a regimi la rende rappresentabile: `ramp_runner` genera **un anno
intero per ogni regime** e poi sceglie, giorno per giorno, quello che
`regime(giorno)` dichiara. Non si concatenano segmenti — con due o quattro
regimi il costo sono due o quattro generazioni, e in cambio ogni regime pesca
dalla propria stocastica su anno pieno, senza spezzare il flusso di numeri
casuali a ogni cambio di stagione. Il seed resta `_seed_stabile()` con il nome
del regime nella stringa, cosi' due regimi dello stesso archetipo non producono
la stessa identica giornata.

**Cosa mettere nel `regime()` e cosa no.** Le festivita' nazionali non sono una
proprieta' dell'archetipo: sono il calendario civile italiano, gia' scritto in
[`lpg_db/valida_domestici.py`](lpg_db/valida_domestici.py) (`festivi()`), e si
importano da li'. Quello che va nel modulo dell'archetipo e' il suo **calendario
di apertura** — la scuola chiusa d'estate, il municipio con agosto ridotto e il
sabato di solo sportello — che e' una proprieta' dell'edificio e vuole una fonte
citabile accanto, come ogni migrazione del catalogo LPG.

Il collaudo sta in [`ramp_db/collaudo_regimi.py`](ramp_db/collaudo_regimi.py) e
verifica due cose: che gli archetipi **senza** regimi escano identici bit per
bit a prima dell'introduzione dello strato (impronte SHA-256 misurate prima
della modifica), e che la selezione giorno per giorno prenda il giorno giusto
dal regime giusto.

### Aggiungere un tipo di famiglia pyLPG

1. Consulta i template disponibili in `pylpg.lpgdata.HouseholdTemplates`
2. Aggiungi una voce in `simulation_config.yaml` sotto `lpg.households`
3. Specifica `label`, `template`, `household_ref` e `count`

## Formato CSV di Output

I file CSV generati sono compatibili con MATLAB (`readtable()`):

```
timestamp,office_1_kWh,small_industry_1_kWh,retail_1_kWh
2025-01-01T00:00:00,0.000,0.000,0.484
2025-01-01T01:00:00,0.000,0.000,0.438
```

- Separatore: `,`
- Prima colonna: timestamp ISO8601
- Valori in **kWh** consumati in quell'ora (colonne con suffisso `_kWh`)
- Risoluzione: 1 ora (fissa, non configurabile)
- Righe: ~8760 (1 anno intero)

### File generati

| File | Contenuto |
|------|-----------|
| `profili_aziende.csv` | Profili individuali aziende/PMI (1 colonna per use case configurato: office, small_industry, retail) |
| `profili_famiglie.csv` | Profili individuali famiglie (1 colonna per nucleo familiare configurato) |
| `profili_tutti.csv` | Tutti i profili aziende + famiglie combinati (join sui timestamp comuni) |
| `profilo_CER_aggregato.csv` | Somma totale CER in kWh/h (1 colonna: `total_CER_kWh`) |

## Struttura del Progetto

```
CER_LoadProfiles/
  generate_load_profiles.py          # Entry point - orchestratore pipeline
  ramp_runner.py                     # Generazione profili RAMP + patch compatibilita
  lpg_runner.py                      # Generazione profili pyLPG + fallback sintetico
  postprocessing.py                  # Ricampionamento, aggregazione, export CSV
  config/
    simulation_config.yaml           # Configurazione principale (4 famiglie)
    simulation_config.baseline.yaml  # Run di controllo (senza profilo di temperatura)
    simulation_config.campione20.yaml   # 4 archetipi x 5 semi: errore di numerosita'
    simulation_config.lombardia20.yaml  # Societa' lombarda: 20 famiglie, 20 template
    simulation_config.milano20.yaml     # Societa' milanese: idem, comune di Milano
  ramp_inputs/use_cases/
    office.py                        # Ufficio medio (illuminazione, PC, clima, stampante, caffe)
    small_industry.py                # Piccola industria (CNC, compressore, illuminazione, ufficio)
    retail.py                        # Negozio (illuminazione, cassa, frigo, clima)
  lpg_inputs/
    household_definitions.py         # Catalogo famiglie pyLPG di riferimento
  lpg_db/                            # Catalogo italiano e validazione (vedi sotto)
    build_italian_db.py              # 19 migrazioni sul .db3 tedesco di pyLPG
    build_manifest.json              # Evidenza della build: righe per migrazione
    riferimento_arera.py             # Bersaglio: curve ARERA per classe di potenza
    riferimento_istat.py             # Calibrazione: AVQ, Consumi, Dotazioni, HETUS
    tipologie_famiglie.py            # Composizione dei nuclei da ISTAT + censimento
    confronta_profili.py             # Utilita' condivise (curve medie)
    valida_domestici.py              # Livello, forma e fasce contro ARERA
    curva_numerosita.py              # Numerosita' vs modello; eterogeneita' di forma
    confronta_societa.py             # Confronto fra due composizioni familiari
    dati/                            # Cache ARERA (versionata) e rapporti per passo
  ramp_db/                           # Riferimento non domestico (vedi sotto)
    riferimento_arera_nd.py          # Livello: ARERA per ATECO e classe BTA, mensile
    riferimento_gse_nd.py            # Forma oraria: profili standard GSE
    leggi_quaderno_enea.py           # Estrae gli indici kWh/m2 dai PDF di benchmark
    benchmark_letteratura.csv        # Secondo parere sul livello, con fonte e pagina
    valida_non_domestici.py          # La misura: livello, forma, fasce, picco
    collaudo_regimi.py               # Non regressione dello strato dei regimi
    dati/riferimento_arera_nd/       # Cache ARERA non domestica (versionata)
    dati/validazione/                # Stdout catturati, un file per passo
  outputs/csv/                       # CSV generati
```

## Catalogo italiano (`lpg_db/`)

Il catalogo di LoadProfileGenerator e' **tedesco**: festivita', orari dei pasti,
vacanze, dotazione degli elettrodomestici. `build_italian_db.py` vi applica 19
migrazioni (583 righe) e produce `profilegenerator.IT.db3`, che **non e'
versionato** perche' e' un artefatto derivato: si ricostruisce con

```bash
cd lpg_db && ../../venv/Scripts/python build_italian_db.py
```

La ricostruzione e' deterministica: a parita' di sorgente produce lo stesso
SHA-256. Lo script verifica l'impronta del `.db3` tedesco originale e si ferma
se e' cambiata.

Ogni migrazione porta **in codice** la fonte che la giustifica (ISTAT AVQ 2024,
Consumi energetici 2021, Dotazioni 2024, ETHOS.ActivityAssure). Il registro
leggibile, modifica per modifica, e' il §13 di
[REPORT_VALIDAZIONE_LPG.md](../REPORT_VALIDAZIONE_LPG.md).

**Attenzione**: `PRAGMA integrity_check` verifica la struttura SQLite, non la
coerenza semantica del catalogo. Un catalogo che passa il check puo' comunque
essere rifiutato dal motore con `DataIntegrityException`: ogni migrazione
richiede uno smoke run.

## Riferimento non domestico (`ramp_db/`)

Il gemello non domestico di `lpg_db/`: costruisce il bersaglio contro cui validare
gli archetipi RAMP (`office`, e i futuri `scuola_superiore` e `comune`). A
differenza del lato domestico il bersaglio viene da **due fonti diverse**, perche'
nessuna delle due lo fornisce per intero:

| Cosa | Fonte | Modulo |
|---|---|---|
| livello annuo e peso di ciascun mese | ARERA, per ATECO e classe di potenza (solo mensile) | `riferimento_arera_nd.py` |
| forma oraria dentro il mese | profili standard GSE | `riferimento_gse_nd.py` |

Un profilo di riferimento completo si ottiene componendo le due cose:

```bash
cd ramp_db
python riferimento_arera_nd.py --ispeziona          # struttura dei file grezzi
python riferimento_arera_nd.py Milano --ateco 82.11 # livello e forma mensile
python riferimento_gse_nd.py                        # forma oraria e controlli
python leggi_quaderno_enea.py --elenca              # indici kWh/m2 nei PDF
python valida_non_domestici.py ../outputs/csv/profili_tutti.csv   # la misura
```

### Che cosa dice la misura oggi, su `office`

Prima di qualunque correzione, l'archetipo **non passa** su tutte le grandezze
che la soglia copre — evidenza completa in
[`ramp_db/dati/validazione/02_office_prima_correzione.txt`](ramp_db/dati/validazione/02_office_prima_correzione.txt):

| Grandezza | `office` | Riferimento | Soglia |
|---|---|---|---|
| livello annuo | 10.957 kWh | 6.951 kWh (ARERA BTA4, ATECO 82.11) | ±3,1% → **1,58x** |
| forma mensile (L1) | 0,0866 | — | 0,0407 → **2,1 volte** |
| TVD feriale vs GSE | 0,450 | — | — |
| fasce F1/F2/F3 | 92,97 / 2,64 / 4,39 | 38,01 / 24,67 / 37,32 | — |
| picco feriale | ore 15 | ore 11 | — |

Il livello di 10.957 kWh coincide quasi con quello che ARERA attribuisce alla
classe **BTA5** (11.126 kWh, potenza oltre 10 kW), mentre `office` ha 9,2 kW
installati, cioe' BTA4: **l'archetipo consuma come una classe piu' grande di
quella che dichiara**. La forma mensile e' piatta — la media giornaliera
feriale sta fra 40,0 e 43,6 kWh in tutti e dodici i mesi, con agosto (41,5)
indistinguibile da gennaio (42,4) — e i festivi nazionali sono giornate di
lavoro piene: Natale 47,9 kWh, Ferragosto 40,6, Capodanno 44,8.

Due letture da non sbagliare. Lo scarto sulle **fasce** e' in buona parte un
artefatto della fonte: F1 e' lun-ven 8-19 e `office` e' acceso solo in quella
finestra, mentre il profilo GSE aggrega anche le utenze attive h24. E la voce
**`spento`** nelle colonne di sabato e domenica non e' uno zero: `office` ha
`wd_we_type=0` e nel fine settimana vale 0,000 kWh su 2.496 ore, quindi la curva
normalizzata non esiste e la TVD non e' calcolabile. Stamparla come 0,000 —
come faceva la prima versione di questo modulo — avrebbe detto "forma perfetta"
proprio dove il modello e' fermo.

### Le fonti, e da dove vengono i dati

I file grezzi stanno in `CER_LoadProfiles/File Non Domestici/`, **non versionati**
per dimensione (~692 MB, vedi `.gitignore`); si versiona la cache in
`ramp_db/dati/riferimento_arera_nd/`, con accanto lo SHA-256 di ogni sorgente,
cosi' la validazione resta rieseguibile da chi clona il progetto. La radice si
sovrascrive con la variabile d'ambiente `CER_DATI_ESTERNI`.

- **ARERA** — consumi provinciali dei clienti non domestici in bassa tensione,
  sezione *Monitoraggio retail*, annualita' **2024 e 2025**: un CSV per classe
  tariffaria BTA. Ogni riga e' il prelievo medio mensile per punto di prelievo
  di una terna (provincia, classe di potenza, classe ATECO). Copertura
  verificata: il **2025** ha 110 province, 20 regioni, 765 classi ATECO; il
  **2024** ha le sole **12 province lombarde** (Milano compresa) e 609 classi.
- **GSE** — "Modalita' di profilazione dei dati di misura: profili standard GSE
  in prelievo e immissione", annualita' 2024 e 2025, area CACER del portale GSE.
  I due xlsx del 2025 in cartella sono stati verificati identici per dimensione
  a quelli dello zip ufficiale `profili GSE_prelievo e immissione_2025.zip`.
- **Base normativa dell'applicazione dei profili** — Testo Integrato Autoconsumo
  Diffuso (TIAD), allegato alla delibera ARERA 727/2022/R/eel: quando il gestore
  di rete non e' tecnicamente in grado di raccogliere i dati di misura orari, il
  GSE profila i dati per tipologia di utenza secondo i profili standard. Per un
  socio di CER non trattato orario la curva che entra nel settlement **e'** quella.
- **Decodifica dei codici di colonna** (`PAUM`, `PDMF`, `IFVM`, ...) — GSE,
  "Modalita' di profilazione dei dati di misura e relative modalita' di utilizzo
  ai sensi dell'articolo 9 dell'Allegato A alla Delibera 318/2020/R/eel",
  versione 1 del 04/04/2022 (`Autoconsumatori.pdf`). Codice `XZZY`: X = P
  prelievo puro / M misto / I immissione; ZZ = tipologia di utenza; Y = M
  monorario / F a fasce. Il documento precede il TIAD, ma la struttura dei codici
  nei file 2024 e 2025 e' invariata.

### I benchmark di letteratura: l'albero energetico e il secondo parere

ARERA e GSE dicono quanto consuma e quando, ma non **di che cosa** e' fatto quel
consumo. Il difetto piu' grave degli archetipi RAMP non e' che i numeri di
`office.py` siano sbagliati: e' che non hanno una fonte. Gli indici di
prestazione energetica per uso finale ce l'hanno, e ogni ramo diventa un gruppo
di `Appliance`. `benchmark_letteratura.csv` li raccoglie con fonte, pagina e
stato di verifica; `leggi_quaderno_enea.py` li ritrova nei PDF.

**ENEA con Assoimmobiliare, *Uffici — Quaderni dell'Efficienza Energetica***
(Ricerca di Sistema Elettrico 2022-2024, MASE), guida alla diagnosi energetica
ex Allegato II del D.Lgs. 102/2014. Il §4.3 porta gli IPE di secondo livello,
cioe' l'albero energetico elettrico di un ufficio:

| Uso finale | Indice | Pagina |
|---|---|---|
| Illuminazione | 25,7 ± 11,8 kWh/m² (≤1.000 m²: 29,1; >1.000 m²: 23,7) | 75 |
| Climatizzazione, trattamento aria e ACS | 126 ± 53 kWh/m² tutti i vettori; **zona E-F solo elettrico 93 ± 39** | 76-77 |
| Infrastruttura informatica (PC, monitor, stampanti, router) | 21,4 ± 11,8 kWh/m², oppure 534 ± 253 kWh/utente | 77-78 |
| Data center | PUE 1,83 ± 0,36 | 78 |
| *Indice globale di sito, tutti i vettori* | *201 ± 79 kWh/m²* | *73* |

Milano e' in **zona climatica E**: la riga da usare per `office` e' quella dei
93 ± 39 kWh/m² a impianto solo elettrico, non i 126 che sommano anche il gas.

**Corgnati, Fabrizio, Ariaudo, Rollino, *Edifici tipo, indici di benchmark di
consumo ... ad uso scolastico (medie superiori e istituti tecnici)***, Report
RSE/2010: per `scuola_superiore`, **energia elettrica 15 kWh/m²** (rule of thumb
30) contro 114 kWh/m² di energia utile per la climatizzazione invernale, con un
breakdown 88% termico / 12% elettrico (p. 42). Da citare con la sua data: e' del
2010.

**RSE, *I consumi della Pubblica Amministrazione* (RSEview**, ISBN
978-88-943145-5-7): il §3.3 copre gli uffici pubblici "dall'amministrazione
centrale a quelli dell'amministrazione regionale sino al livello comunale",
quindi comprende il municipio di `comune`. La Tabella 3.8 (p. 47) da' 373,39
ktep elettrici su 38.248 migliaia di m² in Italia, e 57,17 ktep su 5.553 in
Lombardia.

**La colonna `verificato` ha tre valori, e la distinzione e' il punto della
tabella**: `si` per un numero **riletto sul documento** alla pagina indicata;
`no` per una riga proposta dall'estrattore e non ancora controllata; `derivato`
per un valore **calcolato da altri**, mai stampato come tale nella fonte — i
113,5 kWh/m² degli uffici PA italiani sono il rapporto fra le due grandezze
della Tabella 3.8, non una citazione, e in tesi vanno presentati come tali.

`leggi_quaderno_enea.py` distingue le pagine in cui valore e unita' sono
attaccati (leggibili in automatico) da quelle con la **sola unita'**, dove
l'estrazione ha spezzato la tabella e il numero va letto a mano con `--pagine`.
Non e' un dettaglio: nel report sulle scuole l'unita' sta nell'intestazione di
colonna e i valori su una riga a parte, quindi **tutte** le sue 50 pagine di
indici cadono nel secondo gruppo. Una ricerca dei soli valori attaccati
all'unita' avrebbe concluso che quel documento non contiene benchmark.

### Sei proprieta' dei dati, verificate e non assunte

1. **ARERA non domestico e' solo mensile.** Non esiste la traccia oraria che sul
   lato domestico copre i clienti trattati orari: la forma oraria non e'
   validabile su questa fonte, e per quello servono i profili GSE.
2. **I coefficienti GSE sono normalizzati dentro il mese**, non sull'anno: 1 per
   i profili monorari, 3 per quelli a fasce (una normalizzazione per fascia). Il
   profilo piatto `IAFM` vale 1/744 in ogni ora di gennaio. Ne segue che il peso
   relativo dei mesi va preso da ARERA: GSE non lo contiene.
3. **Il profilo predefinito e' il monorario `PAUM`**, non la variante a fasce.
   Non e' una preferenza sul misuratore: un profilo a fasce richiederebbe il
   consumo mensile *per fascia*, che il file ARERA non domestico non pubblica.
4. **La colonna `Data ora` del file GSE 2025 e' corrotta** da errore di virgola
   mobile (l'ultimo istante e' `22:59:59,998` del 31 dicembre) e verso fine anno
   resta indietro di un'ora rispetto alla colonna `Ora`. L'indice si ricostruisce
   dalle colonne intere Anno/Mese/Giorno/Ora. Indicizzare su `Data ora` produce
   una curva giornaliera traslata di un'ora e somme mensili che non chiudono a 1.
5. **Le due annualita' ARERA non hanno lo stesso formato.** Nomi di colonna
   diversi per gli stessi campi, il 2024 senza la colonna `Regione` e con
   `Anno` ripetuta due volte, il mese come numero nel 2025 e come abbreviazione
   nel 2024 (`Gen` ... `Sett`, con due t), e soprattutto i numeri: virgola
   decimale nel 2025 (`15,82709464`), punto come separatore delle **migliaia**
   nel 2024 (`17.655` vale 17655). Le etichette di classe sono invece identiche
   fra i due anni, ed e' cio' che li rende confrontabili. Lo zip 2024 contiene
   inoltre **due coppie di file byte-identici** (BTA5 e BTA6 pubblicati due
   volte): vengono deduplicati per contenuto, o le loro righe sarebbero contate
   due volte.
6. **La cache si invalida anche quando cambia il parser**, non solo quando
   cambiano le sorgenti: il manifesto porta un `versione_parser` accanto agli
   SHA-256. Non e' una precauzione teorica — una cache scritta mentre il punto
   delle migliaia del 2024 veniva ancora letto come separatore decimale e'
   sopravvissuta alla correzione, perche' i sorgenti non erano cambiati, e
   teneva il livello 2024 mille volte piu' basso del vero.

### La soglia di accettazione, misurata

Il rumore della fonte fra le due annualita' ARERA e' la soglia contro cui si
giudicheranno gli archetipi — lo stesso criterio del lato domestico, non un
numero scelto a tavolino. Misurato su Milano, ATECO 82.11:

| Classe | Scarto sul livello annuo | L1 sulla forma mensile |
|---|---:|---:|
| BTA1 | +1,0% | 0,0634 |
| BTA2 | −3,0% | 0,0568 |
| BTA3a | −4,5% | 0,0662 |
| BTA3b | −3,1% | 0,0556 |
| **BTA4** (classe candidata di `office`) | **−3,1%** | **0,0407** |
| BTA5 | −1,5% | 0,0737 |
| BTA6 | +3,8% | 0,0673 |

In ordine di grandezza: **±3% sul livello annuo e ~0,05 di L1 sulla forma
mensile**. Per `office` il bersaglio e' 7.062 kWh/anno nel 2024 e 6.840 nel 2025.

### Tre limiti da dichiarare in tesi

- **Il 2024 provinciale copre le sole province lombarde.** Milano c'e', quindi
  per la CER di questo progetto la soglia resta calcolabile; per una provincia
  fuori dalla Lombardia esiste il solo 2025, e `rumore_fonte()` si ferma con un
  errore esplicito invece di restituire un numero costruito su un anno solo.
- **Il profilo GSE dei non domestici e' uno solo** per tutta la categoria "altri
  usi": non distingue un ufficio da una scuola da un municipio. Uno scarto sulla
  forma di un archetipo con stagionalita' marcata e' quindi atteso anche se
  l'archetipo e' corretto.
- **Non e' una misura, e' una tabella di giorni tipo.** Misurato: 291 valori
  distinti in un anno (12 mesi x 24 ore = 288), differenza massima fra le tabelle
  2024 e 2025 pari a 7,5e-5, distanza fra giornata feriale e domenicale pari a
  0,001. Il profilo ignora quindi il giorno della settimana, e non varia
  praticamente da un anno all'altro: la chiusura nel fine settimana di un
  archetipo **non e' validabile** su questa fonte, e lo scarto fra due annualita'
  non puo' fare da soglia di accettazione come sul lato domestico.

## Pipeline di Esecuzione

```
[YAML Config] --> generate_load_profiles.py
                      |
         +------------+------------+
         |                         |
    ramp_runner.py            lpg_runner.py
    (RAMP 1-min W)          (pyLPG/sintetico 1-min W)
         |                         |
         +------------+------------+
                      |
              postprocessing.py
              (aggregazione oraria in energia kWh, export CSV)
                      |
              outputs/csv/*.csv
```

## Note Tecniche

- **Patch di compatibilita**: `ramp_runner.py` include patch per RAMP 0.5.0 con NumPy >= 2.0 e Pandas >= 3.0
- **Fallback sintetico**: se pyLPG non e installato, `lpg_runner.py` genera profili basati su pattern tipici italiani (pensionati, lavoratori, famiglie con figli)
- **Seed random**: calcolati da `_seed_stabile(label, indice)`, che usa `zlib.crc32` e non `hash()`. `hash()` sulle stringhe e' randomizzato a ogni avvio dell'interprete (PEP 456) e rendeva i profili diversi a ogni esecuzione; con crc32 il seed e' deterministico. La riproducibilita' e' il prerequisito per poter attribuire una differenza fra due run a una modifica del modello invece che al generatore casuale
- **Profili stocastici**: RAMP genera profili diversi ad ogni esecuzione grazie alla variabilita integrata nel modello
- **Unita interne**: tutti i profili sono generati in Watt a 1 minuto, poi aggregati in energia (kWh) su base oraria nel postprocessing
