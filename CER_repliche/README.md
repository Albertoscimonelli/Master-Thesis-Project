# Repliche dei partecipanti

Servono a capire se i risultati dipendono da **quali famiglie** stanno nelle comunità, a parità di
composizione dichiarata. Ogni replica è la griglia di schede di sempre (solo domestici, PA, imprese)
con famiglie diverse.

**Stato al 3 novembre 2026: finito.**
- 20 repliche più l'identità r00, ciascuna con le 295 comunità da 5 a 25 membri (solo domestici,
  PA, imprese), simulate in tre blocchi di taglia (5-15, 18, 20-25) e poi lette insieme (lettura
  unita 5-25, `outputs/repliche/unito/`).
- **I risultati della tesi sono l'analisi completa sulle repliche r01-r20** (sezione
  "Risultati dell'analisi completa", sotto): 328 conclusioni su 334 reggono in almeno 15 repliche
  su 20, e dipende dai partecipanti solo l'allineamento lordo.
- r00 riproduce le schede originali, con le famiglie tutte persone sole: serve solo come controllo
  del meccanismo e non entra nei risultati.

## Analisi completa: un solo comando (dal 3 novembre 2026)

Dalla root del progetto, in Git Bash, sul PC del run (servono le tabelle di MAIN2 di ogni
replica, in `outputs/repliche/unito/rNN/tables/`, che restano locali):

```bash
bash CER_repliche/analisi_finale.sh
```

Fa tutto, in ordine, e si ferma al primo passo che fallisce dicendo quale. Registro in
`outputs/tesi_finale/analisi_finale.log`. Piano e scelte in `docs/analisi_finale/`.

| Passo | Script | Uscita |
|---|---|---|
| 1 | `unisci_repliche.sh` (MATLAB) | lettura unita 5-25, **solo** per le repliche che non l'hanno: il 3 novembre è fatta per tutte, quindi si salta |
| 2 | `salva_tabelle_analisi.py` | `unito/rNN/tabelle/`: le tabelle di MAIN2 che servono all'analisi (circa 4 MB a replica, versionate) |
| 3 | `controlla_unito.py` | `unito/controlli.txt`: 295 comunità, 10 metodi, stabilità a tutte le taglie |
| 4 | `aggrega_repliche.py --blocco unito --attese 21` | `unito/aggregato/`: CSV, `sintesi.md`, `robustezza.csv`, `van.csv`, `soglia.csv`, `quote_prosumer.csv` |
| 5 | `grafici_repliche.py` | `outputs/tesi_finale/figure/` (G01-G13, PNG e PDF) |
| 6 | `unisci_per_figure.py` + `grafici_metodi.py` | `outputs/tesi_finale/figure_descrittive/` (F01-F13 su tutte le repliche) |
| 7 | `tesi_finale.py` | `outputs/tesi_finale/rapporto.html` (figure), `numeri_tesi.tex`, `tabelle/*.tex`, `conclusioni.csv` |
| 8 | `rapporto_repliche.py` | `outputs/report/RISULTATI_repliche_<data>.html`, il rapporto commentato |

Con `tabelle/` committate l'analisi si rifà su qualunque PC: `aggrega_repliche.py` legge `tables/`
se c'è, altrimenti `tabelle/`. Istruzioni complete in `docs/analisi_finale/COME_RIFARE_L_ANALISI.md`.

Regole (versione B del piano):
- **Metodi.** 10, gli stessi da 5 a 25 membri: niente Nucleolo, un solo Shapley (esatto fino a 18,
  AS oltre). La regola è in `stile_tesi.un_solo_shapley`.
- **Repliche.** I risultati sono le repliche r01-r20. r00 (persone sole) non entra in figure,
  numeri e confronti.
- **Lettura dei risultati.** Una conclusione regge se vale in almeno 15 repliche su 20, si inverte
  con 5 o meno, altrimenti dipende dai partecipanti. Per ogni conclusione ci sono anche il
  controllo a metà (r01-r10 contro r11-r20) e il bootstrap.
