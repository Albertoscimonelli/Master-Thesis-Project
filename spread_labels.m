function spread_labels(ax, x, y, etichette, opts)
%SPREAD_LABELS  Etichette di testo accanto a dei punti, distanziate in
%   verticale quando si sovrappongono, con una linea di richiamo al punto.
%
%   PERCHE' SERVE
%     Sedici metodi su un piano si accalcano quasi sempre: diversi indicatori
%     di equita' variano pochissimo fra loro, e proprio dove i punti si
%     ammassano serve di piu' poterli distinguere. Spostare le etichette in
%     verticale risolve la sovrapposizione ma ne crea un'altra: un'etichetta
%     lontana dal suo punto non si sa piu' a chi appartenga. La linea di
%     richiamo chiude il cerchio - si sposta il testo E si dice da dove viene.
%
%   L'ORDINE VERTICALE NON CAMBIA
%     Le etichette vengono distanziate rispettando l'ordine originale delle y:
%     se un metodo sta sopra un altro nel grafico, la sua etichetta resta
%     sopra. Riordinarle per far stare tutto renderebbe la figura piu' pulita
%     e piu' bugiarda.
%
%   INPUT
%     ax         handle degli assi
%     x, y       [n x 1]  coordinate dei punti, in unita' dei dati
%     etichette  [n x 1]  string, il testo di ciascun punto
%     opts       struct (opzionale)
%                  .lato       "destra" (def.) | "sinistra" | [n x 1] string
%                              per decidere punto per punto
%                  .dx         distacco orizzontale, in unita' dei dati
%                              (def. 1.5% dell'escursione di x)
%                  .dyMin      distanza verticale minima fra due etichette
%                              (def. 3.5% dell'escursione di y)
%                  .fontSize   (def. 8.5)
%                  .grassetto  [n x 1] logico, quali scrivere in grassetto
%                  .colore     [n x 3] colore di ciascuna etichetta
%                              (def. grigio scuro per tutte)

    if nargin < 5 || isempty(opts), opts = struct(); end

    x = x(:); y = y(:);
    etichette = string(etichette(:));
    n = numel(x);

    xr = local_range(xlim(ax));
    yr = local_range(ylim(ax));

    if ~isfield(opts, 'dx'),       opts.dx       = 0.015 * xr;            end
    if ~isfield(opts, 'dyMin'),    opts.dyMin    = 0.035 * yr;            end
    if ~isfield(opts, 'fontSize'), opts.fontSize = 8.5;                   end
    if ~isfield(opts, 'grassetto'),opts.grassetto = false(n, 1);          end
    if ~isfield(opts, 'colore'),   opts.colore   = repmat([0.20 0.20 0.20], n, 1); end
    if ~isfield(opts, 'lato'),     opts.lato     = "destra";              end

    lato = string(opts.lato);
    if isscalar(lato), lato = repmat(lato, n, 1); end

    yLab = local_spread(y, opts.dyMin);

    hold(ax, 'on');
    for k = 1:n
        if lato(k) == "sinistra"
            xLab  = x(k) - opts.dx;
            allin = 'right';
        else
            xLab  = x(k) + opts.dx;
            allin = 'left';
        end

        % La linea di richiamo si disegna SOLO se l'etichetta e' stata
        % davvero spostata: su un punto isolato sarebbe un trattino inutile
        % che sporca la figura.
        if abs(yLab(k) - y(k)) > 0.25 * opts.dyMin
            plot(ax, [x(k), xLab], [y(k), yLab(k)], '-', ...
                 'Color', [opts.colore(k,:) 0.55], 'LineWidth', 0.6, ...
                 'HandleVisibility', 'off');
        end

        if opts.grassetto(k), peso = 'bold'; else, peso = 'normal'; end
        text(ax, xLab, yLab(k), etichette(k), 'FontSize', opts.fontSize, ...
             'FontWeight', peso, 'Color', opts.colore(k,:), ...
             'HorizontalAlignment', allin, 'VerticalAlignment', 'middle', ...
             'Interpreter', 'none');
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function r = local_range(v)
%LOCAL_RANGE  Escursione mai nulla: con estremi coincidenti ogni margine
%   calcolato su di essa andrebbe a zero o a NaN.
    r = max(v) - min(v);
    if ~isfinite(r) || r == 0
        r = max(1, abs(max(v)));
    end
end


function yOut = local_spread(y, dMin)
%LOCAL_SPREAD  Allontana in verticale le etichette piu' vicine di dMin,
%   lasciandole nell'ordine originale.
%
%   Due passate, non una: spingendo solo verso l'alto tutto il gruppo si
%   sposta in su e l'ultima etichetta esce dal grafico. La seconda passata
%   ridiscende comprimendo verso il basso, e il risultato resta centrato
%   sul gruppo di punti da cui e' partito.
    n         = numel(y);
    [ys, ord] = sort(y);

    for i = 2:n
        if ys(i) - ys(i-1) < dMin
            ys(i) = ys(i-1) + dMin;
        end
    end

    scarto = mean(ys) - mean(y);      % di quanto la prima passata ha alzato
    ys     = ys - scarto;             % ...e si rimette il gruppo al suo posto

    yOut      = zeros(n, 1);
    yOut(ord) = ys;
end
