# Asse "non domestici": presenza di imprese (ND) nella CER

Dopo l'asse **PA** (`CER_configuration_PA/`), questa cartella aggiunge le **imprese**: utenti non
domestici privati, con consumi reali (tre) o RAMP (due) e impianto FV proprio. Le schede si
generano con `genera_varianti_IND.py` e **non sono ancora lette da `MAIN2.m`** (serve estendere
`elenco_schede_cer.m`, da concordare): nessun run è stato lanciato.

## Livelli

Per ogni scheda di `CER_configuration/` con **N ≥ 15** (i ND si inseriscono da 15 membri):

| Cartella | Contenuto |
|---|---|
| `ND1`, `ND3`, `ND5` | D + k imprese (k = 1, 3, 5) |
| `ND{k}_PA{p}` | D + k imprese + p PA (p = 1, 2, 3): 9 cartelle |
| `profili/<livello>/` | i CSV dei profili di carico, uno per scheda |

D e D+PA esistono già (`CER_configuration/`, `CER_configuration_PA/PA1..PA3`).

## La regola

Come per le PA: N, C e P restano quelli della scheda; ogni ND e ogni PA è un **prosumer con il
proprio impianto**; per ognuno che entra esce l'ultimo prosumer domestico (per id), con il suo
impianto. Due vincoli, entrambi verificati con `assert` nello script:

1. **La quota dei non domestici resta sotto il 50% di N**: ND + PA ≤ ⌈N/2⌉ − 1 (7 a N = 15,
   8 a N = 18, 9 a N = 20, 12 a N = 25, …). Ogni scheda riporta la quota in intestazione.
2. **Prosumer domestici sufficienti**: ND + PA ≤ P. Non si fa una variante se i prosumer sono meno.

## Le cinque imprese (ordine di ingresso)

| # | Impresa | Categoria | Carico | FV | kWp (stima) | P_prel_kW | Tariffa |
|---|---|---|---|---|---|---|---|
| 1 | antigelo | industriale | reale 2024, 15.720 kWh | `PROVA_CER_1_Project_antigelo.CSV` | 33 | 15 | ORARIO_VARIABILE |
| 2 | office_zummo | terziario | reale 2024, 52.759 kWh | `..._office_zummo.CSV` | 129 | 35 | BIORARIA |
| 3 | small_industry | industriale | RAMP (`csv_scheda9`), 61.692 kWh | `..._small_industry.CSV` | 69 | 50 | ORARIO_VARIABILE |
| 4 | plastica | industriale | reale 2024, 2.012.615 kWh | `..._plastic_industry.CSV` | 250 | 535 | ORARIO_VARIABILE |
| 5 | office | terziario | RAMP (`csv_scheda9`), 4.781 kWh | `..._office.CSV` | 17,5 | 10 | BIORARIA |

Il **retail** (RAMP, senza FV) non è usato per ora. Le PA sono quelle di
[`CER_configuration_PA/README.md`](../CER_configuration_PA/README.md).

## Come sono costruiti i dati

- **Carichi reali** (antigelo, office_zummo, plastica): `CER_LoadProfiles/outputs/Valencia/`, 2024.
  Il 2024 è bisestile e parte di lunedì, la griglia è il 2025 (mercoledì). Ogni giorno del 2025
  prende il giorno 2024 con lo **stesso giorno della settimana** più vicino (0-6 giorni dopo,
  altrimenti 7 giorni prima): il 29/02 non è un giorno della griglia, i feriali restano feriali.
  Per questo l'energia annua differisce di poco dal file originale (antigelo 15.769 → 15.720,
  plastica 2.011.023 → 2.012.615 kWh).
- **Carichi RAMP**: colonne `small_industry_1_kWh` e `office_1_kWh` di `csv_scheda9/profili_tutti.csv`.
- **Categoria**: antigelo, small_industry e plastica → `industriale`; office_zummo e office →
  `terziario`. Nessuna è esente dal fattore F (come per i dati di `cer_reduction_factor.m`).
- **Costo impianto**: 730 €/kWp, come le PA (parametri di `scenario_economico.txt`).

