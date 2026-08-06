clear; clc;
close all;

%% ========================================================================
%  MAIN.m  -  Analisi energetica ed economica della CER
%
%  Pipeline:
%    0) Configurazione (percorsi, costanti, flag)
%    1) Caricamento dati      (profili di carico + generazione PV)
%    2) Elaborazione CER      (richiesta totale, energia condivisa, venduta)
%    3) Analisi economica     (ricavi mensili e annuali, tabella riepilogo)
%   3b-3l) Ripartizione dei benefici con undici modelli di ripartizione
%    3m) Confronto tra i modelli
%    4) Costo energia da rete (PUN 2025, per utente e per modalita)
%    5) Visualizzazione       (istogrammi, profili, confronti)
%
%  Questo file e' un ORCHESTRATORE: coordina i passi e commenta le scelte di
%  modello, ma delega il lavoro agli helper (load_cer_data, report_allocation,
%  plot_*). Le sezioni restano indipendenti e facili da estendere.
%  ========================================================================


%% ========================================================================
%  0) CONFIGURAZIONE
%  ========================================================================

% --- Percorsi file -------------------------------------------------------
loadFile = "C:\Users\scimo\desktop\Project\CER_LoadProfiles\outputs\csv\profili_tutti.csv";


pvFile   = "C:\Users\scimo\desktop\Project\PV_Generation\Salvaplast_Project_VD7_HourlyRes_1.CSV";

zonalPriceFile = "C:\Users\scimo\desktop\Project\20250101_20251231_MGP_PrezziZonali_Nord.xlsx";

% --- Costanti temporali --------------------------------------------------
ANNO    = 2025;
N_HOURS = 8760;          % ore in un anno standard (24 x 365)
N_DAYS  = 365;

% Griglia oraria canonica dell'anno (asse di riferimento per tutti i dati)
tGrid = (datetime(ANNO,1,1,0,0,0) : hours(1) : datetime(ANNO,12,31,23,0,0)).';

% --- Parametri economici -------------------------------------------------
P_SELL = 0.11;           % Prezzo energia venduta in rete        [€/kWh]

% Incentivo CER su energia condivisa: tariffa incentivante premio (TIP)
% oraria (eq. 3.1), calcolata in §1b da compute_cer_incentive.m sul prezzo
% zonale orario. Parametri della formula:
ZONA_CER    = "nord";    % zona geografica della CER (per FC_zonale) -
                          % coerente con zonalPriceFile (prezzi zonali Nord)
P_PV_NOM_KW = 20;        % TODO: potenza nominale impianto PV [kW] - valore
                          % provvisorio, da confermare (seleziona lo
                          % scaglione TP_base/CAP della formula)
F_RIDUZIONE = 0;         % TODO: fattore di riduzione F - definizione non
                          % ancora nota per intero; per ora nessuna riduzione

% --- Potenza impegnata in PRELIEVO per utente [kW] ------------------------
% Quanto ciascun utente puo' prelevare dalla rete (potenza impegnata in
% bolletta). Usata SOLO da remuneration_model1_cer.m (§3h, Candela et al.)
% per pesare il lato CONSUMO nel calcolo di alpha.
% La potenza di GENERAZIONE non sta qui: appartiene all'impianto, ed e'
% dichiarata come campo .kWp della struct pvPlants piu' sotto.
% TODO: valori PROVVISORI/PLACEHOLDER - da confermare per ciascun utente.
% NOTA SCALABILITA': a molti utenti questa tabella scritta a mano non
% regge; vedi README §13 (limiti noti allo scaling).
RATED_LOAD_KW = containers.Map( ...
    {'office_1_kWh', 'small_industry_1_kWh', 'retail_1_kWh', ...
     'household_1_kWh', 'household_2_kWh', 'household_3_kWh'}, ...
    {10, 50, 15, 3, 3, 3});   % TODO: valori placeholder, da confermare

% --- Modalita tariffarie PUN ---------------------------------------------
Modalita = ["MONORARIA", "BIORARIA", "ORARIO_VARIABILE"];

% --- Flag di visualizzazione ---------------------------------------------
SHOW_PROFILE_PLOTS = true;   % grafici profili di consumo (4 giorni tipo)

% Nomi dei mesi (per tabelle e grafici)
meseNomi = ["Gennaio";"Febbraio";"Marzo";"Aprile";"Maggio";"Giugno"; ...
            "Luglio";"Agosto";"Settembre";"Ottobre";"Novembre";"Dicembre"];

