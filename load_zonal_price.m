function Pz_h = load_zonal_price(xlsxFile, tGrid)
%LOAD_ZONAL_PRICE  Legge il prezzo zonale orario del Mercato del Giorno Prima
%   (MGP, export GME) e lo riallinea sulla griglia oraria canonica tGrid.
%
%   Formato atteso (3 colonne, come l'export GME "MGP-PrezziZonali"):
%     Data   dd/mm/yyyy
%     Ora    1..24 (23 o 25 nei giorni di cambio ora legale), numerazione
%            sequenziale delle ore del giorno in ora legale italiana
%     prezzo EUR/MWh, con virgola come separatore decimale
%
%   CAMBIO ORA LEGALE: tGrid (vedi MAIN.m) e' una griglia "civile" con
%   esattamente 24 ore per ogni giorno, senza modellare il DST. Il file GME
%   invece riflette l'ora legale reale: il giorno del passaggio a ora solare
%   (fine ottobre) ha 25 righe (un'ora ripetuta), quello del passaggio a ora
%   legale (fine marzo) ne ha 23 (un'ora mancante). Con la convenzione
%   "Ora N -> +[N-1] ore dalla mezzanotte" la 25esima ora del giorno di
%   rientro collide esattamente con l'ora 1 del giorno successivo: si tiene
%   la seconda (e' quella semanticamente corretta, l'inizio del giorno dopo),
%   scartando l'ora "in piu'" del cambio d'ora. Il giorno mancante di
%   un'ora, invece, viene semplicemente colmato da retime per interpolazione
%   lineare fra le ore adiacenti, senza bisogno di un caso speciale.
%
%   INPUT
%     xlsxFile  string            percorso del file .xlsx
%     tGrid     [H x 1] datetime  griglia oraria canonica di riferimento
%
%   OUTPUT
%     Pz_h  [H x 1]  prezzo zonale orario, allineato a tGrid   [EUR/MWh]

    Traw = readtable(xlsxFile, 'VariableNamingRule', 'preserve', ...
                      'TextType', 'string');

    varNames = Traw.Properties.VariableNames;
    if numel(varNames) < 3
        error('load_zonal_price:formatoInatteso', ...
              'Attese almeno 3 colonne (Data, Ora, prezzo) in:\n  %s', xlsxFile);
    end

    dataStr  = string(Traw.(varNames{1}));
    ora      = double(Traw.(varNames{2}));
    priceStr = string(Traw.(varNames{3}));

    dateVals = datetime(dataStr, 'InputFormat', 'dd/MM/yyyy');
    priceVal = str2double(strrep(priceStr, ',', '.'));

    ts = dateVals + hours(ora - 1);

    % Deduplica per timestamp tenendo l'ULTIMA occorrenza (vedi nota DST
    % sopra); unique ordina anche cronologicamente, sostituendo sortrows.
    [ts, iKeep] = unique(ts, 'last');
    priceVal    = priceVal(iKeep);

    % str2double NON segnala: una cella malformata diventa NaN, e a valle
    % compute_cer_incentive la ASSORBE invece di propagarla, perche' in MATLAB
    % max(0, NaN) vale 0. Il prezzo mancante si travestirebbe da prezzo alto e
    % non ci sarebbe modo di accorgersene. Va intercettato qui, dove si sa
    % ancora a quale timestamp corrispondeva.
    if any(isnan(priceVal))
        primo = find(isnan(priceVal), 1);
        error('load_zonal_price:prezzoNonLeggibile', ...
              ['%d prezzi non leggibili come numero in:\n  %s\n' ...
               '  prima occorrenza al timestamp %s.\n' ...
               '  Se il file usa il punto come separatore delle migliaia, ' ...
               'riesportarlo senza.'], ...
              sum(isnan(priceVal)), xlsxFile, string(ts(primo)));
    end

    % Come per i profili di carico: retime estrapola fuori dall'intervallo dei
    % dati invece di lasciare NaN.
    if min(ts) > tGrid(1) || max(ts) < tGrid(end)
        error('load_zonal_price:coperturaInsufficiente', ...
              ['I prezzi coprono %s - %s, la griglia chiede %s - %s:\n  %s\n' ...
               '  fuori da quell''intervallo retime estrapola in silenzio.'], ...
              string(min(ts)), string(max(ts)), ...
              string(tGrid(1)), string(tGrid(end)), xlsxFile);
    end

    TT        = timetable(ts, priceVal, 'VariableNames', {'price'});
    TTaligned = retime(TT, tGrid, 'linear');
    Pz_h      = TTaligned.price;
end
