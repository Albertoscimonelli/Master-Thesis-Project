function esporta_run(fileMat, cartella)
%ESPORTA_RUN  Da un workspace salvato di MAIN2 a CSV lunghi, leggibili senza
%   MATLAB (pandas, Excel). Uso, dalla root del progetto:
%       addpath(pwd); addpath('outputs/workspace/strumenti');
%       esporta_run('outputs/workspace/run_2026-10-13_fino18.mat', ...
%                   'outputs/workspace/export_fino18')
%
%   Scrive: comunita.csv, tfair_lungo.csv, punteggi_orientati.csv,
%   quote_membri.csv (quote e VAN per membro e metodo), virtuosita.csv.
%
%   PIU' LIVELLI DI COMPOSIZIONE (run dal 20 ottobre 2026)
%     Ogni file ha la colonna Composizione: il prefisso di RESULTS(c).etichetta
%     ("PA2/CER_5_5_0" -> "PA2"), "PA0" per le schede di CER_configuration/ e per i
%     workspace che non hanno etichetta. Senza questa colonna le varianti omonime
%     (CER_5_5_0 esiste in ogni livello) finirebbero mescolate sotto lo stesso nome.
%     I punteggi orientati vengono da LIV(l).AGR, uno per livello, quando il workspace
%     ha LIV: dopo il ciclo per livelli di MAIN2 la variabile AGR e' quella
%     dell'ULTIMO livello e non copre tutte le comunita' di RESULTS.
    L = load(fileMat);
    RESULTS = L.RESULTS;
    if ~exist(cartella, 'dir'), mkdir(cartella); end
    nK = numel(RESULTS);
    comp = repmat("PA0", nK, 1);
    if isfield(RESULTS, 'etichetta')
        for c = 1:nK
            parti = split(string(RESULTS(c).etichetta), "/");
            if numel(parti) > 1, comp(c) = parti(1); end
        end
    end

    sch = strings(nK,1); n = zeros(nK,1); pen = n; vN = n; sh = n; so = n; ct = n;
    quota = n; bind = n; nPro = n;
    for c = 1:nK
        [~, sch(c)] = fileparts(char(RESULTS(c).scheda));
        n(c) = RESULTS(c).nUsers;  pen(c) = RESULTS(c).penetrazione;
        vN(c) = RESULTS(c).vGrand; sh(c) = RESULTS(c).shared_annual;
        so(c) = RESULTS(c).sold_annual; ct(c) = RESULTS(c).contendibleShare;
        nPro(c) = sum(RESULTS(c).isProsumer);
        quota(c) = RESULTS(c).soglia.quotaIncentivata; bind(c) = RESULTS(c).soglia.isBinding;
    end
    writetable(table(comp, sch, n, pen, nPro, vN, sh, so, ct, quota, bind, 'VariableNames', ...
        {'Composizione','Scheda','Membri','Penetrazione_pct','NProsumer','vN_EUR','Condivisa_kWh', ...
         'NonCondivisa_kWh','QuotaContendibile','QuotaIncentivata','Binding'}), ...
        fullfile(cartella, 'comunita.csv'));

    T = table();
    for c = 1:nK
        Tf = RESULTS(c).Tfair; Tf.Metodo = string(Tf.Metodo);
        Tf = addvars(Tf, repmat(comp(c), height(Tf), 1), repmat(sch(c), height(Tf), 1), ...
                     repmat(n(c), height(Tf), 1), repmat(pen(c), height(Tf), 1), ...
                     repmat(vN(c), height(Tf), 1), 'Before', 1, ...
                     'NewVariableNames', {'Composizione','Scheda','Membri','Penetrazione_pct','vN_EUR'});
        T = [T; Tf]; %#ok<AGROW>
    end
    writetable(T, fullfile(cartella, 'tfair_lungo.csv'));

    if isfield(L, 'LIV') && ~isempty(L.LIV)
        blocchi = struct('AGR', {L.LIV.AGR}, 'comp', cellstr("PA" + string([L.LIV.livello])));
    else
        blocchi = struct('AGR', L.AGR, 'comp', 'PA0');
    end
    rows = {};
    for b = 1:numel(blocchi)
        A = blocchi(b).AGR;
        [nM, nI, nKb] = size(A.scores);
        for c = 1:nKb
            for k = 1:nM
                for j = 1:nI
                    rows(end+1, :) = {string(blocchi(b).comp), A.schede(c), A.methods(k), ...
                                      A.indicators(j), A.scores(k,j,c), A.tolTie(j,c), ...
                                      A.discrimina(j,c)}; %#ok<AGROW>
                end
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'Composizione','Scheda','Metodo','Indicatore', ...
        'PunteggioOrientato','TolPareggio','Discrimina'}), fullfile(cartella, 'punteggi_orientati.csv'));

    rows = {};
    for c = 1:nK
        names = string(RESULTS(c).userNames(:)); isP = RESULTS(c).isProsumer(:);
        M = RESULTS(c).metodi;
        for k = 1:numel(M)
            phi = M(k).phi(:);
            for i = 1:numel(names)
                van = NaN;
                if ~isempty(RESULTS(c).NPV) && k <= size(RESULTS(c).NPV, 2), van = RESULTS(c).NPV(i, k); end
                rows(end+1, :) = {comp(c), sch(c), n(c), pen(c), string(M(k).nome), names(i), ...
                                  isP(i), phi(i), van}; %#ok<AGROW>
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'Composizione','Scheda','Membri','Penetrazione_pct', ...
        'Metodo','Membro','Prosumer','Quota_EUR','VAN_EUR'}), fullfile(cartella, 'quote_membri.csv'));

    rows = {};
    for c = 1:nK
        names = string(RESULTS(c).userNames(:));
        vn = RESULTS(c).forza.virtuosita(:); vl = RESULTS(c).forzaLorda.virtuosita(:);
        for i = 1:numel(names)
            rows(end+1, :) = {comp(c), sch(c), names(i), RESULTS(c).isProsumer(i), vn(i), vl(i)}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'Composizione','Scheda','Membro','Prosumer', ...
        'VirtuositaNetta','VirtuositaLorda'}), fullfile(cartella, 'virtuosita.csv'));
    fprintf('Esportato %s in %s\n', fileMat, cartella);
end
