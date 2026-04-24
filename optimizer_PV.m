% =========================================================================
%  optimizer_PV.m
%
%  Ottimizzazione di un impianto fotovoltaico su copertura industriale.
%
%  Logica generale:
%    1. Definizione dei parametri di input (geometria, moduli, inverter,
%       dati meteo, consumi, parametri economici)
%    2. Loop di ottimizzazione su tre variabili decisionali:
%         - N_inv  : numero di inverter  (dimensiona la potenza AC)
%         - tilt   : inclinazione dei moduli [°]
%         - D_rtr  : distanza inter-fila [m]
%       Per ogni combinazione si calcola:
%         a) Layout fisico dell'impianto (numero moduli, stringing)
%         b) Verifica di fattibilità elettrica (tensioni/correnti MPPT)
%         c) Simulazione oraria annuale (posizione solare, ombreggiamento,
%            produzione DC/AC, bilancio energetico con i consumi)
%         d) Analisi economica (CAPEX, OPEX, ricavi, flussi di cassa,
%            IRR e NPV su tutta la vita utile)
%    3. Identificazione della configurazione ottimale (max IRR o max NPV)
%       e grafici 3D dello spazio delle soluzioni
%    4. Ri-simulazione della configurazione ottimale e plot operativo
%       su un sottoinsieme di ore significative
%
%  KPI selezionabile:  KPI=0 → IRR   |   KPI=1 → NPV
%  Modalità consumo:   REC=0 → solo autoconsumo edificio
%                      REC=1 → solo cessione a Comunità Energetica (CER)
%                      REC=2 → autoconsumo + CER
%                      REC=3 → solo rete (benchmark)
% =========================================================================

clear all
clc
close all

%% =========================================================================
%  1) PERCORSI FILE
% =========================================================================
% File TMY (Typical Meteorological Year) scaricato da PVGIS.
% Formato: time(UTC);T2m;RH;G(h);Gb(n);Gd(h);IR(h);WS10m;WD10m;SP
loadFile = "C:\Users\scimo\OneDrive\Desktop\PoliMi\Tesi\tmy_45.464_9.190_2005_2023.csv";

% File dei profili di carico (risoluzione oraria, 8760 righe/anno,
% valori in kWh per ora; generati da generate_load_profiles.py).
% Colonne: timestamp, office_1_kWh, small_industry_1_kWh, small_industry_2_kWh,
%          retail_1_kWh, household_1_kWh, household_2_kWh, household_3_kWh
profilesFile = "C:\Users\scimo\desktop\Project\CER_LoadProfiles\outputs\csv\profili_tutti.csv";

%% =========================================================================
%  2) PARAMETRI DI INPUT
% =========================================================================

% --- Geometria copertura -----------------------------------------------
L_r     = 100;   % Lunghezza copertura [m]
W_r     = 60;    % Larghezza copertura [m]
d_edge  = 1.4;   % Margine perimetrale libero [m]
rho_g   = 0.3;   % Albedo del suolo [-] (usato per irradianza riflessa)

% --- Localizzazione sito -----------------------------------------------
lat  = 45.462;   % Latitudine [°N]  (Milano)
long = 9.19;     % Longitudine [°E]
STZ  = 1;        % Standard Time Zone rispetto a UTC [h]

% --- Modulo fotovoltaico -----------------------------------------------
L_m          = 1.69;     % Lunghezza modulo [m]
W_m          = 1.046;    % Larghezza modulo [m]
P_stc_mod    = 400;      % Potenza nominale STC [Wp]
V_oc         = 75.6;     % Tensione a circuito aperto a STC [V]
V_mpp        = 65.8;     % Tensione al MPP a STC [V]
I_sc         = 6.58;     % Corrente di corto circuito a STC [A]
I_mpp        = 6.08;     % Corrente al MPP a STC [A]
power_coeff  = -0.0029;  % Coefficiente di temperatura sulla potenza [1/°C]
current_coeff =  2.9e-3; % Coefficiente di temperatura sulla corrente [A/°C]
voltage_coeff = -176.8e-3; % Coefficiente di temperatura sulla tensione [V/°C]
NOCT         = 45;       % Nominal Operating Cell Temperature [°C]

% --- Inverter ----------------------------------------------------------
P_ac_inv     = 250;   % Potenza nominale AC per inverter [kWac]
V_max_inv    = 1500;  % Tensione massima in ingresso all'inverter [V]
V_max_mppt   = 1300;  % Tensione massima finestra MPPT [V]
V_min_mppt   = 860;   % Tensione minima finestra MPPT [V]
N_mppt       = 12;    % Numero di ingressi MPPT per inverter
I_max_mppt   = 30;    % Corrente massima per ingresso MPPT [A]
I_sc_max_mppt= 50;    % Corrente di cortocircuito massima per ingresso MPPT [A]
eta_inv      = 0.988; % Rendimento inverter [-]

