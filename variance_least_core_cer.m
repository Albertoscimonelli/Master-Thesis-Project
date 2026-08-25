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
%   2^n coalizioni ed e' impraticabile oltre ~20 giocatori. Qui v(K) e'
%   valutata SU RICHIESTA solo per le poche coalizioni generate.
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
%                 .maxIter       iterazioni max per fase        (def. 500)
%                 .verbose       stampa avanzamento             (def. false)
%                 .validateDense verifica contro l'enumerazione (def. false,
%                                ammessa solo per n <= 12)
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
    if ~isfield(opts, 'maxIter'),       opts.maxIter       = 500;   end
    if ~isfield(opts, 'verbose'),       opts.verbose       = false; end
    if ~isfield(opts, 'validateDense'), opts.validateDense = false; end

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
    vGrand  = coalition_value(true(1, n), genUsers, loadUsers, P_CER);

    if vGrand <= 0
        error('variance_least_core_cer:degenerate', ...
              ['Valore della grande coalizione non positivo (%.4g): non c''e'' ' ...
               'energia condivisa da ripartire.'], vGrand);
    end

    % Tolleranza RELATIVA al valore in gioco: su ricavi dell'ordine di 1e4 EUR
    % una soglia assoluta 1e-7 sarebbe sotto il rumore numerico dei solver.
    tolAbs = opts.tolRel * max(1, abs(vGrand));

    % --- Pre-calcoli per il Separation Problem ------------------------------
    % Le ore senza generazione hanno s_t = 0 per costruzione: si escludono
    % dal MILP, dimezzando circa il numero di variabili e vincoli.
    sep = build_separation(genUsers, loadUsers, P_CER, n);

    % --- Gamma iniziale: le coalizioni singoletto ---------------------------
    % Punto di partenza economico e sufficiente: garantisce che il master sia
    % limitato e introduce subito la razionalita' individuale.
    Gamma  = logical(eye(n));
    vGamma = zeros(n, 1);
    for i = 1:n
        vGamma(i) = coalition_value(Gamma(i, :), genUsers, loadUsers, P_CER);
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
        validate_dense(xVLC, thetaLC, genUsers, loadUsers, userNames, P_CER, n, tolAbs);
    end

    % --- Surplus individuale sigma({i}, x) ----------------------------------
    surplus = zeros(n, 1);
    for i = 1:n
        sel        = false(1, n);
        sel(i)     = true;
        surplus(i) = xVLC(i) - coalition_value(sel, genUsers, loadUsers, P_CER);
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

    [x, ~, exitflag] = quadprog(2*eye(n), zeros(n, 1), Aineq, bineq, ...
                                Aeq, beq, lb, [], [], qpOpts);
    if exitflag ~= 1
        error('variance_least_core_cer:masterVlcFail', ...
              'Master VLC non risolto (exitflag %d) all''iterazione %d.', exitflag, it);
    end
end


function val = coalition_value(sel, genUsers, loadUsers, P_CER)
%COALITION_VALUE  v(K) valutata su richiesta per la sola coalizione K.
%   Stessa formula di cer_coalition_values, ma senza enumerare le 2^n
%   coalizioni: costo O(H*|K|) invece di O(H*2^n). P_CER e' gia' [H x 1]
%   (normalizzato all'ingresso della funzione principale).
%
%   sel  [1 x n] logico sui giocatori (un giocatore per utente).

    genK  = sum(genUsers(:,  sel), 2);
    loadK = sum(loadUsers(:, sel), 2);
    val   = sum(min(genK, loadK) .* P_CER);
end


function sep = build_separation(genUsers, loadUsers, P_CER, n)
%BUILD_SEPARATION  Prepara le matrici FISSE del Separation Problem (eq. 17),
%   che non dipendono dall'allocazione x e vanno costruite una sola volta.
%
%   Variabili del MILP: [z(1..n) binarie ; s(1..Hs) continue >= 0], dove Hs
%   sono le sole ore in cui la comunita' produce qualcosa (nelle altre
%   s_t = 0 per costruzione, qualunque sia la coalizione).
%
%   Con un giocatore per utente entrambi i lati del min() sono somme sulle
%   binarie: nessun giocatore "PV" privilegiato che abiliti la condivisione.

    genTot  = sum(genUsers, 2);
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


function validate_dense(x, thetaLC, genUsers, loadUsers, userNames, P_CER, n, tolAbs)
%VALIDATE_DENSE  Controllo di correttezza per giochi piccoli: enumera TUTTE
%   le coalizioni con cer_coalition_values e verifica che il surplus minimo
%   reale coincida con il theta_LC trovato dalla row-generation, cioe' che la
%   generazione di righe non abbia trascurato una coalizione vincolante.

    if n > 12
        warning('variance_least_core_cer:validateSkipped', ...
                'Validazione esaustiva saltata: %d giocatori (2^%d coalizioni).', n, n);
        return;
    end

    [v, ~, A_inc] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER);
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
