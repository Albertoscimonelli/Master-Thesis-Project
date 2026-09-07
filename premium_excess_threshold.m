function S = premium_excess_threshold(phiMat, methodNames, categoria, E_ACI, E_immessa, opts)
%PREMIUM_EXCESS_THRESHOLD  Controllo POST-HOC della soglia di energia
%   incentivabile e della destinazione della tariffa premio eccedentaria
%   (Decreto CACER, DM MASE 7 dicembre 2023 n. 414, art. 3 comma 2 lett. g e
%   Allegato 1 par. 3-4; Regole Operative GSE per l'accesso al servizio per
%   l'autoconsumo diffuso e al contributo PNRR, versione 16 luglio 2025,
%   par. 2.2.2.1.3 e Appendice B par. 4).
%
%   COSA DICE LA NORMA
%     Le CACER devono assicurare - per previsione statutaria o pattuizione
%     privatistica - che l'importo della tariffa premio ECCEDENTARIO, rispetto
%     a quello determinato applicando il valore soglia dell'energia oggetto di
%     incentivazione, sia destinato ai soli consumatori DIVERSI DALLE IMPRESE
%     e/o utilizzato per finalita' sociali con ricadute sul territorio.
%
%     I valori soglia dell'energia elettrica condivisa incentivabile, espressi
%     in percentuale dell'energia immessa in rete, sono:
%
%       a) accesso alla sola tariffa premio ............................ 55%
%       b) cumulo della tariffa premio con contributo in conto capitale . 45%
%
%     e l'eccedenza si calcola cosi' (Regole Operative par. 2.2.2.1.3):
%
%       %E_ACI,ecc = max[0; (E_ACI / E_immessa * 100)% - valore soglia]
%       C_ACI,ecc  = %E_ACI,ecc * C_ACI
%
%     Attenzione alla lettura della seconda riga: l'eccedenza economica NON e'
%     la quota proporzionale di premio associata all'energia in eccesso (che
%     varrebbe (quota-soglia)/quota * C_ACI), ma il prodotto LETTERALE fra la
%     differenza in PUNTI PERCENTUALI e l'importo totale del premio. Con
%     quota = 60% e soglia = 55% l'eccedenza vale il 5% di C_ACI, non l'8,3%.
%     Si implementa la formula del GSE alla lettera perche' e' quella che il
%     GSE applica a conguaglio, non quella che sarebbe piu' naturale.
%
%   PERCHE' STA FUORI DAI METODI, E NON DENTRO
%     E' un vincolo di DESTINAZIONE dell'importo gia' ripartito, non una regola
%     di ripartizione: la norma non dice come dividere, dice dove NON puo'
%     finire una parte del diviso. Metterlo dentro i sedici metodi
%     significherebbe cambiarli tutti e renderli non piu' confrontabili con i
%     rispettivi paper; metterlo qui lascia i metodi intatti e aggiunge una
%     colonna di ammissibilita' regolatoria a valle. E' anche l'ordine in cui
%     la norma opera: il GSE verifica il superamento della soglia A CONGUAGLIO,
%     su base annuale, sull'esito della ripartizione.
%
%   DUE LIVELLI DI ESITO, DA NON CONFONDERE
%     1. La soglia e' BINDING o no. Dipende SOLO dall'energia: se
%        E_ACI/E_immessa <= soglia l'eccedenza e' nulla e il vincolo non morde
%        per NESSUN metodo, quale che sia la ripartizione. E' un fatto della
%        configurazione (quanta dell'energia immessa viene condivisa), non dei
%        meccanismi.
%     2. Se e' binding, ogni metodo e' CONFORME o no a seconda di quanto
%        assegna ai membri d'impresa: questi possono ricevere al piu'
%        (1 - %E_ACI,ecc) * C_ACI, perche' l'eccedenza spetta ai soli
%        consumatori diversi dalle imprese.
%
%   CHI E' "IMPRESA"
%     La norma esenta dal vincolo (e dal fattore F, par. 2.2.2.1.2) l'energia
%     afferente a punti di prelievo di enti territoriali e autorita' locali,
%     enti religiosi, enti del terzo settore e di protezione ambientale, e
%     PERSONE FISICHE. Sul dominio di [MEMBRI].categoria di questo progetto
%     (domestico | terziario | commerciale | industriale | PA) la mappatura e':
%
%       domestico -> persona fisica ............. NON impresa
%       PA        -> ente territoriale .......... NON impresa
%       terziario | commerciale | industriale ... IMPRESA
%
%     E' un'IPOTESI, non un dato: la categoria del progetto e' una tipologia di
%     consumo, non una forma giuridica. In particolare un ente del terzo
%     settore ricadrebbe qui sotto "terziario" e verrebbe contato come impresa
%     a torto. Si sovrascrive con opts.categorieImpresa quando la scheda
%     dichiara la forma giuridica.
%
%   UN SOLO INSIEME DI IMPIANTI
%     La norma aggrega gli impianti in DUE insiemi j (sola tariffa premio /
%     cumulo con conto capitale) e somma le eccedenze dei due. Qui l'insieme e'
%     uno solo, perche' il modello applica una sola TIP a tutta l'energia
%     condivisa e la scheda non dichiara il conto capitale per singolo
%     impianto. Con quel dato disponibile la generalizzazione e' immediata: si
%     chiama questa funzione una volta per insieme e si sommano le
%     .importoEccedente. Vedi README par. 12.
%
%   INPUT
%     phiMat       [n x nM]  ripartizioni, una colonna per metodo      [EUR]
%     methodNames  [1 x nM]  nomi dei metodi                          (string)
%     categoria    [n x 1]   categoria di ciascun membro              (string)
%                            (da [MEMBRI].categoria, allineata a phiMat)
%     E_ACI        scalare   energia condivisa incentivabile annua      [kWh]
%     E_immessa    scalare   energia immessa in rete annua              [kWh]
%     opts         struct opzionale:
%                    .contoCapitale    logico, cumulo con conto capitale
%                                      -> soglia 45% invece di 55% (def. false)
%                    .soglia           soglia in FRAZIONE (0..1), sovrascrive
%                                      .contoCapitale (def. da .contoCapitale)
%                    .categorieImpresa [1 x k] categorie da contare come
%                                      impresa (def. terziario / commerciale /
%                                      industriale)
%                    .playerNames      [1 x n] nomi dei membri, per i messaggi
%                    .tol              tolleranza sul confronto in EUR
%                                      (def. 1e-6 * max(1, C_ACI))
%                    .validateSelf     esegue l'auto-test analitico (def. true)
%                    .quiet            non stampare il riepilogo (def. false)
%
%   OUTPUT (struct S)
%     .soglia            scalare   valore soglia applicato               [0..1]
%     .contoCapitale     logico    quale dei due regimi si e' applicato
%     .quotaIncentivata  scalare   E_ACI / E_immessa                     [0..1]
%     .quotaEccedente    scalare   max(0, quotaIncentivata - soglia)     [0..1]
%     .isBinding         logico    la soglia e' superata (eccedenza > 0)
%     .E_ACI, .E_immessa scalari   gli ingressi energetici               [kWh]
%     .methods           [1 x nM]  nomi dei metodi
%     .premioTotale      [nM x 1]  C_ACI per metodo (somma delle quote)  [EUR]
%     .importoEccedente  [nM x 1]  C_ACI,ecc per metodo                  [EUR]
%     .quotaImprese      [nM x 1]  quanto ricevono i membri d'impresa    [EUR]
%     .tettoImprese      [nM x 1]  massimo assegnabile alle imprese      [EUR]
%     .eccessoImprese    [nM x 1]  quotaImprese - tettoImprese, >0 = violazione
%     .conforme          [nM x 1]  logico, true se il vincolo e' rispettato
%     .isImpresa         [n x 1]   logico, classificazione dei membri
%     .table             table     riepilogo per metodo
%
%   Vedi anche: compute_cer_incentive, coalition_excess, MAIN

    if nargin < 6 || isempty(opts), opts = struct(); end

    [n, nM] = size(phiMat);

    % --- Guardie sugli ingressi ---------------------------------------------
    methodNames = string(methodNames(:).');
    if numel(methodNames) ~= nM
        error('premium_excess_threshold:nameSizeMismatch', ...
              'methodNames ha %d elementi, phiMat ha %d colonne.', ...
              numel(methodNames), nM);
    end
    categoria = string(categoria(:));
    if numel(categoria) ~= n
        error('premium_excess_threshold:categorySizeMismatch', ...
              'categoria ha %d elementi, phiMat ha %d righe.', ...
              numel(categoria), n);
    end
    if ~all(isfinite(phiMat), 'all')
        error('premium_excess_threshold:nonFiniteInput', ...
              'Ripartizioni con NaN o Inf: controllare i dati a monte.');
    end
    if ~isscalar(E_ACI) || ~isscalar(E_immessa) || ...
       ~isfinite(E_ACI) || ~isfinite(E_immessa)
        error('premium_excess_threshold:badEnergy', ...
              'E_ACI ed E_immessa devono essere scalari finiti.');
    end
    % Senza energia immessa la quota non e' definita: e' un dato sbagliato a
    % monte, non un caso limite da assorbire con uno zero silenzioso.
    if E_immessa <= 0
        error('premium_excess_threshold:noInjectedEnergy', ...
              ['Energia immessa nulla o negativa (%.3f kWh): la quota di ' ...
               'energia incentivata non e'' definita.'], E_immessa);
    end
    if E_ACI < 0
        error('premium_excess_threshold:negativeIncentivized', ...
              'Energia condivisa incentivabile negativa (%.3f kWh).', E_ACI);
    end
    % L'energia condivisa e' un min() con l'immissione: non puo' superarla. Se
    % succede, i due ingressi vengono da grandezze diverse.
    if E_ACI > E_immessa * (1 + 1e-9)
        error('premium_excess_threshold:sharedAboveInjected', ...
              ['Energia condivisa (%.1f kWh) maggiore dell''energia immessa ' ...
               '(%.1f kWh): i due ingressi non sono coerenti.'], ...
              E_ACI, E_immessa);
    end

    % --- Default -------------------------------------------------------------
    if ~isfield(opts, 'contoCapitale'), opts.contoCapitale = false; end
    if ~isfield(opts, 'quiet'),         opts.quiet         = false; end
    if ~isfield(opts, 'validateSelf'),  opts.validateSelf  = true;  end
    if ~isfield(opts, 'categorieImpresa')
        opts.categorieImpresa = ["terziario", "commerciale", "industriale"];
    end
    if ~isfield(opts, 'playerNames') || isempty(opts.playerNames)
        opts.playerNames = "membro_" + string(1:n);
    end
    opts.playerNames = string(opts.playerNames(:).');

    % Soglia: esplicita se dichiarata, altrimenti dal regime.
    if isfield(opts, 'soglia') && ~isempty(opts.soglia)
        soglia = double(opts.soglia);
        if ~isscalar(soglia) || ~isfinite(soglia) || soglia < 0 || soglia > 1
            error('premium_excess_threshold:badThreshold', ...
                  'opts.soglia deve essere una frazione in [0,1], vale %g.', soglia);
        end
    elseif opts.contoCapitale
        soglia = 0.45;
    else
        soglia = 0.55;
    end

    % --- Chi e' impresa ------------------------------------------------------
    isImpresa = ismember(categoria, string(opts.categorieImpresa));

    % --- Soglia: e' binding? (dipende solo dall'energia) --------------------
    quotaIncentivata = E_ACI / E_immessa;
    quotaEccedente   = max(0, quotaIncentivata - soglia);
    isBinding        = quotaEccedente > 0;

    % --- Verifica per metodo -------------------------------------------------
    % C_ACI si prende PER METODO come somma delle quote, non come costante:
    % quasi tutti i metodi sono efficienti e danno lo stesso v(N), ma il
    % Tri-level EP con cashFund > 0 trattiene una parte del montepremi e la sua
    % colonna somma legittimamente a meno. Il tetto va calcolato sul premio che
    % quel metodo distribuisce davvero.
    premioTotale     = sum(phiMat, 1).';                    % C_ACI  [nM x 1]
    importoEccedente = quotaEccedente * premioTotale;       % C_ACI,ecc
    tettoImprese     = premioTotale - importoEccedente;
    quotaImprese     = sum(phiMat(isImpresa, :), 1).';

    if isfield(opts, 'tol') && ~isempty(opts.tol)
        tol = opts.tol;
    else
        tol = 1e-6 * max(1, max(abs(premioTotale)));
    end

    eccessoImprese = quotaImprese - tettoImprese;
    conforme       = eccessoImprese <= tol;

    % --- Struct di uscita ----------------------------------------------------
    S = struct();
    S.soglia           = soglia;
    S.contoCapitale    = logical(opts.contoCapitale);
    S.quotaIncentivata = quotaIncentivata;
    S.quotaEccedente   = quotaEccedente;
    S.isBinding        = isBinding;
    S.E_ACI            = E_ACI;
    S.E_immessa        = E_immessa;
    S.methods          = methodNames;
    S.players          = opts.playerNames;
    S.isImpresa        = isImpresa;
    S.premioTotale     = premioTotale;
    S.importoEccedente = importoEccedente;
    S.quotaImprese     = quotaImprese;
    S.tettoImprese     = tettoImprese;
    S.eccessoImprese   = eccessoImprese;
    S.conforme         = conforme;
    S.tol              = tol;

    S.table = table(methodNames(:), premioTotale, quotaImprese, tettoImprese, ...
                    eccessoImprese, conforme, ...
                    'VariableNames', {'Metodo', 'PremioTotale_EUR', ...
                                      'QuotaImprese_EUR', 'TettoImprese_EUR', ...
                                      'EccessoImprese_EUR', 'Conforme'});

    if opts.validateSelf
        local_validate_self();
    end

    if opts.quiet, return; end

    % --- Riepilogo -----------------------------------------------------------
    regime = "sola tariffa premio";
    if S.contoCapitale, regime = "cumulo con contributo in conto capitale"; end

    nomiImprese = "nessuno";
    if any(isImpresa)
        nomiImprese = strjoin(opts.playerNames(isImpresa), ', ');
    end

    fprintf('\n=== Soglia di energia incentivabile (DM 414/2023, Allegato 1) ===\n');
    fprintf('  %-34s: %s -> soglia %.0f%%\n', 'Regime', regime, 100*soglia);
    fprintf('  %-34s: %.1f%% (%.0f kWh condivisi su %.0f immessi)\n', ...
            'Quota incentivata E_ACI/E_immessa', 100*quotaIncentivata, ...
            E_ACI, E_immessa);
    fprintf('  %-34s: %d su %d (%s)\n', 'Membri d''impresa', sum(isImpresa), n, ...
            nomiImprese);

    if ~isBinding
        fprintf(['  %-34s: NON BINDING - la quota incentivata sta %.1f punti\n' ...
                 '  %-34s  SOTTO la soglia: l''eccedenza e'' nulla e nessun metodo\n' ...
                 '  %-34s  puo'' violare il vincolo di destinazione.\n'], ...
                'Esito', 100*(soglia - quotaIncentivata), '', '');
        return
    end

    fprintf(['  %-34s: BINDING - %.1f punti sopra la soglia, quindi il %.1f%%\n' ...
             '  %-34s  del premio (fino a EUR %.2f) spetta ai soli consumatori\n' ...
             '  %-34s  diversi dalle imprese.\n'], ...
            'Esito', 100*quotaEccedente, 100*quotaEccedente, ...
            '', max(importoEccedente), '');
    disp(S.table);

    nViol = sum(~conforme);
    if nViol == 0
        fprintf('  Tutti i %d metodi rispettano il tetto sulle quote d''impresa.\n', nM);
    else
        fprintf(['  %d metodi su %d assegnano alle imprese piu'' del consentito:\n' ...
                 '  la differenza va redistribuita ai consumatori diversi dalle\n' ...
                 '  imprese o destinata a finalita'' sociali (par. 2.2.2.1.3).\n'], ...
                nViol, nM);
        for k = find(~conforme).'
            fprintf('    %-30s eccesso EUR %9.2f\n', methodNames(k), eccessoImprese(k));
        end
    end
end


function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test analitico su casi costruiti a penna.
%
%   Il progetto non ha una cartella di test: la convenzione e' quella di
%   fairness_index_bm.m, cioe' l'auto-test dentro il modulo, attivo di default.
%   Qui serve piu' che altrove per UNA ragione: la formula del par. 2.2.2.1.3
%   ha due letture plausibili e solo una e' quella del GSE. Un refuso che
%   scivolasse sull'altra darebbe numeri credibili e sbagliati, e nessun
%   assert a valle se ne accorgerebbe.
%
%   Caso base: 5 membri (3 imprese + 2 domestici), 200 EUR a testa,
%   C_ACI = 1000 EUR, quota imprese = 600 EUR.

    cat = ["terziario"; "commerciale"; "industriale"; "domestico"; "domestico"];
    phi = [200; 200; 200; 200; 200];
    o   = struct('quiet', true, 'validateSelf', false);
    tol = 1e-9;

    % --- 1) Sotto soglia: nessuna eccedenza, tetto = premio intero ----------
    A = premium_excess_threshold(phi, "T", cat, 5000, 10000, o);   % quota 50%
    assert(~A.isBinding && A.quotaEccedente == 0 && ...
           abs(A.tettoImprese - 1000) < tol && A.conforme, ...
           'premium_excess_threshold: caso NON BINDING non riconosciuto');

    % --- 2) Sopra soglia: la LETTURA LETTERALE della formula ----------------
    % quota 60%, soglia 55% -> 5 PUNTI di eccedenza -> C_ecc = 0,05 * 1000 = 50.
    % La lettura proporzionale darebbe (60-55)/60 * 1000 = 83,33: e' quella da
    % cui questo assert protegge.
    B = premium_excess_threshold(phi, "T", cat, 6000, 10000, o);
    assert(B.isBinding && abs(B.quotaEccedente - 0.05) < tol, ...
           'premium_excess_threshold: quota eccedente diversa da 5 punti');
    assert(abs(B.importoEccedente - 50) < tol, ...
           ['premium_excess_threshold: C_ACI,ecc = %.2f invece di 50,00 EUR. ' ...
            'Sembra la lettura PROPORZIONALE (83,33) invece di quella ' ...
            'letterale del par. 2.2.2.1.3.'], B.importoEccedente);
    assert(abs(B.tettoImprese - 950) < tol && B.conforme, ...
           'premium_excess_threshold: tetto imprese diverso da 950 EUR');

    % --- 3) Violazione: imprese oltre il tetto ------------------------------
    C = premium_excess_threshold([400; 400; 200; 0; 0], "T", cat, 6000, 10000, o);
    assert(~C.conforme && abs(C.eccessoImprese - 50) < tol, ...
           'premium_excess_threshold: violazione del tetto non rilevata');

    % --- 4) Il regime sceglie la soglia -------------------------------------
    oc = o; oc.contoCapitale = true;
    D  = premium_excess_threshold(phi, "T", cat, 6000, 10000, oc);
    assert(abs(D.soglia - 0.45) < tol && abs(D.quotaEccedente - 0.15) < tol, ...
           'premium_excess_threshold: conto capitale non porta la soglia al 45%%');

    % --- 5) Domestico e PA non sono imprese ---------------------------------
    E = premium_excess_threshold(phi, "T", ["PA";"domestico";"industriale"; ...
                                            "domestico";"terziario"], ...
                                 6000, 10000, o);
    assert(isequal(E.isImpresa, [false;false;true;false;true]), ...
           'premium_excess_threshold: classificazione impresa/non impresa errata');
end
