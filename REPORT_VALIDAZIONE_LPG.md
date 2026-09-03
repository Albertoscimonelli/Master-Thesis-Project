# Validazione dei profili domestici LPG — report completo Fasi 2, 3 e 4

Documento autosufficiente: contiene tutto il necessario per riprendere il
lavoro in una sessione nuova. Sostituisce come sintesi
`REPORT_VALIDAZIONE_FASE2.md`, che resta come registro di dettaglio passo per
passo.

Tutti i numeri sono **misurati eseguendo il codice** e riproducibili. I
rapporti per passo stanno in `CER_LoadProfiles/lpg_db/dati/validazione/`
(dodici file numerati); le citazioni statistiche si rigenerano con
`riferimento_istat.py`, il bersaglio con `riferimento_arera.py`.

---

## 1. Il problema, in due paragrafi

Una CER con 7 membri: 3 imprese (profili da RAMP) e 4 famiglie (profili da
LoadProfileGenerator, modello bottom-up **tedesco**). La domanda di ricerca
dipende dal fatto che i membri consumino **in momenti diversi**: Shapley,
Nucleolo e VLC si distinguono da una ripartizione volumetrica solo se le forme
dei profili differiscono. Quindi la forma conta quanto il livello.

Obiezione da chiudere: *perché profili costruiti su dati tedeschi dovrebbero
rappresentare famiglie italiane?* La risposta richiede due cose: correggere il
catalogo dove è dimostrabilmente tedesco (Fase 2), e misurare quanto il
risultato assomigli al dato italiano reale, sapendo distinguere ciò che è
difetto del modello da ciò che è artefatto statistico (Fase 3).

---

## 2. Metodo: chi calibra e chi giudica

| fonte | ruolo | copertura |
|---|---|---|
| **ARERA** provinciale 2024 + 2025 | **validazione** — energia misurata al contatore | Milano, per classe di potenza |
| ISTAT **AVQ 2024** (45.005 record) | calibrazione: orari, abitudini, **composizione dei nuclei** | **Lombardia**, n=4.139 (1.831 famiglie) |
| ISTAT **Censimento permanente 2021** (rilascio 2023) | calibrazione: marginali demografici | **per sezione**; comune di Milano, 6.059 sezioni |
| ISTAT **Consumi energetici 2021** | calibrazione: dotazione, vettori, ore d'uso | **Lombardia** |
| ISTAT **Dotazioni energetiche 2024** | calibrazione: raffrescamento | **Lombardia** |
| **ETHOS.ActivityAssure** (HETUS 2010) | calibrazione: forma infragiornaliera; controllo negativo su DE | Italia / Germania |

**Regola di non circolarità**: ISTAT entra come *input*, ARERA giudica come
*validazione indipendente*. Grandezze diverse (comportamento contro kWh),
campioni diversi, anni diversi. Calibrare e validare sulla stessa fonte non
sarebbe validazione.

**Soglia di accettazione**: non un numero scelto a tavolino, ma il **rumore
della fonte stessa** fra due anni consecutivi. Misurato: TVD orario
0,0063 (classe 1,5-3 kW) e 0,0107 (classe 3-4,5 kW). È una scelta metodologica
di questo lavoro, non uno standard di letteratura, e va dichiarata come tale.

**Metrica**: Total Variation Distance su curve **normalizzate a somma
unitaria**, così la forma si valida separatamente dal livello. Sono due errori
diversi — consumare troppo e consumare nel momento sbagliato — e un confronto
su curve non normalizzate li mescola in un numero che non dice quale dei due
sia il problema.

---

## 3. Che cosa è stato fatto

Quattordici commit, da `26d1eb0` a `e203ef7`.

**Fase 0** — infrastruttura di validazione (`26d1eb0`). Tre moduli nuovi in
`CER_LoadProfiles/lpg_db/`: `riferimento_arera.py` (bersaglio dai file grezzi,
con cache invalidata per SHA-256), `riferimento_istat.py` (rigenera ogni numero
citato nelle migrazioni), `valida_domestici.py` (confronto, riusa
`curve_medie()` da `confronta_profili.py` che resta invariato).

**Fase 1** — correzione della definizione di POD (`a6ab037`).

**Fase 2** — dieci passi misurati, otto migrazioni nuove del catalogo e due
modifiche di configurazione.

| # | passo | commit |
|---|---|---|
| 0 | riga zero | `e04e0ea` |
| 1 | POD = `Electricity_HH1` + `Electricity_House` | `a6ab037` |
| 2 | `energy_intensity` → `EnergySaving` | `26a038c` |
| 3 | `HT02` un solo circolatore | `6696e8b` |
| 4 | `D02` frigorifero di taglia realistica | `628d5a6` |
| 5 | `L11` ingresso in ufficio alle 08:00 | `47a1825` |
| 6 | `D01` piano cottura a gas, forno elettrico | `cbe0f67` |
| 7 | `HT01` raffrescamento + `house_type` per famiglia | `1af6785` |
| 8 | `L09` bucato e lavastoviglie su cancelli propri | `01698cd` |
| 9 | `L08` cena alle 19:30 | `4213748` |
| 10 | `L10` coda serale | `653d3d4` |

Due migrazioni previste dal piano si sono rivelate **non necessarie**: `D03`
(lampadine, già efficienti con `EnergySaving`) e `L07` (pranzo, orari già
italiani da `L03`).

**Fase 3** — separazione fra errore di numerosità ed errore di modello
(`e203ef7`), con `curva_numerosita.py` e un campione di 20 famiglie.

**Fase 4** — la composizione della società (§12). Scomposizione dello scarto
residuo, misura delle leve rimaste, e derivazione della composizione familiare
dalle fonti demografiche invece che a occhio. Produce `tipologie_famiglie.py` e
due configurazioni da venti famiglie, lombarda e milanese. **I due run non sono
ancora stati eseguiti.**

---

## 4. Risultati della Fase 2

Livello medio delle quattro famiglie, TVD medio per tipo di giorno, fasce
dell'aggregato. Riferimento: ARERA Milano Residente, media 2024-2025.

| passo | livello | TVD fer. | TVD sab. | TVD dom. | F1 | F2 | F3 |
|---|---:|---:|---:|---:|---:|---:|---:|
| riga zero | 1,90x | 0,312 | 0,269 | 0,259 | 30,01 | 42,00 | 27,99 |
| POD | 2,19x | 0,278 | 0,246 | 0,234 | 31,09 | 40,37 | 28,54 |
| `EnergySaving` | 1,42x | 0,295 | 0,286 | 0,269 | 31,81 | 39,87 | 28,32 |
| `HT02` | 1,34x | 0,315 | 0,293 | 0,273 | 31,04 | 40,56 | 28,41 |
| `D02` | 1,41x | 0,291 | 0,280 | 0,268 | 31,14 | 39,78 | 29,08 |
| `L11` | 1,38x | 0,294 | 0,291 | 0,261 | 28,10 | 41,97 | 29,92 |
| `D01` | 1,11x | 0,258 | 0,252 | 0,211 | 31,93 | 37,95 | 30,13 |
| `HT01` | 1,23x | 0,231 | 0,242 | 0,191 | 32,40 | 36,11 | 31,49 |
| `L09` | 1,25x | 0,227 | 0,191 | 0,177 | 31,08 | 37,63 | 31,28 |
| `L08` | 1,25x | 0,237 | 0,197 | 0,183 | 30,84 | 37,93 | 31,23 |
| **`L10`** | **1,25x** | **0,211** | **0,171** | **0,150** | **29,70** | **38,01** | **32,28** |
| **ARERA** | **1,00x** | **0,0063** | **0,0075** | **0,0033** | **31,11** | **30,29** | **38,60** |

### Forma oraria feriale finale, % della giornata

```
ora      0    1    2    3    4    5    6    7    8    9   10   11
LPG   2,36 1,53 1,50 1,55 1,57 1,79 2,78 4,53 3,37 2,35 2,25 2,54
ARERA 3,64 2,98 2,63 2,46 2,40 2,51 2,99 3,78 3,96 3,92 3,85 3,98

ora     12   13   14   15   16   17   18   19   20   21   22   23
LPG   2,89 4,13 3,94 3,90 4,43 6,37 10,35 10,83 8,53 6,28 5,96 4,26
ARERA 4,30 4,42 4,32 4,18 4,19 4,56 5,32 6,43 6,67 6,36 5,57 4,56
```

**Risolti**: livello (da 1,90x a 1,25x), picco mattutino (ore 07-09 dal 29,0%
al 10,25%, ARERA 11,66%), coda serale (ore 22-23 al 10,22% contro il 10,13%).

**Non risolto**: la sera. Ore 17-20 al **36,1%** contro il **22,98%** di ARERA,
picco alle 19 invece che alle 20.

---

## 5. Fase 3: la scomposizione dell'errore

### 5.1 Il campione

Venti famiglie: cinque semi per ciascuno dei quattro archetipi, configurazione
identica a quella principale (10 su 20 con condizionatore, come il 50% più
vicino al 55,6% reale in Lombardia). Da questo si estraggono 400 sottoinsiemi
casuali per ogni dimensione e si misura la distanza da un riferimento ARERA
composito, pesato sulle classi di potenza presenti nel sottoinsieme.

La distanza fra la media di N profili e una media di popolazione decresce come
1/√N, quindi si adatta **TVD(N) = a + b/√N**: il termine b/√N è campionamento,
il termine **a** è l'errore che resterebbe con un campione infinito.

### 5.2 Controllo preliminare: il campione è davvero un campione?

I totali annui dei cinque cloni di uno stesso archetipo differiscono di **meno
dell'1,3%**. Sembrava che il seme non producesse famiglie diverse — e che venti
profili fossero quattro ripetuti cinque volte, incapaci di smussare nulla.

**Sulla forma non è così.** La distanza fra cloni vale **0,0295**, cioè 4,7
volte il rumore della fonte ARERA. Il seme sposta *quando* accadono le cose
lasciando invariato *quanto*, ed è proprio lo spostamento che smussa i picchi.
Il campione è utilizzabile.

### 5.3 Risultato

| N | TVD medio | dev. std |
|---|---:|---:|
| 2 | 0,1826 | 0,0526 |
| 4 | 0,1567 | 0,0395 |
| 8 | 0,1514 | 0,0259 |
| 12 | 0,1473 | 0,0190 |
| 16 | 0,1423 | 0,0119 |
| 20 | 0,1412 | — |

