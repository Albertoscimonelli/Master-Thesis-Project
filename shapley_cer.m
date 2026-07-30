function S = shapley_cer(genUsers, loadUsers, userNames, P_CER)
%SHAPLEY_CER  Ripartizione dell'incentivo CER sull'energia condivisa tramite
%   Shapley value (gioco cooperativo, Moncecchi et al., Appl. Sci. 2020).
%
%   GIOCATORI
%     Un giocatore per utente: ciascuno porta con se' il proprio carico
%     residuo e la propria eccedenza di produzione (nulla se non ha impianti).
%
%   VALORE DELLA COALIZIONE  (solo incentivo sull'energia condivisa)
%     v(C) = sum_t min( sum_{i in C} gen_i(t), sum_{i in C} load_i(t) ) * P_CER(t)
%   P_CER puo' essere uno scalare o un vettore [H x 1] (incentivo orario).
%   Serve almeno un prosumer in eccedenza e almeno un utente con carico
%   residuo: da solo nessun giocatore condivide nulla, quindi v({i}) = 0.
%
%   SHAPLEY VALUE  (eq. 39 del paper)
%     phi_i = sum_{C subset N\{i}} |C|!(n-|C|-1)!/n! * (v(C+i) - v(C))
%   ossia la media, su tutti gli ordini di formazione della grande coalizione,
%   del contributo marginale del giocatore i. Con N piccolo lo Shapley e'
%   calcolato in forma ESATTA su ogni singolo utente, senza l'approssimazione
%   per gruppi adottata nel paper (necessaria solo per centinaia di utenti).
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente    [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                     (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%
%   OUTPUT (struct S)
%     .players    [1 x n]  nomi dei giocatori (= userNames)
%     .phi        [n x 1]  Shapley value di ciascun giocatore   [EUR]
%     .vGrand     scalare  valore della grande coalizione       [EUR]
%     .isProsumer [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare  scalare  quota totale ai prosumer             [EUR]
%     .consShare  scalare  quota totale ai consumatori puri     [EUR]
%     .table      table    riepilogo (giocatore, quota, percentuale)

    n = size(loadUsers, 2);              % un giocatore per utente

    if n > 20
        warning('shapley_cer:bigGame', ...
            ['Gioco con %d giocatori: 2^%d coalizioni. ' ...
             'Il calcolo esatto puo'' essere oneroso; valutare il ' ...
             'raggruppamento dei consumatori.'], n, n);
    end

    % --- Funzione caratteristica v(S) condivisa con gli altri metodi --------
    % Bitmask su n bit: bit i = giocatore i.
    [v, players] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER);
    nSub = numel(v);

    % --- Pesi di Shapley w(s) = s!(n-s-1)!/n! in funzione di s = |C| ---------
    w = zeros(n, 1);
    for s = 0:(n-1)
        w(s+1) = factorial(s) * factorial(n - s - 1) / factorial(n);
    end

    % --- Calcolo dello Shapley value di ogni giocatore ----------------------
    phi = zeros(n, 1);
    for i = 1:n
        bit_i = 2^(i-1);
        for mask = 0:(nSub - 1)
            if bitget(mask, i) == 1, continue; end   % C non deve contenere i
            s      = sum(bitget(mask, 1:n));         % cardinalita' |C|
            marg   = v(mask + bit_i + 1) - v(mask + 1);
            phi(i) = phi(i) + w(s+1) * marg;
        end
    end

    % --- Output -------------------------------------------------------------
    vGrand = v(end);                     % grande coalizione = tutti i bit a 1

    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = phi;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(phi(isProsumer));
    S.consShare  = sum(phi(~isProsumer));
    S.table      = table(players(:), phi, 100*phi/vGrand, ...
                         'VariableNames', {'Giocatore', 'Shapley_EUR', 'Quota_pct'});
end
