# Dove riprendere il lavoro non domestico

Branch `46-ramp-validation`, sospeso il 2026-09-06 per tornare a lavorare su
`main`. Tutto quello che serve per ripartire sta qui.

## Stato: che cosa e' finito e che cosa no

**Finito e verificato**

- Fix dell'ora legale in `ramp_runner.py`: i profili passano da 8759 a 8760 ore.
  Era il prerequisito di qualunque confronto orario.
- `riferimento_gse.py` e `riferimento_arera_nd.py`, i due giudici.
- `valida_non_domestici.py` e la riga zero in `00_baseline.txt`.
- Interruttore `attivo` per archetipo in configurazione: spegnerne uno non
  altera le colonne degli altri, verificato byte per byte.
- `calendario_italiano.py`: festivita', chiusura industriale di agosto,
  calendario scolastico lombardo, profilo di raffrescamento dai gradi giorno.

**Iniziato e NON concluso**

- `office.py` ha ricevuto maschera di calendario e stagionalita'. Funziona -
  Ferragosto e Natale a zero, luglio sopra gennaio - ma il livello e' sceso a
  3.646 kWh/anno contro un bersaglio ARERA di 6.840. Il condizionamento e'
  passato da 7.862 a circa 550 kWh: **troppo poco**.
- Gli altri due use case non sono stati toccati.

## Il punto in cui ci si e' fermati, e perche'

Ricavando la potenza del condizionatore dai gradi giorno normalizzati sul
giorno piu' caldo si ottiene la FORMA giusta ma un LIVELLO troppo basso.
Servirebbe una fonte esterna per il livello: prenderlo da ARERA sarebbe
circolare, perche' ARERA e' il giudice.

Le fonti cercate e il loro esito:

- **ENEA, "consumi della pubblica amministrazione"**: gli indici elettrici per
  gli uffici ci sono, ma stanno nella Figura 3.7 a pagina 46 del PDF, che e'
  un'immagine. Il testo non contiene i valori.
- **RSE, "Raccolta di profili di carico elettrico per utenze urbane e del
  terziario"**: sarebbe la fonte ideale, italiana e da misure reali, ma
  l'accesso non e' aperto. Vale una richiesta a RSE.

## La scoperta che cambia il piano: ELMAS

Dataset **ELMAS**, Nature Scientific Data, figshare DOI
`10.6084/m9.figshare.23889780`, licenza CC BY 4.0, 8,4 MB, scaricabile senza
registrazione. Profili orari per il 2018 da 55.730 clienti francesi misurati,
424 classi NACE aggregate in 18 cluster, tre livelli di potenza contrattuale.
NACE e' ATECO, quindi la chiave combacia con i dati ARERA gia' implementati.

Mappatura dei nostri archetipi sui cluster:

    82.11 ufficio / 84.11 PA -> cluster 5
    25.99 officina           -> cluster 1
    47.11 negozio alimentare -> cluster 3
    85.20 / 85.31 scuola     -> cluster 4
    56.10 ristorante         -> cluster 9
    93.11 impianti sportivi  -> cluster 17

**Misurato: ELMAS non va usato come generatore di profili.**

    distanza di forma fra i settori ELMAS          0,056
    variabilita' di una curva GSE fra i mesi       0,033
    ELMAS contro l'aggregato domestico             0,11 - 0,16
    RAMP contro l'aggregato domestico              0,30 - 0,48
    fra le famiglie domestiche, fra loro           0,21

I profili ELMAS sono medie di decine di migliaia di clienti, quindi smussati:
l'ufficio ha rapporto punta/notte 1,5, mentre un edificio singolo sta su 15-20.
Usandoli come profili di membro, una scuola risulterebbe MENO distinguibile da
una famiglia di quanto due famiglie lo siano fra loro (0,11-0,16 contro 0,21),
e i metodi di ripartizione collasserebbero sulla proporzionale. E' lo stesso
errore che il lavoro domestico ha evitato non usando mai le curve ARERA come
profili.

**ELMAS serve invece a TARARE RAMP**, ed e' proprio la fonte che mancava:

    base notturna        ufficio misurato al 3,4% per ora (RAMP: 0,0%)
    quota di agosto      scuola 5,6%, officina 6,6%, ristorante 8,7%
    quota domenicale     da 9,9% dell'officina a 13,5% del ristorante
    stagionalita'        risposta alla temperatura per settore

La catena resta non circolare: ELMAS calibra (francese, misurato), ARERA e GSE
giudicano (italiani). Stessa struttura di ActivityAssure contro ARERA sul lato
domestico. Da dichiarare come limite che ELMAS e' francese e del 2018: se ne
prende la forma, mentre livello e stagionalita' restano italiani.

Controllo di trasferibilita' gia' fatto: le sei forme ELMAS distano dal profilo
GSE italiano fra 0,039 e 0,078, cioe' poco.

## Da fare, in ordine

1. Scaricare ELMAS e aggiungere `riferimento_elmas.py` accanto agli altri due.
2. Ricavarne base notturna e stagionalita' per i quattro settori principali, e
   riprendere `office.py` dal punto in cui si e' fermato: il livello del
   condizionamento e' il primo numero da chiudere.
3. Prima di toccare `retail.py` e `small_industry.py`: convertire i duty cycle
   a potenza media equivalente. VERIFICATO che con `fixed_cycle > 0` il vettore
   di potenza giornaliera viene IGNORATO in silenzio - su un caso di prova,
   agosto consumava 241,8 kWh invece di zero. E' il difetto che puo' far
   fallire l'intera fase senza errori.
4. Correggere `small_industry.py`: `wd_we_type=2` contraddice il suo stesso
   docstring, che dichiara "lunedi'-sabato".
5. Ridurre il catalogo da sette a quattro archetipi (ufficio/PA, scuola,
   officina, negozio): con una CER a prevalenza domestica e uno o due membri
   non domestici, gli altri tre non ripagano il costo.

## Decisioni gia' prese, da non riaprire

- Bersaglio: **Milano**. Resta aperta l'incoerenza per cui `CER_input.txt`
  dichiara la CER a Pordenone mentre profili e validazione sono su Milano.
- Chiusura industriale: **quindici giorni centrati su Ferragosto**, 8-22
  agosto. Assunzione dichiarata, non un dato misurato.
- Classi ATECO di confronto: 82.11 ufficio, 25.99 officina, 47.11 negozio.
  Sono assunzioni dichiarate in `simulation_config.yaml`, scelte per cio' che
  l'archetipo E' e non per quale bersaglio avvicina di piu' il modello.

## Un numero da tenere presente

Il livello ARERA della stessa classe cambia di un fattore quindici fra le bande
di potenza: 82.11 vale 2.508 kWh/anno in banda 3-4,5 kW e 38.836 in banda
>16,5. **La banda dichiarata pesa sul bersaglio piu' di quasi ogni difetto del
modello**, e va messa al centro del report invece che in nota.
