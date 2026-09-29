function G = ranking_grid(AGR, RESULTS, opts)
%RANKING_GRID  Dispone le configurazioni su una griglia taglia x fascia di
%   penetrazione e dice, cella per cella e indicatore per indicatore, quale
%   metodo vince. E' la base comune dei due sweep di reversals_by_axis e della
%   heatmap congiunta di plot_ranking_grid.
%
%   LE FASCE SONO RANGHI, NON SOGLIE
%     La penetrazione esatta dipende dalla taglia (a 5 membri i passi sono di
%     20 punti, a 25 di 4), quindi arrotondarla a 25/50/75/100% farebbe
%     collidere due configurazioni della stessa taglia (40% e 60% a n = 5
%     finirebbero entrambe su 50%). La fascia k e' la k-esima penetrazione in
%     ordine crescente DENTRO la taglia. L'etichetta riporta la mediana delle
%     penetrazioni della fascia; il valore esatto di ogni cella sta in
%     .penetrazione e nella tabella lunga.
%
%   INTERAZIONE FRA TAGLIA E PENETRAZIONE
%     Per ogni indicatore si prende, taglia per taglia, la sequenza dei
%     vincitori lungo le fasce. Se tutte le taglie hanno la stessa sequenza,
%     l'effetto della penetrazione sul vincitore non dipende dalla taglia:
%     QuotaModale = 1. Piu' le sequenze divergono, piu' i due fattori
%     interagiscono. Guarda solo il PRIMO classificato, non l'intera graduatoria.
%
%   INPUT
%     AGR      uscita di compute_indicator_agreement
%     RESULTS  struct array di MAIN.m, stesso ordine di AGR.schede (.nUsers)
%     opts     .quiet  non stampare il riepilogo (def. false)
%
%   OUTPUT (struct G)
%     .taglie        [1 x nN]          numero di membri, crescente
%     .fasce         [1 x nT] string   etichette delle fasce
%     .idx           [nN x nT]         indice della configurazione in AGR, 0 = cella vuota
%     .penetrazione  [nN x nT]         penetrazione esatta [%], NaN = cella vuota
%     .vincitore     [nN x nT x nI] string  metodo primo; "" = indicatore non
%                                     discriminante o cella vuota; "(pari)" = primi
%                                     due entro la tolleranza di pareggio
%     .primiAPari    [nN x nT x nI] string  metodi entro la tolleranza dal primo, " = "
%     .distacco      [nN x nT x nI]    punteggio orientato del primo meno il secondo
%     .table         table  formato lungo, una riga per (indicatore, cella)
%     .interazione   table  una riga per indicatore

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'quiet'), opts.quiet = false; end

    assert(numel(RESULTS) == numel(AGR.schede), ...
           'ranking_grid: RESULTS e AGR non descrivono le stesse configurazioni');
    for c = 1:numel(RESULTS)
        [~, base] = fileparts(RESULTS(c).scheda);
        assert(strtrim(string(base)) == string(AGR.schede(c)), ...
               'ranking_grid: RESULTS e AGR non sono nello stesso ordine');
    end

    n      = [RESULTS.nUsers];
    rho    = AGR.penetrazione;
    indic  = string(AGR.indicators);
    metodi = string(AGR.methods);
    nI     = numel(indic);

    taglie = unique(n);
    nN     = numel(taglie);
    nT     = max(arrayfun(@(t) sum(n == t), taglie));

    % --- Griglia -----------------------------------------------------------
    idx = zeros(nN, nT);
    P   = nan(nN, nT);
    for r = 1:nN
        cfg = find(n == taglie(r));
        [pOrd, o] = sort(rho(cfg), 'ascend');
        assert(all(diff(pOrd) > 0), ...
               'ranking_grid: due schede da %d membri hanno la stessa penetrazione', ...
               taglie(r));
        % Le taglie con meno configurazioni occupano le fasce ALTE: la fascia
        % piu' alta e' il 100%, presente a ogni taglia della griglia.
        col = (nT - numel(cfg) + 1):nT;
        idx(r, col) = cfg(o);
        P(r, col)   = pOrd;
    end
    fasce = strings(1, nT);
    for k = 1:nT
        fasce(k) = sprintf('fascia %d (~%.0f%%)', k, median(P(:, k), 'omitnan'));
    end

    % --- Vincitore per cella e indicatore -----------------------------------
    V = strings(nN, nT, nI);
    D = nan(nN, nT, nI);
    Q = strings(nN, nT, nI);   % tutti i metodi a pari col primo, separati da " = "
    for r = 1:nN
        for k = 1:nT
            c = idx(r, k);
            if c == 0, continue; end
            for j = 1:nI
                if ~AGR.discrimina(j, c), continue; end
                s = AGR.scores(:, j, c);
                ok = find(isfinite(s));
                if numel(ok) < 2, continue; end
                [sOrd, o] = sort(s(ok), 'descend');
                D(r, k, j) = sOrd(1) - sOrd(2);
                Q(r, k, j) = strjoin(metodi(ok(o(sOrd >= sOrd(1) - AGR.tolTie(j, c)))), " = ");
                if D(r, k, j) <= AGR.tolTie(j, c)
                    V(r, k, j) = "(pari)";
                else
                    V(r, k, j) = metodi(ok(o(1)));
                end
            end
        end
    end

    % --- Tabella lunga ------------------------------------------------------
    nRig = nI * nnz(idx);
    tInd = strings(nRig,1); tN = zeros(nRig,1); tF = zeros(nRig,1);
    tP = zeros(nRig,1); tS = strings(nRig,1); tV = strings(nRig,1); tD = nan(nRig,1);
    tQ = strings(nRig,1);
    q = 0;
    for j = 1:nI
        for r = 1:nN
            for k = 1:nT
                if idx(r, k) == 0, continue; end
                q = q + 1;
                tInd(q) = indic(j); tN(q) = taglie(r); tF(q) = k;
                tP(q) = P(r, k);    tS(q) = AGR.schede(idx(r, k));
                tV(q) = V(r, k, j); tD(q) = D(r, k, j); tQ(q) = Q(r, k, j);
            end
        end
    end
    G.table = table(tInd, tN, tF, tP, tS, tV, tQ, tD, 'VariableNames', ...
                    {'Indicatore', 'Membri', 'Fascia', 'Penetrazione_pct', ...
                     'Scheda', 'Vincitore', 'PrimiAPari', 'Distacco'});

    % --- Interazione --------------------------------------------------------
    iSeq = zeros(nI,1); iVal = zeros(nI,1); iMod = nan(nI,1); iSeqMod = strings(nI,1);
    for j = 1:nI
        righe = strings(0,1);
        for r = 1:nN
            v = V(r, :, j);
            if any(idx(r, :) == 0) || any(v == ""), continue; end
            righe(end+1,1) = strjoin(v, " > "); %#ok<AGROW>
        end
        iVal(j) = numel(righe);
        if iVal(j) == 0, continue; end
        [u, ~, g] = unique(righe);
        cnt = accumarray(g, 1);
        [mx, im] = max(cnt);
        iSeq(j)    = numel(u);
        iMod(j)    = mx / iVal(j);
        iSeqMod(j) = u(im);
    end
    G.interazione = table(indic(:), iVal, iSeq, iMod, iSeqMod, 'VariableNames', ...
                          {'Indicatore', 'TaglieValide', 'SequenzeDistinte', ...
                           'QuotaModale', 'SequenzaModale'});

    G.taglie       = taglie;
    G.fasce        = fasce;
    G.idx          = idx;
    G.penetrazione = P;
    G.vincitore    = V;
    G.primiAPari   = Q;
    G.distacco     = D;
    G.indicators   = indic;

    if ~opts.quiet
        fprintf('\n=== Griglia taglia x penetrazione ===\n');
        fprintf('  %-34s: %s\n', 'Taglie (membri)', strjoin(string(taglie), ', '));
        fprintf('  %-34s: %s\n', 'Fasce di penetrazione', strjoin(fasce, ', '));
        fprintf('  %-34s: %d su %d\n', 'Celle occupate', nnz(idx), numel(idx));
        fprintf('\n  Interazione sul vincitore (1 = stessa sequenza lungo la penetrazione a ogni taglia):\n');
        for j = 1:nI
            if iVal(j) == 0
                fprintf('    %-24s  nessuna taglia con tutte le fasce valutabili\n', indic(j));
            else
                fprintf('    %-24s  QuotaModale %.2f  (%d sequenze distinte su %d taglie)\n', ...
                        indic(j), iMod(j), iSeq(j), iVal(j));
            end
        end
    end
end
