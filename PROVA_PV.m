clear all
clc
close all

%% Input
% Rooftop
L_r=40; % m
W_r=50; % m
d_edge=1.4; % m
rho_g=0.3;
lat=45.462; % Plant location latitude (°)
long=9.19; % Plant location longitude (°)
STZ=1;
% Modules
L_m=1.69; % m
W_m=1.046; % m
P_stc_mod=400; % Wp
V_oc=75.6; % V
V_mpp=65.8; % V
I_sc=6.58; % A
I_mpp=6.08; % A
power_coeff=-0.0029; %-/°C
current_coeff=2.9e-3; % A/°C
voltage_coeff=-176.8e-3; % V/°C
NOCT=45; %°C
% Inverters
P_ac_inv=250; %kWac
V_max_inv=1500; % V
V_max_mppt=1300; % V
V_min_mppt=860; % V
N_mppt=12;
I_max_mppt=30; % A
I_sc_max_mppt=50; % A
eta_inv=0.988;
% Weather data
loadFile = "C:\Users\scimo\OneDrive\Desktop\PoliMi\Tesi\tmy_45.464_9.190_2005_2023.csv";
WD    = readtable(loadFile, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
DNI   = table2array(WD(1:8760, 5));  % Gb(n): irradianza diretta normale [W/m²]
DIFF  = table2array(WD(1:8760, 6));  % Gd(h): irradianza diffusa orizzontale [W/m²]
T_amb = table2array(WD(1:8760, 2));  % T2m:   temperatura ambiente [°C]
%load weather_data_milan.mat DNI DIFF T_amb

% Losses
DC_losses=0.1;
AC_losses=0.05;
% Consumptions
build_cons_data=[10	10	10	10	10	11	12	14	24	24	24	26	26	26	24	20	24	24	20	18	14	14	10	11]*1.5; % kW
REC_cons_data=[16 16 16	16	16	30	35	40	30	30	28	25	25	28	30	30	30	40	45	50	50	45	40	40]*1.5; % kW
% Economic parameters
c_mod=180; % €/kWp
c_inv=50; % €/kWac
c_BOP=270; %€/kWp
c_eng_inst=0.4; % % of TEC
c_interconn=50; % €/kWac
c_fixed=50000;
c_om=10000; % €/MW per year
c_om_fixed=5000;
infl=0.02; % %
p_en_purch=220; % €/MWh
p_en_sell=100; % €/MWh
p_en_REC=110*0.3; %  €/MWh
lifetime=30; % years;

% Opimization variables
N_inv_vet=1:4;% up to 4 since I have interconnection limit of 1000 kWac
D_rtr_vet=0:0.5:7;
tilt_vet=0:5:40;

% Cases
REC=0; % 0=only self-consumption, 1 = only REC, 2 = self-consumption+RE; 3 = only grid
KPI=0; % 0 = IRR, 1 = NPV

%% Array initialization
hours_vet=1:8760;
delta=zeros(1,length(hours_vet));
E_n=zeros(1,length(hours_vet));
t_s=zeros(1,length(hours_vet));
omega=zeros(1,length(hours_vet));
theta_z=zeros(1,length(hours_vet));
gamma_s=zeros(1,length(hours_vet));
theta=zeros(1,length(hours_vet));
G_tot=zeros(1,length(hours_vet));
s=zeros(1,length(hours_vet));
Q_in_noshad=zeros(1,length(hours_vet));
alpha_s=zeros(1,length(hours_vet));
A_active=zeros(1,length(hours_vet));
G_av=zeros(1,length(hours_vet));
T_c=zeros(1,length(hours_vet));
P_dc=zeros(1,length(hours_vet));
P_ac=zeros(1,length(hours_vet));
P_dc_net=zeros(1,length(hours_vet));
P_ac_net=zeros(1,length(hours_vet));
P_purch=zeros(1,length(hours_vet));
P_togrid=zeros(1,length(hours_vet));
P_toREC=zeros(1,length(hours_vet));
P_cons=zeros(1,length(hours_vet));
P_REC=zeros(1,length(hours_vet));

tilt=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
D_rtr=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
N_rows=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
N_mod_rows=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
N_mod=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
P_dc_nom=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
P_ac_nom=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
N_mod_string=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
unfeasible_conf=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
IRR=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
DCAC=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
E_purch=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
E_toREC=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
E_togrid=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
E_saved=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
h_eq=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
CAPEX0=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
NPV=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
eta_shad=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));
h_eq_dc=zeros(length(N_inv_vet),length(tilt_vet),length(D_rtr_vet));

