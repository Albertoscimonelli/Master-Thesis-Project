% =========================================================================
%  optimizer_PV.m
%
%  Pre-dimensionamento di un impianto fotovoltaico su copertura.
%
%  Scopo: data una superficie disponibile, individuare il numero di moduli
%  e l'inclinazione che massimizzano il KPI economico, per poi riportare la
%  configurazione trovata in PVsyst. La simulazione e' volutamente "grezza":
%  serve una stima realistica della producibilita' annua, non un modello
%  di dettaglio.
%
%  Logica generale:
%    1. Parametri di input, distinti per scenario (residenziale / aziendale)
%    2. Precalcolo della posizione solare (una sola volta per tutto l'anno)
%    3. Loop di ottimizzazione sulle variabili decisionali disponibili:
%         - tilt  : inclinazione dei moduli [gradi]   (solo con MOUNT=0)
%         - D_rtr : distanza inter-fila [m]           (solo con MOUNT=0)
%       Con MOUNT=1 entrambe sono imposte dal tetto: resta da determinare
%       quanti moduli entrano sulla falda e quanto producono.
%       Il numero di inverter NON e' una variabile decisionale: viene
%       derivato dalla potenza DC imponendo un rapporto DC/AC obiettivo.
%       Per ogni combinazione si calcola:
%         a) Layout fisico (numero moduli, dimensionamento inverter)
%         b) Verifica di fattibilita' elettrica (tensioni/correnti MPPT)
%         c) Simulazione oraria annuale (ombra, produzione, bilancio)
%         d) Analisi economica (CAPEX, OPEX, ricavi, IRR e NPV)
%    4. Identificazione della configurazione ottimale e superfici del KPI
%    5. Ri-simulazione dell'ottimo, plot operativi e riepilogo per PVsyst
%
%  Struttura di calcolo (evita di ripetere gli stessi conti 500 volte):
%    L0  posizione solare        -> 1 volta      (pv_sun_position)
%    L1  irradianza e T_cella    -> 1 per tilt   (pv_poa_tcell)
%    L2  ombra, produzione, bil. -> 1 per config (pv_simulate_layout)
%
%  Montaggio:          MOUNT=1 -> moduli complanari alla falda del tetto:
%                                 inclinazione imposta dalla pendenza, moduli
%                                 affiancati, nessun ombreggiamento reciproco.
%                                 L_r e W_r sono misurate SULLA FALDA.
%                      MOUNT=0 -> file inclinate su copertura piana: tilt e
%                                 spaziatura sono variabili decisionali e le
%                                 file si ombreggiano a vicenda.
%
%  Scenario:           SCENARIO=0 -> residenziale | SCENARIO=1 -> aziendale
%  KPI selezionabile:  KPI=0 -> IRR   |   KPI=1 -> NPV
%  Modalita' consumo:  REC=0 -> solo autoconsumo edificio
%                      REC=1 -> solo cessione a Comunita' Energetica (CER)
%                      REC=2 -> autoconsumo + CER
%                      REC=3 -> solo rete (benchmark)
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

% File dei profili di carico (risoluzione oraria, generati da
% generate_load_profiles.py).
% Colonne: timestamp, office_1_kWh, small_industry_1_kWh,
%          retail_1_kWh, household_1_kWh, household_2_kWh, household_3_kWh
profilesFile = "C:\Users\scimo\desktop\Project\CER_LoadProfiles\outputs\csv\profili_tutti.csv";

%% =========================================================================
%  2) SELETTORI DI SCENARIO
% =========================================================================
SCENARIO = 1;  % 0 = residenziale | 1 = aziendale
REC      = 2;  % 0=autoconsumo | 1=solo CER | 2=autoconsumo+CER | 3=solo rete
KPI      = 0;  % 0=ottimizza IRR | 1=ottimizza NPV

%% =========================================================================
%  3) PARAMETRI DI INPUT
% =========================================================================

% --- Localizzazione sito (comune ai due scenari) ------------------------
lat   = 45.462;  % Latitudine [gradi N]  (Milano)
long  = 9.19;    % Longitudine [gradi E]
STZ   = 1;       % Standard Time Zone rispetto a UTC [h]
rho_g = 0.3;     % Albedo del suolo [-] (usato per irradianza riflessa)

% --- Modulo fotovoltaico (comune ai due scenari) ------------------------
L_m           = 2.382;      % Lunghezza modulo [m]
W_m           = 1.114;     % Larghezza modulo [m]
P_stc_mod     = 605;       % Potenza nominale STC [Wp]
V_oc          = 48.48;      % Tensione a circuito aperto a STC [V]
V_mpp         = 40.31;      % Tensione al MPP a STC [V]
I_sc          = 15.9;      % Corrente di corto circuito a STC [A]
I_mpp         = 15.010;      % Corrente al MPP a STC [A]
power_coeff   = -0.0029;   % Coefficiente di temperatura sulla potenza [1/C]
current_coeff =  2.9e-3;   % Coefficiente di temperatura sulla corrente [A/C]
voltage_coeff = -176.8e-3; % Coefficiente di temperatura sulla tensione [V/C]
NOCT          = 45;        % Nominal Operating Cell Temperature [C]

