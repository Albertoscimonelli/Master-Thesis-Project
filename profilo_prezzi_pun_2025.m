function [TT, S, P] = profilo_prezzi_pun_2025(modalita, festiviExtra)
% PROFILO_PREZZI_PUN_2025
% Crea il profilo orario dei prezzi PUN per tutto il 2025.
%
% INPUT
%   modalita      : "MONORARIA" | "ORARIO_VARIABILE" | "BIORARIA"
%   festiviExtra  : datetime opzionale con eventuali festivi locali aggiuntivi
%
% OUTPUT
%   TT : timetable oraria per tutto il 2025 con:
%        - MeseNum
%        - Mese
%        - GiornoTipo
%        - Ora
%        - Fascia
%        - Prezzo
%
%   S  : tabella riassuntiva compatta per mese/fascia/intervallo
%   P  : tabella prezzi mensili usata internamente
%
% ESEMPI
%   [TT,S] = profilo_prezzi_pun_2025("MONORARIA");
%   [TT,S] = profilo_prezzi_pun_2025("ORARIO_VARIABILE");
%   [TT,S] = profilo_prezzi_pun_2025("BIORARIA");
%
% NOTA
%   Il profilo è costruito con 8760 ore (anno 2025, senza timezone).

    if nargin < 2
        festiviExtra = datetime.empty(0,1);
    end

    modalita = upper(string(modalita));

    modalitaValide = ["MONORARIA","ORARIO_VARIABILE","BIORARIA"];
    if ~ismember(modalita, modalitaValide)
        error('modalita deve essere "MONORARIA", "ORARIO_VARIABILE" oppure "BIORARIA".');
    end

    %========================
    % Prezzi mensili 2025
    %========================
    P = datiPrezzi2025();

    %========================
    % Festivi 2025
    %========================
    festivi = festiviNazionali2025();
    if ~isempty(festiviExtra)
        festiviExtra = dateshift(festiviExtra(:), 'start', 'day');
        festivi = unique([festivi; festiviExtra]);
    end

    %========================
    % Asse orario 2025
    %========================
    t = (datetime(2025,1,1,0,0,0):hours(1):datetime(2025,12,31,23,0,0)).';
    n = numel(t);

    meseNum = month(t);
    ora = hour(t);
    wd = weekday(t); % 1=dom, 2=lun, ..., 7=sab
    giorno = dateshift(t, 'start', 'day');

    isFestivo = ismember(giorno, festivi);
    isDom = (wd == 1);
    isSab = (wd == 7);
    isFeriale = (wd >= 2 & wd <= 6) & ~isFestivo;

    %========================
    % Tipo giorno
    %========================
    giornoTipo = strings(n,1);
    giornoTipo(isFeriale) = "Feriale";
    giornoTipo(isSab & ~isFestivo) = "Sabato";
    giornoTipo(isDom & ~isFestivo) = "Domenica";
    giornoTipo(isFestivo) = "Festivo";

    %========================
    % Fascia e prezzo orario
    %========================
    fascia = strings(n,1);
    prezzo = zeros(n,1);

    switch modalita

        case "MONORARIA"
            fascia(:) = "MONORARIA";
            prezzo = P.Monoraria(meseNum);

        case "BIORARIA"
            % F1 = lun-ven 08:00-19:00, esclusi i festivi
            % F23 = tutto il resto
            isF1 = isFeriale & (ora >= 8 & ora < 19);

            fascia(:) = "F23";
            fascia(isF1) = "F1";

            prezzo = P.F23(meseNum);
            prezzo(isF1) = P.F1(meseNum(isF1));

        case "ORARIO_VARIABILE"
            % F1 = lun-ven 08:00-19:00, esclusi festivi
            % F2 = lun-ven 07:00-08:00 e 19:00-23:00
            %      sabato 07:00-23:00
            % F3 = lun-sab 23:00-07:00
            %      domenica e festivi 00:00-24:00

            isF1 = isFeriale & (ora >= 8 & ora < 19);

            isF2 = ...
                (isFeriale & ((ora >= 7 & ora < 8) | (ora >= 19 & ora < 23))) | ...
                ((isSab & ~isFestivo) & (ora >= 7 & ora < 23));

            fascia(:) = "F3";
            fascia(isF2) = "F2";
            fascia(isF1) = "F1";

            prezzo = P.F3(meseNum);
            prezzo(isF2) = P.F2(meseNum(isF2));
            prezzo(isF1) = P.F1(meseNum(isF1));
    end

    %========================
    % Timetable oraria
    %========================
    meseNome = P.Mese(meseNum);

    TT = timetable(t, meseNum, meseNome, giornoTipo, ora, fascia, prezzo, ...
        'VariableNames', {'MeseNum','Mese','GiornoTipo','Ora','Fascia','Prezzo'});

    %========================
    % Sommario compatto
    %========================
    S = creaSommario(modalita, P);