% --- Impianti fotovoltaici -----------------------------------------------
% Ogni impianto e' "dietro al contatore" di UN giocatore: la sua produzione
% copre prima l'autoconsumo del proprietario, e solo l'eccedenza va alla CER
% (dettagli in load_cer_data.m).
%
% Oggi c'e' un solo impianto, assegnato a small_industry_1 (l'edificio host).
% La struct e' pensata per estendersi a piu' impianti con proprietari diversi
% aggiungendo elementi ai due cell array, senza toccare il resto del codice.
% Esempio futuro (5 impianti, 4 residenziali + 1 industriale):
%
%   pvPlants = struct( ...
%       'file',  {pvFile_h1, pvFile_h2, pvFile_h3, pvFile_h4, pvFile_ind}, ...
%       'owner', {"household_1_kWh", "household_2_kWh", "household_3_kWh", ...
%                 "household_4_kWh", "small_industry_1_kWh"});
%
% Il campo .kWp e' la potenza nominale dell'impianto: sta qui, e non in una
% tabella per utente, perche' appartiene all'IMPIANTO. Cosi' e' impossibile
% dichiarare potenza di generazione a chi non ha impianti, e la cosa regge
% da sola quando gli impianti diventano molti.
pvPlants = struct( ...
    'file',  {pvFile}, ...
    'owner', {"small_industry_1_kWh"}, ...
    'kWp',   {20});          % TODO: coerente con P_PV_NOM_KW, da confermare


%% ========================================================================
%  1) CARICAMENTO DATI
%  ========================================================================

D = load_cer_data(loadFile, pvPlants, tGrid);

userNames         = D.userNames;
nUsers            = D.nUsers;
loadUsers         = D.loadUsers;
loadTotal         = D.loadTotal;
genPV_raw         = D.genPV_raw;
genPVSurplus      = D.genPVSurplus;
genForShare       = D.genForShare;
loadForShare      = D.loadForShare;
loadTotalForShare = D.loadTotalForShare;


%% ========================================================================
%  1c) PREZZO ZONALE E TARIFFA INCENTIVANTE CER (TIP_h)
%
%  Il prezzo zonale orario (mercato del giorno prima, MGP) alimenta la
%  formula 3.1 della tariffa incentivante premio: al posto di un incentivo
%  CER costante si ottiene un vettore orario P_CER_h, coerente con la griglia
%  oraria canonica tGrid. Vedi compute_cer_incentive.m per i dettagli e per
%  il TODO sul fattore di riduzione F.
%  ========================================================================

Pz_h    = load_zonal_price(zonalPriceFile, tGrid);
P_CER_h = compute_cer_incentive(Pz_h, P_PV_NOM_KW, ZONA_CER, F_RIDUZIONE);

fprintf('\n=== Tariffa incentivante CER (TIP_h) ===\n');
fprintf('  Prezzo zonale medio: %7.2f EUR/MWh\n', mean(Pz_h));
fprintf('  TIP_h media:         %7.2f EUR/MWh  (%.4f EUR/kWh)\n', ...
        mean(P_CER_h)*1000, mean(P_CER_h));
fprintf('  TIP_h min / max:     %7.2f / %7.2f EUR/MWh\n', ...
        min(P_CER_h)*1000, max(P_CER_h)*1000);


%% ========================================================================
%  2) ELABORAZIONE ENERGETICA (CER)
%
%  Per ogni ora:
%    energia condivisa = min(produzione_PV, richiesta_totale)
%    energia venduta   = max(0, produzione_PV - richiesta_totale)
%  ========================================================================

shared = min(genPVSurplus, loadTotalForShare);      % energia condivisa CER   [kWh/h]
sold   = max(0, genPVSurplus - loadTotalForShare);  % surplus immesso in rete [kWh/h]

% Riorganizzazione in matrici 24 x 365 (riga = ora 0..23, colonna = giorno)
% Nota: demand_24x365/gen_24x365 usano i valori "grezzi" (intera comunita' e
% intera produzione) solo per la visualizzazione d'insieme in §5; shared/sold
% riflettono invece il modello con autoconsumo del proprietario (§1).
shared_24x365 = reshape(shared,    24, N_DAYS);
sold_24x365   = reshape(sold,      24, N_DAYS);
demand_24x365 = reshape(loadTotal, 24, N_DAYS);
gen_24x365    = reshape(genPV_raw, 24, N_DAYS);

