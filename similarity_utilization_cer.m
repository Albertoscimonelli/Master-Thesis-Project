function S = similarity_utilization_cer(genUsers, loadUsers, userNames, P_CER, opts)
%SIMILARITY_UTILIZATION_CER  Ripartizione dell'incentivo CER con il metodo
%   performance-based di M. Bilardo, "A fair dynamic incentive allocation
%   method for virtual energy sharing in renewable energy communities that
%   rewards members' virtuosity and engagement", Renewable Energy 255 (2025)
%   123756 (eq. 3-8, Fig. 5).
%
%   IDEA
%     L'incentivo si ripartisce GIORNO PER GIORNO in proporzione a un fattore
%     di allocazione che premia la "virtuosita' energetica" del membro, cioe'
%     il prodotto di due fattori indipendenti (eq. 6):
%
%       f_all(m,d) = theta(m,d) * eta(m,d)          in [0,1]
%
%       theta = SIMILARITA' (eq. 7): coseno dell'angolo tra il profilo
%         giornaliero di carico del membro e il profilo giornaliero di
%         generazione della comunita'. Premia chi CONSUMA QUANDO la comunita'
%         produce. Essendo un coseno, ignora le grandezze assolute: conta solo
%         la forma della curva.
%
%       eta = UTILIZZO (eq. 8): quota del proprio fabbisogno giornaliero che
%         la generazione di comunita' riesce a coprire,
%             eta = min( 1 , E_gen_comunita'(d) / E_load_membro(d) )
%         Vale 1 finche' la comunita' produce abbastanza per quel membro, e
%         decade quando il suo consumo supera la capacita' produttiva.
%         Penalizza CHI CONSUMA TROPPO: nella condivisione virtuale un grande
%         consumatore potrebbe altrimenti accaparrarsi l'incentivo alzando
%         semplicemente i propri prelievi, che e' l'opposto dell'efficienza
%         energetica che la CER dovrebbe promuovere.
%
%     I due fattori sono complementari: theta premia la sincronia, eta la
%     sobrieta'. Il prodotto e' alto solo per chi fa entrambe le cose.
%
%   RIPARTIZIONE (eq. 4-5, flowchart di Fig. 5)
%     Per ogni giorno d:
%       I(d)     = sum_{t in d} shared(t) * P_CER(t)      incentivo del giorno
%       w(m,d)   = f_all(m,d) / sum_m f_all(m,d)          chiave normalizzata
%       phi_m   += w(m,d) * I(d)
%     La normalizzazione e' GIORNALIERA (Fig. 5 e §5.2 del paper: "resulting
%     in a daily percentage allocation"), anche se l'eq. 5 stampata sembra
%     riferirsi all'intero periodo. Poiche' sum_m w(m,d) = 1 ogni giorno,
%     l'efficienza sum_m phi_m = v(N) vale per costruzione.
%
%   PROFILI USATI PER theta ED eta  (scelta di modello, vedi opts)
%     Il paper calcola i due fattori sui profili LORDI, dietro al contatore:
%     carico totale del membro e generazione totale della comunita' prima
%     dell'autoconsumo (lo dichiara esso stesso tra i limiti, §6 del paper: "the
%     proposed method lies in the use of behind-the-meter energy flows").
%     Qui il DEFAULT sono invece i profili NETTI ricevuti in ingresso
%     (genUsers/loadUsers, cioe' genForShare/loadForShare in MAIN.m), per
%     coerenza con gli altri metodi del progetto. La differenza non e'
%     cosmetica: sui profili netti il carico residuo del proprietario
%     dell'impianto e' nullo proprio nelle ore di eccedenza, quindi la sua
%     similarita' crolla e la sua quota con lei; sui profili lordi il
%     prosumer partecipa come tutti gli altri.
%     Per passare alla lettura letterale del paper bastano opts:
%
%       opts.loadForFactors = D.loadUsers;    % carichi LORDI  [H x n]
%       opts.genForFactors  = D.genPV_raw;    % generazione LORDA di comunita' [H x 1]
%
%     Il montepremi v(N) NON cambia in nessuno dei due casi: e' sempre
%     l'incentivo sull'energia condivisa netta (eq. 3), lo stesso degli altri
%     metodi, quindi il confronto in MAIN.m resta valido.
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
%                 .loadForFactors  [H x n] carico usato per theta/eta
%                                  (def. loadUsers)
%                 .genForFactors   [H x 1] generazione di comunita' usata per
%                                  theta/eta (def. sum(genUsers,2))
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici, piu' gli intermedi
%   utili a riprodurre le Fig. 9-10 del paper
%     .players        [1 x n]  nomi dei giocatori (= userNames)
%     .phi            [n x 1]  ripartizione Similarity-Utilization      [EUR]
%     .vGrand         scalare  valore della grande coalizione           [EUR]
%     .isProsumer     [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare      scalare  quota totale ai prosumer                 [EUR]
%     .consShare      scalare  quota totale ai consumatori puri         [EUR]
%     .theta          [nGiorni x n]  fattore di similarita' giornaliero
%     .eta            [nGiorni x n]  fattore di utilizzo giornaliero
%     .fAll           [nGiorni x n]  fattore di allocazione theta*eta
%     .dailyShare     [nGiorni x n]  chiave normalizzata giornaliera (Fig. 10a)
%     .dailyIncentive [nGiorni x 1]  incentivo maturato ogni giorno     [EUR]
%     .meanDailyShare [n x 1]  media SEMPLICE delle quote giornaliere (sui soli
%                              giorni con chiave definita): e' la grandezza
%                              riportata in Fig. 10b/Tabella 5 del paper,
%                              diversa da phi/v(N) che e' la media PESATA
%                              sull'incentivo di ciascun giorno
%     .nDegenerateDays scalare giorni senza generazione, in cui la chiave non
%                              e' definita e si usa la ripartizione uniforme
%                              (giorni che valgono comunque 0 EUR)
%     .thetaMean, .etaMean  [n x 1]  medie annue dei due fattori
%     .grossFactors   logico  true se theta/eta sono stati calcolati su
%                              profili diversi da quelli del gioco
%     .table          table    riepilogo (giocatore, quota, percentuale)

    [H, n]  = size(loadUsers);
    players = string(userNames(:).');

    if mod(H, 24) ~= 0
        error('similarity_utilization_cer:notWholeDays', ...
              ['La serie ha %d ore, non un multiplo di 24: i fattori theta ed ' ...
               'eta sono definiti su giornate intere.'], H);
    end
    nDays = H / 24;

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'loadForFactors') || isempty(opts.loadForFactors)
        opts.loadForFactors = loadUsers;
    end
    if ~isfield(opts, 'genForFactors') || isempty(opts.genForFactors)
        opts.genForFactors = sum(genUsers, 2);
    end
    if ~isequal(size(opts.loadForFactors), [H n])
        error('similarity_utilization_cer:badLoadFactors', ...
              'opts.loadForFactors deve essere [%d x %d].', H, n);
    end
    if numel(opts.genForFactors) ~= H
        error('similarity_utilization_cer:badGenFactors', ...
              'opts.genForFactors deve avere %d ore.', H);
    end
    % Un NaN in ingresso verrebbe altrimenti ASSORBITO in silenzio (theta = 0
    % perche' il denominatore non risulta > 0, eta = 1 perche' il confronto
    % con 0 e' falso): la quota dell'utente crollerebbe senza alcun segnale.
    if ~all(isfinite(loadUsers), 'all') || ~all(isfinite(genUsers), 'all') || ...
       ~all(isfinite(opts.loadForFactors), 'all') || ~all(isfinite(opts.genForFactors))
        error('similarity_utilization_cer:nonFiniteInput', ...
              'Profili con NaN o Inf in ingresso: controllare i dati a monte.');
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    % --- Montepremi: incentivo sull'energia condivisa netta (eq. 3-4) ------
    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    shared   = min(genComm, loadComm);
    vGrand   = sum(shared .* P_CER);

    % Incentivo maturato in ciascun giorno [nGiorni x 1]
    dailyIncentive = sum(reshape(shared .* P_CER, 24, nDays), 1).';

    % --- Profili su cui si valutano i due fattori --------------------------
    Ld = reshape(opts.loadForFactors,   24, nDays, n);   % (ora, giorno, utente)
    Gd = reshape(opts.genForFactors(:), 24, nDays);      % (ora, giorno)

    % --- theta: similarita' coseno giornaliera (eq. 7) ---------------------
    % theta = <load_m, gen_M> / (||load_m|| * ||gen_M||), sulle 24 ore del
    % giorno. Con vettori non negativi risulta sempre in [0,1]: 1 se le due
    % curve sono proporzionali, 0 se non si sovrappongono mai.
    num = sum(Ld .* Gd, 1);                                % [1 x nDays x n]
    den = sqrt(sum(Ld.^2, 1)) .* sqrt(sum(Gd.^2, 1));      % [1 x nDays x n]

    theta3    = zeros(1, nDays, n);
    okTheta   = den > 0;        % giorno senza carico o senza generazione:
    theta3(okTheta) = num(okTheta) ./ den(okTheta);   % coseno non definito -> 0
    theta3    = min(max(theta3, 0), 1);                % guardia numerica

    % --- eta: fattore di utilizzo giornaliero (eq. 8) ----------------------
    Eload = sum(Ld, 1);          % [1 x nDays x n]  fabbisogno del membro
    Egen  = sum(Gd, 1);          % [1 x nDays]      generazione di comunita'

    EgenExp = repmat(Egen, 1, 1, n);   % stessa generazione per tutti i membri
    eta3    = ones(1, nDays, n);       % 1 = la comunita' copre l'intero fabbisogno
    needs   = Eload > 0;               % membro senza consumi quel giorno -> eta = 1
    eta3(needs) = min(1, EgenExp(needs) ./ Eload(needs));

    % --- Fattore di allocazione e chiave giornaliera (eq. 5-6) -------------
    fAll3 = theta3 .* eta3;                       % [1 x nDays x n]
    fAll  = reshape(fAll3, nDays, n);

    sumF  = sum(fAll, 2);
    dailyShare = repmat(1/n, nDays, n);           % giorno degenere (tutti 0):
    valid = sumF > 0;                             % chiave uniforme, ma quel
    dailyShare(valid, :) = fAll(valid, :) ./ sumF(valid);   % giorno vale 0 EUR

    % --- Ripartizione economica -------------------------------------------
    phi = (dailyShare.' * dailyIncentive);        % [n x 1] EUR

    % --- Output -----------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';          % chi porta produzione nel gioco

    S.players        = players;
    S.phi            = phi;
    S.vGrand         = vGrand;
    S.isProsumer     = isProsumer;
    S.prodShare      = sum(phi(isProsumer));
    S.consShare      = sum(phi(~isProsumer));
    S.theta          = reshape(theta3, nDays, n);
    S.eta            = reshape(eta3,   nDays, n);
    S.fAll           = fAll;
    S.dailyShare     = dailyShare;
    S.dailyIncentive = dailyIncentive;
    % Media SEMPLICE delle quote giornaliere (Fig. 10b del paper), calcolata
    % sui soli giorni in cui la chiave e' definita: nei giorni degeneri vale
    % la ripartizione uniforme di ripiego, che non descrive nessun
    % comportamento e falserebbe la media (quei giorni valgono 0 EUR).
    S.meanDailyShare   = mean(dailyShare(valid, :), 1).';
    S.nDegenerateDays  = sum(~valid);
    S.thetaMean      = mean(S.theta, 1).';
    S.etaMean        = mean(S.eta,   1).';
    S.grossFactors   = ~isequal(opts.loadForFactors, loadUsers) || ...
                       ~isequal(opts.genForFactors(:), genComm);
    S.table          = table(players(:), phi, 100*phi/vGrand, ...
                             'VariableNames', ...
                             {'Giocatore', 'SimilarityUtilization_EUR', 'Quota_pct'});
end
