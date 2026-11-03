# Piano d'azione: analisi finale delle repliche

**Decisioni prese (1 novembre 2026):**
- **Versione B:** Nucleolo escluso, stessi 10 metodi da 5 a 25 membri.
- **D1:** il VAN è un'analisi complementare.
- **D2:** le figure F01-F13 usano tutte le repliche insieme; r00 va in appendice.
- **D3:** figure in inglese.
- **D4:** proposta nella sezione 5, da confermare.
- **Colori:** proposta nella sezione 6, da confermare.
- **Branch:** `ccr-13867105-vwc5b6`, sotto-branch di `70-results-analysis`.

**Obiettivo.** Martedì, a run 20-25 finito, lanci **un solo comando** e ottieni tutte le tabelle,
le figure e i numeri per chiudere i capitoli 6-8. Nessun valore scritto a mano. Se un'affermazione
del testo non è più sostenuta dai dati, lo script si ferma e dice quale.

**Dove gira.** Sul PC del run, dove ci sono MATLAB, i `.mat` dei blocchi e le schede
`CER_repliche/rNN/`. Le parti solo Python girano anche altrove, partendo dagli `export/`.

Il piano è in due versioni:
- **A: codice com'è adesso.** Il Nucleolo resta nell'analisi, e servono due letture per replica:
  fino a 25 membri e fino a 18 con il Nucleolo.
- **B: Nucleolo escluso.** Una sola lettura 5-25 con gli stessi 10 metodi a tutte le taglie.

La parte comune è scritta una volta sola (sezione 1). Poi c'è ciò che cambia (sezioni 2 e 3).

---

## 0. Cosa la tesi deve ricevere (mappa capitoli → uscite)

| Sezione della tesi | Cosa serve | Da dove esce |
|---|---|---|
| 6.1 Design | numero di comunità, repliche, metodi, tempi | `controlli/riepilogo_run.csv` (passo 6) |
| 6.2 Confronto fra metodi e indicatori | valori grezzi per metodo, profili normalizzati, mappa di sintesi, chi vince ("poli") | figure F01-F03 sulle repliche, G01 |
| 6.3 Sensibilità a taglia, penetrazione, categoria | assi della griglia, scomposizione della varianza con la quota dei partecipanti, effetto di PA e imprese | F04/F05, G04, G05, F10/F11/F13 |
| 6.4 Inversioni di graduatoria | quota di coppie invertite lungo penetrazione e taglia, su tutte le repliche | G03 |
| 6.5 Accordo fra indicatori, trade-off, insieme ridotto | τ-b per fascia (mediana e intervallo), perdite di trade-off, insieme ridotto, Pareto | G02, G06, G07, G08 |
| 6.6 Soglia regolatoria sulle imprese | quota incentivata di ogni comunità di ogni replica, separata per gruppo | G09 (sostituisce F14) |
| Analisi complementari | VAN e VAN minimo per metodo, quota ai prosumer, sensibilità alla soglia di rilevanza, Shapley contro AS | G10, G11, G12, tabella fase1 |
| Cap. 7 e 8 | i numeri chiave in forma citabile | `numeri_tesi.tex` (macro LaTeX) e rapporto HTML |

**Regola per tutti i numeri.** Il valore principale è la **mediana sulle repliche r01-r20**,
accompagnata da un intervallo (min-max o 10°-90° percentile) e, quando serve, dal numero di
repliche in cui il risultato regge. r00 (il disegno con le persone sole) compare solo come
confronto.

---

## 1. Parte comune alle due versioni

### Passo 1: unione dei blocchi per replica (`CER_repliche/unisci_repliche.sh`, nuovo)

Per ogni replica NN da 00 a 20:
1. `unisci_blocchi('CER_repliche/rNN', {fino15, da18, da20a25}/rNN/checkpoint.mat, 'repNN_unito', 25)`.
2. `MAIN2_RIPRENDI=1 MAIN2_RADICE=CER_repliche/rNN MAIN2_MAX_UTENTI=25 MAIN2_IND=1 MAIN2_CARTELLA=repNN_unito`.
   Questo passo **salva anche `workspace.mat`** (RESULTS, AGR, LIV, GRID, REV, SINT, F1, PERD, CLUS,
   SENS) e chiama `esporta_run_livelli`: è ciò che manca al comando scritto oggi nel README.
