function plot_gini_3d(RESULTS)
%PLOT_GINI_3D  Superficie del Gini su tre assi: i modelli di ripartizione in
%   larghezza, le comunita' in profondita', l'indice in altezza.
%
%   UNA SOLA SUPERFICIE, NON UNA PER COMUNITA'
%     Il Gini e' una funzione di due variabili - quale modello si applica e a
%     quale comunita' - e una superficie e' il modo naturale di guardare una
%     funzione di due variabili: si vede dove sale, dove scende, e soprattutto
%     se la pendenza lungo un asse cambia al muoversi lungo l'altro. Quella e'
%     l'interazione fra i due effetti, ed e' la cosa che ne' la tabella ne' un
%     grafico a barre per metodo riescono a mostrare.
%
%   QUANTE COMUNITA' SERVONO PERCHE' SI VEDA DAVVERO
%     Con DUE schede la superficie ha due soli punti in profondita': e' un
%     nastro piegato lungo i modelli, non un rilievo. Regge - e' comunque la
%     lettura corretta - ma il suo senso pieno arriva con la terza e la quarta
%     comunita', quando la direzione della profondita' smette di essere una
%     semplice interpolazione fra due estremi. La figura non va cambiata per
%     ottenerlo: basta aggiungere una scheda in CER_configuration/.
%
%   ATTENZIONE: LA SUPERFICIE FRA DUE NODI NON E' UN DATO
%     Entrambi gli assi orizzontali sono CATEGORIALI. Fra "Shapley" e
%     "Nucleolo" non esiste un metodo intermedio, e fra due comunita' non
%     esiste una comunita' intermedia: quello che sta fra due nodi e' il
%     raccordo che disegna il software, non un valore calcolato. I dati sono i
%     NODI, marcati apposta con un cerchietto. Anche l'ordine dei modelli
%     sull'asse e' convenzionale - e' quello della tabella di confronto, tenuto
%     identico fra le comunita' perche' i profili siano sovrapponibili:
%     cambiandolo cambierebbe la forma del rilievo, non il dato.
%
%   PERCHE' L'ASSE Z ARRIVA A 1 ANCHE SE I VALORI NON CI ARRIVANO
%     Il Gini e' definito in [0,1] - 0 = ripartizione perfettamente uniforme,
%     1 = concentrazione totale - e quello e' il metro con cui la letteratura
%     lo legge. Ritagliare l'asse sui valori osservati farebbe sembrare enormi
%     differenze che sulla scala dell'indice sono modeste, ed e' un modo
%     classico di esagerare un risultato senza dire una bugia. Il COLORE, che
%     e' una graduatoria e non una misura, si normalizza invece sui valori
%     osservati: sul dominio pieno la superficie sarebbe di una tinta sola.
%
%   ATTENZIONE: il Gini di questa figura e' quello dei RISPARMI, il nucleo
%     dell'EI originale (EI = 1 - Gini). Non e' il Gini di ETEROGENEITA' della
%     composizione della comunita' (gini_heterogeneity.m), che descrive chi
%     c'e' nella CER e non dipende dal metodo di ripartizione.
%
%   INPUT
%     RESULTS  struct array, un elemento per CER, con i campi:
%                .scheda .nUsers  identita' della comunita'
%                .Tfair           table con le colonne Metodo e Gini

    nCER = numel(RESULTS);
    if nCER < 1
        return
    end

    % --- Solo i metodi presenti in TUTTE le comunita' ------------------------
    % Un buco nella griglia diventerebbe un NaN, e un NaN in surf apre un foro
    % nella superficie: si leggerebbe come "qui il Gini non esiste" invece che
    % "questa comunita' non usa quel metodo".
    nomi = string(RESULTS(1).Tfair.Metodo);
    for c = 2:nCER
        nomi = nomi(ismember(nomi, string(RESULTS(c).Tfair.Metodo)));
    end
    nM = numel(nomi);

    % --- La griglia dei valori: [nCER x nM] ---------------------------------
    % Incrocio per NOME e non per posizione: due tabelle con lo stesso numero
    % di righe non garantiscono lo stesso ordine, e uno scambio silenzioso qui
    % attribuirebbe a un metodo il Gini di un altro.
    G = nan(nCER, nM);
    for c = 1:nCER
        T = RESULTS(c).Tfair;
        for k = 1:nM
            G(c, k) = T.Gini(string(T.Metodo) == nomi(k));
        end
    end

    etichCER = strings(nCER, 1);
    for c = 1:nCER
        [~, base]   = fileparts(RESULTS(c).scheda);
        etichCER(c) = sprintf('%s (%d membri)', base, RESULTS(c).nUsers);
    end

    % --- Figura ---------------------------------------------------------------
    figure('Name', 'Gini per CER e per metodo (3D)', 'Color', 'w', ...
           'Position', [40 60 1380 720]);
    ax = axes; hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');

    % --- La superficie --------------------------------------------------------
    % surf vuole almeno due righe e due colonne. Con UNA sola comunita' la
    % griglia e' una riga e non c'e' superficie da fare: si degrada a curva,
    % che e' l'oggetto corretto per quel caso invece di un errore.
    if nCER >= 2
        hs = surf(ax, 1:nM, 1:nCER, G);
        hs.FaceAlpha  = 0.92;
        hs.EdgeColor  = [0.25 0.25 0.25];
        hs.LineWidth  = 0.5;
        hs.FaceColor  = 'interp';       % sfumatura continua, come una mappa di quota
    else
        plot3(ax, 1:nM, ones(1, nM), G(1,:), '-', 'Color', [0.16 0.47 0.71], ...
              'LineWidth', 2.4);
    end

    % --- I nodi: e' li' che stanno i dati ------------------------------------
    for c = 1:nCER
        plot3(ax, 1:nM, repmat(c, 1, nM), G(c,:), 'o', 'MarkerSize', 4.5, ...
              'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.15 0.15 0.15], ...
              'LineWidth', 1.1);
    end

    % --- Colore: graduatoria sui valori osservati, non sul dominio -----------
    colormap(ax, local_cmap_quota());
    lo = min(G(:)); hi = max(G(:));
    if hi > lo
        clim(ax, [lo hi]);
    end
    cb = colorbar(ax);
    cb.Label.String = 'Gini dei risparmi';

    % --- Assi -----------------------------------------------------------------
    xticks(ax, 1:nM);    xticklabels(ax, nomi);    xtickangle(ax, 40);
    yticks(ax, 1:nCER);  yticklabels(ax, etichCER);
    set(ax, 'TickLabelInterpreter', 'none');   % gli underscore delle schede
    zlim(ax, [0 1]);                            % il dominio dell'indice, non i dati
    zticks(ax, 0:0.2:1);
    xlim(ax, [0.7 nM + 0.3]);
    ylim(ax, [0.7 nCER + 0.3]);

    xlabel(ax, 'Modello di ripartizione');
    ylabel(ax, 'Comunita');
    zlabel(ax, 'Gini dei risparmi   (0 = uniforme, 1 = concentrato)');

    % Proporzioni larghe e poco profonde: e' la forma dei dati (molti modelli,
    % poche comunita'). Lasciando fare a MATLAB, la profondita' verrebbe
    % dilatata fino a rendere la superficie quasi frontale, cioe' illeggibile.
    pbaspect(ax, [2.8 1 1]);
    view(ax, -40, 30);
    ax.FontSize = 8.5;
    ax.XAxis.FontSize = 8;

    title(ax, 'Indice di Gini al variare della comunita e del modello di ripartizione', ...
          'FontSize', 12, 'FontWeight', 'bold');
    % Il range osservato va detto: con l'asse Z sul dominio pieno [0,1] il
    % rilievo occupa poca altezza, e senza questo numero si potrebbe scambiare
    % una variazione reale per una figura piatta.
    if nCER < 3
        nota = sprintf('%d comunita'' - la superficie e'' ancora un nastro', nCER);
    else
        nota = sprintf('%d comunita''', nCER);
    end
    subtitle(ax, sprintf(['%d modelli x %s  |  Gini osservato %.2f - %.2f su un dominio ' ...
                          '[0,1]  |  i dati sono i NODI, gli assi orizzontali sono ' ...
                          'categoriali'], nM, nota, lo, hi), 'FontSize', 9);
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function cmap = local_cmap_quota()
%LOCAL_CMAP_QUOTA  Scala sequenziale blu -> verde -> giallo per la quota della
%   superficie. Sequenziale e non divergente perche' il Gini ha uno zero
%   naturale e nessun punto medio privilegiato: non esiste un valore "neutro"
%   rispetto a cui stare sopra o sotto. Percettivamente ordinata, cosi' il
%   colore si legge come un'altezza anche dove la prospettiva inganna.
    m = 192;
    t = linspace(0, 1, m).';
    blu    = [0.15 0.30 0.60];
    ciano  = [0.20 0.68 0.75];
    verde  = [0.55 0.82 0.35];
    giallo = [0.98 0.90 0.20];

    n1 = round(m/3); n2 = round(m/3); n3 = m - n1 - n2;
    s1 = linspace(0,1,n1).'; s2 = linspace(0,1,n2).'; s3 = linspace(0,1,n3).';
    cmap = [blu   + s1 .* (ciano  - blu); ...
            ciano + s2 .* (verde  - ciano); ...
            verde + s3 .* (giallo - verde)];
end