% --- Perdite di sistema (comuni ai due scenari) -------------------------
DC_losses = 0.1;   % Perdite lato DC (cablaggio, mismatch, sporco) [-]
AC_losses = 0.05;  % Perdite lato AC (trasformatore, cablaggio) [-]

% --- Parametri finanziari (comuni ai due scenari) -----------------------
lifetime = 30;     % Vita utile impianto [anni]
infl     = 0.05;   % Tasso di inflazione annuo (OPEX) [-]
r_disc   = 0.04;   % Tasso di sconto di mercato (WACC) [-]
r_en     = 0.03;   % Escalation annua prezzo dell'energia [-]

% --- Rapporto DC/AC obiettivo per il dimensionamento inverter -----------
% Il numero di inverter viene derivato da questo valore, non ottimizzato.
DCAC_target = 1.15;

% =========================================================================
%  PARAMETRI DIPENDENTI DALLO SCENARIO
%
%  ATTENZIONE: i costi e le tariffe qui sotto sono valori di mercato
%  plausibili, NON riferimenti bibliografici. Vanno tarati sui dati della
%  tesi prima di usare i risultati economici.
%
%  L_r e W_r sono l'INPUT PRINCIPALE del modello: la superficie disponibile.
% =========================================================================
if SCENARIO == 0
    % ---------------- RESIDENZIALE ----------------
    scenarioName = 'Residenziale';
    buildColName = 'household_1_kWh';   % Profilo di consumo dell'edificio

    % Montaggio complanare alla falda: i moduli seguono la pendenza del tetto
    % e sono affiancati sullo stesso piano. Non si ombreggiano a vicenda e
    % l'inclinazione NON e' una variabile decisionale: la impone il tetto.
    MOUNT     = 1;    % 1 = complanare a falda | 0 = file inclinate su piano
    tilt_roof = 30;   % Pendenza della falda [gradi]

    % Geometria copertura
    % ATTENZIONE: con MOUNT=1 sono le dimensioni misurate SULLA FALDA
    % (lungo la pendenza), non la proiezione orizzontale del tetto.
    L_r    = 10;      % Lunghezza falda, lungo la pendenza [m]
    W_r    = 6;      % Larghezza falda [m]
    d_edge = 0.5;    % Margine perimetrale libero [m] (tetto a falda)

    % Inverter di stringa residenziale
    P_ac_inv      = 12;     % Potenza nominale AC per inverter [kWac]
    V_max_inv     = 600;   % Tensione massima in ingresso [V]
    V_max_mppt    = 550;   % Tensione massima finestra MPPT [V]
    V_min_mppt    = 350;   % Tensione minima finestra MPPT [V]
    N_mppt        = 2;     % Ingressi MPPT per inverter
    I_max_mppt    = 17.3;    % Corrente massima per ingresso MPPT [A]
    I_sc_max_mppt = 20;    % Corrente di cortocircuito max per ingresso [A]
    eta_inv       = 0.970; % Rendimento inverter [-]

    % Costi
    c_mod       = 250;    % Costo moduli [EUR/kWp]
    c_BOP       = 350;    % Balance of Plant [EUR/kWp]
    c_inv       = 200;    % Costo inverter [EUR/kWac]
    c_eng_inst  = 0.35;   % Ingegneria e installazione [frazione del TEC]
    c_interconn = 0;      % Allacciamento [EUR/kWac] (utenza gia' connessa)
    c_fixed     = 1500;   % Costi fissi di progetto [EUR]
    c_om        = 1000;  % O&M variabile [EUR/MWp/anno]
    c_om_fixed  = 150;    % O&M fisso [EUR/anno]

    % Tariffe
    p_en_purch = 280;        % Energia acquistata dalla rete [EUR/MWh]
    p_en_sell  = 90;         % Energia venduta in rete [EUR/MWh]
    p_en_REC   = 110 * 0.3;  % Incentivo CER [EUR/MWh]

else
    % ---------------- AZIENDALE ----------------
    scenarioName = 'Aziendale';
    buildColName = 'small_industry_1_kWh';  % Profilo di consumo dell'edificio

    % Copertura piana con file inclinate: tilt e spaziatura inter-fila sono
    % entrambi variabili decisionali e le file si ombreggiano a vicenda.
    MOUNT     = 0;    % 1 = complanare a falda | 0 = file inclinate su piano
    tilt_roof = NaN;  % Non usato con MOUNT=0

    % Geometria copertura (piano orizzontale)
    L_r    = 40;     % Lunghezza copertura [m]
    W_r    = 20;     % Larghezza copertura [m]
    d_edge = 1.4;    % Margine perimetrale libero [m]

    % Inverter di stringa commerciale
    P_ac_inv      = 20;    % Potenza nominale AC per inverter [kWac]
    V_max_inv     = 1100;  % Tensione massima in ingresso [V]
    V_max_mppt    = 1000;  % Tensione massima finestra MPPT [V]
    V_min_mppt    = 200;   % Tensione minima finestra MPPT [V]
    N_mppt        = 4;     % Ingressi MPPT per inverter
    I_max_mppt    = 26;    % Corrente massima per ingresso MPPT [A]
    I_sc_max_mppt = 40;    % Corrente di cortocircuito max per ingresso [A]
    eta_inv       = 0.980; % Rendimento inverter [-]

    % Costi
    c_mod       = 200;    % Costo moduli [EUR/kWp]
    c_BOP       = 280;    % Balance of Plant [EUR/kWp]
    c_inv       = 90;     % Costo inverter [EUR/kWac]
    c_eng_inst  = 0.40;   % Ingegneria e installazione [frazione del TEC]
    c_interconn = 50;     % Allacciamento rete [EUR/kWac]
    c_fixed     = 8000;   % Costi fissi di progetto [EUR]
    c_om        = 10000;  % O&M variabile [EUR/MWp/anno]
    c_om_fixed  = 1200;   % O&M fisso [EUR/anno]

    % Tariffe
    p_en_purch = 220;        % Energia acquistata dalla rete [EUR/MWh]
    p_en_sell  = 100;        % Energia venduta in rete [EUR/MWh]
    p_en_REC   = 110 * 0.3;  % Incentivo CER [EUR/MWh]
end

%% =========================================================================
%  4) LETTURA DATI DI INGRESSO
% =========================================================================

