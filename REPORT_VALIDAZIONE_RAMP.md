# Validazione dei profili non domestici RAMP

Gemello non domestico di [REPORT_VALIDAZIONE_LPG.md](REPORT_VALIDAZIONE_LPG.md),
e stesso metodo. Documenta come i tre archetipi non domestici della comunità —
`office`, `scuola_superiore`, `comune` — sono stati confrontati con il dato
italiano reale, che cosa è stato corretto, e che cosa resta aperto.

Le misure di ogni passaggio stanno in `CER_LoadProfiles/ramp_db/dati/validazione/`,
numerate da `01` a `10`: ogni file porta in testa il comando che lo ha prodotto
e la riga di esito.

---

## 1. Il problema

Gli archetipi RAMP erano costruiti su numeri che nessun documento del progetto
attribuiva a una fonte. Le 20 plafoniere, gli 8 PC e i 2 climatizzatori da
2,5 kW di `office.py` non avevano citazione né in codice né nel README: nessuno
poteva dire se un ufficio consumasse in un anno una quantità plausibile, né se
lo facesse nelle ore giuste.

È la stessa obiezione a cui il lato domestico risponde con ARERA — *perché
profili costruiti su un modello dovrebbero rappresentare utenze italiane?* — e
fino a qui il lato non domestico non aveva risposta.

## 2. Il metodo, e perché servono due fonti

Le regole sono quelle del lato domestico, e non cambiano:

1. **Si normalizza prima di confrontare.** Ogni curva a somma unitaria: la forma
   si valida separatamente dal livello. Consumare troppo e consumare nel momento
   sbagliato sono due errori diversi, e un confronto su curve non normalizzate
   li mescola in un numero che non dice quale dei due sia il problema.
2. **Se non torna si corregge l'archetipo, mai l'uscita.** Nessun fattore
   correttivo orario: sistemerebbe la somma rendendo meno plausibile il profilo
   individuale, e la ripartizione dell'energia condivisa vive esattamente sulle
   forme individuali.
3. **La soglia è il rumore della fonte**, non un numero scelto a tavolino:
   quanto cambia ARERA fra il 2024 e il 2025 sullo stesso ATECO e classe.

Cambia però una cosa rispetto al domestico: **il bersaglio viene da due fonti
diverse, perché nessuna delle due lo fornisce per intero.**

| Cosa | Fonte |
|---|---|
| livello annuo e peso di ciascun mese | ARERA, per ATECO e classe di potenza — **solo mensile** |
| forma oraria dentro il mese | profili standard **GSE** |

I profili GSE non sono un benchmark qualsiasi. Secondo il **Testo Integrato
Autoconsumo Diffuso** (TIAD, allegato alla delibera ARERA 727/2022/R/eel),
quando il gestore di rete non è tecnicamente in grado di raccogliere i dati di
misura orari, il GSE profila i dati per tipologia di utenza secondo i profili
standard. Per un socio di CER non trattato orario — cioè la maggior parte delle
piccole utenze non domestiche — **la curva oraria che entra nel settlement è
quella**.

Restano però un metro, non una sorgente: sostituirli a RAMP renderebbe identici
in forma tutti i membri della stessa categoria, ed è esattamente la varietà
delle forme individuali a distinguere Shapley, Nucleolo e VLC da una
ripartizione volumetrica.

## 3. Le fonti, e da dove vengono i dati

I file grezzi stanno in `CER_LoadProfiles/File Non Domestici/`, **non
versionati** per dimensione (~692 MB). Si versiona la cache in
`ramp_db/dati/riferimento_arera_nd/`, con accanto lo SHA-256 di ogni sorgente.

**Dati di validazione**

- **ARERA**, consumi provinciali dei clienti non domestici in BT, sezione
  *Monitoraggio retail*, annualità **2024 e 2025**, un CSV per classe
  tariffaria BTA. Copertura verificata: il 2025 ha 110 province, 20 regioni e
  765 classi ATECO; il **2024 ha le sole 12 province lombarde** — Milano
  compresa — e 609 classi.
