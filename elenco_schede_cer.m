function [schede, info] = elenco_schede_cer(opts)
%ELENCO_SCHEDE_CER  Le schede che MAIN2 analizza: la griglia di CER_configuration/
%   piu' le varianti con PA di CER_configuration_PA/, fino a un tetto di membri.
%
%   PERCHE' UNA FUNZIONE E NON LE QUATTRO RIGHE DI PRIMA
%     Fino al 18 ottobre MAIN2 leggeva solo CER_configuration/ e il tetto sulla
%     taglia si faceva a mano, elencando le schede in MAIN2_SCHEDE. Con l'asse
%     composizione le schede sono quattro volte tante e hanno lo stesso nome in
%     cartelle diverse (CER_5_5_0 esiste in CER_configuration/ e in PA1, PA2,
%     PA3): l'elenco va costruito, e merita un auto-test.
%
%   LE CARTELLE
%     CER_configuration/        livello 0, solo domestici
%     CER_configuration_PA/PAk/ livello k = k pubbliche amministrazioni (k >= 1)
%     PA0/ NON si legge: e' una copia di CER_configuration/ con i percorsi
%     adattati (stessi dati, verificato con diff su tre schede), e leggerla
%     raddoppierebbe il livello 0.
%     Il livello che conta per l'analisi e' pero' quello DEI DATI (quanti membri
%     hanno categoria PA), non quello della cartella: MAIN2 verifica che
%     coincidano, e una scheda finita nella cartella sbagliata si ferma li'.
%
%   IL TETTO
%     N = C + P + E si legge dal nome CER_<C>_<P>_<E>.txt; la scheda e' poi
%     validata da load_cer_input, che si ferma se [RIEPILOGO] non torna. Oltre
%     18 membri Shapley, Nucleolo ed eccesso di coalizione non si calcolano
%     (2^n), e oltre 25 il Variance Least Core non converge: il default e' 18,
%     il run a 25 si ottiene con MAIN2_MAX_UTENTI=25.
%
%   L'ASSE IMPRESE (non domestici), SPENTO DI DEFAULT
%     CER_configuration_IND/ND<k>/        k imprese
%     CER_configuration_IND/ND<k>_PA<p>/  k imprese + p PA
%     Si legge solo con opts.conIND = true (il default lascia l'elenco identico a
%     prima). LivelloCartella diventa il codice 10*k + p (0..3 per base e PA, 10, 11,
%     ..., 53 per le imprese) e la tabella ha due colonne in piu': LivelloND = k e
%     LivelloPA = p. L'etichetta e' "ND3_PA2/CER_9_9_0". MAIN2 NON le legge ancora:
%     il suo controllo "livello della cartella = numero di PA" si ferma sui codici ND.
%
%   LA SELEZIONE ESPLICITA
%     opts.selezione (MAIN2_SCHEDE) vince sul tetto: chi elenca una scheda la
%     vuole. Un nome senza cartella e' una scheda di CER_configuration/ (e' la
%     sintassi di prima, i comandi vecchi funzionano); "PA2/CER_5_5_0" e' la
%     variante PA2. "PA0/..." e' accettato e vale come livello 0.
%
%   INPUT (struct opzionale)
%     .cartellaBase   def. "CER_configuration"
%     .cartellaPA     def. "CER_configuration_PA"
%     .cartellaIND    def. "CER_configuration_IND"
%     .conIND         def. false; true aggiunge le cartelle ND (vedi sopra)
%     .maxUtenti      def. 18
%     .selezione      string array di nomi senza ".txt" (def. vuoto = tutte)
%     .validateSelf   auto-test su una cartella temporanea (def. true)
%
%   OUTPUT
%     schede  [n x 1] string  percorsi con '/' (come in MAIN2), livello 0 per
%                             primo, poi PA1, PA2, ...; dentro ogni cartella
%                             in ordine alfabetico
%     info    table           Scheda, Etichetta, Cartella, LivelloCartella, N, C, P, E
%                             Etichetta = nome per il livello 0, "PAk/nome" per gli altri
%
%   Vedi anche: MAIN2, load_cer_input

    if nargin < 1 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'cartellaBase'), opts.cartellaBase = "CER_configuration"; end
    if ~isfield(opts, 'cartellaPA'),   opts.cartellaPA   = "CER_configuration_PA"; end
    if ~isfield(opts, 'cartellaIND'),  opts.cartellaIND  = "CER_configuration_IND"; end
    if ~isfield(opts, 'conIND'),       opts.conIND       = false; end
    if ~isfield(opts, 'maxUtenti'),    opts.maxUtenti    = 18; end
    if ~isfield(opts, 'selezione'),    opts.selezione    = strings(0, 1); end
    if ~isfield(opts, 'validateSelf'), opts.validateSelf = true; end

    if opts.validateSelf, local_validate_self(); end

    base = string(opts.cartellaBase);
    pa   = string(opts.cartellaPA);
    ind  = "";
    if opts.conIND, ind = string(opts.cartellaIND); end
    T    = local_scansiona(base, pa, ind);

    assert(any(T.LivelloCartella == 0), ...
           'Nessuna scheda CER_*.txt in %s: non c''e'' niente da analizzare.', base);

    sel = strtrim(string(opts.selezione(:)));
    sel = sel(strlength(sel) > 0);

    if isempty(sel)
        tieni = T.N <= opts.maxUtenti;
    else
        voluti = strings(numel(sel), 1);
        for q = 1:numel(sel)
            nome = sel(q);
            if startsWith(nome, "PA0/")
                nome = extractAfter(nome, "PA0/");           % livello 0 = base
            end
            if startsWith(nome, "ND")
                voluti(q) = ind + "/" + nome + ".txt";        % ND3/CER_9_9_0, ND3_PA2/CER_9_9_0
            elseif contains(nome, "/")
                voluti(q) = pa + "/" + nome + ".txt";
            else
                voluti(q) = base + "/" + nome + ".txt";
            end
        end
        mancanti = voluti(~ismember(voluti, T.Scheda));
        if ~isempty(mancanti)
            error('elenco_schede_cer:schedaInesistente', ...
                  'MAIN2_SCHEDE: schede inesistenti: %s', strjoin(mancanti, ', '));
        end
        tieni = ismember(T.Scheda, voluti);
    end

    info    = T(tieni, :);
    schede  = info.Scheda;
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function T = local_scansiona(base, pa, ind)
%LOCAL_SCANSIONA  Tutte le schede delle cartelle, livello 0 per primo.

    cartelle = base;
    livelli  = 0;
    lvND     = 0;
    if isfolder(pa)
        d    = dir(pa);
        nomi = string({d([d.isdir]).name});
        k    = nan(size(nomi));
        for q = 1:numel(nomi)
            tok = regexp(nomi(q), '^PA([1-9]\d*)$', 'tokens', 'once');
            if ~isempty(tok), k(q) = str2double(tok{1}); end
        end
        ok = ~isnan(k);
        [k, o]   = sort(k(ok));
        nomi     = nomi(ok);
        cartelle = [cartelle, pa + "/" + nomi(o)];
        livelli  = [livelli, k];
        lvND     = [lvND, zeros(size(k))];
    end

    % Asse "non domestici" (CER_configuration_IND/): ND<k> = k imprese,
    % ND<k>_PA<p> = k imprese + p PA. Il livello e' il codice 10*k + p, cosi'
    % le cartelle PA (k = 0) restano 0..3 e un ND non si confonde con loro.
    % Ordine: per codice crescente, dopo il livello 0 e le PA.
    etichIND = strings(1, 0);
    if strlength(ind) > 0 && isfolder(ind)
        d    = dir(ind);
        nomi = string({d([d.isdir]).name});
        kk = nan(size(nomi));  pp = nan(size(nomi));
        for q = 1:numel(nomi)
            % due pattern e non uno con gruppo facoltativo: regexp(...,'once') non
            % restituisce il secondo token di un gruppo dentro (?:...)?
            tok = regexp(nomi(q), '^ND([1-9]\d*)_PA([1-9]\d*)$', 'tokens', 'once');
            if numel(tok) == 2
                kk(q) = str2double(tok(1));  pp(q) = str2double(tok(2));
            else
                tok = regexp(nomi(q), '^ND([1-9]\d*)$', 'tokens', 'once');
                if ~isempty(tok), kk(q) = str2double(tok(1));  pp(q) = 0; end
            end
        end
        ok = ~isnan(kk);
        [~, o] = sort(10 * kk(ok) + pp(ok));
        nomi = nomi(ok);  kk = kk(ok);  pp = pp(ok);
        cartelle = [cartelle, ind + "/" + nomi(o)];
        livelli  = [livelli, pp(o)];
        lvND     = [lvND, kk(o)];
        etichIND = nomi(o);
    end

    Scheda = strings(0, 1);  Etichetta = strings(0, 1);  Cartella = strings(0, 1);
    Livello = zeros(0, 1);   NCPE = zeros(0, 4);   LvND = zeros(0, 1);
    for q = 1:numel(cartelle)
        e    = dir(cartelle(q) + "/CER_*.txt");
        nomi = sort(string({e.name}).');
        for f = nomi.'
            tok = regexp(f, '^CER_(\d+)_(\d+)_(\d+)\.txt$', 'tokens', 'once');
            if isempty(tok)
                error('elenco_schede_cer:nomeNonValido', ...
                      ['%s/%s: il nome non e'' CER_<consumatori>_<prosumer>_<puri>.txt, ' ...
                       'quindi non se ne ricava il numero di membri.'], cartelle(q), f);
            end
            c = str2double(string(tok));
            stem = erase(f, ".txt");
            Scheda(end+1, 1)    = cartelle(q) + "/" + f;                 %#ok<AGROW>
            if lvND(q) > 0
                Etichetta(end+1, 1) = etichIND(q - (numel(cartelle) - numel(etichIND))) + "/" + stem; %#ok<AGROW>
            elseif livelli(q) == 0
                Etichetta(end+1, 1) = stem;                              %#ok<AGROW>
            else
                Etichetta(end+1, 1) = "PA" + livelli(q) + "/" + stem;    %#ok<AGROW>
            end
            Cartella(end+1, 1)  = cartelle(q);                           %#ok<AGROW>
            Livello(end+1, 1)   = 10 * lvND(q) + livelli(q);             %#ok<AGROW>
            LvND(end+1, 1)      = lvND(q);                               %#ok<AGROW>
            NCPE(end+1, :)      = [sum(c) c];                            %#ok<AGROW>
        end
    end
    LivelloPA = mod(Livello, 10);
    T = table(Scheda, Etichetta, Cartella, Livello, NCPE(:, 1), NCPE(:, 2), ...
              NCPE(:, 3), NCPE(:, 4), LvND, LivelloPA, 'VariableNames', ...
              {'Scheda', 'Etichetta', 'Cartella', 'LivelloCartella', 'N', 'C', 'P', 'E', ...
               'LivelloND', 'LivelloPA'});
end


function local_validate_self()
%LOCAL_VALIDATE_SELF  Cartella temporanea con schede finte: ordine, tetto,
%   selezione, PA0 saltata, errori. Nessun file del progetto viene letto.

    radice = string(tempname);
    mkdir(radice);
    pulizia = onCleanup(@() rmdir(radice, 's'));
    b = radice + "/base";   p = radice + "/pa";
    for d = [b, p + "/PA0", p + "/PA1", p + "/PA2"]
        mkdir(d);
    end
    crea = @(cartella, nomi) arrayfun(@(n) fclose(fopen(cartella + "/" + n, 'w')), nomi);
    crea(b, ["CER_4_4_0.txt", "CER_2_3_0.txt", "CER_0_18_0.txt", "CER_0_20_0.txt", ...
             "scenario_economico.txt", "bozza_CER_1_1_0.txt"]);
    crea(p + "/PA0", ["CER_2_3_0.txt"]);
    crea(p + "/PA1", ["CER_0_20_0.txt", "CER_2_3_0.txt"]);
    crea(p + "/PA2", ["CER_4_4_0.txt", "CER_2_3_0.txt"]);

    o = struct('cartellaBase', b, 'cartellaPA', p, 'validateSelf', false);

    % --- 1) Default 18: livello 0 per primo, PA0 e bozze fuori, nome alfabetico
    [s, I] = elenco_schede_cer(o);
    assert(isequal(I.Etichetta, ["CER_0_18_0"; "CER_2_3_0"; "CER_4_4_0"; ...
                                 "PA1/CER_2_3_0"; "PA2/CER_2_3_0"; "PA2/CER_4_4_0"]), ...
           'elenco_schede_cer: ordine o contenuto del default sbagliati');
    assert(isequal(I.LivelloCartella, [0; 0; 0; 1; 2; 2]) && all(I.N <= 18) && ...
           isequal(I.N, [18; 5; 8; 5; 5; 8]), 'elenco_schede_cer: livello o N sbagliati');
    assert(all(contains(s, "/")) && ~any(contains(s, "PA0")), ...
           'elenco_schede_cer: PA0 non va letta');

    % --- 2) Il tetto
    o2 = o;  o2.maxUtenti = 5;
    [~, I2] = elenco_schede_cer(o2);
    assert(isequal(I2.Etichetta, ["CER_2_3_0"; "PA1/CER_2_3_0"; "PA2/CER_2_3_0"]), ...
           'elenco_schede_cer: il tetto a 5 membri non funziona');
    o2.maxUtenti = Inf;
    [~, I2] = elenco_schede_cer(o2);
    assert(height(I2) == 8, 'elenco_schede_cer: senza tetto devono esserci tutte le 8');

    % --- 3) La selezione vince sul tetto, il livello 0 e' il default dei nomi
    o3 = o;  o3.selezione = ["PA2/CER_4_4_0", "CER_0_20_0", "PA0/CER_2_3_0"];
    [~, I3] = elenco_schede_cer(o3);
    assert(isequal(I3.Etichetta, ["CER_0_20_0"; "CER_2_3_0"; "PA2/CER_4_4_0"]), ...
           'elenco_schede_cer: selezione, ordine o alias PA0 sbagliati');

    % --- 3b) Asse imprese: spento di default, acceso con conIND
    i = radice + "/ind";
    for d = [i + "/ND1", i + "/ND1_PA2", i + "/ND3", i + "/ND3_PA1", i + "/ND3_PA3"]
        mkdir(d);
    end
    crea(i + "/ND1",     ["CER_4_4_0.txt", "CER_0_20_0.txt"]);
    crea(i + "/ND1_PA2", ["CER_4_4_0.txt"]);
    crea(i + "/ND3",     ["CER_0_20_0.txt", "CER_4_4_0.txt"]);
    crea(i + "/ND3_PA1", ["CER_4_4_0.txt"]);
    crea(i + "/ND3_PA3", ["CER_0_20_0.txt"]);
    o5 = o;  o5.cartellaIND = i;
    [~, I5] = elenco_schede_cer(o5);
    assert(isequal(I5.Etichetta, I.Etichetta) && all(I5.LivelloND == 0), ...
           'elenco_schede_cer: senza conIND le cartelle ND non vanno lette');
    o5.conIND = true;  o5.maxUtenti = Inf;
    [~, I5] = elenco_schede_cer(o5);
    ND = I5(I5.LivelloND > 0, :);
    assert(isequal(ND.Etichetta, ["ND1/CER_0_20_0"; "ND1/CER_4_4_0"; "ND1_PA2/CER_4_4_0"; ...
                                  "ND3/CER_0_20_0"; "ND3/CER_4_4_0"; "ND3_PA1/CER_4_4_0"; ...
                                  "ND3_PA3/CER_0_20_0"]) && ...
           isequal(ND.LivelloCartella, [10; 10; 12; 30; 30; 31; 33]) && ...
           isequal(ND.LivelloND, [1; 1; 1; 3; 3; 3; 3]) && ...
           isequal(ND.LivelloPA, [0; 0; 2; 0; 0; 1; 3]), ...
           'elenco_schede_cer: ordine, codici o etichette delle cartelle ND sbagliati');
    o6 = o5;  o6.conIND = false;
    [~, I6] = elenco_schede_cer(o6);
    assert(isequal(I5.Etichetta(I5.LivelloND == 0), I6.Etichetta), ...
           'elenco_schede_cer: con conIND il livello 0 e le PA non devono cambiare');
    o5.maxUtenti = 8;
    [~, I5b] = elenco_schede_cer(o5);
    assert(all(I5b.N <= 8), 'elenco_schede_cer: il tetto deve valere anche per le ND');
    o5.selezione = "ND3_PA1/CER_4_4_0";
    [~, I5c] = elenco_schede_cer(o5);
    assert(isequal(I5c.Etichetta, "ND3_PA1/CER_4_4_0"), ...
           'elenco_schede_cer: la selezione "ND3_PA1/..." non funziona');

    % --- 4) Errori parlanti
    esito = 'nessun errore';
    o4 = o;  o4.selezione = "CER_9_9_9";
    try, elenco_schede_cer(o4); catch ME, esito = ME.identifier; end
    assert(strcmp(esito, 'elenco_schede_cer:schedaInesistente'), ...
           'elenco_schede_cer: una scheda inesistente deve fermare l''esecuzione');

    fclose(fopen(b + "/CER_x.txt", 'w'));
    esito = 'nessun errore';
    try, elenco_schede_cer(o); catch ME, esito = ME.identifier; end
    assert(strcmp(esito, 'elenco_schede_cer:nomeNonValido'), ...
           'elenco_schede_cer: un nome non CER_C_P_E deve fermare l''esecuzione');
end