```
a (errore irriducibile, modello) = 0,1219
b (errore di campionamento)      = 0,0813
residuo massimo del fit          = 0,0058
```

**Con quattro famiglie: 78% modello, 22% numerosità.** La numerosità **non è**
la spiegazione principale dello scarto, contro quanto ipotizzato a metà Fase 2.
Anche con un campione infinito il modello resterebbe a 0,122 dalla curva ARERA,
cioè diciannove volte il rumore della fonte.

> **Precisazione della Fase 4 (§12).** Quel `a = 0,122` è il limite per N→∞
> **a mix di archetipi fissato**, non un tetto dell'insieme di archetipi. Con
> le stesse quattro curve, riponderate, si arriva a 0,098. La frase «con
> questi quattro archetipi non si scende sotto quella soglia» va letta come
> «con questi quattro archetipi *presi in parti uguali*».

### 5.4 Da che cosa è fatto quel residuo di 0,122

Misura decisiva, e non prevista dal piano: **quanto distano fra loro archetipi
diversi rispetto a semi diversi dello stesso archetipo**.

```
distanza di forma fra SEMI dello stesso archetipo : 0,0295
distanza di forma fra ARCHETIPI diversi           : 0,2239
rapporto                                          : 7,6x
```

Matrice fra archetipi (distanza media di forma, giorno feriale):

| | pensionati | coppia lav. | fam. 1 figlio | fam. 3 figli |
|---|---:|---:|---:|---:|
| **pensionati** | *0,026* | 0,346 | 0,313 | 0,355 |
| **coppia lavoratori** | 0,346 | *0,041* | 0,131 | 0,092 |
| **famiglia 1 figlio** | 0,313 | 0,131 | *0,027* | 0,102 |
| **famiglia 3 figli** | 0,355 | 0,092 | 0,102 | *0,025* |

Distanza di ciascun archetipo da ARERA, e dell'aggregato:

```
pensionati          0,1747
coppia_lavoratori   0,2285
famiglia_1figlio    0,2182
famiglia_3figli     0,2473
AGGREGATO 20        0,1412
```

**Tre letture, tutte importanti.**

1. **L'identità dell'archetipo domina il seme di 7,6 volte.** Aggiungere semi
   non aggiunge diversità; aggiungere archetipi sì. È la leva più forte
   rimasta, e non passa dai time limit.
2. **Il collasso di forma di Marrasso persiste.** I tre nuclei di lavoratori
   distano fra loro 0,092-0,131, mentre i pensionati stanno a 0,31-0,36 da
   tutti. Il documento di contesto misurava 0,118-0,149 prima delle migrazioni:
   **la struttura non è cambiata**. Le migrazioni della Fase 2 hanno spostato
   *cancelli condivisi*, quindi hanno mosso tutte le famiglie insieme.
3. **L'aggregazione porta da 0,22 a 0,14 e poi si ferma.** Ogni archetipo preso
   da solo dista 0,17-0,25 da ARERA; l'aggregato di venti arriva a 0,141 e
   l'estrapolazione a 0,122. Con **questi quattro** archetipi non si scende
   sotto quella soglia, per quanti profili si generino.

---

## 6. Rivalutazione dei problemi segnalati nel report di Fase 2

È la domanda che la Fase 3 doveva chiudere. Per ogni difetto: che cosa dicono
adesso i dati, e che cosa conviene farne.

### 6.1 Sera in eccesso — **è modello, non numerosità, ma non è il catalogo**

Ore 17-20 al 36,1% contro il 22,98% di ARERA. Nel report di Fase 2 era
classificato come «da verificare col campione prima di intervenire».

**Verdetto: solo il 22% dello scarto è numerosità, quindi il difetto è reale.**
Ma la causa non è nei cancelli dei pasti, che sono già stati portati sugli
orari misurati da ActivityAssure. È il **rientro dal lavoro**: i tratti
d'ufficio hanno durate fisse (06h, 07h, 08h, 09h, 10h, 11h) e partono tutti dal
cancello delle 08:00, quindi ogni persona rientra a un'ora determinata e sempre
la stessa. Quattro famiglie danno pochi orari di rientro distinti; venti
famiglie che sono quattro archetipi ne danno gli stessi pochi.

**Conseguenza operativa: smettere di spostare i cancelli dei pasti.** `L08` ha
già mostrato rendimenti decrescenti (picco da 18 a 19, ma TVD peggiorato su due
famiglie). Il difetto si chiude con **diversità di orari di lavoro**, non con
altre migrazioni sulla cena.

### 6.2 Carico notturno basso — **difetto di catalogo, correggibile**

Ore 00-03 all'1,5-2,4% contro il 2,4-3,6% di ARERA, dopo che `D02` ha già
recuperato una parte. Questo è un difetto di **dotazione**, non di orari, e
quindi correggibile con migrazioni dello stesso tipo di quelle già fatte.

Candidati identificati e non ancora esaminati: gli **standby** (LPG ha un flag
`IsStandbyDevice` e un `DefaultStandbyProfileID` mai ispezionati), e il
**congelatore separato**, che ISTAT dà al 22,0% delle famiglie lombarde e che
nel catalogo esiste (quattro modelli, 282 kWh/anno dichiarati) ma di cui non è
stato verificato se le famiglie lo possiedano.

**Conviene farlo**: è a basso rischio, ben referenziato, e agisce su F3 che è la
fascia più lontana dal bersaglio (32,28 contro 38,60).

### 6.3 Circolatore acceso tutto l'anno — **residuo piccolo, correzione pulita**

`TL 3` è condizionato alla temperatura ma ha finestra 00:00-20:00, quindi la
pompa gira anche ad agosto. Non corretto in Fase 2 perché `TL 3` è condiviso da
18 house type.

La tecnica per farlo esiste ed è già stata usata due volte con successo in
`L09`: **creare un time limit nuovo** con l'orario italiano (ISTAT Tavola 7:
10,06 h/giorno nei mesi freddi) e ripuntarci solo le righe di HT06 e HT07.
Nessun oggetto condiviso viene toccato.

**Guadagno atteso piccolo** (la componente casa è già scesa da 898 a 125
kWh/anno), ma la correzione è pulita e chiude un'incoerenza fisica evidente.

### 6.4 Ampiezza del pranzo — **non si corregge con i time limit**

AVQ: per il 59,4% dei lombardi il pranzo è il pasto principale e il 64,6% lo
consuma in casa nei feriali. Gli orari sono già giusti (`L03`), ma le ore 12-15
valgono il 15,4% contro il 17,2% di ARERA.

Il divario è di **ampiezza**, e dipende da quante famiglie possiedono il tratto
che abilita «cucina il pranzo»: è composizione dei nuclei, cioè
`tblHouseholdTraits`. **Confluisce nella raccomandazione principale** (§7.1):
si risolve insieme al problema degli archetipi, non da solo.

### 6.5 24 dicembre festivo — **errore vero, correzione banale**

Non è festivo in Italia. La voce è catalogata *Worldwide* ed è sfuggita a
`H01`-`H03`, che hanno tolto le festività tedesche. Sposta il 24 dicembre in F3
quando dovrebbe essere feriale.

**Effetto trascurabile sui numeri, ma è un errore fattuale in un catalogo che
si dichiara italiano.** Costa una riga (`H04`).

### 6.6 Raffrescamento non stagionalizzato — **limite strutturale, si dichiara**

`AdjustYearlyCoolingHours = 0`: a differenza del riscaldamento, il
raffrescamento non viene riscalato sui gradi giorno e resta identico a Milano
come a Palermo. Non è correggibile con una migrazione: è come il modello è
fatto. **Va dichiarato in tesi come limite**, non nascosto.

Nota: il livello è comunque corretto per Milano, perché `HT01` ha tarato
`CoolingYearlyTotal` sul dato lombardo. Il limite si manifesterebbe replicando
lo studio in un'altra provincia.

### 6.7 Riscaldamento a 15.000 kWh termici — **non rilevante per la CER**

Riscalato sui gradi giorno di Milano (2.404 GG contro i 4.000 di riferimento)
dà circa 9.000 kWh termici effettivi: alto per un appartamento. Ma è **gas**, e
non tocca il contatore elettrico che la CER misura. Rilevante solo se in
futuro si modellassero pompe di calore.

### 6.8 Nomi dei time limit non aggiornati — **cosmetico ma insidioso**

`TL 119` si chiama *Lunch Time (11:30-13:00)* ma contiene 12:30-14:30. Ha già
causato un errore in questa sessione: il piano prescriveva di correggere il
pranzo feriale perché il nome diceva che era tedesco, mentre `L03` lo aveva già
sistemato.

**Consigliato**: una migrazione `N01` che allinei i nomi ai contenuti per i time
limit toccati dalle migrazioni italiane. Costa poco e previene errori futuri.

---

## 7. Raccomandazioni, in ordine di valore

### 7.1 Aumentare la diversità di archetipi — **la leva più forte**

Gli archetipi distano fra loro **7,6 volte** più di quanto distino i semi. Con
quattro composizioni familiari il modello si ferma a 0,122 dalla curva ARERA
per quanti profili si generino: è il tetto strutturale misurato.

Tre strade, in ordine di costo crescente:

1. **Più famiglie CHR dal catalogo.** Ce ne sono 66; se ne usano 4. Aggiungerne
   altre con composizioni diverse (monogenitore, persona sola, coppia di
   pensionati con lavoro part-time) è gratis: si tocca solo la configurazione.
   Il censimento ISTAT 2021 per sezione (`PF3`…`PF8`) dà la distribuzione reale
   delle famiglie per numero di componenti nel quartiere della CER, quindi la
   scelta è documentabile.
2. **`ByTemplateName`** invece di `ByHouseholdName`. Estrae persone e tratti a
   caso *entro* il template, quindi due famiglie dello stesso tipo diventano
   davvero diverse. È esattamente l'antidoto al collasso di forma, e richiede
   una modifica contenuta in `lpg_runner.py` (una `HouseholdDataSpecificationType`
   diversa).
3. **`ByPersons`**, che definisce la composizione a mano con età, genere e
   *living pattern tag*. Massimo controllo, massimo costo.

**Raccomandazione: cominciare da (1), che è configurazione pura, e misurare.**
Se il TVD dell'aggregato scende sensibilmente passando da 4 a 8-10 archetipi
diversi, è la conferma che il tetto era diversità e non catalogo.