## Punti aperti (da confermare)

1. **kWp stimati.** I file PVsyst non riportano la potenza: 33, 129, 250, 69, 17,5 sono
   produzione annua / 1480 kWh/kWp. Se cambiano vanno rigenerate le schede (cambiano capex e quota).
2. **Potenza impegnata.** Per antigelo, zummo e plastica è il picco del profilo arrotondato a
   5 kW (535 kW per plastica): la potenza contrattuale non è nota.
3. **Luogo.** Consumi di Valencia, FV simulato su Milano (Duomo, TMY PVGIS): incoerenza dichiarata.
4. **Plastica domina.** 2 GWh/anno e picco 535 kW: circa 40 volte i consumi di una CER domestica da
   18 membri. Il suo FV (250 kWp) copre il ~18% del carico: quasi tutto è autoconsumato.
5. **FV sovradimensionato** per office (5,3× il carico), antigelo (3,1×), office_zummo (3,6×): la
   produzione va quasi tutta in immissione, come per il comune.
6. **Scaglione TIP.** Plastica (~250 kWp) e zummo (~129 kWp) superano i 100 kW dello scaglione
   unico imposto in `scenario_economico.txt`: la tariffa è approssimata come per il palazzetto.
7. **Tariffe** assunte (non note per le imprese reali).
8. **Dati reali.** I consumi di antigelo, zummo e plastica sono di aziende reali: i file sono
   fuori da git (`Valencia/` non tracciata; schede e profili ignorati da `.gitignore`).
9. **Prosumer rimossi:** l'ultimo per id; se pesa sui risultati va cambiato nello script.
10. **Profili non versionati:** ~750 MB in `profili/`, si rigenerano con
    `python -I CER_configuration_IND/genera_varianti_IND.py` dalla radice (~1 minuto).

## Numeri (28 schede con N ≥ 15)

| Fascia | Schede sorgente | Varianti |
|---|---|---|
| N = 15, 18 | `0_15_0` `4_11_0` `7_8_0` `11_4_0` `0_18_0` `4_14_0` `9_9_0` `13_5_0` | 83 |
| N = 20, 25 | `0_20_0` `5_15_0` `10_10_0` `15_5_0` `0_25_0` `6_19_0` `12_13_0` `18_7_0` | 91 |
| N = 50, 75, 100 | 12 schede | 144 |
| **Totale** | | **318** (18 combinazioni scartate per i due vincoli) |

Ordine di esecuzione previsto per i run: (1) N < 15, già eseguito il 20 ottobre; (2) N = 15 e 18;
(3) N = 20 e 25; (4) N = 50-100. Un salvataggio (checkpoint, workspace, README, commit) a fine blocco.
Oltre 18 membri `MAIN2` salta Shapley, Nucleolo ed eccesso di coalizione (2^n); oltre 25 il Variance
Least Core non converge (tetto imposto dopo un run fallito, da riprovare per il blocco 4).

## Verifiche (23-25 ottobre 2026)

Tutte le **318 schede** sono state lette con `load_cer_input`, `load_cer_data` e
`align_members_to_users` in MATLAB (13 minuti): 0 errori, carichi e FV finiti e non negativi,
quota dei non domestici sempre sotto il 50% (massimo 46,7%). N, numero di prosumer e potenza
installata tornano a ogni livello. **`MAIN2.m` non è stato eseguito su nessuna di esse.**

**Quota in energia dei non domestici sul carico totale** (mediana per livello, schede da 15-18 / 20-25 membri):

| Livello | 15-18 membri | 20-25 membri |
|---|---|---|
| ND1 (antigelo) | 37% | 30% |
| ND3 (+ zummo, small_industry) | 85% | 80% |
| ND5 (+ plastica, office) | 99% | 99% |
| ND5 + PA3 | 99% | 99% |

La regola "sotto il 50%" vale sul **numero di membri**, non sull'energia: già da ND3 le imprese
consumano più dell'80% dell'energia della CER, e con plastica (ND5) circa il 99%. I livelli alti
sono quindi comunità industriali con contorno domestico. Da tenere presente nella lettura dei
risultati (punto aperto 4).
