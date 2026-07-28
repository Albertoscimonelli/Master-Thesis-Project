function plot_benefit_network(players, phi, method, pvOwner, extraRevenue)
%PLOT_BENEFIT_NETWORK  Diagramma radiale dei benefici CER attorno alla
%   cabina primaria.
%
%   La cabina primaria e' il punto di scambio centrale. Ogni giocatore e'
%   disegnato come un cerchio su una circonferenza attorno al centro: il
%   raggio del cerchio e' proporzionale al beneficio ricevuto (area, non
%   raggio lineare, per non esagerare visivamente le differenze). Le
%   frecce vanno tutte dalla cabina VERSO ciascun giocatore.
%
%   Il produttore PV e il suo proprietario (pvOwner) vengono uniti in un
%   solo cerchio (vedi merge_pv_owner.m). Se quel cerchio riceve anche
%   ricavi dalla vendita diretta dell'eccedenza sul mercato (extraRevenue),
%   viene diviso in due spicchi colorati: quota CER (ripartizione dei
%   benefici del gioco cooperativo) e vendita mercato.
%
%   INPUT
%     players      [1 x n] string   nomi dei giocatori (players(1) = "PV")
%     phi          [n x 1] double   beneficio annuo per giocatore [EUR]
%     method       string           "Shapley" o "Nucleolo" (titolo + colore quota CER)
%     pvOwner      string           (opzionale) proprietario dell'impianto PV,
%                                    per fondere il nodo "PV" col suo nodo
%     extraRevenue scalare          (opzionale) ricavo annuo da vendita diretta
%                                    dell'eccedenza sul mercato, attribuito
%                                    interamente al nodo fuso (0 se assente)

    if nargin < 4, pvOwner      = "";  end
    if nargin < 5, extraRevenue = 0;   end

    [players, phi, mergedIdx] = merge_pv_owner(players, phi, pvOwner);
    n = numel(players);

    % --- Beneficio totale per giocatore (usato per il raggio dei cerchi) ----
    phiTotal = phi;
    if ~isempty(mergedIdx)
        phiTotal(mergedIdx) = phi(mergedIdx) + extraRevenue;
    else
        extraRevenue = 0;   % nessun nodo a cui attribuirlo: non disegnare spicchi
    end

    % --- Layout: giocatori su una circonferenza attorno alla cabina ---------
    R     = 10;                                    % raggio di disposizione
    theta = linspace(0, 2*pi, n+1).'; theta(end) = [];
    theta = theta + pi/2;                           % nodo fuso in cima (leggibilita')
    posX  = R * cos(theta);
    posY  = R * sin(theta);

    % --- Raggio dei cerchi: area proporzionale al beneficio totale ----------
    rMin = 0.6; rMax = 2.6;
    phiPos = max(phiTotal, 0);
    if max(phiPos) > 0
        nodeR = rMin + (rMax - rMin) * sqrt(phiPos / max(phiPos));
    else
        nodeR = rMin * ones(n, 1);
    end

    % --- Colori: quota CER (coerente col metodo, vedi method_color.m),
    %     arancio = vendita mercato -----------------------------------------
    colCER    = method_color(method);
    colMarket = [0.90 0.45 0.15];     % arancio - vendita energia eccedente
    colCenter = [0.30 0.30 0.28];
    colArrow  = [0.55 0.55 0.52];

    figure('Name', sprintf('Rete benefici CER - %s', method), 'Color', 'w', ...
           'Position', [150 100 900 850]);
    axes; hold on; axis equal; axis off;

    % --- Frecce dalla cabina verso ogni giocatore (disegnate sotto i cerchi) -
    for i = 1:n
        p = [posX(i) posY(i)];
        u = p / norm(p);              % versore centro -> nodo

        startPt = u * 1.0;             % dal centro...
        endPt   = p - u * nodeR(i);    % ...fino al bordo del cerchio
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
        if i == mergedIdx && extraRevenue > 0
            shareCER = phi(i) / phiTotal(i);
            aSplit   = pi/2 + 2*pi*shareCER;
            drawWedge(posX(i), posY(i), nodeR(i), pi/2, aSplit,     colCER);
            drawWedge(posX(i), posY(i), nodeR(i), aSplit, pi/2+2*pi, colMarket);
        else
            drawCircle(posX(i), posY(i), nodeR(i), colCER);
        end
        label = strrep(players(i), '_', '\_');
        text(posX(i), posY(i) - nodeR(i) - 0.6, ...
             sprintf('%s\n€%.0f', label, phiTotal(i)), ...
             'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    lim = R + rMax + 2;
    xlim([-lim lim]); ylim([-lim lim]);
    title(sprintf('Distribuzione dei benefici CER (%s)  |  area \\propto beneficio', method));

    legEntries = {sprintf('Quota CER (%s)', method)};
    legHandles = scatter(nan, nan, 80, colCER, 'filled');
    if extraRevenue > 0
        legHandles(end+1) = scatter(nan, nan, 80, colMarket, 'filled');
        legEntries{end+1}  = 'Vendita energia eccedente (mercato)';
    end
    legend(legHandles, legEntries, 'Location', 'southoutside', 'Box', 'off');
end


function drawCircle(cx, cy, r, faceColor)
%DRAWCIRCLE  Cerchio riempito (senza dipendenze da toolbox aggiuntivi).
    t = linspace(0, 2*pi, 60);
    fill(cx + r*cos(t), cy + r*sin(t), faceColor, ...
         'FaceAlpha', 0.55, 'EdgeColor', faceColor * 0.7, 'LineWidth', 1.5);
end


function drawWedge(cx, cy, r, a0, a1, faceColor)
%DRAWWEDGE  Spicchio di cerchio da a0 a a1 (radianti), riempito.
    t  = linspace(a0, a1, 40);
    xs = [cx, cx + r*cos(t), cx];
    ys = [cy, cy + r*sin(t), cy];
    fill(xs, ys, faceColor, 'FaceAlpha', 0.55, 'EdgeColor', faceColor * 0.7, 'LineWidth', 1.5);
end