% Aggregati mensili (kWh)
monthOfHour    = month(tGrid);
shared_monthly = accumarray(monthOfHour, shared, [12 1]);
sold_monthly   = accumarray(monthOfHour, sold,   [12 1]);

% Totali annuali (kWh)
shared_annual = sum(shared_monthly);
sold_annual   = sum(sold_monthly);

fprintf('\n=== Bilancio CER annuale ===\n');
fprintf('  Energia condivisa: %9.1f kWh\n', shared_annual);
fprintf('  Energia venduta:   %9.1f kWh\n', sold_annual);


%% ========================================================================
%  3) ANALISI ECONOMICA
%  ========================================================================

% Incentivo orario (TIP_h): il ricavo condiviso si somma ora per ora prima
% di aggregare per mese, non piu' come prodotto di uno scalare costante.
rev_shared_monthly = accumarray(monthOfHour, shared .* P_CER_h, [12 1]);  % [€]
rev_sold_monthly   = sold_monthly * P_SELL;                                % ricavo da energia venduta [€]
rev_tot_monthly    = rev_shared_monthly + rev_sold_monthly;
rev_tot_annual     = sum(rev_tot_monthly);
rev_sold_annual    = sum(rev_sold_monthly);

% ricavo da vendita diretta dell'eccedenza sul mercato: NON passa per il gioco
% cooperativo, va ai proprietari degli impianti (vedi §3b-§3f e
% plot_benefit_network.m)

% --- Vendita eccedenza attribuita a ciascun prosumer ---------------------
% L'eccedenza venduta e' una grandezza di comunita': si ripartisce fra i
% prosumer PRO-QUOTA sulla produzione oraria, che e' l'unica regola coerente
% col fatto che l'invenduto nasce dal surplus aggregato. Con un solo impianto
% si riduce esattamente ad attribuire tutto al suo proprietario.

shareGen = zeros(size(genForShare));
hasGen   = genPVSurplus > 0;
shareGen(hasGen, :) = genForShare(hasGen, :) ./ genPVSurplus(hasGen);
soldPerUser        = (sold(:).' * shareGen).';        % [nUsers x 1]  [kWh/anno]
revSoldPerPlayer   = soldPerUser * P_SELL;            % [nUsers x 1]  [EUR/anno]

assert(abs(sum(revSoldPerPlayer) - rev_sold_annual) < 1e-6 * max(1, rev_sold_annual), ...
       'Vendita eccedenza: la ripartizione per utente non somma al totale annuo');

% --- Tabella riepilogativa (12 mesi + riga totale annuo) -----------------
Mese            = [meseNomi;                "TOTALE ANNO"];
E_condivisa_kWh = [shared_monthly;          shared_annual];
E_venduta_kWh   = [sold_monthly;            sold_annual];
Ric_condivisa_E = [rev_shared_monthly;      sum(rev_shared_monthly)];
Ric_venduta_E   = [rev_sold_monthly;        sum(rev_sold_monthly)];
Ric_totale_E    = [rev_tot_monthly;         rev_tot_annual];

Treport = table(Mese, E_condivisa_kWh, E_venduta_kWh, ...
                Ric_condivisa_E, Ric_venduta_E, Ric_totale_E);

fprintf('\n=== Riepilogo economico mensile/annuale ===\n');
disp(Treport);
fprintf('  Ricavo totale annuo: €%.2f\n', rev_tot_annual);


%% ========================================================================
%  3b) DISTRIBUZIONE DEI BENEFICI - SHAPLEY VALUE
%
%  Primo modello di ripartizione dei ricavi della CER. L'incentivo
%  sull'energia condivisa viene diviso tra i giocatori (impianto PV +
%  consumatori) secondo lo Shapley value del gioco cooperativo
%  (Moncecchi et al., Appl. Sci. 2020). Con pochi consumatori lo Shapley
%  e' calcolato in forma esatta su ogni singolo utente, senza
%  l'approssimazione per gruppi del paper.
%
%    Giocatori : PV (produttore) + consumatori
%    Valore    : v(S) = sum_t min(genPV, load_S) * P_CER_h(t) (0 senza PV)
%
%  NOTA: qui "genPV" e "load_S" sono al netto dell'autoconsumo del
%  proprietario dell'impianto (genPVSurplus, loadForShare calcolati in
%  §1): l'energia gia' autoconsumata dietro al contatore del proprietario
%  non e' energia condivisibile con la CER e va esclusa dal gioco.
%  ========================================================================

