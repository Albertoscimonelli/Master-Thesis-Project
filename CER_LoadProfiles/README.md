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
