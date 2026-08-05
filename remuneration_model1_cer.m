function S = remuneration_model1_cer(genUsers, loadUsers, userNames, P_CER, ratedLoadKW, ratedGenKW)
%REMUNERATION_MODEL1_CER  Ripartizione dell'incentivo CER tramite il
%   "Remuneration Model 1" di Candela, Di Silvestre, Gallo, Riva
%   Sanseverino, Sciume', Zizzo, "A Remuneration Model of Energy Community
%   Members in Italy", IEEE BLORIN 2022.
%
%   IDEA
%     L'incentivo orario viene diviso in due quote, una per la classe dei
%     CONSUMATORI (chi preleva) e una per la classe dei PRODUTTORI/PROSUMER
%     (chi immette), pesate sulla potenza complessiva delle due classi:
%         alpha = sum(Prt_consumatori) / (sum(Prt_consumatori) + sum(Prt_produttori))
%         beta  = sum(Prt_produttori)  / (sum(Prt_consumatori) + sum(Prt_produttori))
%     All'interno di ciascuna classe, la quota oraria si ripartisce in
%     proporzione all'energia di quell'ora (prelievo per i consumatori,
%     immissione per i produttori). Un prosumer (ha sia carico sia
%     produzione) incassa la SOMMA delle due quote.
%
%   DUE POTENZE DISTINTE, NON UNA
%     Il paper usa due grandezze fisiche diverse sui due lati:
%       - lato consumo:    potenza IMPEGNATA IN PRELIEVO  (ratedLoadKW) [kW]
%       - lato produzione: potenza NOMINALE DELL'IMPIANTO (ratedGenKW) [kWp]
%     Un prosumer le ha entrambe e sono numeri diversi (es. 50 kW di
%     potenza impegnata e 20 kWp di pannelli). Tenerle separate e' quello
%     che evita di conteggiare due volte la stessa cifra: usare un unico
%     valore per entrambi i lati sposterebbe la quota destinata alla
%     produzione di quasi il doppio (vedi GUIDA_modelli_distribuzione.md
%     §10.6 per il confronto numerico).
%
%   CHI STA IN QUALE CLASSE
%     Derivata dai dati, non da un'etichetta esterna: un utente concorre al
%     lato consumo se ha carico residuo in almeno un'ora dell'anno, e al
%     lato produzione se ha eccedenza in almeno un'ora. La potenza di chi
%     non concorre a un lato NON entra nel denominatore di quel lato: un
%     impianto che non immette mai nella CER non deve gonfiare beta.
%
%   INPUT
%     genUsers    [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers   [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames   [1 x n]   nomi degli utenti                      (string)
%     P_CER       scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     ratedLoadKW [1 x n] o [n x 1]  potenza impegnata in prelievo  [kW]
%                 (vedi RATED_LOAD_KW in MAIN.m §0)
%     ratedGenKW  [1 x n] o [n x 1]  potenza nominale di generazione [kWp],
%                 0 per chi non possiede impianti (derivata in MAIN.m §3h
%                 dal campo .kWp di pvPlants)
%
%   OUTPUT (struct S)
%     .players          [1 x n]  nomi dei giocatori (= userNames)
%     .phi              [n x 1]  ripartizione Remuneration Model 1 [EUR]
%     .vGrand           scalare  valore della grande coalizione     [EUR]
%     .isProsumer       [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare        scalare  quota totale ai prosumer           [EUR]
%     .consShare        scalare  quota totale ai consumatori puri   [EUR]
%     .alpha, .beta     scalari  pesi di classe derivati dalle potenze
%     .consumerEligible [n x 1]  logico, true se l'utente ha carico > 0 in
%                                almeno un'ora dell'anno
%     .producerEligible [n x 1]  logico, = isProsumer (alias per chiarezza)
%     .ratedLoadKW      [n x 1]  eco dell'input, per tracciabilita'
%     .ratedGenKW       [n x 1]  eco dell'input, per tracciabilita'
%     .table            table    riepilogo (giocatore, quota, percentuale)

    n = size(loadUsers, 2);

    if numel(ratedLoadKW) ~= n
        error('remuneration_model1_cer:sizeMismatch', ...
              'ratedLoadKW ha %d elementi, attesi %d (uno per utente).', ...
              numel(ratedLoadKW), n);
    end
    if numel(ratedGenKW) ~= n
        error('remuneration_model1_cer:sizeMismatch', ...
              'ratedGenKW ha %d elementi, attesi %d (uno per utente).', ...
              numel(ratedGenKW), n);
    end
    ratedLoadKW = ratedLoadKW(:);
    ratedGenKW  = ratedGenKW(:);
    if any(ratedLoadKW < 0) || any(ratedGenKW < 0)
        error('remuneration_model1_cer:negativePower', ...
              'Le potenze non possono essere negative.');
    end

    % P_CER puo' arrivare scalare (incentivo costante) o gia' come vettore
    % [H x 1] (incentivo orario): normalizzato qui una volta sola.
    if isscalar(P_CER)
        P_CER = P_CER * ones(size(loadUsers, 1), 1);
    else
        P_CER = P_CER(:);
    end

    players = string(userNames(:).');

    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    ES       = min(genComm, loadComm);
    B_REC    = ES .* P_CER;                  % [H x 1]
    vGrand   = sum(B_REC);

    consumerMask = any(loadUsers > 0, 1).';  % "consumer-eligible"
    producerMask = any(genUsers  > 0, 1).';  % "producer-eligible" = isProsumer

    % Incoerenza di configurazione: immette energia ma risulta senza impianto.
    % Senza questo avviso beta risulterebbe silenziosamente sottostimato.
    missingGen = producerMask & (ratedGenKW <= 0);
    if any(missingGen)
        warning('remuneration_model1_cer:missingGenPower', ...
                ['Utenti che immettono energia ma con potenza di generazione ' ...
                 'nulla (%s): verificare il campo .kWp di pvPlants in MAIN.m.'], ...
                strjoin(players(missingGen), ', '));
    end

    sumPrtCons = sum(ratedLoadKW(consumerMask));
    sumPrtProd = sum(ratedGenKW(producerMask));
    if sumPrtCons + sumPrtProd <= 0
        error('remuneration_model1_cer:noRatedPower', ...
              ['Somma delle potenze nulla per entrambe le classi: verificare ' ...
               'RATED_LOAD_KW e pvPlants(.kWp) in MAIN.m (TODO non compilati?).']);
    end
    alpha = sumPrtCons / (sumPrtCons + sumPrtProd);
    beta  = sumPrtProd / (sumPrtCons + sumPrtProd);

    % --- Quota consumatori: proporzionale al prelievo orario -----------------
    H = size(loadUsers, 1);
    shareCons = zeros(H, n);
    hrsL = loadComm > 0;
    shareCons(hrsL, :) = loadUsers(hrsL, :) ./ loadComm(hrsL);

    % --- Quota produttori/prosumer: proporzionale all'immissione oraria ------
    shareProd = zeros(H, n);
    hrsG = genComm > 0;
    shareProd(hrsG, :) = genUsers(hrsG, :) ./ genComm(hrsG);

    phi = sum(alpha * B_REC .* shareCons + beta * B_REC .* shareProd, 1).';

    % --- Output ---------------------------------------------------------
    isProsumer = producerMask;

    S.players          = players;
    S.phi              = phi;
    S.vGrand           = vGrand;
    S.isProsumer       = isProsumer;
    S.prodShare        = sum(phi(isProsumer));
    S.consShare        = sum(phi(~isProsumer));
    S.alpha            = alpha;
    S.beta             = beta;
    S.consumerEligible = consumerMask;
    S.producerEligible = producerMask;
    S.ratedLoadKW      = ratedLoadKW;
    S.ratedGenKW       = ratedGenKW;
    S.table            = table(players(:), phi, 100*phi/vGrand, ...
                               'VariableNames', {'Giocatore', 'RemunerationModel1_EUR', 'Quota_pct'});
end
