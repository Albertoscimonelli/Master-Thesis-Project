# Analisi aggiuntive per il capitolo 7

Generato da `CER_repliche/analisi_aggiuntive.py` sulle repliche r01-r20. Le macro LaTeX sono in `outputs/tesi_finale/numeri_aggiuntivi.tex`.

| Macro | Valore | Descrizione |
|---|---|---|
| `\ASLOneVNMax` | 0.9 | distanza L1 fra AS e Shapley esatto in % di v(N): massimo delle mediane per taglia (5-18 membri) |
| `\BreakEvenIncentive` | 10 | incentivo annuo di pareggio, mediana (EUR/anno) |
| `\BreakEvenIncentivePNinety` | 11 | lo stesso, 90 percentile |
| `\CorrConsumersMax` | 0.81 | lo stesso, massimo |
| `\CorrConsumersMin` | 0.63 | correlazione quota-virtuosita' fra i consumatori: minimo su Shapley, VLC, PK, TlE e fasce 1-3 |
| `\CorrProsumersShapleyBandOne` | -0.66 | correlazione quota-virtuosita' fra i prosumer, Shapley, fascia 1 |
| `\CorrProsumersShapleyBandThree` | 0.66 | correlazione quota-virtuosita' fra i prosumer, Shapley, fascia 3 |
| `\CorrProsumersVLCBandOne` | -0.63 | correlazione quota-virtuosita' fra i prosumer, Variance Least Core, fascia 1 |
| `\CorrProsumersVLCBandThree` | 0.70 | correlazione quota-virtuosita' fra i prosumer, Variance Least Core, fascia 3 |
| `\EPActiveSizes` | 25 | taglie di quelle comunita' |
| `\ExcessESFirms` | 45.1 | eccesso massimo mediano dell'Equal Split, % di v(N), with firms |
| `\ExcessESHouseholds` | 16.0 | eccesso massimo mediano dell'Equal Split, % di v(N), households only |
| `\ExcessESPublic` | 47.4 | eccesso massimo mediano dell'Equal Split, % di v(N), with public buildings |
| `\ExcessWSFirms` | 24.9 | eccesso massimo mediano del Weighted Solidarity, % di v(N), with firms |
| `\ExcessWSHouseholds` | 21.2 | eccesso massimo mediano del Weighted Solidarity, % di v(N), households only |
| `\ExcessWSPublic` | 22.0 | eccesso massimo mediano del Weighted Solidarity, % di v(N), with public buildings |
| `\HouseholdsGainEURESFirms` | 58 | guadagno mediano per famiglia (EUR/anno), Equal Split, with firms |
| `\HouseholdsGainEURESPublic` | 120 | guadagno mediano per famiglia (EUR/anno), Equal Split, with public buildings |
| `\HouseholdsGainEURRMOneFirms` | -3 | guadagno mediano per famiglia (EUR/anno), Remuneration Model 1, with firms |
| `\HouseholdsGainEURRMOnePublic` | 1 | guadagno mediano per famiglia (EUR/anno), Remuneration Model 1, with public buildings |
| `\HouseholdsGainEURShapleyFirms` | 17 | guadagno mediano per famiglia (EUR/anno), Shapley, with firms |
| `\HouseholdsGainEURShapleyPublic` | 19 | guadagno mediano per famiglia (EUR/anno), Shapley, with public buildings |
| `\HouseholdsGainPctESFirms` | 100 | % famiglie che guadagnano quando entrano PA o imprese, Equal Split, with firms |
| `\HouseholdsGainPctESPublic` | 100 | % famiglie che guadagnano quando entrano PA o imprese, Equal Split, with public buildings |
| `\HouseholdsGainPctRMOneFirms` | 43 | % famiglie che guadagnano quando entrano PA o imprese, Remuneration Model 1, with firms |
| `\HouseholdsGainPctRMOnePublic` | 56 | % famiglie che guadagnano quando entrano PA o imprese, Remuneration Model 1, with public buildings |
| `\HouseholdsGainPctShapleyFirms` | 90 | % famiglie che guadagnano quando entrano PA o imprese, Shapley, with firms |
| `\HouseholdsGainPctShapleyPublic` | 84 | % famiglie che guadagnano quando entrano PA o imprese, Shapley, with public buildings |
| `\ISSignFlipLevels` | PA1 | livelli di quelle comunita' |
| `\LevelsWithoutLargePublic` | ND1, ND1_PA1, ND2, ND2_PA1, ND3, ND3_PA1, PA1 | livelli senza PA2/PA3 |
| `\MostUnstableFirms` | Equal Split | metodo con l'eccesso mediano piu' alto, with firms |
| `\MostUnstableHouseholds` | Weighted Solidarity | metodo con l'eccesso mediano piu' alto, households only |
| `\MostUnstablePublic` | Equal Split | metodo con l'eccesso mediano piu' alto, with public buildings |
| `\NPVAnnuityFactor` | 13.59 | fattore di annualita' del VAN (EUR di VAN per EUR/anno di incentivo) |
| `\NPVNoIncentiveNegMedian` | -142 | VAN senza incentivo, mediana dei negativi (EUR) |
| `\NPVNoIncentiveNegPFive` | -154 | lo stesso, 5 percentile |
| `\NPVNoIncentiveNegPNinetyFive` | -118 | lo stesso, 95 percentile |
| `\NPVNoIncentivePosMedian` | 1035 | VAN senza incentivo, mediana dei positivi (EUR) |
| `\NumCommunitiesEPActive` | 392 | comunita' con almeno un membro vulnerabile (livello EP del Tri-level attivo) |
| `\NumCommunitiesWithinConsumersMin` | 80 | comunita' minime usate per fascia fra i consumatori (gruppi >= 4) |
| `\NumCommunitiesZeroShare` | 40 | comunita' in cui almeno un metodo lascia un membro a quota zero |
| `\NumHouseholdCommunitiesBandsOneThree` | 420 | comunita' domestiche delle fasce 1-3 |
| `\NumISSignFlips` | 4 | comunita' in cui il denominatore della forza incentivante e' negativo (segno invertito) |
| `\NumReplicasEPActive` | 8 | repliche in cui compaiono |
| `\NumericalShareNonDomFirms` | 17 | quota numerica mediana dei membri non domestici, with firms |
| `\NumericalShareNonDomPublic` | 13 | quota numerica mediana dei membri non domestici, with public buildings |
| `\ParetoGrossES` | 100 | % comunita' in cui Equal Split non e' dominato con Gini + allineamento lordo + VAN minimo |
| `\ParetoGrossOthers` | 0 | altri metodi non dominati in almeno meta' delle comunita' in quell'insieme |
| `\ParetoGrossRMOne` | 68 | % comunita' in cui Remuneration Model 1 non e' dominato con Gini + allineamento lordo + VAN minimo |
| `\PctCommunitiesWithFirms` | 63 | % delle 5900 comunita' con imprese |
| `\PctISTiesPKTLE` | 96 | % celle in cui PK e TlE sono entrambi primi sulla forza incentivante, fra quelle in cui uno dei due lo e' |
| `\PctProsumersNegativeNoIncentive` | 71 | % prosumer domestici con VAN negativo senza incentivo |
| `\PctSeparationGross` | 10 | stessa quota sui profili lordi |
| `\PctSeparationNet` | 100 | % comunita' domestiche fasce 1-3 in cui ogni prosumer e' meno virtuoso (netto) di ogni consumatore |
| `\PctTVPKTLEBelowFive` | 93 | % comunita' con distanza PK - TlE sotto il 5% di v(N) |
| `\PctVLCMarginBelowFive` | 99 | % comunita' con margine VLC sotto il 5% di v(N) (soglia di rilevanza) |
| `\PctVLCMarginBelowOne` | 91 | % comunita' (tutte) con margine VLC sotto l'1% di v(N) |
| `\PctVLCMarginBelowOneHouseholds` | 71 | lo stesso, domestico |
| `\ProsumerIncentiveES` | 40 | incentivo annuo mediano di un prosumer domestico, Equal Split (EUR/anno) |
| `\ProsumerIncentivePK` | 6 | incentivo annuo mediano di un prosumer domestico, Pearson Key (EUR/anno) |
| `\ProsumerIncentiveSU` | 7 | incentivo annuo mediano di un prosumer domestico, Similarity-Utilization (EUR/anno) |
| `\ProsumerIncentiveShapley` | 17 | incentivo annuo mediano di un prosumer domestico, Shapley (EUR/anno) |
| `\ProsumerIncentiveTlE` | 6 | incentivo annuo mediano di un prosumer domestico, Tri-level EP (EUR/anno) |
| `\ProsumerIncentiveVLC` | 14 | incentivo annuo mediano di un prosumer domestico, Variance Least Core (EUR/anno) |
| `\RMOneGainEURMax` | -1 | lo stesso, massimo |
| `\RMOneGainEURMin` | -17 | Remuneration Model 1: guadagno mediano minimo (EUR/anno), livelli senza PA2/PA3 |
| `\RMOneGainPctMax` | 41 | lo stesso, massima |
| `\RMOneGainPctMin` | 18 | Remuneration Model 1: % minima di famiglie che guadagnano, livelli senza PA2/PA3 |
| `\ShapleyCoreBandFourSizeEight` | 90 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 8 membri |
| `\ShapleyCoreBandFourSizeFive` | 100 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 5 membri |
| `\ShapleyCoreBandFourSizeOneEight` | 15 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 18 membri |
| `\ShapleyCoreBandFourSizeOneFive` | 35 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 15 membri |
| `\ShapleyCoreBandFourSizeOneZero` | 85 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 10 membri |
| `\ShapleyCoreBandFourSizeTwoFive` | 0 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 25 membri |
| `\ShapleyCoreBandFourSizeTwoZero` | 10 | % comunita' domestiche di fascia 4 con lo Shapley nel nucleo, 20 membri |
| `\ShapleyCoreBandOneSmallest` | 100 | lo stesso in fascia 1 a 5 membri |
| `\ShapleyCoreBandsTwoThreeMax` | 10 | massimo nelle fasce 2-3, su tutte le taglie |
| `\ShapleyCoreFirms` | 0.6 | % comunita' con lo Shapley nel nucleo, with firms |
| `\ShapleyCoreHouseholds` | 17.0 | % comunita' con lo Shapley nel nucleo, households only |
| `\ShapleyCorePublic` | 14.4 | % comunita' con lo Shapley nel nucleo, with public buildings |
| `\ShapleyShareSingleProsumer` | 53 | quota mediana di v(N) data dallo Shapley all'unico prosumer in quelle comunita' |
| `\ShareNonDomPKFirms` | 53 | quota mediana dell'incentivo ai membri non domestici, Pearson Key, with firms |
| `\ShareNonDomPKPublic` | 64 | quota mediana dell'incentivo ai membri non domestici, Pearson Key, with public buildings |
| `\ShareNonDomPtCFirms` | 67 | quota mediana dell'incentivo ai membri non domestici, Proportional to Consumption, with firms |
| `\ShareNonDomPtCPublic` | 77 | quota mediana dell'incentivo ai membri non domestici, Proportional to Consumption, with public buildings |
| `\ShareNonDomRMOneFirms` | 73 | quota mediana dell'incentivo ai membri non domestici, Remuneration Model 1, with firms |
| `\ShareNonDomRMOnePublic` | 69 | quota mediana dell'incentivo ai membri non domestici, Remuneration Model 1, with public buildings |
| `\ShareNonDomSUFirms` | 9 | quota mediana dell'incentivo ai membri non domestici, Similarity-Utilization, with firms |
| `\ShareNonDomSUPublic` | 10 | quota mediana dell'incentivo ai membri non domestici, Similarity-Utilization, with public buildings |
| `\ShareNonDomShapleyFirms` | 62 | quota mediana dell'incentivo ai membri non domestici, Shapley, with firms |
| `\ShareNonDomShapleyPublic` | 66 | quota mediana dell'incentivo ai membri non domestici, Shapley, with public buildings |
| `\ShareNonDomVLCFirms` | 62 | quota mediana dell'incentivo ai membri non domestici, Variance Least Core, with firms |
| `\ShareNonDomVLCPublic` | 70 | quota mediana dell'incentivo ai membri non domestici, Variance Least Core, with public buildings |
| `\ShareNonDomWSFirms` | 40 | quota mediana dell'incentivo ai membri non domestici, Weighted Solidarity, with firms |
| `\ShareNonDomWSPublic` | 47 | quota mediana dell'incentivo ai membri non domestici, Weighted Solidarity, with public buildings |
| `\SlopeConsumersPearsonMax` | 1.55 | pendenza relativa a SU fra i consumatori, Pearson Key, massimo sulle fasce 1-3 |
| `\SlopeConsumersPearsonMin` | 1.20 | pendenza relativa a SU fra i consumatori, Pearson Key, minimo sulle fasce 1-3 |
| `\SlopeConsumersShapleyMax` | 1.25 | pendenza relativa a SU fra i consumatori, Shapley, massimo sulle fasce 1-3 |
| `\SlopeConsumersShapleyMin` | 1.03 | pendenza relativa a SU fra i consumatori, Shapley, minimo sulle fasce 1-3 |
| `\SlopeConsumersTriLevelMax` | 1.59 | pendenza relativa a SU fra i consumatori, Tri-level EP, massimo sulle fasce 1-3 |
| `\SlopeConsumersTriLevelMin` | 1.20 | pendenza relativa a SU fra i consumatori, Tri-level EP, minimo sulle fasce 1-3 |
| `\SlopeConsumersVLCMax` | 1.43 | pendenza relativa a SU fra i consumatori, Variance Least Core, massimo sulle fasce 1-3 |
| `\SlopeConsumersVLCMin` | 1.15 | pendenza relativa a SU fra i consumatori, Variance Least Core, minimo sulle fasce 1-3 |
| `\TVCTESHouseholds` | 9.0 | distanza TV mediana Cascading Tree - Equal Split, domestico |
| `\TVPKPtCHouseholds` | 7.4 | distanza TV mediana PK - Prop. to Consumption, domestico |
| `\TVPKSUAll` | 29.4 | distanza TV mediana PK - SU, tutte le comunita' |
| `\TVPKSUHouseholds` | 11.4 | distanza TV mediana PK - SU, domestico |
| `\TVPKTLEAll` | 2.8 | distanza TV mediana PK - TlE, tutte le comunita' |
| `\TVPKTLEEPActive` | 3.3 | distanza PK - TlE mediana dove il livello EP e' attivo |
| `\TVPKTLEHouseholds` | 1.5 | distanza TV mediana PK - TlE, % di v(N), domestico |
| `\TVPKTLEHouseholdsPNinety` | 2.6 | lo stesso, 90 percentile |
| `\TVPKTLEMax` | 7.3 | distanza PK - TlE massima |
| `\TVShapleyVLCAll` | 8.1 | distanza TV mediana Shapley - VLC, tutte le comunita' |
| `\TauFairnessIndexAllineamentoVirtulordoBandFour` | 0.20 | tau-b Fairness Index - allineamento lordo, fascia 4 (mediana sulle repliche) |
| `\TauFairnessIndexAllineamentoVirtulordoBandOne` | 0.16 | tau-b Fairness Index - allineamento lordo, fascia 1 (mediana sulle repliche) |
| `\TauFairnessIndexAllineamentoVirtulordoBandThree` | -0.06 | tau-b Fairness Index - allineamento lordo, fascia 3 (mediana sulle repliche) |
| `\TauFairnessIndexAllineamentoVirtulordoBandTwo` | 0.20 | tau-b Fairness Index - allineamento lordo, fascia 2 (mediana sulle repliche) |
| `\TauISConsumerShareBandOne` | 0.91 | tau-b fra forza incentivante e quota ai consumatori, fascia 1 (mediana) |
| `\TauISConsumerShareBandThree` | 1.00 | tau-b fra forza incentivante e quota ai consumatori, fascia 3 (mediana) |
| `\TauISConsumerShareBandTwo` | 0.96 | tau-b fra forza incentivante e quota ai consumatori, fascia 2 (mediana) |
| `\VLCMarginEURLargest` | -1.1 | lo stesso a 25 membri |
| `\VLCMarginEURSmallest` | -10 | margine VLC in EUR/anno, mediana a 5 membri, domestico |
| `\VLCMarginLargest` | -0.10 | lo stesso a 25 membri |
| `\VLCMarginSmallest` | -3.5 | margine VLC (eccesso massimo, % di v(N)), mediana a 5 membri, domestico |
| `\VLCMarginTwenty` | -0.18 | margine VLC, mediana a 20 membri, domestico (% di v(N)) |
| `\VirtGrossConsumer` | 0.52 | virtuosita' lorda mediana dei consumatori, fasce 1-3 |
| `\VirtGrossProsumer` | 0.53 | virtuosita' lorda mediana dei prosumer, fasce 1-3 |
| `\VirtNetConsumerMax` | 0.50 | virtuosita' netta mediana dei consumatori, massimo sulle fasce 1-3 |
| `\VirtNetConsumerMin` | 0.47 | virtuosita' netta mediana dei consumatori, minimo sulle fasce 1-3 |
| `\VirtNetProsumerMax` | 0.02 | virtuosita' netta mediana dei prosumer, massimo sulle fasce 1-3 |
| `\VirtNetProsumerMin` | 0.01 | virtuosita' netta mediana dei prosumer, minimo sulle fasce 1-3 (domestico) |
| `\ZeroShareMethods` | Prop. to Consumption, Pearson Key, Similarity-Utilization, Tri-level EP | metodi che lo fanno |
| `\ZeroShareSizes` | 5 | taglie |
