function F = fairness_indicators_lem(phi, genUsers, loadUsers, opts)
%FAIRNESS_INDICATORS_LEM  Indicatori di equita' distributiva di Dynge & Cali,
%   "Distributive energy justice in local electricity markets: Assessing the
%   performance of fairness indicators", Applied Energy 384 (2025) 125463,
%   calcolati su UNA ripartizione dell'incentivo CER.
%
%   Non e' un modello di ripartizione: non produce quote, le GIUDICA. Per
%   questo non passa da report_allocation.m (che verifica l'efficienza di
%   un'allocazione) e la sua firma parte da phi invece che restituirlo.
%
%   I SETTE INDICATORI (piu' Gini e Jain grezzi)
%     MinMax originale   (eq. 11)  min/max del PRELIEVO DA RETE
%     MinMax prosumer    (eq. 16)  min/max della quota di surplus condivisa
%     MinMax consumer    (eq. 17)  min/max del volume di condivisa ricevuto
%     QoS originale      (eq. 12)  indice di Jain sui volumi scambiati
%     QoS nuovo          (eq. 18)  rho*Jain(quote prosumer) + mu*Jain(volumi consumer)
%     EI originale       (eq. 15)  1 - Gini dei risparmi
%     EI nuovo           (eq. 19)  rho*(1-Gini risparmi RELATIVI) + mu*(1-Gini risparmi)
%
%   Il QoE (eq. 13-14) NON e' implementato: richiede il prezzo di mercato
%   locale lambda_t, che in una CER a condivisione virtuale non esiste (tutti
%   comprano dalla rete al prezzo retail, l'incentivo arriva ex post). Il paper
%   stesso non propone modifiche al QoE e ne rinvia la valutazione ad altri
%   meccanismi di prezzo (§6.2.1). Vedi GUIDA §18.
%
%   DALLE GRANDEZZE DEL PAPER A QUELLE DELLA CER
%     g_imp(t,i)  prelievo da rete   -> loadUsers(t,i) (carico residuo: nella
%                 condivisione virtuale tutto cio' che non e' autoconsumato
%                 dietro al contatore viene fisicamente prelevato)
%     g_exp(t,i)  immissione in rete -> sold(t) * shareGen(t,i)
%     x_LM(t,i)   venduto localmente -> shared(t) * shareGen(t,i)
%     i_LM(t,i)   comprato localmente-> SH(t,i), l'energia condivisa ATTRIBUITA
%     b_ch, b_dis batteria           -> assenti dal modello, valgono 0
%
%   DA EURO A kWh (opts.SH)
%     MinMax e QoS misurano kWh, ma quattordici dei sedici metodi del progetto
%     producono solo euro. In assenza di opts.SH l'energia si ricava dalla
%     ripartizione monetaria: si chiama allocate_shared_energy con pesi
%     COSTANTI nel tempo pari a phi, cosi' chi prende il 30% del montepremi si
%     vede attribuire il 30% dell'energia condivisa ora per ora, con il cap
%     fisico SH(t,i) <= loadUsers(t,i) gia' garantito dall'helper. Pearson Key
%     e Pearson-Sharing Rate espongono la propria SH nativa e possono passarla
%     con opts.SH.
%
%   AGGREGAZIONE TEMPORALE (§6.1 del paper)
%     Gli indicatori NON si calcolano ora per ora: nella maggior parte delle
%     ore qualcuno ha prelievo nullo e il MinMax collasserebbe a zero. Il paper
%     lavora su volumi mensili (Fig. 3) e i suoi esempi numerici lo confermano
%     (§6.1.1: 10.5 e 93 kWh/mese danno MinMax 0.11).
%       - MinMax: rapporto dei volumi ANNUI, che e' anche il rapporto dei
%         volumi mensili medi (dividere entrambi per 12 non cambia nulla) ed e'
%         letteralmente la somma su t delle eq. 16-17.
%       - QoS: indice di Jain calcolato su ogni MESE e poi mediato sui dodici,
%         come da didascalia della Fig. 5.
%       - EI: annuale, come la Fig. 8.
%     Di ogni indicatore si espone anche il vettore mensile, per non nascondere
%     la scelta di aggregazione.
%
%   COSA ASPETTARSI SU QUESTA TOPOLOGIA (leggere prima di usare i numeri)
%     1. Con UN SOLO prosumer, MinMax_pro = 1 e il Gini dei prosumer e' 0 per
%        definizione: gli indici lato prosumer non dicono nulla.
%     2. Il lato prosumer del QoS nuovo vale 1 anche con PIU' impianti. Nella
%        CER la quota condivisa dell'immissione e' shared(t)/genAgg(t) per
%        chiunque, perche' l'attribuzione e' pro-quota sulla produzione: tutti
%        i prosumer hanno la STESSA quota e Jain vale 1. Nel mercato locale di
%        Dynge e' il market clearing a decidere chi vende, quindi li' varia.
%        Non e' un difetto: e' il modello che, lato prosumer, e' equo per
%        costruzione.
%     3. Il MinMax ORIGINALE non dipende dalla ripartizione. I flussi fisici
%        di una CER non cambiano al cambiare di chi prende i soldi, quindi
%        questo indicatore da' lo stesso valore per tutti e sedici i metodi.
%        E' la versione estrema della critica del paper stesso ("almost equal
%        values for all cases", §6.1.1) e va riportato una volta sola, come
%        proprieta' della comunita'.
%     4. ANCHE MinMax_con, QoS e Jain possono risultare quasi identici fra i
%        metodi, e non e' un errore. Nelle ore in cui l'immissione copre
%        l'INTERO carico residuo della comunita' (Einj >= sum load) ogni utente
%        riceve esattamente il proprio carico: la chiave di ripartizione non ha
%        voce in capitolo, qualunque essa sia. Solo l'energia delle ore NON
%        sature e' contendibile, ed e' su quella che i metodi si differenziano.
%        Il campo .contendibleShare misura quanto vale quella frazione: sulla
%        community di default e' circa l'8-9%, perche' un impianto da 20 kWp su
%        un edificio industriale produce un surplus enorme rispetto al carico
%        residuo degli altri cinque membri. Con .contendibleShare basso, gli
%        indicatori ENERGETICI descrivono la comunita' piu' che il metodo: sono
%        quelli ECONOMICI (EI, Gini) a discriminare.
%
%   AMBIGUITA' DELL'EQ. 16 (opts.shareMode)
%     La quota di surplus del prosumer si legge sia come RAPPORTO DI SOMME
%     sum_t(x_LM) / sum_t(x_LM + g_exp), sia come SOMMA DI RAPPORTI
%     sum_t( x_LM / (x_LM + g_exp) ). Il testo del §4.2.5 ("the prosumer
%     selling the smallest SHARE of its surplus") sostiene la prima, che e' il
%     default; la seconda si ottiene con opts.shareMode = "sumOfRatios".
%
%   INPUT
%     phi        [n x 1]   ripartizione da giudicare                    [EUR]
%     genUsers   [H x n]   eccedenza oraria di ciascun utente        [kWh/h]
%     loadUsers  [H x n]   carico residuo orario di ciascun utente    [kWh/h]
%     opts       struct opzionale:
%                  .costNoCER   [n x 1] costo annuo da rete SENZA CER, cioe'
%                               y_noLEM dell'eq. 19. Senza, EI nuovo = NaN
%                  .savings     [n x 1] risparmi y_h (def. phi)
%                  .SH          [H x n] energia condivisa attribuita, per
%                               scavalcare quella implicita
%                  .monthOfHour [H x 1] mese di ogni ora (def. anno civile)
%                  .shareMode   "ratioOfSums" (def.) | "sumOfRatios"
%                  .name        etichetta del metodo giudicato (def. "")
%                  .quiet       non stampare il registro ipotesi (def. false)
%
%   OUTPUT (struct F)
%     .minMaxOrig .minMaxPro .minMaxCon   scalari, eq. 11 / 16 / 17
%     .qosOrig .qosNew                    scalari, eq. 12 / 18
%     .eiOrig .eiNew                      scalari, eq. 15 / 19
%     .gini                               Gini dei risparmi (nucleo dell'EI)
%     .jain                               Jain dei volumi ANNUI (nucleo del QoS)
%     .*Monthly            [12 x 1]  lo stesso indicatore mese per mese
%     .rho .mu                       quote di prosumer e consumatori (P/n, C/n)
%     .nProsumer .nConsumer          numerosita' delle due categorie
%     .isProsumer          [n x 1]   logico
%     .contendibleShare    scalare   frazione dell'energia condivisa su cui la
%                                    chiave puo' davvero incidere (avvertenza 4)
%     .contendibleEnergy   scalare   la stessa, in kWh
%     .sharedTotal         scalare   energia condivisa annua di comunita' [kWh]
%     .nSaturatedHours     scalare   ore in cui la chiave e' ininfluente
%     .SH                  [H x n]   energia condivisa attribuita usata  [kWh]
%     .sharedByUser        [n x 1]   sua somma annua                     [kWh]
%     .soldByUser          [n x 1]   immissione venduta in rete          [kWh]
%     .xLMByUser           [n x 1]   immissione risultata condivisa      [kWh]
%     .gridImportByUser    [n x 1]   prelievo da rete                    [kWh]
%     .impliedSH           logico    true se SH e' stata ricavata da phi
%     .assumptions         table     registro delle ipotesi attive
%     .table               table     riepilogo per indicatore

    if nargin < 4 || isempty(opts), opts = struct(); end

    [H, n] = size(loadUsers);
    phi    = phi(:);

    % --- Guardie sugli ingressi ---------------------------------------------
    if size(genUsers, 1) ~= H || size(genUsers, 2) ~= n
        error('fairness_indicators_lem:sizeMismatch', ...
              'genUsers e'' [%d x %d], loadUsers e'' [%d x %d]: devono coincidere.', ...
              size(genUsers, 1), size(genUsers, 2), H, n);
    end
    if numel(phi) ~= n
        error('fairness_indicators_lem:phiSizeMismatch', ...
              'phi ha %d elementi, gli utenti sono %d.', numel(phi), n);
    end
    if ~all(isfinite(genUsers), 'all') || ~all(isfinite(loadUsers), 'all') ...
            || ~all(isfinite(phi))
        error('fairness_indicators_lem:nonFiniteInput', ...
              'Profili o ripartizione con NaN o Inf: controllare i dati a monte.');
    end

    % Snapshot PRIMA dei default: dopo, isfield direbbe true per tutto e il
    % registro non saprebbe piu' distinguere il dato fornito da quello dedotto.
    tracciati = {'costNoCER', 'savings', 'SH', 'shareMode'};
    fornito   = struct();
    for k = 1:numel(tracciati)
        fornito.(tracciati{k}) = isfield(opts, tracciati{k});
    end

    if ~isfield(opts, 'savings'),   opts.savings   = phi;             end
    if ~isfield(opts, 'shareMode'), opts.shareMode = "ratioOfSums";   end
    if ~isfield(opts, 'name'),      opts.name      = "";              end
    if ~isfield(opts, 'quiet'),     opts.quiet     = false;           end
    if ~isfield(opts, 'monthOfHour')
        opts.monthOfHour = month(datetime(2025,1,1,0,0,0) + hours(0:H-1)).';
    end

    opts.shareMode = string(opts.shareMode);
    if ~ismember(opts.shareMode, ["ratioOfSums", "sumOfRatios"])
        error('fairness_indicators_lem:badShareMode', ...
              'opts.shareMode deve essere "ratioOfSums" o "sumOfRatios", e'' "%s".', ...
              opts.shareMode);
    end

    moh = opts.monthOfHour(:);
    if numel(moh) ~= H
        error('fairness_indicators_lem:monthSizeMismatch', ...
              'opts.monthOfHour ha %d elementi, le ore sono %d.', numel(moh), H);
    end

    y = opts.savings(:);
    if numel(y) ~= n
        error('fairness_indicators_lem:savingsSizeMismatch', ...
              'opts.savings ha %d elementi, gli utenti sono %d.', numel(y), n);
    end

    % --- Categorie e bilancio di comunita' ----------------------------------
    isProsumer = any(genUsers > 0, 1).';
    P          = sum(isProsumer);
    C          = n - P;
    rho        = P / n;
    mu         = C / n;

    genAgg  = sum(genUsers,  2);
    loadAgg = sum(loadUsers, 2);
    shared  = min(genAgg, loadAgg);           % energia condivisa CER  [kWh/h]
    sold    = max(0, genAgg - loadAgg);       % immessa e venduta      [kWh/h]

    % Quanta dell'energia condivisa e' davvero CONTENDIBILE fra i membri: nelle
    % ore SATURE, in cui l'immissione copre l'intero carico residuo, ognuno
    % riceve esattamente il proprio carico e nessuna chiave puo' cambiarlo
    % (ramo Et >= sumC di allocate_shared_energy). Vedi avvertenza 4.
    oreSature  = shared > 0 & genAgg >= loadAgg;
    sharedTot  = sum(shared);
    sharedSat  = sum(shared(oreSature));
    if sharedTot > 0
        contendibleShare = (sharedTot - sharedSat) / sharedTot;
    else
        contendibleShare = NaN;
    end

    % Quota di ciascun prosumer sull'immissione di comunita': e' la stessa
    % regola pro-quota gia' usata in MAIN.m §3 per attribuire la vendita.
    shareGen          = zeros(H, n);
    hasGen            = genAgg > 0;
    shareGen(hasGen,:) = genUsers(hasGen,:) ./ genAgg(hasGen);

    xLM  = shared .* shareGen;     % immissione del prosumer risultata condivisa
    gExp = sold   .* shareGen;     % immissione del prosumer venduta in rete
    gImp = loadUsers;              % prelievo da rete = carico residuo

    % --- Energia condivisa attribuita a ciascun utente (i_LM) ---------------
    if fornito.SH
        SH = opts.SH;
        if ~isequal(size(SH), [H n])
            error('fairness_indicators_lem:shSizeMismatch', ...
                  'opts.SH deve essere [%d x %d], e'' [%d x %d].', ...
                  H, n, size(SH, 1), size(SH, 2));
        end
    else
        % [IPOTESI 3] energia implicita: pesi costanti pari alla quota in euro
        SH = allocate_shared_energy(loadUsers, genAgg, repmat(max(phi, 0).', H, 1));
    end

    % --- Aggregati mensili e annui ------------------------------------------
    xLM_m  = local_monthly(xLM,  moh);        % [12 x n]
    gExp_m = local_monthly(gExp, moh);
    gImp_m = local_monthly(gImp, moh);
    SH_m   = local_monthly(SH,   moh);
    gen_m  = local_monthly(genUsers, moh);

    xLM_y  = sum(xLM,  1).';                  % [n x 1]
    gImp_y = sum(gImp, 1).';
    SH_y   = sum(SH,   1).';
    gen_y  = sum(genUsers, 1).';
    sold_y = sum(gExp, 1).';

    % --- MinMax (eq. 11, 16, 17) --------------------------------------------
    % Annuale in testa, mensile a corredo.
    minMaxOrig = local_minmax(gImp_y);
    minMaxCon  = local_minmax(SH_y(~isProsumer));
    minMaxPro  = local_minmax(local_share_sold(xLM, genUsers, isProsumer, opts.shareMode));

    minMaxOrigM = nan(12, 1);
    minMaxConM  = nan(12, 1);
    minMaxProM  = nan(12, 1);
    for k = 1:12
        minMaxOrigM(k) = local_minmax(gImp_m(k,:).');
        minMaxConM(k)  = local_minmax(SH_m(k, ~isProsumer).');
        shareK         = local_share_ratio(xLM_m(k,:).', gen_m(k,:).');
        minMaxProM(k)  = local_minmax(shareK(isProsumer));
    end

    % --- QoS (eq. 12, 18) ----------------------------------------------------
    % Jain su ogni mese, poi media sui dodici (didascalia Fig. 5). I mesi in
    % cui la grandezza e' identicamente nulla danno NaN e restano fuori dalla
    % media: un mese senza scambi non e' un mese "perfettamente equo".
    qosOrigM = nan(12, 1);
    qosNewM  = nan(12, 1);
    for k = 1:12
        traded       = xLM_m(k,:).' + SH_m(k,:).';
        qosOrigM(k)  = jain_index(traded);

        % Un prosumer senza immissione nel mese non ha una quota definita:
        % resta fuori dal Jain di quel mese invece di entrarci come zero, che
        % lo conterebbe come "trattato malissimo" anziche' come "assente".
        shareK  = local_share_ratio(xLM_m(k,:).', gen_m(k,:).');
        sPro    = shareK(isProsumer);
        jPro    = jain_index(sPro(~isnan(sPro)));
        jCon    = jain_index(SH_m(k, ~isProsumer).');
        qosNewM(k) = rho * jPro + mu * jCon;
    end
    qosOrig = mean(qosOrigM, 'omitnan');
    qosNew  = mean(qosNewM,  'omitnan');

    % Jain grezzo sui volumi ANNUI: e' il nucleo del QoS, esposto a se' stante
    % perche' e' la grandezza con cui ragiona la letteratura.
    jain = jain_index(xLM_y + SH_y);

    % --- EI (eq. 15, 19) -----------------------------------------------------
    % Il Gini grezzo dei risparmi e' il nucleo dell'EI, che ne e' il rovescio.
    gini   = gini_index(y);
    eiOrig = 1 - gini;

    if fornito.costNoCER
        costNoCER = opts.costNoCER(:);
        if numel(costNoCER) ~= n
            error('fairness_indicators_lem:costSizeMismatch', ...
                  'opts.costNoCER ha %d elementi, gli utenti sono %d.', ...
                  numel(costNoCER), n);
        end
        if any(costNoCER <= 0)
            error('fairness_indicators_lem:nonPositiveBaseline', ...
                  ['opts.costNoCER deve essere strettamente positivo: e'' il ' ...
                   'denominatore del risparmio relativo dell''eq. 19.']);
        end
        eiNew = rho * (1 - gini_index(y(isProsumer)  ./ costNoCER(isProsumer))) ...
              + mu  * (1 - gini_index(y(~isProsumer)));
    else
        costNoCER = nan(n, 1);
        eiNew     = NaN;
    end

    % L'EI e' annuale (Fig. 8): il vettore mensile non e' definito, ma si
    % espone comunque per uniformita' della struct, riempito di NaN.
    eiOrigM = nan(12, 1);
    eiNewM  = nan(12, 1);

    % --- Registro delle ipotesi ---------------------------------------------
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});
    if ~fornito.savings
        reg = local_note(reg, 1, 'Risparmio y_h dell''eq. 15', ...
                         'quota CER phi_i, esclusa la vendita eccedenza', ...
                         'passare opts.savings con il risparmio che si preferisce');
    end
    if ~fornito.costNoCER
        reg = local_note(reg, 2, 'Baseline y_noLEM dell''eq. 19', ...
                         'ASSENTE: EI nuovo non calcolabile (NaN)', ...
                         'passare opts.costNoCER con il costo annuo da rete senza CER');
    end
    if ~fornito.SH
        reg = local_note(reg, 3, 'Energia condivisa per utente', ...
                         'ricavata da phi con pesi costanti', ...
                         'passare opts.SH con l''attribuzione oraria nativa del metodo');
    end
    if ~fornito.shareMode
        reg = local_note(reg, 4, 'Lettura dell''eq. 16', ...
                         'rapporto di somme (testo del par. 4.2.5)', ...
                         'passare opts.shareMode = "sumOfRatios" per l''altra lettura');
    end

    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    if isempty(reg)
        F.assumptions = table(zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
                              'VariableNames', colonneReg);
    else
        F.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                       string({reg.valore}).', string({reg.rimozione}).', ...
                                       'VariableNames', colonneReg), 'Id');
    end

    % --- Struttura di uscita -------------------------------------------------
    F.name             = string(opts.name);
    F.minMaxOrig       = minMaxOrig;
    F.minMaxPro        = minMaxPro;
    F.minMaxCon        = minMaxCon;
    F.qosOrig          = qosOrig;
    F.qosNew           = qosNew;
    F.eiOrig           = eiOrig;
    F.eiNew            = eiNew;
    F.gini             = gini;
    F.jain             = jain;
    F.minMaxOrigMonthly = minMaxOrigM;
    F.minMaxProMonthly  = minMaxProM;
    F.minMaxConMonthly  = minMaxConM;
    F.qosOrigMonthly    = qosOrigM;
    F.qosNewMonthly     = qosNewM;
    F.eiOrigMonthly     = eiOrigM;
    F.eiNewMonthly      = eiNewM;
    F.rho              = rho;
    F.mu               = mu;
    F.nProsumer        = P;
    F.nConsumer        = C;
    F.isProsumer       = isProsumer;
    F.SH               = SH;
    F.sharedByUser     = SH_y;
    F.soldByUser       = sold_y;
    F.xLMByUser        = xLM_y;
    F.gridImportByUser = gImp_y;
    F.genByUser        = gen_y;
    F.savings          = y;
    F.costNoCER        = costNoCER;
    F.shareMode        = opts.shareMode;
    F.impliedSH        = ~fornito.SH;
    F.contendibleShare = contendibleShare;
    F.contendibleEnergy = sharedTot - sharedSat;
    F.sharedTotal      = sharedTot;
    F.nSaturatedHours  = sum(oreSature);

    F.table = table( ...
        ["MinMax originale (eq. 11)"; "MinMax prosumer (eq. 16)"; ...
         "MinMax consumer (eq. 17)"; "QoS originale (eq. 12)"; ...
         "QoS nuovo (eq. 18)"; "EI originale (eq. 15)"; "EI nuovo (eq. 19)"; ...
         "Gini dei risparmi"; "Jain dei volumi annui"], ...
        [minMaxOrig; minMaxPro; minMaxCon; qosOrig; qosNew; eiOrig; eiNew; ...
         gini; jain], ...
        'VariableNames', {'Indicatore', 'Valore'});

    if ~opts.quiet && ~isempty(reg)
        fprintf('\n  Ipotesi attive (fairness_indicators_lem%s):\n', ...
                local_suffix(opts.name));
        for k = 1:numel(reg)
            fprintf('    [%d] %s: %s\n', reg(k).id, reg(k).voce, reg(k).valore);
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function M = local_monthly(X, moh)
%LOCAL_MONTHLY  Somma le colonne di X per mese: [H x n] -> [12 x n].
    n = size(X, 2);
    M = zeros(12, n);
    for i = 1:n
        M(:, i) = accumarray(moh, X(:, i), [12 1]);
    end
end

function r = local_minmax(v)
%LOCAL_MINMAX  Rapporto min/max di un vettore, NaN se il massimo non e'
%   positivo (nessuno ha ricevuto nulla: il rapporto non e' definito).
    v = v(:);
    if isempty(v)
        r = NaN;
        return;
    end
    mx = max(v);                      % max/min di MATLAB ignorano i NaN
    if isnan(mx) || mx <= 0
        r = NaN;
        return;
    end
    r = min(v) / mx;
end

function s = local_share_ratio(xLMsum, gensum)
%LOCAL_SHARE_RATIO  Quota di surplus condivisa, come RAPPORTO DI SOMME.
%   Chi non ha immesso nulla nel periodo non ha una quota definita: NaN.
    s = nan(size(xLMsum));
    ok = gensum > 0;
    s(ok) = xLMsum(ok) ./ gensum(ok);
end

function s = local_share_sold(xLM, genUsers, isProsumer, modo)
%LOCAL_SHARE_SOLD  Quota ANNUA di surplus condivisa dei soli prosumer, nelle
%   due letture possibili dell'eq. 16 (vedi header).
    if modo == "sumOfRatios"
        ratio = zeros(size(xLM));
        ok    = genUsers > 0;
        ratio(ok) = xLM(ok) ./ genUsers(ok);
        nOre  = sum(genUsers > 0, 1).';        % ore in cui la quota e' definita
        tot   = sum(ratio, 1).';
        s     = nan(size(tot));
        s(nOre > 0) = tot(nOre > 0) ./ nOre(nOre > 0);
    else
        s = local_share_ratio(sum(xLM, 1).', sum(genUsers, 1).');
    end
    s = s(isProsumer);
end

function reg = local_note(reg, id, voce, valore, rimozione)
%LOCAL_NOTE  Aggiunge una voce al registro delle ipotesi ancora attive.
    reg(end+1) = struct('id', id, 'voce', voce, 'valore', valore, ...
                        'rimozione', rimozione);
end

function s = local_suffix(name)
%LOCAL_SUFFIX  " - <nome metodo>" se il chiamante ha etichettato la chiamata.
    if strlength(string(name)) == 0
        s = '';
    else
        s = sprintf(' - %s', name);
    end
end
