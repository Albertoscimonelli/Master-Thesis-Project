# Master-Thesis-Project — Analisi CER

Simulazione e analisi tecnico-economica di **Comunità Energetiche Rinnovabili (CER)**
italiane: generazione di profili di carico realistici, bilancio orario fra energia
condivisa e immessa, ripartizione dell'incentivo CER fra i membri con dodici regole
alternative (teoria dei giochi cooperativi, benchmark elementari, modelli dalla letteratura
sulle REC italiane, chiavi dinamiche), giudizio di ogni ripartizione con un insieme di
indicatori (uniformità, merito, stabilità, forza incentivante, inclusione, sostenibilità
economica) e confronto delle graduatorie su una **griglia di comunità domestiche** che
varia taglia e penetrazione dei prosumer.

**Autore:** Alberto Scimonelli — Tesi di Laurea Magistrale, 2026

> **Per chi apre questo repository per la prima volta (umano o assistente AI):** questo
> README dà la panoramica completa. La pipeline di analisi è **`MAIN2.m`**; `MAIN.m` è la
> versione precedente, conservata come riferimento storico, e i suoi numeri non vanno
> citati. Per il dettaglio file per file vedi
> [STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt), che descrive il progetto dal punto di
> vista di `MAIN2.m` ([STRUTTURA_PROGETTO.txt](STRUTTURA_PROGETTO.txt) è la mappa storica,
> con `MAIN.m`); per la derivazione matematica dei modelli di ripartizione vedi
> [GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md). Non dovrebbe servire
> leggere il codice sorgente per capire cosa fa il progetto e come è strutturato — solo per
> modificarlo.
>
> **Stato al 23 ottobre 2026:** il run fino a 18 membri (76 comunità, livello 0 più PA1-3) è del
> 20 ottobre; il run **fino a 25 membri con PA** (108 comunità, livello 0 più PA1-3) è del
> 21 ottobre e sta in `outputs/tables_main2_griglia25_PA/` (§7.10.1). Entrambi usano i parametri
> LIHC definitivi (§7.7) e il confronto con / senza PA (§7.10). L'inclusione LIHC non è valutabile
> (nessuna famiglia vulnerabile). Le tabelle `tables_main2_griglia25/` sono del 13 ottobre, con i
> segnaposto e senza PA: sono **superate** da quelle del 21 ottobre. Sintesi dei risultati e del
> lavoro residuo: `outputs/report/REPORT_risultati_e_lavoro_residuo_2026-10-20.md` (precedente al
> run a 25 membri con PA).

---

## Indice

