# Repliche dei partecipanti, blocco unito

Repliche analizzate: 20 (r01, r02, r03, r04, r05, r06, r07, r08, r09, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20). r00 (persone sole) non entra nei risultati.

Regola di lettura: una conclusione **regge** se vale in almeno il 75% delle repliche (15/20, test del segno a due code p = 0,041), **si inverte** se vale in al piu' il 25%, altrimenti **dipende dai partecipanti**. **Forte**: almeno il 85% (17/20). Fra parentesi l'intervallo esatto di Clopper-Pearson al 95%; per le mediane, fra quadre, l'intervallo al 95% delle statistiche d'ordine.

## Il numero di repliche basta?

| Tipo di conclusione | Conclusioni | Reggono | Forti | Dipendono | Si invertono | Meta' concordi | Bootstrap: stesso verdetto (mediana) |
|---|---|---|---|---|---|---|---|
| tau | 107 | 104 | 102 | 3 | 0 | 106/107 | 100% |
| vincitore | 224 | 221 | 216 | 3 | 0 | 218/224 | 100% |
| capovolgimento | 2 | 2 | 2 | 0 | 0 | 2/2 | 100% |
| soglia | 1 | 1 | 1 | 0 | 0 | 1/1 | 100% |
| **tutte** | 334 | 328 | 321 | 6 | 0 | 327/334 | 100% |

## Capovolgimento con la penetrazione e soglia regolatoria

| Conclusione | Repliche | Verdetto | Meta' concordi |
|---|---|---|---|
| tau(Gini, IS) scende di almeno 0,3 dalla fascia 1 alla 4 | 20/20 (83%-100%) | regge (forte) | si |
| tau(FI, IS) negativo in fascia 1 e positivo in fascia 3 | 20/20 (83%-100%) | regge (forte) | si |
| nessuna comunita' con imprese sopra il 55% | 20/20 (83%-100%) | regge (forte) | si |

## Chi vince (livello base: quota delle celle in cui il metodo e' fra i primi, pari compresi)

| Indicatore | Primi tre metodi, tutte le celle di tutte le repliche |
|---|---|
| Gini | Equal Split 100%, Cascading Tree 4% |
| FairnessIndex | Variance Least Core 98%, Shapley 51%, Proportional to Consumption 9% |
| Sigma | Variance Least Core 98%, Shapley 51%, Proportional to Consumption 7% |
| EccessoMax_EUR | Variance Least Core 100%, Shapley 94%, Remuneration Model 1 41% |
| CoalizioniInstabili | Variance Least Core 100%, Shapley 45%, Remuneration Model 1 16% |
| ForzaIncentivante | Pearson Key 95%, Tri-level EP 95%, Similarity-Utilization 86% |
| AllineamentoVirtu | Similarity-Utilization 99%, Pearson Key 78%, Tri-level EP 68% |
| AllineamentoVirtu_lordo | Similarity-Utilization 44%, Remuneration Model 1 36%, Variance Least Core 34% |

| Indicatore | Celle | Repliche col vincitore modale (media) |
|---|---|---|
| Gini | 295 | 100% |
| FairnessIndex | 295 | 90% |
| Sigma | 295 | 92% |
| EccessoMax_EUR | 295 | 85% |
| CoalizioniInstabili | 295 | 88% |
| ForzaIncentivante | 295 | 88% |
| AllineamentoVirtu | 295 | 83% |
| AllineamentoVirtu_lordo | 295 | 76% |

## Accordo fra criteri (tau-b medio per fascia, livello base)

