# Workspace dei run finali (13 ottobre 2026)

Servono a riprendere il lavoro **senza rilanciare MAIN2**: i due run finali costano circa
3 ore. Codice al commit `b6f18a5` (branch `62-test-2`). Dati LIHC ancora a segnaposto
(README §7.7): quando si compilano P50, y* e markup questi workspace diventano superati e i
due run vanno rifatti.

Cartella **non versionata** (i `.mat` sono binari da 10-14 MB): vive solo su questa macchina.

## Cosa c'è

| File | Contenuto |
|---|---|
| `run_2026-10-13_fino18.mat` | workspace del run fino a 18 membri (20 comunità, 11 metodi). Tabelle in `outputs/tables_main2/` |
| `run_2026-10-13_griglia25.mat` | workspace del run fino a 25 membri (28 comunità, 10 metodi). Tabelle in `outputs/tables_main2_griglia25/`. Senza `SENS`: la sensibilità è stata calcolata dopo, vedi README §7.9 |
| `export_fino18/`, `export_griglia25/` | gli stessi dati in CSV lunghi, leggibili senza MATLAB |
| `analisi_fino18.txt`, `analisi_griglia25.txt` | l'analisi in 13 blocchi (comunità, Shapley vs AS, vincitori, τ, raggruppamento, perdite, somiglianza fra metodi, quote ai prosumer, forza incentivante, stabilità, VAN, inversioni, medie per metodo) |
| `strumenti/` | gli script che li hanno prodotti, più quelli di confronto usati nei controlli di regressione |

Variabili nei `.mat`: `RESULTS`, `AGR`, `GRID`, `REV`, `SINT`, `F1`, `PERD`, `CLUS` (e `SENS`
nel run fino a 18). Sono le stesse che MAIN2 ha in memoria a fine esecuzione.

I log dei run, con l'elenco esatto delle schede, sono in `outputs/run_logs/`
(`main2_run_2026-10-13_F6_fino18.log` e `main2_run_2026-10-13_F6_griglia25.log`).

## Come si riprende

In MATLAB, dalla root del progetto:

```matlab
addpath(pwd); addpath('outputs/workspace/strumenti');
load('outputs/workspace/run_2026-10-13_fino18.mat');     % RESULTS, AGR, ... in memoria
% per esempio: rifare la sintesi o le perdite senza rilanciare i metodi
S = sintesi_risultati(RESULTS, AGR, struct('escludiMetodi', strings(0,1)));
P = tradeoff_losses(AGR, RESULTS);
```

Rigenerare i CSV lunghi o l'analisi:

```matlab
esporta_run('outputs/workspace/run_2026-10-13_fino18.mat', 'outputs/workspace/export_fino18')
```

```bash
venv/Scripts/python.exe -I outputs/workspace/strumenti/analizza.py \
    outputs/workspace/export_fino18 outputs/tables_main2 > outputs/workspace/analisi_fino18.txt
```

Figure per la tesi e numeri che le accompagnano (tabelle del 20 ottobre per tutti i livelli PA,
export per i valori grezzi del livello 0):

```bash
python -I outputs/workspace/strumenti/grafici_metodi.py --apri  # -> outputs/figures_tesi/, outputs/tables_tesi/
```

Alla fine scrive `outputs/figures_tesi/index.html`: tutte le figure con spiegazione e risultato, in un file
unico da aprire con un doppio clic o da inviare (`--apri` lo apre nel browser). Si rigenera da solo con
`pagina_risultati.py`, anche senza rifare le figure.

Analisi e scelte statistiche in `outputs/report/ANALISI_risultati_e_figure_2026-10-27.md`.
`esporta_run.m` scrive dal 27 ottobre la colonna `Composizione` e legge i punteggi da `LIV`:
gli export dei workspace con PA fatti prima di quella data mescolerebbero i livelli.

**Attenzione:** `run('script.m')` cambia cartella corrente, e i percorsi relativi finiscono
altrove. Usare `addpath` e chiamare le funzioni, come sopra.

## Controllo di regressione (dopo una modifica al codice)

1. copiare `outputs/tables_main2/` come baseline (o `git archive HEAD outputs/tables_main2`);
2. rilanciare il run fino a 18 salvando il workspace;
3. confronto per chiave delle tabelle:
   `python -I strumenti/confronta_csv.py <baseline> outputs/tables_main2 <token autorizzati>`;
4. confronto delle strutture in MATLAB, sul modello di `strumenti/confronta_F*.m`
   (cambiare i percorsi dei `.mat`).

## Run del 26-27 ottobre 2026: blocco 15-18 membri con le imprese

| File | Contenuto |
|---|---|
| `run_2026-10-27_fino18_IND.mat` | `RESULTS` delle 168 comunità (76 senza imprese, 92 con imprese), copia del checkpoint `outputs/checkpoint_main2_fino18_IND.mat`. Tabelle in `outputs/tables_main2_fino18_IND/` (versionate), log in `outputs/run_logs/main2_run_2026-10-27_fino18_IND.log` |

