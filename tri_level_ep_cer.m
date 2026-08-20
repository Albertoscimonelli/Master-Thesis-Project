function S = tri_level_ep_cer(genUsers, loadUsers, userNames, P_CER, opts)
%TRI_LEVEL_EP_CER  Ripartizione tri-livello "Ownership-based + Proportional +
%   Energy Poverty" di Campagna, Rancilio, Radaelli, Merlo, "Renewable energy
%   communities and mitigation of energy poverty: Instruments for policymakers
%   and community managers", Sustainable Energy, Grids and Networks 39 (2024)
%   101471 (eq. 11-15, Fig. 7-8, tetto di §4.3).
%
%   ============================================================================
%   *** IMPLEMENTAZIONE PROVVISORIA ***
%   Questo metodo gira su DATI SEGNAPOSTO. Undici ipotesi sono attive per
%   difetto: sono elencate nel REGISTRO qui sotto, marcate nel codice con il tag
%   [IPOTESI n] e stampate a ogni esecuzione (solo quelle ancora in vigore).
%
%       grep -n "IPOTESI" tri_level_ep_cer.m      elenco completo nel codice
%       help tri_level_ep_cer                     il registro qui sotto
%       S.assumptions                             la tabella, a programma
%
%   I numeri prodotti oggi NON sono risultati: dipendono dai segnaposto.
%   ============================================================================
%
%   IDEA
%     Il gestore della CER ha in mano due flussi di ricavo distinti, e il metodo
%     fa corrispondere ogni livello alla propria fonte.
%
%     Il ricavo da ENERGIA CONDIVISA (R_sh) nasce dal fatto che qualcuno
%     consumava nella stessa ora in cui qualcun altro immetteva: e' merito dei
%     consumatori, e si ripartisce con il criterio PROPORZIONALE (eq. 11).
%     Il ricavo da VENDITA in rete (R_inj) nasce da energia che nessuno nella
%     comunita' ha consumato: e' merito di chi ha pagato l'impianto, e si
%     ripartisce con il criterio OWNERSHIP. I pesi dei due livelli non sono
%     scelti a mano - sono il rapporto fra i due ricavi, il che elimina
%     l'arbitrio (Fig. 7 del paper).
%
%     Sopra a tutto questo, il tri-livello preleva una fetta di solidarieta':
%     share_EP del montepremi totale va ai soli membri in poverta' energetica,
%     accertata con l'indice LIHC (vedi lihc_index.m).
%
%       share_EP   = min(33% ; n% * N_vu)      n% = 1.32%      (eq. 14)
%       share_rest = 1 - share_EP                              (eq. 15)
%
%       R_tot = R_sh + R_inj
%       phi_i = share_EP   * R_tot * epKey_i
%             + share_rest * ( R_sh * propKey_i + R_inj * ownKey_i )
%
%     La somma si chiude per costruzione:
%       share_EP*R_tot + share_rest*(R_sh + R_inj) = R_tot.
%
%   INVARIANTE DI EFFICIENZA (leggere prima di confrontare con gli altri metodi)
%     A differenza degli altri quindici modelli del progetto, questo ripartisce
%     ENTRAMBI i montepremi, perche' il livello Owners redistribuisce proprio il
%     ricavo di vendita. Quindi S.vGrand = R_sh + R_inj, non v(N). Stessa
%     situazione, e stessa scelta dichiarata, di cascading_tree_cer.m.
%     Per restare confrontabili si espongono .phiFromShared (somma esattamente a
%     v(N) = R_sh) e .phiFromSold (somma a R_inj): e' .phiFromShared che va
%     messo in Tcmp e nel grafico di confronto di MAIN.m, non .phi, altrimenti
%     la vendita verrebbe contata due volte nella barra impilata.
%     Con opts.billCap = true l'invariante cambia ancora: vGrand = R_tot -
%     cashFund, e .phiFromShared non somma piu' a v(N) (vedi IPOTESI 3).
%
%   TEST DI DEGENERAZIONE (il piu' informativo)
%     Con opts.nPct = 0 la formula collassa in R_sh*propKey + R_inj*ownKey, cioe'
%     ESATTAMENTE lo stato attuale del progetto: ripartizione proporzionale al
%     consumo del montepremi condiviso, piu' la vendita attribuita pro-quota ai
%     proprietari. In quel caso .phiFromSold deve coincidere con revSoldPerPlayer
%     calcolato in MAIN.m §3. E' l'assert incrociato della §3r.
%
%   COSA ASPETTARSI SU QUESTA TOPOLOGIA (leggere prima di usare i numeri)
%     1) Il livello Owners NON discrimina. Un solo impianto, un solo
%        proprietario: ownKey e' un vettore indicatore e tutto R_inj va a
%        small_industry_1, esattamente come gia' accade oggi. Il livello
%        acquista significato solo con piu' impianti o quote di cofinanziamento.
%     2) share_EP sara' piccola: con al piu' tre famiglie vulnerabili arriva a
%        3*1.32% = 3.96%, molto sotto il tetto del 33%, che si attiverebbe solo
%        da venticinque vulnerabili in su.
%     3) A Teglio share_EP valeva ~1042 EUR su ~26300 EUR di montepremi, cioe'
%        ~347 EUR a testa, che coprivano circa il 100% di una bolletta elettrica
%        domestica: il paper ha scelto il 2% PERCHE' accadesse questo. Il nostro
%        montepremi e' molto piu' piccolo, quindi la stessa percentuale coprira'
%        una frazione diversa della bolletta. Se il rapporto si discosta molto,
%        la conclusione non e' "il metodo non funziona" ma "n% va ritarato sulla
%        nostra scala" (vedi IPOTESI 11).
%     4) Senza componente gas il livello EP si SPEGNE: la spesa di sola
%        elettricita' non supera mai P50, nessuno risulta "High Cost", N_vu = 0
%        e il tri-livello coincide col bi-livello. Comportamento corretto, da
%        non scambiare per un bug (vedi IPOTESI 2).
%
%   DIFFERENZA DI GOVERNANCE RISPETTO AL PAPER (non e' un parametro)
%     A Teglio gli impianti sono del Comune, su edifici pubblici, in una CER
%     dichiaratamente sociale: chiedergli di cedere il 3.96% del montepremi ai
%     vulnerabili e' coerente col suo mandato. Qui lo stesso livello preleva da
%     una piccola industria PRIVATA, e il prelievo di solidarieta' diventa una
%     richiesta di natura completamente diversa. Il codice lo implementa
%     comunque, ma il risultato numerico presuppone un accordo che nel nostro
%     caso non esiste.
%
%   ============================================================================
%   REGISTRO DELLE IPOTESI (11 voci, in ordine di peso sul risultato)
%   ============================================================================
%    1. REDDITO delle famiglie: segnaposto dalla Tabella 4 del paper (Teglio).
%       Non esiste alcun dato di reddito nel progetto, ed e' la variabile che
%       DECIDE chi e' vulnerabile: nella Tabella 4 le spese energetiche dei
%       quattro Old Couple sono quasi identiche, e' solo il reddito a separare i
%       poveri dai non poveri. Si rimuove con: open data MEF sulle dichiarazioni
%       dei redditi del comune della CER, incrociati con le classi d'eta' ISTAT
%       (la stessa procedura del paper). Override: opts.income.
%    2. SPESA GAS: 15000 kWh/anno per famiglia, dal house_type HT06 dichiarato
%       in CER_LoadProfiles/config/simulation_config.yaml, valorizzati a un
%       prezzo gas dichiarato. Il paper stesso non misurava il gas ("gas
%       consumption is typical for mountain areas"), quindi dichiararlo da
%       statistica NON e' un peggioramento: e' il suo stesso metodo. Serve
%       perche' l'eq. 12 richiede la spesa energetica TOTALE. Si rimuove con:
%       bollette gas reali. Override: opts.gasExpense (0 = solo elettrico, ma
%       allora va ricalibrata anche P50, vedi IPOTESI 4).
%    3. MARKUP RETAIL: i prezzi del progetto sono PUN all'INGROSSO (~0.116
%       EUR/kWh), non prezzi finali di bolletta (0.25-0.35 EUR/kWh con oneri,
%       dispacciamento e imposte). Senza correzione la spesa elettrica sarebbe
%       sottostimata di un fattore ~3 e nessuno risulterebbe mai "High Cost";
%       lo stesso prezzo serve al tetto del 100%, che altrimenti scatterebbe con
%       il triplo dell'anticipo. Il markup moltiplicativo costante e' una
%       semplificazione grossolana - il markup reale non e' ne' moltiplicativo
%       ne' costante - ma sta in UN SOLO punto ed e' sostituibile. Si rimuove
%       con: tariffa di fornitura reale. Override: opts.retailMarkup.
%    4. P50 = 1323 EUR/anno, mediana nazionale della spesa energetica. Il paper
%       non la pubblica: ricavata invertendo l'eq. 13 su Old Couple 3 e 4 e
%       verificata su Young Couple 2 (vedi lihc_index.m). Si rimuove con: la
%       mediana ARERA/ISTAT dell'annata pertinente. Override:
%       opts.medianEnergyExpense.
%    5. y* = 10052 EUR/anno/contribuente, il valore DICHIARATO dal paper. Con
%       quel valore pero' l'eq. 12 riconosce 2 dei 3 nuclei che il paper stesso
%       elenca come vulnerabili: Young Couple 2 sta appena sopra la soglia
%       (10498.12 EUR). L'unica soglia compatibile con tutte e 12 le famiglie
%       sta fra 10498.12 e 11154.34. Il default resta il valore dichiarato, per
%       non truccare una costante in silenzio. Si rimuove con: chiarimento dagli
%       autori, o annata Eurostat corretta. Override: opts.povertyThreshold.
%    6. AND al posto dell'UNIONE nell'eq. 12. Il testo del paper e il nome
%       stesso dell'indice dicono congiunzione. Correzione, non ipotesi.
%       Dettagli e motivazione in lihc_index.m.
%    7. GATE BOOLEANO sull'eq. 13: senza, la Tabella 7 del paper non si
%       riproduce. Correzione, non ipotesi. Dettagli in lihc_index.m.
%    8. OWNERSHIP = quota di PRODUZIONE, non di denaro investito. Il progetto
%       non ha dati di investimento e ha un solo impianto, quindi il livello e'
%       degenere. Si rimuove con: una tabella delle quote di cofinanziamento.
%       Override: opts.ownershipShare.
%    9. CARICO RESIDUO (loadForShare) come Ec dell'eq. 11, non il carico lordo.
%       Scelta di modellazione, non ipotesi: i "prelievi" della definizione di
%       energia condivisa sono energia presa dalla RETE, l'autoconsumo dietro
%       contatore non e' condivisibile (e il paper stesso lo esclude), e v(N) e'
%       gia' calcolato sul residuo - col lordo le quote non corrisponderebbero
%       al piatto da dividere. Tocca UN SOLO membro, small_industry_1, l'unico
%       con impianto; per le tre famiglie lordo e residuo coincidono. Si
%       commuta passando loadUsers al posto di loadForShare dal chiamante.
%   10. N_inc = 2 percettori di reddito per tutti e tre i nuclei. Sta al
%       denominatore dell'eq. 12 e converte il reddito familiare in reddito per
%       contribuente: e' un divisore, quindi scala direttamente chi cade sotto
%       la soglia. Scritto nell'etichetta degli archetipi CHR02 ("with work") e
%       CHR03 ("both at work"); ASSUNTO per la coppia di pensionati CHR54, dove
%       N_inc = 1 raddoppierebbe il reddito per percettore e la farebbe uscire
%       dalla vulnerabilita' - proprio l'archetipo con la maggiore probabilita'
%       a priori di essere povero. A favore: il paper adotta implicitamente 2
%       per tutti e dodici i suoi nuclei. Si rimuove con: anagrafica reale
%       (quanti PERCEPISCONO reddito, non quanti sono). Override:
%       opts.nIncomeEarners.
%   11. n% = 1.32% e tetto 33% trasportati invariati dal paper, dove sono
%       "arbitrarily set as the outcome of a fine-tuning process" su una CER di
%       SEDICI membri. Non sono costanti universali. Si rimuove con: ritaratura
%       sulla nostra scala (vedi COSA ASPETTARSI, punto 3). Override:
%       opts.nPct, opts.capEP.
%   ============================================================================
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente          [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente     [kWh/h]
%     userNames [1 x n]   nomi degli utenti                          (string)
%     P_CER     scalare o [H x 1]  incentivo su energia condivisa  [EUR/kWh]
%     opts      struct    opzionale, campi tutti facoltativi:
%                 .revSold          ricavo annuo da vendita in rete [EUR]
%                                   (def. 0 -> degrada al bi-livello Prop+EP)
%                 .income           [n x 1] reddito familiare, NaN se non
%                                   domestico          [IPOTESI 1 se assente]
%                 .gasExpense       [n x 1] spesa gas  [IPOTESI 2 se assente]
%                 .energyExpense    [n x 1] spesa energetica totale gia' nota:
%                                   scavalca elettrico + gas   [IPOTESI 2 e 3]
%                 .nIncomeEarners   [n x 1]           [IPOTESI 10 se assente]
%                 .isHousehold      [n x 1] logico, chi e' un nucleo domestico
%                                   (def. nomi che iniziano per "household")
%                 .lihcCont         [n x 1] LIHC gia' calcolato, scavalca tutto
%                 .medianEnergyExpense  P50    (def. 1323)     [IPOTESI 4]
%                 .povertyThreshold     y*     (def. 10052)    [IPOTESI 5]
%                 .nPct                 n%     (def. 0.0132)   [IPOTESI 11]
%                 .capEP                tetto  (def. 0.33)     [IPOTESI 11]
%                 .useContinuous    pesa n% sulla PROFONDITA' della poverta'
%                                   usando LIHC_cont (def. false): e' il
%                                   miglioramento che il paper suggerisce ma
%                                   non implementa
%                 .ownershipShare   [n x 1] quote di investimento, somma 1
%                                                     (def. da genUsers) [IPOTESI 8]
%                 .retailMarkup     PUN -> prezzo finale (def. 2.5) [IPOTESI 3]
%                 .gasPrice         prezzo gas [EUR/kWh] (def. 0.12) [IPOTESI 2]
%                 .gasHeatingKWh    riscaldamento annuo [kWh] (def. 15000) [IPOTESI 2]
%                 .tariffMode       "MONORARIA"|"BIORARIA"|"ORARIO_VARIABILE"
%                                   (def. "MONORARIA")
%                 .billCap          applica il tetto di §4.3 (def. false)
%                 .mortgagePerUser  [n x 1] rate di investimento    [EUR/anno]
%                 .quiet            silenzia l'avviso sulle ipotesi (def. false)
%
%   OUTPUT (struct S)
%     .players        [1 x n]  nomi dei giocatori (= userNames)
%     .phi            [n x 1]  ripartizione TOTALE, entrambi i montepremi [EUR]
%     .vGrand         scalare  R_sh + R_inj - cashFund                    [EUR]
%     .isProsumer     [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare      scalare  quota totale ai prosumer                   [EUR]
%     .consShare      scalare  quota totale ai consumatori puri           [EUR]
%     .phiFromShared  [n x 1]  parte finanziata dal montepremi condiviso  [EUR]
%     .phiFromSold    [n x 1]  parte finanziata dalla vendita             [EUR]
%     .revShared      scalare  R_sh = v(N)                                [EUR]
%     .revSold        scalare  R_inj                                      [EUR]
%     .shareEP        scalare  frazione prelevata per la poverta' energetica
%     .shareRest      scalare  1 - shareEP
%     .nVulnerable    scalare  numero di membri in poverta' energetica
%     .isVulnerable   [n x 1]  logico
%     .lihcBool       [n x 1]  logico, indice LIHC booleano (eq. 12)
%     .lihcCont       [n x 1]  indice LIHC continuo (eq. 13)
%     .epKey/.propKey/.ownKey  [n x 1] chiavi dei tre livelli, ciascuna somma 1
%     .cashFund       scalare  residuo non distribuito per il tetto       [EUR]
%     .assumptions    table    registro delle ipotesi ancora ATTIVE
%     .table          table    riepilogo per utente

    H = size(loadUsers, 1);
    n = size(loadUsers, 2);
    players = string(userNames(:).');

    if ~isequal(size(genUsers), size(loadUsers))
        error('tri_level_ep_cer:sizeMismatch', ...
              'genUsers [%s] e loadUsers [%s] devono avere la stessa forma.', ...
              num2str(size(genUsers)), num2str(size(loadUsers)));
    end

    if nargin < 5 || isempty(opts), opts = struct(); end

    % Cosa ha fornito DAVVERO il chiamante, fotografato prima di applicare i
    % default: e' l'unico modo per distinguere un valore vero da un segnaposto.
    % Dopo il blocco qui sotto, isfield() risponderebbe true a tutto.
    fornito = struct();
    campiTracciati = {'revSold', 'nPct', 'capEP', 'medianEnergyExpense', ...
                      'povertyThreshold', 'retailMarkup', 'gasPrice', ...
                      'gasHeatingKWh', 'income', 'gasExpense', 'energyExpense', ...
                      'nIncomeEarners', 'lihcCont', 'ownershipShare'};
    for k = 1:numel(campiTracciati)
        fornito.(campiTracciati{k}) = isfield(opts, campiTracciati{k});
    end

    % --- Default dei parametri ----------------------------------------------
    if ~isfield(opts, 'revSold'),             opts.revSold             = 0;             end
    if ~isfield(opts, 'nPct'),                opts.nPct                = 0.0132;        end  % [IPOTESI 11]
    if ~isfield(opts, 'capEP'),               opts.capEP               = 0.33;          end  % [IPOTESI 11]
    if ~isfield(opts, 'medianEnergyExpense'), opts.medianEnergyExpense = 1323;          end  % [IPOTESI 4]
    if ~isfield(opts, 'povertyThreshold'),    opts.povertyThreshold    = 10052;         end  % [IPOTESI 5]
    if ~isfield(opts, 'retailMarkup'),        opts.retailMarkup        = 2.5;           end  % [IPOTESI 3]
    if ~isfield(opts, 'gasPrice'),            opts.gasPrice            = 0.12;          end  % [IPOTESI 2]
    if ~isfield(opts, 'gasHeatingKWh'),       opts.gasHeatingKWh       = 15000;         end  % [IPOTESI 2]
    if ~isfield(opts, 'tariffMode'),          opts.tariffMode          = "MONORARIA";   end
    if ~isfield(opts, 'useContinuous'),       opts.useContinuous       = false;         end
    if ~isfield(opts, 'billCap'),             opts.billCap             = false;         end
    if ~isfield(opts, 'mortgagePerUser'),     opts.mortgagePerUser     = zeros(n, 1);   end
    if ~isfield(opts, 'quiet'),               opts.quiet               = false;         end

    if ~isscalar(opts.nPct) || opts.nPct < 0 || opts.nPct > 1
        error('tri_level_ep_cer:invalidNPct', ...
              'opts.nPct deve essere uno scalare in [0,1] (ricevuto %s).', mat2str(opts.nPct));
    end
    if ~isscalar(opts.capEP) || opts.capEP < 0 || opts.capEP > 1
        error('tri_level_ep_cer:invalidCap', ...
              'opts.capEP deve essere uno scalare in [0,1] (ricevuto %s).', mat2str(opts.capEP));
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    % --- Guard clause: dati sporchi a monte ---------------------------------
    % Senza questo controllo un NaN nei profili si propagherebbe fino alle
    % verifiche finali, che lo segnalerebbero come violazione dell'efficienza:
    % una diagnosi fuorviante rispetto alla causa vera.
    if ~all(isfinite(genUsers), 'all') || ~all(isfinite(loadUsers), 'all') ...
            || ~all(isfinite(P_CER))
        error('tri_level_ep_cer:nonFiniteInput', ...
              ['Ingressi con NaN o Inf (produzione: %d, carichi: %d, incentivo: ' ...
               '%d valori non finiti): controllare i profili a monte.'], ...
              sum(~isfinite(genUsers), 'all'), sum(~isfinite(loadUsers), 'all'), ...
              sum(~isfinite(P_CER)));
    end
    if ~isscalar(opts.revSold) || ~isfinite(opts.revSold) || opts.revSold < 0
        error('tri_level_ep_cer:invalidRevSold', ...
              'opts.revSold deve essere uno scalare finito non negativo (ricevuto %s).', ...
              mat2str(opts.revSold));
    end

    % --- Montepremi ---------------------------------------------------------
    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    revHour  = min(genComm, loadComm) .* P_CER;    % [H x 1]
    R_sh     = sum(revHour);                        % = v(N)
    R_inj    = opts.revSold;
    R_tot    = R_sh + R_inj;

    % Registro delle ipotesi: parte vuoto e si riempie solo con quelle
    % effettivamente rimaste attive (vedi local_note).
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});

    % --- Chi e' un nucleo domestico -----------------------------------------
    if isfield(opts, 'isHousehold')
        isHousehold = logical(opts.isHousehold(:));
    else
        isHousehold = startsWith(lower(players(:)), "household");
    end

    % --- [IPOTESI 3] Prezzo finale dell'energia elettrica -------------------
    % Il progetto prezza al PUN all'ingrosso. La spesa che entra nel LIHC, e la
    % bolletta su cui si misura il tetto del 100%, sono invece grandezze di
    % BOLLETTA: senza markup la spesa elettrica e' sottostimata di ~3x e la
    % condizione "High Cost" non scatterebbe mai per nessuno.
    TTprice = profilo_prezzi_pun_2025(opts.tariffMode);
    price   = TTprice.Prezzo(:);
    if numel(price) ~= H
        error('tri_level_ep_cer:priceGridMismatch', ...
              'Il profilo prezzi PUN ha %d ore, loadUsers ne ha %d.', numel(price), H);
    end
    elecExpense = (price.' * loadUsers).' * opts.retailMarkup;      % [n x 1] EUR/anno

    if ~fornito.retailMarkup
        reg = local_note(reg, 3, 'Markup retail dal PUN al prezzo finale', ...
                         sprintf('%.2f x PUN (%s)', opts.retailMarkup, opts.tariffMode), ...
                         'tariffa di fornitura reale al posto del profilo PUN');
    end

    % --- [IPOTESI 2] Spesa per il riscaldamento a gas -----------------------
    % Il perimetro dell'eq. 12 e' la spesa energetica TOTALE. Con la sola
    % elettricita' nessuna famiglia supera P50 e il livello EP si spegne.
    % 15000 kWh/anno e' il house_type HT06 gia' dichiarato nella simulazione
    % pyLPG (simulation_config.yaml); per confronto, i nuclei di Teglio usavano
    % 1481 m3 ~ 15850 kWh. Il paper stesso non misurava il gas.
    if fornito.gasExpense
        gasExpense = opts.gasExpense(:);
    else
        gasExpense = zeros(n, 1);
        gasExpense(isHousehold) = opts.gasHeatingKWh * opts.gasPrice;
        if ~fornito.energyExpense && any(isHousehold)
            reg = local_note(reg, 2, 'Spesa gas da statistica (house_type HT06)', ...
                             sprintf('%.0f kWh/anno x %.3f EUR/kWh = %.0f EUR', ...
                                     opts.gasHeatingKWh, opts.gasPrice, ...
                                     opts.gasHeatingKWh * opts.gasPrice), ...
                             'bollette gas reali dei membri');
        end
    end

    % --- Spesa energetica totale --------------------------------------------
    if fornito.energyExpense
        energyExpense = opts.energyExpense(:);
    else
        energyExpense = elecExpense + gasExpense;
    end
    energyExpense(~isHousehold) = NaN;      % i non domestici non hanno LIHC

    % --- [IPOTESI 1] Reddito familiare --------------------------------------
    % Segnaposto dalla Tabella 4 del paper. E' la variabile che DECIDE chi e'
    % vulnerabile: nella Tabella 4 le spese dei quattro Old Couple sono quasi
    % identiche, e' solo il reddito a separarli. Mappatura sugli archetipi
    % dichiarati in CER_LoadProfiles/config/simulation_config.yaml, nell'ordine
    % in cui lpg_runner.py numera le colonne household_N:
    %   household_1 = CHR54 Retired Couple    -> Old Couple 3   (22398.15 EUR)
    %   household_2 = CHR02 Couple with work  -> Young Couple 2 (23429.70 EUR)
    %   household_3 = CHR03 Family, 1 child   -> Family 1       (37685.27 EUR)
    if fornito.income
        income = opts.income(:);
    else
        income = local_placeholder_income(players, isHousehold);
        if any(isHousehold)
            reg = local_note(reg, 1, 'Reddito familiare (segnaposto Tab. 4 del paper)', ...
                             strjoin(compose('%s=%.0f', players(isHousehold).', ...
                                             income(isHousehold)), ', '), ...
                             'open data MEF sui redditi del comune x classi d''eta'' ISTAT');
        end
    end

    % --- [IPOTESI 10] Numero di percettori di reddito -----------------------
    if fornito.nIncomeEarners
        nIncomeEarners = opts.nIncomeEarners(:);
    else
        nIncomeEarners = NaN(n, 1);
        nIncomeEarners(isHousehold) = 2;
        if any(isHousehold)
            reg = local_note(reg, 10, 'Numero di percettori di reddito', ...
                             '2 per ogni nucleo (CHR54 assunto con due pensioni)', ...
                             'anagrafica reale: quanti PERCEPISCONO reddito, non quanti sono');
        end
    end

    income(~isHousehold)         = NaN;
    nIncomeEarners(~isHousehold) = NaN;

    % --- Indice LIHC ---------------------------------------------------------
    if fornito.lihcCont
        lihcCont = opts.lihcCont(:);
        lihcBool = lihcCont < 1;
    else
        L = lihc_index(energyExpense, income, nIncomeEarners, ...
                       struct('medianEnergyExpense', opts.medianEnergyExpense, ...
                              'povertyThreshold',    opts.povertyThreshold));
        lihcBool = L.boolean;
        lihcCont = L.cont;

        if ~fornito.medianEnergyExpense
            reg = local_note(reg, 4, 'P50, mediana nazionale della spesa energetica', ...
                             sprintf('%.0f EUR/anno (ricavata invertendo l''eq. 13)', ...
                                     opts.medianEnergyExpense), ...
                             'mediana ARERA/ISTAT dell''annata pertinente');
        end
        if ~fornito.povertyThreshold
            reg = local_note(reg, 5, 'y*, soglia di poverta''', ...
                             sprintf(['%.0f EUR/anno (valore dichiarato; la Tab. 7 ' ...
                                      'del paper richiede ~11000)'], opts.povertyThreshold), ...
                             'chiarimento dagli autori, o annata Eurostat corretta');
        end
    end

    % Le due correzioni al testo pubblicato valgono sempre: sono nel modello,
    % non nei dati, e non si disattivano passando dati veri.
    reg = local_note(reg, 6, 'Eq. 12 con AND al posto dell''unione stampata', ...
                     'congiunzione (vedi lihc_index.m)', ...
                     'correzione al paper, non ipotesi: nessuna rimozione prevista');
    reg = local_note(reg, 7, 'Eq. 13 con gate sul booleano', ...
                     'LIHC_cont = 1 per chi non e'' a rischio', ...
                     'correzione al paper, non ipotesi: nessuna rimozione prevista');

    isVulnerable = lihcBool & isHousehold;
    nVu          = sum(isVulnerable);

    % --- Eq. 14-15: la fetta di solidarieta' --------------------------------
    shareEP   = min(opts.capEP, opts.nPct * nVu);
    shareRest = 1 - shareEP;

    if ~fornito.nPct || ~fornito.capEP
        reg = local_note(reg, 11, 'n% e tetto della quota di poverta'' energetica', ...
                         sprintf('n%% = %.2f%%, tetto %.0f%% (tarati su una CER di 16 membri)', ...
                                 100*opts.nPct, 100*opts.capEP), ...
                         'ritaratura sulla scala della nostra comunita''');
    end

    % --- Livello 1: chiave di poverta' energetica ---------------------------
    epKey = zeros(n, 1);
    if nVu > 0
        if opts.useContinuous
            % Miglioramento suggerito dal paper ma non implementato: pesare n%
            % sulla PROFONDITA' della poverta' invece che equiripartire.
            depth = zeros(n, 1);
            depth(isVulnerable) = 1 - lihcCont(isVulnerable);
            if sum(depth) > 0
                epKey = depth / sum(depth);
            else
                epKey = double(isVulnerable) / nVu;   % tutti esattamente a 1
            end
        else
            epKey = double(isVulnerable) / nVu;
        end
    end

    % --- Livello 2: chiave proporzionale al consumo (eq. 11) ----------------
    % Ora per ora, ogni membro prende una fetta del ricavo di quell'ora pari
    % alla sua frazione del carico di comunita'. Nelle ore a carico nullo il
    % ricavo e' nullo per costruzione (min(gen,0) = 0): si maschera invece di
    % aggiungere eps al denominatore, cosi' non si introduce un bias.
    wHour = zeros(H, n);
    hasLoad = loadComm > 0;
    wHour(hasLoad, :) = loadUsers(hasLoad, :) ./ loadComm(hasLoad);
    propEUR = (revHour.' * wHour).';                  % [n x 1] EUR
    if R_sh > 0
        propKey = propEUR / R_sh;
    else
        propKey = zeros(n, 1);
    end

    % --- Livello 3: chiave di proprieta' [IPOTESI 8] ------------------------
    genTot = sum(genUsers, 'all');
    if fornito.ownershipShare
        ownKey = opts.ownershipShare(:);
        if abs(sum(ownKey) - 1) > 1e-9
            error('tri_level_ep_cer:ownershipNotNormalized', ...
                  'opts.ownershipShare deve sommare a 1 (somma ricevuta: %.6f).', sum(ownKey));
        end
    elseif genTot > 0
        ownKey = sum(genUsers, 1).' / genTot;
        reg = local_note(reg, 8, 'Quote di proprieta'' derivate dalla produzione', ...
                         sprintf('%s (nessun dato di investimento nel progetto)', ...
                                 strjoin(compose('%s=%.0f%%', players(ownKey > 0).', ...
                                                 100*ownKey(ownKey > 0)), ', ')), ...
                         'tabella delle quote di cofinanziamento in EUR investiti');
    else
        ownKey = zeros(n, 1);
    end

    if R_inj > 0 && sum(ownKey) <= 0
        error('tri_level_ep_cer:ownershipUndefined', ...
              ['Ricavo da vendita pari a %.2f EUR ma nessuna quota di proprieta'' ' ...
               'definita: non si puo'' ripartire un ricavo di vendita senza sapere ' ...
               'chi ha investito. Passare opts.ownershipShare, oppure opts.revSold = 0.'], ...
              R_inj);
    end

    % La scelta del carico residuo tocca solo chi ha un impianto, ma e' proprio
    % il membro il cui trattamento pesa di piu': va dichiarata sempre.
    if any(genUsers > 0, 'all')
        reg = local_note(reg, 9, 'Carico RESIDUO come Ec dell''eq. 11', ...
                         'loadForShare, al netto dell''autoconsumo del proprietario', ...
                         'scelta di modellazione: passare loadUsers per il carico lordo');
    end

    % --- Composizione dei tre livelli ---------------------------------------
    phiFromShared = shareEP * R_sh  * epKey + shareRest * R_sh  * propKey;
    phiFromSold   = shareEP * R_inj * epKey + shareRest * R_inj * ownKey;
    phi           = phiFromShared + phiFromSold;

    % --- Tetto del 100% della bolletta (paper §4.3) -------------------------
    cashFund = 0;
    billPerUser = elecExpense;
    if opts.billCap
        cap    = billPerUser + opts.mortgagePerUser(:);
        excess = max(0, phi - cap);
        cashFund = sum(excess);

        % La riduzione si scarica pro-quota sui due montepremi, cosi' la
        % decomposizione .phiFromShared/.phiFromSold resta coerente con .phi.
        keep = ones(n, 1);
        nz = phi > 0;
        keep(nz) = (phi(nz) - excess(nz)) ./ phi(nz);
        phiFromShared = phiFromShared .* keep;
        phiFromSold   = phiFromSold   .* keep;
        phi           = phiFromShared + phiFromSold;
    end

    vGrand = R_tot - cashFund;

    % --- Verifiche di coerenza ----------------------------------------------
    tolChk = 1e-6 * max(1, abs(R_tot));
    assert(abs(sum(phi) - vGrand) <= tolChk, ...
           'tri_level_ep_cer: la somma delle quote non coincide con vGrand');
    if ~opts.billCap
        assert(abs(sum(phiFromShared) - R_sh) <= tolChk, ...
               ['tri_level_ep_cer: la parte finanziata dal montepremi condiviso ' ...
                'non somma a v(N): la decomposizione per montepremi e'' rotta']);
        assert(abs(sum(phiFromSold) - R_inj) <= tolChk, ...
               ['tri_level_ep_cer: la parte finanziata dalla vendita non somma a ' ...
                'R_inj: la decomposizione per montepremi e'' rotta']);
    end

    % --- Struttura di uscita -------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';

    S = struct();
    S.players       = players;
    S.phi           = phi;
    S.vGrand        = vGrand;
    S.isProsumer    = isProsumer;
    S.prodShare     = sum(phi(isProsumer));
    S.consShare     = sum(phi(~isProsumer));
    S.phiFromShared = phiFromShared;
    S.phiFromSold   = phiFromSold;
    S.revShared     = R_sh;
    S.revSold       = R_inj;
    S.shareEP       = shareEP;
    S.shareRest     = shareRest;
    S.nVulnerable   = nVu;
    S.isVulnerable  = isVulnerable;
    S.isHousehold   = isHousehold;
    S.lihcBool      = lihcBool;
    S.lihcCont      = lihcCont;
    S.epKey         = epKey;
    S.propKey       = propKey;
    S.ownKey        = ownKey;
    S.energyExpense = energyExpense;
    S.elecExpense   = elecExpense;
    S.gasExpense    = gasExpense;
    S.billPerUser   = billPerUser;
    S.cashFund      = cashFund;

    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    if isempty(reg)
        S.assumptions = table(zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
                              'VariableNames', colonneReg);
    else
        S.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                       string({reg.valore}).', string({reg.rimozione}).', ...
                                       'VariableNames', colonneReg), 'Id');
    end

    S.table = table(players.', isHousehold, isVulnerable, lihcCont, ...
                    energyExpense, propKey, ownKey, epKey, ...
                    phiFromShared, phiFromSold, phi, ...
                    'VariableNames', {'Giocatore', 'Domestico', 'Vulnerabile', ...
                                      'LIHC_cont', 'SpesaEnergia_EUR', ...
                                      'ChiaveProp', 'ChiaveOwn', 'ChiaveEP', ...
                                      'DaCondivisa_EUR', 'DaVendita_EUR', 'Totale_EUR'});

    if ~opts.quiet
        local_print_assumptions(S.assumptions);
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function reg = local_note(reg, id, voce, valore, rimozione)
%LOCAL_NOTE  Aggiunge una voce al registro delle ipotesi ATTIVE. Un'ipotesi
%   viene registrata solo se il dato vero non e' stato passato dal chiamante:
%   l'elenco e' quindi un tracciatore vivo dello stato di avanzamento, non un
%   blocco di testo fisso che si smette di leggere.

    reg(end+1) = struct('id', id, 'voce', voce, 'valore', valore, ...
                        'rimozione', rimozione);
end


function income = local_placeholder_income(players, isHousehold)
%LOCAL_PLACEHOLDER_INCOME  [IPOTESI 1] Redditi segnaposto dalla Tabella 4 di
%   Campagna et al. (2024), assegnati per archetipo. La mappatura segue
%   l'ordine con cui lpg_runner.py numera le colonne household_N a partire da
%   CER_LoadProfiles/config/simulation_config.yaml.
%
%   NON sono i redditi della nostra comunita': sono i redditi di tre nuclei di
%   Teglio. Servono a far girare l'ossatura del metodo, non a produrre
%   risultati. Un nucleo domestico non riconosciuto dalla mappatura riceve il
%   valore del terzo archetipo, quello meno vulnerabile, per non gonfiare
%   artificialmente il numero di vulnerabili.

    tabellaPaper = containers.Map( ...
        {'household_1', 'household_2', 'household_3'}, ...
        {22398.15, 23429.70, 37685.27});      % Old Couple 3, Young Couple 2, Family 1

    n = numel(players);
    income = NaN(n, 1);
    for i = 1:n
        if ~isHousehold(i), continue; end
        chiave = char(erase(players(i), "_kWh"));
        if isKey(tabellaPaper, chiave)
            income(i) = tabellaPaper(chiave);
        else
            income(i) = 37685.27;
        end
    end
end


function local_print_assumptions(A)
%LOCAL_PRINT_ASSUMPTIONS  Stampa le sole ipotesi ancora attive. Silenziabile
%   con opts.quiet, ma di default e' rumorosa di proposito: i numeri prodotti
%   con dati segnaposto non devono poter essere scambiati per risultati.

    if height(A) == 0
        fprintf(['\n*** tri_level_ep_cer: nessuna ipotesi attiva - il metodo sta ' ...
                 'girando su dati reali ***\n']);
        return
    end

    fprintf('\n*** tri_level_ep_cer: %d IPOTESI ATTIVE (implementazione provvisoria) ***\n', ...
            height(A));
    for k = 1:height(A)
        fprintf('  [%2d] %s\n', A.Id(k), A.Voce(k));
        fprintf('       valore: %s\n', A.Valore(k));
    end
    fprintf('  Dettagli e procedura di rimozione: help tri_level_ep_cer\n');
end