% --- Dati meteorologici (PVGIS TMY) ------------------------------------
WD    = readtable(loadFile, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
DNI   = table2array(WD(1:8760, 5));  % Gb(n): irradianza diretta normale [W/m²]
DIFF  = table2array(WD(1:8760, 6));  % Gd(h): irradianza diffusa orizzontale [W/m²]
T_amb = table2array(WD(1:8760, 2));  % T2m:   temperatura ambiente [°C]

% --- Perdite di sistema ------------------------------------------------
DC_losses = 0.1;   % Perdite lato DC (cablaggio, mismatch, sporco) [-]
AC_losses = 0.05;  % Perdite lato AC (trasformatore, cablaggio) [-]

% --- Profili di consumo annuali (8760 valori, uno per ora) -------------
% Il CSV e' gia' aggregato a risoluzione oraria dallo script Python:
%   - 8760 righe/anno
%   - Valori in kWh consumati in quell'ora
%     (numericamente equivalenti alla potenza media [kW] di quell'ora)
% build_cons_data: consumo dell'edificio (small_industry_1) [kWh/h ≡ kW]
% REC_cons_data:   somma degli altri utenti della CER       [kWh/h ≡ kW]
PT = readtable(profilesFile, 'VariableNamingRule', 'preserve');

% Colonna small_industry_1_kWh -> edificio; le altre numeriche -> CER (somma)
numColsPT   = varfun(@isnumeric, PT, 'OutputFormat', 'uniform');
allNumNames = PT.Properties.VariableNames(numColsPT);
buildColIdx = strcmp(allNumNames, 'small_industry_1_kWh');
otherIdx    = ~buildColIdx;

build_cons_data = double(PT{:, allNumNames{buildColIdx}})';          % [1 x N]
REC_cons_data   = sum(double(PT{:, allNumNames(otherIdx)}), 2)';     % [1 x N]

% Garantisci esattamente 8760 valori: padding con ultimo valore o troncamento
nH = length(build_cons_data);
if nH < 8760
    fprintf('NOTA: CSV profili ha %d ore (attese 8760), padding con ultimo valore.\n', nH);
    build_cons_data(end+1:8760) = build_cons_data(end);
    REC_cons_data  (end+1:8760) = REC_cons_data(end);
elseif nH > 8760
    build_cons_data = build_cons_data(1:8760);
    REC_cons_data   = REC_cons_data(1:8760);
end

% --- Parametri economici -----------------------------------------------
c_mod       = 180;      % Costo moduli [€/kWp]
c_inv       = 50;       % Costo inverter [€/kWac]
c_BOP       = 270;      % Balance of Plant (strutture, cablaggio DC) [€/kWp]
c_eng_inst  = 0.4;      % Costi di ingegneria e installazione [% del TEC]
c_interconn = 50;       % Costo di allacciamento rete [€/kWac]
c_fixed     = 50000;    % Costi fissi di progetto [€]
c_om        = 10000;    % Costi O&M variabili [€/MWp/anno]
c_om_fixed  = 5000;     % Costi O&M fissi [€/anno]
infl        = 0.05;     % Tasso di inflazione annuo (OPEX) [-]
r_disc      = 0.04;     % Tasso di sconto di mercato (WACC) [-]
r_en        = 0.03;     % Escalation annua prezzo dell'energia [-]
p_en_purch  = 220;      % Prezzo energia acquistata dalla rete [€/MWh]
p_en_sell   = 100;      % Prezzo energia venduta in rete [€/MWh]
p_en_REC    = 110 * 0.3;% Incentivo CER (tariffa incentivante) [€/MWh]
lifetime    = 30;       % Vita utile impianto [anni]

% --- Variabili di ottimizzazione (spazio di ricerca) -------------------
N_inv_vet = 1:4;       % Numero inverter (limite: 4 × 250 kWac = 1000 kWac)
D_rtr_vet = 0:0.5:7;  % Distanza inter-fila [m]
tilt_vet  = 0:5:40;   % Inclinazione moduli [°]

% --- Selettori di scenario ---------------------------------------------
REC = 2;  % 0=autoconsumo | 1=solo CER | 2=autoconsumo+CER | 3=solo rete
KPI = 0;  % 0=ottimizza IRR | 1=ottimizza NPV

%% =========================================================================
%  3) INIZIALIZZAZIONE ARRAY
%  Tutti gli array temporali (8760 ore) e 3D (N_inv × tilt × D_rtr) vengono
%  pre-allocati a zero per evitare crescita dinamica nel loop.
% =========================================================================

hours_vet = 1:8760;
N = length(hours_vet);

% Variabili orarie (scalari per ogni ora dell'anno)
delta    = zeros(1, N);   % Declinazione solare [°]
E_n      = zeros(1, N);   % Equazione del tempo [min]
t_s      = zeros(1, N);   % Ora solare vera [h]
omega    = zeros(1, N);   % Angolo orario [°]
theta_z  = zeros(1, N);   % Angolo zenitale solare [°]
gamma_s  = zeros(1, N);   % Azimut solare [°]
theta    = zeros(1, N);   % Angolo di incidenza sul piano del modulo [°]
G_tot    = zeros(1, N);   % Irradianza totale sul piano inclinato (senza ombra) [W/m²]
alpha_s  = zeros(1, N);   % Altezza solare [°]
s        = zeros(1, N);   % Ombra proiettata dal modulo anteriore sul posteriore [m]
A_active = zeros(1, N);   % Area attiva (non ombreggiata) del campo [m²]
G_av     = zeros(1, N);   % Irradianza media effettiva sul campo (con ombra) [W/m²]
T_c      = zeros(1, N);   % Temperatura di cella [°C]
P_dc     = zeros(1, N);   % Potenza DC lorda [kW]
P_dc_net = zeros(1, N);   % Potenza DC netta (dopo perdite DC) [kW]
P_ac     = zeros(1, N);   % Potenza AC prima delle perdite AC [kW]
P_ac_net = zeros(1, N);   % Potenza AC netta immessa (dopo perdite AC e clipping) [kW]
P_purch  = zeros(1, N);   % Potenza acquistata dalla rete [kW]
P_togrid = zeros(1, N);   % Potenza ceduta alla rete [kW]
P_toREC  = zeros(1, N);   % Potenza ceduta alla CER [kW]
P_cons   = zeros(1, N);   % Consumo dell'edificio [kW]
P_REC    = zeros(1, N);   % Domanda CER nell'ora [kW]

% Dimensioni dello spazio di ottimizzazione
sz = [length(N_inv_vet), length(tilt_vet), length(D_rtr_vet)];

% Risultati fisici per ogni configurazione
tilt           = zeros(sz);
D_rtr          = zeros(sz);
N_rows         = zeros(sz);   % Numero di file di moduli
N_mod_rows     = zeros(sz);   % Numero di moduli per fila
N_mod          = zeros(sz);   % Numero totale di moduli
P_dc_nom       = zeros(sz);   % Potenza DC nominale [kWp]
P_ac_nom       = zeros(sz);   % Potenza AC nominale [kWac]
N_mod_string   = zeros(sz);   % Moduli per stringa (limite tensione)
unfeasible_conf= zeros(sz);   % Flag: 1 se la config viola i limiti inverter
eta_shad       = zeros(sz);   % Efficienza di ombreggiamento annuale [-]
h_eq           = zeros(sz);   % Ore equivalenti AC [kWh/kWp]
h_eq_dc        = zeros(sz);   % Ore equivalenti DC [kWh/kWp]
DCAC           = zeros(sz);   % Rapporto DC/AC [-]

% Risultati energetici annuali [MWh]
E_purch  = zeros(sz);
E_toREC  = zeros(sz);
E_togrid = zeros(sz);
E_saved  = zeros(sz);

% Risultati economici
CAPEX0 = zeros(sz);   % Investimento iniziale [€]
IRR    = zeros(sz);   % Internal Rate of Return [-]
NPV    = zeros(sz);   % Net Present Value [€]

% Flussi di cassa (vettori per un singolo anno di calcolo)
CAPEX = zeros(1, lifetime + 1);
OPEX  = zeros(1, lifetime + 1);
REV   = zeros(1, lifetime + 1);
CF    = zeros(1, lifetime + 1);

% Selezione profilo di consumo in base alla modalità REC
if REC == 0
    build_cons = build_cons_data;
    REC_cons   = zeros(1, 8760);
elseif REC == 1
    build_cons = zeros(1, 8760);
    REC_cons   = REC_cons_data;
elseif REC == 2
    build_cons = build_cons_data;
    REC_cons   = REC_cons_data;
else  % REC == 3: solo rete, nessun consumo locale
    build_cons = zeros(1, 8760);
    REC_cons   = zeros(1, 8760);
end

%% =========================================================================
%  4) LOOP DI OTTIMIZZAZIONE
%  Iterazione su tutte le combinazioni (N_inv, tilt, D_rtr).
%  Per ogni configurazione:
%    4a) Layout impianto
%    4b) Verifica stringing (compatibilità moduli-inverter)
%    4c) Simulazione oraria (posizione sole → irradianza → produzione → bilancio)
%    4d) Analisi economica e calcolo KPI
% =========================================================================