Sh = shapley_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(Sh, "Shapley");

% Coerenza con l'analisi economica: il valore distribuito coincide con il
% ricavo annuo da energia condivisa calcolato nella sezione 3.
assert(abs(Sh.vGrand - sum(rev_shared_monthly)) < 1e-6, ...
       'Shapley: valore distribuito incoerente con il ricavo da condivisa');

% --- Grafico distribuzione ----------------------------------------------
% Ogni colonna e' un utente e si divide in due colori: la quota CER (Shapley)
% e il ricavo dalla vendita diretta dell'eccedenza sul mercato, che non passa
% dal gioco cooperativo e spetta ai soli prosumer.
figure('Name', 'Distribuzione Shapley', 'Color', 'w');
hBar = bar([Sh.phi, revSoldPerPlayer], 'stacked');
hBar(1).FaceColor = method_color("Shapley");
hBar(2).FaceColor = [0.90 0.45 0.15];   % vendita energia eccedente (mercato)
grid on; box on;
xticks(1:numel(Sh.players));
xticklabels(strrep(Sh.players, '_', '\_')); xtickangle(45);
ylabel('Ricavo [€/anno]');
legend(hBar, {'Quota CER (Shapley)', 'Vendita energia eccedente'}, 'Location', 'northeast');
title(sprintf('Ripartizione incentivo CER condivisa  |  Totale CER = €%.0f', Sh.vGrand));

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(Sh.players, Sh.phi, "Shapley", revSoldPerPlayer);


%% ========================================================================
%  3c) DISTRIBUZIONE DEI BENEFICI - NUCLEOLO
%
%  Secondo modello di ripartizione, sulla STESSA funzione caratteristica
%  v(S) usata dallo Shapley (quindi direttamente confrontabile). Il Nucleolo
%  (Fioriti et al., Appl. Energy 2021, eq. 7) distribuisce il valore
%  massimizzando in modo lessicografico il surplus della coalizione piu'
%  scontenta, risolvendo una sequenza di problemi lineari. A differenza
%  dello Shapley, se il Core e' non-vuoto il Nucleolo vi appartiene ed e'
%  quindi STABILE (nessuna sotto-coalizione conviene).
%  ========================================================================

Nu = nucleolus_cer(genForShare, loadForShare, userNames, P_CER_h);

coreMsg = "fuori dal Core";
if Nu.inCore, coreMsg = "nel Core (stabile)"; end
report_allocation(Nu, "Nucleolo", ...
    sprintf('  %-25s: EUR %9.2f  ->  %s', 'Surplus min (theta)', Nu.thetaMin, coreMsg));

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(Nu.players, Nu.phi, "Nucleolo", revSoldPerPlayer);


%% ========================================================================
%  3d) DISTRIBUZIONE DEI BENEFICI - NASH BARGAINING
%
%  Terzo modello di ripartizione, sulla STESSA funzione caratteristica v(S)
%  di Shapley e Nucleolo. Adattamento del modello di Nash Bargaining
%  generale (Yan et al., Int. J. Electr. Power Energy Syst. 152 (2023)
%  109218) al caso di una singola grande coalizione: ogni giocatore incassa
%  il proprio punto di disaccordo (qui 0, nessuno guadagna nulla da solo)
%  piu' una quota del surplus proporzionale al proprio contributo marginale
%  alla grande coalizione (il "potere contrattuale"). Vedi
%  nash_bargaining_cer.m per i dettagli e i riferimenti.
%  ========================================================================

NB = nash_bargaining_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(NB, "Nash Bargaining");

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(NB.players, NB.phi, "Nash Bargaining", revSoldPerPlayer);


