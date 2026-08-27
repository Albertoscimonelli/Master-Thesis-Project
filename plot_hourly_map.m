function plot_hourly_map(shared_24xN, sold_24xN, stato_24xN, contendibleShare, anno)
%PLOT_HOURLY_MAP  Mappa oraria dell'anno: quando la CER condivide, quando
%   vende, e quando la chiave di ripartizione non conta nulla.
%
%   PERCHE' SERVE UNA MAPPA E NON UN'ALTRA CURVA
%     Gli altri grafici energetici del progetto guardano l'anno da lontano:
%     plot_cer_energy aggrega per mese, plot_pv_vs_demand fa la media di ogni
%     giornata. Tutte e due nascondono l'ora, che e' proprio la variabile su
%     cui la CER funziona - l'energia si condivide solo nell'ora in cui viene
%     prodotta. Una matrice 24 x 365 disegnata come immagine tiene l'ora
%     sull'asse verticale e il giorno su quello orizzontale: la stagionalita'
%     si legge in orizzontale, la finestra solare in verticale, e le due cose
%     restano distinte invece di essere mediate l'una nell'altra.
%
%   IL TERZO PANNELLO E' IL PUNTO DELLA FIGURA
%     Nelle ore SATURE - quelle in cui l'immissione copre l'intero carico
%     residuo della comunita' - ogni membro riceve esattamente il proprio
%     consumo e NESSUNA chiave di ripartizione puo' cambiarlo. Solo l'energia
%     delle ore restanti e' contendibile fra i sedici modelli. E' la premessa
%     per leggere la tabella degli indici di equita': se la frazione
%     contendibile e' bassa, gli indicatori energetici descrivono la comunita'
%     e non il metodo, ed e' normale che vengano quasi identici fra i sedici.
%     Quel numero il progetto lo stampa gia'; qui si vede DOVE cade nell'anno.
%
%   INPUT
%     shared_24xN       [24 x nDays]  energia condivisa oraria        [kWh/h]
%     sold_24xN         [24 x nDays]  energia venduta in rete         [kWh/h]
%     stato_24xN        [24 x nDays]  codice di stato dell'ora:
%                                       0 = nessuna condivisione
%                                       1 = condivisa contendibile
%                                       2 = condivisa satura (chiave ininfluente)
%     contendibleShare  scalare       frazione di energia contendibile [0-1]
%     anno              scalare       anno di riferimento (tick dei mesi)

    nDays = size(shared_24xN, 2);

    figure('Name', 'Mappa oraria energia CER', 'Color', 'w', ...
           'Position', [80 80 1250 900]);
    tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf(['Mappa oraria dell''anno %d  |  energia contendibile = %.1f%% ' ...
                       'della condivisa'], anno, 100*contendibleShare), ...
          'FontWeight', 'bold');

    % --- (a) e (b): due grandezze in kWh/h, scala di colore continua --------
    % Le due mappe NON condividono la scala: condivisa e venduta hanno ordini
    % di grandezza diversi e una scala comune schiaccerebbe la piu' piccola su
    % una tinta sola. Ciascuna ha percio' la sua colorbar, e il confronto fra
    % le due si fa sulla FORMA (dove cadono le macchie), non sull'intensita'.
    ax1 = nexttile;
    local_map(ax1, shared_24xN, nDays, anno, 'Energia condivisa [kWh/h]', ...
              local_cmap_verde());

    ax2 = nexttile;
    local_map(ax2, sold_24xN, nDays, anno, 'Energia venduta in rete [kWh/h]', ...
              local_cmap_arancio());

    % --- (c) maschera categorica -------------------------------------------
    % Tre stati, tre colori piatti: qui il colore non e' una quantita' ma una
    % categoria, e una scala continua suggerirebbe una gradazione che non
    % esiste. La legenda si costruisce a mano con patch invisibili, perche'
    % imagesc non ne produce una.
    ax3 = nexttile;
    colStato = [0.93 0.93 0.91;    % 0 - nessuna condivisione
                0.20 0.55 0.85;    % 1 - contendibile
                0.85 0.35 0.25];   % 2 - satura, chiave ininfluente

    imagesc(ax3, [1 nDays], [0 23], stato_24xN);
    colormap(ax3, colStato);
    clim(ax3, [-0.5 2.5]);
    local_axes(ax3, nDays, anno);
    title(ax3, sprintf(['Ore: %d senza condivisione, %d contendibili, %d sature ' ...
                        '(chiave ininfluente)'], ...
                       nnz(stato_24xN == 0), nnz(stato_24xN == 1), ...
                       nnz(stato_24xN == 2)));

    hold(ax3, 'on');
    hLeg = gobjects(1, 3);
    for s = 1:3
        hLeg(s) = patch(ax3, 'XData', nan, 'YData', nan, 'FaceColor', colStato(s,:), ...
                        'EdgeColor', 'none');
    end
    legend(ax3, hLeg, {'Nessuna condivisione', 'Condivisa contendibile', ...
                       'Condivisa satura'}, ...
           'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function local_map(ax, Z, nDays, anno, etichetta, cmap)
%LOCAL_MAP  Un pannello 24 x nDays con la sua colorbar.
%   Le ore a zero restano bianche invece di prendere il primo colore della
%   scala: in una mappa dove meta' delle celle e' notte, colorare lo zero
%   riempie la figura di rumore e nasconde il segnale.
    imagesc(ax, [1 nDays], [0 23], Z, 'AlphaData', Z > 0);
    colormap(ax, cmap);
    set(ax, 'Color', 'w');
    cb = colorbar(ax);
    cb.Label.String = etichetta;
    local_axes(ax, nDays, anno);
    title(ax, sprintf('%s  |  totale annuo = %.0f kWh', etichetta, sum(Z(:))));
end


function local_axes(ax, nDays, anno)
%LOCAL_AXES  Assi comuni ai tre pannelli: ore in verticale (0 in alto non
%   avrebbe senso - la giornata scorre verso il basso solo per convenzione
%   grafica, qui si tiene mezzanotte in basso e mezzogiorno al centro), giorni
%   in orizzontale con i tick sul primo di ogni mese invece che ogni 50 giorni.
    % ylim esplicito: imagesc su [0 23] lascerebbe l'ultima ora mezza fuori, e
    % un tick a 24 - un'ora che non esiste - resterebbe invisibile facendo
    % sembrare che la giornata finisca alle 21.
    set(ax, 'YDir', 'normal');
    ylim(ax, [-0.5 23.5]);
    yticks(ax, 0:3:21);
    ylabel(ax, 'Ora del giorno');

    primiDelMese = day(datetime(anno, 1:12, 1), 'dayofyear');
    xticks(ax, primiDelMese);
    xticklabels(ax, ["G" "F" "M" "A" "M" "G" "L" "A" "S" "O" "N" "D"]);
    xlim(ax, [1 nDays]);
    xlabel(ax, 'Giorno dell''anno');
    set(ax, 'TickLength', [0 0]);
    box(ax, 'on');
end


function cmap = local_cmap_verde()
%LOCAL_CMAP_VERDE  Scala sequenziale chiara -> verde scuro, coerente con il
%   verde che plot_cer_energy e plot_pv_vs_demand gia' usano per la condivisa.
    t = linspace(0, 1, 128).';
    cmap = [0.93 0.96 0.92] + t .* ([0.05 0.32 0.16] - [0.93 0.96 0.92]);
end


function cmap = local_cmap_arancio()
%LOCAL_CMAP_ARANCIO  Scala sequenziale chiara -> arancio scuro, coerente con
%   l'arancio della vendita in plot_benefit_network e plot_allocation_comparison.
    t = linspace(0, 1, 128).';
    cmap = [0.99 0.95 0.89] + t .* ([0.60 0.26 0.04] - [0.99 0.95 0.89]);
end