- **Colori.** Palette Polimi in `stile_tesi.py`, validata per daltonismo e contrasto.

Altri comandi:
- `python -I CER_repliche/prove/banco_prova.py --dest /tmp/banco --repliche 0-6`, poi
  `bash CER_repliche/analisi_finale.sh --radice /tmp/banco --attese 7 --out /tmp/banco/tesi`, provano la
  catena sui file versionati, senza MATLAB. Nel banco di prova due controlli di integrità
  falliscono di proposito: le tabelle di prova sono quelle del 28/10, senza stabilità a 20-25
  membri e con quote diverse dagli export delle repliche.

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
# MAIN2 su una lista di repliche, una dopo l'altra. Fino a 18 membri due liste in parallelo,
# non di piu'; a 20-25 una lista sola, perche' a 25 membri il parallelo non aiuta (fase 2)
bash CER_repliche/lancia_repliche.sh fino15 1 15 1 3 5 7 9 11 13 15 17 19
bash CER_repliche/lancia_repliche.sh fino15 1 15 2 4 6 8 10 12 14 16 18 20
bash CER_repliche/lancia_repliche.sh da20a25 20 25 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
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

Se MAIN2 si ferma, riprova una volta dal checkpoint. Le repliche già fatte si saltano. Dal 30
ottobre, se si ferma lo script stesso (finestra chiusa, riavvio), rilanciato con gli stessi
argomenti riprende dal checkpoint anche la replica interrotta. Per i run lunghi conviene una
finestra Git Bash fuori da VS Code.
`outputs/repliche/<blocco>/avanzamento.txt` ha una riga per replica. **Non modificare
`lancia_repliche.sh` mentre gira:** bash rilegge il file a fine ciclo.

Per il blocco 20-25 c'è `avvia_da20a25.sh`.
- Lancia la lista intera in una finestra Git Bash fuori da VS Code; il comando è in testa al
  file.
- Con `veglia.ps1` tiene sveglio il PC finché la finestra è aperta. Non impedisce la sospensione
  da coperchio o da tasto.
- `stato_run.sh` riassume il run: repliche fatte, replica e comunità in corso, errori veri, RAM,
  minuti medi a replica.

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

## Dati versionati per l'analisi (dal 1 novembre 2026)

**Cosa è nel repository:**
- per ogni replica finita, la cartella `outputs/repliche/<blocco>/rNN/export/`, con 5 CSV in
  formato lungo;
- tutte e 21 le repliche di `fino15`, `da18` e `da20a25`;
- dal 3 novembre anche le 21 della lettura unita, in `outputs/repliche/unito/`.

