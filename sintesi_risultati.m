function S = sintesi_risultati(RESULTS, AGR, opts)
%SINTESI_RISULTATI  Le tre sintesi che rispondono alla domanda di ricerca e che
%   prima non venivano prodotte: accordo fra indicatori per fascia e per taglia,
%   fronte di Pareto fra i criteri, quote ai prosumer per metodo.
%
%   PERCHE' SERVE
%     Fin qui la pipeline salvava l'accordo fra indicatori in formato lungo
%     (una riga per comunita' e coppia di indicatori) e il VAN, il montepremi e
%     le quote nei RESULTS, ma nessun file diceva: (1) come cambia il tau al
%     variare della penetrazione e della taglia, (2) quali metodi restano
%     difendibili se si guardano piu' criteri insieme, (3) quanto premio va ai
%     prosumer rispetto alla loro quota di membri. Sono le tre letture che
%     servono alle ultime due clausole della domanda di ricerca.
%
%   1) ACCORDO PER FASCIA E PER TAGLIA  (S.tauFascia, S.tauTaglia, S.tauCelle)
%     tau-b di Kendall per coppia di indicatori. La fascia e' il RANGO della
%     penetrazione dentro la taglia (come in ranking_grid): la stessa
%     penetrazione ricorre a taglie diverse, un valore soglia mescolerebbe.
%     Per ciascuna coppia: media, minimo, massimo, numero di comunita' e se il
%     segno CAMBIA fra le fasce (media di fascia positiva e negativa).
%
%   2) FRONTE DI PARETO  (S.paretoMembri, S.paretoConteggi)
%     Per ogni comunita' e per ogni insieme di criteri, i metodi non DOMINATI:
%     A domina B se non e' peggio su nessun criterio e meglio su almeno uno,
%     dove "peggio/meglio" usa la STESSA soglia di rilevanza dell'inversione
%     (AGR.tolTie), non la differenza numerica. I punteggi sono gia' orientati
%     (piu' alto = meglio). Un fronte che contiene quasi tutti i metodi dice che
%     i criteri sono in conflitto, non che i metodi sono buoni; un metodo
%     sempre sul fronte vale piu' di uno sul fronte a caso.
%     opts.escludiMetodi (def. "Adaptive Sampling Shapley"): approssima lo
%     Shapley (scarto ~1%), quindi duplica un altro metodo e gonfia i conteggi.
%     MAIN2 passa un elenco vuoto: l'esclusione la fa gia' a monte
%     compute_indicator_agreement, e solo dove lo Shapley esatto c'e'.
%
%     L'incentivo "lordo" e' il COSENO AllineamentoVirtu_lordo, non la forza
%     incentivante lorda: quella ha un denominatore che sui profili lordi va
%     quasi a zero (valori fino a +-13, segno instabile) e resta in Tfair solo
%     come diagnostica (README §7.0-bis).
%
%   3) QUOTE AI PROSUMER  (S.quoteProsumer, S.quoteProsumerFascia)
%     Quota di v(N) ricevuta dai prosumer per metodo, e rapporto con la loro
%     quota di membri (penetrazione): 1 = i prosumer ricevono quanto la loro
%     numerosita', >1 sono premiati, <1 penalizzati. Con penetrazione 100% vale
%     1 per costruzione e viene riportato ma non commentato.
%
%   INPUT
%     RESULTS  struct array di MAIN2 (.scheda .nUsers .penetrazione .metodi
%              .isProsumer .vGrand)
%     AGR      struct di compute_indicator_agreement, con la soglia di rilevanza
%              gia' applicata (apply_relevance_threshold)
%     opts     .cartella  dove scrivere i CSV, vuoto = non scrive
%              .coppieChiave   [k x 2] string, coppie evidenziate
%              .insiemiCriteri struct array (.nome, .criteri)
%              .escludiMetodi  string
%              .validateSelf   def. true
%
%   Vedi anche: apply_relevance_threshold, compute_indicator_agreement

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'cartella'),       opts.cartella = ""; end
    if ~isfield(opts, 'escludiMetodi'),  opts.escludiMetodi = "Adaptive Sampling Shapley"; end
    if ~isfield(opts, 'validateSelf'),   opts.validateSelf = true; end
    if ~isfield(opts, 'insiemiCriteri')
        opts.insiemiCriteri = struct( ...
            'nome', {"Equita(Gini) + Incentivo(IS) + Sostenibilita(VAN_min)", ...
                     "Equita(Gini) + Incentivo(coseno lordo) + Sostenibilita(VAN_min)", ...
                     "Merito(FI) + Stabilita(Eccesso) + Incentivo(IS)", ...
                     "Tutti i criteri normativi + IS + VAN_min"}, ...
            'criteri', {["Gini", "ForzaIncentivante", "VAN_min_EUR"], ...
                        ["Gini", "AllineamentoVirtu_lordo", "VAN_min_EUR"], ...
                        ["FairnessIndex", "EccessoMax_EUR", "ForzaIncentivante"], ...
                        ["Gini", "FairnessIndex", "EccessoMax_EUR", ...
                         "ForzaIncentivante", "VAN_min_EUR"]});
    end
    if ~isfield(opts, 'coppieChiave')
        opts.coppieChiave = ["EI_orig" "EccessoMax_EUR"; "FairnessIndex" "Gini"; ...
                             "EccessoMax_EUR" "FairnessIndex"; ...
                             "ForzaIncentivante" "Gini"; ...
                             "ForzaIncentivante" "AllineamentoVirtu_lordo"; ...
                             "Gini" "VAN_min_EUR"; "EccessoMax_EUR" "VAN_min_EUR"; ...
                             "ForzaIncentivante" "VAN_min_EUR"];
    end
    if opts.validateSelf, local_validate_self(); end

    nK   = numel(RESULTS);
    indic = string(AGR.indicators(:));
    nI   = numel(indic);
    n    = [RESULTS.nUsers].';
    pen  = [RESULTS.penetrazione].';
    sch  = strings(nK, 1);
    for c = 1:nK, [~, sch(c)] = fileparts(char(RESULTS(c).scheda)); end

    % --- Fascia = rango della penetrazione dentro la taglia -------------------
    fascia = zeros(nK, 1);
    for t = unique(n).'
        i = find(n == t);
        [~, o] = sort(pen(i));
        fascia(i(o)) = 1:numel(i);
    end

    % ======================================================================
    %  1) ACCORDO PER FASCIA E PER TAGLIA
    % ======================================================================
    rows = {};
    for a = 1:nI
        for b = a+1:nI
            for c = 1:nK
                t = AGR.tau(a, b, c);
                if isnan(t), continue; end
                rows(end+1, :) = {sch(c), n(c), fascia(c), pen(c), indic(a), indic(b), t}; %#ok<AGROW>
            end
        end
    end
    S.tauCelle = cell2table(rows, 'VariableNames', ...
        {'Scheda','Membri','Fascia','Penetrazione_pct','IndicatoreA','IndicatoreB','TauB'});
    S.tauFascia = local_riassumi(S.tauCelle, 'Fascia');
    S.tauTaglia = local_riassumi(S.tauCelle, 'Membri');

    ck = opts.coppieChiave;
    chiave = false(height(S.tauFascia), 1);
    for k = 1:size(ck, 1)
        chiave = chiave | (S.tauFascia.IndicatoreA == ck(k,1) & S.tauFascia.IndicatoreB == ck(k,2)) ...
                        | (S.tauFascia.IndicatoreA == ck(k,2) & S.tauFascia.IndicatoreB == ck(k,1));
    end
    S.tauFasciaChiave = S.tauFascia(chiave, :);

    % ======================================================================
    %  2) FRONTE DI PARETO
    % ======================================================================
    metodi = string(AGR.methods(:));
    usa    = ~ismember(metodi, string(opts.escludiMetodi(:)));
    rows = {};
    cnt  = {};
    for s = 1:numel(opts.insiemiCriteri)
        cr = string(opts.insiemiCriteri(s).criteri(:));
        j  = zeros(numel(cr), 1);
        for q = 1:numel(cr)
            j(q) = find(indic == cr(q), 1);
        end
        nonDom = false(numel(metodi), nK);
        valido = true(1, nK);
        for c = 1:nK
            X   = squeeze(AGR.scores(usa, j, c));
            if numel(j) == 1, X = X(:); end
            if size(X, 2) ~= numel(j), X = X.'; end
            tol = AGR.tolTie(j, c).';
            if any(~AGR.discrimina(j, c)) || any(isnan(X(:)))
                valido(c) = false; continue;     % un criterio non ordina: insieme non valutabile
            end
            nd = local_non_dominati(X, tol);
            tmp = false(numel(metodi), 1);  tmp(usa) = nd;
            nonDom(:, c) = tmp;
        end
        for c = find(valido)
            rows(end+1, :) = {opts.insiemiCriteri(s).nome, sch(c), n(c), fascia(c), pen(c), ...
                              sum(nonDom(:, c)), sum(usa), strjoin(metodi(nonDom(:, c)), "; ")}; %#ok<AGROW>
        end
        for m = find(usa).'
            cnt(end+1, :) = {opts.insiemiCriteri(s).nome, metodi(m), ...
                             sum(nonDom(m, valido)), sum(valido)}; %#ok<AGROW>
        end
    end
    S.paretoMembri = cell2table(rows, 'VariableNames', ...
        {'InsiemeCriteri','Scheda','Membri','Fascia','Penetrazione_pct', ...
         'NMetodiNonDominati','NMetodiTotali','MetodiNonDominati'});
    S.paretoConteggi = cell2table(cnt, 'VariableNames', ...
        {'InsiemeCriteri','Metodo','VolteSulFronte','ComunitaValutate'});
    S.paretoConteggi.QuotaSulFronte = S.paretoConteggi.VolteSulFronte ./ ...
        max(1, S.paretoConteggi.ComunitaValutate);

    % ======================================================================
    %  3) QUOTE AI PROSUMER
    % ======================================================================
    rows = {};
    for c = 1:nK
        pr = logical(RESULTS(c).isProsumer(:));
        for k = 1:numel(RESULTS(c).metodi)
            phi = RESULTS(c).metodi(k).phi(:);
            q   = sum(phi(pr)) / sum(phi);
            rows(end+1, :) = {sch(c), n(c), fascia(c), pen(c), string(RESULTS(c).metodi(k).nome), ...
                              q, q / (pen(c)/100), RESULTS(c).vGrand}; %#ok<AGROW>
        end
    end
    S.quoteProsumer = cell2table(rows, 'VariableNames', ...
        {'Scheda','Membri','Fascia','Penetrazione_pct','Metodo', ...
         'QuotaProsumer','RapportoAllaQuotaDiMembri','vN_EUR'});
    S.quoteProsumerFascia = groupsummary(S.quoteProsumer, {'Fascia','Metodo'}, 'mean', ...
        {'QuotaProsumer','RapportoAllaQuotaDiMembri'});

    if strlength(string(opts.cartella)) > 0
        save_tables(opts.cartella, struct( ...
            'tau_per_fascia',          S.tauFascia, ...
            'tau_per_taglia',          S.tauTaglia, ...
            'tau_per_cella',           S.tauCelle, ...
            'pareto_per_comunita',     S.paretoMembri, ...
            'pareto_conteggi',         S.paretoConteggi, ...
            'quote_prosumer',          S.quoteProsumer, ...
            'quote_prosumer_fascia',   S.quoteProsumerFascia));
    end