> **Eseguita nella Fase 4 (§12), con una correzione.** La leva non è tanto
> *aggiungere* archetipi quanto **pesarli come sono nella popolazione**: la
> composizione non va scelta per numero di componenti soltanto, come diceva
> questa sezione, ma per **numero di componenti e condizione professionale**,
> perché è la seconda a decidere chi è in casa di giorno. Le due
> configurazioni prodotte sono `simulation_config.lombardia20.yaml` e
> `simulation_config.milano20.yaml`, con venti template diversi ciascuna.

### 7.2 Chiudere i due difetti di dotazione ancora aperti

**Carico notturno** (§6.2) e **circolatore stagionale** (§6.3). Entrambi a basso
rischio, ben referenziati, con la tecnica già collaudata. Agiscono su F3, la
fascia più lontana dal bersaglio.

Più `H04` (24 dicembre) e `N01` (nomi dei time limit), che costano una riga
ciascuna.

### 7.3 Smettere di spostare i cancelli degli orari

`L11`, `L09`, `L08` e `L10` hanno esaurito il margine: `L08` ha già mostrato
rendimenti decrescenti e `L11` ha peggiorato l'indicatore aggregato pur essendo
una correzione giusta. Il residuo serale è **rientro dal lavoro sincronizzato**,
non orario dei pasti, e si chiude con la diversità (§7.1).

Ulteriori migrazioni sui pasti rischiano di **peggiorare la plausibilità dei
profili individuali** per inseguire un aggregato, che è esattamente
l'antipattern che il progetto si è dato la regola di evitare.

### 7.4 Ridefinire il criterio di accettazione, e dichiararlo

Il rumore della fonte (0,006-0,011) è la variabilità fra due anni della **stessa
media di popolazione**: non è il metro giusto per un campione di quattro
famiglie. Confrontare 0,211 con 0,0063 e concludere «non validato» è mal posto.

**Proposta difendibile in tesi**, alla luce della Fase 3:

- si dichiara che si valida il **livello annuo**, la **ripartizione in fasce
  F1/F2/F3** e l'**ora del picco**, che sono grandezze integrali e robuste
  all'aggregazione;
- la forma oraria punto per punto si riporta come **confronto qualitativo**,
  accompagnata dalla scomposizione della Fase 3 (78% modello, 22% numerosità) e
  dal tetto strutturale di 0,122 dovuto ai quattro archetipi;
- la soglia sul rumore della fonte resta citata, ma come **limite inferiore
  teorico** che un campione finito non può raggiungere, non come test.

### 7.5 Misurare l'eterogeneità di forma prima di trarre conclusioni sulla CER

**È la raccomandazione più importante per la domanda di ricerca**, e non è
ancora stata eseguita.

I dati della Fase 3 sono già un allarme: i tre nuclei di lavoratori distano fra
loro 0,092-0,131, contro gli 0,118-0,149 misurati **prima** delle migrazioni. La
struttura non è cambiata, e potrebbe essersi leggermente compressa. Se
l'eterogeneità di forma è diminuita, Shapley, Nucleolo e VLC si distinguono
*meno* da una ripartizione volumetrica di quanto facessero prima — cioè le
correzioni al catalogo avrebbero indebolito la premessa della tesi mentre
miglioravano il realismo.

Da eseguire con `shape_heterogeneity.m`, confrontando con i valori di
riferimento del §10 di `CONTESTO_LPG_RAMP.md` (forma 1,0695; dentro tipologia
0,9314; fra tipologie 1,1248).

Se il valore è sceso, la §7.1 non è più solo un'ottimizzazione della
validazione: diventa **necessaria alla domanda di ricerca**.

---

## 8. Stato del progetto — da sapere prima di riprendere

**Il progetto è in uno stato incoerente e va rimesso in bolla per primo.**

`profili_tutti.csv` ha cambiato *significato* (ora è il POD, non la sola
componente famiglia) e i valori sono cambiati molto: livello medio da 1,90x a
1,25x del bersaglio ARERA. Ma **`MAIN.m` non è stato rieseguito**: tutti i
numeri MATLAB del progetto — bilancio CER, energia condivisa, Shapley,
Nucleolo, VLC, indici di equità — si riferiscono ai profili precedenti.

Non è rotto nulla: i risultati a valle semplicemente non corrispondono più agli
input.

### Primi passi della prossima sessione

1. **Rigenerare i risultati MATLAB.** Verificare che l'assert del VLC non
   fallisca (`MAIN.m` riga ~1306, sensibile alla composizione) e che
   `align_members_to_users.m` non segnali disallineamenti.
2. **Misurare l'eterogeneità di forma** (§7.5). È la misura che decide se le
   correzioni hanno aiutato o danneggiato la domanda di ricerca.
3. **Aggiornare `CONTESTO_VALIDAZIONE_ARERA.md` e `CONTESTO_LPG_RAMP.md`** con
   le correzioni del §9 e i nuovi numeri di riferimento.
4. **Eseguire i due run della Fase 4** (§12.5), quando si decide di farlo, e
   sistemare prima `curva_numerosita.py` come indicato lì. Sono indipendenti dai
   passi 1-3: scrivono in cartelle proprie e non toccano `profili_tutti.csv`.

Nota sullo stato del repository: `profili_tutti.csv` è modificato ma **non
committato**, le schede di `CER_configuration/` puntano ancora allo snapshot
`storico/profili_tutti_20260825_163345.csv` (pre-validazione, e per giunta
ignorato da git), e `profili_famiglie.csv` e `profilo_CER_aggregato.csv` sono
tracciati ma fermi al 24 agosto, con tre colonne invece di quattro. Vanno
rimessi in bolla prima di attribuire significato a qualunque numero MATLAB.

---

## 9. Correzioni a conclusioni precedenti

Emerse misurando. Contraddicono quanto scritto nei documenti di contesto o nel
piano, e vanno recepite.

1. **Il problema di agosto in larga parte non esiste: era geografia.** A Milano
   agosto è un mese basso (7,48% nel 2025, 9,15% nel 2024), non il massimo
   dell'anno come nel dato nazionale (10,11%).
2. **La forma mensile è una metrica debole**: il rumore anno-su-anno vale L1
   0,069-0,086, quindi lo scarto LPG di 0,162 è solo ~2× il rumore.
3. **I dati orari ARERA coprono solo i clienti trattati orari** — confermato
   dalla documentazione ARERA, non è più un'ipotesi.
4. **HETUS 2010 regge strutturalmente**: composizione per stato occupazionale
   HETUS-IT 2010 contro ISTAT 2023, scarto massimo 3,0 punti. Eccezione: il
   lavoro da casa (20,7% degli occupati del Nord-Ovest nel 2023), che nel 2010
   non esisteva e che questo lavoro **non** modella.
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
   kWh (classe 1,5-3) e ~2.220 (classe 3-4,5). Gli scarti dei passi 1-6 sono
   sottostimati di circa 16 punti. Risolto dal passo 7.
10. **`L01` aveva peggiorato l'ingresso al lavoro.** Il valore tedesco (08:00)
    era già corretto per l'Italia: AVQ 2024 sui soli occupati lombardi dà
    mediana di uscita 07:30 e tragitto 15 min. Rettificato da `L11`.
11. **La numerosità non era la spiegazione principale dello scarto**, contro
    quanto ipotizzato a metà Fase 2: vale il 22%, non la maggioranza.
12. **Il tetto di 0,122 non è un limite dei quattro archetipi, è un limite del
    loro mix.** Riponderando le stesse quattro curve si arriva a 0,098 (§12.3).
    Il §5.3 e il §7.1 vanno letti con la precisazione lì aggiunta.
13. **Sera, notte e pranzo non sono tre difetti: sono uno.** Su una curva
    normalizzata l'eccesso serale *impone* il deficit altrove. Le ore 17-20
    portano l'89% dell'eccesso totale, le sole 18 e 19 il 64% (§12.1). Il §6.2
    e il §6.4 restano corretti come interventi, ma non sono indipendenti dal
    §6.1 come il testo lasciava intendere.
14. **La sincronizzazione serale ha parametri propri nel catalogo, mai
    ispezionati.** Il §6.1 concludeva che si chiudesse solo con più diversità.
    Esistono invece `tblTimeLimitEntries.RandomizeTimeAmount` (oggi 15 min sul
    cancello dell'ufficio) e `tblAffordances.TimeStandardDeviation` (0,1 su
    tutti i tratti di lavoro), cioè le manopole che governano proprio quella
    sincronizzazione. `L03` usa già la prima con `rand=45` (§12.2).

---

## 10. Riproducibilità

```bash
# ricostruire il catalogo (11 migrazioni originali + 8 nuove)
cd CER_LoadProfiles/lpg_db && ../../venv/Scripts/python build_italian_db.py

# rigenerare i profili della CER (4 famiglie, ~11 minuti)
cd CER_LoadProfiles && ../venv/Scripts/python generate_load_profiles.py \
    --config config/simulation_config.yaml

# misurare contro ARERA
cd CER_LoadProfiles/lpg_db && ../../venv/Scripts/python valida_domestici.py \
    ../outputs/csv/profili_tutti.csv

# rigenerare le citazioni statistiche usate nelle migrazioni
../../venv/Scripts/python riferimento_istat.py

# campione allargato (20 famiglie, ~45 minuti) e scomposizione dell'errore
cd CER_LoadProfiles && ../venv/Scripts/python generate_load_profiles.py \
    --config config/simulation_config.campione20.yaml
cd lpg_db && ../../venv/Scripts/python curva_numerosita.py \
    ../outputs/csv_campione20/profili_tutti.csv

# le due societa' della Fase 4 (20 famiglie ciascuna, ~45 minuti l'una)
cd CER_LoadProfiles && ../venv/Scripts/python generate_load_profiles.py \
    --config config/simulation_config.lombardia20.yaml
../venv/Scripts/python generate_load_profiles.py \
    --config config/simulation_config.milano20.yaml
```

Il `.db3` non è versionato: si ricostruisce. `build_manifest.json` registra il
conteggio righe di ogni migrazione ed è l'evidenza revisionabile. Ogni build
verifica lo SHA-256 del catalogo tedesco originale e si ferma se è cambiato.

La cache ARERA in `lpg_db/dati/riferimento_arera/` **è versionata** in deroga
alla regola sui derivati: i sorgenti sono 250 MB fuori dal repository e senza la
cache la validazione non sarebbe rieseguibile. Il motivo è annotato nel
`.gitignore`.

### Tre trappole che rendono insufficiente il codice di uscita

