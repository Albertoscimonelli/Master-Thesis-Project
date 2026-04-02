# CER Load Profiles Generator

Generatore di profili di carico elettrico per una Comunita Energetica Rinnovabile (CER), basato su:

- **RAMP** — profili per utenze commerciali/industriali (uffici, piccole industrie, negozi)
- **pyLPG** (LoadProfileGenerator) — profili per famiglie residenziali

## Prerequisiti

- **Python >= 3.10**
- **Runtime .NET 6** (richiesto da pyLPG/LoadProfileGenerator)
  - **Windows**: incluso automaticamente
  - **Linux**: `sudo apt install dotnet-runtime-6.0`
  - **macOS**: `brew install dotnet`

> **Nota**: pyLPG scarica automaticamente i binari di LPG (~500 MB) alla prima esecuzione.

## Installazione

```bash
# Crea ambiente virtuale
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
# Esecuzione con configurazione di default
python generate_load_profiles.py

# Esecuzione con configurazione personalizzata
python generate_load_profiles.py --config path/to/my_config.yaml
```

## Configurazione

Modifica `config/simulation_config.yaml` per personalizzare:

- **Anno e risoluzione temporale** della simulazione
- **Use case RAMP**: tipo e numero di aziende/PMI da simulare
- **Famiglie pyLPG**: template e numero di nuclei familiari
- **Output**: profili individuali, aggregato CER, cartella di destinazione

### Aggiungere un nuovo use case RAMP

1. Crea un file `ramp_inputs/use_cases/nome_use_case.py`
2. Definisci una funzione `create_user() -> User` che configura elettrodomestici e finestre d'uso
3. Aggiungi il nome in `simulation_config.yaml` sotto `ramp.use_cases`

### Aggiungere un tipo di famiglia pyLPG

1. Consulta i template disponibili in `pylpg.lpgdata.HouseholdTemplates`
2. Aggiungi una voce in `config/simulation_config.yaml` sotto `lpg.households`
3. Specifica `label`, `template`, `household_ref` (nome attributo in `lpgdata.Households`) e `count`

## Formato CSV di Output

I file CSV generati sono compatibili con MATLAB (`readtable()`):

```
timestamp,office_1,office_2,household_1,household_2
2024-01-01T00:00:00,0.312,0.289,0.150,0.180
2024-01-01T00:15:00,0.298,0.301,0.145,0.175
...
```

- Separatore: `,`
- Prima colonna: timestamp ISO8601
- Valori in **kW**
- Nessun indice numerico aggiuntivo

### File generati

| File | Contenuto |
|------|-----------|
| `profili_aziende.csv` | Profili individuali aziende/PMI (RAMP) |
| `profili_famiglie.csv` | Profili individuali famiglie (pyLPG) |
| `profili_tutti.csv` | Tutti i profili combinati |
| `profilo_CER_aggregato.csv` | Somma totale CER in kW |

## Struttura del Progetto

```
CER_LoadProfiles/
  config/simulation_config.yaml      # Configurazione simulazione
  ramp_inputs/use_cases/             # Definizioni use case RAMP
    office.py                        # Ufficio medio
    small_industry.py                # Piccola industria
    retail.py                        # Negozio al dettaglio
  lpg_inputs/household_definitions.py # Definizioni famiglie pyLPG
  outputs/csv/                       # CSV generati
  generate_load_profiles.py          # Script orchestratore
  ramp_runner.py                     # Modulo esecuzione RAMP
  lpg_runner.py                      # Modulo esecuzione pyLPG
  postprocessing.py                  # Ricampionamento, aggregazione, export
```

## Note

- Se pyLPG non e installato o il runtime .NET non e disponibile, vengono generati **profili sintetici di fallback** con pattern realistici per famiglie italiane
- RAMP genera profili stocastici: ogni esecuzione produce risultati leggermente diversi
- Per riproducibilita, i seed random sono calcolati deterministicamente dalla configurazione
