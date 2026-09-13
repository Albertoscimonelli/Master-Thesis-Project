# Societa' lombarda a cento famiglie: generazione e validazione

Estensione di `simulation_config.lombardia20.yaml` alla scala di 100 famiglie,
sulla stessa matrice dimensione x tipo gia' pubblicata in
[composizione_cer_scalata.md](../tables/composizione_cer_scalata.md).

## Composizione (Lombardia, pesi AVQ originali)

| componenti | nessun occupato | pensionati | un adulto in casa | tutti occupati | totale |
|---|---|---|---|---|---|
| 1 | 4 | 17 | 0 | 17 | 38 |
| 2 | 4 | 9 | 8 | 8 | 29 |
| 3 | 2 | 0 | 9 | 6 | 17 |
| 4 | 1 | 0 | 6 | 5 | 12 |
| 5+ | 0 | 0 | 3 | 1 | 4 |
| **totale** | **11** | **26** | **26** | **37** | **100** |

Fonti: ISTAT *Aspetti della vita quotidiana 2024*, microdati Lombardia (1.831
famiglie, 4.139 individui, copertura 100% dei componenti); ISTAT *Censimento
permanente della popolazione 2021* (rilascio 2023), dati per sezione,
aggregato regionale. Allocazione gerarchica a resto maggiore
(`tipologie_famiglie.py --famiglie 100`), stessa logica di `lombardia20.yaml`.

## Dalla cella ai template: 66 archetipi, ripetuti dove serve

Il catalogo italiano (`profilegenerator.IT.db3`) ha 66 template (interrogato
da `lpgdata.Households`). Ogni cella e' stata riempita con tutti i template
distinti disponibili per quella combinazione dimensione x tipo, classificati
dal **nome** del template (stessa convenzione di `lombardia20.yaml`: un nome
LPG dichiara esplicitamente eta', numero di componenti e stato occupazionale).
Esclusi: `CHR62` (casa vacanze, presenza di un mese solo, non rappresentativo
di un socio CER stabile) e `CHR52` (dimensione del nucleo non dichiarata nel
nome).

Dove una cella richiede piu' famiglie dei template distinti disponibili, i
template si ripetono con seed diversi (`_seed_stabile(label, indice)`). La
Fase 4 ([REPORT_VALIDAZIONE_LPG.md](../../REPORT_VALIDAZIONE_LPG.md), §12) ha
misurato che l'identita' dell'archetipo pesa 7,6 volte il seme: ripetere lo
stesso archetipo con semi diversi e' quindi una scelta dichiarata, non un
compromesso nascosto. Le celle piu' ripetute: "1 comp. pensionati" (17
famiglie su 4 template), "1 comp. tutti occupati" (17 su 9), "4 comp. tutti
occupati" (5 famiglie sullo stesso template, `CHR27`, nessuna alternativa nel
catalogo).

Raffrescamento: 54/100 (54,0%) contro il 55,6% ISTAT (*Dotazioni energetiche
delle famiglie 2024*, Tavola 3) — lo scarto viene dall'arrotondamento a resto
maggiore applicato cella per cella, distribuito su tutte le tipologie e non
concentrato su una, stesso tipo di residuo gia' dichiarato in `lombardia20.yaml`
per le famiglie con minori (25% contro 21,7% atteso).

Configurazione completa, con la derivazione riga per riga:
[`simulation_config.lombardia100.yaml`](../../CER_LoadProfiles/config/simulation_config.lombardia100.yaml).

## Generazione

```
cd CER_LoadProfiles
python generate_load_profiles.py --config config/simulation_config.lombardia100.yaml
```

- **100/100 famiglie generate da pyLPG**, 0 profili sintetici (nessun fallback).
- Tempo di esecuzione: 13.411 s (~3h 43min).
- Output: `outputs/csv_lombardia100/profili_tutti.csv` (101 colonne: 100 LPG +
  1 RAMP placeholder), `profili_famiglie_dettaglio.csv` (scomposizione
  elettrodomestici/casa per famiglia). Cartella non versionata (v. `.gitignore`),
  riproducibile dai seed deterministici.

## Validazione contro ARERA

```
cd lpg_db
python valida_domestici.py ../outputs/csv_lombardia100/profili_tutti.csv \
    --config ../config/simulation_config.lombardia100.yaml
```

Riferimento: ARERA, dati provinciali orari 2024-2025, Milano, Residente.

| Grandezza | Lombardia100 | Confronto |
|---|---|---|
| livello aggregato | **1,22x** (239.366 kWh contro 196.560 attesi) | lombardia20 1,15x, milano20 1,22x |
| scarto individuale (100 famiglie) | media 1,20x, mediana 1,15x, range 0,43x-2,48x | 63/100 entro 0,8x-1,3x |
| picco feriale | ore 19 | ARERA ore 20 (stesso scostamento di lombardia20/milano20) |

Fasce orarie, aggregato 100 famiglie contro ARERA:

| | F1 | F2 | F3 |
|---|---|---|---|
| LPG (100 famiglie) | 35,97% | 30,81% | 33,22% |
| ARERA classe 1,5-3 kW | 31,11% | 30,29% | 38,60% |
| ARERA classe 3-4,5 kW | 31,68% | 31,14% | 37,18% |

**Lettura**: la scala a 100 famiglie si comporta in linea con le societa' da
20 gia' validate — stesso ordine di grandezza su livello, fasce e forma
oraria, nessuna deriva introdotta dalla scala maggiore. La dispersione
individuale (range 0,43x-2,48x) e' l'effetto di numerosita' gia' misurato in
Fase 3: confrontare una singola famiglia con una curva ARERA aggregata (media
su tutta la popolazione residente) e' intrinsecamente rumoroso, non e' un
difetto nuovo introdotto da questo run.

## Limiti dichiarati

1. **Classificazione dei template per nome, non riga per riga nel database.**
   Non verificata contro `tblTemplatePerson`/`tblTemplatePersonTrait` del
   `.db3`. Stessa assunzione gia' fatta (implicitamente) in `lombardia20.yaml`.
2. **Raffrescamento al 54,0% contro il 55,6% atteso**, per arrotondamento
   cella per cella (v. sopra).
3. **Non eseguita la scomposizione TVD = a + b/sqrt(N)** di `curva_numerosita.py`
   (Fase 3-4): richiede repliche multiple con disegno sperimentale diverso da
   questo run singolo. I numeri "TVD aggregato a N" ed "eterogeneita' di forma"
   del §14 di REPORT_VALIDAZIONE_LPG.md non hanno un equivalente qui.
4. **Classe di potenza per famiglia e' un'assunzione**, non un dato: ARERA non
   pubblica il numero di clienti per classe e provincia (stesso limite
   dichiarato in `valida_domestici.py` e nel report principale).
