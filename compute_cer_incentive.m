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
%   FATTORE F: LA REGOLA C'E', MA NON SI APPLICA QUI
%     F decurta la tariffa in presenza di contributo in conto capitale e vale
%     0,50 * pct/40 (Regole Operative GSE 16/07/2025, Appendice B par. 3): la
%     derivazione dal contributo sta in cer_reduction_factor.m.
%
%     Il punto e' che F NON e' una proprieta' della tariffa: non si applica
%     all'energia afferente a punti di prelievo esenti (persone fisiche ed
%     enti), quindi il suo effetto dipende da CHI consuma l'energia condivisa,
%     e cambia da coalizione a coalizione. Applicarlo qui vorrebbe dire
%     decidere quella composizione una volta per tutte.
%
%     Percio' MAIN.m chiama questa funzione con F = 0 e ne ricava la tariffa
%     LORDA - che e' poi la tariffa dei membri esenti - mentre la decurtazione
%     entra dentro la funzione caratteristica, dove la quota esente e' quella
%     della coalizione che si sta valutando (cer_shared_value.m).
%
%     L'argomento F resta perche' la formula 3.1 lo prevede e perche' per una
%     configurazione SENZA membri esenti le due strade coincidono: in quel caso
%     passarlo qui e' legittimo e piu' diretto.
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