- **GSE**, *Modalità di profilazione dei dati di misura: profili standard GSE
  in prelievo e immissione*, annualità 2024 e 2025, area CACER. I due xlsx del
  2025 sono stati verificati **identici allo zip ufficiale** pubblicato dal GSE.
- **GSE**, *Modalità di profilazione … ai sensi dell'articolo 9 dell'Allegato A
  alla Delibera 318/2020/R/eel*, v1 del 04/04/2022: decodifica i codici colonna
  `XZZY` (X = P prelievo puro / M misto / I immissione; Y = M monorario / F a
  fasce). Precede il TIAD, ma la struttura dei codici nei file 2024 e 2025 è
  invariata.

**Benchmark di letteratura** (`ramp_db/benchmark_letteratura.csv`, con fonte,
pagina e stato di verifica per ogni riga)

- **ENEA con Assoimmobiliare**, *Uffici — Quaderni dell'Efficienza Energetica*,
  guida alla diagnosi energetica ex Allegato II del D.Lgs. 102/2014. Il §4.3
  porta gli IPE di secondo livello, cioè l'albero energetico elettrico di un
  ufficio: illuminazione 25,7 ± 11,8 kWh/m² (p. 75), climatizzazione 93 ± 39 in
  zona E-F a solo vettore elettrico (p. 77), ICT 21,4 ± 11,8 kWh/m² oppure
  534 ± 253 kWh/utente (pp. 77-78), PUE dei data center 1,83 (p. 78).
- **Corgnati, Fabrizio, Ariaudo, Rollino**, *Edifici tipo, indici di benchmark
  … ad uso scolastico*, Report RSE/2010: energia elettrica 15 kWh/m² (p. 42).
- **RSE**, *I consumi della Pubblica Amministrazione* (RSEview, ISBN
  978-88-943145-5-7): §3.3 uffici pubblici fino al livello comunale.

**Fonti normative per i calendari**

- **DGR Lombardia n. 3318 del 18 aprile 2012**, Calendario Scolastico Regionale
  di carattere permanente, confermato con Prot. E1.2025.0481857 del 12/05/2025.
- **D.Lgs. 297/1994 art. 74 c. 3**: almeno 200 giorni di lezione per anno
  scolastico — serve a *verificare* il calendario, non a costruirlo.
- **DPR 412/1993 art. 9**: stagione di riscaldamento della zona climatica E.
- **L. 23/1996 art. 3**, **D.Lgs. 267/2000**, e Consultazione GSE del 4 marzo
  2021 §2.1: perché scuola e comune sono enti territoriali, quindi esenti dal
  fattore F.

## 4. La soglia, misurata

Il rumore della fonte ARERA fra 2024 e 2025, su Milano e ATECO 82.11:

| Classe | scarto livello | L1 forma mensile |
|---|---:|---:|
| BTA1 | +1,0% | 0,0634 |
| BTA2 | −3,0% | 0,0568 |
| BTA3a | −4,5% | 0,0662 |
| BTA3b | −3,1% | 0,0556 |
| **BTA4** | **−3,1%** | **0,0407** |
| BTA5 | −1,5% | 0,0737 |
| BTA6 | +3,8% | 0,0673 |

In ordine di grandezza: **±3% sul livello e ~0,05 di L1 sulla forma mensile**.

La soglia non è però uniforme fra i settori, ed è un risultato in sé. Per
l'**istruzione** (ATECO 85.31) il campione ARERA è rado al punto che i livelli
non sono monotoni nella potenza — BTA3b 10.401 > BTA4 8.159 > BTA5 3.853 — e il
rumore arriva al 60%: dove questo accade, la soglia non è una soglia. Per
l'**amministrazione pubblica** (84.11) avviene l'opposto: livelli monotoni e
rumore di fonte fino a −0,9%, il più basso incontrato.

## 5. I risultati

