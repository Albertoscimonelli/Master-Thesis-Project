# Istruzioni: dalla fine del run alla chiusura del branch

Tutti i comandi vanno dati in **Git Bash, dalla cartella del progetto**, sul PC del run. Lo stesso
contenuto, più breve, è in `CER_repliche/README.md` (sezione "Analisi finale").

Tempi indicativi: lettura unita circa 1 ora (21 repliche × 2-3 min), parte Python circa 10 minuti.

---

## 1. Controllare che il run sia finito

```bash
tail -5 outputs/repliche/da20a25/avanzamento.txt
for i in $(seq -w 0 20); do grep -q "r$i fatta in" outputs/repliche/da20a25/avanzamento.txt || echo "manca r$i"; done   # non deve stampare nulla
grep "FALLITA" outputs/repliche/da20a25/avanzamento.txt         # non deve dare nulla, o righe gia' riprese
ls outputs/checkpoint_main2_rep*_da20a25.mat 2>/dev/null        # non deve esserci nulla
```

**Se una replica è FALLITA.** Rilancia lo stesso comando del run solo con quella replica, per
esempio `bash CER_repliche/lancia_repliche.sh da20a25 20 25 13`. Riparte dal checkpoint (vedi
`CER_repliche/README.md`, "Attenzione per una nuova ripresa").

**La finestra Git Bash del run** si può chiudere solo dopo che l'ultima riga di `avanzamento.txt`
dice "r20 fatta".

## 2. Passare al branch dell'analisi finale

```bash
git status                          # ci saranno da20a25/avanzamento.txt modificato e le nuove rNN/export
git fetch origin
git checkout ccr-13867105-vwc5b6    # le modifiche locali agli output vengono portate con se'
git log --oneline -1                # deve essere il commit piu' recente del branch
```

Il branch contiene tutto `70-results-analysis` più l'analisi finale. Non modifica `MAIN2.m` né
`lancia_repliche.sh`.

## 3. Lanciare l'analisi

```bash
bash CER_repliche/analisi_finale.sh
```

Lo script si ferma al primo passo che fallisce e stampa le ultime righe del registro
`outputs/tesi_finale/analisi_finale.log`. Si può rilanciare: le repliche già unite si saltano.

**Se il passo 1 (MATLAB) fallisce** su una replica, mandare:
- `outputs/repliche/unito/avanzamento.txt`;
- `outputs/repliche/unito/rNN/unisci.log`;
- `outputs/repliche/unito/rNN/main2.log`.

**Se fallisce un passo Python,** mandare il registro `analisi_finale.log`.

## 4. Controllare i risultati (10 minuti)

1. **`outputs/repliche/unito/controlli.txt`** deve finire con "Tutti i controlli passati." e avere
   la riga "r00 contro prova_regola_shapley: ... 0 diverse".
2. **`outputs/tesi_finale/rapporto.html`** (doppio clic):
   - in cima **non** deve esserci il riquadro rosso "Controlli di integrità falliti";
   - la tabella "Conclusioni del rapporto del 28 ottobre" dice quali affermazioni restano vere.
     **Il testo della tesi va adeguato a questa tabella.**
3. **`outputs/repliche/unito/aggregato/sintesi.md`**: tutti i numeri in chiaro. In cima c'è
   "Il numero di repliche basta?": quante conclusioni reggono e su quante le due metà concordano,
   il numero che va nel capitolo 6.1.

## 5. Salvare i risultati nel repository

```bash
git add outputs/repliche/da20a25 outputs/repliche/unito outputs/tesi_finale
git status --short | head -50       # controllo: niente .mat, niente tables/, niente insieme/
git commit -m "Run 20-25 completo (21 repliche) e analisi finale delle repliche"
git push -u origin ccr-13867105-vwc5b6
```

Il `.gitignore` tiene fuori da solo `.mat`, tabelle, log, `unito/insieme/` e gli export della
lettura unita tranne `punteggi_orientati.csv`. Peso atteso del commit: circa 140 MB (export di r07-r20 del blocco 20-25 circa 60 MB, punteggi della lettura unita circa 55 MB, `tesi_finale/` circa 25 MB).

