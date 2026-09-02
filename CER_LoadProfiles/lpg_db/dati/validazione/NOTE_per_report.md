# Note per il report di fine Fase 2

Documento di lavoro. Raccoglie, passo per passo, che cosa e' cambiato, da che
cosa credo dipenda e quali soluzioni restano aperte. Si chiude prima della
Fase 3.

---

## Avvertenza metodologica che condiziona tutto il resto

**Le curve ARERA sono medie di popolazione.** Ogni curva oraria e' la media di
decine di migliaia di clienti della stessa classe di potenza. Mediare tanti
profili individuali attenua fortemente i picchi: quando una famiglia accende il
forno alle 20:00 e un'altra alle 21:00, la media mostra un rialzo largo e
basso, non due picchi stretti.

L'aggregato di **quattro** famiglie non puo' riprodurre quella smussatura, per
ragioni statistiche e non di modello. Una parte dello scarto residuo fra LPG e
ARERA e' quindi **numerosita' del campione**, non difetto del catalogo.

Tre conseguenze operative:

1. Il TVD contro ARERA **non e' un giudizio sul catalogo** finche' non si sa
   quanta parte dipende dalla numerosita'. La misura con 20 famiglie
   (`config/simulation_config.campione20.yaml`) serve a separare le due cose:
   calcolando la distanza per sottoinsiemi di 4, 8, 12, 16 e 20 utenze si vede
   quanto scende al crescere di N. Cio' che resta a 20 e' modello.
2. Le migrazioni si decidono **sull'evidenza** (ISTAT, AVQ, HETUS, catalogo),
   non inseguendo la metrica. Modificare il catalogo a ogni anomalia
   dell'indicatore significa tarare quattro famiglie su una media di
   popolazione, che e' un bersaglio sbagliato.
3. Gli indicatori robusti all'aggregazione restano validi e vanno privilegiati:
   **ripartizione in fasce F1/F2/F3**, ora del picco, consumo annuo. Sono
   grandezze integrali, molto meno sensibili alla numerosita' della forma
   punto per punto.

---

## Quadro d'insieme dei passi eseguiti

Configurazione: HT06, Milano, anno 2025, seed fissi. Riferimento: ARERA Milano
Residente, media 2024-2025. Rumore della fonte: TVD 0,006-0,011.

| passo | commit | livello medio | TVD feriale | F1 | F2 | F3 |
|---|---|---:|---|---:|---:|---:|
| riga zero (HT06 + Random) | `e04e0ea` | 2,22x | 0,227-0,380 | 30,01 | 42,00 | 27,99 |
| POD = famiglia + casa | `a6ab037` | 2,19x | 0,199-0,345 | 31,09 | 40,37 | 28,54 |
| EnergySaving | `26a038c` | 1,42x | 0,244-0,317 | 31,81 | 39,87 | 28,32 |
| HT02 circolatore singolo | `6696e8b` | 1,35x | 0,264-0,339 | 31,04 | 40,56 | 28,41 |
| D02 frigorifero | `628d5a6` | 1,41x | 0,248-0,315 | 31,14 | 39,78 | 29,08 |
| L11 ingresso in ufficio | `47a1825` | 1,38x | 0,248-0,327 | 28,10 | 41,97 | 29,92 |
| **ARERA (bersaglio)** | | **1,00x** | **0,006-0,011** | **31,11** | **30,29** | **38,60** |

**Il livello e' quasi risolto** (da 2,22x a 1,38x). **La forma no**: il TVD e'
praticamente fermo. Ma vedi l'avvertenza qui sopra prima di trarne conclusioni.

---

## Variazione per variazione: che cosa e' successo e perche'

### 1. POD = Electricity_HH1 + Electricity_House

**Osservato.** Livello +18%; TVD migliora su tutte e quattro; F1 va a bersaglio
(31,09 contro 31,11).

**Causa.** La pipeline scartava la componente di casa. Non era una scelta: era
una lettura parziale dell'output di LPG. Aggiungerla ha portato carico di base,
che e' proprio quello che mancava.

