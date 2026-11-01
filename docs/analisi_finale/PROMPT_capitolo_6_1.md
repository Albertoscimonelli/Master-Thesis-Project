Devi riscrivere la Sezione 6.1 "Simulation Design and Experimental Setup" della mia tesi
magistrale, nel file `Chapter6_Simulation.tex` del repository `Tesi-Magistrale`. È la parte
compresa fra `\section{Simulation Design and Experimental Setup}` e
`\section{Reference Configuration: ...}`, con le sottosezioni 6.1.1-6.1.4. Il metodo di analisi
è cambiato e la sezione va allineata. Leggi prima la sezione attuale e il paragrafo
"Households" del capitolo 4 (`Chapter4_Methodology.tex`), che descrive già come sono generate
le repliche.

## Regole di scrittura

- **Lingua e stile.** Inglese accademico, stesso tono e stessa persona della sezione attuale:
  impersonale, frasi complete, niente elenchi puntati nel testo.
- **Struttura.** Tieni le quattro sottosezioni e le loro `\label`. Si aggiunge al più un nuovo
  `\subsection` (vedi punto 3), con label `subsec:sim_replicas`.
- **Lunghezza.** Non più lunga di circa il 30% rispetto a oggi. Taglia le ripetizioni invece di
  aggiungere.
- **Numeri.** Non inventarne. Usa solo quelli di questo prompt. Dove un numero arriverà dopo
  il run finale scrivi `\textcolor{red}{[TBD: descrizione]}`.
- **Citazioni.** Non toccare quelle esistenti. Per i metodi nuovi usa queste chiavi:
  - `clopper1934` per l'intervallo di Clopper-Pearson;
  - `efron1993` per il bootstrap.

  Se non sono in `Thesis_bibliography.bib`, aggiungi le voci bib complete:
  - Clopper, C.J., Pearson, E.S. (1934), "The use of confidence or fiducial limits illustrated in
    the case of the binomial", Biometrika 26(4), 404-413;
  - Efron, B., Tibshirani, R.J. (1993), "An Introduction to the Bootstrap", Chapman & Hall.

  Per il τ-b di Kendall c'è già un commento `% [Citation needed]`: lascialo com'è.
- **Il commento iniziale.** Riscrivi il commento `% Assumption:` all'inizio del capitolo così:
  "the numbers refer to the repository on 1 November 2026; the values marked TBD are filled
  after the final run of the 20-25 member block."
- **Cosa consegnare.**
  1. Il LaTeX completo della nuova Sezione 6.1, pronto da incollare.
  2. Un elenco breve dei cambiamenti fatti.
  3. L'elenco dei punti fuori dalla 6.1 da allineare (ultimo punto di questo prompt).

## Cosa cambiare, punto per punto

### 1. Set of Simulated Communities (6.1.1)

- **Prima frase sulle 295 comunità.** Resta. Aggiungi che ogni replica contiene le stesse
  295 comunità (28 domestiche × 16 livelli di composizione, con le esclusioni già spiegate),
  quindi 21 × 295 = 6195 simulazioni.
- **"In this base design there is therefore no replication and no sampling error".** Va
  sostituita. La nuova lettura è questa:
  - ogni comunità resta una simulazione deterministica;
  - le famiglie che la compongono sono estratte a caso dentro le celle ISTAT dichiarate, e ogni
    replica è un'estrazione indipendente con il proprio seed;
  - i risultati della tesi sono letti **sulle repliche r01-r20**, come mediana e intervallo;
  - la replica identità r00 riproduce l'assegnazione originale, nella quale fino a 25 membri le
    famiglie erano tutte persone sole (capitolo 4). Non è un'estrazione casuale né una
    configurazione corretta, quindi **non entra nei risultati né nelle figure**. Serve solo come
    controllo del meccanismo delle repliche (riproduce le schede e i risultati originali).
    Al più una frase, nei limiti o in appendice, sull'effetto dell'errore corretto.
- **Il disegno annidato** (stesse famiglie in tutte le fasce e i livelli di una taglia, taglie
  annidate). Resta, ma va detto che vale **dentro ogni replica**.

### 2. Mechanisms and Indicators Compared (6.1.2)