% --- Dati meteorologici (PVGIS TMY) ------------------------------------
% Trasposti a vettori riga [1 x N]: tutta la catena di calcolo e' vettoriale.
WD    = readtable(loadFile, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
DNI   = table2array(WD(1:8760, 5))';  % Gb(n): irradianza diretta normale [W/m2]
DIFF  = table2array(WD(1:8760, 6))';  % Gd(h): irradianza diffusa orizzontale [W/m2]
T_amb = table2array(WD(1:8760, 2))';  % T2m:   temperatura ambiente [C]

% --- Profili di consumo annuali (uno per ora) ---------------------------
% build_cons_data: consumo dell'edificio che ospita l'impianto [kWh/h == kW]
% REC_cons_data:   somma degli altri utenti della CER          [kWh/h == kW]
PT = readtable(profilesFile, 'VariableNamingRule', 'preserve');

numColsPT   = varfun(@isnumeric, PT, 'OutputFormat', 'uniform');
allNumNames = PT.Properties.VariableNames(numColsPT);
buildColIdx = strcmp(allNumNames, buildColName);
if ~any(buildColIdx)
    error('optimizer_PV:colonnaAssente', ...
          'Colonna "%s" non trovata nel CSV profili. Disponibili: %s', ...
          buildColName, strjoin(allNumNames, ', '));
end
otherIdx = ~buildColIdx;

build_cons_data = double(PT{:, allNumNames{buildColIdx}})';      % [1 x N]
REC_cons_data   = sum(double(PT{:, allNumNames(otherIdx)}), 2)'; % [1 x N]

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

% Selezione profilo di consumo in base alla modalita' REC
switch REC
    case 0   % Solo autoconsumo edificio
        build_cons = build_cons_data;   REC_cons = zeros(1, 8760);
    case 1   % Solo cessione alla CER
        build_cons = zeros(1, 8760);    REC_cons = REC_cons_data;
    case 2   % Autoconsumo + CER
        build_cons = build_cons_data;   REC_cons = REC_cons_data;
    otherwise % REC == 3: solo rete, nessun consumo locale
        build_cons = zeros(1, 8760);    REC_cons = zeros(1, 8760);
end

%% =========================================================================
%  5) SPAZIO DI RICERCA
%  La griglia di distanze inter-fila e' derivata dalla profondita' utile
%  della copertura: oltre (profondita' - ingombro modulo) non entra piu'
%  nemmeno una fila, quindi esplorare valori maggiori e' tempo sprecato.
% =========================================================================

depth_free = L_r - 2*d_edge;   % Profondita' utile della copertura [m]

if MOUNT == 1
    % --- Complanare a falda -------------------------------------------------
    % L'inclinazione e' quella del tetto e i moduli sono affiancati: non c'e'
    % nulla da ottimizzare, resta solo da contare quanti moduli entrano.
    % Per studiare la sensibilita' alla pendenza del tetto basta allargare
    % tilt_vet (es. tilt_vet = 15:2.5:45): il numero di moduli non cambia,
    % cambia solo l'irradianza sul piano.
    tilt_vet  = tilt_roof;
    D_rtr_vet = 0;
else
    % --- File inclinate su copertura piana ----------------------------------
    tilt_vet  = 0:2.5:45;                    % Inclinazione moduli [gradi]
    D_rtr_max = max(0, depth_free - W_m);    % Oltre questo valore: zero file
    if D_rtr_max > 0
        D_rtr_vet = linspace(0, D_rtr_max, 16);   % Distanza inter-fila [m]
    else
        D_rtr_vet = 0;
    end
end

nTilt = length(tilt_vet);
nD    = length(D_rtr_vet);
sz    = [nTilt, nD];

hours_vet = 1:8760;
N = length(hours_vet);

%% =========================================================================
%  6) STRUTTURA PARAMETRI E PRECALCOLI INDIPENDENTI DALLA CONFIGURAZIONE
% =========================================================================