% Precomputo T_cell e limiti di stringing: non dipendono da (i,j,k), quindi
% calcolati una sola volta fuori dal loop per efficienza.
T_cell_max = max(T_amb) + (NOCT - 25) / 800 * 1000;
T_cell_min = min(T_amb);
V_oc_Tmin  = V_oc  + voltage_coeff * (T_cell_min - 25);
V_mpp_Tmin = V_mpp + voltage_coeff * (T_cell_min - 25);
I_mpp_Tmax = I_mpp + current_coeff  * (T_cell_max - 25);
I_sc_Tmax  = I_sc  + current_coeff  * (T_cell_max - 25);
N_mod_string_oc  = floor(V_max_inv  / V_oc_Tmin);
N_mod_string_mpp = floor(V_max_mppt / V_mpp_Tmin);
N_mod_string_lim = min(N_mod_string_oc, N_mod_string_mpp);

% Contatore configurazioni con cambi di segno multipli nei CF (→ IRR con radici multiple)
n_multIRR = 0;

% Disattivo temporaneamente i warning durante il loop (restorati al termine)
warnState = warning('off','all');

for i = 1:length(N_inv_vet)
    for j = 1:length(tilt_vet)
        for k = 1:length(D_rtr_vet)

            tilt(i,j,k)  = tilt_vet(j);
            D_rtr(i,j,k) = D_rtr_vet(k);

            % -----------------------------------------------------------------
            % 4a) Layout fisico dell'impianto
            %     Quante file e quanti moduli per fila entrano sul tetto,
            %     tenendo conto dell'ingombro dei moduli inclinati e della
            %     distanza inter-fila necessaria a ridurre le ombre.
            % -----------------------------------------------------------------
            N_rows(i,j,k)     = floor((L_r - 2*d_edge) / (W_m*cosd(tilt(i,j,k)) + D_rtr(i,j,k)));
            N_mod_rows(i,j,k) = floor((W_r - 2*d_edge) / L_m);
            N_mod(i,j,k)      = N_rows(i,j,k) * N_mod_rows(i,j,k);
            P_dc_nom(i,j,k)   = N_mod(i,j,k) * P_stc_mod / 1000;   % [kWp]
            P_ac_nom(i,j,k)   = N_inv_vet(i)  * P_ac_inv;           % [kWac]

            % Se non entra nessun modulo sul tetto, configurazione non fattibile
            if N_mod(i,j,k) == 0
                unfeasible_conf(i,j,k) = 1;
                IRR(i,j,k)  = NaN;
                DCAC(i,j,k) = NaN;
                NPV(i,j,k)  = NaN;
                h_eq(i,j,k) = NaN;
                h_eq_dc(i,j,k) = NaN;
                continue;
            end

            % -----------------------------------------------------------------
            % 4b) Verifica compatibilità moduli-inverter (stringing)
            %     Si calcola il numero massimo di moduli per stringa e il
            %     numero massimo di stringhe per ingresso MPPT rispettando:
            %       - Tensione massima inverter (condizione Voc a T minima)
            %       - Finestra MPPT (condizione Vmpp a T minima)
            %       - Corrente massima per ingresso MPPT (T massima)
            % -----------------------------------------------------------------
            N_mod_string(i,j,k) = N_mod_string_lim;

            % Stringhe massime per ingresso MPPT
            N_strings_mpp_max = ceil(N_mod(i,j,k) / N_mod_string(i,j,k) / N_inv_vet(i) / N_mppt);
            I_mpp_max_mpp     = N_strings_mpp_max * I_mpp_Tmax;
            I_mpp_max_sc      = N_strings_mpp_max * I_sc_Tmax;

            % Configurazione non fattibile se supera i limiti di corrente MPPT
            if I_mpp_max_mpp >= I_max_mppt || I_mpp_max_sc >= I_sc_max_mppt
                unfeasible_conf(i,j,k) = 1;
            end

            % -----------------------------------------------------------------
            % 4c) Simulazione oraria annuale (8760 ore)
            %
            %  Per ogni ora h:
            %   i)   Posizione solare: declinazione, angolo orario, zenitale,
            %        azimut, altezza solare
            %   ii)  Irradianza sul piano inclinato (modello isotropico):
            %        G_tot = componente diretta + diffusa + riflessa
            %   iii) Ombreggiamento inter-fila:
            %        calcolo della lunghezza d'ombra proiettata e dell'area
            %        attiva (non ombreggiata) del campo
            %   iv)  Produzione DC: modello lineare con correzione termica
            %   v)   Produzione AC: clipping all'inverter + perdite AC
            %   vi)  Bilancio energetico orario edificio / CER / rete
            % -----------------------------------------------------------------
            for h = 1:length(hours_vet)

                n = ceil(h / 24);   % Giorno dell'anno corrispondente all'ora h

                % -- Posizione solare --
                delta(h)   = 23.45 * sind(360/365 * (n + 284));
                E_n(h)     = 229.18 * (0.000075 ...
                             + 0.001868*cosd(360*(n-1)/365) ...
                             - 0.032770*sind(360*(n-1)/365) ...
                             - 0.014615*cosd(2*360*(n-1)/365) ...
                             - 0.040800*sind(2*360*(n-1)/365));
                t_s(h)     = (h - (n-1)*24) + (long - STZ*15)/15 + E_n(h)/60;
                omega(h)   = 15 * (t_s(h) - 12);
                theta_z(h) = acosd(sind(delta(h))*sind(lat) + cosd(delta(h))*cosd(lat)*cosd(omega(h)));
                gamma_s(h) = acosd((cosd(theta_z(h))*sind(lat) - sind(delta(h))) ...
                             / (cosd(90 - theta_z(h))*cosd(lat)) * sign(lat));
                theta(h)   = acosd(cosd(theta_z(h))*cosd(tilt(i,j,k)) ...
                             + sind(theta_z(h))*sind(tilt(i,j,k))*cosd(gamma_s(h)));

                % -- Irradianza sul piano inclinato (componente diretta + diffusa + riflessa) --
                % VECCHIA VERSIONE (non clampata - da verificare manualmente):
                % G_tot(h) = DNI(h) * cosd(theta(h)) ...
                %          + DIFF(h) * (1 + cosd(tilt(i,j,k))) / 2 ...
                %          + (DNI(h)*cosd(theta_z(h)) + DIFF(h)) * rho_g * (1 - cosd(tilt(i,j,k))) / 2;

                % NUOVA VERSIONE (clampata): evita contributi negativi quando
                % il sole è dietro al modulo (theta>90°) o sotto l'orizzonte (theta_z>90°)
                cosTheta_h  = max(0, cosd(theta(h)));
                cosThetaZ_h = max(0, cosd(theta_z(h)));
                G_tot(h) = DNI(h) * cosTheta_h ...
                         + DIFF(h) * (1 + cosd(tilt(i,j,k))) / 2 ...
                         + (DNI(h)*cosThetaZ_h + DIFF(h)) * rho_g * (1 - cosd(tilt(i,j,k))) / 2;

                alpha_s(h) = 90 - theta_z(h);   % Altezza solare [°]

                % -- Ombreggiamento inter-fila --
                % x: proiezione orizzontale dell'ombra oltre la fila successiva
                x = W_m*sind(tilt(i,j,k))/tand(alpha_s(h)) + W_m*cosd(tilt(i,j,k)) ...
                    - (D_rtr(i,j,k) + W_m*cosd(tilt(i,j,k)));

                if alpha_s(h) <= 0
                    % Sole sotto l'orizzonte: modulo completamente ombreggiato
                    s(h)        = W_m;
                    A_active(h) = 0;
                else
                    s(h) = min([W_m, max([0, (x*sind(alpha_s(h))) / sind(180 - alpha_s(h) - tilt(i,j,k))])]);
                    % Area attiva = parte non ombreggiata su tutte le file
                    A_active(h) = ((W_m - s(h)) * (N_rows(i,j,k) - 1) + W_m) * N_mod_rows(i,j,k) * L_m;
                end

                % Irradianza media effettiva sull'intero campo (pesata sull'area attiva)
                G_av(h) = G_tot(h) / (N_mod(i,j,k) * L_m * W_m) * A_active(h);

                % -- Temperatura di cella e produzione DC --
                % Ipotesi: la temperatura di cella dipende da G_tot (non da G_av)
                T_c(h)     = T_amb(h) + (NOCT - 20) / 800 * G_tot(h);
                P_dc(h)    = G_av(h)/1000 * P_stc_mod * (1 + power_coeff*(T_c(h) - 25)) * N_mod(i,j,k) / 1000;
                P_dc_net(h)= P_dc(h) * (1 - DC_losses);

                % -- Conversione AC e clipping all'inverter --
                P_ac(h)    = min([P_dc_net(h) * eta_inv, P_ac_nom(i,j,k)]);
                P_ac_net(h)= P_ac(h) * (1 - AC_losses);

                % -- Bilancio energetico orario --
                % Priorità: 1° autoconsumo edificio, 2° cessione CER, 3° rete
                P_cons(h) = build_cons(h);
                P_REC(h)  = REC_cons(h);

                if P_ac_net(h) < P_cons(h)
                    % Produzione insufficiente: acquisto dalla rete
                    P_purch(h)  = P_cons(h) - P_ac_net(h);
                    P_toREC(h)  = 0;
                    P_togrid(h) = 0;
                else
                    surplus = P_ac_net(h) - P_cons(h);
                    if surplus < P_REC(h)
                        % Surplus copre parzialmente la domanda CER
                        P_purch(h)  = 0;
                        P_toREC(h)  = surplus;
                        P_togrid(h) = 0;
                    else
                        % Surplus eccede la domanda CER: resto va in rete
                        P_purch(h)  = 0;
                        P_toREC(h)  = P_REC(h);
                        P_togrid(h) = surplus - P_REC(h);
                    end
                end

            end % fine loop ore

            % -- Indicatori energetici annuali --
            eta_shad(i,j,k) = sum(G_av) / sum(G_tot);          % Efficienza ombreggiamento
            E_dc            = sum(P_dc)     / 1000;             % Energia DC lorda [MWh]
            E_ac_net        = sum(P_ac_net) / 1000;             % Energia AC netta [MWh]
            clipping_losses = sum(P_dc_net)/1000 * eta_inv * (1 - AC_losses) - E_ac_net;
            E_purch(i,j,k)  = sum(P_purch)  / 1000;            % Energia acquistata [MWh]
            E_toREC(i,j,k)  = sum(P_toREC)  / 1000;            % Energia ceduta CER [MWh]
            E_togrid(i,j,k) = sum(P_togrid) / 1000;            % Energia ceduta rete [MWh]
            E_saved(i,j,k)  = sum(P_cons)   / 1000 - E_purch(i,j,k); % Energia autoconsumata [MWh]
            h_eq(i,j,k)     = E_ac_net / P_dc_nom(i,j,k) * 1000;    % Ore equivalenti AC [h]
            h_eq_dc(i,j,k)  = E_dc     / P_dc_nom(i,j,k) * 1000;    % Ore equivalenti DC [h]

            % -----------------------------------------------------------------
            % 4d) Analisi economica: CAPEX, OPEX, Ricavi, Flussi di Cassa
            %
            %  Anno 0: solo investimento (CAPEX)
            %  Anni 1…lifetime: OPEX crescente con inflazione, ricavi costanti
            %  Ricavi = vendita in rete + incentivo CER + risparmio autoconsumo
            % -----------------------------------------------------------------
            CAPEX0(i,j,k) = ((c_mod + c_BOP) * P_dc_nom(i,j,k) + c_inv * P_ac_nom(i,j,k)) ...
                            * (1 + c_eng_inst) ...
                            + c_interconn * min([P_dc_nom(i,j,k), P_ac_nom(i,j,k)]) ...
                            + c_fixed;

            for y = 1:lifetime + 1
                if y == 1
                    CAPEX(y) = CAPEX0(i,j,k);
                    OPEX(y)  = 0;
                    REV(y)   = 0;
                else
                    CAPEX(y) = 0;
                    OPEX(y)  = (c_om * P_dc_nom(i,j,k)/1000 + c_om_fixed) * (1 + infl)^(y-1);
                    % Ricavi con escalation annua del prezzo dell'energia
                    REV(y)   = ( E_togrid(i,j,k) * p_en_sell ...
                               + E_toREC(i,j,k)  * (p_en_sell + p_en_REC) ...
                               + E_saved(i,j,k)  * p_en_purch ) * (1 + r_en)^(y-1);
                end
                CF(y) = REV(y) - CAPEX(y) - OPEX(y);
            end

            % -- KPI finanziari --
            if unfeasible_conf(i,j,k) == 1 || any(~isfinite(CF))
                IRR(i,j,k)  = NaN;
                DCAC(i,j,k) = NaN;
                NPV(i,j,k)  = NaN;
                h_eq(i,j,k) = NaN;
                h_eq_dc(i,j,k) = NaN;
            else
                % Conta cambi di segno nei CF: >1 → IRR con radici multiple
                CF_nz = CF(CF ~= 0);
                if numel(CF_nz) > 1 && sum(diff(sign(CF_nz)) ~= 0) > 1
                    n_multIRR = n_multIRR + 1;
                end
                IRR(i,j,k)  = irr(CF);
                DCAC(i,j,k) = P_dc_nom(i,j,k) / P_ac_nom(i,j,k);
                % NPV attualizzato con tasso di sconto r_disc
                NPV(i,j,k)  = sum( CF ./ (1 + r_disc).^(0:lifetime) );
                h_eq(i,j,k) = E_ac_net / P_dc_nom(i,j,k) * 1000;
                h_eq_dc(i,j,k) = E_dc / P_dc_nom(i,j,k) * 1000;
            end

        end
    end