**Dal 1 novembre si versiona anche `rNN/checkpoint.mat` dei tre blocchi** (i `RESULTS`, da 1 a 4
MB). È l'unica parte che costa ore di calcolo, ed è ciò che `unisci_blocchi` legge per la lettura
unita. I checkpoint uniti (9 MB l'uno) restano locali: `unisci_repliche.sh` li rifà dai blocchi
in meno di un'ora.

**Dal 3 novembre si versionano anche le tabelle di MAIN2 che servono all'analisi** della lettura
unita, in `outputs/repliche/unito/rNN/tabelle/` (circa 4,5 MB a replica, `salva_tabelle_analisi.py`):
con quelle `analisi_finale.sh` rifà l'analisi completa su qualunque PC, senza MATLAB.

**Cosa resta locale:** `tables/` complete e `workspace.mat`. Si rigenerano dal checkpoint con
`MAIN2_RIPRENDI=1`, cioè la sola analisi fra comunità, ed `esporta_run_livelli`.

| File | Una riga per | Colonne chiave |
|---|---|---|
| `comunita.csv` | comunità | Composizione, Scheda, Membri, Penetrazione_pct, vN_EUR, Binding |
| `tfair_lungo.csv` | comunità × metodo | le precedenti + Metodo; gli indicatori, compresa la stabilità (EccessoMax_EUR, CoalizioniInstabili, EccessoMax_pct_vN) |
| `punteggi_orientati.csv` | comunità × metodo × indicatore | Metodo, Indicatore, PunteggioOrientato, TolPareggio, Discrimina |
| `quote_membri.csv` | comunità × metodo × membro | Metodo, Membro, Prosumer, Quota_EUR, VAN_EUR |
| `virtuosita.csv` | comunità × membro | Membro, Prosumer, VirtuositaNetta, VirtuositaLorda |

Da leggere prima di usarli:
- **La replica sta nel nome della cartella**, non dentro i file: r00 è il disegno originale,
  r01-r20 le repliche. `aggrega_repliche.py` la aggiunge alla lettura come colonna `Replica`.
- **I metodi non sono gli stessi nei tre blocchi.**
  - `fino15` e `da18` ne hanno 12, fra cui sia "Shapley" (esatto) sia "Adaptive Sampling
    Shapley".
  - `da20a25` ne ha 10: mancano lo Shapley esatto e il Nucleolo.
  - Per leggere i blocchi insieme vale la regola del solo Shapley: fino a 18 membri si tolgono le
    righe dell'AS, da 20 l'AS si rinomina "Shapley".
- **Per l'analisi 5-25 si usano i file della lettura unita,** in
  `outputs/repliche/unito/rNN/export/`, con le stesse colonne. Lì l'AS da 20 membri in su si
  chiama già "Shapley".
  - `punteggi_orientati` ha i soli 10 metodi confrontati, con un solo Shapley.
  - `tfair_lungo` e `quote_membri` tengono invece tutti i metodi calcolati. Fino a 18 membri
    compaiono anche "Adaptive Sampling Shapley" e "Nucleolo": per l'analisi 5-25 vanno tolti. Il
    primo è un doppione dello Shapley esatto, il secondo c'è solo fino a 18.
- **Volume:** circa 190 MB nei tre blocchi e 187 MB nella lettura unita. `quote_membri` di tutte
  le repliche (1,2 milioni di righe) supera il limite di Excel; pandas lo legge in pochi secondi.

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
7. **r00 a 18 membri, con v(S) a blocchi, riproduce il run del 27 ottobre**
   (`checkpoint_main2_fino18_IND.mat`, codice di prima: v(S) col ciclo, VLC con MILP). Sono 63
   comunità, con v(N) identico. Scarti relativi al più:
   - 1,4e-07 su `Tcmp` (VLC);
   - 1,6e-07 su `Tfair`;
   - 3,4e-09 sul VAN.

   È lo stesso ordine del punto 4: viene dal VLC, non da v(S).
8. **Le 21 repliche da 18 membri sono complete** (30 ottobre, 00:20-02:49):
   - 418 file ciascuna, nessun warning, nessuna ripresa;
   - 12 minuti per replica con due in parallelo, 10 da sola;
   - con due MATLAB la RAM libera ha mediana 2,0 GB e minimo 415 MB, a fine replica, quando le
     due istanze arrivano insieme a 4,8-5,0 GB (`outputs/repliche/da18/campioni.csv`).

## Risultati per blocco di taglia (superati)

I tre blocchi sono stati aggregati anche separatamente, man mano che finivano
(`outputs/repliche/<blocco>/aggregato/`, 29 ottobre - 3 novembre). Quei numeri sono superati dalla
lettura unita 5-25, che usa un solo Shapley e la stabilità a ogni taglia: restano solo come
storico. Se ne usa un solo dato, a giustificare l'esclusione del Nucleolo dal confronto: nei blocchi
fino a 18 membri, dove è calcolato, il Nucleolo è fra i primi su merito e stabilità insieme al
Variance Least Core nel 92-100% delle celle (`fino15/aggregato/`, `da18/aggregato/`).

## Risultati della lettura unita 5-25 membri (3 novembre 2026)

295 comunità per replica (5, 8, 10, 15, 18, 20 e 25 membri, tutti i livelli), 10 metodi con un
solo Shapley (esatto fino a 18 membri, AS da 20), tutti gli indicatori a ogni taglia, stabilità
compresa. Mediane sulle repliche r01-r20; numeri in
[`outputs/repliche/unito/aggregato/sintesi.md`](../outputs/repliche/unito/aggregato/sintesi.md).

- **I tre poli.** Quota delle celle del livello base in cui il metodo è fra i primi:
  - su Gini, l'Equal Split (100%);
  - su merito e stabilità, il Variance Least Core (98-100%), poi lo Shapley (45-94%);
  - sulla forza incentivante, Pearson Key e Tri-level EP (95%).
- **Il capovolgimento con la penetrazione, in 20 repliche su 20:**
  - τ(Gini, forza incentivante) va da −0,34 a −0,83 (fascia 1 → 4);
  - τ(Fairness Index, forza incentivante) va da −0,57 a +0,50 (fascia 1 → 3).
- **Il trade-off uguaglianza-incentivo:** scegliere Gini fa perdere 0,82 della forza
  incentivante, scegliere l'incentivo 0,88 su Gini; merito e stabilità non si fanno concorrenza
  (0,00-0,01).
- **La composizione pesa poco:** PA e imprese invertono il 9-10% delle coppie (mediana).
- **I vincitori:** il vincitore della cella è lo stesso nell'83-100% delle repliche, secondo
  l'indicatore (76% per l'allineamento lordo).
