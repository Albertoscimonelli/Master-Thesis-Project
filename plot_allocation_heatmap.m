function plot_allocation_heatmap(metodi, players, vGrand, titolo)
%PLOT_ALLOCATION_HEATMAP  Mappa di calore metodi x membri delle quote di
%   ripartizione, espresse in percentuale di v(N).
%
%   PERCHE' ACCANTO A PLOT_ALLOCATION_COMPARISON E NON AL SUO POSTO
%     Il grafico a barre affianca una barra per metodo su ogni giocatore. Con
%     quattro metodi funzionava; con sedici la larghezza di ciascuna barra
%     scende a 0.8/16 = 0.05 tick, e la figura diventa un pettine di un
%     centinaio di stecche che non si distinguono l'una dall'altra. I due
%     grafici rispondono comunque a due domande diverse e vanno tenuti
%     entrambi: quello a barre tiene gli EURO e impila la vendita di
%     eccedenza, che sta fuori dal gioco cooperativo; questo tiene le QUOTE, e
%     serve a confrontare la FORMA delle ripartizioni.
%
%   SCALA UNICA, NON PER COLONNA
%     E' la scelta opposta a quella di plot_fairness_indicators, e per un
%     motivo precciso: li' ogni colonna e' un indicatore diverso, con unita' ed
%     escursione proprie, e il colore puo' essere solo una graduatoria interna
%     alla colonna. Qui invece TUTTE le celle sono la stessa grandezza - la
%     percentuale di v(N) che quel metodo assegna a quel membro - e
%     normalizzare per colonna direbbe il falso: farebbe sembrare uguali una
%     quota del 3% e una del 40% solo perche' sono entrambe il massimo della
%     loro colonna. Con una scala sola il colore e' finalmente una misura.
%
%   COSA SI VEDE
%     I gruppi di metodi che si comportano allo stesso modo diventano bande
%     orizzontali dello stesso colore. Le chiavi guidate dal consumo lasciano
%     una colonna a zero sul prosumer; l'Equal Split e' una riga uniforme; le
%     tre approssimazioni dello Shapley formano una banda accanto allo Shapley
%     esatto, ed e' li' che si vede a occhio quale delle tre se ne discosta.
%
%   Aggiungere un modello = aggiungere un elemento a "metodi", nient'altro.
%
%   INPUT
%     metodi   struct array con campi:
%                .nome  string  nome del metodo (etichetta di riga)
%                .phi   [n x 1] ripartizione                       [EUR]
%     players  [1 x n] string   nomi dei giocatori (etichette di colonna)
%     vGrand   scalare          v(N), il montepremi ripartito       [EUR]
%     titolo   string           titolo del grafico

    players = string(players(:).');
    nP      = numel(players);
    nM      = numel(metodi);

    % --- Quote in percentuale di v(N) ---------------------------------------
    % Ogni riga somma a 100 per costruzione (efficienza: i metodi distribuiscono
    % tutto v(N), ed e' verificato da report_allocation a monte). Se qui non
    % tornasse, il problema sarebbe nel metodo, non nel grafico.
    Q = zeros(nM, nP);
    for k = 1:nM
        Q(k, :) = 100 * metodi(k).phi(:).' / vGrand;
    end

    figure('Name', 'Quote di ripartizione - mappa metodi x membri', 'Color', 'w', ...
           'Position', [70 70 300+130*nP 190+30*nM]);
    ax = axes;

    imagesc(ax, Q);
    colormap(ax, local_cmap_quote());
    clim(ax, [0 max(Q(:))]);
    cb = colorbar(ax);
    cb.Label.String = 'Quota del membro [% di v(N)]';

    % --- Etichette -----------------------------------------------------------
    xticks(ax, 1:nP);
    xticklabels(ax, strrep(players, '_', '\_'));
    xtickangle(ax, 45);
    yticks(ax, 1:nM);
    yticklabels(ax, strrep([metodi.nome], '_', '\_'));
    set(ax, 'TickLength', [0 0]);
    box(ax, 'on');

    % --- Valore in cella, con il contrasto scelto sullo sfondo ---------------
    cmap = local_cmap_quote();
    hi   = max(Q(:));
    for r = 1:nM
        for c = 1:nP
            if hi > 0
                idx = 1 + round(Q(r,c)/hi * (size(cmap,1) - 1));
            else
                idx = 1;
            end
            idx = min(max(idx, 1), size(cmap,1));
            lum = cmap(idx,:) * [0.299; 0.587; 0.114];
            if lum < 0.5, col = [1 1 1]; else, col = [0 0 0]; end
            text(ax, c, r, sprintf('%.1f', Q(r,c)), 'HorizontalAlignment', 'center', ...
                 'Color', col, 'FontSize', 8);
        end
    end

    % Un pallino sulle quote esattamente nulle: "0.0" per arrotondamento e
    % "zero esatto" sono cose diverse, e le chiavi guidate dal consumo
    % producono il secondo caso - un membro escluso dalla ripartizione, non un
    % membro che prende poco.
    [rz, cz] = find(Q == 0);
    if ~isempty(rz)
        hold(ax, 'on');
        scatter(ax, cz, rz + 0.30, 26, [0.85 0.15 0.15], 'filled', 'Marker', 'v');
    end

    title(ax, titolo, 'Interpreter', 'none');
    subtitle(ax, sprintf(['ogni riga somma a 100%%  |  v(N) = %.0f EUR  |  ' ...
                          'il triangolo rosso segnala una quota ESATTAMENTE nulla'], vGrand));
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function cmap = local_cmap_quote()
%LOCAL_CMAP_QUOTE  Scala sequenziale chiara -> blu scuro. Sequenziale e non
%   divergente perche' la grandezza ha uno zero naturale e nessun punto medio
%   privilegiato: non esiste una quota "neutra" rispetto a cui stare sopra o
%   sotto. Per quella lettura c'e' plot_merit_deviation, che ha invece un
%   riferimento vero (il contributo marginale) e usa una scala divergente.
    m = 160;
    t = linspace(0, 1, m).';
    chiaro = [0.97 0.97 0.95];
    scuro  = [0.08 0.25 0.55];
    cmap   = chiaro + t .* (scuro - chiaro);
end
