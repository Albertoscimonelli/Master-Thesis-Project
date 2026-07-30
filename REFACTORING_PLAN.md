# Piano di Refactoring — Progetto CER

> **STATO: ESEGUITO il 2026-07-29 — con R2 poi ANNULLATO.**
> Gli interventi R1, R3, R4, R5 sono applicati e verificati contro la baseline numerica:
> **nessuna differenza**, delta esattamente 0.
> **R2 e' stato annullato per scelta**: introduceva una regressione di performance 2.8x su
> uno script che non fa parte della pipeline di `MAIN.m` e serve solo per test occasionali.
> `optimizer_PV.m` e' tornato allo stato originale. Vedi §8 per il consuntivo.
> Il piano resta qui come documentazione del metodo.

**Data:** 2026-07-29
**Vincolo assoluto:** *nessun cambiamento di funzionalita'*. Ogni intervento deve produrre
output numericamente identico a quello attuale. Questo piano riorganizza il codice, non lo
corregge.
**Scope:** struttura, modularita', leggibilita'. I **bug** sono trattati separatamente in
[`AUDIT_REPORT.md`](AUDIT_REPORT.md) e restano fuori da qui (vedi §6).

---

## 1. Stato attuale

### MATLAB

| File | Tot | Codice | Commenti | Giudizio |
|---|---:|---:|---:|---|
| `optimizer_PV.m` | 832 | **539** | 193 | 🔴 script monolitico, ~100 righe duplicate |
| `MAIN.m` | 619 | **311** | 207 | 🟠 script che fa 6 lavori, 4 blocchi ripetuti |
| `PROVA_PV.m` | 498 | **443** | 30 | 🔴 legacy morto, non referenziato da codice |
| `variance_least_core_cer.m` | 426 | 206 | 160 | 🟡 corpo principale lungo (2 cicli simili) |
| `profilo_prezzi_pun_2025.m` | 298 | 189 | 62 | 🟢 **modello da seguire** (4 helper locali) |
| `plot_benefit_network.m` | 129 | 78 | 34 | 🟢 ok |
| `nucleolus_cer.m` | 132 | 65 | 52 | 🟢 ok |
| `nash_bargaining_cer.m` | 100 | 34 | 60 | 🟢 ok |
| `shapley_cer.m` | 80 | 34 | 39 | 🟢 ok |
| `cer_coalition_values.m` | 64 | 25 | 34 | 🟢 ok |
| `irr_bisection.m` | 60 | 30 | 20 | 🟢 ok |
| `merge_pv_owner.m` | 42 | 19 | 18 | 🟢 ok |
| `method_color.m` | 22 | 14 | 7 | 🟢 ok |

I file di teoria dei giochi e gli helper grafici sono **gia' puliti e modulari**. Il debito e'
concentrato in tre file: `optimizer_PV.m`, `MAIN.m`, `PROVA_PV.m`.

`profilo_prezzi_pun_2025.m` mostra gia' il pattern giusto e va usato come riferimento
stilistico: una funzione pubblica sottile + helper locali (`datiPrezzi2025`,
`festiviNazionali2025`, `creaSommario`).

### Python — PEP8 sostanzialmente rispettato

| File | Righe | >79 char | >99 char |
|---|---:|---:|---:|
| `lpg_runner.py` | 374 | 19 | 4 |
| `ramp_runner.py` | 248 | 11 | 2 |
| `generate_load_profiles.py` | 214 | 5 | 0 |
| `postprocessing.py` | 139 | 1 | 1 |
| `ramp_inputs/use_cases/*.py` | 64–76 | 5 | 0 |

`snake_case` ovunque (zero violazioni di naming), type hints presenti, docstring presenti.
**Il lato Python non richiede refactoring strutturale** — solo rifiniture PEP8 (§5).

---

## 2. Principi

1. **KISS** — la soluzione minima che elimina il problema. Niente registry, niente pattern
   generici, niente astrazioni "per il futuro". Se serve un solo helper, se ne crea uno solo.