- **Da cosa dipendono i punteggi.** La penetrazione è il primo fattore per 7 indicatori su 8
  (59-72% della varianza); la taglia pesa il 4-10%, i partecipanti il 12-24%. Per l'allineamento
  lordo la penetrazione spiega l'11%, la taglia il 29%, l'interazione il 27%, i partecipanti il 33%.
- **Inversioni lungo gli assi:** 16-26% delle coppie lungo la penetrazione (per taglia), 7-18%
  lungo la taglia (per fascia).
- **Al 100% di prosumer:** τ(Fairness Index, forza incentivante) vale 0,16 (0,01-0,40), positivo in
  20 repliche su 20; τ(Gini, Fairness Index) vale −0,06, con il segno della mediana in 16 su 20.

## Risultati dell'analisi completa (3 novembre 2026)

`bash CER_repliche/analisi_finale.sh` sul PC del run: 8 passi in 2 minuti, nessun errore. Tutti i
controlli di integrità sono passati (295 comunità, 16 livelli, 10 metodi, 7 taglie per replica).
Solo repliche r01-r20. Fonti dei numeri: `outputs/repliche/unito/aggregato/sintesi.md`,
`robustezza.csv`, `van.csv`, `soglia.csv` e `outputs/tesi_finale/conclusioni.csv`.

**Il numero di repliche basta?** Regge una conclusione che vale in almeno 15 repliche su 20; è
forte con almeno 17.

| Tipo | Conclusioni | Reggono | Forti | Dipendono | Si invertono | Metà concordi |
|---|---|---|---|---|---|---|
| tau | 107 | 104 | 102 | 3 | 0 | 106 |
| vincitore | 224 | 221 | 216 | 3 | 0 | 218 |
| capovolgimento | 2 | 2 | 2 | 0 | 0 | 2 |
| soglia | 1 | 1 | 1 | 0 | 0 | 1 |
| **tutte** | **334** | **328** | **321** | **6** | **0** | **327** |

Nel bootstrap il verdetto resta lo stesso nel 100% dei casi (mediana).

**Conclusioni chiave: 10 confermate su 11.**

