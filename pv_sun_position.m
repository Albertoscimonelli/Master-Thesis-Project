function sun = pv_sun_position(hours_vet, lat, long, STZ)
%PV_SUN_POSITION  Posizione solare oraria per un anno intero.
%
%   sun = PV_SUN_POSITION(hours_vet, lat, long, STZ) calcola in forma
%   vettoriale declinazione, equazione del tempo, ora solare vera, angolo
%   orario, angolo zenitale, azimut e altezza solare per tutte le ore.
%
%   La posizione solare non dipende ne' dall'inclinazione dei moduli ne'
%   dal layout dell'impianto: va calcolata UNA SOLA VOLTA e riusata per
%   tutte le configurazioni esaminate.
%
%   INPUT
%     hours_vet  [1 x N]  indici orari progressivi (1..8760)
%     lat        scalare  latitudine [gradi N]
%     long       scalare  longitudine [gradi E]
%     STZ        scalare  fuso orario di riferimento rispetto a UTC [h]
%
%   OUTPUT
%     sun  struct con campi [1 x N]:
%          n_day, delta, E_n, t_s, omega, theta_z, gamma_s, alpha_s

    n_day = ceil(hours_vet / 24);            % Giorno dell'anno (1..365)

    % Declinazione solare [gradi]
    sun.delta = 23.45 * sind(360/365 * (n_day + 284));

    % Equazione del tempo [min]
    sun.E_n = 229.18 * (0.000075 ...
              + 0.001868*cosd(360*(n_day-1)/365) ...
              - 0.032770*sind(360*(n_day-1)/365) ...
              - 0.014615*cosd(2*360*(n_day-1)/365) ...
              - 0.040800*sind(2*360*(n_day-1)/365));

    % Ora solare vera [h] e angolo orario [gradi]
    sun.t_s   = (hours_vet - (n_day-1)*24) + (long - STZ*15)/15 + sun.E_n/60;
    sun.omega = 15 * (sun.t_s - 12);

    % Clamp del dominio di acosd. L'argomento e' matematicamente in [-1,1], ma a
    % latitudini dove il sole si avvicina allo zenit l'arrotondamento puo'
    % portarlo appena oltre, e acosd restituisce allora un angolo COMPLESSO che
    % si propaga in G_tot e P_dc senza un avviso. Misurato a 45.96N sull'anno
    % intero: theta_z in [-0.9235, 0.9231] e gamma_s esattamente in [-1, 1], zero
    % ore complesse. Il clamp non cambia quindi un solo valore qui - protegge un
    % cambio di sito, e costa nulla.
    clamp = @(x) min(max(x, -1), 1);

    % Angolo zenitale [gradi]
    sun.theta_z = acosd( clamp( sind(sun.delta)*sind(lat) ...
                              + cosd(sun.delta)*cosd(lat) .* cosd(sun.omega) ));

    % Azimut solare [gradi], in [0,180]: acosd PERDE IL SEGNO, cioe' la
    % distinzione mattina/pomeriggio, che sta nel segno di sun.omega e che qui
    % non viene mai ripristinato.
    %
    % Oggi e' innocuo, e va detto perche' non lo resti: pv_poa_tcell usa
    % cosd(gamma_s) su una falda esposta a sud, e il coseno e' una funzione PARI,
    % quindi il segno non conta. Ma le schede dichiarano gia' una colonna azimut
    % in [IMPIANTI] (oggi tutta a '?'). CHI LA ATTIVERA' scrivera'
    % cosd(gamma_s - azimut), e li' il segno conta: senza  .* sign(sun.omega)
    % l'irradianza sara' sbagliata ogni mattina, senza che nulla protesti.
    sun.gamma_s = acosd( clamp( (cosd(sun.theta_z)*sind(lat) - sind(sun.delta)) ...
                              ./ (cosd(90 - sun.theta_z)*cosd(lat)) * sign(lat) ));

    % Altezza solare [gradi]
    sun.alpha_s = 90 - sun.theta_z;

    sun.n_day = n_day;
end
