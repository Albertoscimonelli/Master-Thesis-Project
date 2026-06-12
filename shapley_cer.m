function S = shapley_cer(genPV, loadUsers, userNames, P_CER)
%SHAPLEY_CER  Ripartizione dell'incentivo CER sull'energia condivisa tramite
%   Shapley value (gioco cooperativo, Moncecchi et al., Appl. Sci. 2020).
%
%   GIOCATORI
%     1 produttore (impianto PV) + N consumatori. Il produttore e' il
%     giocatore 1, i consumatori i giocatori 2..N+1.
%
%   VALORE DELLA COALIZIONE  (solo incentivo sull'energia condivisa)
%     v(C) = 0                                       se il PV non e' in C
%     v(C) = sum_t min(genPV(t), load_C(t)) * P_CER   altrimenti
%   dove load_C(t) e' la somma dei carichi dei soli consumatori presenti in C.
%   Senza produttore non c'e' generazione, quindi nessuna condivisione e v=0;
%   senza consumatori l'energia condivisa e' nulla e v=0.
%
%   SHAPLEY VALUE  (eq. 39 del paper)
%     phi_i = sum_{C subset N\{i}} |C|!(n-|C|-1)!/n! * (v(C+i) - v(C))
%   ossia la media, su tutti gli ordini di formazione della grande coalizione,
%   del contributo marginale del giocatore i. Con N piccolo lo Shapley e'
%   calcolato in forma ESATTA su ogni singolo utente, senza l'approssimazione
%   per gruppi adottata nel paper (necessaria solo per centinaia di utenti).
%
%   INPUT
%     genPV     [H x 1]   generazione PV oraria               [kWh/h]
%     loadUsers [H x nC]  carichi orari dei consumatori        [kWh/h]
%     userNames [1 x nC]  nomi dei consumatori                 (string)
%     P_CER     scalare   incentivo CER su energia condivisa   [EUR/kWh]
%
%   OUTPUT (struct S)
%     .players   [1 x n]  nomi dei giocatori ("PV" + consumatori)
%     .phi       [n x 1]  Shapley value di ciascun giocatore   [EUR]
%     .vGrand    scalare  valore della grande coalizione       [EUR]
%     .prodShare scalare  quota del produttore                 [EUR]
%     .consShare scalare  quota totale dei consumatori         [EUR]
%     .table     table    riepilogo (giocatore, quota, percentuale)

    nC = size(loadUsers, 2);             % numero consumatori
    n  = nC + 1;                         % giocatori totali (PV = giocatore 1)

    if n > 20
        warning('shapley_cer:bigGame', ...
            ['Gioco con %d giocatori: 2^%d coalizioni. ' ...
             'Il calcolo esatto puo'' essere oneroso; valutare il ' ...
             'raggruppamento dei consumatori.'], n, n);
    end

    % --- Funzione caratteristica v(S) condivisa con gli altri metodi --------
    % Bitmask su n bit: bit 1 = produttore, bit (k+1) = consumatore k.
    [v, players] = cer_coalition_values(genPV, loadUsers, userNames, P_CER);
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

    S.players   = players;
    S.phi       = phi;
    S.vGrand    = vGrand;
    S.prodShare = phi(1);
    S.consShare = sum(phi(2:end));
    S.table     = table(players(:), phi, 100*phi/vGrand, ...
                        'VariableNames', {'Giocatore', 'Shapley_EUR', 'Quota_pct'});
end
