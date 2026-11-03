# Istruzioni: analisi completa delle repliche (aggiornate al 3 novembre 2026)

Il run è finito e la lettura unita 5-25 è stata fatta il 3 novembre (PR #71, in `main`). Questo
branch (`ccr-13867105-vwc5b6`) parte da `main` e aggiunge l'analisi completa:
- robustezza di ogni conclusione (k/20, Clopper-Pearson, controllo a metà, bootstrap);
- intervalli delle mediane;
- VAN per metodo, soglia regolatoria, quote ai prosumer;
- figure G01-G13 e F01-F13 con la palette Polimi;
- tabelle LaTeX e `numeri_tesi.tex`.

Tutti i comandi vanno dati in **Git Bash, dalla cartella del progetto, sul PC del run**. Solo lì ci
sono le tabelle di MAIN2 della lettura unita (`outputs/repliche/unito/rNN/tables/`). Il comando ne
copia la parte necessaria in `rNN/tabelle/` (circa 4 MB a replica): una volta committata,
l'analisi si rifà su qualunque PC.

Tempo: circa 10 minuti, senza MATLAB.

---

## 1. Passare al branch

```bash
git status                          # meglio partire senza modifiche in sospeso
git fetch origin
git checkout ccr-13867105-vwc5b6
git merge origin/main               # porta eventuali commit fatti su main nel frattempo
```

## 2. Lanciare l'analisi

```bash
bash CER_repliche/analisi_finale.sh
```

Passi, ciascuno con il suo esito a schermo:

| Passo | Cosa fa |
|---|---|
| 1 | Lettura unita in MATLAB: si salta da sé, è già fatta per tutte le 21 repliche |
| 2 | Copia delle tabelle per l'analisi in `rNN/tabelle/` |
| 3 | Controlli: 295 comunità, 10 metodi, stabilità a tutte le taglie |
| 4 | Aggregato e robustezza in `outputs/repliche/unito/aggregato/` |
| 5-6 | Figure in `outputs/tesi_finale/figure/` e `figure_descrittive/` |
| 7 | Numeri e tabelle LaTeX in `outputs/tesi_finale/` |
| 8 | Rapporto commentato `outputs/report/RISULTATI_repliche_<data>.html` |

Se un passo fallisce, il comando si ferma e stampa le ultime righe di
`outputs/tesi_finale/analisi_finale.log`: mandami quel file.

## 3. Controllare i risultati

1. **`outputs/repliche/unito/aggregato/sintesi.md`.** Tutti i numeri in chiaro. In cima c'è "Il
   numero di repliche basta?": quante conclusioni reggono (almeno 15/20) e su quante le due metà
   concordano, il numero che va nella 6.1.
2. **`outputs/tesi_finale/rapporto.html`** (doppio clic):
   - in cima **non** deve esserci il riquadro rosso "Controlli di integrità falliti";
   - la tabella delle conclusioni del 28 ottobre dice quali restano vere.
3. **`outputs/report/RISULTATI_repliche_<data>.html`:** il rapporto commentato di `main`, rifatto
   sull'aggregato nuovo.

## 4. Salvare nel repository

```bash
git add outputs/repliche/unito outputs/tesi_finale outputs/report
git status --short | head -40       # controllo: niente .mat, niente tables/ ne' insieme/
git commit -m "Analisi completa delle repliche: robustezza, VAN, soglia, figure e numeri della tesi"
git push -u origin ccr-13867105-vwc5b6
```

Peso atteso: circa 110 MB (`tabelle/` circa 80 MB, `tesi_finale/` circa 25 MB, aggregato pochi MB).

## 5. Cosa dare alla chat che scrive la tesi

| Serve per | File |
|---|---|
| 6.1.4, robustezza (k/20, IC, metà, bootstrap) | `outputs/repliche/unito/aggregato/robustezza.csv`, `outputs/tesi_finale/tabelle/robustness.tex`, sezione "Il numero di repliche basta?" di `sintesi.md` |
| Mediane con intervallo | colonne `ic95_basso`, `ic95_alto` di `tau.csv`, `perdite.csv`, `inversioni.csv` |
| VAN (analisi complementare) | `aggregato/van.csv`, `tabelle/npv.tex`, figura `G10_npv.pdf` |
| Soglia regolatoria (6.6) | `aggregato/soglia.csv`, `tabelle/regulatory_threshold.tex`, `G09_threshold.pdf` |
| Numeri nel testo | `outputs/tesi_finale/numeri_tesi.tex` (macro LaTeX) |

**Indicatori:** il confronto usa gli otto di `stile_tesi.INDICATORI`. L'equality index (= 1 − Gini)
non è un indicatore a parte. L'inclusione LIHC è esclusa: si calcola solo a 25 membri in 8
repliche su 20, con parametri provvisori, e va citata solo fra i limiti.

## 6. Portare i risultati nella tesi (repository `Tesi-Magistrale`)

- **Figure.** Copia i PDF che usi da `outputs/tesi_finale/figure/` e `figure_descrittive/` in
  `Images/CAP6/`.
- **Numeri.** Copia `numeri_tesi.tex` nella tesi, aggiungi `\input{numeri_tesi}` nel preambolo e
  usa le macro (per esempio `\NumReplicas{}`, `\ReversalGiniISCount{}`).
- **Tabelle.** `outputs/tesi_finale/tabelle/*.tex` contengono solo il `tabular` e richiedono
  `\usepackage{booktabs}`:
  ```latex
  \begin{table}[htbp]\centering
  \caption{...}\label{tab:robustness}
  \input{Tables/robustness.tex}
  \end{table}
  ```

## 7. Aggiornare i README

Apri una sessione di Claude Code su questo branch e incolla il testo qui sotto.

```
Ho lanciato CER_repliche/analisi_finale.sh e committato i risultati. Aggiorna README.md (riquadro
di stato e §7.11.6), CER_repliche/README.md e docs/analisi_finale/PIANO_analisi_finale.md (sezione 7)
con i numeri di outputs/repliche/unito/aggregato/sintesi.md, robustezza.csv, van.csv e soglia.csv:
cosa regge, cosa dipende dai partecipanti, cosa non è confermato. Solo numeri presi dai file, in
italiano. Poi commit e push.
```

## 8. Chiudere i branch

`70-results-analysis` è già in `main` (PR #71). Resta da unire questo branch.

1. **Su GitHub:** apri una pull request da `ccr-13867105-vwc5b6` verso `main` e fai il merge, oppure
   chiedi a Claude di aprirla.
2. **Controlla che entrambi i branch siano in `main`:**
   ```bash
   git fetch origin
   git branch -r --merged origin/main | grep -E "70-results-analysis|ccr-13867105"   # devono comparire entrambi
   ```
3. **Cancella i branch:**
   ```bash
   git checkout main && git pull
   git push origin --delete 70-results-analysis ccr-13867105-vwc5b6
   git branch -d 70-results-analysis ccr-13867105-vwc5b6
   ```
   Se `git branch -d` protesta, qualcosa non è in `main`: fermati e controlla.
