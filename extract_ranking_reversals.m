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
    nSerie = 0;

    for j = 1:nI
        for a = 1:nM-1
            for b = a+1:nM
                gap = squeeze(scores(a, j, :) - scores(b, j, :)).';   % [1 x nK]

                ultimoSegno = 0; ultimoIdx = 0;
                primoSegno  = 0;
                nInv = 0; nValidi = 0; gapMax = 0;

                for c = 1:nK
                    if ~discrimina(j, c) || ~isfinite(gap(c)), continue; end
                    nValidi = nValidi + 1;
                    gapMax  = max(gapMax, abs(gap(c)));

                    s = local_segno(gap(c), tolTie(j, c));
                    if s == 0, continue; end          % passo a pari: non chiude nulla

                    if primoSegno == 0, primoSegno = s; end

                    if ultimoSegno ~= 0 && s ~= ultimoSegno
                        nInv = nInv + 1;
                        nRig = nRig + 1;
                        dInd(nRig) = indic(j);
                        dA(nRig)   = metodi(a);   dB(nRig)  = metodi(b);
                        dSda(nRig) = schede(ultimoIdx);  dSa(nRig) = schede(c);
                        dPda(nRig) = asse(ultimoIdx);    dPa(nRig) = asse(c);
                        dGda(nRig) = gap(ultimoIdx);     dGa(nRig) = gap(c);
                        dPar(nRig) = c - ultimoIdx - 1;  % passi neutri in mezzo
                    end
                    ultimoSegno = s;
                    ultimoIdx   = c;
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
                       sEst(1:nSerie), sMax(1:nSerie), sVal(1:nSerie), ...
                       'VariableNames', {'Indicatore', 'MetodoA', 'MetodoB', ...
                                         'nInversioni', 'SegnoIniziale', 'SegnoFinale', ...
                                         'InvertitoAgliEstremi', 'DivarioMax', ...
                                         'ConfigurazioniValide'});

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
end