% Struct unica passata alle funzioni di calcolo
par = struct( ...
    'L_r', L_r, 'W_r', W_r, 'd_edge', d_edge, ...
    'L_m', L_m, 'W_m', W_m, 'P_stc_mod', P_stc_mod, ...
    'power_coeff', power_coeff, ...
    'DC_losses', DC_losses, 'AC_losses', AC_losses, 'eta_inv', eta_inv, ...
    'P_ac_inv', P_ac_inv, 'DCAC_target', DCAC_target, ...
    'coplanar', MOUNT == 1, ...
    'build_cons', build_cons, 'REC_cons', REC_cons, ...
    'c_mod', c_mod, 'c_BOP', c_BOP, 'c_inv', c_inv, ...
    'c_eng_inst', c_eng_inst, 'c_interconn', c_interconn, 'c_fixed', c_fixed, ...
    'c_om', c_om, 'c_om_fixed', c_om_fixed, ...
    'infl', infl, 'r_en', r_en, ...
    'p_en_sell', p_en_sell, 'p_en_purch', p_en_purch, 'p_en_REC', p_en_REC, ...
    'lifetime', lifetime);

% --- L0: posizione solare, calcolata UNA sola volta per tutto l'anno ----
sun = pv_sun_position(hours_vet, lat, long, STZ);

% --- Limiti di stringing: non dipendono dalla configurazione ------------
T_cell_max = max(T_amb) + (NOCT - 20) / 800 * 1000;   % Coerente con pv_poa_tcell
T_cell_min = min(T_amb);
V_oc_Tmin  = V_oc  + voltage_coeff * (T_cell_min - 25);
V_mpp_Tmin = V_mpp + voltage_coeff * (T_cell_min - 25);
I_mpp_Tmax = I_mpp + current_coeff  * (T_cell_max - 25);
I_sc_Tmax  = I_sc  + current_coeff  * (T_cell_max - 25);
N_mod_string_oc  = floor(V_max_inv  / V_oc_Tmin);
N_mod_string_mpp = floor(V_max_mppt / V_mpp_Tmin);
N_mod_string_lim = min(N_mod_string_oc, N_mod_string_mpp);

%% =========================================================================
%  7) INIZIALIZZAZIONE MATRICI RISULTATO  (tilt x D_rtr)
% =========================================================================

% Risultati fisici
N_rows          = zeros(sz);   % Numero di file di moduli
N_mod_rows      = zeros(sz);   % Numero di moduli per fila
N_mod           = zeros(sz);   % Numero totale di moduli
N_inv           = zeros(sz);   % Numero di inverter (derivato)
P_dc_nom        = zeros(sz);   % Potenza DC nominale [kWp]
P_ac_nom        = zeros(sz);   % Potenza AC nominale [kWac]
N_mod_string    = zeros(sz);   % Moduli per stringa (limite tensione)
unfeasible_conf = zeros(sz);   % Flag: 1 se la config viola i limiti
eta_shad        = zeros(sz);   % Efficienza di ombreggiamento annuale [-]
h_eq            = zeros(sz);   % Ore equivalenti AC [kWh/kWp]
h_eq_dc         = zeros(sz);   % Ore equivalenti DC [kWh/kWp]
DCAC            = zeros(sz);   % Rapporto DC/AC [-]
pitch           = zeros(sz);   % Passo tra file [m]
GCR             = zeros(sz);   % Ground Coverage Ratio [-]

% Risultati energetici annuali [MWh]
E_purch  = zeros(sz);
E_toREC  = zeros(sz);
E_togrid = zeros(sz);
E_saved  = zeros(sz);
E_ac_net = zeros(sz);
E_dc     = zeros(sz);

% Risultati economici
CAPEX0 = zeros(sz);   % Investimento iniziale [EUR]
IRR    = zeros(sz);   % Internal Rate of Return [-]
NPV    = zeros(sz);   % Net Present Value [EUR]

%% =========================================================================
%  8) LOOP DI OTTIMIZZAZIONE  (tilt x D_rtr)
%
%  Il ciclo esterno gira sul tilt perche' irradianza e temperatura di cella
%  dipendono solo da quello: si calcolano una volta e si riusano per tutte
%  le distanze inter-fila.
% =========================================================================

% Contatore config. con cambi di segno multipli nei CF (IRR con radici multiple)
n_multIRR = 0;

% Disattivo temporaneamente i warning durante il loop (ripristinati al termine)
warnState = warning('off', 'all');
t_start = tic;

