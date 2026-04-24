clear; clc;
close all;

%% ========================================================================
%  PATH FILES
%  ========================================================================
loadFile  = "C:\Users\scimo\desktop\Project\CER_LoadProfiles\outputs\csv\profili_tutti.csv";
pvPattern = "*.CSV";  % Pattern per trovare tutti i CSV PVsyst

Modalita = ["MONORARIA", "BIORARIA", "ORARIO_VARIABILE"];

%% ========================================================================
%  1) CARICAMENTO CONSUMI ORARI
%  ========================================================================
Tload = readtable(loadFile);

% Trova automaticamente la prima colonna numerica
numCols = varfun(@isnumeric, Tload, "OutputFormat", "uniform");
idxLoad = find(numCols);
assert(~isempty(idxLoad), "Nessuna colonna numerica nel CSV consumi.");

% Crea un vettore per ogni colonna numerica con il nome dell'intestazione
colNames = Tload.Properties.VariableNames(idxLoad);
profiles = struct();
for k = 1:numel(idxLoad)
    profiles.(colNames{k}) = double(Tload{:, idxLoad(k)});
end

% --- DEBUG: consumo annuo per utente ---
fprintf('Colonne caricate (%d):\n', numel(colNames));
fprintf('%-20s  %10s\n', 'Utente', 'kWh/anno');
fprintf('%s\n', repmat('-', 1, 33));
for k = 1:numel(colNames)
    fprintf('%-20s  %10.2f kWh\n', colNames{k}, sum(profiles.(colNames{k})));
end
fprintf('%s\n', repmat('-', 1, 33));
% --- FINE DEBUG ---

% ========================================================================
% CONVERSIONE PROFILI DA 15 MINUTI A 1 ORA
% ========================================================================

% Se presente la colonna timestamp, usa il passo temporale reale per decidere
% se ricampionare a 1h; i valori in input sono in kW.
hasTimestamp = any(strcmpi(Tload.Properties.VariableNames, 'timestamp'));

