function F = fairness_index_bm(phiMat, BC, methodNames, opts)
%FAIRNESS_INDEX_BM  Fairness Index di Casalicchio, Manzolini, Prina, Moser,
%   "From investment optimization to fair benefit distribution in renewable
%   energy community modelling", Applied Energy 310 (2022) 118447, eq. 12-14.
%
%   Misura quanto ciascun modello di ripartizione si discosti da una
%   distribuzione di RIFERIMENTO fondata sul contributo di ogni membro al
%   beneficio complessivo. Non produce quote, le giudica: un valore basso vuol
%   dire "questo metodo da' a ognuno all'incirca quello che porta".
%
%   LE TRE GRANDEZZE (eq. 12-14)
%     Contributo         BC_i  = OPT - OPT_{-i} = v(N) - v(N\{i})     (eq. 12)
%     Distribuzione di
%     riferimento        Dcd_i = BC_i / sum_l BC_l                    (eq. 13)
%     Fairness Index     FI    = sum_i |D_i - Dcd_i|                  (eq. 14)
%                                / sum_i |Dw_i - Dcd_i|      se m = m_tot
%                        FI    = m_tot - m                   altrimenti
%
%   dove D_i e' la quota del metodo giudicato, m il numero di membri con quota
%   positiva e m_tot il totale. Le due branche non sono confrontabili fra loro:
%   la prima da' un numero in [0,1) che misura la DISTANZA dal riferimento, la
%   seconda un intero che conta i membri lasciati a mani vuote. E' il paper
%   stesso a dirlo ("its value corresponds to the number of members that would
%   not be satisfied"): un FI di 5 non e' "cinque volte peggio" di un FI di 1,
%   e' un altro tipo di informazione.
%
%   IL CONTRIBUTO E' GIA' IN CASA
%     BC_i = v(N) - v(N\{i}) e' esattamente il contributo marginale "ultimo"
%     dell'eq. 9 di Cremers et al., cioe' il campo .mcRaw di
%     marginal_contribution_cer.m. Ne segue che Dcd coincide con la
%     ripartizione normalizzata di quel metodo (eq. 10 di Cremers = eq. 13 di
%     Casalicchio): se tutti i BC sono positivi, la Marginal Contribution ha
%     FI = 0 ESATTO. E' l'auto-verifica piu' forte disponibile.
%
%   LA DISTRIBUZIONE PEGGIORE Dw NON E' NEL PAPER
%     Il paper la descrive solo a parole ("the worst case, the one that would
%     lead to a distribution of the benefits the farthest from the reference
%     metric distribution, thereby maximizing the denominator"), senza formula.
%     La deriviamo: sum_i |D_i - Dcd_i| e' CONVESSA in D, quindi sul simplesso
%     (D_i >= 0, sum D_i = 1) il massimo sta in un VERTICE e_k, dove vale
%
%         |1 - Dcd_k| + sum_{i != k} |Dcd_i|
%
%     e basta prendere il k che lo massimizza. Con tutti i Dcd_i >= 0 questo si
%     riduce a 2*(1 - min_i Dcd_i); la forma generale copre anche i contributi
%     negativi, che il paper dichiara ammessi.
%
%     Conseguenza utile: il caso peggiore e' un vertice, cioe' ha m = 1 membri
%     con quota positiva, e finisce quindi nella SECONDA branca. Ne segue che
%     nella prima branca FI e' strettamente MINORE di 1 -- il che spiega perche'
%     il paper scriva "0 <= FI < 1" e non "<= 1".
%
%   COSA ASPETTARSI SU QUESTA TOPOLOGIA (leggere prima di usare i numeri)
%     Con un solo impianto la Marginal Contribution puo' degenerare: togliere
%     un consumatore spesso non riduce l'energia condivisa, quindi BC_i = 0
%     esatto e Dcd si concentra tutto sul prosumer (vedi §3n di MAIN.m). In quel
%     caso il FI premia "dare tutto al prosumer" e penalizza ogni metodo che
%     riconosca qualcosa ai consumatori. Non e' un errore di calcolo ma un esito
%     STRUTTURALE della topologia, dello stesso tipo di quello riportato in §3q
%     per la Stratified Expected Value: va letto come tale, non nascosto.
%     Il campo .nZeroContribution lo segnala esplicitamente.
%
%   SCOSTAMENTO DAL PAPER
%     Casalicchio registra i risparmi distribuiti AL NETTO dei costi di
%     investimento (§2.5). Il nostro MAIN.m non ha i costi di investimento per
%     membro -- stanno in optimizer_PV.m, che e' uno script a se' -- quindi qui
%     D_i si calcola sui benefici lordi. E' registrato in .assumptions.
%
%   INPUT
%     phiMat       [n x nM]  una colonna per metodo, quote in EUR
%     BC           [n x 1]   contributi BC_i (tipicamente MC.mcRaw)     [EUR]
%     methodNames  [1 x nM]  nomi dei metodi                          (string)
%     opts         struct opzionale:
%                    .playerNames [1 x n] nomi dei membri
%                    .Dworst      [n x 1] distribuzione peggiore, per
%                                 scavalcare quella derivata
%                    .sigmaMode   "deviation" (def., std di D - Dcd, Tab. 7)
%                                 | "distribution" (std della sola D)
%                    .tolZero     soglia sotto cui una quota conta come nulla
%                                 (def. 1e-9)
%                    .validateSelf esegue l'auto-test analitico (def. true)
%                    .quiet       non stampare il registro ipotesi (def. false)
%
%   OUTPUT (struct F)
%     .methods           [1 x nM] nomi dei metodi
%     .Dcd               [n x 1]  distribuzione di riferimento (eq. 13)
%     .Dworst            [n x 1]  distribuzione peggiore derivata
%     .denom             scalare  denominatore dell'eq. 14
%     .D                 [n x nM] quote normalizzate di ciascun metodo
%     .deviation         [n x nM] D - Dcd
%     .FI                [nM x 1] Fairness Index
%     .isRatioBranch     [nM x 1] logico, true se FI viene dalla prima branca
%     .sigma             [nM x 1] deviazione standard (Tab. 7)
%     .maxDeviation      [nM x 1] massimo scostamento in valore assoluto
%     .nZeroShare        [nM x 1] membri con quota nulla
%     .nZeroContribution scalare  membri con BC nullo (allarme degenerazione)
%     .assumptions       table    registro delle ipotesi attive
%     .table             table    riepilogo per metodo
%     .tablePlayers      table    Dcd, Dworst e BC per membro

    if nargin < 4 || isempty(opts), opts = struct(); end

    [n, nM] = size(phiMat);
    BC      = BC(:);

    % --- Guardie sugli ingressi ---------------------------------------------
    if numel(BC) ~= n
        error('fairness_index_bm:bcSizeMismatch', ...
              'BC ha %d elementi, phiMat ha %d righe.', numel(BC), n);
    end
    methodNames = string(methodNames(:).');
    if numel(methodNames) ~= nM
        error('fairness_index_bm:nameSizeMismatch', ...
              'methodNames ha %d elementi, phiMat ha %d colonne.', ...
              numel(methodNames), nM);
    end
    if ~all(isfinite(phiMat), 'all') || ~all(isfinite(BC))
        error('fairness_index_bm:nonFiniteInput', ...
              'Ripartizioni o contributi con NaN o Inf: controllare i dati a monte.');
    end
    if sum(BC) <= 0
        error('fairness_index_bm:degenerateContribution', ...
              ['La somma dei contributi e'' %.6g <= 0: la distribuzione di ' ...
               'riferimento dell''eq. 13 non e'' definita.'], sum(BC));
    end

    % Snapshot PRIMA dei default (vedi tri_level_ep_cer.m).
    tracciati = {'Dworst', 'sigmaMode'};
    fornito   = struct();
    for k = 1:numel(tracciati)
        fornito.(tracciati{k}) = isfield(opts, tracciati{k});
    end

    if ~isfield(opts, 'playerNames'),  opts.playerNames  = "membro_" + string(1:n); end
    if ~isfield(opts, 'sigmaMode'),    opts.sigmaMode    = "deviation";             end
    if ~isfield(opts, 'tolZero'),      opts.tolZero      = 1e-9;                    end
    if ~isfield(opts, 'validateSelf'), opts.validateSelf = true;                    end
    if ~isfield(opts, 'quiet'),        opts.quiet        = false;                   end

    opts.sigmaMode = string(opts.sigmaMode);
    if ~ismember(opts.sigmaMode, ["deviation", "distribution"])
        error('fairness_index_bm:badSigmaMode', ...
              'opts.sigmaMode deve essere "deviation" o "distribution", e'' "%s".', ...
              opts.sigmaMode);
    end

    % --- Distribuzione di riferimento (eq. 13) ------------------------------
    Dcd = BC / sum(BC);

    % --- Distribuzione peggiore e denominatore (vedi header) ----------------
    if fornito.Dworst
        Dworst = opts.Dworst(:);
        if numel(Dworst) ~= n
            error('fairness_index_bm:dworstSizeMismatch', ...
                  'opts.Dworst ha %d elementi, i membri sono %d.', numel(Dworst), n);
        end
        denom = sum(abs(Dworst - Dcd));
    else
        % [IPOTESI 1] Dw derivata: vertice del simplesso che massimizza la
        % distanza L1 dal riferimento.
        [Dworst, denom] = local_worst_distribution(Dcd);
    end

    if denom <= 0
        error('fairness_index_bm:zeroDenominator', ...
              ['Il denominatore dell''eq. 14 e'' nullo: la distribuzione di ' ...
               'riferimento coincide con la peggiore, il FI non e'' definito.']);
    end

    % --- Fairness Index per ciascun metodo (eq. 14) -------------------------
    D             = zeros(n, nM);
    FI            = zeros(nM, 1);
    isRatioBranch = false(nM, 1);
    sigma         = zeros(nM, 1);
    maxDeviation  = zeros(nM, 1);
    nZeroShare    = zeros(nM, 1);

    for k = 1:nM
        tot = sum(phiMat(:, k));
        if tot <= 0
            error('fairness_index_bm:nonPositiveAllocation', ...
                  ['Il metodo "%s" distribuisce un totale di %.6g <= 0: le ' ...
                   'quote non sono normalizzabili.'], methodNames(k), tot);
        end
        D(:, k) = phiMat(:, k) / tot;

        mPos             = sum(D(:, k) > opts.tolZero);
        nZeroShare(k)    = n - mPos;
        isRatioBranch(k) = (mPos == n);

        if isRatioBranch(k)
            FI(k) = sum(abs(D(:, k) - Dcd)) / denom;
        else
            FI(k) = n - mPos;
        end

        if opts.sigmaMode == "deviation"
            sigma(k) = std(D(:, k) - Dcd);
        else
            sigma(k) = std(D(:, k));
        end
        maxDeviation(k) = max(abs(D(:, k) - Dcd));
    end

    % Proprieta' dichiarata dal paper ("0 <= FI < 1"): nella branca del
    % rapporto il massimo sta in un vertice, che pero' ha quote nulle e finisce
    % nell'altra branca. Se questo assert cade, e' rotta la derivazione di Dw.
    assert(all(FI(isRatioBranch) >= 0 & FI(isRatioBranch) < 1 + 1e-12), ...
           'fairness_index_bm: FI fuori da [0,1) nella branca del rapporto');

    % --- Registro delle ipotesi ---------------------------------------------
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});
    if ~fornito.Dworst
        reg = local_note(reg, 1, 'Distribuzione peggiore Dw', ...
                         'derivata (vertice del simplesso), non data dal paper', ...
                         'passare opts.Dworst con una definizione alternativa');
    end
    if ~fornito.sigmaMode
        reg = local_note(reg, 2, 'Deviazione standard di Tab. 7', ...
                         'std(D_i - Dcd_i), lettura non esplicitata dal paper', ...
                         'passare opts.sigmaMode = "distribution" per l''altra lettura');
    end
    % Sempre attiva: non e' una scelta ma un dato che al progetto manca.
    reg = local_note(reg, 3, 'Costi di investimento per membro', ...
                     'ASSENTI: D_i calcolato sui benefici LORDI', ...
                     ['fornire il costo di investimento di ciascun membro e ' ...
                      'nettizzarlo dalle quote prima di normalizzare (par. 2.5 del paper)']);

    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    F.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                   string({reg.valore}).', string({reg.rimozione}).', ...
                                   'VariableNames', colonneReg), 'Id');

    % --- Struttura di uscita -------------------------------------------------
    F.methods           = methodNames;
    F.players           = string(opts.playerNames(:).');
    F.Dcd               = Dcd;
    F.Dworst            = Dworst;
    F.denom             = denom;
    F.BC                = BC;
    F.D                 = D;
    F.deviation         = D - Dcd;
    F.FI                = FI;
    F.isRatioBranch     = isRatioBranch;
    F.sigma             = sigma;
    F.maxDeviation      = maxDeviation;
    F.nZeroShare        = nZeroShare;
    F.nZeroContribution = sum(abs(BC) <= opts.tolZero * max(1, max(abs(BC))));
    F.sigmaMode         = opts.sigmaMode;

    F.table = table(methodNames(:), FI, sigma, maxDeviation, nZeroShare, isRatioBranch, ...
                    'VariableNames', {'Metodo', 'FairnessIndex', 'Sigma', ...
                                      'ScostamentoMax', 'QuoteNulle', 'BrancaRapporto'});

    F.tablePlayers = table(F.players(:), BC, Dcd, Dworst, ...
                           'VariableNames', {'Giocatore', 'Contributo_EUR', ...
                                             'Dcd', 'Dworst'});

    if opts.validateSelf
        local_validate_self();
    end

    if ~opts.quiet
        fprintf('\n  Ipotesi attive (fairness_index_bm):\n');
        for k = 1:numel(reg)
            fprintf('    [%d] %s: %s\n', reg(k).id, reg(k).voce, reg(k).valore);
        end
        if F.nZeroContribution > 0
            fprintf(['    ATTENZIONE: %d membri su %d hanno contributo nullo. ' ...
                     'La distribuzione di riferimento e'' degenere,\n' ...
                     '                vedi "COSA ASPETTARSI" nell''header ' ...
                     '(help fairness_index_bm).\n'], F.nZeroContribution, n);
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function [Dworst, denom] = local_worst_distribution(Dcd)
%LOCAL_WORST_DISTRIBUTION  Vertice del simplesso piu' lontano in norma L1 dalla
%   distribuzione di riferimento (derivazione nell'header).
    absDcd = abs(Dcd);
    vals   = abs(1 - Dcd) + (sum(absDcd) - absDcd);
    [denom, kStar] = max(vals);
    Dworst = zeros(numel(Dcd), 1);
    Dworst(kStar) = 1;
end

function reg = local_note(reg, id, voce, valore, rimozione)
%LOCAL_NOTE  Aggiunge una voce al registro delle ipotesi ancora attive.
    reg(end+1) = struct('id', id, 'voce', voce, 'valore', valore, ...
                        'rimozione', rimozione);
end

function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test analitico dell'eq. 14.
%
%   La Tab. 7 del paper (FI = 0.198/0.306/0.062/0.186/0.074 per i BM A-E) NON
%   e' riproducibile: i D_i e Dcd_i per singolo membro stanno solo nella
%   Fig. 13, che e' un grafico. Si verifica quindi la formula su casi costruiti
%   a mano, di cui il risultato si calcola a penna.
    tol = 1e-12;
    Dcd = [0.4; 0.3; 0.2; 0.1];

    % Denominatore: vertice sul membro con Dcd minimo -> 2*(1 - 0.1) = 1.8
    [Dw, den] = local_worst_distribution(Dcd);
    assert(abs(den - 1.8) < tol && Dw(4) == 1, ...
           'fairness_index_bm: denominatore o vertice peggiore errati');

    % Metodo che coincide col riferimento -> FI = 0
    assert(abs(sum(abs(Dcd - Dcd)) / den - 0) < tol, ...
           'fairness_index_bm: un metodo uguale al riferimento non da'' FI = 0');

    % Ripartizione uniforme: |0.15|+|0.05|+|0.05|+|0.15| = 0.4 -> 0.4/1.8
    Duni = [0.25; 0.25; 0.25; 0.25];
    assert(abs(sum(abs(Duni - Dcd)) / den - 0.4/1.8) < tol, ...
           'fairness_index_bm: FI della ripartizione uniforme errato');

    % Branca degli interi: due membri a quota nulla su quattro -> FI = 2
    Dzero = [0.5; 0.5; 0; 0];
    assert(numel(Dcd) - sum(Dzero > 0) == 2, ...
           'fairness_index_bm: conteggio dei membri a quota nulla errato');

    % Contributi negativi ammessi: Dcd = [1.2; -0.2], vertice su k = 2
    % -> |1-(-0.2)| + |1.2| = 1.2 + 1.2 = 2.4
    [~, den2] = local_worst_distribution([1.2; -0.2]);
    assert(abs(den2 - 2.4) < tol, ...
           'fairness_index_bm: denominatore errato con contributi negativi');
end
