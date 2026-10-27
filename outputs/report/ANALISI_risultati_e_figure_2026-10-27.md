# Analisi critica dei risultati e figure per la tesi

27 ottobre 2026. Dati: run del 20 ottobre (`outputs/tables_main2/`, 76 comunità: livello 0 più PA1-3)
ed export lungo del 13 ottobre (`outputs/workspace/export_fino18/`, solo livello 0).
Figure e numeri si rigenerano con un comando, dalla root del progetto:

```bash
python -I outputs/workspace/strumenti/grafici_metodi.py
```

Le figure (PNG e PDF vettoriale) vanno in `outputs/figures_tesi/`, che non è versionata come le
altre cartelle di figure. I numeri dietro ogni figura vanno in `outputs/tables_tesi/`, che è
versionata. Ogni numero citato qui sotto viene da quei CSV o da `controlli.txt`.

Metriche analizzate (scelta del 27 ottobre):

| Gruppo | Metriche |
|---|---|
| Equità | Gini |
| Merito | Fairness Index, σ |
| Stabilità | eccesso massimo, coalizioni instabili |
| Incentivo | forza incentivante (netta), allineamento netto e lordo |

EI_orig è escluso (vale 1 − Gini). InclusioneLIHC e VAN_min sono un'analisi a parte.

---

## 1. Ricostruzione del disegno sperimentale

**Cosa varia.** La griglia ha 5 taglie (5, 8, 10, 15, 18 membri) e 4 fasce di penetrazione dei
prosumer (20–30%, 40–53%, 60–80%, 100%), con una comunità per cella. In più c'è la composizione:
PA0 (solo famiglie), PA1 (+ comune), PA2 (+ scuola), PA3 (+ palazzetto), a N, C e P invariati.
PA2 ha 19 schede e PA3 ne ha 17: mancano quelle con meno prosumer che PA.

**Unità statistica.** Ogni comunità è una sola simulazione deterministica, quindi **non ci sono
repliche**. L'unico elemento casuale è l'Adaptive Sampling Shapley (seme 42), che è fuori
dall'analisi dove c'è lo Shapley esatto. Lo scarto fra i due è lo 0,3–0,8% di v(N), da
`fase1/regime_le18_Shapley_vs_AS_per_taglia.csv`.

**Le comunità sono annidate.** Una comunità da n membri usa le prime n famiglie della stessa
società da 100 (`csv_lombardia100/<n>_utenti.xlsx`). Due conseguenze:
- a taglia fissa, le quattro fasce hanno **le stesse famiglie** e cambia solo chi ha il
  fotovoltaico. Lungo la penetrazione il disegno è quindi *appaiato*, il che è un buon disegno per
  attribuire l'effetto alla penetrazione;
- fra taglie diverse le famiglie si sovrappongono (le 5 della comunità da 5 stanno in tutte le
  altre). Le cinque taglie **non sono repliche indipendenti**, e la loro concordanza non misura
  la robustezza ad altre famiglie.

**Aggregazione.** Il punteggio normalizzato è `1 − rimpianto` di `tradeoff_losses.m`: per ogni
comunità e indicatore, 1 = metodo migliore, 0 = peggiore, con l'indicatore orientato e la soglia
di rilevanza della §7.6.3 del README.

### Sulla deviazione standard (domanda 2)

La tua intuizione è giusta in generale: con più osservazioni dello *stesso scenario* per ogni
valore del parametro, la variabilità va calcolata e mostrata punto per punto. Ma qui quella
situazione non esiste.

| Cosa si mostrava | Problema | Cosa fa ora lo script |
|---|---|---|
| media ± std su tutte le schede, per metodo e metrica (grafici 1–3 della prima versione) | la std mescola comunità di taglia e penetrazione diverse: è variabilità **fra configurazioni** (in gran parte effetto sistematico della penetrazione, F06), non incertezza. Sui punteggi in [0,1] le barre uscivano dall'intervallo | si mostra la distribuzione: un punto per comunità colorato per fascia, mediana e intervallo interquartile (F01, F02, F03) |
| barre di std sulle curve di scalabilità | quasi ogni punto era **una sola comunità** (std = 0 disegnata come se fosse una misura). In più l'arrotondamento a passi del 25% fondeva 40% e 60% a n = 5, cioè **due scenari diversi** nello stesso punto | nessuna barra; una linea per taglia e la mediana fra taglie per fascia (F04, F05). La "variabilità per punto" lungo la penetrazione è la dispersione fra le 5 taglie, mostrata con i dati stessi e non riassunta in una std |
| — | — | nessun errore standard e nessun intervallo di confidenza |

