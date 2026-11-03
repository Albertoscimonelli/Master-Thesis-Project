# Repliche dei partecipanti, blocco unito

Repliche analizzate: 20 (r01, r02, r03, r04, r05, r06, r07, r08, r09, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20); r00 = identita' (schede di prima).

## Vincitori

Per ogni livello, indicatore, taglia e fascia: il vincitore piu' frequente fra le repliche,
in quante repliche vince lui, e se coincide con quello del disegno di prima (r00).

I vincitori si confrontano come insieme dei primi a pari merito.

| Indicatore | Celle | Repliche col vincitore modale (media) | Celle con modale = r00 | Repliche con almeno un primo in comune con r00 |
|---|---|---|---|---|
| Gini | 295 | 100% | 100% | 100% |
| FairnessIndex | 295 | 90% | 74% | 100% |
| Sigma | 295 | 92% | 81% | 100% |
| EccessoMax_EUR | 295 | 85% | 60% | 100% |
| CoalizioniInstabili | 295 | 88% | 69% | 100% |
| ForzaIncentivante | 295 | 88% | 69% | 96% |
| AllineamentoVirtu | 295 | 83% | 73% | 100% |
| AllineamentoVirtu_lordo | 295 | 76% | 46% | 93% |

## Accordo fra criteri (tau-b medio per fascia, livello base)

| Coppia | Fascia | r00 | Mediana repliche | Min-max | Repliche con il segno della mediana |
|---|---|---|---|---|---|
| Gini - ForzaIncentivante | 1 | -0,23 | -0,34 | -0,43 / -0,26 | 100% |
| Gini - ForzaIncentivante | 2 | -0,72 | -0,78 | -0,81 / -0,74 | 100% |
| Gini - ForzaIncentivante | 3 | -0,86 | -0,83 | -0,84 / -0,80 | 100% |
| Gini - ForzaIncentivante | 4 | -0,91 | -0,83 | -0,93 / -0,76 | 100% |
| FairnessIndex - ForzaIncentivante | 1 | -0,56 | -0,57 | -0,68 / -0,51 | 100% |
| FairnessIndex - ForzaIncentivante | 2 | 0,32 | 0,32 | 0,21 / 0,39 | 100% |
| FairnessIndex - ForzaIncentivante | 3 | 0,53 | 0,50 | 0,45 / 0,58 | 100% |
| FairnessIndex - ForzaIncentivante | 4 | 0,39 | 0,16 | 0,01 / 0,40 | 100% |
| Gini - FairnessIndex | 1 | 0,46 | 0,30 | 0,17 / 0,41 | 100% |
| Gini - FairnessIndex | 2 | -0,23 | -0,22 | -0,28 / -0,14 | 100% |
| Gini - FairnessIndex | 3 | -0,39 | -0,38 | -0,43 / -0,35 | 100% |
| Gini - FairnessIndex | 4 | -0,31 | -0,06 | -0,27 / 0,11 | 80% |
| FairnessIndex - EccessoMax_EUR | 1 | 0,61 | 0,58 | 0,52 / 0,64 | 100% |
| FairnessIndex - EccessoMax_EUR | 2 | 0,78 | 0,82 | 0,75 / 0,87 | 100% |
| FairnessIndex - EccessoMax_EUR | 3 | 0,91 | 0,89 | 0,84 / 0,96 | 100% |
| FairnessIndex - EccessoMax_EUR | 4 | 0,88 | 0,82 | 0,73 / 0,90 | 100% |

## Il capovolgimento con la penetrazione, replica per replica

- tau(Gini, forza incentivante) diventa piu' negativo di almeno 0,3 dalla fascia 1 alla 4: 20 repliche su 20 (r00: -0,23 -> -0,91);
- tau(Fairness Index, forza incentivante) passa da negativo (fascia 1) a positivo (fascia 3): 20 repliche su 20 (r00: -0,56 -> 0,53).

| Replica | Gini-IS f1 | Gini-IS f4 | FI-IS f1 | FI-IS f3 |
|---|---|---|---|---|
| r00 | -0,23 | -0,91 | -0,56 | 0,53 |
| r01 | -0,27 | -0,90 | -0,68 | 0,49 |
| r02 | -0,31 | -0,78 | -0,56 | 0,49 |
| r03 | -0,37 | -0,89 | -0,61 | 0,50 |
| r04 | -0,35 | -0,91 | -0,61 | 0,52 |
| r05 | -0,30 | -0,76 | -0,60 | 0,49 |
| r06 | -0,35 | -0,85 | -0,54 | 0,49 |
| r07 | -0,33 | -0,83 | -0,60 | 0,54 |
| r08 | -0,43 | -0,93 | -0,56 | 0,50 |
| r09 | -0,38 | -0,80 | -0,51 | 0,58 |
| r10 | -0,35 | -0,92 | -0,60 | 0,50 |
| r11 | -0,39 | -0,79 | -0,51 | 0,53 |
| r12 | -0,28 | -0,81 | -0,55 | 0,54 |
| r13 | -0,30 | -0,83 | -0,63 | 0,50 |
| r14 | -0,40 | -0,77 | -0,57 | 0,50 |
| r15 | -0,35 | -0,83 | -0,60 | 0,56 |
| r16 | -0,35 | -0,77 | -0,67 | 0,50 |
| r17 | -0,34 | -0,87 | -0,56 | 0,49 |
| r18 | -0,26 | -0,77 | -0,57 | 0,45 |
| r19 | -0,28 | -0,83 | -0,56 | 0,50 |
| r20 | -0,34 | -0,89 | -0,58 | 0,50 |

## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)

| Indicatore | r00 | Repliche (tutte le celle di tutte le repliche) |
|---|---|---|
| Gini | Equal Split 100% | Equal Split 100%, Cascading Tree 4% |
| FairnessIndex | Variance Least Core 100%, Shapley 46%, Cascading Tree 4% | Variance Least Core 98%, Shapley 51%, Proportional to Consumption 9% |
| Sigma | Variance Least Core 100%, Shapley 46%, Cascading Tree 4% | Variance Least Core 98%, Shapley 51%, Proportional to Consumption 7% |
| EccessoMax_EUR | Variance Least Core 100%, Shapley 82%, Tri-level EP 46% | Variance Least Core 100%, Shapley 94%, Remuneration Model 1 41% |
| CoalizioniInstabili | Variance Least Core 100%, Shapley 29%, Similarity-Utilization 7% | Variance Least Core 100%, Shapley 45%, Remuneration Model 1 16% |
| ForzaIncentivante | Pearson Key 96%, Tri-level EP 93%, Similarity-Utilization 82% | Pearson Key 95%, Tri-level EP 95%, Similarity-Utilization 86% |
| AllineamentoVirtu | Similarity-Utilization 100%, Pearson Key 89%, Tri-level EP 89% | Similarity-Utilization 99%, Pearson Key 78%, Tri-level EP 68% |
| AllineamentoVirtu_lordo | Similarity-Utilization 71%, Pearson Key 32%, Tri-level EP 29% | Similarity-Utilization 44%, Remuneration Model 1 36%, Variance Least Core 34% |

## Inversioni di graduatoria lungo gli assi

| Asse | Fisso | r00 | Mediana | Min-max |
|---|---|---|---|---|
| penetrazione | n = 10 | 25% | 22% | 17%-26% |
| penetrazione | n = 15 | 23% | 16% | 15%-22% |
| penetrazione | n = 18 | 21% | 21% | 16%-23% |
| penetrazione | n = 20 | 22% | 21% | 17%-24% |
| penetrazione | n = 25 | 19% | 17% | 14%-19% |
| penetrazione | n = 5 | 29% | 26% | 22%-35% |
| penetrazione | n = 8 | 28% | 26% | 19%-29% |
| taglia | fascia 1 (~27%) | 17% | 13% | 11%-16% |
| taglia | fascia 2 (~50%) | 10% | 18% | 12%-23% |
| taglia | fascia 3 (~75%) | 5% | 7% | 6%-12% |
| taglia | fascia 4 (~100%) | 9% | 10% | 4%-13% |

## Da cosa dipendono i punteggi (quota della varianza, livello base)

| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti | r00: penetrazione | r00: taglia |
|---|---|---|---|---|---|---|
| Gini | 59% | 6% | 22% | 13% | 71% | 4% |
| FairnessIndex | 72% | 9% | 7% | 12% | 79% | 7% |
| Sigma | 71% | 8% | 9% | 12% | 78% | 9% |
| EccessoMax_EUR | 60% | 10% | 7% | 24% | 79% | 7% |
| CoalizioniInstabili | 66% | 8% | 10% | 16% | 78% | 10% |
| ForzaIncentivante | 69% | 10% | 5% | 16% | 82% | 10% |
| AllineamentoVirtu | 70% | 4% | 6% | 20% | 74% | 6% |
| AllineamentoVirtu_lordo | 11% | 29% | 27% | 33% | 53% | 6% |

## Composizione (PA e imprese): coppie invertite rispetto al livello base

| Confronto | r00 (media sugli indicatori) | Mediana repliche |
|---|---|---|
| PA0 contro ND>=1 | 13% | 10% |
| PA0 contro PA>=1 | 13% | 10% |
| PA0-ND1 | 9% | 4% |
| PA0-ND1_PA1 | 13% | 10% |
| PA0-ND1_PA2 | 15% | 10% |
| PA0-ND1_PA3 | 13% | 10% |
| PA0-ND2 | 13% | 11% |
| PA0-ND2_PA1 | 14% | 12% |
| PA0-ND2_PA2 | 14% | 11% |
| PA0-ND2_PA3 | 12% | 9% |
| PA0-ND3 | 14% | 10% |
| PA0-ND3_PA1 | 15% | 11% |
| PA0-ND3_PA2 | 13% | 10% |
| PA0-ND3_PA3 | 11% | 8% |
| PA0-PA1 | 12% | 9% |
| PA0-PA2 | 15% | 11% |
| PA0-PA3 | 13% | 11% |

## Perdite di trade-off principali (perdita ottimistica media)

| Si sceglie | Si perde | r00 | Mediana | Min-max |
|---|---|---|---|---|
| Gini | EccessoMax_EUR | 0,73 | 0,71 | 0,68-0,77 |
| Gini | ForzaIncentivante | 0,80 | 0,82 | 0,79-0,83 |
| ForzaIncentivante | Gini | 0,94 | 0,88 | 0,85-0,91 |
| FairnessIndex | EccessoMax_EUR | 0,00 | 0,00 | 0,00-0,01 |
| EccessoMax_EUR | FairnessIndex | 0,00 | 0,00 | 0,00-0,00 |
