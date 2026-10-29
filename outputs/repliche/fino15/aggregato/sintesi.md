# Repliche dei partecipanti, blocco fino15

Repliche analizzate: 20 (r01, r02, r03, r04, r05, r06, r07, r08, r09, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20); r00 = identita' (schede di prima).

## Vincitori

Per ogni livello, indicatore, taglia e fascia: il vincitore piu' frequente fra le repliche,
in quante repliche vince lui, e se coincide con quello del disegno di prima (r00).

I vincitori si confrontano come insieme dei primi a pari merito.

| Indicatore | Celle | Repliche col vincitore modale (media) | Celle con modale = r00 | Repliche con almeno un primo in comune con r00 |
|---|---|---|---|---|
| Gini | 105 | 99% | 100% | 100% |
| FairnessIndex | 105 | 84% | 67% | 99% |
| Sigma | 105 | 86% | 74% | 99% |
| EccessoMax_EUR | 105 | 81% | 51% | 100% |
| CoalizioniInstabili | 105 | 85% | 68% | 100% |
| ForzaIncentivante | 105 | 85% | 65% | 93% |
| AllineamentoVirtu | 105 | 79% | 70% | 99% |
| AllineamentoVirtu_lordo | 105 | 69% | 37% | 91% |

## Accordo fra criteri (tau-b medio per fascia, livello base)

| Coppia | Fascia | r00 | Mediana repliche | Min-max | Repliche con il segno della mediana |
|---|---|---|---|---|---|
| Gini - ForzaIncentivante | 1 | -0,07 | -0,19 | -0,28 / -0,10 | 100% |
| Gini - ForzaIncentivante | 2 | -0,75 | -0,77 | -0,82 / -0,72 | 100% |
| Gini - ForzaIncentivante | 3 | -0,86 | -0,85 | -0,88 / -0,79 | 100% |
| Gini - ForzaIncentivante | 4 | -0,91 | -0,86 | -0,97 / -0,66 | 100% |
| FairnessIndex - ForzaIncentivante | 1 | -0,60 | -0,59 | -0,73 / -0,55 | 100% |
| FairnessIndex - ForzaIncentivante | 2 | 0,20 | 0,19 | 0,05 / 0,26 | 100% |
| FairnessIndex - ForzaIncentivante | 3 | 0,45 | 0,42 | 0,37 / 0,49 | 100% |
| FairnessIndex - ForzaIncentivante | 4 | 0,35 | 0,06 | -0,12 / 0,34 | 70% |
| Gini - FairnessIndex | 1 | 0,31 | 0,17 | 0,04 / 0,37 | 100% |
| Gini - FairnessIndex | 2 | -0,12 | -0,10 | -0,17 / 0,05 | 80% |
| Gini - FairnessIndex | 3 | -0,32 | -0,33 | -0,38 / -0,28 | 100% |
| Gini - FairnessIndex | 4 | -0,29 | 0,05 | -0,19 / 0,25 | 65% |
| FairnessIndex - EccessoMax_EUR | 1 | 0,65 | 0,65 | 0,58 / 0,70 | 100% |
| FairnessIndex - EccessoMax_EUR | 2 | 0,73 | 0,78 | 0,73 / 0,82 | 100% |
| FairnessIndex - EccessoMax_EUR | 3 | 0,85 | 0,85 | 0,79 / 0,91 | 100% |
| FairnessIndex - EccessoMax_EUR | 4 | 0,89 | 0,77 | 0,64 / 0,85 | 100% |

## Il capovolgimento con la penetrazione, replica per replica

- tau(Gini, forza incentivante) diventa piu' negativo di almeno 0,3 dalla fascia 1 alla 4: 20 repliche su 20 (r00: -0,07 -> -0,91);
- tau(Fairness Index, forza incentivante) passa da negativo (fascia 1) a positivo (fascia 3): 20 repliche su 20 (r00: -0,60 -> 0,45).

| Replica | Gini-IS f1 | Gini-IS f4 | FI-IS f1 | FI-IS f3 |
|---|---|---|---|---|
| r00 | -0,07 | -0,91 | -0,60 | 0,45 |
| r01 | -0,10 | -0,91 | -0,73 | 0,40 |
| r02 | -0,15 | -0,75 | -0,56 | 0,40 |
| r03 | -0,23 | -0,90 | -0,59 | 0,41 |
| r04 | -0,18 | -0,89 | -0,62 | 0,45 |
| r05 | -0,19 | -0,80 | -0,62 | 0,44 |
| r06 | -0,25 | -0,87 | -0,58 | 0,40 |
| r07 | -0,17 | -0,87 | -0,59 | 0,44 |
| r08 | -0,28 | -0,97 | -0,57 | 0,41 |
| r09 | -0,25 | -0,81 | -0,55 | 0,49 |
| r10 | -0,22 | -0,90 | -0,63 | 0,42 |
| r11 | -0,25 | -0,75 | -0,55 | 0,46 |
| r12 | -0,13 | -0,84 | -0,57 | 0,45 |
| r13 | -0,15 | -0,85 | -0,66 | 0,41 |
| r14 | -0,19 | -0,66 | -0,63 | 0,43 |
| r15 | -0,23 | -0,88 | -0,63 | 0,46 |
| r16 | -0,17 | -0,74 | -0,71 | 0,42 |
| r17 | -0,26 | -0,90 | -0,55 | 0,40 |
| r18 | -0,14 | -0,80 | -0,59 | 0,37 |
| r19 | -0,16 | -0,85 | -0,57 | 0,41 |
| r20 | -0,22 | -0,95 | -0,58 | 0,44 |

## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)

| Indicatore | r00 | Repliche (tutte le celle di tutte le repliche) |
|---|---|---|
| Gini | Equal Split 100% | Equal Split 100%, Cascading Tree 4% |
| FairnessIndex | Nucleolo 100%, Variance Least Core 100%, Shapley 44% | Variance Least Core 97%, Nucleolo 93%, Shapley 51% |
| Sigma | Variance Least Core 100%, Nucleolo 94%, Shapley 44% | Variance Least Core 96%, Nucleolo 92%, Shapley 50% |
| EccessoMax_EUR | Nucleolo 100%, Variance Least Core 100%, Shapley 69% | Nucleolo 100%, Variance Least Core 100%, Shapley 89% |
| CoalizioniInstabili | Nucleolo 100%, Variance Least Core 100%, Shapley 31% | Nucleolo 100%, Variance Least Core 100%, Shapley 46% |
| ForzaIncentivante | Pearson Key 94%, Tri-level EP 94%, Similarity-Utilization 75% | Pearson Key 96%, Tri-level EP 94%, Similarity-Utilization 85% |
| AllineamentoVirtu | Pearson Key 100%, Similarity-Utilization 100%, Tri-level EP 100% | Similarity-Utilization 99%, Pearson Key 80%, Tri-level EP 73% |
| AllineamentoVirtu_lordo | Similarity-Utilization 69%, Nucleolo 38%, Variance Least Core 38% | Similarity-Utilization 55%, Pearson Key 38%, Tri-level EP 37% |

## Inversioni di graduatoria lungo gli assi

| Asse | Fisso | r00 | Mediana | Min-max |
|---|---|---|---|---|
| penetrazione | n = 10 | 23% | 20% | 15%-24% |
| penetrazione | n = 15 | 21% | 14% | 13%-19% |
| penetrazione | n = 5 | 27% | 25% | 21%-33% |
| penetrazione | n = 8 | 27% | 24% | 18%-28% |
| taglia | fascia 1 (~26%) | 14% | 14% | 10%-17% |
| taglia | fascia 2 (~50%) | 8% | 15% | 8%-20% |
| taglia | fascia 3 (~74%) | 0% | 5% | 1%-10% |
| taglia | fascia 4 (~100%) | 4% | 8% | 1%-11% |

## Da cosa dipendono i punteggi (quota della varianza, livello base)

| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti | r00: penetrazione | r00: taglia |
|---|---|---|---|---|---|---|
| Gini | 46% | 8% | 31% | 15% | 61% | 5% |
| FairnessIndex | 66% | 11% | 8% | 15% | 75% | 9% |
| Sigma | 64% | 10% | 11% | 16% | 74% | 11% |
| EccessoMax_EUR | 55% | 10% | 7% | 28% | 77% | 8% |
| CoalizioniInstabili | 64% | 6% | 10% | 20% | 79% | 10% |
| ForzaIncentivante | 64% | 10% | 9% | 17% | 81% | 11% |
| AllineamentoVirtu | 70% | 4% | 6% | 20% | 85% | 3% |
| AllineamentoVirtu_lordo | 5% | 34% | 31% | 30% | 85% | 4% |

## Composizione (PA e imprese): coppie invertite rispetto al livello base

| Confronto | r00 (media sugli indicatori) | Mediana repliche |
|---|---|---|
| PA0 contro ND>=1 | 12% | 10% |
| PA0 contro PA>=1 | 13% | 12% |
| PA0-ND1 | 9% | 5% |
| PA0-ND1_PA1 | 11% | 10% |
| PA0-ND1_PA2 | 14% | 11% |
| PA0-ND1_PA3 | 14% | 11% |
| PA0-ND2 | 13% | 11% |
| PA0-ND2_PA1 | 13% | 13% |
| PA0-ND2_PA2 | 12% | 10% |
| PA0-ND2_PA3 | 10% | 8% |
| PA0-ND3 | 12% | 10% |
| PA0-ND3_PA1 | 13% | 11% |
| PA0-ND3_PA2 | 10% | 8% |
| PA0-ND3_PA3 | 10% | 8% |
| PA0-PA1 | 11% | 10% |
| PA0-PA2 | 15% | 13% |
| PA0-PA3 | 14% | 13% |

## Perdite di trade-off principali (perdita ottimistica media)

| Si sceglie | Si perde | r00 | Mediana | Min-max |
|---|---|---|---|---|
| Gini | EccessoMax_EUR | 0,72 | 0,70 | 0,64-0,75 |
| Gini | ForzaIncentivante | 0,79 | 0,80 | 0,76-0,82 |
| ForzaIncentivante | Gini | 0,92 | 0,86 | 0,83-0,89 |
| FairnessIndex | EccessoMax_EUR | 0,00 | 0,00 | 0,00-0,02 |
| EccessoMax_EUR | FairnessIndex | 0,00 | 0,00 | 0,00-0,00 |