Perché niente errore standard né intervallo di confidenza:
1. la griglia è un disegno scelto, non un campione casuale di comunità, quindi non c'è una
   popolazione a cui estendere un intervallo;
2. con 5 osservazioni annidate per fascia una std sarebbe instabile e un errore standard
   sottostimerebbe l'incertezza;
3. la variabilità che conterebbe per la tesi, cioè quanto cambierebbero i risultati con **altre
   famiglie**, oggi non è misurata da nessun dato.

Per stimarla servono repliche vere: proposta C1, sezione 5.

---

## 2. Modifiche implementate

| File | Modifica | Perché |
|---|---|---|
| `outputs/workspace/strumenti/grafici_metodi.py` | riscritto (sostituisce la versione di stamattina) | legge le tabelle del 20 ottobre per **tutti** i livelli; usa per la normalizzazione la stessa definizione e la stessa soglia di MAIN2 invece di ricalcolarla senza soglia; niente std su punti singoli; eccesso e coalizioni in quota (v(N) va da 40 a 1121 €, le coalizioni sono 2ⁿ−2); AS escluso dove c'è lo Shapley; figure coerenti in PNG e PDF; ogni figura salva i suoi numeri in CSV |
| `outputs/workspace/strumenti/esporta_run.m` | colonna `Composizione` in tutti i CSV; punteggi presi da `LIV(l).AGR` quando il workspace ha `LIV` | sui workspace dal 20 ottobre l'export **non era corretto**: (a) `fileparts` toglieva la cartella e le varianti omonime (`CER_5_5_0` in PA0…PA3) finivano mescolate sotto lo stesso nome; (b) dopo il ciclo per livelli `AGR` è quello dell'ultimo livello, mentre il ciclo correva su tutte le 76 comunità di `RESULTS`. Sui workspace vecchi il comportamento non cambia (colonna = PA0). **Non provato in MATLAB** (non disponibile qui): va lanciato una volta |
| `.gitignore` | `outputs/figures_tesi/` | come le altre cartelle di figure |
| `outputs/tables_tesi/` | nuova, versionata | i numeri dietro le figure e `controlli.txt` |

La logica delle simulazioni non è stata toccata.

**Struttura pronta per i dati in arrivo.**
- Un livello nuovo scritto da MAIN2 in `<tabelle>/<NOME>/sintesi/`, per esempio con PMI, entra
  da solo in F10 (si dispone su più righe se i livelli sono tanti). L'etichetta leggibile si
  aggiunge in `ETICHETTE_LIVELLO`.
- Un export con la colonna `Composizione` attiva F13 (valori grezzi appaiati fra livelli).
- Lo script si ferma con un messaggio se trova schede ripetute senza livello, cioè un export
  vecchio applicato a un run con PA.

---

## 3. Figure

Tutte in inglese, come la tesi. Larghezza 7,2", font 8 pt e colori dei metodi di
`method_color.m`, quindi coerenti con le figure MATLAB.