%% ========================================================================
%  3e) DISTRIBUZIONE DEI BENEFICI - VARIANCE LEAST CORE
%
%  Quarto modello di ripartizione, sulla STESSA funzione caratteristica v(S)
%  degli altri tre. Il Variance Least Core (Ferrucci, Fioriti, Poli, IEEE PES
%  ISGT Europe 2025) sceglie, fra tutte le allocazioni del Least Core (quelle
%  che massimizzano il surplus della coalizione piu' scontenta, quindi
%  STABILI), l'unica a distanza quadratica minima dalla ripartizione
%  uniforme: e' quindi al tempo stesso stabile ed UNIVOCA, a differenza del
%  Least Core che e' un insieme.
%
%  A differenza degli altri metodi NON enumera le 2^n coalizioni: usa la
%  ROW-GENERATION (Master + Separation MILP, eq. 15-17 del paper), che genera
%  solo le poche coalizioni realmente vincolanti. E' questa la scelta che
%  rende il metodo applicabile a comunita' con decine o centinaia di membri.
%  Vedi variance_least_core_cer.m per i dettagli.
%  ========================================================================

VLC = variance_least_core_cer(genForShare, loadForShare, userNames, P_CER_h);

coreMsgVLC = "fuori dal Core";
if VLC.inCore, coreMsgVLC = "nel Core (stabile)"; end
report_allocation(VLC, "Variance Least Core", [ ...
    string(sprintf('  %-25s: EUR %9.2f  ->  %s', ...
                   'Surplus min (theta_LC)', VLC.thetaLC, coreMsgVLC)), ...
    string(sprintf('  %-25s: %d iterazioni (LC) + %d (VLC), %d coalizioni generate su %d', ...
                   'Row-generation', VLC.iterLC, VLC.iterVLC, ...
                   size(VLC.coalitions, 1), 2^numel(VLC.players) - 2))]);

% Controllo incrociato: il primo LP del Nucleolo E' l'LP del Least Core,
% quindi i due surplus minimi devono coincidere. E' la verifica piu' forte
% che la row-generation non abbia trascurato coalizioni vincolanti.
assert(abs(VLC.thetaLC - Nu.thetaMin) < 1e-6 * max(1, abs(VLC.vGrand)), ...
       'Variance Least Core: theta_LC diverso dal surplus minimo del Nucleolo');

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(VLC.players, VLC.phi, "Variance Least Core", revSoldPerPlayer);


%% ========================================================================
%  3f) DISTRIBUZIONE DEI BENEFICI - EQUAL SPLIT
%
%  Quinto modello, il piu' semplice possibile: l'incentivo sull'energia
%  condivisa viene diviso in parti UGUALI tra tutti i giocatori, senza
%  guardare a produzione o consumo. Serve da benchmark elementare per
%  misurare quanto i modelli di teoria dei giochi si discostino da una
%  ripartizione paritaria. Vedi equal_split_cer.m per i dettagli.
%  ========================================================================

ES = equal_split_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(ES, "Equal Split");

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(ES.players, ES.phi, "Equal Split", revSoldPerPlayer);


%% ========================================================================
%  3g) DISTRIBUZIONE DEI BENEFICI - PROPORTIONAL TO CONSUMPTION
%
%  Sesto modello, secondo benchmark elementare: l'incentivo sull'energia
%  condivisa viene diviso in proporzione al consumo di ciascun utente nelle
%  sole ore "utili" (energia condivisa di comunita' > 0). Chi consuma di
%  piu' nelle ore in cui la CER matura benefici economici riceve una quota
%  maggiore. Vedi proportional_consumption_cer.m per i dettagli.
%  ========================================================================

PC = proportional_consumption_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(PC, "Proportional to Consumption");

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(PC.players, PC.phi, "Proportional to Consumption", revSoldPerPlayer);


%% ========================================================================
%  3h) DISTRIBUZIONE DEI BENEFICI - REMUNERATION MODEL 1
%
%  Settimo modello, da Candela, Di Silvestre, Gallo, Riva Sanseverino,
%  Sciume', Zizzo, "A Remuneration Model of Energy Community Members in
%  Italy", IEEE BLORIN 2022. L'incentivo si divide in due quote (alpha per i
%  consumatori, beta per i produttori/prosumer) pesate sulla potenza
%  di ciascuna classe: potenza di PRELIEVO per i consumatori (RATED_LOAD_KW,
%  §0) e potenza di GENERAZIONE per i produttori (pvPlants.kWp, §0) - due
%  grandezze fisiche distinte, entrambe valori TODO da confermare.
%  All'interno di ciascuna classe la quota oraria e' proporzionale
%  all'energia di quell'ora. Vedi remuneration_model1_cer.m.
%  ========================================================================

