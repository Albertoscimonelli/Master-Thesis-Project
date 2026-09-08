function R = extract_ranking_reversals(A, opts)
%EXTRACT_RANKING_REVERSALS  In quali punti dell'asse di composizione due metodi
%   si scambiano di posto, indicatore per indicatore.
%
%   A CHE DOMANDA RISPONDE
%     L'ultima clausola della domanda di ricerca (§2.6 della tesi): "to what
%     extent does this ranking depend on the composition of the community". Oggi
%     plot_gini_3d mostra se l'ordine fra i metodi regga al cambio di comunita',
%     ma e' una superficie: chi legge deve cercare a occhio dove due fili si
%     incrociano. Qui gli incroci si estraggono, uno per riga.
%
%   PERCHE' RICEVE LA STRUCT DELL'ACCORDO E NON RESULTS
%     Le due funzioni devono usare gli STESSI punteggi orientati e le STESSE
%     tolleranze di pareggio. Se divergessero anche di poco, la stessa coppia di
%     metodi potrebbe risultare "a pari" per il tau di Kendall e "invertita" qui,
%     e i due file direbbero cose incompatibili sulla stessa configurazione senza
%     che nulla lo segnali. Prendendo in ingresso l'uscita di
%     compute_indicator_agreement il rischio non esiste: i punteggi sono gli
%     stessi oggetti, non due ricostruzioni che si spera coincidano.
%
%   SOLO CONFIGURAZIONI ADIACENTI
%     Un'inversione e' un'affermazione sull'ASSE, e il numero di cambi di segno
%     lungo una sequenza ordinata e' definito solo sui passi consecutivi. Se A > B
%     al 14%, B > A al 43% e di nuovo A > B al 71%, la coppia non adiacente
%     (14, 71) non mostra alcun cambio di segno e NASCONDEREBBE due inversioni
%     vere. Confrontare tutte le coppie genererebbe inoltre O(K^2) record
%     ridondanti, tutti funzione di quelli adiacenti.
%
%     Il confronto fra gli ESTREMI si emette lo stesso, ma a parte, nella colonna
%     InvertitoAgliEstremi: "la graduatoria al 14% e' l'opposto di quella al 100%"
%     e' l'affermazione da titolo, e NON e' deducibile dal conteggio, perche' un
%     numero pari di inversioni riporta all'ordine di partenza.
%
%     ATTENZIONE, ED E' IL MOTIVO DELLE DUE COLONNE ACCANTO: quei due estremi
%     sono il primo e l'ultimo segno NON NULLO, che non coincidono con i due
%     estremi dell'ASSE quando la coppia e' a pari - o l'indicatore non
%     discriminante - proprio nella prima o nell'ultima configurazione. Succede:
%     MinMax_con e QoS_new non discriminano alle due penetrazioni piu' alte.
%     PenetrazioneSegnoIniziale_pct e PenetrazioneSegnoFinale_pct dicono dove
%     stanno davvero i due segni confrontati, cosi' l'affermazione da titolo si
%     puo' verificare invece che dare per buona.
%
%   I PAREGGI IN MEZZO A UNA SEQUENZA
%     Si tiene l'ultimo segno NON NULLO invece di confrontare i passi grezzi. Cosi'
%     la sequenza  + , 0 , -  e' registrata come UNA inversione, delimitata dalle
%     due configurazioni non nulle, con PassiPari che conta i passi neutri in
%     mezzo. L'adiacenza ingenua o la perderebbe (nessun passo cambia segno da
%     solo) o la conterebbe due volte.
%
%     Ne segue una proprieta' utile: un'inversione viene registrata solo fra due
%     punti in cui il divario SUPERA la tolleranza. Un attraversamento dello zero
%     numerico non puo' quindi essere scambiato per un'inversione - che e'
%     esattamente l'artefatto da escludere.
%
%   COPPIE NON ORDINATE
%     (A,B) e (B,A) portano la stessa informazione col segno rovesciato: emetterle
%     entrambe raddoppierebbe il file e gonfierebbe il conteggio delle inversioni
%     esattamente di due volte. Convenzione: A e' il metodo che viene PRIMA
%     nell'ordine di A.methods.
%
%   L'ASSE SI PRENDE DALLA SCHEDA, MAI DAL NOME DEL FILE
%     MAIN.m §0 ordina le schede in modo LESSICOGRAFICO: con schede a una cifra
%     questo mette le comunita' in ordine di penetrazione DECRESCENTE, e si
%     romperebbe del tutto alla prima scheda a due cifre. Qui si riordina per
%     penetrazione crescente, presa dal campo [RIEPILOGO] che load_cer_input
%     valida riga per riga contro la tabella dei membri.
%
%   INPUT
%     A     struct  uscita di compute_indicator_agreement
%     opts  struct opzionale:
%             .validateSelf  auto-test analitico (def. true)
%             .quiet         non stampare il riepilogo (def. false)
%
%   OUTPUT (struct R)
%     .asse        [1 x nK]  penetrazione prosumer ordinata crescente [%]
%     .schede      [1 x nK]  schede nello stesso ordine
%     .ordine      [1 x nK]  permutazione applicata alle configurazioni
%     .inversioni  table     una riga per cambio di segno
%     .sommario    table     una riga per (indicatore, metodo A, metodo B)
%     .nInversioni scalare   totale dei cambi di segno trovati

    if nargin < 2 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'validateSelf'), opts.validateSelf = true; end
    if ~isfield(opts, 'quiet'),        opts.quiet        = false; end

    if opts.validateSelf
        local_validate_self();
    end

    indic  = string(A.indicators(:).');
    metodi = string(A.methods(:).');
    nI = numel(indic);
    nM = numel(metodi);
    nK = numel(A.penetrazione);

    if nK < 2
        error('extract_ranking_reversals:unaSolaCER', ...
              ['Serve piu'' di una comunita'' per parlare di inversioni lungo ' ...
               'l''asse di composizione.']);
    end

    % --- L'asse di composizione ------------------------------------------------
    [~, ordine] = sort(A.penetrazione(:), 'ascend');
    ordine      = reshape(ordine, 1, []);
    asse        = reshape(A.penetrazione(ordine), 1, []);
    if any(diff(asse) <= 0)
        error('extract_ranking_reversals:penetrazioneRipetuta', ...
              ['Due configurazioni hanno la stessa penetrazione prosumer: fra loro ' ...
               'l''adiacenza\nnon e'' definita e "prima" o "dopo" sarebbe una scelta ' ...
               'arbitraria.']);
    end

    scores     = A.scores(:, :, ordine);
    discrimina = A.discrimina(:, ordine);
    tolTie     = A.tolTie(:, ordine);
    schede     = A.schede(ordine);

    % --- Scansione -------------------------------------------------------------
    nMax = nI * nM * (nM-1) / 2 * (nK-1);
    dInd = strings(nMax,1);  dA = strings(nMax,1);  dB = strings(nMax,1);
    dSda = strings(nMax,1);  dSa = strings(nMax,1);
    dPda = zeros(nMax,1);    dPa = zeros(nMax,1);
    dGda = zeros(nMax,1);    dGa = zeros(nMax,1);
    dPar = zeros(nMax,1);
    nRig = 0;

    nSer = nI * nM * (nM-1) / 2;
    sInd = strings(nSer,1);  sA = strings(nSer,1);  sB = strings(nSer,1);
    sN   = zeros(nSer,1);    sIni = zeros(nSer,1);  sFin = zeros(nSer,1);
    sEst = false(nSer,1);    sMax = zeros(nSer,1);  sVal = zeros(nSer,1);
    sPIni = nan(nSer,1);     sPFin = nan(nSer,1);
    nSerie = 0;

    for j = 1:nI
        for a = 1:nM-1
            for b = a+1:nM
                gap = squeeze(scores(a, j, :) - scores(b, j, :)).';   % [1 x nK]

                ultimoSegno = 0; ultimoIdx = 0;
                primoSegno  = 0; primoIdx  = 0;
                nInv = 0; nValidi = 0; gapMax = 0;
                nPari = 0;   % passi VALUTATI e risultati a pari dall'ultimo segno

                for c = 1:nK
                    if ~discrimina(j, c) || ~isfinite(gap(c)), continue; end
                    nValidi = nValidi + 1;
                    gapMax  = max(gapMax, abs(gap(c)));

                    s = local_segno(gap(c), tolTie(j, c));
                    if s == 0                         % passo a pari: non chiude nulla
                        nPari = nPari + 1;
                        continue
                    end

                    if primoSegno == 0, primoSegno = s; primoIdx = c; end

                    if ultimoSegno ~= 0 && s ~= ultimoSegno
                        nInv = nInv + 1;
                        nRig = nRig + 1;
                        dInd(nRig) = indic(j);
                        dA(nRig)   = metodi(a);   dB(nRig)  = metodi(b);
                        dSda(nRig) = schede(ultimoIdx);  dSa(nRig) = schede(c);
                        dPda(nRig) = asse(ultimoIdx);    dPa(nRig) = asse(c);
                        dGda(nRig) = gap(ultimoIdx);     dGa(nRig) = gap(c);
                        % SOLO i passi valutati e risultati a pari. La distanza
                        % fra gli indici conterebbe anche le configurazioni in
                        % cui l'indicatore non ordina niente, e quelle non sono
                        % pareggi fra A e B: sono osservazioni MANCANTI, che e'
                        % un'affermazione diversa e piu' debole.
                        dPar(nRig) = nPari;
                    end
                    ultimoSegno = s;
                    ultimoIdx   = c;
                    nPari       = 0;
                end

                nSerie = nSerie + 1;
                sInd(nSerie) = indic(j);
                sA(nSerie)   = metodi(a);   sB(nSerie) = metodi(b);
                sN(nSerie)   = nInv;
                sIni(nSerie) = primoSegno;  sFin(nSerie) = ultimoSegno;
                sEst(nSerie) = primoSegno ~= 0 && ultimoSegno ~= 0 && ...
                               primoSegno ~= ultimoSegno;
                sMax(nSerie) = gapMax;
                sVal(nSerie) = nValidi;
                % DOVE stanno i due segni confrontati. Senza queste due colonne
                % InvertitoAgliEstremi non e' verificabile: il primo e l'ultimo
                % segno NON sono in generale i due estremi dell'asse, perche' la
                % coppia puo' essere a pari - o l'indicatore non discriminante -
                % proprio nella prima o nell'ultima configurazione. NaN quando la
                % serie non ha nemmeno un segno non nullo.
                if primoIdx  > 0, sPIni(nSerie) = asse(primoIdx);  end
                if ultimoIdx > 0, sPFin(nSerie) = asse(ultimoIdx); end
            end
        end
    end

    R.inversioni = table(dInd(1:nRig), dA(1:nRig), dB(1:nRig), ...
                         dSda(1:nRig), dSa(1:nRig), dPda(1:nRig), dPa(1:nRig), ...
                         dGda(1:nRig), dGa(1:nRig), dPar(1:nRig), ...
                         'VariableNames', {'Indicatore', 'MetodoA', 'MetodoB', ...
                                           'SchedaDa', 'SchedaA', ...
                                           'PenetrazioneDa_pct', 'PenetrazioneA_pct', ...
                                           'DivarioDa', 'DivarioA', 'PassiPari'});

    R.sommario = table(sInd(1:nSerie), sA(1:nSerie), sB(1:nSerie), ...
                       sN(1:nSerie), sIni(1:nSerie), sFin(1:nSerie), ...
                       sEst(1:nSerie), sPIni(1:nSerie), sPFin(1:nSerie), ...
                       sMax(1:nSerie), sVal(1:nSerie), ...
                       'VariableNames', {'Indicatore', 'MetodoA', 'MetodoB', ...
                                         'nInversioni', 'SegnoIniziale', 'SegnoFinale', ...
                                         'InvertitoAgliEstremi', ...
                                         'PenetrazioneSegnoIniziale_pct', ...
                                         'PenetrazioneSegnoFinale_pct', ...
                                         'DivarioMax', 'ConfigurazioniValide'});

    R.asse        = asse;
    R.schede      = schede;
    R.ordine      = ordine;
    R.nInversioni = nRig;

    if ~opts.quiet
        fprintf('\n=== Inversioni di graduatoria lungo la composizione ===\n');
        fprintf('  %-34s: %s\n', 'Asse (penetrazione prosumer)', ...
                strjoin(compose('%.1f%%', asse), ' -> '));
        fprintf('  %-34s: %d su %d serie esaminate\n', ...
                'Coppie che si invertono almeno una volta', ...
                sum(R.sommario.nInversioni > 0), nSerie);
        fprintf('  %-34s: %d\n', 'Cambi di segno totali', nRig);
        fprintf('  %-34s: %d\n', 'Coppie invertite fra i due estremi', ...
                sum(R.sommario.InvertitoAgliEstremi));
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function s = local_segno(d, tol)
%LOCAL_SEGNO  Segno con tolleranza. Deve restare identico a quello di
%   compute_indicator_agreement: e' la stessa regola vista da due file.
    if abs(d) <= tol
        s = 0;
    else
        s = sign(d);
    end
end

function n = local_conta_inversioni(gap, tol)
%LOCAL_CONTA_INVERSIONI  Il solo conteggio, isolato per poterlo testare.
    n = 0; ultimo = 0;
    for c = 1:numel(gap)
        s = local_segno(gap(c), tol);
        if s == 0, continue; end
        if ultimo ~= 0 && s ~= ultimo, n = n + 1; end
        ultimo = s;
    end
end

function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test del conteggio su sequenze costruite a mano.

    % Due cambi di segno: + + - - +
    assert(local_conta_inversioni([1 1 -1 -1 1], 0) == 2, ...
           'extract_ranking_reversals: conteggio errato su due inversioni');

    % Un pareggio in mezzo NON spezza la sequenza: + 0 - vale UNA inversione
    assert(local_conta_inversioni([1 0 -1], 0) == 1, ...
           'extract_ranking_reversals: un pareggio in mezzo non e'' attraversato');

    % Tutto a pari: nessuna inversione
    assert(local_conta_inversioni([0 0 0], 0) == 0, ...
           'extract_ranking_reversals: una serie piatta produce inversioni');

    % Segno costante: nessuna inversione, per quanto grande sia l'escursione
    assert(local_conta_inversioni([1 100 3], 0) == 0, ...
           'extract_ranking_reversals: una serie di segno costante produce inversioni');

    % La tolleranza schiaccia il rumore: 1e-15 non e' un attraversamento
    assert(local_conta_inversioni([1 -1e-15 1], 1e-9) == 0, ...
           'extract_ranking_reversals: il rumore numerico viene letto come inversione');

    % ...ma una differenza vera sopra soglia lo e'
    assert(local_conta_inversioni([1 -1 1], 1e-9) == 2, ...
           'extract_ranking_reversals: un attraversamento vero non viene contato');

    % --- LA SCANSIONE REALE, non una sua copia ------------------------------
    % Gli assert qui sopra esercitano local_conta_inversioni, che la funzione
    % pubblica NON chiama: il ciclo di produzione reimplementa la stessa regola
    % inline. Senza questo blocco un errore introdotto nel ciclo reale passa
    % l'auto-test indisturbato, ed e' proprio il caso peggiore - una rete di
    % sicurezza che non copre nulla e ti fa smettere di guardare.
    % Stessa convenzione di compute_incentive_strength.m, il cui auto-test
    % chiama la funzione pubblica in modo ricorsivo con validateSelf a false.
    o = struct('validateSelf', false, 'quiet', true);

    scores = zeros(2, 1, 3);
    scores(1,1,:) = [1 0 1];        % divario A-B: + , - , +  -> DUE inversioni
    scores(2,1,:) = [0 1 0];
    A = struct('indicators', "X", 'methods', ["A" "B"], ...
               'schede', ["c1" "c2" "c3"], 'penetrazione', [10 20 30], ...
               'scores', scores, 'discrimina', true(1,3), 'tolTie', zeros(1,3));
    R = extract_ranking_reversals(A, o);

    assert(R.nInversioni == 2, ...
           'extract_ranking_reversals: la scansione reale non trova le due inversioni');
    assert(height(R.inversioni) == 2, ...
           'extract_ranking_reversals: il dettaglio non ha una riga per inversione');
    assert(sum(R.sommario.nInversioni) == 2, ...
           'extract_ranking_reversals: il sommario non concorda col dettaglio');
    % Un numero PARI di inversioni riporta all'ordine di partenza: e' il motivo
    % per cui la colonna degli estremi esiste, e non si deduce dal conteggio.
    assert(~R.sommario.InvertitoAgliEstremi(1), ...
           'extract_ranking_reversals: due inversioni non riportano all''ordine iniziale');
    assert(isequal(R.asse, [10 20 30]), ...
           'extract_ranking_reversals: l''asse non e'' ordinato per penetrazione');
    % Qui i due segni estremi cadono davvero sui due estremi dell'asse.
    assert(R.sommario.PenetrazioneSegnoIniziale_pct(1) == 10 && ...
           R.sommario.PenetrazioneSegnoFinale_pct(1)   == 30, ...
           'extract_ranking_reversals: le posizioni dei segni estremi sono sbagliate');

    % --- Un pareggio E una configurazione non misurata, in mezzo -------------
    % Cinque configurazioni: alla terza l'indicatore NON discrimina, alla quarta
    % la coppia e' a pari. Fra il segno + (c=2) e il segno - (c=5) c'e' UN solo
    % pareggio misurato; la distanza fra gli indici ne conterebbe DUE, e
    % scriverebbe come pareggio una configurazione che non e' stata valutata.
    s2 = zeros(2, 1, 5);
    s2(1,1,:) = [1 1 0 1 0];
    s2(2,1,:) = [0 0 0 1 1];
    A2 = struct('indicators', "X", 'methods', ["A" "B"], ...
                'schede', ["a" "b" "c" "d" "e"], 'penetrazione', [10 20 30 40 50], ...
                'scores', s2, 'discrimina', [true true false true true], ...
                'tolTie', zeros(1,5));
    R2 = extract_ranking_reversals(A2, o);

    assert(R2.nInversioni == 1, ...
           'extract_ranking_reversals: inversione persa oltre un passo non misurato');
    assert(R2.inversioni.PassiPari(1) == 1, ...
           'extract_ranking_reversals: PassiPari conta le configurazioni non misurate');
    assert(R2.sommario.ConfigurazioniValide(1) == 4, ...
           'extract_ranking_reversals: la configurazione non discriminante e'' stata contata');
end
