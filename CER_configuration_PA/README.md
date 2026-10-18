# Asse "composizione": presenza di PA nella CER

Oltre alla **taglia** (numero di membri) e alla **penetrazione** (quota di prosumer), questa
cartella aggiunge un terzo asse alla griglia: la **composizione**, cioè quante e quali
pubbliche amministrazioni (PA) ci sono dentro la comunità.

`MAIN2.m` legge questa cartella dal 18 ottobre 2026: `elenco_schede_cer.m` prende le schede di
`CER_configuration/` (livello 0) e quelle di `PA1/`, `PA2/`, `PA3/`, fino a `MAIN2_MAX_UTENTI`
membri (default 18). `PA0/` **non si legge**: è una copia di `CER_configuration/` (stessi dati,
solo i percorsi cambiano). Il confronto con / senza PA è `confronto_pa.m` (README §7.10).

## Struttura

| Cartella | Contenuto | Schede |
|---|---|---|
| `PA0/` | le schede di `CER_configuration/`, solo domestici (copia con i percorsi adattati) | 40 |
| `PA1/` | 1 PA: comune | 40 |
| `PA2/` | 2 PA: comune + scuola | 39 |
| `PA3/` | 3 PA: comune + scuola + palazzetto | 37 |
| `profili/PAk/` | i CSV dei profili di carico di ogni variante (uno per scheda) | — |
| `genera_varianti_PA.py` | genera tutto quanto sopra a partire da `CER_configuration/` | — |

Le schede hanno lo stesso nome della scheda di partenza (`CER_C_P_E.txt`), una per cartella.

## La regola

Per ogni scheda `CER_C_P_E` restano **uguali** il numero di membri N, i consumatori C e i
prosumer P, quindi la penetrazione. Ogni PA è un **prosumer con il proprio impianto**; per ogni
PA che entra **esce un prosumer domestico**, l'ultimo per id, con il suo impianto. I domestici
rimasti non cambiano (stessi profili, reddito, spesa gas). Cambia solo chi sono i prosumer.

Le varianti non si fanno se i prosumer della scheda sono meno delle PA da inserire: sono saltate
`CER_4_1_0` per PA2 e PA3, `CER_3_2_0` e `CER_6_2_0` per PA3. Per questo PA2 ha 39 schede e PA3 37.

## Le tre PA

| PA | Carico | FV | kWp |
|---|---|---|---|
| comune | RAMP, colonna `comune_1` di `csv_nd20` (13.274 kWh/anno) | `PROVA_CER_1_Project_municipio.CSV` (69.500 kWh/anno) | 47 |
| scuola | RAMP, colonna `scuola_superiore_1` (107.103 kWh/anno) | `PROVA_CER_1_Project_scuola.CSV` (49.374 kWh/anno) | 35 |
| palazzetto | ricostruzione Lucca, [`palazzetto_lucca_carico.csv`](../data/external/palazzetto_lucca/) (289.706 kWh/anno) | `palazzetto_lucca_FV.CSV` (copia in `PV_Generation/`, 398.112 kWh/anno) | 310,5 |

Altre assunzioni, scritte anche nell'intestazione di ogni scheda: tariffa BIORARIA (come `office`);
potenza impegnata dal picco del profilo arrotondato a 5 kW (palazzetto: 448 kW, POD in MT della
diagnosi); costo impianto 730 €/kWp, cioè (180+270)×1,40+(50+50) dai parametri di
`scenario_economico.txt`; categoria `PA`, esente dal fattore F.

## Verifiche

Tutte le 156 schede (40+40+39+37) sono state lette con `load_cer_input`, `load_cer_data` e
`align_members_to_users` in MATLAB R2024b, senza errori (gli avvisi non sono stati registrati). N, numero di
prosumer e numero di PA tornano a ogni livello. **`MAIN2.m` è stato eseguito il 18 ottobre su
`CER_2_3_0` e `CER_5_5_0` nei livelli 1-3** (prova, non i risultati finali): nessun errore sui
membri PA, tariffa identica fra i livelli (scaglione unico imposto in `scenario_economico.txt`,
perché il palazzetto da 310,5 kWp altrimenti cadrebbe in un altro scaglione). Un caso ha rivelato
uno stallo del solver del Variance Least Core, ora gestito (README §7.10, avvertenza 4).

## Punti aperti

1. **kWp** dichiarati dall'utente il 17/10/2026: comune 47, scuola 35, palazzetto 310,5. Se cambiano
   la scheda va rigenerata (cambiano capex e quota di investimento).
2. **Comune: FV molto grande rispetto al carico.** L'impianto produce circa 69.500 kWh/anno e il
   comune ne consuma circa 13.300: il FV è 5,2 volte il carico. Controllare se il profilo comune o
   l'impianto sono sovradimensionati.
3. **Palazzetto: FV maggiore del carico** (398.112 contro 289.706 kWh/anno, 1,37 volte).
4. **File FV del comune** (risolto il 17/10/2026): `PROVA_CER_1_Project_municipio.CSV` aveva due
   colonne di dati (`EArray;E_Grid`) e il loader legge la seconda posizione. Ora ha la sola colonna
   `E_Grid` (69.500 kWh/anno, picco 40,0 kW); il primo valore è −0,001 e il loader lo azzera.
5. **Profili non versionati.** I CSV in `profili/` pesano circa 212 MB e sono esclusi da git
   (`profili/.gitignore`): si rigenerano con `python -I CER_configuration_PA/genera_varianti_PA.py`
   dalla radice del progetto.
6. **Rimozione dei prosumer.** Si toglie l'ultimo per id. Se la scelta pesa sui risultati (le
   famiglie hanno archetipi diversi), va cambiata nello script.
7. **FV non versionati.** `PV_Generation/` è escluso da git per scelta del progetto (`.gitignore`:
   restano tracciati solo `PV1`, `PV2` e `PV4`), quindi nemmeno `palazzetto_lucca_FV.CSV` lo è. In un
   clone pulito vanno copiati a mano: il palazzetto da
   `data/external/palazzetto_lucca/palazzetto_lucca_FV.CSV` (tracciato), comune e scuola dagli
   export `PROVA_CER_1_Project_*.CSV` locali.