% Potenza impegnata in prelievo: dalla tabella per utente di §0.
ratedLoadKW = zeros(nUsers, 1);
for u = 1:nUsers
    key = char(userNames(u));
    if ~isKey(RATED_LOAD_KW, key)
        error('MAIN:ratedLoadMissing', ...
              'Potenza di prelievo mancante per %s: aggiungerla a RATED_LOAD_KW in §0.', key);
    end
    ratedLoadKW(u) = RATED_LOAD_KW(key);
end

% Potenza di generazione: derivata dagli IMPIANTI, non da una tabella per
% utente. Chi possiede piu' impianti somma le rispettive potenze; chi non ne
% possiede resta a 0 automaticamente.
ratedGenKW = zeros(nUsers, 1);
for p = 1:numel(pvPlants)
    ownerIdx = find(userNames == pvPlants(p).owner, 1);
    ratedGenKW(ownerIdx) = ratedGenKW(ownerIdx) + pvPlants(p).kWp;
end

RM1 = remuneration_model1_cer(genForShare, loadForShare, userNames, P_CER_h, ...
                              ratedLoadKW, ratedGenKW);
report_allocation(RM1, "Remuneration Model 1", ...
    sprintf('  %-25s: alpha=%.3f  beta=%.3f  (prelievo %.0f kW / generazione %.0f kWp)', ...
            'Pesi di classe', RM1.alpha, RM1.beta, ...
            sum(RM1.ratedLoadKW(RM1.consumerEligible)), ...
            sum(RM1.ratedGenKW(RM1.producerEligible))));

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(RM1.players, RM1.phi, "Remuneration Model 1", revSoldPerPlayer);


%% ========================================================================
%  3i) DISTRIBUZIONE DEI BENEFICI - CASCADING TREE
%
%  Ottavo modello, da Trevisan, Ghiani, Pilo, "Economic Benefits
%  Redistribution Methodology for Renewable Energy Communities", 2022.
%  L'incentivo si scompone ricorsivamente in un albero di categorie
%  (riserve, quota fissa, quota variabile -> prelievi/immissione ->
%  produttori+prosumer/soli prosumer), con pesi di ramo di default
%  (scelte di governance della REC, non derivabili dai dati - vedi
%  cascading_tree_cer.m per i dettagli e per come modificarli via opts).
%  ========================================================================

CT = cascading_tree_cer(genForShare, loadForShare, userNames, P_CER_h);
foldMsg = "";
if CT.prosumersOnlyFolded
    foldMsg = "  (nessun vero prosumer: pool soli-prosumer assorbita in immissione generale)";
end
report_allocation(CT, "Cascading Tree", [ ...
    string(sprintf('  %-25s: EUR %9.2f (riserva)  EUR %9.2f (montepremi totale)', ...
                   'Trattenuto / totale', CT.reservoirAmount, CT.totalIncentive)), ...
    string(sprintf('  %-25s: fisso=%.0f prelievi=%.0f immissione=%.0f prosumer=%.0f%s', ...
                   'Pool [EUR]', CT.pools.fixed, CT.pools.withdrawals, ...
                   CT.pools.feedInGeneral, CT.pools.prosumersOnly, foldMsg))]);

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(CT.players, CT.phi, "Cascading Tree", revSoldPerPlayer);


