# Repliche dei partecipanti

Servono a capire se i risultati dipendono da **quali famiglie** stanno nelle comunità, a parità di
composizione dichiarata. Ogni replica è la griglia di schede di sempre (solo domestici, PA, imprese)
con famiglie diverse.

**Stato al 30 ottobre 2026:**
- blocco **5-15 membri** fatto: 20 repliche più l'identità, tutti i livelli, risultati sotto;
- comunità **da 18 membri** in corso, con v(S) a blocchi (fase 1, in fondo);
- blocco **20-25** con la stabilità estesa: da scrivere (fase 2).

## Perché servono

Le schede da 5 a 25 membri dichiarano in `[MEMBRI].archetipo` la composizione ISTAT della comunità:
numero di componenti × condizione occupazionale, con allocazione a resto maggiore su AVQ 2024 e
Censimento 2021 ([composizione_cer_scalata.md](../outputs/tables/composizione_cer_scalata.md),
`tipologie_famiglie.py`). Il profilo di carico di `household_k`, però, è la k-esima colonna di
`100_utenti.csv` (`N_utenti.xlsx` = prime N colonne). Quel file segue l'ordine di
`simulation_config.lombardia100.yaml`, che mette per prime le 38 famiglie di una persona.

Risultato: **fino a 25 membri le famiglie simulate sono tutte persone sole**. Le famiglie con la
cella dichiarata sono 0 su 5, 0 su 8, 0 su 10, 1 su 15, 1 su 18, 2 su 20 e 3 su 25. Vale per tutte
le 295 comunità dei run del 27-28 ottobre: le schede con PA e imprese usano le stesse colonne.

Effetti misurati:
- la CER da 25 membri consuma 42.545 kWh l'anno invece dei circa 59.200 attesi (−28%);
- i membri consumano tutti fra 1,6 e 1,8 MWh l'anno; con le celle dichiarate si va da 1,6 a 5,0;
- gli impianti FV sono dimensionati sulla famiglia dichiarata, non su quella simulata.

La quota di consumo fra le 9 e le 17 cambia poco (41,5% contro 40,5%).

## Come è fatta una replica

`genera_repliche.py`, con seed `(20261029, replica, cella)`:

- **Estrazione.** Per ogni cella una permutazione casuale delle famiglie del pool da cento. La CER
  da N membri prende, cella per cella e nell'ordine dei membri, le prime famiglie della
  permutazione. Quindi:
  - le stesse famiglie stanno in tutte le fasce di penetrazione e in tutti i livelli PA/ND di una
    taglia;
  - le taglie sono annidate: le famiglie della CER da 5 sono anche in quella da 8, e così via fino a
    25.

  Il generatore si ferma se uno dei due vincoli non vale.
- **Attributi.** Archetipo, componenti, percettori e scala di equivalenza vengono dalla scheda da 100
  membri, dove archetipo e profilo coincidono. Reddito e gas li ricalcola `arricchisci_schede.py`.
  Il fattore di reddito resta legato al nome del posto; la base Istat segue l'archetipo estratto.
- **Impianti FV.** Seguono il numero di componenti: 3,4 / 4,2 / 5,9 kWp. Cambiano di classe solo
  quando si estrae CHR19 (coppia con collaboratrice, 3 componenti in una cella da 2). Nelle repliche
  1-20 fino a 15 membri succede in 2 repliche su 20.
- **Varianti PA e ND.** Si ricavano dalle schede della replica con le funzioni di
  `genera_varianti_PA.py` e `genera_varianti_IND.py`, importate senza modifiche.
- **r00 = identità.** Stesse famiglie e profili delle schede originali. È il controllo del
  meccanismo: il generatore verifica che schede, profili e insieme delle varianti coincidano con gli
  originali.

Cartelle (non versionate, si rigenerano dal seed): `rNN/CER_configuration`,
`rNN/CER_configuration_PA`, `rNN/CER_configuration_IND`, più `rNN/estrazione.csv` con
l'abbinamento posto → famiglia.

## Comandi

```bash
# schede delle repliche (1-2 min per 20 repliche); --min-membri per aggiungere un blocco
venv/Scripts/python.exe -I CER_repliche/genera_repliche.py --repliche 0-20 --max-membri 15
# MAIN2 su una lista di repliche, una dopo l'altra (due liste in parallelo, non di piu')
bash CER_repliche/lancia_repliche.sh fino15 1 15 1 3 5 7 9 11 13 15 17 19
bash CER_repliche/lancia_repliche.sh fino15 1 15 2 4 6 8 10 12 14 16 18 20
# aggregazione: outputs/repliche/fino15/aggregato/
venv/Scripts/python.exe -I CER_repliche/aggrega_repliche.py --blocco fino15
```