for j = 1:nTilt

    % --- L1: irradianza sul piano e temperatura di cella (una per tilt) ---
    [G_tot_j, T_c_j] = pv_poa_tcell(tilt_vet(j), sun, DNI, DIFF, T_amb, rho_g, NOCT);

    for k = 1:nD

        % --- 8a) Layout fisico e dimensionamento inverter -----------------
        geo = pv_layout(tilt_vet(j), D_rtr_vet(k), par);

        N_rows(j,k)     = geo.N_rows;
        N_mod_rows(j,k) = geo.N_mod_rows;
        N_mod(j,k)      = geo.N_mod;
        N_inv(j,k)      = geo.N_inv;
        P_dc_nom(j,k)   = geo.P_dc_nom;
        P_ac_nom(j,k)   = geo.P_ac_nom;
        pitch(j,k)      = geo.pitch;
        GCR(j,k)        = geo.GCR;

        % Se non entra nessun modulo sul tetto, configurazione non fattibile
        if geo.N_mod == 0
            unfeasible_conf(j,k) = 1;
            IRR(j,k)     = NaN;
            NPV(j,k)     = NaN;
            DCAC(j,k)    = NaN;
            h_eq(j,k)    = NaN;
            h_eq_dc(j,k) = NaN;
            continue;
        end

        % --- 8b) Verifica compatibilita' moduli-inverter (stringing) ------
        %   - Tensione massima inverter (Voc a temperatura minima)
        %   - Finestra MPPT (Vmpp a temperatura minima)
        %   - Corrente massima per ingresso MPPT (a temperatura massima)
        N_mod_string(j,k) = N_mod_string_lim;

        N_strings_mpp_max = ceil(geo.N_mod / N_mod_string_lim / geo.N_inv / N_mppt);
        I_mpp_max_mpp     = N_strings_mpp_max * I_mpp_Tmax;
        I_mpp_max_sc      = N_strings_mpp_max * I_sc_Tmax;

        if I_mpp_max_mpp >= I_max_mppt || I_mpp_max_sc >= I_sc_max_mppt
            unfeasible_conf(j,k) = 1;
        end

        % --- 8c) L2: simulazione oraria annuale (vettoriale) --------------
        R = pv_simulate_layout(tilt_vet(j), D_rtr_vet(k), ...
                               G_tot_j, T_c_j, sun.alpha_s, geo, par);

        eta_shad(j,k) = R.eta_shad;
        E_dc(j,k)     = R.E_dc;
        E_ac_net(j,k) = R.E_ac_net;
        E_purch(j,k)  = R.E_purch;
        E_toREC(j,k)  = R.E_toREC;
        E_togrid(j,k) = R.E_togrid;
        E_saved(j,k)  = R.E_saved;

        % --- 8d) Analisi economica ---------------------------------------
        [CF, ~, ~, ~, CAPEX0(j,k)] = pv_cashflow(geo.P_dc_nom, geo.P_ac_nom, ...
                                     R.E_togrid, R.E_toREC, R.E_saved, par);

        if unfeasible_conf(j,k) == 1 || any(~isfinite(CF))
            IRR(j,k)     = NaN;
            NPV(j,k)     = NaN;
            DCAC(j,k)    = NaN;
            h_eq(j,k)    = NaN;
            h_eq_dc(j,k) = NaN;
        else
            % Conta cambi di segno nei CF: >1 -> IRR con radici multiple
            CF_nz = CF(CF ~= 0);
            if numel(CF_nz) > 1 && sum(diff(sign(CF_nz)) ~= 0) > 1
                n_multIRR = n_multIRR + 1;
            end
            IRR(j,k)     = irr_bisection(CF);
            NPV(j,k)     = sum( CF ./ (1 + r_disc).^(0:lifetime) );
            DCAC(j,k)    = geo.P_dc_nom / geo.P_ac_nom;
            h_eq(j,k)    = R.E_ac_net / geo.P_dc_nom * 1000;
            h_eq_dc(j,k) = R.E_dc     / geo.P_dc_nom * 1000;
        end

    end
end

t_loop = toc(t_start);
warning(warnState);

fprintf('\n=== Scenario: %s | REC=%d | KPI=%d ===\n', scenarioName, REC, KPI);
fprintf('Superficie copertura: %.1f x %.1f m (%.0f m2), margine %.1f m\n', ...
        L_r, W_r, L_r*W_r, d_edge);
fprintf('Configurazioni valutate: %d (%d tilt x %d D_rtr) in %.2f s\n', ...
        numel(IRR), nTilt, nD, t_loop);
fprintf('Non fattibili: %d (di cui %d con zero moduli)\n', ...
        sum(unfeasible_conf(:)), sum(N_mod(:) == 0));
if n_multIRR > 0
    fprintf('NOTA: %d configurazioni con cambi di segno multipli nei CF ', n_multIRR);
    fprintf('(IRR con possibili radici multiple).\n');
end

%% =========================================================================
%  9) INDIVIDUAZIONE DELLA CONFIGURAZIONE OTTIMALE
%
%  Guardia esplicita: max() su una matrice interamente NaN restituisce
%  l'indice 1 senza segnalare nulla, facendo passare per "ottimo" il primo
%  punto della griglia. Qui il caso viene intercettato e dichiarato.
% =========================================================================

if KPI == 0
    kpiMat  = IRR;
    kpiName = 'IRR';
else
    kpiMat  = NPV;
    kpiName = 'NPV';
end

