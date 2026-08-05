# Guida ai modelli di distribuzione dei benefici CER

Questo documento spiega **cosa** è stato implementato, **come** e soprattutto **perché**
sono state fatte determinate scelte, con particolare attenzione alla matematica.
Riguarda i nove metodi di ripartizione dei ricavi della comunità energetica:

1. **Shapley value** — Moncecchi et al., *Appl. Sci.* 2020 (eq. 39)
2. **Nucleolo** — Fioriti et al., *Appl. Energy* 2021 (eq. 7)
3. **Nash Bargaining** — Yan et al., *Int. J. Electr. Power Energy Syst.* 152 (2023) 109218
4. **Variance Least Core** — Ferrucci, Fioriti, Poli, IEEE PES ISGT Europe 2025
5. **Equal Split** — benchmark elementare, ripartizione paritaria
6. **Proportional to Consumption** — benchmark elementare, proporzionale al consumo
   nelle ore utili
7. **Remuneration Model 1** — Candela, Di Silvestre, Gallo, Riva Sanseverino, Sciumè,
   Zizzo, IEEE BLORIN 2022
8. **Cascading Tree** — Trevisan, Ghiani, Pilo, *Economic Benefits Redistribution
   Methodology for Renewable Energy Communities*, 2022
9. **Weighted Solidarity** — Marrasso, Martone, Perugini, Roselli, J. Phys.: Conf. Ser.
   3143 (2025) 012113

> **Nota:** le sezioni 2 e 3 sotto trattano in dettaglio Shapley e Nucleolo; il Nash
> Bargaining è documentato nel codice ([`nash_bargaining_cer.m`](nash_bargaining_cer.m), che ne
> spiega per esteso derivazione e adattamento al gioco CER) più che in questa guida — non ha
> ancora una sezione matematica dedicata qui. Il Variance Least Core ha invece la sua sezione
> completa (§7). Equal Split e Proportional to Consumption, essendo regole elementari senza
> apparato di teoria dei giochi, sono documentati per esteso nelle sezioni §8 e §9. I tre
> metodi dalla letteratura sulle REC italiane (Remuneration Model 1, Cascading Tree,
> Weighted Solidarity) hanno le loro sezioni complete §10-§12, allo stesso livello di
> dettaglio del Variance Least Core, data la loro complessità.

---

## 0. Architettura dei file

| File | Ruolo |
|------|-------|
| [`cer_coalition_values.m`](cer_coalition_values.m) | Costruisce la **funzione caratteristica** `v(S)`, condivisa da tutti i metodi |
| [`shapley_cer.m`](shapley_cer.m) | Calcola lo **Shapley value** dalla `v(S)` |
| [`nucleolus_cer.m`](nucleolus_cer.m) | Calcola il **Nucleolo** dalla `v(S)` (LP sequenziali) |
| [`nash_bargaining_cer.m`](nash_bargaining_cer.m) | Calcola il **Nash Bargaining** dalla `v(S)` (forma chiusa) |
| [`variance_least_core_cer.m`](variance_least_core_cer.m) | Calcola il **Variance Least Core** per **row-generation**, valutando `v(K)` su richiesta |
| [`equal_split_cer.m`](equal_split_cer.m) | Calcola l'**Equal Split**: `v(N)` diviso in parti uguali tra gli utenti |
| [`proportional_consumption_cer.m`](proportional_consumption_cer.m) | Calcola il **Proportional to Consumption**: `v(N)` diviso in base al consumo nelle ore utili |
| [`remuneration_model1_cer.m`](remuneration_model1_cer.m) | Calcola il **Remuneration Model 1**: split α/β tra classe consumatori e classe produttori/prosumer, pesato sulla potenza contrattuale |
| [`cascading_tree_cer.m`](cascading_tree_cer.m) | Calcola il **Cascading Tree**: `v(N)` scomposto ricorsivamente in un albero di categorie |
| [`weighted_solidarity_cer.m`](weighted_solidarity_cer.m) | Calcola il **Weighted Solidarity**: peso tecnico+solidarietà, coefficienti scelti su fronte di Pareto |
| [`MAIN.m`](MAIN.m) | Sezioni `3b` (Shapley), `3c` (Nucleolo), `3d` (Nash), `3e` (VLC), `3f` (Equal Split), `3g` (Proportional to Consumption), `3h` (Remuneration Model 1), `3i` (Cascading Tree), `3j` (Weighted Solidarity), `3k` (confronto) |

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
7. **Due benchmark ingenui, Equal Split e Proportional to Consumption** (§8-§9) →
   nessuna teoria dei giochi, solo regole elementari (parti uguali / proporzionale al
   consumo nelle ore utili), per misurare quanto i modelli 1-4 se ne discostino.