%% ========================================================================
%  3j) DISTRIBUZIONE DEI BENEFICI - WEIGHTED SOLIDARITY
%
%  Nono modello, da Marrasso, Martone, Perugini, Roselli, "Towards a fair
%  revenue distribution of a Renewable Energy Community through a
%  proportional energy consumption model application", J. Phys.: Conf. Ser.
%  3143 (2025) 012113. Peso orario = componente tecnica (energia condivisa +
%  carico dell'utente) + componente di solidarieta' (punteggio a scalini sul
%  costo unitario dell'energia, proxy di poverta' energetica); i quattro
%  coefficienti della formula sono scelti su un fronte di Pareto tra indice
%  di Gini minimo e reddito medio massimo degli utenti a rischio poverta'
%  energetica. Vedi weighted_solidarity_cer.m per i dettagli.
%  ========================================================================

WS = weighted_solidarity_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(WS, "Weighted Solidarity", [ ...
    string(sprintf('  %-25s: alpha1=%.0f alpha2=%.0f beta1=%.0f beta2=%.0f', ...
                   'Combinazione Pareto-ottima', WS.alpha1, WS.alpha2, WS.beta1, WS.beta2)), ...
    string(sprintf('  %-25s: %.4f  (%d combinazioni Pareto-ottime)', ...
                   'Indice di Gini', WS.giniIndex, WS.nParetoPoints))]);

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(WS.players, WS.phi, "Weighted Solidarity", revSoldPerPlayer);


%% ========================================================================
%  3k) DISTRIBUZIONE DEI BENEFICI - PEARSON KEY (chiave dinamica M3)
%
%  Decimo modello, da Gianaroli, Ricci, Sdringola, Ancona, Branchini, Melino, "Development
%  of dynamic sharing keys: Algorithms supporting management of renewable
%  energy community and collective self consumption", Energy & Buildings 311
%  (2024) 114158 (metodo M3).
%
%  E' il primo modello che NON ripartisce direttamente il denaro: ripartisce
%  ora per ora l'ENERGIA condivisa tra gli utenti con una chiave dinamica, e
%  solo alla fine la valorizza con la tariffa incentivante P_CER_h. La chiave
%  premia il SINCRONISMO: per ogni giorno si calcola la correlazione di
%  Pearson tra il profilo di consumo dell'utente e il profilo di immissione
%  della comunita', rimappata in [0,1]. L'energia oraria si distribuisce con
%  quei pesi e con il vincolo SH_i <= consumo_i, ridistribuendo iterativamente
%  a chi resta cio' che eccede il consumo di chi viene "cappato"
%  (allocate_shared_energy.m). Vedi pearson_key_cer.m per i dettagli.
%  ========================================================================

PK = pearson_key_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(PK, "Pearson Key", ...
    sprintf('  %-25s: media %+.3f  (min %+.3f / max %+.3f tra gli utenti)', ...
            'Correlazione Pearson', mean(PK.pMeanUser), ...
            min(PK.pMeanUser), max(PK.pMeanUser)));

% L'energia distribuita ora per ora deve coincidere con l'energia condivisa
% della comunita' calcolata nella sezione 2: e' il controllo piu' diretto che
% l'algoritmo iterativo di cap non perda ne' crei energia.
assert(abs(sum(PK.sharedEnergy) - shared_annual) < 1e-6 * max(1, shared_annual), ...
       'Pearson Key: energia condivisa ripartita incoerente con il bilancio CER');

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(PK.players, PK.phi, "Pearson Key", revSoldPerPlayer);


%% ========================================================================
%  3l) DISTRIBUZIONE DEI BENEFICI - PEARSON-SHARING RATE (chiave dinamica M5)
%
%  Undicesimo modello, dallo stesso paper del precedente (metodo M5, eq. 7).
%  Combina linearmente le due chiavi del paper con alpha + beta = 1: la
%  correlazione di Pearson di M3 (sincronismo) e lo "sharing rate" di M4, che
%  penalizza chi in una data ora consuma piu' energia di quanta la comunita'
%  ne stia immettendo. M4 non e' esposto come modello a se': il suo peso resta
%  una componente interna, calcolata da sharing_rate_key.m. La ripartizione
%  oraria dell'energia e il cap al consumo sono gli stessi di M3 (helper
%  condivisi). Vedi pearson_sharing_key_cer.m per i dettagli, e la nota sulla
%  lettura dell'eq. 5 del paper in sharing_rate_key.m.
%
%  DA RILEGGERE CON I DATI REALI: sulla community provvisoria di oggi questo
%  metodo e' quasi indistinguibile dalla Pearson Key (scarto < 1%), perche' il
%  91% dell'energia cade nel caso banale e nessun utente sovraconsuma - l'unico
%  caso in cui lo sharing rate morde. Non e' un bug: GUIDA §14.6 riporta i tre
%  indicatori da ricalcolare per verificare se il fenomeno si ripresenta.
%  ========================================================================

PSK = pearson_sharing_key_cer(genForShare, loadForShare, userNames, P_CER_h);
report_allocation(PSK, "Pearson-Sharing Rate", [ ...
    string(sprintf('  %-25s: alpha=%.2f (Pearson)  beta=%.2f (sharing rate)  xi=%.3f', ...
                   'Pesi della chiave', PSK.alpha, PSK.beta, PSK.xi)), ...
    string(sprintf('  %-25s: lettura "%s" dell''eq. 5 (coerente con Fig. 3 e con l''esempio del paper)', ...
                   'Sharing rate', PSK.sharingRateMode))]);

assert(abs(sum(PSK.sharedEnergy) - shared_annual) < 1e-6 * max(1, shared_annual), ...
       'Pearson-Sharing Rate: energia condivisa ripartita incoerente con il bilancio CER');