1. **Il fallback sintetico è silenzioso.** `run_lpg()` cattura ogni errore pyLPG
   e sostituisce un profilo finto; il processo esce con 0 e i CSV vengono
   scritti. Controllare sempre il `logger.error` finale che elenca le colonne
   sintetiche.
2. **Un run può "riuscire" producendo zero file**, se il motore rifiuta il
   catalogo con `DataIntegrityException`.
3. **I risultati possono essere stale**: se un run muore,
   `read_all_json_results_in_directory()` restituisce quelli del run precedente
   senza errore.

`PRAGMA integrity_check` verifica la struttura SQLite, non la coerenza
semantica del catalogo: ogni migrazione richiede uno smoke run manuale.

---

## 11. Dati esterni

Tutto in `C:\Users\scimo\Downloads\File Utili per profili\`, più
`Downloads\UsoTempo_2023_IT\`. Il percorso è sovrascrivibile con la variabile
d'ambiente `CER_DATI_ESTERNI`.

**Non ottenibile, si aggira**: il numero di clienti ARERA per classe di potenza
e provincia non esiste nelle fonti aperte (verificato). L'assegnazione delle
famiglie alle classi resta un'assunzione dichiarata, con i risultati riportati
anche contro la classe adiacente.

**Non ancora rilasciato**: il diario ISTAT Uso del tempo 2023, che sostituirebbe
HETUS 2010 per la forma infragiornaliera. Molto meno critico di prima: AVQ 2024
copre orari di uscita, spostamento, pranzo e pasto principale con dati lombardi
recenti.

---

## 12. Fase 4: la composizione della società

Tutti i numeri di questa sezione si rigenerano con
`CER_LoadProfiles/lpg_db/tipologie_famiglie.py`. Le due configurazioni prodotte
sono `config/simulation_config.lombardia20.yaml` e
`config/simulation_config.milano20.yaml`. **I due run non sono ancora stati
eseguiti.**

Avvertenza sulla metrica: qui la TVD è quella **dell'aggregato** delle quattro
famiglie (0,134 pesando l'energia, 0,140 pesando le forme allo stesso modo).
Non è confrontabile con lo **0,211** del §4, che è la media delle TVD delle
singole famiglie. I riferimenti omogenei sono quelli della Fase 3: aggregato di
venti 0,141, estrapolazione 0,122.

### 12.1 I difetti residui sono uno solo, non quattro

Il §6 elenca sera, notte e pranzo come problemi separati. Su una curva
**normalizzata** non possono esserlo: l'eccesso da una parte impone il deficit
dall'altra. Contributo di ogni ora allo scarto, in punti percentuali:

```
ora 18   LPG  9,95   ARERA 5,30   +4,65      ora 10   LPG 2,24   ARERA 3,86   -1,62
ora 19   LPG 10,54   ARERA 6,60   +3,94      ora  9   LPG 2,34   ARERA 3,95   -1,61
ora 17   LPG  6,24   ARERA 4,48   +1,76      ora 11   LPG 2,54   ARERA 3,95   -1,41
ora 20   LPG  8,42   ARERA 6,79   +1,63      ora 12   LPG 2,96   ARERA 4,31   -1,35
```

L'eccesso totale vale 13,41 punti, di cui **11,99 nelle ore 17-20 (l'89%)**; le
sole ore 18 e 19 ne portano il 64%. Tutto il resto è un deficit poco profondo e
diffuso su 00-05 e 09-12. Il «carico notturno basso» (§6.2) e il «pranzo
stretto» (§6.4) sono in larga parte l'**ombra aritmetica** del picco serale.

Il difetto non è distribuito fra le famiglie:

| | ore 17-20 | picco | ore 09-12 |
|---|---:|---:|---:|
| `household_1` pensionati | 17,64% | ora 13 | 16,27% |
| `household_2` coppia lavoratori | 37,83% | ora 19 | 7,59% |
| `household_3` famiglia 1 figlio | 41,33% | ora 18 | 8,40% |
| `household_4` famiglia 3 figli | 43,99% | ora 19 | 7,30% |
| **ARERA** | **23,17%** | **ora 20** | **16,08%** |

I pensionati sono **già calibrati** — 16,27% di giorno contro 16,08% — e in
serata stanno perfino sotto il bersaglio. Lo scarto è interamente la forma dei
nuclei di lavoratori.

### 12.2 Tre leve, misurate senza rigenerare nulla

Simulazioni sulla curva già prodotta, quindi indicative e non predittive.

**A — Dispersione degli orari.** Il §6.1 concludeva che la sincronizzazione
serale si chiudesse solo con più diversità. Il catalogo ha invece due parametri
espliciti, mai ispezionati prima: `tblTimeLimitEntries.RandomizeTimeAmount` e
`tblAffordances.TimeStandardDeviation`. Stato misurato: il cancello
dell'ufficio `TL 12` ha `RandomizeTimeAmount = 15` minuti, e tutti e nove i
tratti di lavoro e scuola hanno `TimeStandardDeviation = 0,1`. La migrazione
`L03` usa già il primo con `rand=45` sul pranzo, quindi la tecnica è collaudata.

```
dispersione aggiuntiva   sigma 0,75 h -> TVD 0,1207     sigma 1,5 h -> TVD 0,1060
(convoluzione gaussiana) sigma 1,00 h -> TVD 0,1168     sigma 2,0 h -> TVD 0,0898
```

La convoluzione liscia tutta la giornata, mentre una desincronizzazione vera
agirebbe soprattutto sulle 17-20 e non sbaverebbe il picco delle 07, che oggi è
corretto: la stima è un ordine di grandezza.

**B — Carico di base costante** (§6.2, quantificato). 100 kWh/anno per famiglia
valgono +0,0076; 200 kWh +0,0148; 300 kWh +0,0212. Con lo standby a circa il 7%
di 2.450 kWh più il congelatore (282 kWh dichiarati nel catalogo × 22,0% di
possesso, ISTAT Consumi energetici 2021) si arriva a circa 230 kWh difendibili,
cioè **+0,017**.

**C — Il mix degli archetipi.** Cercando i pesi delle **stesse quattro curve
già generate** che minimizzano la distanza da ARERA:

```
mix attuale (25% ciascuno) ......... TVD 0,1399
mix ottimo delle stesse 4 curve .... TVD 0,0980
   pensionati 60%   coppia lav. 32%   fam. 1 figlio 0%   fam. 3 figli 8%
