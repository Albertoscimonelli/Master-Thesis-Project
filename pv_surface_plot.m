function pv_surface_plot(tilt_vet, D_rtr_vet, Z, zlab, ttl)
%PV_SURFACE_PLOT  Traccia una grandezza sullo spazio delle soluzioni.
%
%   PV_SURFACE_PLOT(tilt_vet, D_rtr_vet, Z, zlab, ttl) sceglie da sola la
%   rappresentazione in base a quante variabili sono davvero esplorate:
%     due variabili -> superficie 3D
%     una variabile -> curva
%     nessuna       -> singolo valore
%
%   Serve perche' col montaggio complanare a falda tilt e spaziatura sono
%   entrambi imposti: la griglia degenera a un punto solo e surf() non e'
%   applicabile.
%
%   INPUT
%     tilt_vet   [1 x nT]      valori di inclinazione esplorati [gradi]
%     D_rtr_vet  [1 x nD]      valori di distanza inter-fila esplorati [m]
%     Z          [nT x nD]     grandezza da rappresentare
%     zlab       char          etichetta della grandezza
%     ttl        char          titolo del grafico

    nT = numel(tilt_vet);
    nD = numel(D_rtr_vet);

    if nT > 1 && nD > 1
        [TILT, D_RTR] = meshgrid(tilt_vet, D_rtr_vet);   % [nD x nT]
        surf(TILT, D_RTR, Z');                           % Z e' [nT x nD]
        xlabel('Tilt [gradi]'); ylabel('D_{rtr} [m]'); zlabel(zlab);
        colorbar; view(45, 30); shading interp;

    elseif nT > 1
        plot(tilt_vet, Z(:,1), '-o', 'LineWidth', 1.6, 'MarkerSize', 4);
        xlabel('Tilt [gradi]'); ylabel(zlab); grid on; box on;

    elseif nD > 1
        plot(D_rtr_vet, Z(1,:), '-o', 'LineWidth', 1.6, 'MarkerSize', 4);
        xlabel('D_{rtr} [m]'); ylabel(zlab); grid on; box on;

    else
        bar(1, Z(1,1), 0.4);
        set(gca, 'XTick', 1, 'XTickLabel', {'configurazione unica'});
        ylabel(zlab); grid on; box on;
    end

    title(ttl);
end