| Coppia | Fascia | Mediana [IC 95%] | Min / max | Repliche col segno della mediana |
|---|---|---|---|---|
| Gini - ForzaIncentivante | 1 | -0,34 [-0,35; -0,30] | -0,43 / -0,26 | 100% |
| Gini - ForzaIncentivante | 2 | -0,78 [-0,80; -0,77] | -0,81 / -0,74 | 100% |
| Gini - ForzaIncentivante | 3 | -0,83 [-0,83; -0,82] | -0,84 / -0,80 | 100% |
| Gini - ForzaIncentivante | 4 | -0,83 [-0,89; -0,79] | -0,93 / -0,76 | 100% |
| FairnessIndex - ForzaIncentivante | 1 | -0,57 [-0,60; -0,56] | -0,68 / -0,51 | 100% |
| FairnessIndex - ForzaIncentivante | 2 | 0,32 [0,27; 0,35] | 0,21 / 0,39 | 100% |
| FairnessIndex - ForzaIncentivante | 3 | 0,50 [0,49; 0,52] | 0,45 / 0,58 | 100% |
| FairnessIndex - ForzaIncentivante | 4 | 0,16 [0,10; 0,19] | 0,01 / 0,40 | 100% |
| Gini - FairnessIndex | 1 | 0,30 [0,26; 0,33] | 0,17 / 0,41 | 100% |
| Gini - FairnessIndex | 2 | -0,22 [-0,26; -0,19] | -0,28 / -0,14 | 100% |
| Gini - FairnessIndex | 3 | -0,38 [-0,41; -0,37] | -0,43 / -0,35 | 100% |
| Gini - FairnessIndex | 4 | -0,06 [-0,10; -0,01] | -0,27 / 0,11 | 80% |
| FairnessIndex - EccessoMax_EUR | 1 | 0,58 [0,54; 0,59] | 0,52 / 0,64 | 100% |
| FairnessIndex - EccessoMax_EUR | 2 | 0,82 [0,80; 0,83] | 0,75 / 0,87 | 100% |
| FairnessIndex - EccessoMax_EUR | 3 | 0,89 [0,87; 0,90] | 0,84 / 0,96 | 100% |
| FairnessIndex - EccessoMax_EUR | 4 | 0,82 [0,81; 0,86] | 0,73 / 0,90 | 100% |

## Inversioni di graduatoria lungo gli assi

| Asse | Fisso | Mediana [IC 95%] | Min-max |
|---|---|---|---|
| penetrazione | n = 10 | 22% [21%; 24%] | 17%-26% |
| penetrazione | n = 15 | 16% [16%; 17%] | 15%-22% |
| penetrazione | n = 18 | 21% [19%; 22%] | 16%-23% |
| penetrazione | n = 20 | 21% [19%; 22%] | 17%-24% |
| penetrazione | n = 25 | 17% [16%; 17%] | 14%-19% |
| penetrazione | n = 5 | 26% [25%; 29%] | 22%-35% |
| penetrazione | n = 8 | 26% [25%; 27%] | 19%-29% |
| taglia | fascia 1 (~27%) | 13% [13%; 15%] | 11%-16% |
| taglia | fascia 2 (~50%) | 18% [17%; 19%] | 12%-23% |
| taglia | fascia 3 (~75%) | 7% [6%; 7%] | 6%-12% |
| taglia | fascia 4 (~100%) | 10% [6%; 11%] | 4%-13% |

## Da cosa dipendono i punteggi (quota della varianza, livello base)

| Indicatore | Penetrazione | Taglia | Interazione | Partecipanti |
|---|---|---|---|---|
| Gini | 59% | 6% | 22% | 13% |
| FairnessIndex | 72% | 9% | 7% | 12% |
| Sigma | 71% | 8% | 9% | 12% |
| EccessoMax_EUR | 60% | 10% | 7% | 24% |
| CoalizioniInstabili | 66% | 8% | 10% | 16% |
| ForzaIncentivante | 69% | 10% | 5% | 16% |
| AllineamentoVirtu | 70% | 4% | 6% | 20% |
| AllineamentoVirtu_lordo | 11% | 29% | 27% | 33% |

## Composizione (PA e imprese) rispetto al livello base

| Confronto | Coppie invertite (mediana) | Vincitore cambia (mediana) |
|---|---|---|
| PA0 contro ND>=1 | 10% | 5% |
| PA0 contro PA>=1 | 10% | 9% |
| PA0-ND1 | 4% | 4% |
| PA0-ND1_PA1 | 10% | 5% |
| PA0-ND1_PA2 | 10% | 9% |
| PA0-ND1_PA3 | 10% | 3% |
| PA0-ND2 | 11% | 5% |
| PA0-ND2_PA1 | 12% | 7% |
| PA0-ND2_PA2 | 11% | 5% |
| PA0-ND2_PA3 | 9% | 2% |
| PA0-ND3 | 10% | 5% |
| PA0-ND3_PA1 | 11% | 4% |
| PA0-ND3_PA2 | 10% | 5% |
| PA0-ND3_PA3 | 8% | 2% |
| PA0-PA1 | 9% | 9% |
| PA0-PA2 | 11% | 6% |
| PA0-PA3 | 11% | 12% |

