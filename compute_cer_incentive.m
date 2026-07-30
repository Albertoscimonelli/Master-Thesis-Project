function TIP_h = compute_cer_incentive(Pz_h, P_nom_kW, zona, F)
%COMPUTE_CER_INCENTIVE  Tariffa incentivante premio (TIP) oraria sull'energia
%   condivisa in una CER (eq. 3.1):
%
%     TIP_h = {min[CAP; TP_base + max(0; 180 - Pz_h)] + FC_zonale} * (1-F)
%
%   TP_base/CAP [EUR/MWh] dipendono dalla taglia dell'impianto P_nom_kW:
%     P_i <= 200 kW              -> TP_base = 80,  CAP = 120
%     200 kW < P_i <= 600 kW     -> TP_base = 70,  CAP = 110
%     P_i > 600 kW               -> TP_base = 60,  CAP = 100
%   FC_zonale [EUR/MWh] corregge per differenziale di insolazione:
%     nord = +10, centro = +4, sud = 0.
%
%   NOTA SU F: la definizione completa del fattore di riduzione F non e'
%   ancora disponibile (il testo di riferimento con la regola esatta e'
%   incompleto). Per ora F = 0 (nessuna riduzione) di default: sostituire con
%   la regola/il valore corretto non appena noto.
%
%   INPUT
%     Pz_h      [H x 1]        prezzo zonale orario           [EUR/MWh]
%     P_nom_kW  scalare        potenza nominale dell'impianto [kW]
%     zona      string         "nord" | "centro" | "sud"
%     F         scalare o [H x 1]  fattore di riduzione (0..1), default 0
%
%   OUTPUT
%     TIP_h  [H x 1]  tariffa incentivante oraria   [EUR/kWh]

    if nargin < 4 || isempty(F)
        F = 0;
    end

    % --- Scaglione di potenza: TP_base e CAP [EUR/MWh] ----------------------
    if P_nom_kW <= 200
        TP_base = 80; CAP = 120;
    elseif P_nom_kW <= 600
        TP_base = 70; CAP = 110;
    else
        TP_base = 60; CAP = 100;
    end

    % --- Correzione zonale (differenziale di insolazione) [EUR/MWh] ---------
    switch char(lower(string(zona)))
        case 'nord',   FC_zonale = 10;
        case 'centro', FC_zonale = 4;
        case 'sud',    FC_zonale = 0;
        otherwise
            error('compute_cer_incentive:zonaNonValida', ...
                  'Zona "%s" non riconosciuta (attese: nord, centro, sud).', zona);
    end

    Pz_h    = Pz_h(:);
    F       = F(:);
    TIP_MWh = min(CAP, TP_base + max(0, 180 - Pz_h)) + FC_zonale;
    TIP_MWh = TIP_MWh .* (1 - F);

    TIP_h = TIP_MWh / 1000;   % EUR/MWh -> EUR/kWh
end
