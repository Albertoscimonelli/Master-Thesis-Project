function plot_benefit_network(players, phi, method)
%PLOT_BENEFIT_NETWORK  Diagramma radiale dei benefici CER attorno alla
%   cabina primaria.
%
%   La cabina primaria e' il punto di scambio centrale. Ogni giocatore e'
%   disegnato come un cerchio su una circonferenza attorno al centro: il
%   raggio del cerchio e' proporzionale al beneficio ricevuto (area, non
%   raggio lineare, per non esagerare visivamente le differenze). Le
%   frecce indicano il verso del flusso di energia rispetto alla cabina:
%     - produttore PV  -> freccia dal giocatore VERSO il centro
%       (immette l'eccedenza nella rete di comunita')
%     - consumatori    -> freccia dal centro VERSO il giocatore
%       (ricevono energia condivisa dalla cabina)
%
%   INPUT
%     players  [1 x n] string   nomi dei giocatori (players(1) = "PV",
%                                per convenzione di shapley_cer/nucleolus_cer)
%     phi      [n x 1] double   beneficio annuo per giocatore [EUR]
%     method   string           "Shapley" o "Nucleolo" (solo per titolo/nome figura)

    n   = numel(players);
    phi = phi(:);

    % --- Layout: giocatori su una circonferenza attorno alla cabina ---------
    R     = 10;                                    % raggio di disposizione
    theta = linspace(0, 2*pi, n+1).'; theta(end) = [];
    theta = theta + pi/2;                           % PV in cima (leggibilita')
    posX  = R * cos(theta);
    posY  = R * sin(theta);

    % --- Raggio dei cerchi: area proporzionale al beneficio -----------------
    rMin = 0.6; rMax = 2.6;
    phiPos = max(phi, 0);
    if max(phiPos) > 0
        nodeR = rMin + (rMax - rMin) * sqrt(phiPos / max(phiPos));
    else
        nodeR = rMin * ones(n, 1);
    end

    % --- Colori (produttore vs consumatori) ----------------------------------
    colPV     = [0.92 0.41 0.20];   % arancio - produzione
    colCons   = [0.16 0.47 0.84];   % blu - consumo
    colCenter = [0.30 0.30 0.28];
    colArrow  = [0.55 0.55 0.52];

    isPV = (players(:).' == "PV");

    figure('Name', sprintf('Rete benefici CER - %s', method), 'Color', 'w', ...
           'Position', [150 100 900 850]);
    axes; hold on; axis equal; axis off;

    % --- Frecce di flusso energetico (disegnate per prime, sotto i cerchi) --
    for i = 1:n
        p = [posX(i) posY(i)];
        u = p / norm(p);              % versore centro -> nodo

        if isPV(i)
            startPt = p - u * nodeR(i);   % dal bordo del cerchio PV...
            endPt   = u * 1.0;             % ...verso il centro
        else
            startPt = u * 1.0;             % dal centro...
            endPt   = p - u * nodeR(i);    % ...fino al bordo del cerchio
        end
        d = endPt - startPt;
        quiver(startPt(1), startPt(2), d(1), d(2), 'AutoScale', 'off', ...
               'Color', colArrow, 'LineWidth', 1.6, 'MaxHeadSize', 0.35);
    end

    % --- Punto centrale: cabina primaria -------------------------------------
    scatter(0, 0, 260, colCenter, 'filled', 'Marker', 's');
    text(0, -1.7, 'Cabina Primaria', 'HorizontalAlignment', 'center', ...
         'FontWeight', 'bold', 'FontSize', 10);

    % --- Cerchi dei giocatori -------------------------------------------------
    for i = 1:n
        c = colCons; if isPV(i), c = colPV; end
        drawCircle(posX(i), posY(i), nodeR(i), c);
        label = strrep(players(i), '_', '\_');
        text(posX(i), posY(i) - nodeR(i) - 0.6, ...
             sprintf('%s\n€%.0f', label, phi(i)), ...
             'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    lim = R + rMax + 2;
    xlim([-lim lim]); ylim([-lim lim]);
    title(sprintf('Distribuzione dei benefici CER (%s)  |  area \\propto beneficio', method));

    h1 = scatter(nan, nan, 80, colPV,   'filled');
    h2 = scatter(nan, nan, 80, colCons, 'filled');
    legend([h1 h2], {'Produttore PV (flusso verso la cabina)', ...
                      'Consumatore (flusso dalla cabina)'}, ...
           'Location', 'southoutside', 'Box', 'off');
end


function drawCircle(cx, cy, r, faceColor)
%DRAWCIRCLE  Cerchio riempito (senza dipendenze da toolbox aggiuntivi).
    t = linspace(0, 2*pi, 60);
    fill(cx + r*cos(t), cy + r*sin(t), faceColor, ...
         'FaceAlpha', 0.55, 'EdgeColor', faceColor * 0.7, 'LineWidth', 1.5);
end