3. Sposta tabelle, checkpoint, workspace ed export in `outputs/repliche/unito/rNN/`, con la stessa
   struttura dei blocchi, così `aggrega_repliche.py` li legge senza modifiche.
4. Salta le repliche già fatte, scrive una riga per replica in `avanzamento.txt` e si ferma con un
   messaggio chiaro se MATLAB esce con errore.

Controlli automatici per ogni replica:
- 295 comunità;
- l'elenco dei metodi è quello atteso;
- "Adaptive Sampling Shapley" non compare nell'analisi fra comunità;
- l'eccesso massimo è presente a tutte le taglie.

Tempo stimato: circa 2-3 minuti per replica, quindi circa 1 ora in totale.

### Passo 2: controllo di regressione su r00

Il r00 unito deve coincidere con `prova_regola_shapley` del 28 ottobre, tranne due cose attese:
- le nuove colonne di stabilità a 20-25 membri;
- le tabelle di analisi che da quelle dipendono.

Si confrontano le tabelle con lo script di sempre (`confronta_regola_shapley.py`). Se qualcosa
cambia fuori da questo, il comando si ferma.

### Passo 3: estensione di `CER_repliche/aggrega_repliche.py`

Cosa resta com'è: vincitori, τ, inversioni, perdite, insieme ridotto, Pareto, composizione,
varianza.

Si aggiunge:
- **controllo di completezza:** 21 repliche presenti, altrimenti lo script si ferma (oggi va
  avanti con quelle che trova);
- **`soglia.csv`:** dagli export (`comunita.csv`), per ogni gruppo (solo domestici, con PA, con
  imprese) la quota incentivata massima e mediana e il numero di comunità in cui la soglia scatta,
  per replica e in aggregato;
- **`van.csv`:** dagli export (`quote_membri.csv`), per ogni metodo il VAN minimo, la quota di
  membri con VAN negativo e la mediana del VAN, per fascia e livello;
- **`quote_prosumer.csv`:** quota dell'incentivo ai prosumer per metodo e fascia, su tutte le
  repliche;
- **`sensibilita_soglia.csv`:** quante volte il vincitore cambia con la soglia di rilevanza, su
  tutte le repliche (dalle tabelle `sensibilita_soglia_*` di MAIN2);
- **`fase1.csv`:** Shapley esatto contro AS fino a 18 membri, cioè l'errore dell'approssimazione
  (validazione per i capitoli 5 e 6);
- **`sintesi.md`:** in più l'insieme ridotto, Pareto, soglia, VAN e quota ai prosumer;
- **indicatori:** `InclusioneLIHC` fuori ovunque. Per `VAN_min_EUR` serve la decisione D1 (sotto).

### Passo 3b: il numero di repliche basta? (aggiunto il 1 novembre)

Per ogni conclusione del rapporto (segno di un τ, vincitore, perdita, quota di comunità sopra la
soglia):
- **Controllo a metà.** Si rifà la conclusione su r01-r10 e su r11-r20 separatamente e si guarda se
  le due metà danno lo stesso esito ("regge", "dipende dai partecipanti", "si inverte"). In tesi va
  il numero di conclusioni concordi sul totale (capitolo 6.1).
- **Bootstrap** (1000 ricampionamenti con reinserimento delle 20 repliche, seed fisso). Per ogni
  conclusione, la quota di ricampionamenti in cui l'esito non cambia. È una colonna delle tabelle,
  per l'appendice.
- **Intervalli esatti** (Clopper-Pearson al 95%) per ogni conteggio k/20, e intervallo della mediana
  fra il 6° e il 15° valore ordinato (copertura 95,9%).
- **Uscite:** `sufficienza_repliche.csv` e una sezione di `sintesi.md`. Pochi secondi, nessun run di
  MATLAB.

**Perché non tutte le estrazioni.** Le combinazioni di famiglie compatibili con le celle ISTAT sono
circa 1,4·10⁵ a 5 membri e circa 8·10¹⁷ a 25 membri (pool di 100, `composizione_cer_scalata.md`):
l'enumerazione è impossibile, quindi le repliche sono un campione casuale di estrazioni (Monte
Carlo). 20 è il numero sostenibile nei tempi; il controllo a metà verifica che basti per le
conclusioni qualitative.

### Passo 4: figure sulle repliche (`CER_repliche/grafici_repliche.py`, nuovo)

Stile e colori dei metodi uguali a `grafici_metodi.py`; testi in inglese come la tesi; PNG e PDF.