8. **Tre modelli dalla letteratura sulle REC italiane, Remuneration Model 1, Cascading
   Tree, Weighted Solidarity** (§10-§12) → regole di ripartizione realmente proposte in
   pubblicazioni recenti (2022-2025) per comunità energetiche italiane, che introducono
   criteri assenti negli altri metodi: potenza contrattuale/nominale, decomposizione
   gerarchica in categorie, equità sociale (povertà energetica).

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

## 8. Equal Split

File: [`equal_split_cer.m`](equal_split_cer.m).

### 8.1 Il concetto

Il benchmark più semplice possibile: il totale da distribuire viene diviso in **parti
uguali** tra tutti gli `n` giocatori, senza guardare a chi ha prodotto o consumato
cosa.

```
φ_i = v(N) / n     per ogni giocatore i
```

dove `v(N)` è lo stesso valore della grande coalizione usato da tutti gli altri
metodi (§1.2):

```
v(N) = Σ_t min( Σ_i gen_i(t), Σ_i load_i(t) ) · P_CER(t)
```

### 8.2 A cosa serve

Non essendo un gioco cooperativo (non usa il contributo marginale né la stabilità),
l'Equal Split non ha assiomi da rispettare — l'unica proprietà che condivide con gli
altri metodi è l'**efficienza** (`Σ_i φ_i = v(N)`). Serve come **termine di paragone
ingenuo**: quanto si discostano Shapley/Nucleolo/Nash/VLC da una ripartizione
paritaria? Nel caso reale (§5), ad esempio, ci si aspetta che il prosumer riceva
*più* dell'Equal Split con Shapley (premia il contributo marginale, molto alto per
chi produce) e che i grandi consumatori restino vicini all'Equal Split o sopra con il
Nucleolo (che li protegge in quanto coalizione "scontenta").

### 8.3 Mappatura formula → codice

```matlab
vGrand = sum(min(sum(genUsers, 2), sum(loadUsers, 2)) .* P_CER(:));
phi    = repmat(vGrand / n, n, 1);
```

**Nota implementativa:** a differenza di Shapley/Nucleolo, `equal_split_cer.m` non
passa da [`cer_coalition_values.m`](cer_coalition_values.m) (che costruisce `2^n`
valori): calcola `v(N)` **direttamente** con la stessa formula, perché non serve
nessun'altra coalizione. Stessa scelta per il Proportional to Consumption (§9) — è
ciò che rende questi due metodi utilizzabili anche su comunità grandi, come il VLC ma
senza bisogno della row-generation.

---

## 9. Proportional to Consumption

File: [`proportional_consumption_cer.m`](proportional_consumption_cer.m).

### 9.1 Il concetto

Secondo benchmark elementare: la quota di ciascun utente è proporzionale al suo
**consumo nelle ore in cui la comunità genera benefici economici**, cioè le ore in
cui l'energia condivisa aggregata è positiva.

Definiamo l'insieme delle **ore utili**:

```
sharedHour(t) = 1  se  min( Σ_i gen_i(t), Σ_i load_i(t) ) > 0
                0  altrimenti
```

Per ogni giocatore `i` si somma il consumo (carico residuo) nelle sole ore utili:

```
cons_i = Σ_{t : sharedHour(t)=1}  load_i(t)
```

e si assegna una quota di `v(N)` pari alla percentuale di consumo dell'utente sul
consumo totale della comunità nelle stesse ore:

```
φ_i = v(N) · cons_i / Σ_j cons_j
```

**Esempio:** se nelle ore utili l'utente 1 consuma il 10% del consumo totale della
comunità, riceve il 10% dell'incentivo CER — indipendentemente da quanto produce o
da quanto la sua presenza sia "necessaria" alla coalizione.

### 9.2 Perché "ore utili" e non tutte le ore

Consumare molto in un'ora in cui la comunità non condivide nulla (`sharedHour = 0`,
o perché non c'è surplus PV o perché il carico residuo aggregato è già nullo) non
genera nessun beneficio economico da ripartire. Pesare il consumo su **tutte** le
8760 ore darebbe peso a consumi che non hanno contribuito in alcun modo all'incentivo
percepito dalla CER; limitarsi alle ore utili mantiene la regola coerente con
l'origine del beneficio che si sta dividendo.

### 9.3 A cosa serve