end

% Ripristino stato warning e stampa riassuntiva IRR multipli
warning(warnState);
if n_multIRR > 0
    fprintf('\nNOTA: %d configurazioni con cambi di segno multipli nei CF (IRR con possibili radici multiple).\n', n_multIRR);
end

%% =========================================================================
%  5) RISULTATI OTTIMIZZAZIONE E GRAFICI 3D DELLO SPAZIO DELLE SOLUZIONI
%  Superficie 3D (tilt × D_rtr) del KPI selezionato per tutti i valori di N_inv.
% =========================================================================

[TILT, D_RTR] = meshgrid(tilt_vet, D_rtr_vet);

if KPI == 0

    % --- Ottimizzazione IRR -----------------------------------------------
    [max_IRR, idx]   = max(IRR(:));
    [ind1, ind2, ind3] = ind2sub(size(IRR), idx);
    N_inv_optimal    = N_inv_vet(ind1);
    tilt_optimal     = tilt_vet(ind2);
    D_rtr_optimal    = D_rtr_vet(ind3);

    fprintf('\n=== Configurazione ottimale (IRR) ===\n');
    fprintf('  Tilt ottimale:   %.2f °\n',    tilt_optimal);
    fprintf('  D_rtr ottimale:  %.2f m\n',    D_rtr_optimal);
    fprintf('  N. inverter:     %d\n',        N_inv_optimal);
    fprintf('  N. pannelli:     %d\n',        N_mod(ind1,ind2,ind3));
    fprintf('  Potenza DC:      %.2f kWdc\n', P_dc_nom(ind1,ind2,ind3));
    fprintf('  Potenza AC:      %.2f kWac\n', P_ac_nom(ind1,ind2,ind3));
    fprintf('  DC/AC ratio:     %.2f\n',      DCAC(ind1,ind2,ind3));
    fprintf('  Ore equivalenti: %.2f kWh/kWp\n', h_eq(ind1,ind2,ind3));
    fprintf('  CAPEX:           %.2f k€\n',   CAPEX0(ind1,ind2,ind3)/1e3);
    fprintf('  IRR:             %.2f %%\n',   max_IRR * 100);
    fprintf('  NPV:             %.2f M€\n',   NPV(ind1,ind2,ind3)/1e6);

    % Superficie IRR per ogni numero di inverter (una tile per N_inv)
    IRR_surfs = cell(1, length(N_inv_vet));
    for ii = 1:length(N_inv_vet)
        IRR_surfs{ii} = permute(IRR(ii,:,:), [2 3 1])';
    end

    figure(1);
    tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'compact');
    for ii = 1:length(N_inv_vet)
        nexttile;
        surf(TILT, D_RTR, IRR_surfs{ii});
        xlabel('Tilt (°)'); ylabel('D_{rtr} (m)'); zlabel('IRR');
        title(sprintf('%d inverter', N_inv_vet(ii)));
        colorbar; view(45, 30); shading interp;
    end
    sgtitle('Spazio soluzioni – IRR');