- **Il Nucleolo è escluso dal confronto.** Dodici meccanismi sono eseguiti, ma il confronto ne
  usa **dieci, gli stessi a tutte le taglie da 5 a 25 membri**:
  - lo Shapley conta una volta sola: valore esatto fino a 18 membri, stima Adaptive Sampling
    da 20 in su;
  - il Nucleolo è calcolato fino a 18 membri ma escluso, perché non è calcolabile oltre (costo
    in 2^N).

  Motivazione, da scrivere:
  - un insieme di metodi omogeneo su tutta la griglia evita due letture separate (fino a 18 e
    fino a 25);
  - la stabilità di coalizione è misurata direttamente dall'eccesso massimo, ora disponibile
    fino a 25 membri;
  - il ruolo di riferimento di stabilità del Nucleolo è coperto da un controllo sul Variance Least
    Core a ogni comunità: il suo eccesso massimo coincide con −θ_LC, e nessuna ripartizione non
    negativa ha un eccesso massimo più basso;
  - nei blocchi fino a 18 membri, dove entrambi sono calcolati, Variance Least Core e Nucleolo
    sono entrambi fra i primi su merito e stabilità nel 92-100% delle celle. I dettagli sono in
    appendice: scrivi un rimando `\ref{app:nucleolus}` con `% TBD appendix`.
- **Il VAN minimo.** Togli "the minimum net present value among members" dagli indicatori di
  equità distributiva. Il VAN diventa un'**analisi complementare** di sostenibilità economica (VAN
  per metodo, VAN minimo, quota di membri con VAN negativo), riportata a parte e non usata nelle
  graduatorie. È coerente con la sezione "Research question" del capitolo 2, che lo chiama
  "complementary analysis".
- **L'indicatore di inclusione.** Il testo attuale lo esclude già: lascia quella frase.

### 3. Nuova sottosezione: "Participant Replicas and Robustness Criterion" (`subsec:sim_replicas`)

Da inserire dopo 6.1.2 o 6.1.3, dove scorre meglio. Contenuto:

- **Perché non tutte le estrazioni.** Con un pool di cento famiglie e le celle ISTAT dichiarate,
  gli insiemi di famiglie possibili sono circa 1.4·10⁵ per una comunità di 5 membri e circa
  8·10¹⁷ per una di 25. L'enumerazione è impossibile, quindi le repliche sono un **campione
  casuale delle estrazioni possibili** (una procedura Monte Carlo).
- **Perché venti.** Il numero è fissato dal costo di calcolo, circa tre-quattro ore per replica per le
  comunità da 20 e 25 membri. La sua adeguatezza è verificata a posteriori (punto sotto).
- **Cosa misurano.** La dispersione fra repliche misura la sensibilità dei risultati a **quali
  famiglie** entrano, a parità di composizione dichiarata. Non è l'errore di campionamento
  rispetto alle comunità italiane: il pool è una sola società sintetica. Questo concetto c'è già
  nel testo attuale: tienilo.
- **Come si riporta un risultato.**
  - Una quantità continua (τ-b, perdite, quote): mediana sulle 20 repliche con un intervallo.
    L'intervallo della mediana fra il 6° e il 15° valore ordinato ha copertura del 95.9%.
  - Un risultato con un esito (segno, vincitore, soglia superata): conteggio k/20, con
    l'intervallo esatto di Clopper-Pearson al 95% \cite{clopper1934}. Per esempio 20/20 è
    compatibile con una quota vera dell'83-100%, 18/20 con il 68-99% e 15/20 con il 51-91%.
- **Criterio di robustezza.** Un risultato:
  - **regge** se vale in almeno 15 repliche su 20: è la soglia minima per cui un test del segno a
    due code rifiuta l'ipotesi di esito casuale (p = 0.041);
  - **dipende dai partecipanti** fra 6 e 14;
  - **si inverte** con 5 o meno.

  Per le conclusioni principali del capitolo 8 si richiede almeno 17/20 (p = 0.003), che resta
  valido anche considerando il numero di affermazioni controllate.