```

Zero migrazioni, zero archetipi nuovi, zero rigenerazione, e si scende **sotto
il tetto di 0,122** che il §5.3 dichiarava irraggiungibile. Da qui la
correzione 12 del §9.

### 12.3 La composizione, derivata dalla demografia

Il mix **non** va scelto minimizzando la TVD: sarebbe calibrare sul validatore,
cioè la circolarità che il §2 vieta. Si deriva dalle fonti di calibrazione, e
poi si guarda dove cade.

**Fonti e loro ruolo.**

- ISTAT, **Aspetti della vita quotidiana 2024**, microdati (`AVQ_Microdati_2024.txt`),
  Lombardia (`REGMf = '030'`): 1.831 famiglie, 4.139 individui. L'indagine
  intervista **tutti** i componenti di ogni famiglia — copertura verificata nel
  codice, non assunta: 100%. Per ciascun membro si hanno età (`ETAMi`) e
  condizione professionale (`CONDMi`); il peso `COEFIN` è costante entro
  famiglia ed è quindi il peso del nucleo. Restituisce 4,56 milioni di famiglie
  contro le 4,57 del censimento.
- ISTAT, **Censimento permanente della popolazione 2021** (rilascio 2023), dati
  per sezione, `R03_Lombardia_2023_sezioni.xlsx`: 67.419 sezioni in Lombardia,
  di cui **6.059 nel solo comune di Milano** (743.276 famiglie, 1.371.499
  residenti). Variabili usate: `PF3`-`PF8` (famiglie per numero di componenti),
  `P1` (popolazione), `P27`-`P29` (65 e oltre), `P101` (occupati 15-64).
- ISTAT, **Dotazioni energetiche delle famiglie 2024**, Tavola 3: 55,6% delle
  famiglie lombarde con impianto di raffrescamento.

**Il limite geografico e come si aggira.** I microdati AVQ pubblici si fermano
alla **regione**: non esiste il dettaglio provinciale. Verificate tutte le 737
variabili del tracciato; `METRO` e `STCOM`, che il nome farebbe sembrare
territoriali, sono domande del questionario. Milano si ottiene per
**post-stratificazione**: si riponderano le famiglie AVQ (IPF) finché
riproducono due marginali del censimento comunale, la distribuzione per numero
di componenti e la quota di popolazione 65+.

**Verifica indipendente della calibrazione**: il tasso di occupazione che ne
risulta è **47,2%** contro il **46,8%** del censimento, e non era un vincolo.
Calibrare sulla sola dimensione familiare sarebbe stato sbagliato e si vede:
dava 27,6% di 65+ contro il 22,2% reale, perché le unipersonali milanesi sono
molto più giovani di quelle regionali.

**Risultato.**

| | Lombardia | Milano |
|---|---:|---:|
| tutti gli adulti occupati | 36,8% | 43,9% |
| solo anziani non occupati | 26,3% | 25,9% |
| un adulto in casa di giorno | 26,6% | 18,5% |
| nessun occupato, non solo anziani | 10,3% | 11,6% |
| **almeno un adulto in casa nei feriali** | **63,2%** | **56,1%** |
| famiglie con figli minori | 21,7% | 15,7% |
| 65+ sulla popolazione | 23,4% | 22,2% |

```
famiglie per componenti      1      2      3      4     5+
Lombardia                 38,6%  27,9%  16,9%  12,4%   4,3%
Milano comune             55,6%  21,3%  11,9%   8,4%   2,9%
```

Il modello fino alla Fase 3 assumeva **25%** di famiglie con qualcuno in casa e
**50%** con figli, e **nessuna** famiglia unipersonale.

**Il test non circolare.** Costruendo il mix solo dai dati demografici e
misurandolo poi contro ARERA:

```
mix attuale (25% ciascuno) ......................... TVD 0,1399
mix da dati Milano, i 'misti' contati come in casa . TVD 0,1035
mix da dati Milano, pesato sulle dimensioni ........ TVD 0,1017
ottimo matematico delle stesse 4 curve ............. TVD 0,0980
```

La demografia da sola arriva a **0,102**, praticamente all'ottimo. E il minimo
della curva di sensibilità sulla quota «qualcuno in casa» cade al 55%, mentre
la demografia milanese dice 56,1%: **due fonti indipendenti che si incontrano**.
Questi mix mappano le unipersonali sulla curva della coppia di lavoratori,
perché quella curva non esiste ancora: 0,102 è quindi una stima prudente.

### 12.4 Le due società

Venti famiglie ciascuna, **venti template diversi**, 34 template distinti sui 66
del catalogo. La ragione di non ripetere: cinque semi dello stesso archetipo
distano 0,0295 sulla forma, archetipi diversi 0,2239 (§5.4).

I due file differiscono **solo** per le venti famiglie. Anno, meteo, quota di
raffrescamento (11 su 20 in entrambi, contro il 55,6% ISTAT), house type di base
ed energy intensity sono identici, così il confronto è attribuibile alla sola
composizione.

L'allocazione è **gerarchica** — prima le classi di dimensione, poi le tipologie
entro ciascuna — perché ripartire direttamente le venti celle non conserverebbe
il marginale censuario delle dimensioni, misurato sull'intera popolazione, e lo
sacrificherebbe a celle campionarie molto più incerte.

**Lombardia** (8 / 6 / 3 / 2 / 1 per numero di componenti):

| template | descrizione | pers. | raffr. |
|---|---|---:|:---:|
| `CHR23` | Single man over 65 years | 1 | sì |
| `CHR24` | Single woman over 65 years | 1 | — |
| `CHR30` | Single, Retired Man | 1 | sì |
| `CHR31` | Single, Retired Woman | 1 | — |
| `CHR36` | Single woman, 30-64, without work | 1 | sì |
| `CHR07` | Single with work | 1 | sì |
| `CHR35` | Single woman, 30-64, with work | 1 | — |
| `CHR37` | Single man, 30-64, with work | 1 | sì |
| `CHR54` | Retired Couple, no work | 2 | — |
| `CHR16` | Couple over 65 years | 2 | sì |
| `CHR04` | Couple 30-64, 1 at work, 1 at home | 2 | — |
| `CHR40` | Couple 30-64, without work | 2 | sì |
| `CHR39` | Couple 30-64, with work | 2 | — |
| `CHR21` | Couple 30-64, shift worker | 2 | sì |
| `CHR14` | Couple at work + Senior at home | 3 | — |
| `CHR60` | Family, 1 toddler, one at work, one at home | 3 | sì |
| `CHR03` | Family, 1 child, both at work | 3 | — |
| `CHR53` | 2 Parents, 1 Working, 2 Children | 4 | sì |
| `CHR27` | Family both at work, 2 children | 4 | — |
| `CHR20` | one at work, one work home, 3 children | 5 | sì |

**Milano** (11 / 4 / 2 / 2 / 1):

| template | descrizione | pers. | raffr. |
|---|---|---:|:---:|
| `CHR23` | Single man over 65 years | 1 | sì |
| `CHR24` | Single woman over 65 years | 1 | — |
| `CHR30` | Single, Retired Man | 1 | sì |
| `CHR31` | Single, Retired Woman | 1 | — |
| `CHR11` | Student, Female, Philosophy | 1 | sì |
| `CHR07` | Single with work | 1 | — |
| `CHR09` | Single woman, 30-64, with work | 1 | sì |
| `CHR10` | Single man, 30-64, shift worker | 1 | — |
| `CHR13` | Student with Work | 1 | sì |
| `CHR25` | Single woman under 30 with work | 1 | — |
| `CHR29` | Single man under 30 with work | 1 | sì |
| `CHR51` | Couple over 65 years II | 2 | — |
| `CHR34` | Couple under 30, one at work, one at home | 2 | sì |
| `CHR32` | Couple under 30 without work | 2 | — |
| `CHR33` | Couple under 30 with work | 2 | sì |
| `CHR45` | Family with 1 child, 1 at work, 1 at home | 3 | — |
| `CHR08` | Single woman, 2 children, with work | 3 | sì |
| `CHR44` | Family with 2 children, 1 at work, 1 at home | 4 | — |
| `CHR27` | Family both at work, 2 children | 4 | sì |
| `CHR15` | Multigenerational: working couple, 2 children, 2 seniors | 6 | sì |

**Scelte che il catalogo permette e che prima non erano rappresentate**: due
turnisti (`CHR21`, `CHR10`), che sono le uniche forme con consumo notturno per
ragioni di orario e non di dotazione; una famiglia con **lavoro da casa**
(`CHR20`), fenomeno che riguarda il 20,7% degli occupati del Nord-Ovest nel 2023
e che HETUS 2010 non poteva contenere (§9.4); un nucleo **monogenitore** che
lavora (`CHR08`); due **studenti** soli, tipici di Milano.

**Residui dichiarati.** Le famiglie con minori risultano il 25% in entrambe le
configurazioni, contro il 21,7% atteso in Lombardia e il 15,7% a Milano. Non è
una scelta: il marginale censuario assegna una famiglia alla classe 5+ e nel
catalogo ogni template da cinque o più componenti ha figli. A venti unità il
residuo non è eliminabile; con quaranta si dimezzerebbe.

### 12.5 Che cosa i due run devono misurare

1. **La TVD dell'aggregato scende come previsto?** Attesa intorno a 0,10 contro
   lo 0,141 del campione a venti della Fase 3. Se resta sopra 0,12, la lettura
   della §12.3 è sbagliata e va rivista prima di procedere.
2. **L'eterogeneità di forma sale o scende?** È la domanda del §7.5, e questa
   volta ci sono i dati per rispondere: mettere insieme un single che lavora e
   un pensionato solo dovrebbe **aumentarla**, perché sono la coppia più
   distante della matrice del §5.4 (0,346). Se è così, la correzione demografica
   rafforza la premessa della tesi invece di indebolirla.
3. **Quanto pesa la scelta fra città e provincia** sui risultati della CER
   (Shapley, Nucleolo, VLC): è la differenza fra i due file, ed è la ragione per
   cui sono due e non uno.

**Prerequisito tecnico.** `curva_numerosita.py` assegna la classe di potenza
assumendo quattro archetipi da cinque copie (`classe_di()`, riga 81). Con venti
gruppi da uno quella regola non vale più: va fatta leggere dalla chiave
`classe_potenza` che entrambe le configurazioni dichiarano, altrimenti il
riferimento ARERA composito è sbagliato. **Da fare prima di analizzare i run**,
non prima di lanciarli.

### 12.6 Limiti

- La post-stratificazione assume che, a parità di dimensione e struttura per
  età, le famiglie milanesi si comportino come quelle lombarde. Non verificabile
  con queste fonti.
- Censimento 2021 (rilascio 2023) contro AVQ 2024: disallineamento di anni.
- «In casa nei feriali» è dedotto dalla condizione professionale, non dalla
  presenza osservata. AVQ ha le domande sul tempo per raffinarlo, già cablate in
  `riferimento_istat.py`.
- La quota di raffrescamento è regionale: il dato comunale non esiste. Tenerla
  identica nei due file è comunque la scelta corretta per il confronto.
- L'assegnazione delle classi di potenza resta l'assunzione dichiarata al §11.

---

## 13. Registro delle modifiche al catalogo tedesco, fonte per fonte

Questa sezione è pensata per essere letta da sola. Per ogni modifica: che cosa
diceva il catalogo tedesco originale, che cosa dice adesso, la fonte che
giustifica il cambio, e la ragione. È il materiale per il capitolo di tesi in
cui si spiega perché profili costruiti su dati tedeschi possono rappresentare
famiglie italiane.

**Base di partenza**: `profilegenerator.db3` distribuito con `pylpg`
(`venv/Lib/site-packages/pylpg/C1/`), SHA-256 `e782bd13…`. Ogni build verifica
l'impronta del sorgente e si ferma se è cambiata, così le modifiche restano
riferite a una base nota. Il database italiano **non è versionato**: si
ricostruisce con `build_italian_db.py`, e `build_manifest.json` registra quante
righe ha toccato ciascuna migrazione. Sono **19 migrazioni** più quattro
modifiche di configurazione.

Convenzione LPG che serve per leggere il resto: un **time limit** (TL) è un
cancello orario, cioè la finestra entro cui un'attività può iniziare; è un
oggetto **condiviso**, quindi modificarne uno agisce su tutte le 66 famiglie
del catalogo insieme. Il campo `RandomizeTimeAmount` è la dispersione in minuti
attorno all'apertura del cancello: è ciò che decide quanto le attività si
addensano sull'orario di apertura.

---

### 13.1 Calendario — 3 migrazioni, 9 righe

| | |
|---|---|
| **H01** | *Origine*: il calendario di Milano portava **Venerdì Santo** e **Lunedì di Pentecoste**, festivi in Germania, più tre voci greche agganciate per errore (`HolidayID` 4, 8, 20, 21, 22). *Attuale*: rimossi, 5 righe. *Fonte*: calendario civile italiano. *Perché*: un giorno festivo cambia il profilo di un'intera giornata, spostandola dal comportamento feriale a quello domenicale. |
| **H02** | *Origine*: **Sa Die de Sa Sardigna** (28 aprile), festività regionale sarda. *Attuale*: rimossa, 1 riga. *Perché*: non osservata a Milano. |
| **H03** | *Origine*: **2 giugno**, **Immacolata** e **Ferragosto** erano presenti nel catalogo ma non agganciate a Milano. *Attuale*: attivate, 3 righe. Calendario finale: **12 voci**. |

**Errore noto e non ancora corretto**: il **24 dicembre** resta festivo perché
catalogato *Worldwide*, e in Italia non lo è (§6.5, migrazione `H04` non ancora
scritta). Effetto numerico trascurabile, ma è un errore fattuale.

---

### 13.2 Orari della giornata — 10 migrazioni, 58 righe

Tutte le modifiche di questa famiglia agiscono **per ID di voce**, mai per
`TimeLimitID`: diversi time limit hanno voci gerarchiche legate da
`ParentEntryID` con logica AND/OR, e un aggiornamento di gruppo la romperebbe.

**`L02` — Cena, primo spostamento** (8 righe). *Origine*: cottura e pasto serale
alle **18:00-21:00**, orario tedesco. *Attuale*: 19:00-21:30 su `TL 121`
(*Dinner Time*, il cancello effettivo imposto dal tratto *Cooking Dinner for the
Family*), più quattro cancelli collegati — `TL 40` (16:30-17:30 → 19:00-20:30),
`TL 66` (16:00-21:00 → 18:30-22:00), `TL 82` (16:30-21:00 → 18:30-22:00),
`TL 88` (17:00-19:00 → 19:00-21:00) — e le tre voci di `TL 57`, le grigliate
condizionate alla temperatura, da 17:00-21:00 a 19:00-23:00. *Poi rettificato
da `L08`.*

**`L03` — Pranzo** (5 righe). *Origine*: **11:00-13:00** nei feriali e
11:00-14:00 nel weekend, con randomizzazione di **60 minuti**. *Attuale*:
**12:30-14:30** feriale, 12:30-15:00 weekend e domenica, randomizzazione a **45
minuti**. *Fonte*: ISTAT **AVQ 2024**, Lombardia — per il **59,4%** dei
lombardi il pranzo è il pasto principale (contro il 28,2% della cena) e il
**64,6%** lo consuma in casa nei giorni feriali. *Perché la randomizzazione*:
lasciandola a 60 minuti il pranzo avrebbe continuato a cadere alle 11:30
nonostante lo spostamento del cancello. È lo stesso meccanismo che `L08` e `L09`
useranno in verso opposto.

**`L04` — Scuola** (11 righe). *Origine*: pomeriggio libero dalle **12:00**,
cioè la scuola tedesca che finisce a mezzogiorno; sveglie scolastiche alle
05:30-06:30; compiti fino alle 22:00. *Attuale*: pomeriggio libero dalle
**13:30**, sveglie posticipate di circa un'ora mantenendone la diversità fra
famiglie (06:30-07:00, 07:00-07:30, 07:15-07:45), compiti fino alle 21:00.
*Non toccati*: i tratti *Primary school 1/2/3*, che durano 6 ore con partenza
07:00-09:00 e finiscono fra le 13 e le 14 — sono già italiani.

**`L05` — Ora di dormire dei bambini** (5 righe). *Origine*: **19:30-20:30**.
*Attuale*: **21:00**. *Non toccato*: il sonno degli adulti (`TL 19`,
22:00-02:00), già compatibile — verrà poi corretto da `L10` per un'altra
ragione.

**`L06` — Colazione** (13 righe). *Origine*: inizio alle **06:00**. *Attuale*:
**07:00**. *Non toccata*: la durata del tratto *Breakfast 1h*. La durata è una
questione diversa dall'orario, e accorciarla avrebbe ridotto il consumo **per
assunzione, non per dato**.

**`L09` — Bucato e lavastoviglie** (8 righe). *Origine*: *do laundry at 30 C*,
*run the dishwasher* e *run the dryer* passavano tutte e tre da `TL 6`, che apre
alle **08:00** con randomizzazione di **15 minuti**: le tre macchine partivano
praticamente insieme. *Attuale*: due time limit **nuovi**, `TL 150` (bucato,
10:00-21:30, randomizzazione **120 min**) e `TL 151` (lavastoviglie,
13:00-22:30, randomizzazione **90 min**), a cui vengono ripuntate le sole
attività interessate. *Fonte*: **ETHOS.ActivityAssure** (HETUS), giorno feriale,
Italia — bucato: moda alle **17:00** per le donne occupate a tempo pieno, con il
37,9% della massa fra le 12 e le 18 e il 43,5% fra le 18 e le 24; per le
pensionate moda alle **10:10** con il 47,6% entro mezzogiorno. Lavastoviglie:
picco alle **20:50** per le occupate a tempo pieno (60,7% della massa fra le 18
e le 24) e alle **13:40** per le pensionate.

> **Perché due cancelli nuovi invece di spostare `TL 6`.** `TL 6` non è il
> cancello del bucato: lo condividono **12 attività**, fra cui cuocere una
> torta, pulire i vetri, il robot aspirapolvere e andare in piscina. Spostarlo
> le avrebbe mosse tutte. Creare un cancello nuovo e ripuntarci solo le
> attività interessate è la tecnica che permette di correggere senza toccare
> oggetti condivisi, ed è quella da riusare per il circolatore stagionale
> (§6.3).

> **Correzione a un'ipotesi di partenza.** Il dato **non** dice che in Italia il
> bucato si faccia la sera: dice pomeriggio e sera per chi lavora, mattina per
> chi non lavora. E la fascia 08-10 pesa il **5,3%** in Italia contro il **4,7%**
> in Germania — il picco delle 08:00 non lo giustificava nemmeno il
> comportamento tedesco. Era un artefatto del cancello, non un tratto culturale.

**`L08` — Cena, rettifica** (2 righe). *Origine dopo `L02`*: 19:00-21:30, ma la
misura sui profili generati mostrava il picco della giornata alle **18**, mentre
ARERA Milano lo ha alle **20**. *Attuale*: `TL 121` a **19:30-22:00** e `TL 66`
a 19:30-22:30, entrambi con randomizzazione da 15 a **45 minuti**. *Fonte*:
**ETHOS.ActivityAssure**, giorno feriale — picco dell'attività *eat* alle
**20:20** in Italia, con ampiezza **42,0%** per le donne occupate a tempo pieno
e 39,4% per gli uomini, contro le **19:20** e le **18:30** in Germania con
ampiezza 16,4% e 16,3%; per le pensionate alle 19:50. Sull'attività *cook*, la
massa fra le 18 e le 22 vale il **60,7%** in Italia contro il **39,2%** in
Germania. *Perché 19:30 e non 20:20*: cucinare precede il mangiare di mezz'ora
abbondante. *Non toccato*: `TL 40`, che pure contiene un'attività di cottura ma
condivide il cancello con lo yoga e il bagno dei bambini, che confina con la
messa a letto delle 21:00 fissata da `L05`.

**`L10` — Coda serale** (2 righe). *Origine*: `TL 19`, che governa tredici
attività di sonno, apriva alle **22:00** con randomizzazione di 15 minuti — gli
adulti andavano a letto praticamente tutti alle 22. E l'attività *watch TV
series on weekdays 18:00* aveva un cancello dedicato largo un quarto d'ora
fissato alle **18:00**. *Attuale*: sonno a **22:45** con randomizzazione **45
min** (solo la voce 133, il ramo serale del time limit gerarchico), e prima
serata TV a **21:00-21:15**. *Fonte*: **ETHOS.ActivityAssure** — in Italia il
50% degli occupati a tempo pieno è addormentato alle **23:10**, contro le
**22:40-23:00** della Germania; alle 22:00 la presenza in attività a basso
consumo (televisione, computer) vale il **35,6%** in Italia contro il **25,4%**
tedesco. ISTAT **AVQ 2024** Lombardia: **2,0 ore** di televisione al giorno,
mediana. *Difetto corretto*: le ore 22-23 valevano il 5,9% della giornata contro
il 10,1% di ARERA Milano.

**`L01` → `L11` — Ingresso al lavoro, con rettifica** (3 + 1 righe). *Origine*:
`TL 12` a **08:00-10:00**. *`L01`* lo spostò a 09:00-11:00 **assumendo** che in
Italia si entri più tardi che in Germania. *`L11`* lo ha **riportato a
08:00-10:00**. *Fonte*: ISTAT **AVQ 2024**, Lombardia, sui soli occupati
(n=1.146, dati pesati) — l'orario di uscita da casa per lavoro ha p25 **07:00**,
mediana **07:30** e p75 **08:00**; il tempo di spostamento ha mediana 15 minuti.
Il lavoratore mediano arriva verso le 07:45 e il 75% entro le 08:15.

> **È il caso da citare in tesi sul metodo.** Il valore tedesco era già corretto
> per l'Italia, e l'italianizzazione lo aveva peggiorato. I dodici tratti che
> passano da quel time limit si chiamano tutti *«Work - Office N, XXh, from
> 08:00»*: dopo `L01` il nome del tratto dichiarava un orario che il cancello
> non rispettava più. È la ragione per cui ogni migrazione va verificata contro
> il dato e nessuna va data per buona perché «suona italiana».

---

### 13.3 Dotazione e vettori energetici — 2 migrazioni, 55 righe

**`D01` — Piano cottura a gas, forno elettrico** (30 righe). *Origine*: in LPG
la cottura è **interamente elettrica**; il gas esiste solo come trasformatore di
casa (caldaia, scaldabagno) e nessun dispositivo domestico ha un vettore diverso
dall'elettricità. *Attuale*: i **sei fuochi** del piano cottura
(`RealDeviceID` 277-281 e 478, categorie *Kitchen stove hind/front left/right*)
passano da `LoadTypeID` 1 (elettricità) a 2 (gas). *Fonte*: ISTAT **Consumi
energetici delle famiglie 2021**, Tavola 19, Lombardia, per 100 famiglie dotate
— piano cottura a **metano 85,9%** e a **GPL 3,6%**, quindi **89,5% a gas**
contro il 10,5% elettrico; **forno elettrico 83,9%** contro il 15,2% a metano.
*Perché conta per la CER*: il consumo del piano finisce in bolletta gas, non sul
contatore elettrico che la CER misura.

> *Non toccati*, e sono scelte deliberate: i **forni** (dispositivi 69-72),
> elettrici come l'83,9% dei forni lombardi e presenti nella composizione dei
> picchi annui di potenza; il **piano a induzione**, elettrico per definizione,
> che rappresenta bene il 10,5% misurato da ISTAT; i piccoli elettrodomestici di
> cottura. Restano invariate anche le righe *Apparent* e *Reactive* (grandezze
> elettriche derivate che il progetto non legge) e *Inner Device Heat Gains* —
> un fuoco a gas scalda l'ambiente esattamente come uno elettrico.

> **Controllo di coerenza previsto**: il calo di elettricità domestica deve
> corrispondere al gas che compare in `Sum.Gas.HH1.json`. I fuochi si accendono
> le stesse volte, su un altro vettore. Se le due quantità non coincidessero, la
> migrazione avrebbe **riscalato** qualcosa invece di **spostarlo**.

**`D02` — Frigorifero di taglia realistica** (25 righe). *Origine*: il gruppo di
azioni 184 offriva sette frigo-congelatori alternativi e con `EnergySaving` il
motore sceglieva il *Siemens KI 20 LA 65 (A+)*, che nei profili generati
consumava **82,9 kWh/anno**. Nessun combinato reale consuma così poco: un A+ ne
consuma 150-200, un combinato 250-350. *Attuale*: il gruppo è ristretto ai due
dispositivi che dichiarano un consumo verificabile, entrambi **Liebherr
combinati da 229 kWh/anno**. *Fonte sulla dotazione*: ISTAT **Consumi energetici
2021**, Tavola 18, Lombardia — il **99,4%** delle famiglie ha un frigorifero e
il **22,0%** ha anche un congelatore separato, quindi il combinato è
l'apparecchio di riferimento. *Difetto corretto*: il frigorifero è il principale
carico continuo di una casa, e sottodimensionarlo **svuota le ore notturne** —
le ore 00-05 valevano lo 0,9-1,5% della giornata contro il 2,4-3,6% di ARERA
Milano, principale causa del deficit sulla fascia F3 (28,4% contro 38,6%).

> **Perché si è agito sulla selezione e non sui consumi.** Cinque dei sette
> dispositivi sono guidati da un **profilo di carico misurato** e dichiarano
> `YearlyEnergyUse = 0`: il loro consumo non è leggibile dal catalogo e la
> scelta di `EnergySaving` fra di essi non è prevedibile. Si è quindi ristretto
> **quali alternative restano disponibili**, senza toccare alcun profilo di
> carico: i profili sono misurati, e alterarli cambierebbe la natura del
> modello. Con due soli candidati noti, `EnergySaving` prende il meno assorbente
> in modo deterministico e il valore atteso è noto in anticipo.

---

### 13.4 Impianti di casa — 2 migrazioni, 3 righe

**`HT02` — Un solo circolatore** (2 righe). *Origine*: ogni house type montava
il gruppo di azioni 214 (*run Circulation pump*) **due volte**, con due cancelli
diversi — uno su `TL 53` (tutti i giorni 06:00-22:00, quindi tutto l'anno) e uno
su `TL 3` (*Below 15 °C*). D'inverno giravano insieme. Misurato sui profili
generati: la componente `Electricity_House` valeva **898 kWh/anno** quando il
sorteggio pescava il Wilo-Star da 80 W e **281** con il Grundfos da 25 W, cioè
in entrambi i casi **2,2 volte** il consumo che il catalogo stesso dichiara per
una singola unità (409 e 128 kWh). La pompa restava accesa **7.784 ore l'anno su
8.760**. *Attuale*: eliminata l'istanza su `TL 53`, tenuta quella su `TL 3`, che
è la pompa del riscaldamento. *Fonte sul valore atteso*: ISTAT **Consumi
energetici 2021**, Tavola 7, Lombardia — il riscaldamento resta acceso **10,06
ore al giorno** nei mesi freddi; a quel regime un circolatore da 25 W consuma
circa **45 kWh/anno** e uno da 80 W circa **145**. L'ordine di grandezza corretto
è quello, non 898. *Perché una sola pompa*: in un appartamento italiano con
caldaia istantanea a gas — che è quello che HT06 descrive — non c'è un anello di
ricircolo sanitario che giustifichi una seconda unità accesa tutto l'anno.
*Ambito*: solo HT06 e HT07, i due house type usati dal progetto; gli altri 20
restano invariati.

> **Residuo aperto**: `TL 3` è condizionato alla temperatura ma ha finestra
> 00:00-20:00, quindi la pompa gira anche ad agosto (§6.3). Si chiude con la
> stessa tecnica di `L09` — un time limit nuovo su orario italiano, ripuntato
> alle sole righe di HT06 e HT07.

**`HT01` — Raffrescamento dimensionato sul dato lombardo** (1 riga). *Origine*:
`CoolingYearlyTotal = 5.000` kWh termici, cioè **1.663 kWh elettrici** con COP 3,
interamente sul contatore della famiglia. *Attuale*: **1.400 kWh termici**, cioè
**466 kWh elettrici**. *Fonte*, due misure indipendenti che concordano: (a) dal
dato **ARERA**, il condizionamento vale circa **233 kWh** elettrici per famiglia
media di Milano, e ISTAT **Dotazioni energetiche 2024**, Tavola 3, dà la
Lombardia al **55,6%** di famiglie dotate, quindi 233 / 0,556 = **419 kWh** per
famiglia che ce l'ha; (b) l'intervallo reale italiano per un condizionatore
domestico è **400-700 kWh** elettrici l'anno. I 466 kWh cadono in entrambi.
*Contesto d'uso*, ISTAT **Consumi energetici 2021**, Lombardia: fra le famiglie
dotate solo il **28,8%** lo usa tutti i giorni o quasi e il **22,1%** quasi mai
(Tavola 14); l'impianto resta acceso in media **6,48 ore al giorno** nei mesi
caldi, di cui 1,04 la mattina, 3,13 il pomeriggio e **2,31 la notte** (Tavola
15) — quest'ultima è il controllo sulla forma, e pesa sulla fascia F3.

> **Limite del modello, da dichiarare in tesi.** A differenza del riscaldamento,
> che ha `AdjustYearlyEnergy = 1` e `ReferenceDegreeDays = 4000` e viene quindi
> riscalato sui gradi giorno della località, il raffrescamento ha
> **`AdjustYearlyCoolingHours = 0`**: i kWh restano identici a Milano come a
> Palermo. Qui si è corretto il **livello**, non il **meccanismo**.
> L'asimmetria si manifesterebbe replicando lo studio in un'altra provincia.

> **La diffusione non si rappresenta riscalando l'impianto di tutti**, ma dando
> HT07 solo ad alcune famiglie. Si fa nella configurazione, con la chiave
> `house_type` per famiglia (§13.6).

---

### 13.5 Clima e vacanze — 2 migrazioni, 458 righe

**`T01` — Profilo di temperatura italiano** (366 righe). *Origine*: il modello
aveva **tre riferimenti climatici scollegati** — nessuna temperatura (default
interno tedesco), radiazione LPG di Milano 2016 e TMY 2005-2023 per il
fotovoltaico. *Attuale*: medie giornaliere di Milano dal **TMY PVGIS
2005-2023**, la stessa sorgente che `optimizer_PV.m` usa per la radiazione.
*Perché*: la temperatura governa il riscaldamento, il raffrescamento e i
cancelli condizionati (grigliate, circolatore). Con sorgenti diverse, LPG e
calcolo fotovoltaico descrivevano due climi diversi nello stesso anno.
*Attenzione*: il GUID del profilo è **fisso e non generato a caso**, altrimenti
ogni build produrrebbe un database diverso a parità di sorgente. Il TMY copre
365 giorni: simulando un anno bisestile mancherebbe il 29 febbraio.

**`V01` — Vacanze italiane** (92 righe). *Origine*: **18 famiglie su 66**
andavano in vacanza ad **aprile** e solo **10 in agosto** — l'opposto della
realtà italiana. *Attuale*: lavoratori e famiglie ad **agosto**; pensionati e
non occupati alternati fra **giugno e settembre**, per mantenere diversità di
occupazione fra i membri della CER; studenti su **agosto-settembre**. `CHR62`
(casa vacanza) resta invariata. *Perché la diversità*: se tutti si assentassero
negli stessi giorni, l'aggregato della CER avrebbe un buco unico e le differenze
fra membri — che sono l'oggetto della ricerca — sparirebbero proprio nel mese in
cui il fotovoltaico produce di più.

> **Correzione emersa misurando** (§9.1): il «problema di agosto» in larga parte
> **non esisteva ed era geografia**. A Milano agosto è un mese basso (7,48% nel
> 2025, 9,15% nel 2024), non il massimo dell'anno come nel dato nazionale
> (10,11%).

---

### 13.6 Modifiche di configurazione, non del catalogo

Non toccano il database: stanno in `config/simulation_config.yaml` e in
`lpg_runner.py`, e sono reversibili senza ricostruire nulla.

| | |
|---|---|
| **Definizione di POD** | *Origine*: il profilo domestico era il solo `Electricity_HH1`, gli elettrodomestici della famiglia. *Attuale*: **`Electricity_HH1` + `Electricity_House`**, cioè anche pompa di circolazione e condizionatore. *Perché*: è ciò che misura il contatore, e quindi ciò che la CER ripartisce. Senza questa correzione si validava contro ARERA una grandezza diversa da quella che ARERA misura. |
| **`energy_intensity`** | *Origine*: `Random` — il motore sceglieva a caso fra le alternative di ciascun gruppo di dispositivi. *Attuale*: **`EnergySaving`**. *Perché*: rende la selezione **deterministica e riproducibile**, e rappresenta un parco elettrodomestici moderno. Ha anche risolto da solo il problema delle lampadine a incandescenza (§9.7), che non era un errore da eliminare ma un problema di peso nel mix. |
| **`house_type` per famiglia** | *Origine*: un unico house type per tutte. *Attuale*: **HT07** (con raffrescamento) a metà delle famiglie, **HT06** all'altra metà. *Fonte*: ISTAT **Dotazioni energetiche 2024**, Tavola 3 — **55,6%** delle famiglie lombarde ha un impianto di raffrescamento. *Perché*: darlo a tutte o a nessuna è sbagliato in entrambi i casi. |
| **`temperature_profile`** | Seleziona il profilo installato da `T01`: `"Milano, Italia - PVGIS TMY 2005-2023"`. Senza questa riga la migrazione `T01` sarebbe inerte. |

---

### 13.7 Modifiche valutate e **non** fatte

Vanno citate quanto quelle fatte: dicono che il catalogo è stato verificato, non
solo modificato.

- **`D03` — lampadine**. Prevista dal piano, risultata **non necessaria**: con
  `EnergySaving` il parco illuminazione è già efficiente. L'incandescenza non
  era un errore da eliminare (§9.7).
- **`L07` — pranzo**. Prevista dal piano, risultata **non necessaria**: `L03`
  aveva già portato gli orari su valori italiani. Il piano la prescriveva perché
  il **nome** del time limit diceva ancora *«Lunch Time (11:30-13:00)»* mentre
  il contenuto era già 12:30-14:30 (§6.8).
- **Durata della colazione** (`Breakfast 1h`), non accorciata: sarebbe stata una
  riduzione di consumo per assunzione e non per dato.
- **Profili di carico dei dispositivi**, mai alterati: sono misurati, e
  modificarli cambierebbe la natura del modello bottom-up.
- **`AdjustYearlyCoolingHours`**, non forzato a 1: è come il modello è fatto, e
  si dichiara come limite (§6.6).

---

### 13.8 Indice per fonte

Quale fonte giustifica quali modifiche. È la tabella da tenere sotto mano
scrivendo il capitolo.

| fonte | modifiche che ne dipendono |
|---|---|
| ISTAT **AVQ 2024**, microdati Lombardia | `L03` (pranzo pasto principale, 59,4% / 64,6% in casa), `L11` (uscita per lavoro p25 07:00, mediana 07:30, p75 08:00; tragitto 15 min), `L10` (2,0 h di TV al giorno), **§12** (composizione dei nuclei: 1.831 famiglie, tutti i componenti) |
| ISTAT **Consumi energetici delle famiglie 2021**, Lombardia | `D01` (Tav. 19: 89,5% gas, forno 83,9% elettrico), `D02` (Tav. 18: 99,4% frigorifero, 22,0% congelatore), `HT02` (Tav. 7: 10,06 h/giorno), `HT01` (Tav. 14 e 15: uso e ore del condizionatore) |
| ISTAT **Dotazioni energetiche 2024**, Tavola 3 | `HT01` (bersaglio del livello), `house_type` per famiglia (55,6%), quota di raffrescamento delle due società (§12.4) |
| ISTAT **Censimento permanente 2021** (rilascio 2023), per sezione | **§12** (marginali di Milano e Lombardia) |
| **ETHOS.ActivityAssure** (HETUS 2010), Italia e Germania | `L08` (cena: picco 20:20, ampiezza 42,0% contro 16,4% tedesca), `L09` (bucato e lavastoviglie: mode 17:00 / 10:10 e 20:50 / 13:40), `L10` (sonno: 50% addormentati alle 23:10) |
| **ARERA**, dati provinciali orari 2024-2025, Milano | `HT01` (233 kWh di condizionamento per famiglia media) e **tutta la validazione** — è il giudice, non un input, salvo questo unico caso dichiarato |
| **PVGIS**, TMY Milano 2005-2023 | `T01` (profilo di temperatura), e la stessa sorgente alimenta `optimizer_PV.m` |
| **Calendario civile italiano** | `H01`, `H02`, `H03` |
| **Misura sui profili generati** (nessuna fonte esterna) | `HT02` (898 kWh e 7.784 ore misurati), `D02` (82,9 kWh misurati), `L08` e `L10` (picco alle 18 e coda serale al 5,9%) |

> **Nota di metodo sull'unico caso ambiguo.** `HT01` usa ARERA per ricavare il
> bersaglio di livello del condizionamento, e ARERA è il validatore. È l'unica
> eccezione alla regola di non circolarità del §2, ed è dichiarata: riguarda il
> **livello** di un singolo impianto, non la **forma**, che resta validata
> indipendentemente. Chi volesse essere rigoroso può escludere `HT01` dal
> conteggio delle migrazioni «validate» e trattarlo come calibrazione.

---

## 14. Esito dei due run: la composizione era la leva

Le due società del §12.4 sono state generate. Entrambi i run sono puliti —
nessun profilo sintetico, nessuna colonna mancante — e durano 4.806 s
(Lombardia) e 2.736 s (Milano); la differenza è che Milano ha undici famiglie
unipersonali, che hanno molte meno attività da simulare.

### 14.1 Risultati

| | campione20 (4 archetipi × 5 semi) | **lombardia20** | **milano20** |
|---|---:|---:|---:|
| TVD aggregato a N=20 | 0,1412 | 0,0778 | **0,0650** |
| `a` — errore irriducibile del modello | 0,1219 | 0,0526 | **0,0431** |
| `b` — errore di campionamento | 0,0813 | 0,1037 | 0,0900 |
| TVD a N=4 | 0,1567 | 0,1040 | 0,0896 |
| **eterogeneità di forma (media)** | 0,1829 | **0,2103** | 0,1840 |
| livello dell'aggregato | 1,25x | 1,15x | 1,22x |
| livello, escluso il nucleo anomalo | — | 2.098 kWh | 2.085 kWh |
| fascia F3 | 32,28 | 33,19 | 34,10 |
| ore 00-05 (ARERA 16,49%) | — | 12,25% | 12,88% |

**Distanza fra le due società: TVD 0,0279**, cioè 4,4 volte il rumore della
fonte. La scelta fra composizione cittadina e regionale è una differenza reale
e misurabile, non un dettaglio di taratura.

### 14.2 Il tetto strutturale non esisteva

Il §5.3 concludeva che il modello non sarebbe sceso sotto **0,122** nemmeno con
un campione infinito, e il §7.1 ne deduceva che servissero più archetipi. Il
valore misurato ora è **0,0526** (Lombardia) e **0,0431** (Milano): meno della
metà. Era una proprietà del **mix**, non del catalogo — la correzione 12 del §9
è confermata dalla misura.

Il `b` che **sale** (0,0813 → 0,1037) è il segno che l'operazione è riuscita:
con venti famiglie davvero diverse i sottoinsiemi piccoli sono più rumorosi, che
è la firma di un campione vero invece di quattro profili ripetuti cinque volte.
Ed è per questo che a N=4 la numerosità pesa ora circa la metà contro il 22%
della Fase 3: non perché sia peggiorata, ma perché l'errore di modello sotto di
essa si è dimezzato.

### 14.3 La forma oraria, prima e dopo

```
ora            0    1    2    3    4    5    6    7    8    9   10   11
4 famiglie  2,36 1,53 1,50 1,55 1,57 1,79 2,78 4,53 3,37 2,35 2,25 2,54
lombardia20 2,33 1,92 1,94 2,02 1,98 2,17 2,71 4,05 3,55 3,40 4,51 4,75
ARERA       3,62 2,96 2,61 2,44 2,38 2,48 2,96 3,80 3,98 3,94 3,86 3,96