Come l'Equal Split (§8), non è un gioco cooperativo: non c'è contributo marginale né
nozione di stabilità, e non premia la produzione (un prosumer riceve quota solo per
il proprio consumo residuo nelle ore utili, non per l'eccedenza che genera). È un
secondo termine di paragone ingenuo, complementare all'Equal Split: mentre l'Equal
Split ignora completamente il comportamento dell'utente, il Proportional to
Consumption lo premia in base a **quanto consuma**, non a quanto **produce** — utile
per capire se i modelli di teoria dei giochi tendono a premiare la produzione (come
lo Shapley, §5) rispetto a una regola guidata solo dal consumo.

### 9.4 Mappatura formula → codice

```matlab
genComm    = sum(genUsers,  2);
loadComm   = sum(loadUsers, 2);
sharedHour = min(genComm, loadComm) > 0;

vGrand    = sum(min(genComm, loadComm) .* P_CER(:));
consUser  = sum(loadUsers(sharedHour, :), 1).';   % consumo nelle ore utili, per utente
consTotal = sum(consUser);

phi = vGrand * consUser / consTotal;
```

Se `consTotal = 0` (nessun consumo registrato nelle ore utili — caso degenere, non
osservato nei dati reali del progetto) la funzione solleva un errore esplicito
piuttosto che dividere per zero.

---

## 10. Remuneration Model 1

File: [`remuneration_model1_cer.m`](remuneration_model1_cer.m).

Riferimento: R. Candela, M. L. Di Silvestre, P. Gallo, E. Riva Sanseverino, G. Sciumè,
G. Zizzo, *A Remuneration Model of Energy Community Members in Italy*, IEEE Workshop on
Blockchain for Renewables Integration (BLORIN), 2022.

### 10.1 Il concetto

A differenza dei metodi 1-6, questo modello introduce un ingrediente nuovo: la
**potenza** [kW] di ciascun utente (non derivabile dai profili orari — dato esterno,
vedi §10.5). L'incentivo orario si divide in due quote:

```
B_REC(t) = ES(t) · P_CER(t)                      (stesso incentivo v(S) degli altri metodi)

B_i(t) = alpha · B_REC(t) · E_i(t) / Σ_i E_i(t)   per ogni CONSUMATORE i
B_y(t) = beta  · B_REC(t) · E_y(t) / Σ_y E_y(t)   per ogni PRODUTTORE/PROSUMER y

alpha = Σ Prt_consumatori / (Σ Prt_consumatori + Σ Prt_produttori)
beta  = Σ Prt_produttori  / (Σ Prt_consumatori + Σ Prt_produttori)
```

dove `E_i(t)` è il prelievo orario del consumatore (carico residuo, `loadUsers`) ed
`E_y(t)` è l'immissione oraria del produttore (eccedenza, `genUsers`). Un **prosumer**
(ha sia carico sia produzione) riceve la **somma** di `B_i(t)` e `B_y(t)`: partecipa a
entrambe le quote.

### 10.2 Chi è "consumatore" e chi è "produttore/prosumer"

Il paper distingue tre classi (Produttore puro, Prosumer, Consumatore puro). Nel
progetto la classificazione è derivata dai dati, non da un'etichetta esterna, con la
stessa logica di `isProsumer` usata da tutti gli altri metodi:

```
consumerMask = any(loadUsers > 0, 1)     % ha carico residuo in almeno un'ora
producerMask = any(genUsers  > 0, 1)     % ha eccedenza in almeno un'ora (= isProsumer)
```

Un utente con entrambe le maschere vere è un prosumer e riceve entrambe le quote; con
la configurazione attuale (un solo impianto, di proprietà di un utente che ha anche
carico) non esiste un "produttore puro" nel senso stretto del paper, ma il codice
gestisce comunque il caso generale.

### 10.3 Due potenze distinte, non una

Il paper usa sui due lati **grandezze fisiche diverse**: `Prt` lato consumo è la
*potenza impegnata in prelievo* (quanto puoi tirare dalla rete, es. 3 kW domestici),
`Prt` lato produzione è la *potenza nominale dell'impianto* (kWp installati). Un
prosumer le ha **entrambe** e sono numeri diversi.

L'implementazione le tiene separate:

| Grandezza | Dove è dichiarata | Perché lì |
|---|---|---|
| Potenza di prelievo `ratedLoadKW` [kW] | `RATED_LOAD_KW` in `MAIN.m` §0 | è una caratteristica del contratto dell'**utente** |
| Potenza di generazione `ratedGenKW` [kWp] | campo `.kWp` di `pvPlants` in `MAIN.m` §0 | appartiene all'**impianto**, non alla persona |

Derivare la potenza di generazione dagli impianti (invece che da una seconda tabella per
utente) ha tre vantaggi: è **impossibile** dichiarare potenza di generazione a chi non ha
impianti; chi ne possiede più di uno somma automaticamente le taglie; e la cosa regge da
sola quando gli impianti diventano molti, senza tabelle parallele da tenere allineate.

**Perché non basta una potenza sola:** vedi §10.6 — usare un unico valore per entrambi i
lati sposta di quasi il doppio la quota destinata alla produzione.

### 10.4 Mappatura formula → codice

```matlab
genComm=sum(genUsers,2); loadComm=sum(loadUsers,2); ES=min(genComm,loadComm);
B_REC = ES .* P_CER;                      vGrand = sum(B_REC);

consumerMask = any(loadUsers>0,1).';      producerMask = any(genUsers>0,1).';
sumPrtCons = sum(ratedLoadKW(consumerMask));    % potenza di PRELIEVO
sumPrtProd = sum(ratedGenKW(producerMask));     % potenza di GENERAZIONE
alpha = sumPrtCons / (sumPrtCons + sumPrtProd);
beta  = sumPrtProd / (sumPrtCons + sumPrtProd);

hrsL = loadComm>0; shareCons = zeros(H,n); shareCons(hrsL,:) = loadUsers(hrsL,:)./loadComm(hrsL);
hrsG = genComm>0;  shareProd = zeros(H,n); shareProd(hrsG,:) = genUsers(hrsG,:)./genComm(hrsG);

phi = sum(alpha*B_REC.*shareCons + beta*B_REC.*shareProd, 1).';   % prosumer = somma dei due termini
```

Le maschere filtrano anche i denominatori: la potenza di chi non concorre a un lato non
vi entra. Un impianto che non immette **mai** nella CER non deve gonfiare `beta`, perché
poi la sua quota finirebbe agli altri produttori. Se un utente immette energia ma ha
`.kWp` nullo (configurazione incoerente) la funzione emette un warning esplicito, invece
di sottostimare `beta` in silenzio.

L'efficienza (`Σφ = v(N)`) vale per costruzione senza normalizzazioni aggiuntive: ogni
volta che `B_REC(t) > 0`, sia `hrsL(t)` sia `hrsG(t)` sono vere (perché `ES(t) =
min(genComm,loadComm) > 0` richiede entrambe positive), quindi le due quote sommano
sempre a `(alpha+beta)·B_REC(t) = B_REC(t)`.

### 10.5 I dati esterni richiesti

Nessuna delle due potenze è derivabile dai profili orari: sono dati esterni, oggi
entrambi **TODO/placeholder** da confermare (vedi README.md §11).

```matlab
% MAIN.m §0 - potenza impegnata in PRELIEVO, per utente [kW]
RATED_LOAD_KW = containers.Map( ...
    {'office_1_kWh', 'small_industry_1_kWh', ...}, {10, 50, ...});

% MAIN.m §0 - potenza nominale di GENERAZIONE, per impianto [kWp]
pvPlants = struct('file', {pvFile}, 'owner', {"small_industry_1_kWh"}, 'kWp', {20});
```

In `MAIN.m` §3h la potenza di generazione per utente si ricava sommando i `.kWp` degli
impianti di cui è proprietario (0 per chi non ne ha).

> **Scalabilità:** `RATED_LOAD_KW` ha una voce per utente e non regge a comunità grandi;
> le alternative (tabella per archetipo, oppure derivazione dal picco di carico) sono
> discusse in README §13.3.

### 10.6 Perché due potenze e non una: l'impatto numerico

Tenere separate le due grandezze **non è un dettaglio formale**. Se si usasse un unico
valore per utente (i 50 kW di `small_industry_1`) su entrambi i lati, gli stessi 50 kW
verrebbero conteggiati due volte e si otterrebbe:

```
sumPrtCons = 10+50+15+3+3+3 = 84     (include i 50 kW del prosumer)
sumPrtProd = 50                       (gli stessi 50 kW, riconteggiati)
α = 84/134 = 0.627      β = 50/134 = 0.373
```

Con le potenze corrette (prelievo 50 kW, generazione 20 kWp) si ha invece:

```
sumPrtCons = 84 kW       sumPrtProd = 20 kWp
α = 84/104 = 0.808      β = 20/104 = 0.192
```

La quota destinata al lato produzione passa da **37,3% a 19,2%**: quasi un dimezzamento.
Sui dati del progetto l'effetto sulle singole quote annue è questo:

| Giocatore | Potenza unica (β=0.373) | Potenze separate (β=0.192) | Δ |
|---|---:|---:|---:|
| small_industry_1 (prosumer) | 876,34 € | **451,65 €** | −48% |
| office_1 | 557,46 € | 718,27 € | +29% |
| retail_1 | 544,68 € | 701,80 € | +29% |
| household_1 / 2 / 3 | ~123 € | ~159 € | +29% |

Il prosumer perde metà della propria quota, che si redistribuisce agli altri cinque
membri. È il motivo per cui la distinzione tra potenza di prelievo e potenza di
generazione va trattata come **scelta di modello**, non come dettaglio di
configurazione — e per cui i due TODO (`RATED_LOAD_KW`, `pvPlants(.kWp)`) vanno
confermati con dati reali prima di portare in tesi i numeri di questo metodo.

---

## 11. Cascading Tree

File: [`cascading_tree_cer.m`](cascading_tree_cer.m).

Riferimento: R. Trevisan, E. Ghiani, F. Pilo, *Economic Benefits Redistribution
Methodology for Renewable Energy Communities*, 2022 (eq. 1-9, Fig. 1).

### 11.1 Il concetto: decomposizione ad albero

L'incentivo totale della comunità `q1` (= `v(N)`) si scompone ricorsivamente in
categorie, ciascuna una frazione della categoria padre (Fig. 1 del paper):

```
q1 "incentivo totale"
├─ q2 "riserve"            (NON redistribuita, trattenuta dalla REC)  peso p1,2
└─ q3 "da redistribuire"                                              peso p1,3 = 1-p1,2
   ├─ q4 "fissa"           (uguale per TUTTI gli utenti)              peso p3,4
   └─ q5 "variabile"                                                  peso p3,5 = 1-p3,4
      ├─ q6 "prelievi"     (proporzionale al carico annuo)            peso p5,6
      └─ q7 "immissione"                                              peso p5,7 = 1-p5,6
         ├─ q8 "produttori+prosumer"  (proporzionale all'immissione)  peso p7,8
         └─ q9 "soli prosumer"        (solo chi ha ANCHE carico)      peso p7,9 = 1-p7,8
```

`φ_i` = somma delle quote di foglia (q4, q6, q8, q9) a cui l'utente `i` partecipa.

### 11.2 Semplificazione "annuale" (dal paper stesso)

Le quote di prelievo (`w_i`) e immissione (`i_i`, `ip_i`) usano il peso **annuo**
(energia totale dell'anno), non un ricalcolo ora per ora — è la stessa semplificazione
esplicitamente adottata dal paper ("for a matter of simplicity... coefficients computed
over a year"). Il metodo non ha quindi bisogno di un ciclo sulle 8760 ore: solo
aggregati.

### 11.3 I pesi di ramo sono scelte di GOVERNANCE, non dati

A differenza di tutti gli altri parametri di questa guida, i pesi `p_f,i` **non sono
derivabili dai dati energetici**: nel paper sono decisioni interne della REC (quanto
accantonare, quanto premiare la sola iscrizione vs. il merito, quanto proteggere i
piccoli prosumer). Il codice li espone come `opts` con default ragionati:

| campo | default | perché |
|---|---|---|
| `reservoirFraction` (p1,2) | 0 | Obbligatorio per `Σφ = v(N)` e comparabilità con gli altri 8 metodi in `Tcmp`. |
| `fixedFraction` (p3,4) | 0.3 | Un 50/50 duplicherebbe funzionalmente l'Equal Split (§8) già presente come benchmark a sé; 30% mantiene una base solidale senza appiattirsi su di esso. |
| `withdrawalsFraction` (p5,6) | 0.5 | Nessuna guida dal paper; prelievo e immissione sono ugualmente necessari perché esista energia condivisa, peso paritario è la scelta meno arbitraria. |
| `prosumersOnlyFraction` (p7,9) | 0.6 | Protegge i piccoli prosumer da un eventuale grande produttore puro (motivazione esplicita del paper), senza azzerarne quasi del tutto la quota. |

### 11.4 Perché `vGrand` non è sempre `v(N)`

`S.vGrand = q3` (quanto **effettivamente** redistribuito), non `q1` (il montepremi
totale). Con `reservoirFraction = 0` (default) `q3 == q1` e il metodo resta
confrontabile con gli altri 8 in `Tcmp`; con una riserva positiva, `vGrand` sarebbe
legittimamente più piccolo — per costruzione, non per errore.

### 11.5 Mappatura formula → codice

```matlab
q1 = sum(min(genComm,loadComm) .* P_CER);
q2 = reservoirFraction*q1;   q3 = q1-q2;
q4 = fixedFraction*q3;       q5 = q3-q4;
q6 = withdrawalsFraction*q5; q7 = q5-q6;
q9 = prosumersOnlyFraction*q7; q8 = q7-q9;

fixedShare    = repmat(q4/n, n, 1);
withdrawShare = q6 * (sum(loadUsers,1)/sum(loadUsers,'all')).';
feedInGeneral = q8 * (sum(genUsers,1)/sum(genUsers,'all')).';

isProsumerStrict = any(genUsers>0,1).' & any(loadUsers>0,1).';   % "vero" prosumer
prosumersOnly = q9 * ip;   % ip: quota di immissione tra i soli isProsumerStrict

phi = fixedShare + withdrawShare + feedInGeneral + prosumersOnly;
```

**Fallback:** se nessun utente è un "vero prosumer" quell'anno (nessuno ha sia
generazione sia carico), la pool `q9` si assorbe in `q8` invece di dividere per zero
(`S.prosumersOnlyFolded = true`).

---

## 12. Weighted Solidarity

File: [`weighted_solidarity_cer.m`](weighted_solidarity_cer.m).

Riferimento: E. Marrasso, C. Martone, I. Perugini, C. Roselli, *Towards a fair revenue
distribution of a Renewable Energy Community through a proportional energy consumption
model application*, J. Phys.: Conf. Ser. 3143 (2025) 012113 (eq. 2.1-2.8, §3.2).

### 12.1 Il concetto: peso tecnico + peso di solidarietà

Ogni ora, l'incentivo `G_REC(t) = ES(t)·(P_CER(t)+V)` (con `V` tariffa cost-reflective
aggiuntiva, di default `0` per restare confrontabile con `v(N)` degli altri metodi) si
ripartisce in proporzione a un peso `omega_i(t)`:

```
G_i(t) = [omega_i(t) / Σ_j omega_j(t)] · G_REC(t)
omega_i(t) = beta1 · B1_i(t) + beta2 · B2_i

B1_i(t) = alpha1 · E_SH_i(t) + alpha2 · E_load_i(t)     (componente TECNICA)
B2_i ∈ {1, 3, 5}                                        (componente di SOLIDARIETÀ)
```

`E_SH_i(t)` (energia condivisa dell'utente `i`, eq. 2.2-2.3) si calcola così: se la
produzione di comunità copre l'intero carico residuo di comunità, ogni utente riceve
la sua energia condivisa pari al proprio carico residuo; altrimenti la quota (più
piccola) di energia condivisa si divide in proporzione al carico residuo di ciascuno —
la stessa logica del Proportional to Consumption (§9), ma calcolata **ora per ora**
invece che su base annua.

`B2_i` è un punteggio a scalini sui **quartili** del costo unitario dell'energia
`Cu_i` [EUR/kWh] (proxy di povertà energetica, in assenza di dati di bolletta reali):
`Cu_i < Q1 → 1`, `Q1 ≤ Cu_i < mediana → 3`, `Cu_i ≥ mediana → 5`.

### 12.2 Da dove viene `Cu_i`

Il progetto non ha dati di bolletta reali (l'ISEE usato nel paper, o anche solo il
`Tcost` di `MAIN.m` §4, richiederebbero dati esterni o un ordine di calcolo diverso).
`weighted_solidarity_cer.m` deriva `Cu_i` **internamente**, chiamando
[`profilo_prezzi_pun_2025.m`](profilo_prezzi_pun_2025.m) (la stessa tariffa PUN usata
in `MAIN.m` §4) sullo **stesso** `loadUsers` ricevuto in ingresso — funzione pura,
nessun accesso nascosto a variabili di `MAIN.m`:

```
Cu_i = Σ_t price(t)·loadUsers(t,i)  /  Σ_t loadUsers(t,i)
```

Con `opts.tariffMode` di default `"MONORARIA"` (prezzo piatto), `Cu_i` **non dipende**
dal fatto che `loadUsers` passato sia il carico lordo o quello residuo netto da
autoconsumo (il prezzo costante si semplifica nel rapporto costo/kWh). Con
`"BIORARIA"`/`"ORARIO_VARIABILE"` questa invarianza non vale più: per i prosumer,
l'autoconsumo rimuove preferenzialmente le ore diurne (fascia F1, più cara), quindi
`Cu_i` calcolato sul carico residuo tende a risultare **più basso** del costo medio
reale (`Tcost` di `MAIN.m` §4, che usa il carico lordo) — scelta di design dichiarata,
non un bug, ed è il motivo per cui il default resta `"MONORARIA"`.

### 12.3 La scelta dei coefficienti: fronte di Pareto

I quattro coefficienti (`alpha1, alpha2, beta1, beta2`) non sono fissati: si esplora
una griglia (default: stessi range/step del paper, `alpha1,alpha2 ∈ [1,30]` passo 5,
`beta1,beta2 ∈ [1,10]` passo 1 → 3.600 combinazioni), e per ognuna si calcola:

- l'**indice di Gini** (eq. 2.8) della ripartizione annua risultante;
- il **reddito medio** degli utenti "potenzialmente in povertà energetica"
  (`isPotentialEP = Cu_i > mediana(Cu)` — classificazione **diversa** da `B2`, usata
  solo per questo obiettivo).

Si scartano le combinazioni **dominate** (fronte di Pareto: minimizzare Gini e
massimizzare il reddito EP sono obiettivi in conflitto) e si sceglie quella a distanza
euclidea minima dal **punto Utopia** (il migliore dei due mondi, ipotetico: Gini minimo
osservato e reddito EP massimo osservato, non necessariamente sullo stesso punto).

**Nota su normalizzazione.** `opts.normalizeObjectives = true` (default) normalizza
entrambi gli obiettivi a `[0,1]` prima di calcolare la distanza: senza normalizzare, la
scala in EUR (centinaia/migliaia) domina completamente la scala del Gini
(adimensionale, `[0,1]`), e la selezione finirebbe per ignorare quasi del tutto
l'equità. `opts.normalizeObjectives = false` riproduce letteralmente la Fig. 3 del
paper (distanza euclidea grezza).

### 12.4 Perché `beta1`/`beta2` devono essere strettamente positivi

`omega_i(t) = beta1·B1_i(t) + beta2·B2_i` deve restare **sempre positivo** per evitare
una divisione 0/0 nel calcolo della quota oraria. Poiché `B2_i ∈ {1,3,5}` (mai zero),
basta che `beta1,beta2 > 0` — la funzione valida esplicitamente questo vincolo sulle
griglie fornite ed è per questo che i range di default partono da 1, non da 0.

### 12.5 Vettorizzazione della ricerca su griglia

La ricerca NON usa un ciclo annidato su tutte le 3.600 combinazioni × 8760 ore (troppo
lento): per ciascuna delle 36 coppie `(alpha1,alpha2)` — unico ciclo esplicito — le 100
coppie `(beta1,beta2)` si valutano **in un colpo solo** via broadcasting 4-D
(`reshape`/espansione implicita su `[H, n, nbeta1, nbeta2]`), sfruttando il fatto che
`B1_i(t)` non dipende da `beta1`/`beta2` e va quindi ricalcolato solo 36 volte, non
3.600. Nessun toolbox aggiuntivo richiesto (niente Optimization/Statistics Toolbox: i
quartili si calcolano con `sort`/`median` di base).

### 12.6 Mappatura formula → codice (sintesi)

```matlab
covered = genComm >= loadComm;
ESH(covered,:) = loadUsers(covered,:);
ESH(~covered & loadComm>0, :) = loadUsers(...)./loadComm(...) .* ES(...);   % eq. 2.2-2.3

Cu = sum(price.*loadUsers,1).' ./ sum(loadUsers,1).';    % costo unitario per utente
[Q1, med] = local_tukey_quartiles(Cu);                    % senza Statistics Toolbox
B2 = ones(n,1); B2(Cu>=Q1 & Cu<med)=3; B2(Cu>=med)=5;
isPotentialEP = Cu > med;

for ia1 = 1:numel(a1)
  for ia2 = 1:numel(a2)
    B1 = a1(ia1)*ESH + a2(ia2)*loadUsers;
    omega = reshape(b1,1,1,[]).*reshape(B1,H,n,1) + reshape(b2,1,1,1,[]).*reshape(B2.',1,n,1,1);
    phiBlock = squeeze(sum(omega./sum(omega,2) .* GREC, 1));   % [n x nb1 x nb2]
  end
end

gini = arrayfun(@(c) local_gini(phiAll(:,c)), 1:nCombos);
% dominanza di Pareto, punto Utopia, distanza -> combinazione vincente -> phi finale
```

**Requisito:** nessuno (solo MATLAB base — niente Optimization/Statistics Toolbox).

### 12.7 Limiti noti e scostamenti dal paper (IMPORTANTE)

Tre osservazioni emerse dalla verifica dell'implementazione contro il paper. La prima è
una **limitazione sostanziale dei dati**, non del codice, e va tenuta presente prima di
usare i risultati di questo metodo in tesi.

**(a) `Cu` come proxy di povertà energetica è molto più debole che nel paper.**
Nel paper, `Cu` viene letto dalle **bollette reali** dei membri (Tabella 1) e include
imposte, IVA e quote fisse: i valori vanno da **14,8 a 59,6 c€/kWh**, con un rapporto
max/min di circa **4×**, e riflettono differenze reali di contratto (mercato libero vs
maggior tutela), di fiscalità e di potenza impegnata. Nel nostro progetto quei dati non
esistono, e `Cu` viene derivato dallo stesso profilo prezzi PUN per tutti: i valori
risultanti stanno tra **0,11498 e 0,11827 €/kWh**, con uno spread di appena il **2,9%**,
generato solo da come ciascun utente distribuisce i consumi tra i mesi.

Conseguenza: la classificazione in `B2 ∈ {1,3,5}` e in `isPotentialEP` resta ben
definita e riproducibile, ma **non misura vulnerabilità economica** — misura la
collocazione temporale dei consumi rispetto a un prezzo all'ingrosso. Il ranking è
sensibile a differenze dell'ordine dell'1%, quindi poco robusto. Per un uso serio della
componente solidaristica servirebbero dati di bolletta (o ISEE) reali per utente.

**(b) La componente `B2` domina numericamente la componente tecnica `B1`.**
`B1` è in kWh (grandezza fisica, ~0,3-1 kWh/ora per utente domestico), mentre `B2` è un
punteggio adimensionale in `{1,3,5}`: con la combinazione vincente sui dati attuali
(`α1=1, α2=1, β1=1, β2=4`) il termine `β2·B2` vale 4-20 contro un `β1·B1` inferiore a 1,
cioè è **7-30 volte più grande**. La ripartizione finisce per essere quasi interamente
determinata da `B2`: nell'esecuzione di riferimento `household_1` e `household_3`
(`B2=5`) ricevono ~483 € ciascuno contro i ~114 € di `household_2` (`B2=1`), un rapporto
di 4,2 contro un rapporto di punteggio di 5. Questo squilibrio è **intrinseco alla
formulazione del paper** (che somma una grandezza fisica e un punteggio senza
normalizzarle), non un errore di implementazione — nel paper stesso l'ottimo ha
`β2 = 9·β1`. Va però tenuto presente che il peso relativo dei due termini dipende
dall'ordine di grandezza dei kWh orari, quindi dalla taglia della comunità.

**(c) Due incongruenze interne al paper, gestite esplicitamente.**
- *Range dei coefficienti:* il paper dichiara `α1,α2 ∈ [1,30]` passo 5 e afferma di aver
  valutato **2500** combinazioni (che però non corrisponde a 6×6×10×10 = 3600), ma poi
  in Tabella 3 riporta come ottimi `α2 = 31, 41, 46` — valori **fuori** dal range
  dichiarato. L'implementazione segue il range **dichiarato** (3600 combinazioni); i
  range sono comunque configurabili via `opts` se si vuole esplorare più in là.
- *Formula del Gini:* l'eq. 2.8 come stampata ha a denominatore `n·Σ_{i=1}^N i` invece
  di `n·Σ_i G_i`, il che renderebbe l'indice dipendente dalla scala assoluta dei redditi
  (e quindi non un indice di disuguaglianza). È con ogni evidenza un refuso:
  l'implementazione usa la **formula standard** di Farris (2010), citata dal paper
  stesso come riferimento [24], verificata sui due casi limite (uguaglianza perfetta →
  0; massima concentrazione → `(N-1)/N`).

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
- R. Candela, M. L. Di Silvestre, P. Gallo, E. Riva Sanseverino, G. Sciumè, G. Zizzo,
  *A Remuneration Model of Energy Community Members in Italy*, IEEE Workshop on
  Blockchain for Renewables Integration (BLORIN), 2022. — Remuneration Model 1.
- R. Trevisan, E. Ghiani, F. Pilo, *Economic Benefits Redistribution Methodology for
  Renewable Energy Communities*, 2022. — Cascading Tree (eq. 1-9).
- E. Marrasso, C. Martone, I. Perugini, C. Roselli, *Towards a fair revenue
  distribution of a Renewable Energy Community through a proportional energy
  consumption model application*, J. Phys.: Conf. Ser. 3143 (2025) 012113. — Weighted
  Solidarity (eq. 2.1-2.8).
