function D = load_cer_data(loadFile, pvPlants, tGrid)
%LOAD_CER_DATA  Carica profili di carico e generazione PV della CER e calcola
%   le grandezze derivate necessarie alla condivisione dell'energia.
%
%   Raccoglie tutto l'I/O di MAIN.m in un unico punto. I profili di carico
%   vengono riallineati sulla griglia oraria canonica tGrid: cosi' eventuali
%   ore mancanti (es. cambio ora legale) sono interpolate e tutti i vettori
%   hanno esattamente numel(tGrid) campioni.
%
%   AUTOCONSUMO DEL PROPRIETARIO
%     Ogni impianto PV e' fisicamente "dietro al contatore" di UN giocatore
%     della comunita' (il proprietario): la sua produzione copre PRIMA
%     l'autoconsumo del proprietario, e SOLO l'eccedenza e' disponibile per
%     la condivisione con il resto della comunita' -- stessa priorita' usata
%     in optimizer_PV.m (1: autoconsumo edificio, 2: CER, 3: rete).
%
%   INPUT
%     loadFile  string  percorso del CSV dei profili di carico orari
%     pvPlants  struct array con campi:
%                 .file   percorso dell'export orario PVsyst
%                 .owner  nome dell'utente proprietario dell'impianto
%     tGrid     [H x 1] datetime  griglia oraria canonica di riferimento
%
%   OUTPUT (struct D)
%     .userNames         [1 x nC]  nomi degli utenti                (string)
%     .nUsers            scalare   numero di utenti
%     .loadUsers         [H x nC]  carichi orari lordi              [kWh/h]
%     .loadTotal         [H x 1]   carico totale comunita'          [kWh/h]
%     .genPV_raw         [H x 1]   produzione PV totale             [kWh/h]
%     .genPVSurplus      [H x 1]   eccedenza totale per la CER      [kWh/h]
%     .genForShare       [H x nC]  eccedenza PER UTENTE disponibile alla
%                                  condivisione (zeri se non ha impianti)
%     .loadForShare      [H x nC]  carico RESIDUO per utente, non coperto
%                                  dal proprio autoconsumo          [kWh/h]
%     .loadTotalForShare [H x 1]   somma di loadForShare            [kWh/h]
%
%   genForShare e loadForShare sono complementari per costruzione: in ogni ora
%   un utente ha eccedenza OPPURE carico residuo, mai entrambi. Sono le due
%   matrici che alimentano il gioco cooperativo (cer_coalition_values), dove
%   ogni utente e' un giocatore che porta con se' entrambe.

    nHours = numel(tGrid);

    % --- Profili di carico orari --------------------------------------------
    [userNames, loadUsers] = read_load_profiles(loadFile, tGrid);
    nUsers    = numel(userNames);
    loadTotal = sum(loadUsers, 2);

    % --- Generazione PV e ripartizione autoconsumo / eccedenza -------------
    % L'eccedenza e' tenuta SEPARATA PER UTENTE: nel gioco cooperativo ogni
    % utente e' un giocatore e deve portare con se' la produzione che possiede.
    genPV_raw    = zeros(nHours, 1);
    genForShare  = zeros(nHours, nUsers);
    loadForShare = loadUsers;

    for p = 1:numel(pvPlants)
        genPV_p   = load_pv_generation(pvPlants(p).file, nHours);
        genPV_raw = genPV_raw + genPV_p;

        ownerIdx = find(userNames == pvPlants(p).owner, 1);
        if isempty(ownerIdx)
            error('load_cer_data:pvOwnerNotFound', ...
                  'Proprietario PV "%s" non trovato tra gli utenti (%s).', ...
                  pvPlants(p).owner, strjoin(userNames, ', '));
        end

        % Si legge il carico eventualmente gia' ridotto da un impianto
        % precedente con lo stesso proprietario, cosi' piu' impianti sullo
        % stesso giocatore si sommano correttamente in autoconsumo.
        ownerLoad_p    = loadForShare(:, ownerIdx);
        surplus_p      = max(0, genPV_p - ownerLoad_p);
        residualLoad_p = max(0, ownerLoad_p - genPV_p);

        genForShare(:, ownerIdx)  = genForShare(:, ownerIdx) + surplus_p;
        loadForShare(:, ownerIdx) = residualLoad_p;
    end

    % --- Output -------------------------------------------------------------
    D.userNames         = userNames;
    D.nUsers            = nUsers;
    D.loadUsers         = loadUsers;
    D.loadTotal         = loadTotal;
    D.genPV_raw         = genPV_raw;
    D.genPVSurplus      = sum(genForShare, 2);
    D.genForShare       = genForShare;
    D.loadForShare      = loadForShare;
    D.loadTotalForShare = sum(loadForShare, 2);

    print_consumption_summary(D);
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function [userNames, loadUsers] = read_load_profiles(loadFile, tGrid)
%READ_LOAD_PROFILES  Legge il CSV dei profili e li riallinea su tGrid.
%   Ogni colonna numerica e' un utente della comunita' (kWh/ora).

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

    % Riallineamento sulla griglia canonica -> [nHours x nUtenti]
    TTload    = retime(timetable(ts, loadRaw, 'VariableNames', {'load'}), tGrid, 'linear');
    loadUsers = TTload.load;
end


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

    parts  = split(dataLines, ';');       % [N x 2] string array
    valori = strtrim(parts(:, 2));
    gen    = str2double(valori);          % [kW medio orario ~ kWh/h]

    % Il file va RIFIUTATO, non corretto: un export PVsyst illeggibile e' un
    % problema all'origine, e leggerlo a meta' produce numeri plausibili e
    % sbagliati. Due modi di essere illeggibile, e il secondo e' il pericoloso:
    %
    %   NaN      valore non numerico. Senza questo controllo diventerebbe 0,
    %            perche' max(NaN,0) vale 0: un impianto mezzo spento in silenzio.
    %   virgola  export in localizzazione italiana. str2double NON da' NaN:
    %            legge la virgola da separatore delle MIGLIAIA ("0,6717" ->
    %            6717) e gonfia la produzione di quattro ordini di grandezza
    %            senza un solo avviso. E' il caso che va intercettato qui,
    %            perche' a valle non si distingue piu' da un impianto grande.
    daScartare = isnan(gen) | contains(valori, ",");
    if any(daScartare)
        primo = dataLines(find(daScartare, 1));
        error('load_pv_generation:parse', ...
              ['%d righe con valore non leggibile come decimale in:\n  %s\n' ...
               '  prima occorrenza: "%s"\n' ...
               '  se il file usa la virgola decimale, riesportarlo da PVsyst ' ...
               'con il punto.'], ...
              sum(daScartare), pvFile, primo);
    end

    gen = max(gen, 0);                    % azzera valori negativi

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


function print_consumption_summary(D)
%PRINT_CONSUMPTION_SUMMARY  Riepilogo dei consumi annui per utente.

    fprintf('=== Consumi annui per utente ===\n');
    for u = 1:D.nUsers
        fprintf('  %-22s %9.1f kWh\n', D.userNames(u), sum(D.loadUsers(:,u)));
    end
    fprintf('  %-22s %9.1f kWh\n', "TOTALE COMUNITA", sum(D.loadTotal));
    fprintf('  %-22s %9.1f kWh\n', "GENERAZIONE PV (tot)", sum(D.genPV_raw));
    fprintf('  %-22s %9.1f kWh\n', "di cui autoconsumata", ...
            sum(D.genPV_raw) - sum(D.genPVSurplus));
    fprintf('  %-22s %9.1f kWh\n', "di cui eccedenza CER", sum(D.genPVSurplus));
end