ora           12   13   14   15   16   17   18   19   20   21   22   23
4 famiglie  2,89 4,13 3,94 3,90 4,43 6,37 10,35 10,83 8,53 6,28 5,96 4,26
lombardia20 4,38 4,78 5,17 5,18 5,15 5,91 6,52 6,74 6,55 5,60 5,09 3,63
ARERA       4,31 4,44 4,33 4,17 4,16 4,51 5,31 6,53 6,74 6,40 5,57 4,55
```

Il **buco diurno è chiuso**: ore 09-12 al 17,04% contro il 16,05% di ARERA,
erano al 10,09%. La **sera è rientrata**: ore 17-20 al 25,72% contro 22,98%,
erano al 36,1%. Il picco resta alle 19 invece che alle 20.

**Il residuo dominante è ora la notte**: ore 00-05 al 12,25% (Lombardia) e
12,88% (Milano) contro il 16,49% di ARERA. È il difetto di dotazione del §6.2 —
standby e congelatore separato — che il §12.2 stimava valere +0,015/0,02 di TVD.
Adesso che tutto il resto è rientrato, è l'intervento rimasto con il miglior
rapporto fra valore e rischio.

### 14.4 Il test non circolare è passato

Milano aderisce ad ARERA **Milano** meglio della Lombardia: 0,0650 contro
0,0778. La composizione milanese è stata derivata da censimento e AVQ **senza
mai guardare ARERA** (§12.3), e risulta più vicina ai contatori milanesi di
quella regionale. È il comportamento atteso se il metodo è sano, e vale come
conferma proprio perché la composizione non è stata scelta per ottenerlo.

### 14.5 Il compromesso, che è la cosa che conta per la domanda di ricerca

L'eterogeneità di forma va nella **direzione opposta** all'aderenza:

```
                            eterogeneità media   coppia più lontana   più vicina
