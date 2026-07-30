# Guida ai modelli di distribuzione dei benefici CER

Questo documento spiega **cosa** è stato implementato, **come** e soprattutto **perché**
sono state fatte determinate scelte, con particolare attenzione alla matematica.
Riguarda i quattro metodi di ripartizione dei ricavi della comunità energetica:

1. **Shapley value** — Moncecchi et al., *Appl. Sci.* 2020 (eq. 39)
2. **Nucleolo** — Fioriti et al., *Appl. Energy* 2021 (eq. 7)
3. **Nash Bargaining** — Yan et al., *Int. J. Electr. Power Energy Syst.* 152 (2023) 109218
4. **Variance Least Core** — Ferrucci, Fioriti, Poli, IEEE PES ISGT Europe 2025

> **Nota:** le sezioni 2 e 3 sotto trattano in dettaglio Shapley e Nucleolo; il Nash
> Bargaining è documentato nel codice ([`nash_bargaining_cer.m`](nash_bargaining_cer.m), che ne
> spiega per esteso derivazione e adattamento al gioco CER) più che in questa guida — non ha
> ancora una sezione matematica dedicata qui. Il Variance Least Core ha invece la sua sezione
> completa (§7).

---

## 0. Architettura dei file

| File | Ruolo |
|------|-------|
| [`cer_coalition_values.m`](cer_coalition_values.m) | Costruisce la **funzione caratteristica** `v(S)`, condivisa da tutti i metodi |
| [`shapley_cer.m`](shapley_cer.m) | Calcola lo **Shapley value** dalla `v(S)` |
| [`nucleolus_cer.m`](nucleolus_cer.m) | Calcola il **Nucleolo** dalla `v(S)` (LP sequenziali) |
| [`nash_bargaining_cer.m`](nash_bargaining_cer.m) | Calcola il **Nash Bargaining** dalla `v(S)` (forma chiusa) |
| [`variance_least_core_cer.m`](variance_least_core_cer.m) | Calcola il **Variance Least Core** per **row-generation**, valutando `v(K)` su richiesta |
| [`MAIN.m`](MAIN.m) | Sezioni `3b` (Shapley), `3c` (Nucleolo), `3d` (Nash), `3e` (VLC), `3f` (confronto) |

**Scelta di design fondamentale.** I metodi *non* ricalcolano l'energia condivisa
ciascuno per conto suo: partono tutti dalla **stessa** `v(S)` di
[`cer_coalition_values.m`](cer_coalition_values.m). Questo garantisce che siano
**matematicamente confrontabili** (giocano lo stesso identico gioco) — esattamente
l'impostazione con cui Fioriti li mette a confronto nelle Fig. 9–10.

**Unica eccezione:** il Variance Least Core usa la stessa *formula* di `v(S)`, ma la
valuta **su richiesta** invece di leggerla dal vettore precalcolato. Il motivo è di
scalabilità, non di modellazione: `cer_coalition_values` costruisce `2^n` valori, quindi
è impraticabile oltre ~20 giocatori, mentre il VLC è pensato per comunità da decine o
centinaia di membri (vedi §7).

---

## 1. Il gioco cooperativo

Un gioco cooperativo a utilità trasferibile (TU-game) è una coppia `(N, v)`:

- `N` = insieme dei **giocatori**;
- `v : 2^N → ℝ` = **funzione caratteristica**, che a ogni coalizione `S ⊆ N`
  associa il valore `v(S)` che quella coalizione sa generare da sola.

### 1.1 I giocatori — **un giocatore per utente**

```
N = { office_1, small_industry_1, retail_1, household_1, household_2, household_3 }
n = |N| = 6
```

Ogni utente è **un** giocatore che porta con sé sia il proprio carico residuo sia la
propria eccedenza di produzione. Un utente senza impianto ha generazione nulla (puro
consumatore); un utente con impianto è un **prosumer** e contribuisce a entrambi i lati
del bilancio.

