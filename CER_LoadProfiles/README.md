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
2. Definisci una funzione `create_user() -> User` che configura elettrodomestici e finestre d'uso
3. Aggiungi il nome in `simulation_config.yaml` sotto `ramp.use_cases`

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
    dati/riferimento_arera_nd/       # Cache ARERA non domestica (versionata)
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
```

### Le fonti, e da dove vengono i dati

I file grezzi stanno in `CER_LoadProfiles/File Non Domestici/`, **non versionati**
per dimensione (~692 MB, vedi `.gitignore`); si versiona la cache in
`ramp_db/dati/riferimento_arera_nd/`, con accanto lo SHA-256 di ogni sorgente,
cosi' la validazione resta rieseguibile da chi clona il progetto. La radice si
sovrascrive con la variabile d'ambiente `CER_DATI_ESTERNI`.

- **ARERA** — consumi provinciali dei clienti non domestici in bassa tensione,
  "Dati provincia" parti 1-3, anno 2025: sette CSV, uno per classe tariffaria
  BTA. Ogni riga e' il prelievo medio mensile per punto di prelievo di una terna
  (provincia, classe di potenza, classe ATECO). Copertura verificata: 110
  province, 20 regioni, 12 mesi, 755 classi ATECO.
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

### Quattro proprieta' dei dati, verificate e non assunte

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

### Due limiti da dichiarare in tesi

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
