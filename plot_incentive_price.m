function plot_incentive_price(tGrid, Pz_h, P_CER_h, shared, meseNomi)
%PLOT_INCENTIVE_PRICE  La tariffa incentivante oraria TIP_h: da dove viene, e
%   se la CER condivide nelle ore in cui vale di piu'.
%
%   PERCHE' QUESTA FIGURA ESISTE
%     Il progetto ha fatto una scelta di modello esplicita: l'incentivo
%     sull'energia condivisa non e' una costante ma un VETTORE ORARIO,
%     calcolato dal prezzo zonale del mercato del giorno prima (eq. 3.1). E'
%     una scelta che si paga in complessita' e va giustificata, ma finora la si
%     vedeva solo come media, minimo e massimo stampati a schermo. Se la TIP
%     oraria fosse quasi piatta, o se le ore di condivisione cadessero a caso
%     rispetto ad essa, tanto varrebbe un incentivo costante.
%
%   IL NUMERO CHE DECIDE: MEDIA SEMPLICE CONTRO MEDIA INCASSATA
%     mean(TIP_h) e' quanto vale un'ora qualunque dell'anno. La media PESATA
%     sull'energia condivisa - sum(shared*TIP)/sum(shared) - e' quanto la CER
%     ha incassato davvero per kWh. Se la seconda supera la prima, la comunita'
%     condivide nelle ore in cui l'incentivo e' alto, e la differenza fra le
%     due e' un risultato: misura quanto la coincidenza fra sole e consumi
%     valga in euro, al di la' dei kWh.
%
%   IL PANNELLO DELLA CURVA DI TRASFERIMENTO
%     L'eq. 3.1 e' una spezzata: TIP cresce al calare del prezzo zonale, ma si
%     ferma a un tetto (CAP) e a un pavimento (TP_base + FC). Disegnare le 8760
%     ore sulla curva mostra in quale tratto e' caduto l'anno. Se stanno quasi
%     tutte sul tratto piatto, la TIP e' di fatto costante e il modello orario
%     non sta aggiungendo nulla - ed e' un'informazione che conviene vedere
%     prima di costruirci sopra le conclusioni.
%
%   UNITA': attenzione, i due ingressi non hanno la stessa unita'.
%     Pz_h arriva in EUR/MWh (e' il prezzo di mercato), P_CER_h in EUR/kWh
%     (e' gia' pronto per moltiplicare i kWh). Qui si porta tutto a EUR/MWh
%     per poterli mettere sullo stesso asse.
%
%   INPUT
%     tGrid     [H x 1]  datetime  griglia oraria canonica
%     Pz_h      [H x 1]  prezzo zonale orario MGP           [EUR/MWh]
%     P_CER_h   [H x 1]  tariffa incentivante oraria TIP_h  [EUR/kWh]
%     shared    [H x 1]  energia condivisa oraria           [kWh/h]
%     meseNomi  [12 x 1] string    nomi dei mesi

    Pz_h    = Pz_h(:);
    TIP_MWh = P_CER_h(:) * 1000;      % EUR/kWh -> EUR/MWh, per l'asse comune
    shared  = shared(:);

    oraDelGiorno = hour(tGrid);
    meseDellOra  = month(tGrid);

    % --- Le due medie che danno il titolo -----------------------------------
    tipMedia = mean(TIP_MWh);
    if sum(shared) > 0
        tipIncassata = sum(shared .* TIP_MWh) / sum(shared);
    else
        tipIncassata = NaN;
    end

    colPz   = [0.35 0.35 0.40];
    colTIP  = [0.75 0.25 0.55];
    colCond = [0.20 0.60 0.30];

    figure('Name', 'Tariffa incentivante TIP_h e prezzo zonale', 'Color', 'w', ...
           'Position', [100 90 1250 830]);
    tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf(['Tariffa incentivante oraria  |  TIP media = %.2f EUR/MWh  |  ' ...
                       'TIP effettivamente incassata = %.2f EUR/MWh  (%+.2f)'], ...
                      tipMedia, tipIncassata, tipIncassata - tipMedia), ...
          'FontWeight', 'bold');

    % --- (a) Giorno medio: prezzo, tariffa, energia condivisa ---------------
    ax1 = nexttile; hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    PzOra   = accumarray(oraDelGiorno + 1, Pz_h,    [24 1], @mean);
    tipOra  = accumarray(oraDelGiorno + 1, TIP_MWh, [24 1], @mean);
    condOra = accumarray(oraDelGiorno + 1, shared,  [24 1], @mean);

    yyaxis(ax1, 'right');
    hCond = bar(ax1, 0:23, condOra, 0.75, 'FaceColor', colCond, 'FaceAlpha', 0.30, ...
                'EdgeColor', 'none');
    ylabel(ax1, 'Energia condivisa media [kWh/h]');
    set(ax1, 'YColor', colCond * 0.8);

    yyaxis(ax1, 'left');
    hPz  = plot(ax1, 0:23, PzOra,  '-o', 'Color', colPz,  'LineWidth', 1.8, 'MarkerSize', 4);
    hTIP = plot(ax1, 0:23, tipOra, '-s', 'Color', colTIP, 'LineWidth', 2.0, 'MarkerSize', 5);
    ylabel(ax1, 'Prezzo / tariffa [EUR/MWh]');
    set(ax1, 'YColor', [0.15 0.15 0.15]);

    xlim(ax1, [-0.5 23.5]); xticks(ax1, 0:3:23);
    xlabel(ax1, 'Ora del giorno');
    legend(ax1, [hPz hTIP hCond], {'Prezzo zonale', 'TIP_h', 'Energia condivisa'}, ...
           'Location', 'north', 'Orientation', 'horizontal', 'Box', 'off');
    title(ax1, 'Giorno medio dell''anno');

    % --- (b) Curva di trasferimento dell'eq. 3.1 ----------------------------
    ax2 = nexttile; hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');

    % Le ore SENZA condivisione sono grigie e sullo sfondo: ci sono, ma non
    % contribuiscono al ricavo. Quelle CON condivisione sono verdi e in primo
    % piano, dimensionate sull'energia: si vede subito su quale tratto della
    % spezzata cade l'energia che conta davvero.
    haCond = shared > 0;
    scatter(ax2, Pz_h(~haCond), TIP_MWh(~haCond), 6, [0.80 0.80 0.78], 'filled', ...
            'MarkerFaceAlpha', 0.35, 'DisplayName', 'Ore senza condivisione');
    if any(haCond)
        dim = 6 + 44 * shared(haCond) / max(shared(haCond));
        scatter(ax2, Pz_h(haCond), TIP_MWh(haCond), dim, colCond, 'filled', ...
                'MarkerFaceAlpha', 0.35, 'DisplayName', 'Ore con condivisione (area \propto kWh)');
    end

    xlabel(ax2, 'Prezzo zonale MGP [EUR/MWh]');
    ylabel(ax2, 'TIP_h [EUR/MWh]');
    legend(ax2, 'Location', 'northeast', 'Box', 'off');
    title(ax2, 'Come il prezzo zonale genera la tariffa (eq. 3.1)');

    % --- (c) Mese per mese: tariffa media contro tariffa incassata -----------
    ax3 = nexttile([1 2]); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');

    tipMese  = accumarray(meseDellOra, TIP_MWh, [12 1], @mean);
    condMese = accumarray(meseDellOra, shared,  [12 1]);
    ricMese  = accumarray(meseDellOra, shared .* TIP_MWh, [12 1]);
    tipInc   = nan(12, 1);
    ok       = condMese > 0;
    tipInc(ok) = ricMese(ok) ./ condMese(ok);

    yyaxis(ax3, 'right');
    hBar = bar(ax3, 1:12, condMese, 0.6, 'FaceColor', colCond, 'FaceAlpha', 0.25, ...
               'EdgeColor', 'none');
    ylabel(ax3, 'Energia condivisa [kWh]');
    set(ax3, 'YColor', colCond * 0.8);

    yyaxis(ax3, 'left');
    hMed = plot(ax3, 1:12, tipMese, '-o', 'Color', colTIP, 'LineWidth', 1.8, ...
                'MarkerSize', 5);
    hInc = plot(ax3, 1:12, tipInc, '-s', 'Color', [0.85 0.35 0.25], 'LineWidth', 2.0, ...
                'MarkerSize', 6, 'MarkerFaceColor', [0.85 0.35 0.25]);
    ylabel(ax3, 'TIP [EUR/MWh]');
    set(ax3, 'YColor', [0.15 0.15 0.15]);

    xlim(ax3, [0.4 12.6]); xticks(ax3, 1:12); xticklabels(ax3, meseNomi);
    xtickangle(ax3, 45);
    legend(ax3, [hMed hInc hBar], ...
           {'TIP media del mese (tutte le ore)', ...
            'TIP incassata (pesata sull''energia condivisa)', ...
            'Energia condivisa'}, ...
           'Location', 'best', 'Box', 'off');
    title(ax3, ['Mese per mese: la tariffa media dell''ora qualunque contro quella ' ...
                'delle ore che contano']);
end
