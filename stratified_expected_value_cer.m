function S = stratified_expected_value_cer(genUsers, loadUsers, userNames, P_CER, opts)
%STRATIFIED_EXPECTED_VALUE_CER  Ripartizione dell'incentivo CER con la
%   "stratified expected value" di Cremers, Robu, Zhang, Andoni, Norbu,
%   Flynn, "Efficient methods for approximating the Shapley value for asset
%   sharing in energy communities", Applied Energy 331 (2023) 120328
%   (§4.1.2, eq. 11-13). E' il metodo NUOVO proposto dal paper.
%
%   IL PROBLEMA CHE RISOLVE
%     Lo Shapley value si puo' riscrivere per STRATI (eq. 8 del paper): lo
%     strato j e' l'insieme delle coalizioni di cardinalita' j, e phi_i e' la
%     media, sugli n strati, del contributo marginale ATTESO di i a quello
%     strato. Il costo esponenziale sta tutto nell'enumerare le coalizioni
%     dentro ogni strato.
%
%     La Marginal Contribution (marginal_contribution_cer.m) tiene un solo
%     strato, l'ultimo, e paga in accuratezza. Questo metodo tiene TUTTI gli
%     strati, ma ne stima il contributo atteso con UNA sola valutazione di v
%     invece che con tutte le coalizioni dello strato.
%
%   L'UTENTE FITTIZIO MEDIO (eq. 11)
%     Per il giocatore i si costruisce un utente medio p_-i, che porta la
%     media dei profili degli altri n-1:
%
%       gen_p-i(t)  = ( sum_{q != i} gen_q(t)  ) / (n-1)
%       load_p-i(t) = ( sum_{q != i} load_q(t) ) / (n-1)
%
%     Lo strato j viene allora rappresentato da j COPIE di p_-i, e il
%     contributo marginale atteso a quello strato si stima con (eq. 12):
%
%       SEV_i = (1/n) * sum_{j=0}^{n-1} [ v({j copie di p_-i} + {i}) - v({j copie}) ]
%
%     Il paper media i soli profili di DOMANDA perche' la generazione e'
%     dell'impianto condiviso; qui, dove ogni utente porta anche la propria
%     eccedenza, si mediano entrambi i lati -- altrimenti l'utente medio non
%     rappresenterebbe gli altri giocatori del NOSTRO gioco.
%
%     Attenzione: p_-i non e' un utente reale. I profili veri sono
%     complementari (in ogni ora eccedenza OPPURE carico residuo, mai
%     entrambi), quindi v({i}) = 0 per ogni giocatore vero; l'utente medio
%     invece MESCOLA utenti diversi e ha entrambi i lati nella stessa ora,
%     percio' v({1 copia}) > 0. E' voluto: p_-i e' uno stand-in statistico
%     dello strato, non un membro della comunita'.
%
%   DUE PROPRIETA' ESATTE NEL NOSTRO GIOCO
%     Poiche' la nostra v dipende solo dai profili SOMMATI della coalizione:
%     - strato 0: v({i}) - v({}) = 0, come per ogni giocatore reale;
%     - strato n-1: n-1 copie dell'utente medio riproducono ESATTAMENTE
%       l'aggregato degli altri n-1 utenti veri, quindi l'ultimo termine
%       coincide con il contributo marginale MC_i dell'eq. 9 (a meno del
%       rumore di arrotondamento della divisione per n-1). E' il modo piu'
%       diretto di verificare l'implementazione: vedi .lastStratumMC e
%       l'assert in MAIN.m §3o.
%
%   NORMALIZZAZIONE (eq. 13)
%     Come per la Marginal Contribution l'efficienza non e' automatica e va
%     imposta:  phi_i = v(N) * SEV_i / sum_q SEV_q.
%
%   I PREGI DICHIARATI DAL PAPER
%     Costa O(n^2) valutazioni di v invece di O(2^n), ed e' DETERMINISTICO:
%     rieseguito sugli stessi dati da' gli stessi numeri, e due utenti con lo
%     stesso profilo ricevono la stessa quota. Il paper insiste su questo
%     punto (§2.2): in una CER i membri devono poter riverificare il conto
%     dell'aggregatore, cosa che un metodo a campionamento non garantisce.
%     Nei loro test batte sempre la Marginal Contribution e, quando la
%     comunita' e' concentrata su pochi profili tipo, anche il campionamento
%     adattivo, a un decimo del costo.
%
%   ...E COSA SUCCEDE INVECE SULLA NOSTRA TOPOLOGIA  (leggere prima di usare
%   i numeri: qui il metodo NON funziona come nel paper)
%     Sui dati del progetto la differenza relativa dallo Shapley esatto e'
%     ~22% in media (MAIN.m §3q), contro l'1% della Marginal Contribution e
%     l'1.5% del campionamento adattivo: e' il PEGGIORE dei tre, l'esatto
%     rovescio della graduatoria del paper. L'errore e' sistematico -- gonfia
%     tutti i consumatori (+19..+25%) e sgonfia il prosumer (-20%) -- quindi
%     non e' rumore ma una distorsione di modello.
%
%     La causa e' l'ipotesi implicita nell'eq. 11: che i membri siano
%     INTERCAMBIABILI, cioe' che un utente medio sia un buon rappresentante di
%     un utente qualsiasi. Nel paper e' vero, perche' la generazione e' di un
%     impianto in COMPROPRIETA' e ogni membro ne porta una fetta: nessuno e'
%     mai indispensabile. Da noi la generazione appartiene a UN solo membro su
%     sei. Le coalizioni vere quindi sono di due tipi nettamente diversi:
%     quelle senza il prosumer, che valgono v = 0, e quelle con lui. L'utente
%     medio invece SPALMA la generazione del prosumer su tutti, cosi' ogni
%     strato fittizio risulta avere generazione e ogni consumatore sembra
%     contribuire anche negli strati in cui, nella realta', non c'e' nulla da
%     condividere. Da qui la sovrastima dei consumatori, e la perdita del
%     prosumer una volta imposta la normalizzazione dell'eq. 13.
%
%     La misura esatta del fenomeno si ottiene con opts.validateStrata (vedi
%     sotto), che enumera il contributo marginale VERO di ogni strato. Sui
%     dati del progetto:
%
%       office_1, strato 1:  vero 185.40 EUR   stimato 640.79 EUR  (+246%)
%       office_1, strato 5:  vero 851.23 EUR   stimato 851.23 EUR  (esatto)
%       small_industry (il prosumer), ogni strato:  scarto < 1.5%
%
%     Il caso limite dello strato 1 dice tutto. Delle 5 coalizioni singoletto
%     che office_1 puo' incontrare, UNA sola contiene il prosumer e vale
%     qualcosa; le altre quattro valgono zero. Il contributo atteso vero e'
%     quindi "1/5 di probabilita' di incontrare l'intero impianto". L'utente
%     medio trasforma quella lotteria in "certezza di incontrare 1/5
%     dell'impianto" -- e poiche' il min() della nostra v e' CONCAVO, le due
%     cose non coincidono affatto (disuguaglianza di Jensen):
%
%       E[ min(G * 1{prosumer in S}, L_S) ]  !=  min( E[G * 1{...}], E[L_S] )
%
%     Nel paper il termine aleatorio non esiste: la generazione e' un dato
%     deterministico che cresce con la taglia della coalizione, quindi lo
%     scarto di Jensen e' trascurabile e l'approssimazione funziona. Da noi
%     il 52% delle coalizioni proprie vale ESATTAMENTE zero (quelle senza il
%     prosumer), ed e' precisamente cio' che l'utente medio non sa
%     rappresentare.
%
%     Non e' quindi un difetto dell'implementazione: gli strati 0 e n-1, dove
%     l'approssimazione non ha spazio per sbagliare, sono riprodotti esatti
%     (verificati a ogni esecuzione tramite .lastStratumMC, e per intero con
%     opts.validateStrata). E' il metodo a poggiare su un'ipotesi che questa
%     comunita' viola. Tornera' accurato con piu' impianti distribuiti fra i
%     membri, cioe' quando nessun giocatore sara' piu' pivotale e le
%     coalizioni a valore nullo spariranno: e' la condizione da ricontrollare
%     prima di portarne i numeri in tesi.
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   valutata su richiesta da cer_shared_value senza enumerare le 2^n coalizioni)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente      [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                       (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%                 .F      scalare  fattore di riduzione per contributo in conto
%                         capitale (def. 0); .esente [n x 1] logico, membri
%                         esenti. Per l'utente fittizio medio (eq. 11) la quota
%                         esente e' quella MEDIA degli altri n-1, coerente col
%                         fatto che quell'utente E' la loro media
%     opts      struct    opzionale, campi tutti facoltativi:
%                 .validateStrata  logico (def. false). Se true - e solo per
%                   n <= 12, altrimenti la verifica costerebbe quanto lo
%                   Shapley esatto - enumera TUTTE le coalizioni e calcola il
%                   contributo marginale medio VERO di ogni strato (eq. 8),
%                   cioe' esattamente la grandezza che l'eq. 12 approssima.
%                   Verifica poi che agli strati 0 e n-1, dove esiste una sola
%                   coalizione e l'approssimazione deve essere esatta, i due
%                   valori coincidano: e' il controllo che separa un errore di
%                   IMPLEMENTAZIONE (che li farebbe divergere) da un errore di
%                   MODELLO (che si concentra sugli strati intermedi). Popola
%                   .muExact e .strataBias. Stessa logica di opts.validateDense
%                   in variance_least_core_cer.m.
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici
%     .players       [1 x n]  nomi dei giocatori (= userNames)
%     .phi           [n x 1]  ripartizione normalizzata              [EUR]
%     .vGrand        scalare  valore della grande coalizione         [EUR]
%     .isProsumer    [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare     scalare  quota totale ai prosumer               [EUR]
%     .consShare     scalare  quota totale ai consumatori puri       [EUR]
%     .sevRaw        [n x 1]  valori SEV grezzi, eq. 12              [EUR]
%     .strataMC      [n x n]  contributo marginale stimato per strato:
%                             riga = giocatore, colonna j+1 = strato j [EUR]
%     .lastStratumMC [n x 1]  ultima colonna di .strataMC, che deve
%                             coincidere con .mcRaw di marginal_contribution_cer
%     .normFactor    scalare  v(N) / sum(SEV), fattore dell'eq. 13
%     .muExact       [n x n]  contributo marginale medio VERO per strato
%                             (eq. 8), solo con opts.validateStrata; [] altrimenti
%     .strataBias    [n x n]  .strataMC - .muExact, cioe' dove e di quanto
%                             l'approssimazione sbaglia; [] senza validazione
%     .table         table    riepilogo (giocatore, quota, percentuale)

    [H, n]  = size(loadUsers);
    players = string(userNames(:).');

    if size(genUsers, 2) ~= n
        error('stratified_expected_value_cer:sizeMismatch', ...
              'genUsers ha %d colonne, loadUsers ne ha %d: serve una colonna per utente.', ...
              size(genUsers, 2), n);
    end
    if n < 2
        error('stratified_expected_value_cer:tooFewPlayers', ...
              ['Servono almeno 2 giocatori: l''utente medio dell''eq. 11 e'' la ' ...
               'media sugli altri n-1, indefinita con n = %d.'], n);
    end
    if ~all(isfinite(genUsers), 'all') || ~all(isfinite(loadUsers), 'all')
        error('stratified_expected_value_cer:nonFiniteInput', ...
              'Profili con NaN o Inf in ingresso: controllare i dati a monte.');
    end

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'validateStrata') || isempty(opts.validateStrata)
        opts.validateStrata = false;
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    % --- Fattore F ed esenzione ---------------------------------------------
    if ~isfield(opts, 'esente'), opts.esente = []; end
    if ~isfield(opts, 'F'),      opts.F      = 0;  end
    if isempty(opts.esente)
        esente = false(n, 1);
    else
        esente = logical(opts.esente(:));
    end
    Fred = opts.F;

    % --- Grande coalizione --------------------------------------------------
    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    loadEsC  = sum(loadUsers(:, esente), 2);
    vGrand   = cer_shared_value(genComm, loadComm, P_CER, loadEsC, Fred);

    % --- Contributo marginale atteso, strato per strato (eq. 11-12) ---------
    strataMC = zeros(n, n);        % riga = giocatore, colonna j+1 = strato j
    for i = 1:n
        % Utente fittizio medio degli altri n-1 (eq. 11), su entrambi i lati.
        genAvg  = (genComm  - genUsers(:,  i)) / (n - 1);
        loadAvg = (loadComm - loadUsers(:, i)) / (n - 1);
        % L'utente medio e' la media degli altri n-1: la sua quota esente e'
        % percio' la loro quota esente media, non quella della comunita'.
        loadEsAvg = (loadEsC - loadUsers(:, i) * esente(i)) / (n - 1);

        for j = 0:(n-1)
            % Strato j rappresentato da j copie dell'utente medio: gli
            % aggregati sono semplicemente j volte il profilo medio.
            vBase = cer_shared_value(j * genAvg, j * loadAvg, P_CER, ...
                                     j * loadEsAvg, Fred);
            vWith = cer_shared_value(j * genAvg  + genUsers(:,  i), ...
                                     j * loadAvg + loadUsers(:, i), P_CER, ...
                                     j * loadEsAvg + loadUsers(:, i) * esente(i), Fred);
            strataMC(i, j+1) = vWith - vBase;
        end
    end

    sev = mean(strataMC, 2);       % media sugli n strati (eq. 12)

    sumSEV = sum(sev);
    if sumSEV <= 0
        error('stratified_expected_value_cer:degenerateGame', ...
              ['Somma dei valori SEV non positiva (%.6g): nessuna energia ' ...
               'condivisa da ripartire (v(N) = %.6g EUR).'], sumSEV, vGrand);
    end

    % --- Normalizzazione all'efficienza (eq. 13) ----------------------------
    normFactor = vGrand / sumSEV;
    phi        = normFactor * sev;

    % --- Validazione facoltativa contro l'eq. 8 esatta ----------------------
    muExact    = [];
    strataBias = [];
    if opts.validateStrata
        if n > 12
            warning('stratified_expected_value_cer:validateSkipped', ...
                    ['Validazione per strati saltata: %d giocatori, ' ...
                     'l''enumerazione costerebbe quanto lo Shapley esatto.'], n);
        else
            muExact    = exact_strata_mc(genUsers, loadUsers, P_CER, n, esente, Fred);
            strataBias = strataMC - muExact;

            % Strati 0 e n-1: una sola coalizione ciascuno, quindi l'utente
            % medio non ha nulla da mediare e la stima DEVE coincidere con il
            % valore vero. Se divergono qui, l'errore e' nella costruzione
            % dell'eq. 11; se divergono solo negli strati intermedi, e' il
            % limite di modello discusso nell'intestazione.
            tol = 1e-6 * max(1, abs(vGrand));
            if max(abs(strataBias(:, 1))) > tol || max(abs(strataBias(:, end))) > tol
                error('stratified_expected_value_cer:strataMismatch', ...
                      ['Strati degeneri non riprodotti esattamente (scarto max ' ...
                       '%.3g EUR allo strato 0, %.3g EUR allo strato n-1): ' ...
                       'l''utente medio dell''eq. 11 e'' costruito male.'], ...
                      max(abs(strataBias(:, 1))), max(abs(strataBias(:, end))));
            end
        end
    end

    % --- Output -------------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';        % chi porta produzione nel gioco

    S.players       = players;
    S.phi           = phi;
    S.vGrand        = vGrand;
    S.isProsumer    = isProsumer;
    S.prodShare     = sum(phi(isProsumer));
    S.consShare     = sum(phi(~isProsumer));
    S.sevRaw        = sev;
    S.strataMC      = strataMC;
    S.lastStratumMC = strataMC(:, end);
    S.normFactor    = normFactor;
    S.muExact       = muExact;
    S.strataBias    = strataBias;
    S.table         = table(players(:), phi, 100*phi/vGrand, ...
                            'VariableNames', ...
                            {'Giocatore', 'StratifiedExpectedValue_EUR', 'Quota_pct'});
end


function muExact = exact_strata_mc(genUsers, loadUsers, P_CER, n, esente, Fred)
%EXACT_STRATA_MC  Contributo marginale medio VERO di ogni strato (eq. 8):
%
%     mu(i,j) = media, su TUTTE le S subset N\{i} con |S| = j, di v(S+i) - v(S)
%
%   E' esattamente la grandezza che l'eq. 12 stima con una sola valutazione
%   sull'utente medio. Enumerarla costa quanto lo Shapley esatto -- 2^(n-1)
%   coalizioni per giocatore -- quindi serve solo come verifica, mai nel
%   percorso normale.
%
%   Proprieta' utile per chi legge il risultato: mean(muExact, 2) E' lo
%   Shapley value esatto, perche' l'eq. 8 non e' altro che lo Shapley scritto
%   per strati. Confrontarla con shapley_cer.m e' quindi un ulteriore
%   controllo incrociato disponibile a costo zero.

    muExact = zeros(n, n);              % colonna j+1 = strato j
    for i = 1:n
        others = setdiff(1:n, i);
        acc = zeros(1, n);
        cnt = zeros(1, n);
        for mask = 0:(2^(n-1) - 1)
            sel   = others(bitget(mask, 1:(n-1)) == 1);
            genS   = sum(genUsers(:,  sel), 2);     % [H x 0] -> colonna di zeri
            loadS  = sum(loadUsers(:, sel), 2);
            loadEs = sum(loadUsers(:, sel(esente(sel))), 2);
            mc    = cer_shared_value(genS + genUsers(:,  i), ...
                                     loadS + loadUsers(:, i), P_CER, ...
                                     loadEs + loadUsers(:, i) * esente(i), Fred) ...
                  - cer_shared_value(genS, loadS, P_CER, loadEs, Fred);
            j        = numel(sel);
            acc(j+1) = acc(j+1) + mc;
            cnt(j+1) = cnt(j+1) + 1;
        end
        muExact(i, :) = acc ./ cnt;
    end
end