else

    % --- Ottimizzazione NPV -----------------------------------------------
    [max_NPV, idx]   = max(NPV(:));
    [ind1, ind2, ind3] = ind2sub(size(NPV), idx);
    N_inv_optimal    = N_inv_vet(ind1);
    tilt_optimal     = tilt_vet(ind2);
    D_rtr_optimal    = D_rtr_vet(ind3);

    fprintf('\n=== Configurazione ottimale (NPV) ===\n');
    fprintf('  Tilt ottimale:   %.2f °\n',    tilt_optimal);
    fprintf('  D_rtr ottimale:  %.2f m\n',    D_rtr_optimal);
    fprintf('  N. inverter:     %d\n',        N_inv_optimal);
    fprintf('  N. pannelli:     %d\n',        N_mod(ind1,ind2,ind3));
    fprintf('  Potenza DC:      %.2f kWdc\n', P_dc_nom(ind1,ind2,ind3));
    fprintf('  Potenza AC:      %.2f kWac\n', P_ac_nom(ind1,ind2,ind3));
    fprintf('  DC/AC ratio:     %.2f\n',      DCAC(ind1,ind2,ind3));
    fprintf('  Ore equivalenti: %.2f kWh/kWp\n', h_eq(ind1,ind2,ind3));
    fprintf('  CAPEX:           %.2f k€\n',   CAPEX0(ind1,ind2,ind3)/1e3);
    fprintf('  IRR:             %.2f %%\n',   IRR(ind1,ind2,ind3)*100);
    fprintf('  NPV:             %.2f M€\n',   max_NPV/1e6);

    NPV_surfs = cell(1, length(N_inv_vet));
    for ii = 1:length(N_inv_vet)
        NPV_surfs{ii} = permute(NPV(ii,:,:), [2 3 1])' * 1e-6;
    end

    figure(1);
    tiledlayout('flow', 'TileSpacing', 'compact', 'Padding', 'compact');
    for ii = 1:length(N_inv_vet)
        nexttile;
        surf(TILT, D_RTR, NPV_surfs{ii});
        xlabel('Tilt (°)'); ylabel('D_{rtr} (m)'); zlabel('NPV (M€)');
        title(sprintf('%d inverter', N_inv_vet(ii)));
        colorbar; view(45, 30); shading interp;
    end
    sgtitle('Spazio soluzioni – NPV');

