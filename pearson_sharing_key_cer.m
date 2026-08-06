function S = pearson_sharing_key_cer(genUsers, loadUsers, userNames, P_CER, opts)
%PEARSON_SHARING_KEY_CER  Ripartizione dell'incentivo CER con la CHIAVE
%   DINAMICA COMBINATA di Gianaroli, Ricci, Sdringola, Ancona, Branchini, Melino,
%   "Development of dynamic sharing keys: Algorithms supporting management of
%   renewable energy community and collective self consumption", Energy &
%   Buildings 311 (2024) 114158 - metodo M5, eq. 7.
%
%   IDEA
%     M5 mette insieme i due criteri dei metodi precedenti dello stesso paper:
%       - M3, chiave di Pearson (pearson_key_cer.m): premia il SINCRONISMO,
%         cioe' chi consuma nelle ore in cui la comunita' immette in rete;
%       - M4, sharing rate (sharing_rate_key.m): premia il consumo fino a
%         concorrenza dell'energia immessa e penalizza il SOVRACONSUMO, cioe'
%         chi in una data ora assorbe piu' energia di quanta la comunita' ne
%         stia immettendo.
%     I due pesi grezzi si combinano linearmente con alpha + beta = 1, PRIMA
%     della normalizzazione oraria tra utenti (per questo gli helper
%     restituiscono i pesi non normalizzati):
%
%       combinato(t,i) = alpha * pHourly(t,i) + beta * SR(t,i)
%       r(t,i)         = combinato(t,i) / sum_i combinato(t,i)      (eq. 7)
%       SH(t,i)        = ripartizione iterativa con cap al consumo (Fig. 2)
%       phi_i          = sum_t SH(t,i) * P_CER(t)                   [EUR]
%
%     M4 NON e' esposto come metodo di ripartizione a se' (non e' fra i
%     modelli richiesti): il suo peso resta una componente interna di M5,
%     calcolata dall'helper condiviso sharing_rate_key.m.
%
%   SCALE DEI DUE TERMINI
%     Entrambe le componenti stanno in [0,1]: pHourly vale 0.5 per correlazione
%     nulla e 1 per correlazione perfetta; SR vale 1 nel punto di massimo
%     (ratio = 1) e decade da entrambi i lati. Con alpha = beta = 0.5 i due
%     criteri pesano quindi in modo confrontabile, senza bisogno di
%     normalizzazioni aggiuntive.
%
%   PERCHE' L'EFFICIENZA VALE PER COSTRUZIONE
%     Come per M3: l'algoritmo di ripartizione garantisce sum_i SH(t,i) =
%     min(Einj(t), sum_i load_i(t)) ora per ora, quindi sum_i phi_i = v(N),
%     lo stesso valore della grande coalizione degli altri metodi.
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   calcolata direttamente senza enumerare le 2^n coalizioni intermedie)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%                         H deve essere un multiplo di 24 (giornate intere)
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct    opzionale, campi tutti facoltativi:
%                 .alpha            peso della componente di Pearson (def. 0.5)
%                 .beta             peso dello sharing rate (def. 1 - alpha)
%                                   DEVE valere alpha + beta = 1, entrambi >= 0
%                 .xi               costante di decadimento dello sharing rate
%                                   (def. ln(2)/0.5 ~= 1.386, calibrata su
%                                   SR = 0.5 per ratio = 1.5)
%                 .sharingRateMode  "fig3" (def.) | "eq5" - quale lettura
%                                   dell'eq. 5 usare; il default riproduce
%                                   Fig. 3, il testo e l'esempio numerico del
%                                   paper, "eq5" la formula come stampata
%                                   (rami invertiti): vedi la nota in
%                                   sharing_rate_key.m
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici, piu' gli intermedi
%   utili alla validazione
%     .players      [1 x n]  nomi dei giocatori (= userNames)
%     .phi          [n x 1]  ripartizione Pearson-Sharing Rate         [EUR]
%     .vGrand       scalare  valore della grande coalizione            [EUR]
%     .isProsumer   [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare    scalare  quota totale ai prosumer                  [EUR]
%     .consShare    scalare  quota totale ai consumatori puri          [EUR]
%     .sharedEnergy [n x 1]  energia condivisa attribuita nell'anno    [kWh]
%     .alpha, .beta, .xi, .sharingRateMode   eco dei parametri usati
%     .pDaily       [nGiorni x n]  coefficiente di Pearson grezzo in [-1,1]
%     .pHourly      [H x n]  componente di Pearson rimappata [0,1]
%     .SR           [H x n]  componente di sharing rate (non normalizzata)
%     .keys         [H x n]  chiave r(t,i) normalizzata (prima del cap)
%     .SH           [H x n]  energia condivisa oraria per utente       [kWh/h]
%     .table        table    riepilogo (giocatore, quota, percentuale)

    H       = size(loadUsers, 1);
    players = string(userNames(:).');

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'alpha'),           opts.alpha           = 0.5;             end
    if ~isfield(opts, 'beta'),            opts.beta            = 1 - opts.alpha;  end
    if ~isfield(opts, 'xi'),              opts.xi              = log(2) / 0.5;    end
    if ~isfield(opts, 'sharingRateMode'), opts.sharingRateMode = "fig3";          end

    if ~isscalar(opts.alpha) || ~isscalar(opts.beta) || ...
       opts.alpha < 0 || opts.beta < 0 || abs(opts.alpha + opts.beta - 1) > 1e-12
        error('pearson_sharing_key_cer:invalidWeights', ...
              ['opts.alpha e opts.beta devono essere scalari non negativi con ' ...
               'alpha + beta = 1 (ora: %g + %g).'], opts.alpha, opts.beta);
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    Einj     = sum(genUsers,  2);        % immissione in rete della comunita'
    loadComm = sum(loadUsers, 2);
    vGrand   = sum(min(Einj, loadComm) .* P_CER);

    % --- Le due componenti, entrambe NON normalizzate (eq. 7) --------------
    [pHourly, pDaily] = pearson_hourly_key(loadUsers, Einj);
    SR = sharing_rate_key(loadUsers, Einj, opts.xi, opts.sharingRateMode);

    combinato = opts.alpha * pHourly + opts.beta * SR;

    % --- Ripartizione oraria dell'energia condivisa con cap al consumo -----
    SH = allocate_shared_energy(loadUsers, Einj, combinato);

    % --- Valorizzazione economica -----------------------------------------
    phi = (SH.' * P_CER);                % [n x 1] EUR

    % --- Output -----------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players         = players;
    S.phi             = phi;
    S.vGrand          = vGrand;
    S.isProsumer      = isProsumer;
    S.prodShare       = sum(phi(isProsumer));
    S.consShare       = sum(phi(~isProsumer));
    S.sharedEnergy    = sum(SH, 1).';
    S.alpha           = opts.alpha;
    S.beta            = opts.beta;
    S.xi              = opts.xi;
    S.sharingRateMode = string(opts.sharingRateMode);
    S.pDaily          = pDaily;
    S.pHourly         = pHourly;
    S.SR              = SR;
    S.keys            = normalize_key_rows(combinato);
    S.SH              = SH;
    S.table           = table(players(:), phi, 100*phi/vGrand, ...
                              'VariableNames', ...
                              {'Giocatore', 'PearsonSharingRate_EUR', 'Quota_pct'});
end
