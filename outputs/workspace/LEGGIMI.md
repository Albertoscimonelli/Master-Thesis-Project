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