Questo `.mat` contiene **solo `RESULTS`**: le strutture di analisi fra comunità (`AGR`, `GRID`, `REV`,
`SINT`, `PERD`, `CLUS`, `LIV`) vivevano nella sessione MATLAB batch e non sono state salvate. I loro
risultati sono comunque nelle tabelle CSV. Per i blocchi successivi conviene lanciare
`MAIN2_IND=1 ... matlab -batch "MAIN2; save('outputs/workspace/<nome>.mat','RESULTS','LIV')"`.
Codice al commit di fase B (`a770725`) più le modifiche al README.

## Run del 27 ottobre 2026: blocco 20-25 membri con le imprese (interrotto, completato il 28 ottobre)

| File | Contenuto |
|---|---|
| `run_2026-10-27_solo2025_IND_interrotto45.mat` | `RESULTS` delle prime 45 comunità su 127 (copia del checkpoint `outputs/checkpoint_main2_solo2025_IND.mat`). Run fermato dal Variance Least Core a 25 membri su `ND1_PA1/CER_18_7_0`. Log in `outputs/run_logs/main2_run_2026-10-27_solo2025_IND_interrotto.log` |

Solo `RESULTS`, nessuna tabella. Dettagli e prossimi passi in README §7.11.2.

## Run del 28 ottobre 2026: blocco 20-25 membri completato e analisi unita fino a 25 membri

Codice del branch `speedup-vlc-shapley` (PR #69): separazione del VLC per enumerazione fino a 25
membri, Shapley vettorizzato, `maxIter` 1000 (README §7.11.3).

| File | Contenuto |
|---|---|
| `run_2026-10-28_solo2025_IND_speedup.mat` | `RESULTS` delle 127 comunità da 20 e 25 membri (livelli PA0-PA3, ND1-ND3, ND{k}_PA{p}). Le prime 45 sono il rifacimento del run interrotto del 27 ottobre, uguali entro 3,5e-11. Tabelle in `outputs/tables_main2_solo2025_IND_speedup/` |
| `run_2026-10-28_fino25_unito.mat` | `RESULTS` delle 295 comunità da 5 a 25 membri: le 168 di `run_2026-10-27_fino18_IND.mat` più le 127 sopra, nell'ordine di `elenco_schede_cer.m`. Riletto da `MAIN2.m` con `MAIN2_RIPRENDI=1` per l'analisi tra comunità: `outputs/tables_main2_fino25_unito/` |

Solo `RESULTS` (niente `AGR` né `LIV`, quindi `esporta_run.m` non si può usare): i valori grezzi
(F01, F04/F05, F07, F08, F13 di `grafici_metodi.py`) per queste comunità non sono disponibili. Le figure
si rigenerano con:

```
python -I outputs/workspace/strumenti/grafici_metodi.py --tabelle outputs/tables_main2_fino25_unito \
    --out outputs/figures_tesi_fino25_unito --numeri outputs/tables_tesi_fino25_unito --senza-pagina
python -I outputs/workspace/strumenti/pagina_figure.py --figure outputs/figures_tesi_fino25_unito \
    --numeri outputs/tables_tesi_fino25_unito
```

`pagina_figure.py` fa una pagina senza testo interpretativo (`pagina_risultati.py` ha frasi scritte per
i dati del 20 ottobre e pretende tutte le figure).

## Workspace completo del run unito e rapporto finale (28 ottobre 2026, sera)

| File | Contenuto |
|---|---|
| `run_2026-10-28_fino25_unito_completo.mat` | lo stesso `RESULTS` di `run_2026-10-28_fino25_unito.mat` più `AGR`, `LIV`, `GRID`, `REV`, `SINT`, `F1`, `PERD`, `CLUS`, `SENS`. Ottenuto rileggendo il checkpoint con `MAIN2_RIPRENDI=1`: si rifà solo l'analisi fra comunità (30 s), e le tabelle di `tables_main2_fino25_unito/` escono identiche al byte |
| `export_fino25_unito/` | i CSV lunghi delle 295 comunità, con la colonna `Composizione` (16 livelli). Versionato |
| `strumenti/esporta_run_livelli.m` | chiama `esporta_run.m` e corregge le etichette dei livelli con imprese in `punteggi_orientati.csv` (`esporta_run.m` scrive `"PA" + codice`, cioè `PA10` invece di `ND1`) |
| `strumenti/rapporto_conclusioni.py` | scrive `outputs/report/RISULTATI_e_conclusioni_RQ_2026-10-28.html`: le figure commentate e le conclusioni rispetto alla domanda di ricerca. I numeri vengono dai CSV, e lo script si ferma se un'affermazione del testo non è più sostenuta dai dati. Produce anche F14 (soglia regolatoria) |

Per i workspace dei run futuri con le imprese conviene usare `esporta_run_livelli.m` al posto di
`esporta_run.m`. I comandi completi, nell'ordine, sono nella §15 del rapporto e nella §7.11.5 del README. I log dei run sono in `outputs/run_logs/`
(`main2_run_2026-10-28_*`, `main2_run_2026-10-27_confronto_speedup_*`, `test_speedup_vlc_shapley_*`).