if all(isnan(kpiMat(:)))
    if KPI == 0 && ~all(isnan(NPV(:)))
        warning('optimizer_PV:IRRnonCalcolabile', ...
            ['Nessuna configurazione ha un IRR calcolabile: i flussi di cassa ' ...
             'non cambiano mai segno (il progetto non rientra mai). ' ...
             'Ottimizzo sull''NPV meno negativo.']);
        kpiMat  = NPV;
        kpiName = 'NPV (ripiego: IRR non calcolabile)';
    else
        error('optimizer_PV:nessunaConfigValida', ...
            ['Nessuna configurazione valida: tutti i KPI sono NaN. ' ...
             'Verificare superficie disponibile e parametri di scenario.']);
    end
end

[kpiBest, idx] = max(kpiMat(:));
[ind_t, ind_d] = ind2sub(size(kpiMat), idx);
tilt_optimal   = tilt_vet(ind_t);
D_rtr_optimal  = D_rtr_vet(ind_d);

fprintf('\n=== Configurazione ottimale (%s) ===\n', kpiName);
fprintf('  Tilt ottimale:   %.2f gradi\n',  tilt_optimal);
fprintf('  D_rtr ottimale:  %.2f m\n',      D_rtr_optimal);
fprintf('  N. moduli:       %d (%d file x %d moduli)\n', ...
        N_mod(ind_t,ind_d), N_rows(ind_t,ind_d), N_mod_rows(ind_t,ind_d));
fprintf('  N. inverter:     %d x %.1f kWac\n', N_inv(ind_t,ind_d), P_ac_inv);
fprintf('  Potenza DC:      %.2f kWdc\n', P_dc_nom(ind_t,ind_d));
fprintf('  Potenza AC:      %.2f kWac\n', P_ac_nom(ind_t,ind_d));
fprintf('  DC/AC ratio:     %.2f\n',      DCAC(ind_t,ind_d));
fprintf('  Ore equivalenti: %.0f kWh/kWp\n', h_eq(ind_t,ind_d));
fprintf('  Eff. ombra:      %.1f %%\n',   eta_shad(ind_t,ind_d)*100);
fprintf('  CAPEX:           %.2f kEUR\n', CAPEX0(ind_t,ind_d)/1e3);
if isnan(IRR(ind_t,ind_d))
    fprintf('  IRR:             non calcolabile\n');
else
    fprintf('  IRR:             %.2f %%\n', IRR(ind_t,ind_d)*100);
end
fprintf('  NPV:             %.2f kEUR\n', NPV(ind_t,ind_d)/1e3);

%% =========================================================================
%  10) SUPERFICI DELLO SPAZIO DELLE SOLUZIONI
% =========================================================================

figure('Name', sprintf('Spazio soluzioni - %s', kpiName), 'Color', 'w');
if KPI == 0
    pv_surface_plot(tilt_vet, D_rtr_vet, IRR*100, 'IRR [%]', ...
                    sprintf('Spazio soluzioni - IRR (%s)', scenarioName));
else
    pv_surface_plot(tilt_vet, D_rtr_vet, NPV/1e3, 'NPV [kEUR]', ...
                    sprintf('Spazio soluzioni - NPV (%s)', scenarioName));
end

%% =========================================================================
%  11) SUPERFICI AUSILIARIE
% =========================================================================

auxData  = {N_mod, DCAC, h_eq, CAPEX0/1e3};
auxLabel = {'Numero di moduli', 'DC/AC ratio', ...
            'Ore equivalenti AC [kWh/kWp]', 'CAPEX [kEUR]'};

figure('Name', 'Grandezze ausiliarie', 'Color', 'w');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for a = 1:4
    nexttile;
    pv_surface_plot(tilt_vet, D_rtr_vet, auxData{a}, auxLabel{a}, auxLabel{a});
end
sgtitle(sprintf('Grandezze ausiliarie - %s', scenarioName));

%% =========================================================================
%  12) RI-SIMULAZIONE DELLA CONFIGURAZIONE OTTIMALE
%  Usa esattamente le stesse funzioni del loop: nessuna duplicazione di
%  codice, quindi nessun rischio che le due versioni divergano.
% =========================================================================

geo_opt = pv_layout(tilt_optimal, D_rtr_optimal, par);
[G_tot_opt, T_c_opt] = pv_poa_tcell(tilt_optimal, sun, DNI, DIFF, T_amb, rho_g, NOCT);
R_opt = pv_simulate_layout(tilt_optimal, D_rtr_optimal, ...
                           G_tot_opt, T_c_opt, sun.alpha_s, geo_opt, par);

[CF_opt, CAPEX_opt, OPEX_opt, REV_opt, CAPEX0_opt] = pv_cashflow( ...
        geo_opt.P_dc_nom, geo_opt.P_ac_nom, ...
        R_opt.E_togrid, R_opt.E_toREC, R_opt.E_saved, par);

IRR_opt = irr_bisection(CF_opt);
NPV_opt = sum( CF_opt ./ (1 + r_disc).^(0:lifetime) );