| | `office` | `scuola_superiore` | `comune` |
|---|---|---|---|
| bersaglio ARERA | 82.11 · BTA4 · 6.951 kWh | 85.31 · BTA6 · 96.991 kWh | 84.11 · BTA5 · 13.695 kWh |
| livello ottenuto | 4.781 (**0,69x**) | 107.103 (**1,10x**) | 13.274 (**0,97x**) |
| soglia sul livello | ±3,1% | −9,1% | −0,9% |
| L1 forma mensile | 0,2041 | 0,1579 | **0,0503** |
| soglia su L1 | 0,0407 | 0,1111 | 0,0504 |
| picco feriale | ore 10 | ore 10 | **ore 11** |
| picco GSE | ore 11 | ore 11 | ore 11 |
| TVD feriale | 0,464 | 0,262 | 0,261 |

**`comune` è l'unico che passa la forma mensile**, e per un millesimo. Nessuno
dei tre passa il livello in senso stretto.

### 5.1 `office`: quattro difetti chiusi, uno aperto

Prima di ogni correzione l'archetipo valeva 10.957 kWh contro 6.951 attesi
(1,58x), con forma mensile piatta — la media giornaliera feriale stava fra 40,0
e 43,6 kWh in *tutti* e dodici i mesi, agosto indistinguibile da gennaio — e i
festivi nazionali erano giornate di lavoro piene (Natale 47,9 kWh).

| | livello | L1 | picco |
|---|---|---|---|
| `02` originale | 10.957 (1,58x) | 0,0866 | ore 15 |
| `03` + regimi, festivi, pausa pranzo | 5.227 (0,75x) | 0,2991 | ore 15 |
| `04` + chiusura di agosto | 4.969 (0,71x) | 0,2462 | ore 10 |
| `05` + raffrescamento fino al 15 set | 4.781 (0,69x) | 0,2041 | ore 10 |

Chiusi: festivi (Natale a 1,19 kWh, i soli carichi permanenti), stagionalità
(da 11,3 kWh/giorno in maggio a 29,4 in luglio), chiusura di agosto (7,4% contro
il 6,9% ARERA), picco feriale.

**Il passaggio `03` è il risultato metodologico più utile del lavoro**: una
correzione fisicamente giusta — separare raffrescamento, riscaldamento e mezza
stagione — ha *peggiorato* L1 da 0,0866 a 0,2991. È il caso che
[`lpg_db/dati/validazione/NOTE_per_report.md`](CER_LoadProfiles/lpg_db/dati/validazione/NOTE_per_report.md)
descrive per il lato domestico: una correzione più realistica di un parametro
peggiora l'indicatore aggregato finché il resto del modello è sbagliato.
Inseguire la metrica avrebbe portato a scartare la correzione giusta.

Resta aperto il livello, al 69% dell'atteso, e **non è stato chiuso gonfiando
apparecchi o potenze**. Il contesto è nel docstring di `office.py`: ARERA misura
punti di prelievo reali ed è il bersaglio giusto; ENEA non risolve la questione
perché i suoi indici vengono dalle diagnosi obbligatorie ex art. 8 del D.Lgs.
102/2014, un campione in cui il grosso dei siti sta fra 3.000 e 10.000 m².
Chiuderla richiede un dato che nessuna delle due fonti pubblica: quante persone
e quanti metri quadri stiano dietro a un POD di classe BTA4.

### 5.2 `scuola_superiore`: due fonti che concordano

ARERA dà 96.991 kWh/anno a un POD BTA6 con ATECO 85.31; il benchmark RSE/2010
dà 15 kWh/m² elettrici. Il rapporto vale ~6.470 m², la taglia di un istituto
reale — ed è la superficie su cui l'archetipo è dimensionato. Le due fonti
restano indipendenti fra loro.

Il dimensionamento ha richiesto due giri, e il primo ha sbagliato bersaglio:
alzare l'illuminazione da 3,9 a 8,1 W/m² ha alzato il livello ma peggiorato
tutto il resto (L1 da 0,1635 a 0,1936), perché aggiungeva consumo solo nei
giorni di lezione. Il livello mancante non era nella didattica, e a dirlo è
ARERA: ad agosto, senza lezioni, un POD scolastico consuma ancora il 6,2% del
totale annuo — circa 194 kWh al giorno a scuola chiusa — contro l'11,7% di
gennaio. Portando la **base permanente** da 4,5 a 8 kW tutte le metriche si sono
mosse insieme. Non erano quattro difetti, era uno solo.