| Figura | Cosa mostra | Sostituisce o aggiunge |
|---|---|---|
| F01 `valori_grezzi` | valori grezzi in unità naturali, un punto per comunità colorato per fascia, mediana | grafico 1 (era media ± std) |
| F02 `profili_metodo` | profilo normalizzato di ciascun metodo sulle 8 metriche | grafico 2 |
| F03 `sintesi_metodi_metriche` | mappa metodo × metrica: mediana e [intervallo interquartile] | grafico 3 (12 barre d'errore sovrapposte) |
| F03b `sintesi_per_fascia` | la stessa mappa per fascia di penetrazione | nuova: mostra il cambio di regime |
| F04 `assi/penetrazione_*` (8) | metrica contro penetrazione, una linea per taglia, un pannello per metodo | scalabilità (era un punto per cella con std = 0) |
| F05 `assi/taglia_*` (8) | metrica contro taglia, una linea per fascia | scalabilità su n |
| F06 `scomposizione_varianza` | quota della varianza fra comunità spiegata da penetrazione, taglia e interazione | nuova |
| F07 `posta_in_gioco` | v(N) per membro e quanto un membro guadagna o perde scegliendo il metodo, in €/anno | nuova |
| F08 `compromessi` | coppie di criteri in unità naturali, per fascia | nuova (il fronte MATLAB è in punteggi) |
| F09 `quota_prosumer` | quota di v(N) ai prosumer rispetto alla loro quota di membri | nuova figura su una tabella esistente |
| F10 `effetto_composizione` | differenza **appaiata** di punteggio PAk − PA0, con la coerenza del segno | nuova |
| F11 `scala_e_quote_PA` | spostamento delle graduatorie contro il rapporto di scala v(N); quota ai membri PA | nuova |
| F12 `accordo_indicatori` | τ-b medio fra le 8 metriche, per fascia | nuova figura su `tau_per_cella.csv` |
| F13 `grezzi_<livello>` | valori grezzi con e senza PA, scheda per scheda | pronta, si attiva con l'export nuovo |

---

## 4. Verifiche effettuate

1. **La normalizzazione coincide con MATLAB.** Sul run griglia25, dove export e tabelle vengono
   dallo stesso run, `1 − (max − s)/(max − min)` ricalcolato dai punteggi orientati coincide con
   `rimpianto_per_comunita.csv` su 2 880 righe (scarto massimo 5·10⁻⁷, arrotondamento del CSV).
   Anche l'insieme delle righe scartate dalla soglia coincide.
2. **Coerenza fra export del 13 e tabelle del 20 ottobre.** La quota ai prosumer coincide
   esattamente (scarto 0) per 10 metodi su 11. Per il Tri-level EP lo scarto è 0,013, perché è
   stato rifatto il 20: lo script lo esclude in automatico dalle figure in valori grezzi e lo
   scrive in `controlli.txt`. Il controllo è stato provato anche con un export volutamente
   sbagliato, e lo rifiuta.
3. **Estremi.** In ogni coppia (comunità, indicatore) il migliore vale 1 e il peggiore 0. Ogni
   metrica discrimina in tutte le comunità di tutti i livelli (20/20/19/17).
4. **Errori trovati e corretti** nella mia prima versione:
   - std disegnata su punti fatti da una sola comunità;
   - 40% e 60% fusi nello stesso punto;
   - normalizzazione senza soglia di rilevanza;
   - nel confronto PA, appaiamento sulla «Fascia». La Fascia delle tabelle è il rango *dentro* il
     livello: in PA2 e PA3 mancano le schede a bassa penetrazione e gli stessi ranghi indicano
     schede diverse, quindi si perdevano 3 e 5 coppie. Ora si appaia sul nome della scheda.
     *Avvertenza per chi legge le tabelle `PAk/sintesi/*_fascia.csv`: le fasce non sono
     confrontabili fra livelli.*
5. **Export multi-livello.** Prima della modifica, `esporta_run.m` avrebbe prodotto un export
   sbagliato sul workspace del 20 ottobre (sezione 2).

---

## 5. Risultati

Ogni risultato è letto su cinque punti: dati, rilevanza, interpretazione, verifica, limiti.

### R1. La penetrazione domina, la taglia conta poco: un numero per la §7.6 (F06)

- **Dati.** Sulla griglia 5 × 4 di soli domestici la fascia di penetrazione spiega fra il 65%
  (Gini) e l'81% (forza incentivante) della varianza fra comunità dei punteggi normalizzati. La
  taglia ne spiega fra il 4% e il 10%, l'interazione fra l'8% e il 31%. Gli unici casi in cui la
  penetrazione conta poco sono strutturali: lo Shapley su eccesso e Gini, Nucleolo e VLC sul
  merito, dove sono sempre primi.
- **Rilevanza.** Risponde alla clausola «how sensitive are these rankings to size and
  penetration» con una quota di varianza invece di due conteggi di inversioni non confrontabili
  (il README avverte che 4 configurazioni contro 5 danno occasioni diverse di invertirsi).
- **Interpretazione.** Nell'intervallo 5–18 membri la graduatoria dipende da *chi* produce
  rispetto a chi consuma, non da quanti sono. Non è supportato estendere la conclusione a
  comunità più grandi.
- **Verifica.** Ripetere F06 sul run griglia25 (fino a 25, con l'AS) dopo averlo rifatto coi
  parametri del 20 ottobre.
- **Limiti.** Una comunità per cella, quindi il residuo è interazione e non rumore e non si può
  separarli. Le taglie sono annidate. La fascia è un rango (20% a n = 5, 28% a n = 18).

### R2. A penetrazione fissa la comunità è quasi «la stessa» a ogni taglia (F07, F04)

- **Dati.**
  - v(N) per membro varia pochissimo con la taglia a fascia fissa: coefficiente di variazione 4%
    alla fascia 2 e 7% alla 4; 5% alla fascia 1 escludendo n = 5, che ha un solo prosumer.
  - Le curve di F04 per n ≥ 8 si sovrappongono.
  - Quanto un membro può guadagnare o perdere scegliendo il metodo vale circa 66–73 €/anno alle
    fasce 1–2 a ogni taglia.
- **Rilevanza.** Dà un meccanismo plausibile al fatto che la taglia inverta poco le graduatorie:
  il gioco per membro è quasi invariante di scala.
- **Interpretazione.** Plausibile: una comunità più grande, alla stessa penetrazione, è vicina a
  una «copia» di quella piccola (stesse famiglie, annidate). Non supportato: che valga per
  famiglie diverse. L'annidamento, da solo, spinge verso questa somiglianza.
- **Verifica.** Repliche con altre famiglie (C1). Se l'invarianza regge anche con famiglie non
  annidate è un risultato forte; altrimenti è un artefatto del disegno.
- **Limiti.** n = 5 è il caso anomalo in quasi tutte le figure (F04, linea più chiara): con 1–3
  prosumer conta il singolo impianto.

### R3. Cambio di regime: le regole della teoria dei giochi cambiano segno sull'incentivo (F04, F09, F03b)

- **Dati.**
  - Forza incentivante (netta) dello Shapley negativa in 5 comunità su 5 alla fascia 20–30% (da
    −1,67 a −0,35), poi positiva (fino a +0,78).
  - Nucleolo e VLC negativi in 3 su 5 alla fascia 1, positivi in tutte le altre.
  - In parallelo (F09), il rapporto fra quota ai prosumer e quota di membri scende per lo
    Shapley da 1,3–2,7 alla fascia 1 a 0,35–0,64 alla fascia 3. Per Nucleolo e VLC scende da
    0,9–3,2 a 0,26–0,36. Attraversa 1 fra la fascia 1 e la 2.
  - Pearson Key, Similarity-Utilization e Proportional to Consumption restano positivi ovunque.
  - Il Cascading Tree è negativo fino all'80%.
- **Rilevanza.** È il risultato più «di tesi»: la stessa regola premia o penalizza il sincronismo
  a seconda della composizione. Risponde direttamente alla domanda su come le graduatorie
  dipendano dalla penetrazione.
- **Interpretazione.** Plausibile e coerente con la teoria: lo Shapley paga il contributo
  marginale, che sta dal lato scarso. Con pochi prosumer l'energia condivisa è limitata dalla
  produzione e i prosumer sono indispensabili; con molti prosumer è limitata dal carico e
  diventano preziosi i consumatori. Poiché sui profili netti i prosumer hanno virtuosità bassa,
  quando la regola premia loro la forza incentivante è negativa.
  - Va letto **insieme all'asse lordo**. Lì il segno negativo persiste alla fascia 1 (Shapley
    negativo in 4 comunità su 5), quindi non è solo l'artefatto dei profili netti del README
    §7.0-bis.
  - Ma al 100% tutte le regole non banali hanno allineamento lordo negativo, e non c'è un lato
    scarso: lì l'asse lordo misura altro. Non va presentato come «penalizzano il sincronismo».
- **Verifica.** Un indice continuo di scarsità al posto della penetrazione (C2). Il punto di
  attraversamento su più comunità fra il 30% e il 50%, oggi assenti.
- **Limiti.**
  - Fra 30% e 50% non c'è nessuna comunità: la soglia è *fra* questi valori, non localizzata.
  - Con 5 osservazioni annidate per fascia il segno è robusto per lo Shapley (5/5) e meno per
    Nucleolo e VLC (3/5).

### R4. Il conflitto uguaglianza–incentivo nasce sopra il 40% di penetrazione (F12, F08)

- **Dati.**
  - τ-b(Gini, forza incentivante): −0,14 alla fascia 1, con segno variabile fra le taglie (da
    −0,42 a +0,46); poi −0,76, −0,86, −0,91.
  - Merito e stabilità concordano sempre di più: τ(Fairness Index, eccesso) da 0,64 a 0,88.
  - L'allineamento lordo si stacca da tutti al 100%.
- **Rilevanza.** Qualifica il risultato del report del 20 ottobre («uniformità e incentivo sono i
  più in conflitto»): è vero sopra il 40%, mentre a bassa penetrazione i due criteri sono quasi
  indipendenti. Conta anche per il sottoinsieme minimo, perché i gruppi di indicatori dipendono
  dalla fascia.
- **Interpretazione.** È la stessa causa di R3: a bassa penetrazione le regole che premiano il
  sincronismo e quelle uniformi non si oppongono perché i prosumer scarsi rompono il legame fra
  quota e virtuosità.
- **Verifica.** Rifare il raggruppamento di `indicator_clusters` per fascia e vedere se il numero
  di gruppi cambia.
- **Limiti.** Media di 5 τ su 11 metodi: un τ di 0,1 corrisponde a poche coppie.

### R5. La stabilità dell'Equal Split è non monotona, e lo Shapley è quasi sempre fuori dal core (F04, F01)

- **Dati.**
  - Eccesso massimo dell'Equal Split: 2–7% di v(N) alla fascia 1, 12–21% alla 2, **28–44%** alla
    3, 11–17% al 100%. Stessa forma per Cascading Tree, Weighted Solidarity e Remuneration
    Model 1.
  - Lo Shapley ha eccesso positivo in 18 comunità su 20, quindi c'è sempre una coalizione
    bloccante, ma piccolo: mediana circa 3% di v(N), massimo 9,5% a n = 5.
  - Nucleolo e VLC hanno eccesso ≤ 0 ovunque, quindi il core non è vuoto.
- **Rilevanza.** Quantifica il costo in stabilità delle regole semplici e dice dove pesa: a
  penetrazione medio-alta, non agli estremi.
- **Interpretazione.** Plausibile: alla fascia 3 pochi consumatori sono il fattore scarso e una
  coalizione «consumatori + alcuni prosumer» ottiene da sola più di quanto le dà la ripartizione
  uniforme. Va verificata con le coalizioni effettivamente bloccanti, che non sono nell'export.
- **Verifica.** Esportare da `coalition_excess` la composizione della coalizione con eccesso
  massimo (A6).
- **Limiti.** Gioco calcolato fino a 18 membri.

### R6. La posta in gioco cambia di un ordine di grandezza (F07)

- **Dati.**
  - v(N) per membro: circa 59 €/anno alla fascia 1 e circa 7 €/anno al 100% di penetrazione.
  - La differenza media fra il metodo più e meno favorevole a un membro: circa 66–73 € alle
    fasce 1–2, 40–55 € alla 3, 7–9 € al 100%.
  - In rapporto alla quota uguale: 85–160%.
- **Rilevanza.** Le perdite fra criteri di `tradeoff_losses` sono in quota dell'escursione, e
  una perdita di 0,7 vale molto meno al 100% che al 25%. La domanda «how large are the
  trade-offs» chiede una grandezza, e questa è l'unità che la rende confrontabile.
- **Interpretazione.** Il 100% di penetrazione è un caso limite in cui quasi nulla è condiviso
  (circa l'1% dell'immissione). Le graduatorie lì sono corrette ma riguardano pochi euro.
- **Verifica.** Rifare la matrice delle perdite in €/membro (A3).
- **Limiti.** L'escursione esclude il Tri-level EP (export superato).

### R7. La composizione sposta le graduatorie, ma non come un semplice effetto di scala (F10, F11)

- **Dati.**
  - Spostamento medio |Δ punteggio| sulle 17 schede comuni ai tre livelli: 0,21 con PA1, **0,31**
    con PA2, 0,28 con PA3. PA2 sposta più di PA3 anche se v(N) cresce meno (mediana ×5,7 contro
    ×11,4).
  - Sommando i livelli, lo spostamento correla con la scala (Spearman 0,56). Dentro ciascun
    livello la correlazione è 0,59 con PA1 e **negativa** con PA2 (−0,30) e PA3 (−0,49).
  - Effetti grandi e coerenti in segno: il Cascading Tree guadagna in stabilità (+0,7) e merito
    con PA2 e PA3; Nucleolo e VLC perdono sull'allineamento netto (da −0,6 a −0,8); la
    Similarity-Utilization perde il primato sull'allineamento lordo (−1,0).
- **Rilevanza.** È la terza dimensione della domanda di ricerca. Il report del 20 ottobre segnala
  il problema della scala ma non lo misura.
- **Interpretazione.**
  - La correlazione aggregata è un paradosso di Simpson: riflette le differenze fra livelli, non
    la scala.
  - Ipotesi plausibile, non dimostrata: conta il *ruolo* del membro aggiunto. La scuola è un
    grande consumatore (107 MWh di carico contro 49 MWh di FV) e cambia il lato scarso; il
    palazzetto è soprattutto un produttore.
  - Non supportato: «la presenza di PA» come effetto unico. PA1, PA2 e PA3 sono membri diversi,
    non dosi diverse dello stesso trattamento.
- **Verifica.**
  - Disegno 2 × 2 forma × scala (sezione 6).
  - F13 con i valori grezzi, appena c'è l'export nuovo.
- **Limiti.**
  - Un solo edificio per tipo.
  - PA2 e PA3 senza schede a bassa penetrazione.
  - Tariffa unica, con errore massimo 7,9% di v(N).
  - Δ di punteggio relativo: un metodo può «perdere» perché un altro guadagna.

### Risultati che non reggono o vanno ridimensionati

- **Il Gini.** È l'indicatore con più interazione (31% di varianza residua) e meno spiegato dalla
  penetrazione. Le affermazioni del tipo «il Gini cresce con la penetrazione» valgono per alcuni
  metodi (Pearson Key, Similarity-Utilization: 0,31 → 0,65) e non per altri (Cascading Tree
  decresce).
- **Le differenze dentro il gruppo merito–stabilità** (Fairness Index contro σ contro eccesso)
  sono spesso sotto la soglia di rilevanza: τ fra 0,8 e 1.
- **Tutto il comportamento a n = 5** dipende da 1–3 impianti.

---

## 6. Proposte, in ordine di priorità

Legenda della solidità: ●●● fondata sui dati disponibili, ●● plausibile, ● speculativa.
Tipo: D = descrittiva, E = esplorativa, S = richiede un disegno sperimentale.

### A. Priorità alta: dati già disponibili

| # | Domanda | Metodo | Dati | Tipo, solidità |
|---|---|---|---|---|
| A1 | Quanto pesano penetrazione e taglia? | scomposizione della varianza a due vie, **fatta** (F06) | tabelle del 20 ottobre | D, ●●● |
| A2 | La stessa regola premia o penalizza il sincronismo? | F04 + F09 + segni per fascia, **fatta**; nel testo riportare il conteggio per segno, non la media | export + `quote_prosumer` | D, ●●● |
| A3 | Quanto valgono le perdite fra criteri in euro? | perdita ottimistica × escursione in €/membro per comunità, da `perdite_dettaglio.csv` × F07. Figura: matrice A → B in €/membro/anno per fascia | tabelle + export | D, ●●● |
| A4 | Il sottoinsieme minimo dipende dalla fascia? | `indicator_clusters` sul τ per fascia (`tau_per_cella`), da rifare in Python sui CSV | tabelle | E, ●● (R4 suggerisce di sì) |
| A5 | Come si leggono le perdite al 100%? | separare nel testo «graduatoria» e «posta»: tabelle per fascia con l'euro accanto alla quota | come A3 | D, ●●● |
| A6 | Chi blocca l'Equal Split alla fascia 3? | esportare la coalizione con eccesso massimo (`coalition_excess` già la calcola) | richiede il `.mat` (locale) | E, ●● |

### B. Priorità media: elaborazioni aggiuntive o run in corso

| # | Domanda | Metodo | Cosa serve | Tipo, solidità |
|---|---|---|---|---|
| B1 | Gli effetti della composizione in unità naturali | F13 | riesportare il run del 20 ottobre (e i nuovi) con `esporta_run.m` aggiornato | D, ●●● |
| B2 | La forma di R3–R5 vale fino a 25 membri? | F04–F06 sul run griglia25 | rifarlo coi parametri del 20 ottobre (circa 10 h, già tra le decisioni aperte) | D, ●● |
| B3 | Sensibilità dei punteggi alla soglia | F03 a soglie 0/5/10/20% (`sensibilita_soglia.m` lo fa per le inversioni) | rilancio del solo post-processing | D, ●● |
| B4 | Robustezza dei profili per metodo | togliere una taglia alla volta e misurare quanto si muove F03 | nessuno | E, ●● |
| B5 | Concordanza fra comunità | W di Kendall delle graduatorie fra le 20 comunità, per metrica | tabelle | D, ●● |

### C. Approfondimenti esplorativi

| # | Idea | Perché può valere | Costo | Solidità |
|---|---|---|---|---|
| C1 | **Repliche vere**: per ogni cella (n, fascia), 5–10 estrazioni diverse di famiglie dalla società da 100, a n ≤ 10 | è l'unico modo di avere una variabilità che giustifichi barre d'errore, intervalli bootstrap e test; verifica R2 (l'invarianza di scala è un artefatto dell'annidamento?) | Shapley 2¹⁰ per comunità: basso; a 18 membri alto | S, ●●● come necessità metodologica |
| C2 | **Indice continuo di scarsità** (immissione condivisa / immissione, oppure produzione / carico annui) al posto della penetrazione | se F04 e F10 collassano su una curva unica, penetrazione e composizione agiscono sullo stesso canale (quale lato è scarso): risultato originale | nessuna simulazione; servono i valori grezzi PA (B1) | E, ● (dentro PA0 l'indice coincide con la penetrazione, Spearman 0,92, quindi oggi non è testabile) |
| C3 | Elasticità vera della quota: perturbare il profilo di un membro e rileggere la quota | trasforma la forza incentivante da covarianza ex post a misura causale | n riesecuzioni per comunità; fuori dallo scope dichiarato | S, ● |
| C4 | Indicatore composito | **sconsigliato**: R3–R4 mostrano che i pesi relativi dei criteri cambiano segno con la penetrazione, e un indice unico nasconderebbe proprio il risultato. Meglio i 4 rappresentanti più la posta in euro | — | — |

---

## 7. Piano per la fase successiva

### 7.1 Integrare i run in corso

1. A fine run salvare il workspace e riesportare con `esporta_run.m` aggiornato. Va provato una
   volta, su un workspace vecchio e su uno nuovo. Controllare che `comunita.csv` abbia la colonna
   `Composizione`.
2. Lanciare `grafici_metodi.py` con `--tabelle` sulla cartella del run e `--export` sull'export
   nuovo. Livelli nuovi in `<tabelle>/<NOME>/sintesi/` entrano da soli in F10. Aggiungere
   l'etichetta in `ETICHETTE_LIVELLO`.
3. Leggere `controlli.txt` prima delle figure: livelli trovati, metodi esclusi, copertura degli
   indicatori.

**Avvertenze per i nuovi livelli.**
- F11 usa `confronto_PA/pa_effetti.csv` e assume livelli numerati `PAk`. Per livelli PMI serve un
  file analogo da `confronto_pa.m` (oggi specifico delle PA).
- Con le imprese diventano attivi la soglia del 55% sull'energia incentivabile e il fattore F
  (README §7.4–7.5): riportare la colonna `Binding` di `comunita.csv` **prima** di interpretare
  qualunque differenza. È anche uno dei TODO del gap.

### 7.2 La composizione come dimensione a sé

**Cosa misurare per non confonderla con penetrazione e taglia.**

| Indicatore | Distingue |
|---|---|
| quota del carico e quota della produzione dei membri non domestici | il *peso* della categoria, al posto del conteggio delle PA |
| rapporto produzione / carico della comunità (C2) | quale lato è scarso, cioè il canale di R3 |
| eterogeneità di forma (`shape_heterogeneity.m`, già calcolata e stampata) | membri con profili diversi |
| concentrazione dei volumi (Gini delle taglie dei membri) | uno o due membri molto grandi |
| quota di v(N) ai membri non domestici rispetto alla loro quota di membri (`RapportoQuotaPA`) | chi viene premiato |

**Metriche più esposte alla composizione,** secondo i dati di oggi (F10): stabilità (il least
core diventa sottile con due membri che valgono l'85%), merito, i due allineamenti e la quota per
categoria. Il Gini e la forza incentivante sono più stabili.

**Disegno consigliato, non fattoriale completo.**

| Passo | Cosa | Perché |
|---|---|---|
| 1 | **2 × 2 forma × scala**: aggiungere un membro con il *profilo* di una PA riscalato al volume di una famiglia, e un membro *domestico* riscalato al volume della PA | è il confronto che separa composizione e scala, che oggi sono confusi (R7) |
| 2 | **2 × 2 PA × PMI**: domestici, +PA, +PMI, +PA+PMI, a N, C, P fissi | l'interazione si misura come differenza delle differenze: Δ(PA+PMI) − Δ(PA) − Δ(PMI) per scheda |
| 3 | farlo su 4 celle e non su tutta la griglia: n ∈ {10, 18} × fasce 2 e 3 | la penetrazione spiega l'80% della varianza (R1) e la taglia poco, quindi due taglie bastano; le fasce 2–3 sono dove il segno di R3 è già stabile e la stabilità pesa di più (R5) |
| 4 | dove il budget lo consente, ripetere le celle con 3–5 estrazioni di famiglie (C1) | è l'unica via a un'incertezza difendibile |

**Aggregazioni.** Sempre appaiate per scheda (Δ rispetto al livello base). Riportare la coerenza
del segno, come in F10, invece di medie fra insiemi di schede diversi.

**Modifiche al modello.** Nessuna per i passi 1–2 se lo stesso generatore (`genera_varianti_PA.py`)
accetta un fattore di scala sul profilo. Per le imprese, verificare prima che lo scaglione
tariffario e la soglia vengano applicati come da norma, e non con lo scaglione unico imposto per
il palazzetto.

---

## 8. Cosa non si può concludere oggi, e cosa servirebbe

| Affermazione | Perché non è verificabile | Cosa servirebbe |
|---|---|---|
| «i risultati valgono per comunità reali in generale» | una società, un anno, una zona, famiglie annidate | C1 e almeno un secondo anno o una seconda zona |
| «la taglia non conta» | solo 5–18 membri e famiglie annidate | B2 e C1 |
| «la presenza di PA cambia le graduatorie *perché* cambia la composizione» | composizione e scala confuse; un edificio per tipo | 2 × 2 forma × scala |
| «la regola X induce comportamenti virtuosi» | la forza incentivante è una covarianza ex post, non una risposta comportamentale | C3 o un modello di risposta |
| soglia di regime fra 30% e 50% | nessuna comunità in quell'intervallo | 2–3 schede a 35–45% per taglia |