| Conclusione | Repliche | Verdetto | Numero |
|---|---|---|---|
| Equal Split è primo su Gini nella maggioranza delle celle | 20/20 | confermata | mediana 100% delle celle |
| il Variance Least Core è primo sul merito (FI) | 20/20 | confermata | mediana 100% delle celle |
| il Variance Least Core è primo sulla stabilità (eccesso) | 20/20 | confermata | mediana 100% delle celle |
| Pearson Key o Tri-level EP sono primi sulla forza incentivante | 20/20 | confermata | mediana 96% delle celle |
| τ(Gini, IS) scende di almeno 0,3 dalla fascia 1 alla 4 | 20/20 | confermata | IC 95% 83-100% |
| τ(FI, IS) negativo in fascia 1 e positivo in fascia 3 | 20/20 | confermata | IC 95% 83-100% |
| nessuna comunità con imprese sopra il 55% | 20/20 | confermata | IC 95% 83-100% |
| il trade-off più caro è uguaglianza contro incentivo | mediane | confermata | forza incentivante → Gini 0,88 |
| merito e stabilità non si fanno concorrenza (perdita ≤ 0,10) | mediana | confermata | FI → eccesso 0,00 [0,00; 0,01] |
| la composizione pesa poco (coppie invertite ≤ 15%) | mediana | confermata | 9% (livelli 1-23%) |
| la penetrazione è il primo fattore della varianza per ogni indicatore | - | **non confermata** | 7/8 indicatori; eccezione l'allineamento lordo |

**Cosa dipende dai partecipanti: solo l'allineamento lordo.**
- Sugli altri sette indicatori reggono tutte e 283 le conclusioni e le metà concordano su tutte.
  Due non sono forti: τ(Gini, Fairness Index) e τ(Gini, Sigma) negativi in fascia 4 (16/20).
- Per l'allineamento lordo ne reggono 45 su 51, e le metà concordano su 44. Le 6 che dipendono:
  - τ con eccesso massimo, Fairness Index e Sigma negativo in fascia 3 (14, 14 e 13 repliche);
  - Similarity-Utilization fra i primi a 5 membri, fascia 4 (14);
  - Cascading Tree fra i primi a 10 e 18 membri, fascia 3 (13 e 14).
- È anche l'unico indicatore in cui la penetrazione non è il primo fattore: ne spiega l'11% della
  varianza, contro il 29% della taglia, il 27% dell'interazione e il 33% dei partecipanti. Negli
  altri sette la penetrazione spiega il 59-72%.

**Soglia regolatoria** (`soglia.csv`, energia condivisa su immessa, tutte le comunità delle 20
repliche):

| Gruppo | Comunità | Massimo | Mediana | Sopra il 55% |
|---|---|---|---|---|
| solo domestici | 560 | 81,4% | 19,7% | 70, in tutte e 20 le repliche e a ogni taglia |
| con imprese | 3740 | 34,7% | 8,5% | 0 |
| con PA | 1600 | 36,1% | 12,0% | 0 |

**VAN per metodo** (`van.csv`, analisi complementare): quota delle comunità con almeno un membro a
VAN negativo.
- Pearson Key, Tri-level EP e Proportional to Consumption: 83-100%.
- Similarity-Utilization: 100% nelle sole domestiche, 44-48% con imprese o PA.
- Equal Split 0-9%, Cascading Tree 0-19%.

## Blocco 18-25 membri, in due fasi (dal 30 ottobre 2026)

**Fase 1: le comunità da 18 membri** (63 a replica, r00 compresa), con v(S) a blocchi. **Fatta il
30 ottobre:** controlli 7-8 e risultati nelle due sezioni sopra.
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
estesa fin lì.** Piano approvato il 30 ottobre in quattro passi: codice; verifiche e commit; run in
serie con un'istanza sola (scelta dell'utente); unione di tutti i blocchi.

*Il codice (passo 1):*
- **`coalition_excess_enum.m`** calcola l'eccesso di coalizione da una v(S) già enumerata.
  - Somma le quote sulle coalizioni un giocatore alla volta, come la separazione del VLC.
  - Stesse uscite di riepilogo di `coalition_excess.m`. Non tiene la matrice di incidenza né
    l'eccesso di ogni coalizione, che a 25 membri peserebbero 6,7 + 3,2 GB.
