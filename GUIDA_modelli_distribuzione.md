# Guida ai modelli di distribuzione dei benefici CER

Questo documento spiega **cosa** è stato implementato, **come** e soprattutto **perché**
sono state fatte determinate scelte, con particolare attenzione alla matematica.
Riguarda i due metodi di ripartizione dei ricavi della comunità energetica:

1. **Shapley value** — Moncecchi et al., *Appl. Sci.* 2020 (eq. 39)
2. **Nucleolo** — Fioriti et al., *Appl. Energy* 2021 (eq. 7)

---

## 0. Architettura dei file

| File | Ruolo |
|------|-------|
| [`cer_coalition_values.m`](cer_coalition_values.m) | Costruisce la **funzione caratteristica** `v(S)`, condivisa da tutti i metodi |
| [`shapley_cer.m`](shapley_cer.m) | Calcola lo **Shapley value** dalla `v(S)` |
| [`nucleolus_cer.m`](nucleolus_cer.m) | Calcola il **Nucleolo** dalla `v(S)` (LP sequenziali) |
| [`MAIN.m`](MAIN.m) | Sezioni `3b` (Shapley) e `3c` (Nucleolo + confronto) |

**Scelta di design fondamentale.** I due metodi *non* ricalcolano l'energia condivisa
ciascuno per conto suo: entrambi partono dallo **stesso** vettore `v(S)` prodotto da
[`cer_coalition_values.m`](cer_coalition_values.m). Questo garantisce che Shapley e
Nucleolo siano **matematicamente confrontabili** (giocano lo stesso identico gioco) —
esattamente l'impostazione con cui Fioriti li mette a confronto nelle Fig. 9–10.

---

## 1. Il gioco cooperativo

Un gioco cooperativo a utilità trasferibile (TU-game) è una coppia `(N, v)`:

- `N` = insieme dei **giocatori**;
- `v : 2^N → ℝ` = **funzione caratteristica**, che a ogni coalizione `S ⊆ N`
  associa il valore `v(S)` che quella coalizione sa generare da sola.

### 1.1 I giocatori

```
N = { PV, office_1, small_industry_1, retail_1, household_1, household_2, household_3 }
     └─ produttore ─┘ └──────────────────── 6 consumatori ─────────────────────────┘
n = |N| = 7
```

Il PV è un **giocatore a sé** (scelta concordata): senza di lui non c'è generazione,
quindi nessuna condivisione. Questo è lo schema "produttore vs consumatori" del paper
di Moncecchi (Sez. 5.2).

### 1.2 La funzione caratteristica `v(S)`

Definita in [`cer_coalition_values.m`](cer_coalition_values.m):

```
v(S) = 0                                         se  PV ∉ S
v(S) = Σ_t  min( genPV(t),  load_S(t) ) · P_CER  se  PV ∈ S
```

dove `load_S(t) = Σ_{i ∈ S∩consumatori} load_i(t)` è il carico orario dei soli
consumatori presenti in `S`, e `P_CER` è l'incentivo €/kWh sull'energia condivisa.

**Perché questa `v` e non quella (più complessa) di Fioriti.** Il paper di Fioriti
definisce `v(J) = SẄ_tot(J) − SW_NC(J)` (costo-opportunità rispetto al caso
non-cooperativo), che richiede tutta la sua macchina MILP (aggregatore, batterie,
peak power, configurazioni NA/NC/ANC/CO). Noi **non** importiamo quel framework:
prendiamo solo la *regola di allocazione* (Shapley, Nucleolo) e la applichiamo alla
nostra `v` semplice. Questo è coerente con la scelta fatta in precedenza
(distribuire **solo l'incentivo sull'energia condivisa**) e mantiene i risultati
allineati a `rev_shared` già calcolato in [`MAIN.m`](MAIN.m).

**Proprietà utili della nostra `v`:**
- `v(∅) = 0` e `v(S) = 0` per ogni `S` senza PV → il PV è un *null player condizionante*;
- `v` è **monotòna** (aggiungere un consumatore non può ridurre l'energia condivisa);
- il valore della grande coalizione `v(N) = Σ_t min(genPV, load_tot)·P_CER`
  coincide *per costruzione* con il ricavo annuo da energia condivisa. In
  [`MAIN.m`](MAIN.m#L180) c'è un `assert` che lo verifica.

### 1.3 La codifica a bitmask (ponte matematica ↔ codice)

Le coalizioni sono `2^n`. Le indicizziamo con un intero `m ∈ {0, …, 2^n−1}` letto in binario:

```
bit 1 (peso 1)  →  PV
bit k+1         →  consumatore k
```

Esempio con `n = 7`: `m = 0b0000101 = 5` ⇒ coalizione `{PV, consumatore_2}`.

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

1. **PV come giocatore separato** → schema produttore-vs-consumatori; senza PV `v=0`.
2. **`v(S) = incentivo su energia condivisa**` (non il costo-opportunità MILP di Fioriti)
   → coerenza con `rev_shared` e con la scelta fatta per lo Shapley.
3. **Funzione `v(S)` condivisa** in un unico helper → Shapley e Nucleolo confrontabili.
4. **Shapley esatto, non per gruppi** → possibile perché `n = 7` (128 coalizioni).
5. **Convenzione "profit-game"** (surplus `θ_S = Σx − v(S)`, stabile se `≥ 0`)
   → coerente con la nostra `v` di ricavi.
6. **Terminazione del Nucleolo per rango** (criterio Kohlberg/Maschler) → garantisce
   unicità senza euristiche fragili.

---

### Riferimenti
- M. Moncecchi, S. Meneghello, M. Merlo, *A Game Theoretic Approach for Energy Sharing
  in the Italian Renewable Energy Communities*, Appl. Sci. 2020, 10(22), 8166. — Shapley (eq. 39).
- D. Fioriti, A. Frangioni, D. Poli, *Optimal sizing of energy communities with fair
  revenue sharing and exit clauses*, Appl. Energy 299 (2021) 117328. — Nucleolo (eq. 7).
- L. S. Shapley, *The value of an n-person game*, 1953.
- D. Schmeidler, *The Nucleolus of a characteristic function game*, SIAM J. Appl. Math, 1969.
