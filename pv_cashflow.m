function [CF, CAPEX, OPEX, REV, CAPEX0] = pv_cashflow(P_dc_nom, P_ac_nom, E_togrid, E_toREC, E_saved, par)
%PV_CASHFLOW  CAPEX, OPEX, ricavi e flussi di cassa su tutta la vita utile.
%
%   [CF, CAPEX, OPEX, REV, CAPEX0] = PV_CASHFLOW(...) costruisce il profilo
%   di cassa dell'impianto:
%     anno 0            -> solo investimento iniziale
%     anni 1..lifetime  -> OPEX crescente con l'inflazione,
%                          ricavi crescenti con l'escalation del prezzo energia
%
%   I ricavi sommano tre voci: vendita in rete, cessione alla CER
%   (prezzo di vendita + incentivo) e risparmio da autoconsumo.
%
%   INPUT
%     P_dc_nom  scalare  potenza DC installata [kWp]
%     P_ac_nom  scalare  potenza AC installata [kWac]
%     E_togrid  scalare  energia annua ceduta in rete [MWh]
%     E_toREC   scalare  energia annua ceduta alla CER [MWh]
%     E_saved   scalare  energia annua autoconsumata [MWh]
%     par       struct   c_mod, c_BOP, c_inv, c_eng_inst, c_interconn,
%                        c_fixed, c_om, c_om_fixed, infl, r_en,
%                        p_en_sell, p_en_purch, p_en_REC, lifetime
%
%   OUTPUT
%     CF      [1 x lifetime+1]  flusso di cassa netto per anno
%     CAPEX   [1 x lifetime+1]  investimento per anno
%     OPEX    [1 x lifetime+1]  costi operativi per anno
%     REV     [1 x lifetime+1]  ricavi per anno
%     CAPEX0  scalare           investimento iniziale [EUR]

    CAPEX0 = ((par.c_mod + par.c_BOP) * P_dc_nom + par.c_inv * P_ac_nom) ...
             * (1 + par.c_eng_inst) ...
             + par.c_interconn * min(P_dc_nom, P_ac_nom) ...
             + par.c_fixed;

    y = 0:par.lifetime;                       % Anno 0 .. anno lifetime

    CAPEX = [CAPEX0, zeros(1, par.lifetime)];

    % OPEX e ricavi nulli all'anno 0 (impianto non ancora in esercizio)
    OPEX = [0, (par.c_om * P_dc_nom/1000 + par.c_om_fixed) * (1 + par.infl).^y(2:end)];

    REV_y1 = E_togrid * par.p_en_sell ...
           + E_toREC  * (par.p_en_sell + par.p_en_REC) ...
           + E_saved  * par.p_en_purch;
    REV = [0, REV_y1 * (1 + par.r_en).^y(2:end)];

    CF = REV - CAPEX - OPEX;
end