2. **Zero cambiamenti funzionali** — nessuna formula toccata, nessuna tolleranza cambiata,
   nessun bug corretto. I bug si correggono dopo, in commit separati e riconoscibili.
3. **Helper con un compito solo**, nome che dice cosa fa, idealmente < 40 righe di codice.
4. **Split per funzionalita', non per lunghezza** — si divide dove c'e' un confine concettuale
   reale (fisica / economia / grafici), non per far scendere un contatore di righe.
5. **Convenzioni gia' in uso nel repo** — commenti in italiano senza accenti, header H1 MATLAB
   maiuscolo, indentazione 4 spazi, `error('file:tag', ...)`. PEP8 per il Python.

---

## 3. Protocollo di verifica (da fare PRIMA di toccare qualsiasi cosa)

Senza questo, "nessun cambiamento funzionale" e' un'affermazione non verificabile. E' il punto
piu' importante del piano.

**Passo 0 — baseline.** Prima di ogni modifica:

```matlab
% baseline_capture.m
set(0,'DefaultFigureVisible','off');
evalc('MAIN');            clearvars -except <lista>; save('baseline_main.mat');
evalc('optimizer_PV');    save('baseline_optimizer.mat');
```

**Passo 1 — confronto dopo ogni singolo intervento** (non alla fine di tutti):

```matlab
% baseline_check.m : 0 differenze o l'intervento e' da rifare
new = load('after.mat'); old = load('baseline_main.mat');
f = intersect(fieldnames(old), fieldnames(new));
for i = 1:numel(f)
    a = old.(f{i}); b = new.(f{i});
    if isnumeric(a) && isnumeric(b)
        d = max(abs(a(:) - b(:)));
        if d > 0, fprintf('DIFF %-22s %.3e\n', f{i}, d); end
    elseif ~isequaln(a, b)
        fprintf('DIFF %-22s (non numerico)\n', f{i});
    end
end
```

La soglia e' **esattamente 0**, non "piccola": un refactoring che non cambia l'ordine delle
operazioni in virgola mobile deve dare bit identici. Se compare una differenza anche di 1e-15,
l'ordine delle operazioni e' cambiato e va capito perche' prima di proseguire.

**Verificato il 2026-07-29** — entrambi gli script girano su questa macchina, quindi la baseline
e' effettivamente ottenibile e `R2` e' verificabile:

| Script | Esito | Durata |
|---|---|---|
| `MAIN.m` | OK (tutti gli `assert` passano) | ~15 s |
| `optimizer_PV.m` | OK | **49 s** |

Valori di riferimento della configurazione ottima, da usare come controllo rapido di
non-regressione prima ancora del confronto completo:

```
IRR_opt = 0.0111323     NPV_opt = -27270.339     N_mod_opt = 110
```

**Due trappole pratiche nella cattura della baseline:**

- `optimizer_PV.m` inizia con `clear` e **azzera il workspace del chiamante**: qualunque
  variabile creata prima (timer, contatori) sparisce. Il `save` va fatto *dopo* la chiamata,
  senza dipendere da variabili preesistenti, e il cronometraggio va fatto fuori da MATLAB.
- 49 s a esecuzione significa che il ciclo verifica/correggi di `R2` costa ~2 minuti a giro:
  va messo in conto, non e' un intervento da fare di fretta.

Nota: `optimizer_PV.m` non e' eseguibile da un clone pulito perche' legge il TMY da
`C:\Users\scimo\OneDrive\...` (audit H5). Non blocca il refactoring qui, ma va ricordato.

**Un commit per intervento**, con il confronto baseline nel messaggio. Cosi' un eventuale
`git revert` e' chirurgico.

---

## 4. Interventi MATLAB, in ordine di esecuzione

### R1 — Archiviare `PROVA_PV.m` 🔴 *(rischio: nullo)*

