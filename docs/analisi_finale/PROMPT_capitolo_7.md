Devi rivedere il Capitolo 7 "Results and Discussion" della mia tesi magistrale, nel file
`Chapter7_Discussion.tex` del repository `Tesi-Magistrale`. Non si riscrive il capitolo: i suoi
risultati sono corretti e restano. Rileggendolo sui dati delle repliche (7 novembre 2026) sono emerse
due letture da correggere e cinque risultati che il capitolo non riporta. Questo prompt dice dove
intervenire e dà per ogni punto una bozza LaTeX già scritta, da integrare nel testo attuale.

## Prima di cominciare: i file da copiare nella tesi

Li trovi nel repository `Master-Thesis-Project`, branch `analisi-aggiuntive-cap7`. Se non li vedi
nella tesi, chiedimeli: li copio io.

- `outputs/tesi_finale/numeri_aggiuntivi.tex` va accanto a `numeri_tesi.tex`. Nel preambolo, subito
  dopo `\input{numeri_tesi}`, aggiungi `\input{numeri_aggiuntivi}`. Ogni macro ha in coda un
  commento che dice cosa misura.
- In `Tables/` vanno le tabelle (solo l'ambiente `tabular`, come le altre):
  `incentive_ownership.tex`, `incentive_within_groups.tex`, `stability_by_group.tex`,
  `mixed_communities.tex`, `allocation_distance.tex`.

## Regole di scrittura

- **Lingua e stile.** Inglese accademico, stesso tono e stessa persona del capitolo: impersonale,
  frasi complete, niente elenchi puntati nel testo. Stessi nomi dei metodi ("the Variance Least
  Core", "the split proportional to consumption") e stessa notazione ($v(\mathcal{M})$, `\euro{}`).
- **Numeri.** Usa solo le macro di `numeri_aggiuntivi.tex` e `numeri_tesi.tex` e i numeri già
  presenti nel capitolo. Non inventarne e non riscriverli a mano. Le macro con valore negativo, e
  tutti i $\tau_b$, vanno in modo matematico: `$\VLCMarginSmallest{}$\%`. I valori di controllo
  sono in fondo a questo prompt.
- **Struttura.** Nessuna sezione nuova: tieni sezioni, `\label` e figure attuali. Le tabelle nuove
  hanno le label indicate nelle bozze. La tabella delle distanze (punto 2) può andare in appendice
  se il capitolo diventa troppo lungo; in quel caso adatta il rimando.
- **Lunghezza.** Il capitolo cresce al più del 20% circa. Le bozze sono un punto di partenza:
  accorciale dove ripetono il testo esistente e fondile con le frasi vicine invece di accodarle.
- **Citazioni.** Non toccare quelle esistenti. Per il valore del least core usa la chiave
  `maschler1979`. Se non è in `Thesis_bibliography.bib`, aggiungi la voce completa: Maschler, M.,
  Peleg, B., Shapley, L.S. (1979), "Geometric properties of the kernel, nucleolus, and related
  solution concepts", Mathematics of Operations Research 4(4), 303-338. Se nel capitolo 6 il
  valore del least core ha già un simbolo (nella 6.1 è $\theta_{LC}$), usa quello.
- **Cosa consegnare.**
  1. Il LaTeX completo di ogni sezione modificata, pronto da incollare.
  2. Un elenco breve dei cambiamenti fatti.
  3. L'elenco dei punti fuori dal capitolo 7 da allineare (punto 8 di questo prompt), con la tua
     proposta di testo.

## Cosa cambiare, punto per punto

### 1. La forza incentivante netta misura soprattutto la proprietà dell'impianto (§7.2, `sec:res_agreement`)

È il punto più importante. Il capovolgimento fra merito e incentivo è "the most robust result" del
capitolo e resta robusto (20/20 repliche), ma oggi si legge come un conflitto fra merito e
comportamento. Gli indicatori di incentivo sono calcolati sui profili netti: lì il carico residuo
di chi ha l'impianto è quasi nullo nelle ore di eccedenza, quindi la sua virtuosità misurata è bassa
per costruzione. Il capovolgimento è quindi del merito, che con la penetrazione passa dai produttori
ai consumatori, mentre la forza incentivante premia i consumatori a ogni penetrazione. Sui profili
lordi il capovolgimento non c'è.

**Dove:** dopo il paragrafo che comincia con "The reversal is the most robust result", e dopo la sua
spiegazione ("With few prosumers the shared energy is limited by the injection, ..."), che resta.

```latex
The incentive indicators are computed on net profiles, on which the residual load of a plant owner is close to zero in the hours of surplus, so that the measured virtuosity of a prosumer is low by construction (Table~\ref{tab:res_ownership}). In all the \NumHouseholdCommunitiesBandsOneThree{} domestic communities of the first three bands, every prosumer is less virtuous than every consumer, with a median virtuosity of \VirtNetProsumerMin{} to \VirtNetProsumerMax{} against \VirtNetConsumerMin{} to \VirtNetConsumerMax{}, whereas on gross profiles the two groups are equally virtuous (\VirtGrossProsumer{} and \VirtGrossConsumer{}). Ranking the mechanisms by incentive strength is therefore the same as ranking them by the share of the incentive that they give to the consumers, with a $\tau_b$ of $\TauISConsumerShareBandOne{}$, $\TauISConsumerShareBandTwo{}$ and $\TauISConsumerShareBandThree{}$ in the three bands. The reversal is thus a reversal of merit, which moves from the producers to the consumers as penetration grows, while the incentive strength favors the consumers in all the bands that have any. On gross profiles the reversal does not appear: the $\tau_b$ between the Fairness Index and the gross alignment is $\TauFairnessIndexAllineamentoVirtulordoBandOne{}$, $\TauFairnessIndexAllineamentoVirtulordoBandTwo{}$, $\TauFairnessIndexAllineamentoVirtulordoBandThree{}$ and $\TauFairnessIndexAllineamentoVirtulordoBandFour{}$ in the four bands.

The same change of direction appears within the group of prosumers. The correlation between share and virtuosity among the prosumers is $\CorrProsumersShapleyBandOne{}$ under the Shapley value and $\CorrProsumersVLCBandOne{}$ under the Variance Least Core in the first band, and $\CorrProsumersShapleyBandThree{}$ and $\CorrProsumersVLCBandThree{}$ in the third, consistently with the scarce side moving from the injection to the consumption. Among the consumers, instead, the Shapley value, the Variance Least Core, the Pearson Key and the Tri-level EP all reward the more synchronous members, with a correlation between share and virtuosity between \CorrConsumersMin{} and \CorrConsumersMax{} (Table~\ref{tab:res_within}). These are cross-sectional relations between the share and the virtuosity, not responses of the share to a change of behavior.

\begin{table}[htbp]
\centering
\small
\caption{Virtuosity on net and gross profiles and agreement of the incentive strength with the share of the incentive going to consumers, by penetration band (domestic level). Virtuosity: median over the members; $\tau_b$ with the consumers' share: median over the communities; $\tau_b$ of the Fairness Index: median over the replicas. Band 4 has no consumers.}
\label{tab:res_ownership}
\resizebox{\linewidth}{!}{\input{Tables/incentive_ownership}}
\end{table}

\begin{table}[htbp]
\centering
\small
\caption{Reward of virtuosity among members with the same ownership (domestic level): slope of the share on the net virtuosity among the consumers, relative to the Similarity-Utilization (equal to 1), and correlation between share and net virtuosity among the prosumers, by band (median over the communities with at least four members in the group).}
\label{tab:res_within}
\resizebox{\linewidth}{!}{\input{Tables/incentive_within_groups}}
\end{table}
```

### 2. Il Tri-level EP, così come è simulato, coincide con la Pearson Key (§7.1, `sec:res_mechanisms`)

Il capitolo li conta come due meccanismi distinti ("96% of the cells each", e lo stesso nel Pareto e
nel VAN). Le due ripartizioni differiscono in mediana dell'1,5% di v(N), perché il livello di
povertà energetica del Tri-level EP è attivo solo in 392 comunità: altrove resta il livello
proporzionale orario, che ripartisce come la Pearson Key.

**Dove:** in §7.1, subito dopo la frase "The incentive is led by the Pearson Key and the Tri-level
EP on the incentive strength (96\% of the cells each) and by the Similarity-Utilization on the net
alignment (100\%)."

```latex
The Pearson Key and the Tri-level EP, however, produce nearly the same allocation. The share of $v(\mathcal{M})$ that has to be moved to turn one into the other, that is, the total variation distance between the two allocations, has a median of \TVPKTLEHouseholds\% in the domestic level and of \TVPKTLEAll\% over all the communities, and it is below 5\% in \PctTVPKTLEBelowFive\% of them, so that the two mechanisms are tied in \PctISTiesPKTLE\% of the cells in which either of them ranks first on the incentive strength. The energy-poverty level of the Tri-level EP is active only in the \NumCommunitiesEPActive{} communities with a vulnerable household, all of \EPActiveSizes{} members, and elsewhere the rule reduces to its proportional level, which, like the Pearson Key, allocates the shared energy hour by hour among the members that are withdrawing. More generally, the ten mechanisms produce fewer distinct allocations (Table~\ref{tab:res_distance}). In the domestic level the split proportional to consumption is \TVPKPtCHouseholds\% away from the Pearson Key and the Cascading Tree \TVCTESHouseholds\% from the Equal Split, and over all the communities the Variance Least Core is \TVShapleyVLCAll\% away from the Shapley value, whereas the Similarity-Utilization, although also based on synchronism, is \TVPKSUHouseholds\% away from the Pearson Key in the domestic level and \TVPKSUAll\% over all the communities.

\begin{table}[htbp]
\centering
\small
\caption{Median total variation distance between the allocations of each pair of mechanisms, in \% of $v(\mathcal{M})$ (domestic level): the share of the value that has to be moved to turn one allocation into the other. S: Shapley value; VLC: Variance Least Core; ES: Equal Split; PtC: proportional to consumption; PK: Pearson Key; SU: Similarity-Utilization; RM1: Remuneration Model 1; CT: Cascading Tree; WS: Weighted Solidarity.}
\label{tab:res_distance}
\resizebox{\linewidth}{!}{\input{Tables/allocation_distance}}
\end{table}
```

In §7.8 la frase "the reward of temporal alignment by the keys that allocate the shared energy in
proportion to synchronism and by the Tri-level EP" resta, ma non va presentato il Tri-level EP come
regola di contrasto alla povertà energetica: nei risultati è la sua forma a due livelli (punto 8).

### 3. Stabilità: il nucleo è sottile e l'Equal Split è il più instabile solo nel dato aggregato (§7.4, `sec:res_stability`)

Tre aggiunte.

**3a. Dove:** sostituisci la frase "The Equal Split is the most unstable mechanism, with a median
excess of 44\% of the value and with the allocation in the core in 0.03\% of the communities:
choosing it for the equality of the shares means that some group of members would almost always gain
by leaving the community." con:

```latex
The Equal Split is the most unstable mechanism over the whole set, with a median excess of 44\% of the value and with the allocation in the core in 0.03\% of the communities, but the ranking depends on the composition (Table~\ref{tab:res_stability_groups}). With public buildings and with firms, where the Equal Split gives the large members the same share as a household, its median excess is \ExcessESPublic\% and \ExcessESFirms\%, and these communities are most of the set (\PctCommunitiesWithFirms\% have firms); in the domestic level the most unstable mechanism is the \MostUnstableHouseholds{} (\ExcessWSHouseholds\%), followed by the Equal Split (\ExcessESHouseholds\%). Choosing the Equal Split for the equality of the shares means that some group of members would almost always gain by leaving the community.

\begin{table}[htbp]
\centering
\small
\caption{Coalitional stability by mechanism and group of communities: median maximum excess in \% of $v(\mathcal{M})$ and share of communities in which the allocation is in the core.}
\label{tab:res_stability_groups}
\resizebox{\linewidth}{!}{\input{Tables/stability_by_group}}
\end{table}
```

**3b e 3c. Dove:** subito prima del paragrafo "By size (Figure~\ref{fig:res_stability}), ...".

```latex
The core is never empty, but it is thin. The maximum excess of the Variance Least Core equals the value of the least core \citep{maschler1979}, that is, the largest margin by which an allocation can keep every coalition away from the incentive to leave. In the domestic level its median is $\VLCMarginSmallest{}$\% of $v(\mathcal{M})$ at 5 members and $\VLCMarginLargest{}$\% at 25 members, between $\VLCMarginEURSmallest{}$ and $\VLCMarginEURLargest{}$~\euro{} per year for the whole community, and over all the communities it is below 1\% of $v(\mathcal{M})$ in \PctVLCMarginBelowOne\% of the cases and below the relevance threshold of 5\% in \PctVLCMarginBelowFive\%. The ranking on the maximum excess therefore does not separate the allocations in the core from those close to its boundary. From 20 members on, the margin ($\VLCMarginTwenty{}$\% at 20 members) is also smaller than the distance between the Adaptive Sampling estimate and the exact Shapley value, about \ASLOneVNMax\% of $v(\mathcal{M})$ where both are available (Section~\ref{sec:res_robustness}), so that whether the Shapley value lies in the core cannot be established for the largest communities.

The share of communities in which the Shapley value lies in the core, \ShapleyCoreHouseholds\% in the domestic level, \ShapleyCorePublic\% with public buildings and \ShapleyCoreFirms\% with firms, comes from nearly homogeneous communities. In the fourth band, where all the members are prosumers, it is \ShapleyCoreBandFourSizeFive\% at 5 members, \ShapleyCoreBandFourSizeOneZero\% at 10, \ShapleyCoreBandFourSizeOneFive\% at 15 and \ShapleyCoreBandFourSizeOneEight\% at 18, and in the first band at 5 members, with a single prosumer, it is \ShapleyCoreBandOneSmallest\%, whereas in the second and third bands it never exceeds \ShapleyCoreBandsTwoThreeMax\%.
```

### 4. Comunità miste e comunità con un solo prosumer (§7.6, `sec:res_beneficiaries`)

Il capitolo guarda le comunità con PA e imprese solo attraverso le graduatorie (§7.3). Ma lì la
regola decide anche quanta parte dell'incentivo va al Comune, alla scuola o alle imprese, e se le
famiglie stanno meglio o peggio che in una comunità di sole famiglie.

**Dove:** dopo il primo paragrafo di §7.6 (quello che finisce con "... up to 78\% for the Cascading
Tree and 80\% for the Weighted Solidarity in the third band."), prima del paragrafo sul VAN.

```latex
In the \NumCommunitiesZeroShare{} communities of \ZeroShareSizes{} members with a single prosumer, the split proportional to consumption, the Pearson Key, the Similarity-Utilization and the Tri-level EP give the owner of the plant no incentive at all, whereas the Shapley value gives it \ShapleyShareSingleProsumer\% of $v(\mathcal{M})$.

In the communities with public buildings or firms the rule also decides how much of the incentive goes to the large members (Table~\ref{tab:res_mixed}). Public buildings and firms are \NumericalShareNonDomPublic\% and \NumericalShareNonDomFirms\% of the members in the median community, and they receive \ShareNonDomSUPublic\% and \ShareNonDomSUFirms\% of the incentive under the Similarity-Utilization, \ShareNonDomShapleyPublic\% and \ShareNonDomShapleyFirms\% under the Shapley value, and \ShareNonDomRMOnePublic\% and \ShareNonDomRMOneFirms\% under the Remuneration Model 1. Under most rules the households are nonetheless better off than in the corresponding domestic community: under the Shapley value \HouseholdsGainPctShapleyPublic\% of them gain when public buildings join and \HouseholdsGainPctShapleyFirms\% when firms join, by a median of \HouseholdsGainEURShapleyPublic{} and \HouseholdsGainEURShapleyFirms~\euro{} per year. The Remuneration Model 1 is the exception: in the communities with the municipal building only, or with firms and at most the municipal building, only \RMOneGainPctMin\% to \RMOneGainPctMax\% of the households gain, with a median change between $\RMOneGainEURMin{}$ and $\RMOneGainEURMax{}$~\euro{} per year.

\begin{table}[htbp]
\centering
\small
\caption{Communities with public buildings (PA) or firms: median share of the incentive going to the non-domestic members, share of households that gain with respect to the corresponding domestic community, and their median gain.}
\label{tab:res_mixed}
\resizebox{\linewidth}{!}{\input{Tables/mixed_communities}}
\end{table}
```

Per la frase sui livelli: PA1 è il municipio; PA2 aggiunge il liceo, PA3 il palazzetto; ND1-ND3
sono le imprese. "Con il solo municipio, o con imprese e al più il municipio" sono i livelli PA1,
ND1-ND3, ND1_PA1, ND2_PA1, ND3_PA1. Se il capitolo 6 li chiama in un altro modo, usa quei nomi.

### 5. Il VAN negativo è un mancato pareggio di circa 10 euro l'anno (§7.6)

Oggi il paragrafo sul VAN chiude con "The incentive therefore does not neutralize the risk of an
investment that does not pay back, and which member bears it depends on the rule." È vero, ma manca
la scala. Senza incentivo i prosumer più piccoli sono già quasi in pareggio, e il VAN negativo delle
chiavi di sincronismo vuol dire "meno di circa 10 euro l'anno".

**Dove:** sostituisci quella frase finale con:

```latex
The negative values are small. The net present value grows by \NPVAnnuityFactor~\euro{} for each euro per year of incentive, and without any incentive \PctProsumersNegativeNoIncentive\% of the domestic prosumers would have a negative value, between $\NPVNoIncentiveNegPFive{}$ and $\NPVNoIncentiveNegPNinetyFive{}$~\euro{} for nine in ten of them (median $\NPVNoIncentiveNegMedian{}$~\euro{}), while the others would be well above zero (median \NPVNoIncentivePosMedian~\euro{}). For most prosumers the investment is therefore close to break-even on its own, and about \BreakEvenIncentive~\euro{} per year of incentive is enough to make it pay back: the Pearson Key, the Similarity-Utilization and the Tri-level EP give the median prosumer \ProsumerIncentivePK{} to \ProsumerIncentiveSU~\euro{} per year, below that level, and the Equal Split \ProsumerIncentiveES~\euro{}. The rule therefore decides which member bears the risk of an investment that does not pay back, but the amounts at stake are of the order of ten euros per year, and the sign of the value rests on a margin that is small compared with the cost of the plant.
```

Se il capitolo 6 riporta il costo dell'impianto da 3,4 kWp (circa 7.000 euro), puoi rendere
l'ultima frase esplicita: il margine è circa il 2% del costo.

### 6. Implicazioni per i gestori (§7.8, `sec:disc_interpretation`)

**6a. Dove:** sostituisci la frase "If the aim is to orient the consumption toward the hours of
surplus, the Pearson Key, the Similarity-Utilization and the Tri-level EP are the rules that reward
it, at the price of leaving to the prosumers a small share of the incentive and, in most communities,
a member whose investment does not pay back (Section~\ref{sec:res_beneficiaries})." con:

```latex
If the aim is to orient the consumption toward the hours of surplus, ownership and behavior have to be kept apart. Among the consumers, who are the members that can move their withdrawals toward the surplus, the Shapley value and the Variance Least Core already reward the more synchronous ones at a rate comparable to that of the keys based on synchronism: relative to the Similarity-Utilization, the slope of the share on the virtuosity is \SlopeConsumersShapleyMin{} to \SlopeConsumersShapleyMax{} for the Shapley value and \SlopeConsumersVLCMin{} to \SlopeConsumersVLCMax{} for the Variance Least Core, against \SlopeConsumersPearsonMin{} to \SlopeConsumersPearsonMax{} for the Pearson Key and \SlopeConsumersTriLevelMin{} to \SlopeConsumersTriLevelMax{} for the Tri-level EP (Section~\ref{sec:res_agreement}). What the Pearson Key, the Similarity-Utilization and the Tri-level EP add is the transfer of the incentive from the owners of the plants to the consumers, at the price of leaving to the prosumers a small share of the incentive and, in most communities, a member whose investment does not pay back (Section~\ref{sec:res_beneficiaries}).
```

**6b. Dove:** nello stesso paragrafo, prima della frase "With few prosumers the choice also decides
how the benefit is divided between who produces and who consumes, ...".

```latex
In a community promoted together with a municipality or with firms, the rule also decides how much of the incentive remains to the households, since the share of the large members ranges from about a tenth under the Similarity-Utilization to two thirds or more under the Shapley value, the Remuneration Model 1 and the split proportional to consumption, and under the Remuneration Model 1, when only the municipal building or firms join, most households would be worse off than in a community of households only (Section~\ref{sec:res_beneficiaries}).
```

### 7. Due risultati già calcolati ma non enunciati

**7a. Pareto (§7.5, `sec:res_tradeoffs`).** Il capitolo dice "for four sets of criteria" ma ne
descrive tre. **Dove:** nel paragrafo "Ordering the mechanisms is not enough to choose among them",
dopo "... the Shapley value (71\%) and the Variance Least Core (68\%)." aggiungi:

```latex
With equality, gross alignment and minimum net present value, only the Equal Split (\ParetoGrossES\%) and the Remuneration Model 1 (\ParetoGrossRMOne\%) are non-dominated in at least half of the communities.
```

**7b. Soglia regolatoria.** In §7.9 la soglia compare fra le conclusioni verificate ("the
regulatory threshold (1)"), ma il risultato non è mai enunciato. Controlla se è già scritto nel
capitolo 6. Se non c'è, aggiungi questa frase in §7.6, dopo il paragrafo sul VAN, oppure in §7.9
dove la soglia è nominata. Le macro sono quelle di `numeri_tesi.tex`.

```latex
The regulatory threshold on the incentivised energy is never exceeded in the communities with firms, where the shared energy is at most \ThresholdMaxWithFirms\% of the injected energy, nor in those with public buildings (at most \ThresholdMaxWithPublicBuildings\%); it is exceeded in \ThresholdAboveHouseholdsOnly{} domestic communities, where it has no effect, since it concerns only the incentive of firms.
```

### 8. Punti fuori dal capitolo 7 da allineare

Non modificarli: elencali con una proposta di testo, li decido io.

- **Definizione della forza incentivante** (capitolo 4 o dove è definita). Va detto che è calcolata
  sui profili netti e che su questi la virtuosità di chi ha l'impianto è bassa per costruzione
  (punto 1).
- **Descrizione del Tri-level EP.** Con i parametri LIHC ai valori di default (P50, y* e markup non
  ancora fissati) il livello di povertà energetica è attivo solo in 392 comunità su 5900, tutte
  da 25 membri, in 8 repliche su 20 (macro `\NumCommunitiesEPActive`, `\NumReplicasEPActive`).
  Nei risultati il metodo è
  quindi la sua forma a due livelli. Va detto dove il metodo è descritto e nei limiti.
- **Limiti: nota sul segno della forza incentivante.** Proposta di nota a piè di pagina, da
  agganciare alla prima menzione della forza incentivante nel capitolo 7:
  ```latex
  \footnote{In \NumISSignFlips{} of the 5,900 communities, all at the level \ISSignFlipLevels{}, the projection of the Similarity-Utilization on its own virtuosity axis is negative, so that the sign of the incentive strength is reversed for all the mechanisms.}
  ```
- **Famiglie di metodi nelle legende delle figure.** Le figure colorano i metodi per famiglia
  ("synchrony-based": Pearson Key e Similarity-Utilization; il Tri-level EP fra le euristiche di
  letteratura). Le famiglie sono di progetto e possono restare. Ma il testo non deve dedurne una
  somiglianza fra le ripartizioni: per le distanze vale la Tabella `tab:res_distance`.

## Valori di controllo delle macro usate nelle bozze

Servono solo per verificare il testo compilato. Nel testo vanno sempre le macro.

<!-- TABELLA MACRO: generata dai file delle macro, non modificare a mano -->

| Macro | Valore | Cosa misura | File |
|---|---|---|---|
| `\NumHouseholdCommunitiesBandsOneThree` | 420 | comunita' domestiche delle fasce 1-3 | numeri_aggiuntivi.tex |
| `\VirtNetProsumerMin` | 0.01 | virtuosita' netta mediana dei prosumer, minimo sulle fasce 1-3 (domestico) | numeri_aggiuntivi.tex |
| `\VirtNetProsumerMax` | 0.02 | virtuosita' netta mediana dei prosumer, massimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\VirtNetConsumerMin` | 0.47 | virtuosita' netta mediana dei consumatori, minimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\VirtNetConsumerMax` | 0.50 | virtuosita' netta mediana dei consumatori, massimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\VirtGrossProsumer` | 0.53 | virtuosita' lorda mediana dei prosumer, fasce 1-3 | numeri_aggiuntivi.tex |
| `\VirtGrossConsumer` | 0.52 | virtuosita' lorda mediana dei consumatori, fasce 1-3 | numeri_aggiuntivi.tex |
| `\TauISConsumerShareBandOne` | 0.91 | tau-b fra forza incentivante e quota ai consumatori, fascia 1 (mediana) | numeri_aggiuntivi.tex |
| `\TauISConsumerShareBandTwo` | 0.96 | tau-b fra forza incentivante e quota ai consumatori, fascia 2 (mediana) | numeri_aggiuntivi.tex |
| `\TauISConsumerShareBandThree` | 1.00 | tau-b fra forza incentivante e quota ai consumatori, fascia 3 (mediana) | numeri_aggiuntivi.tex |
| `\TauFairnessIndexAllineamentoVirtulordoBandOne` | 0.16 | tau-b Fairness Index - allineamento lordo, fascia 1 (mediana sulle repliche) | numeri_aggiuntivi.tex |
| `\TauFairnessIndexAllineamentoVirtulordoBandTwo` | 0.20 | tau-b Fairness Index - allineamento lordo, fascia 2 (mediana sulle repliche) | numeri_aggiuntivi.tex |
| `\TauFairnessIndexAllineamentoVirtulordoBandThree` | -0.06 | tau-b Fairness Index - allineamento lordo, fascia 3 (mediana sulle repliche) | numeri_aggiuntivi.tex |
| `\TauFairnessIndexAllineamentoVirtulordoBandFour` | 0.20 | tau-b Fairness Index - allineamento lordo, fascia 4 (mediana sulle repliche) | numeri_aggiuntivi.tex |
| `\CorrProsumersShapleyBandOne` | -0.66 | correlazione quota-virtuosita' fra i prosumer, Shapley, fascia 1 | numeri_aggiuntivi.tex |
| `\CorrProsumersVLCBandOne` | -0.63 | correlazione quota-virtuosita' fra i prosumer, Variance Least Core, fascia 1 | numeri_aggiuntivi.tex |
| `\CorrProsumersShapleyBandThree` | 0.66 | correlazione quota-virtuosita' fra i prosumer, Shapley, fascia 3 | numeri_aggiuntivi.tex |
| `\CorrProsumersVLCBandThree` | 0.70 | correlazione quota-virtuosita' fra i prosumer, Variance Least Core, fascia 3 | numeri_aggiuntivi.tex |
| `\CorrConsumersMin` | 0.63 | correlazione quota-virtuosita' fra i consumatori: minimo su Shapley, VLC, PK, TlE e fasce 1-3 | numeri_aggiuntivi.tex |
| `\CorrConsumersMax` | 0.81 | lo stesso, massimo | numeri_aggiuntivi.tex |
| `\TVPKTLEHouseholds` | 1.5 | distanza TV mediana PK - TlE, % di v(N), domestico | numeri_aggiuntivi.tex |
| `\TVPKTLEAll` | 2.8 | distanza TV mediana PK - TlE, tutte le comunita' | numeri_aggiuntivi.tex |
| `\PctTVPKTLEBelowFive` | 93 | % comunita' con distanza PK - TlE sotto il 5% di v(N) | numeri_aggiuntivi.tex |
| `\PctISTiesPKTLE` | 96 | % celle in cui PK e TlE sono entrambi primi sulla forza incentivante, fra quelle in cui uno dei due lo e' | numeri_aggiuntivi.tex |
| `\NumCommunitiesEPActive` | 392 | comunita' con almeno un membro vulnerabile (livello EP del Tri-level attivo) | numeri_aggiuntivi.tex |
| `\EPActiveSizes` | 25 | taglie di quelle comunita' | numeri_aggiuntivi.tex |
| `\TVPKPtCHouseholds` | 7.4 | distanza TV mediana PK - Prop. to Consumption, domestico | numeri_aggiuntivi.tex |
| `\TVCTESHouseholds` | 9.0 | distanza TV mediana Cascading Tree - Equal Split, domestico | numeri_aggiuntivi.tex |
| `\TVShapleyVLCAll` | 8.1 | distanza TV mediana Shapley - VLC, tutte le comunita' | numeri_aggiuntivi.tex |
| `\TVPKSUHouseholds` | 11.4 | distanza TV mediana PK - SU, domestico | numeri_aggiuntivi.tex |
| `\TVPKSUAll` | 29.4 | distanza TV mediana PK - SU, tutte le comunita' | numeri_aggiuntivi.tex |
| `\ExcessESPublic` | 47.4 | eccesso massimo mediano dell'Equal Split, % di v(N), with public buildings | numeri_aggiuntivi.tex |
| `\ExcessESFirms` | 45.1 | eccesso massimo mediano dell'Equal Split, % di v(N), with firms | numeri_aggiuntivi.tex |
| `\PctCommunitiesWithFirms` | 63 | % delle 5900 comunita' con imprese | numeri_aggiuntivi.tex |
| `\MostUnstableHouseholds` | Weighted Solidarity | metodo con l'eccesso mediano piu' alto, households only | numeri_aggiuntivi.tex |
| `\ExcessWSHouseholds` | 21.2 | eccesso massimo mediano del Weighted Solidarity, % di v(N), households only | numeri_aggiuntivi.tex |
| `\ExcessESHouseholds` | 16.0 | eccesso massimo mediano dell'Equal Split, % di v(N), households only | numeri_aggiuntivi.tex |
| `\VLCMarginSmallest` | -3.5 | margine VLC (eccesso massimo, % di v(N)), mediana a 5 membri, domestico | numeri_aggiuntivi.tex |
| `\VLCMarginLargest` | -0.10 | lo stesso a 25 membri | numeri_aggiuntivi.tex |
| `\VLCMarginEURSmallest` | -10 | margine VLC in EUR/anno, mediana a 5 membri, domestico | numeri_aggiuntivi.tex |
| `\VLCMarginEURLargest` | -1.1 | lo stesso a 25 membri | numeri_aggiuntivi.tex |
| `\PctVLCMarginBelowOne` | 91 | % comunita' (tutte) con margine VLC sotto l'1% di v(N) | numeri_aggiuntivi.tex |
| `\PctVLCMarginBelowFive` | 99 | % comunita' con margine VLC sotto il 5% di v(N) (soglia di rilevanza) | numeri_aggiuntivi.tex |
| `\VLCMarginTwenty` | -0.18 | margine VLC, mediana a 20 membri, domestico (% di v(N)) | numeri_aggiuntivi.tex |
| `\ASLOneVNMax` | 0.9 | distanza L1 fra AS e Shapley esatto in % di v(N): massimo delle mediane per taglia (5-18 membri) | numeri_aggiuntivi.tex |
| `\ShapleyCoreHouseholds` | 17.0 | % comunita' con lo Shapley nel nucleo, households only | numeri_aggiuntivi.tex |
| `\ShapleyCorePublic` | 14.4 | % comunita' con lo Shapley nel nucleo, with public buildings | numeri_aggiuntivi.tex |
| `\ShapleyCoreFirms` | 0.6 | % comunita' con lo Shapley nel nucleo, with firms | numeri_aggiuntivi.tex |
| `\ShapleyCoreBandFourSizeFive` | 100 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 5 membri | numeri_aggiuntivi.tex |
| `\ShapleyCoreBandFourSizeOneZero` | 85 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 10 membri | numeri_aggiuntivi.tex |
| `\ShapleyCoreBandFourSizeOneFive` | 35 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 15 membri | numeri_aggiuntivi.tex |
| `\ShapleyCoreBandFourSizeOneEight` | 15 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 18 membri | numeri_aggiuntivi.tex |
| `\ShapleyCoreBandOneSmallest` | 100 | lo stesso in fascia 1 a 5 membri | numeri_aggiuntivi.tex |
| `\ShapleyCoreBandsTwoThreeMax` | 10 | massimo nelle fasce 2-3, su tutte le taglie | numeri_aggiuntivi.tex |
| `\NumCommunitiesZeroShare` | 40 | comunita' in cui almeno un metodo lascia un membro a quota zero | numeri_aggiuntivi.tex |
| `\ZeroShareSizes` | 5 | taglie | numeri_aggiuntivi.tex |
| `\ShapleyShareSingleProsumer` | 53 | quota mediana di v(N) data dallo Shapley all'unico prosumer in quelle comunita' | numeri_aggiuntivi.tex |
| `\NumericalShareNonDomPublic` | 13 | quota numerica mediana dei membri non domestici, with public buildings | numeri_aggiuntivi.tex |
| `\NumericalShareNonDomFirms` | 17 | quota numerica mediana dei membri non domestici, with firms | numeri_aggiuntivi.tex |
| `\ShareNonDomSUPublic` | 10 | quota mediana dell'incentivo ai membri non domestici, Similarity-Utilization, with public buildings | numeri_aggiuntivi.tex |
| `\ShareNonDomSUFirms` | 9 | quota mediana dell'incentivo ai membri non domestici, Similarity-Utilization, with firms | numeri_aggiuntivi.tex |
| `\ShareNonDomShapleyPublic` | 66 | quota mediana dell'incentivo ai membri non domestici, Shapley, with public buildings | numeri_aggiuntivi.tex |
| `\ShareNonDomShapleyFirms` | 62 | quota mediana dell'incentivo ai membri non domestici, Shapley, with firms | numeri_aggiuntivi.tex |
| `\ShareNonDomRMOnePublic` | 69 | quota mediana dell'incentivo ai membri non domestici, Remuneration Model 1, with public buildings | numeri_aggiuntivi.tex |
| `\ShareNonDomRMOneFirms` | 73 | quota mediana dell'incentivo ai membri non domestici, Remuneration Model 1, with firms | numeri_aggiuntivi.tex |
| `\HouseholdsGainPctShapleyPublic` | 84 | % famiglie che guadagnano quando entrano PA o imprese, Shapley, with public buildings | numeri_aggiuntivi.tex |
| `\HouseholdsGainPctShapleyFirms` | 90 | % famiglie che guadagnano quando entrano PA o imprese, Shapley, with firms | numeri_aggiuntivi.tex |
| `\HouseholdsGainEURShapleyPublic` | 19 | guadagno mediano per famiglia (EUR/anno), Shapley, with public buildings | numeri_aggiuntivi.tex |
| `\HouseholdsGainEURShapleyFirms` | 17 | guadagno mediano per famiglia (EUR/anno), Shapley, with firms | numeri_aggiuntivi.tex |
| `\RMOneGainPctMin` | 18 | Remuneration Model 1: % minima di famiglie che guadagnano, livelli senza PA2/PA3 | numeri_aggiuntivi.tex |
| `\RMOneGainPctMax` | 41 | lo stesso, massima | numeri_aggiuntivi.tex |
| `\RMOneGainEURMin` | -17 | Remuneration Model 1: guadagno mediano minimo (EUR/anno), livelli senza PA2/PA3 | numeri_aggiuntivi.tex |
| `\RMOneGainEURMax` | -1 | lo stesso, massimo | numeri_aggiuntivi.tex |
| `\NPVAnnuityFactor` | 13.59 | fattore di annualita' del VAN (EUR di VAN per EUR/anno di incentivo) | numeri_aggiuntivi.tex |
| `\PctProsumersNegativeNoIncentive` | 71 | % prosumer domestici con VAN negativo senza incentivo | numeri_aggiuntivi.tex |
| `\NPVNoIncentiveNegPFive` | -154 | lo stesso, 5 percentile | numeri_aggiuntivi.tex |
| `\NPVNoIncentiveNegPNinetyFive` | -118 | lo stesso, 95 percentile | numeri_aggiuntivi.tex |
| `\NPVNoIncentiveNegMedian` | -142 | VAN senza incentivo, mediana dei negativi (EUR) | numeri_aggiuntivi.tex |
| `\NPVNoIncentivePosMedian` | 1035 | VAN senza incentivo, mediana dei positivi (EUR) | numeri_aggiuntivi.tex |
| `\BreakEvenIncentive` | 10 | incentivo annuo di pareggio, mediana (EUR/anno) | numeri_aggiuntivi.tex |
| `\ProsumerIncentivePK` | 6 | incentivo annuo mediano di un prosumer domestico, Pearson Key (EUR/anno) | numeri_aggiuntivi.tex |
| `\ProsumerIncentiveSU` | 7 | incentivo annuo mediano di un prosumer domestico, Similarity-Utilization (EUR/anno) | numeri_aggiuntivi.tex |
| `\ProsumerIncentiveES` | 40 | incentivo annuo mediano di un prosumer domestico, Equal Split (EUR/anno) | numeri_aggiuntivi.tex |
| `\SlopeConsumersShapleyMin` | 1.03 | pendenza relativa a SU fra i consumatori, Shapley, minimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersShapleyMax` | 1.25 | pendenza relativa a SU fra i consumatori, Shapley, massimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersVLCMin` | 1.15 | pendenza relativa a SU fra i consumatori, Variance Least Core, minimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersVLCMax` | 1.43 | pendenza relativa a SU fra i consumatori, Variance Least Core, massimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersPearsonMin` | 1.20 | pendenza relativa a SU fra i consumatori, Pearson Key, minimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersPearsonMax` | 1.55 | pendenza relativa a SU fra i consumatori, Pearson Key, massimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersTriLevelMin` | 1.20 | pendenza relativa a SU fra i consumatori, Tri-level EP, minimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\SlopeConsumersTriLevelMax` | 1.59 | pendenza relativa a SU fra i consumatori, Tri-level EP, massimo sulle fasce 1-3 | numeri_aggiuntivi.tex |
| `\ParetoGrossES` | 100 | % comunita' in cui Equal Split non e' dominato con Gini + allineamento lordo + VAN minimo | numeri_aggiuntivi.tex |
| `\ParetoGrossRMOne` | 68 | % comunita' in cui Remuneration Model 1 non e' dominato con Gini + allineamento lordo + VAN minimo | numeri_aggiuntivi.tex |
| `\ThresholdMaxWithFirms` | 34.7 | (numeri_tesi.tex: vedi il nome) | numeri_tesi.tex |
| `\ThresholdMaxWithPublicBuildings` | 36.1 | (numeri_tesi.tex: vedi il nome) | numeri_tesi.tex |
| `\ThresholdAboveHouseholdsOnly` | 70 | (numeri_tesi.tex: vedi il nome) | numeri_tesi.tex |
| `\NumISSignFlips` | 4 | comunita' in cui il denominatore della forza incentivante e' negativo (segno invertito) | numeri_aggiuntivi.tex |
| `\ISSignFlipLevels` | PA1 | livelli di quelle comunita' | numeri_aggiuntivi.tex |