% Serie orarie della configurazione ottimale (alias per leggibilita' dei plot)
P_ac_net_opt = R_opt.P_ac_net;
P_cons_opt   = R_opt.P_cons;
P_REC_opt    = R_opt.P_REC;
P_toREC_opt  = R_opt.P_toREC;
P_togrid_opt = R_opt.P_togrid;

%% =========================================================================
%  13) FLUSSI DI CASSA DELLA CONFIGURAZIONE OTTIMALE
% =========================================================================

anni = 0:lifetime;
figure('Name', 'Flussi di cassa - Configurazione ottimale', 'Color', 'w');

subplot(2,1,1); hold on; grid on; box on;
bar(anni, [REV_opt(:), -OPEX_opt(:), -CAPEX_opt(:)], 'stacked');
plot(anni, CF_opt, 'k-o', 'LineWidth', 1.8, 'MarkerSize', 5);
legend('Ricavi', 'OPEX', 'CAPEX', 'CF netto', 'Location', 'best');
xlabel('Anno'); ylabel('Flusso di cassa [EUR]');
title('Flussi di cassa annuali - Configurazione ottimale');

subplot(2,1,2); hold on; grid on; box on;
plot(anni, cumsum(CF_opt), 'b-o', 'LineWidth', 1.8, 'MarkerSize', 5);
yline(0, 'r--', 'LineWidth', 1.2);
xlabel('Anno'); ylabel('Flusso cumulato [EUR]');
title('Flusso di cassa cumulato (payback visivo)');

% --- Profilo operativo su un sottoinsieme di ore (meta' giugno) ----------
h_iniz = 4000;
h_fin  = 4100;
t_plot = hours_vet(h_iniz:h_fin) - h_iniz;

figure('Name', 'Profilo operativo', 'Color', 'w'); hold on; grid on;
plot(t_plot, P_ac_net_opt(h_iniz:h_fin),                         'LineWidth', 1.5);
plot(t_plot, P_cons_opt(h_iniz:h_fin),                           'LineWidth', 1.5);
plot(t_plot, P_REC_opt(h_iniz:h_fin) + P_cons_opt(h_iniz:h_fin), 'LineWidth', 1.5);
plot(t_plot, P_toREC_opt(h_iniz:h_fin),                          'LineWidth', 1.5);
plot(t_plot, P_togrid_opt(h_iniz:h_fin),                         'LineWidth', 1.5);
legend('P_{ac,net}', 'P_{cons}', 'P_{cons} + P_{REC}', 'P_{to REC}', 'P_{to grid}', ...
       'Location', 'best');
xlabel('Tempo [h]'); ylabel('Potenza [kW]');
title(sprintf('Profilo operativo - configurazione ottimale (ore %d-%d)', h_iniz, h_fin));

%% =========================================================================
%  14) PRODUZIONE PV vs CONSUMI - Annuale, Giugno, Giorno tipo
% =========================================================================

t_year = datetime(2025,1,1,0,0,0) + hours(0:8759);

% --- 14a) Profilo annuale (media giornaliera per leggibilita') ----------
dayOfYear    = floor((hours_vet - 1) / 24) + 1;
P_ac_net_day = accumarray(dayOfYear', P_ac_net_opt', [], @mean);
P_cons_day   = accumarray(dayOfYear', P_cons_opt',   [], @mean);

figure('Name', 'Produzione PV vs Consumi - Anno', 'Color', 'w');
hold on; grid on; box on;
area(1:365, P_ac_net_day, 'FaceAlpha', 0.35, 'FaceColor', [1 0.8 0], ...
     'EdgeColor', [0.9 0.6 0], 'DisplayName', 'Produzione PV');
plot(1:365, P_cons_day, 'Color', [0.1 0.3 0.7], 'LineWidth', 1.8, ...
     'DisplayName', 'Consumo edificio');
xlabel('Giorno dell''anno'); ylabel('Potenza media giornaliera [kW]');
title('Produzione PV vs Consumo edificio - Profilo annuale');
legend('Location', 'northwest'); xlim([1 365]);

% --- 14b) Mese di giugno ------------------------------------------------
h_jun_start = (152 - 1) * 24 + 1;   % 1 giugno, ora 00:00
h_jun_end   = 181 * 24;             % 30 giugno, ora 23:00
idx_jun     = h_jun_start:h_jun_end;
t_jun       = t_year(idx_jun);

figure('Name', 'Produzione PV vs Consumi - Giugno', 'Color', 'w');
hold on; grid on; box on;
area(t_jun, P_ac_net_opt(idx_jun), 'FaceAlpha', 0.35, 'FaceColor', [1 0.8 0], ...
     'EdgeColor', [0.9 0.6 0], 'DisplayName', 'Produzione PV');
plot(t_jun, P_cons_opt(idx_jun), 'Color', [0.1 0.3 0.7], 'LineWidth', 1.2, ...
     'DisplayName', 'Consumo edificio');
xlabel('Data'); ylabel('Potenza [kW]');
title('Produzione PV vs Consumo edificio - Giugno');
legend('Location', 'northwest');

