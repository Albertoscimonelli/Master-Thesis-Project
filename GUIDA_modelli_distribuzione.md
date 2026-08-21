# Guida ai modelli di distribuzione dei benefici CER

Questo documento spiega **cosa** è stato implementato, **come** e soprattutto **perché**
sono state fatte determinate scelte, con particolare attenzione alla matematica.
Riguarda i quindici metodi di ripartizione dei ricavi della comunità energetica:

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
10. **Pearson Key** — Gianaroli, Ricci, Sdringola, Ancona, Branchini, Melino,
    *Energy & Buildings* 311 (2024) 114158 (metodo M3)
11. **Pearson-Sharing Rate** — stesso paper, metodo M5 (eq. 7), combinazione pesata di
    M3 e M4
12. **Similarity-Utilization** — M. Bilardo, *Renewable Energy* 255 (2025) 123756
13. **Marginal Contribution** — Cremers, Robu, Zhang, Andoni, Norbu, Flynn,
    *Appl. Energy* 331 (2023) 120328 (§4.1.1)
14. **Stratified Expected Value** — stesso paper, §4.1.2 (il metodo nuovo che propone)
15. **Adaptive Sampling Shapley** — O'Brien, El Gamal, Rajagopal, *IEEE Trans. Smart Grid*
    6(6) 2015, nella formulazione dello stesso paper (§4.1.3 e Appendice C)
16. **Tri-level EP** (proprietà + proporzionale + povertà energetica LIHC) — Campagna,
    Rancilio, Radaelli, Merlo, *Sustainable Energy, Grids and Networks* 39 (2024) 101471
    (eq. 11-15) — ⚠ **implementazione provvisoria su dati segnaposto**, vedi §17

> **Nota:** le sezioni 2 e 3 sotto trattano in dettaglio Shapley e Nucleolo; il Nash
> Bargaining è documentato nel codice ([`nash_bargaining_cer.m`](nash_bargaining_cer.m), che ne
> spiega per esteso derivazione e adattamento al gioco CER) più che in questa guida — non ha
> ancora una sezione matematica dedicata qui. Il Variance Least Core ha invece la sua sezione
> completa (§7). Equal Split e Proportional to Consumption, essendo regole elementari senza
> apparato di teoria dei giochi, sono documentati per esteso nelle sezioni §8 e §9. I tre
> metodi dalla letteratura sulle REC italiane (Remuneration Model 1, Cascading Tree,
> Weighted Solidarity) hanno le loro sezioni complete §10-§12, allo stesso livello di
> dettaglio del Variance Least Core, data la loro complessità. Le due **chiavi dinamiche**
> di Gianaroli et al. (§13-§14) sono documentate insieme, perché condividono gran parte
> della matematica e tutti gli helper: sono anche gli unici due metodi che ripartiscono
> **energia** invece di denaro. Stessa scelta per i **tre metodi di Cremers et al.**
> (§16), che condividono l'intero impianto matematico — lo Shapley scritto per strati —
> e che non sono regole di ripartizione autonome ma **approssimazioni dello Shapley**
> stesso, pensate per comunità dove le `2^n` coalizioni non si possono enumerare.

> **§18 non è un metodo.** L'ultima sezione, [§18 Indici di valutazione
> dell'equità](#18-indici-di-valutazione-dellequità), non descrive un modello di
> ripartizione ma i dieci **indicatori** con cui si giudicano tutti gli altri, raggruppati
> per le tre domande a cui rispondono: quanto è *uniforme* la ripartizione (MinMax, QoS,
> EI, Gini, Jain — Dynge & Cali 2025), quanto è vicina al *merito* (Fairness Index —
> Casalicchio et al. 2022), e se *regge* (eccesso di coalizione — Volpato et al. 2024).
> Include la derivazione della `Dw` che il paper non fornisce, e le ragioni per cui QoE e
> Price of Fairness sono stati **esclusi**.

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
| [`pearson_key_cer.m`](pearson_key_cer.m) | Calcola la **Pearson Key** (M3): chiave dinamica sulla correlazione di Pearson giornaliera |
| [`pearson_sharing_key_cer.m`](pearson_sharing_key_cer.m) | Calcola la **Pearson-Sharing Rate** (M5): combinazione pesata α/β di Pearson e sharing rate |
| [`pearson_hourly_key.m`](pearson_hourly_key.m) | Peso grezzo di Pearson: coefficiente giornaliero, rimappato in `[0,1]`, espanso alle 24 ore |
| [`sharing_rate_key.m`](sharing_rate_key.m) | Peso grezzo dello **sharing rate** (M4, eq. 5): componente interna di M5 |
| [`normalize_key_rows.m`](normalize_key_rows.m) | Normalizzazione oraria della chiave (eq. 4), `Σ_i r(t,i) = 1` |
| [`allocate_shared_energy.m`](allocate_shared_energy.m) | Ripartizione oraria dell'**energia** condivisa con cap al consumo (algoritmo di Fig. 2), comune a M3 e M5 |
| [`similarity_utilization_cer.m`](similarity_utilization_cer.m) | Calcola la **Similarity-Utilization**: chiave giornaliera `θ·η` (similarità coseno × fattore di utilizzo) |
| [`marginal_contribution_cer.m`](marginal_contribution_cer.m) | Calcola la **Marginal Contribution**: solo l'ultimo contributo marginale `v(N) − v(N\{i})`, normalizzato |
| [`stratified_expected_value_cer.m`](stratified_expected_value_cer.m) | Calcola la **Stratified Expected Value**: un contributo marginale per strato, stimato su un utente fittizio medio |
| [`adaptive_sampling_shapley_cer.m`](adaptive_sampling_shapley_cer.m) | Calcola l'**Adaptive Sampling Shapley**: campionamento stratificato adattivo (unico metodo stocastico) |
| [`cer_shared_value.m`](cer_shared_value.m) | `v` di **una** coalizione dai suoi profili aggregati, valutata su richiesta in `O(H)`: helper comune ai tre metodi sopra |
| [`tri_level_ep_cer.m`](tri_level_ep_cer.m) | Calcola il **Tri-level EP**: quota di solidarietà + livello proporzionale + livello di proprietà. ⚠ Contiene tutti i **dati segnaposto** e il registro delle 11 ipotesi |
| [`lihc_index.m`](lihc_index.m) | Indice **LIHC** booleano (eq. 12) e continuo (eq. 13) — calcolatore puro, senza segnaposto |
| [`fairness_indicators_lem.m`](fairness_indicators_lem.m) | I sette **indicatori di equità** di Dynge & Cali (MinMax, QoS, EI) su una ripartizione — §18 |
| [`fairness_index_bm.m`](fairness_index_bm.m) | **Fairness Index** di Casalicchio et al.: distanza dalla distribuzione per contributo — §18 |
| [`gini_index.m`](gini_index.m) | Indice di **Gini**, condiviso da `weighted_solidarity_cer` (eq. 2.8) e dall'Equality Index (`EI = 1 − Gini`) |
| [`jain_index.m`](jain_index.m) | Indice di **Jain**, nucleo del Quality of Service (eq. 12 e 18) |
| [`gini_heterogeneity.m`](gini_heterogeneity.m) | Gini di **eterogeneità** della composizione (Casalicchio eq. 10) — *non* è un Gini di reddito |
| [`coalition_excess.m`](coalition_excess.m) | **Eccesso di coalizione** (Volpato eq. 23): quali sottogruppi guadagnerebbero di più uscendo dalla CER — §18.6 |
| [`plot_fairness_indicators.m`](plot_fairness_indicators.m) | Mappa di calore metodi × indicatori, normalizzata per colonna |
| [`MAIN.m`](MAIN.m) | Sezioni `3a` (costo da rete senza CER, baseline), `3b` (Shapley), `3c` (Nucleolo), `3d` (Nash), `3e` (VLC), `3f` (Equal Split), `3g` (Proportional to Consumption), `3h` (Remuneration Model 1), `3i` (Cascading Tree), `3j` (Weighted Solidarity), `3k` (Pearson Key), `3l` (Pearson-Sharing Rate), `3m` (Similarity-Utilization), `3n` (Marginal Contribution), `3o` (Stratified Expected Value), `3p` (Adaptive Sampling), `3q` (accuratezza delle approssimazioni), `3r` (Tri-level EP), `3s` (confronto), `3t` (**indici di equità**) |

**Scelta di design fondamentale.** I metodi *non* ricalcolano l'energia condivisa
ciascuno per conto suo: partono tutti dalla **stessa** `v(S)` di
[`cer_coalition_values.m`](cer_coalition_values.m). Questo garantisce che siano
**matematicamente confrontabili** (giocano lo stesso identico gioco) — esattamente
l'impostazione con cui Fioriti li mette a confronto nelle Fig. 9–10.

**Eccezioni.** Il Variance Least Core (§7) e i tre metodi di Cremers et al. (§16) usano
la stessa *formula* di `v(S)`, ma la valutano **su richiesta** invece di leggerla dal
vettore precalcolato. Il motivo è di scalabilità, non di modellazione:
`cer_coalition_values` costruisce `2^n` valori, quindi è impraticabile oltre ~20
giocatori, mentre questi quattro metodi sono pensati proprio per comunità da decine o
centinaia di membri. Il VLC ha il suo `coalition_value` locale (nato prima);
i tre metodi di §16 passano dall'helper condiviso
[`cer_shared_value.m`](cer_shared_value.m), che lavora sui profili **aggregati** e non su
una maschera di giocatori — indispensabile per la Stratified Expected Value, che valuta
`v` anche su un utente *fittizio* che nessuna bitmask può rappresentare (§16.4).

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
9. **Due chiavi dinamiche, Pearson Key e Pearson-Sharing Rate** (§13-§14) → sono gli
   unici due metodi che ripartiscono **energia** invece di denaro, ora per ora e con il
   vincolo fisico `SH_i(t) ≤ load_i(t)`; la conversione in € avviene solo alla fine e
   l'efficienza `Σφ = v(N)` resta garantita per costruzione, quindi restano confrontabili
   con gli altri nove. L'algoritmo di ripartizione e i due pesi stanno in **helper
   condivisi** (`allocate_shared_energy`, `pearson_hourly_key`, `sharing_rate_key`), così
   M5 riusa M3 e M4 senza duplicare nulla.
10. **Un terzo metodo performance-based su base giornaliera, Similarity-Utilization**
    (§15) → introduce due criteri che nessun altro modello ha: una misura di sincronia
    **invariante di scala** (coseno, non Pearson) e un freno esplicito al sovraconsumo
    (`η`), pensato per la condivisione *virtuale* dove consumare di più significa
    incassare di più. È anche il metodo con la scelta di modello più impattante aperta:
    profili netti (default del progetto) o lordi (lettura letterale del paper), §15.3.
11. **Tre approssimazioni dello Shapley, non tre nuove regole** (§16) → sono gli unici
    metodi del progetto che non propongono un criterio di equità alternativo, ma
    ricalcolano *lo stesso numero* di §2 a costo polinomiale, per comunità dove le `2^n`
    coalizioni non si possono enumerare (il bloccante di [README §13.1](README.md)).
    Vanno giudicati sull'**errore**, non sull'equità, e con `n = 6` abbiamo lo Shapley
    esatto come ground truth per misurarlo. Il risultato è di per sé un contributo: la
    graduatoria del paper **si rovescia** (§16.7), perché la Stratified Expected Value
    assume membri intercambiabili e da noi la generazione è di **un solo membro su sei**
    (§16.8). Introducono anche l'unico metodo **stocastico** del progetto (§16.5), con
    seed esplicito e isolato per renderlo riproducibile.

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
| Potenza di prelievo `ratedLoadKW` [kW] | colonna `P_prel_kW` di `[MEMBRI]` in `CER_input.txt` | è una caratteristica del contratto dell'**utente** |
| Potenza di generazione `ratedGenKW` [kWp] | colonna `kWp` di `[IMPIANTI]` in `CER_input.txt` | appartiene all'**impianto**, non alla persona |

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

Nessuna delle due potenze è derivabile dai profili orari: sono dati esterni, dichiarati
in due tabelle distinte della scheda `CER_input.txt` e ancora **da confermare** (README
§12).

```text
[MEMBRI]   -- potenza impegnata in PRELIEVO, per utente [kW]
id | nome_csv             | ... | P_prel_kW | ... | impianto
 1 | office_1_kWh         | ... |        10 | ... | -
 2 | small_industry_1_kWh | ... |        50 | ... | PV01

[IMPIANTI] -- potenza nominale di GENERAZIONE, per impianto [kWp]
id   | proprietario         | kWp | file_produzione                        | ...
PV01 | small_industry_1_kWh |  20 | Salvaplast_Project_VD7_HourlyRes_1.CSV | ...
```

In `MAIN.m` §3h la potenza di generazione per utente si ricava sommando i `kWp` degli
impianti di cui è proprietario (0 per chi non ne ha); la potenza di prelievo arriva già
allineata ai giocatori da `align_members_to_users`.

> **Scalabilità:** con una riga per membro la tabella regge anche a comunità grandi; resta
> aperta la scelta se compilare le potenze a mano o derivarle dal picco di carico
> (README §14.3).

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
configurazione — e per cui le due colonne (`[MEMBRI].P_prel_kW`, `[IMPIANTI].kWp`) vanno
confermate con dati reali prima di portare in tesi i numeri di questo metodo.

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

## 13. Pearson Key (chiave dinamica M3)

File: [`pearson_key_cer.m`](pearson_key_cer.m).

Riferimento: F. Gianaroli, M. Ricci, P. Sdringola, M. A. Ancona, L. Branchini, F. Melino,
*Development of dynamic sharing keys: Algorithms supporting management of renewable energy
community and collective self consumption*, Energy & Buildings 311 (2024) 114158 —
metodo **M3**.

### 13.1 Cosa cambia rispetto ai nove metodi precedenti

Tutti i metodi §2-§12 ripartiscono **denaro**: partono da `v(N)` (o dall'incentivo orario
`B_REC(t)`) e ne assegnano quote in €. Le due chiavi dinamiche del paper di Gianaroli
ragionano invece sull'**energia**:

```
1. si ripartisce, ORA PER ORA, l'energia condivisa SH(t,i)  [kWh]
2. la si valorizza alla fine:  φ_i = Σ_t SH(t,i) · P_CER(t)  [EUR]
```

La differenza non è cosmetica: la ripartizione dell'energia è soggetta a un **vincolo
fisico** che quella del denaro non ha —

```
SH(t,i) ≤ load_i(t)      (nessuno può "ricevere" più energia di quanta ne consumi)
```

