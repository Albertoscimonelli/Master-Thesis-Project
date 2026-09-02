# Italianizzazione del catalogo LPG — report di fine Fase 2

Chiusura della fase di correzione del catalogo, prima della validazione
statistica. Tutti i numeri qui riportati sono **misurati eseguendo il codice** e
riproducibili: i rapporti per passo stanno in
`CER_LoadProfiles/lpg_db/dati/validazione/`, le fonti si rigenerano con
`riferimento_istat.py`, il bersaglio con `riferimento_arera.py`.

---

## 1. Che cosa è stato fatto

Dieci passi, ognuno con un commit e un rapporto di misura. Otto migrazioni nuove
del catalogo, due modifiche di configurazione, una correzione della pipeline.

| # | passo | commit | tipo |
|---|---|---|---|
| 0 | riga zero | `e04e0ea` | misura |
| 1 | POD = `Electricity_HH1` + `Electricity_House` | `a6ab037` | pipeline |
| 2 | `energy_intensity` → `EnergySaving` | `26a038c` | configurazione |
| 3 | `HT02` un solo circolatore | `6696e8b` | migrazione |
| 4 | `D02` frigorifero di taglia realistica | `628d5a6` | migrazione |
| 5 | `L11` ingresso in ufficio alle 08:00 | `47a1825` | migrazione |
| 6 | `D01` piano cottura a gas, forno elettrico | `cbe0f67` | migrazione |
| 7 | `HT01` raffrescamento + `house_type` per famiglia | `1af6785` | migrazione + config |
| 8 | `L09` bucato e lavastoviglie su cancelli propri | `01698cd` | migrazione |
| 9 | `L08` cena alle 19:30 | `4213748` | migrazione |
| 10 | `L10` coda serale | `653d3d4` | migrazione |

Prima, la Fase 0 aveva costruito l'infrastruttura di validazione (`26d1eb0`):
`riferimento_arera.py`, `riferimento_istat.py`, `valida_domestici.py`.

---

## 2. L'avvertenza che condiziona la lettura di tutto il resto

**Le curve ARERA sono medie di popolazione.** Ogni curva oraria media decine di
migliaia di clienti della stessa classe di potenza. Mediare tanti profili
individuali **attenua fortemente i picchi**: se una famiglia accende il forno
alle 20:00 e un'altra alle 21:00, la media mostra un rialzo largo e basso, non
due picchi stretti.

L'aggregato di **quattro** famiglie non può riprodurre quella smussatura, per
ragioni statistiche e non di modello. Una parte dello scarto residuo è
**numerosità del campione**, non difetto del catalogo.

Conseguenze operative, adottate da metà Fase 2 in avanti:

1. Il TVD contro ARERA **non è un giudizio sul catalogo** finché non si sa
   quanta parte dipenda dalla numerosità.
2. Le migrazioni si decidono **sull'evidenza** (ISTAT, AVQ, HETUS, ispezione del
   catalogo), non inseguendo la metrica.
3. Si privilegiano gli indicatori robusti all'aggregazione: **fasce F1/F2/F3,
   ora del picco, consumo annuo**.

La misura che separa numerosità e modello è il campione a 20 famiglie
(`config/simulation_config.campione20.yaml`, non ancora eseguito). **Va fatta
prima di giudicare l'esito della Fase 2.**

---

## 3. Progressione misurata

Livello medio delle quattro famiglie, TVD medio per tipo di giorno, fasce
dell'aggregato. Riferimento: ARERA Milano Residente, media 2024-2025.

