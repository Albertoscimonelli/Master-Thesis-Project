function S = nucleolus_cer(genUsers, loadUsers, userNames, P_CER)
%NUCLEOLUS_CER  Ripartizione dei ricavi CER tramite il Nucleolo del gioco
%   cooperativo (Fioriti et al., Appl. Energy 2021, eq. 7).
%
%   Usa la STESSA funzione caratteristica v(S) dello Shapley (cer_coalition_values),
%   cosi' i due metodi sono direttamente confrontabili. Un giocatore per utente:
%     v(S) = sum_t min( sum_{i in S} gen_i(t), sum_{i in S} load_i(t) ) * P_CER(t)
%   P_CER puo' essere uno scalare o un vettore [H x 1] (incentivo orario).
%
%   IDEA (eq. 7)
%     Il surplus (o "scontentezza" rovesciata) di una coalizione J e'
%         theta_J = sum_{j in J} x_j - v(J).
%     Il Nucleolo distribuisce x massimizzando in modo LESSICOGRAFICO il
%     surplus minimo: prima si massimizza il surplus della coalizione piu'
%     scontenta, poi - congelate le coalizioni divenute vincolanti - si
%     massimizza il surplus della successiva, e cosi' via finche' x e' unica.
%     Si risolve quindi una sequenza di problemi di programmazione lineare.
%
%   PROPRIETA'
%     - Efficienza: sum_j x_j = v(N) (tutto il valore e' distribuito).
%     - Se il Core e' non-vuoto, il Nucleolo vi appartiene  =>  e' STABILE
%       (nessuna sotto-coalizione conviene): theta_min >= 0.
%     A differenza dello Shapley, il Nucleolo privilegia la stabilita' alla
%     piena equita' assiomatica.
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%
%   OUTPUT (struct S)
%     .players    [1 x n]  nomi dei giocatori (= userNames)
%     .phi        [n x 1]  ripartizione Nucleolo                [EUR]
%     .vGrand     scalare  valore della grande coalizione       [EUR]
%     .isProsumer [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare  scalare  quota totale ai prosumer             [EUR]
%     .consShare  scalare  quota totale ai consumatori puri     [EUR]
%     .thetaMin   scalare  surplus della coalizione piu' scontenta [EUR]
%                          (>= 0  =>  allocazione nel Core, stabile)
%     .inCore     logico   true se thetaMin >= -tol
%     .table      table    riepilogo (giocatore, quota, percentuale)

    [v, players, A_inc] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER);
    n      = numel(players);
    nSub   = numel(v);
    vGrand = v(end);
    tol    = 1e-7;

    % Coalizioni "proprie" su cui si misura il surplus: tutte tranne la vuota
    % (riga 1) e la grande coalizione (riga nSub, fissata dall'efficienza).
    isProper          = true(nSub, 1);
    isProper(1)       = false;
    isProper(end)     = false;

    settled = ~isProper;             % coalizioni gia' fuori dal min-surplus
    M       = ones(1, n);            % righe di equazioni che fissano x (efficienza)
    fixRows = zeros(0, n);           % incidenze delle coalizioni congelate
    fixRhs  = zeros(0, 1);           % rispettivi v(S) + theta congelato

    x        = NaN(n, 1);
    thetaMin = NaN;
    opts     = optimoptions('linprog', 'Display', 'none');

    for it = 1:(n + 2)
        active = find(~settled);
        if isempty(active), break; end

        % Variabili LP: [x(1..n); theta].  Obiettivo: max theta.
        f = [zeros(n, 1); -1];

        % Vincoli surplus delle coalizioni attive: sum_{i in S} x_i - theta >= v(S)
        Aineq = [-A_inc(active, :),  ones(numel(active), 1)];
        bineq = -v(active);

        % Equazioni: efficienza + coalizioni gia' congelate (theta bloccato).
        Aeq = [ones(1, n), 0];
        beq = vGrand;
        if ~isempty(fixRows)
            Aeq = [Aeq; fixRows, zeros(size(fixRows, 1), 1)];
            beq = [beq; fixRhs];
        end

        [sol, ~, exitflag] = linprog(f, Aineq, bineq, Aeq, beq, [], [], opts);
        if exitflag ~= 1
            error('nucleolus_cer:lpFail', ...
                  'LP non risolto (exitflag %d) all''iterazione %d.', exitflag, it);
        end

        x         = sol(1:n);
        thetaStar = sol(end);
        if it == 1, thetaMin = thetaStar; end   % surplus minimo del gioco

        % Coalizioni attive divenute vincolanti a questo livello di surplus.
        excess = A_inc(active, :) * x - v(active);
        tight  = active(abs(excess - thetaStar) < tol);

        % Si congelano: quelle che aumentano il rango fissano nuove componenti
        % di x; le altre sono implicate e si tolgono comunque dagli attivi.
        for Sidx = tight.'
            settled(Sidx) = true;
            if rank([M; A_inc(Sidx, :)], 1e-9) > rank(M, 1e-9)
                M       = [M; A_inc(Sidx, :)];
                fixRows = [fixRows; A_inc(Sidx, :)];
                fixRhs  = [fixRhs;  v(Sidx) + thetaStar];
            end
        end

        if rank(M, 1e-9) >= n, break; end   % x univocamente determinata
    end

    % Se il rango dei vincoli congelati non ha raggiunto n, il sistema di
    % equazioni non determina x in modo univoco: l'allocazione restituita
    % soddisfa il criterio lessicografico fin qui raggiunto (e' quindi un
    % punto valido del nucleolo), ma potrebbe non esserne l'unico punto.
    if rank(M, 1e-9) < n
        warning('nucleolus_cer:notUnique', ...
            ['Nucleolo non univocamente determinato dopo %d iterazioni ' ...
             '(rango vincoli %d/%d giocatori): il risultato e'' un punto ' ...
             'valido del nucleolo ma potrebbe non essere l''unico.'], ...
            it, rank(M, 1e-9), n);
    end

    % --- Output -------------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = x;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(x(isProsumer));
    S.consShare  = sum(x(~isProsumer));
    S.thetaMin   = thetaMin;
    S.inCore     = thetaMin >= -tol;
    S.table      = table(players(:), x, 100*x/vGrand, ...
                         'VariableNames', {'Giocatore', 'Nucleolo_EUR', 'Quota_pct'});
end