ed è questo vincolo a richiedere l'algoritmo iterativo di §13.4. È anche il motivo per cui
il paper parla di *sharing keys* (chiavi di ripartizione dell'energia condivisa) e non di
*revenue allocation*: le chiavi nascono per essere applicate nella gestione operativa di
una CER, non solo a consuntivo.

### 13.2 Il coefficiente di Pearson giornaliero

Per ogni giorno `d` (24 ore) e ogni utente `i`:

$$
p(i,d) \;=\; \frac{\operatorname{Cov}\bigl(\text{load}_i(d),\, E_{inj}(d)\bigr)}
{\sigma\bigl(\text{load}_i(d)\bigr)\;\sigma\bigl(E_{inj}(d)\bigr)} \;\in\; [-1,1]
$$

dove `E_inj(t) = Σ_i gen_i(t)` è l'energia immessa in rete dalla comunità (nel progetto:
la somma delle eccedenze, già al netto dell'autoconsumo dietro al contatore, §1.2).

**Cosa misura.** Non *quanta* energia consuma l'utente, ma **quando**: la correlazione è
alta se il profilo di consumo della giornata "segue" quello di immissione (consumo alto
nelle ore di surplus, basso di notte). È una misura di **sincronismo**, invariante
rispetto alla scala — raddoppiare tutti i consumi di un utente non cambia il suo `p`.

**Perché su base giornaliera** e non annuale o oraria: su base annuale il coefficiente
sarebbe un singolo numero per utente e la chiave diventerebbe statica (niente
"dinamica"); su base oraria non è nemmeno definito (servono più campioni). Le 24 ore del
giorno sono la finestra naturale del ciclo solare, ed è la scelta del paper.

**Caso degenere.** Se una delle due deviazioni standard è nulla (utente a consumo
costante o nullo in quel giorno; giornata senza alcuna immissione) il coefficiente non è
definito: si pone `p = 0` — nessuna correlazione, comportamento neutro. Nel codice il
test è sul denominatore (`den > 0`), che è l'unica forma numericamente robusta.

### 13.3 Rimappatura e normalizzazione (eq. 4)

I pesi di una chiave devono essere non negativi, quindi si rimappa linearmente:

```
p_remap(i,d) = ( p(i,d) + 1 ) / 2   ∈ [0,1]
```

(correlazione perfettamente opposta → peso 0; correlazione nulla → 0.5; correlazione
perfetta → 1). Tutte le 24 ore del giorno `d` ereditano lo stesso valore
(`p_hourly(t,i)`), e la chiave normalizzata è

```
r(t,i) = p_hourly(t,i) / Σ_j p_hourly(t,j)          (eq. 4)   ⇒  Σ_i r(t,i) = 1
```

> **Attenzione:** la normalizzazione **non** viene fatta dentro
> [`pearson_hourly_key.m`](pearson_hourly_key.m), che restituisce il peso *grezzo*. Il
> motivo è M5 (§14): lì Pearson e sharing rate vanno combinati **prima** di normalizzare,
> e normalizzarli separatamente darebbe un risultato diverso. `normalize_key_rows.m`
> serve quindi solo a *restituire* `r` per ispezione (campo `.keys`): la ripartizione vera
> rinormalizza da sola a ogni iterazione, §13.4.

Il campo `.keys` è esattamente la grandezza che il paper riporta nei box plot delle
Fig. 11-12 ("distribution of normalized Pearson values for each user"), utile se si vuole
riprodurre quella figura sui dati del progetto; `.pDaily` è invece il coefficiente grezzo
in `[-1,1]`, prima della rimappatura.

### 13.4 L'algoritmo iterativo con cap al consumo (Fig. 2 del paper)

File: [`allocate_shared_energy.m`](allocate_shared_energy.m) — **condiviso** da M3 e M5:
cambia solo la matrice dei pesi in ingresso, non l'algoritmo.

Per ogni ora `t`:

1. `E_inj(t) ≥ Σ_i load_i(t)` → **caso banale**: `SH(t,i) = load_i(t)` per tutti. La
   chiave non ha alcun effetto (c'è energia per tutti). *Vedi §13.8: nel caso di studio
   questo ramo copre il 91% dell'energia condivisa.*
2. `E_inj(t) ≤ 0` o carico totale nullo → `SH(t,:) = 0`.
3. Altrimenti si itera:
   ```
   RES = E_inj(t) − Σ_i SH(t,i)                 energia ancora da assegnare
   r_norm(i) = r(t,i)·attivo(i) / Σ_j r(t,j)·attivo(j)    (rinormalizzazione)
   SH_temp(i) = SH(t,i) + r_norm(i)·RES
   se SH_temp(i) > load_i(t):  SH(t,i) = load_i(t),  attivo(i) = false   (CAP)
   altrimenti:                 SH(t,i) = SH_temp(i)
   ```
   Si esce quando nessuno sfora (distribuzione stabile) o quando `RES` è esaurito. Ogni
   iterazione cappa **almeno un** utente, quindi bastano `n` iterazioni: il ciclo è
   `O(n)` per ora, non un'iterazione a convergenza asintotica.

Questo è esattamente il comportamento descritto dal paper: quando un utente viene cappato
"il suo coefficiente viene posto a zero" e il residuo si ridistribuisce tra gli altri
rinormalizzando — nel codice, la maschera `active`.

**Caso degenere gestito in più rispetto al paper.** Se in un'ora tutti i pesi degli utenti
ancora attivi sono nulli (`p = -1` per tutti in M3; underflow dell'esponenziale in M5),
il paper non dice cosa fare e la formula `r/Σr` sarebbe `0/0`: il residuo resterebbe non
assegnato e l'efficienza `Σφ = v(N)` verrebbe violata. Il codice ripiega allora sul
**margine residuo** `load_i(t) − SH(t,i)`, l'unico riparto sempre definito e che per
costruzione non può sforare il cap (in quel ramo `E_inj < Σ load`, quindi
`RES < Σ margini`).

### 13.5 Perché l'efficienza vale per costruzione

L'algoritmo garantisce, ora per ora,

```
Σ_i SH(t,i) = min( E_inj(t), Σ_i load_i(t) )
```

che è **esattamente** l'energia condivisa di comunità calcolata in [`MAIN.m`](MAIN.m) §2.
Quindi

```
Σ_i φ_i = Σ_t min(E_inj(t), load_tot(t)) · P_CER(t) = v(N)
```

lo stesso `v(N)` di tutti gli altri metodi: le quote sono direttamente confrontabili in
`Tcmp` (§3r). L'`assert` di [`report_allocation.m`](report_allocation.m) lo verifica a
ogni esecuzione, e `MAIN.m` §3k-§3l aggiunge il controllo **in energia**
(`Σ_i SH_i = shared_annual`), che è più stringente perché non passa dalla valorizzazione.
Le due verifiche interne all'helper (`SH ≤ load` e somma oraria) sono `assert` in
[`allocate_shared_energy.m`](allocate_shared_energy.m).

### 13.6 Mappatura formula → codice

| Formula | Codice |
|---|---|
| `p(i,d)`, `p_remap`, espansione oraria | [`pearson_hourly_key.m`](pearson_hourly_key.m) (vettorizzata su `[24 × nGiorni × n]`) |
| `r(t,i)` (eq. 4) | [`normalize_key_rows.m`](normalize_key_rows.m) — solo per l'output `.keys` |
| Algoritmo di Fig. 2 | [`allocate_shared_energy.m`](allocate_shared_energy.m) |
| `φ_i = Σ_t SH(t,i)·P_CER(t)` | `phi = SH.' * P_CER;` in [`pearson_key_cer.m`](pearson_key_cer.m) |

Il calcolo di Pearson è vettorizzato riorganizzando le serie in `[24 × nGiorni × n]` (lo
stesso `reshape` 24×365 usato in `MAIN.m` §2) e non richiede la Statistics Toolbox:
`corrcoef` lavorerebbe su una coppia di vettori alla volta, cioè `365 × n` chiamate.

### 13.7 Casi limite (checklist del paper, tutti coperti)

| Caso | Gestione |
|---|---|
| `E_inj(t) = 0` (notte) | `SH(t,:) = 0`, nessuna divisione per zero |
| `Σ_i load_i(t) = 0` | `SH(t,:) = 0` |
| Varianza nulla nel Pearson | `p = 0` (neutro) |
| Ore non multiple di 24 | **errore esplicito** `pearson_hourly_key:notWholeDays` — il giorno incompleto va risolto a monte (cambio ora legale: `MAIN.m` §1 riporta già tutto sulla griglia canonica di 8760 ore) |
| Pesi tutti nulli in un'ora | fallback sul margine residuo (§13.4) |
| Utente con consumo nullo in un'ora | cappato a 0 alla prima iterazione ed escluso dalla rinormalizzazione |

La validazione contro l'esempio numerico del paper (Fig. 7 per M3) è in **§14.7**, insieme
a quella di M4 e M5: i tre metodi condividono l'algoritmo di ripartizione, quindi conviene
verificarli sullo stesso caso.

### 13.8 Lettura dei risultati sul caso reale

Correlazione media annua (coefficiente **grezzo**, prima della rimappatura) e quota
risultante:

| Giocatore | Pearson medio | Energia M3 [kWh] | Quota M3 [€] | Confronto: Prop. to Consumption [€] |
|---|---:|---:|---:|---:|
| office_1 | +0.443 | 6.891 | 879,77 | 898,83 |
| small_industry_1 (prosumer) | −0.323 | 0 | **0** | 0 |
| retail_1 | +0.431 | 6.758 | 867,59 | 867,46 |
| household_1 | +0.133 | 1.562 | 199,77 | 195,04 |
| household_2 | +0.047 | 1.496 | 193,07 | 185,05 |
| household_3 | −0.012 | 1.622 | 208,38 | 202,20 |

Tre letture, tutte importanti prima di usare questi numeri:

**(a) Il prosumer riceve 0 — ed è strutturale, non un errore.** Il carico *residuo* del
proprietario dell'impianto è nullo proprio nelle ore in cui c'è eccedenza da condividere
(complementarità, §1.2): una chiave guidata dal **consumo** non può quindi assegnargli
nulla. Vale identicamente per il Proportional to Consumption (§9), che infatti dà lo
stesso 0. Il suo Pearson medio negativo (−0.323) è la stessa cosa vista da un'altra
angolazione: quando la comunità immette, lui non preleva. Il ricavo del prosumer arriva
dalla **vendita diretta dell'eccedenza** (`revSoldPerPlayer`, la barra arancione nei
grafici), che non passa da nessuno dei quindici modelli.

**(b) I risultati sono vicini al Proportional to Consumption, e c'è un motivo preciso.**
Nel caso di studio, sulle 3.223 ore con energia condivisa positiva, **2.762 ricadono nel
caso banale** `E_inj ≥ Σ load` — e valgono il **91,3% dell'energia condivisa annua**. In
quelle ore la chiave *non viene usata affatto*: ciascuno riceve tutto il proprio consumo.
La chiave di Pearson decide quindi solo l'**8,7%** dell'energia (461 ore in cui
l'immissione è scarsa), ed è per questo che M3 finisce a poche unità percentuali dal
riparto proporzionale al consumo. **Non è una proprietà del metodo, è una proprietà della
comunità**: con un impianto largamente sovradimensionato rispetto al carico residuo, le
chiavi dinamiche hanno poco spazio per differenziare. Su una comunità con generazione
scarsa rispetto ai carichi (il caso per cui il paper le propone) la stessa chiave
produrrebbe differenze molto maggiori. È la prima cosa da verificare se si cambia la
taglia dell'impianto — vedi la **nota da rileggere coi dati reali** in §14.6, che raccoglie
gli indicatori da ricalcolare.

**(c) Il coefficiente premia il sincronismo, non il volume.** `office_1` e `retail_1`
hanno consumi annui molto diversi (10.579 vs 13.884 kWh) ma quote quasi identiche, perché
hanno Pearson quasi uguale (+0.443 e +0.431): entrambi consumano di giorno. È il
comportamento voluto — ed è anche la ragione per cui la chiave, da sola, non è una
regola di ripartizione "equa" in senso assiomatico: non ha nessuna delle proprietà
verificate per Shapley e Nucleolo (§2.3, §3), è una regola operativa.

---

## 14. Pearson-Sharing Rate (chiave dinamica M5)

File: [`pearson_sharing_key_cer.m`](pearson_sharing_key_cer.m).

Riferimento: stesso paper della §13 — metodo **M5**, eq. 7 (che combina M3 ed M4).

### 14.1 La componente M4: lo "sharing rate" (eq. 5)

File: [`sharing_rate_key.m`](sharing_rate_key.m).

Mentre Pearson guarda alla **forma** del profilo sulla giornata, lo sharing rate guarda
al **livello** nella singola ora: premia chi consuma fino a concorrenza dell'energia
immessa, e penalizza chi la supera.

```
ratio(t,i) = load_i(t) / E_inj(t)

SR(t,i) = ratio(t,i)                    se ratio < 1     (retta crescente)
SR(t,i) = exp( −ξ · (ratio(t,i) − 1) )  se ratio ≥ 1     (decadimento esponenziale)
```

È una funzione continua con **massimo in `ratio = 1`** (dove `SR = 1`), cioè nel punto in
cui il consumo dell'utente eguaglia l'immissione della comunità. Sotto la soglia il peso
è semplicemente proporzionale al consumo — lo stesso criterio del metodo M1 del paper,
riparto proporzionale — sopra la soglia decade esponenzialmente per disincentivare il
sovraconsumo nelle ore di scarsità.

**Calibrazione di ξ.** Il paper la fissa imponendo `SR = 0.5` per `ratio = 1.5` (consumo
del 50% superiore all'energia disponibile):

```
0.5 = exp(−ξ·0.5)  ⇒  ξ = ln(2)/0.5 ≈ 1.386
```

Nel codice è scritta come `log(2)/0.5` e non come la costante `1.386`: il valore resta
esatto ed è evidente da dove viene. È configurabile via `opts.xi`.

### 14.2 Il refuso dell'eq. 5 (verificato sull'esempio numerico del paper)

L'eq. 5 **come composta tipograficamente** nel paper associa le due espressioni alle
condizioni **opposte** rispetto a quanto scritto sopra:

```
SR = exp(−ξ·(ratio−1))   se ratio < 1        ← invertita
SR = ratio               se ratio ≥ 1        ← invertita
```

Che si tratti di un refuso di composizione è dimostrato da tre riscontri concordi, tutti
interni all'articolo:

1. **Fig. 3** mostra una retta rossa crescente da `(0,0)` a `(1,1)`, etichettata
   `C_ij/E_inj,j`, e — solo oltre `ratio = 1` — la curva blu esponenziale decrescente,
   etichettata `e^(−ξ(C/E−1))`.
2. **Il testo** (§2.1.4): *"the assumed sharing rate SR_i follows an increasing **linear**
   trend if the ratio between the user's consumption and the energy feed into the grid is
   less than 1, while it follows an **exponentially decreasing** trend if the ratio is
   greater than 1"*. E poco oltre, commentando la Fig. 8: *"users u2 and u1 are assigned
   an amount of shared energy equal to the **ratio** between their respective consumption
   and the energy fed into the grid"* — entrambi hanno `ratio < 1`.
3. **L'esempio numerico** a tre utenti (§2.2): è riprodotto **esattamente** solo dalla
   versione implementata qui. Vedi §14.7.

**Scelta implementata:** `opts.sharingRateMode = "fig3"` (default) segue la Fig. 3, il
testo e l'esempio numerico. La lettura letterale dell'equazione resta disponibile
(`"eq5"`) per poterle confrontare, ma **non è quella con cui il paper ha prodotto i suoi
risultati**: sull'esempio a tre utenti darebbe `[0.66 0.24 0.42]` invece di
`[0.48 0.16 0.68]`. La scelta è documentata nell'header di
[`sharing_rate_key.m`](sharing_rate_key.m) ed è dichiarata a schermo dal report di
`MAIN.m` §3l.

**Casi limite.** `E_inj(t) ≤ 0`: il rapporto non è definito e comunque non c'è energia da
condividere → `SR = 0` (è poi `allocate_shared_energy` a imporre `SH = 0`).
`load_i(t) = 0` con immissione positiva: `ratio = 0` e `SR = 0`, peso nullo — coerente,
visto che quell'utente verrebbe comunque cappato a 0 dall'algoritmo di ripartizione.

### 14.3 La combinazione (eq. 7)

```
combinato(t,i) = α · p_hourly(t,i) + β · SR(t,i)          α + β = 1
r_M5(t,i)      = combinato(t,i) / Σ_j combinato(t,j)
SH(t,i)        = algoritmo di Fig. 2 con pesi r_M5        (§13.4, stesso helper)
φ_i            = Σ_t SH(t,i) · P_CER(t)
```

**Perché si normalizza dopo e non prima.** Normalizzare separatamente le due componenti e
poi combinarle darebbe una chiave diversa (la normalizzazione non è lineare rispetto alla
somma pesata): `α·(p/Σp) + β·(SR/ΣSR) ≠ (α·p + β·SR)/Σ(α·p + β·SR)`. È il motivo per cui
i due helper restituiscono i pesi **grezzi** (§13.3).

I default sono `α = β = 0.5` come nel paper, configurabili via `opts`; la funzione
**verifica** `α + β = 1` con entrambi non negativi, invece di rinormalizzarli in silenzio:
una coppia che non somma a 1 è quasi sempre un errore di chi chiama, non un'intenzione.

### 14.4 Le scale delle due componenti

Entrambe le componenti stanno in `[0,1]`: `p_hourly` vale 0.5 per correlazione nulla e 1
per correlazione perfetta; `SR` vale 1 nel massimo (`ratio = 1`) e decade da entrambi i
lati. Con `α = β = 0.5` i due criteri pesano quindi in modo effettivamente confrontabile,
senza bisogno di normalizzazioni aggiuntive — a differenza del Weighted Solidarity, dove
si sommano kWh e punteggi adimensionali di scala molto diversa (§12.7b). È anche un
riscontro indiretto della correzione di §14.2: con la lettura letterale dell'eq. 5, `SR`
arriverebbe a `e^ξ ≈ 4` per un utente a consumo nullo e la componente di sharing rate
dominerebbe la combinazione.

### 14.5 Mappatura formula → codice

```matlab
[pHourly, pDaily] = pearson_hourly_key(loadUsers, Einj);              % §13.2-13.3
SR        = sharing_rate_key(loadUsers, Einj, opts.xi, opts.sharingRateMode);
combinato = opts.alpha * pHourly + opts.beta * SR;                    % eq. 7
SH        = allocate_shared_energy(loadUsers, Einj, combinato);       % Fig. 2
phi       = SH.' * P_CER;                                             % valorizzazione
```

Cinque righe: tutta la matematica sta negli helper, condivisi con M3. **M4 non è esposto
come metodo di ripartizione a sé** (non è fra i modelli richiesti) e resta una componente
interna; volendolo aggiungere in futuro basterebbe un file `*_cer.m` di cinque righe come
questo, con `combinato = SR`.

### 14.6 Risultati e sensibilità ad α

Con i default (`α = β = 0.5`, `ξ = 1.386`, lettura `"fig3"`):

| Giocatore | Quota M5 [€] | Quota M3 [€] | Δ |
|---|---:|---:|---:|
| office_1 | 879,21 | 879,77 | −0,1% |
| small_industry_1 | 0 | 0 | — |
| retail_1 | 867,89 | 867,59 | +0,03% |
| household_1 | 199,84 | 199,77 | +0,03% |
| household_2 | 193,16 | 193,07 | +0,05% |
| household_3 | 208,48 | 208,38 | +0,05% |

Spazzando `α` da 0 (solo sharing rate = M4 puro) a 1 (= M3), le quote percentuali si
muovono di **meno di mezzo punto**:

```
α = 0.00 :  37.5   0.0  37.1   8.4   8.2   8.8
α = 0.50 :  37.4   0.0  37.0   8.5   8.2   8.9
α = 1.00 :  37.5   0.0  36.9   8.5   8.2   8.9
```

La verifica `M5(α=1) ≡ M3` è un test di coerenza incluso nei controlli
dell'implementazione (le due funzioni devono dare quote identiche a meno del round-off).
Ma la piattezza della tabella qui sopra ha una causa fisica precisa, spiegata sotto.

> ### ⚠ Nota da rileggere quando arriveranno i dati reali
>
> **La comunità di oggi (6 utenti, un impianto da 20 kWp) è una configurazione
> provvisoria**, scelta per sviluppare i metodi: tutti i numeri di §13.8 e §14.6 vanno
> ricalcolati sui dati definitivi. In particolare va ricontrollato *se si ripresenta* il
> fenomeno seguente.
>
> **Il fenomeno.** M3 e M5 danno praticamente lo stesso risultato (scarto < 1% per
> utente), **non** perché le due chiavi coincidano — nelle ore vincolanti divergono
> parecchio (correlazione 0,82; per `office_1` la chiave passa da 0,232 a 0,272, +17%) —
> ma per due effetti sovrapposti:
>
> 1. **Il 91,3% dell'energia condivisa cade nel caso banale** `E_inj ≥ Σ load`, dove
>    nessuna chiave viene consultata (§13.8b);
> 2. **nell'8,7% restante il cap assorbe la differenza**: in media **2,27 utenti su 4,68
>    attivi** ricevono esattamente il proprio consumo, e per loro il peso è irrilevante.
>
> **La causa a monte: mancano i sovraconsumatori.** Lo sharing rate differenzia solo chi
> supera l'immissione (`ratio ≥ 1`, ramo esponenziale). Qui il ratio mediano nelle ore
> vincolanti è **0,325** e solo il **21%** delle coppie ora/utente sta sul ramo
> esponenziale: per il resto vale `SR = ratio`, cioè proporzionale al consumo — quello che
> il cap fa già da sé. L'unico utente grande abbastanza per sovraconsumare
> (`small_industry_1`, 60 MWh/anno) ha carico residuo nullo in tutte le ore di
> condivisione, per costruzione (§1.2). Nel paper è l'opposto: le differenze M3/M5 di
> Tabella 3 sono guidate proprio dai due grandi consumatori u1 (SME, 420 MWh/anno) e u6.
>
> **Tre indicatori da ricalcolare sui dati veri** (bastano poche righe sui vettori già
> disponibili in `MAIN.m`, valori attuali fra parentesi):
>
> | Indicatore | Formula | Oggi | Soglia indicativa |
> |---|---|---:|---|
> | Energia nelle ore vincolanti | `sum(shared(Einj<loadComm)) / sum(shared)` | 8,7% | sotto ~20% le chiavi contano poco |
> | Coppie ora/utente con `ratio ≥ 1` | su `loadForShare ./ genPVSurplus` | 21% | sotto ~30% M5 ≈ M3 |
> | Utenti cappati per ora vincolante | `SH_i ≥ C_i` | 2,27 / 4,68 | oltre metà comprime ogni chiave |
>
> **Se il fenomeno si ripresenta** non è un bug: significa che la comunità è
> sovradimensionata sul lato produzione e non ha sovraconsumo da disincentivare — è un
> risultato da riportare, non da nascondere. Riportare M3 e M5 come due modelli con
> conclusioni diverse sarebbe invece fuorviante. Controprova già eseguita sulla
> configurazione attuale, riducendo solo la taglia dell'impianto:
>
> | PV | energia in ore vincolanti | max scostamento M5 vs M3 |
> |---|---:|---:|
> | ×1,0 | 8,7% | 0,02 punti % di `v(N)` |
> | ×0,3 | 46,3% | 0,08 |
> | ×0,2 | 76,2% | 0,11 |
> | ×0,1 | 95,0% | 2,69 |
>
> Serve scendere a un decimo dell'impianto perché i due metodi si separino in modo
> leggibile: la sensibilità è ai **dati**, non ai parametri `α`/`β`.

### 14.7 Validazione: l'esempio orario del paper (Fig. 4-9)

Il paper applica i suoi metodi a una **singola ora** con tre utenti (§2.2), riportando i
kWh assegnati nelle Fig. 5-9. È il banco di prova più diretto dell'implementazione — e
copre M3, M4 e M5 insieme, perché condividono l'algoritmo di ripartizione.

**Dati** (Fig. 4): `C = [0.72, 0.24, 1.56] kWh`, `E_inj = 1.32 kWh`,
`p = [0.64, 0.23, 0.51]` (coefficienti di Pearson già rimappati, assunti dal paper),
`ξ = 1.386`, `α = β = 0.5`.

| Metodo | Atteso (figura) | Ottenuto | Esito |
|---|---|---|:---:|
| **M3** (Fig. 7) | `[0.61, 0.22, 0.49]` | `[0.61, 0.22, 0.49]` | ✔ |
| **M4** — `SR` (testo: `SR(u3) = 78%`) | `[0.55, 0.18, 0.78]` | `[0.55, 0.18, 0.78]` | ✔ |
| **M4** (Fig. 8) | `[0.48, 0.16, 0.68]` | `[0.48, 0.16, 0.68]` | ✔ |
| **M5** (Fig. 9) | `[0.54, 0.19, 0.59]` | `[0.54, 0.19, 0.59]` | ✔ |

La riproduzione è **esatta** su tutte e tre le figure. Lo stesso esempio è ciò che
identifica il refuso dell'eq. 5 (§14.2): con la lettura letterale, M4 darebbe
`[0.66, 0.24, 0.42]` — incompatibile con la Fig. 8, e con `SR(u3)` che sarebbe `1.18`
invece del 78% citato nel testo.

Verifiche aggiuntive eseguite sull'implementazione, oltre a questo esempio:

- efficienza oraria `Σ_i SH(t,i) = min(E_inj, Σ load)` e cap `SH ≤ load` su tutte le ore
  (sono `assert` permanenti in [`allocate_shared_energy.m`](allocate_shared_energy.m));
- Pearson `+1` per un profilo perfettamente sincrono, `−1` per uno in antifase, `0` a
  varianza nulla, e rimappatura corrispondente in `{1, 0, 0.5}`;
- `SR = 1` in `ratio = 1` (continuità tra i due rami) e `SR = 0.5` in `ratio = 1.5`
  (calibrazione di ξ);
- `M5(α = 1) ≡ M3` a meno del round-off;
- ridistribuzione corretta del residuo dopo un cap, e simmetria tra utenti identici;
- errore esplicito su serie che non coprono giornate intere e su `α + β ≠ 1`;
- sui dati reali del progetto: `Σ_i SH_i = 18.329,2 kWh` = energia condivisa di `MAIN.m`
  §2, e `Σ_i φ_i = v(N)` per entrambi i metodi.

---

## 15. Similarity-Utilization

File: [`similarity_utilization_cer.m`](similarity_utilization_cer.m).

Riferimento: M. Bilardo, *A fair dynamic incentive allocation method for virtual energy
sharing in renewable energy communities that rewards members' virtuosity and engagement*,
Renewable Energy 255 (2025) 123756 (eq. 3-8, Fig. 5).

### 15.1 Il concetto: virtuosità = sincronia × sobrietà

È il terzo metodo *performance-based* del progetto, ma con una logica diversa dalle due
chiavi dinamiche di §13-§14: non ripartisce l'energia ora per ora, bensì l'**incentivo**
giorno per giorno, in proporzione a un fattore di allocazione che è il **prodotto** di due
termini indipendenti (eq. 6):

$$
f_{all}(m,d) \;=\; \theta(m,d)\cdot\eta(m,d) \;\in\;[0,1]
$$

**Similarità `θ` (eq. 7)** — coseno dell'angolo fra il vettore delle 24 ore di carico del
membro e il vettore delle 24 ore di generazione della comunità:

$$
\theta_m \;=\; \frac{p_{l,m}\;p_{g,M}^{\top}}
{\sqrt{\bigl(p_{l,m}p_{l,m}^{\top}\bigr)\cdot\bigl(p_{g,M}p_{g,M}^{\top}\bigr)}}
$$

Con vettori non negativi il coseno cade sempre in `[0,1]`: vale 1 se le due curve sono
**proporzionali** e 0 se non si sovrappongono mai. È **invariante di scala** — raddoppiare
tutti i consumi del membro non cambia `θ` — quindi misura *quando* si consuma, non
*quanto*.

> **Differenza con la chiave di Pearson (§13).** Sono entrambe misure giornaliere di
> sincronismo, ma non la stessa cosa: Pearson centra i due vettori sulla media prima di
> correlarli, il coseno no. In pratica Pearson misura se le due curve **oscillano
> insieme**, il coseno se **puntano nella stessa direzione**. Un membro con carico
> costante ha varianza nulla → Pearson indefinito (per convenzione 0, cioè 0.5 dopo la
> rimappatura), mentre il coseno è ben definito e positivo. Il coseno inoltre non è mai
> negativo su profili energetici, quindi non ha bisogno della rimappatura `(p+1)/2`.

**Utilizzo `η` (eq. 8)** — quota del fabbisogno giornaliero del membro che la generazione
di comunità riesce a coprire:

$$
\eta_m \;=\; \min\!\left(1,\; \frac{\sum_M \int_{\Delta t} p_{g,m}\,dt}{\int_{\Delta t} p_{l,m}\,dt}\right)
$$

Vale 1 finché la comunità produce abbastanza per quel membro, e decade quando il suo
consumo giornaliero supera la produzione dell'intera comunità.

**Perché serve `η`.** È il contributo concettuale del paper, spiegato in §3.3: nella
condivisione **virtuale** un grande consumatore può accaparrarsi l'incentivo semplicemente
**alzando i propri prelievi**, perché più consuma più energia "condivide" contabilmente. È
esattamente l'opposto dell'efficienza energetica che una CER dovrebbe promuovere. `η`
disinnesca questa strategia senza penalizzare l'autoconsumo in sé. Nel paper stesso lo si
vede nel confronto con il metodo #5 (performance-based sul solo consumo in fascia
12:00-14:00), che assegna il 66,3% dell'incentivo a un solo membro.

I due fattori sono complementari: `θ` premia la **sincronia**, `η` la **sobrietà**. Il
prodotto è alto solo per chi fa entrambe le cose.

### 15.2 Ripartizione giornaliera (eq. 4-5, Fig. 5)

```
I(d)   = Σ_{t ∈ d} shared(t) · P_CER(t)            incentivo maturato quel giorno
w(m,d) = f_all(m,d) / Σ_m f_all(m,d)               chiave normalizzata del giorno
φ_m    = Σ_d w(m,d) · I(d)
```

`shared(t) = min(Σ export, Σ import)` è l'eq. 3 del paper, **identica** al nostro `shared`
di [`MAIN.m`](MAIN.m) §2: il montepremi è quindi lo stesso `v(N)` di tutti gli altri
metodi. Poiché `Σ_m w(m,d) = 1` ogni giorno, l'efficienza `Σ_m φ_m = v(N)` vale per
costruzione.

> **Nota sull'eq. 5.** Come stampata sembra una normalizzazione sull'intero periodo, ma il
> flowchart di Fig. 5 (ciclo esterno sui giorni, `norm(f_all)` dentro il ciclo) e il §5.2
> (*"resulting in a daily percentage allocation"*) sono espliciti: è **giornaliera**.
> L'implementazione segue questi ultimi. Analogamente, l'eq. 7 definisce
> `p_g,M = Σ_M ∫ p_l,m dt` scrivendo il **carico** al posto della generazione: refuso
> evidente dal contesto (è la "community's generation aggregate profile").

> **Due medie diverse, da non confondere.** `φ_m / v(N)` è la quota **in euro**, cioè la
> media delle quote giornaliere **pesata sull'incentivo di ciascun giorno**. La Fig. 10b e
> la Tabella 5 del paper riportano invece la media **semplice** delle percentuali
> giornaliere, che dà più peso ai giorni invernali (poco incentivo, chiave molto diversa).
> Il codice restituisce entrambe: `.phi` e `.meanDailyShare`.

### 15.3 Profili lordi o netti: la scelta di modello più impattante ⚠

Il paper calcola `θ` ed `η` sui profili **lordi**, dietro al contatore — il carico totale
del membro e la generazione totale della comunità prima dell'autoconsumo. Lo dichiara esso
stesso tra i limiti (§6): *"an important limitation of the proposed method lies in the use
of behind-the-meter energy flows... this information is usually only accessible to
individual members, not to a hypothetical community manager"*.

Nel progetto il **default sono i profili netti** (`genForShare`/`loadForShare`), per
coerenza con gli altri undici metodi. La differenza è tutt'altro che cosmetica:

| Giocatore | `θ` netti | `θ` lordi | Quota netti [€] | Quota lordi [€] |
|---|---:|---:|---:|---:|
| office_1 | 0,521 | 0,585 | 582,14 | 439,06 |
| small_industry_1 (prosumer) | **0,000** | **0,792** | **0** | **549,83** |
| retail_1 | 0,635 | 0,713 | 650,97 | 496,44 |
| household_1 | 0,452 | 0,510 | 471,84 | 362,06 |
| household_2 | 0,349 | 0,389 | 337,13 | 261,54 |
| household_3 | 0,320 | 0,359 | 306,51 | 239,66 |

Sui profili **netti** il carico residuo del proprietario dell'impianto è nullo proprio
nelle ore di eccedenza (complementarità, §1.2): i due vettori sono ortogonali, `θ = 0`
esatto, e la sua quota è 0 — come in §13-§14. Sui profili **lordi** lo stesso membro ha la
**similarità più alta della comunità** (0,792: è l'edificio che ospita l'impianto, con
carico industriale diurno) e incassa il 23% del montepremi. Passare da una lettura
all'altra sposta ~550 € su 2.349 €.

Il montepremi `v(N)` **non cambia** in nessuno dei due casi, quindi il confronto in `Tcmp`
resta valido comunque. La commutazione è una riga, senza toccare il codice:

```matlab
SU = similarity_utilization_cer(genForShare, loadForShare, userNames, P_CER_h, ...
        struct('loadForFactors', loadUsers, 'genForFactors', genPV_raw));
```

> **Decisione aperta.** Il default netto è stato scelto per coerenza interna al progetto,
> non perché sia più fedele al paper — anzi, la lettura letterale è quella lorda. È un
> punto da chiudere con letture aggiuntive prima di portare questo metodo in tesi.

### 15.4 Mappatura formula → codice

| Formula | Codice |
|---|---|
| `θ` (eq. 7) | coseno vettorizzato su `[24 × nGiorni × n]`, `θ = 0` se un denominatore è nullo |
| `η` (eq. 8) | `min(1, E_gen(d) ./ E_load(m,d))`, `η = 1` se il membro non consuma quel giorno |
| `f_all` (eq. 6) | `fAll = theta .* eta` |
| `norm(f_all)` (eq. 5, Fig. 5) | `dailyShare = fAll ./ sum(fAll, 2)`, uniforme nei giorni degeneri |
| `I(d)` (eq. 4) | `sum(reshape(shared .* P_CER, 24, nDays), 1).'` |
| `φ_m` | `dailyShare.' * dailyIncentive` |

Nessun toolbox richiesto. Costo `O(H·n)`, ~0,04 s sui dati del progetto.

### 15.5 Casi limite

| Caso | Gestione |
|---|---|
| Giorno senza generazione di comunità | `θ` indefinito → 0, `f_all = 0` per tutti → chiave uniforme di ripiego; quel giorno vale comunque `0 €`, quindi la scelta non influenza `φ`. Il conteggio è in `.nDegenerateDays` (59 giorni con `η < 1`, 6 giorni degeneri sui dati attuali) |
| Membro senza consumi in un giorno | `η = 1` (fabbisogno nullo banalmente coperto), `θ = 0` → quota 0 |
| Ore non multiple di 24 | errore esplicito `similarity_utilization_cer:notWholeDays` |
| `meanDailyShare` | calcolata sui soli giorni con chiave definita, per non far entrare la uniforme di ripiego nella statistica |

### 15.6 Lettura dei risultati sul caso reale

Con i profili netti (default):

| Giocatore | `θ` medio | `η` medio | Quota [€] | Quota [%] | Confronto: Pearson Key [€] |
|---|---:|---:|---:|---:|---:|
| office_1 | 0,521 | 0,957 | 582,14 | 24,8% | 879,77 |
| small_industry_1 | 0,000 | 0,910 | 0 | 0% | 0 |
| retail_1 | 0,635 | 0,953 | 650,97 | 27,7% | 867,59 |
| household_1 | 0,452 | 0,975 | 471,84 | 20,1% | 199,77 |
| household_2 | 0,349 | 0,976 | 337,13 | 14,4% | 193,07 |
| household_3 | 0,320 | 0,975 | 306,51 | 13,1% | 208,38 |

Due osservazioni:

**(a) È molto più piatto degli altri performance-based, e non per caso.** Le famiglie
prendono 2,4× quanto darebbe loro la Pearson Key, l'ufficio il 34% in meno. Il motivo è
strutturale: il coseno è **invariante di scala**, quindi una famiglia con un carico
piccolo ma ben allineato alla produzione vale quanto un ufficio con un carico dieci volte
maggiore e allineato uguale. Le chiavi di §13-§14 finiscono invece a ridosso del riparto
proporzionale al consumo, perché il cap `SH_i ≤ load_i` le riporta lì (§13.8b). È il
metodo che si discosta di più da *tutte* le altre undici regole di ripartizione (i metodi
1-11; i metodi 13-15 non sono regole ma approssimazioni dello Shapley, §16) — e l'unico in cui la taglia del
consumo non conta quasi nulla.

**(b) `η` morde poco ma non è inerte.** Media 0,958, con 59 giorni su 365 in cui almeno un
membro scende sotto 1 — tutti invernali, quando la produzione crolla. Il più penalizzato è
`small_industry_1` (0,910), l'unico con un fabbisogno paragonabile alla produzione
giornaliera dell'intera comunità: esattamente il comportamento che il fattore vuole
correggere. Su una comunità con generazione più scarsa `η` diventerebbe il fattore
dominante — è lo stesso avvertimento della nota di §14.6, e vale anche qui.

---

## 16. Le tre approssimazioni dello Shapley (Cremers et al. 2023)

File: [`marginal_contribution_cer.m`](marginal_contribution_cer.m),
[`stratified_expected_value_cer.m`](stratified_expected_value_cer.m),
[`adaptive_sampling_shapley_cer.m`](adaptive_sampling_shapley_cer.m), con l'helper
condiviso [`cer_shared_value.m`](cer_shared_value.m).

Riferimento: S. Cremers, V. Robu, P. Zhang, M. Andoni, S. Norbu, D. Flynn, *Efficient
methods for approximating the Shapley value for asset sharing in energy communities*,
Applied Energy 331 (2023) 120328 (§4.1.1–4.1.3, Appendice C).

Sono documentati **insieme** per lo stesso motivo delle due chiavi dinamiche (§13-§14):
condividono l'intero impianto matematico — la scrittura dello Shapley *per strati* — e
differiscono solo in **come** stimano il contributo di ciascuno strato.

### 16.1 Non sono regole di ripartizione: sono approssimazioni

È la differenza che rende questi tre metodi diversi da tutti i dodici precedenti. Gli
altri propongono un **criterio di equità alternativo** (stabilità, sincronia, solidarietà,
potenza contrattuale…): danno una risposta *diversa* e vanno confrontati fra loro. Questi
tre approssimano lo **stesso numero** già calcolato in forma esatta in §2 — lo Shapley
value — e vanno quindi giudicati su un metro completamente diverso: **quanto poco
sbagliano**, non quanto sono equi.

Il problema che risolvono è di scala. Lo Shapley esatto costa `O(2^n)`: con i nostri
`n = 6` sono 64 coalizioni e il calcolo è istantaneo, ma il paper lavora su comunità da
**200 prosumer**, dove `2^200` non esiste su carta. È la stessa barriera documentata in
[README §13.1](README.md) come **bloccante** per lo scaling del progetto a ~100 utenti —
e questi tre metodi sono, insieme al VLC, la risposta della letteratura a quel problema.

Con `n = 6` il loro valore per il progetto non è quindi la ripartizione che producono, ma
il fatto che avendo lo Shapley **esatto** come *ground truth* possiamo **misurare il loro
errore** (§16.7) e stabilire se siano affidabili prima di doverli usare per forza a
`n = 100`. È esattamente l'impostazione del paper, che per costruire un ground truth a 200
agenti sviluppa un metodo di calcolo esatto per classi (§4.2 del paper, qui non
implementato: vedi §16.10).

### 16.2 La base comune: lo Shapley scritto per strati (eq. 8)

Tutti e tre partono da una riscrittura esatta dello Shapley. Uno **strato** `j` è
l'insieme delle coalizioni di cardinalità `j`. Definiamo il **contributo marginale medio
allo strato `j`**:

$$
\mu(i,j) \;=\; \frac{1}{\binom{n-1}{j}}
\sum_{\substack{S \subseteq N\setminus\{i\} \\ |S| = j}}
\bigl[\, v(S \cup \{i\}) - v(S) \,\bigr]
$$

Allora (eq. 8 del paper):

$$
\varphi_i \;=\; \frac{1}{n}\sum_{j=0}^{n-1} \mu(i,j)
$$

**È un'identità, non un'approssimazione:** lo Shapley è la media semplice dei contributi
marginali medi degli `n` strati. La verifica numerica è disponibile nel codice e torna a
`2,3·10⁻¹³` (§16.9).

Il costo esponenziale sta tutto **dentro** `μ(i,j)`, che somma `C(n-1, j)` coalizioni. I
tre metodi si distinguono esclusivamente per come lo aggirano:

| Metodo | Come stima `μ(i,j)` |
|---|---|
| Marginal Contribution | ne calcola **uno solo**, l'ultimo (`j = n-1`), e butta gli altri |
| Stratified Expected Value | ne stima **tutti**, ma con **una sola** valutazione di `v` per strato |
| Adaptive Sampling | ne stima **tutti**, campionando a caso `M` coalizioni in totale |

### 16.3 Marginal Contribution (eq. 9-10)

File: [`marginal_contribution_cer.m`](marginal_contribution_cer.m).

Lo strato `n-1` contiene **una sola** coalizione, `N\{i}`: lì `μ` non è una media di
niente, è un valore esatto ottenibile con una valutazione di `v`. Il metodo tiene solo
quello:

```
MC_i = v(N) − v(N\{i})                                    (eq. 9)
```

Servono `n+1` valutazioni di `v` invece di `2^n`: complessità **`O(n)`**, la più bassa
delle tre.

**La normalizzazione non è un dettaglio.** A differenza dello Shapley, l'efficienza
`Σφ = v(N)` non è una proprietà del metodo e va imposta a mano:

```
φ_i = v(N) · MC_i / Σ_q MC_q                              (eq. 10)
```

Nel gioco CER il fattore di scala è tipicamente **molto** minore di 1 — sui nostri dati
vale **0,5123** — perché ogni giocatore rivendica per intero l'energia condivisa che
sparirebbe senza di lui, e lo stesso kWh viene così contato più volte.

#### Il rischio di degenerazione (da tenere d'occhio)

`MC_i = 0` esattamente ogni volta che togliere `i` non riduce l'energia condivisa. Per un
consumatore ciò accade quando il carico residuo degli **altri** basta comunque ad
assorbire tutta l'eccedenza: quel consumatore riceve **zero**, per quanto grande sia il
suo consumo. Togliendo l'unico prosumer, al contrario, l'energia condivisa crolla a zero e
`MC` vale l'intero `v(N)`. Con un solo impianto e carico abbondante la ripartizione
degenera quindi in **"tutto al prosumer"**.

Sulla community attuale **non** accade (0 giocatori con `MC = 0`), perché il picco del
PV supera in alcune ore il carico residuo, ma è una proprietà fragile rispetto al
dimensionamento dell'impianto: `S.nullPlayers` la sorveglia a ogni esecuzione. Nel paper
il fenomeno non esiste, perché l'impianto è in **comproprietà** e nessun membro è mai del
tutto superfluo.

### 16.4 Stratified Expected Value (eq. 11-13)

File: [`stratified_expected_value_cer.m`](stratified_expected_value_cer.m). È il metodo
**nuovo** proposto dal paper, e quello con più conseguenze per noi.

L'idea: invece di enumerare le `C(n-1, j)` coalizioni dello strato `j`, se ne costruisce
**una sola rappresentativa**, fatta di `j` copie di un utente **fittizio medio** `p₋ᵢ` che
porta la media dei profili degli altri `n-1` (eq. 11):

```
gen_p₋ᵢ(t)  = ( Σ_{q≠i} gen_q(t)  ) / (n−1)
load_p₋ᵢ(t) = ( Σ_{q≠i} load_q(t) ) / (n−1)
```

$$
SEV_i \;=\; \frac{1}{n}\sum_{j=0}^{n-1}
\Bigl[\, v\bigl(\{j \text{ copie di } p_{-i}\} \cup \{i\}\bigr) - v\bigl(\{j \text{ copie}\}\bigr) \,\Bigr]
$$

poi normalizzato come sopra (eq. 13). Costo: `O(n²)` valutazioni di `v`, e il metodo resta
**deterministico**.

**Adattamento al nostro gioco.** Il paper media i soli profili di *domanda*, perché la
generazione è dell'impianto condiviso ed è un dato esterno alla coalizione. Da noi ogni
utente porta anche la propria eccedenza, quindi si mediano **entrambi i lati** —
altrimenti l'utente medio non rappresenterebbe i giocatori del nostro gioco. È l'unica
libertà presa rispetto al testo, ed è forzata dalla struttura di `v(S)`.

**`p₋ᵢ` non è un utente reale.** I profili veri sono complementari (in ogni ora eccedenza
*oppure* carico residuo, mai entrambi), quindi `v({i}) = 0` per ogni giocatore vero.
L'utente medio invece **mescola** utenti diversi e ha entrambi i lati nella stessa ora,
perciò `v({1 copia}) > 0`. È voluto: è uno stand-in statistico dello strato, non un membro
della comunità.

#### Due identità esatte nel nostro gioco

Poiché la nostra `v(S)` dipende **solo dai profili sommati** della coalizione:

- **strato 0** — `v({i}) − v(∅) = 0`, come per ogni giocatore reale;
- **strato n−1** — `n−1` copie dell'utente medio riproducono *esattamente* l'aggregato
  degli altri `n−1` utenti veri, quindi l'ultimo termine **coincide con `MC_i` dell'eq. 9**
  (a meno del rumore della divisione per `n−1`).

Sono le due identità su cui poggia tutta la verifica di §16.9: agli estremi
l'approssimazione **non ha spazio per sbagliare**, quindi se lì i conti tornano l'utente
medio è costruito bene e ogni scostamento residuo è di modello, non di codice.

### 16.5 Adaptive Sampling Shapley (eq. C.1-C.7)

File: [`adaptive_sampling_shapley_cer.m`](adaptive_sampling_shapley_cer.m). Non è del
paper — è di O'Brien et al. (2015) — ma Cremers et al. lo implementano come riferimento
*stato dell'arte* con cui confrontarsi, e qui serve allo stesso scopo.

Per ogni giocatore si estraggono `M` coalizioni casuali (default `M = 1000`, come nel
paper) e la media campionaria stima `μ(i,j)`. La parte **adattiva** è come si spartiscono
gli `M` campioni fra gli strati: non in parti uguali, ma in proporzione alla deviazione
standard stimata dei contributi di ciascuno strato (eq. C.1),

```
π_i,j(m) = ε(m)/|strati| + (1 − ε(m)) · σ_i,j / Σ_s σ_i,s
```

così gli strati con contributi più dispersi — dove la media campionaria è più incerta —
ricevono più campioni. Il peso `ε(m)` è una doppia sigmoide (eq. C.2) che vale **1**
all'inizio (esplorazione uniforme: le `σ` non sono ancora stimate) e decade a ~0,06 alla
fine (sfruttamento). Media e deviazione standard si aggiornano in linea con l'algoritmo di
**Welford** (eq. C.3-C.6), senza conservare i campioni.

**I due strati degeneri.** Gli strati `0` e `n-1` contengono una sola coalizione ciascuno,
quindi ricampionarli non aggiunge informazione: come nell'implementazione del paper (nota
in fondo all'Appendice C) sono valutati **una volta sola in forma esatta** ed esclusi dal
campionamento. Ne segue che il termine di strato `n-1` è esattamente `MC_i`, e il termine
di strato `0` è `v({i}) = 0`. Poiché gli strati campionabili diventano `1…n-2`, il termine
uniforme dell'eq. C.1 è `1/|strati campionabili|` e non `1/n`: è una conseguenza diretta
di quell'esclusione, non una modifica della formula.

#### È l'unico metodo stocastico del progetto ⚠

Rieseguito sugli stessi dati restituisce numeri **diversi**, e due utenti con profili
identici possono ricevere quote diverse. In una CER, dove i membri devono poter
riverificare il conto dell'aggregatore, è un problema di **fiducia** prima ancora che di
accuratezza — è la critica esplicita che il paper gli muove (§2.2 e §5.3) ed è la
motivazione per cui propone la SEV.

Nel progetto il generatore è inizializzato con un **seed** esplicito (`opts.seed`, default
42) e **isolato** dal generatore globale di MATLAB, così l'esecuzione è riproducibile e
lanciare questo metodo non altera altri risultati casuali della sessione. Cambiare seed
cambia i numeri: è proprio la variabilità che il paper contesta, resa visibile invece che
nascosta.

**Nota di scala.** Con `n = 6` questo metodo *non è davvero un'approssimazione*: lo strato
più numeroso ha `C(5,2) = 10` coalizioni, quindi 1000 campioni per giocatore le enumerano
molte volte e la stima converge allo Shapley esatto a meno del rumore di campionamento. Il
divario diventa significativo solo con decine o centinaia di membri.

### 16.6 Complessità a confronto (Tabella 2 del paper)

| Metodo | Valutazioni di `v` | Con `n = 6` | Deterministico? |
|---|---|---:|:---:|
| Shapley esatto | `O(2ⁿ)` | 64 | sì |
| Marginal Contribution | `O(n)` | 7 | sì |
| Stratified Expected Value | `O(n²)` | 72 | sì |
| Adaptive Sampling | `O(n·M)` | ~12 000 | **no** |

A `n = 6` la SEV costa *più* dello Shapley esatto: il vantaggio compare solo quando `2ⁿ`
esplode. A `n = 100` sarebbero 20 000 valutazioni contro `10³⁰`.

### 16.7 Risultati sul caso reale: la graduatoria del paper si rovescia ⚠

Montepremi `v(N)` = **2 348,59 €**. Confronto con lo Shapley esatto (eq. 16 del paper,
`RD = |φ̂ − φ| / |φ| · 100`):

| Giocatore | Shapley esatto | MC | SEV | AS | RD MC | RD SEV | RD AS |
|---|---:|---:|---:|---:|---:|---:|---:|
| office_1 | 438,28 | 436,12 | 520,29 | 451,86 | 0,49% | 18,71% | 3,10% |
| small_industry_1 | 1 193,16 | 1 203,30 | 951,79 | 1 188,74 | 0,85% | 20,23% | 0,37% |
| retail_1 | 427,42 | 423,46 | 517,36 | 418,49 | 0,92% | 21,05% | 2,09% |
| household_1 | 94,61 | 92,38 | 116,52 | 92,78 | 2,36% | 23,16% | 1,93% |
| household_2 | 93,90 | 93,26 | 117,64 | 94,93 | 0,69% | 25,28% | 1,10% |
| household_3 | 101,23 | 100,09 | 124,98 | 101,78 | 1,12% | 23,46% | 0,55% |
| **RD media (eq. 17)** | | **1,07%** | **21,98%** | **1,52%** | | | |

Nel paper la SEV è il metodo **più** accurato e la MC il **meno**; da noi succede
l'esatto contrario. E l'errore della SEV non è rumore: è **sistematico e con segno** —
gonfia tutti i consumatori (+19÷25%) e sgonfia il prosumer (−20%).

Non è un difetto dell'implementazione. La spiegazione, dimostrata numericamente in §16.8,
è che la SEV poggia su un'ipotesi che questa comunità viola.

### 16.8 Perché la SEV sbaglia: Jensen e le coalizioni a valore nullo

L'eq. 11 assume implicitamente che i membri siano **intercambiabili**: che un utente medio
sia un buon rappresentante di un utente qualunque. Nel paper è vero, perché la generazione
è di un impianto in **comproprietà** e ogni membro ne porta una fetta — nessuno è mai
indispensabile. Da noi la generazione appartiene a **un solo membro su sei**.

Il confronto strato per strato con il valore **vero** `μ(i,j)` (calcolabile per
enumerazione, §16.9) mostra dove si rompe:

| Giocatore | strato | `μ` vero [€] | stima SEV [€] | scarto |
|---|---:|---:|---:|---:|
| office_1 | 1 | 185,40 | 640,79 | **+246%** |
| office_1 | 2 | 363,25 | 783,35 | +116% |
| office_1 | 3 | 533,55 | 822,49 | +54% |
| office_1 | 4 | 696,24 | 840,65 | +21% |
| office_1 | 5 | 851,23 | 851,23 | **0** |
| small_industry_1 (prosumer) | 1…4 | 492…1 902 | 501…1 911 | < 1,5% |

Lo **strato 1** dice tutto. Delle 5 coalizioni-singoletto che `office_1` può incontrare,
**una sola** contiene il prosumer e vale qualcosa; le altre quattro valgono **esattamente
zero**. Il contributo atteso vero è quindi *"1/5 di probabilità di incontrare l'intero
impianto"*. L'utente medio lo trasforma in *"certezza di incontrare 1/5 dell'impianto"* —
e poiché il `min()` della nostra `v` è **concavo**, le due cose non coincidono affatto
(disuguaglianza di Jensen):

$$
\mathbb{E}\bigl[\min(G \cdot \mathbb{1}\{\text{prosumer} \in S\},\; L_S)\bigr]
\;\neq\;
\min\bigl(\mathbb{E}[G \cdot \mathbb{1}\{\cdot\}],\; \mathbb{E}[L_S]\bigr)
$$

Nel paper il termine aleatorio `1{prosumer ∈ S}` **non esiste**: la generazione è un dato
deterministico che cresce con la taglia della coalizione, quindi lo scarto di Jensen è
trascurabile. Da noi **il 52% delle coalizioni proprie vale esattamente zero** (32 su 62:
tutte quelle senza il prosumer), ed è precisamente ciò che l'utente medio non sa
rappresentare.

L'effetto sulle quote finali passa poi dalla normalizzazione. Prima dell'eq. 13:

| Giocatore | Shapley | SEV grezzo | scarto |
|---|---:|---:|---:|
| office_1 | 438,28 | 656,42 | +49,8% |
| small_industry_1 | 1 193,16 | 1 200,82 | **+0,6%** |
| retail_1 | 427,42 | 652,73 | +52,7% |
| household_1/2/3 | ~96 | ~151 | +55÷58% |
| **somma** | 2 348,59 | 2 963,07 | |

Il prosumer è stimato quasi perfettamente; sono i consumatori a essere gonfiati del ~55%.
La normalizzazione, moltiplicando **tutto** per 0,7926, scarica quindi l'eccesso sul solo
giocatore che era corretto: da qui il suo −20%.

> **Condizione per riprenderlo.** La SEV tornerà accurata quando nessun giocatore sarà più
> pivotale, cioè con **più impianti distribuiti fra i membri** — la configurazione in cui
> le coalizioni a valore nullo spariscono. È la condizione da ricontrollare prima di
> portare i numeri di questo metodo in tesi. Fino ad allora il risultato da riportare è
> quello di §16.7, che è comunque un contributo: **misura fino a che punto le
> approssimazioni pensate per comunità omogenee reggano su una comunità con un unico
> prosumer pivotale**.

**Perché invece la MC se la cava (1,07%)?** Perché usa *solo* lo strato `n-1`, dove
l'approssimazione è **esatta per costruzione** (§16.4). Il suo errore non è di
approssimazione dello strato, ma di "un solo strato invece della media degli `n`" — e qui
capita che le proporzioni fra giocatori siano stabili fra gli strati. È in parte
fortuito e **non va generalizzato**: degenera appena nessun consumatore è pivotale
(§16.3).

### 16.9 Verifiche disponibili

- **`opts.validateStrata = true`** (solo `n ≤ 12`) in
  [`stratified_expected_value_cer.m`](stratified_expected_value_cer.m): enumera tutte le
  coalizioni e calcola `μ(i,j)` **vero** (eq. 8), cioè esattamente la grandezza che l'eq.
  12 approssima. Verifica poi che agli strati `0` e `n-1` — dove esiste una sola coalizione
  e l'approssimazione non ha spazio per sbagliare — i due valori **coincidano**, e solleva
  errore altrimenti. È il controllo che separa un errore di **implementazione** (che li
  farebbe divergere) da un limite di **modello** (che si concentra sugli strati
  intermedi). Popola `.muExact` e `.strataBias`. È **attivo in `MAIN.m` §3o**: con 6
  giocatori costa 192 valutazioni di `v`. Stessa logica di `opts.validateDense` nel VLC
  (§7.7).
- **Esito attuale:** scarto `0` allo strato 0, `2,3·10⁻¹³` allo strato `n-1`, fino a
  **+324%** su quelli intermedi. È la firma di un'implementazione corretta con un limite di
  modello.
- **`mean(SEV.muExact, 2)` è lo Shapley esatto** (identità dell'eq. 8): confrontarla con
  `shapley_cer.m` è un cross-check gratuito, e torna a `2,3·10⁻¹³`.
- **`assert` in `MAIN.m` §3o:** `SEV.lastStratumMC == MC.mcRaw`. Vale per l'identità di
  §16.4 e salterebbe se l'utente medio fosse costruito male; è attivo anche senza
  `validateStrata`.
- **`assert` in `MAIN.m` §3q:** i tre metodi hanno lo stesso `v(N)` dello Shapley esatto.
  Senza, la §3q non starebbe misurando l'errore di approssimazione ma un errore di modello.
- **Riproducibilità dell'Adaptive Sampling:** stesso seed → risultati identici; seed
  diverso → risultati diversi. Entrambe verificate.

### 16.10 Mappatura formula → codice

| Formula | Codice |
|---|---|
| `v` di una coalizione, `O(H)` | [`cer_shared_value.m`](cer_shared_value.m) |
| `MC_i = v(N) − v(N\{i})` (eq. 9) | ciclo su `i` in `marginal_contribution_cer.m`, per differenza sugli aggregati |
| Normalizzazione (eq. 10, 13) | `normFactor = vGrand / sum(...)`, esposto in `.normFactor` |
| Utente medio `p₋ᵢ` (eq. 11) | `genAvg = (genComm − genUsers(:,i)) / (n−1)` (e uguale per il carico) |
| `SEV_i` (eq. 12) | doppio ciclo `i` × `j`, `strataMC(i, j+1)` |
| `μ(i,j)` vero (eq. 8) | funzione locale `exact_strata_mc`, solo con `validateStrata` |
| Sigmoide `ε(m)` (eq. C.2) | `epsSig`, precalcolata per tutti gli `M` campioni |
| Probabilità di strato (eq. C.1) | `prob` nel ciclo di campionamento |
| Aggiornamento Welford (eq. C.3-C.6) | blocco `delta`/`hits`/`m2`/`sigma` |
| `RL_i` (eq. C.7) | `rl = mean(muStrata, 2)` |
| `RD` e `RD` media (eq. 16-17) | `MAIN.m` §3q, tabella `Trd` |

**Non implementato: il calcolo esatto per `K` classi** (§4.2 del paper, Algoritmi 1-2).
Serve al paper per costruire il *ground truth* a 200 agenti, raggruppando gli utenti in
poche classi con profilo di domanda **identico** e sfruttando la distribuzione
ipergeometrica multivariata. Da noi sarebbe inerte: i sei profili reali sono tutti diversi,
quindi `K = n` e il metodo degenera nello Shapley esatto che già calcoliamo. Tornerebbe
utile solo con molti utenti replicati per archetipo — che è però anche una delle vie
d'uscita già elencate in [README §13.1](README.md), e andrebbero valutate insieme.

---

## 17. Tri-level EP: proprietà + proporzionale + povertà energetica (Campagna et al. 2024)

File: [`tri_level_ep_cer.m`](tri_level_ep_cer.m), con l'helper
[`lihc_index.m`](lihc_index.m). Riferimento: L. Campagna, G. Rancilio, L. Radaelli,
M. Merlo, *"Renewable energy communities and mitigation of energy poverty: Instruments
for policymakers and community managers"*, **Sustainable Energy, Grids and Networks 39
(2024) 101471**, eq. 11-15, Fig. 7-8, tetto di §4.3.

> ⚠ **Implementazione provvisoria.** Il metodo gira su dati segnaposto: undici ipotesi
> sono attive per difetto, elencate in §17.7. I numeri riportati qui sotto servono a
> descrivere il **comportamento** del modello sulla nostra topologia, non a produrre
> risultati sulla comunità reale.

### 17.1 Perché serviva

È l'unico modello del progetto che misura la povertà energetica con un **indicatore
riconosciuto** invece che con un proxy. L'unico altro che ci prova, la Weighted
Solidarity (§12), costruisce un punteggio a quartili sul costo unitario dell'energia: sui
nostri dati lo spread fra il membro "più povero" e il "più ricco" è del 2,9%, contro il
fattore quattro del suo paper, e la classificazione che ne esce riflette la collocazione
oraria dei consumi, non una vulnerabilità economica.

### 17.2 L'idea: ogni livello alla propria fonte di ricavo

Il gestore della CER ha in mano due flussi distinti. L'incentivo sull'**energia
condivisa** (`R_sh`) nasce dal fatto che qualcuno consumava nella stessa ora in cui
qualcun altro immetteva: è merito dei consumatori. Il ricavo da **vendita in rete**
(`R_inj`) nasce da energia che *nessuno* nella comunità ha consumato: è merito di chi ha
pagato l'impianto.

Il bi-livello del paper (Fig. 7) fa corrispondere ogni livello alla sua fonte — il
proporzionale al primo ricavo, la proprietà al secondo — e ne ricava i pesi dal
**rapporto fra i due ricavi**, il che elimina l'arbitrio. Il tri-livello aggiunge sopra
un prelievo di solidarietà:

```
share_EP   = min(33% ; n% · N_vu)          n% = 1,32% (= 0,66 × 2%)     (eq. 14)
share_rest = 1 − share_EP                                               (eq. 15)

R_tot = R_sh + R_inj

phi_i = share_EP   · R_tot · epKey_i
      + share_rest · ( R_sh · propKey_i + R_inj · ownKey_i )
```

`propKey` viene dall'eq. 11, ora per ora: `Σ_h [ Ec_i,h / Ec_REC,h · Rev_h ] / R_sh`.
La somma si chiude per costruzione, perché `share_EP·R_tot + share_rest·R_tot = R_tot`.

### 17.3 Le tre volte in cui il paper non torna

Ricostruire le formule riga per riga ha fatto emergere tre incoerenze fra il testo
pubblicato e le sue stesse tabelle. Ciascuna richiede una decisione, e ciascuna è scritta
nel codice invece di essere presa in silenzio.

**(a) L'eq. 12 stampa l'unione, il testo dice l'intersezione.** L'equazione usa `∪`, ma
il testo immediatamente sotto dice *"the formula returns a value of 1 if the household
meets **both** conditions"*, e il nome dell'indice — *Low Income* **High** *Cost* —
descrive una congiunzione. Con l'unione, chiunque spenda più della mediana risulterebbe
povero e l'indice si svuoterebbe. Implementato **AND**.

**(b) L'eq. 13 è pubblicata senza gate.** Applicata alla lettera ai dati della loro
Tabella 4 restituisce `0,85` per Old Couple 1, mentre la Tabella 7 riporta `1,00`.
Con il gate sul booleano — l'indice continuo misura la *profondità* solo di chi è già
stato riconosciuto povero — tutta la colonna "25% users PE" si riproduce. È del resto
l'unica lettura possibile di un indice che "vale 1 quando non c'è rischio".

**(c) I due parametri esterni non sono pubblicati, e la soglia dichiarata non torna.**
`P50(s_e)` non compare mai nel testo. È stata ricavata invertendo l'eq. 13 sui due nuclei
inequivocabilmente poveri:

| Nucleo | `(y−s_e)/(2·y*)` | `P50/s_e` richiesto | `P50` implicito | Tab. 7 |
|---|---|---|---|---|
| Old Couple 3 | 0,9933 | 0,5468 | 1.327,6 € | 0,77 |
| Old Couple 4 | 0,9351 | 0,5449 | 1.318,5 € | 0,74 |

I due valori concordano su **≈1.323 €/anno**, ordine di grandezza coerente con l'utente
tipo ARERA (elettricità + gas). Verifica indipendente su un terzo nucleo non usato per la
stima: Young Couple 2 dà `0,794` contro lo `0,79` della tabella.

Ma proprio Young Couple 2 rivela il problema della soglia. Il paper dichiara
`y* = 10.052 €/anno`, e con quel valore Young Couple 2 ha `10.498,12 €` di reddito netto
per percettore — **sopra** la soglia, quindi non povero. Il paper però lo elenca fra i
vulnerabili. L'unica soglia compatibile con tutte e dodici le famiglie sta fra
**10.498,12 e 11.154,34 €/anno**. Il default resta il valore *dichiarato*, per non
truccare una costante in silenzio: `lihc_index` riporta lo scostamento a video invece di
nasconderlo.

### 17.4 Verifica: la Tabella 7 si riproduce

`lihc_index(..., struct('validatePaper', true))` esegue la riproduzione sui dodici nuclei
della Tabella 4. Esito con `P50 = 1323` e `y* = 10052`:

```
  Eq. 13 + gate booleano          : scarto massimo 0.0040 (entro 0.01)
  Scostamento sull'eq. 12         : Young2, con y* = 10052
  Intervallo compatibile          : y* fra 10498.12 e 11154.33
```

Lo scarto massimo (0,0040 su Young Couple 2) sta dentro la tolleranza imposta dai due
decimali con cui il paper riporta la tabella.

### 17.5 L'invariante di efficienza è diverso dagli altri quindici metodi

Il Tri-level EP è l'unico modello del progetto che ripartisce **entrambi** i montepremi,
perché il suo livello di proprietà redistribuisce proprio il ricavo di vendita. Quindi
`S.vGrand = R_sh + R_inj`, non `v(N)` — stessa situazione, e stessa scelta dichiarata,
del Cascading Tree (§11).

Per restare confrontabile si espongono due decomposizioni: `.phiFromShared`, che somma
esattamente a `v(N)`, e `.phiFromSold`, che somma a `R_inj`. È `.phiFromShared` a entrare
in `Tcmp` e nel grafico di confronto di `MAIN.m`: usare `.phi` conterebbe due volte la
vendita, che per tutti gli altri metodi è impilata a parte.

**Test di degenerazione.** Con `opts.nPct = 0` la formula collassa in
`R_sh·propKey + R_inj·ownKey`, cioè **esattamente lo stato attuale del progetto**:
ripartizione proporzionale al consumo del montepremi condiviso, più la vendita
attribuita pro-quota ai proprietari. `MAIN.m` §3r verifica che `.phiFromSold` coincida
con `revSoldPerPlayer` entro `1e-9`. È l'assert più informativo del metodo: se cade, è
rotta la composizione dei livelli, non i dati segnaposto.

### 17.6 Risultati sul caso reale ⚠

Con i dati segnaposto, sui profili orari reali:

| Grandezza | Valore |
|---|---|
| Montepremi da energia condivisa `R_sh` | 2.348,59 € |
| Montepremi da vendita `R_inj` | **4.655,27 €** |
| Peso del livello proporzionale | 34% |
| Peso del livello di proprietà | **66%** |
| Vulnerabili (LIHC) | 1 su 6 (`household_1`, `LIHC_cont = 0,72`) |
| `share_EP` | 1,32% (tetto 33% ben lontano) |

Quattro letture, tutte da rifare quando arriveranno i dati veri:

1. **Il ricavo di vendita è quasi il doppio di quello da energia condivisa.** Il livello
   di proprietà pesa perciò due terzi del montepremi, e con un solo impianto va
   interamente a `small_industry_1`. Nel paper il rapporto è rovesciato — la loro CER è
   dimensionata per massimizzare la condivisione — quindi il metodo qui si comporta in
   modo qualitativamente diverso da come lo descrivono gli autori.
2. **Il livello di proprietà non discrimina.** Un impianto, un proprietario: `ownKey` è
   un vettore indicatore. Il livello acquista significato solo con più impianti o quote
   di cofinanziamento.
3. **`small_industry_1` prende zero dal montepremi condiviso.** Il suo carico residuo è
   nullo proprio nelle ore in cui c'è condivisione, quindi `propKey = 0`. Non è
   un'anomalia del metodo: la Proportional to Consumption (§9) dà lo stesso risultato,
   per la stessa ragione.
4. **La taratura dell'`n%` non si trasporta.** A Teglio `share_EP` valeva ~1.042 € su
   ~26.300 €, cioè ~347 € a testa, che coprivano circa il 100% di una bolletta elettrica
   domestica: il paper ha scelto il 2% *perché* accadesse questo. Da noi la stessa
   percentuale dà ~92 € contro una bolletta di ~409 €, cioè circa il 23%. La conclusione
   non è "il metodo non funziona" ma **"`n%` va ritarato sulla nostra scala"**, ed è un
   risultato, non un fallimento.

**Differenza di governance, che non è un parametro.** A Teglio gli impianti sono del
Comune, su edifici pubblici, in una CER dichiaratamente sociale: chiedergli di cedere una
quota ai vulnerabili è coerente col suo mandato. Qui lo stesso livello preleva da una
piccola industria **privata**, e il prelievo di solidarietà diventa una richiesta di
natura completamente diversa. Il codice lo implementa comunque, ma il risultato numerico
presuppone un accordo che nel nostro caso non esiste.

### 17.7 Le undici ipotesi, e come ritrovarle

Tutti i dati provvisori vivono **dentro `tri_level_ep_cer.m`**, non in `MAIN.m`: un unico
file da aprire quando arrivano i dati veri. Tre meccanismi ridondanti perché l'elenco non
si perda:

- `grep -n "IPOTESI" tri_level_ep_cer.m` — i marcatori nel codice;
- `help tri_level_ep_cer` — il registro con cosa si assume, perché, con che valore e la
  procedura per rimuoverla;
- l'**avviso a ogni esecuzione**, che elenca *solo* le ipotesi ancora attive: una sparisce
  appena il dato vero viene passato via `opts`. La stessa lista è in `S.assumptions`.

| # | Ipotesi | Valore provvisorio | Come si rimuove |
|---|---|---|---|
| 1 | Reddito familiare | Tab. 4 del paper, per archetipo | open data MEF × classi d'età ISTAT |
| 2 | Spesa gas | 15.000 kWh/anno × 0,12 €/kWh | bollette gas reali |
| 3 | Markup retail dal PUN | ×2,5 | tariffa di fornitura reale |
| 4 | `P50` | 1.323 €/anno | mediana ARERA/ISTAT |
| 5 | `y*` | 10.052 €/anno (Tab. 7 ne richiede ~11.000) | chiarimento dagli autori |
| 6 | AND al posto di `∪` (eq. 12) | — | correzione al paper, non ipotesi |
| 7 | Gate booleano sull'eq. 13 | — | correzione al paper, non ipotesi |
| 8 | Quote di proprietà dalla produzione | 100% `small_industry_1` | tabella di cofinanziamento |
| 9 | Carico residuo come `Ec` dell'eq. 11 | `loadForShare` | scelta di modellazione |
| 10 | `N_inc` | 2 per ogni nucleo | anagrafica reale |
| 11 | `n%` e tetto | 1,32% e 33% | ritaratura sulla nostra scala |

Le due che pesano di più sono la **1** e la **10**, e per la stessa ragione: nella
Tabella 4 le spese energetiche dei quattro Old Couple sono quasi identiche, ed è solo il
reddito — diviso per i percettori — a separare i poveri dai non poveri. Su Old Couple 3
la classificazione si decide per **67 euro**: con `N_inc = 2` il reddito netto per
percettore è 9.985 € e il nucleo è vulnerabile, con `N_inc = 1` sale a 19.970 € e non lo
è più. L'assegnazione `N_inc = 2` è scritta nell'etichetta degli archetipi CHR02
("with work") e CHR03 ("both at work"), ma è **assunta** per la coppia di pensionati
CHR54 — proprio l'archetipo con la maggiore probabilità a priori di essere povero.

La **2** merita una nota, perché sembra più debole di quanto sia. Il perimetro dell'eq. 12
è la spesa energetica *totale*: con la sola elettricità nessuna famiglia supera `P50`, il
livello EP si spegne e il tri-livello coincide col bi-livello. Il gas però non è
inventato — sono i 15.000 kWh/anno del `house_type` HT06 già dichiarato in
[`CER_LoadProfiles/config/simulation_config.yaml`](CER_LoadProfiles/config/simulation_config.yaml),
e per confronto i nuclei di Teglio consumavano 1.481 m³ ≈ 15.850 kWh. Vale anche la pena
notare che **il paper stesso non misurava il gas**: *"gas consumption is typical for
mountain areas"*. Dichiararlo da statistica non è un peggioramento rispetto al paper — è
il suo stesso metodo.

### 17.8 Verifiche disponibili

- **Riproduzione della Tabella 7** — `lihc_index(..., 'validatePaper', true)`, §17.4.
- **Degenerazione a `n% = 0`** — assert in `MAIN.m` §3r, §17.5.
- **Efficienza** — assert interni e `report_allocation`, sia col tetto spento
  (`vGrand = R_tot`) sia acceso (`vGrand = R_tot − cashFund`).
- **Decomposizione per montepremi** — `Σ phiFromShared = v(N)`, `Σ phiFromSold = R_inj`.
- **Casi limite coperti** — `N_vu = 0`; vendita positiva senza produzione (solleva
  `ownershipUndefined`); comunità di soli non domestici; input con `NaN`/`Inf` (solleva
  `nonFiniteInput`); `useContinuous = true`; tetto bolletta attivo (nessuno supera la
  propria bolletta e l'efficienza resta esatta sul montepremi ridotto).

### 17.9 Mappatura formula → codice

| Formula del paper | Dove |
|---|---|
| eq. 11, chiave proporzionale oraria | `tri_level_ep_cer.m`, blocco "Livello 2" |
| eq. 12, LIHC booleano (con AND) | `lihc_index.m`, `isEP = highCost & lowIncome` |
| eq. 13, LIHC continuo (con gate) | `lihc_index.m`, `cont(isEP) = min(1, ...)` |
| eq. 14-15, `share_EP` / `share_rest` | `tri_level_ep_cer.m`, blocco "Eq. 14-15" |
| Fig. 7, pesi bi-livello `R_sh`/`R_inj` | `tri_level_ep_cer.m`, blocco "Composizione" |
| §4.3, tetto del 100% e fondo di comunità | `tri_level_ep_cer.m`, `opts.billCap` → `.cashFund` |

---

## 18. Indici di valutazione dell'equità

Le sezioni §2-§17 spiegano **come** i sedici metodi ripartiscono. Questa spiega **come si
giudica** una ripartizione. È l'unica sezione che non descrive un modello: descrive dieci
misure, tutte calcolate in `MAIN.m` §3t su tutti e sedici i metodi.

Fonti:

- **[D]** M. F. Dynge, U. Cali, *Distributive energy justice in local electricity markets:
  Assessing the performance of fairness indicators*, **Applied Energy 384 (2025) 125463**
  — eq. 11, 12, 15, 16, 17, 18, 19.
- **[C]** V. Casalicchio, G. Manzolini, M. G. Prina, D. Moser, *From investment
  optimization to fair benefit distribution in renewable energy community modelling*,
  **Applied Energy 310 (2022) 118447** — eq. 10, 12-13, 14.
- **[V]** G. Volpato, G. Carraro, E. Dal Cin, S. Rech, *On the Different Fair Allocations
  of Economic Benefits for Energy Communities*, **Energies 17 (2024) 4788** — eq. 23
  (l'eq. 21 dello stesso paper, il Price of Fairness, è **esclusa**: §18.8).

### 18.0 Tre domande diverse

I dieci indicatori non misurano la stessa cosa in modi diversi. Rispondono a **tre domande
distinte**, che possono dare risposte opposte:

| Gruppo | Domanda | Dove |
|---|---|---|
| MinMax, QoS, EI, Gini, Jain | quanto è **uniforme** la ripartizione | §18.4 |
| Fairness Index, σ | quanto è vicina al **merito** di ciascuno | §18.5 |
| Eccesso di coalizione | se **regge**: qualcuno ha convenienza a uscire? | §18.6 |

L'Equal Split è primo sulla prima domanda (`EI = 1.00`, `Gini = 0.00`) e ultimo sulla terza
(eccesso `+606 €`, nove sottogruppi vorrebbero uscire). Il Nucleolo fa l'opposto:
`EI = 0.45`, il peggiore del lotto, ma nessuna coalizione scontenta. **Guardare una colonna
sola porta a conclusioni sbagliate**, ed è il motivo per cui la mappa di calore di
[`plot_fairness_indicators.m`](plot_fairness_indicators.m) ha tre pannelli separati invece
di una scala unica.

### 18.1 Il problema: due mercati diversi

Gli indicatori di **[D]** nascono per un *local electricity market* peer-to-peer: ogni ora
il market clearing decide chi compra da chi, e c'è un prezzo locale `λ_t` diverso dal
prezzo di rete. La nostra CER è un'altra cosa — condivisione **virtuale**: fisicamente
tutti prelevano dalla rete al prezzo retail, l'impianto immette, e l'incentivo sull'energia
condivisa arriva *ex post*. La traduzione delle grandezze è quindi il primo passo, non un
dettaglio:

| Grandezza di [D] | Significato | Nella CER |
|---|---|---|
| `g_imp(t,i)` | prelievo da rete | `loadForShare(t,i)` — il carico **residuo**: nella condivisione virtuale tutto ciò che non è autoconsumato dietro al contatore viene prelevato |
| `g_exp(t,i)` | immissione in rete | `sold(t) · shareGen(t,i)` |
| `x_LM(t,i)` | venduto localmente | `shared(t) · shareGen(t,i)` |
| `i_LM(t,i)` | comprato localmente | `SH(t,i)`, l'energia condivisa **attribuita** |
| `b_ch`, `b_dis` | carica/scarica batteria | **assenti** dal modello, valgono 0 |
| `λ_t` | prezzo di mercato locale | **non esiste** → vedi §18.6 |

Nota che `x_LM + g_exp = genForShare` per costruzione, perché `shared + sold = genAgg`.

### 18.2 Da euro a kWh: l'energia implicita

MinMax e QoS misurano **kWh**. Ma quattordici dei sedici metodi producono solo **euro**:
solo Pearson Key e Pearson-Sharing Rate (§13-§14) ripartiscono nativamente energia e
espongono una `S.SH` oraria. Serve quindi una regola per sapere a quanti kWh corrisponda
la quota monetaria di ciascuno.

La regola scelta riusa l'helper che già esiste:

```matlab
SH = allocate_shared_energy(loadForShare, genPVSurplus, repmat(phi.', H, 1));
```

Pesi **costanti nel tempo** pari a `φᵢ`: chi prende il 30% del montepremi si vede
attribuire il 30% dell'energia condivisa, ora per ora, con il cap fisico
`SH(t,i) ≤ loadForShare(t,i)` e la garanzia `Σᵢ SH(t,i) = shared(t)` che
[`allocate_shared_energy.m`](allocate_shared_energy.m) già fornisce (§13.4). Nessuna
matematica nuova.

`MAIN.m` §3t riporta, per i due metodi che l'energia oraria ce l'hanno davvero, lo scarto
fra implicita e nativa: **circa l'1%** su entrambi. È una diagnostica, non un `assert` —
uno scarto grande direbbe che la chiave oraria del metodo è molto diversa da una chiave
piatta, che è informazione sul metodo, non un errore.

### 18.3 Aggregazione temporale: perché non ora per ora

Gli indicatori **non** si calcolano sull'ora. Nella maggior parte delle ore qualcuno ha
prelievo nullo e il MinMax collasserebbe a zero. **[D]** lavora su volumi mensili (Fig. 3)
e i suoi esempi numerici lo confermano: §6.1.1 ricava `MinMax = 0.11` da «10.5 e 93
kWh/mese», cioè `10.5/93`. Analogamente il «MinMax originale» di Fig. 4 vale 0.13–0.17,
che è esattamente `5/32` sui consumi annui di Tab. 3.

Quindi:

- **MinMax** → rapporto dei volumi **annui**. Che è anche il rapporto dei volumi mensili
  medi (dividere entrambi per 12 non cambia nulla) ed è letteralmente la somma su `t` delle
  eq. 16-17.
- **QoS** → indice di Jain calcolato su **ogni mese** e mediato sui dodici, come dice la
  didascalia della Fig. 5.
- **EI** → annuale, come la Fig. 8.

Di ogni indicatore si espone anche il vettore mensile (`.*Monthly`), per non nascondere la
scelta di aggregazione.

### 18.4 I sette indicatori di [D]

| Indicatore | Eq. | Formula |
|---|---|---|
| MinMax originale | 11 | `minₕ(gᵢₘₚ) / maxₕ(gᵢₘₚ)` |
| MinMax prosumer | 16 | `minₕ(sₕ) / maxₕ(sₕ)` con `sₕ = Σₜx_LM / Σₜ(x_LM + g_exp)`, solo prosumer |
| MinMax consumer | 17 | `minₕ(Σₜ i_LM) / maxₕ(Σₜ i_LM)`, solo consumatori |
| QoS originale | 12 | `Jain(x_LM + i_LM)` su tutti |
| QoS nuovo | 18 | `ρ·Jain(sₕ sui prosumer) + μ·Jain(i_LM sui consumatori)` |
| EI originale | 15 | `1 − Gini(yₕ)` |
| EI nuovo | 19 | `ρ·(1 − Gini(yₕ/y_noLEM sui prosumer)) + μ·(1 − Gini(yₕ sui consumatori))` |

con `ρ = P/n` (quota prosumer) e `μ = C/n` (quota consumatori).

**Scelte registrate come ipotesi** (`.assumptions`, pattern di §17):

1. `yₕ = φᵢ`, la quota CER, **esclusa** la vendita dell'eccedenza: quella esisterebbe
   comunque anche senza CER (ritiro dedicato), includerla gonfierebbe il prosumer. Per il
   Tri-level EP si usa `phiFromShared`, coerentemente con `Tcmp` (§17).
2. `y_noLEM` = costo annuo da rete in **MONORARIA** (`costMat`, calcolato in `MAIN.m` §3a),
   la stessa modalità con cui `weighted_solidarity_cer` stima il costo unitario (§12.2).
3. L'energia implicita di §18.2.
4. La lettura dell'eq. 16.

**Ambiguità dell'eq. 16.** La quota di surplus si legge sia come *rapporto di somme*
`Σₜx_LM / Σₜ(x_LM+g_exp)`, sia come *somma di rapporti* `Σₜ[x_LM/(x_LM+g_exp)]`. Il testo
di §4.2.5 di **[D]** («the prosumer selling the smallest **share** of its surplus»)
sostiene la prima, che è il default; `opts.shareMode = "sumOfRatios"` dà l'altra.

**Gini e Jain esposti a sé stanti.** `EI = 1 − Gini` e `QoS = Jain`: tenere i due nuclei
impliciti li renderebbe inutilizzabili, e sono le grandezze con cui ragiona la
letteratura. `gini_index.m` è lo stesso file usato da `weighted_solidarity_cer.m` per la
sua eq. 2.8 — una sola definizione, così i due usi non possono divergere.

### 18.5 Il Fairness Index di [C]

Misura quanto un metodo si discosti da una distribuzione di **riferimento** fondata sul
contributo di ciascun membro:

```
BCᵢ  = OPT − OPT₋ᵢ = v(N) − v(N∖{i})                              (eq. 12)
Dcdᵢ = BCᵢ / Σₗ BCₗ                                               (eq. 13)

FI = Σᵢ|Dᵢ − Dcdᵢ| / Σᵢ|Dwᵢ − Dcdᵢ|     se m = m_tot
FI = m_tot − m                          altrimenti                (eq. 14)
```

dove `m` è il numero di membri con quota positiva.

**Il contributo era già in casa.** `BCᵢ = v(N) − v(N∖{i})` è *esattamente* il contributo
marginale «ultimo» dell'eq. 9 di Cremers (§16.3), cioè `MC.mcRaw`. E la normalizzazione
dell'eq. 10 di Cremers **coincide** con l'eq. 13 di Casalicchio. Ne segue l'auto-verifica
più forte disponibile: se tutti i `BCᵢ > 0`, la **Marginal Contribution ha `FI = 0`
esatto**. Sulla community di default l'assert passa (`FI ≈ 9·10⁻¹⁷`). Passa anche per il
Nash Bargaining, che è proporzionale allo stesso contributo — e infatti le due colonne di
`Tcmp` sono identiche.

#### Derivazione di `Dw`, che il paper non dà

**[C]** descrive `Dwᵢ` solo a parole («the worst case… maximizing the denominator»), senza
formula. La deriviamo.

`f(D) = Σᵢ|Dᵢ − Dcdᵢ|` è **convessa** in `D`, e il dominio è il simplesso
`{Dᵢ ≥ 0, ΣDᵢ = 1}`. Il massimo di una funzione convessa su un politopo compatto sta in un
**vertice**, e i vertici del simplesso sono i versori `e_k`. In `e_k`:

```
f(e_k) = |1 − Dcd_k| + Σ_{i≠k} |Dcdᵢ|
```

Basta prendere il `k` che massimizza. Poiché `Σᵢ|Dcdᵢ|` è costante, equivale a

```
denom = 1 + Σᵢ|Dcdᵢ| + max_k( −Dcd_k − |Dcd_k| )
```

che **con tutti i `Dcdᵢ ≥ 0`** — il nostro caso — si riduce a `denom = 2·(1 − minᵢ Dcdᵢ)`.
La forma generale copre anche i contributi negativi, che il paper dichiara ammessi.

**Corollario utile:** il caso peggiore è un vertice, quindi ha `m = 1` e finisce nella
*seconda* branca. Ne segue che nella prima branca `FI < 1` **strettamente** — il che
spiega perché **[C]** scriva «0 ≤ FI < 1» e non «≤ 1». `fairness_index_bm.m` lo verifica
con un `assert`.

#### Le due branche non sono confrontabili

`FI = 1.00` può voler dire due cose opposte:

- nella branca del **rapporto**: distanza quasi massima dal riferimento;
- nella branca **intera**: un solo membro lasciato a quota zero.

Sulla community di default cinque metodi (Proportional to Consumption, Pearson Key,
Pearson-Sharing Rate, Similarity-Utilization, Tri-level EP) danno `φ = 0` al prosumer e
finiscono quindi nella branca intera con `FI = 1` esatto. Per questo `Tfair` porta la
colonna `QuoteNulle` e `MAIN.m` stampa una nota: senza, la tabella si legge male.

#### Scostamento dal paper

**[C]** registra i risparmi **al netto dei costi di investimento** (§2.5). `MAIN.m` non ha
i costi di investimento per membro — stanno in `optimizer_PV.m`, che è uno script a sé —
quindi `Dᵢ` si calcola sui benefici lordi. È l'unico vero **buco dati** dell'intera §18, ed
è registrato in `.assumptions`.

#### Auto-test

La Tab. 7 di **[C]** (`FI = 0.198/0.306/0.062/0.186/0.074` per i BM A-E) **non** è
riproducibile: i `Dᵢ` e `Dcdᵢ` per singolo membro stanno solo nella Fig. 13, che è un
grafico. `opts.validateSelf` (attivo di default) verifica quindi la formula su casi
costruiti a penna — denominatore, metodo coincidente col riferimento, ripartizione
uniforme, branca intera, contributi negativi.

### 18.6 Eccesso di coalizione (eq. 23 di [V])

```
e_S = v(S) − Σ_{i∈S} xᵢ                                            (eq. 23)
```

Per **ogni** sottogruppo `S` confronta due cose: quanto quel sottogruppo genererebbe da
solo, uscito dalla CER (`v(S)`), e quanto i suoi membri ricevono restandoci dentro. Se la
differenza è positiva, hanno un motivo economico per andarsene.

#### Perché serve: misura una cosa che gli altri non guardano

Gli indicatori di §18.4 misurano quanto è **uniforme** la ripartizione; il Fairness Index
di §18.5 quanto è vicina al **merito**. Nessuno dei due dice se **regge**. E la differenza
non è teorica:

| | EI orig | Gini | Eccesso max | Coalizioni instabili |
|---|---:|---:|---:|---:|
| **Equal Split** | **1.00** | **0.00** | **+606 €** | **9** |
| **Nucleolo** | 0.45 | 0.55 | −90 € | 0 |

L'Equal Split è la ripartizione più equa possibile secondo la prima domanda, e la meno
stabile di tutte secondo la terza. Il Nucleolo fa l'opposto. È esattamente l'argomento
della Fig. 10 di **[V]**: lo Shapley lascia coalizioni scontente, il Nucleolo no.

#### Un esempio coi numeri

Equal Split: `v(N) = 2 348.59 €` diviso in sei parti da `391.43 €`. Prendi il sottogruppo
`{office, small_industry, retail}` — le tre aziende senza le tre famiglie:

```
quanto ricevono dentro la CER   3 × 391.43  =  1 174.30 €
quanto genererebbero da sole    v(S)        =  1 780.80 €
                                             ─────────────
eccesso                                        + 606.50 €
```

Hanno 606 € di ragioni per uscire. Col Nucleolo l'eccesso massimo è `−90.15 €`: perfino la
coalizione più scontenta (`household_1` da sola) ci guadagna 90 € a restare.

#### Attenzione al segno: opposto a quello del Nucleolo

Qui si usa la convenzione di **[V]**: eccesso **positivo** = la coalizione vuole uscire.
[`nucleolus_cer.m`](nucleolus_cer.m) e
[`variance_least_core_cer.m`](variance_least_core_cer.m) riportano invece il **surplus**
della coalizione più scontenta (§3.1, §7.2):

```
surplus_S = Σ_{i∈S} xᵢ − v(S) = −e_S
```

quindi `EX.maxExcess = −Nu.thetaMin`. Sono la stessa grandezza letta al contrario, ed è la
**verifica incrociata gratuita** del modulo: `MAIN.m` §3t ne ha due `assert`, uno sul
Nucleolo e uno sul Variance Least Core, più un terzo che impone al Nucleolo di risultare il
metodo con eccesso minimo — è quello che minimizza per costruzione.

#### Cosa aspettarsi su questa topologia

A differenza degli indicatori energetici (§18.9, punto 4) questo **discrimina fortemente**,
da `−90 €` a `+607 €`. Il motivo è che guarda i soldi, e i soldi sono l'unica cosa che i
sedici metodi spostano davvero.

Nota che `v({i}) = 0` per ogni singolo giocatore (netting dietro al contatore, §1.2): da
solo nessuno condivide nulla. L'eccesso di un singleton vale quindi `−φᵢ`, negativo per
chiunque riceva qualcosa — la **razionalità individuale è garantita** da qualunque
ripartizione non negativa. I problemi vengono dalle coalizioni **intermedie**, quelle che
contengono il prosumer più un sottoinsieme di consumatori: nella tabella sopra la
coalizione peggiore dell'Equal Split è proprio `{office, small_industry, retail}`.

#### Costo e scalabilità

Enumera le `2ⁿ` coalizioni, quindi si ferma verso i 20 membri (`opts.maxPlayers`). **Non
aggiunge un limite nuovo**: Shapley, Nucleolo e Variance Least Core hanno già lo stesso
vincolo — è il bloccante di [README §14.1](README.md). Con `n ≤ 20` il costo è
trascurabile, e `opts.v`/`opts.A_inc` permettono di riusare una `v(S)` già calcolata.

### 18.7 Gini di eterogeneità (eq. 10 di [C])

```
G = (1 − Σ_k f_k²) · m / (m − 1)
```

**Non è un Gini di reddito**, malgrado il nome usato nel paper: è un indice di diversità di
Simpson normalizzato, e misura quanto sono **varie le tipologie** dei membri, non quanto è
diseguale la ripartizione. In **[C]** serve a spiegare perché comunità più eterogenee
sfruttino meglio il Demand Side Management (`G = 0.83` contro `G = 0.71`).

- `G = 0` → tutti i membri della stessa tipologia (massima omogeneità).
- `G = 1` → tutte le tipologie distinte, un membro ciascuna. È il punto in cui l'indice
  **smette di discriminare**.

La tipologia si ricava di default dal nome utente togliendo indice e suffisso
(`household_2_kWh → household`), ottenendo la categoria di consumo: sulla community di
default `f = [1/6, 1/6, 1/6, 3/6]` e quindi **`G = 0.80`**. La granularità **fine** — i tre
template LPG distinti di `simulation_config.yaml` più i tre use case RAMP — si passa con
`opts.memberTypes`, ma su sei membri tutti distinti dà `G = 1.00` esatto, cioè degenera:
per questo il default è la categoria grossolana. La scelta è registrata come ipotesi.

### 18.8 Due indicatori esclusi, con la ragione

**QoE (eq. 13-14 di [D]) — non implementato.** Il prezzo percepito dell'eq. 13 richiede
`λ_t`, il prezzo di mercato locale. In una CER a condivisione virtuale non esiste: non c'è
nessun prezzo al quale i membri si scambino energia fra loro. Si potrebbe inventare un
surrogato (costo unitario netto annuo per utente), ma sarebbe un'altra grandezza con lo
stesso nome. **[D]** stesso non propone modifiche al QoE e ne rinvia la valutazione a
meccanismi di prezzo con prezzi differenziati per partecipante (§6.2.1).

**Price of Fairness — non implementato.** Riferimento: **[V]**, eq. 21 — cioè lo *stesso
paper* da cui viene l'eccesso di coalizione di §18.6. Di quel lavoro si prende l'eq. 23 e
si lascia l'eq. 21, e vale la pena capire perché:

```
POF = (u^incr,tot,SW − u^incr,tot,NB) / u^incr,tot,SW · 100 [%]
```

La formula è banale, ma le due grandezze che confronta vengono da **due ottimizzazioni di
esercizio diverse** dello stesso modello: `SW` massimizza il beneficio totale (eq. 18),
`NB` massimizza il prodotto di Nash (eq. 19-20, equivalente a `max Σᵢ log uᵢ`). Le variabili
decisionali sono i flussi P2G/P2P e la **domanda spostabile** (PBDR, eq. 6-8). Nel loro
caso studio il totale scende da €241 a €238, e quel 1.35% è il PoF.

Nel nostro modello quelle variabili **non esistono**:

- `shared(t) = min(Σgen, Σload)` è deterministico — nessun clearing da ottimizzare;
- l'incentivo `P_CER_h` è **uniforme fra i membri** — in Volpato il compromesso nasce
  proprio dal fatto che i prezzi P2P e P2G sono diversi, quindi *chi* scambia e *quando*
  cambia il totale in euro anche a energia fissa;
- la domanda è rigida — niente load shifting.

Quindi `u^tot,SW = u^tot,NB` e **`PoF ≡ 0` per costruzione**, per tutti e sedici i metodi.
Un numero che non porta informazione. Per renderlo significativo servirebbe aggiungere una
**leva operativa** — load shifting (il PBDR di Volpato eq. 6-8, o il `SinkDSM` che
Casalicchio usa in **[C]** §2.1) oppure un accumulo — cioè un nuovo livello del modello
energetico, non un indicatore. Da tenere presente se in futuro si aggiunge il DSM: la
stessa leva servirebbe a entrambi i paper.

> Attenzione a non confondersi: il nostro
> [`nash_bargaining_cer.m`](nash_bargaining_cer.m) (§1) è una regola di **ripartizione** in
> forma chiusa, non l'ottimizzazione NB dell'esercizio dell'eq. 19 di Volpato.

### 18.9 Leggere i numeri: quattro degenerazioni strutturali

Non sono bug. Sono proprietà del modello, dello stesso tipo del ribaltamento di graduatoria
riportato in §16.9 per la Stratified Expected Value: vanno riportate, non nascoste.

**1. Un solo prosumer.** `MinMax_pro = 1` e `Gini` dei prosumer `= 0` per definizione, quindi
il termine prosumer di `EI_new` vale `ρ` a prescindere dal metodo. Gli indici lato prosumer
non dicono nulla finché l'impianto è uno solo.

**2. Il lato prosumer del QoS nuovo vale 1 anche con più impianti.** Nella CER la quota
condivisa dell'immissione del prosumer `i` è

```
shared(t)·shareGen(t,i) / genForShare(t,i) = shared(t) / genAgg(t)
```

cioè **la stessa per tutti i prosumer**, perché l'attribuzione è pro-quota sulla
produzione. Jain di un vettore costante vale 1. Nel mercato di **[D]** è il market clearing
a decidere chi vende localmente, quindi lì varia. Non è un difetto: è il modello che, lato
prosumer, è equo *per costruzione*.

**3. Il MinMax originale è identico per tutti e sedici i metodi** (0.1767). I flussi fisici
di una CER non cambiano al cambiare di chi prende i soldi: solo il denaro si sposta. È la
versione estrema della critica che **[D]** muove all'indicatore («almost equal values for
all cases», §6.1.1). `MAIN.m` §3t ha un `assert` che lo verifica, e lo riporta una volta
sola come proprietà della comunità.

**4. Anche `MinMax_con`, `QoS` e `Jain` variano pochissimo fra i metodi — e questo è il
risultato più importante della sezione.** Nelle ore in cui l'immissione copre l'**intero**
carico residuo della comunità (`Einj ≥ Σload`), `allocate_shared_energy` prende il ramo
banale e assegna a ciascuno esattamente il proprio carico: la chiave di ripartizione, che
sia Equal Split o Shapley, non ha voce in capitolo. Sulla community di default:

| | valore |
|---|---|
| Ore con condivisione possibile | 3 223 |
| di cui **sature** (`Einj ≥ Σload`) | 2 762 — **85.7%** |
| Energia condivisa annua | 18 329 kWh |
| maturata in ore sature | 16 740 kWh — **91.3%** |
| **Energia contendibile** | **1 590 kWh — 8.7%** |

Solo su quel 8.7% i metodi si differenziano, ed è per questo che `MinMax_con` sta fra
0.2098 e 0.2177 su tutti e sedici. La causa è la topologia: un impianto da 20 kWp su un
edificio industriale produce un surplus enorme rispetto al carico residuo degli altri
cinque membri.

**Conseguenza operativa:** con `contendibleShare` così basso, gli indicatori **energetici**
descrivono la comunità più che il metodo. A discriminare sono quelli **economici** — `EI`
va da 0.45 (Nucleolo) a 1.00 (Equal Split), il `Gini` da 0 a 0.55. `MAIN.m` §3t stampa
`contendibleShare` a ogni esecuzione proprio perché le colonne quasi costanti non vengano
scambiate per un errore di calcolo.

### 18.10 Mappatura formula → codice

| Formula | Codice |
|---|---|
| eq. 11, 16, 17 (MinMax) | `fairness_indicators_lem.m`, `local_minmax` + `local_share_sold` |
| eq. 12, 18 (QoS) | idem, ciclo sui dodici mesi + [`jain_index.m`](jain_index.m) |
| eq. 15, 19 (EI) | idem, `1 - gini_index(...)`, pesi `ρ`/`μ` |
| `i_LM` implicita da `φ` | `allocate_shared_energy(loadUsers, genAgg, repmat(phi.', H, 1))` |
| eq. 12-13 ([C], contributo) | `MC.mcRaw` di [`marginal_contribution_cer.m`](marginal_contribution_cer.m) |
| eq. 14 ([C], FI) | `fairness_index_bm.m`, due branche + `local_worst_distribution` |
| eq. 10 ([C], eterogeneità) | [`gini_heterogeneity.m`](gini_heterogeneity.m) |
| eq. 23 ([V], eccesso) | [`coalition_excess.m`](coalition_excess.m), su `v` e `A_inc` di [`cer_coalition_values.m`](cer_coalition_values.m) |
| Orchestrazione, tabella, grafico | `MAIN.m` §3t + [`plot_fairness_indicators.m`](plot_fairness_indicators.m) |

---

## Appendice A — Metodi valutati e non implementati

Questa appendice raccoglie i metodi di ripartizione letti e valutati per il progetto ma
**deliberatamente non implementati**, con le ragioni della scelta e le condizioni alle
quali varrebbe la pena riprenderli. Serve a distinguere ciò che non è stato fatto per
scelta da ciò che non è stato fatto per dimenticanza.

### A.1 PDM3 e PDM4 — Basilico et al. (2025)

Riferimento: P. Basilico, A. Biancardi, I. D'Adamo, M. Gastaldi, T. Yigitcanlar,
*Renewable energy communities for sustainable cities: Economic insights into subsidies,
market dynamics and benefits distribution*, Applied Energy 389 (2025) 125752 (eq. 8-24).

#### Cosa sono

Due modelli di ripartizione (*profit distribution models*) per una REC composta da
**renewable self-consumers (RSC)**, cioè co-proprietari di un impianto condiviso. Il
valore da dividere è l'**NPV dell'investimento** nell'impianto. Entrambi condividono lo
stesso blocco di calcolo (eq. 8-16) e differiscono solo nel peso finale:

```
ω_avg     = media dei tassi di autoconsumo dei membri          (eq. 8)
E_PSC(j)  = E_p(j) · min(ω_avg, ω_self,c(j))     autoconsumo "capped" alla media (eq. 10)
E_PNSC(j) = E_p(j) · min(ω_avg, 1 − ω_self,c(j)) vendita "capped"                (eq. 11)
E_EX(j)   = E_p(j) − E_PSC(j) − E_PNSC(j)        eccedenza destinata allo scambio interno

OB(j) = E_PSC·p_c + [S_u·E_PSC + S_u·ΣE_EX/N] + E_PNSC·p_s + 0.5·E_EX·p_ex + ΣS_EX·ω_v(j)
        └ bolletta ┘ └────── incentivo ──────┘ └ vendita ┘ └── scambio ──┘ └── premio ──┘
```

- **PDM3** (eq. 17-19): `ω_v(j) ∝ p_ex / p_p(j)`, dove `p_p(j)` è il prezzo di scambio che
  ciascun membro **propone** in fase di statuto. Simula un'asta: chi propone meno prende
  di più. Il paper ricava i quattro profili da un sondaggio su 276 cittadini italiani.
- **PDM4**: `ω_v(j)` deriva dalla **fascia di reddito** dichiarata, con pesi (0,40 / 0,30 /
  0,20 / 0,10 dal più povero al più ricco) che il paper stesso definisce *"subjective"*.

#### Perché sono stati valutati

Appartengono alla stessa famiglia *performance-based* dei metodi §13-§15, sono recenti
(2025), sviluppati sul contesto normativo italiano, e affrontano esplicitamente la
povertà energetica — lo stesso tema del Weighted Solidarity (§12) ma con un meccanismo
diverso.

#### Perché NON sono stati implementati

**(a) Rispondono a una domanda diversa dagli altri modelli.** I quindici metodi del
progetto dividono `v(N)`, l'incentivo CER sull'energia condivisa. PDM3/PDM4 dividono il
**ritorno di un investimento in comproprietà** tra co-investitori: le voci interne
(risparmio in bolletta, ricavo da vendita, incentivo, scambio) sono le componenti del
rendimento di un impianto. Si può forzare `v(N)` al posto dell'NPV — la formula lo
consente, perché delle `OB(j)` si usa solo il rapporto `OB(j)/ΣOB` — ma resta un modello
di *quotisti*, non di membri di una CER a proprietà singola.

**(b) La topologia della nostra comunità è incompatibile.** Nelle formule un membro entra
**solo** attraverso `E_p(j)` (la sua quota di produzione) e `ω_self,c(j)` (il suo tasso di
autoconsumo): **il suo consumo non compare mai da solo**. Il paper può permetterselo
perché tutti e quattro i suoi membri sono co-proprietari; il consumatore puro compare solo
in §5.3, trattato *fuori* dal modello con una formula a sé (eq. 24) che gli assegna un
risparmio fisso.

Da noi c'è un impianto solo, di `small_industry_1`, e cinque consumatori puri. Con le
quote di proprietà reali si ottiene `E_p = [0, 101.884, 0, 0, 0, 0]` kWh, quindi per i
cinque consumatori `E_PSC = E_PNSC = E_EX = 0` e restano solo due voci — la quota
collettiva dell'incentivo (uguale per tutti) e il premio dal peso esterno:

| Giocatore | bolletta | vendita | scambio | incentivo | premio | **quota** |
|---|---:|---:|---:|---:|---:|---:|
| office_1 | 0 | 0 | 0 | 1.882 € | 830 € | **11,450 %** |
| small_industry_1 | 797 € | 756 € | 4.980 € | 2.763 € | 830 € | **42,749 %** |
| retail_1 | 0 | 0 | 0 | 1.882 € | 830 € | **11,450 %** |
| household_1 / 2 / 3 | 0 | 0 | 0 | 1.882 € | 830 € | **11,450 %** ciascuno |

I cinque consumatori ricevono quote **identiche a zero cifre decimali** (spread misurato:
`0,00e+00` punti percentuali) pur avendo consumi annui da 3.401 a 13.884 kWh e profili
completamente diversi. L'unica cosa che potrebbe distinguerli sarebbe il placeholder di
prezzo o di reddito inventato da noi. Su cinque membri su sei, **il metodo non leggerebbe
i dati del progetto**.

**(c) Tre input su quattro non sono derivabili dai nostri dati.**

| Input | Stato |
|---|---|
| `p_p(j)` prezzo di scambio proposto | Non esiste. Nel paper è la dichiarazione di persone reali in fase statutaria |
| fascia di reddito + pesi | Non esiste. Dichiarata in statuto, pesi soggettivi |
| `p_c` prezzo di acquisto retail | Abbiamo il PUN all'ingrosso (0,116 €/kWh), non una bolletta (0,25-0,35 €/kWh) |
| quote di proprietà | Le abbiamo, ma sono quelle "sbagliate" per il metodo (vedi (b)) |

C'è una differenza qualitativa rispetto ai placeholder già tollerati nel progetto
(`[MEMBRI].P_prel_kW`, §10.5): la potenza impegnata **esiste** ed è scritta su ogni
bolletta, va solo recuperata. Il prezzo proposto in asta è invece l'esito di una procedura mai
avvenuta, in una REC che non esiste ancora: non è un dato mancante, è un dato non
definibile per una comunità simulata.

**(d) Corollario: la nostra forbice di prezzo annulla il meccanismo di PDM3.** Uno scambio
interno ha senso solo se `p_s < p_ex < p_c`, altrimenti una delle due parti preferisce la
rete. Con `p_s = 0,110` e `p_c = 0,116 €/kWh` la banda è larga **0,6 centesimi** contro i
**30 centesimi** del paper, e i pesi collassano:

| Banda dei prezzi proposti | Pesi `ω_v` risultanti | max/min |
|---|---|---:|
| Paper, 0,081–0,309 €/kWh | 0,480 / 0,231 / 0,163 / 0,126 | **3,81×** |
| Nostra, 0,110–0,116 €/kWh | 0,257 / 0,252 / 0,248 / 0,243 | **1,05×** |

Il canale "comportamento virtuoso", cioè l'unico contributo originale di PDM3, si
ridurrebbe di fatto a una ripartizione paritaria.

#### La rinuncia non è per difficoltà tecnica

Le formule sono non ambigue e sono state **riprodotte esattamente** in uno script di prova
(non incluso nel progetto), sul caso studio a 4 RSC del paper:

| Grandezza | Atteso (paper) | Ottenuto |
|---|---|---|
| `E_PSC` (Tab. 7) | `[4874, 4874, 3412, 1950]` | `[4875, 4875, 3412, 1950]` |
| `E_EX` (Tab. 7) | `[2925, 1462, 1462, 2925]` | `[2925, 1462, 1462, 2925]` |
| **PDM3** (Fig. 5) | `30,45 / 28,63 / 23,09 / 17,84 %` | `30,44 / 28,64 / 23,11 / 17,80 %` |
| **PDM4** (Fig. 5) | `27,68 / 28,41 / 24,11 / 19,80 %` | `27,69 / 28,42 / 24,11 / 19,79 %` |

L'implementazione costerebbe circa 150 righe e nessuna dipendenza nuova. È stata scartata
per le ragioni (a)-(d), non per il costo.

#### A quali condizioni riprenderli

Basta che **una** di queste cambi:

1. **Scenario a impianto cofinanziato.** Se si dichiara l'impianto in comproprietà (anche
   solo come scenario, non come configurazione reale), il metodo torna nel suo habitat:
   ogni membro ha una quota `E_out/N` e un `ω_self,c` calcolabile ora per ora dai nostri
   profili come `Σ_t min(genPV_raw(t)/N, load_i(t))`. Verificato sui nostri dati: si
   otterrebbe `ω_self,c` da 0,105 (household_2) a 0,982 (small_industry_1) e quote fra
   14,8 % e 18,9 %, cioè **tutti i membri differenziati dal proprio comportamento**.
2. **Dati di bolletta e reddito reali** per i membri — che servirebbero comunque anche al
   Weighted Solidarity (§12.7a) e al Remuneration Model 1 (§10.5).
3. **Aggancio a `optimizer_PV.m`** invece che a `v(N)`. Quello script calcola già NPV e IRR
   dell'impianto: è esattamente la grandezza che PDM3/PDM4 sono nati per ripartire, e
   sarebbe il collegamento — oggi assente — fra il ramo di dimensionamento e quello di
   ripartizione dei benefici.

#### Nota: PDM1 e PDM2 del paper sono già nel progetto

Il paper confronta i suoi due modelli con altri tre. Due li abbiamo già: **PDM1**
(*"revenues split equally"*) è l'**Equal Split** (§8), e **PDM2** (*"revenues shared
entirely according to energy consumption profile"*) è concettualmente il **Proportional to
Consumption** (§9). Il confronto con le due estremità che il paper usa come riferimento è
quindi già disponibile in `Tcmp`.

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
- F. Gianaroli, M. Ricci, P. Sdringola, M. A. Ancona, L. Branchini, F. Melino,
  *Development of dynamic sharing keys: Algorithms supporting management of renewable
  energy community and collective self consumption*, Energy & Buildings 311 (2024)
  114158. — Pearson Key (M3, eq. 4), sharing rate (M4, eq. 5 e Fig. 3), combinazione
  pesata (M5, eq. 7) e algoritmo iterativo di ripartizione con cap al consumo (Fig. 2).
- M. Bilardo, *A fair dynamic incentive allocation method for virtual energy sharing in
  renewable energy communities that rewards members' virtuosity and engagement*,
  Renewable Energy 255 (2025) 123756. — Similarity-Utilization (eq. 3-8, Fig. 5).
- S. Cremers, V. Robu, P. Zhang, M. Andoni, S. Norbu, D. Flynn, *Efficient methods for
  approximating the Shapley value for asset sharing in energy communities*, Applied Energy
  331 (2023) 120328. — Marginal Contribution (§4.1.1, eq. 9-10), Stratified Expected Value
  (§4.1.2, eq. 11-13), lo Shapley per strati (eq. 8) e le metriche di errore (eq. 16-17).
  Il calcolo esatto per `K` classi (§4.2) è valutato e **non** implementato, vedi §16.10.
- G. O'Brien, A. El Gamal, R. Rajagopal, *Shapley value estimation for compensation of
  participants in demand response programs*, IEEE Trans. Smart Grid 6(6) 2015, 2837-2844. —
  Campionamento stratificato adattivo, nella formulazione dell'Appendice C di Cremers et al.
- P. Basilico, A. Biancardi, I. D'Adamo, M. Gastaldi, T. Yigitcanlar, *Renewable energy
  communities for sustainable cities: Economic insights into subsidies, market dynamics
  and benefits distribution*, Applied Energy 389 (2025) 125752. — PDM3 e PDM4 (eq. 8-24):
  valutati e **non** implementati, vedi Appendice A.1.