end


%======================================================================
function P = datiPrezzi2025()
% Prezzi PUN Index GME 2025, in euro/kWh

    MeseNum = (1:12).';

    Mese = [ ...
        "Gennaio 2025"
        "Febbraio 2025"
        "Marzo 2025"
        "Aprile 2025"
        "Maggio 2025"
        "Giugno 2025"
        "Luglio 2025"
        "Agosto 2025"
        "Settembre 2025"
        "Ottobre 2025"
        "Novembre 2025"
        "Dicembre 2025" ];

    Monoraria = [ ...
        0.143030
        0.150360
        0.120550
        0.099850
        0.093580
        0.111780
        0.113130
        0.108790
        0.109080
        0.111040
        0.117090
        0.115490 ];

    F1 = [ ...
        0.158320
        0.157640
        0.121680
        0.095840
        0.089090
        0.113060
        0.108960
        0.105580
        0.109590
        0.117830
        0.129590
        0.130090 ];

    F2 = [ ...
        0.151610
        0.158950
        0.134860
        0.115080
        0.110640
        0.126760
        0.127100
        0.117970
        0.120930
        0.121660
        0.124020
        0.119980 ];

    F3 = [ ...
        0.128540
        0.139910
        0.111650
        0.095050
        0.087110
        0.103630
        0.108490
        0.106040
        0.101880
        0.099480
        0.105510
        0.104520 ];

    F23 = [ ...
        0.139152
        0.148668
        0.122327
        0.104264
        0.097934
        0.114270
        0.117050
        0.111528
        0.110643
        0.109683
        0.114025
        0.111632 ];

    P = table(MeseNum, Mese, Monoraria, F1, F2, F3, F23);
end


%======================================================================
function festivi = festiviNazionali2025()
% Festivi nazionali italiani 2025
% Pasqua 2025 è domenica, quindi è già coperta come F3/Domenica.
% Inserisco anche Pasquetta.

    festivi = datetime([ ...
        "2025-01-01"
        "2025-01-06"
        "2025-04-21"
        "2025-04-25"
        "2025-05-01"
        "2025-06-02"
        "2025-08-15"
        "2025-11-01"
        "2025-12-08"
        "2025-12-25"
        "2025-12-26"], ...
        'InputFormat', 'yyyy-MM-dd');

    festivi = dateshift(festivi(:), 'start', 'day');
end


%======================================================================
function S = creaSommario(modalita, P)
% Tabella compatta mese/intervallo/fascia/prezzo

    righe = {};

    for m = 1:height(P)
        mese = P.Mese(m);

        switch modalita

            case "MONORARIA"
                righe(end+1,:) = {mese, "Tutti", "00:00-24:00", "MONORARIA", P.Monoraria(m)};

            case "BIORARIA"
                righe(end+1,:) = {mese, "Feriale",           "00:00-08:00", "F23", P.F23(m)};
                righe(end+1,:) = {mese, "Feriale",           "08:00-19:00", "F1",  P.F1(m)};
                righe(end+1,:) = {mese, "Feriale",           "19:00-24:00", "F23", P.F23(m)};
                righe(end+1,:) = {mese, "Sabato",            "00:00-24:00", "F23", P.F23(m)};
                righe(end+1,:) = {mese, "Domenica/Festivi",  "00:00-24:00", "F23", P.F23(m)};

            case "ORARIO_VARIABILE"
                righe(end+1,:) = {mese, "Feriale",           "00:00-07:00", "F3", P.F3(m)};
                righe(end+1,:) = {mese, "Feriale",           "07:00-08:00", "F2", P.F2(m)};
                righe(end+1,:) = {mese, "Feriale",           "08:00-19:00", "F1", P.F1(m)};
                righe(end+1,:) = {mese, "Feriale",           "19:00-23:00", "F2", P.F2(m)};
                righe(end+1,:) = {mese, "Feriale",           "23:00-24:00", "F3", P.F3(m)};
                righe(end+1,:) = {mese, "Sabato",            "00:00-07:00", "F3", P.F3(m)};
                righe(end+1,:) = {mese, "Sabato",            "07:00-23:00", "F2", P.F2(m)};
                righe(end+1,:) = {mese, "Sabato",            "23:00-24:00", "F3", P.F3(m)};
                righe(end+1,:) = {mese, "Domenica/Festivi",  "00:00-24:00", "F3", P.F3(m)};
        end
   end

    S = cell2table(righe, ...
        'VariableNames', {'Mese','GiornoTipo','Intervallo','Fascia','Prezzo'});

    S.Mese = string(S.Mese);
    S.GiornoTipo = string(S.GiornoTipo);
    S.Intervallo = string(S.Intervallo);
    S.Fascia = string(S.Fascia);
end