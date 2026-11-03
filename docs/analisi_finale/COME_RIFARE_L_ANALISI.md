# Come rifare l'analisi completa e dove trovare i risultati (3 novembre 2026)

Simulazioni e analisi sono finite. I risultati della tesi sono le repliche dei partecipanti r01-r20
(README §7.13). Questo documento dice come rifare l'analisi e cosa usare per scrivere la tesi.

## Rifare l'analisi

Da Git Bash, nella cartella del progetto, su **qualunque PC** con Python (pandas, matplotlib,
Pillow):

```bash
bash CER_repliche/analisi_finale.sh
```

- **Tempo:** circa 10 minuti, senza MATLAB.
- **Da dove legge:** la lettura unita è già fatta. Le tabelle di MAIN2 che servono sono versionate
  in `outputs/repliche/unito/rNN/tabelle/`, gli export in `rNN/export/`.
- **Se mancasse la lettura unita** di qualche replica, lo script la rifà in MATLAB con
  `CER_repliche/unisci_repliche.sh`. Serve il PC con i checkpoint, che sono comunque versionati.
- **Se un passo fallisce,** lo script si ferma e stampa le ultime righe di
  `outputs/tesi_finale/analisi_finale.log`.

Passi:

| Passo | Cosa fa |
|---|---|
| 1 | Lettura unita in MATLAB, solo dove manca (oggi si salta) |
| 2 | Copia delle tabelle per l'analisi in `rNN/tabelle/` (se ci sono le `tables/` complete) |
| 3 | Controlli: 295 comunità, 10 metodi, stabilità a tutte le taglie |
| 4 | Aggregato e robustezza in `outputs/repliche/unito/aggregato/` |
| 5-6 | Figure in `outputs/tesi_finale/figure/` (G01-G13) e `figure_descrittive/` (F01-F13) |
| 7 | Numeri e tabelle LaTeX in `outputs/tesi_finale/` |
| 8 | Rapporto commentato `outputs/report/RISULTATI_repliche_<data>.html` |

Il 3 novembre la stessa analisi rifatta da un altro PC, dai soli file versionati, ha dato lo stesso
testo del rapporto e le stesse tabelle, a meno di 1e-16.

## Cosa usare per la tesi

| Serve per | File |
|---|---|
| 6.1, robustezza (k/20, IC, metà, bootstrap) | `outputs/repliche/unito/aggregato/robustezza.csv`, `outputs/tesi_finale/tabelle/robustness.tex`, sezione "Il numero di repliche basta?" di `sintesi.md` |
| Mediane con intervallo | colonne `ic95_basso` e `ic95_alto` di `tau.csv`, `perdite.csv` e `inversioni.csv` |
| Conclusioni chiave | `outputs/tesi_finale/conclusioni.csv` |
| VAN (analisi complementare) | `aggregato/van.csv`, `tabelle/npv.tex`, figura `G10_npv.pdf` |
| Soglia regolatoria (6.6) | `aggregato/soglia.csv`, `tabelle/regulatory_threshold.tex`, `G09_threshold.pdf` |
| Numeri nel testo | `outputs/tesi_finale/numeri_tesi.tex` (macro LaTeX) |
| Commento ai risultati | `outputs/report/RISULTATI_repliche_2026-11-03.html` |

**Indicatori.** Il confronto usa gli otto di README §7.9. L'equality index (= 1 − Gini) non è un
indicatore a parte. L'inclusione LIHC è esclusa: si calcola solo a 25 membri in 8 repliche su 20.

**r00.** Non entra in nessun numero: è il controllo del generatore delle repliche.

## Portare figure, numeri e tabelle nella tesi (repository `Tesi-Magistrale`)

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

## Gli altri documenti di questa cartella

- `PIANO_analisi_finale.md`: il piano con cui è stata decisa l'analisi (versione B senza Nucleolo,
  criterio 15/20, palette). È eseguito; la sezione 7 ne riporta lo stato e i risultati.
- `PROMPT_capitolo_6_1.md`: il prompt per riscrivere la Sezione 6.1 della tesi.
- `anteprima_palette.png` e `anteprima_palette.py`: l'anteprima dei colori.
