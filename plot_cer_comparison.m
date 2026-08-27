function plot_cer_comparison(RESULTS)
%PLOT_CER_COMPARISON  Confronto fra le comunita' analizzate: quanto cambia il
%   bilancio energetico, e quanto cambia la ripartizione, al cambiare di chi
%   abita la CER.
%
%   PERCHE' QUESTO GRAFICO STA FUORI DAL CICLO
%     MAIN.m ripete l'intera analisi una volta per scheda e azzera il workspace
%     a ogni giro: dentro il ciclo una comunita' non puo' vedere le altre. La
%     struct RESULTS esiste apposta - viene riempita in coda a ogni giro con
%     quello che serve dopo. Questa e' la funzione che la usa. Finche' la
%     cartella contiene una scheda sola non ha nulla da dire, ed e' giusto che
%     il chiamante non la invochi.
%
%   COSA SI PUO' CONFRONTARE E COSA NO
%     Le CER hanno un numero di membri diverso, e i membri stessi cambiano. Non
%     ha percio' senso affiancare vettori per membro: "il terzo utente" non e'
%     la stessa persona in due comunita' diverse. Si confrontano solo
%     grandezze di COMUNITA' (energia, ricavi) e grandezze NORMALIZZATE (quote
%     in percentuale di v(N), indici in [0,1]), che restano confrontabili
%     qualunque sia la taglia. E' lo stesso motivo per cui MAIN.m fa clearvars
%     a ogni giro: una lunghezza che cambia in silenzio non da' errore, da'
%     un risultato sbagliato.
%
%   LA DOMANDA A CUI SERVE RISPONDERE
%     Aggiungere un prosumer non cambia solo i totali: cambia quanta energia e'
%     CONTENDIBILE fra i metodi, e quindi quanto la scelta del modello di
%     ripartizione conti davvero. I pannelli in basso misurano proprio questo -
%     di quanto si spostano le quote e gli indici quando si passa da una
%     comunita' all'altra.
%
%   INPUT
%     RESULTS  struct array, un elemento per CER, con i campi:
%                .nome .scheda .nUsers .userNames  identita' della comunita'
%                .shared_annual .sold_annual       energia annua      [kWh]
%                .vGrand                           ricavo da condivisa [EUR]
%                .rev_tot_annual                   ricavo totale       [EUR]
%                .contendibleShare                 frazione contendibile
%                .isProsumer   [n x 1] logico
%                .metodi       struct array con .nome e .phi
%                .Tfair        table degli indici di equita'

    nCER = numel(RESULTS);
    if nCER < 2
        return      % con una comunita' sola non c'e' confronto da fare
    end

    % Etichetta su UNA riga: MATLAB spezza le etichette dei tick sugli a capo
    % e le ridistribuisce sui tick successivi, cosi' la seconda riga della
    % prima CER finirebbe sotto la seconda. E interprete 'none' sui tick, o
    % gli underscore dei nomi delle schede diventano pedici TeX.
    etich = strings(nCER, 1);
    for c = 1:nCER
        [~, base] = fileparts(RESULTS(c).scheda);
        etich(c)  = sprintf('%s (%d membri)', base, RESULTS(c).nUsers);
    end

    figure('Name', 'Confronto fra le CER analizzate', 'Color', 'w', ...
           'Position', [60 50 1300 880]);
    tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('Confronto fra le %d comunita'' analizzate', nCER), ...
          'FontWeight', 'bold');

    % --- (a) Bilancio energetico --------------------------------------------
    ax1 = nexttile; hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    E = [[RESULTS.shared_annual].', [RESULTS.sold_annual].'];
    hb = bar(ax1, 1:nCER, E, 0.7);
    hb(1).FaceColor = [0.20 0.60 0.30];
    hb(2).FaceColor = [0.90 0.45 0.15];

    % La frazione contendibile e' la chiave di lettura di tutto il resto della
    % figura, e va accanto ai kWh e non in una nota a pie' di pagina.
    for c = 1:nCER
        text(ax1, c, max(E(c,:)) * 1.06, ...
             sprintf('contendibile %.1f%%', 100*RESULTS(c).contendibleShare), ...
             'HorizontalAlignment', 'center', 'FontSize', 8.5, ...
             'FontWeight', 'bold', 'Color', [0.30 0.30 0.30]);
    end

    local_assi_cer(ax1, nCER, etich);
    ylim(ax1, [0 max(E(:)) * 1.20]);
    ylabel(ax1, 'Energia annua [kWh]');
    legend(ax1, hb, {'Condivisa (incentivata)', 'Venduta in rete'}, ...
           'Location', 'northwest', 'Box', 'off');
    title(ax1, 'Bilancio energetico di comunita');

    % --- (b) Da dove arrivano i soldi ---------------------------------------
    % v(N) e' il ricavo da energia condivisa, cioe' il montepremi che i sedici
    % metodi si dividono; il resto e' vendita in rete, che sta fuori dal gioco
    % e va ai proprietari degli impianti. Il rapporto fra i due decide quanto
    % pesi davvero la scelta del metodo di ripartizione.
    ax2 = nexttile; hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    vg   = [RESULTS.vGrand].';
    vend = [RESULTS.rev_tot_annual].' - vg;
    hb2  = bar(ax2, 1:nCER, [vg, vend], 0.6, 'stacked');
    hb2(1).FaceColor = [0.20 0.55 0.85];
    hb2(2).FaceColor = [0.90 0.45 0.15];

    for c = 1:nCER
        quota = 100 * vg(c) / (vg(c) + vend(c));
        text(ax2, c, vg(c) + vend(c) + 0.04*max(vg+vend), ...
             sprintf('v(N) = %.0f%% del totale', quota), ...
             'HorizontalAlignment', 'center', 'FontSize', 8.5, ...
             'FontWeight', 'bold', 'Color', [0.30 0.30 0.30]);
    end

    local_assi_cer(ax2, nCER, etich);
    ylim(ax2, [0 max(vg+vend) * 1.18]);
    ylabel(ax2, 'Ricavo annuo [EUR]');
    % Handle espliciti e nell'ordine di impilamento: la legenda automatica di
    % una barra impilata elenca gli strati dall'alto, cioe' al contrario.
    legend(ax2, [hb2(1) hb2(2)], ...
           {'v(N) - condivisa, ripartita dai 16 metodi', ...
            'Vendita in rete - fuori dal gioco'}, ...
           'Location', 'northwest', 'Box', 'off');
    title(ax2, 'Il montepremi in palio, e quello che non lo e');

    % --- (c) Slope chart: quanto va ai prosumer, metodo per metodo ----------
    % Una linea per metodo. E' la grandezza normalizzata piu' informativa che
    % due CER di taglia diversa possano condividere: dice come ciascun modello
    % reagisce all'ingresso di un secondo prosumer, e i modelli che reagiscono
    % in modo opposto si vedono come linee che si incrociano.
    ax3 = nexttile; hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');

    nomiComuni = local_metodi_comuni(RESULTS);
    nK         = numel(nomiComuni);
    Q          = nan(nCER, nK);
    for k = 1:nK
        for c = 1:nCER
            idx = find([RESULTS(c).metodi.nome] == nomiComuni(k), 1);
            if ~isempty(idx)
                phi     = RESULTS(c).metodi(idx).phi(:);
                mask    = logical(RESULTS(c).isProsumer(:));
                Q(c, k) = 100 * sum(phi(mask)) / RESULTS(c).vGrand;
            end
        end
        plot(ax3, 1:nCER, Q(:, k), '-o', 'Color', method_color(nomiComuni(k)), ...
             'LineWidth', 1.8, 'MarkerSize', 5, ...
             'MarkerFaceColor', method_color(nomiComuni(k)));
    end

    % Il nome accanto all'ultimo punto invece di una legenda da sedici voci,
    % che occuperebbe meta' pannello. Le quote si accalcano - diversi metodi
    % danno quasi lo stesso risultato - quindi le etichette vanno distanziate
    % e collegate alla propria linea, altrimenti restano illeggibili proprio
    % dove il grafico avrebbe piu' da dire.
    xlim(ax3, [0.85 nCER + 1.15]);
    ylim(ax3, [min(Q(:)) - 0.10*max(1, range_o(Q(:))), ...
               max(Q(:)) + 0.10*max(1, range_o(Q(:)))]);

    colK = zeros(nK, 3);
    for k = 1:nK
        colK(k, :) = method_color(nomiComuni(k)) * 0.75;
    end
    spread_labels(ax3, repmat(nCER, nK, 1), Q(end, :).', nomiComuni, ...
                  struct('colore', colK, 'fontSize', 7.5, ...
                         'dx', 0.035 * nCER, 'dyMin', 0.040 * range_o(Q(:))));

    local_assi_cer(ax3, nCER, etich);
    ylabel(ax3, 'Quota totale ai prosumer [% di v(N)]');
    title(ax3, 'Come ciascun metodo reagisce al cambio di comunita');

    % --- (d) Quanto conta scegliere il metodo -------------------------------
    % Non il VALORE di un indice, ma la sua ESCURSIONE fra i sedici metodi: di
    % quanto cambia il risultato solo perche' si e' scelta un'altra regola di
    % ripartizione. Se l'escursione e' piccola, la scelta del modello e' quasi
    % indifferente in quella comunita'.
    %
    % I tre indicatori non sono tre modi di misurare la stessa cosa, e per
    % questo stanno insieme: uno ECONOMICO (EI, sui risparmi in euro), uno
    % ENERGETICO (Jain, sui volumi scambiati) e uno di STABILITA' (l'eccesso di
    % coalizione). Sui dati del progetto i primi due si comportano in modo molto
    % diverso - l'energetico resta quasi fermo perche' solo una frazione minima
    % dell'energia e' contendibile fra i metodi, ed e' il collegamento diretto
    % con la percentuale annotata nel primo pannello.
    %
    % Gini NON compare, benche' sia in tabella: EI originale e' definito come
    % 1 - Gini sugli stessi risparmi, quindi le due escursioni sono lo stesso
    % numero e affiancarle riempirebbe il pannello di una colonna in doppio.
    ax4 = nexttile; hold(ax4, 'on'); grid(ax4, 'on'); box(ax4, 'on');

    etIndic  = ["EI originale (economico)", "Jain (energetico)", ...
                "Eccesso max (stabilita)"];
    colIndic = [0.13 0.42 0.58; 0.20 0.60 0.30; 0.79 0.29 0.20];

    A = zeros(nCER, 3);
    for c = 1:nCER
        T = RESULTS(c).Tfair;
        A(c, 1) = max(T.EI_orig) - min(T.EI_orig);
        A(c, 2) = max(T.Jain)    - min(T.Jain);
        % Rapportato a v(N), altrimenti due CER con montepremi diversi non
        % sarebbero confrontabili: 100 EUR di eccesso pesano il doppio in una
        % comunita' che ne ripartisce la meta'.
        A(c, 3) = (max(T.EccessoMax_EUR) - min(T.EccessoMax_EUR)) / RESULTS(c).vGrand;
    end

    hb4 = bar(ax4, 1:nCER, A, 0.75);
    for j = 1:3
        hb4(j).FaceColor = colIndic(j, :);
    end

    for c = 1:nCER
        for j = 1:3
            text(ax4, hb4(j).XEndPoints(c), A(c,j) + 0.02*max(A(:)), ...
                 sprintf('%.2f', A(c,j)), 'HorizontalAlignment', 'center', ...
                 'FontSize', 8, 'Color', colIndic(j,:) * 0.8);
        end
    end

    % Legenda fuori dagli assi: dentro copriva la prima barra, che e' anche la
    % piu' alta - ed e' proprio quella da leggere.
    legend(ax4, hb4, cellstr(etIndic), 'Location', 'southoutside', ...
           'Orientation', 'horizontal', 'Box', 'off');
    local_assi_cer(ax4, nCER, etich);
    ylim(ax4, [0 max(A(:)) * 1.15]);
    ylabel(ax4, {'Escursione fra i 16 metodi', ...
                 '(indici in [0,1]; eccesso in frazione di v(N))'});
    title(ax4, 'Quanto conta la scelta del metodo');
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function local_assi_cer(ax, nCER, etich)
%LOCAL_ASSI_CER  Asse orizzontale comune ai quattro pannelli: una tacca per
%   comunita', col nome della scheda. Interprete 'none' perche' i nomi delle
%   schede contengono underscore, che il TeX di default trasformerebbe in
%   pedici (CER_5_1_0 diventerebbe "CER" con "5" a pedice).
    xticks(ax, 1:nCER);
    xticklabels(ax, etich);
    set(ax, 'TickLabelInterpreter', 'none');
end


function r = range_o(v)
%RANGE_O  Escursione mai nulla, per non azzerare i margini calcolati su di essa.
    r = max(v) - min(v);
    if ~isfinite(r) || r == 0
        r = max(1, abs(max(v)));
    end
end


function nomi = local_metodi_comuni(RESULTS)
%LOCAL_METODI_COMUNI  Nomi dei metodi presenti in TUTTE le CER, nell'ordine
%   della prima. Una linea che salta un punto e' peggio di una linea assente:
%   se domani una comunita' escludesse un metodo, tracciarlo comunque
%   suggerirebbe una continuita' che non c'e'.
    nomi = [RESULTS(1).metodi.nome];
    for c = 2:numel(RESULTS)
        nomi = nomi(ismember(nomi, [RESULTS(c).metodi.nome]));
    end
end