- **Il numero di repliche basta?** Ogni conclusione è ricalcolata separatamente sulle repliche
  r01-r10 e r11-r20. Le due metà concordano sull'esito in
  `\textcolor{red}{[TBD: k di K conclusioni]}`. Come controllo aggiuntivo, 1000 ricampionamenti
  bootstrap delle repliche \cite{efron1993} danno la frequenza con cui ogni esito resta invariato
  (in appendice).
- **Sostituisci la frase "no confidence interval is attached to the results"** con la distinzione
  giusta:
  - sulle singole comunità non si mettono intervalli, perché la griglia è un disegno fattoriale
    scelto;
  - gli intervalli sui conteggi e sulle mediane fra repliche sono invece legittimi, perché le
    repliche sono estrazioni casuali. Valgono per la popolazione delle estrazioni possibili dal
    pool, non per le CER reali.

### 4. Aggregation and Analysis Procedure (6.1.3)

- **La procedura descritta oggi** (normalizzazione, rimpianto, soglia di rilevanza, τ-b,
  inversioni, scomposizione della varianza, trade-off, insieme ridotto, soglia regolatoria) resta.
  Aggiungi che è applicata **a ciascuna replica**, e che i risultati sono poi riassunti fra
  repliche come al punto 3.
- **La scomposizione della varianza** ha ora una quarta componente, i **partecipanti**: la
  variazione dei punteggi fra repliche dentro la stessa cella fascia × taglia. Si affianca a
  penetrazione, taglia e interazione.
- **La soglia regolatoria** (55% dell'energia ammessa) è verificata su tutte le comunità di tutte
  le repliche, separando le comunità con imprese da quelle senza. Non anticipare risultati: si
  vedono nella 6.6.

### 5. Computational Aspects and Reproducibility (6.1.4)

- **Correggi** "In the base run the exact Shapley value, the Nucleolus and the stability indicators
  are computed up to 18 members". Ora:
  - Shapley esatto e Nucleolo fino a 18 membri;
  - Variance Least Core ed **eccesso massimo fino a 25 membri in tutte le repliche**, grazie
    all'enumerazione delle coalizioni senza matrice di incidenza;
  - Adaptive Sampling al posto dello Shapley da 20 membri in su.
- **I tre blocchi di taglia** (fino a 15, 18, da 20 a 25 membri) restano, uniti per replica prima
  dell'analisi.
- **Tempi di calcolo.** Scegli una delle due opzioni:
  - **(a) Toglierli del tutto.** Rimuovi la frase "a replica up to 15 members ... takes about 15
    to 18 minutes".
  - **(b) Tenerli con le specifiche della macchina.**
    - Una frase con i tempi: circa 15-18 minuti per replica fino a 15 membri (due istanze MATLAB in
      parallelo), circa 10-12 minuti per i 18 membri, circa 3-4 ore per i 20-25 membri (228 minuti per r00) (un'istanza
      sola, perché il Variance Least Core a 25 membri è limitato dalla banda della memoria e il
      parallelo non aiuta). In totale circa 60-70 ore per le 21 repliche del blocco 20-25.
    - Le specifiche come segnaposto:
      `\textcolor{red}{[TBD: CPU, RAM, MATLAB version, Windows version]}`.

  **Usa l'opzione (b)** se io ti fornisco le specifiche, altrimenti la (a).
- **Riproducibilità.** Il resto resta: determinismo, seed espliciti, tabelle identiche byte per
  byte come test di regressione, ripresa da checkpoint. Aggiungi che la replica identità r00 ha
  riprodotto il run precedente con scarti relativi al più dell'ordine di 1e-7.

### 6. Fuori dalla 6.1: segnalali soltanto, non modificarli

- **`GAPV3.tex`:** la domanda di ricerca elenca ancora "inclusion" fra i criteri di equità, ma
  l'indicatore è escluso perché non valutabile.
- **Capitoli 4 e 5:** parlano di sedici meccanismi invece di dodici eseguiti e dieci confrontati.
- **Capitolo 4:** il Nucleolo va presentato come implementato ma escluso dal confronto, con
  rimando alla 6.1.
- **Capitolo 5:** va descritto il controllo di stabilità sul Variance Least Core (eccesso massimo
  = −θ_LC).
- **Appendice `app:nucleolus`:** da creare, con la tabella del Nucleolo nei blocchi fino a 18
  membri.