% --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
plot_benefit_network(PSK.players, PSK.phi, "Pearson-Sharing Rate", revSoldPerPlayer);


%% ========================================================================
%  3m) CONFRONTO TRA I MODELLI DI RIPARTIZIONE
%
%  Tabella e grafico riepilogativi che confrontano, sulla STESSA funzione
%  caratteristica v(S), i modelli di ripartizione calcolati finora.
%  Aggiungere un nuovo modello = una colonna nella tabella e un elemento
%  nella struct "metodi", nient'altro.
%
%  NOTA: CT.vGrand (Cascading Tree) coincide col v(N) degli altri metodi
%  solo perche' il default e' opts.reservoirFraction=0 (nessuna riserva
%  trattenuta); con una riserva > 0 sarebbe legittimamente piu' piccolo -
%  per costruzione, non per errore (vedi cascading_tree_cer.m).
%  ========================================================================

Tcmp = table(Sh.players(:), Sh.phi, Nu.phi, NB.phi, VLC.phi, ES.phi, PC.phi, ...
             RM1.phi, CT.phi, WS.phi, PK.phi, PSK.phi, ...
             'VariableNames', {'Giocatore', 'Shapley_EUR', 'Nucleolo_EUR', ...
                               'NashBargaining_EUR', 'VarianceLeastCore_EUR', ...
                               'EqualSplit_EUR', 'ProportionalConsumption_EUR', ...
                               'RemunerationModel1_EUR', 'CascadingTree_EUR', ...
                               'WeightedSolidarity_EUR', 'PearsonKey_EUR', ...
                               'PearsonSharingRate_EUR'});
fprintf('\n=== Confronto tra i modelli di ripartizione [€/anno] ===\n');
disp(Tcmp);

metodi = struct( ...
    'nome', {"Shapley", "Nucleolo", "Nash Bargaining", "Variance Least Core", ...
              "Equal Split", "Proportional to Consumption", ...
              "Remuneration Model 1", "Cascading Tree", "Weighted Solidarity", ...
              "Pearson Key", "Pearson-Sharing Rate"}, ...
    'phi',  {Sh.phi,    Nu.phi,     NB.phi,            VLC.phi, ...
              ES.phi,     PC.phi,   RM1.phi,           CT.phi,  WS.phi, ...
              PK.phi,    PSK.phi});

plot_allocation_comparison(metodi, Sh.players, revSoldPerPlayer, ...
    sprintf('Confronto modelli di ripartizione  |  Totale CER = €%.0f  |  \\theta_{min}=%.0f €', ...
            Nu.vGrand, Nu.thetaMin));


%% ========================================================================
%  4) COSTO ENERGIA DA RETE (PUN 2025)
%  Costo annuo di approvvigionamento per ogni utente e per ogni modalita'
%  tariffaria. I profili prezzo del 2025 condividono la griglia canonica.
%  ========================================================================

% Profilo prezzi orario per ciascuna modalita'
priceByMod = cell(1, numel(Modalita));
for m = 1:numel(Modalita)
    TTprice       = profilo_prezzi_pun_2025(Modalita(m));
    priceByMod{m} = TTprice.Prezzo;          % [N_HOURS x 1]
end

% Costo annuo = somma( prezzo_orario .* consumo_orario )
costMat = zeros(nUsers, numel(Modalita));
for u = 1:nUsers
    for m = 1:numel(Modalita)
        costMat(u, m) = sum(priceByMod{m} .* loadUsers(:, u));
    end
end

Tcost = array2table(costMat, ...
        'VariableNames', cellstr(Modalita), ...
        'RowNames', cellstr(userNames));
Tcost{'COMUNITA', :} = sum(costMat, 1);      % riga con il totale comunita'

fprintf('\n=== Costo annuo energia da rete (PUN 2025) [€] ===\n');
disp(Tcost);


%% ========================================================================
%  5) VISUALIZZAZIONE
%  ========================================================================

plot_cer_energy(meseNomi, shared_monthly, shared_annual, ...
                rev_shared_monthly, rev_sold_monthly, rev_tot_annual);

plot_pv_vs_demand(gen_24x365, demand_24x365, shared_24x365, N_DAYS);

if SHOW_PROFILE_PLOTS
    plot_load_profiles(tGrid, loadUsers, userNames, ANNO);
end