| passo | livello | TVD fer. | TVD sab. | TVD dom. | F1 | F2 | F3 |
|---|---:|---:|---:|---:|---:|---:|---:|
| riga zero (HT06 + `Random`) | 1,90x | 0,312 | 0,269 | 0,259 | 30,01 | 42,00 | 27,99 |
| POD = famiglia + casa | 2,19x | 0,278 | 0,246 | 0,234 | 31,09 | 40,37 | 28,54 |
| `EnergySaving` | 1,42x | 0,295 | 0,286 | 0,269 | 31,81 | 39,87 | 28,32 |
| `HT02` circolatore | 1,34x | 0,315 | 0,293 | 0,273 | 31,04 | 40,56 | 28,41 |
| `D02` frigorifero | 1,41x | 0,291 | 0,280 | 0,268 | 31,14 | 39,78 | 29,08 |
| `L11` ingresso ufficio | 1,38x | 0,294 | 0,291 | 0,261 | 28,10 | 41,97 | 29,92 |
| `D01` cottura a gas | 1,11x | 0,258 | 0,252 | 0,211 | 31,93 | 37,95 | 30,13 |
| `HT01` raffrescamento | 1,23x | 0,231 | 0,242 | 0,191 | 32,40 | 36,11 | 31,49 |
| `L09` bucato | 1,25x | 0,227 | 0,191 | 0,177 | 31,08 | 37,63 | 31,28 |
| `L08` cena | 1,25x | 0,237 | 0,197 | 0,183 | 30,84 | 37,93 | 31,23 |
| **`L10` coda serale** | **1,25x** | **0,211** | **0,171** | **0,150** | **29,70** | **38,01** | **32,28** |
| **ARERA (bersaglio)** | **1,00x** | **0,0063** | **0,0075** | **0,0033** | **31,11** | **30,29** | **38,60** |

**Il livello passa da 1,90x a 1,25x**; il TVD feriale da 0,312 a 0,211, quello
domenicale da 0,259 a 0,150. F3 da 27,99 a 32,28 contro un bersaglio di 38,60.

### Forma oraria feriale finale, % della giornata

```
ora      0    1    2    3    4    5    6    7    8    9   10   11
LPG   2,36 1,53 1,50 1,55 1,57 1,79 2,78 4,53 3,37 2,35 2,25 2,54
ARERA 3,64 2,98 2,63 2,46 2,40 2,51 2,99 3,78 3,96 3,92 3,85 3,98

ora     12   13   14   15   16   17   18   19   20   21   22   23
LPG   2,89 4,13 3,94 3,90 4,43 6,37 10,35 10,83 8,53 6,28 5,96 4,26
ARERA 4,30 4,42 4,32 4,18 4,19 4,56 5,32 6,43 6,67 6,36 5,57 4,56
```

**Risolti**: picco mattutino (07-09 al 10,25% contro l'11,66% di ARERA, era il
29,0%), coda serale (22-23 al 10,22% contro il 10,13%), fascia F1 in prossimità
del bersaglio per gran parte del percorso.

**Non risolto**: la sera. Le ore 17-20 valgono il **36,1%** della giornata
contro il **22,98%** di ARERA, con il picco alle 19 invece che alle 20.

---

## 4. Migrazione per migrazione: evidenza, effetto, causa

### Passo 1 — POD = `Electricity_HH1` + `Electricity_House`

La pipeline leggeva solo la componente elettrodomestici e scartava quella di
casa (pompa di circolazione e, dove previsto, condizionatore). Il contatore
misura la somma.

Effetto: livello +18%, TVD migliora su tutte e quattro, F1 va a bersaglio.

**Limite dichiarato**: AVQ 2024 (`TRISC`) dà il 27,1% delle abitazioni lombarde
con riscaldamento centralizzato. Per quelle la pompa non sta sul contatore della
famiglia. HT06 e HT07 modellano solo il caso autonomo: il POD così definito è
corretto per il 71,6% dei casi.

### Passo 2 — `EnergySaving`

`Random` sorteggiava fra le alternative di ogni categoria, quindi le differenze
fra i quattro nuclei misuravano il sorteggio invece della composizione
familiare. Era una conclusione già dimostrata nel §4.1 di
`CONTESTO_VALIDAZIONE_ARERA.md` ma mai applicata al file di configurazione vivo,
mentre il piano scriveva `D02` e `D03` dandola per fatta.

Effetto: **la leva più forte sul livello**, da 2,19x a 1,42x. Sulla forma è
leggermente negativa, perché `EnergySaving` sceglie anche il frigorifero più
piccolo del catalogo (82,9 kWh/anno) e abbassa ulteriormente il carico di base.

### Passo 3 — `HT02`, un solo circolatore

