function C = confronto_pa(RESULTS, LIV, opts)
%CONFRONTO_PA  La presenza di PA cambia la graduatoria dei metodi? Confronto fra
%   il livello 0 (solo domestici) e i livelli con PA, a taglia, consumatori e
%   prosumer invariati.
%
%   A CHE DOMANDA RISPONDE
%     E' la parte "composizione per categoria" della prima clausola della domanda
%     di ricerca: l'ordinamento dei meccanismi cambia con la presenza di una o piu'
%     pubbliche amministrazioni? Le altre due leve (taglia e penetrazione) le
%     leggono reversals_by_axis e ranking_grid; qui la leva e' il livello PA.
%
%   CHE COSA SI CONFRONTA
%     Per ogni scheda presente a livello 0 e a livello k (stesso nome, quindi
%     stessi N, C, P: cambia solo CHI sono i prosumer, vedi
%     CER_configuration_PA/README.md) si mettono a fianco i punteggi orientati e le
%     tolleranze di pareggio che MAIN2 ha gia' calcolato per ciascun livello
%     (LIV(l).AGR). Niente viene ricalcolato: sono gli stessi oggetti che usano le
%     inversioni lungo penetrazione e taglia, quindi la soglia di rilevanza e' la
%     stessa e i numeri sono confrontabili con quelli.
%
%     1) INVERSIONI. extract_ranking_reversals su una sequenza di DUE
%        configurazioni (asse [0 k]): una coppia di metodi si inverte se in un
%        livello batte l'altra oltre la tolleranza e nell'altro e' battuta oltre la
%        tolleranza. Si dice anche quante coppie sono VALUTABILI (non a pari in
%        entrambi i livelli), perche' una coppia a pari in un livello non si
%        inverte: e' ambigua. La stessa funzione, su tutti i livelli di una scheda
%        insieme, da' la scansione lungo l'asse PA0 > PA1 > PA2 > PA3.
%     2) VINCITORI. Il primo classificato per indicatore e scheda, e se cambia: il
%        vincitore "cambia" quando gli insiemi dei metodi a pari col primo nei due
%        livelli non hanno nessun elemento in comune (con i pareggi dentro la
%        soglia, un cambio di nome fra due pari non e' un cambio di vincitore).
%     3) EFFETTI. Quanto vale il montepremi v(N), quanto va ai membri PA con
%        ciascun metodo, e in rapporto alla loro quota di membri.
%     4) TRADE-OFF E SOTTOINSIEME MINIMO PER LIVELLO. Le perdite fra criteri
%        (tradeoff_losses) a confronto, ristrette alle SOLE schede presenti in
%        entrambi i livelli: PA2 e PA3 hanno meno schede di PA0 (mancano quelle con
%        meno prosumer che PA), e confrontare medie su insiemi diversi mescolerebbe
%        l'effetto della PA con quello delle schede che mancano. Poi i gruppi di
%        indicatori (indicator_clusters) di ciascun livello.
%
%   ERRORE DELLO SCAGLIONE UNICO
%     Con il palazzetto (310,5 kWp) lo scenario impone lo scaglione 80/120 a tutte le
%     schede (tip_potenza_rif_kW, README 14.4.1): per norma il palazzetto avrebbe
%     70/110, cioe' 0,010 EUR/kWh in meno. L'errore e' al piu' 0,010 x energia
%     condivisa, ed e' nelle colonne ErroreMaxScaglione_*. Compare solo dove un
%     impianto supera i 200 kWp.
%
%   INPUT
%     RESULTS  struct array con TUTTE le comunita' (tutti i livelli):
%                .scheda .nUsers .penetrazione .vGrand .shared_annual
%                .sold_annual .metodi(.nome,.phi) .isPA .CFG.impianti.kWp
%     LIV      struct array dei livelli, costruita da MAIN2:
%                .livello  .idx (posizioni in RESULTS, nell'ordine di AGR)
%                .AGR (compute_indicator_agreement + apply_relevance_threshold)
%                .PERD (tradeoff_losses, [] se il livello ha una sola comunita')
%                .CLUS (indicator_clusters, [] idem)
%     opts     struct opzionale:
%                .cartella      cartella di uscita dei CSV ("" = non scrivere)
%                .quiet         non stampare la sintesi (def. false)
%                .validateSelf  auto-test su dati costruiti a penna (def. true)
%                .deltaTariffa  differenza di tariffa fra scaglioni [EUR/kWh] (def. 0.010)
%                .sogliaKwp     potenza oltre cui l'impianto cambia scaglione (def. 200)
%
%   OUTPUT (struct C)
%     .disponibile  false se manca il livello 0 o ogni livello con PA
%     .inversioni   table  una riga per cambio di segno, PA0 contro PAk
%     .vincitori    table  una riga per (indicatore, comunita'): vincitore e cambio
%     .perScheda    table  una riga per (scheda, confronto): serie, invertite, quote
%     .sommario     table  una riga per (indicatore, confronto) e per tutti insieme
%     .effetti      table  una riga per (comunita', metodo)
%     .perdite      table  perdite fra criteri, PA0 contro PAk, sulle schede comuni
%     .cluster      table  gruppi di indicatori per livello
%
%   Vedi anche: extract_ranking_reversals, reversals_by_axis, tradeoff_losses,
%               indicator_clusters, MAIN2

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'cartella'),     opts.cartella     = ""; end
    if ~isfield(opts, 'quiet'),        opts.quiet        = false; end
    if ~isfield(opts, 'validateSelf'), opts.validateSelf = true; end
    if ~isfield(opts, 'deltaTariffa'), opts.deltaTariffa = 0.010; end
    if ~isfield(opts, 'sogliaKwp'),    opts.sogliaKwp    = 200; end

    if opts.validateSelf, local_validate_self(); end

    C = struct('disponibile', false);
    nL  = numel(LIV);
    lev = [LIV.livello];
    if ~any(lev == 0) || nL < 2
        if ~opts.quiet
            fprintf(['\n  Confronto con / senza PA non disponibile: servono il ' ...
                     'livello 0 e almeno un livello con PA.\n']);
        end
        return
    end
    l0 = find(lev == 0, 1);

    % --- Metodi e indicatori comuni a tutti i livelli -----------------------
    % L'ordine e' quello del livello 0: extract_ranking_reversals chiama A il metodo
    % che viene prima, e le coppie di tutti i livelli devono avere la stessa A e la stessa B.
    metodi = string(LIV(l0).AGR.methods(:)).';
    indic  = string(LIV(l0).AGR.indicators(:)).';
    for l = 1:nL
        metodi = metodi(ismember(metodi, string(LIV(l).AGR.methods)));
        indic  = indic(ismember(indic,  string(LIV(l).AGR.indicators)));
    end
    nM = numel(metodi);  nI = numel(indic);
    assert(nM >= 2 && nI >= 1, ...
           'confronto_pa: i livelli non hanno almeno due metodi e un indicatore in comune.');
    mi = cell(1, nL);  ii = cell(1, nL);
    for l = 1:nL
        mi{l} = arrayfun(@(m) find(string(LIV(l).AGR.methods)    == m, 1), metodi);
        ii{l} = arrayfun(@(m) find(string(LIV(l).AGR.indicators) == m, 1), indic);
    end

    % --- Catalogo delle comunita' (tutti i livelli) -------------------------
    levK = zeros(0, 1);  nomeK = strings(0, 1);  iResK = zeros(0, 1);
    lK   = zeros(0, 1);  cK    = zeros(0, 1);
    for l = 1:nL
        nomi = string(LIV(l).AGR.schede(:));
        assert(numel(unique(nomi)) == numel(nomi), ...
               'confronto_pa: due comunita'' omonime nel livello PA%d.', LIV(l).livello);
        assert(numel(LIV(l).idx) == numel(nomi), ...
               'confronto_pa: LIV(%d).idx e AGR descrivono un numero diverso di comunita''.', l);
        for c = 1:numel(nomi)
            levK(end+1, 1)  = LIV(l).livello;   %#ok<AGROW>
            nomeK(end+1, 1) = nomi(c);          %#ok<AGROW>
            iResK(end+1, 1) = LIV(l).idx(c);    %#ok<AGROW>
            lK(end+1, 1)    = l;                %#ok<AGROW>
            cK(end+1, 1)    = c;                %#ok<AGROW>
        end
    end
    nK = numel(levK);

    % La fascia e' il rango della penetrazione dentro la taglia, SUL LIVELLO 0
    % (come ranking_grid): i livelli con PA non hanno tutte le schede, ma la
    % scheda e' la stessa, quindi la fascia e' quella del suo omonimo a livello 0.
    nUs = arrayfun(@(i) RESULTS(i).nUsers, iResK);
    pen = arrayfun(@(i) RESULTS(i).penetrazione, iResK);
    fasciaK = zeros(nK, 1);
    for t = unique(nUs(levK == 0)).'
        r = find(levK == 0 & nUs == t);
        [~, o] = sort(pen(r));
        fasciaK(r(o)) = 1:numel(r);
    end

    % --- Omonimo a livello 0 di ogni comunita' con PA -----------------------
    omo = zeros(nK, 1);
    for q = find(levK > 0).'
        r = find(levK == 0 & nomeK == nomeK(q));
        if isempty(r)
            warning('confronto_pa:senzaOmonimo', ...
                    '%s (livello PA%d) non ha la scheda omonima a livello 0: si salta.', ...
                    nomeK(q), levK(q));
            continue
        end
        assert(nUs(r) == nUs(q) && abs(pen(r) - pen(q)) < 1e-9, ...
               ['confronto_pa: %s ha taglia o penetrazione diverse a livello 0 e a ' ...
                'livello PA%d: la regola della sostituzione non e'' rispettata.'], ...
               nomeK(q), levK(q));
        omo(q) = r;
        fasciaK(q) = fasciaK(r);
    end

    % ======================================================================
    %  1) VINCITORI, per indicatore e comunita'
    % ======================================================================
    nRV = nK * nI;
    vInd = strings(nRV, 1);  vSch = strings(nRV, 1);  vN = zeros(nRV, 1);
    vPen = zeros(nRV, 1);    vLiv = zeros(nRV, 1);    vVin = strings(nRV, 1);
    vPar = strings(nRV, 1);  vDis = nan(nRV, 1);      vTop = cell(nRV, 1);
    r = 0;
    for q = 1:nK
        A = LIV(lK(q)).AGR;
        for j = 1:nI
            r = r + 1;
            [vin, par, dis, top] = local_vincitore(A.scores(mi{lK(q)}, ii{lK(q)}(j), cK(q)), ...
                                                   A.tolTie(ii{lK(q)}(j), cK(q)), ...
                                                   A.discrimina(ii{lK(q)}(j), cK(q)), metodi);
            vInd(r) = indic(j);  vSch(r) = nomeK(q);  vN(r) = nUs(q);
            vPen(r) = pen(q);    vLiv(r) = levK(q);
            vVin(r) = vin;       vPar(r) = par;       vDis(r) = dis;   vTop{r} = top;
        end
    end
    confrontabile = false(nRV, 1);
    cambia        = false(nRV, 1);
    for r = 1:nRV
        if vLiv(r) == 0, continue; end
        r0 = find(vLiv == 0 & vSch == vSch(r) & vInd == vInd(r), 1);
        if isempty(r0) || isempty(vTop{r}) || isempty(vTop{r0}), continue; end
        confrontabile(r) = true;
        cambia(r)        = isempty(intersect(vTop{r}, vTop{r0}));
    end
    C.vincitori = table(vInd, vSch, vN, vPen, vLiv, vVin, vPar, vDis, confrontabile, cambia, ...
        'VariableNames', {'Indicatore', 'Scheda', 'Membri', 'Penetrazione_pct', 'Livello', ...
                          'Vincitore', 'PrimiAPari', 'Distacco', 'Confrontabile', 'CambiaVincitore'});

    % ======================================================================
    %  2) INVERSIONI: PA0 contro PAk, comunita' per comunita'
    % ======================================================================
    pairs = find(omo > 0).';
    nP = numel(pairs);
    pSch = strings(nP, 1);  pN = zeros(nP, 1);  pPen = zeros(nP, 1);  pFas = zeros(nP, 1);
    pLiv = zeros(nP, 1);
    pSer = zeros(nP, nI);  pVal = zeros(nP, nI);  pInv = zeros(nP, nI);
    EV = cell(nP, 1);
    for u = 1:nP
        q  = pairs(u);  q0 = omo(q);
        [X, ~] = local_scansione([q0; q], LIV, lK, cK, mi, ii, metodi, indic, levK, nomeK);

        pSch(u) = nomeK(q);  pN(u) = nUs(q);  pPen(u) = pen(q);
        pFas(u) = fasciaK(q); pLiv(u) = levK(q);
        S = X.sommario;
        valida = isfinite(S.PenetrazioneSegnoIniziale_pct) & isfinite(S.PenetrazioneSegnoFinale_pct) ...
                 & (S.PenetrazioneSegnoIniziale_pct ~= S.PenetrazioneSegnoFinale_pct);
        for j = 1:nI
            m = S.Indicatore == indic(j);
            pSer(u, j) = nnz(m);
            pVal(u, j) = nnz(m & valida);
            pInv(u, j) = nnz(m & S.nInversioni > 0);
        end
        assert(X.nInversioni == height(X.inversioni) && sum(pInv(u, :)) == nnz(S.nInversioni > 0), ...
               'confronto_pa: il conteggio delle inversioni non torna su %s.', nomeK(q));

        E = X.inversioni;
        h = height(E);
        EV{u} = table(repmat(nomeK(q), h, 1), repmat(nUs(q), h, 1), repmat(pen(q), h, 1), ...
                      repmat(levK(q), h, 1), E.Indicatore, E.MetodoA, E.MetodoB, ...
                      E.DivarioDa, E.DivarioA, E.PassiPari, ...
                      'VariableNames', {'Scheda', 'Membri', 'Penetrazione_pct', 'LivelloPA', ...
                                        'Indicatore', 'MetodoA', 'MetodoB', ...
                                        'DivarioPA0', 'DivarioPAk', 'PassiPari'});
    end
    if nP > 0
        C.inversioni = vertcat(EV{:});
    else
        C.inversioni = table();
    end

    % --- Scansione lungo l'asse PA0 > PA1 > PA2 > PA3, scheda per scheda -----
    nomiAsse = unique(nomeK(levK > 0)).';
    aSch = strings(0, 1);  aN = zeros(0, 1);  aPen = zeros(0, 1);  aFas = zeros(0, 1);
    aSer = zeros(0, 1);  aVal = zeros(0, 1);  aInv = zeros(0, 1);  aEst = zeros(0, 1);
    for nm = nomiAsse
        rr = find(nomeK == nm);
        [~, o] = sort(levK(rr));
        rr = rr(o);
        if numel(rr) < 2 || levK(rr(1)) ~= 0, continue; end
        [X, ~] = local_scansione(rr, LIV, lK, cK, mi, ii, metodi, indic, levK, nomeK);
        S = X.sommario;
        valida = isfinite(S.PenetrazioneSegnoIniziale_pct) & isfinite(S.PenetrazioneSegnoFinale_pct) ...
                 & (S.PenetrazioneSegnoIniziale_pct ~= S.PenetrazioneSegnoFinale_pct);
        aSch(end+1, 1) = nm;           aN(end+1, 1)  = nUs(rr(1));       %#ok<AGROW>
        aPen(end+1, 1) = pen(rr(1));   aFas(end+1, 1) = fasciaK(rr(1));  %#ok<AGROW>
        aSer(end+1, 1) = height(S);    aVal(end+1, 1) = nnz(valida);     %#ok<AGROW>
        aInv(end+1, 1) = nnz(S.nInversioni > 0);                          %#ok<AGROW>
        aEst(end+1, 1) = nnz(S.InvertitoAgliEstremi);                     %#ok<AGROW>
    end

    % --- Tabella per scheda ---------------------------------------------------
    confr = "PA0-PA" + pLiv;
    perScheda = table(pSch, pN, pPen, pFas, confr, sum(pSer, 2), sum(pVal, 2), sum(pInv, 2), ...
                      sum(pInv, 2) ./ sum(pSer, 2), sum(pInv, 2) ./ sum(pVal, 2), ...
                      sum(pInv, 2), ...
        'VariableNames', {'Scheda', 'Membri', 'Penetrazione_pct', 'Fascia', 'Confronto', ...
                          'SerieEsaminate', 'SerieValide', 'CoppieInvertite', ...
                          'QuotaInvertite', 'QuotaInvertiteSuValide', 'InvertiteAgliEstremi'});
    if ~isempty(aSch)
        asse = table(aSch, aN, aPen, aFas, repmat("asse PA", numel(aSch), 1), aSer, aVal, aInv, ...
                     aInv ./ aSer, aInv ./ aVal, aEst, ...
            'VariableNames', perScheda.Properties.VariableNames);
        perScheda = [perScheda; asse];
    end
    C.perScheda = perScheda;

    % --- Sommario per indicatore e confronto ---------------------------------
    livPA = unique(pLiv).';
    righe = {};
    gruppi = [num2cell(livPA), {0}];                 % 0 = tutti i livelli con PA insieme
    for g = 1:numel(gruppi)
        k = gruppi{g};
        if k == 0
            selP = true(nP, 1);          nomeConf = "PA0 contro PA>=1";
            selV = vLiv > 0;
        else
            selP = (pLiv == k);          nomeConf = "PA0-PA" + k;
            selV = (vLiv == k);
        end
        for j = [1:nI, 0]
            if j == 0
                ind = "(tutti)";  cols = 1:nI;
                mv = selV & confrontabile;
            else
                ind = indic(j);   cols = j;
                mv = selV & confrontabile & vInd == indic(j);
            end
            nSerie = sum(pSer(selP, cols), 'all');
            nVal   = sum(pVal(selP, cols), 'all');
            nInv   = sum(pInv(selP, cols), 'all');
            righe(end+1, :) = {ind, nomeConf, nnz(selP), nnz(mv), ...                       %#ok<AGROW>
                               local_quota(nnz(mv & cambia), nnz(mv)), ...
                               nSerie, nVal, nInv, local_quota(nInv, nSerie), local_quota(nInv, nVal)};
        end
    end
    C.sommario = cell2table(righe, 'VariableNames', ...
        {'Indicatore', 'Confronto', 'Comunita', 'ComunitaConVincitore', 'QuotaVincitoreCambia', ...
         'SerieEsaminate', 'SerieValide', 'CoppieInvertite', 'QuotaInvertite', ...
         'QuotaInvertiteSuValide'});

    % ======================================================================
    %  3) EFFETTI sul montepremi e sulle quote dei membri PA
    % ======================================================================
    E = {};
    for q = 1:nK
        R = RESULTS(iResK(q));
        q0 = find(levK == 0 & nomeK == nomeK(q), 1);
        if isempty(q0), vN0 = NaN; else, vN0 = RESULTS(iResK(q0)).vGrand; end
        nPAq = nnz(R.isPA);
        quotaMembri = 100 * nPAq / R.nUsers;
        grande = any(R.CFG.impianti.kWp > opts.sogliaKwp);
        errEUR = opts.deltaTariffa * R.shared_annual * grande;
        for k = 1:numel(R.metodi)
            phi = R.metodi(k).phi(:);
            quotaPA = 100 * sum(phi(R.isPA(:))) / sum(phi);
            if nPAq == 0, rapporto = NaN; else, rapporto = quotaPA / quotaMembri; end
            E(end+1, :) = {nomeK(q), levK(q), R.nUsers, R.penetrazione, nPAq, string(R.metodi(k).nome), ...  %#ok<AGROW>
                           R.vGrand, R.vGrand / vN0, R.shared_annual, R.sold_annual, ...
                           quotaPA, quotaMembri, rapporto, errEUR, 100 * errEUR / R.vGrand};
        end
    end
    C.effetti = cell2table(E, 'VariableNames', ...
        {'Scheda', 'Livello', 'Membri', 'Penetrazione_pct', 'MembriPA', 'Metodo', ...
         'vN_EUR', 'vN_rapportoPA0', 'Condivisa_kWh', 'NonCondivisa_kWh', ...
         'QuotaPA_pct_vN', 'QuotaMembriPA_pct', 'RapportoQuotaPA', ...
         'ErroreMaxScaglione_EUR', 'ErroreMaxScaglione_pct_vN'});

    % ======================================================================
    %  4) TRADE-OFF E SOTTOINSIEME MINIMO, livello per livello
    % ======================================================================
    C.perdite = table();
    D0 = [];
    if ~isempty(LIV(l0).PERD), D0 = LIV(l0).PERD.perditeDettaglio; end
    if ~isempty(D0)
        PR = {};
        for l = find(lev > 0)
            if isempty(LIV(l).PERD), continue; end
            Dk = LIV(l).PERD.perditeDettaglio;
            comuni = unique(Dk.Scheda);
            m0 = local_media_gruppi(D0(ismember(D0.Scheda, comuni), :));
            mk = local_media_gruppi(Dk);
            for q = 1:height(mk)
                p0 = find(m0.Scelto == mk.Scelto(q) & m0.Perde == mk.Perde(q), 1);
                if isempty(p0), continue; end
                PR(end+1, :) = {LIV(l).livello, mk.Scelto(q), mk.Perde(q), mk.Comunita(q), ... %#ok<AGROW>
                                m0.Ott(p0), mk.Ott(q), mk.Ott(q) - m0.Ott(p0), ...
                                m0.Pes(p0), mk.Pes(q), mk.Pes(q) - m0.Pes(p0)};
            end
        end
        if ~isempty(PR)
            C.perdite = cell2table(PR, 'VariableNames', ...
                {'LivelloPA', 'Scelto', 'Perde', 'ComunitaComuni', ...
                 'PerditaOttimisticaPA0', 'PerditaOttimisticaPAk', 'DeltaOttimistica', ...
                 'PerditaPessimisticaPA0', 'PerditaPessimisticaPAk', 'DeltaPessimistica'});
        end
    end

    CL = {};
    for l = 1:nL
        if isempty(LIV(l).CLUS), continue; end
        G = LIV(l).CLUS.gruppi;
        for q = 1:height(G)
            CL(end+1, :) = {LIV(l).livello, G.TaglioTau(q), G.Gruppo(q), G.NIndicatori(q), ... %#ok<AGROW>
                            string(G.Indicatori(q)), string(G.Rappresentante(q)), G.TauMedioInterno(q)};
        end
    end
    if isempty(CL)
        C.cluster = table();
    else
        C.cluster = cell2table(CL, 'VariableNames', ...
            {'LivelloPA', 'TaglioTau', 'Gruppo', 'NIndicatori', 'Indicatori', ...
             'Rappresentante', 'TauMedioInterno'});
    end

    C.disponibile = true;

    if strlength(string(opts.cartella)) > 0
        daScrivere = struct('pa_inversioni',       C.inversioni, ...
                            'pa_vincitori',        C.vincitori, ...
                            'pa_per_scheda',       C.perScheda, ...
                            'pa_sommario',         C.sommario, ...
                            'pa_effetti',          C.effetti, ...
                            'pa_perdite_tradeoff', C.perdite, ...
                            'pa_cluster',          C.cluster);
        for f = string(fieldnames(daScrivere)).'
            if isempty(daScrivere.(f))      % livelli con una sola comunita': niente da scrivere
                daScrivere = rmfield(daScrivere, f);
            end
        end
        save_tables(opts.cartella, daScrivere);
    end

    if ~opts.quiet, local_stampa(C, nP); end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function [X, sub] = local_scansione(righe, LIV, lK, cK, mi, ii, metodi, indic, levK, nomeK)