`lancia_repliche.sh <blocco> <min_membri> <max_membri> <repliche...>` chiama MAIN2 con
`MAIN2_RADICE=CER_repliche/rNN`. Con `min_membri` > 1 gli passa in `MAIN2_SCHEDE` le schede della
replica in quell'intervallo, in tutti i livelli. Per ogni replica salva in
`outputs/repliche/<blocco>/rNN/`:
- tabelle e checkpoint;
- workspace (`RESULTS`, `AGR`, `LIV`, …);
- export (`esporta_run_livelli.m`);
- log.

Se MAIN2 si ferma, riprova una volta dal checkpoint. Le repliche già fatte si saltano.
`outputs/repliche/<blocco>/avanzamento.txt` ha una riga per replica. **Non modificare
`lancia_repliche.sh` mentre gira:** bash rilegge il file a fine ciclo.

## Lettura unita dei blocchi: un solo Shapley

I blocchi si dividono per taglia solo per non fare un'unica esecuzione di molte ore: si leggono
insieme. Fra 18 e 20 membri cambia una cosa. Fino a 18 MAIN2 calcola lo Shapley esatto. Da 20 in su
non lo calcola, e l'Adaptive Sampling Shapley (AS, Cremers et al. 2023) ne prende il posto:
- come sostituto nell'analisi (README §7.6.1);
- come riferimento della tabella di redditività `Tfin` (MAIN2 §3v).

Senza un accorgimento, l'analisi fra comunità di un run che mescola le due taglie tiene i soli
metodi comuni a tutte (`compute_indicator_agreement.m`). Resterebbe l'AS ovunque e lo Shapley esatto
da nessuna parte, anche dove c'è. **È ciò che è successo nel run unito del 28 ottobre**
(`tables_main2_fino25_unito/`).

Ora la regola è: **un solo metodo "Shapley", esatto fino a 18 membri, AS da 20 in su**; l'AS non
compare dove c'è l'esatto.
- `outputs/workspace/strumenti/unisci_shapley_as.m`: nelle comunità senza Shapley esatto rinomina
  l'AS in "Shapley" in tutti i campi che portano il nome del metodo (`metodi`, `Tfair`, `forza`,
  `forzaLorda`, `soglia`, le colonne di `Tcmp` e `Tfin`). Lascia `fase1`, cioè il confronto AS
  contro esatto, e alla fine controlla che il nome dell'AS non compaia altrove. Con lo Shapley in
  tutte le comunità, MAIN2 esclude l'AS da sé (§7b).
- `unisci_blocchi.m`:
  1. unisce i `RESULTS` di più blocchi nell'ordine di `elenco_schede_cer.m`;
  2. si ferma su doppioni e mancanti;
  3. applica `unisci_shapley_as`;
  4. scrive un checkpoint.

  MAIN2 con `MAIN2_RIPRENDI=1` rifà poi la sola analisi fra comunità (circa 30 s).

**Prova sul run unito del 28 ottobre** (295 comunità, `outputs/repliche/prova_regola_shapley/`):

```bash
matlab -batch "addpath('CER_repliche'); addpath('outputs/workspace/strumenti'); unisci_blocchi('', 'outputs/workspace/run_2026-10-28_fino25_unito.mat', 'prova_regola_shapley', 25)"
MAIN2_RIPRENDI=1 MAIN2_MAX_UTENTI=25 MAIN2_IND=1 MAIN2_CARTELLA=prova_regola_shapley matlab -batch "MAIN2"
mv outputs/tables_main2_prova_regola_shapley outputs/repliche/prova_regola_shapley/tables
venv/Scripts/python.exe -I CER_repliche/confronta_regola_shapley.py outputs/tables_main2_fino25_unito outputs/repliche/prova_regola_shapley/tables
```

Esito in `confronto_con_fino25_unito.txt`; tabelle e `.mat` restano locali.
- MAIN2 stampa "Fuori dall'analisi - metodi: Adaptive Sampling Shapley", e i 10 metodi sono gli
  stessi di prima con "Shapley" al posto dell'AS.
- **Vincitori.** L'insieme dei primi a pari merito cambia in **20 celle su 3245 (0,6%)**: tutte a 15
  o 18 membri (più una a 5 e una a 10), tutte nei livelli con PA o imprese, nessuna nel livello base.
  Sono quasi sempre pareggi che si allargano o si restringono; 11 riguardano `AllineamentoVirtu_lordo`.
- **τ medio per fascia:** cambia al più di 0,014, nessun segno si inverte.
- **Perdite di trade-off e rimpianto:** cambiano al più di 0,0024 e di 0,0035.

Le conclusioni del rapporto del 28 ottobre non cambiano. Le tabelle ufficiali di
`tables_main2_fino25_unito/` restano quelle di prima, con l'AS ovunque.

