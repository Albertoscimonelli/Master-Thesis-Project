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
%   ALLINEAMENTO POSIZIONALE, NON PER ETICHETTA ORARIA
%     La riga k del file e' la k-esima ora ASSOLUTA dell'anno, e va nella
%     k-esima posizione della griglia. Non si costruisce nessun timestamp dalle
%     colonne Data e Ora: servono solo a validare che il file sia completo e in
%     ordine. E' la stessa convenzione di load_pv_generation, che allinea per
%     posizione e non per data.
%
%   PERCHE', E COS'ERA SBAGLIATO PRIMA
%     Il tempo assoluto scorre uniforme: il cambio d'ora sposta le ETICHETTE,
%     non l'ordine ne' il conteggio. Un anno ha 8760 ore assolute anche con il
%     DST, perche' l'ora persa a marzo e quella guadagnata a ottobre si
%     compensano - ed e' esattamente quello che il file contiene: 8760 righe,
%     con un giorno da 23 ore e uno da 25.
%
%     Tutte le altre serie del progetto vivono su un orologio locale UNIFORME
%     senza cambio d'ora: RAMP genera 525.600 minuti consecutivi, LPG un anno
%     pieno di 8760 ore, e l'export PVsyst ha il picco di produzione a
%     mezzogiorno in TUTTI i mesi - misurato - quindi non modella il DST
%     nemmeno lui. La riga k di ciascuna e' la k-esima ora assoluta dell'anno.
%
%     Il prezzo era l'unica serie indicizzata per etichetta in ora LEGALE. Con
%     "Ora N -> +[N-1] ore dalla mezzanotte" ogni prezzo dell'ora legale
%     finiva un'ora piu' avanti sulla griglia dell'energia che doveva
%     valorizzare: misurato, nella finestra fra marzo e ottobre la mappatura
%     posizionale coincide con la vecchia TRASLATA DI UN'ORA su 5019 ore su
%     5019. Lo scarto orario non era piccolo - |differenza| media 5.08 EUR/MWh,
%     massimo 82 su 4823 ore - e la TIP e' non lineare in Pz, quindi non si
%     compensava nella media.
%
%     La vecchia mappatura, in piu', PERDEVA un prezzo vero (la 25esima ora del
%     rientro, scartata come duplicato) e ne INVENTAVA uno (l'ora mancante di
%     marzo, colmata da retime per interpolazione). Con l'allineamento
%     posizionale non serve ne' deduplicare ne' interpolare: le 8760 righe
%     coprono le 8760 posizioni, una a una.
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

    % str2double NON segnala: una cella malformata diventa NaN, e a valle
    % compute_cer_incentive la ASSORBE invece di propagarla, perche' in MATLAB
    % max(0, NaN) vale 0. Il prezzo mancante si travestirebbe da prezzo alto e
    % non ci sarebbe modo di accorgersene. Va intercettato qui, dove si sa
    % ancora quale riga del file era.
    if any(isnan(priceVal))
        primo = find(isnan(priceVal), 1);
        error('load_zonal_price:prezzoNonLeggibile', ...
              ['%d prezzi non leggibili come numero in:\n  %s\n' ...
               '  prima occorrenza alla riga %d (%s, ora %d).\n' ...
               '  Se il file usa il punto come separatore delle migliaia, ' ...
               'riesportarlo senza.'], ...
              sum(isnan(priceVal)), xlsxFile, primo, ...
              string(dateVals(primo), 'dd/MM/yyyy'), ora(primo));
    end

    % --- Il file deve essere l'elenco COMPLETO e ORDINATO dell'anno ---------
    % Con l'allineamento posizionale la corrispondenza riga <-> ora non e' piu'
    % verificata da un timestamp: va imposta qui, altrimenti un file con una
    % riga in meno sposterebbe di un'ora tutto quello che viene dopo, in
    % silenzio. Sono le tre condizioni che rendono la posizione un'informazione
    % affidabile: quante righe, in che ordine, di che anno.
    if numel(priceVal) ~= numel(tGrid)
        error('load_zonal_price:numeroOreErrato', ...
              ['Il file ha %d righe, la griglia canonica ne chiede %d:\n  %s\n' ...
               '  con l''allineamento posizionale il file deve contenere tutte ' ...
               'le ore dell''anno.'], ...
              numel(priceVal), numel(tGrid), xlsxFile);
    end
    if ~issorted(dateVals)
        error('load_zonal_price:nonCronologico', ...
              'Le date del file non sono in ordine crescente:\n  %s', xlsxFile);
    end
    % Dentro il giorno l'ora sale di uno; a inizio giorno riparte da 1. Un salto
    % qui vuol dire righe mancanti o rimescolate, ed e' cio' che la posizione
    % da sola non potrebbe accorgersi.
    salto = [false; diff(ora(:)) ~= 1 & ora(2:end) ~= 1];
    if any(salto)
        k = find(salto, 1);
        error('load_zonal_price:oreNonConsecutive', ...
              ['Salto nella numerazione delle ore alla riga %d (%s, ora %d):' ...
               '\n  %s'], ...
              k, string(dateVals(k), 'dd/MM/yyyy'), ora(k), xlsxFile);
    end
    if dateshift(dateVals(1), 'start', 'day') ~= dateshift(tGrid(1), 'start', 'day') ...
       || dateshift(dateVals(end), 'start', 'day') ~= dateshift(tGrid(end), 'start', 'day')
        error('load_zonal_price:annoDiverso', ...
              ['Il file copre %s - %s, la griglia %s - %s:\n  %s'], ...
              string(dateVals(1),   'dd/MM/yyyy'), string(dateVals(end), 'dd/MM/yyyy'), ...
              string(tGrid(1),      'dd/MM/yyyy'), string(tGrid(end),    'dd/MM/yyyy'), ...
              xlsxFile);
    end

    Pz_h = priceVal(:);
end
