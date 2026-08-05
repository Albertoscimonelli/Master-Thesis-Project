function S = cascading_tree_cer(genUsers, loadUsers, userNames, P_CER, opts)
%CASCADING_TREE_CER  Ripartizione dell'incentivo CER tramite il modello ad
%   albero ("layered") di Trevisan, Ghiani, Pilo, "Economic Benefits
%   Redistribution Methodology for Renewable Energy Communities", 2022.
%
%   IDEA
%     L'incentivo totale della comunita' (q1) si scompone ricorsivamente in
%     categorie (Fig. 1 del paper), ciascuna una frazione della categoria
%     padre:
%       q1 -> q2 "riserve" (NON redistribuite) + q3 "da redistribuire"
%       q3 -> q4 "fissa" (uguale per tutti) + q5 "variabile"
%       q5 -> q6 "prelievi" (proporzionale al carico annuo) + q7 "immissione"
%       q7 -> q8 "produttori+prosumer" (proporzionale all'immissione annua)
%             + q9 "soli prosumer" (proporzionale all'immissione annua dei
%               soli utenti che hanno SIA produzione SIA carico)
%     phi_i = somma delle quote di foglia a cui l'utente i partecipa.
%
%   SEMPLIFICAZIONE "PER SIMPLICITY" DEL PAPER
%     Le quote di prelievo/immissione usano il peso ANNUO (energia totale
%     dell'anno), non un ricalcolo ora per ora: e' la stessa semplificazione
%     esplicitamente adottata dal paper ("for a matter of simplicity...
%     coefficients computed over a year").
%
%   INVARIANTE DI EFFICIENZA
%     S.vGrand = q3 (quanto EFFETTIVAMENTE redistribuito), non q1 (il
%     "montepremi" totale della comunita'): con opts.reservoirFraction = 0
%     (default) q3 == q1 e il metodo resta confrontabile con gli altri 8 in
%     MAIN.m Tcmp. Con una riserva > 0, vGrand sara' legittimamente minore
%     del v(N) degli altri metodi — per costruzione, non per errore.
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct    opzionale, campi tutti facoltativi (pesi di ramo,
%                         scelte di GOVERNANCE della REC, non derivabili
%                         dai dati — vedi GUIDA_modelli_distribuzione.md):
%                 .reservoirFraction      p1,2  (def. 0)
%                 .fixedFraction          p3,4  (def. 0.3)
%                 .withdrawalsFraction    p5,6  (def. 0.5)
%                 .prosumersOnlyFraction  p7,9  (def. 0.6)
%
%   OUTPUT (struct S)
%     .players             [1 x n]  nomi dei giocatori (= userNames)
%     .phi                 [n x 1]  ripartizione Cascading Tree      [EUR]
%     .vGrand              scalare  = q3, quota effettivamente redistribuita
%     .isProsumer          [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare           scalare  quota totale ai prosumer          [EUR]
%     .consShare           scalare  quota totale ai consumatori puri  [EUR]
%     .totalIncentive      scalare  = q1, montepremi totale comunita' [EUR]
%     .reservoirAmount     scalare  = q2, quota trattenuta            [EUR]
%     .pools               struct   .fixed .withdrawals .feedInGeneral .prosumersOnly [EUR]
%     .weights             struct   eco degli opts risolti (con i default applicati)
%     .prosumersOnlyFolded logico   true se nessun "vero prosumer" esisteva
%                                   quell'anno e la pool q9 e' stata assorbita in q8
%     .table               table    riepilogo con il dettaglio per foglia

    n = size(loadUsers, 2);

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'reservoirFraction'),     opts.reservoirFraction     = 0;   end
    if ~isfield(opts, 'fixedFraction'),         opts.fixedFraction         = 0.3; end
    if ~isfield(opts, 'withdrawalsFraction'),   opts.withdrawalsFraction   = 0.5; end
    if ~isfield(opts, 'prosumersOnlyFraction'), opts.prosumersOnlyFraction = 0.6; end

    fracFields = ["reservoirFraction", "fixedFraction", "withdrawalsFraction", "prosumersOnlyFraction"];
    for k = 1:numel(fracFields)
        v = opts.(fracFields(k));
        if ~isscalar(v) || v < 0 || v > 1
            error('cascading_tree_cer:invalidFraction', ...
                  'opts.%s deve essere uno scalare in [0,1] (ricevuto %s).', ...
                  fracFields(k), mat2str(v));
        end
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(size(loadUsers, 1), 1);
    else
        P_CER = P_CER(:);
    end

    players = string(userNames(:).');

    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    q1 = sum(min(genComm, loadComm) .* P_CER);

    q2 = opts.reservoirFraction * q1;
    q3 = q1 - q2;
    q4 = opts.fixedFraction * q3;
    q5 = q3 - q4;
    q6 = opts.withdrawalsFraction * q5;
    q7 = q5 - q6;
    q9 = opts.prosumersOnlyFraction * q7;
    q8 = q7 - q9;

    tolZero = 1e-9;

    % --- q4: quota fissa, uguale per tutti -----------------------------------
    fixedShare = repmat(q4 / n, n, 1);

    % --- q6: prelievi, proporzionale al carico annuo -------------------------
    totalLoad = sum(loadUsers, 'all');
    w = zeros(n, 1);
    if totalLoad > tolZero
        w = sum(loadUsers, 1).' / totalLoad;
    end
    withdrawShare = q6 * w;

    % --- q8: immissione generale, proporzionale all'immissione annua ---------
    totalGen = sum(genUsers, 'all');
    inj = zeros(n, 1);
    if totalGen > tolZero
        inj = sum(genUsers, 1).' / totalGen;
    end
    feedInGeneralShare = q8 * inj;

    % --- q9: soli "veri" prosumer (hanno SIA produzione SIA carico) ----------
    isProsumerStrict = any(genUsers > 0, 1).' & any(loadUsers > 0, 1).';
    prosumersOnlyFolded = false;
    ip = zeros(n, 1);
    if ~any(isProsumerStrict)
        % Nessun vero prosumer quest'anno: la pool q9 si assorbe in q8
        % invece di dividere per zero (fallback documentato, non un errore).
        q8 = q8 + q9;
        q9 = 0;
        prosumersOnlyFolded = true;
        feedInGeneralShare = q8 * inj;
    else
        totalGenProsumers = sum(genUsers(:, isProsumerStrict), 'all');
        if totalGenProsumers > tolZero
            ip(isProsumerStrict) = sum(genUsers(:, isProsumerStrict), 1).' / totalGenProsumers;
        end
    end
    prosumersOnlyShare = q9 * ip;

    phi = fixedShare + withdrawShare + feedInGeneralShare + prosumersOnlyShare;

    % --- Output ---------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';

    S.players             = players;
    S.phi                 = phi;
    S.vGrand              = q3;
    S.isProsumer          = isProsumer;
    S.prodShare           = sum(phi(isProsumer));
    S.consShare           = sum(phi(~isProsumer));
    S.totalIncentive      = q1;
    S.reservoirAmount     = q2;
    S.pools               = struct('fixed', q4, 'withdrawals', q6, ...
                                    'feedInGeneral', q8, 'prosumersOnly', q9);
    S.weights             = opts;
    S.prosumersOnlyFolded = prosumersOnlyFolded;
    S.table = table(players(:), phi, 100*phi/max(q3, eps), ...
                     fixedShare, withdrawShare, feedInGeneralShare, prosumersOnlyShare, ...
                     'VariableNames', {'Giocatore', 'CascadingTree_EUR', 'Quota_pct', ...
                                       'FixedShare_EUR', 'WithdrawalShare_EUR', ...
                                       'FeedInShare_EUR', 'ProsumersOnlyShare_EUR'});
end
