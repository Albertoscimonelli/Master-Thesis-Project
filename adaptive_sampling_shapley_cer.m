function S = adaptive_sampling_shapley_cer(genUsers, loadUsers, userNames, P_CER, opts)
%ADAPTIVE_SAMPLING_SHAPLEY_CER  Approssimazione dello Shapley value per
%   CAMPIONAMENTO STRATIFICATO ADATTIVO, secondo l'algoritmo di O'Brien, El
%   Gamal, Rajagopal, IEEE Trans. Smart Grid 6(6) 2015, nella formulazione
%   ripresa e implementata da Cremers, Robu, Zhang, Andoni, Norbu, Flynn,
%   Applied Energy 331 (2023) 120328 (§4.1.3 e Appendice C, eq. C.1-C.7).
%
%   E' il riferimento "stato dell'arte" con cui il paper confronta i propri
%   due metodi deterministici (marginal_contribution_cer.m e
%   stratified_expected_value_cer.m).
%
%   IDEA
%     Lo Shapley e' la media, sugli n strati, del contributo marginale atteso
%     del giocatore a quello strato (eq. 8). Invece di enumerare le coalizioni
%     di ogni strato se ne estraggono M a caso, e la media campionaria stima
%     il contributo atteso. La parte "adattiva" e' COME si spartiscono gli M
%     campioni fra gli strati: non in parti uguali, ma in proporzione alla
%     deviazione standard stimata dei contributi marginali di ciascuno strato
%     (eq. C.1),
%
%       pi_i,j(m) = eps(m)/|strati| + (1 - eps(m)) * sigma_i,j / sum_s sigma_i,s
%
%     cosi' gli strati con contributi molto dispersi -- quelli dove la media
%     campionaria e' piu' incerta -- ricevono piu' campioni. Il peso eps(m) e'
%     una doppia sigmoide (eq. C.2) che vale 1 all'inizio (esplorazione
%     uniforme: le sigma non sono ancora stimate) e decade verso ~0.06 alla
%     fine (sfruttamento: si insiste sugli strati incerti).
%
%     Media e deviazione standard di ogni strato si aggiornano in linea con
%     l'algoritmo di Welford (eq. C.3-C.6), senza conservare i campioni.
%
%   I DUE STRATI DEGENERI
%     Gli strati 0 e n-1 contengono UNA sola coalizione ciascuno (l'insieme
%     vuoto e tutti gli altri giocatori), quindi ricampionarli non aggiunge
%     informazione. Come nell'implementazione del paper (nota in fondo
%     all'Appendice C) vengono valutati una volta sola in modo esatto ed
%     esclusi dal campionamento, che si concentra sugli strati 1..n-2. Ne
%     segue che il termine di strato n-1 e' esattamente il contributo
%     marginale MC_i dell'eq. 9, e quello di strato 0 e' v({i}) = 0.
%
%   NORMALIZZAZIONE
%     Come per gli altri due approssimatori l'efficienza non e' automatica:
%       phi_i = v(N) * RL_i / sum_q RL_q
%
%   IL LIMITE DEL METODO (motivo per cui il paper propone un'alternativa)
%     E' STOCASTICO: rieseguito sugli stessi dati restituisce numeri diversi,
%     e due utenti con profili identici possono ricevere quote diverse. In una
%     CER, dove i membri devono poter riverificare il conto dell'aggregatore,
%     e' un problema di fiducia prima ancora che di accuratezza (§2.2 e §5.3
%     del paper). Qui il generatore casuale e' inizializzato con un SEED
%     esplicito (opts.seed) e isolato dal generatore globale di MATLAB, cosi'
%     l'esecuzione e' riproducibile: cambiare seed cambia i numeri, ed e'
%     proprio questa la variabilita' che il paper contesta.
%
%   NOTA DI SCALA
%     Con n piccolo il metodo NON e' davvero un'approssimazione: lo strato piu'
%     numeroso ha C(n-1, j) coalizioni (10 per n = 6), quindi M = 1000
%     campioni per giocatore le enumerano molte volte e la stima converge allo
%     Shapley esatto a meno del rumore di campionamento. Il divario dal valore
%     esatto diventa significativo solo con decine o centinaia di membri, che
%     e' il regime per cui il metodo e' pensato.
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   valutata su richiesta da cer_shared_value senza enumerare le 2^n coalizioni)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente      [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                       (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%                 .F      scalare  fattore di riduzione per contributo in conto
%                         capitale (def. 0); .esente [n x 1] logico, membri
%                         esenti. La quota esente entra in v(S) COALIZIONE PER
%                         COALIZIONE: vedi cer_shared_value.m
%     opts      struct    opzionale, campi tutti facoltativi:
%                 .M      numero di campioni per giocatore (def. 1000, come
%                         nel paper: va tenuto M >> n)
%                 .seed   seme del generatore casuale   (def. 42)
%                 .beta   parametro della sigmoide eq. C.2 (def. 0.075)
%                 .gamma  parametro della sigmoide eq. C.2 (def. 0.2)
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici
%     .players       [1 x n]  nomi dei giocatori (= userNames)
%     .phi           [n x 1]  ripartizione normalizzata               [EUR]
%     .vGrand        scalare  valore della grande coalizione          [EUR]
%     .isProsumer    [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare     scalare  quota totale ai prosumer                [EUR]
%     .consShare     scalare  quota totale ai consumatori puri        [EUR]
%     .rlRaw         [n x 1]  stime grezze RL_i, eq. C.7              [EUR]
%     .muStrata      [n x n]  contributo marginale medio stimato:
%                             riga = giocatore, colonna j+1 = strato j [EUR]
%     .sdStrata      [n x n]  deviazione standard stimata per strato  [EUR]
%     .samplesPerStratum [n x n]  campioni effettivamente spesi per strato
%     .M             scalare  campioni per giocatore usati
%     .seed          scalare  seme usato (per riprodurre l'esecuzione)
%     .normFactor    scalare  v(N) / sum(RL)
%     .table         table    riepilogo (giocatore, quota, percentuale)

    [H, n]  = size(loadUsers);
    players = string(userNames(:).');

    if size(genUsers, 2) ~= n
        error('adaptive_sampling_shapley_cer:sizeMismatch', ...
              'genUsers ha %d colonne, loadUsers ne ha %d: serve una colonna per utente.', ...
              size(genUsers, 2), n);
    end
    if ~all(isfinite(genUsers), 'all') || ~all(isfinite(loadUsers), 'all')
        error('adaptive_sampling_shapley_cer:nonFiniteInput', ...
              'Profili con NaN o Inf in ingresso: controllare i dati a monte.');
    end

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'M')     || isempty(opts.M),     opts.M     = 1000;  end
    if ~isfield(opts, 'seed')  || isempty(opts.seed),  opts.seed  = 42;    end
    if ~isfield(opts, 'beta')  || isempty(opts.beta),  opts.beta  = 0.075; end
    if ~isfield(opts, 'gamma') || isempty(opts.gamma), opts.gamma = 0.2;   end

    if opts.M < n
        warning('adaptive_sampling_shapley_cer:tooFewSamples', ...
                ['M = %d campioni per %d strati: il paper richiede M >> n ' ...
                 'perche'' ogni strato sia visitato piu'' volte.'], opts.M, n);
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    % Generatore ISOLATO: non tocca lo stato del generatore globale di MATLAB,
    % cosi' eseguire questo metodo non altera altri risultati casuali della
    % sessione, e a parita' di seed l'esecuzione e' riproducibile.
    rs = RandStream('mt19937ar', 'Seed', opts.seed);

    % --- Fattore F ed esenzione ---------------------------------------------
    if ~isfield(opts, 'esente'), opts.esente = []; end
    if ~isfield(opts, 'F'),      opts.F      = 0;  end
    if isempty(opts.esente)
        esente = false(n, 1);
    else
        esente = logical(opts.esente(:));
    end
    Fred = opts.F;

    % --- Grande coalizione --------------------------------------------------
    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    loadEsC  = sum(loadUsers(:, esente), 2);
    vGrand   = cer_shared_value(genComm, loadComm, P_CER, loadEsC, Fred);

    % --- Sigmoide eps(m) (eq. C.2), precalcolata per tutti i campioni -------
    % eps(0) = 1 (esplorazione uniforme), eps(M) ~ 0.06 (sfruttamento).
    m       = (1:opts.M).';
    epsSig  = 1 + 1 ./ (1 + exp(opts.gamma / opts.beta)) ...
                - 1 ./ (1 + exp(-(m - opts.gamma * opts.M) / (opts.beta * opts.M)));

    % Strati campionabili: tutti tranne 0 e n-1, che hanno una sola coalizione
    % e vengono valutati esattamente (vedi intestazione). Indici 1-based:
    % colonna j+1 corrisponde allo strato j.
    eligible = 2:(n-1);

    muStrata  = zeros(n, n);
    sdStrata  = zeros(n, n);
    hits      = zeros(n, n);

    for i = 1:n
        others = setdiff(1:n, i);

        % --- Strati degeneri, valutati una volta in forma esatta ------------
        % Strato 0: coalizione vuota. v({i}) - v({}) = v({i}), nullo con
        % profili netti (eccedenza e carico sono complementari) ma calcolato
        % comunque, per non dipendere da quell'ipotesi.
        muStrata(i, 1) = cer_shared_value(genUsers(:, i), loadUsers(:, i), P_CER, ...
                                          loadUsers(:, i) * esente(i), Fred);
        hits(i, 1)     = 1;

        % Strato n-1: tutti gli altri. E' il contributo marginale MC_i (eq. 9).
        vWithout       = cer_shared_value(genComm  - genUsers(:,  i), ...
                                          loadComm - loadUsers(:, i), P_CER, ...
                                          loadEsC - loadUsers(:, i) * esente(i), Fred);
        muStrata(i, n) = vGrand - vWithout;
        hits(i, n)     = 1;

        if isempty(eligible)
            continue;    % n <= 2: nessuno strato da campionare, gia' esatto
        end

        % --- Campionamento adattivo sugli strati intermedi ------------------
        % sigma inizializzata a un valore molto grande (come nel paper) perche'
        % all'inizio ogni strato risulti ugualmente "incerto" e venga visitato.
        sigma = 1e4 * ones(1, numel(eligible));
        m2    = zeros(1, numel(eligible));

        for s = 1:opts.M
            % Probabilita' di scelta dello strato (eq. C.1), ristretta agli
            % strati campionabili: il termine uniforme e' quindi 1/|eligible|
            % e non 1/n, conseguenza diretta dell'esclusione dei due degeneri.
            sumSigma = sum(sigma);
            if sumSigma > 0
                prob = epsSig(s) / numel(eligible) + (1 - epsSig(s)) * sigma / sumSigma;
            else
                prob = ones(1, numel(eligible)) / numel(eligible);
            end
            prob = prob / sum(prob);                  % guardia numerica

            k = find(rand(rs) <= cumsum(prob), 1);    % strato scelto (indice in eligible)
            if isempty(k), k = numel(eligible); end
            col = eligible(k);                        % colonna in muStrata
            j   = col - 1;                            % cardinalita' dello strato

            % Coalizione casuale di j giocatori fra gli altri n-1
            sel   = others(randperm(rs, n - 1, j));
            genS   = sum(genUsers(:,  sel), 2);
            loadS  = sum(loadUsers(:, sel), 2);
            loadEs = sum(loadUsers(:, sel(esente(sel))), 2);

            mc = cer_shared_value(genS + genUsers(:,  i), ...
                                  loadS + loadUsers(:, i), P_CER, ...
                                  loadEs + loadUsers(:, i) * esente(i), Fred) ...
               - cer_shared_value(genS, loadS, P_CER, loadEs, Fred);

            % Aggiornamento in linea di media e varianza (eq. C.3-C.6, Welford)
            delta            = mc - muStrata(i, col);
            hits(i, col)     = hits(i, col) + 1;
            muStrata(i, col) = muStrata(i, col) + delta / hits(i, col);
            m2(k)            = m2(k) + delta * (mc - muStrata(i, col));
            if hits(i, col) > 1
                sigma(k) = sqrt(m2(k) / (hits(i, col) - 1));
            end
        end

        sdStrata(i, eligible) = sigma;
    end

    % --- Stima dello Shapley: media sugli n strati (eq. C.7) ----------------
    rl = mean(muStrata, 2);

    sumRL = sum(rl);
    if sumRL <= 0
        error('adaptive_sampling_shapley_cer:degenerateGame', ...
              ['Somma delle stime non positiva (%.6g): nessuna energia ' ...
               'condivisa da ripartire (v(N) = %.6g EUR).'], sumRL, vGrand);
    end

    % --- Normalizzazione all'efficienza -------------------------------------
    normFactor = vGrand / sumRL;
    phi        = normFactor * rl;

    % --- Output -------------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';        % chi porta produzione nel gioco

    S.players           = players;
    S.phi               = phi;
    S.vGrand            = vGrand;
    S.isProsumer        = isProsumer;
    S.prodShare         = sum(phi(isProsumer));
    S.consShare         = sum(phi(~isProsumer));
    S.rlRaw             = rl;
    S.muStrata          = muStrata;
    S.sdStrata          = sdStrata;
    S.samplesPerStratum = hits;
    S.M                 = opts.M;
    S.seed              = opts.seed;
    S.normFactor        = normFactor;
    S.table             = table(players(:), phi, 100*phi/vGrand, ...
                                'VariableNames', ...
                                {'Giocatore', 'AdaptiveSampling_EUR', 'Quota_pct'});
end
