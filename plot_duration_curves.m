function plot_duration_curves(genSurplus, loadResiduo, shared, sold)
%PLOT_DURATION_CURVES  Curve di durata di immissione, carico residuo, energia
%   condivisa e venduta: quante ore l'anno ciascuna grandezza sta sopra un
%   certo livello.
%
%   COSA DICE UNA CURVA DI DURATA CHE UN PROFILO NON DICE
%     Un profilo orario risponde a "quando"; una curva di durata risponde a
%     "per quante ore". Ordinando ogni grandezza in senso decrescente si perde
%     il tempo e si guadagna la statistica: l'area sotto la curva resta
%     l'energia annua, ma la forma dice se quell'energia arriva concentrata in
%     poche ore di punta o distribuita su tutto l'anno. E' la lettura giusta
%     per una domanda di dimensionamento.
%
%   IL PUNTO DI INCROCIO E' IL RISULTATO
%     Le due curve di immissione e carico residuo si incrociano nell'ora in cui
%     l'una supera l'altra. A sinistra di quel punto l'immissione eccede il
%     carico: il surplus viene VENDUTO in rete al prezzo di mercato, e non
%     matura incentivo. A destra viene condiviso per intero. Quante ore stanno
%     a sinistra, e quanta energia ci cade dentro, e' esattamente la misura di
%     quanto l'impianto sia sovradimensionato rispetto alla comunita' che deve
%     servire - la terza domanda a cui il progetto risponde.
%
%   PERCHE' LE CURVE NON SI SOMMANO PIU'
%     Ogni grandezza e' ordinata per conto proprio, quindi l'ora k della curva
%     dell'immissione NON e' la stessa ora k della curva del carico. Le curve
%     si possono confrontare come distribuzioni, non leggere come un bilancio
%     ora per ora: per quello c'e' plot_hourly_map. Le aree restano pero'
%     esatte, perche' l'ordinamento non cambia la somma.
%
%   INPUT
%     genSurplus   [H x 1]  eccedenza PV disponibile per la CER    [kWh/h]
%     loadResiduo  [H x 1]  carico residuo della comunita'         [kWh/h]
%     shared       [H x 1]  energia condivisa = min(gen, load)     [kWh/h]
%     sold         [H x 1]  energia venduta  = max(0, gen - load)  [kWh/h]

    genSurplus  = genSurplus(:);
    loadResiduo = loadResiduo(:);
    shared      = shared(:);
    sold        = sold(:);

    H  = numel(genSurplus);
    hh = (1:H).';

    genOrd    = sort(genSurplus,  'descend');
    loadOrd   = sort(loadResiduo, 'descend');
    sharedOrd = sort(shared,      'descend');
    soldOrd   = sort(sold,        'descend');

    % --- Le due grandezze che riassumono la figura --------------------------
    oreEccedenza = sum(genSurplus > loadResiduo & genSurplus > 0);
    eTot         = sum(shared) + sum(sold);
    if eTot > 0
        quotaVenduta = sum(sold) / eTot;
    else
        quotaVenduta = 0;
    end

    figure('Name', 'Curve di durata CER', 'Color', 'w', ...
           'Position', [120 120 1150 760]);
    tl = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf(['Curve di durata  |  %d ore/anno con immissione oltre il carico  |  ' ...
                       '%.1f%% dell''immissione finisce venduta'], ...
                      oreEccedenza, 100*quotaVenduta), 'FontWeight', 'bold');

    % --- (a) Immissione contro carico residuo -------------------------------
    ax1 = nexttile; hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    plot(ax1, hh, genOrd,  'Color', [0.90 0.60 0.00], 'LineWidth', 1.8, ...
         'DisplayName', 'Immissione PV disponibile');
    plot(ax1, hh, loadOrd, 'Color', [0.10 0.30 0.70], 'LineWidth', 1.8, ...
         'DisplayName', 'Carico residuo comunita');

    % La soglia in cui la curva ordinata dell'immissione scende sotto quella
    % del carico: sopra di li' c'e' piu' produzione che consumo da servire.
    kCross = find(genOrd <= loadOrd, 1, 'first');
    if ~isempty(kCross) && kCross > 1
        xline(ax1, kCross, '--', sprintf('%d ore', kCross), ...
              'Color', [0.45 0.45 0.45], 'LabelVerticalAlignment', 'top', ...
              'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
    end

    xlim(ax1, [1 H]);
    xlabel(ax1, 'Ore dell''anno, ordinate per valore decrescente');
    ylabel(ax1, 'Potenza [kW]');
    legend(ax1, 'Location', 'northeast');
    title(ax1, 'Immissione disponibile e carico residuo (ciascuno ordinato per se)');

    % --- (b) Come si divide l'immissione ------------------------------------
    % Le due aree partono entrambe da zero e si sovrappongono: si disegna
    % prima la piu' ALTA, altrimenti copre l'altra e ne resta visibile solo il
    % bordo. Quale sia la piu' alta dipende dalla comunita', quindi si decide
    % qui invece di fissare un ordine che regge solo su questi dati.
    hSh = struct('y', sharedOrd, 'col', [0.20 0.60 0.30], 'bordo', [0.12 0.42 0.20], ...
                 'nome', sprintf('Condivisa - incentivata (%.0f kWh)', sum(shared)));
    hSo = struct('y', soldOrd,   'col', [0.90 0.45 0.15], 'bordo', [0.70 0.32 0.08], ...
                 'nome', sprintf('Venduta - non incentivata (%.0f kWh)', sum(sold)));
    if max(soldOrd) >= max(sharedOrd)
        strati = [hSo, hSh];
    else
        strati = [hSh, hSo];
    end

    ax2 = nexttile; hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    for s = 1:2
        area(ax2, hh, strati(s).y, 'FaceColor', strati(s).col, 'FaceAlpha', 0.45, ...
             'EdgeColor', strati(s).bordo, 'LineWidth', 1.2, ...
             'DisplayName', strati(s).nome);
    end

    % Oltre l'ultima ora con condivisione la curva e' piatta a zero e occupa
    % meta' figura senza dire nulla: si taglia l'asse poco dopo.
    kUltima = find(sharedOrd > 0, 1, 'last');
    if isempty(kUltima), kUltima = H; end
    xlim(ax2, [1 min(H, round(kUltima * 1.15))]);

    xlabel(ax2, 'Ore dell''anno, ordinate per valore decrescente');
    ylabel(ax2, 'Potenza [kW]');
    legend(ax2, 'Location', 'northeast');
    title(ax2, 'Destinazione dell''immissione: quanta matura incentivo e quanta no');
end
