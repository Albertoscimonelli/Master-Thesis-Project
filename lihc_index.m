function L = lihc_index(energyExpense, income, nIncomeEarners, opts)
%LIHC_INDEX  Indice di poverta' energetica LIHC (Low Income High Cost) nelle
%   versioni booleana e continua, secondo Campagna, Rancilio, Radaelli, Merlo,
%   "Renewable energy communities and mitigation of energy poverty: Instruments
%   for policymakers and community managers", Sustainable Energy, Grids and
%   Networks 39 (2024) 101471, eq. (12) e (13).
%
%   IDEA
%     Una famiglia e' in poverta' energetica quando due condizioni valgono
%     INSIEME: spende per l'energia piu' della mediana nazionale ("High Cost"),
%     e quel che le resta in tasca al netto di quella spesa, diviso per il
%     numero di percettori di reddito, la porta sotto la soglia di poverta'
%     ("Low Income").
%
%       LIHC_i = I{ [ s_e,i > P50(s_e) ] AND
%                   [ (y_i - s_e,i) / N_inc,i < y* ] }               (eq. 12)
%
%     La versione continua misura la PROFONDITA' della condizione: vale 1
%     quando non c'e' rischio e scende verso 0 quanto piu' la famiglia e'
%     lontana da entrambe le soglie.
%
%       LIHC_cont,i = 1                               se LIHC_i = 0
%                   = min(1; mean{ P50/s_e,i ;
%                                  (y_i - s_e,i)/(N_inc,i * y*) })   (eq. 13)
%
%   DUE DIVERGENZE DAL TESTO PUBBLICATO (scelte deliberate, non sviste)
%     1) L'eq. 12 stampa l'operatore di UNIONE, ma il testo subito sotto dice
%        "the formula returns a value of 1 if the household meets BOTH
%        conditions", e il nome dell'indice - Low Income HIGH Cost - descrive
%        una congiunzione. Con l'unione, per giunta, chiunque spenda piu' della
%        mediana risulterebbe povero e l'indice si svuoterebbe. Qui: AND.
%     2) L'eq. 13 e' pubblicata senza il gate sul booleano. Applicata alla
%        lettera ai dati della Tabella 4 del paper restituisce 0.85 per Old
%        Couple 1, mentre la Tabella 7 riporta 1.00. Con il gate, tutta la
%        colonna "25% users PE" della Tabella 7 si riproduce (verificabile con
%        opts.validatePaper = true). Del resto un indice che "vale 1 quando non
%        c'e' rischio" non puo' che essere posto a 1 per chi non e' a rischio.
%
%   P50 E' UNA COSTANTE NAZIONALE, NON LA MEDIANA DEL CAMPIONE
%     E' l'errore piu' facile da commettere qui, e va detto esplicitamente.
%     Calcolare la mediana sui membri della CER segnalerebbe MECCANICAMENTE
%     meta' della comunita' qualunque cosa spendesse: con tre famiglie ne
%     segnerebbe sempre una o due, indipendentemente dalla loro condizione
%     reale. P50 arriva quindi da fuori (statistica nazionale) e non viene MAI
%     derivata dagli input di questa funzione.
%
%   MEMBRI NON DOMESTICI
%     Un ufficio, un negozio, una scuola non sono famiglie e non possono
%     trovarsi in poverta' energetica: si passano con NaN in uno qualsiasi dei
%     tre input. Restituiscono .isHousehold = false, .boolean = false e
%     .cont = 1, MAI NaN (un NaN si propagherebbe alle chiavi di ripartizione
%     a valle e contaminerebbe le quote di tutti).
%
%   INPUT
%     energyExpense   [n x 1]  spesa energetica annua TOTALE della famiglia,
%                              elettricita' + riscaldamento          [EUR/anno]
%     income          [n x 1]  reddito familiare annuo               [EUR/anno]
%     nIncomeEarners  [n x 1]  numero di percettori di reddito              [-]
%     opts            struct   opzionale, campi tutti facoltativi:
%                       .medianEnergyExpense  P50(s_e), mediana nazionale della
%                                             spesa energetica (def. 1323
%                                             EUR/anno, vedi NOTA sotto)
%                       .povertyThreshold     y*, soglia di poverta'
%                                             (def. 10052 EUR/anno/contribuente,
%                                             il valore dichiarato dal paper)
%                       .validatePaper        riproduce la Tabella 7 del paper
%                                             sui suoi 12 nuclei (def. false)
%
%   NOTA SUL DEFAULT DI P50
%     Il paper non pubblica mai il valore di P50. E' stato ricavato invertendo
%     l'eq. 13 sui due nuclei inequivocabilmente poveri della Tabella 4:
%       Old Couple 3 -> P50 = 1327.6 EUR ;  Old Couple 4 -> P50 = 1318.5 EUR
%     I due valori concordano su ~1323 EUR/anno, ordine di grandezza coerente
%     con l'utente tipo ARERA (elettricita' + gas). Verifica indipendente su un
%     terzo nucleo non usato per la stima: Young Couple 2 restituisce 0.794
%     contro lo 0.79 della Tabella 7.
%
%   OUTPUT (struct L)
%     .boolean            [n x 1] logico, true se in poverta' energetica (eq. 12)
%     .cont               [n x 1] indice continuo in (0,1], 1 = nessun rischio
%     .isHousehold        [n x 1] logico, false per i membri non domestici
%     .netIncomePerEarner [n x 1] (y - s_e)/N_inc                    [EUR/anno]
%     .expenseRatio       [n x 1] s_e/P50,  > 1 = condizione "High Cost"    [-]
%     .incomeRatio        [n x 1] (y-s_e)/(N_inc*y*), < 1 = "Low Income"    [-]
%     .medianEnergyExpense, .povertyThreshold   eco dei parametri usati
%     .table              table   riepilogo per utente

    energyExpense  = energyExpense(:);
    income         = income(:);
    nIncomeEarners = nIncomeEarners(:);
    n = numel(energyExpense);

    if ~isequal(numel(income), n) || ~isequal(numel(nIncomeEarners), n)
        error('lihc_index:sizeMismatch', ...
              ['energyExpense (%d), income (%d) e nIncomeEarners (%d) devono ' ...
               'avere lo stesso numero di elementi.'], ...
              n, numel(income), numel(nIncomeEarners));
    end

    if nargin < 4 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'medianEnergyExpense'), opts.medianEnergyExpense = 1323;  end
    if ~isfield(opts, 'povertyThreshold'),    opts.povertyThreshold    = 10052; end
    if ~isfield(opts, 'validatePaper'),       opts.validatePaper       = false; end

    P50    = opts.medianEnergyExpense;
    yStar  = opts.povertyThreshold;

    if ~isscalar(P50) || ~isfinite(P50) || P50 <= 0
        error('lihc_index:invalidMedian', ...
              ['opts.medianEnergyExpense deve essere uno scalare positivo e ' ...
               'finito (ricevuto %s). E'' una costante NAZIONALE: non va mai ' ...
               'calcolata come mediana del campione, vedi header.'], mat2str(P50));
    end
    if ~isscalar(yStar) || ~isfinite(yStar) || yStar <= 0
        error('lihc_index:invalidThreshold', ...
              'opts.povertyThreshold deve essere uno scalare positivo e finito (ricevuto %s).', ...
              mat2str(yStar));
    end

    % --- Chi e' una famiglia -------------------------------------------------
    % Un dato mancante in uno qualsiasi dei tre input significa "non e' un
    % nucleo domestico". Gli Inf sono invece dati sporchi e vanno segnalati:
    % un NaN e' un'assenza dichiarata, un Inf e' un errore a monte.
    isHousehold = ~isnan(energyExpense) & ~isnan(income) & ~isnan(nIncomeEarners);

    dirty = (isinf(energyExpense) | isinf(income) | isinf(nIncomeEarners));
    if any(dirty)
        error('lihc_index:nonFiniteInput', ...
              ['Valori Inf negli input LIHC (posizioni: %s): usare NaN per ' ...
               'dichiarare un membro NON domestico, mentre un Inf indica dati ' ...
               'sporchi a monte da correggere.'], mat2str(find(dirty).'));
    end
    if any(isHousehold & (energyExpense <= 0 | nIncomeEarners <= 0))
        bad = find(isHousehold & (energyExpense <= 0 | nIncomeEarners <= 0));
        error('lihc_index:invalidHouseholdData', ...
              ['Spesa energetica o numero di percettori non positivi per i ' ...
               'nuclei %s: entrambi compaiono a denominatore nell''eq. 13.'], ...
              mat2str(bad.'));
    end

    % --- Le due condizioni dell'eq. 12 --------------------------------------
    expenseRatio       = nan(n, 1);
    incomeRatio        = nan(n, 1);
    netIncomePerEarner = nan(n, 1);

    hh = isHousehold;
    expenseRatio(hh)       = energyExpense(hh) / P50;
    netIncomePerEarner(hh) = (income(hh) - energyExpense(hh)) ./ nIncomeEarners(hh);
    incomeRatio(hh)        = netIncomePerEarner(hh) / yStar;

    highCost  = false(n, 1);   highCost(hh)  = expenseRatio(hh) > 1;
    lowIncome = false(n, 1);   lowIncome(hh) = incomeRatio(hh)  < 1;

    isEP = highCost & lowIncome;          % eq. 12, con AND (vedi divergenza 1)

    % --- Eq. 13, applicata solo a chi il booleano ha riconosciuto -----------
    cont = ones(n, 1);                    % 1 = nessun rischio (vedi divergenza 2)
    cont(isEP) = min(1, 0.5 * (P50 ./ energyExpense(isEP) + incomeRatio(isEP)));

    L = struct();
    L.boolean            = isEP;
    L.cont               = cont;
    L.isHousehold        = isHousehold;
    L.netIncomePerEarner = netIncomePerEarner;
    L.expenseRatio       = expenseRatio;
    L.incomeRatio        = incomeRatio;
    L.medianEnergyExpense = P50;
    L.povertyThreshold    = yStar;

    L.table = table((1:n).', isHousehold, energyExpense, income, nIncomeEarners, ...
                    netIncomePerEarner, expenseRatio, incomeRatio, isEP, cont, ...
                    'VariableNames', {'Idx', 'Domestico', 'SpesaEnergia_EUR', ...
                                      'Reddito_EUR', 'NPercettori', ...
                                      'RedditoNettoPro_EUR', 'RapportoSpesa', ...
                                      'RapportoReddito', 'LIHC', 'LIHC_cont'});

    if opts.validatePaper
        validate_against_paper(P50, yStar);
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function validate_against_paper(P50, yStar)
%VALIDATE_AGAINST_PAPER  Riproduce la Tabella 7 di Campagna et al. (2024),
%   colonna "25% users PE - before", sui 12 nuclei della loro Tabella 4.
%
%   Verifica l'eq. 13 CON il gate booleano (divergenza 2 dell'header): la
%   classificazione booleana usata come gate e' quella dichiarata dal paper
%   (Old Couple 3, Old Couple 4, Young Couple 2), non quella ricalcolata, in
%   modo da isolare la verifica della formula continua da quella della soglia.
%   Lo scostamento sulla soglia e' poi riportato a parte.

    % Tabella 4 del paper: spesa energetica totale e reddito familiare
    nomi = ["Old1";"Old2";"Old3";"Old4";"Young1";"Young2"; ...
            "Family1";"Family2";"Family3";"Family4";"Family5";"Family6"];
    se   = [2446.86; 2447.18; 2427.93; 2419.87; 2433.04; 2433.46; ...
            3308.97; 3294.82; 3282.15; 3281.97; 4175.47; 4150.99];
    y    = [25934.70; 24755.85; 22398.15; 21219.30; 28636.30; 23429.70; ...
            37685.27; 36543.06; 35401.20; 33117.47; 31975.61; 30833.40];
    nInc = 2 * ones(12, 1);        % il paper usa implicitamente 2 per tutti

    % Tabella 7, colonna "25% users PE - before"
    attesa      = [1.00; 1.00; 0.77; 0.74; 1.00; 0.79; ...
                   1.00; 1.00; 1.00; 1.00; 1.00; 1.00];
    epDelPaper  = logical([0;0;1;1;0;1; 0;0;0;0;0;0]);   % Old3, Old4, Young2

    netPro   = (y - se) ./ nInc;
    ottenuta = ones(12, 1);
    ottenuta(epDelPaper) = min(1, 0.5 * (P50 ./ se(epDelPaper) + netPro(epDelPaper) / yStar));

    scarto = abs(ottenuta - attesa);
    tol    = 0.01;                 % il paper riporta due decimali

    fprintf('\n=== lihc_index: verifica sulla Tabella 7 di Campagna et al. (2024) ===\n');
    disp(table(nomi, se, y, netPro, epDelPaper, attesa, ottenuta, scarto, ...
               'VariableNames', {'Nucleo', 'SpesaEnergia_EUR', 'Reddito_EUR', ...
                                 'RedditoNettoPro_EUR', 'EP_nelPaper', ...
                                 'Tab7_attesa', 'Calcolata', 'Scarto'}));
    fprintf('  %-32s: P50 = %.0f EUR/anno, y* = %.0f EUR/anno\n', ...
            'Parametri usati', P50, yStar);

    if max(scarto) > tol
        error('lihc_index:paperMismatch', ...
              ['L''eq. 13 non riproduce la Tabella 7 (scarto massimo %.3f > %.2f ' ...
               'sul nucleo %s). Controllare opts.medianEnergyExpense (P50) e ' ...
               'opts.povertyThreshold (y*): i valori che riproducono la tabella ' ...
               'sono 1323 e 10052.'], ...
              max(scarto), tol, nomi(find(scarto == max(scarto), 1)));
    end
    fprintf('  %-32s: scarto massimo %.4f (entro %.2f)\n', ...
            'Eq. 13 + gate booleano', max(scarto), tol);

    % --- Lo scostamento sulla soglia, riportato e non nascosto --------------
    % Con la y* DICHIARATA dal paper (10052), l'eq. 12 riconosce 2 dei 3 nuclei
    % che il paper stesso elenca come vulnerabili: Young Couple 2 ha 10498.12
    % EUR/anno di reddito netto per percettore, appena SOPRA la soglia. Non e'
    % un errore di implementazione: l'unica soglia compatibile con tutte e 12
    % le famiglie sta fra 10498.12 e 11154.34 EUR/anno.
    epRicalcolato = (se > P50) & (netPro < yStar);
    diverso = epRicalcolato ~= epDelPaper;
    if any(diverso)
        candidati = sort(netPro);
        fprintf('  %-32s: %s, con y* = %.0f\n', 'Scostamento sull''eq. 12', ...
                strjoin(cellstr(nomi(diverso)), ', '), yStar);
        fprintf('  %-32s: y* fra %.2f e %.2f riprodurrebbe la classificazione\n', ...
                'Intervallo compatibile', candidati(3), candidati(4));
        fprintf('  %-32s  del paper (vedi IPOTESI 5 in tri_level_ep_cer.m)\n', '');
    else
        fprintf('  %-32s: classificazione identica a quella del paper\n', ...
                sprintf('Eq. 12 con y* = %.0f', yStar));
    end
end