- **`MAIN2.m`, solo da 19 a 25 membri** (`stabilitaEnum`):
  - v(S) si enumera una volta con `cer_coalition_values_blocchi` e va al VLC e all'eccesso;
  - stampa della stabilità e piano uniformità × stabilità;
  - due controlli: l'eccesso massimo del VLC vale −θ_LC entro la sua tolleranza, e nessuna
    ripartizione non negativa ha un eccesso massimo più basso. È il ruolo che fino a 18 membri ha
    il Nucleolo.
  - Shapley e Nucleolo restano fuori: a 20-25 membri lo Shapley è l'AS.
- **`lancia_repliche.sh`:**
  - la selezione delle schede non apre più processi per file;
  - una replica interrotta riparte dal checkpoint (`MAIN2_RIPRENDI`), invece che da capo.

*Le verifiche (passo 2, `outputs/repliche/controlli_fase2/`):*
1. **Test di unità** (`test_coalition_excess_enum.m`, `test_unita.txt`):
   - contro `coalition_excess` da 2 a 20 giocatori, con e senza F, su quattro ripartizioni;
   - a 25 giocatori contro un riferimento a blocchi di 2^20 coalizioni;
   - scarto 0 in tutti i 20 casi;
   - i due controlli sul VLC tengono, e il VLC con v(S) passata è identico bit per bit.
2. **Fino a 18 membri non cambia niente.** Le 12 schede di controllo della fase 1 danno 44 tabelle
   identiche al byte a quelle della fase 1 (`confronto_tabelle_le18.txt`). `RESULTS` è identico
   tranne i tempi.
3. **Comunità vere contro `coalition_excess`:** ND3_PA3/CER_4_14_0 (18 membri, 12 metodi) e
   ND3_PA3/CER_5_15_0 (20 membri, 10 metodi). Scarto 0 sull'eccesso massimo e coalizioni instabili
   identiche.
4. **7 schede di r00 da 20-25 membri contro il run del 28 ottobre** (`selezione_2025.txt`,
   `confronto_risultati.txt`):
   - tutti i campi di `RESULTS` sono identici (isequaln), tranne le nuove colonne di stabilità, i
     tempi e i percorsi in `CFG`;
   - il VLC con la v(S) di MAIN2 resta identico;
   - i controlli dentro MAIN2 tengono.
5. **Tempi e memoria.** A 25 membri:
   - v(S) 35-99 s, VLC 31-45 s, eccesso 2 s;
   - per comunità 94-161 s, contro 74-147 s il 28 ottobre (nei primi minuti girava insieme la prova
     della selezione vecchia);
   - MATLAB al più 2,4 GB, RAM libera almeno 1,7 GB (`campioni_2025.csv`).
6. **Selezione:** la nuova dà gli stessi elenchi della vecchia (r00 a 20-25, r13 a 18, r07 a 5-15),
   in 5-6 s invece di circa 60 (`selezione_vecchia_nuova.txt`).
7. **Ripresa** (`ripresa.txt`):
   - un blocco di prova (r01, 61 comunità da 15 membri) fermato a mano dopo 11 comunità e
     rilanciato riparte dalla 12 e si chiude;
   - i risultati coincidono con il blocco 5-15 del 29 ottobre entro 3e-13 sulle quote e 2e-12 su
     `Tfair`, il rumore del cambio d'ordine delle somme della fase 1.

*Il run (passo 3):*
- **Avvio:** 30 ottobre alle 15:48, blocco `da20a25`, repliche 0-20 con r00 per prima, in una
  finestra Git Bash fuori da VS Code. Uno script a parte chiede a Windows di non andare in
  sospensione finché la finestra è aperta; le impostazioni di alimentazione non sono state
  toccate.
- **Primo controllo, passato:** dopo r00 (228 min), il confronto con il run del 28 ottobre su
  tutte le 127 comunità. `RESULTS` è identico (`isequaln`) tranne i percorsi di scheda e
  configurazione e i tempi. Il VLC ha eccesso massimo negativo in tutte le comunità: sta nel
  nucleo. Registro in `outputs/repliche/controlli_fase2/confronto_r00_da20a25.txt`.