## 6. Aggiornare README e documenti

I numeri finali stanno in `sintesi.md` e `conclusioni.csv`. Il modo più rapido è aprire una
sessione di Claude Code su questo branch e incollare il testo qui sotto.

```
Il run 20-25 è finito e ho lanciato CER_repliche/analisi_finale.sh; i risultati sono committati.
Aggiorna la documentazione allo stato finale, senza toccare il codice:
1. README.md: il riquadro "Stato" in cima (run finito, analisi finale fatta, risultati di
   riferimento = outputs/tesi_finale/ e outputs/repliche/unito/aggregato/, il rapporto del 28/10
   superato) e la §7.11.6 (aggiungi "Risultati della lettura unita" con i numeri principali di
   sintesi.md e conclusioni.csv: cosa regge, cosa dipende dai partecipanti, cosa non è confermato).
2. CER_repliche/README.md: lo "Stato" in cima e una sezione "Risultati della lettura unita
   5-25" sul modello di quelle dei blocchi.
3. outputs/workspace/LEGGIMI.md: una riga che rimanda a outputs/tesi_finale/ come fonte dei
   numeri della tesi.
4. docs/analisi_finale/PIANO_analisi_finale.md, sezione 7: segna tutti i passi come eseguiti,
   con la data.
Usa solo numeri presi dai file; scrivi in italiano, come il resto dei README. Poi commit e push.
```

## 7. Portare i risultati nella tesi (repository `Tesi-Magistrale`)

- **Figure.** Copia `outputs/tesi_finale/figure/*.pdf` e i `figure_descrittive/*.pdf` che usi in
  `Images/CAP6/`. In LaTeX: `\includegraphics[width=\textwidth]{Images/CAP6/G02_tau_by_band.pdf}`.
- **Numeri.** Copia `outputs/tesi_finale/numeri_tesi.tex` nella cartella della tesi. Aggiungi
  `\input{numeri_tesi}` nel preambolo (`Thesis.tex`) e usa le macro nel testo, per esempio
  `\NumReplicas{}`, `\TauGiniForzaIncentivanteBandFour{}`, `\ReversalGiniISCount{}`. L'elenco
  completo è nel file.
- **Tabelle.** `outputs/tesi_finale/tabelle/*.tex` contengono solo il `tabular`. Esempio:
  ```latex
  \begin{table}[htbp]\centering
  \caption{...}\label{tab:robustness}
  \input{Tables/robustness.tex}
  \end{table}
  ```
  Richiedono `\usepackage{booktabs}`.
- **Sezione 6.1.** Usa il prompt `docs/analisi_finale/PROMPT_capitolo_6_1.md` e sostituisci i
  segnaposto TBD con i numeri di `sintesi.md`, per esempio il controllo a metà.

## 8. Chiudere i branch

`ccr-13867105-vwc5b6` contiene tutti i commit di `70-results-analysis` più l'analisi finale.
Unendolo in `main` si chiude anche il lavoro di `70-results-analysis`.

1. **Su GitHub:** apri una pull request da `ccr-13867105-vwc5b6` verso `main`, controlla i file e
   fai il merge. In alternativa chiedi a Claude di aprire la PR.
2. **Verifica che `70-results-analysis` sia tutto dentro `main`:**
   ```bash
   git fetch origin
   git branch -r --merged origin/main | grep -E "70-results-analysis|ccr-13867105"   # devono comparire entrambi
   ```
3. **Cancella i branch** (sul sito, con "Delete branch" dopo il merge, oppure da terminale):
   ```bash
   git checkout main && git pull
   git push origin --delete 70-results-analysis
   git push origin --delete ccr-13867105-vwc5b6
   git branch -d 70-results-analysis ccr-13867105-vwc5b6
   ```
   `git branch -d` rifiuta di cancellare un branch non unito: se protesta, qualcosa non è in
   `main`. Fermati e controlla.
