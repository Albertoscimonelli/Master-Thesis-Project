function R = pv_simulate_layout(tilt_deg, D_rtr_m, G_tot, T_c, alpha_s, geo, par)
%PV_SIMULATE_LAYOUT  Simulazione oraria annuale di una configurazione.
%
%   R = PV_SIMULATE_LAYOUT(tilt_deg, D_rtr_m, G_tot, T_c, alpha_s, geo, par)
%   esegue in forma vettoriale (nessun ciclo sulle ore) la catena:
%     ombreggiamento inter-fila -> irradianza effettiva -> produzione DC ->
%     clipping e conversione AC -> bilancio energetico edificio/CER/rete.
%
%   G_tot e T_c arrivano gia' calcolati da pv_poa_tcell: dipendono solo dal
%   tilt, quindi vengono riusati per tutte le distanze inter-fila.
%
%   Ombreggiamento, secondo par.coplanar:
%     false -> file inclinate su piano orizzontale: la fila anteriore proietta
%              un'ombra di altezza s sulla fila retrostante (la prima fila non
%              e' mai ombreggiata). Perdita lineare sull'area attiva.
%     true  -> moduli complanari alla falda e affiancati: essendo tutti sullo
%              stesso piano non si ombreggiano a vicenda, quindi s = 0 e
%              l'area attiva e' sempre l'intera superficie dei moduli.
%
%   INPUT
%     tilt_deg  scalare   inclinazione moduli [gradi]
%     D_rtr_m   scalare   distanza inter-fila [m]
%     G_tot     [1 x N]   irradianza sul piano inclinato [W/m2]
%     T_c       [1 x N]   temperatura di cella [C]
%     alpha_s   [1 x N]   altezza solare [gradi]
%     geo       struct    da pv_layout: N_rows, N_mod_rows, N_mod, P_ac_nom
%     par       struct    L_m, W_m, P_stc_mod, power_coeff, DC_losses,
%                         eta_inv, AC_losses, build_cons, REC_cons
%
%   OUTPUT
%     R  struct con serie orarie [1 x N] e aggregati annuali [MWh]

    W_m = par.W_m;

    % -- Ombreggiamento inter-fila -------------------------------------------
    coplanar = isfield(par, 'coplanar') && par.coplanar;

    if coplanar
        % Moduli complanari alla falda del tetto: giacciono tutti sullo stesso
        % piano e sono affiancati, quindi nessuno puo' proiettare ombra su un
        % altro. L'area attiva e' sempre l'intera superficie dei moduli.
        s        = zeros(size(alpha_s));
        A_active = geo.N_mod * par.L_m * W_m * ones(size(alpha_s));
    else
        % File inclinate su piano orizzontale: la fila anteriore ombreggia
        % quella retrostante.
        % x: sporgenza dell'ombra oltre l'inizio della fila successiva
        % (forma algebrica lasciata identica alla versione scalare precedente,
        %  per garantire risultati bit-per-bit invariati dopo la vettorizzazione)
        x = W_m*sind(tilt_deg) ./ tand(alpha_s) + W_m*cosd(tilt_deg) ...
            - (D_rtr_m + W_m*cosd(tilt_deg));

        % s: altezza di modulo ombreggiata, limitata tra 0 e l'intero modulo
        s = min(W_m, max(0, (x .* sind(alpha_s)) ./ sind(180 - alpha_s - tilt_deg)));

        % Area attiva: la prima fila e' sempre interamente illuminata
        A_active = ((W_m - s) * (geo.N_rows - 1) + W_m) * geo.N_mod_rows * par.L_m;

        % Sole sotto l'orizzonte: campo completamente ombreggiato
        s(alpha_s <= 0) = W_m;
    end

    % Sole sotto l'orizzonte: nessuna produzione, in entrambi i montaggi
    A_active(alpha_s <= 0) = 0;

    % Irradianza media effettiva sul campo, pesata sull'area non ombreggiata
    G_av = G_tot / (geo.N_mod * par.L_m * W_m) .* A_active;

    % -- Produzione DC (modello lineare con correzione termica) ---------------
    P_dc     = G_av/1000 * par.P_stc_mod .* (1 + par.power_coeff*(T_c - 25)) ...
               * geo.N_mod / 1000;                      % [kW]
    P_dc_net = P_dc * (1 - par.DC_losses);

    % -- Conversione AC: clipping alla potenza nominale inverter --------------
    P_ac     = min(P_dc_net * par.eta_inv, geo.P_ac_nom);
    P_ac_net = P_ac * (1 - par.AC_losses);

    % -- Bilancio energetico orario ------------------------------------------
    % Priorita': 1) autoconsumo edificio, 2) cessione CER, 3) immissione in rete
    P_cons = par.build_cons;
    P_REC  = par.REC_cons;

    P_purch  = max(0, P_cons - P_ac_net);          % Prelievo dalla rete
    surplus  = max(0, P_ac_net - P_cons);          % Eccedenza dopo autoconsumo
    P_toREC  = min(surplus, P_REC);                % Quota assorbita dalla CER
    P_togrid = max(0, surplus - P_REC);            % Residuo immesso in rete

    % -- Serie orarie ---------------------------------------------------------
    R.s        = s;
    R.A_active = A_active;
    R.G_av     = G_av;
    R.P_dc     = P_dc;
    R.P_dc_net = P_dc_net;
    R.P_ac     = P_ac;
    R.P_ac_net = P_ac_net;
    R.P_purch  = P_purch;
    R.P_toREC  = P_toREC;
    R.P_togrid = P_togrid;
    R.P_cons   = P_cons;
    R.P_REC    = P_REC;

    % -- Aggregati annuali [MWh] ---------------------------------------------
    R.E_dc     = sum(P_dc)     / 1000;
    R.E_ac_net = sum(P_ac_net) / 1000;
    R.E_purch  = sum(P_purch)  / 1000;
    R.E_toREC  = sum(P_toREC)  / 1000;
    R.E_togrid = sum(P_togrid) / 1000;
    R.E_saved  = sum(P_cons)/1000 - R.E_purch;     % Energia autoconsumata

    % Perdite da clipping: differenza tra AC teorica e AC effettivamente immessa
    R.clipping_losses = sum(P_dc_net)/1000 * par.eta_inv * (1 - par.AC_losses) - R.E_ac_net;

    % Efficienza di ombreggiamento annuale
    R.eta_shad = sum(G_av) / sum(G_tot);
end