> **Modello precedente (superato il 2026-07-29).** Prima esisteva un settimo giocatore
> "PV" che aggregava *tutta* la produzione della comunità. Con più impianti di
> proprietari diversi quel modello era inservibile: sommava tutte le produzioni in un
> giocatore fittizio, rendendo impossibile distinguere chi avesse prodotto cosa. Aveva
> anche un effetto collaterale sgradevole: il proprietario dell'impianto risultava un
> **null player** (il suo carico residuo è nullo proprio nelle ore in cui c'è
> eccedenza), quindi riceveva 0 e serviva `merge_pv_owner.m` per ricucire i due nodi
> nei grafici. Ora il merito della produzione è nativamente del prosumer che la
> possiede, e quell'helper è stato archiviato.

### 1.2 La funzione caratteristica `v(S)`

Definita in [`cer_coalition_values.m`](cer_coalition_values.m):

```
v(S) = Σ_t  min( Σ_{i∈S} gen_i(t),  Σ_{i∈S} load_i(t) ) · P_CER(t)
```

dove `gen_i` è l'eccedenza dell'utente `i` e `load_i` il suo carico residuo, entrambi
già al netto dell'autoconsumo dietro al contatore (vedi
[`load_cer_data.m`](load_cer_data.m)). `P_CER` è l'incentivo €/kWh sull'energia condivisa:
può essere uno scalare costante oppure un vettore `[H x 1]`, cioè la tariffa incentivante
premio oraria `TIP_h` (eq. 3.1) calcolata da
[`compute_cer_incentive.m`](compute_cer_incentive.m) sul prezzo zonale orario letto da
[`load_zonal_price.m`](load_zonal_price.m). In [`MAIN.m`](MAIN.m) è quest'ultima a essere
usata (`P_CER_h`); i quattro metodi (`cer_coalition_values`, `shapley_cer`,
`nucleolus_cer`, `nash_bargaining_cer`, `variance_least_core_cer`) accettano entrambe le
forme senza distinzioni di codice.

Poiché eccedenza e carico residuo di uno stesso utente sono **complementari** (in ogni
ora si ha l'una o l'altro, mai entrambi), risulta `v({i}) = 0` per ogni singolo
giocatore: da solo nessuno condivide nulla. Serve almeno un prosumer in eccedenza e
almeno un utente con carico residuo.

**Perché questa `v` e non quella (più complessa) di Fioriti.** Il paper di Fioriti
definisce `v(J) = SẄ_tot(J) − SW_NC(J)` (costo-opportunità rispetto al caso
non-cooperativo), che richiede tutta la sua macchina MILP (aggregatore, batterie,
peak power, configurazioni NA/NC/ANC/CO). Noi **non** importiamo quel framework:
prendiamo solo la *regola di allocazione* (Shapley, Nucleolo) e la applichiamo alla
nostra `v` semplice. Questo è coerente con la scelta fatta in precedenza
(distribuire **solo l'incentivo sull'energia condivisa**) e mantiene i risultati
allineati a `rev_shared` già calcolato in [`MAIN.m`](MAIN.m).

