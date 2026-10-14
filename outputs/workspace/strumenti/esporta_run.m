function esporta_run(fileMat, cartella)
%ESPORTA_RUN  Da un workspace salvato di MAIN2 a CSV lunghi, leggibili senza
%   MATLAB (pandas, Excel). Uso, dalla root del progetto:
%       addpath(pwd); addpath('outputs/workspace/strumenti');
%       esporta_run('outputs/workspace/run_2026-10-13_fino18.mat', ...
%                   'outputs/workspace/export_fino18')
%
%   Scrive: comunita.csv, tfair_lungo.csv, punteggi_orientati.csv,
%   quote_membri.csv (quote e VAN per membro e metodo), virtuosita.csv.
    L = load(fileMat, 'RESULTS', 'AGR');
    RESULTS = L.RESULTS; AGR = L.AGR;
    if ~exist(cartella, 'dir'), mkdir(cartella); end
    nK = numel(RESULTS);

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
    writetable(table(sch, n, pen, nPro, vN, sh, so, ct, quota, bind, 'VariableNames', ...
        {'Scheda','Membri','Penetrazione_pct','NProsumer','vN_EUR','Condivisa_kWh', ...
         'NonCondivisa_kWh','QuotaContendibile','QuotaIncentivata','Binding'}), ...
        fullfile(cartella, 'comunita.csv'));

    T = table();
    for c = 1:nK
        Tf = RESULTS(c).Tfair; Tf.Metodo = string(Tf.Metodo);
        Tf = addvars(Tf, repmat(sch(c), height(Tf), 1), repmat(n(c), height(Tf), 1), ...
                     repmat(pen(c), height(Tf), 1), repmat(vN(c), height(Tf), 1), ...
                     'Before', 1, 'NewVariableNames', {'Scheda','Membri','Penetrazione_pct','vN_EUR'});
        T = [T; Tf]; %#ok<AGROW>
    end
    writetable(T, fullfile(cartella, 'tfair_lungo.csv'));

    [nM, nI, ~] = size(AGR.scores);
    rows = {};
    for c = 1:nK
        for k = 1:nM
            for j = 1:nI
                rows(end+1, :) = {AGR.schede(c), AGR.methods(k), AGR.indicators(j), ...
                                  AGR.scores(k,j,c), AGR.tolTie(j,c), AGR.discrimina(j,c)}; %#ok<AGROW>
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'Scheda','Metodo','Indicatore', ...
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
                rows(end+1, :) = {sch(c), n(c), pen(c), string(M(k).nome), names(i), isP(i), phi(i), van}; %#ok<AGROW>
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'Scheda','Membri','Penetrazione_pct', ...
        'Metodo','Membro','Prosumer','Quota_EUR','VAN_EUR'}), fullfile(cartella, 'quote_membri.csv'));

    rows = {};
    for c = 1:nK
        names = string(RESULTS(c).userNames(:));
        vn = RESULTS(c).forza.virtuosita(:); vl = RESULTS(c).forzaLorda.virtuosita(:);
        for i = 1:numel(names)
            rows(end+1, :) = {sch(c), names(i), RESULTS(c).isProsumer(i), vn(i), vl(i)}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'Scheda','Membro','Prosumer', ...
        'VirtuositaNetta','VirtuositaLorda'}), fullfile(cartella, 'virtuosita.csv'));
    fprintf('Esportato %s in %s\n', fileMat, cartella);
end