- **Tre repliche fermate dal limite del VLC (notte del 30-31 ottobre).**
  - r01, r02 e r03 si sono fermate rispettivamente sulle comunità 124, 82 e 94, tutte da 25
    membri. L'errore era "non convergente in 1000 iterazioni"; lo script le ha riprovate dal
    checkpoint, con lo stesso esito, e poi è andato avanti.
  - Le iterazioni dipendono dalle famiglie estratte: la stessa scheda va da 341 a oltre 1000
    secondo la replica. Motivi e numeri nel README principale, §7.11.6.
  - **Correzione del 31 ottobre:** `optVLC.maxIter = 5000` in `MAIN2.m`. Chi convergeva prima fa
    le stesse iterazioni.
- **Ripresa (31 ottobre, 16:12):**
  - il run fermato subito dopo un salvataggio;
  - i checkpoint di r01-r03 riportati in `outputs/checkpoint_main2_repNN_da20a25.mat`, con una
    copia che resta in `rNN/checkpoint.mat`;
  - i log dei tentativi falliti rinominati `main2_ripresa_limite1000.log`;
  - stesso comando di lancio.

  r01 si chiude in 13 minuti: la comunità bloccata richiede 1121 iterazioni, la successiva 1150.
- **Attenzione per una nuova ripresa:** rilanciare tutte le repliche funziona solo se il checkpoint
  di ogni replica non finita sta in `outputs/`. Lo script li sposta in `rNN/` a fine replica, anche
  quando fallisce: una replica fallita senza il checkpoint in `outputs/` ripartirebbe da capo.
- **Sospensione del 31 ottobre:** il PC è rimasto fermo dalle 7:56 alle 15:58, per il coperchio
  chiuso o il tasto. MATLAB è ripartito da dove era.
- **Edge aperto (31 ottobre, dalle 18:45):** v(S) a 25 membri è raddoppiata fino alla chiusura del
  browser. r05 ha impiegato 318 min. È una coincidenza nel tempo, non una causa dimostrata.
- **Riavvio del PC (1 novembre):** run fermato alle 17:03 dopo un salvataggio, con r00-r08 finite;
  ripreso alle 17:15 con `avvia_da20a25.sh`, che ha saltato le finite e ripreso r09 dalla
  comunità 19. Una replica è scesa da circa 4 h 10 a circa 2 h 35, come il run del 28 ottobre.
- **Fine: 3 novembre alle 00:26.** 21 repliche su 21, 2667 comunità, nessuna fallita, massimo 1365
  iterazioni del VLC, 26 comunità oltre le 1000.

Tempi misurati a replica:

