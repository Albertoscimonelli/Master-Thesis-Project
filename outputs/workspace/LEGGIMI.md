# outputs/workspace: strumenti dell'analisi ed export dei run superati

**Aggiornato al 3 novembre 2026.** I risultati della tesi non stanno qui. Stanno nelle repliche
dei partecipanti:
- numeri: `outputs/repliche/unito/aggregato/sintesi.md` e i CSV accanto;
- per la tesi: `outputs/tesi_finale/` (figure, tabelle LaTeX, `numeri_tesi.tex`);
- rapporto commentato: `outputs/report/RISULTATI_repliche_2026-11-03.html`.

Si rifanno con `bash CER_repliche/analisi_finale.sh` (README §7.13). Questa cartella contiene due
cose: gli strumenti che quell'analisi usa, e gli export dei run del 13-28 ottobre, che sono
superati (README §7.14).

## Strumenti usati dall'analisi finale (`strumenti/`)

| File | A cosa serve |
|---|---|
| `esporta_run.m`, `esporta_run_livelli.m` | Da un workspace di MAIN2 ai 5 CSV lunghi di `export/` (comunità, indicatori, punteggi orientati, quote, virtuosità). `esporta_run_livelli.m` corregge le etichette dei livelli con imprese; lo chiamano `lancia_repliche.sh` e `unisci_repliche.sh` |
| `unisci_shapley_as.m` | La regola di un solo Shapley nella lettura unita: dove manca lo Shapley esatto (20-25 membri) l'Adaptive Sampling prende il suo nome. La chiama `CER_repliche/unisci_blocchi.m` |
| `grafici_metodi.py` | Le figure descrittive F01-F13. `analisi_finale.sh` le produce su tutte le repliche insieme (`CER_repliche/unisci_per_figure.py`), con la palette Polimi di `CER_repliche/stile_tesi.py` |
| `confronta_csv.py`, `confronta_F*.m` | Confronto per chiave fra due cartelle di tabelle e fra strutture MATLAB: i controlli di regressione |

## Controllo di regressione (dopo una modifica al codice)

1. Prendere come baseline le tabelle di una replica (`outputs/repliche/<blocco>/rNN/tables/`, sul PC
   del run) oppure una cartella `tables_main2_*` versionata.
2. Rilanciare MAIN2 sulle stesse schede, con un suffisso (`MAIN2_CARTELLA=prova`).
3. Confrontare per chiave:
   `python -I outputs/workspace/strumenti/confronta_csv.py <baseline> outputs/tables_main2_prova <token autorizzati>`.
4. Per le strutture MATLAB, usare il modello di `strumenti/confronta_F*.m`, cambiando i percorsi dei
   `.mat`.

La pipeline è deterministica: senza modifiche le tabelle escono identiche al byte.

**Attenzione:** `run('script.m')` cambia la cartella corrente, e i percorsi relativi finiscono
altrove. Usare `addpath` e chiamare le funzioni.

## Run superati: solo storico

Hanno, fino a 25 membri, famiglie che sono tutte persone sole (README §7.12): non vanno citati.

| File | Run |
|---|---|
| `export_fino18/`, `export_griglia25/`, `analisi_fino18.txt`, `analisi_griglia25.txt` | 13 ottobre: solo famiglie, fino a 18 e fino a 25 membri |
| `export_fino25_unito/` | 28 ottobre: 295 comunità con PA e imprese, lettura unita del disegno originale |
| `run_2026-10-*.mat` (non versionati, solo sul PC del run) | i workspace dei run del 13-28 ottobre |

Gli altri script di `strumenti/` (`analizza.py`, `rapporto_conclusioni.py`, `pagina_figure.py`,
`pagina_risultati.py`, `dati_interfaccia.py`) hanno prodotto i rapporti di quei run (in
`outputs/report/`, file del 13-28 ottobre). Restano per tracciabilità e non servono all'analisi
finale.