profiles_hourly = struct();
tHourOut = [];
if hasTimestamp
    tRaw = datetime(Tload.timestamp, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
    dtMin = minutes(median(diff(tRaw)));

    if abs(dtMin - 15) < 1e-6
        % Ricampionamento quartorario -> orario.
        % Per profili in kW, la media oraria equivale anche all'energia
        % oraria in kWh (kW medi su 1h).
        fprintf('Risoluzione input: %.0f min -> conversione a 60 min...\n', dtMin);
        tHour = dateshift(tRaw(1), 'start', 'hour'):hours(1):dateshift(tRaw(end), 'start', 'hour');
        tHourOut = tHour(:);

        for k = 1:numel(idxLoad)
            x = profiles.(colNames{k});
            TTk = timetable(tRaw, x, 'VariableNames', {'val'});
            TTh = retime(TTk, tHour', 'mean');
            profiles_hourly.(colNames{k}) = TTh.val;
        end
    else
        fprintf('Risoluzione input: %.0f min (nessuna conversione applicata).\n', dtMin);
        profiles_hourly = profiles;
        tHourOut = tRaw(:);
    end
else
    warning('Colonna timestamp non trovata: uso i profili cosi'' come sono.');
    profiles_hourly = profiles;
end

% Debug robustezza: conta NaN nei profili orari
for k = 1:numel(colNames)
    nNaN = sum(isnan(profiles_hourly.(colNames{k})));
    if nNaN > 0
        fprintf('ATTENZIONE: profilo %s contiene %d NaN.\n', colNames{k}, nNaN);
    end
end


%% ========================================================================
%  2) CALCOLO PROFILO PREZZI PUN 2025
%  ========================================================================

for i = 1:numel(colNames)
    fprintf('Profilo %d: %s\n', i, colNames{i});

for k = 1:numel(Modalita)
    modalita = Modalita(k);
    fprintf('\n=== Elaborazione modalità: %s ===\n', modalita);
    
    [TT, S, P] = profilo_prezzi_pun_2025(modalita);
    
    % % --- DEBUG: prezzi medi mensili per fascia ---
    % fprintf('Prezzi medi mensili per fascia:\n');
    % disp(S);
    % % --- FINE DEBUG ---

    % Allinea i vettori e scarta campioni invalidi per evitare NaN finale.
    priceVec = TT.Prezzo;
    loadVec = profiles_hourly.(colNames{i});

    nMin = min(numel(priceVec), numel(loadVec));
    if numel(priceVec) ~= numel(loadVec)
        fprintf('ATTENZIONE: lunghezze diverse (prezzo=%d, carico=%d). Uso i primi %d campioni.\n', ...
            numel(priceVec), numel(loadVec), nMin);
    end

    priceVec = priceVec(1:nMin);
    loadVec = loadVec(1:nMin);

    validMask = isfinite(priceVec) & isfinite(loadVec);
    nScartati = sum(~validMask);
    if nScartati > 0
        fprintf('ATTENZIONE: scartati %d campioni non validi nel costo annuo.\n', nScartati);
    end

    Total_CostY1 = sum(priceVec(validMask) .* loadVec(validMask)); % Costo totale per il primo utente
    fprintf('Costo totale annuo per %s: €%.2f\n', colNames{i}, Total_CostY1);
end

end

%% ========================================================================
%  3) GRAFICO COSTO ORARIO GIORNALIERO (UTENTE CASUALE)
%  ========================================================================
if hasTimestamp && ~isempty(tHourOut)
    rng('shuffle'); %scelta casuale utente

    idxUser = randi(numel(colNames));
    userName = colNames{idxUser};
    loadUser = profiles_hourly.(userName);

    % Allinea timeline profilo utente
    nL = min(numel(tHourOut), numel(loadUser));
    tUser = tHourOut(1:nL);
    loadUser = loadUser(1:nL);

    % Giorni completi disponibili
    allDays = unique(dateshift(tUser, 'start', 'day'));
    validDays = datetime.empty(0,1);
    for d = 1:numel(allDays)
        nDay = sum(dateshift(tUser, 'start', 'day') == allDays(d));
        if nDay >= 24
            validDays(end+1,1) = allDays(d); %#ok<SAGROW>
        end
    end
    assert(~isempty(validDays), 'Nessun giorno completo disponibile per il grafico.');

    daySel = validDays(randi(numel(validDays)));
    h = 0:23;
    costHour = nan(numel(Modalita), 24);
    costDay = nan(numel(Modalita), 1);
    priceHour = nan(numel(Modalita), 24);

    for k = 1:numel(Modalita)
        modalita = Modalita(k);
        [TT, ~, ~] = profilo_prezzi_pun_2025(modalita);

        tPrice = TT.Properties.RowTimes;
        pPrice = TT.Prezzo;

        [tCommon, iU, iP] = intersect(tUser, tPrice);
        if isempty(tCommon)
            warning('Nessun timestamp comune per modalita %s.', modalita);
            continue;
        end

        cHourly = loadUser(iU) .* pPrice(iP); % Costo orario = PUN(h) * Consumo(h)

        maskDay = dateshift(tCommon, 'start', 'day') == daySel;
        tDay = tCommon(maskDay);
        cDay = cHourly(maskDay);
        pDay = pPrice(iP(maskDay));

        % Garantisce ordine per ora e primi 24 campioni
        [~, ord] = sort(tDay);
        cDay = cDay(ord);
        pDay = pDay(ord);
        if numel(cDay) >= 24
            costHour(k,:) = cDay(1:24).';
            costDay(k) = sum(costHour(k,:), 'omitnan');
            priceHour(k,:) = pDay(1:24).';
        end
    end

    figure('Name','Costo giornaliero per modalita','Color','w');
    tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(h, costHour(1,:), '-o', 'LineWidth', 1.2, 'DisplayName', 'MONORARIA'); hold on;
    plot(h, costHour(2,:), '-s', 'LineWidth', 1.2, 'DisplayName', 'BIORARIA');
    plot(h, costHour(3,:), '-^', 'LineWidth', 1.2, 'DisplayName', 'ORARIO VARIABILE');
    grid on;
    xlim([0 23]);
    xticks(0:23);
    xlabel('Ora del giorno');
    ylabel('Costo orario [€]');
    title(sprintf('Utente: %s | Giorno: %s', userName, datestr(daySel,'dd-mmm-yyyy')));
    legend('Location','best');

    nexttile;
    bar(categorical(Modalita), costDay);
    grid on;
    ylabel('Costo giornaliero totale [€]');
    title('Totale giornaliero = somma costi orari');

    nexttile;
    plot(h, priceHour(1,:), '-o', 'LineWidth', 1.2, 'DisplayName', 'MONORARIA'); hold on;
    plot(h, priceHour(2,:), '-s', 'LineWidth', 1.2, 'DisplayName', 'BIORARIA');
    plot(h, priceHour(3,:), '-^', 'LineWidth', 1.2, 'DisplayName', 'ORARIO VARIABILE');
    grid on;
    xlim([0 23]);
    xticks(0:23);
    xlabel('Ora del giorno');
    ylabel('Prezzo [€/kWh]');
    title('Prezzi orari nel giorno selezionato');
    legend('Location','best');

    fprintf('\n=== CONTROLLO GIORNALIERO (utente casuale) ===\n');
    fprintf('Utente: %s\n', userName);
    fprintf('Giorno: %s\n', datestr(daySel,'dd-mmm-yyyy'));
    for k = 1:numel(Modalita)
        fprintf('%s -> Totale giorno = %.3f € (somma di 24 costi orari)\n', Modalita(k), costDay(k));
    end
