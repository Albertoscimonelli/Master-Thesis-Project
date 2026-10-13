function S = tradeoff_losses(AGR, RESULTS, opts)
%TRADEOFF_LOSSES  Quanto costa un criterio in termini di un altro: la
%   "loss incurred by the other mechanisms" della domanda di ricerca, misurata
%   invece che contata.
%
%   PERCHE' SERVE
%     Il fronte di Pareto (sintesi_risultati) dice QUALI metodi non sono
%     dominati, non QUANTO si perde passando da uno all'altro. Molti indicatori
%     sono massimi per costruzione per un metodo (Equal Split sul Gini,
%     Nucleolo sull'eccesso, Similarity-Utilization sulla forza incentivante):
%     il vincitore e' noto prima di calcolare. L'informazione sta in quanto gli
%     ALTRI si allontanano, e in quanto costa su B il campione di A.
%
%   1) RIMPIANTO  (S.rimpianto, S.rimpiantoMedio)
%     Per metodo k, indicatore j, comunita' c, con punteggi gia' orientati
%     (piu' alto = meglio):
%         R = (max_k s - s_k) / (max_k s - min_k s)        in [0,1]
%     0 = e' il migliore, 1 = e' il peggiore. Sugli indicatori in euro si
%     riporta anche la distanza in euro, e per quelli ANNUI (opts.indicatoriAnnui,
%     def. EccessoMax_EUR) in % di v(N). NaN dove l'indicatore non discrimina.
%
%   2) PERDITE FRA CRITERI  (S.perdite, S.perditeFascia)
%     Per ogni coppia ordinata (A, B): si sceglie il metodo migliore su A e si
%     legge il suo rimpianto su B. Se su A piu' metodi sono a pari (entro la
%     soglia di rilevanza AGR.tolTie, la stessa delle inversioni) il risultato
%     non e' unico, e si riportano due letture:
%         ottimistica   fra i pari su A, il migliore su B
%         pessimistica  fra i pari su A, il peggiore su B
%     Esempio: A = Gini, B = EccessoMax_EUR. Il migliore sul Gini e' l'Equal
%     Split; se il suo eccesso e' 100 EUR su un'escursione fra 0 e 120 EUR,
%     la perdita vale 100/120 = 0,83 dell'escursione, e 100 EUR in assoluto.
%     La matrice NON e' simmetrica: scegliere il campione dell'uniformita' puo'
%     costare molto in stabilita' e il contrario poco.
%
%   INPUT
%     AGR      struct di compute_indicator_agreement, con la soglia di
%              rilevanza gia' applicata (apply_relevance_threshold)
%     RESULTS  struct array di MAIN2, nello stesso ordine di AGR.schede
%              (.nUsers .penetrazione .vGrand)
%     opts     .indicatoriAnnui  string, def. "EccessoMax_EUR"
%              .validateSelf     def. true
%
%   OUTPUT (struct S)
%     .rimpianto       table, una riga per (comunita', metodo, indicatore)
%     .rimpiantoMedio  table, una riga per (metodo, indicatore): media, min, max
%     .perdite         table, una riga per (A, B): medie sulle comunita'
%     .perditeFascia   table, come sopra per fascia di penetrazione
%
%   Vedi anche: indicator_clusters, sintesi_risultati, apply_relevance_threshold

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'indicatoriAnnui'), opts.indicatoriAnnui = "EccessoMax_EUR"; end
    if ~isfield(opts, 'validateSelf'),    opts.validateSelf    = true; end
    if opts.validateSelf, local_validate_self(); end

    [nM, nI, nK] = size(AGR.scores);
    assert(numel(RESULTS) == nK, 'tradeoff_losses: RESULTS e AGR hanno %d e %d comunita''.', ...
           numel(RESULTS), nK);
    metodi = string(AGR.methods(:));
    indic  = string(AGR.indicators(:));
    inEuro = endsWith(indic, "_EUR");
    annuo  = ismember(indic, string(opts.indicatoriAnnui(:)));

    n   = [RESULTS.nUsers].';
    pen = [RESULTS.penetrazione].';
    vN  = [RESULTS.vGrand].';
    sch = strings(nK, 1);
    for c = 1:nK, [~, sch(c)] = fileparts(char(RESULTS(c).scheda)); end
    fascia = local_fascia(n, pen);

    % --- 1) Rimpianto ------------------------------------------------------
    R    = nan(nM, nI, nK);
    Reur = nan(nM, nI, nK);
    for c = 1:nK
        for j = 1:nI
            s = AGR.scores(:, j, c);
            if ~AGR.discrimina(j, c) || all(isnan(s)), continue; end
            esc = max(s) - min(s);
            if ~(esc > 0), continue; end
            R(:, j, c) = (max(s) - s) / esc;
            if inEuro(j), Reur(:, j, c) = max(s) - s; end
        end
    end
    [kk, jj, cc] = ndgrid(1:nM, 1:nI, 1:nK);
    pctvN = Reur ./ reshape(vN, 1, 1, nK) * 100;
    pctvN(~repmat(annuo.', nM, 1, nK)) = NaN;
    S.rimpianto = table(sch(cc(:)), n(cc(:)), fascia(cc(:)), pen(cc(:)), metodi(kk(:)), indic(jj(:)), ...
                        R(:), Reur(:), pctvN(:), ...
                        'VariableNames', {'Scheda','Membri','Fascia','Penetrazione_pct', ...
                                          'Metodo','Indicatore','Rimpianto','Rimpianto_EUR','Rimpianto_pct_vN'});
    S.rimpianto = S.rimpianto(~isnan(S.rimpianto.Rimpianto), :);
    S.rimpiantoMedio = local_medie(S.rimpianto, {'Metodo','Indicatore'}, ...
                                   {'Rimpianto','Rimpianto_EUR','Rimpianto_pct_vN'});

    % --- 2) Perdite fra criteri --------------------------------------------
    rows = {};
    for a = 1:nI
        for b = 1:nI
            if a == b, continue; end
            for c = 1:nK
                sa = AGR.scores(:, a, c);
                if isnan(R(1, b, c)) || ~AGR.discrimina(a, c) || all(isnan(sa)), continue; end
                pari = find(sa >= max(sa) - AGR.tolTie(a, c));
                rb   = R(pari, b, c);
                eb   = Reur(pari, b, c);
                [ott, io] = min(rb);
                [pes, ip] = max(rb);
                rows(end+1, :) = {indic(a), indic(b), sch(c), n(c), fascia(c), ...
                                  ott, pes, eb(io), eb(ip), 100 * eb(io) / vN(c) * annuo(b), ...
                                  numel(pari), strjoin(metodi(pari), "; ")}; %#ok<AGROW>
            end
        end
    end
    P = cell2table(rows, 'VariableNames', {'Scelto','Perde','Scheda','Membri','Fascia', ...
        'PerditaOttimistica','PerditaPessimistica','Perdita_EUR_ott','Perdita_EUR_pes', ...
        'Perdita_pct_vN_ott','NPariSuScelto','PariSuScelto'});
    P.Perdita_pct_vN_ott(~ismember(P.Perde, string(opts.indicatoriAnnui(:)))) = NaN;
    S.perditeDettaglio = P;
    S.perdite = local_medie(P, {'Scelto','Perde'}, ...
        {'PerditaOttimistica','PerditaPessimistica','Perdita_EUR_ott','Perdita_pct_vN_ott'});
    S.perditeFascia = local_medie(P, {'Scelto','Perde','Fascia'}, ...
        {'PerditaOttimistica','PerditaPessimistica'});
end


function T = local_medie(D, chiavi, valori)
% Media, minimo e massimo per gruppo, ignorando i NaN; Comunita = righe del gruppo.
    [G, T] = findgroups(D(:, chiavi));
    T.Comunita = splitapply(@numel, D.(valori{1}), G);
    for v = 1:numel(valori)
        x = D.(valori{v});
        T.([valori{v} '_medio']) = splitapply(@(y) mean(y, 'omitnan'), x, G);
        if v == 1
            T.([valori{v} '_min']) = splitapply(@(y) min(y, [], 'omitnan'), x, G);
            T.([valori{v} '_max']) = splitapply(@(y) max(y, [], 'omitnan'), x, G);
        end
    end
end


function f = local_fascia(n, pen)
% Rango della penetrazione dentro la taglia, come in ranking_grid e sintesi_risultati.
    f = zeros(numel(n), 1);
    for t = unique(n(:)).'
        i = find(n == t);
        [~, o] = sort(pen(i));
        f(i(o)) = 1:numel(i);
    end
end


function local_validate_self()
% Caso a penna: 3 metodi, 2 indicatori, 1 comunita'.
%   indicatore A: M1 = 1, M2 = 1, M3 = 0   (M1 e M2 a pari, soglia 0.1)
%   indicatore B: M1 = 0, M2 = 2, M3 = 4   (escursione 4)
% Rimpianto su B: M1 = 1, M2 = 0.5, M3 = 0. Scegliendo il migliore su A:
% ottimistica = min(1, 0.5) = 0.5, pessimistica = 1.
    A.scores     = cat(2, [1; 1; 0], [0; 2; 4]);
    A.tolTie     = [0.1; 0.1];
    A.discrimina = [true; true];
    A.methods    = ["M1" "M2" "M3"];
    A.indicators = ["IndA" "IndB_EUR"];
    R = struct('scheda', "x/CER_T.txt", 'nUsers', 5, 'penetrazione', 20, 'vGrand', 8);
    S = tradeoff_losses(A, R, struct('validateSelf', false, 'indicatoriAnnui', "IndB_EUR"));
    r = S.perdite(S.perdite.Scelto == "IndA" & S.perdite.Perde == "IndB_EUR", :);
    assert(abs(r.PerditaOttimistica_medio - 0.5) < 1e-12 && abs(r.PerditaPessimistica_medio - 1) < 1e-12, ...
           'tradeoff_losses: auto-test fallito sulle due letture');
    assert(abs(r.Perdita_EUR_ott_medio - 2) < 1e-12 && abs(r.Perdita_pct_vN_ott_medio - 25) < 1e-12, ...
           'tradeoff_losses: auto-test fallito sulla perdita in euro');
    q = S.rimpiantoMedio(S.rimpiantoMedio.Indicatore == "IndB_EUR", :);
    assert(isequal(sortrows(q, 'Metodo').Rimpianto_medio, [1; 0.5; 0]), ...
           'tradeoff_losses: auto-test fallito sul rimpianto');
end
