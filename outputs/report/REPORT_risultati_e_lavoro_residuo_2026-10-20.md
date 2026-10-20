# Report sui risultati della tesi e sul lavoro che manca

Aggiornato al 20 ottobre 2026. Linguaggio semplice, pensato per essere letto anche da chi non conosce il codice. I numeri vengono da `outputs/tables_main2/` (run del 20 ottobre, 76 comunità) e dalla pagina `recap_run_fino18_PA_2026-10-20.html`, che ha i grafici.

---

## 1. In una frase

Abbiamo costruito un simulatore che prende comunità energetiche di famiglie (con e senza edifici pubblici), divide l'incentivo CER con 12 regole diverse e le giudica con gli stessi indicatori. Il risultato principale è che **non esiste una regola migliore su tutto**: cambia con ciò che si vuole ottenere e, in parte, con com'è fatta la comunità.

---

## 2. Cosa abbiamo fatto, in parole semplici

- **Il problema.** In una comunità energetica chi produce con il fotovoltaico condivide energia con chi consuma, e lo Stato paga un incentivo sull'energia condivisa. La legge non dice come dividerlo fra i membri.
- **Le comunità.** 76 comunità simulate, da 5 a 18 membri, con quote diverse di chi ha il fotovoltaico (dal 20% al 100%). Quattro livelli di composizione: solo famiglie, oppure con 1, 2 o 3 edifici pubblici (comune, scuola, palazzetto dello sport di Lucca). Le famiglie sono simulate ora per ora per un anno.
- **Le regole di divisione.** 12 regole: alcune dalla teoria dei giochi (Shapley, Nucleolo, Variance Least Core), alcune semplici (parti uguali, in proporzione al consumo), alcune che premiano chi consuma quando gli altri producono (Pearson Key, Similarity-Utilization), altre dalla letteratura sulle comunità italiane.
- **I criteri per giudicarle.** Uguaglianza (tutti ricevono simile?), merito (chi contribuisce di più riceve di più?), stabilità (a qualche sottogruppo conviene uscire?), forza incentivante (la regola premia il comportamento "virtuoso"?) e il rendimento dell'investimento del membro messo peggio.

---

## 3. I risultati principali

### 3.1 Nessuna regola vince su tutto

| Se voglio… | La regola migliore è… |
|---|---|
| che tutti ricevano uguale | Equal Split (parti uguali) |
| che nessun gruppo voglia uscire (stabilità) | Nucleolo e Variance Least Core (le regole "stabili" della teoria dei giochi) |
| premiare chi consuma quando gli altri producono | Similarity-Utilization e Pearson Key |

Le regole migliori su un criterio sono quasi sempre pessime su un altro. Esempi (perdita da 0 = nessuna a 1 = come la regola peggiore):

| Scelgo la migliore su… | …e perdo su… | Perdita |
|---|---|---:|
| uguaglianza | stabilità | 0,72 |
| uguaglianza | incentivo | 0,79 |
| incentivo | uguaglianza | 0,93 |
| incentivo | stabilità | 0,29 |
| stabilità | uguaglianza | 0,61 |
| stabilità | merito | 0,00 |

Quindi: **uguaglianza e incentivo sono i due criteri più in conflitto**; merito e stabilità vanno d'accordo.

### 3.2 La classifica cambia con la composizione della comunità

Per una coppia di regole, "si inverte" vuol dire che cambiando la comunità passa avanti l'altra.

| Cosa cambia | Quota di coppie che si invertono |
|---|---:|
| la quota di chi ha il fotovoltaico (a parità di membri) | 18-27% |
| il numero di membri (a parità di quota) | 0,5-15% |
| si aggiungono edifici pubblici (da solo famiglie a 1, 2 o 3 edifici) | 11% a coppie, 23% lungo tutti i livelli |

In parole semplici: **per circa una coppia di regole su quattro o cinque, quale sia la migliore dipende da quanti hanno il fotovoltaico**. Il numero di membri conta meno. La presenza di edifici pubblici conta come un cambio di quota di fotovoltaico, ma non di più.

### 3.3 Con gli edifici pubblici