end


function T = local_riassumi(Tc, per)
% Media, minimo, massimo e cambio di segno del tau, per coppia e per gruppo.
    T = groupsummary(Tc, {'IndicatoreA','IndicatoreB', per}, ...
                     {'mean','min','max'}, 'TauB');
    T.Properties.VariableNames = strrep(T.Properties.VariableNames, 'mean_TauB', 'TauMedio');
    T.Properties.VariableNames = strrep(T.Properties.VariableNames, 'min_TauB',  'TauMin');
    T.Properties.VariableNames = strrep(T.Properties.VariableNames, 'max_TauB',  'TauMax');
    T.Properties.VariableNames = strrep(T.Properties.VariableNames, 'GroupCount', 'Comunita');
    % Il segno CAMBIA fra i gruppi se la media di gruppo e' positiva in alcuni e
    % negativa in altri.
    chiave = T.IndicatoreA + "|" + T.IndicatoreB;
    T.SegnoCambiaFraGruppi = false(height(T), 1);
    for k = unique(chiave).'
        i = chiave == k;
        T.SegnoCambiaFraGruppi(i) = any(T.TauMedio(i) > 0) && any(T.TauMedio(i) < 0);
    end
end


function nd = local_non_dominati(X, tol)
% X [m x q] punteggi orientati (piu' alto = meglio), tol [1 x q] soglia di pareggio.
% A domina B se A >= B - tol su tutti e A > B + tol su almeno un criterio.
    m  = size(X, 1);
    nd = true(m, 1);
    for b = 1:m
        for a = 1:m
            if a == b, continue; end
            nonPeggio = all(X(a, :) >= X(b, :) - tol);
            meglio    = any(X(a, :) >  X(b, :) + tol);
            if nonPeggio && meglio
                nd(b) = false; break
            end
        end
    end
end


function local_validate_self()
% Caso a penna: 3 metodi, 2 criteri. M1 e M2 si incrociano, M3 e' dominato da M1.
    X = [1.0 0.0;      % M1
         0.0 1.0;      % M2
         0.5 -0.5];    % M3 (M1 lo domina)
    nd = local_non_dominati(X, [0 0]);
    assert(isequal(nd, [true; true; false]), 'Pareto: fronte sbagliato');
    % Con una soglia di rilevanza 0.6, M1 e M3 distano meno su entrambi: pari.
    nd = local_non_dominati([1 0; 0.8 -0.2], [0.6 0.6]);
    assert(all(nd), 'Pareto: la soglia di rilevanza non rende i due metodi pari');
end
