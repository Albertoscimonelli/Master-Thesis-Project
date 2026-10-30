function E = coalition_excess_enum(phiMat, methodNames, v, userNames, opts)
%COALITION_EXCESS_ENUM  Eccesso di coalizione da una v(S) gia' enumerata, senza matrice
%   di incidenza: la versione di coalition_excess per le comunita' da 19 a 25 membri.
%
%       e_S = v(S) - sum_{i in S} x_i          (Volpato et al., Energies 17 (2024)
%                                               4788, eq. 23)
%
%   E = coalition_excess_enum(phiMat, methodNames, v, userNames, opts)
%
%   Stessa grandezza, stesse regole e stesse uscite di riepilogo di coalition_excess:
%   eccesso della coalizione peggiore, quante coalizioni hanno eccesso positivo, quale
%   e' la peggiore. Significato, segno e lettura sono nel help di coalition_excess.
%   Cambia solo il modo di arrivare alle somme sum_{i in S} x_i.
%
%   PERCHE' UNA SECONDA FUNZIONE
%     coalition_excess moltiplica la matrice di incidenza A_inc [2^n x n] per le quote
%     e tiene l'eccesso di ogni coalizione per ogni metodo ([2^n x nM]): a 25 membri
%     sono 6,7 GB piu' 3,2 GB. Qui le somme sulle coalizioni si costruiscono un
%     giocatore alla volta, come nella separazione di variance_least_core_cer
%     (subset_sums), e un metodo alla volta; dell'eccesso si tengono solo massimo,
%     posizione e conteggio. Memoria: due vettori di 2^n double oltre a v, circa
%     0,5 GB a 25 membri.
%
%   COSA NON RESTITUISCE
%     I campi .excess e .coalitions di coalition_excess (l'eccesso di ogni coalizione e
%     la sua composizione): MAIN2 non li usa, e a 25 membri non starebbero in memoria.
%
%   DIFFERENZE NUMERICHE DA coalition_excess
%     Solo l'ordine delle somme sulle quote: un giocatore alla volta invece del
%     prodotto matriciale. Fra coalizioni a pari merito vince la prima nell'ordine
%     delle bitmask, come in coalition_excess. Il confronto e' in
%     test_coalition_excess_enum.m.
%
%   INPUT
%     phiMat       [n x nM]   una colonna per metodo, quote in EUR
%     methodNames  [1 x nM]   nomi dei metodi                          (string)
%     v            [2^n x 1]  v(S) di tutte le coalizioni, indicizzata dalla bitmask
%                             come in cer_coalition_values (v(m+1) = valore della
%                             coalizione di bitmask m), per esempio da
%                             cer_coalition_values_blocchi. Deve essere la stessa v(S)
%                             su cui giocano i metodi (stessa tariffa, stessi F ed
%                             esenti), altrimenti l'eccesso non vuol dire nulla
%     userNames    [1 x n]    nomi degli utenti                       (string)
%     opts         struct opzionale:
%                    .tol         soglia sopra cui un eccesso conta come positivo
%                                 (def. 1e-9 * max(1, |v(N)|), come coalition_excess)
%                    .maxPlayers  limite di sicurezza sull'enumerazione (def. 25, come
%                                 opts.denseMaxPlayers del VLC)
%                    .quiet       non stampare il riepilogo (def. false)
%
%   OUTPUT (struct E), con lo stesso significato e formato di coalition_excess:
%     .methods, .players, .vGrand, .maxExcess, .maxExcessPct, .nUnstable, .isStable,
%     .worstCoalition, .worstMask, .nCoalitions, .tol, .table
%
%   Vedi anche: coalition_excess, cer_coalition_values_blocchi, variance_least_core_cer

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'maxPlayers'), opts.maxPlayers = 25;    end
    if ~isfield(opts, 'quiet'),      opts.quiet      = false; end

    [n, nM]     = size(phiMat);
    players     = string(userNames(:).');
    methodNames = string(methodNames(:).');

    % --- Guardie sugli ingressi (come coalition_excess) ---------------------
    if numel(players) ~= n
        error('coalition_excess_enum:playerSizeMismatch', ...
              'userNames ha %d elementi, phiMat ha %d righe.', numel(players), n);
    end
    if numel(methodNames) ~= nM
        error('coalition_excess_enum:nameSizeMismatch', ...
              'methodNames ha %d elementi, phiMat ha %d colonne.', ...
              numel(methodNames), nM);
    end
    if ~all(isfinite(phiMat), 'all')
        error('coalition_excess_enum:nonFiniteInput', ...
              'Ripartizioni con NaN o Inf: controllare i dati a monte.');
    end
    if n < 2
        error('coalition_excess_enum:tooFewPlayers', ...
              'Con %d giocatore non ci sono coalizioni proprie da esaminare.', n);
    end
    if n > opts.maxPlayers
        error('coalition_excess_enum:tooManyPlayers', ...
              ['%d giocatori: v(S) avrebbe 2^%d = %.3g elementi. Il limite di %d e'' ' ...
               'quello dell''enumerazione del Variance Least Core (README §14.1).'], ...
              n, n, 2^n, opts.maxPlayers);
    end
    v = v(:);
    if numel(v) ~= 2^n
        error('coalition_excess_enum:valueSizeMismatch', ...
              'v ha %d elementi, con %d giocatori ne servono 2^%d.', numel(v), n, n);
    end

    vGrand = v(end);
    if ~isfield(opts, 'tol'), opts.tol = 1e-9 * max(1, abs(vGrand)); end

    % --- Eccesso di ogni coalizione propria, un metodo alla volta (eq. 23) --
    % La coalizione vuota (indice 1) e la grande coalizione (indice end) restano
    % fuori, come in coalition_excess: eccesso nullo per definizione e per
    % efficienza. max prende il primo indice fra i pari, e le coalizioni sono
    % nell'ordine delle bitmask come le righe di coalition_excess: la coalizione
    % peggiore e' la stessa.
    maxExcess = zeros(nM, 1);
    nUnstable = zeros(nM, 1);
    idxWorst  = zeros(nM, 1);
    for k = 1:nM
        e      = v - local_subset_sums(phiMat(:, k));
        e(1)   = -Inf;
        e(end) = -Inf;
        [maxExcess(k), idxWorst(k)] = max(e);
        nUnstable(k) = nnz(e > opts.tol);
    end
    clear e
    isStable = nUnstable == 0;

    worstMask      = false(nM, n);
    worstCoalition = strings(nM, 1);
    for k = 1:nM
        worstMask(k, :)   = bitget(idxWorst(k) - 1, 1:n) == 1;
        worstCoalition(k) = strjoin(cellstr(players(worstMask(k, :))), '+');
    end

    % --- Struttura di uscita (campi di coalition_excess) --------------------
    E.methods        = methodNames;
    E.players        = players;
    E.vGrand         = vGrand;
    E.maxExcess      = maxExcess;
    E.maxExcessPct   = 100 * maxExcess / vGrand;
    E.nUnstable      = nUnstable;
    E.isStable       = isStable;
    E.worstCoalition = worstCoalition;
    E.worstMask      = worstMask;
    E.nCoalitions    = 2^n - 2;
    E.tol            = opts.tol;

    E.table = table(methodNames(:), maxExcess, E.maxExcessPct, nUnstable, ...
                    isStable, worstCoalition, ...
                    'VariableNames', {'Metodo', 'EccessoMax_EUR', 'EccessoMax_pct', ...
                                      'CoalizioniInstabili', 'Stabile', ...
                                      'CoalizionePeggiore'});

    if ~opts.quiet
        nInst = sum(~isStable);
        fprintf(['  Eccesso di coalizione: %d metodi su %d lasciano almeno una ' ...
                 'coalizione con\n  convenienza a uscire (su %d coalizioni proprie ' ...
                 'esaminate).\n'], nInst, nM, E.nCoalitions);
    end
end


function s = local_subset_sums(x)
%LOCAL_SUBSET_SUMS  sum_{i in S} x_i per ogni bitmask S, nello stesso ordine di v
%   (s(m+1) = somma sulla coalizione di bitmask m). Si aggiunge un giocatore alla
%   volta: le coalizioni col bit i acceso sono quelle senza, piu' x_i. Come
%   subset_sums di variance_least_core_cer.

    n   = numel(x);
    s   = zeros(2^n, 1);
    len = 1;
    for i = 1:n
        s(len+1:2*len) = s(1:len) + x(i);
        len = 2 * len;
    end
end