campione20 (4 archetipi)          0,1829               0,3674          0,0155
lombardia20                       0,2103               0,4600          0,0453
milano20                          0,1840               0,3759          0,0628
```

Lombardia guadagna il **15%** di eterogeneità rispetto al campione precedente;
Milano resta praticamente ferma. Il motivo è strutturale: Milano ha undici
famiglie unipersonali, e le persone sole si somigliano fra loro più di quanto si
somiglino tipologie familiari diverse. La distribuzione si comprime da entrambi
i lati — la coppia più lontana scende, la più vicina sale.

**Le due società rispondono quindi a due domande diverse.** Milano è più fedele
al dato milanese; la Lombardia offre più differenza di forma fra i membri, che è
la premessa da cui dipende che Shapley, Nucleolo e VLC si distinguano da una
ripartizione volumetrica.

Va però registrato il fatto principale: **entrambe migliorano l'eterogeneità
rispetto alla configurazione precedente**, e la Lombardia la migliora
nettamente. Il timore del §7.5 — che correggere il realismo indebolisse la
premessa della tesi — **non si è avverato**. Va nell'altro verso.

### 14.6 Due avvertenze sui numeri

**Il nucleo anomalo di ciascuna società non è un difetto del profilo.**
`M20_multigenerazionale` risulta a 2,48x il bersaglio, ma è una famiglia di
**sei persone** confrontata con la classe 3-4,5 kW: le due sole classi di
potenza disponibili non reggono oltre i quattro componenti. È un limite
dell'assunzione dichiarata al §11, non del modello. Escludendo i due nuclei
anomali (`L20` e `M20`) le due società stanno a 2.098 e 2.085 kWh per famiglia:
praticamente identiche.

**Un'incoerenza geografica del progetto, da sciogliere.** La CER è dichiarata a
**Pordenone** in `CER_input.txt`, mentre tutta la catena dei profili e della
validazione è su Milano: `geographic_location: Italy_Mailand`, temperatura TMY
Milano, bersaglio ARERA Milano. Finché resta così, la società **lombarda** è la
scelta più difendibile — un capoluogo di provincia del Nord assomiglia molto più
alla composizione regionale (38,6% di unipersonali) che a Milano città (55,6%) —
e ha in più l'eterogeneità maggiore. Se invece la CER va collocata a Milano,
allora `milano20` è coerente con il resto e il calo di eterogeneità va
dichiarato. **È una decisione di merito, non tecnica, e va presa prima di
rigenerare i risultati MATLAB.**

### 14.7 Verifica di riproducibilità

Eseguita il 2026-09-03, tutti gli undici controlli superati:

- ricostruzione del catalogo da zero → **stesso SHA-256** (`b0e82dbf…`),
  19 migrazioni, 583 righe, `integrity_check: ok`, sorgente tedesco intatto;
- `riferimento_istat.py` e `tipologie_famiglie.py` rigenerano tutte le citazioni;
- `valida_domestici.py` sui quattro set di profili (principale, campione20,
  lombardia20, milano20);
- `curva_numerosita.py` sui tre campioni allargati;
- `confronta_societa.py` sul confronto fra le due società.

I valori riprodotti coincidono con quelli riportati qui.
