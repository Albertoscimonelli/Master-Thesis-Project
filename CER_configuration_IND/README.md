# Asse "imprese": comunità con imprese (ND) e con imprese e PA

Dopo l'asse **PA** (`CER_configuration_PA/`), questa cartella aggiunge le **imprese** (ND = non
domestici privati: PMI, uffici e simili; le PA restano a parte). Le schede si generano con
`genera_varianti_IND.py`. `MAIN2.m` le legge con `MAIN2_IND=1` (spento di default: senza, il run
è identico a prima), ad esempio:

```bash
MAIN2_IND=1 matlab -batch "MAIN2"                                     # tutte fino a 18 membri
MAIN2_IND=1 MAIN2_SCHEDE="CER_9_9_0;ND2/CER_9_9_0" matlab -batch "MAIN2"   # poche schede
```

Ogni livello (`ND1`, `ND2_PA1`, …) ha la sua analisi e le sue tabelle; il confronto con il livello
0 è in `confronto_PA/`. Il quadro generale (strati D, D+PA, D+ND, D+ND+PA) e come `MAIN2` li
raggruppa sono nel README principale, §7.11. Il run completo non è ancora stato lanciato.

## Livelli

Per ogni scheda di `CER_configuration/` con **N ≥ 15** (le imprese si inseriscono da 15 membri):

| Cartella | Contenuto |
|---|---|
| `ND1`, `ND2`, `ND3` | famiglie + 1, 2 o 3 imprese |
| `ND{k}_PA{p}` | famiglie + k imprese + p PA (p = 1, 2, 3): 9 cartelle |
| `profili/<livello>/` | i CSV dei profili di carico, uno per scheda |

**Perché 1-3 imprese.** Nel database pubblico delle CER italiane [DB] le CER del Nord con imprese
prosumer ne hanno 1 in 18 casi, 2 in 10, 3 in 2, 4 o più in 8: una o due nel 74% dei casi. Fino al
25 ottobre i livelli erano 1, 3 e 5 imprese; 5 imprese è un caso raro e portava le imprese al 99%
dei consumi, quindi è stato tolto. Numeri, metodo e limiti in
[`data/external/koltunov2026/README.md`](../data/external/koltunov2026/README.md).

## La regola

Come per le PA: N, C e P restano quelli della scheda; ogni impresa e ogni PA è un **prosumer con il
proprio impianto**; per ognuno che entra esce l'ultimo prosumer domestico (per id), con il suo
impianto. Due vincoli, entrambi verificati con `assert` nello script:

1. **Imprese più PA restano sotto il 50% di N**: al massimo ⌈N/2⌉ − 1 (7 a N = 15, 8 a N = 18,
   9 a N = 20, 12 a N = 25, …). Ogni scheda riporta la quota in intestazione.
2. **Prosumer domestici sufficienti**: imprese + PA ≤ P. Se i prosumer sono meno, la variante non
   si fa.

Esempio su `CER_9_9_0` (18 membri: 9 famiglie consumatrici, 9 prosumer): `ND2` = 9 consumatrici,
7 famiglie prosumer, antigelo e office_zummo; `ND3_PA3` = 9 consumatrici, 3 famiglie prosumer,
3 imprese e 3 PA (6 su 18, il 33%).

## Le imprese (ordine di ingresso)

| # | Impresa | Categoria | Carico | FV | kWp (stima) | P_prel_kW | Tariffa | Usata |
|---|---|---|---|---|---|---|---|---|
| 1 | antigelo | industriale | reale 2024, 15.720 kWh | `PROVA_CER_1_Project_antigelo.CSV` | 33 | 15 | ORARIO_VARIABILE | sì |
| 2 | office_zummo | terziario | reale 2024, 52.759 kWh | `..._office_zummo.CSV` | 129 | 35 | BIORARIA | sì |
| 3 | small_industry | industriale | RAMP (`csv_scheda9`), 61.692 kWh | `..._small_industry.CSV` | 69 | 50 | ORARIO_VARIABILE | sì |
| 4 | plastica | industriale | reale 2024, 2.012.615 kWh | `..._plastic_industry.CSV` | 250 | 535 | ORARIO_VARIABILE | no (test finale) |
| 5 | office | terziario | RAMP (`csv_scheda9`), 4.781 kWh | `..._office.CSV` | 17,5 | 10 | BIORARIA | no |

L'ordine mette prima i dati reali. Con al massimo 3 imprese entrano solo le prime tre. Il
**retail** (RAMP, senza FV) non è usato. Le PA sono quelle di
[`CER_configuration_PA/README.md`](../CER_configuration_PA/README.md).

**Confronto con le CER reali** ([K26], [DB]):
- Potenza media di un impianto PMI al Nord: 107 kW [K26, Fig. 7]. Le tre imprese usate: 33, 129
  e 69 kWp.
- FV per membro nelle CER reali da 15-25 membri: quartili 1,95 / 5,84 / 22,3 kWp [DB]. Nelle
  nostre schede: con 1 impresa 2,2-3,4; con 3 imprese 10-14; con 3 imprese e 3 PA oltre il terzo
  quartile.

## Come sono costruiti i dati

- **Carichi reali** (antigelo, office_zummo; plastica pronta ma non usata):
  `CER_LoadProfiles/outputs/Valencia/`, 2024. Il 2024 è bisestile e parte di lunedì, la griglia è il
  2025 (mercoledì). Ogni giorno del 2025 prende il giorno 2024 con lo **stesso giorno della
  settimana** più vicino (0-6 giorni dopo, altrimenti 7 giorni prima): il 29/02 non è un giorno della
  griglia, i feriali restano feriali. Per questo l'energia annua differisce di poco dal file originale
  (antigelo 15.769 → 15.720 kWh).
