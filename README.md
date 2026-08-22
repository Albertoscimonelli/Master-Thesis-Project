# Master-Thesis-Project — Analisi CER

Simulazione e analisi tecnico-economica di una **Comunità Energetica Rinnovabile (CER)**
italiana: generazione di profili di carico realistici, bilancio energia condivisa/venduta,
ripartizione dell'incentivo CER tra i membri con quindici modelli alternativi (teoria dei giochi
cooperativi, benchmark elementari, modelli dalla letteratura sulle REC italiane e chiavi
dinamiche di ripartizione dell'energia), costo dell'approvvigionamento da rete,
dimensionamento di un impianto fotovoltaico.

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
6. [I quindici modelli di ripartizione dei benefici](#6-i-quindici-modelli-di-ripartizione-dei-benefici)
7. [Indici di valutazione dell'equità](#7-indici-di-valutazione-dellequità)
8. [Dimensionamento impianto PV (standalone)](#8-dimensionamento-impianto-pv-standalone)
9. [Configurazione attuale (community di default)](#9-configurazione-attuale-community-di-default)
10. [Dipendenze e requisiti](#10-dipendenze-e-requisiti)
11. [Output prodotti](#11-output-prodotti)
12. [Limitazioni note / TODO](#12-limitazioni-note--todo)
13. [Documentazione aggiuntiva](#13-documentazione-aggiuntiva)
14. [Scaling a comunità grandi (~100 utenti): cosa va risolto prima](#14-scaling-a-comunità-grandi-100-utenti-cosa-va-risolto-prima)

---

## 1. Cosa fa il progetto

Un quartiere (uffici, piccola industria, negozio, famiglie) aderisce a una CER. Alcuni
membri hanno un impianto fotovoltaico (**prosumer**), altri no (**consumatori puri**).
Quando la produzione PV eccede l'autoconsumo del proprietario, il surplus viene condiviso
con il resto della comunità: sull'energia condivisa lo Stato eroga un incentivo (la
tariffa incentivante premio, **TIP_h**). Il progetto risponde a tre domande:

1. **Quanta energia si condivide e quanta si vende in rete?** (bilancio orario annuale)
2. **Come si ripartisce equamente l'incentivo tra i membri?** (quindici modelli a confronto,
   dalla teoria dei giochi cooperativi a semplici regole di buon senso, fino a modelli
   proposti in letteratura per le REC italiane e a chiavi dinamiche che ripartiscono
   l'energia ora per ora)
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
  la produzione PV, calcola il bilancio energetico, ripartisce i benefici con quindici modelli,
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
`MAIN.m` legge tutta la configurazione da [`CER_configuration/`](CER_configuration/)
(§9): la scheda della comunità — `CER_5_1_0.txt`, con membri, tariffe, impianti e
percorsi — più lo scenario economico che la scheda dichiara — `scenario_economico.txt`,
con prezzi, costi e soglie di povertà, gli stessi per tutte le CER. I percorsi sono
**relativi alla scheda**, quindi il progetto gira anche spostato di cartella o su
un'altra macchina, e per analizzare un'altra comunità si cambia scheda senza toccare il
codice. Richiede **Optimization Toolbox** (`linprog`, `quadprog`, `intlinprog`) per
Nucleolo e Variance Least Core.

[`CER_input.txt`](CER_input.txt) è la guida commentata alla compilazione: spiega sezione
per sezione cosa scrivere nelle due schede, e non viene letta da `MAIN.m`.

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
| `CER_configuration/` | **Schede dati lette da `MAIN.m`** — `CER_C_P_E.txt`, una per comunità (membri, categorie, tariffe, potenze, impianti, dati socio-economici, governance), e `scenario_economico.txt`, uno per tutte (prezzi, costi di investimento, soglie di povertà) (§9) |
| `CER_input.txt` | **Guida alla compilazione** — le stesse sezioni, spiegate riga per riga su una CER di esempio. Non viene letta da `MAIN.m` (§9) |
| `MAIN.m` | **Entry point MATLAB** — orchestra l'intera analisi energetico-economica. Non contiene dati |
| `load_cer_input.m`, `align_members_to_users.m` | Lettura e validazione della scheda; riordino dei membri sull'ordine delle colonne dei profili |
| `opts_from_config.m`, `rmfield_if.m` | Traduzione delle chiavi della scheda nei campi `opts` dei metodi, saltando quelle a `?` |
| `load_cer_data.m` | Caricamento profili + assegnazione impianti PV/autoconsumo (§5) |
| `load_zonal_price.m`, `compute_cer_incentive.m` | Prezzo zonale → tariffa incentivante oraria TIP_h |
| `cer_coalition_values.m` | Funzione caratteristica `v(S)` del gioco cooperativo, condivisa dai metodi 1-4 |
| `shapley_cer.m`, `nucleolus_cer.m`, `nash_bargaining_cer.m`, `variance_least_core_cer.m` | I quattro modelli di teoria dei giochi (§6) |
| `equal_split_cer.m`, `proportional_consumption_cer.m` | I due benchmark elementari (§6) |
| `remuneration_model1_cer.m`, `cascading_tree_cer.m`, `weighted_solidarity_cer.m` | I tre modelli dalla letteratura sulle REC italiane (§6) |
| `pearson_key_cer.m`, `pearson_sharing_key_cer.m` | Le due chiavi dinamiche di Gianaroli et al. — M3 e M5 (§6) |
| `similarity_utilization_cer.m` | Ripartizione giornaliera su similarità coseno × fattore di utilizzo (Bilardo 2025) (§6) |
| `marginal_contribution_cer.m`, `stratified_expected_value_cer.m`, `adaptive_sampling_shapley_cer.m` | Le tre **approssimazioni dello Shapley** di Cremers et al. 2023 — non regole nuove, ma lo stesso valore a costo polinomiale (§6) |
| `tri_level_ep_cer.m` | Ripartizione **tri-livello** proprietà + proporzionale + povertà energetica LIHC (Campagna et al. 2024) (§6). ⚠ **Provvisorio**: gira su dati segnaposto, 11 ipotesi attive nel registro dell'header |
| `lihc_index.m` | Indice di povertà energetica **LIHC** (Low Income High Cost), booleano e continuo — calcolatore puro, riusabile |
| `fairness_indicators_lem.m` | I sette indicatori di equità distributiva di Dynge & Cali 2025 — MinMax, QoS, EI (originali e riformulati) su **una** ripartizione (§7) |
| `fairness_index_bm.m` | **Fairness Index** di Casalicchio et al. 2022: distanza di ciascun metodo dalla distribuzione per contributo `v(N) − v(N∖{i})` (§7) |
| `coalition_excess.m` | **Eccesso di coalizione** di Volpato et al. 2024 (eq. 23): quali sottogruppi guadagnerebbero di più uscendo dalla CER — l'unico indicatore di **stabilità** (§7) |
| `gini_index.m`, `jain_index.m` | I due nuclei degli indicatori sopra (`EI = 1 − Gini`, `QoS = Jain`), esposti a sé stanti e condivisi anche da `weighted_solidarity_cer.m` |
| `gini_heterogeneity.m` | Gini di **eterogeneità** della composizione della comunità (Casalicchio eq. 10) — non è un Gini di reddito |
| `plot_fairness_indicators.m` | Mappa di calore metodi × indicatori di equità (§7) |
| `pearson_hourly_key.m`, `sharing_rate_key.m`, `normalize_key_rows.m`, `allocate_shared_energy.m` | Helper condivisi dalle chiavi dinamiche: pesi di Pearson, sharing rate, normalizzazione oraria, ripartizione iterativa con cap al consumo |
| `cer_shared_value.m` | Helper condiviso dalle tre approssimazioni: `v` di **una** coalizione dai profili aggregati, `O(H)` invece di `O(H·2ⁿ)` |
| `report_allocation.m`, `method_color.m`, `plot_allocation_comparison.m`, `plot_benefit_network.m` | Reporting e grafici condivisi da tutti e quindici i modelli |
| `plot_cer_energy.m`, `plot_pv_vs_demand.m`, `plot_load_profiles.m` | Grafici energetici (mensili, annuali, profili tipo) |
| `profilo_prezzi_pun_2025.m` | Prezzi PUN 2025 per 3 modalità tariffarie (costo da rete, §4) |
| `optimizer_PV.m`, `irr_bisection.m` | Dimensionamento impianto PV (standalone, §8) |
| `archive/` | Codice superato mantenuto per riferimento storico (`PROVA_PV.m`, `merge_pv_owner.m`) |
| `GUIDA_modelli_distribuzione.md` | Derivazione matematica completa dei quindici modelli di ripartizione |
| `STRUTTURA_PROGETTO.txt` | Mappa dettagliatissima di ogni file/funzione/CSV del progetto |
| `AUDIT_REPORT.md` | Audit del codice — bug noti e possibili miglioramenti (2026-07-10) |

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

Questo bilancio (con `P_CER_h`) è l'input di **tutti e quindici** i modelli di ripartizione:
```
v(S) = Σ_t min( Σ_{i∈S} gen_i(t), Σ_{i∈S} load_i(t) ) · P_CER_h(t)
```
è la **funzione caratteristica** del gioco cooperativo (`cer_coalition_values.m`), e
`v(N)` (l'intera comunità) è il totale che i quindici modelli si dividono in modo diverso.

## 6. I quindici modelli di ripartizione dei benefici

L'incentivo CER `v(N)` viene ripartito tra i giocatori secondo quindici modelli,
tutti calcolati in `MAIN.m` (§3b-§3p) e confrontati in tabella e grafico (§3r). Firma comune:
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
| 7 | **Remuneration Model 1** | `remuneration_model1_cer.m` | Split α/β tra classe consumatori e classe produttori/prosumer, pesato sulla **potenza contrattuale/nominale** [kW] di ciascuna classe (dato manuale, vedi §9); dentro ogni classe, proporzionale all'energia oraria (Candela et al. 2022) | N/A (non è un gioco) |
| 8 | **Cascading Tree** | `cascading_tree_cer.m` | L'incentivo si scompone ricorsivamente in un **albero di categorie** (riserva → fissa/variabile → prelievi/immissione → produttori+prosumer/soli prosumer), con pesi di ramo di default (scelte di governance) (Trevisan et al. 2022) | N/A (non è un gioco) |
| 9 | **Weighted Solidarity** | `weighted_solidarity_cer.m` | Peso orario = componente tecnica (energia condivisa + carico) + componente di **solidarietà** (costo unitario dell'energia, proxy povertà energetica); i coefficienti sono scelti su un **fronte di Pareto** (Gini minimo vs reddito medio degli utenti a rischio povertà energetica) (Marrasso et al. 2025) | N/A (non è un gioco) |
| 10 | **Pearson Key** | `pearson_key_cer.m` | Chiave dinamica M3: ripartisce **l'energia** ora per ora in proporzione alla **correlazione di Pearson giornaliera** tra il consumo dell'utente e l'immissione della comunità (premia il sincronismo), con cap al consumo; solo alla fine la si valorizza con `P_CER_h` (Gianaroli et al. 2024) | N/A (non è un gioco) |
| 11 | **Pearson-Sharing Rate** | `pearson_sharing_key_cer.m` | Chiave dinamica M5: combinazione pesata `α`/`β` della chiave di Pearson (M3) e dello **sharing rate** (M4), che penalizza chi in un'ora consuma più di quanto la comunità immetta (Gianaroli et al. 2024, eq. 7) | N/A (non è un gioco) |
| 12 | **Similarity-Utilization** | `similarity_utilization_cer.m` | Ripartizione **giornaliera** proporzionale alla "virtuosità energetica" `f = θ·η`: `θ` è la similarità **coseno** tra profilo di carico del membro e generazione della comunità (premia la sincronia, ignora le quantità), `η = min(1, E_gen/E_load)` penalizza chi consuma più di quanto la comunità produca (Bilardo 2025) | N/A (non è un gioco) |
| 13 | **Marginal Contribution** | `marginal_contribution_cer.m` | *Approssimazione dello Shapley*, `O(n)`: tiene **un solo** contributo marginale, l'ultimo — `MC_i = v(N) − v(N\{i})` — poi normalizzato a `v(N)` (Cremers et al. 2023, eq. 9-10) | approssima il metodo 1 |
| 14 | **Stratified Expected Value** | `stratified_expected_value_cer.m` | *Approssimazione dello Shapley*, `O(n²)` e **deterministica**: stima il contributo marginale di **ogni strato** con una sola valutazione di `v` su copie di un utente fittizio **medio** (Cremers et al. 2023, eq. 11-13). È il metodo nuovo proposto dal paper — ⚠ ma sui nostri dati è il **meno** accurato dei tre, vedi sotto | approssima il metodo 1 |
| 15 | **Adaptive Sampling Shapley** | `adaptive_sampling_shapley_cer.m` | *Approssimazione dello Shapley*, `O(n·M)` e **stocastica**: campiona `M` coalizioni per giocatore, concentrando i campioni sugli strati a varianza più alta (O'Brien et al. 2015, App. C di Cremers et al.) | approssima il metodo 1 |
| 16 | **Tri-level EP** | `tri_level_ep_cer.m` | Tre livelli sovrapposti: una quota `min(33%, 1,32%·N_vu)` va ai soli membri in **povertà energetica** (indice LIHC, `lihc_index.m`); il resto si divide fra criterio **proporzionale** al consumo orario (finanziato dal ricavo di energia condivisa) e criterio di **proprietà** (finanziato dal ricavo di vendita), con pesi pari al rapporto fra i due ricavi (Campagna et al. 2024, eq. 11-15). ⚠ **Provvisorio**, 11 ipotesi attive — vedi sotto | N/A (non è un gioco) |

I metodi 1-4 sono giochi cooperativi a utilità trasferibile e condividono la stessa
`v(S)` (`cer_coalition_values.m`), tranne il VLC che la valuta su richiesta per restare
scalabile — come fanno anche i metodi 13-15, tramite l'helper `cer_shared_value.m`.

> ⚠ **Il metodo 16 è provvisorio e non va usato per produrre risultati.**
> `tri_level_ep_cer.m` gira su **dati segnaposto** (reddito delle famiglie, spesa
> gas, markup dal PUN al prezzo di bolletta, mediana nazionale della spesa
> energetica): undici ipotesi sono attive per difetto. Sono elencate nel registro
> in testa alla funzione (`help tri_level_ep_cer`), marcate nel codice come
> `[IPOTESI n]` (`grep -n IPOTESI tri_level_ep_cer.m`) e **stampate a ogni
> esecuzione**, ma solo quelle ancora in vigore: un'ipotesi sparisce dall'elenco
> appena il dato vero viene passato via `opts`. La stessa lista è esposta come
> `S.assumptions`.
>
> Il metodo 16 è anche l'unico che ripartisce **entrambi** i montepremi (energia
> condivisa *e* vendita in rete), perché il suo livello di proprietà redistribuisce
> proprio il ricavo di vendita: `vGrand = v(N) + ricavo di vendita`, non `v(N)`.
> Nella tabella di confronto e nel grafico entra quindi `phiFromShared`, che somma
> esattamente a `v(N)`; il totale sui due montepremi resta in `phi`.
>
> **Sui nostri dati il ricavo di vendita (≈4.655 €) è quasi il doppio di quello da
> energia condivisa (≈2.349 €)**: il livello di proprietà pesa perciò il 66% del
> montepremi e va interamente a `small_industry_1`, unico proprietario
> dell'impianto. È il primo numero da rileggere quando arriveranno i dati veri.
I metodi 5-12 **non** usano teoria dei giochi (né passano da
`cer_coalition_values.m`: calcolano `v(N)` direttamente) — servono da **termine di
paragone** per misurare quanto i modelli 1-4 se ne discostino (es. quanto lo Shapley
premi la produzione rispetto a una ripartizione puramente proporzionale al consumo, o
quanto un criterio di equità sociale come quello di Marrasso sposti valore verso gli
utenti più vulnerabili). Il **Cascading Tree** è l'unico i cui parametri (`opts`)
possono far sì che `vGrand` sia inferiore a `v(N)` (se si trattiene una riserva) — con i
default usati in `MAIN.m` questo non accade.

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
forma della curva, non i kWh). Il risultato è marcatamente più piatto degli altri —
le famiglie ricevono 3-5× quanto darebbero i modelli 10-11 a parità di consumi. Con i
profili netti (default del progetto) anche qui il prosumer riceve `0`; il paper usa
invece i profili **lordi**, e con quelli riceverebbe la quota maggiore di tutte: è la
scelta di modello più impattante del metodo, commutabile via `opts` senza toccare il
codice ([GUIDA §15.3](GUIDA_modelli_distribuzione.md)).

I modelli **13-15 sono di natura ancora diversa: non propongono un criterio di equità
alternativo, ma approssimano il metodo 1**. Servono perché lo Shapley esatto costa `O(2ⁿ)`
e diventa irrealizzabile oltre ~20 giocatori — sono cioè, insieme al VLC, la risposta della
letteratura al bloccante di [§14.1](#141-tre-modelli-diventano-matematicamente-impossibili--bloccante).
Vanno quindi giudicati sull'**errore**, non sull'equità: con `n = 6` lo Shapley esatto è
disponibile come *ground truth*, e `MAIN.m` §3q ne misura lo scarto (eq. 16-17 del paper).

> ⚠ **Risultato: la graduatoria del paper si rovescia.** Scarto medio dallo Shapley esatto
> sui dati del progetto: **Marginal Contribution 1,07%**, **Adaptive Sampling 1,52%**,
> **Stratified Expected Value 21,98%** — mentre nel paper è quest'ultima la più accurata.
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
> solo. Con la nostra topologia (un impianto, un proprietario, cinque consumatori puri) i
> cinque consumatori riceverebbero quote **identiche** a prescindere dai loro profili, e
> tre input su quattro sarebbero inventati. Le formule sono state comunque riprodotte
> esattamente sul caso studio del paper: la rinuncia è di modello, non tecnica. Ragioni per
> esteso, numeri e condizioni per riprenderli in
> [GUIDA — Appendice A.1](GUIDA_modelli_distribuzione.md).

## 7. Indici di valutazione dell'equità

I sedici modelli di §6 dicono **quanto** prende ciascuno; questa sezione dice **quale
ripartizione sia più equa**, e rispetto a quale definizione di equità. Dieci indicatori,
calcolati in `MAIN.m` §3t su tutti e sedici i metodi, da due articoli:

| Indicatore | Eq. | File | Cosa misura | Verso |
|---|---|---|---|:---:|
| **MinMax originale** | 11 | `fairness_indicators_lem.m` | min/max del prelievo da rete | 1 = equo |
| **MinMax prosumer** | 16 | " | min/max della quota di surplus condivisa | 1 = equo |
| **MinMax consumer** | 17 | " | min/max del volume di condivisa ricevuto | 1 = equo |
| **QoS originale** | 12 | " | indice di **Jain** sui volumi scambiati | 1 = equo |
| **QoS nuovo** | 18 | " | `ρ·Jain`(quote prosumer) + `μ·Jain`(volumi consumer) | 1 = equo |
| **EI originale** | 15 | " | `1 −` **Gini** dei risparmi | 1 = equo |
| **EI nuovo** | 19 | " | `ρ·(1−Gini` risparmi *relativi*`) + μ·(1−Gini` risparmi`)` | 1 = equo |
| **Gini di eterogeneità** | 10 | `gini_heterogeneity.m` | varietà delle tipologie di membro (**non** un Gini di reddito) | — |
| **Fairness Index** + σ | 12-14 | `fairness_index_bm.m` | distanza dalla distribuzione per **contributo** `BCᵢ = v(N) − v(N∖{i})` | 0 = equo |
| **Eccesso di coalizione** | 23 | `coalition_excess.m` | se qualche sottogruppo guadagnerebbe di più **uscendo** dalla CER | ↓ = stabile |

Fonti: Dynge, Cali, *Distributive energy justice in local electricity markets*, Appl.
Energy 384 (2025) 125463 (eq. 11-19); Casalicchio, Manzolini, Prina, Moser, *From
investment optimization to fair benefit distribution in renewable energy community
modelling*, Appl. Energy 310 (2022) 118447 (eq. 10, 12-14); Volpato, Carraro, Dal Cin,
Rech, *On the Different Fair Allocations of Economic Benefits for Energy Communities*,
Energies 17 (2024) 4788 (eq. 23). Derivazioni, mappatura formula → codice e avvertenze in
[GUIDA §18](GUIDA_modelli_distribuzione.md).

**Gini e Jain sono esposti a sé stanti** oltre che dentro EI e QoS: sono le grandezze con
cui ragiona la letteratura, e tenerle implicite le renderebbe inutilizzabili.

### 7.0 Tre domande diverse, non tre modi di misurare la stessa cosa

| Gruppo | Domanda a cui risponde |
|---|---|
| MinMax, QoS, EI, Gini, Jain | quanto è **uniforme** la ripartizione |
| Fairness Index, σ | quanto è vicina al **merito** di ciascuno |
| Eccesso di coalizione | se **regge**, cioè se un sottogruppo ha convenienza a uscire |

Le tre domande possono dare risposte **opposte**, ed è il caso: l'**Equal Split** è primo
sulla prima (`EI = 1.00`, `Gini = 0.00` — per quegli indici è la ripartizione più equa
possibile) e **ultimo** sulla terza (eccesso `+606 €`, nove sottogruppi vorrebbero
uscire). Il **Nucleolo** fa l'opposto: `EI = 0.45`, il peggiore del lotto, ma è l'unico
insieme al Variance Least Core a garantire che nessuno voglia andarsene. Guardare una
colonna sola porta a conclusioni sbagliate.

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
3. **Il MinMax originale è identico per tutti e sedici i metodi**: i flussi fisici di una
   CER non cambiano al cambiare di chi prende i soldi. È la versione estrema della critica
   che il paper stesso muove all'indicatore.
4. **Anche `MinMax_con`, `QoS` e `Jain` variano pochissimo fra i metodi.** Sulla community
   di default solo l'**8.7%** dell'energia condivisa è *contendibile*: nel restante 91.3%
   l'immissione copre l'intero carico residuo e ogni utente riceve esattamente il proprio
   consumo, qualunque sia la chiave. Con `contendibleShare` così basso, gli indicatori
   **energetici** descrivono la comunità più che il metodo — a discriminare sono quelli
   **economici** (EI, Gini, Fairness Index).

`MAIN.m` §3t stampa `contendibleShare` a ogni esecuzione, proprio perché le colonne
quasi costanti non vengano scambiate per un errore di calcolo.

### 7.3 Verifiche automatiche

`MAIN.m` §3t contiene sette `assert` che valgono come test di regressione:

- **Equal Split ⇒ `EI_orig = 1`** esatto (il Gini di un vettore uniforme è zero).
- **Marginal Contribution ⇒ `FI = 0`** esatto, perché la normalizzazione dell'eq. 10 di
  Cremers *coincide* con l'eq. 13 di Casalicchio. (Se qualche `BCᵢ = 0`, il metodo cade
  nella branca intera e l'assert verifica quella.)
- **MinMax originale identico** fra i sedici metodi.
- **L'energia implicita somma all'energia condivisa** di comunità.
- **Eccesso del Nucleolo `= −Nu.thetaMin`** e **del VLC `= −VLC.thetaLC`**: sono la stessa
  grandezza con il segno opposto (il Nucleolo riporta il *surplus* della coalizione più
  scontenta, `Σxᵢ − v(S)`). Verifica gratis che l'eccesso giri sulla stessa `v(S)` del gioco.
- **Il Nucleolo ha l'eccesso minimo** fra i sedici — è ciò che minimizza per costruzione.
- Tutti gli indicatori di Dynge **dentro `[0,1]`**.

Inoltre `fairness_index_bm.m` ha un auto-test analitico (`opts.validateSelf`, attivo di
default): la Tab. 7 del paper **non** è riproducibile — i `Dᵢ` per membro stanno solo in un
grafico — quindi si verifica la formula su casi costruiti a penna, contributi negativi
inclusi.

## 8. Dimensionamento impianto PV (standalone)

`optimizer_PV.m` non fa parte della pipeline di `MAIN.m`: è uno script indipendente che
ottimizza il layout di un impianto fotovoltaico su copertura industriale (numero di
inverter, tilt, distanza inter-fila), simulando ora per ora produzione DC/AC e bilancio
economico (CAPEX, OPEX, ricavi, IRR via `irr_bisection.m`, NPV) per selezionare la
configurazione che massimizza IRR o NPV. `archive/PROVA_PV.m` è la versione precedente,
mantenuta come riferimento storico.

## 9. Le schede dati (`CER_configuration/`)

Tutta la configurazione sta in **file di testo**, letti da `load_cer_input.m`. `MAIN.m`
non contiene dati: per analizzare un'altra CER si cambia scheda, non il codice.

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

Nessuno dei due ha commenti — la CER di esempio sta in 41 righe, lo scenario in 28 — e
sono pensati per essere stampati come appendice di tesi.
[`CER_input.txt`](CER_input.txt) è la **guida alla compilazione**: le stesse sezioni con
gli stessi dati, ma spiegate riga per riga. Non viene letta da `MAIN.m`, e infatti tiene
dentro tutte e nove le sezioni senza dichiarare nessuno scenario.

**Formato:** sezioni `[NOME]`, righe `chiave = valore`, tabelle a `|` (la prima riga è
l'intestazione), commenti con `#`.

**Le due forme di dato mancante, che non sono la stessa cosa:**

| | Significato | Effetto |
|---|---|---|
| `-` | **non applicabile** — il reddito di un ufficio non manca, non esiste | `NaN`, nessuna conseguenza |
| `?` | **non ancora noto** | il campo **non** viene passato al metodo, che applica il proprio default e **lo dichiara** come ipotesi attiva in `S.assumptions` |

È il meccanismo che tiene onesto il registro delle ipotesi: riempire un `?` con un dato
vero toglie una riga da quel registro, scriverci il valore che il modello userebbe
comunque la toglierebbe senza che nulla sia stato verificato. Sulla community di default
tutte le colonne socio-economiche sono a `?`, e le 11 ipotesi del Tri-level EP restano
tutte attive; compilandole scendono a 3 — le sole tre che sono correzioni dichiarate
(ipotesi 6, 7, 9) e non dati mancanti.

**Le sezioni.** Le tre marcate *scenario* stanno in `scenario_economico.txt`, le altre
sei nella scheda della comunità.

| Sezione | Contenuto |
|---|---|
| `[CER]` | nome, comune, zona di mercato, cabina primaria, anno, griglia oraria |
| `[RIEPILOGO]` | conteggi e potenza installata **dichiarati**. Non è una fonte di dati: il loader li ricalcola dalle tabelle e si ferma se non tornano |
| `[FILE]` | percorsi **relativi** alla scheda (profili di carico, prezzi zonali, cartella PV) e la chiave `scenario_economico`, che dichiara il file dello scenario |
| `[MERCATO]` | *scenario* — prezzo di vendita, markup retail, prezzo gas, parametri della tariffa TIP |
| `[INVESTIMENTO]` | *scenario* — WACC, vita utile, costi specifici CAPEX/OPEX. **Trasportati, non ancora usati**: `MAIN.m` si ferma al flusso di cassa annuo |
| `[POVERTA_ENERGETICA]` | *scenario* — soglie dell'indice LIHC e taratura della quota di solidarietà |
| `[GOVERNANCE]` | scelte deliberate dalla CER: pesi del Cascading Tree, α della Pearson-Sharing, M e seed dell'Adaptive Sampling |
| `[MEMBRI]` | **una riga per membro**: nome della colonna nel CSV, ruolo (C/P/E), categoria, archetipo, tariffa, potenza impegnata, componenti e percettori, reddito, gas, quota di investimento, mutuo, impianto posseduto |
| `[IMPIANTI]` | **una riga per impianto**: proprietario, kWp, export PVsyst, tilt/azimut, CAPEX/OPEX |

**Community di default:** 6 membri (`office_1`, `small_industry_1`, `retail_1`,
`household_1..3`), 1 impianto da 20 kWp su `small_industry_1_kWh`, anno 2025, zona Nord,
`prezzo_vendita = 0.110 €/kWh`. I profili orari si rigenerano da
`CER_LoadProfiles/config/simulation_config.yaml`: la scheda **descrive** i membri, non li
crea, e `align_members_to_users.m` si ferma elencando tutti i disallineamenti fra le due
liste.

**Tariffa per utente.** La spesa annua di ciascun membro non si dichiara: si ottiene
incrociando la sua `tariffa` con il proprio profilo di carico. È la colonna `Effettivo`
di `Tcost` (§11) ed è la baseline `y_noLEM` degli indicatori di equità — prima si
assumeva la monoraria per tutti.

**Due valori ora derivati invece che scritti a mano.** Se `tip_potenza_rif_kW` è `?`, lo
scaglione della tariffa TIP usa la potenza installata totale di `[IMPIANTI]`, che si
aggiorna da sola; se `tip_fattore_riduzione` è `?`, non si applica riduzione.

## 10. Dipendenze e requisiti

**Python 3.12** (venv in root): `rampdemand` 0.5.0, `pyloadprofilegenerator`, `pandas`
3.0.x, `numpy` 2.4.x, `PyYAML`. RAMP 0.5.0 non è ancora compatibile nativamente con
numpy 2 / pandas 3: `ramp_runner.py` applica due monkey-patch a runtime (rimovibili
quando RAMP verrà aggiornato). Vedi `requirements.txt` (freeze completo) e
`CER_LoadProfiles/requirements.txt` (dipendenze dirette).

**MATLAB:** base + **Optimization Toolbox** (`linprog`, `quadprog`, `intlinprog`,
richiesti da Nucleolo e Variance Least Core). `irr_bisection.m` evita la dipendenza dalla
Financial Toolbox per il calcolo dell'IRR in `optimizer_PV.m`.

## 11. Output prodotti

**Stadio Python** → `CER_LoadProfiles/outputs/csv/`: `profili_aziende.csv`,
`profili_famiglie.csv`, `profili_tutti.csv` (input di `MAIN.m`), `profilo_CER_aggregato.csv`.
CSV orari, separatore virgola, timestamp ISO8601, ~8760 righe.

**Stadio MATLAB** (`MAIN.m`), a schermo e in tabelle/figure:
- `Treport` — riepilogo mensile/annuale energia condivisa, venduta, ricavi.
- Report testuale + grafico a barre + grafico a rete per ciascuno dei quindici modelli di
  ripartizione (§6).
- `Trd` — accuratezza delle tre approssimazioni dello Shapley rispetto al valore esatto
  (§3q, eq. 16-17 di Cremers et al.).
- `Tcmp` — tabella di confronto tra i quindici modelli + grafico a barre raggruppate.
- `Tfair` — i dieci **indici di equità** per ciascun metodo + mappa di calore a tre
  pannelli (uniformità / merito / stabilità), più il registro delle ipotesi attive, la
  distribuzione per contributo e la classifica di stabilità con la coalizione peggiore di
  ciascun metodo (§3t, §7). Stampa anche `contendibleShare`, cioè quanta energia condivisa
  è davvero in palio fra i metodi.
- `Tcost` — costo annuo di approvvigionamento da rete per utente, nelle 3 modalità
  tariffarie PUN (monoraria, bioraria, oraria variabile), calcolato in §3a, più la
  tariffa che ciascun membro ha davvero e la colonna `Effettivo` con la spesa che ne
  risulta.
- Il riepilogo della scheda dati con l'elenco dei campi ancora a `?` (§9), stampato per
  primo da `load_cer_input`.
- Grafici energetici: andamento mensile CER, PV vs domanda, profili di consumo tipo.

## 12. Limitazioni note / TODO

- **I dati mancanti sono ora elencati dal codice, non da questa lista.** `load_cer_input`
  stampa a ogni esecuzione i campi della scheda ancora a `?`, e ciascun metodo stampa le
  proprie ipotesi attive. Le voci qui sotto restano perché spiegano *perché* un dato è
  difficile, non per tenerne il conto: quello si legge dall'output.
- `tip_fattore_riduzione` (fattore F della formula TIP) **non è ancora definito per
  intero**: finché la scheda lo lascia a `?`, nessuna riduzione viene applicata.
- Lo scaglione della tariffa TIP usa la **potenza installata totale**. Con impianti di
  taglia molto diversa andrebbe valutato per impianto; ora che `[IMPIANTI]` porta il kWp
  di ciascuno, il dato per farlo esiste già (§14.4).
- Le potenze usate da Remuneration Model 1 restano **da confermare**: potenza di prelievo
  in `[MEMBRI].P_prel_kW`, potenza di generazione in `[IMPIANTI].kWp`. Hanno impatto di
  primo ordine sul risultato — con una potenza sola al posto di due, i pesi α/β
  passerebbero da 0.81/0.19 a 0.63/0.37 e il prosumer riceverebbe quasi il doppio
  ([GUIDA §10.6](GUIDA_modelli_distribuzione.md)).
- **I costi di investimento sono dichiarati ma non usati.** `[INVESTIMENTO]` e le colonne
  `capex_EUR` / `quota_inv_EUR` sono lette e validate, ma `MAIN.m` si ferma al flusso di
  cassa annuo: non calcola NPV, IRR né payback. È anche la ragione dell'ipotesi 3 di
  `fairness_index_bm` ("costi di investimento per membro ASSENTI: `D_i` calcolato sui
  benefici LORDI"), che resta attiva finché quei campi non alimentano un calcolo.
- **Weighted Solidarity — la componente di solidarietà è un proxy debole.** Il modello
  di Marrasso classifica gli utenti "a rischio povertà energetica" dal costo unitario
  in bolletta `Cu`; nel paper quel dato viene da bollette reali e varia di ~4× tra i
  membri, mentre qui è derivato dal solo prezzo PUN e varia del **2,9%**. La logica è
  implementata fedelmente, ma la classificazione risultante riflette la collocazione
  oraria dei consumi, **non** una reale vulnerabilità economica — e la ripartizione è
  in larga parte guidata da quella classificazione
  ([GUIDA §12.7](GUIDA_modelli_distribuzione.md)). Servono dati di bolletta o ISEE
  reali per usare seriamente questo metodo.
- **Chiavi dinamiche (Pearson Key, Pearson-Sharing Rate) — due avvertenze.** (a) Sono
  chiavi guidate dal **consumo**: il proprietario dell'impianto riceve `0`, perché il suo
  carico residuo è nullo proprio nelle ore di eccedenza (vedi §6). È il comportamento
  atteso dato il modello di autoconsumo del progetto, non un bug, ed è lo stesso del
  Proportional to Consumption. (b) L'eq. 5 del paper (sharing rate) contiene un **refuso**:
  le due espressioni sono associate alle condizioni invertite rispetto alla Fig. 3, al
  testo e all'esempio numerico dell'articolo. L'implementazione segue questi ultimi
  (`SR = ratio` sotto 1, esponenziale decrescente sopra) e ne **riproduce esattamente**
  i risultati (Fig. 7-9); la lettura letterale resta disponibile con
  `opts.sharingRateMode = "eq5"`
  ([GUIDA §14.2 e §14.7](GUIDA_modelli_distribuzione.md)). (c) **Sulla community
  provvisoria di oggi M3 e M5 danno quasi lo stesso risultato** (scarto < 1%): non perché
  le chiavi coincidano, ma perché il 91% dell'energia cade nel caso banale e il cap
  assorbe il resto — manca chi sovraconsuma, l'unico caso in cui lo sharing rate morde.
  **Da ricontrollare sui dati reali**: la nota in
  [GUIDA §14.6](GUIDA_modelli_distribuzione.md) elenca i tre indicatori da ricalcolare.
- I seed RAMP non sono bit-per-bit riproducibili tra esecuzioni diverse (`hash()` su
  stringhe è salato per processo in Python) — vedi
  [STRUTTURA_PROGETTO.txt §3.2](STRUTTURA_PROGETTO.txt).
- `optimizer_PV.m` non è integrato nella pipeline di `MAIN.m` ed è pensato per test
  occasionali, non per l'uso corrente della community.
- Per l'elenco completo di bug noti e miglioramenti proposti vedi
  [AUDIT_REPORT.md](AUDIT_REPORT.md) (audit del 2026-07-10, review-only).

## 13. Documentazione aggiuntiva

| Documento | Quando consultarlo |
|---|---|
| [STRUTTURA_PROGETTO.txt](STRUTTURA_PROGETTO.txt) | Serve il dettaglio di un file/funzione specifico, o la mappa completa di cartelle e CSV |
| [GUIDA_modelli_distribuzione.md](GUIDA_modelli_distribuzione.md) | Serve la derivazione matematica, gli assiomi o la mappatura formula→codice di uno dei quindici modelli di ripartizione |
| [AUDIT_REPORT.md](AUDIT_REPORT.md) | Serve un elenco di bug noti / debito tecnico (audit 2026-07-10, non aggiornato con modifiche successive) |
| [CER_LoadProfiles/README.md](CER_LoadProfiles/README.md) | Serve il dettaglio del pacchetto Python di generazione profili |

## 14. Scaling a comunità grandi (~100 utenti): cosa va risolto prima

Il progetto è oggi calibrato su **6 utenti**. È previsto di testare i modelli fino a
**~100 utenti**: questa sezione elenca i punti che si romperanno o degraderanno a quella
scala, così da affrontarli consapevolmente invece di scoprirli a metà lavoro. Nessuno di
questi è un problema *oggi* — sono tutti conseguenze della crescita di `n`.

### 14.1 Tre modelli diventano matematicamente impossibili — BLOCCANTE

**Shapley**, **Nucleolo** e **Nash Bargaining** passano da `cer_coalition_values.m`, che
enumera **2^n** coalizioni. Con `n = 100` significa ~10³⁰ valori: non è un problema di
lentezza, è irrealizzabile su qualsiasi hardware. `shapley_cer.m` emette già un warning
sopra i 20 giocatori; oltre quella soglia `MAIN.m` §3b fallirebbe in allocazione di
memoria.

**Per lo Shapley la via d'uscita è già in repo (metodi 13-15, §6).** Le tre
approssimazioni di Cremers et al. sono state introdotte esattamente per questo: valutano
`v` su richiesta (`cer_shared_value.m`) e costano `O(n)`, `O(n²)` e `O(n·M)` invece di
`O(2ⁿ)`. A `n = 100` sono rispettivamente ~100, ~20 000 e ~200 000 valutazioni, contro
`10³⁰`. Con `n = 6` il loro errore rispetto allo Shapley esatto è già misurato
(`MAIN.m` §3q) — e il risultato **va letto prima di affidarsi a loro su larga scala**:

| Metodo | Costo | Scarto medio dallo Shapley esatto |
|---|---|---:|
| Marginal Contribution | `O(n)` | 1,07% |
| Adaptive Sampling | `O(n·M)` | 1,52% |
| Stratified Expected Value | `O(n²)` | **21,98%** ⚠ |

La SEV non è utilizzabile con l'attuale topologia (un solo prosumer pivotale, vedi §6 e
[GUIDA §16.8](GUIDA_modelli_distribuzione.md)); potrebbe però tornare la migliore proprio
a `n` grande, se l'espansione porterà **più impianti distribuiti fra i membri** — è la
condizione da ricontrollare, non un verdetto definitivo. Restano poi le due vie d'uscita
classiche, complementari a queste:
- **Raggruppamento per archetipo** — è la scelta di Moncecchi et al. (il paper di
  riferimento dello Shapley) che gestisce 131 utenti calcolando il valore su pochi
  *gruppi* e ripartendolo poi internamente in proporzione al consumo. Il docstring di
  `shapley_cer.m` già menziona questa approssimazione come non necessaria a `n` piccolo.
  Aprirebbe anche la strada al calcolo **esatto per `K` classi** di Cremers et al. §4.2,
  oggi inerte perché i sei profili reali sono tutti diversi
  ([GUIDA §16.10](GUIDA_modelli_distribuzione.md)).
- **Campionamento Monte Carlo** delle permutazioni per lo Shapley (stimatore standard).

Restano invece scoperti **Nucleolo e Nash Bargaining**, che passano ancora da
`cer_coalition_values.m` e per i quali il progetto non ha oggi un'alternativa scalabile.

Il **Variance Least Core non ha questo problema**: la row-generation è nata esattamente
per comunità da decine o centinaia di membri e valuta `v(K)` solo sulle poche coalizioni
vincolanti. Gli otto metodi non cooperativi (Equal Split, Proportional to Consumption,
Remuneration Model 1, Cascading Tree, Weighted Solidarity, Pearson Key,
Pearson-Sharing Rate, Similarity-Utilization) sono tutti `O(H·n)` e scalano senza
modifiche — le due chiavi
dinamiche hanno un ciclo sulle 8760 ore con al più `n` iterazioni interne, quindi
`O(H·n²)` nel caso peggiore (tutti gli utenti cappati uno alla volta): a 100 utenti
restano nell'ordine dei secondi.

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
- **Scaglione della tariffa TIP**: è ancora uno scalare unico di comunità (la potenza
  installata totale, o `tip_potenza_rif_kW` se dichiarato). Con molti impianti di taglia
  diversa la tariffa andrebbe valutata per impianto; ora che `[IMPIANTI]` porta il kWp di
  ciascuno, il dato per farlo esiste già.
- **Generazione dei profili**: `simulation_config.yaml` scala aumentando `num_users` e
  `count`, ma i seed RAMP non sono riproducibili tra esecuzioni (vedi §12) — con 100
  profili la varianza tra run diventa più visibile nei risultati aggregati.