CAPEX=zeros(1,lifetime+1);
OPEX=zeros(1,lifetime+1);
REV=zeros(1,lifetime+1);
CF=zeros(1,lifetime+1);
residual_loan=zeros(1,lifetime+1);
Mort_Int=zeros(1,lifetime+1);

if REC ==0
    build_cons=build_cons_data;
    REC_cons=zeros(1,24);
elseif REC==1
    build_cons=zeros(1,24);
    REC_cons=REC_cons_data;
elseif REC==2
    build_cons=build_cons_data;
    REC_cons=REC_cons_data;
else
    build_cons=zeros(1,24);
    REC_cons=zeros(1,24);
end

%% Loops start
for i=1:length(N_inv_vet)
    for j=1:length(tilt_vet)
        for k=1:length(D_rtr_vet)
            tilt(i,j,k)=tilt_vet(j);
            D_rtr(i,j,k)=D_rtr_vet(k);
            % PV layout
            N_rows(i,j,k)=floor((L_r-2*d_edge)/(W_m*cosd(tilt(i,j,k))+D_rtr(i,j,k)));
            N_mod_rows(i,j,k)=floor((W_r-2*d_edge)/L_m);
            N_mod(i,j,k)=N_rows(i,j,k)*N_mod_rows(i,j,k);
            P_dc_nom(i,j,k)=N_mod(i,j,k)*P_stc_mod/1000; % kW
            P_ac_nom(i,j,k)=N_inv_vet(i)*P_ac_inv; % kW

            % Modules-Inverter matching verification
            T_cell_max=max(T_amb)+(NOCT-25)/800*1000;
            T_cell_min=min(T_amb);
            V_oc_Tmin=V_oc+voltage_coeff*(T_cell_min-25);
            V_mpp_Tmin=V_mpp+voltage_coeff*(T_cell_min-25);
            % V_mpp_Tmax=V_mpp+voltage_coeff*(T_cell_max-25);
            I_mpp_Tmax=I_mpp+current_coeff*(T_cell_max-25);
            I_sc_Tmax=I_sc+current_coeff*(T_cell_max-25);
            N_mod_string_oc=floor(V_max_inv/V_oc_Tmin);
            N_mod_string_mpp=floor(V_max_mppt/V_mpp_Tmin);
            N_mod_string(i,j,k)=min(N_mod_string_oc,N_mod_string_mpp);
            N_strings_mpp_max=ceil(N_mod(i,j,k)/N_mod_string(i,j,k)/N_inv_vet(i)/N_mppt);
            I_mpp_max_mpp=N_strings_mpp_max*I_mpp_Tmax;
            I_mpp_max_sc=N_strings_mpp_max*I_sc_Tmax;
            if I_mpp_max_mpp>=I_max_mppt || I_mpp_max_sc>=I_sc_max_mppt
                unfeasible_conf(i,j,k)=1;
            end
            % Yearly analysis
            for h=1:length(hours_vet)
                % Sun position and radiation
                n=ceil(h/24);
                delta(h)= 23.45*sind(360/365*(n+284)); % declination angle
                E_n(h)=229.18*(0.000075+0.001868*cosd(360*(n-1)/365)-0.03277*sind(360*(n-1)/365)-0.014615*cosd(2*360*(n-1)/365)-0.04080*sind(2*360*(n-1)/365));
                t_s(h)=(h-(n-1)*24)+(long-STZ*15)/15+E_n(h)/60; % solar time
                omega(h)=15*(t_s(h)-12); % hour angle
                theta_z(h)=acosd(sind(delta(h))*sind(lat)+cosd(delta(h))*cosd(lat)*cosd(omega(h))); % solar zenith angle
                gamma_s(h)=acosd((cosd(theta_z(h))*sind(lat)-sind(delta(h)))/(cosd(90-theta_z(h))*cosd(lat))*sign(lat)); % solar azmiuth angle
                theta(h)=acosd(cosd(theta_z(h))*cosd(tilt(i,j,k))+sind(theta_z(h))*sind(tilt(i,j,k))*cosd(gamma_s(h))); % incidence angle
                G_tot(h)=DNI(h)*cosd(theta(h))+DIFF(h)*(1+cosd(tilt(i,j,k)))/2+(DNI(h)*cosd(theta_z(h))+DIFF(h))*rho_g*(1-cosd(tilt(i,j,k)))/2;
                alpha_s(h)=90-theta_z(h);
                x=W_m*sind(tilt(i,j,k))/tand(alpha_s(h))+W_m*cosd(tilt(i,j,k))-(D_rtr(i,j,k)+W_m*cosd(tilt(i,j,k)));
                if alpha_s(h)<=0
                    s(h)=W_m;
                    A_active(h)=0;
                else
                    s(h)=min([W_m,max([0,(x*sind(alpha_s(h)))/sind(180-alpha_s(h)-tilt(i,j,k))])]);
                    A_active(h)=((W_m-s(h))*(N_rows(i,j,k)-1)+W_m)*N_mod_rows(i,j,k)*L_m;
                end
                G_av(h)=G_tot(h)/(N_mod(i,j,k)*L_m*W_m)*A_active(h);
                T_c(h)=T_amb(h)+(NOCT-20)/800*G_tot(h); % Hyp: Tcell of the active part depends on G_tot 
                P_dc(h)=G_av(h)/1000*P_stc_mod*(1+power_coeff*(T_c(h)-25))*N_mod(i,j,k)/1000; % kW
                P_dc_net(h)=P_dc(h)*(1-DC_losses);
                P_ac(h)=min([P_dc_net(h)*eta_inv,P_ac_nom(i,j,k)]);
                P_ac_net(h)=P_ac(h)*(1-AC_losses);
                h_index=int32(h-(n-1)*24);
                P_cons(h)=build_cons(h_index);
                P_REC(h)=REC_cons(h_index);
                if P_ac_net(h)<P_cons(h)
                    P_purch(h)=P_cons(h)-P_ac_net(h);
                    P_toREC(h)=0;
                    P_togrid(h)=0;
                else
                    if P_ac_net(h)-P_cons(h)<P_REC(h)
                        P_purch(h)=0;
                        P_togrid(h)=0;
                        P_toREC(h)=P_ac_net(h)-P_cons(h);
                    else
                        P_purch(h)=0;
                        P_toREC(h)=P_REC(h);
                        P_togrid(h)=P_ac_net(h)-P_cons(h)-P_REC(h);
                    end
                end
            end
            eta_shad(i,j,k)=sum(G_av)/sum(G_tot);
            E_dc=sum(P_dc)/1000; %MWh
            E_ac_net=sum(P_ac_net)/1000; %MWh
            clipping_losses=sum(P_dc_net)/1000*eta_inv*(1-AC_losses)-E_ac_net; %MWh
            clipping_losses_perc=clipping_losses/(sum(P_dc_net)/1000*eta_inv*(1-AC_losses));
            E_purch(i,j,k)=sum(P_purch)/1000; %MWh
            E_toREC(i,j,k)=sum(P_toREC)/1000; %MWh
            E_togrid(i,j,k)=sum(P_togrid)/1000; %MWh
            E_saved(i,j,k)=sum(P_cons)/1000-E_purch(i,j,k); %MWh
            % Economic analysis
            CAPEX0(i,j,k)=((c_mod+c_BOP)*P_dc_nom(i,j,k)+c_inv*P_ac_nom(i,j,k))*(1+c_eng_inst)+c_interconn*min([P_dc_nom(i,j,k),P_ac_nom(i,j,k)])+c_fixed; % €
            spec_capex=CAPEX0(i,j,k)/P_dc_nom(i,j,k);
            for y=1:lifetime+1
                if y==1
                    CAPEX(y)=CAPEX0(i,j,k); % €
                    OPEX(y)=0;
                    REV(y)=0;
                else
                    CAPEX(y)=0;
                    OPEX(y)=(c_om*P_dc_nom(i,j,k)/1000+c_om_fixed)*(1+infl)^(y-1);
                    REV(y)=E_togrid(i,j,k)*p_en_sell+E_toREC(i,j,k)*(p_en_sell+p_en_REC)+E_saved(i,j,k)*p_en_purch; % €
                end
                CF(y)=REV(y)-CAPEX(y)-OPEX(y);
            end
            if unfeasible_conf(i,j,k)==1
                IRR(i,j,k)=NaN;
                DCAC(i,j,k)=NaN;
                NPV(i,j,k)=NaN;
                h_eq(i,j,k)=NaN;
            else
                IRR(i,j,k)=irr(CF);
                DCAC(i,j,k)=P_dc_nom(i,j,k)/P_ac_nom(i,j,k);
                NPV(i,j,k)=sum(CF); % simplified as doesn't accoung for discount rate
                h_eq(i,j,k)=E_ac_net/P_dc_nom(i,j,k)*1000;
            end
                            h_eq_dc(i,j,k)=E_dc/P_dc_nom(i,j,k)*1000;

        end
    end
