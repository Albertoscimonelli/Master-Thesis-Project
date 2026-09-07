function plot_financial_metrics(Tfin, FIN, metodi, nomeRif, incentivoRif)
%PLOT_FINANCIAL_METRICS  Redditivita' dell'investimento per membro: da dove
%   viene il flusso, quanto vale attualizzato, in quanto rientra.
%
%   Tre riquadri, che rispondono a tre domande diverse e nessuno dei tre da'
%   la risposta degli altri:
%
%     1. COMPOSIZIONE DEL FLUSSO. Barre impilate: risparmio da autoconsumo,
%        vendita dell'eccedenza, quota di incentivo, meno OPEX e mutuo. E' il
%        riquadro che spiega perche' il perimetro conta - su un prosumer la
%        quota CER e' la fetta piu' sottile, e valutare l'investimento sulla
%        sola CER darebbe un altro verdetto.
%
%     2. VAN E TEMPO DI RITORNO. Il VAN da solo premia chi e' grande; il
%        payback da solo ignora quanto si guadagna dopo. Insieme dicono se un
%        investimento e' buono E se lo e' presto. La linea orizzontale e' la
%        vita utile: sopra quella, l'investimento non rientra.
%
%     3. IL VAN AL VARIARE DEL METODO. Un punto per metodo, per membro: la
%        dispersione verticale dice quanto la scelta del meccanismo di
%        ripartizione sposti la redditivita' di ciascuno. Se i punti stanno
%        quasi sovrapposti, la §3s sta discutendo di quote e non di
%        convenienza.
%
%   I MEMBRI SENZA INVESTIMENTO NON SONO NASCOSTI
%     Hanno VAN positivo, payback nullo e TIR indefinito, e restano nel
%     grafico marcati come tali: toglierli darebbe l'impressione che la CER
%     convenga solo a chi ha investito, che e' il contrario di quello che
%     dicono i numeri.
%
%   INPUT
%     Tfin     table   la tabella della §3v di MAIN.m (una riga per membro)
%     FIN      struct  uscita di compute_financial_metrics (serve .NPV, che
%                      e' [n x k], e .lifetimeYears)
%     metodi   struct array con campo .nome, per colori ed etichette
%     nomeRif  string  metodo di riferimento, quello delle prime due tavole
%     incentivoRif [n x 1]  quota di incentivo del metodo di riferimento
%                      [EUR/anno]. Passata a parte e non ripescata da Tfin
%                      perche' li' la colonna porta il nome del metodo nel
%                      titolo, e alcuni nomi hanno spazi: indicizzarla
%                      significherebbe ricostruire quel nome, o peggio
%                      contare le colonne.
%
%   Vedi anche: compute_financial_metrics, method_color, save_figures, MAIN

    nomi     = string(Tfin.Giocatore(:)).';
    n        = numel(nomi);
    etichette = strrep(nomi, '_', '\_');
    senzaInv = Tfin.Investimento_E <= 0;

    figure('Name', 'Redditivita per membro (VAN, TIR, payback)', 'Color', 'w', ...
           'Position', [80 80 1250 760]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % --- 1) Da dove viene il flusso annuo ------------------------------------
    nexttile;
    positivi = [Tfin.Risp_autocons_E, Tfin.Vendita_E, incentivoRif(:)];
    negativi = -Tfin.OPEX_mutuo_E;
    hold on; grid on; box on;
    bar(1:n, positivi, 0.6, 'stacked');
    bar(1:n, negativi, 0.6, 'FaceColor', [0.75 0.30 0.30]);
    plot(1:n, Tfin.Flusso_annuo_E, 'k.', 'MarkerSize', 16);
    xticks(1:n); xticklabels(etichette); xtickangle(45);
    ylabel('[€/anno]');
    legend({'Risparmio autoconsumo', 'Vendita eccedenza', ...
            char("Incentivo CER (" + nomeRif + ")"), 'OPEX + mutuo', 'Flusso netto'}, ...
           'Location', 'best');
    title('Composizione del flusso di cassa annuo');

    % --- 2) VAN per membro ---------------------------------------------------
    nexttile;
    hold on; grid on; box on;
    hb = bar(1:n, Tfin.VAN_E, 0.6, 'FaceColor', 'flat');
    for i = 1:n
        if senzaInv(i)
            hb.CData(i,:) = [0.60 0.72 0.85];    % chi non ha investito
        else
            hb.CData(i,:) = method_color(nomeRif);
        end
    end
    yline(0, 'k-');
    xticks(1:n); xticklabels(etichette); xtickangle(45);
    ylabel('VAN [€]');
    title(sprintf('VAN a %d anni (barre chiare: nessun investimento)', ...
                  FIN.lifetimeYears));

    % --- 3) Tempo di ritorno -------------------------------------------------
    % Chi non rientra entro la vita utile ha payback infinito e non si puo'
    % disegnare: si mette una barra alta quanto l'orizzonte e la si marca, cosi'
    % il caso resta visibile invece di sparire dal grafico.
    nexttile;
    pb        = Tfin.Payback_anni;
    fuori     = ~isfinite(pb);
    pbPlot    = pb;
    pbPlot(fuori) = FIN.lifetimeYears;
    hold on; grid on; box on;
    hp = bar(1:n, pbPlot, 0.6, 'FaceColor', 'flat');
    for i = 1:n
        if fuori(i)
            hp.CData(i,:) = [0.75 0.30 0.30];
        elseif senzaInv(i)
            hp.CData(i,:) = [0.60 0.72 0.85];
        else
            hp.CData(i,:) = [0.35 0.60 0.45];
        end
    end
    yline(FIN.lifetimeYears, 'k--', 'vita utile', ...
          'LabelHorizontalAlignment', 'left');
    if any(fuori)
        text(find(fuori), repmat(FIN.lifetimeYears, sum(fuori), 1), ...
             '  non rientra', 'Rotation', 90, 'FontSize', 8);
    end
    xticks(1:n); xticklabels(etichette); xtickangle(45);
    ylabel('Tempo di ritorno [anni]');
    ylim([0, FIN.lifetimeYears * 1.15]);
    title('Tempo di ritorno semplice');

    % --- 4) Quanto sposta la scelta del metodo -------------------------------
    % Si disegna lo SCARTO dal VAN medio del membro, non il VAN. In valore
    % assoluto la scala la detta il membro piu' grande - un prosumer
    % industriale sta un ordine di grandezza sopra una famiglia - e la
    % dispersione di tutti gli altri si schiaccia su una riga piatta, che e'
    % esattamente l'informazione che questo riquadro dovrebbe dare. Centrando
    % ciascun membro sul proprio medio, le dispersioni diventano confrontabili.
    nexttile;
    scarto = FIN.NPV - mean(FIN.NPV, 2);
    hold on; grid on; box on;
    h = gobjects(1, numel(metodi));
    for k = 1:numel(metodi)
        h(k) = plot(1:n, scarto(:,k), 'o', 'MarkerSize', 5, ...
                    'MarkerFaceColor', method_color(metodi(k).nome), ...
                    'MarkerEdgeColor', 'none');
    end
    yline(0, 'k-');
    xticks(1:n); xticklabels(etichette); xtickangle(45);
    ylabel('scarto dal VAN medio [€]');
    legend(h, cellstr([metodi.nome]), 'Location', 'eastoutside', 'FontSize', 7);
    title(sprintf('Quanto il metodo sposta il VAN (%d metodi, scarto dal medio)', ...
                  numel(metodi)));
end