1. [Cosa fa il progetto](#1-cosa-fa-il-progetto)
2. [Pipeline a due stadi](#2-pipeline-a-due-stadi)
3. [Come eseguirlo](#3-come-eseguirlo)
4. [Struttura del repository](#4-struttura-del-repository)
5. [Il modello energetico CER](#5-il-modello-energetico-cer)
6. [I modelli di ripartizione dei benefici](#6-i-modelli-di-ripartizione-dei-benefici)
7. [Indici di valutazione dell'equità](#7-indici-di-valutazione-dellequità)
8. [Dimensionamento impianto PV (standalone)](#8-dimensionamento-impianto-pv-standalone)
9. [Le schede dati (`CER_configuration/`)](#9-le-schede-dati-cer_configuration)
10. [Dipendenze e requisiti](#10-dipendenze-e-requisiti)
11. [Output prodotti](#11-output-prodotti)
12. [Limitazioni note / TODO](#12-limitazioni-note--todo)
13. [Documentazione aggiuntiva](#13-documentazione-aggiuntiva)
14. [Scaling a comunità grandi (~100 utenti): cosa va risolto prima](#14-scaling-a-comunità-grandi-100-utenti-cosa-va-risolto-prima)
15. [Dati del palazzetto dello sport di Lucca](#15-dati-del-palazzetto-dello-sport-di-lucca)

---

## 1. Cosa fa il progetto

Una CER riunisce membri che consumano soltanto (**consumatori**) e membri che hanno anche un
impianto fotovoltaico (**prosumer**). La produzione copre prima l'autoconsumo del
proprietario; l'eccedenza viene immessa in rete, e la parte di energia immessa che ora per
ora trova un prelievo di un altro membro è **energia condivisa**: su quella il GSE eroga
un incentivo, la tariffa premio oraria **TIP_h**. La norma non dice come dividerlo fra i
membri. Il progetto risponde a quattro domande:

1. **Quanta energia si condivide, quanta resta soltanto immessa, e quanto valgono?**
   (bilancio orario annuale, §5)
2. **Come si può dividere l'incentivo?** Dodici regole a confronto, dalla teoria dei giochi
   cooperativi a semplici regole di buon senso, fino a modelli proposti in letteratura per
   le REC italiane e a chiavi dinamiche che ripartiscono l'energia ora per ora (§6)
3. **Quale divisione è migliore, e secondo quale criterio?** Uniformità, merito, stabilità
   della coalizione, forza incentivante, inclusione dei vulnerabili, sostenibilità
   economica del membro messo peggio (§7.0-§7.7)
4. **Quanto la risposta dipende dalla comunità?** Le stesse analisi su una griglia di
   comunità domestiche da 5 a 25 membri, con penetrazione dei prosumer dal 20-30% al 100%:
   accordo fra indicatori, inversioni di graduatoria, costo dei trade-off, sottoinsieme
   minimo di indicatori (§7.6-§7.9)

Accanto c'è un ramo indipendente, il pre-dimensionamento di un impianto fotovoltaico su
copertura (§8), che non fa parte della pipeline di analisi.

## 2. Pipeline a due stadi

```
STADIO 1 (Python, CER_LoadProfiles/)            STADIO 2 (MATLAB, root)

config/simulation_config.lombardia100.yaml
        |
        v
generate_load_profiles.py (orchestratore)
   |-- lpg_runner.py   (famiglie, pyLPG)
   +-- ramp_runner.py  (utenze non domestiche, RAMP)
        |
        v
postprocessing.py (energia oraria + export CSV)
        |
        v
outputs/csv_lombardia100/100_utenti.csv
        |   prime N colonne -> N_utenti.xlsx
        v
CER_configuration/CER_<C>_<P>_<E>.txt ----------> MAIN2.m --> outputs/tables_main2/
        ^                                         ^
        |                                         |
arricchisci_schede.py (reddito, gas)        PV_Generation/*.CSV (export PVsyst)
                                            prezzi zonali MGP 2025 (GME)
```

- **Stadio 1 — Python** (`CER_LoadProfiles/`): genera profili di carico orari annuali per
  famiglie (pyLPG, su un catalogo LoadProfileGenerator italianizzato e validato contro
  ARERA) e per utenze non domestiche (RAMP). Le schede attuali usano una società di cento
  famiglie lombarde; una comunità da N membri prende le prime N colonne, estratte negli
  `N_utenti.xlsx` fuori dal codice. `arricchisci_schede.py` compila poi reddito e spesa gas
  dei membri domestici da Istat e ARERA.
- **Stadio 2 — MATLAB** (root): `MAIN2.m` legge le schede, e per ciascuna carica profili e
  produzione PV, calcola il bilancio energetico, ripartisce l'incentivo con le dodici
  regole, calcola indicatori, soglia regolatoria e VAN dei membri; dopo il ciclo confronta
  le comunità e scrive le tabelle. `MAIN.m` è la pipeline precedente (sedici metodi, sette
  comunità miste da 7 membri): resta nel repository ma non è aggiornata — fra l'altro
  calcola ancora la vendita sulla sola energia non condivisa (§5.2).

I due stadi comunicano solo tramite file: non c'è integrazione automatica, si esegue prima
Python e poi MATLAB.

## 3. Come eseguirlo

**Stadio 1 (opzionale se i profili esistono già):**
```bash
cd CER_LoadProfiles
python generate_load_profiles.py --config config/simulation_config.lombardia100.yaml
cd ..
python CER_LoadProfiles/arricchisci_schede.py      # reddito ed euro_gas nelle schede
```
Senza `--config` lo script usa `config/simulation_config.yaml`, la comunità mista dei primi
studi. pyLPG simula una famiglia alla volta: cento famiglie richiedono alcune ore. Serve
l'ambiente Python descritto in [requirements.txt](requirements.txt) (root, freeze completo)
o [CER_LoadProfiles/requirements.txt](CER_LoadProfiles/requirements.txt) (dipendenze
dirette del pacchetto).

**Stadio 2:**
```bash
# Git Bash, dalla root del progetto
MAIN2_SCHEDE="CER_0_5_0;CER_2_3_0;CER_3_2_0;CER_4_1_0" matlab -batch "MAIN2"
```
In MATLAB, dalla root, basta `MAIN2` (con `setenv("MAIN2_SCHEDE", "...")` prima, per
scegliere le schede). `MAIN2.m` legge tutta la configurazione da
[`CER_configuration/`](CER_configuration/) (§9): le schede delle comunità —
`CER_C_P_E.txt`, con membri, tariffe, impianti e percorsi — più lo scenario economico che
ogni scheda dichiara — `scenario_economico.txt`, con prezzi, costi e soglie di povertà, gli
stessi per tutte le CER. Ripete l'intera analisi una volta per comunità, lascia i risultati
di ciascuna nella struct `RESULTS`, e dopo il ciclo confronta le comunità fra loro. I
percorsi sono **relativi alla scheda**, quindi il progetto gira anche spostato di cartella
o su un'altra macchina, e aggiungere una comunità allo studio vuol dire mettere un file in
quella cartella, senza toccare il codice. Richiede **Optimization Toolbox** (`linprog`,
`quadprog`, `intlinprog`) per Nucleolo e Variance Least Core.

**Quali schede legge.** Senza nessuna variabile, `MAIN2.m` prende **tutte le schede fino a
18 membri**: il livello 0 di `CER_configuration/` (solo domestici) e le varianti con PA di
`CER_configuration_PA/PA1..PA3` (asse composizione, §7.10). L'elenco lo costruisce
`elenco_schede_cer.m`, che legge N = C+P+E dal nome della scheda e salta `PA0/` (copia
identica del livello 0). Quattro variabili d'ambiente, tutte facoltative:

| Variabile | Cosa fa |
|---|---|
| `MAIN2_SCHEDE` | nomi di scheda senza `.txt`, separati da `;`. Vince sul tetto di membri. Un nome senza cartella è una scheda di `CER_configuration/`; `PA2/CER_5_5_0` è la variante PA2 |
| `MAIN2_MAX_UTENTI` | tetto di membri, default **18** (Shapley, Nucleolo e stabilità si calcolano fino a lì). `25` dà la griglia fino a 25 (con `MAIN2_CARTELLA=griglia25`, o `griglia25_PA` per il run con le PA del 21 ottobre, §7.10.1); le schede da 50-100 membri esistono ma il Variance Least Core non arriva in fondo (§14.1) |
| `MAIN2_CARTELLA` | suffisso delle cartelle di uscita: `outputs/tables_main2_<suffisso>/` e `outputs/figures_main2_<suffisso>/` |
| `MAIN2_RIPRENDI` | `1` = riparte dal checkpoint di un run interrotto. Dopo ogni comunità `MAIN2.m` salva `RESULTS` in `outputs/checkpoint_main2[_<suffisso>].mat` (non versionato); la ripresa vuole lo stesso elenco di schede, e si ferma se non coincide |

I run di riferimento — fino a 18 membri (20 ottobre), fino a 25 membri con PA (21 ottobre) e
la griglia a 25 membri del 13 ottobre, superata — sono descritti nelle §7.9 e §7.10.1;
l'elenco completo delle schede di ciascuno è in
[STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt) §2.3. Per una prova su poche schede
conviene un suffisso (`MAIN2_CARTELLA=prova`): senza, le tabelle della prova
sovrascriverebbero quelle versionate in `outputs/tables_main2/`.

[`CER_input.txt`](CER_input.txt) è la guida commentata alla compilazione: spiega sezione
per sezione cosa scrivere nelle due schede, su una comunità mista di esempio, e non viene
letta dal codice.

**Tempi** (analisi senza figure, run del 13 ottobre): 42 min per le 20 comunità fino a 18
membri, 2 h 28 min per le 28 fino a 25; una comunità da 5 membri costa pochi secondi, una
da 25 fino a mezz'ora (§11.2). Il run del 21 ottobre, 108 comunità fino a 25 membri con PA,
ha richiesto 9 h 9 min di analisi (due sessioni, §7.10.1). La pipeline è **deterministica** — l'unica sorgente casuale,
l'Adaptive Sampling, ha un seed esplicito — e rilanciata senza modifiche riscrive le tabelle
identiche al byte: il confronto prima/dopo una modifica è un test di regressione. Per
ripartire dai run finali senza rilanciarli vedi
[outputs/workspace/LEGGIMI.md](outputs/workspace/LEGGIMI.md).

`optimizer_PV.m` si esegue separatamente ed è pensato per test occasionali di
dimensionamento, non fa parte del flusso principale.

## 4. Struttura del repository

Mappa sintetica — per il dettaglio completo (ogni file, ogni funzione, ogni tabella) vedi
[STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt) §1 e §5.

| Percorso | Contenuto |
|---|---|
| `MAIN2.m` | **Entry point MATLAB** — il ciclo sulle comunità (bilancio, dodici ripartizioni, indicatori, soglia regolatoria, VAN dei membri) e, dopo il ciclo, l'analisi fra comunità (§7.6-§7.9). Non contiene dati |
| `MAIN.m` | Pipeline precedente: sedici metodi, sette comunità miste da 7 membri. Resta come riferimento storico, non è aggiornata (calcola ancora la vendita sulla sola energia non condivisa, §5.2) e i suoi numeri non vanno citati |
| `CER_configuration/` | **Schede dati lette da `MAIN2.m`** — `CER_C_P_E.txt`, una per comunità: le 40 della griglia (membri, categorie, tariffe, potenze, impianti, dati socio-economici, governance) — e `scenario_economico.txt`, uno per tutte (prezzi, costi di investimento, soglie di povertà) (§9). Le schede miste dei primi studi stanno in `Provvsiorio/`, che `MAIN2.m` non legge |
| `CER_input.txt` | **Guida alla compilazione** — le stesse sezioni, spiegate riga per riga su una CER mista di esempio. Non viene letta dal codice (§9) |
| `PV_Generation/` | Export orari PVsyst: i tre impianti residenziali tipo delle schede della griglia (3,4 / 4,2 / 5,9 kWp) e quelli dei primi studi |
| `20250101_20251231_MGP_PrezziZonali_Nord.xlsx` | Prezzo zonale orario MGP 2025 (GME, zona Nord) |
| `CER_LoadProfiles/` | Pacchetto Python — generazione profili di carico (pyLPG per le famiglie, RAMP per le utenze non domestiche). In `outputs/csv_lombardia100/` i profili delle cento famiglie usati dalle schede |
| `CER_LoadProfiles/lpg_db/` | **Italianizzazione del catalogo LPG e validazione dei profili domestici.** `build_italian_db.py` applica 19 migrazioni al `.db3` tedesco (festività, orari, vettori, dotazione); `riferimento_arera.py` costruisce il bersaglio, `riferimento_istat.py` e `tipologie_famiglie.py` le calibrazioni, `valida_domestici.py` / `curva_numerosita.py` / `confronta_societa.py` la misura. Vedi [REPORT_VALIDAZIONE_LPG.md](REPORT_VALIDAZIONE_LPG.md) |
| `CER_LoadProfiles/ramp_db/` | **Riferimento per la validazione dei profili non domestici.** Gemello non domestico di `lpg_db/`, con il bersaglio diviso fra due fonti: `riferimento_arera_nd.py` porta livello annuo e peso dei mesi da ARERA per ATECO e classe BTA (dato **solo mensile**), `riferimento_gse_nd.py` la forma oraria dentro il mese dai **profili standard GSE** 2024-2025 — gli stessi che il GSE applica nel settlement dei POD non trattati orari (TIAD, delibera ARERA 727/2022/R/eel). Fonti, trappole dei file e limiti in [CER_LoadProfiles/README.md](CER_LoadProfiles/README.md); risultati, difetti residui e riproducibilità in [REPORT_VALIDAZIONE_RAMP.md](REPORT_VALIDAZIONE_RAMP.md) |
| `CER_LoadProfiles/arricchisci_schede.py` | **Compila reddito e spesa gas dei membri domestici** nelle schede (`reddito_EUR`, `euro_gas` più le colonne di provenienza), da Istat EU-SILC e ARERA. Test in `CER_LoadProfiles/tests/` |
| `data/external/` | Dati esterni versionati con la fonte riga per riga (reddito Istat, quote gas ARERA) e i parametri dell'arricchimento. Fonti in [DATA_SOURCES.md](DATA_SOURCES.md) |
| `data/external/palazzetto_lucca/` | **Consumo e produzione FV 2024 del palazzetto dello sport di Lucca** (CSV orari), guida al metodo e script Python. Dati archiviati, non letti da `MAIN2.m`. Vedi §15 |
| `CER_configuration_PA/` | **Asse composizione (presenza di PA)**: le schede della griglia in quattro livelli, `PA0` (solo domestici) e `PA1`-`PA3` (comune, +scuola, +palazzetto), a N, C e P invariati. Non lette da `MAIN2.m`. Vedi [CER_configuration_PA/README.md](CER_configuration_PA/README.md) |
| `data/mapping_archetipo_istat.csv`, `docs/` | Mappatura archetipo LPG → tipologia familiare Istat, motivata in [docs/mapping_household_istat.md](docs/mapping_household_istat.md) |
| `CER_configuration_IND/` | **Asse imprese**: le schede con N ≥ 15 con 1-3 imprese (`ND1`-`ND3`) e con imprese più PA (`ND{k}_PA{p}`), a N, C e P invariati; 331 schede generate da `genera_varianti_IND.py`, non ancora lette da `MAIN2.m`. Vedi §7.11 e [CER_configuration_IND/README.md](CER_configuration_IND/README.md) |
| `elenco_schede_cer.m` | Elenco delle schede che `MAIN2.m` analizza: `CER_configuration/` più le varianti con PA di `CER_configuration_PA/PA1..PA3`, fino a `MAIN2_MAX_UTENTI` membri (default 18); auto-test su cartella temporanea (§3) |
| `load_cer_input.m`, `align_members_to_users.m` | Lettura e validazione della scheda; riordino dei membri sull'ordine delle colonne dei profili |
| `opts_from_config.m`, `rmfield_if.m` | Traduzione delle chiavi della scheda nei campi `opts` dei metodi, saltando quelle a `?` |
| `load_cer_data.m` | Caricamento profili + assegnazione impianti PV/autoconsumo (§5) |
| `load_zonal_price.m`, `compute_cer_incentive.m`, `cer_tip_bracket_power.m` | Prezzo zonale → tariffa incentivante oraria TIP_h, con lo scaglione scelto sulla potenza del singolo impianto (§5, §14.4.1) |
| `cer_coalition_values.m`, `cer_shared_value.m` | Funzione caratteristica `v(S)`: per tutte le `2ⁿ` coalizioni — calcolata una volta per comunità e condivisa da Shapley, Nucleolo ed eccesso di coalizione, fino a 18 membri — e per una coalizione sola, su richiesta (Variance Least Core, Adaptive Sampling) |
| `shapley_cer_cached.m`, `nucleolus_cer_cached.m`, `variance_least_core_cer.m` | I tre modelli di teoria dei giochi di `MAIN2.m` (§6). Le versioni senza cache (`shapley_cer.m`, `nucleolus_cer.m`) e `nash_bargaining_cer.m` restano per `MAIN.m` |
| `equal_split_cer.m`, `proportional_consumption_cer.m` | I due benchmark elementari (§6) |
| `remuneration_model1_cer.m`, `cascading_tree_cer.m`, `weighted_solidarity_cer.m` | I tre modelli dalla letteratura sulle REC italiane (§6) |
| `pearson_key_cer.m` | Chiave dinamica M3 di Gianaroli et al. (§6). La M5, `pearson_sharing_key_cer.m` con `sharing_rate_key.m`, è solo in `MAIN.m` |
| `pearson_hourly_key.m`, `allocate_shared_energy.m`, `normalize_key_rows.m` | Helper della chiave dinamica: pesi di Pearson, ripartizione iterativa con cap al consumo, normalizzazione oraria |
| `similarity_utilization_cer.m` | Ripartizione giornaliera su similarità coseno × fattore di utilizzo (Bilardo 2025) (§6) |
| `adaptive_sampling_shapley_cer.m`, `marginal_contribution_cer.m` | Le due approssimazioni dello Shapley di Cremers et al. 2023 che `MAIN2.m` usa: l'Adaptive Sampling come stima dello Shapley (l'unica nell'analisi sopra i 18 membri), i contributi marginali solo come riferimento di merito del Fairness Index. La terza, `stratified_expected_value_cer.m`, è solo in `MAIN.m` (§6) |
| `tri_level_ep_cer.m` | Ripartizione **tri-livello** proprietà + proporzionale + povertà energetica LIHC (Campagna et al. 2024) (§6). ⚠ **Provvisorio**: registro di 11 ipotesi, 8 attive sulle schede della griglia |
| `lihc_index.m` | Indice di povertà energetica **LIHC** (Low Income High Cost), booleano e continuo — calcolatore puro, riusabile |
| `fairness_indicators_lem.m` | Indicatori di equità distributiva di Dynge & Cali 2025 — MinMax, QoS, EI (originali e riformulati) su **una** ripartizione; in `Tfair` di `MAIN2.m` entrano EI e Gini (§7) |
| `fairness_index_bm.m` | **Fairness Index** di Casalicchio et al. 2022: distanza di ciascun metodo dalla distribuzione per contributo `v(N) − v(N∖{i})` (§7) |
| `coalition_excess.m` | **Eccesso di coalizione** di Volpato et al. 2024 (eq. 23): quali sottogruppi guadagnerebbero di più uscendo dalla CER — l'unico indicatore di **stabilità** (§7) |
| `compute_incentive_strength.m` | **Forza incentivante** e allineamento alla virtuosità, sull'asse netto e su quello lordo (§7.0-bis) |
| `inclusion_index.m` | Indicatore di **inclusione**: quota di v(N) ai vulnerabili LIHC rispetto al loro numero (§7.7) |
| `premium_excess_threshold.m` | **Soglia di energia incentivabile** 55%/45% e destinazione della tariffa premio eccedentaria (DM MASE 414/2023, Regole Operative GSE): non misura l'equità, dice quali ripartizioni sono **ammissibili** (§7.4) |
| `cer_reduction_factor.m` | **Fattore F** di decurtazione della tariffa premio per contributo in conto capitale, e maschera dei membri **esenti** — persone fisiche ed enti (§7.5) |
| `gini_index.m`, `jain_index.m` | I due nuclei degli indicatori sopra (`EI = 1 − Gini`, `QoS = Jain`), esposti a sé stanti e condivisi anche da `weighted_solidarity_cer.m` |
| `gini_heterogeneity.m`, `shape_heterogeneity.m` | Eterogeneità della comunità: per categoria (Casalicchio eq. 10, **non** un Gini di reddito; sulla griglia vale 0) e per forma dei profili. Stampate, non in `Tfair` |
| `profilo_prezzi_pun_2025.m` | Prezzi PUN 2025 per 3 modalità tariffarie: costo da rete, risparmio da autoconsumo, `Cu` della Weighted Solidarity, spesa del Tri-level EP |
| `compute_financial_metrics.m`, `irr_bisection.m` | VAN, TIR e tempo di ritorno per membro e per metodo (`MAIN2.m` §3v, §12); TIR per bisezione, senza Financial Toolbox |
| `fase1_shapley_vs_as.m` | Fase 1 dell'analisi: Shapley esatto contro Adaptive Sampling per comunità, membro e taglia (§6) |
| `compute_indicator_agreement.m`, `indicator_tie_tol.m` | τ-b di Kendall fra indicatori, con i versi degli indicatori dichiarati in tabella e le tolleranze di pareggio (§7.6) |
| `extract_ranking_reversals.m`, `reversals_by_axis.m`, `ranking_grid.m`, `plot_ranking_grid.m` | Inversioni di graduatoria e lettura della griglia **taglia × penetrazione**, un fattore alla volta più la vista congiunta (§7.6) |
| `apply_relevance_threshold.m`, `ricalcola_inversioni_soglia.m` | Soglia di **rilevanza pratica** su tutti gli indicatori e ricalcolo di inversioni, vincitori e interazione dai soli `RESULTS`, senza rilanciare i metodi (§7.6) |
| `sintesi_risultati.m` | Le tre **sintesi** della domanda di ricerca: tau-b per fascia e per taglia, fronte di Pareto fra i criteri, quote ai prosumer per metodo. Scritte in `outputs/tables_main2/sintesi/` da `MAIN2.m` §7c (§7.6) |
| `confronto_pa.m` | **Presenza di PA**: PA0 contro PA1-3 a N, C, P invariati — inversioni, vincitori, quote ai membri PA, trade-off e sottoinsieme minimo per livello; auto-test su dati a penna (§7.10) |
| `tradeoff_losses.m` | **Quanto costano i trade-off**: rimpianto di ogni metodo e perdita su B di chi vince su A (§7.8) |
| `indicator_clusters.m` | **Sottoinsieme minimo** di indicatori: gruppi per τ medio, rappresentanti e prove di sufficienza (§7.8) |
| `sensibilita_soglia.m` | Inversioni e vincitori a più **soglie di rilevanza**, dagli stessi `RESULTS` (§7.9) |
| `report_allocation.m`, `save_tables.m` | Stampa e verifica di una ripartizione (somma a `v(N)`); tabelle CSV arrotondate solo in scrittura (§11.0) |
| `save_figures.m`, `spread_labels.m` | Export delle figure su file (PDF+PNG) ed etichette distanziate con linea di richiamo |
| `format_duration.m` | Una durata in secondi resa in secondi/minuti/ore, per il riepilogo dei tempi (§11.2) |
| `method_color.m` | Un colore per metodo, condiviso da tutti i grafici |
| `plot_cer_comparison_main2.m`, `plot_gini_3d.m` | Confronto **fra le CER** analizzate e superficie del Gini, dopo il ciclo (§11.1). `plot_cer_comparison.m` è la versione di `MAIN.m` |
| `plot_allocation_comparison.m`, `plot_allocation_heatmap.m`, `plot_benefit_network.m` | Quote per metodo: barre, mappa metodi × membri, grafo a rete (§11.1) |
| `plot_fairness_indicators.m`, `plot_merit_deviation.m`, `plot_fairness_tradeoff.m` | Equità: mappa degli indicatori, chi è premiato e chi penalizzato rispetto al contributo marginale, piano uniformità × stabilità con frontiera di Pareto (§11.1) |
| `plot_cer_energy.m`, `plot_pv_vs_demand.m`, `plot_hourly_map.m`, `plot_duration_curves.m`, `plot_incentive_price.m`, `plot_load_profiles.m` | Energia: mensili, PV contro domanda, mappa oraria con le ore sature, curve di durata, TIP_h contro prezzo zonale, profili tipo (§11.1) |
| `plot_financial_metrics.m` | VAN, tempo di ritorno, composizione del flusso di cassa (§11.1) |
| `optimizer_PV.m`, `pv_*.m` | Pre-dimensionamento di un impianto PV su copertura (standalone, §8) |
| `outputs/tables_main2/`, `outputs/tables_main2_griglia25_PA/`, `outputs/tables_main2_griglia25/` | Le tabelle dei run finali, versionate (§11.0): fino a 18 membri (20 ottobre), fino a 25 membri con PA (21 ottobre), e quelle del 13 ottobre a 25 membri, superate |
| `outputs/workspace/` | Per ripartire dai run finali senza rilanciarli: CSV esportati dai workspace, analisi testuale, strumenti; istruzioni in [LEGGIMI.md](outputs/workspace/LEGGIMI.md) |
| `outputs/report/` | Pagina dei risultati finali (`regole_ripartizione_cer.html`), validazione della società a cento famiglie, costo dei metodi al crescere dei membri |
| `archive/` | Codice superato mantenuto per riferimento storico (`PROVA_PV.m`, `merge_pv_owner.m`) |
| `GUIDA_modelli_distribuzione.md` | Derivazione matematica dei modelli di ripartizione e degli indicatori |
| `STRUTTURA_PROGETTO2.txt`, `STRUTTURA_PROGETTO.txt` | Mappa dettagliata di ogni file, funzione e tabella dal punto di vista di `MAIN2.m`; mappa storica, con `MAIN.m` |
| `REPORT_VALIDAZIONE_RAMP.md` | **Validazione dei profili non domestici** — gemello non domestico del report LPG: come `office`, `scuola_superiore` e `comune` sono stati confrontati con ARERA (livello, solo mensile) e con i profili standard GSE (forma oraria), che cosa è stato corretto, e i difetti residui dichiarati |
| `AUDIT_REPORT.md` | Audit del codice — bug noti e possibili miglioramenti (2026-07-10) |

## 5. Il modello energetico CER

**Giocatori = utenti.** Ogni utente della comunità porta con sé un carico (`loadUsers`) e,
se possiede un impianto, una produzione PV. Un impianto è fisicamente "dietro al
contatore" del proprietario: la produzione copre **prima** il suo autoconsumo, e **solo
l'eccedenza** è disponibile per la comunità (dettagli e formule in
[STRUTTURA_PROGETTO2.txt §8](STRUTTURA_PROGETTO2.txt)). Da questo derivano, ora per ora e
per ogni utente:

- `gen_i(t)` — eccedenza PV dell'utente `i` (0 se non ha impianto o se è tutta autoconsumata)
- `load_i(t)` — carico **residuo** dell'utente `i` (al netto dell'autoconsumo)

Per costruzione, `gen_i(t)` e `load_i(t)` sono **complementari**: in ogni ora un utente ha
l'una o l'altro, mai entrambi.

**Bilancio di comunità** (`MAIN2.m` §2-§3):
```
energia immessa(t)   = Σ_i gen_i(t)                          → venduta in rete a P_SELL, tutta (§5.2)
energia condivisa(t) = min( Σ_i gen_i(t),  Σ_i load_i(t) )   → matura in più l'incentivo CER
non condivisa(t)     = energia immessa(t) − energia condivisa(t)
```

**Tariffa incentivante (TIP_h).** L'incentivo sull'energia condivisa non è una costante:
è un vettore orario `P_CER_h` (eq. 3.1), calcolato da `compute_cer_incentive.m` a partire
dal prezzo zonale orario del Mercato del Giorno Prima (`load_zonal_price.m`, letto da
`20250101_20251231_MGP_PrezziZonali_Nord.xlsx`).

Questo bilancio (con `P_CER_h`) è l'input di **tutti** i modelli di ripartizione:
```
v(S) = Σ_t min( Σ_{i∈S} gen_i(t), Σ_{i∈S} load_i(t) ) · P_CER_h(t)
```
è la **funzione caratteristica** del gioco cooperativo (`cer_coalition_values.m`), e
`v(N)` (l'intera comunità) è il totale che i modelli si dividono in modo diverso. La vendita
dell'energia immessa resta fuori dal gioco: va a ciascun prosumer per la propria immissione.

### 5.1 Il modello di calendario: un orologio solo, senza cambio d'ora

Tutte le serie del progetto vivono su un **anno locale uniforme di 8760 ore**: la riga `k`
di ciascuna è la `k`-esima ora **assoluta** dell'anno. Non si modella l'ora legale, in
nessun punto della catena.

Non è una semplificazione scelta a tavolino, è una **proprietà delle sorgenti**, verificata:
RAMP genera 525 600 minuti consecutivi giorno per giorno, pyLPG un anno pieno di 8760 ore,
e l'export PVsyst ha il picco di produzione a mezzogiorno in *tutti* i mesi — misurato,
estate compresa — quindi non conosce il cambio d'ora nemmeno lui. Il file GME dei prezzi
zonali *sì*, ma contiene comunque le 8760 ore assolute dell'anno (un giorno da 23 ore e uno
da 25, che si compensano): `load_zonal_price` lo allinea **per posizione**, come già faceva
`load_pv_generation`, quindi la riga `k` finisce nell'ora `k` della griglia.

> **Perché è importante saperlo.** Fino al 9 settembre 2026 il progetto usava *due* modelli
> di calendario senza dichiararlo. `ramp_runner` costruiva un indice `tz`-aware sopra un
> array che non aveva l'ora legale, e questo spostava avanti di un'ora **tutta la metà
> estiva** dei profili aziendali (30 marzo → 26 ottobre): il minuto generato come «15 luglio
> ore 12:00» finiva etichettato 13:00. In parallelo il prezzo zonale era indicizzato per
> etichetta in ora legale, e finiva un'ora più avanti dell'energia che doveva valorizzare.
> Correggendo entrambi, **l'energia condivisa è salita del 5,43%** (89 443 → 94 302 kWh) e
> il montepremi del 5,46% (11 444 → 12 068 €), con l'effetto che cresce con la penetrazione
> prosumer (+4,4% con un impianto solo, +8,1% con sette). Tutti i risultati numerici di
> questo README sono posteriori alla correzione.

### 5.2 La vendita: tutta l'energia immessa, non solo quella non condivisa

**La regola.** Nella CER italiana la condivisione è **virtuale**. L'energia condivisa è «il
minimo tra l'energia elettrica immessa ai fini della condivisione e l'energia elettrica
prelevata» (Regole Operative GSE del 16 luglio 2025, Appendice A, p. 155): è una *parte*
dell'energia immessa, non una sua destinazione alternativa. E la messa a disposizione
dell'impianto verso la comunità «rileva esclusivamente ai fini della erogazione dei benefici
economici connessi alla condivisione dell'energia e, come previsto dal TIAD, non rileva ai
fini della valorizzazione economica dell'energia immessa in rete che rimane liberamente
definibile dal produttore» (ivi, §1.2.2, p. 17). Il produttore vende quindi **tutta**
l'energia immessa, e sulla parte condivisa la CER incassa **in più** la tariffa premio.

**Cosa faceva il codice fino al 13 ottobre 2026.** La vendita si calcolava sulla sola parte
non condivisa, `max(0, immessa − prelievo)`, come se il kWh condiviso fosse ceduto al vicino
invece che venduto. Il lato dei consumi era già corretto (`costUser` è sul carico pieno,
nessuno sconto per l'energia condivisa): i due lati non erano coerenti fra loro.

| CER_4_1_0, un prosumer da 3,4 kWp | prima | dopo |
|---|---:|---:|
| energia immessa | 3 630 kWh | 3 630 kWh |
| di cui condivisa / non condivisa | 1 819 / 1 811 kWh | 1 819 / 1 811 kWh |
| vendita (0,11 €/kWh) | 1 811 × 0,11 = **199 €** | 3 630 × 0,11 = **399 €** |
| incentivo da ripartire, `v(N)` | 233 € | 233 € |

Al prosumer mancavano 200 € l'anno, cioè 2 719 € di VAN (fattore di annualità 13,59 a 4% e
20 anni). L'errore era piccolo sulle sette comunità originali, dove la condivisa era il
2-26% dell'immessa, ed è diventato grande sulla griglia di famiglie a bassa penetrazione,
dove arriva al 50%.

**Cosa cambia, e cosa no** (verificato sulle 20 comunità fino a 18 membri, confronto per
chiave prima/dopo):

- **non cambia** nulla di ciò che ripartisce l'incentivo: `v(S)`, le quote di tutti i
  metodi, `Tcmp`, tutte le colonne di `Tfair`, la soglia regolatoria (che usava già
  `immessa = condivisa + non condivisa`), la forza incentivante, le tabelle `fase1/` e
  `quote_prosumer*`. Identici al bit;
- **cambiano** il ricavo totale (di esattamente `condivisa × 0,11`), la vendita per membro,
  il VAN dei prosumer (di `Δvendita × 13,59`, uguale con ogni metodo; i consumatori non
  cambiano), il montepremi di proprietà del Tri-level EP (`TL.phiFromSold`; la colonna del
  confronto `phiFromShared` resta identica) e quindi le righe di `VAN_min_EUR` nelle tabelle
  di `confronto/` e `sintesi/`.

| Prosumer (141 in 20 comunità) | prima | dopo |
|---|---:|---:|
| con VAN negativo | 103 | 48 |
| VAN medio, fascia 1 → 4 | −1 750 → +323 € | +896 → +410 € |

`VAN_min_EUR` diventa più stabile (meno inversioni lungo la penetrazione: a 18 membri da 18
a 2 coppie) e più vicino all'uniformità: τ(VAN_min, Gini) passa da 0,58 a 0,80, e il
metodo che lo massimizza è l'Equal Split in tutte e 20 le comunità.

**Dove.** Solo in `MAIN2.m` §2-§3. `MAIN.m` resta il riferimento storico e **conserva la
convenzione vecchia**: i suoi VAN non vanno citati.

## 6. I modelli di ripartizione dei benefici

L'incentivo CER `v(N)` viene ripartito tra i giocatori secondo regole diverse. Il
repository contiene sedici implementazioni; `MAIN2.m` (§3b-§3r) ne usa **dodici** come
regole di ripartizione, più i contributi marginali come riferimento di merito per il
Fairness Index: lo dice l'ultima colonna. Le altre tre restano per `MAIN.m`. Firma comune:
`S = metodo_cer(genUsers, loadUsers, userNames, P_CER, ...)` → struct con almeno `.phi`
(quota per utente, €), `.vGrand` (= `v(N)`, salvo eccezioni documentate), `.table`.
Derivazione matematica completa, assiomi ed esempi numerici in
[GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md).

| # | Metodo | File | Logica | Stabile? | In `MAIN2.m` |
|---|---|---|---|:---:|:---:|
| 1 | **Shapley value** | `shapley_cer.m` (`MAIN2.m`: `shapley_cer_cached.m`) | Media dei contributi marginali di ciascun utente su tutti gli ordini possibili di formazione della coalizione (Moncecchi et al. 2020) | No (in generale) | fino a 18 membri |
| 2 | **Nucleolo** | `nucleolus_cer.m` (`MAIN2.m`: `nucleolus_cer_cached.m`) | Massimizza lessicograficamente il surplus della coalizione più scontenta, via LP sequenziali (Fioriti et al. 2021) | Sì, se il Core è non vuoto | fino a 18 membri |
| 3 | **Nash Bargaining** | `nash_bargaining_cer.m` | Quota proporzionale al contributo marginale alla grande coalizione, forma chiusa (Yan et al. 2023) | No (in generale) | — |
| 4 | **Variance Least Core** | `variance_least_core_cer.m` | L'allocazione del Least Core più vicina alla ripartizione uniforme, via row-generation — pensata per comunità grandi, sui nostri dati arriva a 25 membri (§14.1) (Ferrucci, Fioriti, Poli 2025) | Sì | sì |
| 5 | **Equal Split** | `equal_split_cer.m` | Benchmark ingenuo: `v(N)` diviso in **parti uguali** tra tutti gli utenti — `φ_i = v(N)/n` | N/A (non è un gioco) | sì |
| 6 | **Proportional to Consumption** | `proportional_consumption_cer.m` | Benchmark ingenuo: quota proporzionale al **consumo** di ciascun utente nelle sole ore "utili" (energia condivisa di comunità > 0) — `φ_i = v(N) · cons_i / Σ_j cons_j` | N/A (non è un gioco) | sì |
| 7 | **Remuneration Model 1** | `remuneration_model1_cer.m` | Split α/β tra classe consumatori e classe produttori/prosumer, pesato sulla **potenza contrattuale/nominale** [kW] di ciascuna classe (dato manuale, vedi §9); dentro ogni classe, proporzionale all'energia oraria (Candela et al. 2022) | N/A (non è un gioco) | sì |
| 8 | **Cascading Tree** | `cascading_tree_cer.m` | L'incentivo si scompone ricorsivamente in un **albero di categorie** (riserva → fissa/variabile → prelievi/immissione → produttori+prosumer/soli prosumer), con pesi di ramo di default (scelte di governance) (Trevisan et al. 2022) | N/A (non è un gioco) | sì |
| 9 | **Weighted Solidarity** | `weighted_solidarity_cer.m` | Peso orario = componente tecnica (energia condivisa + carico) + componente di **solidarietà** (costo unitario dell'energia, proxy povertà energetica); i coefficienti sono scelti su un **fronte di Pareto** (Gini minimo vs reddito medio degli utenti a rischio povertà energetica) (Marrasso et al. 2025) | N/A (non è un gioco) | sì |
| 10 | **Pearson Key** | `pearson_key_cer.m` | Chiave dinamica M3: ripartisce **l'energia** ora per ora in proporzione alla **correlazione di Pearson giornaliera** tra il consumo dell'utente e l'immissione della comunità (premia il sincronismo), con cap al consumo; solo alla fine la si valorizza con `P_CER_h` (Gianaroli et al. 2024) | N/A (non è un gioco) | sì |
| 11 | **Pearson-Sharing Rate** | `pearson_sharing_key_cer.m` | Chiave dinamica M5: combinazione pesata `α`/`β` della chiave di Pearson (M3) e dello **sharing rate** (M4), che penalizza chi in un'ora consuma più di quanto la comunità immetta (Gianaroli et al. 2024, eq. 7) | N/A (non è un gioco) | — |
| 12 | **Similarity-Utilization** | `similarity_utilization_cer.m` | Ripartizione **giornaliera** proporzionale alla "virtuosità energetica" `f = θ·η`: `θ` è la similarità **coseno** tra profilo di carico del membro e generazione della comunità (premia la sincronia, ignora le quantità), `η = min(1, E_gen/E_load)` penalizza chi consuma più di quanto la comunità produca (Bilardo 2025) | N/A (non è un gioco) | sì |
| 13 | **Marginal Contribution** | `marginal_contribution_cer.m` | *Approssimazione dello Shapley*, `O(n)`: tiene **un solo** contributo marginale, l'ultimo — `MC_i = v(N) − v(N\{i})` — poi normalizzato a `v(N)` (Cremers et al. 2023, eq. 9-10) | approssima il metodo 1 | solo come riferimento di merito |
| 14 | **Stratified Expected Value** | `stratified_expected_value_cer.m` | *Approssimazione dello Shapley*, `O(n²)` e **deterministica**: stima il contributo marginale di **ogni strato** con una sola valutazione di `v` su copie di un utente fittizio **medio** (Cremers et al. 2023, eq. 11-13). È il metodo nuovo proposto dal paper — ⚠ ma sui nostri dati è il **meno** accurato dei tre, vedi sotto | approssima il metodo 1 | — |
| 15 | **Adaptive Sampling Shapley** | `adaptive_sampling_shapley_cer.m` | *Approssimazione dello Shapley*, `O(n·M)` e **stocastica**: campiona `M` coalizioni per giocatore, concentrando i campioni sugli strati a varianza più alta (O'Brien et al. 2015, App. C di Cremers et al.) | approssima il metodo 1 | sì |
| 16 | **Tri-level EP** | `tri_level_ep_cer.m` | Tre livelli sovrapposti: una quota `min(33%, 1,32%·N_vu)` va ai soli membri in **povertà energetica** (indice LIHC, `lihc_index.m`); il resto si divide fra criterio **proporzionale** al consumo orario (finanziato dal ricavo di energia condivisa) e criterio di **proprietà** (finanziato dal ricavo di vendita), con pesi pari al rapporto fra i due ricavi (Campagna et al. 2024, eq. 11-15). ⚠ **Provvisorio**: registro di 11 ipotesi, 8 attive sulle schede della griglia — vedi sotto | N/A (non è un gioco) | sì |

I metodi 1-4 sono giochi cooperativi a utilità trasferibile e condividono la stessa
`v(S)` (`cer_coalition_values.m`, che in `MAIN2.m` si calcola una volta per comunità e
serve a Shapley, Nucleolo ed eccesso di coalizione), tranne il VLC che la valuta su
richiesta per restare scalabile — come fanno anche i metodi 13-15, tramite l'helper
`cer_shared_value.m`.

> ⚠ **Il metodo 16 è provvisorio e non va usato per produrre risultati.**
> `tri_level_ep_cer.m` gira in parte su **dati segnaposto**. Il registro in testa alla
> funzione (`help tri_level_ep_cer`) conta undici ipotesi, marcate nel codice come
> `[IPOTESI n]` (`grep -n IPOTESI tri_level_ep_cer.m`) e **stampate a ogni esecuzione**, ma
> solo quelle ancora in vigore: un'ipotesi sparisce dall'elenco appena il dato vero viene
> passato via `opts`. Sulle schede della griglia ne restano attive **sei** (3, 4, 5, 6, 7,
> 9): reddito, spesa gas, quote di investimento, numero di percettori (dal 19 ottobre) e
> n% e tetto della quota (valori del paper) sono compilati, mentre markup dal PUN al prezzo
> di bolletta, mediana nazionale della spesa energetica e soglia di povertà sono ancora a
> `?` (§7.7, §9). La stessa lista è esposta come `S.assumptions`.
>
> Il metodo 16 è anche l'unico che ripartisce **entrambi** i montepremi (energia
> condivisa *e* vendita in rete), perché il suo livello di proprietà redistribuisce
> proprio il ricavo di vendita: `vGrand = v(N) + ricavo di vendita`, non `v(N)`.
> Nella tabella di confronto e nel grafico entra quindi `phiFromShared`, che somma
> esattamente a `v(N)`; il totale sui due montepremi resta in `phi`.
>
> **Sulla griglia la vendita vale dal 63% al 99% del ricavo totale** (§7.4): il livello di
> proprietà, finanziato dalla vendita, domina il montepremi del metodo e va ai soli
> prosumer, in proporzione alla quota di investimento. È il primo numero da rileggere
> quando arriveranno i dati veri.

I metodi 5-12 **non** usano teoria dei giochi (né passano da
`cer_coalition_values.m`: calcolano `v(N)` direttamente) — servono da **termine di
paragone** per misurare quanto i modelli 1-4 se ne discostino (es. quanto lo Shapley
premi la produzione rispetto a una ripartizione puramente proporzionale al consumo, o
quanto un criterio di equità sociale come quello di Marrasso sposti valore verso gli
utenti più vulnerabili). Il **Cascading Tree** è l'unico i cui parametri (`opts`)
possono far sì che `vGrand` sia inferiore a `v(N)` (se si trattiene una riserva) — con la
governance delle schede (`ct_riserva = 0`) questo non accade.

I modelli **10 e 11 sono di natura diversa dai modelli 1-9**: non ripartiscono
direttamente il denaro, ma **l'energia condivisa ora per ora** con una chiave dinamica
`r(t,i)`, sotto il vincolo fisico che nessuno riceva più energia di quanta ne consumi in
quell'ora (algoritmo iterativo di cap, `allocate_shared_energy.m`); la quota in € è
`φ_i = Σ_t SH_i(t)·P_CER_h(t)`, e l'efficienza `Σφ_i = v(N)` vale per costruzione.
Essendo chiavi guidate dal **consumo**, attribuiscono `0` al proprietario dell'impianto:
il suo carico residuo è nullo proprio nelle ore in cui c'è eccedenza da condividere
(complementarità, §5) — stesso comportamento del modello 6, e per lui il ricavo arriva
dalla vendita diretta dell'eccedenza (la barra arancione nei grafici).

Il modello **12** è anch'esso *performance-based* ma lavora su base **giornaliera**: non
ha vincolo di cap, e la sua chiave `θ·η` è **invariante di scala** (il coseno guarda la
forma della curva, non i kWh). Sulla comunità mista dei primi studi il risultato era
marcatamente più piatto degli altri: le famiglie ricevevano 3-5× quanto avrebbero dato i
modelli 10-11 a parità di consumi. Con i profili netti (default del progetto) anche qui il
prosumer riceve `0`; il paper usa invece i profili **lordi**, e con quelli riceverebbe la
quota maggiore di tutte: è la scelta di modello più impattante del metodo, commutabile via
`opts` senza toccare il codice ([GUIDA §15.3](GUIDA_modelli_distribuzione.md)). Per questo
`MAIN2.m` misura la forza incentivante su entrambi gli assi (§7.0-bis).

I modelli **13-15 sono di natura ancora diversa: non propongono un criterio di equità
alternativo, ma approssimano il metodo 1**. Servono perché lo Shapley esatto costa `O(2ⁿ)`
e diventa irrealizzabile oltre ~20 giocatori — sono cioè, insieme al VLC, la risposta della
letteratura al bloccante di [§14.1](#141-tre-modelli-diventano-matematicamente-impossibili--bloccante).
Vanno quindi giudicati sull'**errore**, non sull'equità. `MAIN2.m` ne tiene uno solo,
l'Adaptive Sampling, e ne misura lo scarto dallo Shapley esatto dove questo esiste, fino a
18 membri (§3q e fase 1, eq. 16-17 del paper; tabelle in `outputs/tables_main2/fase1/`):

> **Sulla griglia l'Adaptive Sampling è preciso.** Sulle 20 comunità da 5 a 18 membri lo
> scarto relativo medio dallo Shapley esatto va dallo **0,9% all'1,5%** a seconda della
> taglia (massimo 7,2% su un singolo membro); la somma degli scarti assoluti vale lo
> 0,8-1,0% di `v(N)`, cioè passa da un membro all'altro lo 0,4-0,5% del montepremi; l'ordine
> dei membri resta quasi lo stesso (ρ di Spearman medio 0,96-1,00, minimo 0,90). Sopra i 18
> membri lo Shapley esatto non c'è più: le stime grezze dell'AS sommano a `v(N)` entro lo
> 0,6%, prima della normalizzazione.

La scelta di tenere solo l'AS viene dal primo studio, dove le tre approssimazioni erano
state misurate tutte:

> ⚠ **Primo studio (`MAIN.m`): la graduatoria del paper si rovescia.** Scarto relativo medio dallo
> Shapley esatto (`RD` dell'eq. 17, media sui 7 membri × 7 comunità del set originale a 7 membri): **Adaptive Sampling
> 1,34%**, **Marginal Contribution 16,20%**, **Stratified Expected Value 21,79%** —
> mentre nel paper è quest'ultima la più accurata.
>
> L'unica approssimazione utilizzabile su questi dati è quindi l'**Adaptive Sampling**, ed
> è anche la più cara delle tre (`O(n·M)`). La Marginal Contribution, che costa `O(n)`,
> sbaglia in media del 16%: non è un ripiego accettabile.
> L'errore è sistematico (gonfia i consumatori del +19÷25%, sgonfia il prosumer del −20%) e
> la causa è strutturale: la SEV rappresenta ogni strato con un utente **medio**, ipotesi
> valida quando l'impianto è in comproprietà fra tutti — il caso del paper — e insostenibile
> quando la generazione è di **un solo membro su sei**, perché il 52% delle coalizioni vale
> allora esattamente zero e l'utente medio non sa rappresentarle. L'implementazione è
> verificata: agli strati dove l'approssimazione non può sbagliare riproduce il valore vero
> a `10⁻¹³` (`opts.validateStrata`, attivo in `MAIN.m` §3o). Derivazione, tabelle e
> condizioni per riprendere il metodo in
> [GUIDA §16.7-§16.9](GUIDA_modelli_distribuzione.md).

Il modello **15 è l'unico stocastico del progetto**: rieseguito dà numeri leggermente
diversi, ed è la critica che il paper stesso gli muove (in una CER i membri devono poter
riverificare il conto dell'aggregatore). Il seed è esplicito (`opts.seed`, default 42) e
isolato dal generatore globale di MATLAB, quindi l'esecuzione è riproducibile.

> **Metodi valutati e non implementati.** Non tutti i modelli letti in letteratura sono
> finiti nel progetto. **PDM3 e PDM4** (Basilico et al., *Applied Energy* 389 (2025)
> 125752) sono stati valutati e **scartati deliberatamente**: ripartiscono l'NPV di un
> impianto in *comproprietà* fra co-investitori, quindi un membro vi entra solo tramite la
> sua quota di produzione e il suo tasso di autoconsumo — il consumo non compare mai da
> solo. Con la topologia dei primi studi (un impianto, un proprietario, cinque consumatori
> puri) i cinque consumatori avrebbero ricevuto quote **identiche** a prescindere dai loro
> profili, e tre input su quattro sarebbero stati inventati; la griglia non cambia la
> conclusione, perché anche lì ogni impianto ha un solo proprietario e nessuna
> comproprietà. Le formule sono state comunque riprodotte
> esattamente sul caso studio del paper: la rinuncia è di modello, non tecnica. Ragioni per
> esteso, numeri e condizioni per riprenderli in
> [GUIDA — Appendice A.1](GUIDA_modelli_distribuzione.md).

## 7. Indici di valutazione dell'equità

I modelli di §6 dicono **quanto** prende ciascuno; questa sezione dice **quale
ripartizione sia più equa**, e rispetto a quale definizione di equità. Gli indicatori
vengono da quattro articoli, più due costruzioni del progetto (inclusione e VAN del membro
peggiore); `MAIN2.m` §3t ne calcola per ogni metodo le 13 colonne di `Tfair`, segnate
nell'ultima colonna:

| Indicatore | Eq. | File | Cosa misura | Verso | In `Tfair` di `MAIN2.m` |
|---|---|---|---|:---:|---|
| **MinMax originale** | 11 | `fairness_indicators_lem.m` | min/max del prelievo da rete | 1 = equo | — (identico fra i metodi: è un `assert`) |
| **MinMax prosumer** | 16 | " | min/max della quota di surplus condivisa | 1 = equo | — |
| **MinMax consumer** | 17 | " | min/max del volume di condivisa ricevuto | 1 = equo | — |
| **QoS originale** | 12 | " | indice di **Jain** sui volumi scambiati | 1 = equo | — |
| **QoS nuovo** | 18 | " | `ρ·Jain`(quote prosumer) + `μ·Jain`(volumi consumer) | 1 = equo | — |
| **EI originale** | 15 | " | `1 −` **Gini** dei risparmi | 1 = equo | `EI_orig`, `Gini` |
| **EI nuovo** | 19 | " | `ρ·(1−Gini` risparmi *relativi*`) + μ·(1−Gini` risparmi`)` | 1 = equo | — |
| **Gini di eterogeneità** | 10 | `gini_heterogeneity.m` | varietà delle tipologie di membro (**non** un Gini di reddito) | — | stampato (sulla griglia vale 0) |
| **Fairness Index** + σ | 12-14 | `fairness_index_bm.m` | distanza dalla distribuzione per **contributo** `BCᵢ = v(N) − v(N∖{i})` | 0 = equo | `FairnessIndex`, `Sigma`, `QuoteNulle` |
| **Eccesso di coalizione** | 23 | `coalition_excess.m` | se qualche sottogruppo guadagnerebbe di più **uscendo** dalla CER | ↓ = stabile | `EccessoMax_EUR`, `CoalizioniInstabili`, `EccessoMax_pct_vN` (fino a 18 membri) |
| **Forza incentivante** + coseno | 6-8 | `compute_incentive_strength.m` | quanto la regola **premia il sincronismo** fra prelievo e immissione | nessun verso | `ForzaIncentivante`, `AllineamentoVirtu` e le due colonne `_lordo` |
| **Eterogeneità di forma** | — | `shape_heterogeneity.m` | quanto i membri consumano in momenti diversi (distanza L1 fra i profili normalizzati) | — | stampata |
| **Inclusione** | — | `inclusion_index.m` | quota di `v(N)` ai vulnerabili LIHC rispetto al loro numero (§7.7) | ↑ = inclusivo | `InclusioneLIHC` |
| **VAN del membro peggiore** | — | `compute_indicator_agreement.m` | il VAN più basso fra i membri (`MAIN2.m` §3v) | ↑ = sostenibile | no: si aggiunge nell'analisi fra comunità (`VAN_min_EUR`, §7.6) |

Fonti: Dynge, Cali, *Distributive energy justice in local electricity markets*, Appl.
Energy 384 (2025) 125463 (eq. 11-19); Casalicchio, Manzolini, Prina, Moser, *From
investment optimization to fair benefit distribution in renewable energy community
modelling*, Appl. Energy 310 (2022) 118447 (eq. 10, 12-14); Volpato, Carraro, Dal Cin,
Rech, *On the Different Fair Allocations of Economic Benefits for Energy Communities*,
Energies 17 (2024) 4788 (eq. 23); Bilardo, *A fair dynamic incentive allocation method…*,
Renewable Energy 255 (2025) 123756 (eq. 6-8, riusate come **asse di misura** e non come
regola). Derivazioni, mappatura formula → codice e avvertenze in
[GUIDA §18](GUIDA_modelli_distribuzione.md).

**Gini e Jain sono esposti a sé stanti** oltre che dentro EI e QoS: sono le grandezze con
cui ragiona la letteratura, e tenerle implicite le renderebbe inutilizzabili.

### 7.0 Quattro domande diverse, non quattro modi di misurare la stessa cosa

| Gruppo | Domanda a cui risponde |
|---|---|
| EI, Gini (e MinMax, QoS, Jain) | quanto è **uniforme** la ripartizione |
| Fairness Index, σ | quanto è vicina al **merito** di ciascuno |
| Forza incentivante, coseno | quanto **premia il sincronismo** fra prelievo e immissione |
| Eccesso di coalizione | se **regge**, cioè se un sottogruppo ha convenienza a uscire |

Le quattro domande possono dare risposte **opposte**, ed è il caso. In `CER_7_3_0` (10
membri, 3 prosumer; run del 13 ottobre) l'**Equal Split** è primo sulla prima (`EI = 1`,
`Gini = 0`: per quegli indici è la ripartizione più equa possibile), vale **esattamente
zero** sulla terza (dà a tutti lo stesso, quindi nessun comportamento cambia la quota) ed è
il quarto peggiore su dodici sulla quarta: eccesso `+43,58 €` (7,5% di `v(N)`), e 202
sottogruppi vorrebbero uscire. Il **Nucleolo** ha `EI = 0,87` ma eccesso `−3,51 €`: nessun
sottogruppo ha convenienza ad andarsene, e lo stesso vale per il Variance Least Core. La
**Similarity-Utilization**, che fissa l'unità della forza incentivante, è la meno stabile
di tutte: eccesso `+87,93 €` (15,1% di `v(N)`). Guardare una colonna sola porta a
conclusioni sbagliate.

Le prime due e la quarta hanno un **verso**: si sa da che parte sta il meglio. La terza no,
ed è la ragione per cui non entra nella mappa di `plot_fairness_indicators`, il cui
contratto di colore dichiara che il freddo vuol dire *sempre* "più equo". Nell'analisi fra
comunità le si dà un verso convenzionale, dichiarato **non normativo** in
`orientamenti.csv` (§7.6).

Due domande si sono aggiunte dopo: *chi è vulnerabile riceve in proporzione al suo
numero?* (inclusione, §7.7) e *il membro messo peggio rientra dall'investimento?* (VAN
minimo, §7.6). Esiste poi una domanda **di natura ancora diversa**, che non misura equità:
*quali ripartizioni sono ammesse dalla norma*. La tratta il §7.4 — un metodo può essere il
più equo di tutti e restare inammissibile, o viceversa.

### 7.0-bis La forza incentivante: cosa misura e come si legge

È il terzo criterio della domanda di ricerca — *incentive strength of the rule* — accanto
all'equità distributiva e alla sostenibilità economica, e fino a qui il modello non lo
sapeva esprimere. Non è un indice di equità e **non ha un verso normativo**: "più
incentivante" non vuol dire "più equo", è un asse di progetto.

La definizione letterale sarebbe un'**elasticità** — perturbare il profilo di un membro e
rileggere la sua quota — che è fuori dallo scope della tesi (richiederebbe di simulare la
risposta comportamentale) oltre a costare *n* riesecuzioni di Shapley e Nucleolo per
comunità. Il sostituto ex-post è la **covarianza trasversale fra quota e virtuosità**: i
membri virtuosi prendono sistematicamente di più, o no?

L'asse di virtuosità è il fattore `θ·η` di Bilardo già calcolato dalla §6 per il modello 12,
mediato sui giorni **con peso pari all'incentivo maturato** (così un giorno senza
generazione, dove la chiave non è definita, pesa zero e non inquina l'asse):

```
b_i = Σ_d w_d · fAll(d,i)        q_k = phi_k / Σ phi_k        u = 1/n
IS_k    = ⟨q_k − u, b − b̄⟩ / ⟨q_SU − u, b − b̄⟩     forza incentivante
ALIGN_k = cos( q_k − u , b − b̄ )                    allineamento, in [−1,1]
```

**Due ancore esatte**, che in `MAIN2.m` §3t sono `assert`: `IS = 0` per l'**Equal Split**
(quote uguali ⇒ nessun segnale) e `IS = 1` per la **Similarity-Utilization**, che fissa
l'unità di misura. `IS` **non è limitata superiormente**, ed è voluto: è una pendenza, non
una quota. Si legge *1 = come la regola di Bilardo, 2 = il doppio, negativo = premia il
contrario*.

Il coseno del riferimento, invece, **vale meno di 1**, ed è la garanzia che la metrica non
sia circolare: la regola di Bilardo rinormalizza la chiave giorno per giorno, quindi la sua
ripartizione annua non è proporzionale alla media del fattore. Se l'asse fosse l'*output*
della regola invece del *segnale grezzo*, il coseno varrebbe 1 per costruzione e la colonna
misurerebbe sé stessa.

> **Avvertenza sui profili, da leggere prima dei numeri — e non è teorica.** Sui profili
> **netti** il carico residuo del proprietario dell'impianto è nullo proprio nelle ore di
> eccedenza, quindi la sua `θ` crolla e ogni metodo che premi i prosumer viene spinto verso
> il basso. È un artefatto della convenzione, non una proprietà della regola — la stessa
> contaminazione da proprietà dell'impianto per cui il Fairness Index va letto con cautela
> (§7.2). Per questo `MAIN2.m` calcola la colonna su **entrambi** gli assi e stampa il coseno
> fra i due.
>
> Sulle sette comunità miste dei primi studi (7 membri, penetrazione variabile, run di `MAIN.m`) l'effetto è **misurato e grande**, e cresce al calare dei prosumer:
>
> | CER | prosumer | cos(assi) | Shapley netto | Shapley lordo |
> |---|:---:|:---:|---:|---:|
> | `CER_0_7_0` | 7/7 | 0.903 | +0.697 | +1.652 |
> | `CER_2_5_0` | 5/7 | 0.616 | +0.555 | +1.970 |
> | `CER_4_3_0` | 3/7 | 0.566 | +0.384 | +1.014 |
> | `CER_6_1_0` | **1/7** | **0.224** | **−0.657** | **+2.502** |
>
> Con un solo prosumer **il segno dello Shapley si ribalta**: sull'asse netto sembrerebbe
> punire la virtuosità, su quello lordo la premia più di Bilardo. Il coseno scende sotto 0.8
> su **sei comunità su sette**. Conclusione operativa: la graduatoria per forza incentivante
> **va riportata su entrambi gli assi**, e una lettura sui soli profili netti sarebbe una
> conclusione sbagliata, non una conclusione parziale.
>
> **Ma sull'asse lordo si legge il coseno, non l'indice** (`MAIN2.m`, 13 ottobre 2026). Sulla
> griglia a 20 comunità la forza incentivante lorda arriva a ±13 e cambia segno al 100% di
> penetrazione: il suo denominatore, la proiezione della regola di riferimento sull'asse
> lordo, va quasi a zero. Resta in `Tfair` come diagnostica; nell'analisi il controllo lordo
> è `AllineamentoVirtu_lordo`, che sta in [−1, 1] (§7.6).

### 7.1 Due indicatori esclusi, e perché

- **QoE** (Dynge eq. 13-14) richiede il prezzo di mercato locale `λ_t`. In una CER a
  condivisione **virtuale** non esiste: tutti comprano dalla rete al prezzo retail e
  l'incentivo arriva ex post. Il paper stesso non ne propone modifiche e ne rinvia la
  valutazione ad altri meccanismi di prezzo (§6.2.1).
- **Price of Fairness** (Volpato, Carraro, Dal Cin, Rech, *Energies* 17 (2024) 4788,
  eq. 21) confronta due **ottimizzazioni di esercizio**, le cui variabili decisionali sono
  i flussi P2G/P2P e la domanda spostabile. Qui quelle variabili non esistono —
  `shared(t) = min(Σgen, Σload)` è deterministico, l'incentivo è uniforme fra i membri, la
  domanda è rigida — quindi il PoF sarebbe **identicamente nullo per costruzione**.
  Servirebbe prima aggiungere una leva operativa (load shifting o accumulo).

### 7.2 Leggere i numeri: quattro degenerazioni strutturali

Non sono bug, sono proprietà del modello. Vanno riportate, non nascoste.

1. **Un solo prosumer** ⇒ `MinMax_pro = 1` e `Gini` dei prosumer `= 0` per definizione.
2. **Il lato prosumer del QoS nuovo vale 1 anche con più impianti**: nella CER la quota
   condivisa dell'immissione è `shared(t)/genAgg(t)` per chiunque, perché l'attribuzione è
   pro-quota sulla produzione. Lato prosumer il modello è equo *per costruzione*.
3. **Il MinMax originale è identico per tutti i metodi**: i flussi fisici di una
   CER non cambiano al cambiare di chi prende i soldi. È la versione estrema della critica
   che il paper stesso muove all'indicatore.
4. **Anche gli indicatori energetici (`MinMax_con`, `QoS`, `Jain`) variano pochissimo fra i
   metodi.** Sulla griglia la frazione di energia condivisa *contendibile* — quella su cui
   una chiave può davvero incidere — va dall'**11%** (`CER_5_15_0`) al **42%**
   (`CER_0_5_0`): è più alta agli estremi della penetrazione (22-30% alla fascia 1, 30-42%
   al 100%) e più bassa in mezzo (11-18%). Nelle ore sature, che portano il resto della
   condivisa, l'immissione copre l'intero carico residuo e ogni utente riceve esattamente
   il proprio consumo, qualunque sia la chiave. Gli indicatori **energetici** descrivono
   quindi la comunità più che il metodo — a discriminare sono quelli **economici**, e
   `Tfair` di `MAIN2.m` tiene infatti solo EI e Gini fra quelli di Dynge & Cali.

`MAIN2.m` §3t stampa `contendibleShare` a ogni esecuzione, proprio perché le colonne
quasi costanti non vengano scambiate per un errore di calcolo.

### 7.3 Verifiche automatiche

`MAIN2.m` contiene 41 `assert`, più quello di efficienza che `report_allocation` esegue su
ogni metodo (la ripartizione somma a `v(N)`): valgono come test di regressione. Quelli sugli
indicatori, in §3t:

- **Equal Split ⇒ `EI_orig = 1` e `InclusioneLIHC = 1`** esatti (il Gini di un vettore
  uniforme è zero; quote uguali danno ai vulnerabili esattamente la loro quota di membri).
- **Marginal Contribution ⇒ `FI = 0`** esatto, perché la normalizzazione dell'eq. 10 di
  Cremers *coincide* con l'eq. 13 di Casalicchio. (Se qualche `BCᵢ = 0`, il metodo cade
  nella branca intera e l'assert verifica quella.)
- **MinMax originale identico** fra i metodi.
- **L'energia implicita somma all'energia condivisa** di comunità.
- **Eccesso del Nucleolo `= −Nu.thetaMin`**, ed è il **minimo** fra i metodi — è ciò che
  minimizza per costruzione; **eccesso del VLC `= −VLC.thetaLC`**, entro la sua tolleranza
  di convergenza (`tolConv`). Sono la stessa grandezza con il segno opposto (il Nucleolo
  riporta il *surplus* della coalizione più scontenta, `Σxᵢ − v(S)`): verifica gratis che
  l'eccesso giri sulla stessa `v(S)` del gioco.
- **Forza incentivante `= 0` per l'Equal Split** (su entrambi gli assi) e **`= 1` per la
  Similarity-Utilization**; coseno in `[−1, 1]`, virtuosità in `[0, 1]`.
- EI e Gini **dentro `[0,1]`**.

Gli altri controllano il bilancio (§2), il gioco (stesso `v(N)` per le due strade del
fattore F, `theta_LC` del VLC uguale a `theta_min` del Nucleolo, `v(N)` di AS e MC uguale
a quello dello Shapley), il Tri-level EP e l'analisi dopo il ciclo; elenco completo in
[STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt) §9.

Le verifiche che passano dall'eccesso di coalizione o dal Nucleolo **non girano sopra i
18 utenti**, dove né il Nucleolo né l'eccesso vengono calcolati (§14.1). Le altre valgono a
ogni taglia.

Inoltre `fairness_index_bm.m` ha un auto-test analitico (`opts.validateSelf`, attivo di
default): la Tab. 7 del paper **non** è riproducibile — i `Dᵢ` per membro stanno solo in un
grafico — quindi si verifica la formula su casi costruiti a penna, contributi negativi
inclusi.

Stessa convenzione in `premium_excess_threshold.m` (§7.4), e lì serve per una ragione
precisa: la formula dell'eccedenza ha **due letture plausibili** e solo una è quella del
GSE. Un refuso che scivolasse sull'altra darebbe numeri credibili e sbagliati (83,33 €
invece di 50,00 € sul caso di riferimento), senza che nessun `assert` a valle se ne
accorga. L'auto-test blocca proprio quello, più il regime 45%/55%, il riconoscimento
della violazione e la classificazione impresa / non-impresa.

### 7.4 Ammissibilità regolatoria: la soglia di energia incentivabile

Il §7 giudica i metodi sull'**equità**; `MAIN2.m` §3u li giudica sulla **norma**.
Sono due domande diverse: un metodo può essere il più equo di tutti e restare
inammissibile, o viceversa.

**La regola.** Il Decreto CACER (DM MASE 7 dicembre 2023 n. 414, art. 3 c. 2 lett. g e
Allegato 1 §§3-4; Regole Operative GSE del 16 luglio 2025, §2.2.2.1.3 e Appendice B §4)
fissa un valore soglia dell'energia condivisa incentivabile, espresso in **percentuale
dell'energia immessa in rete**:

| Regime | Soglia |
|---|---|
| accesso alla sola tariffa premio | **55%** |
| cumulo della tariffa premio con contributo in conto capitale | **45%** |

L'importo di premio che eccede la soglia **non può essere destinato ai membri che sono
imprese**: spetta ai soli consumatori diversi dalle imprese, o a finalità sociali con
ricadute sui territori dove stanno gli impianti.

```
%E_ACI,ecc = max[0; (E_ACI / E_immessa · 100)% − valore soglia]
C_ACI,ecc  = %E_ACI,ecc · C_ACI
```

Attenzione alla seconda riga: l'eccedenza economica è il prodotto **letterale** fra la
differenza in *punti percentuali* e l'importo totale del premio — non la quota
proporzionale di premio associata all'energia in eccesso, che varrebbe
`(quota − soglia)/quota · C_ACI`. Con `quota = 60%` e `soglia = 55%` l'eccedenza vale il
**5%** di `C_ACI`, non l'8,3%. Si implementa la formula del GSE alla lettera, perché è
quella che il GSE applica a conguaglio.

**Perché è post-hoc, e non dentro i metodi.** La norma non dice *come* ripartire: dice
dove non può finire una parte del già ripartito. Entrare nei metodi li renderebbe
non più confrontabili con i rispettivi paper — che è il punto del confronto del §6. È
anche l'ordine in cui la norma stessa opera: il GSE verifica il superamento della soglia
**a conguaglio, su base annuale**, sull'esito della ripartizione.

**Due esiti, da non confondere.** Se la quota incentivata sta sotto la soglia il vincolo è
**non binding**, l'eccedenza è nulla e *nessun* metodo può violarlo: è un fatto della
configurazione energetica, non dei meccanismi. Solo se è **binding** ha senso chiedersi
quale metodo assegni alle imprese più del consentito (tetto: `(1 − %E_ACI,ecc) · C_ACI`).

**Sulla griglia il vincolo non morde: la quota resta sotto il 55% in tutte le 28
comunità.** Il rapporto `E_ACI/E_immessa` scende con la penetrazione — più prosumer, più
potenza installata, più energia immessa che non trova carico residuo da coprire (run del
13 ottobre, `outputs/workspace/export_griglia25/comunita.csv`):

| Membri | Fascia 1 (20-30%) | Fascia 2 (40-53%) | Fascia 3 (60-80%) | Fascia 4 (100%) |
|---:|---:|---:|---:|---:|
| 5 | **50,1%** | 23,8% | 11,9% | 1,4% |
| 8 | 43,5% | 17,3% | 7,6% | 1,2% |
| 10 | 35,3% | 18,6% | 5,7% | 1,3% |
| 15 | 43,5% | 17,2% | 8,6% | 1,3% |
| 18 | 41,8% | 19,0% | 6,9% | 1,4% |
| 20 | **45,6%** | 18,3% | 7,2% | 1,4% |
| 25 | 37,4% | 16,2% | 6,4% | 1,3% |

Nel regime al 45% (con conto capitale) il vincolo sarebbe binding in due comunità a bassa
penetrazione, `CER_4_1_0` e `CER_15_5_0`. Neanche lì cambierebbe la ripartizione: la
destinazione dell'eccedenza riguarda le **imprese**, e i membri della griglia sono tutti
domestici (persone fisiche, non imprese). Sulle sette comunità miste dei primi studi la
quota andava dal 2,2% al 25,7% e il vincolo sembrava strutturalmente irrilevante; la
griglia mostra che a bassa penetrazione ci si avvicina. È un risultato da riportare come
tale, non un controllo da togliere: cambia con i dati, non con il codice.

**Due ipotesi dichiarate.**

1. **Chi è "impresa".** La norma esenta i punti di prelievo di enti territoriali e autorità
   locali, enti religiosi, enti del terzo settore e di protezione ambientale, e *persone
   fisiche*. Sul dominio di `[MEMBRI].categoria` la mappatura è `domestico` → persona
   fisica e `PA` → ente territoriale (**non** imprese), `terziario | commerciale |
   industriale` → **imprese**. È un'ipotesi, non un dato: la categoria del progetto è una
   *tipologia di consumo*, non una forma giuridica, e un ente del terzo settore
   ricadrebbe sotto `terziario` e verrebbe contato come impresa a torto. Si sovrascrive
   con `opts.categorieImpresa`.
2. **Quale delle due soglie.** La decide `[INVESTIMENTO].contributo_conto_capitale_pct`,
   che finora era letto e validato ma mai usato. A `?` si ripiega su
   `tip_fattore_riduzione` (`F > 0` implica conto capitale, Allegato 1 §3); se nessuno
   dei due è noto resta il regime base al 55%, che è quello attuale.

Il risultato per comunità sta in `RESULTS(i).soglia`, con `.isBinding`, `.quotaEccedente`,
`.importoEccedente` e la tabella per metodo (`.table`).

### 7.5 Il fattore di riduzione F, e chi ne è esente

**La regola.** Con un contributo in conto capitale la tariffa premio è decurtata:
`TIP = TIP_lorda · (1 − F)`, dove `F` varia linearmente fra `0` (nessun contributo) e
`0,50` (contributo pari al **40%** dell'investimento) — Regole Operative GSE del
16 luglio 2025, Appendice B §3. Quindi `F = 0,50 · pct/40`. Oltre il 40% la tariffa non è
cumulabile affatto (§1.2.1.6): lì `cer_reduction_factor.m` si ferma con un errore invece
di troncare in silenzio.

**L'esenzione, e la voce che sfugge.** F *non si applica* all'energia afferente a punti di
prelievo di enti territoriali, enti religiosi, enti del terzo settore e di protezione
ambientale, **e persone fisiche** (§2.2.2.1.2).

> ⚠️ Le **persone fisiche** non erano nell'Allegato 1 del DM 414/2023: le ha aggiunte il
> **DM 127 del 16 maggio 2025** (Premessa delle Regole Operative, p. 5). Chi cita il solo
> 414/2023 legge la lista *pre-127* e lascia fuori la categoria più numerosa di una CER
> residenziale — sulla griglia, **tutti** i membri.

**Il campo che lo esprime.** Il dominio di `[MEMBRI].categoria` si è allargato a
`terzo_settore | religioso | ambientale`. È additivo — nessuna scheda esistente cambia — e
serve perché una tipologia di *consumo* non sa esprimere una forma *giuridica*: un ente del
terzo settore consuma come un terziario, e contarlo come impresa costerebbe il 50% della
tariffa. Esenti: `domestico` (persone fisiche), `PA` (enti territoriali), `terzo_settore`,
`religioso`, `ambientale`.

**Perché F entra dentro `v(S)` e non nella tariffa.** F dipende da *chi* consuma l'energia
condivisa, quindi cambia da coalizione a coalizione. Sulle schede miste dei primi studi la
quota esente andava da **0%** (coalizioni di sole imprese) a **100%** (di sole famiglie),
contro l'1-20% della comunità intera. Usare la quota di comunità dentro `v(S)`
sottostimerebbe le coalizioni ricche di esenti e farebbe sembrare la CER **più stabile di
quanto sia** — un bias proprio sull'indicatore del §7.3. Sulla griglia attuale la questione
non si pone: tutti i membri sono domestici, quindi esenti, la quota esente vale 100% per
ogni coalizione e F non toccherebbe `v(S)` nemmeno con un contributo in conto capitale
(cambierebbe solo la soglia del §7.4, dal 55% al 45%). Il trattamento per coalizione resta
per le comunità miste. Perciò:

- `compute_cer_incentive.m` produce la tariffa **lorda** (`F = 0`), che è poi la tariffa
  dei membri esenti;
- la decurtazione entra in `cer_shared_value.m`, con la quota esente **della coalizione**;
- i metodi che spartiscono solo `v(N)` ricevono la **tariffa efficace di comunità**.

Le due strade danno lo stesso `v(N)` per costruzione, ed è verificato da un `assert` in
`MAIN2.m` §3b — senza, un F applicato due volte si vedrebbe solo come uno scarto
inspiegabile fra metodi.

**Cosa succede davvero** (`CER_6_1_0`, scheda mista dei primi studi, ora in
`CER_configuration/Provvsiorio/`; gli stessi profili, solo il contributo cambia; run di
`MAIN.m`):

| Conto capitale | `F` | `v(N)` | Quota domestici | in % di `v(N)` |
|---:|---:|---:|---:|---:|
| 0% | 0,000 | €2039,54 | €200,06 | 9,8% |
| 20% | 0,250 | €1632,28 | €202,02 | 12,4% |
| 40% | 0,500 | €1225,02 | €203,99 | **16,7%** |

> ⚠ **Valori assoluti da rigenerare.** Questa tabella precede l'unificazione del calendario
> (§5.1): con i profili corretti `v(N)` di `CER_6_1_0` vale ora **€2130,66** e non €2039,54,
> e le due righe con `F > 0` richiedono un nuovo run dopo aver compilato il contributo in
> conto capitale. **Il meccanismo che la tabella illustra non cambia** — il montepremi
> crolla, la quota in euro dei domestici no — ma i tre numeri vanno rimisurati prima di
> citarli in tesi, su una scheda mista: sulla griglia, tutta domestica, F non ha effetto.

Il montepremi crolla del 40%, ma la quota in euro dei domestici **non si muove** (€200 →
€204): l'esenzione li protegge, e la loro fetta relativa passa da 9,8% a 16,7%. È
l'effetto che la norma cerca, e si vede **solo** con il trattamento per coalizione — con
una quota di comunità scenderebbero in proporzione come tutti.

**`v` non è più monotona, ed è la norma a volerlo.** Con `F > 0` aggiungere un membro può
*ridurre* `v(S)`. Un'ora sola, `P` che produce 10 kWh, `A` esente e `B` non esente che
consumano 10 kWh ciascuno, `F = 0,5`:

| Coalizione | Energia condivisa | Quota esente | Tariffa | `v` |
|---|---:|---:|---:|---:|
| `{P,A}` | 10 kWh | 100% | piena | **1,00 €** |
| `{P,A,B}` | 10 kWh | 50% | −25% | **0,75 €** |

L'energia è la stessa — è la *generazione* a fare da tappo — e `B` cambia solo le
proporzioni: `MC_B = −0,25 €`. Non è un dato corrotto, è il premio che il GSE
erogherebbe davvero. `marginal_contribution_cer.m` mantiene perciò l'errore solo quando
`F = 0` (dove la monotonia è garantita) e con `F > 0` emette un warning, azzerando le
quote negative. Serve una comunità **povera di impianti** perché accada: sulle schede miste
dei primi studi, ricche di surplus, il minimo `MC` restava ampiamente positivo anche a
`F = 0,50` (+24 € su `CER_0_7_0`, +51 € su `CER_6_1_0`).

**Un limite introdotto, dichiarato.** Con `F > 0` il Separation Problem del Variance Least
Core smette di essere un MILP: il valore della coalizione contiene
`s_t · loadNonEsente(z)/load(z)`, un **rapporto** fra combinazioni lineari delle binarie.
Linearizzarlo è un lavoro di modellazione a sé. Finché non è fatto, con `F > 0` la
separazione ripiega sull'**enumerazione** di tutte le coalizioni: il risultato è esatto —
anzi, è la separazione esatta per definizione, e `theta_LC` continua a coincidere con il
surplus minimo del Nucleolo — ma il metodo perde la scalabilità che è il suo tratto
distintivo e ricade nel limite di §14.1. Con `F = 0` non cambia nulla.

**Regressione.** Con `contributo_conto_capitale_pct = ?` si ha `F = 0` e l'output è
**identico riga per riga** a prima dell'introduzione del fattore: le uniche differenze
sono le nuove righe diagnostiche della §1c.

### 7.6 Quanto gli indicatori concordano, e quanto la graduatoria dipende dalla comunità

Le §7.0–7.5 dicono **quali** indicatori esistono e cosa misurano. Questa sezione risponde
alle due domande che vengono dopo, e che il §2.6 della tesi pone esplicitamente: *quanto
indicatori diversi concordino nel giudicare gli stessi metodi*, e *quanto la graduatoria
dipenda dalla composizione della comunità*. Le calcola `MAIN2.m` §7b — **dopo** il ciclo,
perché servono tutte le comunità insieme — e le scrive in `outputs/tables_main2/confronto/`
(§11.0).

**L'accordo si misura col τ-b di Kendall**, scritto a mano perché il progetto non dipende
dallo Statistics Toolbox. Prima di calcolarlo bisogna **orientare** gli indicatori, ed è il
passaggio più facile da sbagliare: EI, Jain, QoS e MinMax vanno verso 1, mentre Gini,
Fairness Index, σ ed EccessoMax vanno verso il basso. Senza orientarli, τ fra EI e Gini
verrebbe −1 mentre la verità è +1. L'orientamento è quindi **dato e non codice** — sta in
una tabella letterale, esce in `orientamenti.csv`, e una colonna nuova di `Tfair` senza un
verso dichiarato fa **fallire** la funzione invece di farle indovinare.

C'è un'ancora esatta che verifica tutto l'impianto in un colpo solo: `fairness_indicators_lem`
calcola `eiOrig = 1 - gini` sullo **stesso** vettore di risparmi, quindi dopo un orientamento
corretto `τ(EI_orig, Gini)` deve valere **esattamente +1** su ogni configurazione. È un
`assert` in §7b, e verifica insieme la tabella dei versi, la regola dei pareggi e
l'implementazione del τ.

**Il risultato: la §7.0 non è un aneddoto, ed è modulata dalla composizione.** L'accordo fra
uniformità e stabilità — due domande che il §7.0 dice opposte — dipende dalla penetrazione
(τ-b sulle cinque taglie da 5 a 18 membri, `sintesi/tau_per_fascia.csv`):

| Fascia | Penetrazione | `τ(EI_orig, EccessoMax_EUR)` medio | fra le taglie |
|---|---|---:|---|
| 1 | 20-30% | +0,11 | da −0,53 a +0,35 |
| 2 | 40-53% | −0,32 | da −0,42 a −0,20 |
| 3 | 60-80% | −0,42 | da −0,49 a −0,38 |
| 4 | 100% | −0,36 | da −0,49 a −0,16 |

Con pochi prosumer i due criteri sono in media quasi indipendenti, e il segno cambia da una
taglia all'altra; da metà penetrazione in su si oppongono a ogni taglia. La divergenza
raccontata a parole nel §7.0 non è una costante della CER, è una funzione della sua
composizione. (Sulle sette comunità miste dei primi studi, con `MAIN.m`, l'andamento era
opposto — più negativo con meno prosumer — ma quelle comunità avevano un'altra
composizione per categoria e quei numeri precedono la correzione del calendario, §5.1: il
confronto dice solo che la direzione non è una proprietà generale.)

#### 7.6.1 Cosa entra nell'analisi (`MAIN2.m` §7b)

`Tfair` contiene tutto quello che si calcola; τ, inversioni, vincitori e fronti di Pareto ne
usano una parte. Le esclusioni passano per due opzioni di `compute_indicator_agreement`
(`escludiMetodi`, `escludiIndicatori`, vuote di default), quindi le colonne escluse restano
leggibili in `Tfair`.

| Fuori dall'analisi | Perché | Cosa resta |
|---|---|---|
| **Adaptive Sampling Shapley**, se lo Shapley esatto c'è in tutte le comunità | sposta lo 0,4% di v(N) rispetto allo Shapley: contarlo due volte raddoppia coppie e presenze sul fronte | in `Tfair`; sopra i 18 membri resta nell'analisi come sostituto dello Shapley |
| `QuoteNulle` | distingue i metodi in 1 comunità su 20 | in `Tfair`, serve a leggere la branca intera del Fairness Index |
| `ForzaIncentivante_lordo` | sull'asse lordo il denominatore va quasi a zero: valori fino a ±13 e inversioni nell'82% delle serie | in `Tfair` come diagnostica; come controllo lordo resta il coseno `AllineamentoVirtu_lordo` |
| `EccessoMax_pct_vN` (nuova) | dentro una comunità ordina i metodi come `EccessoMax_EUR`, su cui è tarata la soglia del 5% di v(N) | in `Tfair`, per confrontare l'eccesso **fra taglie** |

Verifica, alla revisione del 13 ottobre (20 comunità fino a 18 membri): quote, VAN e
`Tfair` identici; i punteggi dei metodi e degli indicatori rimasti identici; nessun
vincitore cambia (200 casi su 200); il τ medio fra gli indicatori rimasti si muove al più di
0,03, perché si calcola su 11 metodi invece di 12. Dopo le esclusioni l'analisi usa **11
indicatori** — i 10 di `Tfair` rimasti più `VAN_min_EUR` — e 11 metodi fino a 18 membri, 10
sulla griglia fino a 25 (§7.9).

#### 7.6.2 Due assi: taglia × penetrazione

Con le schede della griglia (5, 8, 10, 15, 18, 20, 25 membri × quattro livelli di
penetrazione) l'asse unico non regge più: la stessa penetrazione ricorre a taglie diverse
(50% a 8, 10, 18 e 20 membri), e `extract_ranking_reversals` si ferma, giustamente,
perché fra due configurazioni alla stessa penetrazione "prima" e "dopo" sarebbero
arbitrari. Ordinare tutto per penetrazione mescolerebbe poi l'effetto della taglia con
quello della composizione. La griglia si legge quindi **un fattore alla volta**, più una
vista **congiunta**:

| Vista | Funzione | Cosa risponde |
|---|---|---|
| sweep di **penetrazione** a taglia fissa | `reversals_by_axis.m` | una scansione per taglia, lungo le sue fasce: quanto la graduatoria dipende dai prosumer a parità di membri |
| sweep di **taglia** a fascia fissa | `reversals_by_axis.m` | una scansione per fascia, lungo le taglie: quanto dipende dal numero di membri a parità di penetrazione |
| **heatmap congiunta** | `ranking_grid.m` + `plot_ranking_grid.m` | il metodo primo in ogni cella (n, ρ), un pannello per dimensione della domanda di ricerca, e se i due fattori interagiscano |

`reversals_by_axis` non reimplementa la scansione: passa a `extract_ranking_reversals`
sottoinsiemi della griglia su cui l'asse è strettamente crescente, quindi stessi punteggi
e stesse tolleranze di sempre. Con una taglia sola — il vecchio studio a sette comunità — produce
esattamente la scansione di prima.

**Le fasce sono ranghi, non soglie.** A 5 membri la penetrazione sale a passi di 20 punti,
a 25 di 4: arrotondare a 25/50/75/100% farebbe collidere 40% e 60% a n = 5. La fascia *k*
è la *k*-esima penetrazione in ordine crescente dentro la taglia; ogni cella della heatmap
riporta il valore esatto. Lo sweep di taglia tiene quindi fermo il rango, non il valore
(20% a 5 membri, 28% a 25), e porta con sé quello scarto residuo.

**L'interazione in un numero.** Per ogni indicatore si prende, taglia per taglia, la
sequenza dei vincitori lungo le fasce. `QuotaModale` è la quota di taglie che segue la
sequenza più frequente: 1 vuol dire che l'effetto della penetrazione sul vincitore è lo
stesso a ogni taglia, valori bassi che i due fattori interagiscono. Guarda il solo primo
classificato, non l'intera graduatoria. Quando i primi due sono entro la soglia di
rilevanza (§7.6.3) la cella è "pari" e dice fra chi.

#### 7.6.3 La soglia di rilevanza

Con la sola tolleranza numerica (1e-6 dell'escursione) ogni scambio di posto fra due metodi conta come inversione, anche se i due differiscono di un millesimo di Gini. `apply_relevance_threshold.m` estende a **tutti** gli indicatori la soglia che MAIN2 applicava al solo `EccessoMax_EUR` (5% di v(N)): sugli indicatori in euro resta il 5% di v(N); sugli altri (adimensionali, VAN, forza incentivante) due metodi sono a pari se distano meno del **10% dell'escursione** osservata fra i metodi di quella comunità. La percentuale è una scelta di modello, un parametro (`opts.fracEscursione`): va riportata la sensibilità. Il tau-b di Kendall non cambia, resta calcolato con la tolleranza numerica.

`ricalcola_inversioni_soglia.m` rifà il solo post-processing di §7b da `RESULTS` e `AGR`,
senza rilanciare Shapley e Nucleolo. `sensibilita_soglia.m` ricalcola inversioni e
vincitori a quattro soglie: sui run finali le inversioni calano con la soglia ma non
spariscono, e il primo classificato non cambia mai (§7.9).

#### 7.6.4 Le inversioni nei run finali (13 ottobre 2026)

| Sweep | Fisso | fino a 18 membri (11 metodi, 605 serie) | griglia fino a 25 (10 metodi, 495 serie) |
|---|---|---:|---:|
| penetrazione | n = 5 | 164 (27%) | 143 (29%) |
| penetrazione | n = 8 | 200 (33%) | 172 (35%) |
| penetrazione | n = 10 | 183 (30%) | 165 (33%) |
| penetrazione | n = 15 | 171 (28%) | 152 (31%) |
| penetrazione | n = 18 | 157 (26%) | 140 (28%) |
| penetrazione | n = 20 | — | 118 (24%) |
| penetrazione | n = 25 | — | 110 (22%) |
| taglia | fascia 1 (~27%) | 127 (21%) | 108 (22%) |
| taglia | fascia 2 (~50%) | 52 (8,6%) | 53 (11%) |
| taglia | fascia 3 (~75%) | 4 (0,7%) | 27 (5,5%) |
| taglia | fascia 4 (100%) | 35 (5,8%) | 40 (8,1%) |

Coppie di metodi che si invertono almeno una volta, con la soglia di rilevanza di default
(`confronto/inversioni_per_sweep.csv`). Una serie è un indicatore per una coppia di metodi:
11 indicatori × 55 coppie fino a 18 membri, × 45 sulla griglia.

- **La sensibilità alla penetrazione cala con la taglia**, da 8 membri in su: dal 33-35% a
  8 membri al 22% a 25. Per circa una coppia di metodi su tre, quale dei due sia
  preferibile **cambia** con la quota di prosumer: è la risposta alla terza clausola della
  domanda di ricerca.
- **La sensibilità alla taglia dipende dalla fascia**: massima a bassa penetrazione (21-22%
  alla fascia 1), minima alla fascia 3 (0,7% fino a 18 membri, 5,5% fino a 25). I due sweep
  non vanno confrontati fra loro in valore assoluto: uno ha 4 configurazioni per
  sottoinsieme, l'altro 5 o 7, e più passi danno più occasioni di invertirsi.
- **Il primo classificato si muove poco** (`griglia_interazione.csv`). Sull'uniformità la
  `QuotaModale` è 1 in entrambi i run (Equal Split ovunque); su merito e stabilità è 1 fino
  a 18 membri, dove VLC e Nucleolo sono sempre a pari (0,57 sul merito fino a 25, dove il
  VLC vince da solo in metà delle celle); sulla forza incentivante 0,8-0,86. L'interazione
  fra i due fattori sul vincitore compare sugli indicatori secondari: allineamento lordo
  0,29-0,4, inclusione 0,5, VAN del membro peggiore 0,57-0,6.
- **Invertite agli estremi.** `inversioni_sommario.csv` dice anche se una coppia è
  invertita fra i due estremi dell'asse, che non è deducibile dal conteggio: un numero pari
  di inversioni riporta all'ordine di partenza. "Estremi" significa il primo e l'ultimo
  segno **non nullo**, che coincidono con la prima e l'ultima configurazione solo se la
  coppia non è a pari lì: le colonne `AsseSegnoIniziale` e `AsseSegnoFinale` dicono dove
  stanno davvero.

#### 7.6.5 Le tre sintesi (`MAIN2.m` §7c, `sintesi_risultati.m`)

Le tabelle di §7b sono in formato lungo. `sintesi_risultati` ne ricava tre letture, scritte in `outputs/tables_main2/sintesi/`. **Misurate sulle 20 comunità fino a 18 membri** (soglia di rilevanza attiva, vendita corretta come in §5.2).

- **Accordo per fascia e taglia** (`tau_per_fascia`, `tau_per_taglia`, `tau_per_cella`): il tau-b medio, minimo e massimo per coppia di indicatori, con il segno che cambia o no fra le fasce. La fascia è il rango della penetrazione dentro la taglia. Esempio: tau(Gini, Fairness Index) vale +0,41 alla fascia 1 e fra −0,14 e −0,32 nelle altre; tau(Gini, forza incentivante) va da −0,16 (fascia 1) a −0,91 (fascia 4).
- **Fronte di Pareto** (`pareto_per_comunita`, `pareto_conteggi`): per ogni comunità e per quattro insiemi di criteri, i metodi non dominati. Dominanza con la stessa soglia di rilevanza delle inversioni. L'Adaptive Sampling Shapley è escluso a monte, in §7b, perché duplica lo Shapley (scarto ~1%). Con la soglia i fronti sono più stretti: 4,1 metodi su 11 in media sull'insieme merito + stabilità + incentivo, 6,2 su equità + incentivo + VAN (7,4 prima della correzione della vendita, §5.2), 2,8 su equità + coseno lordo + VAN (l'incentivo lordo è il coseno, non la forza incentivante lorda: vedi sopra). Il Nucleolo e il VLC stanno sul fronte merito/stabilità/incentivo 19 volte su 20, ma **anche Tri-level EP (75%), che gira su dati segnaposto (§6)**.
- **Quote ai prosumer** (`quote_prosumer`, `quote_prosumer_fascia`): quota di v(N) ricevuta dai prosumer e suo rapporto con la quota di membri. Lo Shapley passa da 1,73 (pochi prosumer) a 0,44 (fascia 3): premia il lato scarso, e cambia lato con la penetrazione. Pearson Key e Similarity-Utilization restano sotto 0,2 a ogni fascia (premiano chi consuma, non chi produce). Alla fascia 4 (100% prosumer) il rapporto vale 1 per costruzione.

> ⚠ Il fronte dice quanto i criteri siano in conflitto, non quale metodo sia migliore. La scelta dell'insieme dei criteri e la soglia del 10% sono scelte di modello: riportare la sensibilità.

> ⚠ **Tre limiti da tenere presenti leggendo la griglia.**
> 1. `compute_indicator_agreement` tiene solo i metodi presenti in **tutte** le comunità.
>    Sopra i 18 membri Shapley e Nucleolo sono saltati (§14.1), quindi su una griglia che
>    arriva a 25 spariscono **anche dalle celle a 5-18 membri**: per questo i run sono due
>    (§7.9).
> 2. L'eccesso di coalizione (stabilità) non è calcolato sopra i 18 membri: le celle a 20 e
>    25 del pannello di stabilità sono "n.d.".
> 3. Il VAN esiste solo dove la scheda compila `quota_inv_EUR`: sulle 28 comunità della
>    griglia c'è ovunque (verificato il 13 ottobre 2026).

### 7.7 Inclusione: quanto va ai vulnerabili LIHC (`inclusion_index.m`)

> ✅ **Compilati il 19 ottobre 2026** in `CER_configuration/scenario_economico.txt` i tre dati che
> decidono **chi** è vulnerabile (fonti in `Paper/PARAMETRI_TESI_fonti.md` della sessione di ricerca
> del 19/10; qui il riassunto):
>
> | Chiave | Valore | Come si ricava | Stato |
> |---|---:|---|---|
> | `[MERCATO].markup_retail` | 3,02 | prezzo finale medio domestici 2025 0,3512 €/kWh (ARERA, Relazione annuale 2025, p. 9) / PUN medio 2025 0,11615 €/kWh | dedotto; è la media di tutti i domestici, non del cliente da 3 kW; il PUN viene da una fonte secondaria |
> | `[POVERTA_ENERGETICA].mediana_spesa_energetica_EUR` | 1 652 € | 2 105 kWh (mediana annua delle cento famiglie simulate) × 0,3512 €/kWh + 630 smc × 10,57 kWh/smc × 0,1371 €/kWh | **stimato**: il paper non dà P50 e l'Istat non scorpora elettricità e gas; è una ricostruzione lombarda, non la mediana nazionale |
> | `[POVERTA_ENERGETICA].soglia_poverta_EUR_equivalente` | 13 237 € | 60% del reddito mediano equivalente, Istat 2025 (redditi 2024) | letto; è **per adulto equivalente**, non per percettore |
>
> **La soglia del nucleo** è y* × `scala_equiv` (colonna di `[MEMBRI]`, scala OCSE modificata:
> 1,0 il primo adulto, 0,5 ogni altra persona di 14+ anni, 0,3 ogni minore di 14, calcolata dalle
> età dell'archetipo con `CER_LoadProfiles/compila_scala_equiv.py`; la collaboratrice domestica di
> CHR19 non conta). `MAIN2.m` la converte per percettore, `y* × scala / n_perc`, e `lihc_index.m`
> accetta ora una soglia per nucleo. Il 10 052 € del paper non compare in nessuna serie ufficiale
> e non si usa più. Il vecchio nome della chiave, `soglia_poverta_EUR_percettore`, non esiste più
> (la leggeva solo `MAIN.m`).
>
> ⚠ **Con questi valori nessun nucleo della società da cento famiglie è vulnerabile.** I redditi
> delle schede sono la media Istat della tipologia familiare ±15% (§9): il minimo è 21 333 € e il
> rapporto fra reddito netto e soglia del nucleo non scende sotto 1,14, quindi la condizione
> *Low Income* non scatta mai (55 famiglie su 100 sono *High Cost*, ma nessuna è anche povera).
> L'indicatore di inclusione è `NaN` in tutte le comunità e il livello di solidarietà del Tri-level
> EP si azzera. Non è un errore di codice: la distribuzione dei redditi è troppo compressa per
> contenere poveri. **Decisione dell'autore (19/10/2026): si accetta.** I redditi vengono da Istat, e se
> nessun nucleo risulta povero non è un problema del modello: l'inclusione LIHC non è valutabile su questa
> società e si dichiara come tale (l'indicatore è `NaN` e compute_indicator_agreement lo tratta come non
> discriminante). **Limite sul gas:** la categoria d'uso del gas si estrae dalle stesse quote ARERA per
> ogni famiglia, indipendentemente dalla tipologia (stesse proporzioni di cottura e riscaldamento in tutte
> le classi di reddito): il gas non varia per tipologia familiare. Oggi non incide sui risultati, perché senza
> famiglie a basso reddito la spesa energetica alta non basta a renderle vulnerabili.

È la nozione di *inclusione* della domanda di ricerca. Per ogni metodo:

```
Incl_k = ( quota di v(N) che il metodo k dà ai vulnerabili ) / ( vulnerabili / membri )
```

Esempio: 10 membri, 1 vulnerabile, v(N) = 500 €. Un metodo che gli dà 50 € vale
(50/500)/(1/10) = **1**, cioè in proporzione al suo numero, come l'Equal Split; uno che
gliene dà 25 vale **0,5**. Senza vulnerabili l'indice è `NaN` ("non calcolabile", non
"esclusi"). Chi è vulnerabile lo decide l'indice LIHC (`lihc_index.m`) con la **stessa**
classificazione del Tri-level EP: la regola sta in un posto solo. La colonna è
`Tfair.InclusioneLIHC`, verso "più alto = più inclusivo"; `MAIN2.m` §3t verifica che l'Equal
Split valga 1.

**Cosa dice oggi, coi segnaposto** (20 comunità fino a 18 membri, run del 13 ottobre 2026):

- l'indice è definito in 16 comunità su 20 (le quattro da 5 membri non hanno vulnerabili);
- sotto il 100% di penetrazione va da circa 0,1 (Similarity-Utilization, che premia il
  sincronismo e quindi non la famiglia vulnerabile) a 1,3-1,8 (Cascading Tree, Weighted
  Solidarity); al 100% il massimo è il Tri-level EP (≈4,3), che riserva per costruzione una
  quota ai vulnerabili;
- concorda poco con gli altri indicatori (τ medio fra −0,14 e +0,19), e va contro
  l'allineamento alla virtuosità (−0,36 netto, −0,60 lordo): è una nozione a sé, non un
  doppione;
- cambia graduatoria nel 63% delle coppie lungo la penetrazione: misura **una** famiglia, e
  ogni composizione la tratta in modo diverso. È il primo numero da rileggere coi dati veri.

Verifica: aggiungere la colonna lascia identici al bit quote, VAN, `Tfair`, punteggi, τ e
tolleranze di tutti gli altri indicatori; nelle tabelle cambiano solo le righe nuove.

### 7.8 Quanto costano i trade-off, e quali indicatori bastano

Le ultime due clausole della domanda di ricerca: (ii) *quanto* si perde su una nozione per
guadagnare su un'altra, e (iii) quale sottoinsieme minimo di indicatori basta. Le calcola
`MAIN2.m` §7c, dopo le sintesi della §7.6.5, e le scrive in `outputs/tables_main2/sintesi/`.
Numeri sulle 20 comunità fino a 18 membri, run del 13 ottobre 2026.

#### (ii) Perdite fra criteri (`tradeoff_losses.m`)

**Rimpianto** di un metodo su un indicatore: quanto dista dal migliore, in quota
dell'escursione fra i metodi di quella comunità. 0 = è il migliore, 1 = è il peggiore. Sugli
indicatori in euro c'è anche la distanza in euro, e per l'eccesso di coalizione in % di v(N).
File: `rimpianto_per_comunita.csv`, `rimpianto_medio.csv`.

**Perdita fra criteri**: si sceglie il metodo migliore sul criterio A e si legge il suo
rimpianto sul criterio B. Esempio: il migliore sul Gini è l'Equal Split; se il suo eccesso è
100 € su un'escursione fra 0 e 120 €, la perdita vale 100/120 = 0,83. Se su A più metodi sono
a pari (soglia di rilevanza della §7.6.3) si danno due letture: *ottimistica* (fra i pari, il
migliore su B) e *pessimistica* (il peggiore). La matrice non è simmetrica. File:
`perdite_tradeoff.csv` (medie), `perdite_tradeoff_fascia.csv`, `perdite_dettaglio.csv`.

| Scelgo il migliore su… | perdo su uniformità (Gini) | su stabilità (eccesso) | su incentivo | su inclusione |
|---|---:|---:|---:|---:|
| uniformità (Gini) | — | 0,72 (eccesso = 20% di v(N)) | 0,79 | 0,57 |
| stabilità (eccesso) | 0,61 | — | 0,24 | 0,39 |
| merito (Fairness Index) | 0,65 | 0 | 0,32 | 0,56 |
| incentivo (forza incentivante) | 0,93 | 0,29 (6,6% di v(N)) | — | 0,46 |
| inclusione (LIHC) | 0,56 | 0,67 (19,6% di v(N)) | 0,62 | — |

Lettura ottimistica, media sulle comunità. **Merito e stabilità non si fanno concorrenza**
(perdita 0 nei due versi); **uniformità e incentivo sono i due criteri più in conflitto**
(chi vince su uno sta quasi in fondo sull'altro).

#### (iii) Sottoinsieme minimo (`indicator_clusters.m`)

Due indicatori con τ medio vicino a +1 ordinano i metodi allo stesso modo: tenerli entrambi
non aggiunge informazione. Distanza `d = 1 − τ medio`, raggruppamento gerarchico
*average-linkage* scritto a mano, taglio a τ ≥ 0,5 (sensibilità a 0,7 e 0,3), e per ogni
gruppo il membro con il τ medio più alto verso gli altri. File: `cluster_fusioni.csv`,
`cluster_gruppi.csv`, `cluster_sufficienza.csv`, `cluster_pareto.csv`.

| Gruppo | Indicatori | Rappresentante |
|---|---|---|
| uniformità | EI, Gini, VAN_min | EI |
| merito e stabilità | Fairness Index, σ, coalizioni instabili, eccesso | σ |
| inclusione | InclusioneLIHC | InclusioneLIHC |
| incentivo (netto) | forza incentivante, allineamento | forza incentivante |
| incentivo (lordo) | allineamento lordo | allineamento lordo |

Cinque gruppi sia a τ ≥ 0,7 sia a 0,5; a 0,3 i due assi dell'incentivo si fondono e i gruppi
diventano quattro. Il VAN del membro peggiore cade nel gruppo dell'uniformità (τ 0,81): dopo
la correzione della §5.2 lo massimizza l'Equal Split.

**Basta davvero?** Due prove.

- *Concordanza delle coppie*: per ogni indicatore, la quota di coppie di metodi che il suo
  rappresentante ordina nello stesso verso. Va da 0,95 (VAN_min) a 1,00: togliere gli altri
  indicatori perde al più il 5% degli ordinamenti.
- *Fronte di Pareto* con i 5 rappresentanti contro gli 11 indicatori: coincide in 8 comunità
  su 20. Dove non coincide, coi soli rappresentanti escono dal fronte da uno a tre metodi
  (spesso lo Shapley) che restavano non dominati solo grazie a differenze **dentro** un
  gruppo, per esempio fra eccesso e σ. Il sottoinsieme conserva le graduatorie; il fronte
  completo distingue in più solo sfumature interne a una stessa nozione.

> La scelta del rappresentante è algoritmica. Per la tesi può essere preferibile, a parità di
> concordanza, l'indicatore più leggibile del gruppo (l'eccesso in euro invece di σ): la
> concordanza dell'eccesso con σ è 0,98.

### 7.9 Il run finale: due run, due cartelle (13 ottobre 2026)

> ⚠ **Superato per il run fino a 18 membri.** I numeri di questa sezione, di §7.6.4 e di §7.8 sono del
> 13 ottobre, con i segnaposto LIHC e senza le PA. Il 20 ottobre `outputs/tables_main2/` è stato
> riscritto con i parametri LIHC definitivi (76 comunità: livello 0 più PA1-3, §7.10); nel livello 0 le
> quote di tutti i metodi sono identiche, tranne il Tri-level EP, e l'inclusione non è più valutabile.
> Le tabelle `outputs/tables_main2_griglia25/` restano quelle del 13 ottobre, con i segnaposto e senza
> PA: il 21 ottobre il run a 25 membri è stato rifatto con le PA e i parametri definitivi
> (`outputs/tables_main2_griglia25_PA/`, §7.10.1), e quelle tabelle sono superate.

> ⚠ **Gira ancora con i segnaposto LIHC** (§7.7): dopo aver compilato P50, y* e markup
> vanno rifatti entrambi i run. Cambiano l'inclusione e il Tri-level EP, non il resto.

`compute_indicator_agreement` tiene solo i metodi presenti in **tutte** le comunità. Sopra i
18 membri Shapley e Nucleolo non si calcolano (§14.1), quindi un run unico fino a 25 membri
li toglierebbe anche dalle comunità piccole, e con loro la stabilità. Per questo i run sono
due, sullo stesso codice, in cartelle diverse grazie alla variabile `MAIN2_CARTELLA` (come
`MAIN2_SCHEDE`, vuota = cartella di sempre):

| Run | Comunità | Metodi nell'analisi | Cartella | Durata |
|---|---|---|---|---|
| fino a 18 membri | 20 (5, 8, 10, 15, 18 × 4 fasce) | 11: tutti, AS escluso perché duplica lo Shapley | `outputs/tables_main2/` | 42 min |
| griglia fino a 25 | 28 (+ 20 e 25 membri) | 10: senza Shapley e Nucleolo, con l'AS al loro posto | `outputs/tables_main2_griglia25/` | 2 h 28 min |

```bash
MAIN2_SCHEDE="CER_0_5_0;...;CER_13_5_0" matlab -batch "MAIN2"                          # fino a 18
MAIN2_CARTELLA=griglia25 MAIN2_SCHEDE="CER_0_5_0;...;CER_18_7_0" matlab -batch "MAIN2" # griglia
```

L'elenco esatto delle schede è in testa ai log in `outputs/run_logs/`
(`main2_run_2026-10-13_F6_*.log`) e, scritto per esteso, in
[STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt) §2.3. Il primo run riproduce al bit i
risultati della §7.8.

**I risultati, nei due run.**

| | fino a 18 membri | griglia fino a 25 |
|---|---|---|
| coppie invertite lungo la penetrazione (soglia di default) | 26-33% | 22-35%, calando da 8 a 25 membri |
| coppie invertite lungo la taglia | 0,7-21% | 5-22% |
| primo sull'uniformità (Gini) | Equal Split 20/20 | Equal Split 28/28 |
| primo sul merito (Fairness Index) | VLC, con Shapley e Nucleolo a pari | VLC 14/28, a pari nelle altre |
| primo sulla stabilità | a pari in 20 comunità su 20 entro il 5% di v(N); il Nucleolo, minimo per costruzione, è sempre fra i primi | a pari in 19 comunità su 20, VLC nell'altra; n.d. sopra i 18 membri |
| gruppi di indicatori a τ ≥ 0,5 | 5 | 4 (i due assi dell'incentivo si fondono) |
| perdita in stabilità scegliendo l'uniformità | 0,72 (eccesso 20% di v(N)) | 0,72 (stesso valore: la stabilità esiste solo fino a 18) |
| perdita in uniformità scegliendo l'incentivo | 0,93 | 0,93 |

Sulla griglia la concordanza minima col rappresentante scende a 0,79 (allineamento lordo
dentro il gruppo dell'incentivo), e il fronte di Pareto coi soli 4 rappresentanti coincide
con quello completo in 1 comunità su 28: con quattro criteri invece di cinque il fronte
completo distingue più sfumature. Il sottoinsieme minimo **regge sulle graduatorie** (le
concordanze), meno sui fronti.

**Sensibilità alla soglia di rilevanza** (`sensibilita_soglia.m`, chiamata da §7c; file
`sensibilita_soglia_sweep.csv` e `sensibilita_soglia_vincitori.csv` in `sintesi/`). Si
ricalcola l'analisi dagli stessi `RESULTS` con la soglia spostata, a coppie escursione /
v(N): 0/0, 5/2,5, 10/5 (default), 20/10%.

| Soglia | inversioni lungo la penetrazione, fino a 18 | griglia fino a 25 |
|---|---:|---:|
| 0% (solo tolleranza numerica) | 41-51% | 33-53% |
| 5% | 32-39% | 25-41% |
| **10% (default)** | **26-33%** | **22-35%** |
| 20% | 19-24% | 17-25% |

Le inversioni calano con la soglia ma non spariscono: la dipendenza della graduatoria dalla
composizione **non è un effetto di differenze minime**. E il primo classificato **non cambia
mai**: su 220 celle (indicatore × comunità) fino a 18 membri e 308 sulla griglia, a nessuna
soglia un altro metodo prende il primo posto; cambia solo quante celle diventano "a pari" (da
20 a 186 fino a 18). Il vincitore per nozione è robusto alla soglia.

> Il run della griglia è partito prima che la sensibilità fosse collegata a §7c: i suoi due
> file sono stati prodotti con la stessa funzione dagli stessi `RESULTS` salvati, e la riga
> al 10% riproduce esattamente le inversioni del run.

### 7.10 La presenza di PA: la composizione per categoria

La griglia varia taglia e penetrazione, ma tutte le comunità sono di soli domestici: i risultati
non separano l'effetto di quei due fattori da quello del mix di categorie (§12). Il terzo asse,
la **composizione**, sta in [`CER_configuration_PA/`](CER_configuration_PA/README.md): per ogni
scheda della griglia quattro livelli, `PA0` (solo domestici), `PA1` (+ comune), `PA2` (+ scuola),
`PA3` (+ palazzetto di Lucca, §15). **A N, C e P invariati**: ogni PA è un prosumer col proprio
impianto, e per ogni PA che entra esce un prosumer domestico (l'ultimo per id). Cambia quindi solo
*chi* sono i prosumer, non quanti sono né quanti membri ci sono. PA2 ha 39 schede e PA3 37: mancano
quelle con meno prosumer che PA, cioè sempre le più a bassa penetrazione.

**Come gira.** `MAIN2.m` legge le schede di tutti i livelli (§3) e le analizza un livello alla
volta (§11.0); dopo di che `confronto_pa.m` (§7d di `MAIN2.m`) mette a fianco il livello 0 e ogni
livello con PA, scheda per scheda. Non ricalcola nulla: usa i punteggi orientati e le tolleranze di
pareggio già prodotti per ciascun livello, quindi la soglia di rilevanza (§7.6.3) è la stessa
delle inversioni lungo penetrazione e taglia e i numeri sono confrontabili con quelli.

**Che cosa si misura**, in `outputs/tables_main2[_<suffisso>]/confronto_PA/`:

| File | Cosa contiene |
|---|---|
| `pa_inversioni.csv` | una riga per cambio di segno: quale coppia di metodi, su quale indicatore, da PA0 a PAk, con i due divari |
| `pa_per_scheda.csv` | per ogni scheda e confronto (`PA0-PA1`, `PA0-PA2`, `PA0-PA3`, `asse PA` = scansione PA0>PA1>PA2>PA3): serie esaminate (indicatore × coppia di metodi), serie *valutabili* (non a pari in entrambi i livelli), coppie invertite e le due quote |
| `pa_vincitori.csv` | primo classificato per (indicatore, comunità, livello), metodi a pari, distacco, e se il vincitore *cambia* rispetto a PA0 |
| `pa_sommario.csv` | per indicatore e confronto: quota di comunità in cui cambia il vincitore e quota di coppie invertite, più la riga «PA0 contro PA>=1» |
| `pa_effetti.csv` | per comunità e metodo: v(N), rapporto con PA0, energia condivisa e non condivisa, quota di v(N) ai membri PA, rapporto con la loro quota di membri |
| `pa_perdite_tradeoff.csv` | perdite fra criteri (§7.8) a PA0 e a PAk, **sulle sole schede comuni ai due livelli**, con la differenza |
| `pa_cluster.csv` | gruppi di indicatori e rappresentanti (§7.8) di ciascun livello: dice se il sottoinsieme minimo cambia con la PA |

Una coppia di metodi si dice *invertita* se in un livello batte l'altra oltre la tolleranza e
nell'altro è battuta oltre la tolleranza (`extract_ranking_reversals`, su due configurazioni con
asse `[0 k]`). La quota di serie invertite è calcolata come in `inversioni_per_sweep.csv`
(serie invertite / serie esaminate, 605 per comunità con 11 metodi), così è confrontabile col
22-35% dell'asse penetrazione; la quota «sulle valutabili» toglie le coppie a pari. Il vincitore
*cambia* quando gli insiemi dei metodi a pari col primo nei due livelli non hanno elementi in
comune, perché con i pareggi un cambio di nome fra due pari non è un cambio di vincitore. Le
perdite si confrontano sulle sole schede comuni perché PA2 e PA3 hanno meno schede di PA0, e una
media su insiemi diversi mescolerebbe l'effetto della PA con quello delle schede che mancano.

**Cinque avvertenze, da leggere prima dei numeri.**

1. **Scaglione unico.** Il palazzetto (310,5 kWp) è sopra i 200 kW: per norma avrebbe 70/110 €/MWh
   contro gli 80/120 dei domestici, e `MAIN2.m` si fermava (§14.4.1). Lo scenario impone ora il
   primo scaglione a tutte le schede (`tip_potenza_rif_kW = 100`), quindi **la tariffa è identica
   nei quattro livelli** (127,31 €/MWh medi) e la differenza fra livelli è solo composizione. Il
   prezzo è una sovrastima di al più 0,010 €/kWh sull'energia condivisa di PA3; la colonna
   `ErroreMaxScaglione_EUR` di `pa_effetti.csv` la riporta come limite superiore (nelle prove su
   `CER_2_3_0`: 343 € su 4 345 €, il 7,9% di v(N), ipotizzando che *tutta* l'energia condivisa
   venga dal palazzetto).
2. **Le PA cambiano la scala, non solo la composizione.** Comune, scuola e palazzetto portano
   carichi e impianti di uno o due ordini di grandezza sopra quelli di una famiglia. Nelle prove
   del 18 ottobre v(N) di `CER_2_3_0` passa da 198 € (PA0) a 265 € (PA1) a 4 345 € (PA3), cioè
   ×22. Una differenza fra livelli può dipendere da questa scala oltre che dalla *forma* della
   comunità, e il confronto non la separa.
3. **Griglie incomplete.** PA2 e PA3 non hanno le schede con meno prosumer che PA: i confronti
   riguardano le schede presenti in entrambi i livelli, e le medie per livello non sono fatte
   sullo stesso insieme.
4. **Variance Least Core.** Con PA il Least Core può diventare sottile (due giocatori valgono
   l'85% del montepremi) e il QP del master esce con `exitflag` 2, «solver stalled, constraints
   satisfied». Dal 18 ottobre `variance_least_core_cer.m` accetta quell'esito solo se i vincoli
   sono rispettati ben dentro il rilassamento (≤ 1e-3 × `relax`) e l'ottimalità del primo ordine
   è praticamente raggiunta (≤ 1e-6): sulla scheda che lo ha rivelato valgono 4,5e-13 e 3,4e-8.
   Con `exitflag` 1 niente cambia, e i risultati del livello 0 sono identici bit a bit.
5. **Dati PA ancora da controllare** ([README della cartella](CER_configuration_PA/README.md)):
   FV del comune 5,2 volte il suo carico, FV del palazzetto 1,37 volte, e i 448 kW di potenza
   impegnata del palazzetto, che pesano sul Remuneration Model 1 (§12). Le schede PA non sono
   versionate: si rigenerano con `genera_varianti_PA.py`.

**Risultati** (run del 20 ottobre 2026, 76 comunità fino a 18 membri, 2 h 31 min, parametri LIHC
definitivi; tabelle in `outputs/tables_main2/`, pagina `outputs/report/recap_run_fino18_PA_2026-10-20.html`).
PA2 ha 19 schede e PA3 17, PA1 20: 56 confronti con il livello 0.

| Confronto | Comunità | Coppie invertite | Sulle valutabili | Il vincitore cambia |
|---|---:|---:|---:|---:|
| PA0 → PA1 | 20 | 9,6% | 15,8% | 12,5% |
| PA0 → PA2 | 19 | 11,9% | 21,7% | 8,4% |
| PA0 → PA3 | 17 | 11,2% | 20,9% | 11,8% |
| PA0 contro PA ≥ 1 | 56 | 10,9% | 19,2% | 10,9% |
| lungo l'asse PA0 → PA3 | 20 schede | 23,3% (da 15% a 31%) | – | – |

- **Confronto con gli altri fattori.** Lungo la penetrazione, a taglia fissa, si invertono il 18,5-27,1% delle
  coppie (media 23,2%); lungo la taglia, a penetrazione fissa, lo 0,5-15,0% (media 7,4%). La scansione
  lungo l'asse PA (23,3%) è paragonabile a quella di penetrazione; i confronti a coppie, con due sole
  configurazioni, hanno meno occasioni di invertirsi.
- **Il vincitore** non cambia mai per Gini, EI, eccesso di coalizione, coalizioni instabili e allineamento
  netto (vince l'Equal Split sull'uniformità); cambia nel 64% dei casi per l'allineamento lordo e nel 27%
  per σ. Gli indicatori con più coppie invertite sono l'allineamento lordo (31,8%), σ (18,5%) e il
  Fairness Index (14,6%).
- **Trade-off.** Scegliere il metodo migliore sulla forza incentivante costa in stabilità 0,26-0,29 a PA0 (secondo le
  schede comuni) e 0,23 a PA1, ma 0,74 a PA2 e 0,71 a PA3 (perdita ottimistica, sulle schede comuni): con PA2 e PA3 chi vince
  sull'incentivo è molto peggiore sulla stabilità.
- **Sottoinsieme minimo** (τ ≥ 0,5): 4 gruppi a PA0 e PA1, 3 a PA2, 4 a PA3.
- **Scala.** v(N) mediano rispetto a PA0: ×1,3 a PA1, ×5,7 a PA2, ×11,4 a PA3 (fino a ×107): una differenza
  fra livelli può dipendere dalla scala e non solo dalla composizione.
- **Inclusione.** Nessuna famiglia è vulnerabile (§7.7): l'indicatore è `NaN` e fuori dall'analisi, e il
  Tri-level EP perde la fetta di solidarietà. È il motivo per cui le inversioni lungo penetrazione e taglia
  sono più basse di quelle del 13 ottobre (26-33% lungo la penetrazione, 21% alla fascia 1 della taglia): quelle includevano
  un'inclusione e un Tri-level EP calcolati su segnaposto.

### 7.10.1 Il run fino a 25 membri con PA (21 ottobre 2026)

**Cosa è.** 108 comunità: 28 al livello 0, 28 a PA1, 27 a PA2, 25 a PA3 (le schede da 5, 8, 10, 15,
18, 20 e 25 membri, quattro fasce di penetrazione per taglia). Parametri LIHC definitivi, stesso
codice del run a 18 membri. Tabelle in `outputs/tables_main2_griglia25_PA/` (`PA1/`, `PA2/`, `PA3/`,
`confronto/`, `confronto_PA/`, `fase1/`, `sintesi/`).

```bash
MAIN2_MAX_UTENTI=25 MAIN2_CARTELLA=griglia25_PA matlab -batch "MAIN2"
MAIN2_MAX_UTENTI=25 MAIN2_CARTELLA=griglia25_PA MAIN2_RIPRENDI=1 matlab -batch "MAIN2"   # ripresa
```

**Durata e interruzione.** 9 h 9 min di analisi in due sessioni. La prima si è fermata alla comunità
87 (`PA3/CER_0_20_0`) con `Separation problem non risolto (exitflag 2)`: `intlinprog` ha superato
`MaxTime = 7200 s` nel Variance Least Core (lo stesso limite della §14.1). Il checkpoint
dell'ultima comunità completata è delle 04:25 e l'errore delle 11:21: la causa più probabile è la
sospensione del PC, che ha fatto scattare un limite a tempo reale su un calcolo che di norma dura
minuti. Ripreso da `MAIN2_RIPRENDI=1` (86 comunità già fatte), la comunità 87 si è chiusa in meno di
8 minuti e le altre 21 sono seguite senza errori. Non è stato verificato che il risultato sia
identico al byte a quello di un run unico senza interruzioni. **Prima di un run lungo conviene
disattivare la sospensione del PC.**

**Metodi.** Nell'analisi fra comunità sono 10: Shapley esatto e Nucleolo non si calcolano sopra i
18 membri (§14.1), quindi restano fuori anche dalle comunità piccole e l'Adaptive Sampling Shapley
prende il loro posto. Stabilità (eccesso massimo, coalizioni instabili) valutabile solo fino a 18
membri: 20 comunità su 28 al livello 0 e a PA1, 19 su 27 a PA2, 17 su 25 a PA3. Nelle comunità fino a 18 membri l'Adaptive Sampling si misura contro lo Shapley
esatto: scarto relativo medio 0,9-1,5% per taglia (massimo 7,2% a 15 membri), Spearman minimo 0,90
(8 membri). Oltre 18 membri non c'è un riferimento.

**Livello 0 (28 comunità senza PA).**
- *Vincitori.* Equal Split primo su EI e Gini in 28 comunità su 28 e sul VAN minimo in 24 (a pari in 4);
  Variance Least Core primo su Fairness Index e σ in circa metà delle celle, a pari nelle altre;
  `ForzaIncentivante` a pari in 27 su 28; solo l'allineamento lordo discrimina (13 celle su 28 con un
  vincitore) e cambia sequenza da una taglia all'altra.
- *Trade-off.* τ medio fra EI e forza incentivante da −0,48 a −0,79 in ogni taglia; EI e Fairness
  Index da −0,04 a −0,21. Scegliere l'uniformità costa 0,69 sul merito, 0,80 sulla forza incentivante
  e 0,72 sull'eccesso (78 €, il 20% di v(N)); scegliere l'incentivo costa 0,94 sull'uniformità.
- *Inversioni.* Lungo la penetrazione, a taglia fissa, si invertono il 28,9% delle coppie a 5 membri
  e il 15,6% a 25; lungo la taglia, a penetrazione fissa, il 16,2%, 10,5%, 5,1% e 8,7% nelle quattro
  fasce (la fascia ~100% sta sopra la ~75%).
- *Sottoinsieme minimo.* τ ≥ 0,5: tre gruppi, con rappresentanti EI, σ e allineamento netto; τ ≥ 0,7:
  quattro. Concordanza delle coppie col rappresentante ≥ 0,96 per tutti tranne l'allineamento
  lordo (0,80). L'ultima fusione del dendrogramma (uniformità contro il resto) ha τ equivalente −0,30.
- *Fronte di Pareto.* Weighted Solidarity non è mai sul fronte, in nessuno dei quattro insiemi di
  criteri; Cascading Tree 0-2 volte su 20-28.

**Effetto delle PA.**

| Confronto | Comunità | Coppie invertite | Sulle valutabili | Il vincitore cambia |
|---|---:|---:|---:|---:|
| PA0 → PA1 | 28 | 9,9% | 16,8% | 14,4% |
| PA0 → PA2 | 27 | 11,5% | 21,6% | 9,8% |
| PA0 → PA3 | 25 | 10,3% | 19,6% | 11,5% |
| PA0 contro PA ≥ 1 | 80 | 10,6% | 19,2% | 12,0% |

- *Il vincitore* non cambia mai per Gini, EI, eccesso, coalizioni instabili e allineamento netto;
  cambia nel 70% delle comunità per l'allineamento lordo, nel 29% per σ e nel 5% per Fairness Index
  e VAN minimo.
- *Scala.* v(N) rispetto a PA0 ha mediana ×1,3 (PA1), ×5,3 (PA2) e ×9,5 (PA3), fino a ×107: la
  differenza fra livelli può dipendere dalla scala e non solo dalla composizione.
- *Quota delle PA* (quota delle PA su v(N) divisa per la quota dei membri): 1,0 con l'Equal Split;
  tra 3 e 6,2 con tutti gli altri metodi a PA2 e PA3; 0,5 (PA1), 1,8 (PA2) e 1,4 (PA3) col
  Similarity-Utilization. Alcuni metodi non sono monotoni nel numero di PA: Pearson Key passa da 0,86
  a 5,5.
- *Gruppi di indicatori.* A τ ≥ 0,5: 3 gruppi a PA0 e PA2, 4 a PA1 e PA3. A τ ≥ 0,7: 4 gruppi a PA0 e
  PA3, 7 a PA1 e PA2: con una o due PA gli indicatori di stabilità e il VAN minimo si staccano dai
  loro gruppi.

**Comunità al 100% di prosumer.** Il valore da distribuire dipende dalle PA: a PA0 è 40-186 €
l'anno (7,5 € a membro, contro 47 € sotto il 100%), a PA1 91-294 € (13,9 € a membro), a PA2
2073-2958 € (217 € a membro) e a PA3 4304-5178 € (418 € a membro). L'argomento «c'è poco da spartire»
vale quindi solo a PA0 e PA1.

**Limiti.**
- L'inclusione LIHC è `NaN` in tutte le comunità (§7.7); il Tri-level EP ha quota di povertà
  energetica 0,00% del montepremi.
- A PA3 lo scaglione tariffario unico imposto (§7.10) introduce un errore medio del 7,9% di v(N)
  (circa 400-470 €), sopra la soglia di rilevanza del 5%: i risultati di PA3 non vanno presentati
  come robusti. A PA1 e PA2 l'errore è nullo.
- Quattro comunità per taglia, un solo campione di famiglie e nessun intervallo di confidenza.
- La composizione è solo la presenza di 0-3 PA: non ci sono altre categorie di membri.

### 7.11 Come costruiamo i casi da simulare: famiglie, PA, imprese

Le comunità simulate si costruiscono a strati, sempre a partire dalle schede di sole famiglie di
`CER_configuration/`:

| Strato | Cartella | Cosa cambia | Da quali schede |
|---|---|---|---|
| **D** (domestici) | `CER_configuration/` | taglia N e penetrazione (quota di famiglie prosumer) | tutte, 5-100 membri |
| **D + PA** | `CER_configuration_PA/PA1..PA3` | entrano comune, scuola, palazzetto (§7.10) | tutte |
| **D + ND** | `CER_configuration_IND/ND1..ND3` | entrano 1, 2 o 3 imprese (ND = non domestici privati: PMI, uffici) | N ≥ 15 |
| **D + ND + PA** | `CER_configuration_IND/ND{k}_PA{p}` | k imprese e p PA insieme | N ≥ 15 |

**Una sola regola per tutti gli strati.** N, consumatori e prosumer restano quelli della scheda di
partenza: ogni PA e ogni impresa è un prosumer col proprio impianto, e per ognuno che entra esce
l'ultimo prosumer domestico (per id). Cambia solo *chi* sono i prosumer. Esempio su `CER_9_9_0`
(18 membri, 9 famiglie consumatrici e 9 prosumer): `ND2_PA1` = 9 famiglie consumatrici, 6 famiglie
prosumer, antigelo, office_zummo e comune. Per le imprese valgono due vincoli in più: si entra solo
da **15 membri**, e imprese più PA restano **sotto il 50% dei membri** (al massimo ⌈N/2⌉ − 1).

**Perché proprio questi livelli: i dati sulle CER reali.** I numeri vengono dal paper di
Koltunov et al. [K26] e dal loro database pubblico [DB], letto con lo script e le avvertenze di
[`data/external/koltunov2026/`](data/external/koltunov2026/README.md):

- *Imprese 1-3.* Nelle CER del Nord con imprese prosumer (PMI o enti non profit) ce n'è 1 in 18
  casi, 2 in 10, 3 in 2, 4 o più in 8 [DB]: una o due nel 74% dei casi. Da qui ND1, ND2, ND3; le
  schede con 5 imprese generate il 25 ottobre sono state tolte.
- *PA 1-3.* Le CER del Nord con PA prosumer ne hanno 1-3 nel 67% dei casi [DB].
- *Taglia.* Mediana 17 membri al Nord (quartili 6 / 17 / 128, n = 181) [DB]: le schede da 15-25
  membri, dove entrano le imprese, sono attorno alla mediana.
- *Taglia degli impianti.* Potenza media di un impianto al Nord: residenziale 5,3 kW, PMI 107 kW,
  pubblico 122,4 kW [K26, Fig. 7]. I nostri valori: famiglie 3,4-5,9 kWp, imprese 33-129 kWp,
  comune 47, scuola 35, palazzetto 310,5.
- *FV per membro.* Nelle CER reali da 15-25 membri: quartili 1,95 / 5,84 / 22,3 kWp a membro
  [DB]. Le nostre schede di sole famiglie stanno a 1,0-1,9 (sotto il primo quartile), con una PA o
  un'impresa a 2,2-5,8 (attorno alla mediana), con 3 imprese a 10-14, con 3 PA a 16-23 (in alto).

**Le imprese** sono cinque, in quest'ordine: antigelo e office_zummo (consumi reali), small_industry
(RAMP), plastica (consumi reali), office (RAMP). Con al massimo 3 imprese entrano solo le prime tre.
Profili, kWp, tariffe e punti aperti in [`CER_configuration_IND/README.md`](CER_configuration_IND/README.md).

**Stato.** Le 331 schede (92 a 15-18 membri, 95 a 20-25, 144 a 50-100) sono generate e lette senza
errori da `load_cer_input`, `load_cer_data` e `align_members_to_users`. `elenco_schede_cer.m` le
elenca con `opts.conIND = true` (spento di default), ma **`MAIN2.m` non le legge ancora**: raggruppa
le comunità per numero di PA, e una scheda con imprese e senza PA finirebbe nel gruppo delle sole
famiglie. Nessun run è stato fatto.

**Due test lasciati per la fine.**
1. *Filtro sulla penetrazione.* Nel database l'**83%** delle CER del Nord ha prosumer ≤ 50% dei
   membri (mediana 28%, quartili 10% / 28% / 50%, n = 64; il 9° decile è 85%) [DB]. Le schede al 75%
   e al 100% di prosumer sono quindi poco rappresentative. Nel primo run restano tutte; se lì non
   emergono risultati notevoli si può limitare l'analisi alle schede con prosumer ≤ ~55% dei membri,
   dichiarando che in Italia, secondo [K26]/[DB], la grande maggioranza delle CER resta sotto metà
   (non tutte: circa una su sei la supera).
2. *Plastica.* Consuma 2 GWh/anno, circa 40 volte una CER di 18 famiglie, e con 1-3 imprese non
   entra mai. Un livello di sensibilità `ND3p` = antigelo + office_zummo + plastica dirà quanto pesa
   un'impresa grande sui risultati.

[K26] Koltunov, M., Beltrami, F., Grossi, L., Blasuttigh, N. (2026). *Impact of renewable energy
communities on the Italian day-ahead electricity market: A scenario analysis*. Energy Policy, 218,
115518. doi:10.1016/j.enpol.2026.115518 (preprint arXiv:2510.13517v3).
[DB] https://github.com/maksym-koltunov/energy-communities-Italy, `CER database 2025 PUBLIC.xlsm`,
dati a gennaio 2025, commit `7560715`.

## 8. Dimensionamento impianto PV (standalone)

`optimizer_PV.m` non fa parte della pipeline di analisi: è uno script indipendente di
**pre-dimensionamento** di un impianto fotovoltaico su copertura, pensato per trovare una
configurazione da riportare poi in PVsyst. Data la superficie disponibile, simula ora per
ora produzione DC/AC, ombreggiamento e bilancio economico (CAPEX, OPEX, ricavi, IRR via
`irr_bisection.m`, NPV), e sceglie la configurazione che massimizza il KPI scelto, IRR o
NPV. Le variabili decisionali dipendono dal montaggio: con `MOUNT = 0` (file inclinate su
copertura piana) sono l'inclinazione e la distanza fra le file; con `MOUNT = 1` (moduli
complanari alla falda) le impone il tetto, e resta da stabilire quanti moduli entrano. Il
numero di inverter **non** è una variabile decisionale: si ricava dalla potenza DC con un
rapporto DC/AC obiettivo. Lo scenario è residenziale o aziendale, con quattro modalità di
consumo (solo autoconsumo, sola cessione alla CER, autoconsumo più CER, sola rete). I
calcoli stanno nei moduli `pv_*.m`; il file meteo (TMY di PVGIS) è indicato con un percorso
assoluto scritto nello script. `archive/PROVA_PV.m` è la versione precedente, mantenuta
come riferimento storico.

## 9. Le schede dati (`CER_configuration/`)

Tutta la configurazione sta in **file di testo**, letti da `load_cer_input.m`. `MAIN2.m`
non contiene dati: legge le schede `CER_*.txt` della cartella — tutte, o quelle elencate in
`MAIN2_SCHEDE` (§3) — in ordine alfabetico, e gira una volta per ciascuna. Studiare una CER
in più significa aggiungere una scheda, non modificare il codice.

I file operativi sono due, divisi sulla domanda *questo dato cambia se cambio comunità?*

| File | Contenuto | Quanti |
|---|---|---|
| `CER_configuration/CER_C_P_E.txt` | chi abita la CER e cosa possiede | uno per comunità studiata; il nome sono i conteggi di `[RIEPILOGO]`: **C** consumatori, **P** prosumer, **E** produttori puri |
| `CER_configuration/scenario_economico.txt` | prezzi, costi e soglie di povertà: lo scenario in cui le CER vengono valutate | uno solo, per tutte |

La scheda dichiara lo scenario in `[FILE].scenario_economico`, e il loader ne innesta
`[MERCATO]`, `[INVESTIMENTO]` e `[POVERTA_ENERGETICA]` come se fossero scritte dentro:
da valle nulla cambia, `CFG.mercato.prezzo_gas_EUR_kWh` sta dov'era. Ritoccare un prezzo
resta così una modifica sola, e due CER non possono dire prezzi diversi senza che nessuno
se ne accorga. Una sezione sta però in un file solo: se compare in tutti e due, il loader
si ferma invece di scegliere in silenzio quale dei due comanda.

Lo scenario non ha commenti e sta in 28 righe, pensato per essere stampato come appendice
di tesi. Le schede della griglia portano in testa un blocco di commento della fase di
preparazione, che le dice ancora «BOZZA»: è un residuo, le schede sono complete.
[`CER_input.txt`](CER_input.txt) è la **guida alla compilazione**: le stesse sezioni con
gli stessi dati, ma spiegate riga per riga su una comunità mista di esempio. Non viene
letta dal codice, e infatti tiene dentro tutte e nove le sezioni senza dichiarare nessuno
scenario.

**Formato:** sezioni `[NOME]`, righe `chiave = valore`, tabelle a `|` (la prima riga è
l'intestazione), commenti con `#`.

**Le due forme di dato mancante, che non sono la stessa cosa:**

| | Significato | Effetto |
|---|---|---|
| `-` | **non applicabile** — il reddito di un ufficio non manca, non esiste | `NaN`, nessuna conseguenza |
| `?` | **non ancora noto** | il campo **non** viene passato al metodo, che applica il proprio default e **lo dichiara** come ipotesi attiva in `S.assumptions` |

È il meccanismo che tiene onesto il registro delle ipotesi: riempire un `?` con un dato
vero toglie una riga da quel registro, scriverci il valore che il modello userebbe
comunque la toglierebbe senza che nulla sia stato verificato. Sulle schede della griglia
reddito, spesa gas e quote di investimento sono compilati, quindi delle 11 ipotesi del
Tri-level EP ne restano attive 6 (3, 4, 5, 6, 7, 9): markup, P50 e y* sono ancora a `?`.
Compilandoli scenderebbero a 3 — le sole tre che sono correzioni dichiarate (ipotesi 6, 7, 9)
e non dati mancanti. Dal 19 ottobre sono compilati il **numero di percettori** (ipotesi 10) e
**n% e tetto** (ipotesi 11):

- `n_perc` viene dall'archetipo dichiarato del membro, con
  `CER_LoadProfiles/compila_n_perc.py` e `data/mapping_archetipo_nperc.csv` (55 archetipi,
  con il criterio riga per riga). Regola: contano uno ciascuno gli occupati e i pensionati;
  un nucleo senza occupati conta 1, perché il reddito per percettore non è definito con 0; la
  collaboratrice domestica (CHR19) non conta; CHR14 vale 3 (coppia di lavoratori + anziana
  con pensione) e CHR15 vale 4. Distribuzione sulle 40 schede e sulle varianti PA: 1 percettore
  in 4 172 celle, 2 in 1 778, 3 in 271, 4 in 47. Il conteggio dei lavoratori viene dalle
  etichette degli archetipi LPG, non da una statistica Istat: l'Istat non pubblica i percettori
  per tipologia (solo 2,14-2,2 per le coppie con figli).
- `quota_n_pct = 0,0132` e `tetto_quota_EP = 0,33` sono i valori di Campagna et al. 2024,
  tarati dagli autori su una CER di 16 membri. Con 5-18 membri i vulnerabili sono pochi e la
  fetta di solidarietà `min(tetto, n% × vulnerabili)` vale pochi punti: il livello pesa
  poco, ed è una scelta dichiarata.

**Reddito e spesa gas nelle schede operative.** Nelle schede di `CER_configuration/` le
colonne `reddito_EUR` ed `euro_gas` dei membri domestici non sono più a `?`. Le compila
[`CER_LoadProfiles/arricchisci_schede.py`](CER_LoadProfiles/arricchisci_schede.py):
- il reddito è la media Istat EU-SILC (netto, Nord-ovest, redditi 2024) della tipologia
  familiare dell'archetipo, perturbata per utente con una gaussiana troncata a ±15%;
- la spesa gas viene da una categoria d'uso estratta dalle quote ARERA dei punti di
  prelievo domestici lombardi 2023-24.

`euro_gas` è già in euro e ha sostituito `gas_kWh`: `MAIN.m`/`MAIN2.m` la passano
direttamente come spesa gas, e accettano ancora `gas_kWh` per le schede del vecchio
formato. Accanto a ogni valore la scheda conserva valore base, fattore di perturbazione e
fonte. Le perturbazioni e le soglie del gas sono **ASSUNZIONI** dell'autore, elencate con
le fonti e i limiti in [DATA_SOURCES.md](DATA_SOURCES.md). Con questi dati il Tri-level EP
non dichiara più attive le ipotesi 1 (reddito) e 2 (gas). Le schede sono escluse da git:
dopo una modifica a dati, parametri o prezzo del gas si rigenerano con
`python CER_LoadProfiles/arricchisci_schede.py`.

**Le sezioni.** Le tre marcate *scenario* stanno in `scenario_economico.txt`, le altre
sei nella scheda della comunità.

| Sezione | Contenuto |
|---|---|
| `[CER]` | nome, comune, zona di mercato, cabina primaria, anno, griglia oraria |
| `[RIEPILOGO]` | conteggi e potenza installata **dichiarati**. Non è una fonte di dati: il loader li ricalcola dalle tabelle e si ferma se non tornano |
| `[FILE]` | percorsi **relativi** alla scheda (profili di carico, prezzi zonali, cartella PV) e la chiave `scenario_economico`, che dichiara il file dello scenario |
| `[MERCATO]` | *scenario* — prezzo di vendita, markup retail, prezzo gas, parametri della tariffa TIP |
| `[INVESTIMENTO]` | *scenario* — tasso di sconto e vita utile (usati dal VAN, `MAIN2.m` §3v), O&M variabile (OPEX di ripiego quando l'impianto non dichiara il suo), contributo in conto capitale (fattore F e soglia, §7.4-§7.5). Inflazione OPEX, escalation e degrado sono dichiarati ma **non applicati**; i costi unitari e `om_fisso_EUR_anno` sono trasportati e non usati (§12) |
| `[POVERTA_ENERGETICA]` | *scenario* — soglie dell'indice LIHC e taratura della quota di solidarietà |
| `[GOVERNANCE]` | scelte deliberate dalla CER: pesi del Cascading Tree, M e seed dell'Adaptive Sampling (più α della Pearson-Sharing, letto solo da `MAIN.m`) |
| `[MEMBRI]` | **una riga per membro**: nome della colonna nel CSV, ruolo (C/P/E), categoria, archetipo, tariffa, potenza impegnata, componenti e percettori, reddito, spesa gas (`euro_gas`), quota di investimento, mutuo, impianto posseduto |
| `[IMPIANTI]` | **una riga per impianto**: proprietario, kWp, export PVsyst, tilt/azimut, CAPEX/OPEX |

**Le schede della griglia:** 40 comunità domestiche da 5 a 100 membri. I membri sono
`household_1 … household_N`, le prime N colonne della società da cento famiglie
(`N_utenti.xlsx`; `100_utenti.csv` a 100 membri): tutti in tariffa monoraria con 3 kW
impegnati, `n_perc`, reddito ed `euro_gas` compilati. Ogni prosumer ha un impianto
dimensionato sul nucleo — 3,4 kWp per 1-2 componenti, 4,2 per 3-4, 5,9 per 5 o più, con la
stessa curva PVsyst per fascia e una quota di investimento di 7 000 / 7 400 / 9 100 € — e
la governance è la stessa ovunque. Tabella completa e convenzioni in
[STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt) §3. I profili si rigenerano da
`CER_LoadProfiles/config/simulation_config.lombardia100.yaml` (§3). Le schede miste dei
primi studi (7 membri: uffici, piccola industria, negozio, famiglie) stanno in
`CER_configuration/Provvsiorio/`, che `MAIN2.m` non legge. La scheda
**descrive** i membri, non li crea, e `align_members_to_users.m` si ferma elencando tutti i
disallineamenti fra le due liste.

**Tariffa per utente.** La spesa annua di ciascun membro non si dichiara: si ottiene
incrociando la sua `tariffa` con il proprio profilo di carico. È la colonna `Effettivo`
di `Tcost` (§11) ed è la baseline `y_noLEM` degli indicatori di equità — prima si
assumeva la monoraria per tutti.

**Due valori ora derivati invece che scritti a mano.** Se `tip_potenza_rif_kW` è `?`, lo
scaglione della tariffa TIP si sceglie sulla potenza del **singolo impianto** di
`[IMPIANTI]` (§14.4.1); se `tip_fattore_riduzione` è `?`, non si applica riduzione.

## 10. Dipendenze e requisiti

**Python 3.12** (venv in root): `rampdemand` 0.5.0, `pyloadprofilegenerator`, `pandas`
3.0.x, `numpy` 2.4.x, `PyYAML`. RAMP 0.5.0 non è ancora compatibile nativamente con
numpy 2 / pandas 3: `ramp_runner.py` applica due monkey-patch a runtime (rimovibili
quando RAMP verrà aggiornato). Vedi `requirements.txt` (freeze completo) e
`CER_LoadProfiles/requirements.txt` (dipendenze dirette).

**MATLAB:** base + **Optimization Toolbox** (`linprog`, `quadprog`, `intlinprog`,
richiesti da Nucleolo e Variance Least Core). `irr_bisection.m` evita la dipendenza dalla
Financial Toolbox per il calcolo dell'IRR, usato sia da `optimizer_PV.m` sia da
`compute_financial_metrics.m` (§3v).

**Un controllo aggiunto, e cosa ha trovato.** `[MEMBRI].impianto` e
`[IMPIANTI].proprietario` descrivono lo stesso fatto — chi possiede cosa — da capi
opposti, ma il modello usa **solo** la seconda (`costruisci_impianti_struct` →
`load_cer_data`). Finché nessuno le confrontava, la prima poteva dire un'altra cosa senza
conseguenze visibili: `load_cer_input` verificava solo che puntasse a un `id` esistente.
Il confronto è stato aggiunto, ed era violato in `CER_0_7_0` e `CER_1_6_0`, due schede miste
dei primi studi — PV06
risultava di `office_1_kWh` in `[IMPIANTI]` ma dichiarato da `retail_1_kWh` in
`[MEMBRI]`, che ne aveva pure pagato la quota. È rimasto invisibile finché
`quota_inv_EUR` non è stata letta da nessuno; la §3v è la prima cosa che la legge, e ne
ricavava un VAN negativo per un membro che non possedeva nulla. Le due schede sono state
corrette assegnando PV06 a `retail_1_kWh`, il che **cambia i loro risultati energetici**
(l'energia condivisa scende del ~60%, perché PV06 finisce dietro il contatore di un
commerciale che se ne autoconsuma buona parte invece che dietro quello di un ufficio già
coperto da PV04). Il controllo è in una direzione sola: `[MEMBRI]` ha una cella per
membro, quindi chi possiede due impianti non può dichiararli entrambi — «il membro
dichiara un impianto che non è suo» è un errore, «un impianto non è dichiarato da
nessuno» non lo è.

## 11. Output prodotti

**Stadio Python** → `CER_LoadProfiles/outputs/csv_lombardia100/`: `100_utenti.csv`, le cento
famiglie in kWh/h su 8760 righe, da cui si estraggono gli `N_utenti.xlsx` che le schede
dichiarano in `[FILE].profili_carico`. Le altre configurazioni scrivono in `outputs/csv/`
(`profili_tutti.csv`, `profili_aziende.csv`, `profili_famiglie.csv`,
`profilo_CER_aggregato.csv`). CSV orari, separatore virgola, timestamp ISO8601.

**Stadio MATLAB** (`MAIN2.m`). Per ogni comunità, a schermo e in `RESULTS(i)`:
- il riepilogo della scheda con l'elenco dei campi ancora a `?` (§9), stampato per primo da
  `load_cer_input`;
- `Treport` — energia condivisa, non condivisa e immessa, ricavi da incentivo e da vendita,
  per mese e per anno;
- il report testuale di ciascuna ripartizione, con la verifica che sommi a `v(N)`;
- `Trd` — fino a 18 membri, lo scarto dell'Adaptive Sampling dallo Shapley esatto (§3q,
  eq. 16-17 di Cremers et al.);
- `Tcmp` — la quota di ogni membro con ciascun metodo;
- `Tfair` — gli indicatori per metodo (13 colonne, §7), più le ipotesi attive, l'energia
  contendibile e la classifica di stabilità con la coalizione peggiore di ciascun metodo;
- la soglia regolatoria (`RESULTS(i).soglia`, §7.4);
- `Tfin` e `Tvan` — VAN, TIR e tempo di ritorno per membro con il metodo di riferimento
  (Shapley, o Adaptive Sampling sopra i 18 membri), e il VAN con tutti i metodi (§12);
- `Tcost` — costo annuo da rete per utente nelle 3 modalità tariffarie PUN (monoraria,
  bioraria, oraria variabile), più la tariffa che ciascun membro ha davvero e la colonna
  `Effettivo` con la spesa che ne risulta.

Dopo il ciclo: le tabelle su file (§11.0), le figure della fase 1 e, a richiesta, le altre
(§11.1), il riepilogo dei tempi (§11.2).

### 11.0 Le tabelle su file: `outputs/tables_main2/`

Le scrive `save_tables` con l'interruttore `CSV` della §0b — **separato** da quello delle
figure, perché le figure sono un servizio e queste tabelle sono un risultato. Con
`MAIN2_CARTELLA=<suffisso>` la cartella diventa `outputs/tables_main2_<suffisso>/`: i due
run finali stanno in `tables_main2/` (fino a 18 membri, 20 ottobre) e `tables_main2_griglia25_PA/`
(fino a 25 membri con PA, 21 ottobre, §7.10.1); `tables_main2_griglia25/` (13 ottobre, §7.9) è superata.

**`confronto/`** (§7b: accordo fra indicatori e inversioni, §7.6):

| File | Cosa contiene |
|---|---|
| `accordo_indicatori.csv` | il **τ-b di Kendall** fra ogni coppia di indicatori, una configurazione alla volta, con il conteggio di coppie concordi e discordi e se ciascuno dei due discrimini |
| `inversioni_di_graduatoria.csv` | una riga per **cambio di segno**: quale sweep (`Sweep`, `Fisso`), quale coppia di metodi, quale indicatore, fra quali due configurazioni, con i due divari. L'asse sta in `AsseDa`/`AsseA`: penetrazione in % se `Sweep = penetrazione`, membri se `Sweep = taglia` (§7.6) |
| `inversioni_sommario.csv` | una riga per serie: quante inversioni, e se la graduatoria sia **invertita fra i due estremi** dell'asse — che non è deducibile dal conteggio, perché un numero pari di inversioni riporta all'ordine di partenza |
| `inversioni_per_sweep.csv` | una riga per sottoinsieme della griglia: quante coppie si invertono e quante agli estremi, per ogni taglia (sweep di penetrazione) e ogni fascia (sweep di taglia) |
| `griglia_vincitori.csv` | una riga per (indicatore, cella): il metodo primo, i metodi a pari merito e il distacco dal secondo — i dati della heatmap congiunta |
| `griglia_interazione.csv` | una riga per indicatore: `QuotaModale` e numero di sequenze distinte di vincitori lungo la penetrazione (§7.6) |
| `orientamenti.csv` | **da che parte sta il meglio**, indicatore per indicatore, con il motivo e se il verso sia normativo. È il primo file da aprire quando un risultato non torna |

**`fase1/`** (§7a: Shapley esatto contro Adaptive Sampling, §6):

| File | Cosa contiene |
|---|---|
| `regime_le18_Shapley_vs_AS_per_CER.csv` | fino a 18 membri: scarto relativo medio e massimo, somma degli scarti assoluti in % di `v(N)`, scarto massimo in euro, ρ di Spearman |
| `regime_le18_Shapley_vs_AS_per_membro.csv` | le quote Shapley e AS di ogni membro |
| `regime_le18_Shapley_vs_AS_per_taglia.csv` | le stesse misure, mediate per taglia |
| `regime_gt18_AS_per_CER.csv`, `regime_gt18_AS_per_membro.csv` | sopra i 18 membri: fattore di normalizzazione, quote minima e massima, quote AS di ogni membro |

**`sintesi/`** (§7c):

| File | Cosa contiene |
|---|---|
| `tau_per_fascia.csv`, `tau_per_taglia.csv`, `tau_per_cella.csv` | τ-b medio, minimo e massimo per coppia di indicatori, e se il segno cambia fra i gruppi (§7.6.5) |
| `pareto_per_comunita.csv`, `pareto_conteggi.csv` | metodi non dominati per comunità e insieme di criteri; quante volte ciascuno è sul fronte (§7.6.5) |
| `quote_prosumer.csv`, `quote_prosumer_fascia.csv` | quota di `v(N)` ai prosumer e rapporto con la loro quota di membri (§7.6.5) |
| `rimpianto_per_comunita.csv`, `rimpianto_medio.csv`, `perdite_tradeoff.csv`, `perdite_tradeoff_fascia.csv`, `perdite_dettaglio.csv` | rimpianto di ogni metodo e perdite fra criteri (§7.8) |
| `cluster_fusioni.csv`, `cluster_gruppi.csv`, `cluster_sufficienza.csv`, `cluster_pareto.csv` | sottoinsieme minimo di indicatori (§7.8) |
| `sensibilita_soglia_sweep.csv`, `sensibilita_soglia_vincitori.csv` | inversioni e vincitori a quattro soglie di rilevanza (§7.9) |

**Un livello PA alla volta.** Dal 18 ottobre `MAIN2.m` esegue le analisi fra comunità (`confronto/`,
`fase1/`, `sintesi/`) separatamente per ogni livello di composizione (§7.10): il livello 0 (solo
domestici) scrive nelle cartelle di sempre, con tabelle identiche bit a bit a quelle del 13
ottobre; i livelli con PA scrivono in `tables_main2[_<suffisso>]/PA1/`, `PA2/`, `PA3/`
(`confronto/` e `sintesi/`, senza `fase1/`, che è una verifica dei metodi e non dipende dalla
composizione). La ragione è tecnica: la stessa scheda esiste in ogni livello con lo stesso nome
base, e le funzioni di §7b-§7c identificano le comunità da quello.

Questi CSV **si versionano**, a differenza delle figure: sono ASCII, pesano poche decine di
KB e si leggono in diff. `save_tables` arrotonda **in scrittura e solo lì** — due decimali
fissi sugli euro, sei **cifre significative** sul resto, con uno zero vero sotto `1e-12` —
perché la precisione di default di `writetable` produrrebbe churn a `1e-16` a ogni
riesecuzione, indistinguibile in un diff da un cambiamento vero.

Le cifre significative non sono un vezzo: coi decimali fissi un divario di `3e-8`
diventerebbe `0.000000`, e chi legge vedrebbe *"un'inversione con divario zero"* e
concluderebbe che il codice conta il rumore, mentre il divario c'è ed è solo piccolo.

**Riprendere senza rilanciare.** In `outputs/workspace/` ci sono i workspace dei due run
(`run_2026-10-13_*.mat`, non versionati), le stesse grandezze esportate in CSV leggibili
senza MATLAB (`export_<run>/`: comunità, indicatori, punteggi orientati, quote, virtuosità),
l'analisi testuale (`analisi_<run>.txt`) e gli strumenti che le producono. Istruzioni, e la
procedura del test di regressione, in
[outputs/workspace/LEGGIMI.md](outputs/workspace/LEGGIMI.md). La pagina dei risultati finali
è [outputs/report/regole_ripartizione_cer.html](outputs/report/regole_ripartizione_cer.html);
i log completi dei run stanno in `outputs/run_logs/` (non versionati).

### 11.1 Le figure: quali si producono, e dove finiscono

`MAIN2.m` §0b contiene la struct `FIG`, l'unico punto da cui si decide **cosa disegnare**.
Non è un dato della comunità ma una preferenza di presentazione, e sta prima del ciclo
perché serve anche alla §7, che gira dopo. Di default è tutto spento tranne
`.confrontoCER`, ed `.esporta` è `false`: i run finali non hanno prodotto figure per
comunità.

| Campo | Cosa accende |
|---|---|
| `.profili` | profili di consumo, 4 giorni tipo |
| `.energia` | mensili, PV vs domanda + **mappa oraria**, **curve di durata**, **TIP_h vs prezzo zonale** |
| `.dettaglio` | un grafico a rete per metodo, più la barra dello Shapley |
| `.metodi` | confronto a barre + **mappa quote metodi × membri** |
| `.equita` | indici di equità + **scostamento dal merito** + **trade-off uniformità × stabilità** |
| `.finanza` | VAN, tempo di ritorno, composizione del flusso di cassa |
| `.confrontoCER` | dopo il ciclo: **confronto fra CER**, superficie del Gini, griglia dei vincitori (§7.6) |
| `.esporta`, `.chiudi`, `.cartella` | salvataggio su file, chiusura finestre, cartella di destinazione (`outputs/figures_main2`) |

Le figure della **fase 1** (quote Shapley contro AS, scarto per taglia, confronto per
comunità, sole quote AS sopra i 18 membri) si producono e si salvano **sempre**, in
`<cartella delle figure>/fase1/`: non dipendono da `FIG`.

Con `.esporta` ogni figura finisce in `outputs/figures_main2/<scheda>/` (più `confronto/`
per la §7) in **PDF vettoriale** — per la tesi, il testo resta testo — e in **PNG**. Il
nome del file viene dalla proprietà `Name` della figura, quindi la cartella si legge senza
aprire le immagini. Le cartelle delle figure non sono versionate: si rigenerano.

**Le figure meno ovvie**, e a quale risultato servono:

| Figura | Risultato che rende visibile |
|---|---|
| **Mappa oraria 24×365** | dove cadono nell'anno le ore **sature** — quelle in cui l'immissione copre l'intero carico e nessuna chiave può cambiare nulla. È la premessa per leggere la §7: sulla griglia la frazione contendibile va dall'11% al 42% (§7.2) |
| **Curve di durata** | quanta immissione non trova carico residuo e resta **soltanto venduta**, senza incentivo: sulla griglia dal 50% (`CER_4_1_0`) al 98,8% (`CER_0_8_0`) dell'energia immessa |
| **TIP_h vs prezzo zonale** | la spezzata dell'eq. 3.1 con sopra le 8760 ore, e il confronto fra TIP **media** e TIP **effettivamente incassata**: se la seconda è maggiore, la CER condivide nelle ore in cui l'incentivo vale di più |
| **Mappa quote metodi × membri** | i **gruppi di metodi che si comportano uguale**, che il grafico a barre non mostra: con dodici metodi ogni barra è larga `0.8/12 ≈ 0.07` tick |
| **Scostamento dal merito** | apre lo scalare `FI` per membro: non *quanto* un metodo si discosta dal contributo marginale, ma **chi** premia e chi penalizza |
| **Trade-off uniformità × stabilità** | la sintesi della §7.0 — le tre domande danno risposte opposte — resa geometrica, con la **frontiera di Pareto** che separa le scelte difendibili da quelle dominate |
| **Confronto fra CER** | `plot_cer_comparison_main2`: bilancio energetico, montepremi contro vendita, quota ai prosumer per metodo, escursione di EI ed eccesso fra i metodi — come ciascun metodo reagisce alla composizione, e quanto la scelta del metodo conta davvero in ciascuna comunità |
| **Superficie 3D del Gini** | il Gini come **funzione di due variabili** — quale modello, quale comunità: si vede se la pendenza lungo un asse cambia muovendosi lungo l'altro, cioè l'**interazione** fra i due effetti, che né la tabella né un grafico per metodo mostrano |
| **Griglia dei vincitori** | `plot_ranking_grid`: il primo metodo in ogni cella taglia × penetrazione, un pannello per indicatore (§7.6.2) |

> ⚠ **La superficie 3D vuole più di due comunità per dire tutto.** Con due schede ha due
> soli nodi in profondità: è un nastro piegato lungo i modelli, corretto ma non ancora un
> rilievo. Il senso pieno arriva dalla terza scheda in poi, e non richiede di toccare il
> codice — basta aggiungere un file in `CER_configuration/`.
>
> Due scelte da conoscere prima di leggerla: **entrambi gli assi orizzontali sono
> categoriali** (fra Shapley e Nucleolo non esiste un metodo intermedio, fra due comunità
> non esiste una comunità intermedia), quindi i dati sono i **nodi** — marcati apposta — e
> la superficie fra un nodo e l'altro è un raccordo grafico, non un valore calcolato.
> L'**asse Z sta sul dominio pieno `[0,1]`** dell'indice, non sui valori osservati: il
> rilievo occupa quindi poca altezza, ed è voluto — ritagliare l'asse sui dati farebbe
> sembrare enormi differenze che sulla scala del Gini sono modeste. Il sottotitolo riporta
> il range osservato, e il **colore** (che è una graduatoria, non una misura) si normalizza
> invece su quello.

### 11.2 Tempo di esecuzione

`MAIN2.m` §8 chiude con il riepilogo dei tempi, una riga per comunità più i totali
(estratto dal run fino a 18 membri del 13 ottobre):

```
=== Tempo di esecuzione ===
  CER_0_10_0              analisi     16.0 s   figure      0.0 s
  ...
  CER_9_9_0               analisi 7 min 14 s   figure      0.0 s
  -- somma analisi        41 min 59 s
  -- somma figure         0.0 s
  -- confronto CER        25.6 s
  TOTALE                  42 min 24 s
```

Per taglia, nei due run: 5 membri 3-8 s; 8 membri 7,5-44 s; 10 membri 15 s-1,5 min; 15
membri 1-6 min; 18 membri 2,7-10 min; 20 membri 2,5-14 min; 25 membri 7,5-31 min. A parità
di taglia costano di più le comunità a bassa penetrazione (dagli 8 membri in su), e dai 15
membri in su il tempo è dominato dal Variance Least Core (§14.1). La griglia fino a 25
membri dura 2 h 28 min; il run del 21 ottobre, con le PA e 108 comunità, 9 h 9 min (il solo
Variance Least Core di `CER_12_13_0`, 25 membri, ha richiesto 21 min 45 s).

**Analisi e figure sono separate perché si governano in modo diverso.** Il calcolo è
quello che serve; l'export delle figure è un servizio, e si spegne con `FIG.esporta` o si
alleggerisce con `FIG.dettaglio` (§11.1). Sapere quale delle due voci pesa è l'unico modo
per decidere cosa togliere quando l'esecuzione è lenta (con `MAIN.m`, sulle sette schede
dei primi studi, le figure costavano più dell'analisi: 3 min contro 2 min 40 s).

Il conto chiude senza residui: somma delle comunità + confronto = totale. La riga
"confronto CER" è la §7, che non appartiene a nessuna comunità. I tempi per comunità
restano anche in `RESULTS`, nei campi `tempo_analisi_s` e `tempo_figure_s`.

Il cronometro usa `tic` con identificatore esplicito (`T_TOT`, `T_CER`), non il `tic/toc`
globale: quello è unico per tutto MATLAB, e qualunque funzione chiamata più a valle che lo
usi per conto proprio lo azzererebbe senza che nessuno se ne accorga.

## 12. Limitazioni note / TODO

- **DA FARE (Alberto): compilare P50, y* e markup in `scenario_economico.txt`** prima del
  run finale. Decidono chi è vulnerabile LIHC, quindi l'indicatore di inclusione e il
  Tri-level EP. Chiavi, segnaposto attuali e fonti suggerite in §7.7.
- **I dati mancanti sono ora elencati dal codice, non da questa lista.** `load_cer_input`
  stampa a ogni esecuzione i campi della scheda ancora a `?`, e ciascun metodo stampa le
  proprie ipotesi attive. Le voci qui sotto restano perché spiegano *perché* un dato è
  difficile, non per tenerne il conto: quello si legge dall'output.
- **Reddito e spesa gas sono stime statistiche, non dati dei membri.** Reddito medio
  Istat del Nord-ovest (non della sola Lombardia, e netto) e quote gas ARERA uguali per
  ogni tipologia, entrambi perturbati in modo sintetico. Sotto i 100 membri l'archetipo
  dichiarato nelle schede non coincide con il profilo simulato. L'elenco completo è in
  [DATA_SOURCES.md](DATA_SOURCES.md) §Limiti noti.
- **La griglia di `CER_configuration/` varia due assi, ma non la composizione per categoria.**
  Le 40 schede coprono taglie da 5 a 100 membri e quattro livelli di penetrazione;
  l'analisi usa le 28 fino a 25 membri, un fattore alla volta più la vista congiunta
  (§7.6, §7.9). Tutti i membri sono domestici: i risultati dei run del 13 ottobre non
  separano l'effetto della taglia o della penetrazione da quello del mix di categorie, e
  sulla griglia fattore F e soglia GSE non hanno effetto (§7.4, §7.5). **Il terzo asse
  esiste dal 18 ottobre** (§7.10, `CER_configuration_PA/`): `MAIN2.m` lo legge e i risultati
  con i dati LIHC definitivi sono quelli del 20 e del 21 ottobre (§7.10, §7.10.1). Copre solo
  la presenza di 0-3 PA. **Le imprese** (1-3 per comunità, §7.11, `CER_configuration_IND/`) sono
  generate ma non ancora lette da `MAIN2.m`. Le schede da 50, 75 e 100 membri non sono
  analizzate: il Variance Least Core non converge in tempi pratici oltre ~25 membri
  (§14.1). Aggiungere una comunità significa aggiungere un file in `CER_configuration/`
  (`cer_config_writer.py` ne redige la bozza) e il corrispondente set di profili dallo
  stadio Python.
- **Filtro opzionale sulla penetrazione** (da decidere dopo il primo run con le imprese, §7.11):
  l'83% delle CER reali del Nord ha prosumer ≤ 50% dei membri [K26]/[DB]. Se le schede al 75% e
  al 100% non danno risultati degni di nota, l'analisi si può limitare a prosumer ≤ ~55%.
- **Test finale con plastica** (§7.11): l'impresa da 2 GWh/anno non entra nei livelli ND1-ND3.
- **Un clone pulito non riproduce la griglia.** Le 40 schede, lo scenario e tutti i
  risultati (tabelle dei due run, CSV esportati dai workspace, pagina dei risultati) sono
  versionati; non lo sono i profili di carico (`N_utenti.xlsx`, `100_utenti.csv`) e gli
  export PVsyst della griglia (`PROVA_CER_*`), che le schede dichiarano.
- **Il fattore F è implementato** (§7.5), ma resta *dormiente* finché
  `[INVESTIMENTO].contributo_conto_capitale_pct` è a `?`: senza contributo in conto
  capitale `F = 0` e non c'è nulla da decurtare. Il campo va compilato quando il piano
  finanziario della CER è deciso — è lo stesso che sceglie la soglia del §7.4. Sulla
  griglia, tutta domestica, F non avrebbe comunque effetto: tutti i membri sono esenti.
- **Con `F > 0` il Variance Least Core perde la scalabilità.** Il suo Separation Problem
  non è più un MILP (il termine di esenzione è un rapporto fra combinazioni lineari delle
  binarie) e il metodo ripiega sull'enumerazione: esatto, ma con lo stesso limite di
  Shapley e Nucleolo (§14.1). Rimuoverlo richiede di linearizzare il rapporto con
  variabili ausiliarie — modellazione, non implementazione.
- **La quota esente dell'energia condivisa è attribuita ai punti di prelievo
  *pro-rata sul carico residuo* orario.** Il decreto prescrive «un'ulteriore ripartizione»
  senza fissarne la chiave; il pro-rata è quella neutra, ma è un'ipotesi e va detta se il
  risultato finisce in tesi. La regola di priorità del §2.2.2.1.2 (energia degli enti
  allocata prima agli impianti col contributo) qui è **vacua**, perché il conto capitale è
  dichiarato per la comunità e non per singolo impianto: o tutti gli impianti sono
  decurtati o nessuno.
- **Il controllo di soglia (§7.4) ragiona su un solo insieme di impianti.** La norma ne
  prevede due (sola tariffa premio / cumulo con conto capitale) e somma le eccedenze;
  qui l'insieme è uno perché il modello applica **una sola TIP** a tutta l'energia
  condivisa e la scheda dichiara il conto capitale per la *comunità*, non per singolo
  impianto. Con quel dato per impianto la generalizzazione è una chiamata in più a
  `premium_excess_threshold` e la somma delle due `.importoEccedente`.
- Lo scaglione della tariffa TIP si sceglie sulla potenza del **singolo impianto**, come
  vuole il par. 2.2.2.1.2. Resta non implementato il caso in cui gli impianti cadano in
  scaglioni **diversi**: lì servirebbero una tariffa per impianto e la ripartizione
  dell'energia condivisa per UP. Il modello non lo approssima, si ferma (§14.4.1).
- Le potenze usate da Remuneration Model 1 restano **da confermare**: potenza di prelievo
  in `[MEMBRI].P_prel_kW` (sulla griglia 3 kW per tutti), potenza di generazione in
  `[IMPIANTI].kWp`. Hanno impatto di primo ordine sul risultato — sulla comunità mista dei
  primi studi, con una potenza sola al posto di due, i pesi α/β passavano da 0.81/0.19 a
  0.63/0.37 e il prosumer riceveva quasi il doppio
  ([GUIDA §10.6](GUIDA_modelli_distribuzione.md)).
- **I costi di investimento alimentano ora un calcolo — ma solo uno.** `MAIN2.m` §3v
  attualizza il flusso di cassa per membro e produce VAN, TIR e tempo di ritorno
  (`compute_financial_metrics.m`), leggendo `[MEMBRI].quota_inv_EUR` come esborso
  all'anno 0 e `[INVESTIMENTO].tasso_sconto` / `vita_utile_anni` come parametri. Restano
  fuori: `capex_EUR` e `opex_EUR_anno` di `[IMPIANTI]` (usati solo se compilati — oggi
  sono a `?`, e l'OPEX si ripiega su `om_variabile_EUR_MWp_anno × kWp`), tutti i costi
  unitari di `[INVESTIMENTO]`, e `om_fisso_EUR_anno`, che viene da `optimizer_PV.m` ed è
  di taglia industriale: cinquemila euro l'anno su una famiglia da 12 kWp non sono un
  costo, sono un errore di scala. **L'ipotesi 3 di `fairness_index_bm` resta attiva**
  ("costi di investimento per membro ASSENTI: `D_i` calcolato sui benefici LORDI"): la
  §3v non la rimuove, perché gli indicatori di equità continuano deliberatamente a
  ragionare sui benefici lordi — sono due domande diverse, chi prende quanto e a chi
  conviene investire.
- **Il perimetro del flusso di cassa è l'investimento, non la CER.** È una scelta, e
  cambia il verdetto: sui prosumer di `CER_2_5_0` (scheda mista dei primi studi) la quota di incentivo vale il 2-3% del
  flusso annuo, contro il 60-90% della vendita dell'eccedenza e il resto di risparmio da
  autoconsumo. Valutare i 42.000 € dell'industria sul solo incentivo darebbe un tempo di
  ritorno oltre la vita utile per un impianto che rientra in 3,7 anni. Il **risparmio da
  autoconsumo** non esisteva in nessuna variabile prima della §3v (`costUser` è calcolato
  sul carico *lordo*, perché serve da baseline agli indicatori): si ottiene da
  `loadUsers - loadForShare` valutato al profilo prezzi della tariffa del membro.
- **I flussi sono costanti su vent'anni.** `escalation_energia`, `inflazione_opex` e
  `degrado_pv_pct_anno` sono dichiarati nello scenario ma **non applicati**, e compaiono
  fra le ipotesi attive stampate sotto la tabella. Sono tre parametri non tarati che,
  composti su vent'anni, muovono il VAN più di quanto lo muova la scelta del metodo di
  ripartizione — cioè proprio la grandezza che il progetto vuole confrontare. Si
  accendono da `opts` senza toccare la funzione. Nota: l'escalation **non andrebbe
  comunque** applicata alla quota di incentivo, perché la TIP è regolata e si muove al
  contrario del prezzo dell'energia (`max(0; 180 − Pz)`).
- **Vent'anni sono insieme il dato di scheda e il periodo di incentivazione** (Regole
  Operative GSE §2.2.1, p. 35). Le due cose coincidono per fortuna, non per costruzione:
  se una scheda dichiarasse una vita utile diversa dal periodo incentivato, il flusso
  costante smetterebbe di essere una semplificazione innocua, perché dopo il ventesimo
  anno la quota di incentivo sparisce. (`optimizer_PV.m` usa 30 anni scritti a mano: è un
  altro ramo del progetto, e la scheda vince.)
- **Weighted Solidarity — la componente di solidarietà è un proxy debole.** Il modello
  di Marrasso classifica gli utenti "a rischio povertà energetica" dal costo unitario
  in bolletta `Cu`; nel paper quel dato viene da bollette reali e varia di ~4× tra i
  membri, mentre qui è stimato da un'unica modalità tariffaria (`opts.tariffMode`, di
  default la monoraria) e varia pochissimo fra i membri (del **2,9%** sulla comunità mista
  dei primi studi). La logica è implementata fedelmente, ma la classificazione risultante
  riflette quando si consuma, **non** una reale vulnerabilità economica — e la
  ripartizione è in larga parte guidata da quella classificazione
  ([GUIDA §12.7](GUIDA_modelli_distribuzione.md)). Servono dati di bolletta o ISEE reali
  per usare seriamente questo metodo.
- **Chiavi dinamiche (Pearson Key, Pearson-Sharing Rate) — tre avvertenze.** (a) Sono
  chiavi guidate dal **consumo**: il proprietario dell'impianto riceve `0`, perché il suo
  carico residuo è nullo proprio nelle ore di eccedenza (vedi §6). È il comportamento
  atteso dato il modello di autoconsumo del progetto, non un bug, ed è lo stesso del
  Proportional to Consumption. (b) L'eq. 5 del paper (sharing rate) contiene un **refuso**:
  le due espressioni sono associate alle condizioni invertite rispetto alla Fig. 3, al
  testo e all'esempio numerico dell'articolo. L'implementazione segue questi ultimi
  (`SR = ratio` sotto 1, esponenziale decrescente sopra) e ne **riproduce esattamente**
  i risultati (Fig. 7-9); la lettura letterale resta disponibile con
  `opts.sharingRateMode = "eq5"`
  ([GUIDA §14.2 e §14.7](GUIDA_modelli_distribuzione.md)). (c) **Sulla comunità mista dei
  primi studi M3 e M5 davano quasi lo stesso risultato** (scarto < 1%): non perché le
  chiavi coincidano, ma perché il 91% dell'energia cadeva nel caso banale e il cap
  assorbiva il resto — mancava chi sovraconsuma, l'unico caso in cui lo sharing rate
  morde. `MAIN2.m` usa la sola M3; per riprendere la M5 sui dati della griglia, la nota in
  [GUIDA §14.6](GUIDA_modelli_distribuzione.md) elenca i tre indicatori da ricalcolare.
- **I seed di RAMP e pyLPG sono deterministici** (`_seed_stabile`, `zlib.crc32`), e la
  riproducibilità è verificata: rigenerando i profili, le quattro famiglie LPG escono
  identiche byte per byte. Resta **un solo punto non riproducibile**, il *fallback
  sintetico* di `lpg_runner`: `_generate_synthetic_profile` ricava il proprio seed da
  `hash()`, salato per processo, ignorando quello deterministico calcolato dal chiamante.
  Scatta solo se pyLPG non risponde, e l'avviso lo dichiara — ma finché resta così un
  profilo sintetico va trattato come un risultato non riproducibile.
- `optimizer_PV.m` non è integrato nella pipeline di analisi ed è pensato per test
  occasionali, non per l'uso corrente della community.
- Per l'elenco completo di bug noti e miglioramenti proposti vedi
  [AUDIT_REPORT.md](AUDIT_REPORT.md) (audit del 2026-07-10, review-only).

## 13. Documentazione aggiuntiva

| Documento | Quando consultarlo |
|---|---|
| [STRUTTURA_PROGETTO2.txt](STRUTTURA_PROGETTO2.txt) | Serve il dettaglio di un file o di una funzione, la mappa di cartelle e tabelle, le schede della griglia, o `MAIN2.m` sezione per sezione |
| [STRUTTURA_PROGETTO.txt](STRUTTURA_PROGETTO.txt) | Mappa storica, con `MAIN.m` e i sedici metodi: serve per i file fuori dal perimetro di `MAIN2.m` |
| [outputs/workspace/LEGGIMI.md](outputs/workspace/LEGGIMI.md) | Serve ripartire dai run finali senza rilanciarli, o confrontare due run (test di regressione) |
| [outputs/report/regole_ripartizione_cer.html](outputs/report/regole_ripartizione_cer.html) | Serve la pagina dei risultati finali (13 ottobre 2026) |
| [DATA_SOURCES.md](DATA_SOURCES.md) | Serve la fonte di un reddito o di una spesa gas di una scheda, le assunzioni dell'arricchimento o i suoi limiti noti |
| [data/external/palazzetto_lucca/GUIDA_dati_e_metodi.md](data/external/palazzetto_lucca/GUIDA_dati_e_metodi.md) | Serve il metodo completo con cui sono state costruite le curve di consumo e di produzione FV del palazzetto di Lucca, con affidabilità e limiti |
| [CER_configuration_PA/README.md](CER_configuration_PA/README.md) | Serve la regola con cui si inseriscono le PA nelle schede, le assunzioni sulle tre PA e i punti aperti dell'asse composizione |
| [CER_configuration_IND/README.md](CER_configuration_IND/README.md) | Serve sapere come entrano le imprese nelle schede, i loro profili e kWp, e i punti aperti dell'asse imprese |
| [data/external/koltunov2026/README.md](data/external/koltunov2026/README.md) | Serve un numero sulle CER italiane reali (taglia, prosumer, imprese, PA, potenza) con la sua fonte e i suoi limiti |
| [docs/mapping_household_istat.md](docs/mapping_household_istat.md) | Serve sapere perché un archetipo LPG ha quella tipologia familiare Istat (età e componenti dal catalogo LPG) |
| [GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md) | Serve la derivazione matematica, gli assiomi o la mappatura formula→codice di uno dei modelli di ripartizione o degli indicatori |
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | Serve un elenco di bug noti / debito tecnico (audit 2026-07-10, non aggiornato con modifiche successive) |
| [CER_LoadProfiles/README.md](CER_LoadProfiles/README.md) | Serve il dettaglio del pacchetto Python di generazione profili |
| [REPORT_VALIDAZIONE_LPG.md](REPORT_VALIDAZIONE_LPG.md) | **Serve sapere perché i profili domestici, costruiti su un catalogo tedesco, rappresentano famiglie italiane.** Metodo e risultati della validazione contro ARERA (§1-§12); il **§13 è il registro modifica per modifica**, con la fonte che giustifica ciascuna — è la sezione da citare in tesi |
| [outputs/report/validazione_lombardia100.md](outputs/report/validazione_lombardia100.md) | Serve la validazione della società a cento famiglie da cui vengono i profili delle schede |
| [REPORT_VALIDAZIONE_RAMP.md](REPORT_VALIDAZIONE_RAMP.md) | Serve la validazione dei profili non domestici (RAMP) |
| [outputs/report/scaling_metodi_ripartizione.md](outputs/report/scaling_metodi_ripartizione.md) | Serve il costo misurato dei metodi al crescere dei membri, da cui la soglia dei 18 |
| [REPORT_VALIDAZIONE_FASE2.md](REPORT_VALIDAZIONE_FASE2.md) | Serve il registro di dettaglio passo per passo della Fase 2; come sintesi è sostituito dal documento sopra |

## 14. Scaling a comunità grandi (~100 utenti): cosa va risolto prima

Il progetto nasce calibrato su **6-7 utenti**; oggi analizza comunità da 5 a 25 membri (la
griglia della §7.6) e dispone di schede fino a 100 membri — quattro per ciascuna taglia da
50, 75 e 100, da `CER_37_13_0` a `CER_0_100_0` — che non si riescono ancora ad analizzare.
Questa sezione elenca i punti che si rompono o degradano al crescere di `n`: alcuni sono
già stati affrontati (lo skip sopra i 18 utenti, la scheda per membro), altri restano
aperti.

### 14.1 Tre modelli diventano matematicamente impossibili — BLOCCANTE

**Shapley**, **Nucleolo** e **Nash Bargaining** passano da `cer_coalition_values.m`, che
enumera **2^n** coalizioni. Con `n = 100` significa ~10³⁰ valori: non è un problema di
lentezza, è irrealizzabile su qualsiasi hardware. `shapley_cer.m` emette già un warning
sopra i 20 giocatori; oltre quella soglia la §3b fallirebbe in allocazione di memoria.

> **Dal 15 settembre 2026 la pipeline non ci prova nemmeno: sopra i 18 utenti li salta.** La
> soglia è un `skipGameTheory = nUsers > 18` calcolato in §1, appena i profili sono caricati,
> e stampato in chiaro (`[BYPASS] ... 2^n ...`); `MAIN2.m` la eredita da `MAIN.m`. Non è
> una stima prudenziale, è misurata: a `n = 21` lo Shapley costa 9 min 13 s, il Nucleolo
> 18 min, il Nash Bargaining supera i 25 minuti senza finire
> ([scaling_metodi_ripartizione.md](outputs/report/scaling_metodi_ripartizione.md)).
> Insieme a loro viene saltato l'**eccesso di coalizione** (§7), che enumera per conto
> suo — il suo costo sta nel numero di *utenti*, non di metodi, quindi non basta aver
> saltato i primi. Tutto il resto della pipeline prosegue: in `MAIN2.m` girano gli altri
> dieci metodi, con l'Adaptive Sampling al posto dello Shapley, e l'analisi fra comunità
> tiene i soli metodi comuni a tutte (§7.6.5). Sotto soglia non cambia **nulla**.
>
> Cosa si perde sopra i 18 utenti, e non per una rinuncia implementativa: la domanda
> *«questa ripartizione regge?»* non ha risposta, perché per definizione guarda **tutti**
> i sottogruppi. Le colonne `EccessoMax_EUR` e `CoalizioniInstabili` restano a `NaN` —
> deliberatamente, perché uno zero si leggerebbe come «nessuno vuole uscire».

> **Con `F > 0` diventano quattro.** Il Variance Least Core sfugge a questo limite grazie
> alla row-generation, ma solo finché il suo Separation Problem è un MILP — e con il
> fattore di riduzione non lo è più (§7.5). In quel caso ripiega sull'enumerazione e
> si aggiunge alla lista, con un errore esplicito sopra i 20 giocatori. È il primo punto
> da sistemare se si vorrà usare il conto capitale su comunità grandi.

**Per lo Shapley la via d'uscita è già in repo (metodi 13-15, §6).** Le tre
approssimazioni di Cremers et al. sono state introdotte esattamente per questo: valutano
`v` su richiesta (`cer_shared_value.m`) e costano `O(n)`, `O(n²)` e `O(n·M)` invece di
`O(2ⁿ)`. A `n = 100` sono rispettivamente ~100, ~20 000 e ~200 000 valutazioni, contro
`10³⁰`. Il loro errore rispetto allo Shapley esatto si misura dove lo Shapley esiste, e va
letto prima di affidarsi a loro su larga scala (scarto relativo medio):

| Metodo | Costo | Primi studi (`MAIN.m`, 7 membri) | Griglia (`MAIN2.m`, 5-18 membri) |
|---|---|---:|---:|
| Adaptive Sampling | `O(n·M)` | **1,34%** | **0,9-1,5%** secondo la taglia |
| Marginal Contribution | `O(n)` | 16,20% ⚠ | non misurato |
| Stratified Expected Value | `O(n²)` | **21,79%** ⚠ | non misurato |

La SEV non era utilizzabile con la topologia dei primi studi (un solo prosumer pivotale,
vedi §6 e [GUIDA §16.8](GUIDA_modelli_distribuzione.md)); potrebbe però tornare la
migliore proprio a `n` grande, se l'espansione porta **più impianti distribuiti fra i
membri** — e sulla griglia la condizione c'è, fino al 100% di prosumer. `MAIN2.m` però non
la calcola: è la verifica da fare se la si vuole riprendere. Restano poi le due vie
d'uscita classiche, complementari a queste:
- **Raggruppamento per archetipo** — è la scelta di Moncecchi et al. (il paper di
  riferimento dello Shapley) che gestisce 131 utenti calcolando il valore su pochi
  *gruppi* e ripartendolo poi internamente in proporzione al consumo. Il docstring di
  `shapley_cer.m` già menziona questa approssimazione come non necessaria a `n` piccolo.
  Aprirebbe anche la strada al calcolo **esatto per `K` classi** di Cremers et al. §4.2,
  oggi inerte perché i sei profili reali sono tutti diversi
  ([GUIDA §16.10](GUIDA_modelli_distribuzione.md)).
- **Campionamento Monte Carlo** delle permutazioni per lo Shapley (stimatore standard).

Restano invece scoperti **Nucleolo e Nash Bargaining**: passano ancora da
`cer_coalition_values.m`, e il progetto non ha oggi un'alternativa scalabile — sopra i
18 utenti vengono saltati, non sostituiti. Per lo Shapley il sostituto c'è ed è
l'Adaptive Sampling (scarto 1-2% a ogni taglia testata); per questi due, chi guarda una
CER grande resta senza una lettura di stabilità e senza il Nash, e va detto nei
risultati invece che lasciato dedurre da una colonna assente.

Il **Variance Least Core** è nato per questo — la row-generation valuta `v(K)` solo sulle
poche coalizioni vincolanti, ed è pensata per comunità da decine o centinaia di membri — ma
**sui nostri dati non scala quanto promette**. A ogni iterazione la separazione è un MILP
(`intlinprog`) su tutte le ore con generazione, e il suo costo cresce in fretta con i
membri: nei run del 13 ottobre l'analisi di una comunità da 20 membri durava 2,5-14 min e
da 25 fino a 31 min (`CER_18_7_0`), quasi tutti spesi nel VLC; nelle prove del 25-28
settembre, a 50 membri, non convergeva in 5 ore, e tolleranze allentate o arresto
anticipato del MILP non hanno dato guadagni. C'è anche un limite di robustezza:
`intlinprog` usa il limite di tempo di default (7200 s) e, se scatta, la separazione si
ferma con un errore invece di usare la migliore soluzione trovata — è successo il 5
ottobre su `CER_18_7_0` (log in `outputs/run_logs/`) e il 21 ottobre su `PA3/CER_0_20_0`, dove
la causa più probabile è la sospensione del PC (il limite è a tempo reale, §7.10.1). Per questo le schede da 50-100 membri
non sono nell'analisi: è il primo punto da sistemare per andare oltre i 25 membri.

Gli otto metodi non cooperativi (Equal Split, Proportional to Consumption,
Remuneration Model 1, Cascading Tree, Weighted Solidarity, Pearson Key,
Pearson-Sharing Rate, Similarity-Utilization) sono tutti `O(H·n)` e scalano senza
modifiche — le due chiavi dinamiche hanno un ciclo sulle 8760 ore con al più `n`
iterazioni interne, quindi `O(H·n²)` nel caso peggiore (tutti gli utenti cappati uno alla
volta): a 100 utenti restano nell'ordine dei secondi.

### 14.2 `weighted_solidarity_cer.m` esaurisce la memoria — DA SISTEMARE

La ricerca su griglia è vettorizzata con array 4-D `[H, n, nβ1, nβ2]`. Il consumo cresce
linearmente in `n`:

| n utenti | Dimensione array | Picco stimato (con i temporanei) |
|---:|---:|---:|
| 6 | ~42 MB | ~130 MB (ok) |
| 100 | **~700 MB** | **~2 GB per iterazione** |

Con i default (36 iterazioni sulle coppie α) diventa impraticabile su una macchina
normale. La correzione non cambia la matematica: basta **processare le combinazioni β a
blocchi** dimensionati su un budget di memoria, invece che tutte insieme. Sono poche
righe, ma vanno aggiunte prima di girare a `n` grande.

### 14.3 Le tabelle di configurazione a mano — risolto

Era il problema del `containers.Map` `RATED_LOAD_KW`, con una voce per utente scritta
dentro `MAIN.m`. **Non esiste più:** la potenza impegnata è una colonna di `[MEMBRI]`
nella scheda della CER (§9), e una tabella di sessanta righe si compila come una di
sei. `align_members_to_users.m` verifica la corrispondenza con le colonne del CSV e
riporta **tutti** i disallineamenti insieme, invece di fermarsi al primo.

Resta una scelta da fare quando i membri diventeranno molti: **compilare a mano sessanta
potenze impegnate** oppure **derivarle dal picco di carico** di ciascun utente,
arrotondato al taglio contrattuale superiore. La seconda strada richiede zero
configurazione e riflette il profilo effettivo, ma serve un fattore di sicurezza — il
dato orario in kWh sottostima la potenza istantanea di picco. Oggi la scheda non la
implementa: dichiara le potenze.

### 14.4 Punti minori da tenere d'occhio

- **Matrice di dominanza di Pareto** in `weighted_solidarity_cer.m`: è
  `nCombos × nCombos` (~13 MB con i default) e **non dipende da `n`** — resta invariata
  anche a 100 utenti. Cresce però col numero di combinazioni se si allargano i range dei
  coefficienti via `opts`.
- **`plot_benefit_network.m`**: dispone i giocatori su una circonferenza con
  un'etichetta ciascuno. A 100 nodi il grafico diventa illeggibile — servirà una
  visualizzazione aggregata o per gruppi.
- **Scaglione della tariffa TIP — corretto, con un caso lasciato scoperto per scelta.**
  Lo scaglione `TP_base`/`CAP` si sceglie sulla potenza del **singolo impianto**
  (`cer_tip_bracket_power.m`), non più sulla somma di comunità. Il dettaglio sta nel
  paragrafo qui sotto: è la voce più lunga di questa sezione perché la parte non
  implementata va scritta da qualche parte, e questo è il posto a cui rimanda il
  messaggio d'errore del codice.
- **Generazione dei profili**: `simulation_config.yaml` scala aumentando `num_users` e
  `count`. I seed sono deterministici (§12), quindi la varianza fra run non è un problema;
  lo diventa il **tempo**, perché pyLPG simula un nucleo alla volta — quattro famiglie
  costano ~21 minuti, cento ne costano ore. I cento profili lombardi sono stati generati e
  validati (`CER_LoadProfiles/outputs/csv_lombardia100/`, `lpg_db/confronta_societa.py`).

#### 14.4.1 Lo scaglione della TIP: cosa fa il modello e cosa no

**La regola.** `TP_base` e `CAP` si scelgono «in base al valore della *potenza
impianto/sezione della medesima UP*» (Regole Operative GSE del 16 luglio 2025,
§2.2.2.1.2): lo scaglione appartiene all'**impianto**, non alla comunità.

| Potenza impianto | `TP_base` | `CAP` |
|---|---|---|
| P ≤ 200 kW | 80 €/MWh | 120 €/MWh |
| 200 < P ≤ 600 kW | 70 €/MWh | 110 €/MWh |
| P > 600 kW | 60 €/MWh | 100 €/MWh |

**Cos'era sbagliato.** Fino alla correzione `MAIN.m` passava `sum(CFG.impianti.kWp)`. Su
due schede su sette questo bastava a far scivolare l'intera comunità in uno scaglione che
il decreto non prevede per quegli impianti: CER_0_7_0 ha sette impianti per 225,6 kW
complessivi ma il maggiore è da 76 kW, CER_1_6_0 ne ha sei per 213,6 kW. Entrambe
ricevevano 70/110 invece di 80/120.

Il costo era **esattamente 10 €/MWh in ogni ora**, non in media: poiché `CAP − TP_base`
vale 40 in tutti e tre gli scaglioni, la spezzata `min(CAP; TP_base + max(0; 180 − Pz))`
di due scaglioni adiacenti è la stessa curva traslata di dieci, qualunque sia il prezzo
zonale. Sulle due schede il valore della grande coalizione è salito di +8,5%
(1694,12 → 1838,26 € e 1797,87 → 1950,73 €), e la differenza coincide con
`0,010 €/kWh × energia condivisa` fino alla dodicesima cifra — è un'identità, ed è il
controllo con cui si verifica la correzione.

**Qual è l'unità: il punto di connessione.** «La potenza di un impianto, ai fini
dell'accesso alla tariffa incentivante, verrà calcolata come somma delle potenze delle
sezioni che compongono le unità di produzione, alimentate dalla stessa fonte e *collegate
allo stesso punto di connessione* alla rete elettrica» (§1.2.1.2). L'unità non è quindi la
riga della scheda, e non è il membro: è il **POD**. Per questo `[IMPIANTI]` accetta una
colonna facoltativa `pod`: quando c'è, le righe che la condividono si sommano prima di
scegliere lo scaglione; quando manca, una riga vale un impianto. Sulle schede della griglia
non c'è e non servirebbe: ogni prosumer ha un solo impianto domestico, da 3,4-5,9 kWp.
(Nelle schede miste dei primi studi `office_1_kWh` possedeva PV04 e PV06 da 50,8 kW: 101,6 kW
restavano nel primo scaglione tanto sommati quanto no.)

**Cosa NON è modellato, e perché.**

1. *Artato frazionamento* (§1.2.1.5). Impianti della stessa fonte, su particella catastale
   medesima o contigua e riconducibili a un unico produttore, contano come «unico
   impianto» di potenza pari alla somma — anche su POD diversi. Servirebbe la particella
   catastale, che la scheda non porta; e la norma stessa esclude dalla regola gli impianti
   «inseriti in distinti edifici/condomini» e quelli «connessi a utenze con potenza in
   prelievo pari o superiore alla potenza dell'impianto», che senza il dato sull'edificio
   non si sanno riconoscere. Aggregare per proprietario sarebbe *più* sbagliato che non
   aggregare: applicherebbe la regola anche dove il decreto la esclude.

2. *Impianti in scaglioni diversi.* È il caso che rende la tariffa non più una sola. Il
   decreto lo prevede per intero:
   - una tariffa per impianto — il GSE pubblica «il valore della tariffa premio applicata
     a ogni impianto incentivato» e «l'energia condivisa incentivabile **ripartita per
     UP**» (§2.2.2);
   - la ripartizione dell'energia condivisa fra impianti avviene «a partire dalle
     immissioni degli impianti di produzione **entrati prima in esercizio**» (Appendice A,
     definizioni di `E_AC` e `E_ACI`) — una cascata per data di entrata in esercizio, dato
     che `[IMPIANTI].anno_esercizio` già porta;
   - il contributo diventa quindi `C_ACI = Σ_p Σ_h E_ACI(p,h) · TIP(p,h)`.

   Non è implementato perché **nessun impianto delle schede supera i 200 kW**: stanno
   tutti nel primo scaglione, la tariffa resta una sola, e una ripartizione per UP non
   cambierebbe un solo numero. `cer_tip_bracket_power.m` non lo approssima e non lo tace:
   verifica che tutti gli impianti condividano lo scaglione e **si ferma** con un errore
   che rimanda a questo paragrafo. Chi volesse comunque un risultato può dichiarare
   `[MERCATO].tip_potenza_rif_kW` e imporre uno scaglione unico, sapendo che è
   un'approssimazione.

   > **Dal 18 ottobre 2026 lo scenario impone lo scaglione unico** (`tip_potenza_rif_kW = 100`
   > in `scenario_economico.txt`: qualunque valore fino a 200 kW sceglie il primo scaglione,
   > 80/120 €/MWh). Serve all'asse composizione (§7.10): nelle schede con il palazzetto di
   > Lucca (PA3, 310,5 kWp) gli impianti cadrebbero in scaglioni diversi e `MAIN2.m` si
   > fermerebbe. Il primo scaglione è quello dei domestici, quindi **la tariffa è identica in
   > tutti i livelli PA** e la differenza fra livelli è solo composizione. L'approssimazione:
   > per norma il palazzetto avrebbe 70/110, quindi in PA3 la tariffa è sovrastimata di al più
   > 0,010 €/kWh sull'energia condivisa (`CAP − TP_base` vale 40 in ogni scaglione, come
   > sopra). Sulle schede domestiche non cambia nulla: lo scaglione derivato era già il primo,
   > e `RESULTS` è identico bit a bit al run del 13 ottobre (verificato su `CER_0_8_0`,
   > `CER_4_1_0`, `CER_7_3_0`). Lo scenario non ha commenti per scelta: la motivazione sta qui.

   Se un giorno servisse davvero, l'ostacolo non è la formula ma il **gioco cooperativo**:
   con tariffe diverse per impianto, `v(S)` dipenderebbe da quali impianti possiede la
   coalizione `S`, e `stratified_expected_value_cer.m` valuta `v` su utenti *fittizi* medi
   che non possiedono alcun impianto (§4.1.2 di Cremers et al.) — lì la domanda «quali
   impianti ha questa coalizione» non ha risposta. È lo stesso nodo già affrontato per il
   fattore F, ma senza la via d'uscita che F aveva.

---

## 15. Dati del palazzetto dello sport di Lucca

Due curve orarie 2024 di un'utenza reale, in [`data/external/palazzetto_lucca/`](data/external/palazzetto_lucca/).
Sono **archiviate con la loro documentazione ma non ancora collegate a `MAIN2.m`**: usarle in una
scheda richiede di concordare prima il cambio.

| File | Contenuto |
|---|---|
| `palazzetto_lucca_carico.csv` | **Consumo orario allineato alla pipeline**: 8.760 righe su griglia 2025, formato di `100_utenti.csv` (`timestamp;palazzetto_lucca_kWh`). Energia 289.706 kWh, minimo 9,9 kW, massimo 114,0 kW |
| `palazzetto_lucca_FV.CSV` | **Produzione FV allineata alla pipeline**: 8.760 righe, layout degli export PVsyst di `PV_Generation/` (`dd/mm/yy HH:MM;kW`, anno 90). Energia 398.112 kWh, picco 280,2 kW |
| `originali_2024/` | Le due serie come costruite (anno 2024, 8.784 righe, ora di orologio): `lucca_anno_2024_ricostruito_kW.csv` (290.131 kWh) e `lucca_pv_2024_kW.csv` (398.902 kWh, con colonna `origine`) |
| `GUIDA_dati_e_metodi.md` | Metodo completo, scelte, affidabilità e limiti |
| `scripts/` | `lucca_year.py` e `plot_lucca_year.py` (carico), `lucca_pv_tmy.py` e `plot_lucca_pv_tmy.py` (FV), `allinea_alla_pipeline.py` (dagli originali ai due file allineati) |

**Perimetro.** Solo il palazzetto di Lucca; i dati ENEA della palestra "Volley" e il relativo input
RAMP sono stati scartati. I due oggetti sono diversi: il **consumo** è dell'edificio **esistente**
(misure 2024 lette dai grafici della diagnosi), la **produzione** è dell'impianto del **nuovo**
palazzetto (progetto). Il loro confronto è quindi indicativo: circa il 30% dell'energia FV
sarebbe autoconsumata e il FV coprirebbe circa il 40% del consumo annuo.

**Come sono state ottenute.**

- *Consumo (ricostruito, non misurato).* La diagnosi non ha tabelle orarie ma grafici. Le barre
  mensili (Fig. 2) danno l'energia di ogni mese, scalata a 290,136 MWh; il massimo e il minimo
  di ogni giorno (Fig. 3) danno l'inviluppo; la settimana 22-28 gennaio 2024 (Fig. 4) dà la
  forma oraria per feriale, sabato e domenica. Per ogni giorno
  `P(h) = min + (max − min)·s(h)^γ`, con γ scelto mese per mese perché l'energia mensile
  coincida con quella letta. Affidabilità: alta su energia mensile e annua, buona su massimo e
  minimo giornalieri, media sulla forma oraria, più bassa d'estate. Sulla settimana nota lo scarto
  quadratico medio è 8,6 kW (circa il 20% del carico medio), correlazione 0,94: verifica
  ottimistica, perché la stessa settimana fornisce la forma. **Non è adatta a dimensionare FV,
  accumuli o CER**: servono le curve vere del POD.
- *Produzione FV (modellata).* Impianto da 310 kWp, 15° verso sud, perdite 14%. Il TMY orario di
  PVGIS per Lucca è portato sul piano dei moduli con pvlib (Hay-Davies, temperatura di cella
  Faiman, perdite per angolo di incidenza), riportato sul calendario 2024 con ora legale e
  ogni mese riscalato alla tabella mensile della diagnosi (stima del progetto, 398.902 kWh/anno,
  pag. 246): così la produzione è paragonabile al progetto mese per mese. Il calcolo fisico dal
  TMY, senza riscalatura, è entro −0,7% da PVGIS-SARAH3 (391.232 kWh/anno), che nella prima
  versione era il bersaglio ed è ora termine di confronto: rispetto al progetto ha gennaio +14%,
  febbraio +16%, luglio −10%, totale −1,9%. È scartata una tabella in immagine di fonte ignota.
  La tabella del progetto non dichiara inclinazione, orientamento né software.
- *Colonna `origine`.* `tmy` (8.739 righe), `tmy_riempito` (21 ore diurne che nel TMY erano a
  zero, tra cui il 2 dicembre dalle 10 alle 15) e `copia_28feb` (24 righe del 29 febbraio, copia
  del 28). Il criterio di riempimento va confermato dall'autore.

**Allineamento alla pipeline** (`scripts/allinea_alla_pipeline.py`). I due file nella cartella principale sono gli originali portati alle convenzioni del progetto (§5.1):
- *Calendario.* Anno uniforme di 8.760 ore **senza ora legale**: le ore estive sono riportate a ora standard (−1 h dal 31 marzo al 27 ottobre 2024). Dopo lo spostamento il picco FV cade alle 12–13 in tutti i mesi, come negli export di `PV_Generation/`.
- *Bisestile.* Il FV perde il 29 febbraio (24 ore, circa 790 kWh: febbraio scende da 18.123 a 17.333 kWh e l'annuo da 398.902 a 398.112 kWh) e il suo anno fittizio è il 1990. Il carico è rimappato sulla griglia **2025** a parità di giorno della settimana (il giorno D del 2025 prende il giorno D−364 del 2024, 52 settimane): la struttura settimanale, quindi feriali e festivi, resta al posto giusto, ma il fermo estivo e le festività si spostano di due giorni. L'energia annua del carico passa da 290.131 a 289.706 kWh.
- *Formato.* Il FV ha la stessa struttura degli export PVsyst (righe di intestazione ignorate dal lettore, separatore `;`, punto decimale, lettura per posizione) con un'intestazione che dichiara che **non** è un export PVsyst. Il carico ha lo stesso formato di `100_utenti.csv` (timestamp ISO con `T`, separatore `;`, CRLF).
- Il lettore di `load_cer_data.m` è stato emulato in Python sul FV (8.760 righe, nessun valore negativo o con virgola); non è stato eseguito in MATLAB.

**Limiti.** Il FV è un anno tipico, non il 2024. Inclinazione e orientamento reali non sono nella
diagnosi. Il picco di 280,2 kW supera i 270 kW di inverter (4 ore, circa 15 kWh/anno oltre il limite,
taglio non applicato). Il progetto esecutivo del Comune (134,4 kWp) è un impianto diverso e non è usato.

**Riferimenti.** Comune di Lucca, *Diagnosi energetica – Palazzetto dello Sport*, cod. 047.24.01.R.01,
novembre 2025 (Fig. 2, 3, 4, cap. 7.3, cap. 12.1); Comune di Lucca, progetto esecutivo PE Silver 1,
relazione tecnica FV; Commissione Europea JRC, PVGIS 5 (PVGIS-SARAH3, TMY 2005-2023),
https://re.jrc.ec.europa.eu/pvg_tools/en/; pvlib python 0.16.1. Riferimenti completi in
[DATA_SOURCES.md](DATA_SOURCES.md).
