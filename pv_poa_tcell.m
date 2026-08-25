function [G_tot, T_c] = pv_poa_tcell(tilt_deg, sun, DNI, DIFF, T_amb, rho_g, NOCT)
%PV_POA_TCELL  Irradianza sul piano inclinato e temperatura di cella.
%
%   [G_tot, T_c] = PV_POA_TCELL(tilt_deg, sun, DNI, DIFF, T_amb, rho_g, NOCT)
%   restituisce, per tutte le ore dell'anno in una sola chiamata vettoriale,
%   l'irradianza totale sul piano dei moduli (modello di cielo isotropico) e
%   la temperatura di cella (modello NOCT).
%
%   Dipende solo dall'inclinazione: va quindi calcolata una volta per ogni
%   valore di tilt, non per ogni configurazione.
%
%   I coseni sono clampati a zero per evitare contributi negativi quando il
%   sole e' dietro al modulo (theta > 90 gradi) o sotto l'orizzonte
%   (theta_z > 90 gradi).
%
%   INPUT
%     tilt_deg  scalare        inclinazione moduli [gradi]
%     sun       struct         theta_z, gamma_s [1 x N], da pv_sun_position
%     DNI       [1 x N]        irradianza diretta normale [W/m2]
%     DIFF      [1 x N]        irradianza diffusa orizzontale [W/m2]
%     T_amb     [1 x N]        temperatura ambiente [C]
%     rho_g     scalare        albedo del suolo [-]
%     NOCT      scalare        Nominal Operating Cell Temperature [C]
%
%   OUTPUT
%     G_tot  [1 x N]  irradianza sul piano inclinato, senza ombra [W/m2]
%     T_c    [1 x N]  temperatura di cella [C]

    % Angolo di incidenza sul piano del modulo
    theta = acosd( cosd(sun.theta_z)*cosd(tilt_deg) ...
                 + sind(sun.theta_z)*sind(tilt_deg) .* cosd(sun.gamma_s) );

    cosTheta  = max(0, cosd(theta));
    cosThetaZ = max(0, cosd(sun.theta_z));

    % Diretta + diffusa isotropica + riflessa dal suolo
    G_tot = DNI .* cosTheta ...
          + DIFF * (1 + cosd(tilt_deg)) / 2 ...
          + (DNI .* cosThetaZ + DIFF) * rho_g * (1 - cosd(tilt_deg)) / 2;

    % Temperatura di cella: dipende da G_tot (irradianza sul piano), non da G_av
    T_c = T_amb + (NOCT - 20) / 800 * G_tot;
end
