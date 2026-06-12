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
%    4) Costo energia da rete (PUN 2025, per utente e per modalita)
%    5) Visualizzazione       (istogrammi, profili, confronti)
%
%  Il codice e' organizzato in sezioni indipendenti ed e' predisposto per
%  estensioni future (cicli su piu' scenari, test di modelli multipli, ecc.).
%  ========================================================================


%% ========================================================================
%  0) CONFIGURAZIONE
%  ========================================================================

% --- Percorsi file -------------------------------------------------------
loadFile = "C:\Users\scimo\desktop\Project\CER_LoadProfiles\outputs\csv\profili_tutti.csv";


pvFile   = "C:\Users\scimo\desktop\Project\PV_Generation\Salvaplast_Project_VD7_HourlyRes_1.CSV";

% --- Costanti temporali --------------------------------------------------
ANNO    = 2025;
N_HOURS = 8760;          % ore in un anno standard (24 x 365)
N_DAYS  = 365;

% Griglia oraria canonica dell'anno (asse di riferimento per tutti i dati)
tGrid = (datetime(ANNO,1,1,0,0,0) : hours(1) : datetime(ANNO,12,31,23,0,0)).';

% --- Parametri economici -------------------------------------------------
P_SELL = 0.11;           % Prezzo energia venduta in rete        [€/kWh]
P_CER  = 0.18;           % Incentivo CER su energia condivisa    [€/kWh]

% --- Modalita tariffarie PUN ---------------------------------------------
Modalita = ["MONORARIA", "BIORARIA", "ORARIO_VARIABILE"];

% --- Flag di visualizzazione ---------------------------------------------
SHOW_PROFILE_PLOTS = true;   % grafici profili di consumo (4 giorni tipo)

% Nomi dei mesi (per tabelle e grafici)
meseNomi = ["Gennaio";"Febbraio";"Marzo";"Aprile";"Maggio";"Giugno"; ...
            "Luglio";"Agosto";"Settembre";"Ottobre";"Novembre";"Dicembre"];


%% ========================================================================
%  1) CARICAMENTO DATI
%  ========================================================================

% --- 1a) Profili di carico orari -----------------------------------------
% Ogni colonna numerica e' un utente della comunita' (kWh/ora). I dati
% vengono riallineati sulla griglia oraria canonica: cosi' eventuali ore
% mancanti (es. cambio ora legale) sono interpolate e tutti i vettori hanno
% esattamente N_HOURS campioni.
Tload = readtable(loadFile, 'VariableNamingRule', 'preserve');

% Timestamp (gia' datetime, oppure testo ISO da convertire)
ts = Tload.timestamp;
if ~isdatetime(ts)
    ts = datetime(string(ts), 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
end

% Colonne utente (tutte le colonne numeriche)
isNum     = varfun(@isnumeric, Tload, 'OutputFormat', 'uniform');
userNames = string(Tload.Properties.VariableNames(isNum));
loadRaw   = Tload{:, isNum};                       % [nRighe x nUtenti]

% Riallineamento sulla griglia canonica -> [N_HOURS x nUtenti]
TTload    = retime(timetable(ts, loadRaw, 'VariableNames', {'load'}), tGrid, 'linear');
loadUsers = TTload.load;                            % [N_HOURS x nUtenti]
loadTotal = sum(loadUsers, 2);                      % richiesta totale comunita' [kWh/h]
nUsers    = numel(userNames);

% --- 1b) Generazione fotovoltaica oraria ---------------------------------
genPV = load_pv_generation(pvFile, N_HOURS);        % [N_HOURS x 1] [kWh/h]

% --- Riepilogo consumi annui per utente ----------------------------------
fprintf('=== Consumi annui per utente ===\n');
for u = 1:nUsers
    fprintf('  %-22s %9.1f kWh\n', userNames(u), sum(loadUsers(:,u)));
end
fprintf('  %-22s %9.1f kWh\n', "TOTALE COMUNITA", sum(loadTotal));
fprintf('  %-22s %9.1f kWh\n', "GENERAZIONE PV",  sum(genPV));


%% ========================================================================
%  2) ELABORAZIONE ENERGETICA (CER)
%
%  Per ogni ora:
%    energia condivisa = min(produzione_PV, richiesta_totale)
%    energia venduta   = max(0, produzione_PV - richiesta_totale)
%  ========================================================================

