function plot_merit_deviation(BM, players, methodNames)
%PLOT_MERIT_DEVIATION  Chi viene premiato e chi penalizzato rispetto alla
%   distribuzione per contributo marginale, metodo per metodo e membro per
%   membro.
%
%   COSA AGGIUNGE AL FAIRNESS INDEX
%     Il Fairness Index di Casalicchio et al. (eq. 14) comprime in UN NUMERO
%     per metodo la distanza fra la ripartizione e la distribuzione di
%     riferimento D_cd, quella proporzionale al contributo marginale
%     BC_i = v(N) - v(N\{i}). Un numero solo dice QUANTO un metodo se ne
%     discosta, ma non DA CHE PARTE: due metodi con lo stesso FI possono
%     spostare valore in direzioni opposte. Questa mappa apre quel numero e
%     mostra il segno dello scostamento membro per membro. E' il complemento
%     naturale del secondo pannello di plot_fairness_indicators, che del
%     Fairness Index tiene solo lo scalare.
%
%   SCALA DIVERGENTE E SIMMETRICA, CENTRATA SULLO ZERO
%     Qui, a differenza di plot_allocation_heatmap, lo zero e' un valore
%     privilegiato e non un estremo: significa "questo membro riceve
%     esattamente quanto contribuisce". Il colore deve percio' dire il segno
%     prima ancora del modulo, e i due versi devono pesare uguale - altrimenti
%     uno scostamento di +5 punti sembrerebbe piu' grave di uno di -5 solo per
%     via della normalizzazione. Da qui la scala simmetrica su +-max|dev|.
%
%   AVVERTENZA DA LEGGERE PRIMA DELLA FIGURA
%     Se qualche membro ha contributo marginale NULLO, la distribuzione di
%     riferimento e' degenere: assegna zero a chi non e' pivotale, e ogni
%     metodo che gli dia qualcosa risulta "in eccesso" rispetto al merito. Con
%     un solo impianto in comunita' e' la norma, non l'eccezione. Il numero di
%     membri in quella condizione e' scritto nel sottotitolo proprio perche' la
%     mappa non venga letta come una classifica morale.
%
%   INPUT
%     BM           struct  uscita di fairness_index_bm, con almeno i campi
%                            .deviation [n x nM]  D - D_cd (quote, non EUR)
%                            .Dcd       [n x 1]   distribuzione di riferimento
%                            .nZeroContribution   scalare
%     players      [1 x n]  string  nomi dei giocatori
%     methodNames  [1 x nM] string  nomi dei metodi

    players     = string(players(:).');
    methodNames = string(methodNames(:).');
    nP          = numel(players);
    nM          = numel(methodNames);

    % Punti percentuali: le quote di fairness_index_bm sono frazioni che
    % sommano a 1, e "+3.2 punti" si legge meglio di "+0.032".
    Dev = 100 * BM.deviation.';        % [nM x nP] - metodi in riga, come B1
    Ref = 100 * BM.Dcd(:).';           % [1 x nP]

    lim = max(abs(Dev(:)));
    if ~isfinite(lim) || lim == 0, lim = 1; end

    figure('Name', 'Scostamento dal merito', 'Color', 'w', ...
           'Position', [70 70 300+130*nP 250+30*nM]);
    tl = tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Scostamento dalla distribuzione per contributo marginale', ...
          'FontWeight', 'bold');
    subtitle(tl, sprintf(['blu = riceve PIU'' del proprio contributo, rosso = MENO  |  ' ...
                          'punti percentuali di v(N)  |  %d membri con contributo nullo'], ...
                         BM.nZeroContribution), 'FontSize', 9);

    % --- Fascia superiore: la distribuzione di riferimento -------------------
    % Senza, la mappa sotto e' illeggibile: uno scostamento di -2 punti su un
    % membro che dovrebbe prenderne 3 e' quasi un'esclusione, sullo stesso
    % scostamento su un membro da 40 punti e' rumore.
    axRef = nexttile;
    bar(axRef, 1:nP, Ref, 0.6, 'FaceColor', [0.45 0.45 0.48], 'EdgeColor', 'none');
    grid(axRef, 'on'); box(axRef, 'on');
    xlim(axRef, [0.5 nP+0.5]); xticks(axRef, 1:nP); xticklabels(axRef, []);
    ylabel(axRef, {'Riferimento', 'D_{cd} [%]'});
    title(axRef, 'Distribuzione per contributo marginale BC_i = v(N) - v(N\\{i})');

    % --- Mappa dello scostamento ---------------------------------------------
    ax = nexttile([3 1]);
    cmap = local_cmap_divergente();
    imagesc(ax, Dev);
    colormap(ax, cmap);
    clim(ax, [-lim lim]);
    cb = colorbar(ax);
    cb.Label.String = 'Scostamento da D_{cd} [punti % di v(N)]';

    xticks(ax, 1:nP);
    xticklabels(ax, strrep(players, '_', '\_'));
    xtickangle(ax, 45);
    yticks(ax, 1:nM);
    yticklabels(ax, strrep(methodNames, '_', '\_'));
    set(ax, 'TickLength', [0 0]);
    box(ax, 'on');

    for r = 1:nM
        for c = 1:nP
            v   = Dev(r, c);
            idx = 1 + round((v + lim) / (2*lim) * (size(cmap,1) - 1));
            idx = min(max(idx, 1), size(cmap,1));
            lum = cmap(idx,:) * [0.299; 0.587; 0.114];
            if lum < 0.5, col = [1 1 1]; else, col = [0 0 0]; end
            text(ax, c, r, sprintf('%+.1f', v), 'HorizontalAlignment', 'center', ...
                 'Color', col, 'FontSize', 8);
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function cmap = local_cmap_divergente()
%LOCAL_CMAP_DIVERGENTE  Rosso -> bianco -> blu, con il bianco esattamente al
%   centro. Stessi estremi della scala di plot_fairness_indicators, cosi' le
%   due figure si leggono con lo stesso codice colore; li' pero' il bianco e'
%   un punto qualunque della graduatoria, qui e' lo zero - il che rende la
%   scala divergente l'unica onesta.
    rosso  = [0.79 0.29 0.20];
    bianco = [0.97 0.96 0.94];
    blu    = [0.13 0.42 0.58];

    m = 128;
    t = linspace(0, 1, m).';
    cmap = [rosso  + t .* (bianco - rosso); ...
            bianco + t .* (blu    - bianco)];
end
