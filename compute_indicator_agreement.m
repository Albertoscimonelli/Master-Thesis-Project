function A = compute_indicator_agreement(RESULTS, opts)
%COMPUTE_INDICATOR_AGREEMENT  Quanto due indicatori di equita' concordano
%   nell'ORDINARE i sedici metodi, misurato con il tau-b di Kendall, una
%   configurazione alla volta.
%
%   A CHE DOMANDA RISPONDE
%     La domanda di ricerca (§2.6 della tesi) chiede "to what extent do different
%     fairness indicators agree in evaluating them". Il README §7.0 racconta gia'
%     il caso piu' netto - l'Equal Split e' primo su EI e Gini e ULTIMO sulla
%     stabilita', il Nucleolo fa l'opposto - e plot_fairness_tradeoff lo rende
%     geometrico. Ma sono racconto e figura: chi legge deve ricostruire a occhio
%     quanto due colonne concordino. Questa funzione lo misura.
%
%   LA TRAPPOLA DEI VERSI, CHE E' LA COSA PIU' FACILE DA SBAGLIARE
%     Gli indicatori hanno direzioni opposte del "buono": EI, Jain, QoS e MinMax
%     vanno verso 1, mentre Gini, Fairness Index, Sigma ed EccessoMax_EUR vanno
%     verso il basso. Senza orientarli, il tau fra EI e Gini verrebbe -1 mentre la
%     verita' e' +1, e la tabella delle inversioni direbbe il CONTRARIO del vero.
%
%     C'e' pero' un'ancora esatta, e va usata come test: fairness_indicators_lem
%     calcola eiOrig = 1 - gini sullo STESSO vettore di risparmi. Dopo un
%     orientamento corretto, quindi, tau_b(EI_orig, Gini) deve valere ESATTAMENTE
%     +1, su ogni configurazione - e puo' valerlo perche' le loro strutture di
%     pareggio sono identiche per costruzione, che e' l'unico caso in cui il tau-b
%     raggiunge +-1. Quel singolo assert esercita insieme la tabella dei versi, la
%     regola dei pareggi e l'implementazione del tau.
%
%     Per questo l'orientamento e' DATO e non codice: sta in una tabella letterale
%     (local_orientamenti), esce nella struct e finisce nel CSV. E ogni colonna di
%     Tfair deve comparirvi esattamente una volta: una colonna nuova senza una
%     decisione sul verso fa FALLIRE la funzione invece di farle indovinare.
%
%   NON TUTTI GLI INDICATORI HANNO UN VERSO NORMATIVO
%     Le quattro colonne della forza incentivante hanno una direzione ben definita
%     - piu' alto = premia di piu' il sincronismo - quindi il tau e' calcolabile.
%     Ma "piu' incentivante" NON vuol dire "piu' equo": e' un asse di progetto.
%     La colonna Normativo lo dichiara, cosi' quelle quattro non finiscono per
%     sbaglio in un punteggio aggregato di equita'.
%
%   IL TAU-B, SCRITTO A MANO E CONTANDO COPPIE
%     corr(...,'Type','Kendall') vive nello Statistics Toolbox, da cui questo
%     progetto non dipende (Gini, Jain e Pearson sono tutti scritti a mano). Con
%     sedici metodi sono 120 coppie: un doppio ciclo e' istantaneo.
%
%         tau_b = (C - D) / sqrt((n0 - n1) * (n0 - n2))
%         n0 = m(m-1)/2,  n1 = coppie a pari su x,  n2 = coppie a pari su y
%
%     Si contano COPPIE e non gruppi di pareggio, e non e' un dettaglio di stile:
%     con una regola di pareggio a tolleranza "essere a pari" NON E' TRANSITIVO
%     (a~b e b~c non implicano a~c), quindi i gruppi non sono ben definiti e la
%     formula da manuale sum_g t_g(t_g-1)/2 puo' non coincidere col conteggio. Il
%     conteggio di coppie e' sempre definito.
%
%     Si usa tau-b e non tau-a, che non corregge i pareggi e sarebbe distorto
%     proprio dove questi indicatori degenerano; ne' tau-c, che serve a tabelle
%     rettangolari con categorie di numerosita' diversa, non e' il caso qui.
%     DA DICHIARARE IN TESI: il tau-b non puo' raggiungere +-1 quando i due
%     indicatori hanno strutture di pareggio DIVERSE, quindi un tau < 1 fra un
%     indicatore molto pareggiato (QuoteNulle, CoalizioniInstabili) e uno continuo
%     non e' prova di disaccordo sostanziale.
%
%   INDICATORE COSTANTE: NaN, NON ZERO
%     Se un indicatore non discrimina, n0 - n1 = 0 e il tau e' 0/0. Restituire
%     zero direbbe "questi due indicatori sono indipendenti", che e' un'affermazione
%     falsa, e trascinerebbe verso lo zero qualunque media di accordo. NaN dice
%     "qui questo indicatore non ordina niente", che e' la verita'. E' la stessa
%     scelta di jain_index.m, per lo stesso motivo. La diagonale resta 1 per
%     definizione, cosi' resta leggibile anche in presenza di colonne piatte.
%
%   IL TERZO CRITERIO DELLA DOMANDA DI RICERCA
%     Oltre alle colonne di Tfair viene aggiunto VAN_min_EUR, il VAN del membro
%     messo PEGGIO sotto ciascun metodo: "con questa regola, chi ci rimette di
%     piu' rientra comunque?". E' la lettura piu' diretta della "economic
%     sustainability of participation" della domanda di ricerca, e si costruisce
%     da RESULTS.NPV, che porta il VAN di tutti e sedici i metodi. Vale NaN sulle
%     comunita' che non compilano quota_inv_EUR.
%
%   INPUT
%     RESULTS  struct array, un elemento per CER, con almeno i campi
%                .scheda .Tfair .metodi .penetrazione .NPV
%     opts     struct opzionale:
%                .tolAssoluta   soglia di discriminazione (def. 1e-9)
%                .tolRelativa   soglia di pareggio (def. 1e-6)
%                .validateSelf  auto-test analitico del tau (def. true)
%                .quiet         non stampare il riepilogo (def. false)
%
%   OUTPUT (struct A)
%     .indicators   [1 x nI]  nomi degli indicatori, orientati
%     .methods      [1 x nM]  metodi presenti in TUTTE le comunita'
%     .schede       [1 x nK]  identita' delle configurazioni
%     .penetrazione [1 x nK]  penetrazione prosumer [%], asse di composizione
%     .orientation  table     Indicatore | Verso | Normativo | Motivo
%     .scores       [nM x nI x nK]  punteggi ORIENTATI (piu' alto = meglio)
%     .tau          [nI x nI x nK]  tau-b per configurazione
%     .tauMedio     [nI x nI]       media sulle configurazioni, NaN esclusi
%     .discrimina   [nI x nK]  logico, false se l'indicatore e' piatto
%     .tolTie       [nI x nK]  tolleranza di pareggio effettivamente usata
%     .table        table     formato lungo, una riga per (config, indA, indB)

    if nargin < 2 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'tolAssoluta'),  opts.tolAssoluta  = 1e-9; end
    if ~isfield(opts, 'tolRelativa'),  opts.tolRelativa  = 1e-6; end
    if ~isfield(opts, 'validateSelf'), opts.validateSelf = true; end
    if ~isfield(opts, 'quiet'),        opts.quiet        = false; end

    if opts.validateSelf
        local_validate_self();
    end

    nK = numel(RESULTS);
    if nK < 1
        error('compute_indicator_agreement:nessunaCER', ...
              'RESULTS e'' vuoto: non c''e'' niente da confrontare.');
    end

    optTol = struct('tolAssoluta', opts.tolAssoluta, 'tolRelativa', opts.tolRelativa);
    O      = local_orientamenti();

    % --- Metodi comuni a tutte le comunita', incrociati per NOME -------------
    % Per posizione sarebbe sbagliato: due tabelle con lo stesso numero di righe
    % non garantiscono lo stesso ordine, e uno scambio silenzioso attribuirebbe a
    % un metodo il punteggio di un altro (stessa cautela di plot_gini_3d.m).
    metodi = string(RESULTS(1).Tfair.Metodo);
    for c = 2:nK
        metodi = metodi(ismember(metodi, string(RESULTS(c).Tfair.Metodo)));
    end
    nM = numel(metodi);
    if nM < 2
        error('compute_indicator_agreement:metodiInsufficienti', ...
              'Solo %d metodi comuni a tutte le comunita'': non c''e'' graduatoria.', nM);
    end

    % --- Indicatori comuni, derivati da Tfair e non scritti a mano -----------
    % Cosi' l'unico accoppiamento con chi aggiunge una colonna e' la tabella dei
    % versi, e dimenticarla e' un errore invece che un numero sbagliato.
    indic = setdiff(string(RESULTS(1).Tfair.Properties.VariableNames), "Metodo", 'stable');
    for c = 2:nK
        indic = indic(ismember(indic, ...
                    string(RESULTS(c).Tfair.Properties.VariableNames)));
    end

    % La colonna del VAN entra se ALMENO UNA configurazione la produce, non se la
    % producono tutte. Pretendere tutte sarebbe sbagliato due volte: basta una
    % scheda con quota_inv_EUR a "?" - oggi CER_6_1_0 - per cancellare il terzo
    % criterio della domanda di ricerca da TUTTE le altre sei; e il meccanismo per
    % gestire un'assenza esiste gia', perche' un indicatore con NaN e' dichiarato
    % non discriminante SOLO per quella configurazione. Meglio una colonna con un
    % buco dichiarato che nessuna colonna.
    haNPV = arrayfun(@(r) ~isempty(r.NPV), RESULTS);
    if any(haNPV)
        indic(end+1) = "VAN_min_EUR";
    end

    mancanti = indic(~ismember(indic, string(O.Indicatore)));
    if ~isempty(mancanti)
        error('compute_indicator_agreement:indicatoreNonOrientato', ...
              ['Questi indicatori non hanno un verso dichiarato: %s.\n' ...
               'Aggiungerli a local_orientamenti dentro compute_indicator_agreement.m, ' ...
               'decidendo\nse un valore alto sia meglio (+1) o peggio (-1) e se il ' ...
               'verso sia NORMATIVO.'], strjoin(cellstr(mancanti), ', '));
    end
    nI = numel(indic);

    % --- Punteggi orientati ---------------------------------------------------
    verso  = zeros(nI, 1);
    for j = 1:nI
        verso(j) = O.Verso(string(O.Indicatore) == indic(j));
    end

    scores = nan(nM, nI, nK);
    for c = 1:nK
        T = RESULTS(c).Tfair;
        nomiT = string(T.Metodo);
        for k = 1:nM
            r = find(nomiT == metodi(k), 1);
            for j = 1:nI
                if indic(j) == "VAN_min_EUR", continue; end
                scores(k, j, c) = verso(j) * T.(indic(j))(r);
            end
        end
        if any(haNPV) && haNPV(c)
            jVan  = find(indic == "VAN_min_EUR", 1);
            nomiM = [RESULTS(c).metodi.nome];
            for k = 1:nM
                col = find(nomiM == metodi(k), 1);
                if ~isempty(col) && col <= size(RESULTS(c).NPV, 2)
                    scores(k, jVan, c) = verso(jVan) * min(RESULTS(c).NPV(:, col));
                end
            end
        end
    end

    % --- Discriminazione e tolleranze, una per (indicatore, configurazione) ---
    discrimina = false(nI, nK);
    tolTie     = zeros(nI, nK);
    for c = 1:nK
        for j = 1:nI
            [discrimina(j, c), tolTie(j, c)] = ...
                indicator_tie_tol(scores(:, j, c), optTol);
        end
    end

    % --- Tau-b -----------------------------------------------------------------
    tau = nan(nI, nI, nK);
    nCo = nan(nI, nI, nK);
    nDi = nan(nI, nI, nK);
    nPa = nan(nI, nI, nK);
    for c = 1:nK
        for a = 1:nI
            if ~discrimina(a, c), continue; end
            tau(a, a, c) = 1;      % un indicatore concorda con se stesso
            nPa(a, a, c) = 0;
            for b = a+1:nI
                if ~discrimina(b, c), continue; end
                [t, nc, nd, n1, ~] = local_kendall_tau_b( ...
                        scores(:, a, c), scores(:, b, c), tolTie(a, c), tolTie(b, c));
                tau(a, b, c) = t;   tau(b, a, c) = t;
                nCo(a, b, c) = nc;  nCo(b, a, c) = nc;
                nDi(a, b, c) = nd;  nDi(b, a, c) = nd;
                nPa(a, b, c) = n1;
            end
        end
        % La diagonale vale 1 anche per gli indicatori piatti: la verifica
        % "diagonale unitaria" deve reggere sempre, e la piattezza si legge nella
        % colonna Discrimina, che e' il posto giusto.
        for a = 1:nI
            tau(a, a, c) = 1;
        end
    end

    tauMedio = mean(tau, 3, 'omitnan');

    % --- Tabella lunga per il CSV ---------------------------------------------
    % Lunga e non nK matrici: un file solo, nessuna ambiguita' su come sia
    % orientata la matrice, e si pivota in un attimo.
    schede = strings(1, nK);
    for c = 1:nK
        [~, schede(c)] = fileparts(RESULTS(c).scheda);
        schede(c) = strtrim(schede(c));
    end
    penetr = arrayfun(@(r) r.penetrazione, RESULTS);

    nRig = nI * nI * nK;
    cS   = strings(nRig, 1);  cP = zeros(nRig, 1);
    cA   = strings(nRig, 1);  cB = strings(nRig, 1);
    cT   = nan(nRig, 1);      cC = nan(nRig, 1);   cD = nan(nRig, 1);
    cDA  = false(nRig, 1);    cDB = false(nRig, 1);
    i = 0;
    for c = 1:nK
        for a = 1:nI
            for b = 1:nI
                i = i + 1;
                cS(i) = schede(c);   cP(i)  = penetr(c);
                cA(i) = indic(a);    cB(i)  = indic(b);
                cT(i) = tau(a,b,c);  cC(i)  = nCo(a,b,c);   cD(i) = nDi(a,b,c);
                cDA(i) = discrimina(a,c);  cDB(i) = discrimina(b,c);
            end
        end
    end

    A.table = table(cS, cP, cA, cB, cT, cC, cD, cDA, cDB, ...
                    'VariableNames', {'Scheda', 'Penetrazione_pct', ...
                                      'IndicatoreA', 'IndicatoreB', 'TauB', ...
                                      'Concordi', 'Discordi', ...
                                      'DiscriminaA', 'DiscriminaB'});

    % --- Struttura di uscita ---------------------------------------------------
    A.indicators   = indic(:).';
    A.methods      = metodi(:).';
    A.schede       = schede;
    A.penetrazione = penetr(:).';
    A.orientation  = O(ismember(string(O.Indicatore), indic), :);
    A.scores       = scores;
    A.tau          = tau;
    A.tauMedio     = tauMedio;
    A.discrimina   = discrimina;
    A.tolTie       = tolTie;
    A.verso        = verso;

    if ~opts.quiet
        piatti = indic(any(~discrimina, 2));
        fprintf('\n=== Accordo fra indicatori (tau-b di Kendall) ===\n');
        fprintf('  %-34s: %d indicatori x %d metodi x %d comunita''\n', ...
                'Griglia', nI, nM, nK);
        if ~isempty(piatti)
            fprintf(['  %-34s: %s\n' ...
                     '  %-34s  (tau = NaN dove non ordinano: e'' informazione, non un buco)\n'], ...
                    'Non discriminanti almeno una volta', ...
                    strjoin(cellstr(piatti), ', '), '');
        end
        if any(~haNPV)
            fprintf(['  %-34s: %d comunita'' su %d senza VAN, perche'' non compilano\n' ...
                     '  %-34s  [MEMBRI].quota_inv_EUR: %s\n'], ...
                    'Sostenibilita'' economica parziale', sum(~haNPV), nK, '', ...
                    strjoin(cellstr(schede(~haNPV)), ', '));
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function O = local_orientamenti()
%LOCAL_ORIENTAMENTI  Da che parte sta il meglio, per ogni indicatore.
%
%   Dichiarato come DATO e non come codice, perche' e' la prima cosa che un
%   lettore deve poter verificare e l'ultima che si vorrebbe trovare sepolta in
%   un if. Esce nella struct e finisce nel CSV.
%
%   Verso     +1 = un valore alto e' meglio; -1 = un valore basso e' meglio.
%   Normativo true se "meglio" e' un giudizio di equita'; false se e' solo una
%             direzione di lettura, e l'indicatore non deve entrare in nessun
%             punteggio aggregato di equita'.
    nome = [ "MinMax_pro"; "MinMax_con"; "QoS_orig"; "QoS_new"
             "EI_orig"; "EI_new"; "Jain"
             "Gini"; "FairnessIndex"; "Sigma"; "QuoteNulle"
             "EccessoMax_EUR"; "CoalizioniInstabili"
             "ForzaIncentivante"; "AllineamentoVirtu"
             "ForzaIncentivante_lordo"; "AllineamentoVirtu_lordo"
             "VAN_min_EUR" ];

    verso = [ +1; +1; +1; +1
              +1; +1; +1
              -1; -1; -1; -1
              -1; -1
              +1; +1
              +1; +1
              +1 ];

    normativo = [ true;  true;  true;  true
                  true;  true;  true
                  true;  true;  true;  true
                  true;  true
                  false; false
                  false; false
                  true ];

    % Nessuna virgola dentro i motivi: writetable la quoterebbe correttamente, ma
    % il file smetterebbe di essere leggibile a occhio in un terminale, ed e' il
    % primo che si apre quando un risultato non torna.
    motivo = [ "1 = equo (Dynge eq. 16)"
               "1 = equo (Dynge eq. 17)"
               "1 = equo - Jain sui volumi (Dynge eq. 12)"
               "1 = equo - Jain segmentato (Dynge eq. 18)"
               "1 = equo - 1 meno il Gini dei risparmi (Dynge eq. 15)"
               "1 = equo - EI segmentato (Dynge eq. 19)"
               "1 = equo - indice di Jain grezzo"
               "0 = equo - concentrazione dei risparmi"
               "0 = equo - distanza dal merito (Casalicchio eq. 14)"
               "0 = equo - dispersione dello scostamento dal merito"
               "0 = equo - membri lasciati a quota nulla"
               "piu' basso = piu' stabile (Volpato eq. 23)"
               "piu' basso = piu' stabile - sottogruppi che uscirebbero"
               "piu' alto = premia di piu' il sincronismo - NON un giudizio di equita'"
               "piu' alto = il premio e' piu' diretto alla virtuosita' - NON equita'"
               "come sopra - asse costruito sui profili lordi"
               "come sopra - asse costruito sui profili lordi"
               "piu' alto = il membro messo peggio rientra meglio" ];

    O = table(nome, verso, normativo, motivo, ...
              'VariableNames', {'Indicatore', 'Verso', 'Normativo', 'Motivo'});