| Figura | Contenuto |
|---|---|
| G01 | Poli: mappa metodo × indicatore con la quota di celle in cui il metodo è fra i primi. Mediana sulle repliche, r00 annotato |
| G02 | τ-b per fascia sulle coppie chiave (Gini-IS, FI-IS, Gini-FI, FI-Eccesso): linea della mediana, banda 10°-90°, punti di r00 |
| G03 | Inversioni lungo penetrazione e taglia: distribuzione sulle repliche, r00 marcato |
| G04 | Scomposizione della varianza per indicatore: barre impilate (penetrazione, taglia, interazione, partecipanti) |
| G05 | Composizione: coppie invertite e cambi di vincitore per livello PA/ND rispetto al livello base |
| G06 | Matrice delle perdite di trade-off (scelto × perso), mediana e intervallo in ogni casella |
| G07 | Insieme ridotto: concordanza delle coppie per taglio di τ, rappresentante modale |
| G08 | Pareto: quota di comunità sul fronte, per metodo e insieme di criteri |
| G09 | Soglia regolatoria: tutte le comunità di tutte le repliche, colore per gruppo, linee al 55% e al 45%. Sostituisce F14 |
| G10 | VAN minimo e quota di membri con VAN negativo, per metodo |
| G11 | Quota ai prosumer per metodo e fascia, mediana e banda |
| G12 | Stabilità: quota di celle in cui ciascun metodo è primo sull'eccesso massimo e sulle coalizioni instabili |

### Passo 5: figure descrittive F01-F13 su tutte le repliche

`grafici_metodi.py` oggi descrive un solo run. Si aggiunge l'opzione `--repliche <cartella>`:
legge export e tabelle di r01-r20 insieme, con la replica nella chiave di ogni comunità.

Così F01 (valori grezzi), F02/F03 (profili e mappa), F04/F05 (assi), F07-F09 e F10/F11/F13
(composizione) mostrano tutte le comunità di tutte le repliche come distribuzioni, senza
intervalli di confidenza, come chiede il capitolo 6. F06 viene sostituita da G04, che separa
anche i partecipanti. F14 viene sostituita da G09.

Lo stesso script su r00 da solo produce le figure "di prima", per l'appendice o il confronto.

### Passo 6: rapporto e numeri per LaTeX (`rapporto_conclusioni.py`, rifatto sulle repliche)

- **Fonti:** gli aggregati di `unito/`, le figure G e F dei passi 4-5.
- **Verifiche ricalibrate.** Ogni affermazione diventa "regge in almeno 16 repliche su 20"
  (soglia della decisione D4). Le affermazioni che già sappiamo cambiate si riscrivono secondo i
  dati:
  - l'allineamento lordo dipende dai partecipanti;
  - τ(FI, IS) in fascia 4;
  - la soglia: scatta in alcune piccole comunità di soli domestici, mai dove ci sono imprese
    (oggi massimo 34,7%).
- **Uscite:**
  - `outputs/tesi_finale/rapporto.html`: figure commentate e conclusioni clausola per clausola
    della domanda di ricerca;
  - `outputs/tesi_finale/numeri_tesi.tex`: macro LaTeX (per esempio `\newcommand{\tauGiniISfUno}{...}`)
    da `\input` nella tesi, così i numeri del testo non si copiano a mano;
  - `outputs/tesi_finale/figure/`: le figure in PDF, con i nomi delle sezioni della tesi;
  - `outputs/tesi_finale/tabelle/`: le tabelle della tesi in CSV e in LaTeX (`booktabs`);
  - `outputs/tesi_finale/controlli/riepilogo_run.csv`: comunità, repliche, metodi, tempi,
    eventuali ripartenze del VLC.

### Passo 7: il comando unico (`CER_repliche/analisi_finale.sh`, nuovo)

```bash
bash CER_repliche/analisi_finale.sh            # tutto
bash CER_repliche/analisi_finale.sh --solo-python   # salta MATLAB, rifà analisi, figure e rapporto
```

Lo script:
1. **Pre-controllo:** 21 repliche in `da20a25` con checkpoint ed export e nessuna riga "FALLITA" in
   `avanzamento.txt`; altrimenti si ferma e dice quale replica manca.
2. Passo 1 e passo 2.
3. Passi 3-6.
4. Stampa il riepilogo finale: cosa è stato prodotto, quanto ha impiegato, quali verifiche sono
   passate.

È idempotente: se si interrompe, rilanciato riprende da dove era.