**Proprietà utili della nostra `v`:**
- `v(∅) = 0` e `v({i}) = 0` per ogni singolo giocatore (complementarità, vedi sopra);
- `v(S) = 0` per ogni `S` senza prosumer → i prosumer sono *giocatori essenziali*;
- `v` è **monotòna** (aggiungere un utente non può ridurre l'energia condivisa);
- il valore della grande coalizione `v(N) = Σ_t min(gen_tot, load_tot)·P_CER(t)`
  coincide *per costruzione* con il ricavo annuo da energia condivisa, e **non è
  cambiato** passando al modello per-prosumer: la torta da dividere è la stessa, cambia
  solo come la si divide. In [`MAIN.m`](MAIN.m) c'è un `assert` che lo verifica.

### 1.3 La codifica a bitmask (ponte matematica ↔ codice)

Le coalizioni sono `2^n`. Le indicizziamo con un intero `m ∈ {0, …, 2^n−1}` letto in binario:

```
bit i (peso 2^(i-1))  →  utente i
```

Esempio con `n = 6`: `m = 0b000101 = 5` ⇒ coalizione `{utente_1, utente_3}`.

In MATLAB gli array partono da 1, quindi **il valore della coalizione `m` si legge `v(m+1)`**;
la coalizione vuota è `v(1)`, la grande coalizione è `v(end)`.

La **matrice di incidenza** `A_inc` (dimensione `2^n × n`) ha
`A_inc(m+1, i) = 1` se il giocatore `i` è in `m`. È la traduzione vettoriale della
appartenenza, usata per scrivere i vincoli del Nucleolo come prodotti matrice-vettore.

**Ottimizzazione di calcolo.** Poiché la presenza del PV agisce da semplice
interruttore on/off, in [`cer_coalition_values.m`](cer_coalition_values.m) si calcola
`v` solo sui `2^{n-1}` sottoinsiemi di *consumatori* (`vCons`), e poi si propaga:
`v(mask) = vCons(mask senza il bit del PV)` se il PV c'è, `0` altrimenti.

---

## 2. Shapley value

File: [`shapley_cer.m`](shapley_cer.m).

### 2.1 La formula

$$
\varphi_i(v) \;=\; \sum_{S \subseteq N\setminus\{i\}}
\frac{|S|!\,\bigl(n-|S|-1\bigr)!}{n!}\;\bigl[\,v(S\cup\{i\}) - v(S)\,\bigr]
$$

Il termine `v(S∪{i}) − v(S)` è il **contributo marginale** del giocatore `i` quando
si aggiunge alla coalizione `S`.

### 2.2 Da dove viene il peso `|S|!(n−|S|−1)!/n!`

Interpretazione probabilistica (la più chiara). Immagina di far entrare i giocatori
nella grande coalizione in **ordine casuale** (tutti gli `n!` ordini equiprobabili).
In un dato ordine, il contributo di `i` è `v(predecessori ∪ {i}) − v(predecessori)`.
Lo Shapley value è la **media** di questo contributo su tutti gli ordini.

Quanti ordini hanno come predecessori di `i` *esattamente* l'insieme `S` con `|S| = s`?
- `s!` modi di ordinare gli elementi di `S` prima di `i`;
- `(n − s − 1)!` modi di ordinare i restanti dopo `i`.

Quindi la probabilità di quel particolare `S` è `s!(n−s−1)!/n!`: è esattamente il peso.
Lo Shapley value è dunque un **valore atteso di contributi marginali**.

### 2.3 I quattro assiomi (perché è "equo")

Lo Shapley value è l'**unica** regola che soddisfa contemporaneamente:

1. **Efficienza:** `Σ_i φ_i = v(N)` (tutto il valore è distribuito).
2. **Simmetria:** se `i` e `j` contribuiscono uguale a ogni coalizione, ricevono uguale.
3. **Additività:** `φ(v + w) = φ(v) + φ(w)` su giochi sommati.
4. **Null player:** un giocatore con contributo marginale sempre nullo riceve `0`.

Questi assiomi sono verificati nel test di validazione (vedi §4).

### 2.4 Mappatura formula → codice

In [`shapley_cer.m`](shapley_cer.m#L52):

```matlab
w(s+1) = factorial(s) * factorial(n - s - 1) / factorial(n);   % il peso
...
for i = 1:n
    for mask = 0:(nSub-1)
        if bitget(mask, i) == 1, continue; end   % S non deve contenere i
        s    = sum(bitget(mask, 1:n));            % |S|
        marg = v(mask + bit_i + 1) - v(mask + 1); % v(S∪{i}) − v(S)
        phi(i) = phi(i) + w(s+1) * marg;
    end
end
```

`bit_i = 2^(i-1)` è il bit del giocatore `i`; `mask + bit_i` accende quel bit
(cioè costruisce `S ∪ {i}`). Il `+1` finale è solo l'offset 1-based di MATLAB.

### 2.5 Perché esatto e non per gruppi

Moncecchi **raggruppa** i consumatori perché ne ha 131 e lo Shapley costa `O(2^n)`
(per 131 giocatori `2^131` è impossibile). Noi abbiamo `n = 7`, cioè `2^7 = 128`
coalizioni: il calcolo **esatto su ogni singolo utente** è istantaneo e **non
introduce l'approssimazione** della distribuzione proporzionale intra-gruppo. È un
vantaggio diretto della piccola taglia del nostro caso.

---

## 3. Nucleolo

File: [`nucleolus_cer.m`](nucleolus_cer.m).

### 3.1 Il concetto: surplus ed equità "lessicografica"

Per una data ripartizione `x = (x_1, …, x_n)` e una coalizione `S`, definiamo il
**surplus** (o eccesso, segno invertito rispetto alla convenzione di costo):

$$
\theta_S(x) \;=\; \sum_{i\in S} x_i \;-\; v(S)
$$

Interpretazione: `θ_S` è quanto la coalizione `S` **guadagna restando** nella grande
coalizione invece di staccarsi e prendersi `v(S)` da sola. Se `θ_S < 0`, la coalizione
`S` è "scontenta" (le converrebbe uscire); se `θ_S ≥ 0` per ogni `S`, nessuno ha
interesse a uscire → l'allocazione è **stabile** (sta nel *Core*, vedi §3.4).

Il **Nucleolo** sceglie `x` per rendere la coalizione *più scontenta* il meno scontenta
possibile; poi, fissata quella, ottimizza la successiva, e così via. Formalmente:
si ordina il vettore dei surplus `(θ_S)` in senso **crescente** e si cerca l'`x`
(efficiente) che lo rende **lessicograficamente massimo**. È un criterio di tipo
**max-min iterato**: massimizza il minimo, poi il secondo minimo, ecc.

Schmeidler (1969) dimostra che il Nucleolo **esiste ed è unico**, e che **se il Core è
non-vuoto, il Nucleolo vi appartiene**.

### 3.2 La sequenza di LP (eq. 7 di Fioriti)

Non esiste formula chiusa: si risolve una **sequenza di programmi lineari**. Al primo
passo:

$$
\max_{x,\;\theta}\;\theta
\quad\text{s.t.}\quad
\sum_{i\in S} x_i - \theta \;\ge\; v(S)\;\;\forall S,\qquad
\sum_{i\in N} x_i = v(N)
$$

- L'obiettivo `max θ` con i vincoli `Σ_{i∈S} x_i − θ ≥ v(S)` significa
  "alza il pavimento `θ` sotto **tutti** i surplus" → massimizza il surplus minimo.
- L'uguaglianza `Σ x_i = v(N)` è l'**efficienza** (vincolo di chiusura).

Sia `θ*` l'ottimo. Alcune coalizioni saranno **vincolanti** (`θ_S = θ*`): per loro il
surplus non può salire oltre senza abbassare quello di altri. Queste si **congelano**
(diventano uguaglianze al livello `θ*`) e si rilancia l'LP massimizzando il surplus
*delle restanti*. Si itera finché `x` è completamente determinata.

### 3.3 Come si decide "quando fermarsi": il criterio del rango

Congelare le coalizioni vincolanti a ogni passo riduce i gradi di libertà di `x`.
Il punto è unico quando i vincoli congelati **determinano** `x` univocamente, cioè
quando le loro righe di incidenza (più la riga dell'efficienza) **generano tutto ℝⁿ**:

$$
\operatorname{rank}(M) = n
\qquad
M = \begin{bmatrix} \mathbf{1}^\top \\ \text{incidenze coalizioni congelate} \end{bmatrix}
$$

Questo è il criterio di Kohlberg/Maschler usato in
[`nucleolus_cer.m`](nucleolus_cer.m#L88): a ogni iterazione si aggiungono a `M` solo
le coalizioni vincolanti che **aumentano il rango** (le altre sono linearmente
implicate e si scartano); ci si ferma appena `rank(M) = n`. A quel punto il sistema
lineare ha soluzione unica = il Nucleolo.

### 3.4 Mappatura → codice

In [`nucleolus_cer.m`](nucleolus_cer.m#L70), variabili LP `[x(1..n); θ]`:

```matlab
f     = [zeros(n,1); -1];                       % max θ  ≡  min −θ
Aineq = [-A_inc(active,:),  ones(numel(active),1)];   % −Σ_S x + θ ≤ −v(S)
bineq = -v(active);                             %  ⇔  Σ_S x − θ ≥ v(S)
Aeq   = [ones(1,n), 0];  beq = vGrand;          % efficienza Σx = v(N)
% + righe di uguaglianza per le coalizioni gia' congelate (θ bloccato)
```

Note di implementazione:
- la **coalizione vuota** (`v=0`) e la **grande coalizione** (fissata dall'efficienza)
  sono escluse dal min-surplus (`isProper`);
- `thetaMin` = il `θ*` della **prima** iterazione = surplus della coalizione più
  scontenta dell'intero gioco; `inCore = (thetaMin ≥ 0)`.

### 3.5 Relazione con Shapley e Core

| | Shapley | Nucleolo |
|---|---|---|
| Cosa ottimizza | equità assiomatica (contributo marginale medio) | stabilità (surplus min lessicografico) |
| Forma | **formula chiusa** `O(2^n)` somme | **LP sequenziali** |
| Nel Core? | **non garantito** | **sì, se il Core è non-vuoto** |
| Unico? | sì | sì |

Il **Core** è l'insieme delle allocazioni efficienti e *razionali*
(`Σ_{i∈S} x_i ≥ v(S) ∀S`, cioè `θ_S ≥ 0 ∀S`). Lo Shapley è equo ma può cadere
fuori dal Core (instabile); il Nucleolo è "spinto" dentro il Core dalla sua stessa
costruzione max-min. Per questo il Nucleolo riporta anche il flag `inCore`.

---

## 4. Validazione effettuata

**Shapley** (test indipendente per permutazioni di tutti gli `n!` ordini):
- coincidenza con la formula a `< 10⁻¹²`;
- efficienza `Σφ = v(N)`;
- null player (consumatore a carico nullo → 0) e simmetria (consumatori identici →
  stessa quota) verificati esattamente.

**Nucleolo**:
- gioco di maggioranza a 3 (`v(S)=1` se `|S|≥2`) → `(⅓,⅓,⅓)` (simmetria);
- efficienza `Σx = v(N)`;
- **dominanza lessicografica** sul vettore dei surplus rispetto allo Shapley
  (`θ` ordinati: il Nucleolo è ≥);
- coerenza `thetaMin` Nucleolo ≫ `thetaMin` Shapley (rinforza la coalizione più debole).

---

## 5. Lettura dei risultati sul caso reale

Totale da distribuire ≈ **10.721 €/anno** (incentivo CER condiviso).

| Giocatore | Shapley | Nucleolo |
|---|---:|---:|
| PV (produttore) | 5.538 € (52%) | 1.801 € (17%) |
| small_industry_1 | 3.414 € | 6.416 € (60%) |
| altri consumatori | resto | resto |

Il Nucleolo **sposta valore dal produttore ai consumatori** (in particolare al carico
maggiore, `small_industry`, che assorbe gran parte dell'energia condivisa). È
*esattamente* il comportamento descritto da Fioriti (Sez. 7.5): *"the Nucleolus tends
to favour consumers over prosumers"*. Spiegazione: lo Shapley premia il **contributo
marginale** (il PV, indispensabile, ne ha tantissimo); il Nucleolo premia la
**stabilità**, alzando il surplus delle coalizioni di consumatori che altrimenti
sarebbero le più scontente.

---

## 6. Riepilogo delle scelte di progetto

1. **Un giocatore per utente** (dal 2026-07-29; prima il PV era un giocatore aggregato
   a sé) → i prosumer portano carico e produzione, il merito resta a chi possiede
   l'impianto, e il modello regge con più impianti di proprietari diversi.
2. **`v(S) = incentivo su energia condivisa**` (non il costo-opportunità MILP di Fioriti)
   → coerenza con `rev_shared` e con la scelta fatta per lo Shapley.
3. **Funzione `v(S)` condivisa** in un unico helper → Shapley e Nucleolo confrontabili.
4. **Shapley esatto, non per gruppi** → possibile perché `n = 7` (128 coalizioni).
5. **Convenzione "profit-game"** (surplus `θ_S = Σx − v(S)`, stabile se `≥ 0`)
   → coerente con la nostra `v` di ricavi.
6. **Terminazione del Nucleolo per rango** (criterio Kohlberg/Maschler) → garantisce
   unicità senza euristiche fragili.

---

## 7. Variance Least Core (row-generation)

Riferimento: T. Ferrucci, D. Fioriti, D. Poli, *Reward allocation in Energy Communities by
size, composition and prosumers penetration*, IEEE PES ISGT Europe 2025 (eq. 12–17).

### 7.1 Il problema che risolve

Il Nucleolo è unico ma richiede una **sequenza** di LP con criterio del rango, ed entrambi
— Shapley e Nucleolo — hanno bisogno di **tutte** le `2^n` coalizioni. Con `n = 7` sono 128
righe; con `n = 30` sono un miliardo; con `n = 100` il problema non esiste nemmeno su carta.
Il VLC nasce proprio per rompere questa barriera.

### 7.2 Least Core

Dato il **surplus** di una coalizione (stessa convenzione del Nucleolo, §3.1)

```
σ(K, x) = Σ_{i∈K} x_i − v(K)
```

il **Least Core** è l'insieme delle allocazioni efficienti che massimizzano il surplus della
coalizione più scontenta (eq. 12–13):

```
θ_LC = max θ
  s.t.  σ(K, x) ≥ θ      ∀ K ⊂ I        (2^n − 2 vincoli)
        Σ_i x_i = v(I)                  (efficienza)
        x ≥ 0                           (x ∈ B, eq. 9)
```

`θ_LC > 0` ⇒ ogni sottogruppo guadagna strettamente a restare nella CER ⇒ **coalizione
stabile**. `θ_LC = 0` ⇒ siamo sul bordo del Core.

> **Nota importante:** questo LP è *esattamente* la **prima iterazione** di
> [`nucleolus_cer.m`](nucleolus_cer.m). Per questo `VLC.thetaLC` e `Nu.thetaMin` devono
> coincidere — ed è il controllo incrociato usato come `assert` in `MAIN.m` §3e.
> (Differenza minore: il VLC impone anche `x ≥ 0`, come da eq. 9 del paper; nel gioco CER
> è non vincolante finché `θ_LC ≥ 0`, perché `v({i}) = 0` implica già `x_i ≥ θ_LC`.)

### 7.3 Da insieme a punto unico: la varianza

Il Least Core è un **poliedro**, non un punto. Il VLC ne sceglie l'elemento più vicino alla
ripartizione uniforme (eq. 14):

```
x_VLC = argmin { Σ_i (x_i − v(I)/|I|)²  :  x ∈ LC(I,v) }
```

Poiché l'efficienza fissa `Σ x_i = v(I)`, sviluppando il quadrato il termine lineare è
**costante** e il problema si riduce a `min x'x`: un QP con Hessiana `2·I`, definita
positiva ⇒ **minimo unico**. Nel codice: `Hqp = 2*eye(n)`, `fqp = zeros(n,1)`.

### 7.4 Row-generation: Master + Separation

L'idea chiave. La stragrande maggioranza dei `2^n − 2` vincoli non è attiva all'ottimo:
invece di scriverli tutti, si parte da un sottoinsieme `Γ` piccolo e lo si fa crescere solo
con i vincoli che risultano **effettivamente violati**.

| Passo | Problema | Solver |
|---|---|---|
| **Master** fase 1 (eq. 16) | `max θ` sui soli vincoli di `Γ` → dà `θ_LC` | `linprog` |
| **Master** fase 2 (eq. 15) | `min x'x` con `θ_LC` ormai fisso, sui soli vincoli di `Γ` | `quadprog` |
| **Separation** (eq. 17) | fra **tutte** le coalizioni, quella col surplus minimo dato `x` | `intlinprog` |

Ciclo: risolvo il Master → ottengo `x` tentativo → il Separation cerca la coalizione più
scontenta. Se il suo surplus rispetta già il livello richiesto, **nessun vincolo omesso era
violato** e la procedura converge; altrimenti quella coalizione entra in `Γ` e si ripete.
`Γ` parte dai singoletti ed è **ereditato** dalla fase 1 alla fase 2 (warm start).

Il paper misura tipicamente poche decine di iterazioni anche per comunità da 50 membri
(Fig. 3): sono le uniche coalizioni per cui `v(K)` viene mai calcolata.

### 7.5 Il Separation Problem è un MILP

Con `z_i = 1` se il giocatore `i` appartiene alla coalizione (eq. 17):

```
min_z  Σ_i x_i z_i − v(z)      s.t.  1 ≤ Σ_i z_i ≤ |I| − 1,  z ∈ {0,1}
```

`v(z)` contiene un `min()`, non lineare. Si linearizza con le variabili continue `s_t`
(energia condivisa all'ora `t`) e i due upper bound (eq. 5–6):

```
s_t ≤ genPV(t) · z_PV                    ← se il PV non è in K, s ≡ 0 e v(K) = 0
s_t ≤ Σ_i loadUsers(t,i) · z_(i+1)
v(z) = P_CER · Σ_t s_t
```

**La linearizzazione è esatta, non un rilassamento:** l'obiettivo *premia* `s` grande
(coefficiente `−P_CER`), quindi all'ottimo `s_t` sale fino al minore dei due bound, cioè
`s_t = min(genPV(t), load_K(t))` — proprio la definizione di `v(K)`.

Riduzioni per la scala: `s` è costruita solo sulle ore con `genPV > 0` (~metà delle 8760,
nelle altre `s_t = 0` per costruzione) e tutte le matrici dei vincoli sono `sparse`.

### 7.6 Mappatura → codice

| Formula | Codice in [`variance_least_core_cer.m`](variance_least_core_cer.m) |
|---|---|
| `v(K)` on-demand | funzione locale `coalition_value` |
| Master eq. (16) | blocco `FASE 1`, `linprog` con variabili `[x; θ]` |
| Master eq. (15) | blocco `FASE 2`, `quadprog` con `Hqp = 2*eye(n)` |
| Separation eq. (17) | `build_separation` (matrici fisse) + `solve_separation` (`intlinprog`) |
| Test di convergenza | `if sigmaMin >= thetaLC - tolAbs, break; end` |
| Crescita di `Γ` | `add_coalition`, con guardia anti-stallo sui duplicati |

Tolleranza **relativa**: `tolAbs = tolRel · max(1, |v(N)|)`. Su ricavi dell'ordine di
10⁴ € una soglia assoluta `1e-7` (come quella del Nucleolo) starebbe sotto il rumore
numerico dei solver.

### 7.7 Verifiche disponibili

- `opts.validateDense = true` (solo `n ≤ 12`): rienumera tutte le coalizioni con
  `cer_coalition_values` e verifica che il surplus minimo **reale** coincida con il `θ_LC`
  trovato dalla row-generation — cioè che nessuna coalizione vincolante sia stata saltata.
- `assert` in `MAIN.m` §3e: `VLC.thetaLC == Nu.thetaMin` (vedi §7.2).
- Efficienza: `Σ x_i = v(N)`.
- `VLC.iterLC` / `VLC.iterVLC` / `size(VLC.coalitions,1)`: le grandezze della Fig. 3 del
  paper, utili per documentare la scalabilità.

**Requisito:** Optimization Toolbox (`linprog`, `quadprog`, `intlinprog`).

---

### Riferimenti
- M. Moncecchi, S. Meneghello, M. Merlo, *A Game Theoretic Approach for Energy Sharing
  in the Italian Renewable Energy Communities*, Appl. Sci. 2020, 10(22), 8166. — Shapley (eq. 39).
- D. Fioriti, A. Frangioni, D. Poli, *Optimal sizing of energy communities with fair
  revenue sharing and exit clauses*, Appl. Energy 299 (2021) 117328. — Nucleolo (eq. 7).
- T. Ferrucci, D. Fioriti, D. Poli, *Reward allocation in Energy Communities by size,
  composition and prosumers penetration*, IEEE PES ISGT Europe 2025. — Variance Least Core
  e row-generation (eq. 12–17).
- D. Fioriti, G. Bigi, A. Frangioni, M. Passacantando, D. Poli, *Fair least core: efficient,
  stable and unique game-theoretic reward allocation in energy communities by row-generation*,
  IEEE Trans. Energy Markets Policy Regul., 2024.
- L. S. Shapley, *The value of an n-person game*, 1953.
- D. Schmeidler, *The Nucleolus of a characteristic function game*, SIAM J. Appl. Math, 1969.
