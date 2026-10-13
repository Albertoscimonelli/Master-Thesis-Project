function S = indicator_clusters(AGR, opts)
%INDICATOR_CLUSTERS  Il sottoinsieme minimo di indicatori: si raggruppano
%   quelli che ordinano i metodi allo stesso modo e se ne tiene uno per gruppo.
%
%   A CHE DOMANDA RISPONDE
%     "which minimal subset of indicators suffices to discriminate among the
%     mechanisms?" (punto iii della domanda di ricerca). Due indicatori con
%     tau-b medio vicino a +1 danno la stessa graduatoria: tenerli entrambi non
%     aggiunge informazione, solo peso a quella dimensione.
%
%   IL METODO, PASSO PER PASSO
%     1. Distanza fra due indicatori: d = 1 - tau_medio, con tau_medio la media
%        sulle comunita' del tau-b gia' orientato (AGR.tauMedio). d = 0 stessa
%        graduatoria, d = 1 indipendenti, d = 2 graduatorie opposte.
%     2. Raggruppamento gerarchico AVERAGE-LINKAGE, scritto a mano (il progetto
%        non dipende dallo Statistics Toolbox): si fondono via via i due gruppi
%        con la distanza media minore fra i loro membri.
%     3. Si taglia l'albero a una soglia di tau (opts.tagli, def. 0.7 0.5 0.3):
%        stanno nello stesso gruppo indicatori con tau medio fra gruppi almeno
%        pari alla soglia. Il taglio principale e' opts.taglioPrincipale (0.5).
%     4. Rappresentante: il membro con il tau medio piu' alto verso gli altri
%        membri del gruppo (a pari merito, quello che viene prima in AGR).
%     Esempio: tau(EI, Gini) = 1 per costruzione, quindi i due finiscono nello
%     stesso gruppo a distanza zero, al primo passo.
%
%   DUE PROVE CHE IL SOTTOINSIEME BASTI
%     a) Concordanza delle coppie: per ogni indicatore, la quota di coppie di
%        metodi (distinte da entrambi, entro la soglia di rilevanza) che il suo
%        rappresentante ordina nello stesso verso. 1 = toglierlo non perde
%        nessun ordinamento.
%     b) Fronte di Pareto: per ogni comunita', i metodi non dominati usando i
%        soli rappresentanti e usando tutti gli indicatori, con la stessa regola
%        di dominanza di sintesi_risultati. Si riportano le due dimensioni: con
%        molti criteri il fronte tende a contenere tutti, e la coincidenza va
%        letta insieme alla dimensione.
%
%   INDICATORI AMMESSI
%     Solo quelli che discriminano in almeno opts.minComunita comunita' (def.
%     meta'): con poche comunita' il tau medio non e' affidabile.
%
%   INPUT
%     AGR   struct di compute_indicator_agreement (soglia di rilevanza applicata)
%     opts  .tagli             def. [0.7 0.5 0.3]   soglie di tau
%           .taglioPrincipale  def. 0.5
%           .minComunita       def. ceil(nK/2)
%           .validateSelf      def. true
%
%   OUTPUT (struct S)
%     .fusioni      table  passo, distanza, tau equivalente, gruppi fusi
%     .gruppi       table  per taglio: gruppo, indicatori, rappresentante
%     .sufficienza  table  per taglio e indicatore: rappresentante e concordanza
%     .pareto       table  per comunita': fronte con i rappresentanti e con tutti
%     .esclusi      string indicatori non ammessi
%
%   Vedi anche: compute_indicator_agreement, tradeoff_losses, sintesi_risultati

    if nargin < 2 || isempty(opts), opts = struct(); end
    nK = size(AGR.scores, 3);
    if ~isfield(opts, 'tagli'),            opts.tagli = [0.7 0.5 0.3]; end
    if ~isfield(opts, 'taglioPrincipale'), opts.taglioPrincipale = 0.5; end
    if ~isfield(opts, 'minComunita'),      opts.minComunita = ceil(nK / 2); end
    if ~isfield(opts, 'validateSelf'),     opts.validateSelf = true; end
    if opts.validateSelf, local_validate_self(); end

    indicAll = string(AGR.indicators(:));
    ammesso  = sum(AGR.discrimina, 2) >= opts.minComunita;
    S.esclusi = indicAll(~ammesso);
    idx   = find(ammesso);
    indic = indicAll(idx);
    nI    = numel(idx);
    T     = AGR.tauMedio(idx, idx);
    D     = 1 - T;
    D(logical(eye(nI))) = 0;

    % --- Average-linkage ----------------------------------------------------
    gruppi  = num2cell(1:nI);
    fusioni = {};
    while numel(gruppi) > 1
        best = [Inf 0 0];
        for a = 1:numel(gruppi)
            for b = a+1:numel(gruppi)
                dd = D(gruppi{a}, gruppi{b});
                dm = mean(dd(~isnan(dd)));
                if ~isempty(dm) && ~isnan(dm) && dm < best(1)
                    best = [dm a b];
                end
            end
        end
        if isinf(best(1)), break; end
        a = best(2); b = best(3);
        fusioni(end+1, :) = {size(fusioni, 1) + 1, best(1), 1 - best(1), ...
                             strjoin(indic(gruppi{a}), " + "), strjoin(indic(gruppi{b}), " + ")}; %#ok<AGROW>
        gruppi{a} = [gruppi{a} gruppi{b}];
        gruppi(b) = [];
    end
    S.fusioni = cell2table(fusioni, 'VariableNames', ...
        {'Passo','Distanza','TauEquivalente','GruppoA','GruppoB'});

    % --- Gruppi ai tagli, rappresentanti, concordanza -----------------------
    rowsG = {}; rowsS = {};
    for t = opts.tagli(:).'
        G = local_taglia(D, 1 - t);
        for g = 1:numel(G)
            m   = G{g};
            rep = local_rappresentante(T, m);
            if numel(m) > 1
                tt = T(m, m); tt(logical(eye(numel(m)))) = NaN;
                tauInt = mean(tt(:), 'omitnan');
            else
                tauInt = NaN;
            end
            rowsG(end+1, :) = {t, g, numel(m), strjoin(indic(m), "; "), indic(rep), tauInt}; %#ok<AGROW>
            for j = m
                rowsS(end+1, :) = {t, indic(j), indic(rep), T(j, rep), ...
                                   local_concordanza(AGR, idx(j), idx(rep))}; %#ok<AGROW>
            end
        end
    end
    S.gruppi = cell2table(rowsG, 'VariableNames', ...
        {'TaglioTau','Gruppo','NIndicatori','Indicatori','Rappresentante','TauMedioInterno'});
    S.sufficienza = cell2table(rowsS, 'VariableNames', ...
        {'TaglioTau','Indicatore','Rappresentante','TauConRappresentante','ConcordanzaCoppie'});

    % --- Prova del fronte di Pareto al taglio principale --------------------
    G    = local_taglia(D, 1 - opts.taglioPrincipale);
    reps = idx(cellfun(@(m) local_rappresentante(T, m), G));
    metodi = string(AGR.methods(:));
    rowsP = {};
    for c = 1:nK
        okTutti = idx(AGR.discrimina(idx, c));
        okRep   = reps(AGR.discrimina(reps, c));
        Xt = AGR.scores(:, okTutti, c);  Xr = AGR.scores(:, okRep, c);
        if isempty(okRep) || any(isnan(Xt(:))) || any(isnan(Xr(:))), continue; end
        ndT = local_non_dominati(Xt, AGR.tolTie(okTutti, c).');
        ndR = local_non_dominati(Xr, AGR.tolTie(okRep, c).');
        rowsP(end+1, :) = {string(AGR.schede(c)), numel(okRep), numel(okTutti), nnz(ndR), nnz(ndT), ...
                           isequal(ndR, ndT), strjoin(metodi(ndR & ~ndT), "; "), ...
                           strjoin(metodi(ndT & ~ndR), "; ")}; %#ok<AGROW>
    end
    S.pareto = cell2table(rowsP, 'VariableNames', {'Scheda','NRappresentanti','NIndicatori', ...
        'FronteRappresentanti','FronteTutti','Coincidono','SoloConRappresentanti','SoloConTutti'});
end


function G = local_taglia(D, dMax)
% Ripete l'average-linkage fermandosi quando la distanza minima supera dMax.
    n = size(D, 1);
    G = num2cell(1:n);
    while numel(G) > 1
        best = [Inf 0 0];
        for a = 1:numel(G)
            for b = a+1:numel(G)
                dd = D(G{a}, G{b});
                dm = mean(dd(~isnan(dd)));
                if ~isempty(dm) && ~isnan(dm) && dm < best(1), best = [dm a b]; end
            end
        end
        if best(1) > dMax + 1e-12, break; end
        G{best(2)} = [G{best(2)} G{best(3)}];
        G(best(3)) = [];
    end
end


function r = local_rappresentante(T, m)
% Il membro con il tau medio piu' alto verso gli altri membri del gruppo.
    if numel(m) == 1, r = m; return; end
    tt = T(m, m); tt(logical(eye(numel(m)))) = NaN;
    [~, k] = max(mean(tt, 2, 'omitnan'));
    r = m(k);
end


function q = local_concordanza(AGR, j, r)
% Quota di coppie di metodi distinte da entrambi gli indicatori e ordinate nello
% stesso verso, sommata su tutte le comunita' in cui entrambi discriminano.
    if j == r, q = 1; return; end
    conc = 0; tot = 0;
    for c = 1:size(AGR.scores, 3)
        if ~AGR.discrimina(j, c) || ~AGR.discrimina(r, c), continue; end
        sj = AGR.scores(:, j, c); sr = AGR.scores(:, r, c);
        for a = 1:numel(sj)
            for b = a+1:numel(sj)
                dj = local_segno(sj(a) - sj(b), AGR.tolTie(j, c));
                dr = local_segno(sr(a) - sr(b), AGR.tolTie(r, c));
                if dj ~= 0 && dr ~= 0
                    tot  = tot + 1;
                    conc = conc + (dj == dr);
                end
            end
        end
    end
    q = conc / max(tot, 1);
    if tot == 0, q = NaN; end
end


function s = local_segno(d, tol)
    if isnan(d) || abs(d) <= tol, s = 0; else, s = sign(d); end
end


function nd = local_non_dominati(X, tol)
% Stessa regola di sintesi_risultati: A domina B se A >= B - tol su tutti i
% criteri e A > B + tol su almeno uno.
    m  = size(X, 1);
    nd = true(m, 1);
    for b = 1:m
        for a = 1:m
            if a == b, continue; end
            if all(X(a, :) >= X(b, :) - tol) && any(X(a, :) > X(b, :) + tol)
                nd(b) = false; break
            end
        end
    end
end


function local_validate_self()
% Tre indicatori su 4 metodi e 2 comunita': I1 e I2 danno la stessa
% graduatoria, I3 quella opposta. Al taglio 0.5 i gruppi sono {I1, I2} e {I3}.
    s1 = [4 3 2 1].';  s3 = -s1;
    A.scores     = cat(3, [s1 s1 s3], [s1 s1 s3]);
    A.tolTie     = zeros(3, 2);
    A.discrimina = true(3, 2);
    A.methods    = ["M1" "M2" "M3" "M4"];
    A.indicators = ["I1" "I2" "I3"];
    A.schede     = ["C1" "C2"];
    A.tauMedio   = [1 1 -1; 1 1 -1; -1 -1 1];
    S = indicator_clusters(A, struct('validateSelf', false, 'tagli', 0.5));
    assert(height(S.gruppi) == 2 && any(S.gruppi.Indicatori == "I1; I2"), ...
           'indicator_clusters: auto-test fallito sui gruppi');
    assert(all(S.sufficienza.ConcordanzaCoppie == 1), ...
           'indicator_clusters: auto-test fallito sulla concordanza');
    assert(abs(S.fusioni.Distanza(1)) < 1e-12, ...
           'indicator_clusters: la prima fusione deve essere a distanza zero');
end
