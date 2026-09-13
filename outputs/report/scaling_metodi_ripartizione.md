# Tempi di esecuzione dei metodi di ripartizione al crescere della CER

Test di scala su `MAIN.m` (pipeline trilevel completa) sulle 11 comunita' gia'
descritte in [validazione_lombardia100.md](validazione_lombardia100.md) e
[composizione_cer_scalata.md](../tables/composizione_cer_scalata.md), da 4 a
101 membri (domestici + il membro `office`).

## Risultato principale

| Membri | Tempo totale | Note |
|---:|---|---|
| 4 | 12,8 s | |
| 6 | 16,9 s | |
| 9 | 53,9 s | |
| 11 | 1 min 27 s | |
| 16 | 5 min 12 s | |
| 19 | 17 min 21 s | |
| 21 | **>53 min, interrotto** | Shapley 9:13, Nucleolo 18:00, Nash Bargaining >25 min senza finire |
| 26, 51, 76, 101 | non tentati | vedi §3 |

La crescita e' chiaramente super-lineare gia' a partire da ~16 membri, e
diventa impraticabile per un uso iterativo fra 19 e 21 membri — in linea con
l'aspettativa di partenza (intorno a 18-20 utenti).

## 1. Causa: tre metodi diversi rifanno la stessa enumerazione O(2^n)

`cer_coalition_values.m` calcola v(S) per tutte le 2^n-1 coalizioni non vuote
con un ciclo `for` esplicito (non vettorizzato fra coalizioni): per ognuna,
due `sum()` su una sottomatrice 8760×|S| piu' una chiamata a
`cer_shared_value.m`. E' chiamata **indipendentemente** da:

- `shapley_cer.m` (Shapley esatto)
- `nucleolus_cer.m` (Nucleolo)
- `nash_bargaining_cer.m` (Nash Bargaining)

nessuna delle tre riusa il risultato delle altre. A N=21, il conto misurato
(cronometro per metodo aggiunto in `MAIN.m`):

| Metodo | Tempo (N=21) |
|---|---|
| Shapley esatto | 9 min 13 s |
| Nucleolo | 18 min 00 s |
| Nash Bargaining | >25 min (interrotto, mai finito) |

Il Nucleolo costa quasi il doppio di Shapley (stessa enumerazione, piu' una
sequenza di programmi lineari sopra); Nash Bargaining a questa taglia e'
risultato il piu' lento dei tre. Il `Variance Least Core` (Ferrucci, Fioriti,
Poli, IEEE PES ISGT Europe 2025) **non** ha questo problema: usa row-generation
(Master + Separation MILP) e genera solo le coalizioni realmente vincolanti,
per costruzione applicabile a comunita' di decine o centinaia di membri.

**Non e' stato applicato nessun fix**: condividere l'enumerazione fra i tre
metodi (calcolarla una volta, passarla ai tre) e' un'ottimizzazione reale ma
piu' invasiva di quanto richiesto in questa sessione — segnalata qui per una
fase futura.

## 2. Bug trovato e corretto in MAIN.m