end

%% =========================================================================
%  6) GRAFICI 3D AUSILIARI (per N_inv fisso = N_inv_plot)
%  Visualizzazione di DC/AC ratio, ore equivalenti e CAPEX al variare di
%  tilt e distanza inter-fila, per un numero di inverter scelto.
% =========================================================================

N_inv_plot  = 2;   % Indice del numero di inverter da visualizzare
DCAC_plot   = permute(DCAC(N_inv_plot,:,:),   [2 3 1]);
h_eq_plot   = permute(h_eq(N_inv_plot,:,:),   [2 3 1]);
CAPEX0_plot = permute(CAPEX0(N_inv_plot,:,:), [2 3 1]);
h_eq_dc_plot= permute(h_eq_dc(N_inv_plot,:,:),[2 3 1]);

figure(2); hold on;
surf(TILT, D_RTR, DCAC_plot');
xlabel('Tilt (°)'); ylabel('D_{rtr} (m)'); zlabel('DC/AC ratio');
title('DC/AC ratio'); colorbar; view(45, 30);

figure(3); hold on;
surf(TILT, D_RTR, h_eq_plot');
xlabel('Tilt (°)'); ylabel('D_{rtr} (m)'); zlabel('Ore equivalenti [h]');
title('Ore equivalenti AC'); colorbar; view(45, 30);

figure(4); hold on;
surf(TILT, D_RTR, CAPEX0_plot');
xlabel('Tilt (°)'); ylabel('D_{rtr} (m)'); zlabel('CAPEX [€]');
title('CAPEX'); colorbar; view(45, 30);

%% =========================================================================
%  7) SIMULAZIONE OPERATIVA DELLA CONFIGURAZIONE OTTIMALE
%  Ri-simulazione con i parametri ottimali, usando variabili LOCALI (_opt)
%  per NON corrompere le matrici 3D dell'ottimizzazione.
% =========================================================================

tilt_opt  = tilt_optimal;
D_rtr_opt = D_rtr_optimal;
N_inv_opt = N_inv_optimal;

% Layout impianto (scalari)
N_rows_opt     = floor((L_r - 2*d_edge) / (W_m*cosd(tilt_opt) + D_rtr_opt));
N_mod_rows_opt = floor((W_r - 2*d_edge) / L_m);
N_mod_opt      = N_rows_opt * N_mod_rows_opt;
P_dc_nom_opt   = N_mod_opt * P_stc_mod / 1000;
P_ac_nom_opt   = N_inv_opt * P_ac_inv;

% Array orari locali (non riusare quelli del loop 4)
P_dc_opt     = zeros(1, N);
P_dc_net_opt = zeros(1, N);
P_ac_opt     = zeros(1, N);
P_ac_net_opt = zeros(1, N);
P_purch_opt  = zeros(1, N);
P_togrid_opt = zeros(1, N);
P_toREC_opt  = zeros(1, N);
P_cons_opt   = zeros(1, N);
P_REC_opt    = zeros(1, N);
G_tot_opt    = zeros(1, N);
G_av_opt     = zeros(1, N);
A_active_opt = zeros(1, N);
s_opt        = zeros(1, N);
T_c_opt      = zeros(1, N);

for h = 1:N
    n          = ceil(h / 24);
    delta_h    = 23.45 * sind(360/365 * (n + 284));
    E_n_h      = 229.18 * (0.000075 ...
                 + 0.001868*cosd(360*(n-1)/365) ...
                 - 0.032770*sind(360*(n-1)/365) ...
                 - 0.014615*cosd(2*360*(n-1)/365) ...
                 - 0.040800*sind(2*360*(n-1)/365));
    t_s_h      = (h - (n-1)*24) + (long - STZ*15)/15 + E_n_h/60;
    omega_h    = 15 * (t_s_h - 12);
    theta_z_h  = acosd(sind(delta_h)*sind(lat) + cosd(delta_h)*cosd(lat)*cosd(omega_h));
    gamma_s_h  = acosd((cosd(theta_z_h)*sind(lat) - sind(delta_h)) ...
                 / (cosd(90 - theta_z_h)*cosd(lat)) * sign(lat));
    theta_h    = acosd(cosd(theta_z_h)*cosd(tilt_opt) ...
                 + sind(theta_z_h)*sind(tilt_opt)*cosd(gamma_s_h));

    % VECCHIA VERSIONE (non clampata - da verificare manualmente):
    % G_tot_opt(h) = DNI(h)*cosd(theta_h) ...
    %              + DIFF(h)*(1 + cosd(tilt_opt))/2 ...
    %              + (DNI(h)*cosd(theta_z_h) + DIFF(h))*rho_g*(1 - cosd(tilt_opt))/2;

    % NUOVA VERSIONE (clampata)
    cosTheta_h  = max(0, cosd(theta_h));
    cosThetaZ_h = max(0, cosd(theta_z_h));
    G_tot_opt(h) = DNI(h)*cosTheta_h ...
                 + DIFF(h)*(1 + cosd(tilt_opt))/2 ...
                 + (DNI(h)*cosThetaZ_h + DIFF(h))*rho_g*(1 - cosd(tilt_opt))/2;

    alpha_s_h = 90 - theta_z_h;
    x = W_m*sind(tilt_opt)/tand(alpha_s_h) + W_m*cosd(tilt_opt) ...
        - (D_rtr_opt + W_m*cosd(tilt_opt));
    if alpha_s_h <= 0
        s_opt(h)        = W_m;
        A_active_opt(h) = 0;
    else
        s_opt(h) = min([W_m, max([0, (x*sind(alpha_s_h))/sind(180 - alpha_s_h - tilt_opt)])]);
        A_active_opt(h) = ((W_m - s_opt(h))*(N_rows_opt - 1) + W_m) * N_mod_rows_opt * L_m;
    end
    G_av_opt(h)     = G_tot_opt(h) / (N_mod_opt*L_m*W_m) * A_active_opt(h);
    T_c_opt(h)      = T_amb(h) + (NOCT - 20)/800 * G_tot_opt(h);
    P_dc_opt(h)     = G_av_opt(h)/1000 * P_stc_mod * (1 + power_coeff*(T_c_opt(h) - 25)) * N_mod_opt/1000;
    P_dc_net_opt(h) = P_dc_opt(h) * (1 - DC_losses);
    P_ac_opt(h)     = min([P_dc_net_opt(h)*eta_inv, P_ac_nom_opt]);
    P_ac_net_opt(h) = P_ac_opt(h) * (1 - AC_losses);
    P_cons_opt(h)   = build_cons(h);
    P_REC_opt(h)    = REC_cons(h);
    if P_ac_net_opt(h) < P_cons_opt(h)
        P_purch_opt(h)  = P_cons_opt(h) - P_ac_net_opt(h);
        P_toREC_opt(h)  = 0;
        P_togrid_opt(h) = 0;
    else
        surplus = P_ac_net_opt(h) - P_cons_opt(h);
        if surplus < P_REC_opt(h)
            P_purch_opt(h)  = 0;
            P_toREC_opt(h)  = surplus;
            P_togrid_opt(h) = 0;
        else
            P_purch_opt(h)  = 0;
            P_toREC_opt(h)  = P_REC_opt(h);
            P_togrid_opt(h) = surplus - P_REC_opt(h);
        end
    end
end

% Indicatori annuali della configurazione ottimale
E_dc_opt      = sum(P_dc_opt)     / 1000;
E_ac_net_opt  = sum(P_ac_net_opt) / 1000;
E_purch_opt   = sum(P_purch_opt)  / 1000;
E_toREC_opt   = sum(P_toREC_opt)  / 1000;
E_togrid_opt  = sum(P_togrid_opt) / 1000;
E_saved_opt   = sum(P_cons_opt)   / 1000 - E_purch_opt;

% CAPEX (formula coerente con loop 4: c_interconn sul minimo tra DC e AC)
CAPEX0_opt = ((c_mod + c_BOP)*P_dc_nom_opt + c_inv*P_ac_nom_opt) ...
             * (1 + c_eng_inst) ...
             + c_interconn * min([P_dc_nom_opt, P_ac_nom_opt]) ...
             + c_fixed;

% Flussi di cassa
CAPEX_opt = zeros(1, lifetime + 1);
OPEX_opt  = zeros(1, lifetime + 1);
REV_opt   = zeros(1, lifetime + 1);
CF_opt    = zeros(1, lifetime + 1);
for y = 1:lifetime + 1
    if y == 1
        CAPEX_opt(y) = CAPEX0_opt; OPEX_opt(y) = 0; REV_opt(y) = 0;
    else
        CAPEX_opt(y) = 0;
        OPEX_opt(y)  = (c_om*P_dc_nom_opt/1000 + c_om_fixed)*(1 + infl)^(y-1);
        % Ricavi con escalation annua del prezzo dell'energia
        REV_opt(y)   = ( E_togrid_opt*p_en_sell ...
                       + E_toREC_opt*(p_en_sell + p_en_REC) ...
                       + E_saved_opt*p_en_purch ) * (1 + r_en)^(y-1);
    end
    CF_opt(y) = REV_opt(y) - CAPEX_opt(y) - OPEX_opt(y);
end

IRR_opt = irr(CF_opt);
NPV_opt = sum( CF_opt ./ (1 + r_disc).^(0:lifetime) );

% --- Grafico flussi di cassa della configurazione ottimale ----------------
anni = 0:lifetime;
figure('Name', 'Flussi di cassa – Configurazione ottimale', 'Color', 'w');

subplot(2,1,1); hold on; grid on; box on;
bar(anni, [REV_opt(:), -OPEX_opt(:), -CAPEX_opt(:)], 'stacked');
plot(anni, CF_opt, 'k-o', 'LineWidth', 1.8, 'MarkerSize', 5, 'DisplayName', 'CF netto');
legend('Ricavi', 'OPEX', 'CAPEX', 'CF netto', 'Location', 'best');
xlabel('Anno'); ylabel('Flusso di cassa [€]');
title('Flussi di cassa annuali – Configurazione ottimale');

subplot(2,1,2); hold on; grid on; box on;
plot(anni, cumsum(CF_opt), 'b-o', 'LineWidth', 1.8, 'MarkerSize', 5);
yline(0, 'r--', 'LineWidth', 1.2);
xlabel('Anno'); ylabel('Flusso cumulato [€]');
title('Flusso di cassa cumulato (payback visivo)');

% Plot operativo su un sottoinsieme di ore (es. ore 4000-4100, ~metà giugno)
h_iniz = 4000;
h_fin  = 4100;
t_plot = hours_vet(h_iniz:h_fin) - h_iniz;

figure(11); hold on;
plot(t_plot, P_ac_net_opt(h_iniz:h_fin),                         'LineWidth', 1.5);
plot(t_plot, P_cons_opt(h_iniz:h_fin),                           'LineWidth', 1.5);
plot(t_plot, P_REC_opt(h_iniz:h_fin) + P_cons_opt(h_iniz:h_fin), 'LineWidth', 1.5);
plot(t_plot, P_toREC_opt(h_iniz:h_fin),                          'LineWidth', 1.5);
plot(t_plot, P_togrid_opt(h_iniz:h_fin),                         'LineWidth', 1.5);
legend('P_{ac,net}', 'P_{cons}', 'P_{cons} + P_{REC}', 'P_{to REC}', 'P_{to grid}', ...
       'Location', 'best');
xlabel('Tempo [h]');
ylabel('Potenza [kW]');
title(sprintf('Profilo operativo – configurazione ottimale (ore %d–%d)', h_iniz, h_fin));
grid on;

%% =========================================================================
%  8) PRODUZIONE PV vs CONSUMI AZIENDA – Annuale, Giugno, Giorno tipo
% =========================================================================

% Vettore temporale orario dell'anno (partendo dal 1 gennaio, ore 00:00)
t_year = datetime(2025,1,1,0,0,0) + hours(0:8759);

% --- 8a) Profilo annuale (media giornaliera per leggibilità) -------------
% Si raggruppano le 8760 ore in 365 giorni, calcolando la media oraria
% di produzione e consumo per ciascun giorno.
dayOfYear    = floor((hours_vet - 1) / 24) + 1;     % 1..365 per ogni ora
P_ac_net_day = accumarray(dayOfYear', P_ac_net_opt', [], @mean);
P_cons_day   = accumarray(dayOfYear', P_cons_opt',   [], @mean);