Ogni house type montava il gruppo di azioni 214 (*run Circulation pump*) **due
volte**, con due cancelli: `TL 53` (ogni giorno 06:00-22:00, tutto l'anno) e
`TL 3` (sotto i 15 °C). D'inverno giravano insieme. La pompa restava accesa
**7.784 ore l'anno su 8.760** e consumava **2,2 volte** quanto il catalogo stesso
dichiara per una singola unità (898 contro 409 kWh per il Wilo-Star, 281 contro
128 per il Grundfos: identico fattore).

Riferimento: ISTAT *Consumi energetici 2021*, Tavola 7, Lombardia — 10,06 h/g di
riscaldamento nei mesi freddi, da cui 45-145 kWh/anno di circolatore.

Effetto: componente casa da 281 a **125 kWh/anno**, uniforme.

**Aperto**: la pompa gira ancora tutto l'anno, agosto compreso, perché `TL 3` ha
finestra 00:00-20:00. Non corretto perché è condiviso da 18 house type. Si
risolverebbe con un time limit dedicato a HT06/HT07.

### Passo 4 — `D02`, frigorifero

Il gruppo di azioni 184 offriva sette frigo-congelatori, cinque dei quali
guidati da profilo misurato e dichiaranti `YearlyEnergyUse = 0`: consumo non
leggibile dal catalogo e scelta non prevedibile. Ristretto ai due che dichiarano
229 kWh/anno.

Effetto: **primo passo che migliora la forma su tutte e quattro**. Carico
notturno +25%, F3 recupera per la prima volta.

**Aperto**: le ore 00-03 restano all'1,1-2,4% contro il 2,4-3,6% di ARERA. Il
frigorifero era una causa, non l'unica. Da esaminare: standby, congelatore
separato (ISTAT: 22,0% delle famiglie lombarde).

### Passo 5 — `L11`, ingresso in ufficio

`L01` aveva spostato `TL 12` da 08:00-10:00 a **09:00-11:00**, assumendo che in
Italia si entri al lavoro più tardi che in Germania. AVQ 2024 sui soli occupati
lombardi (n=1.146, pesati) dice il contrario: uscita di casa p25 07:00, **mediana
07:30**, p75 08:00; tragitto mediano 15 minuti. Arrivo mediano verso le 07:45.
I dodici tratti che passano da quel cancello si chiamano *"Work - Office N, XXh,
from 08:00"*.

**Il valore tedesco originale era già corretto per l'Italia: `L01` lo aveva
peggiorato.**

Effetto grande e in due direzioni opposte: picco mattutino da 29,0% a 17,8%
della giornata, ma sera da 25,8% a 33,7%. Entrando un'ora prima si rientra
un'ora prima. Il TVD medio resta invariato e F1 peggiora.

**Lezione**: una correzione più realistica di un parametro può peggiorare
l'indicatore aggregato finché il resto del modello è sbagliato.

Nota: gli altri due time limit di `L01` reggono al controllo; il `TL 7` non è
usato da **alcun** tratto, quindi quel terzo di `L01` non ha mai avuto effetto.

### Passo 6 — `D01`, piano cottura a gas

ISTAT *Consumi energetici 2021*, Tavola 19, Lombardia: piano cottura a gas
**89,5%** (metano 85,9 + GPL 3,6), forno **elettrico 83,9%**. Due apparecchi con
vettori opposti.

Spostati a gas i **sei** fuochi (categorie 180-183). La prova documentata nel
§5 di `CONTESTO_VALIDAZIONE_ARERA.md` ne spostava **sette** in blocco: la
differenza è il forno, che deve restare elettrico e che compare nella
composizione dei picchi annui di potenza. Lasciati elettrici anche i piani a
induzione, che rappresentano bene il 10,5% elettrico misurato da ISTAT.

**Controllo di coerenza superato al kWh**: il calo di elettricità coincide con
il gas comparso (520/370/663/709 kWh sulle quattro famiglie). I fuochi si
accendono le stesse volte, su un altro vettore.

Effetto: **passo migliore su ogni dimensione**. Livello da 1,38x a 1,11x, TVD
migliora su tutte e quattro insieme al livello. **Picco mattutino risolto**.

### Passo 7 — `HT01`, raffrescamento

`CoolingYearlyTotal` di HT07 da 5.000 a **1.400 kWh termici** (466 elettrici con
COP 3). Due misure indipendenti concordano: dal dato ARERA il condizionamento
vale ~233 kWh per famiglia media, che divisi per il 55,6% di famiglie dotate
(ISTAT *Dotazioni energetiche 2024*, Tavola 3) danno **419 kWh per famiglia
dotata**; l'intervallo reale italiano è 400-700.

Più la chiave `house_type` per famiglia: HT07 a due nuclei su quattro, **uno per
coppia di archetipi**, così il condizionatore non risulta correlato al tipo di
famiglia. ISTAT non pubblica la diffusione per tipo di nucleo: è una scelta
dichiarata.

**Previsione confermata al kWh**: componente casa da 125 a 587 nelle due dotate,
+462 contro i 466 attesi. Il TVD migliora **solo** su quelle due, che è il
controllo di attribuzione più pulito del percorso. F3 al massimo.

**Limite dichiarato**: `AdjustYearlyCoolingHours = 0`. A differenza del
riscaldamento, il raffrescamento non viene riscalato sui gradi giorno: i valori
restano identici a Milano come a Palermo.

### Passo 8 — `L09`, bucato e lavastoviglie

**Due premesse del piano si sono rivelate sbagliate.**

La prima: `TL 6` non è il cancello del bucato. Lo condividono **dodici**
attività, di cui solo tre riguardano il bucato; le altre nove sono cuocere una
torta, pulire i vetri, spazzare, il robot aspirapolvere, andare in piscina. Il
piano prescriveva di allargarlo: avrebbe spostato anche quelle. Si sono creati
**due time limit nuovi** e vi si sono ripuntate le sole attività interessate.

La seconda: il dato **non** dice che in Italia il bucato si faccia la sera.
ActivityAssure, feriale: moda alle 17:00 per le occupate a tempo pieno (37,9%
della massa fra le 12 e le 18, 43,5% fra le 18 e le 24), moda alle 10:10 per le
pensionate (47,6% entro mezzogiorno). Bucato e lavastoviglie vanno inoltre
separati: la lavastoviglie segue i pasti (picco 20:50 per le occupate, 13:40 per
le pensionate).

```
TL 150  Bucato italiano         10:00-21:30  randomizzazione 120 min
TL 151  Lavastoviglie italiana  13:00-22:30  randomizzazione  90 min
```

Il parametro decisivo è la **randomizzazione**, non l'orario: con i 15 minuti di
`TL 6` tre macchine sullo stesso cancello partivano insieme all'apertura.

Effetto maggiore **nel fine settimana**, non previsto: TVD sabato da 0,242 a
0,191. Il bucato è anche attività del fine settimana e il cancello delle 08:00
valeva tutti i giorni.

### Passo 9 — `L08`, cena

ActivityAssure: picco italiano di `eat` alle **20:20** con ampiezza 42,0% per le
donne occupate a tempo pieno, contro le 19:20 al 16,4% della Germania; su `cook`
la massa 18-22 vale il 60,7% in Italia contro il 39,2% tedesco. La cena italiana
è più tarda **e molto più concentrata**.

Spostati `TL 121` (*Dinner Time*, 29 usi via tratti) da 19:00-21:30 a
19:30-22:00 e `TL 66` da 18:30-22:00 a 19:30-22:30, randomizzazione 15 → 45.
Non toccato `TL 40`, che condivide il cancello con yoga e bagno dei bambini.

**Esito parziale**: il picco si sposta dalle 18 alle 19, ma ARERA lo ha alle 20.
La massa si è spostata senza distribuirsi; su due famiglie il TVD peggiora.

**Diagnosi del residuo, che nessuna migrazione sui pasti può chiudere**: alle
17-18 non c'è cena, c'è il **rientro dal lavoro**. I tratti d'ufficio hanno
durate fisse (06h, 07h, 08h, 09h, 10h, 11h) e partono tutti dal cancello delle
08:00, quindi ogni persona rientra a un'ora determinata e sempre la stessa. Con
quattro famiglie si ottengono pochi orari di rientro distinti invece di una
distribuzione.

### Passo 10 — `L10`, coda serale

Il `TL 19` governa tredici attività di sonno e apriva alle **22:00** con
randomizzazione di 15 minuti: gli adulti andavano a letto tutti alle 22.
ActivityAssure misura il superamento del 50% di addormentati alle **23:10** in
Italia contro le 22:40-23:00 tedesche; alle 22:00 la presenza in `tv`+`pc` vale
il 35,6% contro il 25,4%. AVQ 2024 Lombardia: 2,0 h di TV al giorno di mediana.

Più la prima serata televisiva: l'attività *watch TV series on weekdays 18:00*
aveva un cancello dedicato fissato alle **18:00**, orario tedesco. In Italia la
prima serata comincia fra le 20:40 e le 21:30.

`TL 19` ha voci gerarchiche (contenitore con `AnyAll = 0` e due figlie): toccata
**solo** la figlia serale.

**Risultato migliore del percorso**: migliora su tutte e quattro le famiglie e
su tutti e tre i tipi di giorno. Ore 22-23 da 5,94% a **10,22%** contro il
10,13% di ARERA. F3 al massimo.

---

## 5. Due migrazioni non necessarie

Entrambe perché il problema era già stato risolto altrove. In tutti e due i casi
il piano si basava sul documento di contesto, che descriveva lo stato del
catalogo **prima** delle migrazioni già applicate.

**`D03` lampadine.** Ogni categoria di illuminazione contiene già l'alternativa
efficiente ed `EnergySaving` sceglie la meno assorbente (LED 3W invece della
incandescenza da 60W, 20W invece di 100-300W nelle luci di stanza). La
lampadina a incandescenza segnalata nel §4.3 era pescata solo da `Random`.
Assunzione dichiarata: illuminazione interamente a basso consumo. ISTAT 2021
misura il 76,5% di lampadine a risparmio, ma il dato ha cinque anni e la
sostituzione è proseguita.

**`L07` pranzo.** I cancelli sono già tutti su orario italiano da `L03`:
`TL 119` (*Lunch Time*, 43 tratti) contiene 12:30-14:30 con randomizzazione 45,
non gli 11:30-13:00 che il nome dichiara. La misura conferma: ore 12-15 al 15,4%
contro il 17,2% di ARERA.

**Cosa resta di `L07`**: l'ampiezza. AVQ dice che per il 59,4% dei lombardi il
pranzo è il pasto principale e che il 64,6% lo consuma in casa nei feriali. Il
divario non dipende da un cancello ma da quante famiglie possiedono il tratto
che abilita «cucina il pranzo», cioè dalla composizione dei nuclei. Toccarla
significa intervenire su `tblHouseholdTraits`: più invasivo e con esito meno
prevedibile.

---

## 6. Correzioni a conclusioni precedenti

Emerse misurando. Contraddicono quanto scritto nei documenti di contesto e nel
piano, e vanno recepite.

1. **Il problema di agosto in larga parte non esiste: era geografia.** A Milano
   agosto è un mese basso (7,48% nel 2025, 9,15% nel 2024), non il massimo
   dell'anno come nel dato nazionale (10,11%).
2. **La forma mensile è una metrica debole**: il rumore anno-su-anno vale L1
   0,069-0,086, quindi lo scarto LPG di 0,162 è solo ~2× il rumore. Le metriche
   discriminanti sono quella oraria e le fasce.
3. **I dati orari ARERA coprono solo i clienti trattati orari** — confermato
   dalla pagina ARERA, non è più un'ipotesi.
4. **HETUS 2010 regge strutturalmente**: composizione per stato occupazionale
   HETUS-IT 2010 vs ISTAT 2023, scarto massimo 3,0 punti. Eccezione: il lavoro
   da casa (20,7% degli occupati del Nord-Ovest nel 2023), che nel 2010 non
   esisteva e che questo lavoro **non** modella.
5. **Il giardino non è assurdo come sembrava**: AVQ 2024 dà il 42,5% delle
   famiglie lombarde con giardino privato. Gli attrezzi da giardino restano
   inappropriati per un POD condominiale, ma è la **classe di utenza** a
   escluderli, non l'assenza di giardini in Italia.
6. **Il pasto principale italiano è il pranzo, non la cena** (59,4% contro
   28,2%), e il 64,6% lo consuma in casa nei feriali.
7. **La lampadina a incandescenza non era un errore da eliminare**: era un
   problema di peso nel mix, e `EnergySaving` lo ha già risolto.
8. **Il picco mattutino non era il bucato.** Si è chiuso con `L11` e `D01`,
   cioè orario di lavoro e cottura a gas.
9. **Il bersaglio di livello è stato letto male fino al passo 6.** La media
   ARERA include il condizionamento per il 55,6% dei clienti, mentre il modello
   ne era privo: i bersagli corretti per una famiglia **non** dotata sono ~1.429
   kWh (classe 1,5-3) e ~2.220 (classe 3-4,5), non 1.662 e 2.582. Gli scarti
   riportati nei passi 1-6 sono sottostimati di circa 16 punti percentuali.
   Risolto dal passo 7.

---

## 7. Difetti noti e non corretti

| difetto | evidenza | possibile soluzione |
|---|---|---|
| Sera in eccesso: 17-20 al 36,1% contro il 22,98% | rientro dal lavoro concentrato su pochi orari fissi | **numerosità**: da verificare col campione a 20 famiglie prima di intervenire |
| Carico notturno ancora basso: 00-03 all'1,5-2,4% contro 2,4-3,6% | dopo `D02` resta un divario | standby, congelatore separato (22,0% delle famiglie) |
| Circolatore acceso tutto l'anno | `TL 3` ha finestra 00:00-20:00, non l'orario italiano | time limit dedicato a HT06/HT07, senza toccare l'oggetto condiviso |
| Ampiezza del pranzo | AVQ: 59,4% pasto principale, 64,6% in casa | tratti familiari, non time limit |
| 24 dicembre festivo nel calendario di Milano | non è festivo in Italia; voce catalogata *Worldwide*, sfuggita a `H01`-`H03` | migrazione `H04` |
| Raffrescamento non stagionalizzato | `AdjustYearlyCoolingHours = 0` | limite strutturale del modello, da dichiarare |
| Riscaldamento a 15.000 kWh termici nominali | riscalato sui gradi giorno di Milano dà ~9.000, alto per un appartamento | è gas, non tocca il contatore elettrico |
| Nomi dei time limit non aggiornati | `TL 119` si chiama *Lunch Time (11:30-13:00)* ma contiene 12:30-14:30 | cosmetico, ma induce in errore chi legge il catalogo |

---

## 8. Prossimi passi, in ordine

1. **Campione a 20 famiglie** (`config/simulation_config.campione20.yaml`, già
   scritto e non eseguito, ~45 minuti). Calcolare la distanza da ARERA per
   sottoinsiemi di 4, 8, 12, 16 e 20 utenze: quanto scende al crescere di N è
   numerosità, ciò che resta a 20 è modello. **È la misura che rende
   interpretabile tutta la Fase 2** e va fatta prima di qualsiasi altro
   intervento sul catalogo.
2. **Ridefinire la soglia di accettazione.** Il rumore della fonte
   (0,006-0,011) è la variabilità fra due anni della stessa *media di
   popolazione*: non è il metro giusto per un campione di quattro. Serve una
   banda che tenga conto di N, oppure si dichiara che si validano fasce, ora del
   picco e livello, non la curva punto per punto.
3. **Rigenerare i risultati MATLAB.** La grandezza in ingresso è cambiata (POD
   invece della sola componente famiglia) e tutti i numeri a valle vanno
   ricalcolati: bilancio CER, Shapley, Nucleolo, VLC, indici di equità,
   `shape_heterogeneity`. Verificare che l'assert del VLC non fallisca e che
   `align_members_to_users.m` non segnali disallineamenti.
4. **Aggiornare `CONTESTO_VALIDAZIONE_ARERA.md` e `CONTESTO_LPG_RAMP.md`** con
   le nove correzioni della sezione 6 e i nuovi numeri di riferimento.
5. **Verificare l'eterogeneità di forma fra le quattro famiglie.** È la
   precondizione della domanda di ricerca: Shapley, Nucleolo e VLC si
   distinguono da una ripartizione volumetrica solo se i membri consumano in
   momenti diversi. Le migrazioni di questa fase hanno spostato **cancelli
   condivisi**, quindi hanno mosso tutte le famiglie insieme: è possibile che
   l'eterogeneità sia diminuita invece di crescere. Da misurare con
   `shape_heterogeneity.m`.

---

## 9. Riproducibilità

```bash
# ricostruire il catalogo (12 migrazioni originali + 8 nuove)
cd CER_LoadProfiles/lpg_db && ../../venv/Scripts/python build_italian_db.py

# rigenerare i profili
cd CER_LoadProfiles && ../venv/Scripts/python generate_load_profiles.py \
    --config config/simulation_config.yaml

# misurare contro ARERA
cd CER_LoadProfiles/lpg_db && ../../venv/Scripts/python valida_domestici.py \
    ../outputs/csv/profili_tutti.csv

# rigenerare tutte le citazioni statistiche usate nelle migrazioni
../../venv/Scripts/python riferimento_istat.py
```

Il `.db3` non è versionato: si ricostruisce. `build_manifest.json` registra il
conteggio righe di ogni migrazione ed è l'evidenza revisionabile. Ogni build
verifica lo SHA-256 del catalogo tedesco originale e si ferma se è cambiato.

**Tre trappole che rendono insufficiente il codice di uscita**: il fallback
sintetico è silenzioso, un run può "riuscire" producendo zero file, e i
risultati possono essere stale. Controllare sempre il `logger.error` finale che
elenca le colonne sintetiche.