shared = min(genPV, loadTotal);          % energia condivisa (autoconsumo CER) [kWh/h]
sold   = max(0, genPV - loadTotal);      % surplus immesso in rete             [kWh/h]

% Riorganizzazione in matrici 24 x 365 (riga = ora 0..23, colonna = giorno)
shared_24x365 = reshape(shared,    24, N_DAYS);
sold_24x365   = reshape(sold,      24, N_DAYS);
demand_24x365 = reshape(loadTotal, 24, N_DAYS);
gen_24x365    = reshape(genPV,     24, N_DAYS);

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

rev_shared_monthly = shared_monthly * P_CER;     % ricavo da energia condivisa [€]
rev_sold_monthly   = sold_monthly   * P_SELL;    % ricavo da energia venduta   [€]
rev_tot_monthly    = rev_shared_monthly + rev_sold_monthly;
rev_tot_annual     = sum(rev_tot_monthly);

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
%    Valore    : v(S) = sum_t min(genPV, load_S) * P_CER   (0 senza PV)
%  ========================================================================

Sh = shapley_cer(genPV, loadUsers, userNames, P_CER);

fprintf('\n=== Distribuzione Shapley dell''incentivo CER condivisa ===\n');
disp(Sh.table);
fprintf('  Valore grande coalizione : EUR %9.2f\n', Sh.vGrand);
fprintf('  Quota produttore (PV)    : EUR %9.2f  (%.1f%%)\n', ...
        Sh.prodShare, 100*Sh.prodShare/Sh.vGrand);
fprintf('  Quota consumatori        : EUR %9.2f  (%.1f%%)\n', ...
        Sh.consShare, 100*Sh.consShare/Sh.vGrand);

% Verifica efficienza di Pareto: la somma delle quote deve eguagliare il
% valore della grande coalizione (assioma 1 dello Shapley value).
assert(abs(sum(Sh.phi) - Sh.vGrand) < 1e-6, ...
       'Shapley: somma delle quote diversa dal valore della grande coalizione');

% Coerenza con l'analisi economica: il valore distribuito coincide con il
% ricavo annuo da energia condivisa calcolato nella sezione 3.
assert(abs(Sh.vGrand - sum(rev_shared_monthly)) < 1e-6, ...
       'Shapley: valore distribuito incoerente con il ricavo da condivisa');

% --- Grafico distribuzione ----------------------------------------------
figure('Name', 'Distribuzione Shapley', 'Color', 'w');
barColors      = repmat([0.20 0.60 0.30], numel(Sh.phi), 1);  % consumatori
barColors(1,:) = [0.85 0.33 0.10];                            % produttore PV
hBar = bar(Sh.phi, 'FaceColor', 'flat');
hBar.CData = barColors;
grid on; box on;
xticks(1:numel(Sh.players));
xticklabels(strrep(Sh.players, '_', '\_')); xtickangle(45);
ylabel('Quota Shapley [€/anno]');
title(sprintf('Ripartizione incentivo CER condivisa  |  Totale = €%.0f', Sh.vGrand));


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

Nu = nucleolus_cer(genPV, loadUsers, userNames, P_CER);

fprintf('\n=== Distribuzione Nucleolo dell''incentivo CER condivisa ===\n');
disp(Nu.table);
fprintf('  Quota produttore (PV) : EUR %9.2f  (%.1f%%)\n', ...
        Nu.prodShare, 100*Nu.prodShare/Nu.vGrand);
fprintf('  Quota consumatori     : EUR %9.2f  (%.1f%%)\n', ...
        Nu.consShare, 100*Nu.consShare/Nu.vGrand);
