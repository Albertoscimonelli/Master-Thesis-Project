function S = pearson_key_cer(genUsers, loadUsers, userNames, P_CER)
%PEARSON_KEY_CER  Ripartizione dell'incentivo CER con la CHIAVE DINAMICA
%   basata sulla correlazione di Pearson (metodo M3 di Gianaroli, Ricci,
%   Sdringola, Ancona, Branchini, Melino, "Development of dynamic sharing keys: Algorithms
%   supporting management of renewable energy community and collective self
%   consumption", Energy & Buildings 311 (2024) 114158).
%
%   IDEA
%     A differenza di tutti gli altri metodi implementati, qui non si
%     ripartisce direttamente il DENARO: si ripartisce ora per ora l'ENERGIA
%     condivisa tra gli utenti, e solo alla fine la si valorizza con la
%     tariffa incentivante P_CER. La chiave premia il SINCRONISMO: chi
%     consuma proprio quando la comunita' immette in rete (correlazione di
%     Pearson giornaliera alta tra il proprio profilo di consumo e il profilo
%     di immissione) riceve una quota maggiore di energia condivisa, a
%     prescindere da quanto consuma in valore assoluto.
%
%   PASSAGGI (§1 della guida di implementazione)
%     1. p(i,d)   = Pearson(load_i, Einj) sulle 24 ore del giorno d
%                   (0 se una delle due varianze e' nulla)
%     2. pRemap   = (p + 1)/2                       rimappatura in [0,1]
%     3. pHourly  = pRemap espanso alle 24 ore del giorno    -> pearson_hourly_key.m
%     4. r(t,i)   = pHourly(t,i) / sum_i pHourly(t,i)        (eq. 4 del paper)
%     5. SH(t,i)  = ripartizione iterativa di Einj(t) con pesi r e cap al
%                   consumo (Fig. 2 del paper)              -> allocate_shared_energy.m
%     6. phi_i    = sum_t SH(t,i) * P_CER(t)                 valorizzazione [EUR]
%
%   I passi 4-5 sono in helper condivisi con il metodo M5
%   (pearson_sharing_key_cer.m): cambia solo la chiave, non l'algoritmo.
%
%   PERCHE' L'EFFICIENZA VALE PER COSTRUZIONE
%     L'algoritmo di ripartizione garantisce sum_i SH(t,i) = min(Einj(t),
%     sum_i load_i(t)) per ogni ora, cioe' esattamente l'energia condivisa di
%     comunita'. Quindi
%       sum_i phi_i = sum_t min(Einj(t), load_tot(t)) * P_CER(t) = v(N)
%     lo STESSO valore della grande coalizione degli altri metodi: le quote
%     restano direttamente confrontabili in MAIN.m §3k.
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   calcolata direttamente senza enumerare le 2^n coalizioni intermedie,
%   qui inutili)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%                         H deve essere un multiplo di 24 (giornate intere)
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici (plot_benefit_network,
%   plot_allocation_comparison), piu' gli intermedi utili alla validazione
%     .players      [1 x n]  nomi dei giocatori (= userNames)
%     .phi          [n x 1]  ripartizione Pearson Key                  [EUR]
%     .vGrand       scalare  valore della grande coalizione            [EUR]
%     .isProsumer   [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare    scalare  quota totale ai prosumer                  [EUR]
%     .consShare    scalare  quota totale ai consumatori puri          [EUR]
%     .sharedEnergy [n x 1]  energia condivisa attribuita nell'anno    [kWh]
%     .pDaily       [nGiorni x n]  coefficiente di Pearson grezzo in [-1,1]
%     .pMeanUser    [n x 1]  media annua del coefficiente grezzo per utente
%     .pHourly      [H x n]  coefficiente rimappato [0,1] espanso alle ore
%     .keys         [H x n]  chiave r(t,i) normalizzata (prima del cap)
%     .SH           [H x n]  energia condivisa oraria per utente       [kWh/h]
%     .table        table    riepilogo (giocatore, quota, percentuale)

    H       = size(loadUsers, 1);
    players = string(userNames(:).');

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    Einj     = sum(genUsers,  2);        % immissione in rete della comunita'
    loadComm = sum(loadUsers, 2);
    vGrand   = sum(min(Einj, loadComm) .* P_CER);

    % --- Chiave dinamica: Pearson giornaliero rimappato in [0,1] -----------
    [pHourly, pDaily] = pearson_hourly_key(loadUsers, Einj);

    % --- Ripartizione oraria dell'energia condivisa con cap al consumo -----
    SH = allocate_shared_energy(loadUsers, Einj, pHourly);

    % --- Valorizzazione economica -----------------------------------------
    phi = (SH.' * P_CER);                % [n x 1] EUR

    % --- Output -----------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players      = players;
    S.phi          = phi;
    S.vGrand       = vGrand;
    S.isProsumer   = isProsumer;
    S.prodShare    = sum(phi(isProsumer));
    S.consShare    = sum(phi(~isProsumer));
    S.sharedEnergy = sum(SH, 1).';
    S.pDaily       = pDaily;
    S.pMeanUser    = mean(pDaily, 1).';
    S.pHourly      = pHourly;
    S.keys         = normalize_key_rows(pHourly);
    S.SH           = SH;
    S.table        = table(players(:), phi, 100*phi/vGrand, ...
                           'VariableNames', {'Giocatore', 'PearsonKey_EUR', 'Quota_pct'});
end