### Passo 8: prove prima di martedì

- **Qui (senza MATLAB).** Provo le parti Python che leggono solo gli export (soglia, VAN, quota ai
  prosumer, G09-G11) su fino15, da18 e da20a25 r00-r06, che sono già nel repository.
- **Sul PC del run, lunedì (prova generale).**
  - `analisi_finale.sh --repliche 0-6` su r00-r06, che hanno già tutti e tre i blocchi.
  - Una sola istanza MATLAB corta (~2-3 min per replica) accanto al run: rallenta un po' il VLC,
    ma non lo ferma. In alternativa si prova solo su r00 e r01.
  - Serve a scoprire problemi come l'unione di RESULTS prodotti da versioni diverse del codice
    (fino15 del 29/10, da20a25 del 30-31/10), che in teoria hanno gli stessi campi.
- **Martedì:** il comando completo.

### Passo 9: allineamento del testo della tesi (lista, non codice)

- `GAPV3.tex`: togliere l'"inclusione" dai criteri della domanda di ricerca (non valutabile, come
  già scritto nel capitolo 6).
- Capitoli 4 e 5: numero dei metodi (16 contro 12) da allineare.
- Capitolo 6.1: aggiornare "stabilità fino a 18 nel run base", ora disponibile fino a 25 in tutte
  le repliche.
- Capitolo 6.6: riformulare il risultato della soglia secondo G09.
- Commit dei soli file nuovi o modificati e del rapporto. Gli export di `unito/` si versionano
  come quelli dei blocchi (~190 MB), le tabelle no.

### Decisioni da prendere (valgono per A e B)

- **D1, VAN minimo.** Proposta: analisi complementare (G10), fuori dagli indicatori del confronto,
  come dice il gap ("complementary analysis"). Il capitolo 6.2 oggi lo elenca fra gli indicatori di
  equità: va corretto il testo.
- **D2, figure descrittive.** Proposta: tutte le repliche insieme (passo 5), r00 solo in appendice.
- **D3, lingua delle figure.** Proposta: inglese, come la tesi.
- **D4, quando un risultato "regge".** Proposta: almeno 16 repliche su 20 (80%). Fra 50% e 80% lo
  si dichiara "dipende dai partecipanti".

---

## 2. Versione A: codice com'è adesso (Nucleolo nell'analisi)

**Il problema.** Il Nucleolo si calcola solo fino a 18 membri. Nella lettura unita 5-25 l'analisi
fra comunità tiene solo i metodi presenti ovunque, quindi il Nucleolo sparisce da sé: i punteggi
del 28 ottobre lo confermano, 10 metodi senza Nucleolo. Per tenerlo servono **due letture per
replica**.