% --- 14c) Giorno tipo (media oraria su tutto giugno) --------------------
hour_of_day_jun = mod(idx_jun - 1, 24);
PV_daytype   = accumarray(hour_of_day_jun' + 1, P_ac_net_opt(idx_jun)', [], @mean);
Cons_daytype = accumarray(hour_of_day_jun' + 1, P_cons_opt(idx_jun)',   [], @mean);

figure('Name', 'Giorno tipo giugno - PV vs Consumi', 'Color', 'w');
hold on; grid on; box on;
area(0:23, PV_daytype, 'FaceAlpha', 0.35, 'FaceColor', [1 0.8 0], ...
     'EdgeColor', [0.9 0.6 0], 'DisplayName', 'Produzione PV');
plot(0:23, Cons_daytype, 'Color', [0.1 0.3 0.7], 'LineWidth', 2, ...
     'DisplayName', 'Consumo edificio');
xlabel('Ora del giorno [h]'); ylabel('Potenza media [kW]');
title('Giorno tipo - Giugno (media su 30 giorni)');
legend('Location', 'northwest'); xlim([0 23]); xticks(0:2:23);

%% =========================================================================
%  15) RIEPILOGO PER PVSYST
%  Dati da riportare nel progetto PVsyst per la simulazione di dettaglio.
% =========================================================================

N_strings_opt = ceil(geo_opt.N_mod / N_mod_string_lim);

fprintf('\n');
fprintf('=========================================================\n');
fprintf('  DATI PER PVSYST - scenario %s\n', scenarioName);
fprintf('=========================================================\n');
fprintf('  CAMPO\n');
fprintf('    Moduli totali        : %d  (%d file x %d moduli/fila)\n', ...
        geo_opt.N_mod, geo_opt.N_rows, geo_opt.N_mod_rows);
fprintf('    Modulo               : %.0f Wp, %.3f x %.3f m\n', P_stc_mod, L_m, W_m);
fprintf('    Tilt                 : %.1f gradi\n', tilt_optimal);
fprintf('    Azimut               : 0 gradi (sud) - assunzione del modello\n');
if MOUNT == 1
    fprintf('    Montaggio            : complanare alla falda (pendenza tetto)\n');
    fprintf('    Disposizione         : moduli affiancati, nessuna spaziatura\n');
    fprintf('    Ombra tra moduli     : assente (tutti sullo stesso piano)\n');
    fprintf('    NOTA PVsyst          : modellare come piano unico inclinato,\n');
    fprintf('                           non come file con pitch/GCR\n');
else
    fprintf('    Montaggio            : file inclinate su copertura piana\n');
    fprintf('    Pitch (passo file)   : %.3f m\n', geo_opt.pitch);
    fprintf('    Spazio libero D_rtr  : %.3f m\n', D_rtr_optimal);
    fprintf('    GCR                  : %.3f\n', geo_opt.GCR);
end
fprintf('  ELETTRICO\n');
fprintf('    Potenza DC           : %.2f kWp\n', geo_opt.P_dc_nom);
fprintf('    Inverter             : %d x %.1f kWac = %.1f kWac\n', ...
        geo_opt.N_inv, P_ac_inv, geo_opt.P_ac_nom);
fprintf('    DC/AC ratio          : %.2f (obiettivo %.2f)\n', ...
        geo_opt.P_dc_nom/geo_opt.P_ac_nom, DCAC_target);
fprintf('    Moduli per stringa   : %d (limite tensione)\n', N_mod_string_lim);
fprintf('    Stringhe             : %d\n', N_strings_opt);
fprintf('  ENERGIA (stima annua)\n');
fprintf('    Produzione DC lorda  : %.2f MWh\n', R_opt.E_dc);
fprintf('    Produzione AC netta  : %.2f MWh\n', R_opt.E_ac_net);
fprintf('    Resa specifica       : %.0f kWh/kWp\n', ...
        R_opt.E_ac_net / geo_opt.P_dc_nom * 1000);
fprintf('    Efficienza ombra     : %.2f %%\n', R_opt.eta_shad * 100);
fprintf('    Perdite da clipping  : %.3f MWh\n', R_opt.clipping_losses);
fprintf('    Perdite DC / AC      : %.0f %% / %.0f %%\n', DC_losses*100, AC_losses*100);
fprintf('  BILANCIO\n');
fprintf('    Autoconsumo edificio : %.2f MWh\n', R_opt.E_saved);
fprintf('    Ceduta alla CER      : %.2f MWh\n', R_opt.E_toREC);
fprintf('    Immessa in rete      : %.2f MWh\n', R_opt.E_togrid);
fprintf('    Prelevata da rete    : %.2f MWh\n', R_opt.E_purch);
fprintf('  ECONOMIA\n');
fprintf('    CAPEX                : %.2f kEUR\n', CAPEX0_opt/1e3);
if isnan(IRR_opt)
    fprintf('    IRR                  : non calcolabile (CF sempre negativi)\n');
else
    fprintf('    IRR                  : %.2f %%\n', IRR_opt*100);
end
fprintf('    NPV (%d anni, r=%.0f%%): %.2f kEUR\n', lifetime, r_disc*100, NPV_opt/1e3);
fprintf('=========================================================\n');