- Il primo classificato non cambia mai su uguaglianza e stabilità; cambia nel 64% dei casi per un indicatore tecnico (l'allineamento lordo) e nel 27% per uno dei due indicatori di merito.
- Chi sceglie la regola più incentivante perde molto di più in stabilità quando ci sono gli edifici pubblici: la perdita passa da 0,26-0,29 a **0,71-0,74** con 2 o 3 edifici.
- Gli edifici pubblici prendono più della loro quota di membri: con la regola di Shapley circa 2 volte con 1 edificio, 4 volte con 2, 3 volte con 3. Le regole "premio al consumo" danno invece ai prosumer quasi nulla (quota sotto un quinto).

### 3.4 Quanti indicatori bastano

Gli 11 indicatori si raggruppano in 4 gruppi che dicono più o meno le stesse cose. Ne bastano 4: uno per l'uniformità, uno per merito e stabilità, uno per la forza incentivante e uno per il suo controllo sui profili lordi. Con questi quattro si ricostruisce l'ordine delle regole (concordanza 0,95-0,99 nelle comunità di solo famiglie), ma **non** si ricostruiscono sempre le regole "non dominate" (il fronte di Pareto coincide in 9 comunità su 20 con solo famiglie e in 0 su 17 con 3 edifici).

### 3.5 Una nota tecnica che conta

Con gli edifici pubblici il montepremi cresce di molto (11 volte con 3 edifici). Una differenza fra livelli può quindi dipendere anche dalla scala e non solo dalla composizione.

---

## 4. Cosa non è stato ottenuto (limiti)

1. **L'inclusione dei vulnerabili non è valutabile.** Con i redditi Istat e la soglia di povertà vera (13.237 € per adulto equivalente) nessuna famiglia simulata risulta vulnerabile. Il criterio "inclusione" è quindi vuoto, e le regole pensate per aiutare i vulnerabili (Tri-level EP, Weighted Solidarity) non mostrano il loro scopo.
2. **La composizione è solo "con o senza edifici pubblici".** Non ci sono imprese, quindi le regole del decreto (riduzione della tariffa, soglia del 55% dell'energia incentivabile) sono implementate ma non hanno effetto in nessuna comunità simulata.
3. **Dimensioni modeste.** Le comunità arrivano a 18 membri (la stabilità non si calcola oltre). La letteratura chiede "decine o più".
4. **Una sola società simulata.** Cento famiglie lombarde, un anno, una zona: nessun intervallo di confidenza, e i risultati sono evidenza su un caso, non dimostrazioni.
5. **Dati che sono ricostruzioni.** Il palazzetto è ricostruito da grafici; per le PA si usa una tariffa unica (errore massimo 7,9% sul montepremi a 3 edifici); il gas delle famiglie non varia per tipologia.
6. **Non si studia il comportamento.** Non sappiamo se chi è premiato cambierebbe davvero abitudini: la tesi misura cosa premia ogni regola, non come reagiscono i membri.

---

## 5. Cosa manca per finire

### 5.1 Decisioni tue (poche, ma bloccano il testo)

| Decisione | Opzioni |
|---|---|
| Tri-level EP | tenerlo (ora senza la fetta di solidarietà, equivale a due livelli) oppure escluderlo |
| Run a 25 membri (circa 10 ore) | rifarlo con i parametri nuovi e le PA, oppure ridimensionare nel testo la frase "decine di membri" |
| Inclusione | toglierla dalla domanda di ricerca e dichiararla limite (la tua scelta di ieri), mantenendo la nota che Couraud ha lo stesso limite |
| Mappa o strumento | la tesi consegna una mappa dei compromessi più un insieme minimo di 4 indicatori, non una metrica unica |
| Famiglia "prezzi dinamici" (2.2.4) | esclusa perché presuppone un prezzo interno che il caso italiano non ha, da confermare con il tuo Cap. 2 |

### 5.2 Verifiche sulle fonti

- Prezzo all'ingrosso 2025 (PUN): da confermare sul GME.
- Prezzi ARERA 2025: ricontrollare sul volume.
- Testi ufficiali del DM 127/2025, del DM 414/2023 e delle Regole Operative GSE (e la loro data, discordante fra le fonti).
- Regola per i percettori nei nuclei senza occupati (uno) e per la collaboratrice domestica (non conta): confermare.

### 5.3 Testo

1. **Riscrivere il gap (§2.6)** in coerenza con i risultati: togliere l'inclusione, qualificare il sottoinsieme minimo ("conserva le graduatorie, non i fronti"), definire la composizione come presenza di edifici pubblici, aggiornare il numero di regole (12; 11 nell'analisi fino a 18 membri), chiudere i quattro commenti TODO. Il gap è già scritto, ma va allineato.
2. **Capitoli da scrivere** (dallo stato di agosto, da verificare): Introduzione, Metodologia, Simulazione e risultati, Discussione e conclusioni. Il materiale c'è: README, `GUIDA_modelli_distribuzione.md`, le tabelle e il recap.
3. **Bibliografia:** a luglio il file `.bib` aveva 37 chiavi su 64 citate: da completare.
4. **Limiti e minacce alla validità** (sezione 4 di questo report): vanno nel testo come parte del lavoro, non come ripensamenti.

### 5.4 Chiusura del progetto

- Aprire la pull request verso `main` e fare il merge.
- Togliere dalle schede il commento "BOZZA" ormai falso.
- Decidere come rendere riproducibile un clone pulito: profili di carico e file FV non sono versionati.
- Rigenerare il recap e le tabelle se rifai uno dei run.

### 5.5 In che ordine lo farei

1. Le decisioni della sezione 5.1.
2. Il gap riscritto (sezione 5.3, punto 1): da lì discendono i capitoli.
3. Il capitolo dei risultati, usando le tabelle e il recap.
4. Metodologia e Simulazione (il codice è fermo e documentato).
5. Le verifiche sulle fonti e la bibliografia.
6. Introduzione e conclusioni, per ultime.
7. Chiusura del repository.

Il lavoro di calcolo è sostanzialmente finito. Quello che resta è soprattutto scrittura, qualche verifica di fonti e quattro decisioni.