## Controlli fatti (29 ottobre 2026)

1. **Senza `MAIN2_RADICE`, MAIN2 non cambia.** Ho preso 6 schede (5-15 membri, con PA e imprese) e
   confrontato le tabelle prima e dopo la modifica: 40 su 40 identiche al byte.
2. **Con `MAIN2_RADICE=CER_repliche/r00`, le stesse 6 schede danno gli stessi risultati.**
   - Le tabelle sono identiche al byte, anche se i profili arrivano da CSV invece che da xlsx.
   - `RESULTS` è identico in tutti i 25 campi confrontati.
   - Membri e impianti della `CFG` sono identici; cambiano solo i percorsi, per costruzione.
3. **La replica identità rigenera le 295 schede di oggi** (28 base + 267 varianti):
   - schede identiche cella per cella;
   - profili delle varianti identici al byte;
   - `arricchisci_schede.py` le lascia invariate.
4. **r00 rifatta per intero fino a 15 membri riproduce il run del 27 ottobre:** 105 comunità, v(N)
   identico; scarti relativi al più 7,6e-08 (`Tcmp`, VLC), 4,6e-08 (`Tfair`), 2,2e-09 (VAN).
5. **Le 21 repliche del blocco 5-15 sono complete:** 410 tabelle ciascuna, workspace ed export,
   nessun warning, nessuna ripresa dal checkpoint. 15-18 minuti per replica, con due in parallelo.
6. **La regola dello Shapley regge sul run unito del 28 ottobre** (sezione sopra).

## Risultati del blocco 5-15 membri (29 ottobre 2026)

105 comunità per replica:
- 16 del livello base (taglie 5, 8, 10 e 15 × 4 fasce di penetrazione);
- 44 varianti con PA (PA1-PA3);
- 45 con imprese (ND1-ND3 e ND{k}_PA{p}), che fino a 15 membri esistono solo a 15.

r00 è il disegno di prima: tutte persone sole. I numeri completi sono in
[`outputs/repliche/fino15/aggregato/sintesi.md`](../outputs/repliche/fino15/aggregato/sintesi.md) e
nei CSV accanto.

**Tengono:**
- **I tre poli.** Quota delle celle del livello base, su tutte le repliche, in cui il metodo è fra i
  primi:
  - su Gini, l'Equal Split (100%);
  - su merito e stabilità, Variance Least Core e Nucleolo (92-100%);
  - sulla forza incentivante, Pearson Key e Tri-level EP (96% e 94%).
- **Il capovolgimento con la penetrazione, in 20 repliche su 20.**
  - τ(Gini, forza incentivante) scende di almeno 0,3 dalla fascia 1 alla 4: mediana da −0,19 a
    −0,86 (r00: da −0,07 a −0,91).
  - τ(Fairness Index, forza incentivante) è negativo nella fascia 1 e positivo nella 3 (mediana
    −0,59 e +0,42; r00 −0,60 e +0,45).
- **Il trade-off più caro resta uguaglianza contro incentivo.**
  - Scegliere Gini fa perdere 0,80 della forza incentivante (0,76-0,82; r00 0,79).
  - Scegliere l'incentivo fa perdere 0,86 di Gini (0,83-0,89; r00 0,92).
  - Merito e stabilità non si fanno concorrenza (perdita 0,00).
- **La composizione pesa poco.** Rispetto al livello base, PA e imprese invertono il 5-13% delle
  coppie di metodi (mediane per livello), contro il 9-15% di r00.

**Cambia:**
- **Una parte della varianza va ai partecipanti.** Quali famiglie ci sono spiega il 15-30% della
  varianza dei punteggi del livello base. Tranne che per l'allineamento lordo (punto sotto):
  - la penetrazione resta il primo fattore (46-70%, r00 61-85%);
  - la taglia sta al più all'11%.
- **L'allineamento lordo (`AllineamentoVirtu_lordo`) dipendeva dalle persone sole.**
  - Con famiglie vere la penetrazione ne spiega il 5% della varianza, invece dell'85%. Vale per
    tutti e 12 i metodi (2-14%).
  - Contano la taglia (34%), l'interazione (31%) e i partecipanti (30%).
  - Il vincitore coincide con quello di r00 solo nel 37% delle celle.

  L'indicatore misura quanto la ripartizione segue il consumo nelle ore di sole sui profili lordi, e
  quel consumo dipende da chi è la famiglia: con persone sole quasi uguali non poteva emergere.
- **Al 100% di prosumer il legame merito-incentivo si scioglie.**
  - τ(Fairness Index, forza incentivante) in fascia 4 ha mediana 0,06 (da −0,12 a 0,34; r00 0,35):
    il segno della mediana vale in 14 repliche su 20.
  - τ(Gini, Fairness Index) in fascia 4 è −0,29 in r00 e +0,05 di mediana.
