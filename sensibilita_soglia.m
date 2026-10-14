function S = sensibilita_soglia(RESULTS, optsAGR, soglie)
%SENSIBILITA_SOGLIA  Quanto i risultati di §7b dipendono dalla soglia di
%   rilevanza: inversioni e vincitori ricalcolati a piu' soglie, dagli stessi
%   RESULTS, senza rilanciare i metodi.
%
%   PERCHE' SERVE
%     La soglia (README §7.6) e' una scelta di modello: due metodi sono "a
%     pari" se distano meno del 10% dell'escursione fra i metodi (5% di v(N)
%     sugli indicatori in euro). Va riportato quanto i risultati cambiano se la
%     si sposta.
%
%   PERCHE' SI RIPARTE DA RESULTS E NON DALL'AGR DI MAIN2
%     apply_relevance_threshold prende il MASSIMO fra la tolleranza che trova e
%     quella nuova. Applicata a un AGR gia' sogliato al 10%, una soglia del 5%
%     non abbasserebbe nulla. Qui l'AGR si ricalcola ogni volta con la sola
%     tolleranza numerica, poi si applica la soglia di quel giro.
%
%   LE SOGLIE, A COPPIE  (soglie [k x 2] = [fracEscursione fracVN])
%     def. [0 0; 0.05 0.025; 0.10 0.05; 0.20 0.10]: la riga 3 e' quella di
%     MAIN2, la riga 1 e' la sola tolleranza numerica. Le due frazioni si
%     muovono insieme, nello stesso rapporto della soglia di default.
%
%   INPUT
%     RESULTS  struct array di MAIN2
%     optsAGR  opzioni di compute_indicator_agreement (escludiMetodi,
%              escludiIndicatori): le stesse di MAIN2 §7b
%     soglie   [k x 2], facoltativo
%
%   OUTPUT (struct S)
%     .perSweep   table, una riga per (soglia, sweep): coppie invertite e quota
%     .vincitori  table, una riga per soglia: celle (indicatore x comunita') il
%                 cui vincitore differisce da quello alla soglia di MAIN2; fra
%                 queste, quelle in cui il primo e' un ALTRO metodo (e non un
%                 pareggio); celle "a pari" (nessun vincitore unico)
%
%   Vedi anche: apply_relevance_threshold, ricalcola_inversioni_soglia

    if nargin < 3 || isempty(soglie)
        soglie = [0 0; 0.05 0.025; 0.10 0.05; 0.20 0.10];
    end
    if nargin < 2 || isempty(optsAGR), optsAGR = struct(); end
    optsAGR.quiet = true;
    iRif = find(abs(soglie(:,1) - 0.10) < 1e-12 & abs(soglie(:,2) - 0.05) < 1e-12, 1);

    vinc = cell(size(soglie, 1), 1);
    rowsS = {}; rowsV = {};
    for s = 1:size(soglie, 1)
        AGR  = compute_indicator_agreement(RESULTS, optsAGR);
        AGR  = apply_relevance_threshold(AGR, [RESULTS.vGrand], struct( ...
                   'fracEscursione', soglie(s, 1), 'fracVN', soglie(s, 2)));
        GRID = ranking_grid(AGR, RESULTS);
        REV  = reversals_by_axis(AGR, GRID);
        P = REV.perSweep;
        for r = 1:height(P)
            rowsS(end+1, :) = {soglie(s,1), soglie(s,2), string(P.Sweep(r)), string(P.Fisso(r)), ...
                               P.SerieEsaminate(r), P.CoppieInvertite(r), P.QuotaInvertite(r), ...
                               P.InvertiteAgliEstremi(r)}; %#ok<AGROW>
        end
        vinc{s} = GRID.table;
    end
    S.perSweep = cell2table(rowsS, 'VariableNames', {'FracEscursione','FracVN','Sweep','Fisso', ...
        'SerieEsaminate','CoppieInvertite','QuotaInvertite','InvertiteAgliEstremi'});

    if ~isempty(iRif)
        rif = vinc{iRif};
        for s = 1:size(soglie, 1)
            T = vinc{s};
            [~, ia, ib] = intersect(rif.Indicatore + "|" + rif.Scheda, T.Indicatore + "|" + T.Scheda);
            va = string(rif.Vincitore(ia)); vb = string(T.Vincitore(ib));
            diversi = nnz(va ~= vb);
            % Un vincitore che diventa "(pari)" e' un pareggio in piu', non un
            % altro metodo primo: si contano a parte i cambi fra due vincitori.
            cambiVeri = nnz(va ~= vb & va ~= "(pari)" & vb ~= "(pari)");
            rowsV(end+1, :) = {soglie(s,1), soglie(s,2), numel(ia), diversi, cambiVeri, ...
                               nnz(string(T.Vincitore) == "(pari)")}; %#ok<AGROW>
        end
        S.vincitori = cell2table(rowsV, 'VariableNames', {'FracEscursione','FracVN', ...
            'Celle','VincitoreDiversoDaMAIN2','AltroMetodoPrimo','CelleAPari'});
    else
        S.vincitori = table();
    end
end
