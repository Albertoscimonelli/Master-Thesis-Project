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
%   3b-3e) Ripartizione dei benefici con quattro modelli di teoria dei giochi
%    3f) Confronto tra i modelli
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
pvPlants = struct( ...
    'file',  {pvFile}, ...
    'owner', {"small_industry_1_kWh"});


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
%  3f) CONFRONTO TRA I MODELLI DI RIPARTIZIONE
%
%  Tabella e grafico riepilogativi che confrontano, sulla STESSA funzione
%  caratteristica v(S), i modelli di ripartizione calcolati finora.
%  Aggiungere un nuovo modello = una colonna nella tabella e un elemento
%  nella struct "metodi", nient'altro.
%  ========================================================================

Tcmp = table(Sh.players(:), Sh.phi, Nu.phi, NB.phi, VLC.phi, ...
             'VariableNames', {'Giocatore', 'Shapley_EUR', 'Nucleolo_EUR', ...
                               'NashBargaining_EUR', 'VarianceLeastCore_EUR'});
fprintf('\n=== Confronto tra i modelli di ripartizione [€/anno] ===\n');
disp(Tcmp);

metodi = struct( ...
    'nome', {"Shapley", "Nucleolo", "Nash Bargaining", "Variance Least Core"}, ...
    'phi',  {Sh.phi,    Nu.phi,     NB.phi,            VLC.phi});

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
