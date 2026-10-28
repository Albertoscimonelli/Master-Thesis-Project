function S = variance_least_core_cer(genUsers, loadUsers, userNames, P_CER, opts)
%VARIANCE_LEAST_CORE_CER  Ripartizione dei ricavi CER tramite il Variance
%   Least Core (VLC), calcolato con la tecnica di ROW-GENERATION di
%   Ferrucci, Fioriti, Poli, "Reward allocation in Energy Communities by
%   size, composition and prosumers penetration", IEEE PES ISGT Europe 2025
%   (eq. 12-17), a sua volta basata su Fioriti et al., IEEE Trans. Energy
%   Markets Policy Regul., 2024.
%
%   Usa la STESSA funzione caratteristica v(S) di Shapley/Nucleolo/Nash --
%   un giocatore per utente, ciascuno con il proprio carico residuo e la
%   propria eccedenza:
%       v(S) = sum_t min( sum_{i in S} gen_i(t), sum_{i in S} load_i(t) ) * P_CER(t)
%   P_CER puo' essere uno scalare o un vettore [H x 1] (incentivo orario), cosi'
%   i quattro metodi sono direttamente confrontabili. A differenza
%   degli altri tre NON chiama cer_coalition_values: quella enumera tutte le
%   2^n coalizioni con un ciclo ed e' impraticabile oltre ~20 giocatori. Per
%   il master v(K) e' valutata SU RICHIESTA solo per le poche coalizioni
%   generate; per la separazione vedi "SEPARAZIONE PER ENUMERAZIONE" sotto.
%
%   IDEA
%     Surplus di una coalizione K data l'allocazione x (eq. 11):
%         sigma(K, x) = sum_{i in K} x_i - v(K).
%     LEAST CORE (eq. 12-13): insieme delle allocazioni efficienti che
%     massimizzano il surplus della coalizione piu' scontenta,
%         theta_LC = max theta  s.t.  sigma(K,x) >= theta  per ogni K,
%                                     sum_i x_i = v(N),  x >= 0.
%     Se theta_LC >= 0 nessuna sotto-coalizione conviene: allocazione STABILE.
%     Il Least Core e' pero' un INSIEME. Il VARIANCE LEAST CORE (eq. 14)
%     ne sceglie l'unico punto piu' vicino alla ripartizione uniforme:
%         x_VLC = argmin sum_i (x_i - v(N)/|I|)^2   con x nel Least Core.
%     Essendo l'obiettivo strettamente convesso, la soluzione e' UNICA.
%
%   ROW-GENERATION (eq. 15-17)
%     I vincoli di surplus sono 2^n - 2: non si possono scrivere tutti. Si
%     itera allora fra due problemi, su un insieme ristretto Gamma di
%     coalizioni che cresce a ogni giro:
%       - MASTER   : ottimizza su Gamma soltanto  ->  allocazione tentativa x
%       - SEPARATION: cerca, fra TUTTE le coalizioni, quella col surplus
%                     minimo dato x. E' un MILP nelle binarie z (z_i = 1 se
%                     il giocatore i appartiene alla coalizione).
%     Se il surplus minimo trovato rispetta gia' il livello richiesto, la
%     procedura converge (il vincolo omesso non era violato); altrimenti la
%     coalizione violata entra in Gamma e si ripete. Il numero di iterazioni
%     resta nell'ordine delle decine anche per comunita' grandi (Fig. 3 del
%     paper), invece delle 2^n righe dell'approccio esaustivo.
%     La procedura e' eseguita DUE volte: prima con il master (16) per
%     ricavare theta_LC, poi con il master (15) per il VLC vero e proprio,
%     riutilizzando il Gamma gia' costruito (warm start).
%
%   LINEARIZZAZIONE DEL SEPARATION PROBLEM
%     v(z) contiene un min(), non lineare. Si introducono le variabili
%     continue s_t (energia condivisa all'ora t) con i due upper bound
%         s_t <= sum_i genUsers(t,i)  * z_i          (eq. 5)
%         s_t <= sum_i loadUsers(t,i) * z_i          (eq. 6)
%     e v(z) = sum_t P_CER(t) * s_t. Poiche' l'obiettivo (min x'z - v(z))
%     PREMIA s grande, all'ottimo s_t = min(gen_K(t), load_K(t)) esattamente:
%     la linearizzazione e' esatta, non un rilassamento. Entrambi i lati sono
%     somme sulle binarie: nessun giocatore abilita da solo la condivisione.
%
%   REQUISITI: Optimization Toolbox (linprog, quadprog, intlinprog).
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct    opzionale, campi tutti facoltativi:
%                 .tolRel        tolleranza RELATIVA a v(N)     (def. 1e-6)
%                 .maxIter       iterazioni max per fase        (def. 1000:
%                                PA1/CER_12_13_0, 25 membri, converge in 519)
%                 .verbose       stampa avanzamento             (def. false)
%                 .validateDense verifica contro l'enumerazione (def. false,
%                                ammessa solo per n <= 12)
%                 .v             [2^n x 1] v(S) gia' enumerata da
%                                cer_coalition_values (facoltativo): se c'e'
%                                la separazione la usa invece di ricalcolarla
%                 .denseMaxPlayers fino a quanti giocatori la separazione
%                                enumera tutte le coalizioni invece di
%                                risolvere il MILP (def. 25, vedi sotto)
%
%   SEPARAZIONE PER ENUMERAZIONE FINO A 25 GIOCATORI
%     Il MILP della separazione si risolve a ogni iterazione, e le iterazioni
%     sono centinaia: a 25 membri la row-generation costava fino a 37 minuti
%     per comunita', e su ND1_PA1/CER_18_7_0 non convergeva in 500 iterazioni
%     (README 7.11.2). Fino a opts.denseMaxPlayers giocatori si calcola invece
%     v(S) per TUTTE le coalizioni una volta sola (enumerate_values, a blocchi
%     vettorizzati, qualche minuto a n = 25), e ogni separazione diventa un
%     argmin su 2^n surplus: O(2^n) per iterazione, meno di un secondo a
%     n = 25. La separazione e' esatta, non soggetta alla tolleranza di gap
%     del MILP. Memoria: tre vettori di 2^n double, circa 800 MB a n = 25.
%     Oltre la soglia resta il MILP di sempre.
%
%   OUTPUT (struct S)
%     .players     [1 x n]  nomi dei giocatori (= userNames)
%     .phi         [n x 1]  ripartizione Variance Least Core     [EUR]
%     .vGrand      scalare  valore della grande coalizione       [EUR]
%     .isProsumer  [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare   scalare  quota totale ai prosumer             [EUR]
%     .consShare   scalare  quota totale ai consumatori puri     [EUR]
%     .thetaLC     scalare  surplus della coalizione piu' scontenta [EUR]
%                           (>= 0  =>  allocazione nel Core, stabile)
%     .tolConv     scalare  tolleranza con cui la row-generation dichiara
%                           la convergenza: i vincoli del master VLC sono
%                           rilassati, quindi l'allocazione restituita puo'
%                           stare fino a tolConv sotto il bordo del Least
%                           Core. Chi verifica .phi dall'esterno deve usare
%                           QUESTA soglia, non tolRel*v(N)          [EUR]
%     .inCore      logico   true se thetaLC >= -tol
%     .surplus     [n x 1]  surplus individuale sigma({i}, x)    [EUR]
%     .iterLC      scalare  iterazioni row-generation, fase theta_LC
%     .iterVLC     scalare  iterazioni row-generation, fase VLC
%     .coalitions  [nG x n] logico, coalizioni generate (righe di Gamma)
%     .table       table    riepilogo (giocatore, quota, percentuale, surplus)

    % --- Opzioni e valori di default ----------------------------------------
    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'tolRel'),        opts.tolRel        = 1e-6;  end
    if ~isfield(opts, 'maxIter'),       opts.maxIter       = 1000;  end
    if ~isfield(opts, 'verbose'),       opts.verbose       = false; end
    if ~isfield(opts, 'validateDense'), opts.validateDense = false; end
    if ~isfield(opts, 'esente'),        opts.esente        = [];    end
    if ~isfield(opts, 'F'),             opts.F             = 0;     end
    if ~isfield(opts, 'v'),             opts.v             = [];    end
    if ~isfield(opts, 'denseMaxPlayers'), opts.denseMaxPlayers = 25; end

    n = size(loadUsers, 2);              % un giocatore per utente

    if ~isequal(size(genUsers), size(loadUsers))
        error('variance_least_core_cer:sizeMismatch', ...
              'genUsers e'' %s, loadUsers e'' %s: devono coincidere.', ...
              mat2str(size(genUsers)), mat2str(size(loadUsers)));
    end

    % P_CER puo' arrivare scalare (incentivo costante) o gia' come vettore
    % [H x 1] (incentivo orario): normalizzato qui una volta sola, cosi' le
    % funzioni locali sotto possono sempre indicizzarlo per ora.
    if isscalar(P_CER)
        P_CER = P_CER * ones(size(loadUsers, 1), 1);
    else
        P_CER = P_CER(:);
    end

    players = string(userNames(:).');
    vGrand  = coalition_value(true(1, n), genUsers, loadUsers, P_CER, ...
                              opts.esente, opts.F);

    if vGrand <= 0
        error('variance_least_core_cer:degenerate', ...
              ['Valore della grande coalizione non positivo (%.4g): non c''e'' ' ...
               'energia condivisa da ripartire.'], vGrand);
    end

    % Tolleranza RELATIVA al valore in gioco: su ricavi dell'ordine di 1e4 EUR
    % una soglia assoluta 1e-7 sarebbe sotto il rumore numerico dei solver.
    tolAbs = opts.tolRel * max(1, abs(vGrand));

    % --- Pre-calcoli per il Separation Problem ------------------------------
    % Fino a opts.denseMaxPlayers giocatori: v(S) enumerata (o presa da
    % opts.v). Oltre: MILP, da cui si escludono le ore senza generazione, che
    % hanno s_t = 0 per costruzione.
    sep = build_separation(genUsers, loadUsers, P_CER, n, opts.esente, opts.F, ...
                           opts.v, opts.denseMaxPlayers);

    % --- Gamma iniziale: le coalizioni singoletto ---------------------------
    % Punto di partenza economico e sufficiente: garantisce che il master sia
    % limitato e introduce subito la razionalita' individuale.
    Gamma  = logical(eye(n));
    vGamma = zeros(n, 1);
    for i = 1:n
        vGamma(i) = coalition_value(Gamma(i, :), genUsers, loadUsers, P_CER, ...
                                    opts.esente, opts.F);
    end

    lpOpts = optimoptions('linprog',  'Display', 'none');
    qpOpts = optimoptions('quadprog', 'Display', 'none');

    % --- FASE 1: theta_LC con master (16) -----------------------------------
    thetaLC   = -Inf;
    iterLC    = 0;
    converged = false;
    for it = 1:opts.maxIter
        iterLC = it;

        [x, thetaLC] = solve_master_lc(Gamma, vGamma, vGrand, n, lpOpts, it);

        % Separation: la coalizione col surplus minimo dato x.
        [sigmaMin, selK, vK] = solve_separation(sep, x, tolAbs);

        if opts.verbose
            fprintf('  [LC  it %3d] theta = %10.2f   sigma_min = %10.2f   |Gamma| = %d\n', ...
                    it, thetaLC, sigmaMin, size(Gamma, 1));
        end

        % Se nessuna coalizione fa peggio di theta, i vincoli omessi sono
        % soddisfatti: il master ristretto coincide col problema completo.
        if sigmaMin >= thetaLC - tolAbs, converged = true; break; end

        % Se la coalizione peggiore e' gia' in Gamma, il master la stava gia'
        % vincolando: la violazione residua e' solo rumore numerico del
        % solver e non c'e' altra riga utile da generare.
        [Gamma, vGamma, isDup] = add_coalition(Gamma, vGamma, selK, vK, ...
                                               thetaLC - sigmaMin, tolAbs);
        if isDup, converged = true; break; end
    end
    if ~converged
        error('variance_least_core_cer:noConvergenceLC', ...
              'Row-generation (fase theta_LC) non convergente in %d iterazioni.', opts.maxIter);
    end

    % --- FASE 2: VLC con master (15), theta_LC ora fissato ------------------
    % I vincoli del QP sono rilassati di "relax" (theta_LC arriva dal solver
    % LP con la sua tolleranza), quindi l'allocazione ammessa puo' scendere
    % fino a theta_LC - relax: il test di convergenza dev'essere piu' largo
    % del rilassamento, altrimenti la separazione ri-propone all'infinito una
    % coalizione gia' vincolata.
    relax   = tolAbs;
    tolConv = relax + tolAbs;

    xVLC      = x;
    iterVLC   = 0;
    converged = false;
    for it = 1:opts.maxIter
        iterVLC = it;

        xVLC = solve_master_vlc(Gamma, vGamma, vGrand, n, thetaLC, relax, qpOpts, it);

        [sigmaMin, selK, vK] = solve_separation(sep, xVLC, tolAbs);

        if opts.verbose
            fprintf('  [VLC it %3d] var = %10.2f   sigma_min = %10.2f   |Gamma| = %d\n', ...
                    it, var(xVLC), sigmaMin, size(Gamma, 1));
        end

        if sigmaMin >= thetaLC - tolConv, converged = true; break; end

        [Gamma, vGamma, isDup] = add_coalition(Gamma, vGamma, selK, vK, ...
                                               thetaLC - sigmaMin, tolConv);
        if isDup, converged = true; break; end
    end
    if ~converged
        error('variance_least_core_cer:noConvergenceVLC', ...
              'Row-generation (fase VLC) non convergente in %d iterazioni.', opts.maxIter);
    end

    % --- Validazione opzionale contro l'enumerazione esaustiva --------------
    if opts.validateDense
        validate_dense(xVLC, thetaLC, genUsers, loadUsers, userNames, P_CER, n, ...
                       tolAbs, opts.esente, opts.F);
    end

    % --- Surplus individuale sigma({i}, x) ----------------------------------
    surplus = zeros(n, 1);
    for i = 1:n
        sel        = false(1, n);
        sel(i)     = true;
        surplus(i) = xVLC(i) - coalition_value(sel, genUsers, loadUsers, P_CER, ...
                                               opts.esente, opts.F);
    end

    % --- Output -------------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = xVLC;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(xVLC(isProsumer));
    S.consShare  = sum(xVLC(~isProsumer));
    S.thetaLC    = thetaLC;
    S.tolConv    = tolConv;
    S.inCore     = thetaLC >= -tolAbs;
    S.surplus    = surplus;
    S.iterLC     = iterLC;
    S.iterVLC    = iterVLC;
    S.coalitions = Gamma;
    S.table      = table(players(:), xVLC, 100*xVLC/vGrand, surplus, ...
                         'VariableNames', ...
                         {'Giocatore', 'VarianceLeastCore_EUR', 'Quota_pct', 'Surplus_EUR'});
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function [x, theta] = solve_master_lc(Gamma, vGamma, vGrand, n, lpOpts, it)
%SOLVE_MASTER_LC  Master Problem della fase Least Core (eq. 16 del paper):
%   massimizza il surplus minimo theta sulle sole coalizioni presenti in Gamma.
%
%   Variabili LP: [x(1..n); theta].  Obiettivo: max theta.

    f     = [zeros(n, 1); -1];
    Aineq = [-double(Gamma), ones(size(Gamma, 1), 1)];   % -sum_K x + theta <= -v(K)
    bineq = -vGamma;
    Aeq   = [ones(1, n), 0];                             % efficienza
    beq   = vGrand;
    lb    = [zeros(n, 1); -Inf];                         % x in B (eq. 9)

    [sol, ~, exitflag] = linprog(f, Aineq, bineq, Aeq, beq, lb, [], lpOpts);
    if exitflag ~= 1
        error('variance_least_core_cer:masterLcFail', ...
              'Master LC non risolto (exitflag %d) all''iterazione %d.', exitflag, it);
    end

    x     = sol(1:n);
    theta = sol(end);
end


function x = solve_master_vlc(Gamma, vGamma, vGrand, n, thetaLC, relax, qpOpts, it)
%SOLVE_MASTER_VLC  Master Problem della fase Variance Least Core (eq. 15):
%   fra le allocazioni del Least Core cerca quella a varianza minima.
%
%   min sum_i (x_i - v(N)/n)^2 = x'x - 2*(v(N)/n)*sum(x) + cost.
%   L'efficienza fissa sum(x) = v(N), quindi il termine lineare e' costante e
%   il problema equivale a min x'x  =>  H = 2*I, f = 0 (quadprog usa
%   0.5*x'Hx + f'x). Hessiana definita positiva => minimo UNICO.

    Aineq = -double(Gamma);                      % sum_K x >= v(K) + theta_LC
    bineq = -(vGamma + thetaLC - relax);         % rilassato di relax
    Aeq   = ones(1, n);
    beq   = vGrand;
    lb    = zeros(n, 1);

    [x, ~, exitflag, output] = quadprog(2*eye(n), zeros(n, 1), Aineq, bineq, ...
                                        Aeq, beq, lb, [], [], qpOpts);

    % exitflag 2 = "Solver stalled, constraints satisfied": il punto interno si e'
    % fermato prima di toccare la tolleranza di ottimalita'. Succede quando due
    % giocatori pesano molto piu' degli altri e il Least Core e' sottile (PA2 di
    % CER_2_3_0, 5 membri: comune e scuola valgono l'85% del montepremi; i due
    % finiscono allo stesso valore, 950,16 EUR, che e' il minimo di varianza).
    % Si accetta SOLO se i vincoli sono rispettati ben dentro il rilassamento e
    % l'ottimalita' del primo ordine e' praticamente raggiunta (qui 3e-8): in ogni
    % altro caso l'errore resta quello di prima. Con exitflag 1 niente cambia.
    stallaMaValido = exitflag == 2 ...
                     && output.constrviolation <= 1e-3 * relax ...
                     && output.firstorderopt   <= 1e-6;
    if exitflag ~= 1 && ~stallaMaValido
        error('variance_least_core_cer:masterVlcFail', ...
              'Master VLC non risolto (exitflag %d) all''iterazione %d.', exitflag, it);
    end
end


function val = coalition_value(sel, genUsers, loadUsers, P_CER, esente, F)
%COALITION_VALUE  v(K) valutata su richiesta per la sola coalizione K.
%   Stessa formula di cer_coalition_values, ma senza enumerare le 2^n
%   coalizioni: costo O(H*|K|) invece di O(H*2^n). P_CER e' gia' [H x 1]
%   (normalizzato all'ingresso della funzione principale).
%
%   sel  [1 x n] logico sui giocatori (un giocatore per utente).
%
%   Con F > 0 la quota esente e' quella DI K, non della comunita': la formula
%   sta in cer_shared_value.m, qui si preparano solo gli aggregati.

    genK  = sum(genUsers(:,  sel), 2);
    loadK = sum(loadUsers(:, sel), 2);
    if nargin < 6 || isempty(F) || F == 0
        val = sum(min(genK, loadK) .* P_CER);
        return
    end
    loadEsK = sum(loadUsers(:, sel(:) & logical(esente(:))), 2);
    val     = cer_shared_value(genK, loadK, P_CER, loadEsK, F);
end


function sep = build_separation(genUsers, loadUsers, P_CER, n, esente, F, vCache, denseMax)
%BUILD_SEPARATION  Prepara le matrici FISSE del Separation Problem (eq. 17),
%   che non dipendono dall'allocazione x e vanno costruite una sola volta.
%
%   RAMO DENSO (v(S) passata dal chiamante, oppure n <= denseMax)
%     Si tiene v(S) per tutte le 2^n coalizioni, indicizzata dalla bitmask
%     come in cer_coalition_values (v(m+1) = valore della coalizione di
%     bitmask m): la separazione diventa un argmin (solve_separation).
%
%   RAMO MILP (n > denseMax)
%     Variabili del MILP: [z(1..n) binarie ; s(1..Hs) continue >= 0], dove Hs
%     sono le sole ore in cui la comunita' produce qualcosa (nelle altre
%     s_t = 0 per costruzione, qualunque sia la coalizione).
%
%     Con un giocatore per utente entrambi i lati del min() sono somme sulle
%     binarie: nessun giocatore "PV" privilegiato che abiliti la condivisione.
%
%   CON F > 0 IL MILP NON VALE PIU'
%     Il fattore di riduzione non si applica all'energia dei punti di prelievo
%     esenti, quindi il valore della coalizione contiene il termine
%
%         s_t * loadNonEsente(z) / load(z)
%
%     che e' un RAPPORTO fra due combinazioni lineari delle binarie z: non e'
%     lineare, e il Separation Problem smette di essere un MILP. Linearizzarlo
%     e' un lavoro di modellazione a se' (variabili ausiliarie per il
%     rapporto), non un dettaglio implementativo. Con F > 0 resta quindi solo
%     il ramo denso, e oltre denseMax giocatori il metodo non si applica
%     (README par. 14.1).

    if ~isempty(vCache)
        if numel(vCache) ~= 2^n
            error('variance_least_core_cer:cacheSizeMismatch', ...
                  'opts.v ha %d elementi, con %d giocatori ne servono 2^%d.', ...
                  numel(vCache), n, n);
        end
        sep = struct('dense', true, 'n', n, 'v', vCache(:));
        return
    end

    if n <= denseMax
        sep = struct('dense', true, 'n', n, ...
                     'v', enumerate_values(genUsers, loadUsers, P_CER, esente, F));
        return
    end

    if ~isempty(F) && F ~= 0
        error('variance_least_core_cer:denseTooBig', ...
              ['Con F > 0 la separazione ricade sull''enumerazione di 2^%d ' ...
               'coalizioni, oltre opts.denseMaxPlayers = %d. Serve la ' ...
               'linearizzazione del Separation Problem prima di usare il ' ...
               'metodo a questa scala.'], n, denseMax);
    end

    sep.dense = false;
    genTot    = sum(genUsers, 2);
    keep    = genTot > 0;                % ore utili
    gKeep   = genTot(keep);
    genK    = genUsers(keep, :);
    loadK   = loadUsers(keep, :);
    PKeep   = P_CER(keep);               % incentivo orario ristretto alle ore utili
    Hs      = numel(gKeep);

    if Hs == 0
        error('variance_least_core_cer:noGeneration', ...
              'Generazione nulla su tutte le ore: nessuna energia condivisibile.');
    end

    Is = speye(Hs);

    % (a)  s_t - sum_i gen(t,i) * z_i  <= 0        (eq. 5)
    A1 = [-sparse(genK),  Is];

    % (b)  s_t - sum_i load(t,i) * z_i <= 0        (eq. 6)
    A2 = [-sparse(loadK), Is];

    % (c)  1 <= sum_i z_i <= n-1   (esclude coalizione vuota e grande)
    Acard = [sparse(ones(1, n)), sparse(1, Hs)];

    sep.Aineq   = [A1; A2; Acard; -Acard];
    sep.bineq   = [zeros(2*Hs, 1); n-1; -1];
    sep.nVar    = n + Hs;
    sep.n       = n;
    sep.Hs      = Hs;
    sep.P_CER   = PKeep;                 % [Hs x 1], una tariffa per ora utile
    sep.intcon  = 1:n;
    sep.lb      = zeros(n + Hs, 1);

    % Bound superiore esplicito s_t <= sum_i gen(t,i). E' ridondante rispetto
    % al vincolo (a) con tutte le z_i = 1, e sempre valido perche'
    % s_t = min(gen, load), ma NON e' facoltativo in pratica: senza di esso
    % (ub = Inf) il presolve di intlinprog dichiara falsamente infeasible il
    % problema quando molte componenti di Delta valgono 0 e il MILP diventa
    % fortemente degenere. Con il bound per-ora il rilassamento continuo e'
    % molto piu' stretto e il solver converge sempre.
    sep.ub      = [ones(n, 1); gKeep];
    sep.milpOpt = optimoptions('intlinprog', 'Display', 'none', ...
                               'RelativeGapTolerance', 1e-7);
end


function [sigmaMin, sel, vK] = solve_separation(sep, x, tolAbs)
%SOLVE_SEPARATION  Risolve il Separation Problem (eq. 17): fra TUTTE le
%   coalizioni proprie trova quella col surplus minimo data l'allocazione x,
%       min_z  sum_i x_i z_i - v(z).
%
%   OUTPUT
%     sigmaMin  surplus minimo trovato          [EUR]
%     sel       [1 x n] logico, coalizione che lo realizza
%     vK        v(K) della coalizione trovata   [EUR]

    n = sep.n;

    % Ramo esatto per enumerazione (vedi build_separation): v(S) e' gia' pronta
    % per tutte le coalizioni, la separazione e' un argmin. La coalizione vuota
    % (indice 1) e la grande coalizione (indice end) non sono proprie e restano
    % fuori, come nel vincolo di cardinalita' del MILP.
    if sep.dense
        sigmaAll        = subset_sums(x) - sep.v;
        sigmaAll(1)     = Inf;
        sigmaAll(end)   = Inf;
        [sigmaMin, idx] = min(sigmaAll);
        sel             = bitget(idx - 1, 1:n) == 1;
        vK              = sep.v(idx);
        return
    end

    % Obiettivo: x'z - sum_t P_CER(t) * s_t
    f = [x(:); -sep.P_CER];

    [sol, fval, exitflag, out] = intlinprog(f, sep.intcon, sep.Aineq, sep.bineq, ...
                                            [], [], sep.lb, sep.ub, [], sep.milpOpt);
    if exitflag ~= 1 || isempty(sol)
        error('variance_least_core_cer:separationFail', ...
              'Separation problem non risolto (exitflag %d): %s', ...
              exitflag, strtrim(out.message));
    end

    sel      = round(sol(1:n)).' == 1;           % arrotonda il rumore binario
    sigmaMin = fval;
    vK       = sum(sep.P_CER .* sol(n+1:end));

    % Coerenza: il surplus deve corrispondere alla coalizione restituita.
    if abs((sum(x(sel)) - vK) - sigmaMin) > max(tolAbs, 1e-6)
        error('variance_least_core_cer:separationInconsistent', ...
              'Surplus del MILP (%.6g) diverso da quello ricalcolato (%.6g).', ...
              sigmaMin, sum(x(sel)) - vK);
    end
end


function s = subset_sums(x)
%SUBSET_SUMS  sum_{i in S} x_i per ogni bitmask S, nello stesso ordine di v
%   (s(m+1) = somma sulla coalizione di bitmask m). Si aggiunge un giocatore
%   alla volta: le coalizioni col bit i acceso sono quelle senza, piu' x_i.
%   Costo O(2^n), senza la matrice di incidenza [2^n x n].

    n   = numel(x);
    s   = zeros(2^n, 1);
    len = 1;
    for i = 1:n
        s(len+1:2*len) = s(1:len) + x(i);
        len = 2 * len;
    end
end


function v = enumerate_values(genUsers, loadUsers, P_CER, esente, F)
%ENUMERATE_VALUES  v(S) per tutte le 2^n coalizioni, stessa formula e stesso
%   ordine di cer_coalition_values, ma a blocchi vettorizzati invece di un
%   ciclo sulle 2^n bitmask.
%
%   I primi k giocatori formano il blocco "basso": i loro 2^k profili
%   aggregati si costruiscono una volta sola ([Hs x 2^k], come in
%   subset_sums). Per ognuna delle 2^(n-k) combinazioni dei giocatori
%   rimanenti si somma il loro profilo a tutte le colonne del blocco e si
%   valutano 2^k coalizioni con una sola operazione matriciale.
%
%   Si tengono solo le ore con generazione E carico nella comunita': nelle
%   altre min(gen, load) = 0 per ogni coalizione, e il fattore F moltiplica
%   comunque zero. I valori coincidono con cer_coalition_values a meno
%   dell'ordine delle somme (scarti relativi dell'ordine di 1e-12).

    n    = size(loadUsers, 2);
    keep = sum(genUsers, 2) > 0 & sum(loadUsers, 2) > 0;
    g    = genUsers(keep, :);
    l    = loadUsers(keep, :);
    p    = P_CER(keep).';                          % [1 x Hs]

    conF = ~isempty(F) && F ~= 0;
    if conF
        if isempty(esente), esente = false(n, 1); end
        e = l .* double(logical(esente(:)).');     % carico dei soli esenti
    end

    k    = min(n, 8);                              % blocco [Hs x 256]
    nLow = 2^k;
    GL   = block_sums(g(:, 1:k));
    LL   = block_sums(l(:, 1:k));
    gH   = g(:, k+1:end);
    lH   = l(:, k+1:end);
    if conF
        EL = block_sums(e(:, 1:k));
        eH = e(:, k+1:end);
    end

    v = zeros(2^n, 1);
    for h = 0:(2^(n-k) - 1)
        b  = bitget(h, 1:(n-k)).';                 % giocatori "alti" presenti
        lS = LL + lH * b;
        sh = min(GL + gH * b, lS);
        if conF
            eS      = EL + eH * b;
            wEs     = zeros(size(lS));
            ok      = lS > 0;
            wEs(ok) = min(eS(ok) ./ lS(ok), 1);
            sh      = sh .* (1 - F * (1 - wEs));
        end
        v(h*nLow + (1:nLow)) = p * sh;
    end
end


function M = block_sums(A)
%BLOCK_SUMS  M(:, m+1) = somma delle colonne di A selezionate dalla bitmask m.

    k   = size(A, 2);
    M   = zeros(size(A, 1), 2^k);
    len = 1;
    for i = 1:k
        M(:, len+1:2*len) = M(:, 1:len) + A(:, i);
        len = 2 * len;
    end
end


function [Gamma, vGamma, isDup] = add_coalition(Gamma, vGamma, sel, vK, viol, tolConv)
%ADD_COALITION  Aggiunge la coalizione violata a Gamma.
%
%   Se la coalizione e' GIA' presente non ha senso duplicarla (renderebbe il
%   master singolare senza aggiungere informazione): il master la stava gia'
%   vincolando, quindi la violazione residua "viol" puo' solo essere rumore
%   numerico del solver e si segnala convergenza (isDup = true). Una
%   violazione grande, invece, indicherebbe un vero problema di modello o una
%   tolleranza mal calibrata, e viene sollevata come errore.
%
%   OUTPUT  isDup  true se la coalizione era gia' in Gamma

    isDup = any(all(Gamma == sel, 2));
    if isDup
        if viol > max(1e3 * tolConv, 1e-6)
            error('variance_least_core_cer:cycling', ...
                  ['La coalizione col surplus minimo e'' gia'' in Gamma ma ' ...
                   'resta violata di %.6g: row-generation in stallo.'], viol);
        end
        return;
    end
    Gamma  = [Gamma; sel];
    vGamma = [vGamma; vK];
end


function validate_dense(x, thetaLC, genUsers, loadUsers, userNames, P_CER, n, tolAbs, esente, F)
%VALIDATE_DENSE  Controllo di correttezza per giochi piccoli: enumera TUTTE
%   le coalizioni con cer_coalition_values e verifica che il surplus minimo
%   reale coincida con il theta_LC trovato dalla row-generation, cioe' che la
%   generazione di righe non abbia trascurato una coalizione vincolante.

    if n > 12
        warning('variance_least_core_cer:validateSkipped', ...
                'Validazione esaustiva saltata: %d giocatori (2^%d coalizioni).', n, n);
        return;
    end

    [v, ~, A_inc] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER, esente, F);
    isProper      = true(numel(v), 1);
    isProper(1)   = false;
    isProper(end) = false;

    sigmaAll  = A_inc(isProper, :) * x - v(isProper);
    sigmaTrue = min(sigmaAll);

    if abs(sigmaTrue - thetaLC) > 1e3 * tolAbs
        error('variance_least_core_cer:validationFailed', ...
              ['Validazione fallita: surplus minimo reale %.6g, theta_LC ' ...
               'della row-generation %.6g.'], sigmaTrue, thetaLC);
    end
end
