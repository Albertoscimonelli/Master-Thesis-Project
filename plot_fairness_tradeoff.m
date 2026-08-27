function plot_fairness_tradeoff(Tfair, vGrand, titolo)
%PLOT_FAIRNESS_TRADEOFF  Uniformita' contro stabilita': i modelli di
%   ripartizione su un piano a due assi, con la frontiera di Pareto.
%
%   LA FIGURA CHE LA TABELLA NON PUO' DARE
%     Gli indici di equita' rispondono a domande diverse che possono dare
%     risposte OPPOSTE. L'Equal Split e' la ripartizione piu' uniforme
%     possibile (EI = 1, Gini = 0) ed e' anche la meno stabile: diversi
%     sottogruppi guadagnerebbero di piu' uscendo dalla CER. Il Nucleolo fa
%     l'esatto contrario. Finche' le due grandezze stanno in due colonne di una
%     tabella, o in due pannelli separati di una mappa di calore normalizzata
%     per colonna, il rapporto fra loro va ricostruito a mente. Su un piano
%     diventa una geometria: il compromesso si vede, e si vede anche chi non lo
%     fa.
%
%   PERCHE' UNA FRONTIERA DI PARETO E NON UNA CLASSIFICA
%     Non esiste un metodo "migliore" su due criteri in conflitto: esiste
%     l'insieme di quelli che nessun altro batte su ENTRAMBI. Quelli sono
%     scelte difendibili, e la scelta fra loro e' politica - quanto la
%     comunita' voglia pagare in stabilita' per avere uniformita'. Tutti gli
%     altri sono dominati: c'e' un metodo che li batte su un criterio senza
%     perdere sull'altro, e sceglierli e' difficile da argomentare. E' questa
%     la distinzione che la figura serve a rendere visibile.
%
%   COME SI LEGGE L'ASSE ORIZZONTALE
%     L'eccesso massimo e' quanto guadagnerebbe in piu', uscendo dalla CER, il
%     sottogruppo piu' scontento. NEGATIVO vuol dire che nessuno ci guadagna:
%     l'allocazione sta nel Core e la coalizione regge. La linea verticale a
%     zero e' quindi la soglia che conta, e a sinistra di essa si sta al
%     sicuro. Attenzione: piu' a sinistra e' meglio, quindi su questo asse
%     l'ordine "buono" e' rovesciato rispetto all'abitudine.
%
%   INPUT
%     Tfair   table   uscita della sezione indici di equita' di MAIN.m, con
%                     almeno le colonne Metodo, EI_orig, Gini,
%                     EccessoMax_EUR, CoalizioniInstabili
%     vGrand  scalare v(N), per esprimere l'eccesso anche in percentuale [EUR]
%     titolo  string  titolo del grafico

    nomi   = string(Tfair.Metodo);
    x      = Tfair.EccessoMax_EUR;
    y      = Tfair.EI_orig;
    nInst  = Tfair.CoalizioniInstabili;
    nM     = numel(nomi);

    % --- Frontiera di Pareto: minimizzare x, massimizzare y ------------------
    % Un metodo e' dominato se ne esiste un altro con eccesso non maggiore ED
    % equita' non minore, con almeno una delle due strettamente migliore.
    dominato = false(nM, 1);
    for i = 1:nM
        dominato(i) = any((x <= x(i) + eps) & (y >= y(i) - eps) & ...
                          ((x < x(i) - eps) | (y > y(i) + eps)));
    end
    efficiente = ~dominato;

    figure('Name', 'Trade-off uniformita vs stabilita', 'Color', 'w', ...
           'Position', [110 100 1200 780]);
    ax = axes; hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    % --- Limiti degli assi, con il margine per le etichette -----------------
    % Il margine a destra e' generoso perche' li' ci vanno i nomi dei metodi:
    % senza, quelli dei punti piu' a destra escono dalla figura. I punti che
    % cadono nell'ultimo quarto vengono comunque etichettati a SINISTRA.
    yl = [min(y) - 0.10*range_o(y), max(y) + 0.14*range_o(y)];
    xl = [min(x) - 0.14*range_o(x), max(x) + 0.30*range_o(x)];
    xlim(ax, xl); ylim(ax, yl);

    % Fondo verde tenue sulla meta' stabile: e' l'unica informazione della
    % figura che va colta senza leggere nulla.
    if xl(1) < 0
        patch(ax, 'XData', [xl(1) 0 0 xl(1)], 'YData', [yl(1) yl(1) yl(2) yl(2)], ...
              'FaceColor', [0.20 0.60 0.30], 'FaceAlpha', 0.07, 'EdgeColor', 'none', ...
              'HandleVisibility', 'off');
    end

    % --- Soglia di stabilita' -------------------------------------------------
    % L'etichetta va in orizzontale e in alto: verticale attraversava il
    % grafico e si sovrapponeva ai nomi dei metodi. HandleVisibility off
    % perche' altrimenti la linea finisce in legenda come "data1".
    xline(ax, 0, '-', 'soglia di stabilita'' (Core)', 'Color', [0.35 0.35 0.35], ...
          'LineWidth', 1.4, 'LabelOrientation', 'horizontal', ...
          'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'right', ...
          'FontSize', 9, 'HandleVisibility', 'off');

    % --- Frontiera: spezzata che unisce i non dominati -----------------------
    [xf, ord] = sort(x(efficiente));
    yf        = y(efficiente);
    yf        = yf(ord);
    hFront = plot(ax, xf, yf, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.3);

    % --- I metodi ------------------------------------------------------------
    % Area del marcatore proporzionale al numero di coalizioni instabili: dice
    % se l'eccesso massimo e' un caso isolato o la punta di molti malcontenti.
    dim = 90 + 260 * nInst / max(1, max(nInst));

    for k = 1:nM
        c = method_color(nomi(k));
        if efficiente(k)
            bordo = [0.10 0.10 0.10]; spess = 1.8;
        else
            bordo = [0.60 0.60 0.60]; spess = 0.6;
        end
        scatter(ax, x(k), y(k), dim(k), c, 'filled', 'MarkerEdgeColor', bordo, ...
                'LineWidth', spess, 'MarkerFaceAlpha', 0.85, 'HandleVisibility', 'off');
    end

    % --- Etichette, distanziate e collegate al proprio punto -----------------
    colori = zeros(nM, 3);
    for k = 1:nM
        colori(k, :) = method_color(nomi(k)) * 0.70;   % scurito, per leggerlo
    end
    lato = repmat("destra", nM, 1);
    lato(x > xl(1) + 0.72 * (xl(2) - xl(1))) = "sinistra";

    spread_labels(ax, x, y, nomi, struct( ...
        'lato', lato, 'grassetto', efficiente, 'colore', colori, ...
        'dyMin', 0.033 * range_o(y)));

    xlabel(ax, sprintf(['Eccesso massimo di coalizione [EUR]        ' ...
                        '<- piu'' stabile        (v(N) = %.0f EUR)'], vGrand));
    ylabel(ax, 'EI originale = 1 - Gini dei risparmi        piu'' uniforme ->');
    title(ax, titolo, 'Interpreter', 'none');
    subtitle(ax, ['bordo nero e nome in grassetto = non dominato  |  ' ...
                  'area del punto \propto numero di coalizioni instabili']);
    legend(ax, hFront, {'Frontiera di Pareto'}, 'Location', 'southeast', 'Box', 'off');
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function r = range_o(v)
%RANGE_O  Escursione di un vettore, mai nulla: con tutti i valori uguali una
%   escursione zero manderebbe a NaN ogni margine calcolato su di essa.
    r = max(v) - min(v);
    if ~isfinite(r) || r == 0
        r = max(1, abs(max(v)));
    end
end