figure('Name', 'Produzione PV vs Consumi – Anno', 'Color', 'w');
hold on; grid on; box on;
area(1:365, P_ac_net_day, 'FaceAlpha', 0.35, 'FaceColor', [1 0.8 0], ...
     'EdgeColor', [0.9 0.6 0], 'DisplayName', 'Produzione PV');
plot(1:365, P_cons_day, 'Color', [0.1 0.3 0.7], 'LineWidth', 1.8, ...
     'DisplayName', 'Consumo edificio');
xlabel('Giorno dell''anno');
ylabel('Potenza media giornaliera [kW]');
title('Produzione PV vs Consumo edificio – Profilo annuale');
legend('Location', 'northwest');
xlim([1 365]);

% --- 8b) Mese di giugno (ore 3624–4343 → 1 giu 00:00 – 30 giu 23:00) ---
% Giugno: giorni 152–181, ore = (152-1)*24+1 = 3625 fino a 181*24 = 4344
h_jun_start = (152 - 1) * 24 + 1;   % ora 3625
h_jun_end   = 181 * 24;             % ora 4344
idx_jun     = h_jun_start:h_jun_end;
t_jun       = t_year(idx_jun);

figure('Name', 'Produzione PV vs Consumi – Giugno', 'Color', 'w');
hold on; grid on; box on;
area(t_jun, P_ac_net_opt(idx_jun), 'FaceAlpha', 0.35, 'FaceColor', [1 0.8 0], ...
     'EdgeColor', [0.9 0.6 0], 'DisplayName', 'Produzione PV');