`stratified_expected_value_cer.m` (SEV) si autodisattiva quando n > 12
(soglia **diversa e piu' bassa** di quella di Shapley, n > 20): lascia
`muExact`/`strataBias` vuoti e stampa un warning invece di enumerare. A N=16
questo mandava in crash `MAIN.m` riga 984 (`relBiasMax = ...`), che indicizzava
l'array vuoto senza controllarne prima la forma.

**Fix applicato** (righe 983-1000 circa di `MAIN.m`): guardia
`isempty(SEV.strataBias)` che sostituisce il calcolo con una nota esplicita
("non calcolato, validazione saltata, n=%d > 12") invece di andare in errore.
Nessun'altra parte del codice referenzia `relBiasMax`, quindi il fix e'
isolato.

**Cronometratura aggiunta**: quattro `tic/toc` (Shapley, Nucleolo, Nash
Bargaining, Coalition Excess) con stampa `[cronometro] <metodo>: <durata>`,
per capire in futuro quale metodo pesa senza dover rifare il profiling a mano.

## 3. Schede escluse dal test (51, 76, 101 membri)

Per queste taglie 2^n e' gia' fuori da qualunque tempo pratico (2^51 e oltre):
non sono state nemmeno tentate. Restano in `CER_configuration/` come le altre
otto, semplicemente non sono state eseguite.

## 4. Verifica di correttezza dello Shapley esatto

Motivata dal sospetto che 2^21 = 2.097.152 coalizioni in 9 min 13 s fosse
troppo veloce per essere un'enumerazione vera.

- **Formula verificata riga per riga**: peso di Shapley
  `w(s) = s!(n-s-1)!/n!`, contributo marginale `v(S∪{i}) - v(S)` con
  indicizzazione a bitmask corretta (`shapley_cer.m`, righe 62-78) — combacia
  con la definizione teorica.
- **Controllo incrociato gia' presente in produzione**: `MAIN.m` (~riga 535)
  verifica che `Sh.vGrand` coincida (tolleranza 1e-6) con un calcolo
  indipendente del valore della grande coalizione. Non e' mai fallito in
  nessuno dei sei run completati.
- **Il tempo torna con i conti**: l'implementazione e' un doppio ciclo `for`
  non vettorizzato fra coalizioni. Stima: ~2,1M coalizioni × ~200.000 flop
  ciascuna (due `sum()` su sottomatrici 8760×|S| + `cer_shared_value`) ≈ 440
  miliardi di operazioni in 553 s, cioe' **~800 milioni di flop/s** — resa
  modesta e del tutto ordinaria per MATLAB single-thread con slicing ripetuto,
  non sospetta.

**Conclusione**: l'implementazione e' matematicamente corretta. Non e' pero'
ottimizzata (nessun trucco di vettorizzazione fra coalizioni tramite la
matrice di incidenza `A_inc` gia' calcolata) — margine di miglioramento reale,
ma non un difetto da correggere ora.

## 5. Accuratezza delle tre approssimazioni contro lo Shapley esatto

Scarto relativo medio (eq. 17, Cremers, Robu, Zhang, Andoni, Norbu, Flynn,
*Efficient methods for approximating the Shapley value for asset sharing in
energy communities*, Applied Energy 331 (2023) 120328):

| Membri | Marginal Contribution | Stratified Expected Value | Adaptive Sampling |
|---:|---:|---:|---:|
| 4 | 0,36% | 18,70% | 0,70% |
| 6 | 35,79% | 46,74% | 1,32% |
| 9 | 36,72% | 47,22% | 1,09% |
| 11 | 37,36% | 43,43% | 1,42% |
| 16 | 32,85% | 37,57% | 1,15% |
| 19 | 30,80% | 34,73% | 2,01% |

**L'Adaptive Sampling e' l'unica approssimazione affidabile**, con scarto
1-2% in ogni configurazione testata. Marginal Contribution e Stratified
Expected Value sono entrambe inaffidabili (30-47%) tranne nel caso degenere a
4 membri.

**Nota**: il commento originale in `MAIN.m` (§3o, righe ~966-970) riporta "MC
sbaglia ~1%, SEV ~22%" — numeri calibrati sulla community di esempio
originaria (6 utenti generici), non sulle composizioni reali ISTAT usate qui.
Sui nostri dati quella cifra **non regge**: MC e' quasi sempre pessimo, non
buono. La spiegazione strutturale gia' in codice resta valida (SEV assume
membri intercambiabili, falso quando la produzione e' di un solo prosumer su
N) ma la dimensione dello scarto va aggiornata per composizioni realistiche.

## 6. Altre modifiche di questa sessione

- **11 schede** in `CER_configuration/` compilate con `zona_mercato = nord`
  (dichiarato: coerente con la geografia Milano/Lombardia gia' usata in tutto
  il progetto — non e' un dato misurato).
- **Scheda minima tracciata in git sostituita**: `CER_5_2_0.txt` e' stata
  spostata dall'utente in `CER_configuration/Provvsiorio/` insieme al resto
  del vecchio sweep (scheda9). Promossa **`CER_3_1_0.txt`** (4 membri) a
  nuova scheda di riferimento nel `.gitignore`, con i file che dichiara
  (`PV4.CSV`, `3_utenti.xlsx`) riammessi di conseguenza — altrimenti un clone
  pulito del progetto non avrebbe piu' nessuna scheda eseguibile.

## Raccomandazione pratica

- Fino a ~15-16 membri: Shapley esatto e' ancora praticabile per un'analisi
  puntuale (ordine dei minuti).
- Oltre ~18-20 membri: **Shapley esatto, Nucleolo e Nash Bargaining diventano
  insostenibili** per un uso iterativo. Usare **Adaptive Sampling Shapley**
  come proxy (scarto 1-2%, costo O(n·M) con M = `as_campioni`).
- Il Variance Least Core resta applicabile a qualunque N per costruzione
  (row-generation), e puo' quindi accompagnare l'Adaptive Sampling anche
  sulle comunita' piu' grandi (26-101 membri) senza il problema qui descritto.