- **Carichi RAMP**: colonna `small_industry_1_kWh` di `csv_scheda9/profili_tutti.csv`.
- **Categoria**: antigelo e small_industry → `industriale`; office_zummo → `terziario`. Nessuna è
  esente dal fattore F; il premio dimezzato per le PMI con contributo in conto capitale è anche in
  [K26] (p. 41).
- **Costo impianto**: 730 €/kWp, come le PA (parametri di `scenario_economico.txt`).

## Punti aperti

1. **kWp stimati.** I file PVsyst non riportano la potenza: i valori sono produzione annua / 1480
   kWh/kWp. Se cambiano vanno rigenerate le schede (cambiano capex e quota).
2. **Potenza impegnata.** Per antigelo e zummo è il picco del profilo arrotondato a 5 kW: la potenza
   contrattuale non è nota.
3. **Luogo.** Consumi di Valencia, FV simulato su Milano (Duomo, TMY PVGIS): incoerenza dichiarata.
4. **Le imprese pesano molto in energia** (tabella sotto): la regola del 50% vale sul numero di
   membri, non sui consumi.
5. **FV sovradimensionato** per antigelo (3,1× il carico) e office_zummo (3,6×): la produzione va
   quasi tutta in immissione, come per il comune. Autoconsumo dell'impianto: antigelo 22%, zummo
   18%, small_industry 40%. Il 49,1% medio citato da [K26] non è un buon termine di paragone (è
   quasi sempre un 50% dichiarato nei business plan).
6. **Scaglione TIP.** Zummo (~129 kWp) è sotto i 200 kW e sta nello scaglione giusto; con le PA vale
   l'avvertenza del palazzetto (README §7.10).
7. **Tariffe** assunte (non note per le imprese reali).
8. **Dati reali.** I consumi di antigelo, zummo e plastica sono di aziende reali: i file sono fuori da
   git (`Valencia/` non tracciata; schede e profili ignorati da `.gitignore`).
9. **Prosumer rimossi:** l'ultimo per id; se pesa sui risultati va cambiato nello script.
10. **Profili non versionati:** ~770 MB in `profili/`, si rigenerano con
    `python -I CER_configuration_IND/genera_varianti_IND.py` dalla radice (~1 minuto).

## Test lasciati per la fine

- **Plastica** (2 GWh/anno, picco 535 kW, circa 40 volte i consumi di una CER di 18 famiglie): un
  livello di sensibilità `ND3p` = antigelo + office_zummo + plastica, per vedere quanto pesa
  un'impresa grande. Prima va verificato che sia una PMI: le grandi imprese non possono essere membri
  di una CER ([K26], nota 39).
- **Filtro sulla penetrazione** (README §7.11): l'83% delle CER reali del Nord ha prosumer ≤ 50%
  dei membri. Se le schede al 75% e al 100% non danno risultati notevoli, le si può escludere.

## Numeri (28 schede con N ≥ 15)

| Fascia | Schede sorgente | Varianti |
|---|---|---|
| N = 15, 18 | `0_15_0` `4_11_0` `7_8_0` `11_4_0` `0_18_0` `4_14_0` `9_9_0` `13_5_0` | 92 |
| N = 20, 25 | `0_20_0` `5_15_0` `10_10_0` `15_5_0` `0_25_0` `6_19_0` `12_13_0` `18_7_0` | 95 |
| N = 50, 75, 100 | 12 schede | 144 |
| **Totale** | | **331** (5 combinazioni scartate per i due vincoli) |

Ordine di esecuzione previsto per i run: (1) N < 15, già eseguito il 20 ottobre; (2) N = 15 e 18;
(3) N = 20 e 25; (4) N = 50-100. Un salvataggio (checkpoint, workspace, README, commit) a fine blocco.
Oltre 18 membri `MAIN2` salta Shapley, Nucleolo ed eccesso di coalizione (2^n); oltre 25 il Variance
Least Core non converge (tetto imposto dopo un run fallito, da riprovare per il blocco 4).

## Verifiche (26 ottobre 2026)

Tutte le **331 schede** sono state lette con `load_cer_input`, `load_cer_data` e
`align_members_to_users` in MATLAB: 0 errori, carichi e FV finiti e non negativi, quota di imprese
e PA sempre sotto il 50% dei membri (massimo 40,0%). N, numero di prosumer e potenza installata
tornano a ogni livello (`assert` del generatore). `elenco_schede_cer` con `conIND = true` elenca
92 schede con imprese fino a 18 membri e 331 in tutto; il suo auto-test passa e l'elenco di default
resta di 76 schede.

**Quota dei consumi di imprese e PA sul carico della comunità** (mediana per livello):

| Livello | 15-18 membri | 20-25 membri |
|---|---|---|
| ND1 (antigelo) | 37% | 30% |
| ND2 (+ office_zummo) | 73% | 66% |
| ND3 (+ small_industry) | 85% | 80% |
| ND1_PA3 | 95% | 93% |
| ND3_PA3 | 97% | 94% |

Le imprese sono poche come membri ma pesano molto sui consumi: già con 2 imprese consumano due
terzi dell'energia della comunità. Con le 3 PA il peso viene soprattutto da scuola e palazzetto.

[K26] Koltunov, M., Beltrami, F., Grossi, L., Blasuttigh, N. (2026). *Impact of renewable energy
communities on the Italian day-ahead electricity market: A scenario analysis*. Energy Policy, 218,
115518. doi:10.1016/j.enpol.2026.115518 (preprint arXiv:2510.13517v3).
[DB] https://github.com/maksym-koltunov/energy-communities-Italy, `CER database 2025 PUBLIC.xlsm`,
dati a gennaio 2025, commit `7560715`.