- **Lo Shapley vince più spesso sulla stabilità.** È fra i primi sull'eccesso massimo nell'89%
  delle celle (r00 69%) e sulle coalizioni instabili nel 46% (r00 31%).
- **Inversioni lungo gli assi.**
  - Lungo la penetrazione sono un po' meno: mediana 14-25% secondo la taglia, contro 21-27%.
  - Lungo la taglia sono di più nelle fasce 2-4: mediana 5-15%, contro 0-8%.
- **Vincitori.** Il vincitore della cella è lo stesso in 69-99% delle repliche, secondo
  l'indicatore. Coincide con quello di r00 nel 37-100% delle celle. Almeno un primo in comune con
  r00 c'è nel 91-100% dei casi.

## Blocco 18-25 membri, in due fasi (dal 30 ottobre 2026)

**Fase 1: le comunità da 18 membri** (63 a replica, r00 compresa), con v(S) a blocchi.
- **La modifica.** `MAIN2.m` calcola v(S) con `cer_coalition_values_blocchi.m`, l'algoritmo che il
  VLC usava già da 19 a 25 membri, invece del ciclo di `cer_coalition_values.m`. A 18 membri v(S)
  passa da 50-56 s a 0,4-1,1 s.
- **Test di unità** (`test_cer_coalition_values_blocchi.m`): sui giochi sintetici da 1 a 16
  giocatori, con e senza F e nei casi limite, v(S) coincide con il ciclo entro 2e-15. Con la v(S)
  nuova il VLC dà la stessa allocazione bit per bit.
- **Regressione** (`outputs/repliche/controlli_fase1/`): 12 schede di r00 (le 6 di sempre più 6 da
  18 membri, con PA e imprese), prima e dopo.
  - Le 44 tabelle sono identiche al byte.
  - `RESULTS` resta entro 8e-14 relativo, con v(N) identico.
  - Il tempo totale scende da 7 min 07 s a 1 min 29 s.
- Comando: `bash CER_repliche/lancia_repliche.sh da18 18 18 <repliche...>`, due liste in parallelo.

**Fase 2: 20-25 membri, con l'AS al posto dello Shapley e la stabilità (eccesso di coalizione)
estesa fin lì.** Va ancora scritta: serve una versione dell'eccesso di coalizione senza matrice di
incidenza, che a 25 membri peserebbe 6,7 GB.

**Prova di scalabilità a 25 membri** (29 ottobre, `outputs/repliche/prova_scalabilita/`, stessa
scheda r01/CER_6_19_0 in ogni istanza):

| Configurazione | 25 membri | 18 membri (CER_4_14_0, ciclo vecchio) |
|---|---|---|
| Da sola | 2 min 31 s | 1 min 23 s |
| Due istanze da 25 insieme | 4 min 48 s ciascuna | — |
| Una da 25 e una da 18 insieme | 2 min 39 s | 2 min 07 s |

- **Il parallelo non aiuta a 25 membri.** Il VLC è limitato dalla banda verso la RAM, non dai core:
  ogni passo dell'enumerazione scorre matrici 4.400 ore × 256 coalizioni, troppo grandi per la
  cache. Con due istanze la CPU sale dal 36% al 79%, ma il lavoro fatto è lo stesso.
- **Ogni istanza occupa 2,1-2,2 GB.**
- **Tempo della fase 2:** la parte a 25 membri va di fatto in serie. 21 repliche × 64 comunità ×
  circa 150 s fanno circa 56 h; la seconda istanza può fare intanto le comunità da 20.

**Lettura unita**, per ogni replica NN, dopo le due fasi:

```bash
matlab -batch "addpath('CER_repliche'); addpath('outputs/workspace/strumenti'); unisci_blocchi('CER_repliche/rNN', {'outputs/repliche/fino15/rNN/checkpoint.mat', 'outputs/repliche/da18/rNN/checkpoint.mat', 'outputs/repliche/da20a25/rNN/checkpoint.mat'}, 'repNN_unito', 25)"
MAIN2_RIPRENDI=1 MAIN2_RADICE=CER_repliche/rNN MAIN2_MAX_UTENTI=25 MAIN2_IND=1 MAIN2_CARTELLA=repNN_unito matlab -batch "MAIN2"
```

Note:
- Con `maxUtenti` 18 si ottiene la vista fino a 18 membri, con il Nucleolo.
- **r00 va rifatta anche a 20-25:** nel run del 28 ottobre la stabilità a quelle taglie non c'è.
- `aggrega_repliche.py` va esteso a leggere le cartelle `repNN_unito`. Oggi legge
  `outputs/repliche/<blocco>/rNN/tables`.