### 5.3 `comune`: riuscito al primo tentativo

Bersaglio 84.11 · BTA5, la cella meglio campionata fra quelle usate. Livello
0,97x e L1 0,0503 contro una soglia di 0,0504, con il picco feriale alle 11
esattamente come il GSE. Nessun ritocco: i tre punti che mancano sul livello
starebbero dentro il rumore, e limarli sarebbe tarare sul bersaglio.

I due tratti che lo distinguono da un ufficio si misurano: i **sabati** valgono
984 kWh (7,4% dell'anno) per lo sportello di anagrafe e stato civile, ed è
l'unico archetipo non domestico che consuma di sabato; la **sala consiglio**
vale 1.298 kWh fra le 20 e le 24 (9,8%), unico carico serale non domestico
dell'intera CER — e conta più del suo peso in kWh, perché cade in fascia F3 e
in ore senza sole.

## 6. Scomposizione dell'errore: la numerosità spiega zero

Uno scarto può venire dal modello o dal fatto che una istanza non è una media.
Con venti istanze per archetipo si adatta `TVD(N) = a + b/√N`.

| archetipo | `a` | TVD a N=1 | `b` | quota spiegata |
|---|---|---|---|---|
| `office` | 0,4652 | 0,4652 | 0,0000 | **0%** |
| `scuola_superiore` | 0,2651 | 0,2655 | 0,0004 | **0%** |
| `comune` | 0,2527 | 0,2529 | −0,0000 | **0%** |

Ciò che decresce come 1/√N è la **dispersione** (dev.std da 0,0035 a 0,0000),
non la media: mediare venti istanze dello stesso archetipo converge alla curva
media dell'archetipo, che una singola istanza già approssima.

È diverso dal lato domestico, dove le venti famiglie erano di tipologie diverse
e mediarle avvicinava davvero la media di popolazione. Qui la curva è **meglio
posta** — istanze dello stesso archetipo con semi indipendenti, che è l'ipotesi
di 1/√N — e proprio per questo risponde in modo più netto.

Anche il **livello** non è un artefatto di campionamento: su venti istanze varia
di ±4,5% (`office`), ±0,8% (`scuola_superiore`), ±1,1% (`comune`).

## 7. Difetti residui, dichiarati

1. **Il livello di `office` è al 69% dell'atteso.** Non chiuso, per non inseguire
   la metrica. Richiede un dato che le fonti non pubblicano.
2. **L1 resta fuori soglia per `office` (0,2041) e `scuola_superiore` (0,1579).**
   Per `office` gli scarti mensili valgono +9,7 punti d'estate e −9,6 fra inverno
   e maggio: il raffrescamento è troppo grande *rispetto alla base*, che è lo
   stesso difetto del livello visto da un'altra angolazione.
3. **Lo scarto sulle fasce è in buona parte un artefatto della fonte.** F1 è
   lun-ven 8-19 e gli archetipi sono accesi soprattutto lì, mentre il profilo GSE
   aggrega l'intera categoria "altri usi" comprese le utenze attive h24.
4. **Il profilo GSE è uno solo per tutti i non domestici e ignora il giorno della
   settimana** (TVD feriale contro domenica = 0,001). La chiusura nel fine
   settimana di un archetipo **non è validabile** su questa fonte, e l'errore
   irriducibile `a` del §6 è un *limite superiore*: contiene anche la distanza
   fra l'archetipo e la media di categoria.
5. **Il rumore di fonte non è calcolabile fuori dalla Lombardia**, perché la
   pubblicazione ARERA 2024 copre le sole 12 province lombarde.

## 8. Trappole trovate nei dati, e come sono state chiuse

Sono la parte che un lettore che rifà il lavoro deve conoscere.

- **Una cache avvelenata è sopravvissuta alla correzione del parser.** I valori
  2024 usano il punto come separatore delle *migliaia* (`17.655` = 17655); letti
  con la convenzione del 2025 davano numeri mille volte più piccoli. La cache si
  invalidava sull'impronta dei sorgenti, che non erano cambiati, quindi restava
  "valida": il livello 2024 di BTA6 risultava 37 kWh invece di 37.409, con uno
  scarto apparente del +103714%. La cache porta ora un `versione_parser`.
- **La colonna `Data ora` del file GSE 2025 è corrotta** da errore di virgola
  mobile (ultimo istante `22:59:59,998` del 31 dicembre) e verso fine anno resta
  indietro di un'ora. L'indice si ricostruisce dalle colonne intere.
- **Un TVD di 0,000 diceva "forma perfetta" dove il modello era spento.**
  `office` valeva 0,000 kWh su 2.496 ore di fine settimana: la curva
  normalizzata non esiste, e la media di NaN restituiva zero. Ora quelle celle
  dicono `spento`.
- **Lo zip ARERA 2024 contiene due coppie di file byte-identici** (BTA5 e BTA6):
  vanno deduplicati per contenuto, o le loro righe si contano due volte.
- **Le due annualità ARERA non hanno lo stesso formato**: nomi di colonna
  diversi, niente `Regione` nel 2024, `Anno` ripetuta, mese come numero nel 2025
  e come abbreviazione nel 2024 (`Gen` … `Sett`, con due t).
- **`outputs/csv/profili_aziende.csv` è obsoleto**: 8759 righe, manca
  `2025-03-30 02:00`, viene da un run precedente alla correzione sull'ora legale.
  `profili_tutti.csv` è invece integro. Per questo `valida_non_domestici.py`
  controlla in apertura che il CSV abbia 8760 ore continue.

## 9. Riproducibilità

```bash
cd CER_LoadProfiles/ramp_db

# il bersaglio e la soglia
python riferimento_arera_nd.py --ispeziona
python riferimento_arera_nd.py Milano --ateco 82.11 --anni 2024 2025
python riferimento_gse_nd.py

# i benchmark di letteratura
python leggi_quaderno_enea.py --elenca

# la misura
python valida_non_domestici.py ../outputs/csv/profili_tutti.csv

# non regressione dello strato dei regimi
python collaudo_regimi.py

# scomposizione modello / numerosita' (la generazione richiede ~47 minuti)
cd .. && python generate_load_profiles.py --config config/simulation_config.nd20.yaml
cd ramp_db && python numerosita_nd.py ../outputs/csv_nd20/profili_nd20.csv
```

La generazione è deterministica: i seed vengono da `_seed_stabile()` (crc32, non
`hash()`), quindi un run ripetuto a parità di catalogo produce gli stessi
profili byte per byte. È la premessa che rende attribuibile a una modifica del
modello qualunque differenza fra due esecuzioni.

## 10. Integrazione a valle

I due archetipi nuovi nascono **spenti** nel catalogo di
`config/simulation_config.yaml`: ogni voce di `ramp.use_cases` porta un
interruttore `enabled`, e la chiave assente vale *acceso* — così le altre
configurazioni restano valide senza essere toccate.

Il motivo dell'interruttore è a valle: ogni archetipo acceso aggiunge una
colonna a `profili_tutti.csv`, e `align_members_to_users.m` si ferma con errore
su ogni colonna che non trova in `[MEMBRI]`. Accenderli richiede quindi prima
una scheda CER che li contempli.

In `cer_config_writer.py` entrambi sono classificati **`PA`**, cioè enti
territoriali: l'edificio di una scuola secondaria di secondo grado è per legge
della Provincia o Città metropolitana (L. 23/1996 art. 3), e il comune è il
primo degli enti locali del Testo Unico. La categoria non è un dettaglio
contabile — rende il punto di prelievo **esente dal fattore F** di decurtazione
della tariffa premio.