**Problema:** 443 righe di codice morto, con difetti gia' corretti nel successore
(`NPV = sum(CF)` non attualizzato, `c_interconn` incoerente, nessun clamp sull'irradianza).
Nessun file `.m` lo chiama; solo la documentazione lo cita come `[LEGACY]`.

**Intervento:** spostare in `archive/PROVA_PV.m` con una riga in testa
`% [SUPERATO da optimizer_PV.m il 2026-07-29 — conservato per storico tesi]`.
Aggiornare i riferimenti in `STRUTTURA_PROGETTO.txt`.

**Perche' spostare e non cancellare:** e' materiale di tesi, la storia git non e' consultabile
in sede di discussione. Se preferisci, `git rm` va bene comunque.

**Effetto:** −443 righe di codice (−28% del MATLAB totale) a costo zero.

---

### R2 — Eliminare la duplicazione in `optimizer_PV.m` 🔴 *(rischio: alto — il piu' delicato)*

**Problema.** La simulazione oraria e l'analisi economica esistono **due volte**:

| | Loop di ottimizzazione | Ri-simulazione ottimale |
|---|---|---|
| Fisica oraria | righe 328–416 | righe 635–697 |
| Indicatori annuali | righe 418–428 | righe 699–705 |
| CAPEX / CF | righe 437–456 | righe 707–730 |
| IRR / NPV | righe 471–474 | righe 732–733 |

Le due copie differiscono solo per il suffisso `_opt` sulle variabili. Che sia una trappola e'
gia' documentato *nel codice stesso*: la riga 707 porta il commento
`% CAPEX (formula coerente con loop 4: ...)` — cioe' la coerenza e' mantenuta a mano. Ogni
correzione futura alla fisica va applicata due volte o i risultati divergono in silenzio.

**Intervento — due soli file nuovi** (non sette: la fisica intermedia resta in helper *locali*,
che e' quanto basta):

**`pv_simulate_config.m`** — simula una configurazione per 8760 ore.

```matlab
function R = pv_simulate_config(cfg, meteo, loads, par)
%PV_SIMULATE_CONFIG  Simulazione oraria annuale di una configurazione PV.
%   cfg   struct  tilt, D_rtr, N_inv        (la configurazione da simulare)
%   meteo struct  DNI, DIFF, T_amb
%   loads struct  build_cons, REC_cons
%   par   struct  parametri fissi (geometria, modulo, inverter, perdite)
%   R     struct  P_dc, P_ac_net, P_purch, P_toREC, P_togrid, G_tot, G_av, ...
```

con helper **locali** nello stesso file, uno per blocco fisico gia' oggi separato dai commenti
`% -- ... --`:

| Helper locale | Da righe | Righe attuali |
|---|---|---|
| `solar_position` | 332–345 | 14 |
| `plane_irradiance` | 347–359 | 13 |
| `row_shading` | 363–379 | 17 |
| `dc_ac_chain` | 381–389 | 9 |
| `energy_balance` | 391–414 | 24 |

**`pv_cashflow.m`** — CAPEX/OPEX/REV/CF + IRR + NPV, da righe 437–456 e 471–474.

```matlab
function E = pv_cashflow(P_dc_nom, P_ac_nom, energie, par)
%PV_CASHFLOW  Flussi di cassa, IRR e NPV di una configurazione.
%   E  struct  CAPEX0, CAPEX, OPEX, REV, CF, IRR, NPV, nCambiSegno
```

`optimizer_PV.m` diventa: §4 = loop che chiama le due funzioni e salva nelle matrici 3D
(~40 righe invece di 250); §7 = **le stesse due chiamate** con la configurazione ottima
(~15 righe invece di 100). La duplicazione sparisce per costruzione.

**Stima:** 832 → ~450 righe nello script + ~200 nei due nuovi file. Netto ~−180 righe, ma il
guadagno vero e' che la fisica esiste in un posto solo.

**Attenzione (rischio reale).** Il loop attuale scrive in array orari **preallocati fuori dal
loop e riusati** tra un'iterazione e l'altra (`delta`, `G_tot`, `P_ac`, …). Se una configurazione
esce con `continue` (riga 290), quegli array conservano i valori della configurazione precedente.
Spostare tutto in una funzione crea array **freschi a ogni chiamata**. Nei percorsi con
`continue` questo non cambia il risultato (i KPI sono messi a `NaN` e gli array non vengono
riletti), ma **va verificato esplicitamente** con il protocollo §3 prima di considerare
l'intervento chiuso. Se emerge una differenza, e' un bug preesistente da trattare in `AUDIT`,
non da "aggiustare" qui.

---

### R3 — Alleggerire `MAIN.m` 🟠 *(rischio: basso)*

**Problema.** Script di 311 righe di codice che fa caricamento dati, bilancio energetico,
economia, quattro ripartizioni, costi di rete e sei grafici. I quattro blocchi di ripartizione
(§3b, §3c, §3d, §3e) ripetono lo stesso schema: chiamata → intestazione → `disp(table)` →
due `fprintf` di quota → `assert` di efficienza → `plot_benefit_network`. Sono ~12 righe
identiche moltiplicate per 4.

Il grafico di confronto §3f e' l'esempio piu' chiaro del costo: aggiungere il quarto metodo ha
richiesto di ricalcolare a mano gli offset delle barre e di estendere a mano tre elenchi.

**Intervento — quattro helper:**

| Nuovo file | Sostituisce | Beneficio |
|---|---|---|
| `load_cer_data.m` | §1 (righe 57–155) + la locale `load_pv_generation` | Isola l'I/O; restituisce una struct `D` |
| `report_allocation.m` | il blocco stampa+`assert` ripetuto 4× | 48 righe → 4 chiamate |
| `plot_allocation_comparison.m` | §3f (righe 411–456) | Cicla su una lista di metodi: aggiungerne uno = 1 riga |
| `plot_cer_overview.m` | §5 (righe 493–546) + la locale `plotProfiliStagionali` | Toglie 60 righe di grafica dal main |

`report_allocation.m` firmato in modo da coprire tutte e quattro le varianti senza rami
speciali:

```matlab
function report_allocation(S, nome, extra)
%REPORT_ALLOCATION  Stampa il riepilogo di una ripartizione e verifica l'efficienza.
%   S      struct  risultato di *_cer (.table .phi .vGrand .prodShare .consShare)
%   nome   string  nome del metodo, per intestazione e messaggi
%   extra  string  (opzionale) righe aggiuntive gia' formattate dal chiamante
```

Le righe specifiche di un metodo (surplus del Nucleolo, iterazioni del VLC) restano **nel
chiamante** e passano da `extra`: niente `switch` sul nome del metodo dentro l'helper.

**Da NON fare** (over-engineering): una "registry dei metodi" con handle di funzione, o un
ciclo `for` sui quattro metodi che li renda anonimi. I quattro blocchi hanno commenti didattici
diversi che sono parte del valore della tesi. Si estrae la *ripetizione meccanica*, si lascia
la *prosa*.

**Stima:** `MAIN.m` 619 → ~230 righe, e resta leggibile come pipeline.

---

### R4 — Accorciare il corpo di `variance_least_core_cer.m` 🟡 *(rischio: basso)*

**Problema.** La funzione principale e' ~130 righe con due cicli di row-generation quasi
paralleli; l'algoritmo del paper si legge male perche' e' annegato nel setup dei solver.

**Intervento:** estrarre due helper locali nello stesso file (che ne ha gia' quattro):

```matlab
function [x, theta] = solve_master_lc(Gamma, vGamma, vGrand, n, lpOpts)   % eq. (16)
function x          = solve_master_vlc(Gamma, vGamma, vGrand, n, thetaLC, relax, qpOpts) % eq. (15)
```

I due cicli scendono a ~15 righe ciascuno e diventano leggibili come la procedura della
Sez. III.C del paper. Nessuna riga di matematica cambia: solo spostata.

---

### R5 — Helper condiviso per l'output dei metodi di ripartizione 🟢 *(rischio: nullo, priorita' bassa)*

Le quattro funzioni `*_cer.m` chiudono con lo stesso blocco:

```matlab
S.players = players;  S.phi = x;  S.vGrand = vGrand;
S.prodShare = x(1);   S.consShare = sum(x(2:end));
S.table = table(players(:), x, 100*x/vGrand, ...);
```

Estraibile in `pack_allocation_result(players, x, vGrand, colName)`, con le colonne extra
(`Surplus_EUR`, `PotereContrattuale_EUR`) aggiunte dal chiamante con `addvars`.

**Valutazione onesta:** risparmia ~20 righe su 4 file e aggiunge un livello di indirezione a
funzioni che oggi si leggono benissimo. **Da fare solo se R1–R4 sono andati lisci**; al limite
si salta senza perdite. Lo segnalo per completezza, non perche' lo consigli.

---

## 5. Interventi Python (PEP8) 🟢 *(rischio: nullo)*

Il codice e' gia' conforme nella sostanza. Restano tre rifiniture:

1. **Righe lunghe** — 39 righe superano i 79 caratteri, 7 superano i 99. Mandare a capo quelle
   sopra 99 (`lpg_runner.py`, `postprocessing.py`, `ramp_runner.py`); per le altre adottare
   esplicitamente un limite a 99 (deroga PEP8 comune e accettata) invece di lasciarlo implicito.
2. **Import dentro le funzioni** — `lpg_runner.py:46-48` importa `shutil`, `stat`, `os` dentro
   `_clean_lpg_results()`. Vanno in testa al modulo.
   *Non toccare* gli import locali di `ramp_runner.py` (righe 28, 89, 94, 178) e
   `lpg_runner.py:27-28`: sono deliberati (dipendenze opzionali e monkey-patch a runtime),
   spostarli in testa **cambierebbe il comportamento** all'import.
3. **Rendere PEP8 verificabile** — aggiungere un `setup.cfg` di 3 righe:

   ```ini
   [pycodestyle]
   max-line-length = 99
   exclude = venv,__pycache__
   ```

   e `pycodestyle` in un `requirements-dev.txt`. Oggi nel venv non c'e' alcun linter, quindi
   "seguire PEP8" non e' controllabile.

**Fuori scope:** spezzare `lpg_runner.py` (374 righe) — le sue funzioni sono gia' separate per
responsabilita' e sotto la soglia critica.

---

## 6. Cosa questo piano NON fa

Esplicitamente **fuori scope**, perche' cambierebbero i risultati:

- Tutti i bug di `AUDIT_REPORT.md`: seed non deterministici (C1), requirements incoerenti (C3),
  DST (H3), path assoluti (H5), `acosd` non clampato (H6), escalation off-by-one (M1),
  incentivo CER incoerente tra i due script (M2), modelli di condivisione diversi (M3).
- La `v(S)` del gioco cooperativo e ogni formula fisica o economica.
- Tolleranze numeriche, opzioni dei solver, criteri di convergenza.
- Rinominare variabili di dominio (`P_dc_nom`, `theta_z`, `omega`): sono nomenclatura tecnica
  standard, cambiarli peggiorerebbe la leggibilita' per un revisore di tesi.

**Un'eccezione da concordare:** i path assoluti (H5) rendono il progetto non eseguibile altrove.
Non e' refactoring in senso stretto e *cambia* quale file viene letto se l'albero e' diverso —
per questo lo lascio fuori. Se lo vuoi dentro, va fatto come intervento a se' stante e verificato
a parte.

---

## 7. Ordine di esecuzione consigliato

| # | Intervento | Rischio | Righe tolte | Prerequisito |
|---|---|---|---|---|
| 0 | Baseline numerica (§3) | — | — | — |
| 1 | **R1** archiviare `PROVA_PV.m` | nullo | −443 | 0 |
| 2 | **R3** helper di `MAIN.m` | basso | −390 | 0 |
| 3 | **R4** helper del VLC | basso | ~0 | 0 |
| 4 | **R5** Python PEP8 | nullo | ~0 | — |
| 5 | **R2** de-duplicare `optimizer_PV.m` | **alto** | −180 | 0, e tempo dedicato |
| 6 | R5-bis `pack_allocation_result` | nullo | −20 | opzionale |

`R2` e' ultimo di proposito: e' il piu' rischioso e il piu' lungo, e conviene affrontarlo quando
il protocollo di verifica e' gia' stato esercitato sugli interventi facili.

**Risultato atteso:** da 2 902 a ~1 900 righe di MATLAB, nessun file sopra le 450 righe, fisica
PV e blocchi di report in un posto solo, e output numericamente identico riga per riga.

---

## 8. Consuntivo dell'esecuzione (2026-07-29)

### Verifica

| | Variabili confrontate | Esito |
|---|---:|---|
| `MAIN.m` | 63 comuni | **tutte identiche** |
| `optimizer_PV.m` (prima del rollback) | 180 comuni | tutte identiche |

Delta esattamente `0.0e+00` su tutte le grandezze numeriche.

### Dimensioni finali

| File | Prima | Dopo |
|---|---:|---:|
| `MAIN.m` | 619 (311 cod.) | **354 (132 cod.)** |
| `PROVA_PV.m` | 498 (443 cod.) | archiviato |
| `optimizer_PV.m` | 832 (539 cod.) | 832 — **invariato (R2 annullato)** |

Il codice effettivo della pipeline principale e' calato di ~390 righe.

### R2 annullato: perche'

La de-duplicazione di `optimizer_PV.m` era corretta (verifica a delta 0) ma **rallentava lo
script di 2.8x**: da 49 s a 138 s. La causa e' il loop orario, eseguito ~4.7 milioni di volte:
accessi a campi di struct (`par.W_m`, `par.lat`, ...) e ~19 milioni di chiamate alle
micro-funzioni locali. In MATLAB entrambe le cose costano molto piu' di variabili semplici e
codice inline.

Dato che `optimizer_PV.m` **non fa parte della pipeline di `MAIN.m`** ed e' usato solo per
test occasionali, il rapporto costo/beneficio non regge: si e' preferito riportarlo allo stato
originale (`git restore`) e rimuovere i tre helper `pv_*.m`, che servivano solo a lui.
KPI dopo il rollback: `IRR_opt = 0.0111323`, `NPV_opt = -27270.339` — identici all'originale,
runtime 44 s.

**Se un giorno servisse rifarlo**, la lezione e': la de-duplicazione utile vive al livello di
*una* funzione `pv_simulate_config` usata sia dal loop §4 sia dalla ri-simulazione §7. Le
micro-funzioni al suo interno (posizione solare, irradianza, ombreggiamento, bilancio) vanno
lasciate inline come blocchi commentati, e i parametri spacchettati in scalari locali fuori dal
loop orario. Cosi' si elimina la duplicazione senza pagare il 2.8x.

### Difetto preesistente scoperto (e ora di nuovo presente)

La de-duplicazione aveva rivelato che 22 array orari (`G_tot`, `theta_z`, `P_ac_net`, ...)
sono preallocati e riusati a ogni iterazione, e a fine loop contengono i valori dell'**ultima
configurazione simulata**. Nessuno li legge — sono residui — ma compaiono nel workspace come
se fossero risultati. Col rollback il comportamento e' tornato: e' innocuo, ma vale la pena
saperlo se si ispeziona il workspace dopo un run.

### Scostamenti dal piano

1. **R3 ha prodotto 4 helper di plotting invece di uno** (`plot_cer_energy`,
   `plot_pv_vs_demand`, `plot_load_profiles` + `plot_allocation_comparison`): un unico
   `plot_cer_overview` avrebbe richiesto 14 argomenti. Tre funzioni da 4-6 argomenti sono
   piu' KISS di una da 14.
2. **R5-bis (`pack_allocation_result`) non eseguito**, come gia' sconsigliato al §5.
3. **Unica differenza visibile**: l'output di console dei quattro metodi di ripartizione e'
   ora uniforme — tutti stampano `Valore grande coalizione` (prima solo lo Shapley) e usano
   lo stesso allineamento. Nessun valore numerico cambia.
4. **Il protocollo di verifica non misurava i tempi**, solo i numeri: per questo la regressione
   di R2 e' emersa solo a posteriori. Un confronto futuro dovrebbe includere il runtime.