end

%% Plots and results
if KPI==0
    [max_IRR, idx] = max(IRR(:));
    [ind1, ind2, ind3] = ind2sub(size(IRR), idx);
    N_inv_optimal = N_inv_vet(ind1);
    tilt_optimal = tilt_vet(ind2);
    D_rtr_optimal = D_rtr_vet(ind3);
    % Optimization results
    fprintf('IRR-Optimized tilt: %.2f °\n', tilt_optimal);
    fprintf('IRR-Optimized D_{rtr}: %.2f m\n', D_rtr_optimal);
    fprintf('IRR-Optimized DC size: %.2f kWdc\n', P_dc_nom(ind1,ind2,ind3));
    fprintf('IRR-Optimized AC size: %.2f kWac\n', P_ac_nom(ind1,ind2,ind3));
    fprintf('IRR-Optimized DC/AC ratio: %.2f\n', DCAC(ind1,ind2,ind3));
    fprintf('IRR-Optimized Eq. hours: %.2f kWh/kWp\n', h_eq(ind1,ind2,ind3));
    fprintf('IRR-Optimized CAPEX: %.2f k€\n', CAPEX0(ind1,ind2,ind3)/1e3);
    fprintf('IRR-Optimized IRR: %.2f %%\n', max_IRR*100);
    fprintf('IRR-Optimized NPV: %.2f M€\n', NPV(ind1,ind2,ind3)/1e6);
    IRR_1=permute(IRR(1,:,:),[2 3 1]);
    IRR_2=permute(IRR(2,:,:),[2 3 1]);
    IRR_3=permute(IRR(3,:,:),[2 3 1]);
    IRR_4=permute(IRR(4,:,:),[2 3 1]);
    [TILT, D_RTR] = meshgrid(tilt_vet, D_rtr_vet);
    figure(1)
    hold on
    surf(TILT, D_RTR, IRR_1'); % Trasponi IRR per allineare gli indici
    surf(TILT, D_RTR, IRR_2'); % Trasponi IRR per allineare gli indici
    surf(TILT, D_RTR, IRR_3'); % Trasponi IRR per allineare gli indici
    surf(TILT, D_RTR, IRR_4'); % Trasponi IRR per allineare gli indici
    xlabel('Tilt (°)');
    ylabel('D_{rtr} (m)');
    zlabel('IRR');
    title('IRR (%)');
    colorbar;
    view(45, 30);

else

    [max_NPV, idx] = max(NPV(:));
    [ind1, ind2, ind3] = ind2sub(size(NPV), idx);
    N_inv_optimal = N_inv_vet(ind1);
    tilt_optimal = tilt_vet(ind2);
    D_rtr_optimal = D_rtr_vet(ind3);
    fprintf('NPV-Optimized tilt: %.2f °\n', tilt_optimal);
    fprintf('NPV-Optimized D_{rtr}: %.2f m\n', D_rtr_optimal);
    fprintf('NPV-Optimized DC size: %.2f kWdc\n', P_dc_nom(ind1,ind2,ind3));
    fprintf('NPV-Optimized AC size: %.2f kWac\n', P_ac_nom(ind1,ind2,ind3));
    fprintf('NPV-Optimized DC/AC ratio: %.2f\n', DCAC(ind1,ind2,ind3));
    fprintf('NPV-Optimized Eq. hours: %.2f kWh/kWp\n', h_eq(ind1,ind2,ind3));
    fprintf('NPV-Optimized CAPEX: %.2f k€\n', CAPEX0(ind1,ind2,ind3)/1e3);
    fprintf('NPV-Optimized IRR: %.2f %%\n', IRR(ind1,ind2,ind3)*100);
    fprintf('NPV-Optimized NPV: %.2f M€\n', max_NPV/1e6);
    NPV_1=permute(NPV(1,:,:),[2 3 1])*1e-6;
    NPV_2=permute(NPV(2,:,:),[2 3 1])*1e-6;
    NPV_3=permute(NPV(3,:,:),[2 3 1])*1e-6;
    NPV_4=permute(NPV(4,:,:),[2 3 1])*1e-6;

    [TILT, D_RTR] = meshgrid(tilt_vet, D_rtr_vet);
    figure(1)
    hold on
    surf(TILT, D_RTR, NPV_1'); 
    surf(TILT, D_RTR, NPV_2'); 
    surf(TILT, D_RTR, NPV_3'); 
    surf(TILT, D_RTR, NPV_4'); 
    xlabel('Tilt (°)');
    ylabel('D_{rtr} (m)');
    zlabel('NPV (M€)');
    title('NPV');
    colorbar;
    view(45, 30);
end

%% Plots 3D
% For optimized N_inv
N_inv_plot=2;
DCAC_plot=permute(DCAC(N_inv_plot,:,:),[2 3 1]);
h_eq_plot=permute(h_eq(N_inv_plot,:,:),[2 3 1]);
CAPEX0_plot=permute(CAPEX0(N_inv_plot,:,:),[2 3 1]);
h_eq_dc_plot=permute(h_eq_dc(N_inv_plot,:,:),[2 3 1]);

figure(2)
hold on
surf(TILT, D_RTR, DCAC_plot'); 
xlabel('Tilt (°)');
ylabel('D_{rtr} (m)');
zlabel('DC/AC ratio');
title('DC/AC ratio');
colorbar;
view(45, 30);

figure(3)
hold on
surf(TILT, D_RTR, h_eq_plot'); 
xlabel('Tilt (°)');
ylabel('D_{rtr} (m)');
zlabel('Eq. hours');
title('Eq. hours');
colorbar;
view(45, 30);

figure(4)
hold on
surf(TILT, D_RTR, CAPEX0_plot'); 
xlabel('Tilt (°)');
ylabel('D_{rtr} (m)');
zlabel('CAPEX');
title('CAPEX');
colorbar;
view(45, 30);



%% Plot operation (Optimized configuration)
D_rtr_vet=D_rtr_optimal;
tilt_vet=tilt_optimal;
N_inv_vet=N_inv_optimal;
for i=1:length(N_inv_vet)
    for j=1:length(tilt_vet)
        for k=1:length(D_rtr_vet)
            tilt(i,j,k)=tilt_vet(j);
            D_rtr(i,j,k)=D_rtr_vet(k);
            % PV layout
            N_rows(i,j,k)=floor((L_r-2*d_edge)/(W_m*cosd(tilt(i,j,k))+D_rtr(i,j,k)));
            N_mod_rows(i,j,k)=floor((W_r-2*d_edge)/L_m);
            N_mod(i,j,k)=N_rows(i,j,k)*N_mod_rows(i,j,k);
            P_dc_nom(i,j,k)=N_mod(i,j,k)*P_stc_mod/1000; % kW
            P_ac_nom(i,j,k)=N_inv_vet(i)*P_ac_inv; % kW

            % Modules-Inverter matching verification
            T_cell_max=max(T_amb)+(NOCT-25)/800*1000;
            T_cell_min=min(T_amb);
            V_oc_Tmin=V_oc+voltage_coeff*(T_cell_min-25);
            V_mpp_Tmin=V_mpp+voltage_coeff*(T_cell_min-25);
            % V_mpp_Tmax=V_mpp+voltage_coeff*(T_cell_max-25);
            I_mpp_Tmax=I_mpp+current_coeff*(T_cell_max-25);
            I_sc_Tmax=I_sc+current_coeff*(T_cell_max-25);
            N_mod_string_oc=floor(V_max_inv/V_oc_Tmin);
            N_mod_string_mpp=floor(V_max_mppt/V_mpp_Tmin);
            N_mod_string(i,j,k)=min(N_mod_string_oc,N_mod_string_mpp);
            N_strings_mpp_max=ceil(N_mod(i,j,k)/N_mod_string(i,j,k)/N_inv_vet(i)/N_mppt);
            I_mpp_max_mpp=N_strings_mpp_max*I_mpp_Tmax;
            I_mpp_max_sc=N_strings_mpp_max*I_sc_Tmax;
            if I_mpp_max_mpp>=I_max_mppt || I_mpp_max_sc>=I_sc_max_mppt
                unfeasible_conf(i,j,k)=1;
            end
            % Yearly analysis
            for h=1:length(hours_vet)
                % Sun position and radiation
                n=ceil(h/24);
                delta(h)= 23.45*sind(360/365*(n+284)); % declination angle
                E_n(h)=229.18*(0.000075+0.001868*cosd(360*(n-1)/365)-0.03277*sind(360*(n-1)/365)-0.014615*cosd(2*360*(n-1)/365)-0.04080*sind(2*360*(n-1)/365));
                t_s(h)=(h-(n-1)*24)+(long-STZ*15)/15+E_n(h)/60; % solar time
                omega(h)=15*(t_s(h)-12); % hour angle
                theta_z(h)=acosd(sind(delta(h))*sind(lat)+cosd(delta(h))*cosd(lat)*cosd(omega(h))); % solar zenith angle
                gamma_s(h)=acosd((cosd(theta_z(h))*sind(lat)-sind(delta(h)))/(cosd(90-theta_z(h))*cosd(lat))*sign(lat)); % solar azmiuth angle
                theta(h)=acosd(cosd(theta_z(h))*cosd(tilt(i,j,k))+sind(theta_z(h))*sind(tilt(i,j,k))*cosd(gamma_s(h))); % incidence angle
                G_tot(h)=DNI(h)*cosd(theta(h))+DIFF(h)*(1+cosd(tilt(i,j,k)))/2+(DNI(h)*cosd(theta_z(h))+DIFF(h))*rho_g*(1-cosd(tilt(i,j,k)))/2;
                alpha_s(h)=90-theta_z(h);
                x=W_m*sind(tilt(i,j,k))/tand(alpha_s(h))+W_m*cosd(tilt(i,j,k))-(D_rtr(i,j,k)+W_m*cosd(tilt(i,j,k)));
                if alpha_s(h)<=0
                    s(h)=W_m;
                    A_active(h)=0;
                else
                    s(h)=min([W_m,max([0,(x*sind(alpha_s(h)))/sind(180-alpha_s(h)-tilt(i,j,k))])]);
                    A_active(h)=((W_m-s(h))*(N_rows(i,j,k)-1)+W_m)*N_mod_rows(i,j,k)*L_m;
                end
                G_av(h)=G_tot(h)/(N_mod(i,j,k)*L_m*W_m)*A_active(h);
                T_c(h)=T_amb(h)+(NOCT-20)/800*G_tot(h);
                P_dc(h)=G_av(h)/1000*P_stc_mod*(1+power_coeff*(T_c(h)-25))*N_mod(i,j,k)/1000; % kW
                P_dc_net(h)=P_dc(h)*(1-DC_losses);
                P_ac(h)=min([P_dc_net(h)*eta_inv,P_ac_nom(i,j,k)]);
                P_ac_net(h)=P_ac(h)*(1-AC_losses);
                h_index=int32(h-(n-1)*24);
                P_cons(h)=build_cons(h_index);
                P_REC(h)=REC_cons(h_index);
                if P_ac_net(h)<P_cons(h)
                    P_purch(h)=P_cons(h)-P_ac_net(h);
                    P_toREC(h)=0;
                    P_togrid(h)=0;
                else
                    if P_ac_net(h)-P_cons(h)<P_REC(h)
                        P_purch(h)=0;
                        P_togrid(h)=0;
                        P_toREC(h)=P_ac_net(h)-P_cons(h);
                    else
                        P_purch(h)=0;
                        P_toREC(h)=P_REC(h);
                        P_togrid(h)=P_ac_net(h)-P_cons(h)-P_REC(h);
                    end
                end
            end
            eta_shad(i,j,k)=sum(G_av)/sum(G_tot);
            E_dc=sum(P_dc)/1000; %MWh
            E_ac_net=sum(P_ac_net)/1000; %MWh
            clipping_losses=sum(P_dc_net)/1000*eta_inv*(1-AC_losses)-E_ac_net; %MWh
            clipping_losses_perc=clipping_losses/(sum(P_dc_net)/1000*eta_inv*(1-AC_losses));
            E_purch(i,j,k)=sum(P_purch)/1000; %MWh
            E_toREC(i,j,k)=sum(P_toREC)/1000; %MWh
            E_togrid(i,j,k)=sum(P_togrid)/1000; %MWh
            E_saved(i,j,k)=sum(P_cons)/1000-E_purch(i,j,k); %MWh
            % Economic analysis
            CAPEX0(i,j,k)=((c_mod+c_BOP)*P_dc_nom(i,j,k)+c_inv*P_ac_nom(i,j,k))*(1+c_eng_inst)+c_interconn*P_ac_nom(i,j,k)+c_fixed; % €
            spec_capex=CAPEX0(i,j,k)/P_dc_nom(i,j,k);
            for y=1:lifetime+1
                if y==1
                    CAPEX(y)=CAPEX0(i,j,k); % €
                    OPEX(y)=0;
                    REV(y)=0;
                else
                    CAPEX(y)=0;
                    OPEX(y)=(c_om*P_dc_nom(i,j,k)/1000+c_om_fixed)*(1+infl)^(y-1);
                    REV(y)=E_togrid(i,j,k)*p_en_sell+E_toREC(i,j,k)*(p_en_sell+p_en_REC)+E_saved(i,j,k)*p_en_purch; % €
                end
                CF(y)=REV(y)-CAPEX(y)-OPEX(y);
            end
            if unfeasible_conf(i,j,k)==1
                IRR(i,j,k)=NaN;
                DCAC(i,j,k)=NaN;
                NPV(i,j,k)=NaN;
                h_eq(i,j,k)=NaN;

            else
                IRR(i,j,k)=irr(CF);
                DCAC(i,j,k)=P_dc_nom(i,j,k)/P_ac_nom(i,j,k);
                NPV(i,j,k)=sum(CF); % simplified as doesn't accoung for discount rate
                h_eq(i,j,k)=E_ac_net/P_dc_nom(i,j,k)*1000;

            end
        end
    end
end
h_iniz=4000;
h_fin=4100;
figure(11)
hold on
plot(hours_vet(h_iniz:h_fin)-h_iniz,P_ac_net(h_iniz:h_fin),'linewidth',1)
plot(hours_vet(h_iniz:h_fin)-h_iniz,P_cons(h_iniz:h_fin),'linewidth',1)
plot(hours_vet(h_iniz:h_fin)-h_iniz,P_REC(h_iniz:h_fin)+P_cons(h_iniz:h_fin),'linewidth',1)
plot(hours_vet(h_iniz:h_fin)-h_iniz,P_toREC(h_iniz:h_fin),'linewidth',1)
plot(hours_vet(h_iniz:h_fin)-h_iniz,P_togrid(h_iniz:h_fin),'linewidth',1)
legend('P_{ac net}','P_{cons}','P_{cons+REC}','P_{to REC}','P_{to grid}')
xlabel('Time [h]')
ylabel('Power [kW]')