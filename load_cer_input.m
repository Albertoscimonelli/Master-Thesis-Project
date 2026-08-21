function CFG = load_cer_input(inputFile)
%LOAD_CER_INPUT  Legge la scheda dati della CER (CER_input.txt) e la
%   restituisce come struct, validata.
%
%   E' l'unico punto in cui il progetto legge la configurazione della
%   comunita': MAIN.m non contiene piu' dati, solo il flusso di calcolo.
%
%   FORMATO
%     [SEZIONE]        apre una sezione
%     chiave = valore  dato scalare
%     a | b | c        riga di tabella (la prima e' l'intestazione)
%     #                commento fino a fine riga
%
%   I DUE MODI DI NON AVERE UN DATO
%     '-'  NON APPLICABILE  -> NaN (o stringa vuota). Il modello non se ne
%          aspetta uno: il reddito di un ufficio non esiste, non manca.
%     '?'  NON ANCORA NOTO  -> NaN, PIU' un flag a false in CFG.noto. E' il
%          flag che MAIN.m usa per decidere se passare o no il campo opts
%          corrispondente: se non lo passa, il metodo applica il proprio
%          default e lo dichiara come ipotesi attiva in S.assumptions.
%
%     La distinzione e' il cuore del meccanismo. Un '-' e' una risposta, un
%     '?' e' una domanda aperta, e il registro delle ipotesi stampato a fine
%     esecuzione conta esattamente i '?' che contano.
%
%   INPUT
%     inputFile  string  percorso della scheda (default "CER_input.txt")
%
%   OUTPUT (struct CFG)
%     .cer .riepilogo .file .mercato .investimento .poverta .governance
%                       struct di scalari, una per sezione
%     .membri           table, una riga per membro (ordine del file)
%     .impianti         table, una riga per impianto
%     .impiantiStruct   struct array [.file .owner .kWp] pronta per
%                       load_cer_data (percorsi gia' risolti in assoluto)
%     .noto             struct di flag: .noto.mercato.tip_fattore_riduzione,
%                       .noto.membri.reddito_EUR, ... true = dato disponibile
%     .incognito        solo per le tabelle: .incognito.membri.reddito_EUR e'
%                       un logico [nRighe x 1], true dove c'era un '?'
%     .radice           cartella della scheda, base dei percorsi relativi
%
%     Due granularita', per due usi diversi. In .noto il flag di una tabella
%     e' PER COLONNA e vale true solo se NESSUNA cella e' '?': una colonna con
%     anche un solo buco non e' utilizzabile come vettore [n x 1] e va trattata
%     come assente. In .incognito il flag e' PER CELLA, e serve a dire a chi
%     compila la scheda su quale riga ha scritto '-' dove voleva dire '?'.
%
%   VALIDAZIONI
%     Tutti i problemi trovati vengono raccolti e riportati INSIEME, con il
%     numero di riga. Correggerne uno alla volta su una scheda di sessanta
%     membri sarebbe una tortura.
%
%   Vedi anche: align_members_to_users, load_cer_data, MAIN

    if nargin < 1 || strlength(string(inputFile)) == 0
        inputFile = "CER_input.txt";
    end
    inputFile = string(inputFile);

    if ~isfile(inputFile)
        error('load_cer_input:fileNotFound', ...
              'Scheda dati non trovata:\n  %s', inputFile);
    end

    % La radice dei percorsi relativi e' la cartella della scheda, non la
    % cartella di lavoro di MATLAB: cosi' MAIN.m gira da qualunque pwd.
    [radice, ~, ~] = fileparts(which_or_full(inputFile));
    if strlength(radice) == 0, radice = pwd; end

    % --- Sezione -> campo della struct ---------------------------------------
    % Le sezioni tabellari sono elencate a parte: cambiano il modo di leggere
    % le righe, non solo il nome del campo.
    mappaSezioni = struct( ...
        'CER',                'cer', ...
        'RIEPILOGO',          'riepilogo', ...
        'FILE',               'file', ...
        'MERCATO',            'mercato', ...
        'INVESTIMENTO',       'investimento', ...
        'POVERTA_ENERGETICA', 'poverta', ...
        'GOVERNANCE',         'governance', ...
        'MEMBRI',             'membri', ...
        'IMPIANTI',           'impianti');
    sezioniTabellari = ["MEMBRI", "IMPIANTI"];

    % --- Parsing -------------------------------------------------------------
    [CFG, problemi] = parse_file(inputFile, mappaSezioni, sezioniTabellari);
    CFG.radice = string(radice);

    % --- Validazioni ---------------------------------------------------------
    problemi = [problemi, valida_sezioni(CFG, mappaSezioni)];
    problemi = [problemi, valida_membri(CFG)];
    problemi = [problemi, valida_impianti(CFG)];
    problemi = [problemi, valida_riepilogo(CFG)];
    problemi = [problemi, valida_percorsi(CFG)];

    if ~isempty(problemi)
        error('load_cer_input:validazione', ...
              ['La scheda dati contiene %d problemi:\n\n%s\n\n' ...
               'File: %s'], ...
              numel(problemi), strjoin("  - " + problemi, newline), inputFile);
    end

    % --- Struct impianti pronta per load_cer_data ---------------------------
    CFG.impiantiStruct = costruisci_impianti_struct(CFG);

    stampa_riepilogo(CFG, inputFile);
end


% ===========================================================================
%  PARSING
% ===========================================================================

function [CFG, problemi] = parse_file(inputFile, mappaSezioni, sezioniTabellari)
%PARSE_FILE  Automa a stati sulle righe della scheda.

    CFG      = struct('noto', struct());
    problemi = string.empty(1, 0);

    righe = readlines(inputFile);

    sezioneCorr = "";      % nome della sezione aperta
    campoCorr   = "";      % nome del campo struct corrispondente
    isTabella   = false;
    intestaz    = string.empty(1, 0);   % nomi colonna della tabella corrente
    celle       = string.empty(0, 0);   % celle grezze accumulate
    righeTab    = [];                   % numero di riga di ciascuna riga dati

    for k = 1:numel(righe)
        riga = strip_comment(righe(k));
        if strlength(riga) == 0, continue; end

        % --- Apertura di sezione --------------------------------------------
        tok = regexp(riga, '^\[([A-Z_]+)\]$', 'tokens', 'once');
        if ~isempty(tok)
            % Chiude la tabella eventualmente aperta
            [CFG, problemi] = chiudi_tabella(CFG, problemi, campoCorr, ...
                                             intestaz, celle, righeTab);
            sezioneCorr = string(tok{1});
            if ~isfield(mappaSezioni, sezioneCorr)
                problemi(end+1) = sprintf( ...
                    'riga %d: sezione [%s] sconosciuta (attese: %s)', ...
                    k, sezioneCorr, strjoin(string(fieldnames(mappaSezioni)).', ', ')); %#ok<AGROW>
                campoCorr = "";
                isTabella = false;
                continue;
            end
            campoCorr = string(mappaSezioni.(sezioneCorr));
            isTabella = ismember(sezioneCorr, sezioniTabellari);
            intestaz  = string.empty(1, 0);
            celle     = string.empty(0, 0);
            righeTab  = [];
            if ~isTabella
                CFG.(campoCorr)      = struct();
                CFG.noto.(campoCorr) = struct();
            end
            continue;
        end

        if strlength(campoCorr) == 0
            problemi(end+1) = sprintf( ...
                'riga %d: dato fuori da ogni sezione ("%s")', k, riga); %#ok<AGROW>
            continue;
        end

        % --- Riga di tabella -------------------------------------------------
        if contains(riga, "|")
            if ~isTabella
                problemi(end+1) = sprintf( ...
                    'riga %d: riga di tabella nella sezione scalare [%s]', ...
                    k, sezioneCorr); %#ok<AGROW>
                continue;
            end
            campi = strtrim(split(riga, "|")).';
            if isempty(intestaz)
                intestaz = campi;
                if numel(unique(intestaz)) ~= numel(intestaz)
                    problemi(end+1) = sprintf( ...
                        'riga %d: intestazione di [%s] con nomi di colonna ripetuti', ...
                        k, sezioneCorr); %#ok<AGROW>
                end
            elseif numel(campi) ~= numel(intestaz)
                problemi(end+1) = sprintf( ...
                    'riga %d: [%s] ha %d colonne, l''intestazione ne dichiara %d', ...
                    k, sezioneCorr, numel(campi), numel(intestaz)); %#ok<AGROW>
            else
                celle(end+1, :) = campi;   %#ok<AGROW>
                righeTab(end+1) = k;       %#ok<AGROW>
            end
            continue;
        end

        % --- Riga chiave = valore --------------------------------------------
        if isTabella
            problemi(end+1) = sprintf( ...
                'riga %d: "%s" non e'' una riga di tabella, ma [%s] e'' tabellare', ...
                k, riga, sezioneCorr); %#ok<AGROW>
            continue;
        end

        parti = split(riga, "=");
        if numel(parti) < 2
            problemi(end+1) = sprintf( ...
                'riga %d: "%s" non e'' nella forma "chiave = valore"', k, riga); %#ok<AGROW>
            continue;
        end
        chiave = matlab.lang.makeValidName(strtrim(parti(1)));
        valore = strtrim(join(parti(2:end), "="));

        [v, noto] = converti_valore(valore);
        CFG.(campoCorr).(chiave)      = v;
        CFG.noto.(campoCorr).(chiave) = noto;
    end

    % Chiude l'ultima tabella rimasta aperta a fine file
    [CFG, problemi] = chiudi_tabella(CFG, problemi, campoCorr, ...
                                     intestaz, celle, righeTab);
end


function [CFG, problemi] = chiudi_tabella(CFG, problemi, campoCorr, intestaz, celle, righeTab)
%CHIUDI_TABELLA  Converte le celle grezze accumulate in una table MATLAB,
%   decidendo il tipo di ciascuna colonna e registrando i '?'.

    if strlength(campoCorr) == 0 || isempty(intestaz), return; end

    if isempty(celle)
        problemi(end+1) = sprintf( ...
            'sezione [%s]: intestazione presente ma nessuna riga di dati', ...
            upper(campoCorr));
        return;
    end

    nCol = numel(intestaz);
    vars = cell(1, nCol);
    nomi = strings(1, nCol);

    for c = 1:nCol
        grezze = celle(:, c);
        nomi(c) = matlab.lang.makeValidName(intestaz(c));

        isNoto = ~(grezze == "?");
        isDato = isNoto & (grezze ~= "-");

        % Colonna numerica se OGNI cella con un dato vero e' un numero.
        % Una colonna interamente '?' resta numerica: e' il caso di un dato
        % che sara' numerico appena qualcuno lo misura.
        num = str2double(grezze(isDato));
        if isempty(num) || all(~isnan(num))
            col            = nan(size(grezze));
            col(isDato)    = num;
            vars{c}        = col;
        else
            col            = grezze;
            col(~isDato)   = "";
            vars{c}        = col;
        end

        % Due granularita', per due usi diversi:
        %   .noto      per COLONNA - decide se passare il vettore al metodo,
        %              e basta un solo buco perche' il vettore non sia un dato
        %   .incognito per CELLA    - distingue '?' da '-' riga per riga, che
        %              serve a dire a chi compila la scheda dove ha sbagliato
        CFG.noto.(campoCorr).(nomi(c))      = all(isNoto);
        CFG.incognito.(campoCorr).(nomi(c)) = ~isNoto;
    end

    CFG.(campoCorr) = table(vars{:}, 'VariableNames', cellstr(nomi));
    CFG.(campoCorr).Properties.UserData = righeTab(:);   % righe nel file
end


function [v, noto] = converti_valore(s)
%CONVERTI_VALORE  Numero, logico o stringa; '?' e '-' diventano mancanti.

    noto = true;
    if s == "?"
        v = NaN; noto = false; return;
    end
    if s == "-"
        v = NaN; return;
    end
    if ismember(lower(s), ["true", "false"])
        v = lower(s) == "true"; return;
    end
    num = str2double(s);
    if ~isnan(num)
        v = num; return;
    end
    v = s;
end


function s = strip_comment(riga)
%STRIP_COMMENT  Toglie il commento e gli spazi. Nessun valore della scheda
%   contiene '#', quindi lo si puo' tagliare ovunque compaia.

    s = string(riga);
    idx = strfind(s, "#");
    if ~isempty(idx)
        s = extractBefore(s, idx(1));
    end
    s = strtrim(s);
end


% ===========================================================================
%  VALIDAZIONI
% ===========================================================================

function problemi = valida_sezioni(CFG, mappaSezioni)
%VALIDA_SEZIONI  Verifica che nessuna sezione manchi del tutto.

    problemi = string.empty(1, 0);
    sezioni  = string(fieldnames(mappaSezioni)).';
    for s = sezioni
        campo = string(mappaSezioni.(s));
        if ~isfield(CFG, campo) || isempty(CFG.(campo))
            problemi(end+1) = sprintf('sezione [%s] assente o vuota', s); %#ok<AGROW>
        end
    end
end


function problemi = valida_membri(CFG)
%VALIDA_MEMBRI  Colonne obbligatorie, domini ammessi, coerenza ruolo/impianto.

    problemi = string.empty(1, 0);
    if ~isfield(CFG, 'membri') || ~istable(CFG.membri), return; end
    M = CFG.membri;

    obbligatorie = ["nome_csv", "ruolo", "categoria", "tariffa", ...
                    "P_prel_kW", "impianto"];
    mancanti = setdiff(obbligatorie, string(M.Properties.VariableNames));
    if ~isempty(mancanti)
        problemi(end+1) = sprintf('[MEMBRI]: colonne obbligatorie mancanti: %s', ...
                                  strjoin(mancanti, ', ')); %#ok<AGROW>
        return;   % senza queste colonne i controlli seguenti non hanno senso
    end

    righe = CFG.membri.Properties.UserData;

    % --- Domini ammessi ------------------------------------------------------
    problemi = [problemi, ...
        controlla_dominio(M.ruolo,     ["C","P","E"], "ruolo",     "[MEMBRI]", righe)];
    problemi = [problemi, ...
        controlla_dominio(M.categoria, ["domestico","terziario","commerciale", ...
                                        "industriale","PA"], ...
                          "categoria", "[MEMBRI]", righe)];
    problemi = [problemi, ...
        controlla_dominio(M.tariffa,   ["MONORARIA","BIORARIA","ORARIO_VARIABILE"], ...
                          "tariffa",   "[MEMBRI]", righe)];

    % --- Nomi duplicati ------------------------------------------------------
    [u, ~, idx] = unique(M.nome_csv);
    dup = u(accumarray(idx, 1) > 1);
    for d = dup(:).'
        problemi(end+1) = sprintf('[MEMBRI]: nome_csv "%s" ripetuto', d); %#ok<AGROW>
    end

    % --- Potenza di prelievo -------------------------------------------------
    bad = isnan(M.P_prel_kW) | M.P_prel_kW <= 0;
    for i = find(bad(:).')
        problemi(end+1) = sprintf( ...
            'riga %d: P_prel_kW mancante o non positiva per "%s" (serve sempre)', ...
            righe(i), M.nome_csv(i)); %#ok<AGROW>
    end

    % --- Coerenza ruolo <-> possesso di impianto ----------------------------
    haImpianto = strlength(M.impianto) > 0;
    isProd     = ismember(M.ruolo, ["P", "E"]);
    for i = find((haImpianto ~= isProd).')
        if isProd(i)
            problemi(end+1) = sprintf( ...
                'riga %d: "%s" ha ruolo %s ma nessun impianto in colonna impianto', ...
                righe(i), M.nome_csv(i), M.ruolo(i)); %#ok<AGROW>
        else
            problemi(end+1) = sprintf( ...
                'riga %d: "%s" ha ruolo C ma possiede l''impianto %s (ruolo P o E?)', ...
                righe(i), M.nome_csv(i), M.impianto(i)); %#ok<AGROW>
        end
    end

    % --- Dati domestici: '-' non e' una risposta ammessa --------------------
    % Per un nucleo domestico reddito e percettori ESISTONO: se non si sanno
    % si scrive '?', che tiene accesa l'ipotesi. Scrivere '-' affermerebbe che
    % quel nucleo non ha reddito, ed e' un'altra cosa.
    isDom = M.categoria == "domestico";
    for campo = ["reddito_EUR", "n_perc", "n_comp"]
        if ~ismember(campo, string(M.Properties.VariableNames)), continue; end
        v = M.(campo);
        if ~isnumeric(v), continue; end
        for i = find((isDom & isnan(v)).')
            if ~cella_e_incognita(CFG, "membri", campo, i)
                problemi(end+1) = sprintf( ...
                    'riga %d: "%s" e'' domestico ma %s vale "-": usare "?" se il dato manca', ...
                    righe(i), M.nome_csv(i), campo); %#ok<AGROW>
            end
        end
    end
end


function problemi = valida_impianti(CFG)
%VALIDA_IMPIANTI  Colonne obbligatorie e legame biunivoco con [MEMBRI].

    problemi = string.empty(1, 0);
    if ~isfield(CFG, 'impianti') || ~istable(CFG.impianti), return; end
    P = CFG.impianti;

    obbligatorie = ["id", "proprietario", "kWp", "file_produzione"];
    mancanti = setdiff(obbligatorie, string(P.Properties.VariableNames));
    if ~isempty(mancanti)
        problemi(end+1) = sprintf('[IMPIANTI]: colonne obbligatorie mancanti: %s', ...
                                  strjoin(mancanti, ', ')); %#ok<AGROW>
        return;
    end

    righe = P.Properties.UserData;

    % --- kWp -----------------------------------------------------------------
    bad = isnan(P.kWp) | P.kWp <= 0;
    for i = find(bad(:).')
        problemi(end+1) = sprintf( ...
            'riga %d: impianto %s senza kWp valida (serve alla tariffa TIP e al Remuneration Model 1)', ...
            righe(i), P.id(i)); %#ok<AGROW>
    end

    % --- File di produzione --------------------------------------------------
    for i = find((strlength(P.file_produzione) == 0).')
        problemi(end+1) = sprintf( ...
            'riga %d: impianto %s senza file_produzione: senza export PVsyst non c''e'' generazione', ...
            righe(i), P.id(i)); %#ok<AGROW>
    end

    if ~isfield(CFG, 'membri') || ~istable(CFG.membri) || ...
       ~ismember("nome_csv", string(CFG.membri.Properties.VariableNames))
        return;
    end
    M = CFG.membri;

    % --- Proprietario esistente ---------------------------------------------
    for i = 1:height(P)
        if ~any(M.nome_csv == P.proprietario(i))
            problemi(end+1) = sprintf( ...
                'riga %d: impianto %s appartiene a "%s", che non e'' fra i membri', ...
                righe(i), P.id(i), P.proprietario(i)); %#ok<AGROW>
        end
    end

    % --- Riferimenti da [MEMBRI] risolti ------------------------------------
    if ismember("impianto", string(M.Properties.VariableNames))
        righeM = M.Properties.UserData;
        for i = find((strlength(M.impianto) > 0).')
            if ~any(P.id == M.impianto(i))
                problemi(end+1) = sprintf( ...
                    'riga %d: "%s" rimanda all''impianto %s, che non esiste in [IMPIANTI]', ...
                    righeM(i), M.nome_csv(i), M.impianto(i)); %#ok<AGROW>
            end
        end
    end
end


function problemi = valida_riepilogo(CFG)
%VALIDA_RIEPILOGO  Il riepilogo dichiarato contro i conteggi reali.
%   Non e' pedanteria: quel blocco e' scritto per essere copiato in tesi, e
%   deve essere impossibile che descriva una comunita' diversa da quella
%   effettivamente simulata.

    problemi = string.empty(1, 0);
    if ~isfield(CFG, 'riepilogo') || ~isfield(CFG, 'membri') || ...
       ~istable(CFG.membri) || ~ismember("ruolo", string(CFG.membri.Properties.VariableNames))
        return;
    end
    R = CFG.riepilogo;
    M = CFG.membri;

    reale = struct( ...
        'membri_totali',   height(M), ...
        'consumatori',     sum(M.ruolo == "C"), ...
        'prosumer',        sum(M.ruolo == "P"), ...
        'produttori_puri', sum(M.ruolo == "E"));

    if isfield(CFG, 'impianti') && istable(CFG.impianti)
        reale.impianti_totali        = height(CFG.impianti);
        if ismember("kWp", string(CFG.impianti.Properties.VariableNames))
            reale.potenza_installata_kWp = sum(CFG.impianti.kWp, 'omitnan');
        end
    end

    for campo = string(fieldnames(reale)).'
        if ~isfield(R, campo) || isnan(R.(campo)), continue; end
        if abs(R.(campo) - reale.(campo)) > 1e-9
            problemi(end+1) = sprintf( ...
                '[RIEPILOGO]: %s dichiarato %g, dalle tabelle risulta %g', ...
                campo, R.(campo), reale.(campo)); %#ok<AGROW>
        end
    end

    % La penetrazione e' una percentuale arrotondata: tolleranza di 0.5 punti.
    if isfield(R, 'penetrazione_prosumer_pct') && ~isnan(R.penetrazione_prosumer_pct) ...
       && height(M) > 0
        attesa = 100 * (reale.prosumer + reale.produttori_puri) / height(M);
        if abs(R.penetrazione_prosumer_pct - attesa) > 0.5
            problemi(end+1) = sprintf( ...
                '[RIEPILOGO]: penetrazione_prosumer_pct dichiarata %.1f%%, dalle tabelle risulta %.1f%%', ...
                R.penetrazione_prosumer_pct, attesa); %#ok<AGROW>
        end
    end
end


function problemi = valida_percorsi(CFG)
%VALIDA_PERCORSI  I file dichiarati devono esistere.

    problemi = string.empty(1, 0);
    if ~isfield(CFG, 'file'), return; end

    for campo = ["profili_carico", "prezzi_zonali"]
        if ~isfield(CFG.file, campo), continue; end
        p = fullfile(CFG.radice, CFG.file.(campo));
        if ~isfile(p)
            problemi(end+1) = sprintf('[FILE].%s non trovato:\n      %s', campo, p); %#ok<AGROW>
        end
    end

    if isfield(CFG.file, 'cartella_pv') && isfield(CFG, 'impianti') && ...
       istable(CFG.impianti) && ...
       ismember("file_produzione", string(CFG.impianti.Properties.VariableNames))
        righe = CFG.impianti.Properties.UserData;
        for i = 1:height(CFG.impianti)
            f = CFG.impianti.file_produzione(i);
            if strlength(f) == 0, continue; end
            p = fullfile(CFG.radice, CFG.file.cartella_pv, f);
            if ~isfile(p)
                problemi(end+1) = sprintf( ...
                    'riga %d: file di produzione non trovato:\n      %s', righe(i), p); %#ok<AGROW>
            end
        end
    end
end


function problemi = controlla_dominio(col, ammessi, nomeCol, sezione, righe)
%CONTROLLA_DOMINIO  Segnala i valori fuori dall'elenco ammesso.

    problemi = string.empty(1, 0);
    if ~isstring(col), col = string(col); end
    for i = find((~ismember(col, ammessi)).')
        problemi(end+1) = sprintf( ...
            'riga %d: %s.%s = "%s" non ammesso (valori: %s)', ...
            righe(i), sezione, nomeCol, col(i), strjoin(ammessi, ' | ')); %#ok<AGROW>
    end
end


function tf = cella_e_incognita(CFG, tabella, colonna, i)
%CELLA_E_INCOGNITA  true se QUELLA cella conteneva un '?', cioe' se il NaN
%   incontrato e' un dato non noto e non un dato non applicabile.
%
%   Il controllo dev'essere per cella: con il flag di colonna, un '-' scritto
%   per errore su una riga passava inosservato finche' un'altra riga della
%   stessa colonna aveva un '?' - cioe' proprio nel caso misto, che e' quello
%   che capita compilando la scheda a poco a poco.

    tf = isfield(CFG, 'incognito') && isfield(CFG.incognito, tabella) && ...
         isfield(CFG.incognito.(tabella), colonna) && ...
         CFG.incognito.(tabella).(colonna)(i);
end


% ===========================================================================
%  USCITA
% ===========================================================================

function P = costruisci_impianti_struct(CFG)
%COSTRUISCI_IMPIANTI_STRUCT  Struct array nel formato atteso da
%   load_cer_data: .file (percorso assoluto), .owner, .kWp.

    n = height(CFG.impianti);
    P = struct('file', cell(1, n), 'owner', cell(1, n), 'kWp', cell(1, n));
    for i = 1:n
        P(i).file  = string(fullfile(CFG.radice, CFG.file.cartella_pv, ...
                                     CFG.impianti.file_produzione(i)));
        P(i).owner = CFG.impianti.proprietario(i);
        P(i).kWp   = CFG.impianti.kWp(i);
    end
end


function stampa_riepilogo(CFG, inputFile)
%STAMPA_RIEPILOGO  Cosa e' stato letto, e quanti dati mancano ancora.

    M = CFG.membri;
    fprintf('\n=== Scheda dati CER ===\n');
    fprintf('  %-22s %s\n', 'File', inputFile);
    fprintf('  %-22s %s (%s, zona %s), anno %d\n', 'Comunita''', ...
            CFG.cer.nome, valore_o_ignoto(CFG.cer.comune), ...
            CFG.cer.zona_mercato, CFG.cer.anno);
    fprintf('  %-22s %d (%d consumatori, %d prosumer, %d produttori puri)\n', ...
            'Membri', height(M), sum(M.ruolo == "C"), ...
            sum(M.ruolo == "P"), sum(M.ruolo == "E"));
    fprintf('  %-22s %d, %.1f kWp totali\n', 'Impianti', ...
            height(CFG.impianti), sum(CFG.impianti.kWp, 'omitnan'));

    % Il conto dei '?' e' l'unica misura onesta di quanto e' pronta la scheda.
    mancanti = elenca_incognite(CFG);
    if isempty(mancanti)
        fprintf('  %-22s nessuno: la scheda e'' completa\n', 'Dati non noti');
    else
        fprintf('  %-22s %d campi ancora a "?":\n', 'Dati non noti', numel(mancanti));
        fprintf('      %s\n', mancanti);
    end
end


function m = elenca_incognite(CFG)
%ELENCA_INCOGNITE  Percorsi "sezione.campo" di tutto cio' che vale '?'.

    m = string.empty(1, 0);
    for sez = string(fieldnames(CFG.noto)).'
        for campo = string(fieldnames(CFG.noto.(sez))).'
            if ~CFG.noto.(sez).(campo)
                m(end+1) = sez + "." + campo; %#ok<AGROW>
            end
        end
    end
end


function s = valore_o_ignoto(v)
%VALORE_O_IGNOTO  Stampa un campo che potrebbe essere '?'.

    if isnumeric(v) && all(isnan(v))
        s = "comune non dichiarato";
    else
        s = string(v);
    end
end


function p = which_or_full(f)
%WHICH_OR_FULL  Percorso assoluto della scheda, sia che sia stata indicata
%   con un percorso relativo alla cartella di lavoro sia che si trovi solo
%   sul path di MATLAB.

    d = dir(f);
    if ~isempty(d)
        p = fullfile(d(1).folder, d(1).name);
    else
        p = which(f);
    end
end