## Perdite di trade-off principali (perdita ottimistica media)

| Si sceglie | Si perde | Mediana [IC 95%] | Min-max |
|---|---|---|---|
| Gini | EccessoMax_EUR | 0,71 [0,69; 0,74] | 0,68-0,77 |
| Gini | ForzaIncentivante | 0,82 [0,81; 0,82] | 0,79-0,83 |
| ForzaIncentivante | Gini | 0,88 [0,86; 0,88] | 0,85-0,91 |
| FairnessIndex | EccessoMax_EUR | 0,00 [0,00; 0,01] | 0,00-0,01 |
| EccessoMax_EUR | FairnessIndex | 0,00 [0,00; 0,00] | 0,00-0,00 |

## Insieme ridotto di indicatori

| Taglio di tau | Indicatore | Rappresentante modale | Concordanza delle coppie (mediana, min) |
|---|---|---|---|
| 0.7 | AllineamentoVirtu | ForzaIncentivante | 0,99, 0,97 |
| 0.7 | AllineamentoVirtu_lordo | AllineamentoVirtu_lordo | 1,00, 1,00 |
| 0.7 | CoalizioniInstabili | Sigma | 0,99, 0,97 |
| 0.7 | EccessoMax_EUR | Sigma | 0,96, 0,95 |
| 0.7 | FairnessIndex | Sigma | 1,00, 1,00 |
| 0.7 | ForzaIncentivante | ForzaIncentivante | 1,00, 1,00 |
| 0.7 | Gini | EI_orig | 1,00, 1,00 |
| 0.7 | Sigma | Sigma | 1,00, 1,00 |
| 0.5 | AllineamentoVirtu | ForzaIncentivante | 0,99, 0,97 |
| 0.5 | AllineamentoVirtu_lordo | AllineamentoVirtu_lordo | 1,00, 1,00 |
| 0.5 | CoalizioniInstabili | Sigma | 0,99, 0,97 |
| 0.5 | EccessoMax_EUR | Sigma | 0,96, 0,95 |
| 0.5 | FairnessIndex | Sigma | 1,00, 1,00 |
| 0.5 | ForzaIncentivante | ForzaIncentivante | 1,00, 1,00 |
| 0.5 | Gini | EI_orig | 1,00, 1,00 |
| 0.5 | Sigma | Sigma | 1,00, 1,00 |
| 0.3 | AllineamentoVirtu | ForzaIncentivante | 0,99, 0,97 |
| 0.3 | AllineamentoVirtu_lordo | AllineamentoVirtu_lordo | 1,00, 0,73 |
| 0.3 | CoalizioniInstabili | Sigma | 0,99, 0,97 |
| 0.3 | EccessoMax_EUR | Sigma | 0,96, 0,95 |
| 0.3 | FairnessIndex | Sigma | 1,00, 1,00 |
| 0.3 | ForzaIncentivante | ForzaIncentivante | 1,00, 1,00 |
| 0.3 | Gini | EI_orig | 1,00, 1,00 |
| 0.3 | Sigma | Sigma | 1,00, 1,00 |

## Fronte di Pareto (quota di comunita' in cui il metodo non e' dominato, mediana)

| Insieme di criteri | Metodi con quota mediana >= 50% |
|---|---|
| Equita(Gini) + Incentivo(IS) + Sostenibilita(VAN_min) | Equal Split 100%, Similarity-Utilization 89%, Remuneration Model 1 86%, Shapley 71%, Variance Least Core 68% |
| Equita(Gini) + Incentivo(coseno lordo) + Sostenibilita(VAN_min) | Equal Split 100%, Remuneration Model 1 68% |
| Merito(FI) + Stabilita(Eccesso) + Incentivo(IS) | Variance Least Core 100%, Pearson Key 88%, Tri-level EP 82% |
| Tutti i criteri normativi + IS + VAN_min | Equal Split 100%, Remuneration Model 1 95%, Variance Least Core 93%, Pearson Key 79%, Shapley 75%, Tri-level EP 75%, Similarity-Utilization 50% |

## Soglia regolatoria (energia condivisa / immessa)

| Gruppo | Comunita' | Max | Mediana | Sopra 55% | Repliche con almeno una sopra 55% | Taglie sopra 55% |
|---|---|---|---|---|---|---|
| households only | 560 | 81,4% | 19,7% | 70 | 20 | 5 8 10 15 18 20 25 |
| with firms | 3740 | 34,7% | 8,5% | 0 | 0 | - |
| with public buildings | 1600 | 36,1% | 12,0% | 0 | 0 | - |

