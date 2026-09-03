# Validazione dei profili domestici LPG — report completo Fase 2 e Fase 3

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
| ISTAT **AVQ 2024** (45.005 record) | calibrazione: orari e abitudini | **Lombardia**, n=4.139 |
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

### Primi tre passi della prossima sessione

1. **Rigenerare i risultati MATLAB.** Verificare che l'assert del VLC non
   fallisca (`MAIN.m` riga ~1306, sensibile alla composizione) e che
   `align_members_to_users.m` non segnali disallineamenti.
2. **Misurare l'eterogeneità di forma** (§7.5). È la misura che decide se le
   correzioni hanno aiutato o danneggiato la domanda di ricerca.
3. **Aggiornare `CONTESTO_VALIDAZIONE_ARERA.md` e `CONTESTO_LPG_RAMP.md`** con
   le correzioni del §9 e i nuovi numeri di riferimento.

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
