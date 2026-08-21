function E = coalition_excess(phiMat, methodNames, genUsers, loadUsers, userNames, P_CER, opts)
%COALITION_EXCESS  Eccesso di coalizione di Volpato, Carraro, Dal Cin, Rech,
%   "On the Different Fair Allocations of Economic Benefits for Energy
%   Communities", Energies 17 (2024) 4788, eq. 23.
%
%       e_S = v(S) - sum_{i in S} x_i
%
%   Per OGNI sottogruppo S della comunita' confronta due cose: quanto quel
%   sottogruppo genererebbe da solo, fuori dalla CER (v(S)), e quanto i suoi
%   membri ricevono restandoci dentro. Se la differenza e' POSITIVA, quel
%   sottogruppo guadagnerebbe di piu' uscendo: e' un incentivo a rompere la
%   comunita'.
%
%   PERCHE' SERVE: misura una cosa che gli altri indicatori non guardano
%     MinMax, QoS, EI, Gini e Jain misurano quanto UNIFORME sia la
%     ripartizione; il Fairness Index quanto sia vicina al MERITO. Nessuno di
%     loro dice se la ripartizione REGGE. La differenza non e' teorica:
%     l'Equal Split e' primo su EI (1.00) e Gini (0.00) -- per quegli indici e'
%     la ripartizione piu' equa possibile -- ed e' contemporaneamente la meno
%     stabile di tutte, con nove sottogruppi che avrebbero convenienza a
%     uscire. E' l'argomento della Fig. 10 del paper: lo Shapley lascia
%     coalizioni scontente, il Nucleolo no.
%
%   SEGNO (attenzione: opposto a quello del Nucleolo)
%     Qui si usa la convenzione del paper: eccesso POSITIVO = la coalizione
%     vuole uscire. nucleolus_cer.m e variance_least_core_cer.m riportano
%     invece il SURPLUS della coalizione piu' scontenta,
%
%         surplus_S = sum_{i in S} x_i - v(S) = -e_S
%
%     quindi .maxExcess = -Nu.thetaMin. Sono la stessa grandezza letta al
%     contrario, ed e' la verifica incrociata gratuita del modulo: il Nucleolo
%     MINIMIZZA per costruzione l'eccesso massimo, quindi deve risultare il
%     metodo piu' stabile dei sedici, e il suo valore deve coincidere con
%     quello che il Nucleolo stesso dichiara.
%
%   COSA ASPETTARSI SU QUESTA TOPOLOGIA
%     A differenza degli indicatori energetici di fairness_indicators_lem.m,
%     questo DISCRIMINA fortemente: sulla community di default va da -90 EUR
%     (Nucleolo, nessuna coalizione scontenta) a +607 EUR (Equal Split, nove
%     coalizioni scontente). Il motivo e' che guarda i soldi, e i soldi sono
%     l'unica cosa che i sedici metodi spostano davvero.
%
%     Nota che v({i}) = 0 per ogni singolo giocatore (netting dietro al
%     contatore, vedi cer_coalition_values.m): da solo nessuno condivide
%     nulla. Quindi l'eccesso di un singleton vale -phi_i ed e' negativo per
%     chiunque riceva qualcosa -- la razionalita' individuale e' garantita da
%     qualunque ripartizione non negativa. Le coalizioni che possono creare
%     problemi sono quelle INTERMEDIE, che contengono il prosumer piu' un
%     sottoinsieme di consumatori.
%
%   COSTO E SCALABILITA'
%     Enumera le 2^n coalizioni, quindi si ferma verso i 20 membri. Non
%     aggiunge pero' un limite nuovo al progetto: Shapley, Nucleolo e Variance
%     Least Core hanno gia' lo stesso vincolo (README §14.1). Con n <= 20 il
%     costo e' trascurabile perche' v(S) e' gia' calcolata da
%     cer_coalition_values.m, e si puo' passare precalcolata con opts.v.
%
%   INPUT
%     phiMat       [n x nM]  una colonna per metodo, quote in EUR
%     methodNames  [1 x nM]  nomi dei metodi                          (string)
%     genUsers     [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers    [H x n]   carico residuo orario                  [kWh/h]
%     userNames    [1 x n]   nomi degli utenti                       (string)
%     P_CER        scalare o [H x 1]  incentivo CER            [EUR/kWh]
%     opts         struct opzionale:
%                    .v      [2^n x 1]  funzione caratteristica gia' calcolata
%                    .A_inc  [2^n x n]  matrice di incidenza gia' calcolata
%                    .tol    soglia sopra cui un eccesso conta come positivo
%                            (def. 1e-9 * max(1, |v(N)|))
%                    .maxPlayers  limite di sicurezza sull'enumerazione (def. 20)
%                    .quiet  non stampare il riepilogo (def. false)
%
%   OUTPUT (struct E)
%     .methods         [1 x nM]  nomi dei metodi
%     .players         [1 x n]   nomi dei giocatori
%     .vGrand          scalare   v(N)                                   [EUR]
%     .maxExcess       [nM x 1]  eccesso della coalizione peggiore       [EUR]
%     .maxExcessPct    [nM x 1]  lo stesso in % di v(N)
%     .nUnstable       [nM x 1]  quante coalizioni hanno eccesso > tol
%     .isStable        [nM x 1]  logico, true se nessuna coalizione vuole uscire
%     .worstCoalition  [nM x 1]  nomi della coalizione peggiore, uniti da "+"
%     .worstMask       [nM x n]  logico, composizione della coalizione peggiore
%     .excess          [nS x nM] eccesso di OGNI coalizione propria      [EUR]
%     .coalitions      [nS x n]  logico, composizione di ogni riga di .excess
%     .table           table     riepilogo per metodo

    if nargin < 7 || isempty(opts), opts = struct(); end

    [n, nM] = size(phiMat);
    players = string(userNames(:).');

    % --- Guardie sugli ingressi ---------------------------------------------
    if numel(players) ~= n
        error('coalition_excess:playerSizeMismatch', ...
              'userNames ha %d elementi, phiMat ha %d righe.', numel(players), n);
    end
    methodNames = string(methodNames(:).');
    if numel(methodNames) ~= nM
        error('coalition_excess:nameSizeMismatch', ...
              'methodNames ha %d elementi, phiMat ha %d colonne.', ...
              numel(methodNames), nM);
    end
    if ~all(isfinite(phiMat), 'all')
        error('coalition_excess:nonFiniteInput', ...
              'Ripartizioni con NaN o Inf: controllare i dati a monte.');
    end

    if ~isfield(opts, 'maxPlayers'), opts.maxPlayers = 20;    end
    if ~isfield(opts, 'quiet'),      opts.quiet      = false; end

    if n > opts.maxPlayers
        error('coalition_excess:tooManyPlayers', ...
              ['%d giocatori richiedono 2^%d = %.3g coalizioni. Oltre %d ' ...
               'l''enumerazione non e'' praticabile: vedi README §14.1, dove ' ...
               'lo stesso limite blocca Shapley, Nucleolo e Variance Least ' ...
               'Core. Alzare opts.maxPlayers solo sapendo cosa si sta facendo.'], ...
              n, n, 2^n, opts.maxPlayers);
    end

    % --- Funzione caratteristica --------------------------------------------
    % Si riusa quella gia' calcolata se il chiamante la passa: e' esattamente
    % la stessa v(S) su cui giocano tutti i metodi, ed e' cio' che rende
    % l'eccesso confrontabile con le loro quote.
    if isfield(opts, 'v') && isfield(opts, 'A_inc')
        v     = opts.v(:);
        A_inc = opts.A_inc;
        if numel(v) ~= 2^n || ~isequal(size(A_inc), [2^n n])
            error('coalition_excess:precomputedSizeMismatch', ...
                  'opts.v e opts.A_inc devono essere [%d x 1] e [%d x %d].', ...
                  2^n, 2^n, n);
        end
    else
        [v, ~, A_inc] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER);
    end

    vGrand = v(end);

    if ~isfield(opts, 'tol'), opts.tol = 1e-9 * max(1, abs(vGrand)); end

    % Coalizioni PROPRIE: si escludono la vuota (eccesso nullo per definizione)
    % e la grande coalizione (eccesso nullo per efficienza, sum phi = v(N)).
    righe       = (2:(2^n - 1)).';
    coalitions  = A_inc(righe, :) == 1;
    nS          = numel(righe);

    % --- Eccesso di ogni coalizione, per ogni metodo (eq. 23) ---------------
    excess = v(righe) - A_inc(righe, :) * phiMat;      % [nS x nM]

    [maxExcess, idxWorst] = max(excess, [], 1);
    maxExcess = maxExcess(:);
    idxWorst  = idxWorst(:);

    nUnstable = sum(excess > opts.tol, 1).';
    isStable  = nUnstable == 0;

    worstMask      = coalitions(idxWorst, :);
    worstCoalition = strings(nM, 1);
    for k = 1:nM
        worstCoalition(k) = strjoin(cellstr(players(worstMask(k, :))), '+');
    end

    % --- Struttura di uscita -------------------------------------------------
    E.methods        = methodNames;
    E.players        = players;
    E.vGrand         = vGrand;
    E.maxExcess      = maxExcess;
    E.maxExcessPct   = 100 * maxExcess / vGrand;
    E.nUnstable      = nUnstable;
    E.isStable       = isStable;
    E.worstCoalition = worstCoalition;
    E.worstMask      = worstMask;
    E.excess         = excess;
    E.coalitions     = coalitions;
    E.nCoalitions    = nS;
    E.tol            = opts.tol;

    E.table = table(methodNames(:), maxExcess, E.maxExcessPct, nUnstable, ...
                    isStable, worstCoalition, ...
                    'VariableNames', {'Metodo', 'EccessoMax_EUR', 'EccessoMax_pct', ...
                                      'CoalizioniInstabili', 'Stabile', ...
                                      'CoalizionePeggiore'});

    if ~opts.quiet
        nInst = sum(~isStable);
        fprintf(['  Eccesso di coalizione: %d metodi su %d lasciano almeno una ' ...
                 'coalizione con\n  convenienza a uscire (su %d coalizioni proprie ' ...
                 'esaminate).\n'], nInst, nM, nS);
    end
end