## VAN per metodo (analisi complementare, tutte le comunita')

| Metodo | Gruppo | VAN minimo, mediana [p10; p90] EUR | Comunita' con almeno un VAN negativo |
|---|---|---|---|
| Cascading Tree | households only | 448 [-23; 625] | 19% |
| Cascading Tree | with firms | 782 [173; 1538] | 0% |
| Cascading Tree | with public buildings | 1032 [204; 2103] | 3% |
| Equal Split | households only | 652 [5; 966] | 9% |
| Equal Split | with firms | 1847 [520; 4544] | 0% |
| Equal Split | with public buildings | 2508 [423; 6223] | 0% |
| Pearson Key | households only | -133 [-151; -101] | 100% |
| Pearson Key | with firms | -68 [-104; 3] | 89% |
| Pearson Key | with public buildings | -72 [-110; 62] | 84% |
| Proportional to Consumption | households only | -96 [-129; -34] | 96% |
| Proportional to Consumption | with firms | -70 [-105; 21] | 86% |
| Proportional to Consumption | with public buildings | -70 [-109; 56] | 83% |
| Remuneration Model 1 | households only | 366 [-29; 616] | 22% |
| Remuneration Model 1 | with firms | 294 [30; 449] | 7% |
| Remuneration Model 1 | with public buildings | 413 [64; 612] | 8% |
| Shapley | households only | 200 [-59; 416] | 25% |
| Shapley | with firms | 299 [13; 583] | 8% |
| Shapley | with public buildings | 468 [6; 740] | 9% |
| Similarity-Utilization | households only | -128 [-148; -92] | 100% |
| Similarity-Utilization | with firms | 9 [-81; 389] | 48% |
| Similarity-Utilization | with public buildings | 26 [-83; 932] | 44% |
| Tri-level EP | households only | -133 [-152; -102] | 100% |
| Tri-level EP | with firms | -86 [-113; -15] | 92% |
| Tri-level EP | with public buildings | -88 [-120; 19] | 88% |
| Variance Least Core | households only | 60 [-72; 372] | 44% |
| Variance Least Core | with firms | 4 [-72; 277] | 47% |
| Variance Least Core | with public buildings | 193 [-85; 496] | 25% |
| Weighted Solidarity | households only | 103 [-103; 407] | 34% |
| Weighted Solidarity | with firms | 379 [10; 932] | 9% |
| Weighted Solidarity | with public buildings | 449 [31; 1129] | 8% |

## Quota dell'incentivo ai prosumer (livello base, mediana per fascia)

| Metodo | Fascia 1 | Fascia 2 | Fascia 3 |
|---|---|---|---|
| Cascading Tree | 48% | 62% | 78% |
| Equal Split | 27% | 50% | 75% |
| Pearson Key | 1% | 4% | 15% |
| Proportional to Consumption | 4% | 13% | 30% |
| Remuneration Model 1 | 25% | 41% | 56% |
| Shapley | 43% | 29% | 33% |
| Similarity-Utilization | 1% | 4% | 13% |
| Tri-level EP | 1% | 4% | 15% |
| Variance Least Core | 35% | 19% | 22% |
| Weighted Solidarity | 31% | 57% | 80% |

## Sensibilita' alla soglia di rilevanza (livello base)

| Escursione | Frazione di v(N) | Celle col vincitore cambiato (mediana, max) | Altro metodo primo (max) |
|---|---|---|---|
| 0.0 | 0.0 | 44%, 53% | 0 |
| 0.05 | 0.025 | 16%, 21% | 0 |
| 0.1 | 0.05 | 0%, 0% | 0 |
| 0.2 | 0.1 | 20%, 29% | 0 |

## Shapley esatto contro Adaptive Sampling (fino a 18 membri)

| Membri | Scarto relativo medio % (mediana) | Scarto massimo % (max) | Spearman minimo (min) |
|---|---|---|---|
| 5 | 1,20 | 5,53 | 0,90 |
| 8 | 0,98 | 6,87 | 0,88 |
| 10 | 1,03 | 8,45 | 0,92 |
| 15 | 1,30 | 10,13 | 0,96 |
| 18 | 1,10 | 8,34 | 0,96 |
