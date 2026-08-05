# Master-Thesis-Project — Analisi CER

Simulazione e analisi tecnico-economica di una **Comunità Energetica Rinnovabile (CER)**
italiana: generazione di profili di carico realistici, bilancio energia condivisa/venduta,
ripartizione dell'incentivo CER tra i membri con nove modelli alternativi (teoria dei giochi
cooperativi, benchmark elementari e modelli dalla letteratura sulle REC italiane), costo
dell'approvvigionamento da rete, dimensionamento di un impianto fotovoltaico.

**Autore:** Alberto Scimonelli — Tesi di Laurea Magistrale, 2026

> **Per chi apre questo repository per la prima volta (umano o assistente AI):** questo
> README dà la panoramica completa. Per il dettaglio file-per-file vedi
> [STRUTTURA_PROGETTO.txt](STRUTTURA_PROGETTO.txt); per la derivazione matematica dei
> modelli di ripartizione vedi [GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md).
> Non dovrebbe servire leggere il codice sorgente per capire cosa fa il progetto e come è
> strutturato — solo per modificarlo.

---

## Indice

1. [Cosa fa il progetto](#1-cosa-fa-il-progetto)
2. [Pipeline a due stadi](#2-pipeline-a-due-stadi)
3. [Come eseguirlo](#3-come-eseguirlo)
4. [Struttura del repository](#4-struttura-del-repository)
5. [Il modello energetico CER](#5-il-modello-energetico-cer)
6. [I nove modelli di ripartizione dei benefici](#6-i-nove-modelli-di-ripartizione-dei-benefici)
7. [Dimensionamento impianto PV (standalone)](#7-dimensionamento-impianto-pv-standalone)
8. [Configurazione attuale (community di default)](#8-configurazione-attuale-community-di-default)
9. [Dipendenze e requisiti](#9-dipendenze-e-requisiti)
10. [Output prodotti](#10-output-prodotti)
11. [Limitazioni note / TODO](#11-limitazioni-note--todo)
12. [Documentazione aggiuntiva](#12-documentazione-aggiuntiva)
13. [Scaling a comunità grandi (~100 utenti): cosa va risolto prima](#13-scaling-a-comunità-grandi-100-utenti-cosa-va-risolto-prima)

---

## 1. Cosa fa il progetto

Un quartiere (uffici, piccola industria, negozio, famiglie) aderisce a una CER. Alcuni
membri hanno un impianto fotovoltaico (**prosumer**), altri no (**consumatori puri**).
Quando la produzione PV eccede l'autoconsumo del proprietario, il surplus viene condiviso
con il resto della comunità: sull'energia condivisa lo Stato eroga un incentivo (la
tariffa incentivante premio, **TIP_h**). Il progetto risponde a tre domande:

1. **Quanta energia si condivide e quanta si vende in rete?** (bilancio orario annuale)
2. **Come si ripartisce equamente l'incentivo tra i membri?** (nove modelli a confronto,
   dalla teoria dei giochi cooperativi a semplici regole di buon senso, fino a modelli
   proposti in letteratura per le REC italiane)
3. **Conviene dimensionare diversamente l'impianto PV?** (ottimizzatore indipendente per
   IRR/NPV)

## 2. Pipeline a due stadi

```
STADIO 1 (Python)                          STADIO 2 (MATLAB)
CER_LoadProfiles/                           root/

simulation_config.yaml                      outputs/csv/profili_tutti.csv ---+
        |                                                                    |
        v                                   PV_Generation/Salvaplast_*.CSV --+--> MAIN.m
generate_load_profiles.py (orchestratore)                                    |
   |-- ramp_runner.py   (aziende, RAMP)                                      +--> optimizer_PV.m
   +-- lpg_runner.py    (famiglie, pyLPG)                                        (indipendente)
        |
        v
postprocessing.py (aggregazione oraria + export CSV)
        |
        v
outputs/csv/*.csv  (kWh/h, 2025, ~8760 righe)
```

- **Stadio 1 — Python** (`CER_LoadProfiles/`): genera profili di carico orari annuali
  realistici per aziende (libreria RAMP) e famiglie (pyLPG, con fallback sintetico se
  pyLPG non è disponibile). Output: CSV orari in kWh, compatibili con `readtable()` di
  MATLAB.
- **Stadio 2 — MATLAB** (root): `MAIN.m` è l'entry point che carica i profili di carico +
  la produzione PV, calcola il bilancio energetico, ripartisce i benefici con nove modelli,
  calcola il costo dell'approvvigionamento da rete e produce i grafici. `optimizer_PV.m` è
  uno script **indipendente** (non chiamato da `MAIN.m`) per il dimensionamento fisico
  dell'impianto.

I due stadi comunicano solo tramite CSV: non c'è integrazione automatica, si esegue prima
Python e poi MATLAB.

## 3. Come eseguirlo

**Stadio 1 (opzionale se `outputs/csv/profili_tutti.csv` esiste già):**
```bash
cd CER_LoadProfiles
python generate_load_profiles.py            # usa config/simulation_config.yaml
python generate_load_profiles.py --config altro_config.yaml
```
Richiede l'ambiente Python descritto in [requirements.txt](requirements.txt) (root, freeze
completo) o [CER_LoadProfiles/requirements.txt](CER_LoadProfiles/requirements.txt)
(dipendenze dirette del pacchetto).

**Stadio 2:**
```matlab
% In MATLAB, dalla root del progetto:
MAIN
```
I percorsi dei file di input (`loadFile`, `pvFile`, `zonalPriceFile`) sono **hardcoded**
nella sezione `%% 0) CONFIGURAZIONE` di `MAIN.m` — da aggiornare se si spostano i dati.
Richiede **Optimization Toolbox** (`linprog`, `quadprog`, `intlinprog`) per Nucleolo e
Variance Least Core.

`optimizer_PV.m` si esegue separatamente ed è pensato per test occasionali di
dimensionamento, non fa parte del flusso principale.

## 4. Struttura del repository

Mappa sintetica — per il dettaglio completo (ogni file, ogni funzione, ogni CSV) vedi
[STRUTTURA_PROGETTO.txt](STRUTTURA_PROGETTO.txt) §1-§4.

| Percorso | Contenuto |
|---|---|
| `CER_LoadProfiles/` | Pacchetto Python — generazione profili di carico (RAMP + pyLPG) |
| `PV_Generation/` | Export orario PVsyst della produzione dell'impianto PV |
| `20250101_20251231_MGP_PrezziZonali_Nord.xlsx` | Prezzo zonale orario MGP 2025 (GME, zona Nord) |
| `MAIN.m` | **Entry point MATLAB** — orchestra l'intera analisi energetico-economica |
| `load_cer_data.m` | Caricamento profili + assegnazione impianti PV/autoconsumo (§5) |
| `load_zonal_price.m`, `compute_cer_incentive.m` | Prezzo zonale → tariffa incentivante oraria TIP_h |
| `cer_coalition_values.m` | Funzione caratteristica `v(S)` del gioco cooperativo, condivisa dai metodi 1-4 |
| `shapley_cer.m`, `nucleolus_cer.m`, `nash_bargaining_cer.m`, `variance_least_core_cer.m` | I quattro modelli di teoria dei giochi (§6) |
| `equal_split_cer.m`, `proportional_consumption_cer.m` | I due benchmark elementari (§6) |
| `remuneration_model1_cer.m`, `cascading_tree_cer.m`, `weighted_solidarity_cer.m` | I tre modelli dalla letteratura sulle REC italiane (§6) |
| `report_allocation.m`, `method_color.m`, `plot_allocation_comparison.m`, `plot_benefit_network.m` | Reporting e grafici condivisi da tutti e nove i modelli |
| `plot_cer_energy.m`, `plot_pv_vs_demand.m`, `plot_load_profiles.m` | Grafici energetici (mensili, annuali, profili tipo) |
| `profilo_prezzi_pun_2025.m` | Prezzi PUN 2025 per 3 modalità tariffarie (costo da rete, §4) |
| `optimizer_PV.m`, `irr_bisection.m` | Dimensionamento impianto PV (standalone, §7) |
| `archive/` | Codice superato mantenuto per riferimento storico (`PROVA_PV.m`, `merge_pv_owner.m`) |
| `GUIDA_modelli_distribuzione.md` | Derivazione matematica completa dei nove modelli di ripartizione |
| `STRUTTURA_PROGETTO.txt` | Mappa dettagliatissima di ogni file/funzione/CSV del progetto |
| `AUDIT_REPORT.md` | Audit del codice — bug noti e possibili miglioramenti (2026-07-10) |
| `REFACTORING_PLAN.md` | Piano ed esito del refactoring strutturale eseguito (2026-07-29) |

## 5. Il modello energetico CER

**Giocatori = utenti.** Ogni utente della comunità porta con sé un carico (`loadUsers`) e,
se possiede un impianto, una produzione PV. Un impianto è fisicamente "dietro al
contatore" del proprietario: la produzione copre **prima** il suo autoconsumo, e **solo
l'eccedenza** è disponibile per la comunità (dettagli e formule in
[STRUTTURA_PROGETTO.txt §7](STRUTTURA_PROGETTO.txt)). Da questo derivano, ora per ora e
per ogni utente:

- `gen_i(t)` — eccedenza PV dell'utente `i` (0 se non ha impianto o se è tutta autoconsumata)
- `load_i(t)` — carico **residuo** dell'utente `i` (al netto dell'autoconsumo)

Per costruzione, `gen_i(t)` e `load_i(t)` sono **complementari**: in ogni ora un utente ha
l'una o l'altro, mai entrambi.

**Bilancio di comunità** (§2 di `MAIN.m`):
```
energia condivisa(t) = min( Σ_i gen_i(t),  Σ_i load_i(t) )    → matura l'incentivo CER
energia venduta(t)   = max( 0, Σ_i gen_i(t) - Σ_i load_i(t) )  → venduta in rete a P_SELL
```

**Tariffa incentivante (TIP_h).** L'incentivo sull'energia condivisa non è una costante:
è un vettore orario `P_CER_h` (eq. 3.1), calcolato da `compute_cer_incentive.m` a partire
dal prezzo zonale orario del Mercato del Giorno Prima (`load_zonal_price.m`, letto da
`20250101_20251231_MGP_PrezziZonali_Nord.xlsx`).

Questo bilancio (con `P_CER_h`) è l'input di **tutti e nove** i modelli di ripartizione:
```
v(S) = Σ_t min( Σ_{i∈S} gen_i(t), Σ_{i∈S} load_i(t) ) · P_CER_h(t)
```
è la **funzione caratteristica** del gioco cooperativo (`cer_coalition_values.m`), e
`v(N)` (l'intera comunità) è il totale che i nove modelli si dividono in modo diverso.

## 6. I nove modelli di ripartizione dei benefici

L'incentivo CER `v(N)` viene ripartito tra i giocatori secondo nove modelli alternativi,
tutti calcolati in `MAIN.m` (§3b-§3j) e confrontati in tabella e grafico. Firma comune:
`S = metodo_cer(genUsers, loadUsers, userNames, P_CER, ...)` → struct con almeno `.phi`
(quota per utente, €), `.vGrand` (= `v(N)`, salvo eccezioni documentate), `.table`.
Derivazione matematica completa, assiomi ed esempi numerici in
[GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md).

| # | Metodo | File | Logica | Stabile? |
|---|---|---|---|:---:|
| 1 | **Shapley value** | `shapley_cer.m` | Media dei contributi marginali di ciascun utente su tutti gli ordini possibili di formazione della coalizione (Moncecchi et al. 2020) | No (in generale) |
| 2 | **Nucleolo** | `nucleolus_cer.m` | Massimizza lessicograficamente il surplus della coalizione più scontenta, via LP sequenziali (Fioriti et al. 2021) | Sì, se il Core è non vuoto |
| 3 | **Nash Bargaining** | `nash_bargaining_cer.m` | Quota proporzionale al contributo marginale alla grande coalizione, forma chiusa (Yan et al. 2023) | No (in generale) |
| 4 | **Variance Least Core** | `variance_least_core_cer.m` | L'allocazione del Least Core più vicina alla ripartizione uniforme, via row-generation — scala a decine/centinaia di membri (Ferrucci, Fioriti, Poli 2025) | Sì |
| 5 | **Equal Split** | `equal_split_cer.m` | Benchmark ingenuo: `v(N)` diviso in **parti uguali** tra tutti gli utenti — `φ_i = v(N)/n` | N/A (non è un gioco) |
| 6 | **Proportional to Consumption** | `proportional_consumption_cer.m` | Benchmark ingenuo: quota proporzionale al **consumo** di ciascun utente nelle sole ore "utili" (energia condivisa di comunità > 0) — `φ_i = v(N) · cons_i / Σ_j cons_j` | N/A (non è un gioco) |
| 7 | **Remuneration Model 1** | `remuneration_model1_cer.m` | Split α/β tra classe consumatori e classe produttori/prosumer, pesato sulla **potenza contrattuale/nominale** [kW] di ciascuna classe (dato manuale, vedi §8); dentro ogni classe, proporzionale all'energia oraria (Candela et al. 2022) | N/A (non è un gioco) |
| 8 | **Cascading Tree** | `cascading_tree_cer.m` | L'incentivo si scompone ricorsivamente in un **albero di categorie** (riserva → fissa/variabile → prelievi/immissione → produttori+prosumer/soli prosumer), con pesi di ramo di default (scelte di governance) (Trevisan et al. 2022) | N/A (non è un gioco) |
| 9 | **Weighted Solidarity** | `weighted_solidarity_cer.m` | Peso orario = componente tecnica (energia condivisa + carico) + componente di **solidarietà** (costo unitario dell'energia, proxy povertà energetica); i coefficienti sono scelti su un **fronte di Pareto** (Gini minimo vs reddito medio degli utenti a rischio povertà energetica) (Marrasso et al. 2025) | N/A (non è un gioco) |

I metodi 1-4 sono giochi cooperativi a utilità trasferibile e condividono la stessa
`v(S)` (`cer_coalition_values.m`), tranne il VLC che la valuta su richiesta per restare
scalabile. I metodi 5-9 **non** usano teoria dei giochi (né passano da
`cer_coalition_values.m`: calcolano `v(N)` direttamente) — servono da **termine di
paragone** per misurare quanto i modelli 1-4 se ne discostino (es. quanto lo Shapley
premi la produzione rispetto a una ripartizione puramente proporzionale al consumo, o
quanto un criterio di equità sociale come quello di Marrasso sposti valore verso gli
utenti più vulnerabili). Il **Cascading Tree** è l'unico i cui parametri (`opts`)
possono far sì che `vGrand` sia inferiore a `v(N)` (se si trattiene una riserva) — con i
default usati in `MAIN.m` questo non accade.

## 7. Dimensionamento impianto PV (standalone)

`optimizer_PV.m` non fa parte della pipeline di `MAIN.m`: è uno script indipendente che
ottimizza il layout di un impianto fotovoltaico su copertura industriale (numero di
inverter, tilt, distanza inter-fila), simulando ora per ora produzione DC/AC e bilancio
economico (CAPEX, OPEX, ricavi, IRR via `irr_bisection.m`, NPV) per selezionare la
configurazione che massimizza IRR o NPV. `archive/PROVA_PV.m` è la versione precedente,
mantenuta come riferimento storico.

## 8. Configurazione attuale (community di default)

- **Comunità:** 6 utenti — `office_1`, `small_industry_1`, `retail_1`, `household_1`,
  `household_2`, `household_3` (configurabile in
  `CER_LoadProfiles/config/simulation_config.yaml`).
- **Impianto PV:** uno solo, assegnato a `small_industry_1_kWh` (file
  `PV_Generation/Salvaplast_Project_VD7_HourlyRes_1.CSV`); la struct `pvPlants` in
  `MAIN.m` §1b è pensata per estendersi a più impianti/proprietari senza altre modifiche.
- **Anno di simulazione:** 2025, griglia oraria 8760 ore.
- **Prezzo vendita eccedenza:** `P_SELL = 0.11 €/kWh` (costante).
- **Zona CER:** Nord (coerente col file prezzi zonali).
- **Potenza nominale PV per la formula TIP:** `P_PV_NOM_KW = 20` — **provvisorio**, vedi §11.
- **Potenze per Remuneration Model 1** — **valori TODO/placeholder**, vedi §11:
  potenza di prelievo per utente in `RATED_LOAD_KW`, potenza di generazione per
  impianto nel campo `.kWp` di `pvPlants`.

## 9. Dipendenze e requisiti

**Python 3.12** (venv in root): `rampdemand` 0.5.0, `pyloadprofilegenerator`, `pandas`
3.0.x, `numpy` 2.4.x, `PyYAML`. RAMP 0.5.0 non è ancora compatibile nativamente con
numpy 2 / pandas 3: `ramp_runner.py` applica due monkey-patch a runtime (rimovibili
quando RAMP verrà aggiornato). Vedi `requirements.txt` (freeze completo) e
`CER_LoadProfiles/requirements.txt` (dipendenze dirette).

**MATLAB:** base + **Optimization Toolbox** (`linprog`, `quadprog`, `intlinprog`,
richiesti da Nucleolo e Variance Least Core). `irr_bisection.m` evita la dipendenza dalla
Financial Toolbox per il calcolo dell'IRR in `optimizer_PV.m`.

## 10. Output prodotti

**Stadio Python** → `CER_LoadProfiles/outputs/csv/`: `profili_aziende.csv`,
`profili_famiglie.csv`, `profili_tutti.csv` (input di `MAIN.m`), `profilo_CER_aggregato.csv`.
CSV orari, separatore virgola, timestamp ISO8601, ~8760 righe.

**Stadio MATLAB** (`MAIN.m`), a schermo e in tabelle/figure:
- `Treport` — riepilogo mensile/annuale energia condivisa, venduta, ricavi.
- Report testuale + grafico a barre + grafico a rete per ciascuno dei nove modelli di
  ripartizione (§6).
- `Tcmp` — tabella di confronto tra i nove modelli + grafico a barre raggruppate.
- `Tcost` — costo annuo di approvvigionamento da rete per utente, nelle 3 modalità
  tariffarie PUN (monoraria, bioraria, oraria variabile).
- Grafici energetici: andamento mensile CER, PV vs domanda, profili di consumo tipo.

## 11. Limitazioni note / TODO

- `P_PV_NOM_KW = 20` in `MAIN.m` §0 è un valore **provvisorio** (TODO nel codice): da
  confermare, seleziona lo scaglione della formula TIP.
- `F_RIDUZIONE = 0` in `MAIN.m` §0: il fattore di riduzione F della formula TIP non è
  ancora definito per intero (TODO nel codice), per ora nessuna riduzione applicata.
- Le potenze usate da Remuneration Model 1 sono **valori TODO/placeholder**: potenza di
  prelievo in `RATED_LOAD_KW` (`MAIN.m` §0) e potenza di generazione nel campo `.kWp`
  di `pvPlants`. Hanno impatto di primo ordine sul risultato — con una potenza sola al
  posto di due, i pesi α/β passerebbero da 0.81/0.19 a 0.63/0.37 e il prosumer
  riceverebbe quasi il doppio ([GUIDA §10.6](GUIDA_modelli_distribuzione.md)).
- **Weighted Solidarity — la componente di solidarietà è un proxy debole.** Il modello
  di Marrasso classifica gli utenti "a rischio povertà energetica" dal costo unitario
  in bolletta `Cu`; nel paper quel dato viene da bollette reali e varia di ~4× tra i
  membri, mentre qui è derivato dal solo prezzo PUN e varia del **2,9%**. La logica è
  implementata fedelmente, ma la classificazione risultante riflette la collocazione
  oraria dei consumi, **non** una reale vulnerabilità economica — e la ripartizione è
  in larga parte guidata da quella classificazione
  ([GUIDA §12.7](GUIDA_modelli_distribuzione.md)). Servono dati di bolletta o ISEE
  reali per usare seriamente questo metodo.
- I seed RAMP non sono bit-per-bit riproducibili tra esecuzioni diverse (`hash()` su
  stringhe è salato per processo in Python) — vedi
  [STRUTTURA_PROGETTO.txt §3.2](STRUTTURA_PROGETTO.txt).
- `optimizer_PV.m` non è integrato nella pipeline di `MAIN.m` ed è pensato per test
  occasionali, non per l'uso corrente della community.
- Per l'elenco completo di bug noti e miglioramenti proposti vedi
  [AUDIT_REPORT.md](AUDIT_REPORT.md) (audit del 2026-07-10, review-only).

## 12. Documentazione aggiuntiva

| Documento | Quando consultarlo |
|---|---|
| [STRUTTURA_PROGETTO.txt](STRUTTURA_PROGETTO.txt) | Serve il dettaglio di un file/funzione specifico, o la mappa completa di cartelle e CSV |
| [GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md) | Serve la derivazione matematica, gli assiomi o la mappatura formula→codice di uno dei nove modelli di ripartizione |
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | Serve un elenco di bug noti / debito tecnico (audit 2026-07-10, non aggiornato con modifiche successive) |
| [REFACTORING_PLAN.md](REFACTORING_PLAN.md) | Serve capire perché il codice è organizzato in helper separati invece che in un unico script (refactoring 2026-07-29) |
| [CER_LoadProfiles/README.md](CER_LoadProfiles/README.md) | Serve il dettaglio del pacchetto Python di generazione profili |

## 13. Scaling a comunità grandi (~100 utenti): cosa va risolto prima

Il progetto è oggi calibrato su **6 utenti**. È previsto di testare i modelli fino a
**~100 utenti**: questa sezione elenca i punti che si romperanno o degraderanno a quella
scala, così da affrontarli consapevolmente invece di scoprirli a metà lavoro. Nessuno di
questi è un problema *oggi* — sono tutti conseguenze della crescita di `n`.

### 13.1 Tre modelli diventano matematicamente impossibili — BLOCCANTE

**Shapley**, **Nucleolo** e **Nash Bargaining** passano da `cer_coalition_values.m`, che
enumera **2^n** coalizioni. Con `n = 100` significa ~10³⁰ valori: non è un problema di
lentezza, è irrealizzabile su qualsiasi hardware. `shapley_cer.m` emette già un warning
sopra i 20 giocatori; oltre quella soglia `MAIN.m` §3b fallirebbe in allocazione di
memoria.

Le vie d'uscita, entrambe presenti in letteratura:
- **Raggruppamento per archetipo** — è la scelta di Moncecchi et al. (il paper di
  riferimento dello Shapley) che gestisce 131 utenti calcolando il valore su pochi
  *gruppi* e ripartendolo poi internamente in proporzione al consumo. Il docstring di
  `shapley_cer.m` già menziona questa approssimazione come non necessaria a `n` piccolo.
- **Campionamento Monte Carlo** delle permutazioni per lo Shapley (stimatore standard).

Il **Variance Least Core non ha questo problema**: la row-generation è nata esattamente
per comunità da decine o centinaia di membri e valuta `v(K)` solo sulle poche coalizioni
vincolanti. I cinque metodi non cooperativi (Equal Split, Proportional to Consumption,
Remuneration Model 1, Cascading Tree, Weighted Solidarity) sono tutti `O(H·n)` e scalano
senza modifiche.

### 13.2 `weighted_solidarity_cer.m` esaurisce la memoria — DA SISTEMARE

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

### 13.3 Le tabelle di configurazione a mano non reggono

`RATED_LOAD_KW` in `MAIN.m` §0 è un `containers.Map` con **una voce per utente**: a 100
utenti è ingestibile e fragile (una voce mancante ferma l'esecuzione). Le due impostazioni
sensate, da scegliere al momento dell'espansione:

- **Tabella per archetipo** — i nomi utente sono già strutturati (`office_1_kWh`,
  `household_23_kWh`): si estrae il prefisso e si assegna la potenza per *tipo*. 90
  famiglie in più non richiedono alcuna modifica alla configurazione.
- **Derivazione dal picco di carico** — potenza calcolata dal picco orario reale di
  ciascun utente, arrotondato al taglio contrattuale standard superiore. Zero
  configurazione e riflette il profilo effettivo, ma richiede un fattore di sicurezza
  (il dato orario in kWh sottostima la potenza istantanea di picco).

La potenza di **generazione** non ha questo problema: è già dichiarata come campo `.kWp`
della struct `pvPlants`, quindi cresce insieme agli impianti e non richiede una tabella
parallela.

### 13.4 Punti minori da tenere d'occhio

- **Matrice di dominanza di Pareto** in `weighted_solidarity_cer.m`: è
  `nCombos × nCombos` (~13 MB con i default) e **non dipende da `n`** — resta invariata
  anche a 100 utenti. Cresce però col numero di combinazioni se si allargano i range dei
  coefficienti via `opts`.
- **`plot_benefit_network.m`**: dispone i giocatori su una circonferenza con
  un'etichetta ciascuno. A 100 nodi il grafico diventa illeggibile — servirà una
  visualizzazione aggregata o per gruppi.
- **`P_PV_NOM_KW`** (scaglione della tariffa TIP) è ancora uno scalare unico di
  comunità. Con molti impianti di taglia diversa la tariffa andrebbe valutata per
  impianto; ora che `pvPlants` porta il campo `.kWp`, il dato per farlo esiste già.
- **Generazione dei profili**: `simulation_config.yaml` scala aumentando `num_users` e
  `count`, ma i seed RAMP non sono riproducibili tra esecuzioni (vedi §11) — con 100
  profili la varianza tra run diventa più visibile nei risultati aggregati.
