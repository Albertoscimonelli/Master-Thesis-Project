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
  Profili aziende (RAMP):   6
  Profili famiglie (LPG):   5
  Totale utenti CER:        11
  Anno:                     2024
  Risoluzione:              15 min
  File generati:            4
  Tempo di esecuzione:      36.4 s
```

## Configurazione

Il file `config/simulation_config.yaml` controlla tutti i parametri:

```yaml
simulation:
  year: 2024
  timezone: "Europe/Rome"
  temporal_resolution_minutes: 15   # Risoluzione CSV finali

ramp:
  num_days: 365
  date_start: "2024-01-01"
  date_end: "2024-12-31"
  use_cases:
    - name: "office"            # 3 uffici
      num_users: 3
    - name: "small_industry"    # 2 piccole industrie
      num_users: 2
    - name: "retail"            # 1 negozio
      num_users: 1

lpg:
  households:
    - label: "pensionati"
      household_ref: "CHR54_Retired_Couple_no_work"
      count: 2
    - label: "coppia_lavoratori"
      household_ref: "CHR02_Couple_30_64_age_with_work"
      count: 2
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
timestamp,office_1,office_2,household_1,household_2
2024-01-01T00:00:00,0.312,0.289,0.150,0.180
2024-01-01T00:15:00,0.298,0.301,0.145,0.175
```

- Separatore: `,`
- Prima colonna: timestamp ISO8601
- Valori in **kW**
- Risoluzione: 15 minuti (configurabile)
- Righe: ~35.000 (1 anno intero)

### File generati

| File | Contenuto |
|------|-----------|
| `profili_aziende.csv` | Profili individuali aziende/PMI (6 colonne: 3 office + 2 small_industry + 1 retail) |
| `profili_famiglie.csv` | Profili individuali famiglie (5 colonne: household_1..5) |
| `profili_tutti.csv` | Tutti gli 11 profili combinati in un unico file |
| `profilo_CER_aggregato.csv` | Somma totale CER in kW (1 colonna: total_CER_kW) |

## Struttura del Progetto

```
CER_LoadProfiles/
  generate_load_profiles.py          # Entry point - orchestratore pipeline
  ramp_runner.py                     # Generazione profili RAMP + patch compatibilita
  lpg_runner.py                      # Generazione profili pyLPG + fallback sintetico
  postprocessing.py                  # Ricampionamento, aggregazione, export CSV
  config/
    simulation_config.yaml           # Configurazione simulazione
  ramp_inputs/use_cases/
    office.py                        # Ufficio medio (illuminazione, PC, clima, stampante, caffe)
    small_industry.py                # Piccola industria (CNC, compressore, illuminazione, ufficio)
    retail.py                        # Negozio (illuminazione, cassa, frigo, clima)
  lpg_inputs/
    household_definitions.py         # Catalogo famiglie pyLPG di riferimento
  outputs/csv/                       # CSV generati
```

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
              (resample 15-min, export kW)
                      |
              outputs/csv/*.csv
```

## Note Tecniche

- **Patch di compatibilita**: `ramp_runner.py` include patch per RAMP 0.5.0 con NumPy >= 2.0 e Pandas >= 3.0
- **Fallback sintetico**: se pyLPG non e installato, `lpg_runner.py` genera profili basati su pattern tipici italiani (pensionati, lavoratori, famiglie con figli)
- **Riproducibilita**: i seed random sono calcolati deterministicamente da `hash(nome_utente_indice) % 2^31`
- **Profili stocastici**: RAMP genera profili diversi ad ogni esecuzione grazie alla variabilita integrata nel modello
- **Unita interne**: tutti i profili sono generati in Watt a 1 minuto, poi convertiti in kW a 15 minuti nel postprocessing
