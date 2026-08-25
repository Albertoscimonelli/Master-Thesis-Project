function geo = pv_layout(tilt_deg, D_rtr_m, par)
%PV_LAYOUT  Layout fisico del campo e dimensionamento automatico inverter.
%
%   geo = PV_LAYOUT(tilt_deg, D_rtr_m, par) calcola quante file e quanti
%   moduli per fila entrano sulla copertura disponibile, la potenza DC
%   installata e il numero di inverter necessario.
%
%   Il numero di inverter NON e' una variabile decisionale: viene derivato
%   dalla potenza DC imponendo un rapporto DC/AC obiettivo (par.DCAC_target).
%   Questo evita accoppiamenti irrealistici (es. 3 kWp su 250 kWac) che
%   rendono l'analisi economica priva di significato.
%
%   Con par.coplanar = true i moduli giacciono sul piano della falda (tetto
%   inclinato): sono affiancati, senza spaziatura, e L_r/W_r vanno intese
%   come dimensioni misurate SULLA FALDA, non in proiezione orizzontale.
%
%   INPUT
%     tilt_deg  scalare  inclinazione moduli [gradi]
%     D_rtr_m   scalare  distanza inter-fila (spazio libero tra le file) [m]
%                        (ignorata se par.coplanar = true)
%     par       struct   parametri: L_r, W_r, d_edge, L_m, W_m, P_stc_mod,
%                                   P_ac_inv, DCAC_target, coplanar
%
%   OUTPUT
%     geo  struct  N_rows, N_mod_rows, N_mod, P_dc_nom [kWp],
%                  N_inv, P_ac_nom [kWac], pitch [m], GCR [-]

    % Profondita' e larghezza utili al netto del margine perimetrale
    depth_free = par.L_r - 2*par.d_edge;
    width_free = par.W_r - 2*par.d_edge;

    % Passo tra file consecutive.
    %   coplanar = 1 -> moduli complanari alla falda, affiancati: occupano
    %                   l'intera larghezza W_m misurata SUL PIANO del tetto,
    %                   senza proiezione orizzontale e senza spaziatura.
    %   coplanar = 0 -> file inclinate su piano orizzontale: conta l'ingombro
    %                   proiettato del modulo piu' lo spazio libero inter-fila.
    coplanar = isfield(par, 'coplanar') && par.coplanar;
    if coplanar
        pitch = par.W_m;
    else
        pitch = par.W_m*cosd(tilt_deg) + D_rtr_m;
    end

    geo.N_rows     = max(0, floor(depth_free / pitch));
    geo.N_mod_rows = max(0, floor(width_free / par.L_m));
    geo.N_mod      = geo.N_rows * geo.N_mod_rows;

    geo.P_dc_nom = geo.N_mod * par.P_stc_mod / 1000;    % [kWp]

    % Dimensionamento inverter sul rapporto DC/AC obiettivo
    geo.N_inv    = max(1, ceil(geo.P_dc_nom / (par.P_ac_inv * par.DCAC_target)));
    geo.P_ac_nom = geo.N_inv * par.P_ac_inv;            % [kWac]

    geo.pitch = pitch;
    % Ground Coverage Ratio: quota di superficie coperta dai moduli
    if pitch > 0
        geo.GCR = par.W_m / pitch;
    else
        geo.GCR = NaN;
    end
end