end

function s = local_segno(d, tol)
%LOCAL_SEGNO  Segno con tolleranza: dentro tol i due punteggi sono a pari.
    if abs(d) <= tol
        s = 0;
    else
        s = sign(d);
    end
end

function [tau, nC, nD, n1, n2] = local_kendall_tau_b(x, y, tolx, toly)
%LOCAL_KENDALL_TAU_B  Tau-b contando COPPIE (vedi header: con i pareggi a
%   tolleranza i gruppi di pari non sono ben definiti, le coppie si').
    x = x(:); y = y(:);
    m = numel(x);
    nC = 0; nD = 0; n1 = 0; n2 = 0;
    for i = 1:m-1
        for j = i+1:m
            sx = local_segno(x(i) - x(j), tolx);
            sy = local_segno(y(i) - y(j), toly);
            if sx == 0, n1 = n1 + 1; end
            if sy == 0, n2 = n2 + 1; end
            p = sx * sy;
            if     p > 0, nC = nC + 1;
            elseif p < 0, nD = nD + 1;
            end
        end
    end
    n0  = m * (m - 1) / 2;
    den = sqrt((n0 - n1) * (n0 - n2));
    if den <= 0
        tau = NaN;
    else
        tau = (nC - nD) / den;
    end
end

function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test del tau-b su casi calcolabili a penna.
    tol = 1e-12;

    % Ordine inverso, nessun pareggio: tutte discordanti -> tau = -1
    t = local_kendall_tau_b([1;2;3], [3;2;1], 0, 0);
    assert(abs(t + 1) < tol, 'compute_indicator_agreement: tau di due ordini inversi non -1');

    % Ordine identico -> tau = +1
    t = local_kendall_tau_b([1;2;3], [1;2;3], 0, 0);
    assert(abs(t - 1) < tol, 'compute_indicator_agreement: tau di due ordini uguali non +1');

    % Un pareggio su x: m=3 -> n0=3, n1=1, n2=0, C-D = 2
    %   tau = 2 / sqrt(2*3) = 2/sqrt(6) = 0.816496...
    t = local_kendall_tau_b([1;1;2], [1;2;3], 0, 0);
    assert(abs(t - 2/sqrt(6)) < tol, ...
           'compute_indicator_agreement: tau-b con un pareggio errato');

    % Trasformazione affine crescente: non cambia l'ordine -> tau invariato
    t2 = local_kendall_tau_b([1;1;2], 10*[1;2;3] + 7, 0, 0);
    assert(abs(t2 - t) < tol, ...
           'compute_indicator_agreement: il tau non e'' invariante per scala positiva');

    % Serie costante: n0 - n1 = 0 -> NaN, non zero
    t = local_kendall_tau_b([1;1;1], [1;2;3], 0, 0);
    assert(isnan(t), 'compute_indicator_agreement: serie costante non da'' NaN');

    % La tolleranza deve schiacciare un pareggio numerico
    t = local_kendall_tau_b([1;1+1e-15;2], [1;2;3], 1e-9, 0);
    assert(abs(t - 2/sqrt(6)) < tol, ...
           'compute_indicator_agreement: la tolleranza non riconosce il pareggio');

    % --- La tabella dei versi e' coerente ------------------------------------
    O = local_orientamenti();
    assert(numel(unique(string(O.Indicatore))) == height(O), ...
           'compute_indicator_agreement: indicatore ripetuto nella tabella dei versi');
    assert(all(ismember(O.Verso, [-1 1])), ...
           'compute_indicator_agreement: un verso diverso da +-1');

    % L'ancora: EI_orig = 1 - Gini per costruzione, quindi versi OPPOSTI.
    vEI   = O.Verso(string(O.Indicatore) == "EI_orig");
    vGini = O.Verso(string(O.Indicatore) == "Gini");
    assert(vEI == -vGini, ...
           ['compute_indicator_agreement: EI_orig e Gini devono avere versi ' ...
            'opposti, essendo EI = 1 - Gini']);

    % ...e con quei versi il tau fra loro deve venire +1 su dati sintetici.
    g   = [0.10; 0.25; 0.40; 0.55];
    ei  = 1 - g;
    t   = local_kendall_tau_b(vEI * ei, vGini * g, 0, 0);
    assert(abs(t - 1) < tol, ...
           'compute_indicator_agreement: EI e Gini orientati non danno tau = +1');
end