coreMsg = "fuori dal Core";
if Nu.inCore, coreMsg = "nel Core (stabile)"; end
fprintf('  Surplus min (theta)   : EUR %9.2f  ->  %s\n', Nu.thetaMin, coreMsg);

% Verifica efficienza: tutto il valore della grande coalizione e' distribuito.
assert(abs(sum(Nu.phi) - Nu.vGrand) < 1e-6, ...
       'Nucleolo: somma delle quote diversa dal valore della grande coalizione');

% --- Confronto Shapley vs Nucleolo --------------------------------------
Tcmp = table(Sh.players(:), Sh.phi, Nu.phi, Nu.phi - Sh.phi, ...
             'VariableNames', {'Giocatore', 'Shapley_EUR', 'Nucleolo_EUR', 'Diff_EUR'});
fprintf('\n=== Confronto Shapley vs Nucleolo [€/anno] ===\n');
disp(Tcmp);

figure('Name', 'Shapley vs Nucleolo', 'Color', 'w');
hB = bar([Sh.phi, Nu.phi], 'grouped');
hB(1).FaceColor = [0.20 0.60 0.30];
hB(2).FaceColor = [0.10 0.35 0.75];
grid on; box on;
xticks(1:numel(Sh.players));
xticklabels(strrep(Sh.players, '_', '\_')); xtickangle(45);
ylabel('Quota [€/anno]');
legend('Shapley', 'Nucleolo', 'Location', 'northeast');
title(sprintf('Ripartizione incentivo CER  |  Totale = €%.0f  |  \\theta_{min}=%.0f €', ...
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

% --- 5a) Energia condivisa mensile + totale annuo ------------------------
figure('Name', 'Energia condivisa CER', 'Color', 'w');
bar(1:12, shared_monthly, 'FaceColor', [0.20 0.60 0.30]);
grid on; box on;
xticks(1:12); xticklabels(meseNomi); xtickangle(45);
ylabel('Energia condivisa [kWh]');
title(sprintf('Energia condivisa mensile  |  Totale annuo = %.0f kWh', shared_annual));

% --- 5b) Ricavi mensili (condivisa vs venduta) ---------------------------
figure('Name', 'Ricavi CER', 'Color', 'w');
bar(1:12, [rev_shared_monthly, rev_sold_monthly], 'stacked');
grid on; box on;
xticks(1:12); xticklabels(meseNomi); xtickangle(45);
ylabel('Ricavo [€]');
legend('Energia condivisa', 'Energia venduta', 'Location', 'northwest');
title(sprintf('Ricavi mensili  |  Totale annuo = €%.0f', rev_tot_annual));

% --- 5c) Produzione PV vs richiesta comunita' (media giornaliera) --------
genDayMean    = mean(gen_24x365,    1);
demDayMean    = mean(demand_24x365, 1);
sharedDayMean = mean(shared_24x365, 1);

figure('Name', 'PV vs Richiesta comunita', 'Color', 'w');
hold on; grid on; box on;
area(1:N_DAYS, genDayMean, 'FaceAlpha', 0.30, 'FaceColor', [1.0 0.8 0.0], ...
     'EdgeColor', [0.9 0.6 0.0], 'DisplayName', 'Produzione PV');
area(1:N_DAYS, sharedDayMean, 'FaceAlpha', 0.45, 'FaceColor', [0.2 0.6 0.3], ...
     'EdgeColor', 'none', 'DisplayName', 'Energia condivisa');
plot(1:N_DAYS, demDayMean, 'Color', [0.1 0.3 0.7], 'LineWidth', 1.6, ...
     'DisplayName', 'Richiesta comunita');
xlabel('Giorno dell''anno'); ylabel('Potenza media giornaliera [kW]');
xlim([1 N_DAYS]);
legend('Location', 'northwest');
title('Produzione PV, richiesta comunita ed energia condivisa');

