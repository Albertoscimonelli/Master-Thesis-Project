function plot_allocation_comparison(metodi, players, soldPerPlayer, titolo)
%PLOT_ALLOCATION_COMPARISON  Grafico a barre raggruppate+impilate che
%   confronta piu' modelli di ripartizione sugli stessi giocatori.
%
%   Per ogni giocatore si affiancano le barre dei diversi metodi; ciascuna
%   barra e' impilata in due parti: la quota CER del metodo e la vendita
%   diretta dell'eccedenza sul mercato (uguale per tutti i metodi, perche'
%   non passa dal gioco cooperativo). bar() non sa fare raggruppato+impilato
%   in una sola chiamata, quindi gli offset orizzontali sono calcolati a mano.
%
%   Aggiungere un modello = aggiungere un elemento a "metodi", nient'altro:
%   larghezza e posizione delle barre si adattano da sole.
%
%   INPUT
%     metodi        struct array con campi:
%                     .nome  string  nome del metodo (legenda e colore)
%                     .phi   [n x 1] ripartizione                    [EUR]
%     players       [1 x n] string   nomi dei giocatori
%     soldPerPlayer [n x 1] double   ricavo annuo da vendita diretta
%                                    dell'eccedenza, per giocatore   [EUR]
%     titolo        string           titolo del grafico

    nMetodi  = numel(metodi);
    players_m = players(:).';
    nPlayers  = numel(players_m);

    soldPerPlayer = soldPerPlayer(:);

    phi_m = zeros(nPlayers, nMetodi);
    for k = 1:nMetodi
        phi_m(:,k) = metodi(k).phi(:);
    end

    % Offset centrati sul tick: per nMetodi barre servono i moltiplicatori
    % -(nMetodi-1)/2 ... +(nMetodi-1)/2, cosi' il gruppo resta simmetrico
    % qualunque sia il numero di modelli.
    larghezza = 0.8 / nMetodi;
    offset    = ((1:nMetodi) - (nMetodi + 1)/2) * larghezza;

    figure('Name', 'Confronto modelli di ripartizione', 'Color', 'w');
    hold on; grid on; box on;

    hQuota = gobjects(1, nMetodi);
    hVend  = gobjects(1, 1);
    for k = 1:nMetodi
        x = (1:nPlayers) + offset(k);
        h = bar(x, [phi_m(:,k), soldPerPlayer], larghezza, 'stacked');
        h(1).FaceColor = method_color(metodi(k).nome);
        h(2).FaceColor = [0.90 0.45 0.15];   % vendita eccedente (uguale per tutti)
        hQuota(k) = h(1);
        hVend     = h(2);
    end

    xticks(1:nPlayers);
    xticklabels(strrep(players_m, '_', '\_')); xtickangle(45);
    ylabel('Ricavo [€/anno]');
    legend([hQuota, hVend], ...
           [arrayfun(@(m) m.nome + " (quota CER)", metodi), "Vendita energia eccedente"], ...
           'Location', 'northeast');
    title(titolo);
end
