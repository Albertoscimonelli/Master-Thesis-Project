# Repliche dei partecipanti, blocco da20a25

Repliche analizzate: 20 (r01, r02, r03, r04, r05, r06, r07, r08, r09, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20); r00 = identita' (schede di prima).

## Vincitori

Per ogni livello, indicatore, taglia e fascia: il vincitore piu' frequente fra le repliche,
in quante repliche vince lui, e se coincide con quello del disegno di prima (r00).

I vincitori si confrontano come insieme dei primi a pari merito.

| Indicatore | Celle | Repliche col vincitore modale (media) | Celle con modale = r00 | Repliche con almeno un primo in comune con r00 |
|---|---|---|---|---|
| Gini | 127 | 100% | 100% | 100% |
| FairnessIndex | 127 | 92% | 76% | 100% |
| Sigma | 127 | 92% | 79% | 100% |
| EccessoMax_EUR | 127 | 87% | 61% | 100% |
| CoalizioniInstabili | 127 | 89% | 69% | 100% |
| ForzaIncentivante | 127 | 90% | 69% | 98% |
| AllineamentoVirtu | 127 | 86% | 73% | 100% |
| AllineamentoVirtu_lordo | 127 | 77% | 52% | 95% |

## Accordo fra criteri (tau-b medio per fascia, livello base)

| Coppia | Fascia | r00 | Mediana repliche | Min-max | Repliche con il segno della mediana |
|---|---|---|---|---|---|
| Gini - ForzaIncentivante | 1 | -0,40 | -0,42 | -0,51 / -0,33 | 100% |
| Gini - ForzaIncentivante | 2 | -0,76 | -0,84 | -0,89 / -0,80 | 100% |
| Gini - ForzaIncentivante | 3 | -0,91 | -0,81 | -0,87 / -0,76 | 100% |
| Gini - ForzaIncentivante | 4 | -0,93 | -0,84 | -0,93 / -0,76 | 100% |
| FairnessIndex - ForzaIncentivante | 1 | -0,40 | -0,52 | -0,60 / -0,42 | 100% |
| FairnessIndex - ForzaIncentivante | 2 | 0,42 | 0,44 | 0,38 / 0,51 | 100% |
| FairnessIndex - ForzaIncentivante | 3 | 0,56 | 0,53 | 0,44 / 0,60 | 100% |
| FairnessIndex - ForzaIncentivante | 4 | 0,44 | 0,24 | 0,13 / 0,40 | 100% |
| Gini - FairnessIndex | 1 | 0,60 | 0,38 | 0,24 / 0,51 | 100% |
| Gini - FairnessIndex | 2 | -0,36 | -0,36 | -0,42 / -0,33 | 100% |
| Gini - FairnessIndex | 3 | -0,47 | -0,40 | -0,47 / -0,36 | 100% |
| Gini - FairnessIndex | 4 | -0,38 | -0,16 | -0,31 / -0,07 | 100% |
| FairnessIndex - EccessoMax_EUR | 1 | 0,60 | 0,56 | 0,49 / 0,64 | 100% |
| FairnessIndex - EccessoMax_EUR | 2 | 0,89 | 0,87 | 0,78 / 0,96 | 100% |
| FairnessIndex - EccessoMax_EUR | 3 | 0,96 | 0,92 | 0,89 / 1,00 | 100% |
| FairnessIndex - EccessoMax_EUR | 4 | 0,87 | 0,89 | 0,80 / 0,98 | 100% |

## Il capovolgimento con la penetrazione, replica per replica

- tau(Gini, forza incentivante) diventa piu' negativo di almeno 0,3 dalla fascia 1 alla 4: 20 repliche su 20 (r00: -0,40 -> -0,93);
- tau(Fairness Index, forza incentivante) passa da negativo (fascia 1) a positivo (fascia 3): 20 repliche su 20 (r00: -0,40 -> 0,56).

| Replica | Gini-IS f1 | Gini-IS f4 | FI-IS f1 | FI-IS f3 |
|---|---|---|---|---|
| r00 | -0,40 | -0,93 | -0,40 | 0,56 |
| r01 | -0,38 | -0,87 | -0,56 | 0,51 |
| r02 | -0,49 | -0,89 | -0,49 | 0,58 |
| r03 | -0,42 | -0,89 | -0,60 | 0,53 |
| r04 | -0,47 | -0,93 | -0,56 | 0,51 |
| r05 | -0,36 | -0,78 | -0,53 | 0,47 |
| r06 | -0,42 | -0,82 | -0,44 | 0,53 |
| r07 | -0,44 | -0,80 | -0,56 | 0,56 |
| r08 | -0,49 | -0,84 | -0,53 | 0,53 |
| r09 | -0,44 | -0,84 | -0,47 | 0,60 |
| r10 | -0,44 | -0,93 | -0,49 | 0,51 |
| r11 | -0,51 | -0,89 | -0,42 | 0,51 |
| r12 | -0,38 | -0,84 | -0,51 | 0,58 |
| r13 | -0,38 | -0,82 | -0,53 | 0,53 |
| r14 | -0,49 | -0,91 | -0,44 | 0,51 |
| r15 | -0,40 | -0,80 | -0,53 | 0,60 |
| r16 | -0,42 | -0,82 | -0,56 | 0,56 |
| r17 | -0,33 | -0,84 | -0,49 | 0,53 |
| r18 | -0,33 | -0,76 | -0,49 | 0,44 |
| r19 | -0,36 | -0,82 | -0,53 | 0,56 |
| r20 | -0,38 | -0,82 | -0,51 | 0,53 |

## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)

| Indicatore | r00 | Repliche (tutte le celle di tutte le repliche) |
|---|---|---|
| Gini | Equal Split 100% | Equal Split 100%, Cascading Tree 2% |
| FairnessIndex | Variance Least Core 100%, Adaptive Sampling Shapley 50%, Proportional to Consumption 12% | Variance Least Core 100%, Adaptive Sampling Shapley 50%, Proportional to Consumption 5% |
| Sigma | Variance Least Core 100%, Adaptive Sampling Shapley 50% | Variance Least Core 100%, Adaptive Sampling Shapley 50%, Proportional to Consumption 4% |
| EccessoMax_EUR | Adaptive Sampling Shapley 100%, Variance Least Core 100%, Pearson Key 50% | Adaptive Sampling Shapley 100%, Variance Least Core 100%, Tri-level EP 44% |
| CoalizioniInstabili | Variance Least Core 100%, Adaptive Sampling Shapley 25% | Variance Least Core 100%, Adaptive Sampling Shapley 42%, Remuneration Model 1 3% |
| ForzaIncentivante | Pearson Key 100%, Similarity-Utilization 100%, Tri-level EP 88% | Tri-level EP 97%, Pearson Key 94%, Similarity-Utilization 87% |
| AllineamentoVirtu | Similarity-Utilization 100%, Pearson Key 75%, Proportional to Consumption 75% | Similarity-Utilization 100%, Pearson Key 74%, Tri-level EP 59% |
| AllineamentoVirtu_lordo | Similarity-Utilization 75%, Pearson Key 38%, Tri-level EP 38% | Remuneration Model 1 57%, Variance Least Core 42%, Adaptive Sampling Shapley 38% |

## Inversioni di graduatoria lungo gli assi

| Asse | Fisso | r00 | Mediana | Min-max |
|---|---|---|---|---|
| penetrazione | n = 20 | 22% | 21% | 17%-24% |
| penetrazione | n = 25 | 19% | 17% | 14%-19% |
| taglia | fascia 1 (~26%) | 3% | 0% | 0%-2% |
| taglia | fascia 2 (~51%) | 0% | 0% | 0%-3% |
| taglia | fascia 3 (~76%) | 3% | 4% | 0%-5% |
| taglia | fascia 4 (~100%) | 1% | 0% | 0%-2% |

## Da cosa dipendono i punteggi (quota della varianza, livello base)

| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti | r00: penetrazione | r00: taglia |
|---|---|---|---|---|---|---|
| Gini | 90% | 1% | 2% | 8% | 98% | 1% |
| FairnessIndex | 93% | 1% | 1% | 5% | 97% | 1% |
| Sigma | 93% | 1% | 1% | 5% | 97% | 1% |
| EccessoMax_EUR | 85% | 1% | 1% | 14% | 95% | 1% |
| CoalizioniInstabili | 91% | 1% | 1% | 7% | 97% | 1% |
| ForzaIncentivante | 86% | 1% | 2% | 11% | 98% | 0% |
| AllineamentoVirtu | 78% | 1% | 3% | 18% | 83% | 5% |
| AllineamentoVirtu_lordo | 27% | 11% | 27% | 35% | 54% | 6% |

## Composizione (PA e imprese): coppie invertite rispetto al livello base

| Confronto | r00 (media sugli indicatori) | Mediana repliche |
|---|---|---|
| PA0 contro ND>=1 | 13% | 9% |
| PA0 contro PA>=1 | 13% | 8% |
| PA0-ND1 | 9% | 4% |
| PA0-ND1_PA1 | 13% | 9% |
| PA0-ND1_PA2 | 15% | 9% |
| PA0-ND1_PA3 | 12% | 9% |
| PA0-ND2 | 13% | 10% |
| PA0-ND2_PA1 | 14% | 11% |
| PA0-ND2_PA2 | 14% | 10% |
| PA0-ND2_PA3 | 12% | 9% |
| PA0-ND3 | 14% | 9% |
| PA0-ND3_PA1 | 15% | 11% |
| PA0-ND3_PA2 | 13% | 10% |
| PA0-ND3_PA3 | 11% | 8% |
| PA0-PA1 | 12% | 7% |
| PA0-PA2 | 15% | 9% |
| PA0-PA3 | 12% | 9% |

## Perdite di trade-off principali (perdita ottimistica media)

| Si sceglie | Si perde | r00 | Mediana | Min-max |
|---|---|---|---|---|
| Gini | EccessoMax_EUR | 0,76 | 0,73 | 0,68-0,80 |
| Gini | ForzaIncentivante | 0,81 | 0,84 | 0,82-0,85 |
| ForzaIncentivante | Gini | 0,95 | 0,88 | 0,84-0,91 |
| FairnessIndex | EccessoMax_EUR | 0,00 | 0,00 | 0,00-0,00 |
| EccessoMax_EUR | FairnessIndex | 0,00 | 0,00 | 0,00-0,00 |