plot(t_jun, P_cons_opt(idx_jun), 'Color', [0.1 0.3 0.7], 'LineWidth', 1.2, ...
     'DisplayName', 'Consumo edificio');
xlabel('Data');
ylabel('Potenza [kW]');
title('Produzione PV vs Consumo edificio – Giugno');
legend('Location', 'northwest');

% --- 8c) Giorno tipo (media oraria su tutto giugno) ----------------------
% Per ogni ora 0–23, si calcola la media della produzione e del consumo
% su tutti i 30 giorni di giugno → profilo "giorno tipo estivo".
hour_of_day_jun = mod(idx_jun - 1, 24);   % 0..23 ciclico
PV_daytype   = accumarray(hour_of_day_jun' + 1, P_ac_net_opt(idx_jun)', [], @mean);
Cons_daytype = accumarray(hour_of_day_jun' + 1, P_cons_opt(idx_jun)',   [], @mean);

figure('Name', 'Giorno tipo giugno – PV vs Consumi', 'Color', 'w');
hold on; grid on; box on;
area(0:23, PV_daytype, 'FaceAlpha', 0.35, 'FaceColor', [1 0.8 0], ...
     'EdgeColor', [0.9 0.6 0], 'DisplayName', 'Produzione PV');
plot(0:23, Cons_daytype, 'Color', [0.1 0.3 0.7], 'LineWidth', 2, ...
     'DisplayName', 'Consumo edificio');
xlabel('Ora del giorno [h]');
ylabel('Potenza media [kW]');
title('Giorno tipo – Giugno (media su 30 giorni)');
legend('Location', 'northwest');
xlim([0 23]);
xticks(0:2:23);
