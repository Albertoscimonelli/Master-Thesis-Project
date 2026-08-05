function S = weighted_solidarity_cer(genUsers, loadUsers, userNames, P_CER, opts)
%WEIGHTED_SOLIDARITY_CER  Ripartizione dell'incentivo CER tramite il modello
%   pesato tecnica+solidarieta' di Marrasso, Martone, Perugini, Roselli,
%   "Towards a fair revenue distribution of a Renewable Energy Community
%   through a proportional energy consumption model application", J. Phys.:
%   Conf. Ser. 3143 (2025) 012113 (eq. 2.1-2.8), incluso il fronte di Pareto
%   per la scelta dei coefficienti (paper §3.2).
%
%   IDEA
%     Ogni ora, l'incentivo G_REC(t) = ES(t)*(P_CER(t)+V) viene ripartito tra
%     gli utenti in proporzione a un peso omega_i(t) = beta1*B1_i(t) +
%     beta2*B2_i, somma di:
%       - B1_i(t) = alpha1*E_SH_i(t) + alpha2*E_load_i(t)   (componente
%         TECNICA: energia condivisa dall'utente + suo carico residuo)
%       - B2_i in {1,3,5}                                    (componente di
%         SOLIDARIETA': punteggio a scalini sui quartili del costo unitario
%         dell'energia Cu_i, proxy di poverta' energetica)
%     I quattro coefficienti (alpha1,alpha2,beta1,beta2) NON sono fissati a
%     priori: si esplora una griglia di combinazioni, si scarta quelle
%     dominate (fronte di Pareto tra indice di Gini minimo e reddito medio
%     massimo degli utenti "potenzialmente in poverta' energetica"), e si
%     sceglie la combinazione Pareto-ottima piu' vicina al punto Utopia
%     (il meglio dei due mondi, ipotetico).
%
%   E_SH_i(t) — energia condivisa dell'utente i all'ora t (eq. 2.2-2.3)
%     Se la produzione di comunita' copre l'intero carico residuo di
%     comunita' (genComm(t) >= loadComm(t)), ogni utente riceve la sua
%     energia condivisa pari al proprio carico residuo; altrimenti la quota
%     (piu' piccola) di energia condivisa si divide in proporzione al
%     carico residuo di ciascuno.
%
%   Cu_i — costo unitario dell'energia [EUR/kWh] (proxy di poverta' energetica)
%     Non esistono dati di bolletta reali nel progetto: Cu_i viene derivato
%     internamente chiamando profilo_prezzi_pun_2025.m (stessa tariffa PUN
%     usata in MAIN.m §4) sullo STESSO loadUsers ricevuto in ingresso, cosi'
%     la funzione resta pura e autosufficiente. Con opts.tariffMode di
%     default "MONORARIA" (prezzo piatto), Cu_i NON dipende dal fatto che
%     loadUsers passato sia il carico lordo o quello residuo netto da
%     autoconsumo: il prezzo costante si semplifica nel rapporto costo/kWh.
%     Con "BIORARIA"/"ORARIO_VARIABILE" questa invarianza NON vale piu': per
%     i prosumer, l'autoconsumo rimuove preferenzialmente le ore diurne
%     (fascia F1, piu' cara), quindi Cu_i calcolato su loadForShare tende a
%     essere PIU' BASSO del costo medio reale (Tcost di MAIN.m §4, che usa
%     il carico lordo) — scelta di design dichiarata, non un bug.
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct    opzionale, campi tutti facoltativi:
%                 .V                    tariffa cost-reflective aggiuntiva
%                                       [EUR/kWh] (def. 0, per restare
%                                       confrontabile con v(N) degli altri
%                                       8 metodi)
%                 .tariffMode           "MONORARIA"|"BIORARIA"|"ORARIO_VARIABILE"
%                                       per il calcolo di Cu_i (def. "MONORARIA")
%                 .alpha1Range          griglia alpha1 (def. 1:5:30)
%                 .alpha2Range          griglia alpha2 (def. 1:5:30)
%                 .beta1Range           griglia beta1, DEVE essere > 0 (def. 1:1:10)
%                 .beta2Range           griglia beta2, DEVE essere > 0 (def. 1:1:10)
%                 .normalizeObjectives  normalizza Gini/reddito EP a [0,1]
%                                       prima della distanza dal punto
%                                       Utopia (def. true — raccomandato:
%                                       senza normalizzare, la scala EUR
%                                       domina la scala Gini adimensionale
%                                       e la selezione ignora quasi del
%                                       tutto l'equita'; false riproduce
%                                       letteralmente la Fig. 3 del paper)
%                 .verbose              stampa avanzamento (def. false)
%
%   OUTPUT (struct S)
%     .players       [1 x n]  nomi dei giocatori (= userNames)
%     .phi           [n x 1]  ripartizione Weighted Solidarity        [EUR]
%     .vGrand        scalare  valore della grande coalizione           [EUR]
%     .isProsumer    [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare     scalare  quota totale ai prosumer                 [EUR]
%     .consShare     scalare  quota totale ai consumatori puri         [EUR]
%     .alpha1, .alpha2, .beta1, .beta2   coefficienti della combinazione vincente
%     .giniIndex     scalare  indice di Gini della combinazione vincente
%     .nParetoPoints scalare  numero di combinazioni Pareto-ottime trovate
%     .paretoFront   table    alpha1,alpha2,beta1,beta2,Gini,EPavg_EUR per
%                             ogni combinazione Pareto-ottima (riusabile per
%                             riprodurre la Fig. 3 del paper)
%     .utopia        [1 x 2]  [minGini, maxEPavg] osservati su TUTTA la griglia
%     .Cu            [n x 1]  costo unitario stimato per utente        [EUR/kWh]
%     .B2            [n x 1]  punteggio di solidarieta' {1,3,5}
%     .isPotentialEP [n x 1]  logico, true se Cu_i > mediana(Cu)
%     .V, .tariffMode  eco degli opts usati
%     .table         table    riepilogo con Cu/B2/PotentialEP per utente

    H = size(loadUsers, 1);
    n = size(loadUsers, 2);
    players = string(userNames(:).');

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'V'),                   opts.V                   = 0;          end
    if ~isfield(opts, 'tariffMode'),           opts.tariffMode           = "MONORARIA"; end
    if ~isfield(opts, 'alpha1Range'),          opts.alpha1Range          = 1:5:30;    end
    if ~isfield(opts, 'alpha2Range'),          opts.alpha2Range          = 1:5:30;    end
    if ~isfield(opts, 'beta1Range'),           opts.beta1Range           = 1:1:10;    end
    if ~isfield(opts, 'beta2Range'),           opts.beta2Range           = 1:1:10;    end
    if ~isfield(opts, 'normalizeObjectives'),  opts.normalizeObjectives  = true;      end
    if ~isfield(opts, 'verbose'),              opts.verbose              = false;     end

    if any(opts.beta1Range <= 0) || any(opts.beta2Range <= 0)
        error('weighted_solidarity_cer:invalidBetaRange', ...
              ['opts.beta1Range e opts.beta2Range devono essere strettamente ' ...
               'positivi: garantiscono omega(t) > 0 per costruzione (B2 in ' ...
               '{1,3,5}, mai zero), evitando divisioni 0/0 nel calcolo delle quote.']);
    end
    if any(opts.alpha1Range < 0) || any(opts.alpha2Range < 0)
        error('weighted_solidarity_cer:invalidAlphaRange', ...
              'opts.alpha1Range e opts.alpha2Range non possono contenere valori negativi.');
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    % --- Precompute: incentivo orario e energia condivisa per utente --------
    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    ES       = min(genComm, loadComm);
    GREC     = ES .* (P_CER + opts.V);           % [H x 1]
    vGrand   = sum(GREC);

    covered = genComm >= loadComm;                % [H x 1] logico
    ESH = zeros(H, n);
    ESH(covered, :) = loadUsers(covered, :);
    notCov = ~covered & (loadComm > 0);
    ESH(notCov, :) = loadUsers(notCov, :) ./ loadComm(notCov) .* ES(notCov);

    % --- Cu_i: costo unitario derivato dalla tariffa PUN, sullo stesso
    %     loadUsers ricevuto in ingresso (funzione pura, vedi header) --------
    TTprice = profilo_prezzi_pun_2025(opts.tariffMode);
    price   = TTprice.Prezzo;
    if numel(price) ~= H
        error('weighted_solidarity_cer:priceGridMismatch', ...
              'Il profilo prezzi PUN ha %d ore, loadUsers ne ha %d.', numel(price), H);
    end
    cost_i  = sum(price(:) .* loadUsers, 1).';
    denom_i = sum(loadUsers, 1).';
    Cu = zeros(n, 1);
    zeroLoadUser = denom_i <= 0;
    Cu(~zeroLoadUser) = cost_i(~zeroLoadUser) ./ denom_i(~zeroLoadUser);
    % Utente senza mai carico residuo (es. puro produttore): Cu=0 per
    % convenzione, MAI NaN (si propagherebbe a tutti gli utenti tramite omega).

    [Q1, med] = local_tukey_quartiles(Cu);
    B2 = ones(n, 1);
    B2(Cu >= Q1 & Cu < med) = 3;
    B2(Cu >= med)           = 5;

    isPotentialEP = Cu > med;

    % --- Ricerca su griglia (alpha1,alpha2,beta1,beta2), vettorizzata -------
    a1 = opts.alpha1Range(:); a2 = opts.alpha2Range(:);
    b1 = opts.beta1Range(:);  b2 = opts.beta2Range(:);
    nb1 = numel(b1); nb2 = numel(b2);
    combosPerAlpha = nb1 * nb2;
    nCombos = numel(a1) * numel(a2) * combosPerAlpha;

    phiAll = zeros(n, nCombos);
    params = zeros(nCombos, 4);   % [alpha1 alpha2 beta1 beta2] per colonna

    [B1grid, B2grid] = ndgrid(b1, b2);
    B1gridVec = B1grid(:); B2gridVec = B2grid(:);

    col = 0;
    for ia1 = 1:numel(a1)
        for ia2 = 1:numel(a2)
            B1 = a1(ia1) * ESH + a2(ia2) * loadUsers;      % [H x n]

            B1r = reshape(B1, H, n, 1, 1);
            B2r = reshape(B2.', 1, n, 1, 1);
            b1r = reshape(b1, 1, 1, nb1, 1);
            b2r = reshape(b2, 1, 1, 1, nb2);

            omega    = b1r .* B1r + b2r .* B2r;             % [H,n,nb1,nb2]
            sumOmega = sum(omega, 2);                       % [H,1,nb1,nb2]
            Gshare   = omega ./ sumOmega;                   % sicuro: sumOmega>0 sempre
            phiBlock = reshape(sum(Gshare .* reshape(GREC, H, 1, 1, 1), 1), ...
                                n, nb1, nb2);                % somma sulle ore

            phiAll(:, col+1:col+combosPerAlpha) = reshape(phiBlock, n, combosPerAlpha);
            params(col+1:col+combosPerAlpha, :) = [repmat(a1(ia1), combosPerAlpha, 1), ...
                                                     repmat(a2(ia2), combosPerAlpha, 1), ...
                                                     B1gridVec, B2gridVec];
            col = col + combosPerAlpha;

            if opts.verbose
                fprintf('  weighted_solidarity_cer: alpha1=%g alpha2=%g (%d/%d combinazioni)\n', ...
                        a1(ia1), a2(ia2), col, nCombos);
            end
        end
    end

    % --- Indice di Gini per ogni combinazione (eq. 2.8) ----------------------
    gini = zeros(nCombos, 1);
    for c = 1:nCombos
        gini(c) = local_gini(phiAll(:, c));
    end

    % --- Fronte di Pareto (min Gini, max reddito medio EP) e selezione ------
    if any(isPotentialEP)
        epAvg = mean(phiAll(isPotentialEP, :), 1).';

        % dominatesMat(a,b) = true se la combinazione a DOMINA la b (Gini non
        % peggiore, reddito EP non peggiore, e strettamente meglio in almeno
        % uno dei due obiettivi).
        dominatesMat = (gini <= gini.') & (epAvg >= epAvg.') & ...
                       ((gini < gini.') | (epAvg > epAvg.'));
        isDominated  = any(dominatesMat, 1).';
        paretoIdx    = find(~isDominated);

        minGini = min(gini); maxEP = max(epAvg);

        if opts.normalizeObjectives
            rangeG = max(gini) - min(gini);
            rangeE = max(epAvg) - min(epAvg);
            gN = (gini(paretoIdx) - min(gini)) / max(rangeG, eps);
            eN = (epAvg(paretoIdx) - min(epAvg)) / max(rangeE, eps);
            dist = sqrt(gN.^2 + (1 - eN).^2);
        else
            dist = sqrt((gini(paretoIdx) - minGini).^2 + (epAvg(paretoIdx) - maxEP).^2);
        end
        [~, k] = min(dist);
        bestIdx = paretoIdx(k);

        paretoFront = table(params(paretoIdx,1), params(paretoIdx,2), ...
                             params(paretoIdx,3), params(paretoIdx,4), ...
                             gini(paretoIdx), epAvg(paretoIdx), ...
                             'VariableNames', {'alpha1','alpha2','beta1','beta2','Gini','EPavg_EUR'});
        utopia = [minGini, maxEP];
        nParetoPoints = numel(paretoIdx);
    else
        warning('weighted_solidarity_cer:noEP', ...
                ['Nessun utente "potenzialmente in poverta'' energetica" (Cu tutti ' ...
                 '<= mediana): salto il fronte di Pareto e scelgo la combinazione a ' ...
                 'indice di Gini minimo.']);
        [~, bestIdx] = min(gini);
        paretoFront = table('Size', [0 6], ...
            'VariableTypes', repmat({'double'}, 1, 6), ...
            'VariableNames', {'alpha1','alpha2','beta1','beta2','Gini','EPavg_EUR'});
        utopia = [NaN, NaN];
        nParetoPoints = 0;
    end

    phi = phiAll(:, bestIdx);
    winning = params(bestIdx, :);

    % --- Output ---------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';

    % vGrand e' il totale calcolato INDIPENDENTEMENTE da phi (somma di GREC):
    % cosi' l'assert di efficienza in report_allocation.m e' un vero controllo
    % di conservazione, non una tautologia. Le due quantita' coincidono per
    % costruzione, perche' sum_i Gshare(t,i) = 1 per ogni ora.
    S.players       = players;
    S.phi           = phi;
    S.vGrand        = vGrand;
    S.isProsumer    = isProsumer;
    S.prodShare     = sum(phi(isProsumer));
    S.consShare     = sum(phi(~isProsumer));
    S.alpha1        = winning(1);
    S.alpha2        = winning(2);
    S.beta1         = winning(3);
    S.beta2         = winning(4);
    S.giniIndex     = gini(bestIdx);
    S.nParetoPoints = nParetoPoints;
    S.paretoFront   = paretoFront;
    S.utopia        = utopia;
    S.Cu            = Cu;
    S.B2            = B2;
    S.isPotentialEP = isPotentialEP;
    S.V             = opts.V;
    S.tariffMode    = opts.tariffMode;
    S.table = table(players(:), phi, 100*phi/max(vGrand, eps), Cu, B2, isPotentialEP, ...
                     'VariableNames', {'Giocatore', 'WeightedSolidarity_EUR', 'Quota_pct', ...
                                       'Cu_EURperkWh', 'B2_score', 'PotentialEP'});
end


function [Q1, med] = local_tukey_quartiles(x)
%LOCAL_TUKEY_QUARTILES  Primo quartile e mediana senza Statistics Toolbox
%   (metodo di Tukey: il primo quartile e' la mediana della meta' inferiore
%   del campione ordinato, esclusa la mediana centrale se il campione ha
%   cardinalita' dispari).
    x = sort(x(:));
    m = numel(x);
    med = median(x);
    if mod(m, 2) == 0
        lowerHalf = x(1:m/2);
    else
        lowerHalf = x(1:(m-1)/2);
    end
    if isempty(lowerHalf)
        Q1 = med;
    else
        Q1 = median(lowerHalf);
    end
end


function g = local_gini(x)
%LOCAL_GINI  Indice di Gini (eq. 2.8 di Marrasso et al.), formula standard
%   su vettore ordinato in senso crescente (Farris, 2010).
    x = sort(x(:));
    m = numel(x);
    if m == 0 || sum(x) <= 0
        g = 0;
        return;
    end
    idx = (1:m).';
    g = (2 * sum(idx .* x)) / (m * sum(x)) - (m + 1) / m;
end