Passi in più rispetto alla parte comune:
- **A1, passo 1 doppio.** Per ogni replica, oltre a `unito` (25 membri, 10 metodi, Shapley esatto
  fino a 18 e AS oltre), si fa `unito18`:
  - `unisci_blocchi` su fino15 + da18 con tetto 18;
  - 168 comunità, 11 metodi (Shapley esatto e Nucleolo; l'AS è escluso da MAIN2);
  - uscite in `outputs/repliche/unito18/rNN/`.

  Tempo in più: circa 1 ora (quindi circa 2 ore in tutto).
- **A2, passo 2 doppio.** Il r00 di `unito18` deve coincidere con le tabelle di
  `tables_main2_fino18_IND` del 27 ottobre.
- **A3, passo 3 due volte.** `aggrega_repliche.py --blocco unito` e `--blocco unito18`.
- **A4, figure per la vista fino a 18.** Si rifanno solo le figure in cui il Nucleolo conta: G01
  (poli), G02 (τ), G06 (perdite), G08 (Pareto), G12 (stabilità). Non tutte, per non raddoppiare il
  capitolo.
- **A5, rapporto.** Due livelli di lettura, da spiegare nel capitolo 6.1:
  - la vista 5-25 è quella principale;
  - la vista fino a 18 serve per le affermazioni sul Nucleolo (per esempio il polo "merito e
    stabilità = VLC e Nucleolo") e per il confronto con lo Shapley esatto.

  Le verifiche controllano che le due viste non si contraddicano sui metodi comuni.
- **A6, testo.** Il capitolo 6 deve dire esplicitamente che il Nucleolo è confrontato solo fino a 18
  membri e perché (costo in 2^N).

| | Versione A |
|---|---|
| Metodi nel confronto | 10 (5-25 membri) + 11 (fino a 18) |
| Letture per replica | 2 |
| Tempo martedì | circa 2 ore |
| Figure | ~25 (F01-F13 + G01-G12) + 5 della vista fino a 18 |
| Rischio | più complessità e due viste da raccontare; nessuna modifica a MAIN2 |

---

## 3. Versione B: Nucleolo escluso dall'analisi

**Perché si può fare.**
- Il Nucleolo serviva come riferimento di stabilità e come controllo del VLC. Quel controllo ora è
  dentro MAIN2 fino a 25 membri: l'eccesso massimo del VLC vale −θ_LC, e nessuna ripartizione non
  negativa ha un eccesso massimo più basso.
- L'eccesso di coalizione c'è ora a tutte le taglie, quindi la stabilità si misura senza Nucleolo.
- Nelle repliche dei blocchi già fatti, VLC e Nucleolo sono entrambi fra i primi su merito e stabilità
  nel 92-100% delle celle (README delle repliche): il Nucleolo aggiunge poco rispetto al VLC. Questi numeri sono già in
  `fino15/aggregato` e `da18/aggregato` e si possono citare in una frase o in appendice senza
  lavoro in più.
- Un solo insieme di metodi da 5 a 25 membri: una sola vista, più facile da raccontare.

**Niente da rifare in MATLAB.** I run dei blocchi restano come sono. Nella lettura unita MAIN2
toglie il Nucleolo da sé, perché manca a 20-25.

Cosa cambia rispetto alla parte comune:
- **B1, filtro nei dati grezzi.** In `unito/rNN/export/` i file per comunità (`tfair_lungo.csv`,
  `quote_membri.csv`) contengono ancora le righe del Nucleolo fino a 18 membri (verificato sull'export
  del 28 ottobre); `punteggi_orientati.csv` invece no. `aggrega_repliche.py`, `grafici_repliche.py`
  e `grafici_metodi.py --repliche` tolgono quelle righe in un punto solo, così che figure dei valori
  grezzi, VAN e quota ai prosumer usino gli stessi 10 metodi dei punteggi. Un controllo verifica che
  "Nucleolo" non compaia in nessuna uscita.
- **B2, niente `unito18`.** Passo 1 singolo, circa 1 ora martedì.
- **B3, testo della tesi.**
  - Capitolo 6.1: metodi confrontati 10. Erano 12 eseguiti: il Nucleolo è eseguito fino a 18
    membri ma escluso dal confronto, e l'AS conta come "Shapley" sopra 18.
  - Capitolo 4: il Nucleolo resta descritto come metodo implementato, con la ragione
    dell'esclusione dal confronto.
  - Capitolo 5: il controllo di stabilità del VLC che ne prende il ruolo.
- **B4, appendice opzionale.** Una tabella con il Nucleolo dai due aggregati di blocco già pronti
  (fino a 15 e 18 membri), per mostrare che escluderlo non cambia i poli.

| | Versione B |
|---|---|
| Metodi nel confronto | 10, uguali da 5 a 25 membri |
| Letture per replica | 1 |
| Tempo martedì | circa 1 ora |
| Figure | ~25 (F01-F13 + G01-G12) |
| Rischio | va giustificata l'esclusione nel testo (argomenti sopra); codice più semplice e una sola storia |

---

## 4. Calendario

| Quando | Cosa |
|---|---|
| Domenica-lunedì | Scrivo i passi 1, 3, 4, 5, 6, 7 e provo qui le parti che leggono gli export. Commit sul branch `70-results-analysis` (o su quello che indichi) |
| Lunedì sera | Prova generale sul PC del run su r00-r06 (o solo r00-r01), con correzioni |
| Martedì, a run finito | `bash CER_repliche/analisi_finale.sh`: circa 1 ora (B) o 2 ore (A) |
| Dopo | Inserimento delle figure e di `numeri_tesi.tex` nei capitoli 6-8, passo 9 |

**Scelta: versione B** (decisione del 1 novembre). Usa un insieme di metodi uniforme su tutta la griglia e dimezza
lavoro e tempi. Il Nucleolo non porta informazioni che VLC ed eccesso non diano già, e quanto serve
a giustificarne l'esclusione è già calcolato.

---

## 5. D4: quando un risultato "regge" sulle repliche

Le 20 repliche sono estrazioni indipendenti delle famiglie, ciascuna con un seed. Per un risultato
con un segno (per esempio "τ(Gini, IS) è negativo in fascia 4") si può usare il test del segno:
se il segno fosse a caso (probabilità 1/2), quante repliche concordi su 20 sarebbero sorprendenti?

| Repliche concordi | Quota | p a una coda | p a due code |
|---|---|---|---|
| 14 | 70% | 0,058 | 0,115 |
| **15** | **75%** | **0,021** | **0,041** |
| 16 | 80% | 0,006 | 0,012 |
| 17 | 85% | 0,001 | 0,003 |

**Proposta:**
- **regge** con almeno **15 repliche su 20**: è la soglia più bassa con p < 0,05 anche a due code;
- **dipende dai partecipanti** fra 6 e 14;
- **si inverte** con 5 o meno.

Il conteggio esatto, per esempio "18/20", si scrive **sempre** accanto al risultato, così chi legge
giudica da sé.

Per i "vincitori" (fra 10 metodi) la probabilità a caso di uno stesso vincitore è molto più bassa
di 1/2, quindi 15/20 è prudente.

**Avvertenza da scrivere nella tesi.** È un criterio di **robustezza rispetto alle famiglie
estratte dal pool di 100**, non un'inferenza sulle CER italiane, e si applica a decine di
affermazioni. Per le poche affermazioni centrali delle conclusioni (cap. 8) si può chiedere 17/20
(p ≈ 0,003 a due code), che regge anche correggendo per molti confronti.

---

## 6. Colori: palette Polimi senza perdere chiarezza

**Regola: il colore si sceglie dal compito che fa nella figura.**
- Il blu Polimi è l'**ancora** di tutte le figure.
- Una **palette sfumata a una sola tinta** si usa **solo** dove i dati hanno un ordine: lì è anche
  la scelta corretta.
- Dove il colore deve distinguere categorie servono tinte diverse.

| Compito | Dove | Colori |
|---|---|---|
| Ordine (ordinale) | 4 fasce di penetrazione, taglie | rampa del blu Polimi `#7FAACB → #4A82AE → #005AA0 → #00305A` |
| Intensità (sequenziale) | mappe 0-1: punteggi, quota di celle vinte | da bianco-azzurro `#F4F8FB` al blu Polimi `#005AA0` e `#00305A` |
| Polarità (divergente) | τ da −1 a +1, differenze fra livelli | arancio `#D9731A` ↔ grigio `#F2F2F2` ↔ blu Polimi `#005AA0` |
| Identità (categoriale) | 4 famiglie di metodi; 3 gruppi di comunità | blu Polimi `#005AA0`, arancio `#D9731A`, verde `#3BA272`, prugna `#A23B72`, **sempre con marker diversi** e, per i metodi, il nome scritto |
| Riferimento | r00, mediane, soglie | grigio scuro / nero, marker vuoto |

**Accorgimenti:**
- **I 10 metodi non hanno 10 colori.** Il nome del metodo sta sull'asse o accanto al punto; il
  colore dice la famiglia. Dieci tinte non si distinguono, né a schermo né in stampa.
- **La palette è verificata con un validatore**, non a occhio: daltonismo protan/deutan, contrasto
  sullo sfondo e differenza fra colori vicini.
  - I 3 colori dei gruppi passano tutti i controlli.
  - I 4 delle famiglie stanno nella fascia "ammessa con codifica secondaria" (blu-prugna ΔE 7,7
    per i protanopi): per questo hanno marker diversi.
  - La rampa delle fasce passa tutti i controlli.
- **Il blu Polimi come ancora è `#005AA0`.** Il `bluepoli` del template (CMYK 0,4/0,1/0/0,4, circa
  `#5C8999`) è troppo grigio per distinguere dati: va bene per titoli e cornici, non per i punti.
- Anteprima su dati veri del repository: `anteprima_palette.png`.

---

## 7. Stato dell'implementazione (aggiornato al 3 novembre 2026)

Tutto sul branch `ccr-13867105-vwc5b6`. Il comando è `bash CER_repliche/analisi_finale.sh`;
istruzioni in `CER_repliche/README.md`, sezione "Analisi finale".

| Passo | File | Stato |
|---|---|---|
| 1 | `unisci_repliche.sh` | **fatto il 3 novembre** sulle 21 repliche (PR #71) |
| 2 | `controlla_unito.py` | provato sul banco di prova; **passato il 3 novembre** sulle 21 repliche |
| 3, 3b | `aggrega_repliche.py` | provato sul banco di prova; **fatto il 3 novembre** |
| 4 | `grafici_repliche.py` (G01-G13) | provato e figure controllate a vista; **fatto il 3 novembre** |
| 5 | `unisci_per_figure.py` + `grafici_metodi.py` (palette Polimi) | provato; **fatto il 3 novembre** |
| 6 | `rapporto_repliche.py` | provato; **fatto il 3 novembre** |
| 7 | `analisi_finale.sh` | provato con `--solo-python` sul banco di prova; **lanciato sul PC del run il 3 novembre** |

**r00 (decisione del 1 novembre).** Non entra in figure, numeri e conclusioni: non è
un'estrazione casuale né una configurazione corretta. Resta come controllo del meccanismo delle
repliche (passo 2) e in una sezione in fondo a `sintesi.md`.

**Il rapporto del 28/10 non si ferma più sulle conclusioni.** `rapporto_repliche.py` le ricalcola
sulle repliche e le marca "confermata", "non confermata" o "dipende dai partecipanti"
(`conclusioni.csv`). Si ferma solo sui controlli di integrità: repliche, comunità, metodi,
stabilità a tutte le taglie, nessun metodo escluso dalle figure descrittive.

**Prova generale lunedì sul PC del run**, mentre il run 20-25 continua: r00 e r01 hanno già tutti
e tre i blocchi.
```bash
bash CER_repliche/unisci_repliche.sh 0 1
python -I CER_repliche/controlla_unito.py          # su r00 fa anche la regressione col 28/10
```
Se passa, martedì basta `bash CER_repliche/analisi_finale.sh`.

**Esito (3 novembre 2026).** `analisi_finale.sh` sul PC del run: il passo MATLAB si è saltato da
sé, gli altri 7 sono finiti in 2 minuti senza errori. Tutti i controlli di integrità sono passati
(295 comunità, 16 livelli, 10 metodi, 7 taglie per replica), e in `outputs/tesi_finale/rapporto.html`
il riquadro "Controlli di integrità falliti" non c'è. Risultati committati in `974ca57`: tabelle
in `unito/rNN/tabelle/`, aggregato, `outputs/tesi_finale/`, circa 98 MB. Numeri da
`outputs/repliche/unito/aggregato/sintesi.md`, `robustezza.csv`, `van.csv`, `soglia.csv` e
`outputs/tesi_finale/conclusioni.csv`, solo repliche r01-r20.

- **Il numero di repliche basta (passo 3b).** 334 conclusioni: 328 reggono (almeno 15/20), 321
  forti (almeno 17/20), 6 dipendono dai partecipanti, nessuna si inverte. Le metà concordano su
  327, e il bootstrap dà lo stesso verdetto nel 100% dei casi (mediana).
- **Cosa regge.** 10 conclusioni chiave su 11, tutte in 20 repliche su 20 dove si contano:
  - i tre poli: Equal Split su Gini, Variance Least Core su merito e stabilità, Pearson Key o
    Tri-level EP sulla forza incentivante;
  - il capovolgimento con la penetrazione;
  - nessuna comunità con imprese sopra il 55%;
  - il trade-off più caro, uguaglianza contro incentivo (0,88 [0,86; 0,88]);
  - merito e stabilità non in concorrenza (0,00 [0,00; 0,01]);
  - la composizione che pesa poco (9%, livelli 1-23%).
- **Cosa dipende dai partecipanti: solo l'allineamento lordo.** Le 6 conclusioni che non reggono e
  le 7 con le metà discordi sono tutte sue (45 su 51 reggono). Sugli altri sette indicatori
  reggono tutte e 283, con le metà concordi.
- **Cosa non è confermato: la penetrazione primo fattore della varianza per ogni indicatore.** Vale
  per 7 su 8 (59-72%). Per l'allineamento lordo la penetrazione spiega l'11%, la taglia il 29%.
  Nella tesi l'affermazione va limitata a sette indicatori: è un punto in più per la lista del
  passo 9.
- **Soglia regolatoria.** Supera il 55% solo il gruppo dei soli domestici: 70 comunità su 560,
  massimo 81,4%. Con imprese il massimo è 34,7%, con PA il 36,1%.
- **VAN.** Pearson Key, Tri-level EP e Proportional to Consumption lasciano almeno un VAN negativo
  nell'83-100% delle comunità; Equal Split nello 0-9%.