**Aperto.** In Lombardia il 27,1% delle abitazioni ha riscaldamento
centralizzato (AVQ 2024, `TRISC`): per quelle la pompa non sta sul contatore
della famiglia. HT06 e HT07 modellano solo il caso autonomo, quindi il POD
cosi' definito e' corretto per il 71,6% dei casi. Da dichiarare come limite.

### 2. energy_intensity: Random -> EnergySaving

**Osservato.** Livello da 2,19x a 1,42x, la variazione singola piu' grande.
TVD peggiora su tre famiglie su quattro. F3 scende.

**Causa.** `Random` sorteggia fra le alternative di ogni categoria, quindi le
differenze fra i quattro nuclei misuravano il sorteggio invece della
composizione familiare. Caso esemplare: il circolatore, 898 kWh/anno a due
famiglie e 281 alle altre due a parita' di house type. Il peggioramento della
forma ha causa identificata: `EnergySaving` sceglie anche il frigorifero piu'
piccolo del catalogo (82,9 kWh/anno), abbassando ancora il carico di base.

**Nota.** Era una conclusione gia' dimostrata nel §4.1 di
`CONTESTO_VALIDAZIONE_ARERA.md` ma mai applicata al file di configurazione
vivo, mentre il piano scriveva D02 e D03 dandola per fatta.

### 3. HT02 - un solo circolatore

**Osservato.** Componente casa da 281 a 125 kWh/anno, uniforme. Livello -5%.
TVD peggiora leggermente su tutte.

**Causa.** Ogni house type montava il gruppo di azioni 214 due volte, con due
cancelli (`TL 53` tutto l'anno 06:00-22:00 e `TL 3` sotto i 15 C). La pompa
restava accesa 7.784 ore l'anno su 8.760 e consumava 2,2 volte quanto il
catalogo stesso dichiara per una singola unita'. Il peggioramento del TVD e' di
nuovo carico di base tolto.

**Riferimento.** ISTAT Consumi energetici 2021, Tavola 7, Lombardia: 10,06 h/g
di riscaldamento nei mesi freddi, da cui 45-145 kWh/anno di circolatore.

**Aperto.** La pompa gira ancora tutto l'anno, agosto compreso (il cancello
`TL 3` e' condizionato alla temperatura ma la finestra e' 00:00-20:00). Non e'
stato corretto perche' `TL 3` e' condiviso da 18 house type. Soluzione
possibile: creare un time limit nuovo con l'orario italiano e ripuntare le sole
righe di HT06/HT07, senza toccare l'oggetto condiviso.

### 4. D02 - frigorifero di taglia realistica

**Osservato.** Primo passo che **migliora la forma su tutte e quattro**. Ore
00-03 da 0,9 a 1,1% della giornata. F3 +0,67. F1 esatto (31,14 contro 31,11).

**Causa.** Il frigorifero e' il principale carico continuo di una casa:
sottodimensionarlo svuota le ore notturne. Il gruppo 184 offriva sette
alternative, cinque delle quali guidate da profilo misurato e dichiaranti
`YearlyEnergyUse = 0`, quindi con consumo non leggibile dal catalogo e scelta
non prevedibile.

**Aperto.** Le ore notturne restano a 1,1% contro il 2,4-3,6% di ARERA: il
frigorifero era una causa, non l'unica. Restano da esaminare gli altri carichi
continui (standby, router, congelatore separato, che ISTAT da al 22,0% delle
famiglie lombarde).

### 5. L11 - ingresso in ufficio alle 08:00 (rettifica di L01)

**Osservato.** Effetto grande e in due direzioni opposte.

```
ora        07     08     09  |    18     19     20
prima    8,51  10,57   9,89  |  5,97   9,28  10,51
dopo     8,61   6,01   3,22  | 10,04  11,86  11,76
ARERA    3,78   3,96   3,92  |  5,32   6,43   6,67
```

Picco mattutino: ore 07-09 dal 29,0% al 17,8%. Sera: ore 18-20 dal 25,8% al
33,7%. Picco spostato dalle 08 alle 19. F1 peggiora (28,10 contro 31,11), F3
migliora.