%LOCAL_SCANSIONE  extract_ranking_reversals su una sequenza di comunita' omonime,
%   una per livello, con il livello PA come asse. I punteggi e le tolleranze sono
%   quelli dei rispettivi AGR, riletti sugli stessi metodi e indicatori.

    nR = numel(righe);
    nM = numel(metodi);  nI = numel(indic);
    S = nan(nM, nI, nR);  D = false(nI, nR);  T = nan(nI, nR);
    etichette = strings(1, nR);
    for u = 1:nR
        q = righe(u);
        A = LIV(lK(q)).AGR;
        S(:, :, u) = A.scores(mi{lK(q)}, ii{lK(q)}, cK(q));
        D(:, u)    = A.discrimina(ii{lK(q)}, cK(q));
        T(:, u)    = A.tolTie(ii{lK(q)}, cK(q));
        etichette(u) = nomeK(q) + "@PA" + levK(q);
    end
    sub = struct('indicators', indic, 'methods', metodi, 'schede', etichette, ...
                 'penetrazione', levK(righe).', 'scores', S, 'discrimina', D, 'tolTie', T);
    X = extract_ranking_reversals(sub, struct('quiet', true, 'validateSelf', false));
end


function [vin, par, dis, top] = local_vincitore(s, tol, discrimina, metodi)
%LOCAL_VINCITORE  Primo classificato con i pareggi, come in ranking_grid:
%   "(pari)" se i primi due sono entro la tolleranza, "" se l'indicatore non
%   ordina niente, PrimiAPari = tutti i metodi entro la tolleranza dal primo.
    vin = "";  par = "";  dis = NaN;  top = strings(0, 1);
    ok = find(isfinite(s));
    if ~discrimina || numel(ok) < 2, return; end
    [so, o] = sort(s(ok), 'descend');
    dis = so(1) - so(2);
    top = metodi(ok(o(so >= so(1) - tol)));
    top = top(:);
    par = strjoin(top, " = ");
    if dis <= tol
        vin = "(pari)";
    else
        vin = metodi(ok(o(1)));
    end
end


function q = local_quota(a, b)
%LOCAL_QUOTA  a/b, NaN se b e' zero (nessun caso su cui calcolarla).
    if b == 0, q = NaN; else, q = a / b; end
end


function T = local_media_gruppi(D)
%LOCAL_MEDIA_GRUPPI  Media delle perdite per coppia (Scelto, Perde), NaN ignorati.
    [G, T] = findgroups(D(:, {'Scelto', 'Perde'}));
    T.Comunita = splitapply(@numel, D.PerditaOttimistica, G);
    T.Ott = splitapply(@(y) mean(y, 'omitnan'), D.PerditaOttimistica, G);
    T.Pes = splitapply(@(y) mean(y, 'omitnan'), D.PerditaPessimistica, G);
end


function local_stampa(C, nP)
%LOCAL_STAMPA  Una pagina di sintesi. Solo ASCII: i simboli escono corrotti dallo
%   stdout di MATLAB in modalita' batch.
    fprintf('\n=== Presenza di PA: PA0 contro i livelli con PA (%d confronti) ===\n', nP);
    S = C.sommario(C.sommario.Indicatore == "(tutti)", :);
    for q = 1:height(S)
        fprintf('  %-18s %3d comunita'': coppie invertite %5.1f%% (sulle valutabili %5.1f%%), vincitore cambia %5.1f%%\n', ...
                S.Confronto(q), S.Comunita(q), 100 * S.QuotaInvertite(q), ...
                100 * S.QuotaInvertiteSuValide(q), 100 * S.QuotaVincitoreCambia(q));
    end
    a = C.perScheda(C.perScheda.Confronto == "asse PA", :);
    if ~isempty(a)
        fprintf('  lungo l''asse PA0>PA3 (%d schede): coppie invertite %5.1f%% in media\n', ...
                height(a), 100 * mean(a.QuotaInvertite, 'omitnan'));
    end
    I = C.sommario(C.sommario.Confronto == "PA0 contro PA>=1" & C.sommario.Indicatore ~= "(tutti)", :);
    [~, o] = sort(I.QuotaInvertite, 'descend');
    fprintf('  indicatori piu'' sensibili alla PA (quota di coppie invertite):\n');
    for q = o(1:min(3, numel(o))).'
        fprintf('    %-26s %5.1f%%\n', I.Indicatore(q), 100 * I.QuotaInvertite(q));
    end
    E = C.effetti(C.effetti.MembriPA > 0, :);
    if ~isempty(E)
        [g, m] = findgroups(E.Metodo);
        r = splitapply(@(x) mean(x, 'omitnan'), E.RapportoQuotaPA, g);
        [~, o] = sort(r, 'descend');
        fprintf('  quota ai membri PA / quota di membri PA (media): massima %s %.2f, minima %s %.2f\n', ...
                m(o(1)), r(o(1)), m(o(end)), r(o(end)));
    end
end


function local_validate_self()
%LOCAL_VALIDATE_SELF  Tre livelli di una sola comunita' costruita a penna.
%   Metodi M1 M2 M3, indicatori IndA e IndB_EUR, soglia di pareggio 0.1.
%     PA0   IndA = [3 2 1]   IndB = [1 2 3]
%     PA1   IndA = [3 2 1]   IndB = [3 2 1]   IndB rovesciato: tre coppie invertite
%     PA2   identico a PA0                    nessuna inversione, vincitori uguali
%   Lungo l'asse PA0>PA1>PA2 le tre coppie di IndB si invertono due volte.

    metodi = ["M1" "M2" "M3"];  indic = ["IndA" "IndB_EUR"];
    scoreA = {[3 2 1], [3 2 1], [3 2 1]};
    scoreB = {[1 2 3], [3 2 1], [1 2 3]};
    isPA   = {false(3, 1), [false; false; true], [false; true; true]};
    kWp    = {3.4, [3.4; 310], 3.4};
    liv    = [0 1 2];
    for l = 1:3
        AGR = struct('indicators', indic, 'methods', metodi, 'schede', "CER_T", ...
                     'penetrazione', 33, 'scores', cat(2, scoreA{l}(:), scoreB{l}(:)), ...
                     'discrimina', [true; true], 'tolTie', [0.1; 0.1]);
        LIV(l) = struct('livello', liv(l), 'idx', l, 'AGR', AGR, 'PERD', [], 'CLUS', []); %#ok<AGROW>
        RES(l) = struct('scheda', "x/CER_T.txt", 'nUsers', 3, 'penetrazione', 33, ...      %#ok<AGROW>
                        'vGrand', 6, 'shared_annual', 100, 'sold_annual', 20, ...
                        'metodi', struct('nome', {"M1", "M2"}, 'phi', {[1; 2; 3], [2; 2; 2]}), ...
                        'isPA', isPA{l}, 'CFG', struct('impianti', table(kWp{l}, 'VariableNames', {'kWp'})));
    end
    C = confronto_pa(RES, LIV, struct('validateSelf', false, 'quiet', true));
    assert(C.disponibile, 'confronto_pa: auto-test, confronto non disponibile');

    % Inversioni: PA0-PA1 invertite le 3 coppie di IndB su 6 serie; PA0-PA2 nessuna
    p1 = C.perScheda(C.perScheda.Confronto == "PA0-PA1", :);
    p2 = C.perScheda(C.perScheda.Confronto == "PA0-PA2", :);
    assert(p1.SerieEsaminate == 6 && p1.CoppieInvertite == 3 && abs(p1.QuotaInvertite - 0.5) < 1e-12 ...
           && p1.SerieValide == 6 && abs(p1.QuotaInvertiteSuValide - 0.5) < 1e-12, ...
           'confronto_pa: auto-test fallito sulle inversioni PA0-PA1');
    assert(p2.CoppieInvertite == 0 && p2.QuotaInvertite == 0, ...
           'confronto_pa: un livello identico al livello 0 non deve avere inversioni');
    assert(height(C.inversioni) == 3 && all(C.inversioni.Indicatore == "IndB_EUR"), ...
           'confronto_pa: auto-test fallito sugli eventi di inversione');

    % Asse: le tre coppie di IndB cambiano segno due volte, ma si conta la serie una sola
    ax = C.perScheda(C.perScheda.Confronto == "asse PA", :);
    assert(ax.CoppieInvertite == 3 && ax.InvertiteAgliEstremi == 0, ...
           'confronto_pa: auto-test fallito sulla scansione lungo l''asse');

    % Vincitori: IndA invariato, IndB da M3 a M1
    V = C.vincitori;
    vB0 = V(V.Indicatore == "IndB_EUR" & V.Livello == 0, :);
    vB1 = V(V.Indicatore == "IndB_EUR" & V.Livello == 1, :);
    vA1 = V(V.Indicatore == "IndA"     & V.Livello == 1, :);
    vB2 = V(V.Indicatore == "IndB_EUR" & V.Livello == 2, :);
    assert(vB0.Vincitore == "M3" && vB1.Vincitore == "M1" && vB1.CambiaVincitore ...
           && ~vA1.CambiaVincitore && ~vB2.CambiaVincitore, ...
           'confronto_pa: auto-test fallito sui vincitori');
    s = C.sommario(C.sommario.Indicatore == "IndB_EUR" & C.sommario.Confronto == "PA0-PA1", :);
    assert(s.QuotaVincitoreCambia == 1, 'confronto_pa: auto-test fallito sul sommario');

    % Effetti: PA1, M1 phi = [1 2 3], PA = terzo membro -> 3/6 = 50% contro 1/3 dei membri
    e = C.effetti(C.effetti.Livello == 1 & C.effetti.Metodo == "M1", :);
    assert(abs(e.QuotaPA_pct_vN - 50) < 1e-12 && abs(e.RapportoQuotaPA - 1.5) < 1e-12, ...
           'confronto_pa: auto-test fallito sulla quota ai membri PA');
    assert(abs(e.ErroreMaxScaglione_EUR - 1.0) < 1e-12, ...
           'confronto_pa: l''errore dello scaglione vale 0,010 x 100 kWh = 1 EUR con un impianto da 310 kWp');
    e0 = C.effetti(C.effetti.Livello == 0 & C.effetti.Metodo == "M1", :);
    assert(e0.ErroreMaxScaglione_EUR == 0 && isnan(e0.RapportoQuotaPA), ...
           'confronto_pa: a livello 0 non ci sono PA ne'' errore di scaglione');
end