% --- 5d) Profili di consumo - 4 giorni tipo (opzionale) ------------------
if SHOW_PROFILE_PLOTS
    stagioni = ["Inverno (15 gen)", "Primavera (15 apr)", ...
                "Estate (15 lug)",  "Autunno (15 ott)"];
    giorni   = datetime([ANNO 1 15; ANNO 4 15; ANNO 7 15; ANNO 10 15]);

    isRes   = startsWith(userNames, 'household');
    idxRes  = find(isRes);
    idxCom  = find(~isRes);

    if ~isempty(idxCom)
        plotProfiliStagionali(tGrid, loadUsers, idxCom, userNames, giorni, ...
            stagioni, 'Profili commerciali', 'Profili di consumo COMMERCIALI - 4 giorni tipo');
    end
    if ~isempty(idxRes)
        plotProfiliStagionali(tGrid, loadUsers, idxRes, userNames, giorni, ...
            stagioni, 'Profili residenziali', 'Profili di consumo RESIDENZIALI - 4 giorni tipo');
    end
end


%% ========================================================================
%  FUNZIONI LOCALI
%  ========================================================================

function gen = load_pv_generation(pvFile, nHoursTarget)
%LOAD_PV_GENERATION  Legge un export orario PVsyst (E_Grid) e restituisce
%   la generazione fotovoltaica oraria come vettore colonna [kWh/h].
%
%   - Salta le righe di intestazione/metadati PVsyst.
%   - Riconosce sia "dd/mm/yy HH:MM" sia "dd/mm/yyyy HH:MM:SS".
%   - Azzera i piccoli valori negativi (autoconsumo notturno inverter).
%   - Allinea la lunghezza a nHoursTarget (padding con 0 o troncamento).

    lines = readlines(pvFile);
    lines = strtrim(lines);
    lines(lines == "") = [];

    % Mantiene solo le righe-dato "data;valore"
    isData    = ~cellfun('isempty', ...
                regexp(lines, '^\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}', 'once'));
    dataLines = lines(isData);

    if isempty(dataLines)
        error('load_pv_generation:noData', ...
              'Nessuna riga di dati orari trovata in:\n  %s', pvFile);
    end

    parts = split(dataLines, ';');        % [N x 2] string array
    gen   = str2double(parts(:, 2));      % [kW medio orario ~ kWh/h]
    gen   = max(gen, 0);                  % azzera valori negativi

    % Allinea alla lunghezza attesa
    nH = numel(gen);
    if nH < nHoursTarget
        warning('load_pv_generation:short', ...
                'File PV con sole %d ore (attese %d): padding con 0.\n  %s', ...
                nH, nHoursTarget, pvFile);
        gen(end+1:nHoursTarget, 1) = 0;
    elseif nH > nHoursTarget
        gen = gen(1:nHoursTarget);
    end
end


function plotProfiliStagionali(t, dataMat, colIdx, names, giorni, stagioni, figName, figTitle)
%PLOTPROFILISTAGIONALI  Traccia i profili orari di un gruppo di utenti in 4
%   giorni tipo (uno per stagione), in un layout 2x2.

    nC   = numel(colIdx);
    cmap = lines(nC);
    figure('Name', figName, 'Color', 'w', 'Position', [120 120 1300 820]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    for d = 1:4
        nexttile; hold on; grid on; box on;
        maskDay = dateshift(t, 'start', 'day') == giorni(d);
        tDay    = t(maskDay);
        hAxis   = hours(tDay - dateshift(tDay(1), 'start', 'day'));
        for u = 1:nC
            plot(hAxis, dataMat(maskDay, colIdx(u)), 'Color', cmap(u,:), ...
                 'LineWidth', 1.4, 'DisplayName', strrep(names(colIdx(u)), '_', '\_'));
        end
        xlim([0 24]); xticks(0:4:24);
        xlabel('Ora del giorno [h]'); ylabel('Potenza [kW]');
        title(stagioni(d));
        if d == 1
            legend('Location', 'northeast', 'FontSize', 8);
        end
    end
    sgtitle(figTitle, 'FontSize', 13, 'FontWeight', 'bold');
end
