function fig = plot_ranking_grid(G, indicatori)
%PLOT_RANKING_GRID  Heatmap congiunta taglia x penetrazione: in ogni cella il
%   metodo primo classificato, un pannello per criterio.
%
%   COME SI LEGGE L'INTERAZIONE
%     Righe = taglie, colonne = fasce di penetrazione. Se le bande di colore
%     sono le stesse su ogni riga, l'effetto della penetrazione sul vincitore
%     non dipende dalla taglia; se cambiano forma da una riga all'altra, i due
%     fattori interagiscono. La QuotaModale nel titolo lo riassume in un numero
%     (ranking_grid). Ogni cella riporta la penetrazione ESATTA: le fasce sono
%     ranghi dentro la taglia, non valori comuni.
%
%   Cella grigia chiara = primi due a pari entro la tolleranza. Cella bianca
%   "n.d." = indicatore non calcolato o non discriminante in quella
%   configurazione (per esempio l'eccesso di coalizione sopra i 18 membri, o
%   il VAN dove la scheda non compila quota_inv_EUR).
%
%   INPUT
%     G           uscita di ranking_grid
%     indicatori  string, un pannello per indicatore. Default: uno per
%                 dimensione della domanda di ricerca.

    if nargin < 2 || isempty(indicatori)
        indicatori = ["EI_orig", "FairnessIndex", "EccessoMax_EUR", ...
                      "ForzaIncentivante", "VAN_min_EUR"];
    end
    etichette = containers.Map( ...
        {'EI_orig', 'FairnessIndex', 'EccessoMax_EUR', 'ForzaIncentivante', 'VAN_min_EUR'}, ...
        {'equita'' - uniformita''', 'equita'' - merito', 'equita'' - stabilita''', ...
         'forza incentivante', 'sostenibilita'' economica'});
    indicatori = indicatori(ismember(indicatori, G.indicators));

    [nN, nT] = size(G.idx);
    nP   = numel(indicatori);
    nCol = min(3, nP + 1);
    nRow = ceil((nP + 1) / nCol);

    fig = figure('Name', 'Vincitore su taglia x penetrazione', 'Color', 'w', ...
                 'Position', [80 80 420*nCol 330*nRow]);
    tl = tiledlayout(nRow, nCol, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Metodo primo classificato per taglia e penetrazione prosumer');

    presenti = strings(0,1);
    for p = 1:nP
        j = find(G.indicators == indicatori(p), 1);
        V = G.vincitore(:, :, j);
        img = ones(nN, nT, 3);
        for r = 1:nN
            for k = 1:nT
                if V(r, k) == "(pari)"
                    img(r, k, :) = 0.88;
                elseif V(r, k) ~= ""
                    img(r, k, :) = method_color(V(r, k));
                    presenti(end+1,1) = V(r, k); %#ok<AGROW>
                end
            end
        end

        ax = nexttile(tl);
        image(ax, img);
        axis(ax, 'ij');
        set(ax, 'XTick', 1:nT, 'XTickLabel', G.fasce, 'YTick', 1:nN, ...
                'YTickLabel', compose('%d membri', G.taglie), ...
                'TickLength', [0 0], 'FontSize', 8);
        xtickangle(ax, 20);
        hold(ax, 'on');
        for r = 0.5:1:nN+0.5, plot(ax, [0.5 nT+0.5], [r r], 'w-', 'LineWidth', 1.5); end
        for k = 0.5:1:nT+0.5, plot(ax, [k k], [0.5 nN+0.5], 'w-', 'LineWidth', 1.5); end
        for r = 1:nN
            for k = 1:nT
                if G.idx(r, k) == 0, continue; end
                if V(r, k) == "",           s = "n.d.";
                elseif V(r, k) == "(pari)"
                    s = strjoin(string(arrayfun(@local_sigla, split(G.primiAPari(r, k, j), " = "), ...
                                                'UniformOutput', false)).', "=");
                    presenti = [presenti; split(G.primiAPari(r, k, j), " = ")]; %#ok<AGROW>
                else,                       s = local_sigla(V(r, k));
                end
                testo = sprintf('%s\n%.0f%%', s, G.penetrazione(r, k));
                chiaro = V(r, k) ~= "" && V(r, k) ~= "(pari)" && ...
                         mean(method_color(V(r, k))) < 0.5;
                text(ax, k, r, testo, 'HorizontalAlignment', 'center', ...
                     'FontSize', 7, 'Color', [1 1 1]*chiaro);
            end
        end
        hold(ax, 'off');

        riga = G.interazione(G.interazione.Indicatore == indicatori(p), :);
        if etichette.isKey(char(indicatori(p)))
            nomeCrit = etichette(char(indicatori(p)));
        else
            nomeCrit = char(indicatori(p));
        end
        if riga.TaglieValide == 0
            sotto = 'interazione non valutabile';
        else
            sotto = sprintf('QuotaModale %.2f su %d taglie', riga.QuotaModale, riga.TaglieValide);
        end
        title(ax, {sprintf('%s  [%s]', nomeCrit, indicatori(p)), sotto}, ...
              'FontSize', 9, 'Interpreter', 'none');
    end

    % --- Legenda: sigla -> metodo, solo i metodi che vincono da qualche parte
    ax = nexttile(tl);
    axis(ax, 'off');
    presenti = unique(presenti, 'stable');
    for q = 1:numel(presenti)
        y = 1 - q / (numel(presenti) + 1);
        patch(ax, [0 0.08 0.08 0], [y-0.03 y-0.03 y+0.03 y+0.03], ...
              method_color(presenti(q)), 'EdgeColor', 'none');
        text(ax, 0.11, y, sprintf('%s  %s', local_sigla(presenti(q)), presenti(q)), ...
             'FontSize', 8, 'Interpreter', 'none');
    end
    xlim(ax, [0 1]); ylim(ax, [0 1]);
end


function s = local_sigla(nome)
%LOCAL_SIGLA  Iniziali delle parole: "Variance Least Core" -> "VLC".
    parti = split(string(nome), {' ', '-'});
    parti = parti(parti ~= "");
    s = upper(strjoin(extractBefore(parti, 2), ""));
end
