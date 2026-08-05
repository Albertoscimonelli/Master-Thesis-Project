function S = proportional_consumption_cer(genUsers, loadUsers, userNames, P_CER)
%PROPORTIONAL_CONSUMPTION_CER  Ripartizione dell'incentivo CER proporzionale
%   al consumo di ciascun utente nelle ore "utili", cioe' le ore in cui la
%   comunita' genera benefici economici (energia condivisa > 0). Secondo
%   benchmark elementare, alternativo all'Equal Split: chi consuma di piu'
%   nelle ore in cui l'energia condivisa e' effettivamente positiva riceve
%   una quota maggiore, indipendentemente dal proprio contributo marginale
%   al gioco cooperativo.
%
%   ORE UTILI
%     sharedHour(t) = true se min( sum_i gen_i(t), sum_i load_i(t) ) > 0,
%     cioe' le ore in cui la comunita', nel suo complesso, condivide energia
%     (e quindi matura l'incentivo CER).
%
%   RIPARTIZIONE
%     Per ciascun giocatore i si calcola il consumo cumulato nelle sole ore
%     utili
%         cons_i = sum_{t in sharedHour} load_i(t)
%     e la sua quota percentuale sul consumo totale della comunita' nelle
%     stesse ore:
%         phi_i = v(N) * cons_i / sum_j cons_j
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   calcolata direttamente senza enumerare le 2^n coalizioni intermedie,
%   qui inutili)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
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
%     .phi        [n x 1]  ripartizione Proportional to Consumption [EUR]
%     .vGrand     scalare  valore della grande coalizione            [EUR]
%     .isProsumer [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare  scalare  quota totale ai prosumer                  [EUR]
%     .consShare  scalare  quota totale ai consumatori puri          [EUR]
%     .table      table    riepilogo (giocatore, quota, percentuale)

    players = string(userNames(:).');

    genComm    = sum(genUsers,  2);
    loadComm   = sum(loadUsers, 2);
    sharedHour = min(genComm, loadComm) > 0;

    vGrand = sum(min(genComm, loadComm) .* P_CER(:));

    consUser  = sum(loadUsers(sharedHour, :), 1).';   % [n x 1] consumo nelle ore utili
    consTotal = sum(consUser);

    if consTotal <= 0
        error('proportional_consumption_cer:noConsumption', ...
              ['Nessun consumo registrato nelle ore con energia condivisa > 0: ' ...
               'impossibile ripartire.']);
    end

    phi = vGrand * consUser / consTotal;

    % --- Output ---------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = phi;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(phi(isProsumer));
    S.consShare  = sum(phi(~isProsumer));
    S.table      = table(players(:), phi, 100*phi/vGrand, ...
                         'VariableNames', {'Giocatore', 'ProportionalConsumption_EUR', 'Quota_pct'});
end