else
    warning('Timestamp non disponibile: impossibile creare il grafico giornaliero.');
end


%% ========================================================================
%  4) PROFILI DI TUTTI I PARTECIPANTI IN 4 GIORNI TIPO
%  ========================================================================

% Carica il CSV a 15 min con tutti i profili
rawPath = "C:\Users\scimo\desktop\Project\CER_LoadProfiles\outputs\csv\profili_tutti.csv";
Traw = readtable(rawPath);
tRaw15 = datetime(Traw.timestamp, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');

% Separa colonne commerciali e residenziali per prefisso nome
numColsRaw = varfun(@isnumeric, Traw, 'OutputFormat', 'uniform');
allUserCols = Traw.Properties.VariableNames(numColsRaw);

isHousehold = startsWith(allUserCols, 'household');
colsRes  = allUserCols( isHousehold);   % residenziali
colsCom  = allUserCols(~isHousehold);   % commerciali

% 4 giorni tipo: inverno, primavera, estate, autunno
stagioni = ["Inverno (15 gen)", "Primavera (15 apr)", "Estate (15 lug)", "Autunno (15 ott)"];
giorni   = datetime([2025 1 15; 2025 4 15; 2025 7 15; 2025 10 15]);

% --- helper: plot un gruppo di colonne in un layout 2x2 ---
function plotGruppo(Traw, tRaw15, cols, giorni, stagioni, figName, figTitle)
    nC = numel(cols);
    cmap = lines(nC);
    figure('Name', figName, 'Color', 'w', 'Position', [120 120 1300 820]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    for d = 1:4
        nexttile;
        hold on; grid on; box on;
        maskDay = dateshift(tRaw15, 'start', 'day') == giorni(d);
        tDay    = tRaw15(maskDay);
        hAxis   = hours(tDay - dateshift(tDay(1), 'start', 'day'));
        for u = 1:nC
            yVec = Traw{maskDay, cols{u}};
            plot(hAxis, yVec, 'Color', cmap(u,:), 'LineWidth', 1.4, ...
                 'DisplayName', strrep(cols{u}, '_', '\_'));
        end
        xlim([0 24]); xticks(0:4:24);
        xlabel('Ora del giorno [h]');
        ylabel('Potenza [kW]');
        title(stagioni(d));
        if d == 1
            legend('Location', 'northeast', 'FontSize', 8);
        end
    end
    sgtitle(figTitle, 'FontSize', 13, 'FontWeight', 'bold');
end

% --- Figura 1: profili commerciali ---
plotGruppo(Traw, tRaw15, colsCom, giorni, stagioni, ...
    'Profili commerciali – 4 giorni tipo', ...
    'Profili di consumo COMMERCIALI – 4 giorni tipo');

% --- Figura 2: profili residenziali ---
plotGruppo(Traw, tRaw15, colsRes, giorni, stagioni, ...
    'Profili residenziali – 4 giorni tipo', ...
    'Profili di consumo RESIDENZIALI – 4 giorni tipo');
