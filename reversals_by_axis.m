function R = reversals_by_axis(AGR, G, opts)
%REVERSALS_BY_AXIS  Inversioni di graduatoria su una griglia a due fattori,
%   un fattore alla volta con l'altro fermo.
%
%   PERCHE' NON UNA SOLA SCANSIONE
%     extract_ranking_reversals conta i cambi di segno fra configurazioni
%     ADIACENTI lungo un asse, e l'adiacenza esiste solo se l'asse e'
%     strettamente ordinato. Con taglie diverse la penetrazione si ripete (50%
%     a 8, 10, 18 e 20 membri) e ordinare tutto per penetrazione mescolerebbe
%     l'effetto della taglia con quello della composizione. Qui la griglia si
%     legge per righe e per colonne:
%       sweep "penetrazione"  a taglia fissa, lungo le fasce  (una per taglia)
%       sweep "taglia"        a fascia fissa, lungo le taglie (una per fascia)
%     Ogni sottoinsieme ha un asse strettamente crescente, e la funzione di
%     scansione e' la stessa, non una copia: stessi punteggi, stesse tolleranze.
%
%   ATTENZIONE SULLO SWEEP DI TAGLIA
%     Jain e MinMax hanno un pavimento che dipende da n (1/n): una loro
%     inversione lungo la taglia puo' venire dal pavimento e non dal merito
%     dei metodi. E la fascia tiene fermo il RANGO della penetrazione, non il
%     suo valore esatto (20% a 5 membri, 28% a 25): lo sweep di taglia porta
%     con se' questo scarto residuo, leggibile nelle colonne di penetrazione.
%
%   INPUT
%     AGR   uscita di compute_indicator_agreement
%     G     uscita di ranking_grid
%     opts  .quiet  non stampare il riepilogo (def. false)
%
%   OUTPUT (struct R)
%     .inversioni  table  come extract_ranking_reversals, con davanti
%                         Sweep | Fisso | FissoValore, e l'asse in colonne
%                         generiche AsseDa / AsseA (% o membri secondo Sweep)
%     .sommario    table  idem, una riga per (sweep, sottoinsieme, indicatore, coppia)
%     .perSweep    table  conteggi riassuntivi per sottoinsieme

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'quiet'), opts.quiet = false; end

    [nN, nT] = size(G.idx);
    blocchi = struct('sweep', {}, 'fisso', {}, 'valore', {}, 'cfg', {}, 'asse', {});

    for r = 1:nN
        k = find(G.idx(r, :) > 0);
        blocchi(end+1) = struct('sweep', "penetrazione", ...
                                'fisso', sprintf("n = %d", G.taglie(r)), ...
                                'valore', G.taglie(r), ...
                                'cfg', G.idx(r, k), ...
                                'asse', G.penetrazione(r, k)); %#ok<AGROW>
    end
    for k = 1:nT
        r = find(G.idx(:, k) > 0).';
        blocchi(end+1) = struct('sweep', "taglia", ...
                                'fisso', G.fasce(k), ...
                                'valore', k, ...
                                'cfg', G.idx(r, k).', ...
                                'asse', G.taglie(r)); %#ok<AGROW>
    end

    INV = {};  SOM = {};
    pS = strings(0,1); pF = strings(0,1); pK = zeros(0,1);
    pSer = zeros(0,1); pInv = zeros(0,1); pEst = zeros(0,1); pTot = zeros(0,1);
    primo = true;

    for b = 1:numel(blocchi)
        B = blocchi(b);
        if numel(B.cfg) < 2, continue; end

        sub = struct('indicators', AGR.indicators, 'methods', AGR.methods, ...
                     'schede', AGR.schede(B.cfg), 'penetrazione', B.asse, ...
                     'scores', AGR.scores(:, :, B.cfg), ...
                     'discrimina', AGR.discrimina(:, B.cfg), ...
                     'tolTie', AGR.tolTie(:, B.cfg));
        X = extract_ranking_reversals(sub, struct('quiet', true, 'validateSelf', primo));
        primo = false;

        INV{end+1} = local_prefissa(local_rinomina(X.inversioni), B); %#ok<AGROW>
        SOM{end+1} = local_prefissa(local_rinomina(X.sommario),   B); %#ok<AGROW>

        pS(end+1,1)   = B.sweep;   pF(end+1,1) = B.fisso;  pK(end+1,1) = numel(B.cfg); %#ok<AGROW>
        pSer(end+1,1) = height(X.sommario); %#ok<AGROW>
        pInv(end+1,1) = sum(X.sommario.nInversioni > 0); %#ok<AGROW>
        pEst(end+1,1) = sum(X.sommario.InvertitoAgliEstremi); %#ok<AGROW>
        pTot(end+1,1) = X.nInversioni; %#ok<AGROW>
    end

    if isempty(INV)
        R = struct('inversioni', table(), 'sommario', table(), 'perSweep', table());
        return
    end
    R.inversioni = vertcat(INV{:});
    R.sommario   = vertcat(SOM{:});
    R.perSweep   = table(pS, pF, pK, pSer, pInv, pInv ./ pSer, pEst, pTot, ...
                         'VariableNames', {'Sweep', 'Fisso', 'Configurazioni', ...
                                           'SerieEsaminate', 'CoppieInvertite', ...
                                           'QuotaInvertite', 'InvertiteAgliEstremi', ...
                                           'CambiDiSegno'});

    if ~opts.quiet
        fprintf('\n=== Inversioni di graduatoria, un fattore alla volta ===\n');
        fprintf('  %-14s %-22s %5s %12s %10s\n', 'Sweep', 'Fisso', 'Conf', ...
                'Invertite', 'Estremi');
        for q = 1:height(R.perSweep)
            fprintf('  %-14s %-22s %5d %6d (%3.0f%%) %10d\n', R.perSweep.Sweep(q), ...
                    R.perSweep.Fisso(q), R.perSweep.Configurazioni(q), ...
                    R.perSweep.CoppieInvertite(q), 100*R.perSweep.QuotaInvertite(q), ...
                    R.perSweep.InvertiteAgliEstremi(q));
        end
    end
end


function T = local_rinomina(T)
%LOCAL_RINOMINA  L'asse non e' piu' sempre la penetrazione: nomi generici.
    vecchi = ["PenetrazioneDa_pct", "PenetrazioneA_pct", ...
              "PenetrazioneSegnoIniziale_pct", "PenetrazioneSegnoFinale_pct"];
    nuovi  = ["AsseDa", "AsseA", "AsseSegnoIniziale", "AsseSegnoFinale"];
    for q = 1:numel(vecchi)
        if any(T.Properties.VariableNames == vecchi(q))
            T = renamevars(T, vecchi(q), nuovi(q));
        end
    end
end

function T = local_prefissa(T, B)
%LOCAL_PREFISSA  Tre colonne in testa che dicono da quale sottoinsieme viene la riga.
    h = height(T);
    P = table(repmat(B.sweep, h, 1), repmat(string(B.fisso), h, 1), ...
              repmat(B.valore, h, 1), ...
              'VariableNames', {'Sweep', 'Fisso', 'FissoValore'});
    T = [P, T];
end
