# Repliche dei partecipanti, blocco da18

Repliche analizzate: 20 (r01, r02, r03, r04, r05, r06, r07, r08, r09, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20); r00 = identita' (schede di prima).

## Vincitori

Per ogni livello, indicatore, taglia e fascia: il vincitore piu' frequente fra le repliche,
in quante repliche vince lui, e se coincide con quello del disegno di prima (r00).

I vincitori si confrontano come insieme dei primi a pari merito.

| Indicatore | Celle | Repliche col vincitore modale (media) | Celle con modale = r00 | Repliche con almeno un primo in comune con r00 |
|---|---|---|---|---|
| Gini | 63 | 100% | 100% | 100% |
| FairnessIndex | 63 | 90% | 75% | 100% |
| Sigma | 63 | 92% | 78% | 100% |
| EccessoMax_EUR | 63 | 89% | 70% | 100% |
| CoalizioniInstabili | 63 | 90% | 73% | 100% |
| ForzaIncentivante | 63 | 88% | 71% | 96% |
| AllineamentoVirtu | 63 | 85% | 78% | 100% |
| AllineamentoVirtu_lordo | 63 | 76% | 44% | 93% |

## Accordo fra criteri (tau-b medio per fascia, livello base)

| Coppia | Fascia | r00 | Mediana repliche | Min-max | Repliche con il segno della mediana |
|---|---|---|---|---|---|
| Gini - ForzaIncentivante | 1 | -0,42 | -0,42 | -0,60 / -0,20 | 100% |
| Gini - ForzaIncentivante | 2 | -0,78 | -0,85 | -0,93 / -0,82 | 100% |
| Gini - ForzaIncentivante | 3 | -0,85 | -0,85 | -0,85 / -0,82 | 100% |
| Gini - ForzaIncentivante | 4 | -0,93 | -0,89 | -0,96 / -0,75 | 100% |
| FairnessIndex - ForzaIncentivante | 1 | -0,49 | -0,45 | -0,60 / -0,31 | 100% |
| FairnessIndex - ForzaIncentivante | 2 | 0,35 | 0,35 | 0,27 / 0,42 | 100% |
| FairnessIndex - ForzaIncentivante | 3 | 0,49 | 0,49 | 0,42 / 0,56 | 100% |
| FairnessIndex - ForzaIncentivante | 4 | 0,31 | 0,22 | 0,09 / 0,42 | 100% |
| Gini - FairnessIndex | 1 | 0,71 | 0,38 | 0,24 / 0,56 | 100% |
| Gini - FairnessIndex | 2 | -0,27 | -0,27 | -0,35 / -0,20 | 100% |
| Gini - FairnessIndex | 3 | -0,35 | -0,35 | -0,42 / -0,27 | 100% |
| Gini - FairnessIndex | 4 | -0,24 | -0,11 | -0,31 / -0,02 | 100% |
| FairnessIndex - EccessoMax_EUR | 1 | 0,56 | 0,56 | 0,45 / 0,71 | 100% |
| FairnessIndex - EccessoMax_EUR | 2 | 0,85 | 0,85 | 0,78 / 0,93 | 100% |
| FairnessIndex - EccessoMax_EUR | 3 | 0,96 | 0,93 | 0,82 / 0,96 | 100% |
| FairnessIndex - EccessoMax_EUR | 4 | 0,75 | 0,85 | 0,75 / 0,96 | 100% |

## Il capovolgimento con la penetrazione, replica per replica

- tau(Gini, forza incentivante) diventa piu' negativo di almeno 0,3 dalla fascia 1 alla 4: 19 repliche su 20 (r00: -0,42 -> -0,93);
- tau(Fairness Index, forza incentivante) passa da negativo (fascia 1) a positivo (fascia 3): 20 repliche su 20 (r00: -0,49 -> 0,49).

| Replica | Gini-IS f1 | Gini-IS f4 | FI-IS f1 | FI-IS f3 |
|---|---|---|---|---|
| r00 | -0,42 | -0,93 | -0,49 | 0,49 |
| r01 | -0,20 | -0,96 | -0,60 | 0,53 |
| r02 | -0,42 | -0,93 | -0,45 | 0,45 |
| r03 | -0,45 | -0,89 | -0,53 | 0,49 |
| r04 | -0,42 | -0,96 | -0,49 | 0,49 |
| r05 | -0,38 | -0,75 | -0,42 | 0,45 |
| r06 | -0,35 | -0,85 | -0,38 | 0,49 |
| r07 | -0,42 | -0,82 | -0,53 | 0,56 |
| r08 | -0,53 | -0,93 | -0,45 | 0,53 |
| r09 | -0,53 | -0,82 | -0,31 | 0,53 |
| r10 | -0,35 | -0,93 | -0,49 | 0,53 |
| r11 | -0,49 | -0,89 | -0,31 | 0,49 |
| r12 | -0,42 | -0,82 | -0,38 | 0,45 |
| r13 | -0,27 | -0,89 | -0,56 | 0,49 |
| r14 | -0,60 | -0,93 | -0,42 | 0,49 |
| r15 | -0,42 | -0,78 | -0,38 | 0,53 |
| r16 | -0,42 | -0,85 | -0,49 | 0,45 |
| r17 | -0,38 | -0,93 | -0,45 | 0,49 |
| r18 | -0,38 | -0,75 | -0,38 | 0,49 |
| r19 | -0,38 | -0,85 | -0,38 | 0,49 |
| r20 | -0,27 | -0,89 | -0,60 | 0,42 |

## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)

| Indicatore | r00 | Repliche (tutte le celle di tutte le repliche) |
|---|---|---|
| Gini | Equal Split 100% | Equal Split 100%, Cascading Tree 6% |
| FairnessIndex | Nucleolo 100%, Variance Least Core 100%, Shapley 50% | Nucleolo 100%, Variance Least Core 100%, Shapley 50% |
| Sigma | Nucleolo 100%, Variance Least Core 100%, Shapley 50% | Nucleolo 100%, Variance Least Core 100%, Shapley 50% |
| EccessoMax_EUR | Nucleolo 100%, Shapley 100%, Variance Least Core 100% | Nucleolo 100%, Shapley 100%, Variance Least Core 100% |
| CoalizioniInstabili | Nucleolo 100%, Variance Least Core 100%, Shapley 25% | Nucleolo 100%, Variance Least Core 100%, Shapley 45% |
| ForzaIncentivante | Pearson Key 100%, Tri-level EP 100%, Similarity-Utilization 75% | Pearson Key 94%, Tri-level EP 92%, Similarity-Utilization 86% |
| AllineamentoVirtu | Similarity-Utilization 100%, Pearson Key 75%, Proportional to Consumption 75% | Similarity-Utilization 100%, Pearson Key 80%, Tri-level EP 68% |
| AllineamentoVirtu_lordo | Similarity-Utilization 75%, Nucleolo 25%, Pearson Key 25% | Remuneration Model 1 49%, Nucleolo 29%, Variance Least Core 29% |

## Inversioni di graduatoria lungo gli assi

| Asse | Fisso | r00 | Mediana | Min-max |
|---|---|---|---|---|
| penetrazione | n = 18 | 19% | 19% | 14%-20% |

## Da cosa dipendono i punteggi (quota della varianza, livello base)

| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti | r00: penetrazione | r00: taglia |
|---|---|---|---|---|---|---|
| Gini | 90% | 0% | -0% | 10% | 100% | 0% |
| FairnessIndex | 92% | 0% | -0% | 8% | 100% | 0% |
| Sigma | 92% | 0% | -0% | 8% | 100% | 0% |
| EccessoMax_EUR | 81% | 0% | -0% | 19% | 100% | 0% |
| CoalizioniInstabili | 90% | 0% | -0% | 10% | 100% | 0% |
| ForzaIncentivante | 88% | 0% | -0% | 12% | 100% | 0% |
| AllineamentoVirtu | 85% | 0% | -0% | 15% | 100% | 0% |
| AllineamentoVirtu_lordo | 49% | 0% | -0% | 51% | 100% | 0% |

## Composizione (PA e imprese): coppie invertite rispetto al livello base

| Confronto | r00 (media sugli indicatori) | Mediana repliche |
|---|---|---|
| PA0 contro ND>=1 | 12% | 9% |
| PA0 contro PA>=1 | 12% | 9% |
| PA0-ND1 | 9% | 4% |
| PA0-ND1_PA1 | 11% | 9% |
| PA0-ND1_PA2 | 14% | 10% |
| PA0-ND1_PA3 | 12% | 10% |
| PA0-ND2 | 13% | 10% |
| PA0-ND2_PA1 | 13% | 10% |
| PA0-ND2_PA2 | 12% | 9% |
| PA0-ND2_PA3 | 11% | 9% |
| PA0-ND3 | 12% | 9% |
| PA0-ND3_PA1 | 13% | 10% |
| PA0-ND3_PA2 | 12% | 9% |
| PA0-ND3_PA3 | 9% | 8% |
| PA0-PA1 | 11% | 7% |
| PA0-PA2 | 14% | 10% |
| PA0-PA3 | 12% | 10% |

## Perdite di trade-off principali (perdita ottimistica media)

| Si sceglie | Si perde | r00 | Mediana | Min-max |
|---|---|---|---|---|
| Gini | EccessoMax_EUR | 0,73 | 0,73 | 0,67-0,80 |
| Gini | ForzaIncentivante | 0,82 | 0,84 | 0,81-0,86 |
| ForzaIncentivante | Gini | 0,96 | 0,89 | 0,88-0,94 |
| FairnessIndex | EccessoMax_EUR | 0,00 | 0,00 | 0,00-0,00 |
| EccessoMax_EUR | FairnessIndex | 0,00 | 0,00 | 0,00-0,00 |
