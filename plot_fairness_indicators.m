function plot_fairness_indicators(methodNames, pannelli, titolo)
%PLOT_FAIRNESS_INDICATORS  Mappa di calore metodi x indicatori di equita',
%   nello stile delle Fig. 4-5-8 di Dynge & Cali (Applied Energy 384, 2025).
%
%   PERCHE' DUE PANNELLI E NON UNO
%     Gli indicatori non hanno tutti lo stesso verso: MinMax, QoS, EI e Jain
%     sono tanto migliori quanto piu' valgono 1, mentre Gini, Fairness Index e
%     sigma sono tanto migliori quanto piu' valgono 0. Metterli su un'unica
%     scala di colore direbbe il falso -- lo stesso colore significherebbe
%     "equo" in una colonna e "iniquo" in quella accanto. Ogni pannello
%     dichiara quindi il proprio verso e usa la scala orientata di conseguenza,
%     cosi' il colore FREDDO vuol dire sempre "piu' equo" in tutta la figura.
%
%   IL COLORE E' UNA GRADUATORIA, NON UNA MISURA
%     La normalizzazione e' per COLONNA: ogni indicatore usa i propri estremi,
%     perche' le escursioni sono molto diverse fra loro e una scala comune
%     appiattirebbe i piu' compressi. Il colore dice quindi "come si piazza
%     questo metodo rispetto agli altri, su questo indicatore"; il valore
%     assoluto e' il numero scritto sopra la cella. Per lo stesso motivo non
%     c'e' colorbar: sarebbe ambigua.
%
%   Aggiungere un indicatore = aggiungere una colonna al pannello giusto;
%   aggiungere una famiglia = aggiungere un elemento a "pannelli".
%
%   INPUT
%     methodNames [1 x nM] string  nomi dei metodi (una riga ciascuno)
%     pannelli    struct array con campi:
%                   .nome        string   titolo del pannello
%                   .indicatori  [1 x k]  string, etichette delle colonne
%                   .valori      [nM x k] double, NaN dove non applicabile
%                   .bestIsOne   logico   true se il valore ALTO e' il migliore
%                   .etichettaVerso  string (opzionale) come dichiarare il verso
%                                nel titolo del pannello. Senza, si scrive
%                                "1 = piu' equo" / "0 = piu' equo" secondo
%                                .bestIsOne -- che pero' e' sbagliato quando il
%                                meglio non sta a 0 ne' a 1, come per l'eccesso
%                                di coalizione (migliore quanto piu' negativo)
%     titolo      string  titolo generale della figura
%
%   I NaN non vengono colorati: restano trasparenti e marcati "n/d", perche'
%   "non applicabile" e "pari a zero" sono cose diverse e vanno viste diverse.

    methodNames = string(methodNames(:).');
    nM          = numel(methodNames);
    nPan        = numel(pannelli);

    % Larghezza generosa: le etichette degli indicatori sono lunghe e inclinate,
    % e i nomi dei metodi sulla sinistra pure. Con figure strette il titolo
    % viene troncato e le etichette si sovrappongono.
    figure('Name', 'Indicatori di equita'' distributiva', 'Color', 'w', ...
           'Position', [60 60 260+460*nPan 170+26*nM]);

    tl = tiledlayout(1, nPan, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, titolo, 'FontWeight', 'bold', 'Interpreter', 'none');

    for p = 1:nPan
        V     = pannelli(p).valori;
        etich = string(pannelli(p).indicatori(:).');
        k     = numel(etich);

        if ~isequal(size(V), [nM k])
            error('plot_fairness_indicators:sizeMismatch', ...
                  ['Il pannello "%s" ha valori [%d x %d] ma servono ' ...
                   '[%d metodi x %d indicatori].'], ...
                  pannelli(p).nome, size(V, 1), size(V, 2), nM, k);
        end

        ax = nexttile;

        % Il colore normalizza COLONNA PER COLONNA, non sull'intero pannello.
        % Gli indicatori hanno escursioni molto diverse -- il Gini spazia su
        % mezzo intervallo, sigma su un quarto, il Fairness Index puo' uscire
        % da [0,1] nella branca intera dell'eq. 14 -- e una scala comune
        % schiaccerebbe i piu' compressi su una tinta sola, facendoli sembrare
        % tutti uguali. Con la normalizzazione per colonna il colore mostra la
        % GRADUATORIA dentro ciascun indicatore, e il numero scritto sopra da'
        % il valore assoluto. Per questo non c'e' colorbar: sarebbe ambigua.
        Vn = local_normalize_columns(V);

        % Colonne che contengono solo interi (un CONTEGGIO, come il numero di
        % coalizioni instabili) si scrivono senza decimali: "30.00" per un
        % conteggio e' rumore che fa sembrare la cella una misura continua.
        interi = false(1, k);
        for c = 1:k
            fin = V(~isnan(V(:, c)), c);
            interi(c) = ~isempty(fin) && all(fin == round(fin));
        end

        cmap = local_fairness_cmap();
        if ~pannelli(p).bestIsOne
            cmap = flipud(cmap);      % 0 = equo -> il freddo resta sull'equo
        end

        imagesc(ax, Vn, 'AlphaData', ~isnan(Vn));
        colormap(ax, cmap);
        clim(ax, [0 1]);
        set(ax, 'Color', [0.94 0.94 0.94]);   % sfondo dei NaN

        % Etichette
        xticks(ax, 1:k);
        xticklabels(ax, etich);
        xtickangle(ax, 45);
        yticks(ax, 1:nM);
        if p == 1
            yticklabels(ax, strrep(methodNames, '_', '\_'));
        else
            yticklabels(ax, []);
        end
        set(ax, 'TickLength', [0 0]);
        box(ax, 'on');

        % Il verso si puo' dichiarare a mano: non tutti i pannelli hanno il
        % "meglio" a 0 o a 1. L'eccesso di coalizione, per esempio, e' tanto
        % migliore quanto piu' e' NEGATIVO, e "0 = piu' equo" direbbe il falso.
        if isfield(pannelli, 'etichettaVerso') && strlength(string(pannelli(p).etichettaVerso)) > 0
            verso = char(pannelli(p).etichettaVerso);
        elseif pannelli(p).bestIsOne
            verso = '1 = piu'' equo';
        else
            verso = '0 = piu'' equo';
        end
        title(ax, sprintf('%s  (%s)', pannelli(p).nome, verso), ...
              'Interpreter', 'none');

        % Valori scritti sopra le celle, in bianco o nero secondo la
        % luminosita' dello sfondo, altrimenti su un estremo della scala
        % diventano illeggibili.
        for r = 1:nM
            for c = 1:k
                v = V(r, c);
                if isnan(v)
                    text(ax, c, r, 'n/d', 'HorizontalAlignment', 'center', ...
                         'Color', [0.45 0.45 0.45], 'FontSize', 8);
                    continue
                end
                idx  = 1 + round(Vn(r, c) * (size(cmap,1) - 1));
                idx  = min(max(idx, 1), size(cmap,1));
                lum  = cmap(idx,:) * [0.299; 0.587; 0.114];
                if lum < 0.5, col = [1 1 1]; else, col = [0 0 0]; end
                text(ax, c, r, local_format(v, interi(c)), ...
                     'HorizontalAlignment', 'center', 'Color', col, 'FontSize', 8);
            end
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function s = local_format(v, isIntero)
%LOCAL_FORMAT  Testo della cella: senza decimali per i conteggi, due decimali
%   per le misure, e senza decimali anche per le misure di grande modulo, dove
%   i centesimi non aggiungono nulla e allargano la cella.
    if isIntero
        s = sprintf('%d', round(v));
    elseif abs(v) >= 100
        s = sprintf('%.0f', v);
    else
        s = sprintf('%.2f', v);
    end
end

function Vn = local_normalize_columns(V)
%LOCAL_NORMALIZE_COLUMNS  Riporta ogni colonna in [0,1] con i propri estremi.
%   Una colonna costante (tutti i metodi allo stesso valore, come il MinMax
%   prosumer con un solo impianto) non ha graduatoria: va a 0.5, tinta neutra,
%   che e' esattamente il messaggio giusto -- qui non c'e' niente da ordinare.
    Vn = nan(size(V));
    for c = 1:size(V, 2)
        col = V(:, c);
        lo  = min(col, [], 'omitnan');
        hi  = max(col, [], 'omitnan');
        if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
            Vn(~isnan(col), c) = 0.5;
        else
            Vn(:, c) = (col - lo) / (hi - lo);
        end
    end
end

function cmap = local_fairness_cmap()
%LOCAL_FAIRNESS_CMAP  Scala divergente rosso -> bianco -> blu, con il rosso
%   sull'estremo iniquo e il blu su quello equo, come le heatmap del paper.
    rosso  = [0.79 0.29 0.20];
    bianco = [0.97 0.96 0.94];
    blu    = [0.13 0.42 0.58];

    m = 128;
    t = linspace(0, 1, m).';
    cmap = [rosso  + t .* (bianco - rosso); ...
            bianco + t .* (blu    - bianco)];
end
