function S = equal_split_cer(genUsers, loadUsers, userNames, P_CER)
%EQUAL_SPLIT_CER  Ripartizione elementare di riferimento: l'incentivo CER
%   sull'energia condivisa viene diviso in PARTI UGUALI tra tutti gli n
%   giocatori, indipendentemente dal loro contributo (produzione o consumo).
%   Serve come benchmark per valutare quanto i modelli di teoria dei giochi
%   (Shapley, Nucleolo, Nash Bargaining, Variance Least Core) si discostino
%   da una ripartizione paritaria.
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   calcolata direttamente senza enumerare le 2^n coalizioni intermedie,
%   qui inutili)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
%
%   RIPARTIZIONE
%     phi_i = v(N) / n   per ogni giocatore i
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici (plot_benefit_network,
%   plot_allocation_comparison)
%     .players    [1 x n]  nomi dei giocatori (= userNames)
%     .phi        [n x 1]  ripartizione Equal Split           [EUR]
%     .vGrand     scalare  valore della grande coalizione      [EUR]
%     .isProsumer [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare  scalare  quota totale ai prosumer            [EUR]
%     .consShare  scalare  quota totale ai consumatori puri    [EUR]
%     .table      table    riepilogo (giocatore, quota, percentuale)

    n       = size(loadUsers, 2);
    players = string(userNames(:).');

    vGrand = sum(min(sum(genUsers, 2), sum(loadUsers, 2)) .* P_CER(:));

    phi = repmat(vGrand / n, n, 1);

    % --- Output ---------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = phi;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(phi(isProsumer));
    S.consShare  = sum(phi(~isProsumer));
    S.table      = table(players(:), phi, 100*phi/vGrand, ...
                         'VariableNames', {'Giocatore', 'EqualSplit_EUR', 'Quota_pct'});
end
