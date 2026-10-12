function F = fase1_shapley_vs_as(RESULTS, opts)
%FASE1_SHAPLEY_VS_AS  Fase 1 di MAIN2: Shapley esatto e Adaptive Sampling
%   Shapley, con due set di risultati distinti per regime di taglia.
%
%   REGIME <= 18 UTENTI ("le18")
%     Shapley esatto e Adaptive Sampling Shapley sono due metodi separati,
%     calcolati entrambi. Qui si affiancano e si misura lo scarto del secondo
%     dal primo, che e' il riferimento esatto:
%       RD_i   = |phiAS_i - phiSh_i| / |phiSh_i| * 100   (eq. 16 di Cremers
%                et al. 2023, membri con Shapley non nullo)
%       L1     = sum_i |phiAS_i - phiSh_i| / v(N) * 100  (euro spostati, in %
%                del montepremi)
%       rho    = correlazione di Spearman fra le due graduatorie dei membri
%
%   REGIME > 18 UTENTI ("gt18")
%     Lo Shapley esatto non e' calcolabile (2^n coalizioni) e l'Adaptive
%     Sampling Shapley lo sostituisce. Non c'e' un riferimento con cui misurare
%     lo scarto: si riportano le quote e il fattore di normalizzazione (somma
%     delle stime grezze rispetto a v(N)), unica diagnostica disponibile.
%
%   INPUT
%     RESULTS  struct array di MAIN2, con il campo .fase1 per comunita'
%     opts     struct opzionale:
%                .cartellaTabelle  dove scrivere i CSV  (def. outputs/tables_main2/fase1)
%                .cartellaFigure   dove scrivere PDF e PNG (def. outputs/figures_main2/fase1)
%                .chiudi           chiude le figure dopo l'export (def. true)
%                .quiet            non stampare il riepilogo (def. false)
%
%   OUTPUT (struct F)
%     .le18PerCER, .le18PerMembro, .le18PerTaglia   tabelle del regime <= 18
%     .gt18PerCER, .gt18PerMembro                   tabelle del regime > 18

    if nargin < 2 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'cartellaTabelle'), opts.cartellaTabelle = "outputs/tables_main2/fase1"; end
    if ~isfield(opts, 'cartellaFigure'),  opts.cartellaFigure  = "outputs/figures_main2/fase1"; end
    if ~isfield(opts, 'chiudi'),          opts.chiudi          = true;  end
    if ~isfield(opts, 'quiet'),           opts.quiet           = false; end

    NOME_AS = "Adaptive Sampling Shapley";   % stesso nome usato in MAIN2 e report_allocation

    nK     = numel(RESULTS);
    schede = strings(nK, 1);
    for c = 1:nK
        [~, schede(c)] = fileparts(RESULTS(c).scheda);
    end
    rec    = [RESULTS.fase1];
    regime = [rec.regime].';
    nUt    = [rec.nUsers].';
    pen    = [rec.penetrazione].';

    % Ordine di lettura: per taglia, poi per penetrazione
    [~, ordine] = sortrows([nUt, pen]);

    F = struct();

    % =====================================================================
    %  REGIME <= 18 UTENTI
    % =====================================================================
    iLe = ordine(regime(ordine) == "le18");
    nLe = numel(iLe);

    cS = strings(nLe,1); cN = zeros(nLe,1); cP = zeros(nLe,1); cV = zeros(nLe,1);
    cRDm = nan(nLe,1); cRDx = nan(nLe,1); cL1 = zeros(nLe,1); cErrMax = zeros(nLe,1);
    cRho = nan(nLe,1); cM = zeros(nLe,1); cSeed = zeros(nLe,1);
    mS = strings(0,1); mN = zeros(0,1); mG = strings(0,1);
    mSh = zeros(0,1); mAS = zeros(0,1); mRD = zeros(0,1);

    for q = 1:nLe
        r  = rec(iLe(q));
        sh = r.phiShapley(:);
        as = r.phiAS(:);
        ok = abs(sh) > 1e-9 * max(1, abs(r.vGrand));
        rd = nan(size(sh));
        rd(ok) = 100 * abs(as(ok) - sh(ok)) ./ abs(sh(ok));

        cS(q)  = schede(iLe(q));  cN(q) = r.nUsers;  cP(q) = r.penetrazione;
        cV(q)  = r.vGrand;
        cRDm(q) = mean(rd, 'omitnan');
        cRDx(q) = max(rd, [], 'omitnan');
        cL1(q)  = 100 * sum(abs(as - sh)) / r.vGrand;
        cErrMax(q) = max(abs(as - sh));
        cRho(q) = local_spearman(sh, as);
        cM(q)   = r.M;  cSeed(q) = r.seed;

        nm = numel(sh);
        mS  = [mS;  repmat(cS(q), nm, 1)];        %#ok<AGROW>
        mN  = [mN;  repmat(r.nUsers, nm, 1)];     %#ok<AGROW>
        mG  = [mG;  r.players(:)];                %#ok<AGROW>
        mSh = [mSh; sh];                          %#ok<AGROW>
        mAS = [mAS; as];                          %#ok<AGROW>
        mRD = [mRD; rd];                          %#ok<AGROW>
    end

    F.le18PerCER = table(cS, cN, cP, cV, cRDm, cRDx, cL1, cErrMax, cRho, cM, cSeed, ...
        'VariableNames', {'Scheda', 'Membri', 'Penetrazione_pct', 'vN_EUR', ...
                          'RD_medio_pct', 'RD_max_pct', 'L1_su_vN_pct', ...
                          'ScartoMax_EUR', 'Spearman_rho', 'AS_campioni_M', 'AS_seed'});

    F.le18PerMembro = table(mS, mN, mG, mSh, mAS, mAS - mSh, mRD, ...
        'VariableNames', {'Scheda', 'Membri', 'Giocatore', 'ShapleyEsatto_EUR', ...
                          'AdaptiveSamplingShapley_EUR', 'Scarto_EUR', 'Scarto_rel_pct'});

    taglie = unique(cN);
    tN = taglie; tK = zeros(numel(taglie),1);
    tRDm = nan(numel(taglie),1); tRDx = nan(numel(taglie),1); tL1 = nan(numel(taglie),1);
    tRho = nan(numel(taglie),1); tRhoMin = nan(numel(taglie),1);
    for t = 1:numel(taglie)
        s = cN == taglie(t);
        tK(t)      = sum(s);
        tRDm(t)    = mean(cRDm(s), 'omitnan');
        tRDx(t)    = max(cRDx(s), [], 'omitnan');
        tL1(t)     = mean(cL1(s));
        tRho(t)    = mean(cRho(s), 'omitnan');
        tRhoMin(t) = min(cRho(s), [], 'omitnan');
    end
    F.le18PerTaglia = table(tN, tK, tRDm, tRDx, tL1, tRho, tRhoMin, ...
        'VariableNames', {'Membri', 'Comunita', 'RD_medio_pct', 'RD_max_pct', ...
                          'L1_su_vN_pct', 'Spearman_rho_medio', 'Spearman_rho_min'});

    % =====================================================================
    %  REGIME > 18 UTENTI
    % =====================================================================
    iGt = ordine(regime(ordine) == "gt18");
    nGt = numel(iGt);
    gS = strings(nGt,1); gN = zeros(nGt,1); gP = zeros(nGt,1); gV = zeros(nGt,1);
    gNorm = zeros(nGt,1); gQmin = zeros(nGt,1); gQmax = zeros(nGt,1);
    gM = zeros(nGt,1); gSeed = zeros(nGt,1);
    hS = strings(0,1); hN = zeros(0,1); hG = strings(0,1); hAS = zeros(0,1); hQ = zeros(0,1);
    for q = 1:nGt
        r  = rec(iGt(q));
        as = r.phiAS(:);
        quota = 100 * as / r.vGrand;
        gS(q) = schede(iGt(q));  gN(q) = r.nUsers;  gP(q) = r.penetrazione;
        gV(q) = r.vGrand;  gNorm(q) = r.normFactor;
        gQmin(q) = min(quota);  gQmax(q) = max(quota);
        gM(q) = r.M;  gSeed(q) = r.seed;
        nm = numel(as);
        hS  = [hS;  repmat(gS(q), nm, 1)];     %#ok<AGROW>
        hN  = [hN;  repmat(r.nUsers, nm, 1)];  %#ok<AGROW>
        hG  = [hG;  r.players(:)];             %#ok<AGROW>
        hAS = [hAS; as];                       %#ok<AGROW>
        hQ  = [hQ;  quota];                    %#ok<AGROW>
    end
    F.gt18PerCER = table(gS, gN, gP, gV, gNorm, gQmin, gQmax, gM, gSeed, ...
        'VariableNames', {'Scheda', 'Membri', 'Penetrazione_pct', 'vN_EUR', ...
                          'FattoreNormalizzazione', 'QuotaMin_pct', 'QuotaMax_pct', ...
                          'AS_campioni_M', 'AS_seed'});
    F.gt18PerMembro = table(hS, hN, hG, hAS, hQ, ...
        'VariableNames', {'Scheda', 'Membri', 'Giocatore', ...
                          'AdaptiveSamplingShapley_EUR', 'Quota_pct'});

    % =====================================================================
    %  TABELLE SU FILE
    % =====================================================================
    daScrivere = struct();
    if nLe > 0
        daScrivere.regime_le18_Shapley_vs_AS_per_CER    = F.le18PerCER;
        daScrivere.regime_le18_Shapley_vs_AS_per_membro = F.le18PerMembro;
        daScrivere.regime_le18_Shapley_vs_AS_per_taglia = F.le18PerTaglia;
    end
    if nGt > 0
        daScrivere.regime_gt18_AS_per_CER    = F.gt18PerCER;
        daScrivere.regime_gt18_AS_per_membro = F.gt18PerMembro;
    end
    fprintf('\n=== Fase 1: tabelle su file ===\n');
    if ~isempty(fieldnames(daScrivere))
        save_tables(opts.cartellaTabelle, daScrivere);
    end

    % =====================================================================
    %  FIGURE
    % =====================================================================
    cSh = method_color("Shapley");
    cAS = method_color(NOME_AS);
    figs = gobjects(0);

    if nLe > 0
        % --- (a) quote per membro: AS contro Shapley esatto ---------------
        f = figure('Name', 'fase1_regime_le18_quote_Shapley_vs_AS', 'Color', 'w', ...
                   'Position', [80 80 640 560]);
        ax = axes(f); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
        cmap = parula(max(2, numel(taglie)));
        vNm  = repelem(cV, cN);          % v(N) della comunita' di ciascun membro
        qSh  = 100 * mSh ./ vNm;
        qAS  = 100 * mAS ./ vNm;
        h = gobjects(numel(taglie), 1);
        for t = 1:numel(taglie)
            s = mN == taglie(t);
            h(t) = scatter(ax, qSh(s), qAS(s), 28, ...
                           cmap(t, :), 'filled', 'MarkerFaceAlpha', 0.75);
        end
        lim = [0, max([qSh; qAS])] * 1.05;
        plot(ax, lim, lim, 'k--', 'LineWidth', 1);
        xlim(ax, lim); ylim(ax, lim); axis(ax, 'square');
        xlabel(ax, 'Shapley esatto [% di v(N)]');
        ylabel(ax, sprintf('%s [%% di v(N)]', NOME_AS));
        legend(ax, h, compose('%d membri', taglie), 'Location', 'southeast');
        title(ax, {'Regime \leq 18 utenti', ...
                   sprintf('Shapley esatto contro %s, quota di ciascun membro', NOME_AS)});
        figs(end+1) = f;

        % --- (b) scarto per taglia ----------------------------------------
        f = figure('Name', 'fase1_regime_le18_scarto_per_taglia', 'Color', 'w', ...
                   'Position', [80 80 1200 380]);
        tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('Regime \\leq 18 utenti - scarto dell''%s dallo Shapley esatto', NOME_AS));
        serie = {cRDm, cL1, cRho};
        medie = {tRDm, tL1, tRho};
        etich = {'RD medio sui membri [%]', 'Euro spostati [% di v(N)]', ...
                 '\rho di Spearman fra le graduatorie'};
        for p = 1:3
            ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
            scatter(ax, cN, serie{p}, 30, cAS, 'filled', 'MarkerFaceAlpha', 0.6);
            plot(ax, tN, medie{p}, '-o', 'Color', cSh, 'LineWidth', 1.5, ...
                 'MarkerFaceColor', cSh);
            xlabel(ax, 'Membri della comunita''');
            ylabel(ax, etich{p});
            xticks(ax, tN);
            if p == 3, ylim(ax, [min(0, min(cRho) - 0.05), 1.02]); end
        end
        legend(nexttile(tl, 1), {'una comunita''', 'media per taglia'}, 'Location', 'northeast');
        figs(end+1) = f;

        % --- (c) affiancati, un pannello per comunita' --------------------
        nCol = min(4, nLe);
        nRow = ceil(nLe / nCol);
        f = figure('Name', 'fase1_regime_le18_affiancati', 'Color', 'w', ...
                   'Position', [40 40 360*nCol 260*nRow]);
        tl = tiledlayout(f, nRow, nCol, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, sprintf('Regime \\leq 18 utenti - Shapley esatto e %s affiancati [EUR/anno]', NOME_AS));
        for q = 1:nLe
            s  = mS == cS(q);
            ax = nexttile(tl);
            hb = bar(ax, [mSh(s), mAS(s)], 'grouped', 'EdgeColor', 'none');
            hb(1).FaceColor = cSh;  hb(2).FaceColor = cAS;
            grid(ax, 'on'); box(ax, 'on');
            xticks(ax, 1:sum(s)); xticklabels(ax, []);
            title(ax, sprintf('%s  (n = %d, %.0f%%)', strrep(cS(q), '_', '\_'), ...
                              cN(q), cP(q)), 'FontWeight', 'normal');
        end
        lg = legend(nexttile(tl, 1), {'Shapley esatto', char(NOME_AS)}, 'Orientation', 'horizontal');
        lg.Layout.Tile = 'south';
        xlabel(tl, 'membri della comunita''');
        figs(end+1) = f;
    end

    if nGt > 0
        % --- (d) solo AS, un pannello per comunita' ------------------------
        nCol = min(4, nGt);
        nRow = ceil(nGt / nCol);
        f = figure('Name', 'fase1_regime_gt18_AS', 'Color', 'w', ...
                   'Position', [40 40 360*nCol 260*nRow]);
        tl = tiledlayout(f, nRow, nCol, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(tl, {sprintf('Regime > 18 utenti - %s [EUR/anno]', NOME_AS), ...
                   'sostituisce lo Shapley esatto, non calcolabile (2^n coalizioni)'});
        for q = 1:nGt
            s  = hS == gS(q);
            ax = nexttile(tl);
            bar(ax, hAS(s), 'FaceColor', cAS, 'EdgeColor', 'none');
            grid(ax, 'on'); box(ax, 'on');
            xticks(ax, 1:sum(s)); xticklabels(ax, []);
            title(ax, sprintf('%s  (n = %d, %.0f%%)', strrep(gS(q), '_', '\_'), ...
                              gN(q), gP(q)), 'FontWeight', 'normal');
        end
        xlabel(tl, 'membri della comunita''');
        figs(end+1) = f;
    end

    if ~isempty(figs)
        cartella = string(opts.cartellaFigure);
        if ~isfolder(cartella), mkdir(cartella); end
        drawnow;
        for k = 1:numel(figs)
            base = fullfile(cartella, string(figs(k).Name));
            exportgraphics(figs(k), base + ".pdf", 'ContentType', 'vector');
            exportgraphics(figs(k), base + ".png", 'Resolution', 200);
        end
        fprintf('  %d figure della fase 1 salvate in %s\n', numel(figs), cartella);
        if opts.chiudi, close(figs); end
    end

    if ~opts.quiet
        fprintf('\n=== Fase 1 - regime <= 18 utenti: %s contro Shapley esatto ===\n', NOME_AS);
        if nLe > 0, disp(F.le18PerTaglia); else, fprintf('  nessuna comunita'' in questo regime\n'); end
        fprintf('\n=== Fase 1 - regime > 18 utenti: solo %s ===\n', NOME_AS);
        if nGt > 0, disp(F.gt18PerCER); else, fprintf('  nessuna comunita'' in questo regime\n'); end
    end
end


function rho = local_spearman(a, b)
%LOCAL_SPEARMAN  Correlazione di Spearman con ranghi medi sui pareggi, scritta
%   a mano perche' il progetto non dipende dallo Statistics Toolbox.
    ra = local_ranghi(a(:));
    rb = local_ranghi(b(:));
    if std(ra) == 0 || std(rb) == 0
        rho = NaN;
        return
    end
    C   = corrcoef(ra, rb);
    rho = C(1, 2);
end

function r = local_ranghi(x)
    [~, ord] = sort(x);
    r = zeros(size(x));
    r(ord) = 1:numel(x);
    valori = unique(x);
    for v = valori.'
        s = x == v;
        if sum(s) > 1, r(s) = mean(r(s)); end
    end
end