**Causa.** Meccanica: entrando un'ora prima si rientra un'ora prima, quindi la
finestra serale in casa si allunga e quella mattutina si accorcia. La massa non
sparisce, si sposta.

**Perche' la correzione era giusta lo stesso.** AVQ 2024 sui soli occupati
lombardi: uscita di casa p25 07:00, mediana 07:30, p75 08:00; tragitto mediano
15 minuti. I dodici tratti che passano da `TL 12` si chiamano *"Work - Office
N, XXh, from 08:00"*. Il valore tedesco originale era gia' corretto per
l'Italia: `L01` lo aveva peggiorato.

**Lezione generale.** Una correzione piu' realistica di un parametro puo'
peggiorare l'indicatore aggregato finche' il resto del modello e' sbagliato.
E' un argomento in piu' per non usare il TVD come criterio di accettazione di
una singola migrazione.

**Conseguenza sul seguito.** Il difetto dominante e' ora la sera. `L08` (cena
alle 20:20) e `L10` (coda serale) erano previste come ultimi passi; sulla base
di questa misura sono diventate le piu' importanti.

---

## Difetti noti e non ancora corretti

| difetto | evidenza | dove si corregge |
|---|---|---|
| Sera troppo concentrata e anticipata: 18-20 al 33,7% contro 18,4% | ActivityAssure: picco `eat` di cena alle 20:20 in IT contro 19:20 in DE | `L08` |
| Coda serale assente: 22-23 al 4,3% contro il 10,1% | ActivityAssure: presenza `tv`+`pc` alle 22:00 al 35,6% in IT contro 25,4% in DE; AVQ: 2,0 h di TV al giorno | `L10` |
| Pranzo debole e mal collocato | AVQ: per il 59,4% dei lombardi il pasto principale e' il pranzo e il 64,6% lo consuma in casa nei feriali | `L07` |
| Bucato concentrato all'apertura del cancello delle 08:00 | ActivityAssure: la fascia 08-10 pesa il 5,3% in IT e il 4,7% in DE; nessuno dei due giustifica il picco | `L09` |
| Carico notturno ancora meno della meta' di ARERA | ore 00-03 all'1,1% contro 2,4-3,6% | da identificare: standby, congelatore separato |
| Circolatore acceso tutto l'anno | `TL 3` ha finestra 00:00-20:00 e non l'orario italiano | nuovo time limit dedicato a HT06/HT07 |
| 24 dicembre festivo nel calendario di Milano | non e' festivo in Italia; voce catalogata "Worldwide", quindi sfuggita a H01-H03 | `H04` |
| Cottura tutta elettrica | ISTAT Tavola 19 Lombardia: 89,5% dei piani cottura a gas, ma 83,9% dei forni elettrici | `D01` |
| Raffrescamento sovradimensionato e non stagionalizzato | `CoolingYearlyTotal` 5.000 kWh; `AdjustYearlyCoolingHours = 0` | `HT01` |

---

## Questioni aperte da chiudere nel report

1. **Quanto dello scarto e' numerosita'.** Da misurare con le 20 famiglie. E'
   la domanda che condiziona l'interpretazione di tutto il resto.
2. **La soglia di accettazione va ridefinita.** Il rumore della fonte
   (0,006-0,011) e' la variabilita' fra due anni della *stessa media di
   popolazione*: non e' il metro giusto per un campione di quattro. Serve una
   banda che tenga conto di N, oppure si dichiara che si validano fasce, ora
   del picco e livello, non la curva punto per punto.
3. **Classe di potenza per famiglia.** Resta un'assunzione: ARERA non pubblica
   il numero di clienti per classe e provincia. I risultati vanno riportati
   anche contro la classe adiacente.
4. **Rappresentativita' delle curve orarie ARERA.** Coprono i soli clienti
   trattati orari, sottoinsieme di cui non si puo' verificare la
   rappresentativita' coi dati pubblicati.