| Repliche | Minuti | Condizioni |
|---|---|---|
| r00 | 228 | prima replica |
| r06-r08 | 243-254 | PC acceso da giorni |
| r05 | 318 | con Edge aperto nella prima parte |
| r10-r20 | 151-165 | dopo il riavvio |

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
- **Tempo della fase 2, con una sola istanza** (decisione del 30 ottobre).
  - Per replica: 63 comunità da 20 membri (circa 15 s l'una) e 64 da 25 (circa 140 s), più 2-3 min
    di avvio, analisi ed export. Fanno circa 2 h 50 min.
  - Le 21 repliche: circa 60 h (55-65).
  - **Misurato:** circa 2 h 35 a replica a PC appena riavviato, cioè 54 h per 21 repliche; da 3 h
    50 a 4 h 10 a PC acceso da giorni, cioè 80-88 h. Il run ha impiegato 81 h di calendario,
    comprese le fermate del limite del VLC e la sospensione.

**Lettura unita (passo 4, 3 novembre).** `unisci_repliche.sh` fa per ogni replica due chiamate:

```bash
bash CER_repliche/unisci_repliche.sh 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
venv/Scripts/python.exe -I CER_repliche/aggrega_repliche.py --blocco unito
# cio' che lo script fa per la replica NN:
matlab -batch "addpath('CER_repliche'); addpath('outputs/workspace/strumenti'); unisci_blocchi('CER_repliche/rNN', {'outputs/repliche/fino15/rNN/checkpoint.mat', 'outputs/repliche/da18/rNN/checkpoint.mat', 'outputs/repliche/da20a25/rNN/checkpoint.mat'}, 'repNN_unito', 25)"
MAIN2_RIPRENDI=1 MAIN2_RADICE=CER_repliche/rNN MAIN2_MAX_UTENTI=25 MAIN2_IND=1 MAIN2_CARTELLA=repNN_unito matlab -batch "MAIN2"
```

Le uscite vanno in `outputs/repliche/unito/rNN/`, con la stessa struttura dei blocchi:
- **Tempi:** 2-4 minuti a replica, 8 minuti e mezzo la prima; 21 repliche dalle 9:53 alle 10:59
  del 3 novembre. Nessun errore, 295 comunità in ognuna.
- **r00 unita contro la prova della regola Shapley sul run del 28 ottobre**
  (`outputs/repliche/prova_regola_shapley/`; registri in `outputs/repliche/unito/controlli_r00.txt`
  e `confronto_r00_con_prova_regola_shapley.txt`):
  - **Per comunità:** identica a 20-25 membri, entro 5e-12 a 5-10 membri. A 15 e 18 membri
    differisce solo il VLC, al massimo di 2,1e-8 di v(N), 100 volte sotto la sua tolleranza di
    convergenza (2e-6 di v(N)). Tutti gli altri metodi coincidono entro 1e-11 di v(N).
  - **Fra comunità:** su 3245 celle dei vincitori cambiano solo le 254 della stabilità a 20-25
    membri (EccessoMax_EUR e CoalizioniInstabili), che nel run del 28 ottobre erano vuote.
- **r00 a 20-25 viene dal blocco `da20a25`,** non dal run del 28 ottobre, dove la stabilità a
  quelle taglie non c'è.
- **Con `maxUtenti` 18** si otterrebbe la vista fino a 18 membri, con il Nucleolo. Non si fa:
  nella versione B del piano il Nucleolo è escluso dal confronto (`docs/analisi_finale/`).
- **Niente divisione 5-18 contro 20-25** (decisione del 3 novembre): con la stabilità a ogni
  taglia gli indicatori ci sono tutti, e l'analisi si legge intera.

## Rapporto finale sulle repliche (3 novembre 2026)

[`outputs/report/RISULTATI_repliche_2026-11-03.html`](../outputs/report/RISULTATI_repliche_2026-11-03.html)
è la pagina unica con tutti i risultati della lettura unita: tabelle, 14 grafici, commento di
ciascuno e conclusioni rispetto alla domanda di ricerca. La scrive `rapporto_repliche.py`:

```bash
venv/Scripts/python.exe -I CER_repliche/aggrega_repliche.py --blocco unito   # aggregato (7 s)
venv/Scripts/python.exe -I CER_repliche/rapporto_repliche.py                 # pagina (circa 1 minuto)
```

- **Fonti:** `outputs/repliche/unito/aggregato/` e, per replica, `export/` e `tables/`. Solo
  r01-r20: **r00 non entra in nessun numero**, è il controllo del generatore.
- **Controlli:** ogni numero del testo viene dai CSV. Ogni affermazione qualitativa ha un controllo
  e lo script non scrive la pagina se i dati non la sostengono.
- **Due risultati nuovi rispetto al disegno di partenza:**
  - **Soglia GSE al 55%:** morde in 70 comunità su 5.900 (1,2%, massimo 81%), tutte nel livello base
    e a penetrazione fino al 30%. L'eccedenza spetta alle sole imprese, quindi la ripartizione non
    cambia (README principale §7.4).
  - **Inclusione LIHC:** calcolabile solo a 25 membri e in 8 repliche su 20 (6,6% delle comunità).
    Resta preliminare: P50, y* e markup sono ancora `?` in `CER_input.txt`.
- **Dove sono i dati dei run:** `export/` e `checkpoint.mat` di ogni replica sono versionati
  (sezione "Dati versionati"). `tables/` e `workspace.mat` restano locali e si rigenerano dal
  checkpoint con `MAIN2_RIPRENDI=1`.
