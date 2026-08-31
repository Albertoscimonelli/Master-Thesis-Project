clear; clc;
close all;

%% ========================================================================
%  MAIN.m  -  Analisi energetica ed economica della CER
%
%  Pipeline (ripetuta per ogni CER di CER_configuration/):
%    0)  Le CER da analizzare (elenco delle schede + ciclo)
%    0a) Configurazione       (lettura della scheda dati della CER)
%    1)  Caricamento dati     (profili di carico + generazione PV)
%    2)  Elaborazione CER     (richiesta totale, energia condivisa, venduta)
%    3)  Analisi economica    (ricavi mensili e annuali, tabella riepilogo)
%   3b-3m) Ripartizione dei benefici con dodici modelli di ripartizione
%    3n) Confronto tra i modelli
%    4)  Costo energia da rete (PUN 2025, per utente e per modalita)
%    5)  Visualizzazione      (istogrammi, profili, confronti)
%    6)  Risultati della CER  (messi da parte in RESULTS per i confronti)
%
%  Questo file e' un ORCHESTRATORE: coordina i passi e commenta le scelte di
%  modello, ma delega il lavoro agli helper (load_cer_data, report_allocation,
%  plot_*). Le sezioni restano indipendenti e facili da estendere.
%
%  NON contiene dati. Membri, tariffe, potenze, impianti, redditi, costi di
%  investimento e parametri di governance stanno tutti nelle schede operative
%  di CER_configuration/, lette da load_cer_input.m. E non ne analizza una
%  sola: le legge tutte, una per giro di ciclo. Aggiungere una comunita' allo
%  studio vuol dire mettere un file in quella cartella, non toccare questo.
%  ========================================================================


%% ========================================================================
%  0) LE CER DA ANALIZZARE
%
%  Ogni scheda di CER_configuration/ e' una comunita' diversa: cambiano i
%  membri, quanti di loro hanno un impianto, quanta potenza c'e' installata.
%  Tutto il resto del file non lo sa e non deve saperlo - gira una volta per
%  scheda, sempre nello stesso modo.
%
%  L'elenco si costruisce dalla cartella, non a mano. Le schede si chiamano
%  CER_<C>_<P>_<E>.txt, e il pattern lascia fuori scenario_economico.txt, che
%  e' lo scenario comune a tutte e non una comunita'. Aggiungere una CER allo
%  studio significa copiare un file li' dentro: qui non si tocca nulla.
%  ========================================================================

CARTELLA_CER = "CER_configuration";

elencoSchede = dir(CARTELLA_CER + "/CER_*.txt");
assert(~isempty(elencoSchede), ...
       'Nessuna scheda CER_*.txt in %s: non c''e'' niente da analizzare.', ...
       CARTELLA_CER);

% sort esplicito: l'ordine di dir dipende dal filesystem, quello dei risultati no.
% Separatore '/' e non fullfile: MATLAB lo accetta su ogni sistema, ed e' la
% stessa barra dei percorsi [FILE] dentro le schede. Cosi' il percorso che
% finisce stampato nel riepilogo si legge uguale ovunque giri il progetto.
SCHEDE = CARTELLA_CER + "/" + sort(string({elencoSchede.name}).');
N_CER  = numel(SCHEDE);

fprintf('\n=== CER da analizzare: %d ===\n', N_CER);
fprintf('  %s\n', SCHEDE);

% Un elemento per CER, riempito in coda a ogni giro (§6). Serve perche' a fine
% esecuzione il workspace contiene solo l'ULTIMA comunita': senza, i confronti
% fra CER non avrebbero piu' i dati su cui lavorare.
RESULTS = struct('scheda', {}, 'nome', {}, 'nUsers', {}, 'userNames', {}, ...
                 'Tcmp', {}, 'Tfair', {}, 'metodi', {}, ...
                 'shared_annual', {}, 'sold_annual', {}, 'vGrand', {}, ...
                 'rev_tot_annual', {}, 'contendibleShare', {}, ...
                 'isProsumer', {}, 'tempo_analisi_s', {}, ...
                 'tempo_figure_s', {}, 'CFG', {});


%% ========================================================================
%  0b) QUALI FIGURE PRODURRE, E DOVE FINISCONO
%
%  Non e' un dato della comunita' ma una preferenza di presentazione, e sta
%  qui - PRIMA del ciclo - per due motivi. Il primo e' che serve anche alla
%  §7, che gira dopo il ciclo e non vedrebbe una variabile nata dentro. Il
%  secondo e' che ogni giro produce una ventina di figure: con piu' schede si
%  arriva a qualche decina di finestre aperte, che non e' un modo di lavorare.
%
%  I grafici di DETTAGLIO (uno per metodo: i sedici grafici a rete piu' la
%  barra dello Shapley) sono OPT-IN, perche' da soli sono diciassette figure e
%  dicono per un metodo alla volta quello che il confronto d'insieme della §3s
%  dice per tutti insieme. Si accendono quando serve guardare un metodo, non
%  per abitudine.
%
%  Con .esporta le figure finiscono su file (PDF vettoriale per la tesi + PNG),
%  una cartella per scheda; con .chiudi le finestre si chiudono dopo il
%  salvataggio, cosi' il giro successivo parte pulito.
%  ========================================================================

FIG = struct( ...
    'profili',      false,  ...   % profili di consumo, 4 giorni tipo
    'energia',      false,  ...   % mensili, PV vs domanda, mappa oraria, durata, TIP_h
    'dettaglio',    false, ...   % 17 grafici di dettaglio, uno per metodo (opt-in)
    'metodi',       false,  ...   % confronto delle quote fra i sedici metodi
    'equita',       false,  ...   % indici, scostamento dal merito, trade-off
    'confrontoCER', true,  ...   % confronto fra comunita' (§7, dopo il ciclo)
    'esporta',      true,  ...   % salva le figure su file
    'chiudi',       false,  ...   % chiude le finestre dopo il salvataggio
    'cartella',     "outputs/figures");


% --- Cronometro dell'intera esecuzione ------------------------------------
%  tic con un identificatore esplicito, non il tic/toc globale: quello e' uno
%  solo per tutto MATLAB, e qualunque funzione chiamata piu' sotto che lo usi
%  per conto proprio azzererebbe questo senza che nessuno se ne accorga. Con
%  l'identificatore i due cronometri non si vedono.
T_TOT = tic;


% --- Un giro per comunita' -----------------------------------------------
%  clearvars qui non e' prudenza generica. Le CER hanno numero di membri
%  diverso, quindi quasi ogni vettore di questo file cambia lunghezza da un
%  giro all'altro: una variabile sopravvissuta alla CER precedente non darebbe
%  errore, darebbe un risultato sbagliato in silenzio. Sopravvivono solo le
%  variabili del ciclo, elencate qui - T_TOT compreso, altrimenti il cronometro
%  verrebbe azzerato dal primo giro.
%
%  Nessun try/catch: se una scheda e' rotta l'esecuzione si ferma li', con
%  l'errore in chiaro, invece di nasconderlo in un riepilogo di fine batch.
for iCER = 1:N_CER

    clearvars -except CARTELLA_CER SCHEDE N_CER iCER RESULTS FIG T_TOT

    % Cronometro di QUESTA comunita'. Sta dopo il clearvars, quindi nasce e
    % muore dentro il giro: quello che serve dopo finisce in RESULTS (§6).
    T_CER = tic;

    SCHEDA = SCHEDE(iCER);

    fprintf('\n\n########################################################################\n');
    fprintf('#  CER %d/%d  -  %s\n', iCER, N_CER, SCHEDA);
    fprintf('########################################################################\n');

    %% ========================================================================
    %  0a) CONFIGURAZIONE DELLA CER
    %
    %  Tutti i dati della comunita' stanno in una sola scheda: membri, categorie,
    %  tariffe, potenze impegnate, impianti, redditi, costi di investimento. Qui
    %  resta solo il flusso di calcolo. QUALE scheda non si decide piu' qui: e'
    %  quella del giro di ciclo, gia' pronta in SCHEDA.
    %
    %  I campi lasciati a '?' nella scheda NON vengono passati ai metodi: ognuno
    %  applica il proprio default e lo dichiara come ipotesi attiva nel registro
    %  stampato a fine esecuzione. Riempire un '?' spegne una riga di quel
    %  registro, ed e' cosi' che si misura quanto e' pronta l'analisi.
    %  ========================================================================

    % La scheda di questo giro, scelta dal ciclo della §0. Il nome dice chi abita
    % la CER: CER_<consumatori>_<prosumer>_<produttori puri>. Prezzi, costi e
    % soglie di poverta' non stanno li' dentro: sono gli stessi per tutte le CER e
    % la scheda se li tira dietro da scenario_economico.txt. CER_input.txt e' la
    % guida commentata alla compilazione, e non viene letta da qui.
    CFG = load_cer_input(SCHEDA);

    % --- Costanti temporali --------------------------------------------------
    ANNO    = CFG.cer.anno;
    N_HOURS = CFG.cer.n_ore;
    N_DAYS  = N_HOURS / 24;

    % Griglia oraria canonica dell'anno (asse di riferimento per tutti i dati)
    tGrid = (datetime(ANNO,1,1,0,0,0) : hours(1) : datetime(ANNO,12,31,23,0,0)).';
    assert(numel(tGrid) == N_HOURS, ...
           '%s: n_ore = %d incoerente con l''anno %d, che ha %d ore.', ...
           SCHEDA, N_HOURS, ANNO, numel(tGrid));

    % --- Parametri economici -------------------------------------------------
    P_SELL = CFG.mercato.prezzo_vendita_EUR_kWh;   % energia venduta in rete [€/kWh]

    % Incentivo CER su energia condivisa: tariffa incentivante premio (TIP)
    % oraria (eq. 3.1), calcolata in §1c da compute_cer_incentive.m sul prezzo
    % zonale orario. Parametri della formula:
    ZONA_CER    = CFG.cer.zona_mercato;   % per FC_zonale - deve essere coerente
                                          % con [FILE].prezzi_zonali

    % Potenza che seleziona lo scaglione TP_base/CAP della tariffa. Se la scheda
    % non la dichiara si usa la potenza installata totale: e' piu' difendibile di
    % una costante scritta a mano, e si aggiorna da sola quando si aggiungono
    % impianti. (Con impianti di taglia molto diversa la tariffa andrebbe valutata
    % per impianto: vedi README §14.4.)
    if CFG.noto.mercato.tip_potenza_rif_kW
        P_PV_NOM_KW = CFG.mercato.tip_potenza_rif_kW;
    else
        P_PV_NOM_KW = sum(CFG.impianti.kWp, 'omitnan');
    end

    % Il fattore di riduzione F non e' ancora definito per intero: finche' nella
    % scheda vale '?', nessuna riduzione viene applicata.
    if CFG.noto.mercato.tip_fattore_riduzione
        F_RIDUZIONE = CFG.mercato.tip_fattore_riduzione;
    else
        F_RIDUZIONE = 0;
    end

    % --- Modalita tariffarie PUN ---------------------------------------------
    % L'elenco delle modalita' esistenti. Quale sia la tariffa DI CIASCUN UTENTE
    % e' un dato della scheda ([MEMBRI].tariffa), usato in §3a.
    Modalita = ["MONORARIA", "BIORARIA", "ORARIO_VARIABILE"];

    % --- Flag di visualizzazione ---------------------------------------------
    % Stanno nella struct FIG della §0b, che sopravvive al clearvars: servono
    % anche alla §7, dopo il ciclo, e valgono per tutte le comunita'.

    % Nomi dei mesi (per tabelle e grafici)
    meseNomi = ["Gennaio";"Febbraio";"Marzo";"Aprile";"Maggio";"Giugno"; ...
                "Luglio";"Agosto";"Settembre";"Ottobre";"Novembre";"Dicembre"];

    % --- Impianti fotovoltaici -----------------------------------------------
    % Ogni impianto e' "dietro al contatore" di UN giocatore: la sua produzione
    % copre prima l'autoconsumo del proprietario, e solo l'eccedenza va alla CER
    % (dettagli in load_cer_data.m). La struct arriva dalla sezione [IMPIANTI]
    % della scheda, una riga per impianto: aggiungerne uno non richiede alcuna
    % modifica al codice.
    %
    % Il campo .kWp appartiene all'IMPIANTO, non all'utente. Cosi' e' impossibile
    % dichiarare potenza di generazione a chi non ha impianti, e la cosa regge da
    % sola quando gli impianti diventano molti.
    pvPlants = CFG.impiantiStruct;


    %% ========================================================================
    %  1) CARICAMENTO DATI
    %  ========================================================================

    loadFile = fullfile(CFG.radice, CFG.file.profili_carico);
    D = load_cer_data(loadFile, pvPlants, tGrid);

    userNames         = D.userNames;
    nUsers            = D.nUsers;
    loadUsers         = D.loadUsers;
    loadTotal         = D.loadTotal;
    genPV_raw         = D.genPV_raw;
    genPVSurplus      = D.genPVSurplus;
    genForShare       = D.genForShare;
    loadForShare      = D.loadForShare;
    loadTotalForShare = D.loadTotalForShare;

    % --- Membri della scheda, riordinati sull'ordine delle colonne del CSV ---
    % L'identita' dei giocatori nasce dal CSV (una colonna = un utente); la
    % scheda e' scritta a mano e puo' elencarli in altro ordine. Da qui in poi
    % M.<campo> e' sempre [nUsers x 1] e allineato a userNames.
    M = align_members_to_users(CFG, userNames);


    %% ========================================================================
    %  1c) PREZZO ZONALE E TARIFFA INCENTIVANTE CER (TIP_h)
    %
    %  Il prezzo zonale orario (mercato del giorno prima, MGP) alimenta la
    %  formula 3.1 della tariffa incentivante premio: al posto di un incentivo
    %  CER costante si ottiene un vettore orario P_CER_h, coerente con la griglia
    %  oraria canonica tGrid. Vedi compute_cer_incentive.m per i dettagli e per
    %  il TODO sul fattore di riduzione F.
    %  ========================================================================

    zonalPriceFile = fullfile(CFG.radice, CFG.file.prezzi_zonali);
    Pz_h    = load_zonal_price(zonalPriceFile, tGrid);
    P_CER_h = compute_cer_incentive(Pz_h, P_PV_NOM_KW, ZONA_CER, F_RIDUZIONE);

    fprintf('\n=== Tariffa incentivante CER (TIP_h) ===\n');
    fprintf('  Prezzo zonale medio: %7.2f EUR/MWh\n', mean(Pz_h));
    fprintf('  TIP_h media:         %7.2f EUR/MWh  (%.4f EUR/kWh)\n', ...
            mean(P_CER_h)*1000, mean(P_CER_h));
    fprintf('  TIP_h min / max:     %7.2f / %7.2f EUR/MWh\n', ...
            min(P_CER_h)*1000, max(P_CER_h)*1000);


    %% ========================================================================
    %  2) ELABORAZIONE ENERGETICA (CER)
    %
    %  Per ogni ora:
    %    energia condivisa = min(produzione_PV, richiesta_totale)
    %    energia venduta   = max(0, produzione_PV - richiesta_totale)
    %  ========================================================================

    shared = min(genPVSurplus, loadTotalForShare);      % energia condivisa CER   [kWh/h]
    sold   = max(0, genPVSurplus - loadTotalForShare);  % surplus immesso in rete [kWh/h]

    % Riorganizzazione in matrici 24 x 365 (riga = ora 0..23, colonna = giorno)
    % Nota: demand_24x365/gen_24x365 usano i valori "grezzi" (intera comunita' e
    % intera produzione) solo per la visualizzazione d'insieme in §5; shared/sold
    % riflettono invece il modello con autoconsumo del proprietario (§1).
    shared_24x365 = reshape(shared,    24, N_DAYS);
    sold_24x365   = reshape(sold,      24, N_DAYS);
    demand_24x365 = reshape(loadTotal, 24, N_DAYS);
    gen_24x365    = reshape(genPV_raw, 24, N_DAYS);

    % Aggregati mensili (kWh)
    monthOfHour    = month(tGrid);
    shared_monthly = accumarray(monthOfHour, shared, [12 1]);
    sold_monthly   = accumarray(monthOfHour, sold,   [12 1]);

    % Totali annuali (kWh)
    shared_annual = sum(shared_monthly);
    sold_annual   = sum(sold_monthly);

    fprintf('\n=== Bilancio CER annuale ===\n');
    fprintf('  Energia condivisa: %9.1f kWh\n', shared_annual);
    fprintf('  Energia venduta:   %9.1f kWh\n', sold_annual);


    %% ========================================================================
    %  3) ANALISI ECONOMICA
    %  ========================================================================

    % Incentivo orario (TIP_h): il ricavo condiviso si somma ora per ora prima
    % di aggregare per mese, non piu' come prodotto di uno scalare costante.
    rev_shared_monthly = accumarray(monthOfHour, shared .* P_CER_h, [12 1]);  % [€]
    rev_sold_monthly   = sold_monthly * P_SELL;                                % ricavo da energia venduta [€]
    rev_tot_monthly    = rev_shared_monthly + rev_sold_monthly;
    rev_tot_annual     = sum(rev_tot_monthly);
    rev_sold_annual    = sum(rev_sold_monthly);

    % ricavo da vendita diretta dell'eccedenza sul mercato: NON passa per il gioco
    % cooperativo, va ai proprietari degli impianti (vedi §3b-§3f e
    % plot_benefit_network.m)

    % --- Vendita eccedenza attribuita a ciascun prosumer ---------------------
    % L'eccedenza venduta e' una grandezza di comunita': si ripartisce fra i
    % prosumer PRO-QUOTA sulla produzione oraria, che e' l'unica regola coerente
    % col fatto che l'invenduto nasce dal surplus aggregato. Con un solo impianto
    % si riduce esattamente ad attribuire tutto al suo proprietario.

    shareGen = zeros(size(genForShare));
    hasGen   = genPVSurplus > 0;
    shareGen(hasGen, :) = genForShare(hasGen, :) ./ genPVSurplus(hasGen);
    soldPerUser        = (sold(:).' * shareGen).';        % [nUsers x 1]  [kWh/anno]
    revSoldPerPlayer   = soldPerUser * P_SELL;            % [nUsers x 1]  [EUR/anno]

    assert(abs(sum(revSoldPerPlayer) - rev_sold_annual) < 1e-6 * max(1, rev_sold_annual), ...
           'Vendita eccedenza: la ripartizione per utente non somma al totale annuo');

    % --- Tabella riepilogativa (12 mesi + riga totale annuo) -----------------
    Mese            = [meseNomi;                "TOTALE ANNO"];
    E_condivisa_kWh = [shared_monthly;          shared_annual];
    E_venduta_kWh   = [sold_monthly;            sold_annual];
    Ric_condivisa_E = [rev_shared_monthly;      sum(rev_shared_monthly)];
    Ric_venduta_E   = [rev_sold_monthly;        sum(rev_sold_monthly)];
    Ric_totale_E    = [rev_tot_monthly;         rev_tot_annual];

    Treport = table(Mese, E_condivisa_kWh, E_venduta_kWh, ...
                    Ric_condivisa_E, Ric_venduta_E, Ric_totale_E);

    fprintf('\n=== Riepilogo economico mensile/annuale ===\n');
    disp(Treport);
    fprintf('  Ricavo totale annuo: €%.2f\n', rev_tot_annual);


    %% ========================================================================
    %  3a) COSTO ENERGIA DA RETE SENZA CER (baseline)
    %
    %  Costo annuo di approvvigionamento di ciascun utente nelle tre modalita'
    %  tariffarie PUN, cioe' quanto spenderebbe NON partecipando alla CER.
    %
    %  Il calcolo sta qui e non piu' in §4 perche' e' la baseline y_noLEM
    %  dell'eq. 19 di Dynge & Cali, che serve agli indicatori di equita' della
    %  §3t. La §4 continua a presentarne la tabella: si e' spostato il conto,
    %  non il risultato.
    %
    %  DUE GRANDEZZE DIVERSE, e serve tenerle distinte:
    %    costMat  [nUsers x 3]  quanto spenderebbe ciascuno in OGNUNA delle tre
    %                           modalita' - la tabella comparativa della §4
    %    costUser [nUsers x 1]  quanto spende DAVVERO, con la tariffa che ha in
    %                           bolletta ([MEMBRI].tariffa) - la baseline della §3t
    %  ========================================================================

    % Profilo prezzi orario per ciascuna modalita'
    priceByMod = cell(1, numel(Modalita));
    for m = 1:numel(Modalita)
        TTprice       = profilo_prezzi_pun_2025(Modalita(m));
        priceByMod{m} = TTprice.Prezzo;          % [N_HOURS x 1]
    end

    % Costo annuo = somma( prezzo_orario .* consumo_orario )
    costMat = zeros(nUsers, numel(Modalita));
    for u = 1:nUsers
        for m = 1:numel(Modalita)
            costMat(u, m) = sum(priceByMod{m} .* loadUsers(:, u));
        end
    end

    % --- Costo con la tariffa EFFETTIVA di ciascun utente --------------------
    % costMat risponde a "quanto spenderebbe ciascuno in ognuna delle tre
    % modalita'": e' la tabella comparativa della §4, e resta. costUser risponde
    % a "quanto spende davvero", incrociando il profilo di carico con la tariffa
    % che quell'utente ha in bolletta ([MEMBRI].tariffa nella scheda).
    %
    % E' la baseline y_noLEM dell'eq. 19 usata dagli indicatori della §3t. Prima
    % si assumeva la MONORARIA per tutti; ora la differenza fra i membri riflette
    % anche il contratto, non la sola collocazione oraria dei consumi.
    costUser = zeros(nUsers, 1);
    for u = 1:nUsers
        iMod = find(Modalita == M.tariffa(u), 1);
        costUser(u) = costMat(u, iMod);
    end


    %% ========================================================================
    %  3b) DISTRIBUZIONE DEI BENEFICI - SHAPLEY VALUE
    %
    %  Primo modello di ripartizione dei ricavi della CER. L'incentivo
    %  sull'energia condivisa viene diviso tra i giocatori (impianto PV +
    %  consumatori) secondo lo Shapley value del gioco cooperativo
    %  (Moncecchi et al., Appl. Sci. 2020). Con pochi consumatori lo Shapley
    %  e' calcolato in forma esatta su ogni singolo utente, senza
    %  l'approssimazione per gruppi del paper.
    %
    %    Giocatori : PV (produttore) + consumatori
    %    Valore    : v(S) = sum_t min(genPV, load_S) * P_CER_h(t) (0 senza PV)
    %
    %  NOTA: qui "genPV" e "load_S" sono al netto dell'autoconsumo del
    %  proprietario dell'impianto (genPVSurplus, loadForShare calcolati in
    %  §1): l'energia gia' autoconsumata dietro al contatore del proprietario
    %  non e' energia condivisibile con la CER e va esclusa dal gioco.
    %  ========================================================================

    Sh = shapley_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(Sh, "Shapley");

    % Coerenza con l'analisi economica: il valore distribuito coincide con il
    % ricavo annuo da energia condivisa calcolato nella sezione 3.
    assert(abs(Sh.vGrand - sum(rev_shared_monthly)) < 1e-6, ...
           'Shapley: valore distribuito incoerente con il ricavo da condivisa');

    % --- Grafico distribuzione ----------------------------------------------
    % Ogni colonna e' un utente e si divide in due colori: la quota CER (Shapley)
    % e il ricavo dalla vendita diretta dell'eccedenza sul mercato, che non passa
    % dal gioco cooperativo e spetta ai soli prosumer.
    %
    % Sta sotto FIG.dettaglio con i grafici a rete, ed e' la stessa ragione: e'
    % il dettaglio di UN metodo, e quello che dice per lo Shapley il confronto
    % della §3s lo dice per tutti e sedici insieme.
    if FIG.dettaglio
        figure('Name', 'Distribuzione Shapley', 'Color', 'w');
        hBar = bar([Sh.phi, revSoldPerPlayer], 'stacked');
        hBar(1).FaceColor = method_color("Shapley");
        hBar(2).FaceColor = [0.90 0.45 0.15];   % vendita energia eccedente (mercato)
        grid on; box on;
        xticks(1:numel(Sh.players));
        xticklabels(strrep(Sh.players, '_', '\_')); xtickangle(45);
        ylabel('Ricavo [€/anno]');
        legend(hBar, {'Quota CER (Shapley)', 'Vendita energia eccedente'}, 'Location', 'northeast');
        title(sprintf('Ripartizione incentivo CER condivisa  |  Totale CER = €%.0f', Sh.vGrand));
    end

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(Sh.players, Sh.phi, "Shapley", revSoldPerPlayer); end


    %% ========================================================================
    %  3c) DISTRIBUZIONE DEI BENEFICI - NUCLEOLO
    %
    %  Secondo modello di ripartizione, sulla STESSA funzione caratteristica
    %  v(S) usata dallo Shapley (quindi direttamente confrontabile). Il Nucleolo
    %  (Fioriti et al., Appl. Energy 2021, eq. 7) distribuisce il valore
    %  massimizzando in modo lessicografico il surplus della coalizione piu'
    %  scontenta, risolvendo una sequenza di problemi lineari. A differenza
    %  dello Shapley, se il Core e' non-vuoto il Nucleolo vi appartiene ed e'
    %  quindi STABILE (nessuna sotto-coalizione conviene).
    %  ========================================================================

    Nu = nucleolus_cer(genForShare, loadForShare, userNames, P_CER_h);

    coreMsg = "fuori dal Core";
    if Nu.inCore, coreMsg = "nel Core (stabile)"; end
    report_allocation(Nu, "Nucleolo", ...
        sprintf('  %-25s: EUR %9.2f  ->  %s', 'Surplus min (theta)', Nu.thetaMin, coreMsg));

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(Nu.players, Nu.phi, "Nucleolo", revSoldPerPlayer); end


    %% ========================================================================
    %  3d) DISTRIBUZIONE DEI BENEFICI - NASH BARGAINING
    %
    %  Terzo modello di ripartizione, sulla STESSA funzione caratteristica v(S)
    %  di Shapley e Nucleolo. Adattamento del modello di Nash Bargaining
    %  generale (Yan et al., Int. J. Electr. Power Energy Syst. 152 (2023)
    %  109218) al caso di una singola grande coalizione: ogni giocatore incassa
    %  il proprio punto di disaccordo (qui 0, nessuno guadagna nulla da solo)
    %  piu' una quota del surplus proporzionale al proprio contributo marginale
    %  alla grande coalizione (il "potere contrattuale"). Vedi
    %  nash_bargaining_cer.m per i dettagli e i riferimenti.
    %  ========================================================================

    NB = nash_bargaining_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(NB, "Nash Bargaining");

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(NB.players, NB.phi, "Nash Bargaining", revSoldPerPlayer); end


    %% ========================================================================
    %  3e) DISTRIBUZIONE DEI BENEFICI - VARIANCE LEAST CORE
    %
    %  Quarto modello di ripartizione, sulla STESSA funzione caratteristica v(S)
    %  degli altri tre. Il Variance Least Core (Ferrucci, Fioriti, Poli, IEEE PES
    %  ISGT Europe 2025) sceglie, fra tutte le allocazioni del Least Core (quelle
    %  che massimizzano il surplus della coalizione piu' scontenta, quindi
    %  STABILI), l'unica a distanza quadratica minima dalla ripartizione
    %  uniforme: e' quindi al tempo stesso stabile ed UNIVOCA, a differenza del
    %  Least Core che e' un insieme.
    %
    %  A differenza degli altri metodi NON enumera le 2^n coalizioni: usa la
    %  ROW-GENERATION (Master + Separation MILP, eq. 15-17 del paper), che genera
    %  solo le poche coalizioni realmente vincolanti. E' questa la scelta che
    %  rende il metodo applicabile a comunita' con decine o centinaia di membri.
    %  Vedi variance_least_core_cer.m per i dettagli.
    %  ========================================================================

    VLC = variance_least_core_cer(genForShare, loadForShare, userNames, P_CER_h);

    coreMsgVLC = "fuori dal Core";
    if VLC.inCore, coreMsgVLC = "nel Core (stabile)"; end
    report_allocation(VLC, "Variance Least Core", [ ...
        string(sprintf('  %-25s: EUR %9.2f  ->  %s', ...
                       'Surplus min (theta_LC)', VLC.thetaLC, coreMsgVLC)), ...
        string(sprintf('  %-25s: %d iterazioni (LC) + %d (VLC), %d coalizioni generate su %d', ...
                       'Row-generation', VLC.iterLC, VLC.iterVLC, ...
                       size(VLC.coalitions, 1), 2^numel(VLC.players) - 2))]);

    % Controllo incrociato: il primo LP del Nucleolo E' l'LP del Least Core,
    % quindi i due surplus minimi devono coincidere. E' la verifica piu' forte
    % che la row-generation non abbia trascurato coalizioni vincolanti.
    assert(abs(VLC.thetaLC - Nu.thetaMin) < 1e-6 * max(1, abs(VLC.vGrand)), ...
           'Variance Least Core: theta_LC diverso dal surplus minimo del Nucleolo');

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(VLC.players, VLC.phi, "Variance Least Core", revSoldPerPlayer); end


    %% ========================================================================
    %  3f) DISTRIBUZIONE DEI BENEFICI - EQUAL SPLIT
    %
    %  Quinto modello, il piu' semplice possibile: l'incentivo sull'energia
    %  condivisa viene diviso in parti UGUALI tra tutti i giocatori, senza
    %  guardare a produzione o consumo. Serve da benchmark elementare per
    %  misurare quanto i modelli di teoria dei giochi si discostino da una
    %  ripartizione paritaria. Vedi equal_split_cer.m per i dettagli.
    %  ========================================================================

    ES = equal_split_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(ES, "Equal Split");

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(ES.players, ES.phi, "Equal Split", revSoldPerPlayer); end


    %% ========================================================================
    %  3g) DISTRIBUZIONE DEI BENEFICI - PROPORTIONAL TO CONSUMPTION
    %
    %  Sesto modello, secondo benchmark elementare: l'incentivo sull'energia
    %  condivisa viene diviso in proporzione al consumo di ciascun utente nelle
    %  sole ore "utili" (energia condivisa di comunita' > 0). Chi consuma di
    %  piu' nelle ore in cui la CER matura benefici economici riceve una quota
    %  maggiore. Vedi proportional_consumption_cer.m per i dettagli.
    %  ========================================================================

    PC = proportional_consumption_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(PC, "Proportional to Consumption");

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(PC.players, PC.phi, "Proportional to Consumption", revSoldPerPlayer); end


    %% ========================================================================
    %  3h) DISTRIBUZIONE DEI BENEFICI - REMUNERATION MODEL 1
    %
    %  Settimo modello, da Candela, Di Silvestre, Gallo, Riva Sanseverino,
    %  Sciume', Zizzo, "A Remuneration Model of Energy Community Members in
    %  Italy", IEEE BLORIN 2022. L'incentivo si divide in due quote (alpha per i
    %  consumatori, beta per i produttori/prosumer) pesate sulla potenza
    %  di ciascuna classe: potenza di PRELIEVO per i consumatori
    %  ([MEMBRI].P_prel_kW) e potenza di GENERAZIONE per i produttori
    %  ([IMPIANTI].kWp) - due grandezze fisiche distinte, dichiarate in due
    %  tabelle distinte della scheda proprio per non confonderle.
    %  All'interno di ciascuna classe la quota oraria e' proporzionale
    %  all'energia di quell'ora. Vedi remuneration_model1_cer.m.
    %  ========================================================================

    % Potenza impegnata in prelievo: colonna P_prel_kW di [MEMBRI], gia'
    % riordinata sull'ordine dei giocatori da align_members_to_users.
    ratedLoadKW = M.P_prel_kW;

    % Potenza di generazione: derivata dagli IMPIANTI, non da una tabella per
    % utente. Chi possiede piu' impianti somma le rispettive potenze; chi non ne
    % possiede resta a 0 automaticamente.
    ratedGenKW = zeros(nUsers, 1);
    for p = 1:numel(pvPlants)
        ownerIdx = find(userNames == pvPlants(p).owner, 1);
        ratedGenKW(ownerIdx) = ratedGenKW(ownerIdx) + pvPlants(p).kWp;
    end

    RM1 = remuneration_model1_cer(genForShare, loadForShare, userNames, P_CER_h, ...
                                  ratedLoadKW, ratedGenKW);
    report_allocation(RM1, "Remuneration Model 1", ...
        sprintf('  %-25s: alpha=%.3f  beta=%.3f  (prelievo %.0f kW / generazione %.0f kWp)', ...
                'Pesi di classe', RM1.alpha, RM1.beta, ...
                sum(RM1.ratedLoadKW(RM1.consumerEligible)), ...
                sum(RM1.ratedGenKW(RM1.producerEligible))));

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(RM1.players, RM1.phi, "Remuneration Model 1", revSoldPerPlayer); end


    %% ========================================================================
    %  3i) DISTRIBUZIONE DEI BENEFICI - CASCADING TREE
    %
    %  Ottavo modello, da Trevisan, Ghiani, Pilo, "Economic Benefits
    %  Redistribution Methodology for Renewable Energy Communities", 2022.
    %  L'incentivo si scompone ricorsivamente in un albero di categorie
    %  (riserve, quota fissa, quota variabile -> prelievi/immissione ->
    %  produttori+prosumer/soli prosumer), con pesi di ramo di default
    %  (scelte di governance della REC, non derivabili dai dati - vedi
    %  cascading_tree_cer.m per i dettagli e per come modificarli via opts).
    %  ========================================================================

    % I quattro pesi di ramo sono scelte di governance, non dati: stanno nella
    % sezione [GOVERNANCE] della scheda. Lasciarli a '?' riporta ai default.
    optCT = opts_from_config(CFG.governance, CFG.noto.governance, [ ...
        "ct_riserva",        "reservoirFraction"
        "ct_quota_fissa",    "fixedFraction"
        "ct_quota_prelievi", "withdrawalsFraction"
        "ct_quota_prosumer", "prosumersOnlyFraction"]);

    CT = cascading_tree_cer(genForShare, loadForShare, userNames, P_CER_h, optCT);
    foldMsg = "";
    if CT.prosumersOnlyFolded
        foldMsg = "  (nessun vero prosumer: pool soli-prosumer assorbita in immissione generale)";
    end
    report_allocation(CT, "Cascading Tree", [ ...
        string(sprintf('  %-25s: EUR %9.2f (riserva)  EUR %9.2f (montepremi totale)', ...
                       'Trattenuto / totale', CT.reservoirAmount, CT.totalIncentive)), ...
        string(sprintf('  %-25s: fisso=%.0f prelievi=%.0f immissione=%.0f prosumer=%.0f%s', ...
                       'Pool [EUR]', CT.pools.fixed, CT.pools.withdrawals, ...
                       CT.pools.feedInGeneral, CT.pools.prosumersOnly, foldMsg))]);

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(CT.players, CT.phi, "Cascading Tree", revSoldPerPlayer); end


    %% ========================================================================
    %  3j) DISTRIBUZIONE DEI BENEFICI - WEIGHTED SOLIDARITY
    %
    %  Nono modello, da Marrasso, Martone, Perugini, Roselli, "Towards a fair
    %  revenue distribution of a Renewable Energy Community through a
    %  proportional energy consumption model application", J. Phys.: Conf. Ser.
    %  3143 (2025) 012113. Peso orario = componente tecnica (energia condivisa +
    %  carico dell'utente) + componente di solidarieta' (punteggio a scalini sul
    %  costo unitario dell'energia, proxy di poverta' energetica); i quattro
    %  coefficienti della formula sono scelti su un fronte di Pareto tra indice
    %  di Gini minimo e reddito medio massimo degli utenti a rischio poverta'
    %  energetica. Vedi weighted_solidarity_cer.m per i dettagli.
    %
    %  NOTA: questo e' l'unico metodo che NON usa le tariffe per utente della
    %  scheda. Stima il costo unitario Cu internamente da un'unica modalita'
    %  tariffaria (opts.tariffMode, default MONORARIA), perche' la sua API
    %  prende uno scalare e non un vettore. E' anche il motivo per cui il suo
    %  Cu varia cosi' poco fra i membri (README §12): riflette la collocazione
    %  oraria dei consumi, non il contratto ne' la vulnerabilita' economica.
    %  ========================================================================

    WS = weighted_solidarity_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(WS, "Weighted Solidarity", [ ...
        string(sprintf('  %-25s: alpha1=%.0f alpha2=%.0f beta1=%.0f beta2=%.0f', ...
                       'Combinazione Pareto-ottima', WS.alpha1, WS.alpha2, WS.beta1, WS.beta2)), ...
        string(sprintf('  %-25s: %.4f  (%d combinazioni Pareto-ottime)', ...
                       'Indice di Gini', WS.giniIndex, WS.nParetoPoints))]);

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(WS.players, WS.phi, "Weighted Solidarity", revSoldPerPlayer); end


    %% ========================================================================
    %  3k) DISTRIBUZIONE DEI BENEFICI - PEARSON KEY (chiave dinamica M3)
    %
    %  Decimo modello, da Gianaroli, Ricci, Sdringola, Ancona, Branchini, Melino, "Development
    %  of dynamic sharing keys: Algorithms supporting management of renewable
    %  energy community and collective self consumption", Energy & Buildings 311
    %  (2024) 114158 (metodo M3).
    %
    %  E' il primo modello che NON ripartisce direttamente il denaro: ripartisce
    %  ora per ora l'ENERGIA condivisa tra gli utenti con una chiave dinamica, e
    %  solo alla fine la valorizza con la tariffa incentivante P_CER_h. La chiave
    %  premia il SINCRONISMO: per ogni giorno si calcola la correlazione di
    %  Pearson tra il profilo di consumo dell'utente e il profilo di immissione
    %  della comunita', rimappata in [0,1]. L'energia oraria si distribuisce con
    %  quei pesi e con il vincolo SH_i <= consumo_i, ridistribuendo iterativamente
    %  a chi resta cio' che eccede il consumo di chi viene "cappato"
    %  (allocate_shared_energy.m). Vedi pearson_key_cer.m per i dettagli.
    %  ========================================================================

    PK = pearson_key_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(PK, "Pearson Key", ...
        sprintf('  %-25s: media %+.3f  (min %+.3f / max %+.3f tra gli utenti)', ...
                'Correlazione Pearson', mean(PK.pMeanUser), ...
                min(PK.pMeanUser), max(PK.pMeanUser)));

    % L'energia distribuita ora per ora deve coincidere con l'energia condivisa
    % della comunita' calcolata nella sezione 2: e' il controllo piu' diretto che
    % l'algoritmo iterativo di cap non perda ne' crei energia.
    assert(abs(sum(PK.sharedEnergy) - shared_annual) < 1e-6 * max(1, shared_annual), ...
           'Pearson Key: energia condivisa ripartita incoerente con il bilancio CER');

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(PK.players, PK.phi, "Pearson Key", revSoldPerPlayer); end


    %% ========================================================================
    %  3l) DISTRIBUZIONE DEI BENEFICI - PEARSON-SHARING RATE (chiave dinamica M5)
    %
    %  Undicesimo modello, dallo stesso paper del precedente (metodo M5, eq. 7).
    %  Combina linearmente le due chiavi del paper con alpha + beta = 1: la
    %  correlazione di Pearson di M3 (sincronismo) e lo "sharing rate" di M4, che
    %  penalizza chi in una data ora consuma piu' energia di quanta la comunita'
    %  ne stia immettendo. M4 non e' esposto come modello a se': il suo peso resta
    %  una componente interna, calcolata da sharing_rate_key.m. La ripartizione
    %  oraria dell'energia e il cap al consumo sono gli stessi di M3 (helper
    %  condivisi). Vedi pearson_sharing_key_cer.m per i dettagli, e la nota sulla
    %  lettura dell'eq. 5 del paper in sharing_rate_key.m.
    %
    %  DA RILEGGERE CON I DATI REALI: sulla community provvisoria di oggi questo
    %  metodo e' quasi indistinguibile dalla Pearson Key (scarto < 1%), perche' il
    %  91% dell'energia cade nel caso banale e nessun utente sovraconsuma - l'unico
    %  caso in cui lo sharing rate morde. Non e' un bug: GUIDA §14.6 riporta i tre
    %  indicatori da ricalcolare per verificare se il fenomeno si ripresenta.
    %  ========================================================================

    % Solo alpha dalla scheda: beta = 1 - alpha lo impone il metodo, e passarli
    % entrambi aprirebbe la porta a una coppia incoerente.
    optPSK = opts_from_config(CFG.governance, CFG.noto.governance, ...
                              ["psk_alpha", "alpha"]);

    PSK = pearson_sharing_key_cer(genForShare, loadForShare, userNames, P_CER_h, optPSK);
    report_allocation(PSK, "Pearson-Sharing Rate", [ ...
        string(sprintf('  %-25s: alpha=%.2f (Pearson)  beta=%.2f (sharing rate)  xi=%.3f', ...
                       'Pesi della chiave', PSK.alpha, PSK.beta, PSK.xi)), ...
        string(sprintf('  %-25s: lettura "%s" dell''eq. 5 (coerente con Fig. 3 e con l''esempio del paper)', ...
                       'Sharing rate', PSK.sharingRateMode))]);

    assert(abs(sum(PSK.sharedEnergy) - shared_annual) < 1e-6 * max(1, shared_annual), ...
           'Pearson-Sharing Rate: energia condivisa ripartita incoerente con il bilancio CER');

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(PSK.players, PSK.phi, "Pearson-Sharing Rate", revSoldPerPlayer); end


    %% ========================================================================
    %  3m) DISTRIBUZIONE DEI BENEFICI - SIMILARITY-UTILIZATION
    %
    %  Dodicesimo modello, da M. Bilardo, "A fair dynamic incentive allocation
    %  method for virtual energy sharing in renewable energy communities that
    %  rewards members' virtuosity and engagement", Renewable Energy 255 (2025)
    %  123756. Come le due chiavi dinamiche precedenti e' un metodo
    %  "performance-based", ma ripartisce l'incentivo GIORNO PER GIORNO con un
    %  fattore che premia la "virtuosita' energetica", prodotto di due termini:
    %    theta = similarita' COSENO tra il profilo giornaliero di carico
    %            dell'utente e quello di generazione della comunita' (premia chi
    %            consuma quando la comunita' produce; ignora le quantita');
    %    eta   = quota del fabbisogno giornaliero che la generazione di comunita'
    %            riesce a coprire, min(1, E_gen/E_load) (penalizza chi consuma
    %            piu' di quanto la comunita' produca).
    %  Vedi similarity_utilization_cer.m per i dettagli.
    %
    %  SCELTA DI MODELLO: theta ed eta sono qui calcolati sui profili NETTI
    %  (genForShare/loadForShare), come tutti gli altri metodi del progetto. Il
    %  paper li calcola invece sui profili LORDI dietro al contatore; per
    %  riprodurlo alla lettera basta passare gli opts, senza altre modifiche:
    %
    %    SU = similarity_utilization_cer(genForShare, loadForShare, userNames, ...
    %             P_CER_h, struct('loadForFactors', loadUsers, ...
    %                             'genForFactors',  genPV_raw));
    %
    %  Il montepremi v(N) non cambia in nessuno dei due casi. Vedi GUIDA §15.3.
    %  ========================================================================

    SU = similarity_utilization_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(SU, "Similarity-Utilization", [ ...
        string(sprintf('  %-25s: media %.3f (min %.3f / max %.3f tra gli utenti)', ...
                       'Similarita'' theta', mean(SU.thetaMean), ...
                       min(SU.thetaMean), max(SU.thetaMean))), ...
        string(sprintf('  %-25s: media %.3f (min %.3f / max %.3f tra gli utenti)', ...
                       'Utilizzo eta', mean(SU.etaMean), ...
                       min(SU.etaMean), max(SU.etaMean)))]);

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(SU.players, SU.phi, "Similarity-Utilization", revSoldPerPlayer); end


    %% ========================================================================
    %  3n) DISTRIBUZIONE DEI BENEFICI - MARGINAL CONTRIBUTION
    %
    %  Tredicesimo modello, e primo dei tre di Cremers, Robu, Zhang, Andoni,
    %  Norbu, Flynn, "Efficient methods for approximating the Shapley value for
    %  asset sharing in energy communities", Applied Energy 331 (2023) 120328.
    %
    %  I tre metodi che seguono NON sono regole di ripartizione alternative allo
    %  Shapley: sono APPROSSIMAZIONI dello Shapley stesso, pensate per comunita'
    %  in cui le 2^n coalizioni non si possono enumerare (il paper arriva a 200
    %  prosumer). Con i nostri 6 giocatori lo Shapley esatto e' istantaneo, quindi
    %  qui servono a misurare QUANTO le approssimazioni si discostino dal valore
    %  esatto - il confronto della §3q, che riproduce le Tabelle E.3-E.4 del
    %  paper sui nostri dati.
    %
    %  Questo primo metodo tiene un solo contributo marginale, l'ultimo:
    %    MC_i = v(N) - v(N\{i}),  poi normalizzato a v(N)  (eq. 9-10).
    %  Costa O(n) valutazioni di v invece di O(2^n). Vedi
    %  marginal_contribution_cer.m, in particolare la nota sul comportamento
    %  degenere quando un consumatore e' superfluo (MC = 0 -> quota nulla).
    %  ========================================================================

    MC = marginal_contribution_cer(genForShare, loadForShare, userNames, P_CER_h);
    report_allocation(MC, "Marginal Contribution", [ ...
        string(sprintf('  %-25s: %.4f  (v(N) / somma dei contributi grezzi)', ...
                       'Fattore di normalizz.', MC.normFactor)), ...
        string(sprintf('  %-25s: %d su %d giocatori con MC = 0, quindi quota nulla', ...
                       'Giocatori superflui', MC.nullPlayers, numel(MC.players)))]);

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(MC.players, MC.phi, "Marginal Contribution", revSoldPerPlayer); end


    %% ========================================================================
    %  3o) DISTRIBUZIONE DEI BENEFICI - STRATIFIED EXPECTED VALUE
    %
    %  Quattordicesimo modello, dallo stesso paper (§4.1.2, eq. 11-13): e' il
    %  metodo NUOVO proposto dagli autori. Invece di tenere il solo ultimo strato
    %  li tiene TUTTI, stimando il contributo marginale atteso di ogni strato con
    %  una sola valutazione di v su copie di un utente FITTIZIO medio (eq. 11).
    %  Costa O(n^2) valutazioni di v, resta DETERMINISTICO, e nei test del paper
    %  batte sempre la Marginal Contribution e spesso anche il campionamento
    %  adattivo, a un decimo del costo.
    %
    %  ATTENZIONE: sui NOSTRI dati e' invece il peggiore dei tre (~22% di scarto
    %  dallo Shapley esatto, vedi §3q). L'eq. 11 assume che i membri siano
    %  intercambiabili, cosa vera nel paper - dove l'impianto e' in comproprieta'
    %  e nessuno e' indispensabile - ma falsa qui, dove la generazione e' di un
    %  solo membro su sei. Spiegazione per esteso in stratified_expected_value_cer.m.
    %  ========================================================================

    % opts.validateStrata enumera il contributo marginale VERO di ogni strato
    % (eq. 8) e verifica che agli strati 0 e n-1 -- dove esiste una sola
    % coalizione e l'approssimazione non ha spazio per sbagliare -- la stima sia
    % esatta. E' cio' che distingue un errore di IMPLEMENTAZIONE da un limite di
    % MODELLO, e con 6 giocatori costa 192 valutazioni di v: si tiene acceso.
    SEV = stratified_expected_value_cer(genForShare, loadForShare, userNames, P_CER_h, ...
                                        struct('validateStrata', true));

    interior   = 2:(nUsers-1);                       % strati intermedi (1..n-2)
    relBiasMax = 100 * max(SEV.strataBias(:, interior) ./ ...
                           max(SEV.muExact(:, interior), eps), [], 'all');
    report_allocation(SEV, "Stratified Expected Value", [ ...
        string(sprintf('  %-25s: %.4f  (v(N) / somma dei valori SEV grezzi)', ...
                       'Fattore di normalizz.', SEV.normFactor)), ...
        string(sprintf('  %-25s: %d strati per giocatore, %d valutazioni di v (contro %d coalizioni)', ...
                       'Costo di calcolo', nUsers, 2*nUsers^2, 2^nUsers)), ...
        string(sprintf('  %-25s: nullo sugli strati 0 e n-1, fino a %+.0f%% su quelli intermedi', ...
                       'Scarto vs eq. 8 esatta', relBiasMax))]);

    % Controllo incrociato forte: nel nostro gioco v dipende solo dai profili
    % AGGREGATI della coalizione, quindi n-1 copie dell'utente medio riproducono
    % esattamente l'aggregato degli altri n-1 utenti veri. L'ultimo strato della
    % SEV deve percio' coincidere con il contributo marginale della §3n - se non
    % coincide, l'utente fittizio dell'eq. 11 e' costruito male.
    assert(max(abs(SEV.lastStratumMC - MC.mcRaw)) < 1e-6 * max(1, abs(SEV.vGrand)), ...
           'Stratified Expected Value: ultimo strato diverso dal contributo marginale');

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(SEV.players, SEV.phi, "Stratified Expected Value", revSoldPerPlayer); end


    %% ========================================================================
    %  3p) DISTRIBUZIONE DEI BENEFICI - ADAPTIVE SAMPLING SHAPLEY
    %
    %  Quindicesimo modello: l'approssimazione per CAMPIONAMENTO STRATIFICATO
    %  ADATTIVO di O'Brien, El Gamal, Rajagopal (IEEE Trans. Smart Grid 2015),
    %  che nel paper di Cremers et al. fa da riferimento "stato dell'arte"
    %  (§4.1.3 e Appendice C). Per ogni giocatore estrae M coalizioni casuali,
    %  distribuendo i campioni fra gli strati in proporzione alla dispersione
    %  stimata dei contributi marginali.
    %
    %  E' l'unico metodo STOCASTICO del progetto: il seed lo rende riproducibile,
    %  ma cambiandolo i numeri cambiano - ed e' esattamente la critica che il
    %  paper gli muove (in una CER i membri devono poter riverificare il conto).
    %  Con soli 6 giocatori gli strati hanno al massimo 10 coalizioni, quindi
    %  M = 1000 campioni le enumerano molte volte e la stima converge di fatto
    %  allo Shapley esatto. Vedi adaptive_sampling_shapley_cer.m.
    %  ========================================================================

    % M e seed vengono dalla scheda: il seed e' cio' che rende riverificabile
    % l'unico conto stocastico del progetto, quindi va dichiarato insieme ai dati
    % e non nascosto in un default.
    optAS = opts_from_config(CFG.governance, CFG.noto.governance, [ ...
        "as_campioni", "M"
        "as_seed",     "seed"]);

    AS = adaptive_sampling_shapley_cer(genForShare, loadForShare, userNames, P_CER_h, optAS);
    report_allocation(AS, "Adaptive Sampling Shapley", [ ...
        string(sprintf('  %-25s: M = %d campioni/giocatore, seed = %d (metodo STOCASTICO)', ...
                       'Campionamento', AS.M, AS.seed)), ...
        string(sprintf('  %-25s: %.4f  (v(N) / somma delle stime grezze)', ...
                       'Fattore di normalizz.', AS.normFactor))]);

    % --- Grafico a rete: cabina primaria + benefici + verso del flusso -------
    if FIG.dettaglio, plot_benefit_network(AS.players, AS.phi, "Adaptive Sampling Shapley", revSoldPerPlayer); end


    %% ========================================================================
    %  3q) ACCURATEZZA DELLE APPROSSIMAZIONI DELLO SHAPLEY
    %
    %  I tre metodi di §3n-3p approssimano la STESSA grandezza gia' calcolata in
    %  forma esatta in §3b. Qui si misura di quanto se ne discostino, con la
    %  differenza relativa percentuale del paper (eq. 16):
    %
    %    RD(phi_i) = |phi_stimato_i - phi_Shapley_i| / |phi_Shapley_i| * 100
    %
    %  e la sua media sui giocatori (eq. 17; nel paper e' pesata sulla numerosita'
    %  delle classi, qui ogni utente e' una classe a se', quindi e' una media
    %  semplice). E' la riproduzione, sui nostri dati, delle Tabelle E.3-E.4 del
    %  paper.
    %
    %  RISULTATO: la graduatoria del paper si ROVESCIA. Da noi la Marginal
    %  Contribution sbaglia ~1%, il campionamento adattivo ~1.5% e la Stratified
    %  Expected Value ~22%, mentre nel paper e' quest'ultima la piu' accurata.
    %  Il motivo e' strutturale, non numerico: SEV rappresenta ogni strato con un
    %  utente MEDIO, ipotesi ragionevole quando l'impianto e' in comproprieta' fra
    %  tutti (il caso del paper) e insostenibile quando la generazione e' di un
    %  solo membro su sei (il nostro), perche' spalma su tutti una produzione che
    %  in realta' e' di uno solo. E' un esito da riportare come tale: misura fino
    %  a che punto le approssimazioni pensate per comunita' OMOGENEE reggano su
    %  una comunita' con un unico prosumer pivotale.
    %  ========================================================================

    approxPhi = [MC.phi, SEV.phi, AS.phi];

    % Un giocatore con Shapley nullo non ha una differenza RELATIVA definita:
    % si riporta NaN invece di dividere per zero.
    okShapley = abs(Sh.phi) > 1e-9 * max(1, abs(Sh.vGrand));
    RD = nan(size(approxPhi));
    RD(okShapley, :) = 100 * abs(approxPhi(okShapley, :) - Sh.phi(okShapley)) ...
                           ./ abs(Sh.phi(okShapley));

    Trd = table(Sh.players(:), Sh.phi, MC.phi, SEV.phi, AS.phi, ...
                RD(:,1), RD(:,2), RD(:,3), ...
                'VariableNames', {'Giocatore', 'ShapleyEsatto_EUR', ...
                                  'MarginalContribution_EUR', 'StratifiedExpValue_EUR', ...
                                  'AdaptiveSampling_EUR', 'MC_RD_pct', 'SEV_RD_pct', ...
                                  'AS_RD_pct'});
    fprintf('\n=== Accuratezza delle approssimazioni dello Shapley (eq. 16 del paper) ===\n');
    disp(Trd);
    fprintf('  %-25s: MC %.4f%%   SEV %.4f%%   AS %.4f%%\n', ...
            'RD media (eq. 17)', mean(RD(:,1), 'omitnan'), ...
            mean(RD(:,2), 'omitnan'), mean(RD(:,3), 'omitnan'));

    % I tre approssimatori giocano lo stesso gioco degli altri metodi: se il
    % montepremi non coincide con quello dello Shapley esatto, il confronto della
    % §3q non sta misurando l'errore di approssimazione ma un errore di modello.
    assert(max(abs([MC.vGrand, SEV.vGrand, AS.vGrand] - Sh.vGrand)) < 1e-6 * max(1, abs(Sh.vGrand)), ...
           'Approssimazioni Shapley: v(N) diverso da quello dello Shapley esatto');


    %% ========================================================================
    %  3r) TRI-LEVEL: OWNERSHIP + PROPORTIONAL + ENERGY POVERTY (LIHC)
    %
    %  Metodo tri-livello di Campagna, Rancilio, Radaelli, Merlo (SEGAN 39, 2024,
    %  101471), eq. 11-15. E' l'unico modello del progetto che misura la poverta'
    %  energetica con un indicatore riconosciuto (LIHC) invece di un proxy.
    %
    %  *** IMPLEMENTAZIONE PROVVISORIA ***
    %  Gira su DATI SEGNAPOSTO: reddito delle famiglie, spesa gas, markup dal PUN
    %  al prezzo di bolletta, mediana nazionale della spesa energetica. Undici
    %  ipotesi sono attive e vengono stampate qui sotto a ogni esecuzione. I numeri
    %  prodotti NON sono risultati. Il registro completo, con la procedura per
    %  rimuovere ciascuna ipotesi, sta nell'header della funzione: i dati
    %  provvisori vivono TUTTI li' dentro, deliberatamente, e non in questo file,
    %  cosi' c'e' un unico posto da aprire quando arrivano i dati veri.
    %
    %      help tri_level_ep_cer          il registro delle 11 ipotesi
    %      grep -n IPOTESI tri_level_ep_cer.m    i punti nel codice
    %
    %  MONTEPREMI: a differenza degli altri quindici modelli, questo ripartisce
    %  ENTRAMBI i ricavi, perche' il livello Owners redistribuisce proprio il
    %  ricavo di vendita (Fig. 7 del paper). Quindi TL.vGrand = v(N) + vendita,
    %  non v(N) - stessa situazione dichiarata dal Cascading Tree. Per il confronto
    %  della §3s si usa TL.phiFromShared, che somma esattamente a v(N).
    %  ========================================================================

    % --- Dati della scheda che spengono le ipotesi del metodo ----------------
    % Ogni campo passato qui e' una riga in meno nel registro stampato sotto; i
    % campi assenti lasciano al metodo il proprio default, che il metodo dichiara.
    % Un vettore per membro si passa SOLO se la colonna della scheda non ha
    % nemmeno un '?': un vettore con un buco non e' un dato.
    optTL = struct('revSold', rev_sold_annual);

    optTL = opts_from_config(CFG.mercato, CFG.noto.mercato, [ ...
        "markup_retail",      "retailMarkup"
        "prezzo_gas_EUR_kWh", "gasPrice"], optTL);

    optTL = opts_from_config(CFG.poverta, CFG.noto.poverta, [ ...
        "mediana_spesa_energetica_EUR",  "medianEnergyExpense"
        "soglia_poverta_EUR_percettore", "povertyThreshold"
        "quota_n_pct",                   "nPct"
        "tetto_quota_EP",                "capEP"
        "usa_profondita_poverta",        "useContinuous"
        "applica_tetto_bolletta",        "billCap"], optTL);

    % Chi e' un nucleo domestico: dichiarato in [MEMBRI].categoria invece che
    % dedotto dal nome. Un "comune_1_kWh" di categoria domestica sfuggirebbe
    % all'euristica sui nomi; la categoria no.
    optTL.isHousehold = M.isHousehold;

    if M.noto.reddito_EUR,    optTL.income          = M.reddito_EUR;    end
    if M.noto.n_perc,         optTL.nIncomeEarners  = M.n_perc;         end
    if M.noto.mutuo_EUR_anno, optTL.mortgagePerUser = M.mutuo_EUR_anno; end

    % La spesa gas si costruisce da due dati distinti: i kWh del membro e il
    % prezzo di comunita'. Serve che siano noti entrambi.
    if M.noto.gas_kWh && CFG.noto.mercato.prezzo_gas_EUR_kWh
        optTL.gasExpense = M.gas_kWh * CFG.mercato.prezzo_gas_EUR_kWh;
    end

    % Quote di proprieta' dalle quote di investimento effettivamente versate.
    % align_members_to_users azzera il flag se sono tutte nulle: in quel caso non
    % sono un dato di proprieta' ma la sua assenza, e il metodo deduce le quote
    % dalla produzione dichiarandolo.
    if M.noto.quota_inv_EUR
        optTL.ownershipShare = M.quota_inv_EUR / sum(M.quota_inv_EUR);
    end

    TL = tri_level_ep_cer(genForShare, loadForShare, userNames, P_CER_h, optTL);

    report_allocation(TL, "Tri-level EP", [ ...
        string(sprintf('  %-25s: %d su %d membri (%s)', 'Vulnerabili (LIHC)', ...
                       TL.nVulnerable, nUsers, ...
                       strjoin(cellstr(TL.players(TL.isVulnerable)), ', '))), ...
        string(sprintf('  %-25s: %.2f%% del montepremi totale (n%% = %.2f%%, tetto %.0f%%)', ...
                       'Quota poverta'' energ.', 100*TL.shareEP, 100*TL.nPct, 100*TL.capEP)), ...
        string(sprintf('  %-25s: condivisa EUR %.2f + vendita EUR %.2f', ...
                       'Montepremi', TL.revShared, TL.revSold))]);

    fprintf('\n=== Ipotesi ancora attive (tri_level_ep_cer) ===\n');
    disp(TL.assumptions);

    % Il montepremi e' la somma dei due ricavi calcolati in §3: se non torna, il
    % metodo sta ripartendo una torta diversa da quella che la CER ha incassato.
    assert(abs(TL.vGrand - (sum(rev_shared_monthly) + rev_sold_annual)) ...
           < 1e-6 * max(1, rev_tot_annual), ...
           'Tri-level EP: montepremi incoerente con i ricavi della sezione 3');

    % La parte finanziata dall'energia condivisa deve valere esattamente v(N):
    % e' cio' che rende la colonna confrontabile con gli altri quindici metodi.
    assert(abs(sum(TL.phiFromShared) - sum(rev_shared_monthly)) ...
           < 1e-6 * max(1, sum(rev_shared_monthly)), ...
           'Tri-level EP: la quota da energia condivisa non somma a v(N)');

    % Test di degenerazione: azzerando la quota di solidarieta', il tri-livello
    % deve collassare ESATTAMENTE nello stato attuale del progetto, cioe' vendita
    % attribuita pro-quota ai proprietari (revSoldPerPlayer, §3) e montepremi
    % condiviso ripartito in proporzione al consumo. Se questo assert cade, e'
    % rotta la composizione dei livelli, non i dati segnaposto.
    % La chiave di proprieta' resta quella dedotta dalla produzione anche se la
    % scheda dichiara le quote di investimento: il test confronta phiFromSold con
    % la ripartizione PRO-QUOTA SULLA PRODUZIONE della §3, e con quote di
    % cofinanziamento diverse dalla produzione i due valori divergerebbero per
    % ragioni di modello, non di codice. E' la composizione dei livelli che si
    % vuole testare, non la chiave.
    optDeg = rmfield_if(optTL, 'ownershipShare');
    optDeg.nPct  = 0;
    optDeg.quiet = true;

    TLdeg = tri_level_ep_cer(genForShare, loadForShare, userNames, P_CER_h, optDeg);
    % Il confronto per singolo membro vale SOLO con un impianto. Con piu'
    % impianti le due grandezze rispondono a due domande diverse, entrambe
    % legittime e citate dal paper (Campagna et al. 2024, sez. 2.2.1):
    %   revSoldPerPlayer  la vendita resta al prosumer che l'ha prodotta,
    %                     attribuita ora per ora ("can be kept by the prosumer
    %                     with the installed PV plant"). E' lo stato attuale
    %                     del progetto, quello sommato agli altri quindici.
    %   phiFromSold       la vendita e' conferita alla CER e ridistribuita per
    %                     QUOTA DI INVESTIMENTO ("redirected from the prosumer
    %                     to the REC and split considering a sharing method").
    % Il criterio 1 della sez. 2.2.2 e' esplicito: la chiave Owners "pays back
    % who paid for the system, DISREGARDING WHERE THE SYSTEM IS LOCATED", cioe'
    % ignora di proposito la produzione. Con un impianto solo le due chiavi
    % coincidono per forza (ownKey e' un vettore indicatore) e il collasso e'
    % esatto; con piu' impianti divergono per modello, non per codice - il
    % paper lo dice nei risultati di Teglio: li' i due criteri si somigliavano
    % "only because the installations are located on the building of the same
    % members who invested [...] the results would be very different in a
    % different set-up". Questa CER e' quel different set-up.
    if height(CFG.impianti) == 1
        assert(max(abs(TLdeg.phiFromSold - revSoldPerPlayer)) < 1e-9 * max(1, rev_sold_annual), ...
               ['Tri-level EP: con n%% = 0 la ripartizione della vendita non coincide ' ...
                'con quella pro-quota della sezione 3']);
    else
        % Cio' che resta verificabile in generale: il montepremi di vendita
        % dev'essere ridistribuito per intero, senza crearne ne' perderne.
        assert(abs(sum(TLdeg.phiFromSold) - rev_sold_annual) < 1e-9 * max(1, rev_sold_annual), ...
               ['Tri-level EP: con n%% = 0 la vendita ridistribuita non somma ' ...
                'al ricavo da vendita della sezione 3']);
    end

    % --- Grafico a rete -------------------------------------------------------
    % Vendita a zero: per questo metodo e' GIA' dentro phi (vedi header), passarla
    % di nuovo la conterebbe due volte.
    if FIG.dettaglio, plot_benefit_network(TL.players, TL.phi, "Tri-level EP", zeros(nUsers, 1)); end


    %% ========================================================================
    %  3s) CONFRONTO TRA I MODELLI DI RIPARTIZIONE
    %
    %  Tabella e grafico riepilogativi che confrontano, sulla STESSA funzione
    %  caratteristica v(S), i modelli di ripartizione calcolati finora.
    %  Aggiungere un nuovo modello = una colonna nella tabella e un elemento
    %  nella struct "metodi", nient'altro.
    %
    %  NOTA: CT.vGrand (Cascading Tree) coincide col v(N) degli altri metodi
    %  solo perche' il default e' opts.reservoirFraction=0 (nessuna riserva
    %  trattenuta); con una riserva > 0 sarebbe legittimamente piu' piccolo -
    %  per costruzione, non per errore (vedi cascading_tree_cer.m).
    %
    %  NOTA: del Tri-level EP entra qui TL.phiFromShared, non TL.phi. Quel metodo
    %  ripartisce anche il ricavo di vendita, che per tutti gli altri sta fuori dal
    %  gioco ed e' impilato a parte nel grafico: usare TL.phi lo conterebbe due
    %  volte e la barra non sarebbe piu' confrontabile. Il totale sui due
    %  montepremi resta in TL.phi, riportato nella §3r.
    %  ========================================================================

    Tcmp = table(Sh.players(:), Sh.phi, Nu.phi, NB.phi, VLC.phi, ES.phi, PC.phi, ...
                 RM1.phi, CT.phi, WS.phi, PK.phi, PSK.phi, SU.phi, ...
                 MC.phi, SEV.phi, AS.phi, TL.phiFromShared, ...
                 'VariableNames', {'Giocatore', 'Shapley_EUR', 'Nucleolo_EUR', ...
                                   'NashBargaining_EUR', 'VarianceLeastCore_EUR', ...
                                   'EqualSplit_EUR', 'ProportionalConsumption_EUR', ...
                                   'RemunerationModel1_EUR', 'CascadingTree_EUR', ...
                                   'WeightedSolidarity_EUR', 'PearsonKey_EUR', ...
                                   'PearsonSharingRate_EUR', 'SimilarityUtilization_EUR', ...
                                   'MarginalContribution_EUR', 'StratifiedExpValue_EUR', ...
                                   'AdaptiveSampling_EUR', 'TriLevelEP_EUR'});
    fprintf('\n=== Confronto tra i modelli di ripartizione [€/anno] ===\n');
    disp(Tcmp);

    metodi = struct( ...
        'nome', {"Shapley", "Nucleolo", "Nash Bargaining", "Variance Least Core", ...
                  "Equal Split", "Proportional to Consumption", ...
                  "Remuneration Model 1", "Cascading Tree", "Weighted Solidarity", ...
                  "Pearson Key", "Pearson-Sharing Rate", "Similarity-Utilization", ...
                  "Marginal Contribution", "Stratified Expected Value", ...
                  "Adaptive Sampling Shapley", "Tri-level EP"}, ...
        'phi',  {Sh.phi,    Nu.phi,     NB.phi,            VLC.phi, ...
                  ES.phi,     PC.phi,   RM1.phi,           CT.phi,  WS.phi, ...
                  PK.phi,    PSK.phi,   SU.phi, ...
                  MC.phi,    SEV.phi,   AS.phi,  TL.phiFromShared});

    % --- Due grafici, due domande diverse ------------------------------------
    % Il grafico a barre tiene gli EURO e impila la vendita di eccedenza, che
    % sta fuori dal gioco cooperativo: risponde a "quanto incassa ciascuno".
    % La mappa tiene le QUOTE in percentuale di v(N): risponde a "che FORMA ha
    % questa ripartizione", ed e' l'unica delle due che regga sedici metodi -
    % con sedici barre per giocatore ciascuna e' larga 0.05 tick.
    if FIG.metodi
        plot_allocation_comparison(metodi, Sh.players, revSoldPerPlayer, ...
            sprintf('Confronto modelli di ripartizione  |  Totale CER = €%.0f  |  \\theta_{min}=%.0f €', ...
                    Nu.vGrand, Nu.thetaMin));

        plot_allocation_heatmap(metodi, Sh.players, Sh.vGrand, ...
            sprintf('Quote di ripartizione dei %d modelli  -  %s', ...
                    numel(metodi), CFG.cer.nome));
    end


    %% ========================================================================
    %  3t) INDICI DI VALUTAZIONE DELL'EQUITA'
    %
    %  Le sezioni §3b-§3s dicono QUANTO prende ciascuno con ciascun metodo, ma non
    %  dicono quale ripartizione sia piu' equa. Questa sezione li giudica, con dieci
    %  indicatori presi da tre articoli:
    %
    %    Dynge, Cali, "Distributive energy justice in local electricity markets:
    %    Assessing the performance of fairness indicators", Applied Energy 384
    %    (2025) 125463 - eq. 11, 12, 15, 16, 17, 18, 19.
    %
    %    Casalicchio, Manzolini, Prina, Moser, "From investment optimization to
    %    fair benefit distribution in renewable energy community modelling",
    %    Applied Energy 310 (2022) 118447 - eq. 10, 12-13, 14.
    %
    %    Volpato, Carraro, Dal Cin, Rech, "On the Different Fair Allocations of
    %    Economic Benefits for Energy Communities", Energies 17 (2024) 4788 - eq. 23.
    %
    %  Piu' il Gini e il Jain grezzi, che di quegli indici sono il nucleo (EI =
    %  1 - Gini, QoS = Jain) ed e' con quelli che ragiona la letteratura.
    %
    %  TRE DOMANDE DIVERSE. Gli indicatori non misurano la stessa cosa in modi
    %  diversi: rispondono a domande che possono dare risposte opposte.
    %    MinMax, QoS, EI, Gini, Jain   quanto e' UNIFORME la ripartizione
    %    Fairness Index                quanto e' vicina al MERITO di ciascuno
    %    Eccesso di coalizione         se REGGE, cioe' se qualche sottogruppo ha
    %                                  convenienza a uscire dalla CER
    %  L'Equal Split e' primo sulla prima domanda (EI = 1, Gini = 0) e ULTIMO sulla
    %  terza (nove coalizioni vorrebbero uscire). Guardare una colonna sola porta a
    %  conclusioni sbagliate.
    %
    %  DUE ESCLUSIONI MOTIVATE (dettagli in GUIDA §18)
    %    QoE (Dynge eq. 13-14) richiede il prezzo di mercato locale lambda_t, che
    %    in una CER a condivisione virtuale non esiste: tutti comprano dalla rete
    %    al prezzo retail e l'incentivo arriva ex post. Il paper stesso non ne
    %    propone modifiche e ne rinvia la valutazione ad altri meccanismi di
    %    prezzo (§6.2.1).
    %
    %    Price of Fairness (Volpato et al., stesso paper dell'eccesso di
    %    coalizione, eq. 21) confronta due OTTIMIZZAZIONI DI ESERCIZIO, le cui variabili
    %    decisionali sono i flussi P2G/P2P e la domanda spostabile. Qui quelle
    %    variabili non esistono - shared(t) = min(sum gen, sum load) e'
    %    deterministico, l'incentivo e' uniforme fra i membri, la domanda e'
    %    rigida - quindi il PoF sarebbe identicamente nullo per costruzione.
    %    Servirebbe aggiungere una leva operativa (load shifting o accumulo).
    %
    %  LEGGERE PRIMA I NUMERI: tre indici degenerano su questa topologia (un solo
    %  prosumer, attribuzione pro-quota, flussi fisici invarianti). Le avvertenze
    %  stanno negli header dei due moduli:
    %      help fairness_indicators_lem
    %      help fairness_index_bm
    %  ========================================================================

    % Baseline "senza CER" (y_noLEM dell'eq. 19): costo annuo di
    % approvvigionamento di ciascun membro con la PROPRIA tariffa, calcolato in
    % §3a. Prima si assumeva la monoraria per tutti; ora due membri con lo stesso
    % profilo ma contratti diversi hanno baseline diverse, che e' il punto
    % dell'indicatore.
    costNoCER = costUser;

    % --- Indice di comunita': eterogeneita' della composizione (eq. 10) -------
    % Non dipende da come si ripartiscono i benefici: descrive CHI c'e' nella CER.
    % La tipologia arriva da [MEMBRI].categoria, dichiarata, invece che dedotta
    % dal nome utente: due membri possono avere nomi simili e categorie diverse.
    HET = gini_heterogeneity(userNames, struct('memberTypes', M.categoria));

    % --- Indice di comunita': eterogeneita' di FORMA --------------------------
    % L'indice qui sopra conta le ETICHETTE, questo confronta i RITMI. Serve
    % perche' Shapley, Nucleolo e VLC si distinguono da una ripartizione
    % volumetrica solo se i membri consumano in momenti diversi: se le forme
    % fossero tutte uguali il confronto fra meccanismi non mostrerebbe nulla.
    % Carichi LORDI, come per l'indice categoriale: descrive chi c'e' nella CER,
    % non l'esito della condivisione. Il registro delle ipotesi (scelta della
    % metrica) resta in SHP.assumptions.
    SHP = shape_heterogeneity(loadUsers, userNames, ...
                              struct('memberTypes', M.categoria, 'quiet', true));

    fprintf('\n=== Indici di valutazione dell''equita'' ===\n');
    fprintf('  %-34s: %.4f  (%d tipologie su %d membri)\n', ...
            'Gini di eterogeneita'' (eq. 10)', HET.G, numel(HET.types), nUsers);
    fprintf('  %-34s: %.4f  (0 = stessi ritmi, 2 = mai sovrapposti)\n', ...
            'Eterogeneita'' di forma (L1)', SHP.L1);
    fprintf('  %-34s: %.4f dentro tipologia, %.4f fra tipologie\n', ...
            '  ripartita', SHP.dentroTipologia, SHP.traTipologie);

    % --- Un pacchetto di indicatori per ciascuno dei sedici metodi -----------
    nMet   = numel(metodi);
    FIND   = cell(nMet, 1);
    optInd = struct('costNoCER', costNoCER, 'monthOfHour', monthOfHour, 'quiet', true);
    for k = 1:nMet
        optInd.name = metodi(k).nome;
        FIND{k} = fairness_indicators_lem(metodi(k).phi, genForShare, loadForShare, optInd);
    end

    % Il MinMax originale misura il PRELIEVO DA RETE, che in una CER non cambia al
    % cambiare di chi prende i soldi: deve venire identico per tutti e sedici. Se
    % questo assert cade, qualcosa sta contaminando i flussi fisici con la
    % ripartizione monetaria.
    minMaxOrigAll = cellfun(@(F) F.minMaxOrig, FIND);
    assert(max(abs(minMaxOrigAll - minMaxOrigAll(1))) < 1e-12, ...
           ['Indici di equita'': il MinMax originale varia tra i metodi, ma in una ' ...
            'CER i flussi fisici sono invarianti rispetto alla ripartizione']);
    fprintf('  %-34s: %.4f  (uguale per tutti i metodi, vedi header sez. 3t)\n', ...
            'MinMax originale (eq. 11)', minMaxOrigAll(1));
    fprintf('  %-34s: %d prosumer, %d consumatori (rho = %.2f)\n', ...
            'Composizione', FIND{1}.nProsumer, FIND{1}.nConsumer, FIND{1}.rho);

    % Quanta energia condivisa e' davvero in palio. Nelle ore in cui l'immissione
    % copre l'intero carico residuo ognuno riceve esattamente il proprio carico e
    % nessuna chiave di ripartizione puo' cambiarlo: se questa frazione e' bassa,
    % gli indicatori ENERGETICI (MinMax_con, QoS, Jain) descrivono la comunita' e
    % non il metodo, ed e' normale che vengano quasi identici fra i sedici.
    fprintf('  %-34s: %.1f%% (%.0f kWh su %.0f) - il resto matura in ore in cui\n', ...
            'Energia contendibile', 100*FIND{1}.contendibleShare, ...
            FIND{1}.contendibleEnergy, FIND{1}.sharedTotal);
    fprintf('  %-34s  l''immissione copre l''intero carico e la chiave e'' ininfluente\n', '');

    % --- Fairness Index rispetto alla distribuzione per contributo (eq. 12-14)
    % BC_i = v(N) - v(N\{i}) e' gia' calcolato: e' MC.mcRaw della §3n.
    BM = fairness_index_bm([metodi.phi], MC.mcRaw, [metodi.nome], ...
                           struct('playerNames', Sh.players, 'quiet', true));

    % --- Stabilita': eccesso di coalizione (Volpato eq. 23) ------------------
    % Unica colonna che non guarda l'uniformita' della ripartizione ne' la sua
    % aderenza al merito, ma se REGGE: per ogni sottogruppo confronta quanto
    % genererebbe uscendo dalla CER con quanto riceve restandoci.
    EX = coalition_excess([metodi.phi], [metodi.nome], genForShare, loadForShare, ...
                          userNames, P_CER_h, struct('quiet', true));

    % --- Tabella di confronto -------------------------------------------------
    Tfair = table([metodi.nome].', ...
                  cellfun(@(F) F.minMaxPro, FIND), cellfun(@(F) F.minMaxCon, FIND), ...
                  cellfun(@(F) F.qosOrig,   FIND), cellfun(@(F) F.qosNew,    FIND), ...
                  cellfun(@(F) F.eiOrig,    FIND), cellfun(@(F) F.eiNew,     FIND), ...
                  cellfun(@(F) F.jain,      FIND), cellfun(@(F) F.gini,      FIND), ...
                  BM.FI, BM.sigma, BM.nZeroShare, EX.maxExcess, EX.nUnstable, ...
                  'VariableNames', {'Metodo', 'MinMax_pro', 'MinMax_con', ...
                                    'QoS_orig', 'QoS_new', 'EI_orig', 'EI_new', ...
                                    'Jain', 'Gini', 'FairnessIndex', 'Sigma', ...
                                    'QuoteNulle', 'EccessoMax_EUR', 'CoalizioniInstabili'});
    fprintf('\n=== Indicatori di equita'' per metodo ===\n');
    disp(Tfair);

    % La colonna QuoteNulle non e' decorativa: senza, il Fairness Index si legge
    % male. L'eq. 14 ha DUE branche e la seconda restituisce un INTERO, il numero
    % di membri lasciati a zero. Un FI di 1.00 con QuoteNulle = 1 vuol dire "un
    % membro escluso", non "distanza massima dal riferimento": e' un'altra unita' di
    % misura, e va confrontato solo con gli altri metodi che hanno quote nulle.
    if any(BM.nZeroShare > 0)
        fprintf(['  NOTA: %d metodi lasciano qualcuno a quota zero e finiscono nella\n' ...
                 '  branca INTERA dell''eq. 14 (FI = numero di esclusi). Il loro FI non\n' ...
                 '  e'' confrontabile con quello dei metodi a quote tutte positive.\n'], ...
                sum(BM.nZeroShare > 0));
    end

    % --- Stabilita' della coalizione, in dettaglio ---------------------------
    fprintf('\n=== Stabilita'': eccesso di coalizione (eq. 23) ===\n');
    fprintf(['  e_S = v(S) - somma delle quote di S. POSITIVO = quel sottogruppo\n' ...
             '  guadagnerebbe di piu'' uscendo dalla CER. Esaminate %d coalizioni proprie.\n'], ...
            EX.nCoalitions);
    disp(sortrows(EX.table, 'EccessoMax_EUR'));

    fprintf('\n=== Distribuzione di riferimento per contributo (eq. 13) ===\n');
    disp(BM.tablePlayers);

    fprintf('\n=== Ipotesi attive (indici di equita'') ===\n');
    disp(HET.assumptions);
    disp(FIND{1}.assumptions);
    disp(BM.assumptions);
    if BM.nZeroContribution > 0
        fprintf(['  ATTENZIONE: %d membri su %d hanno contributo marginale nullo. La\n' ...
                 '  distribuzione di riferimento e'' degenere e il Fairness Index premia\n' ...
                 '  chi concentra tutto sui membri pivotali: e'' un esito STRUTTURALE\n' ...
                 '  della topologia (un solo impianto), non un errore di calcolo.\n' ...
                 '  Vedi "COSA ASPETTARSI" in: help fairness_index_bm\n'], ...
                BM.nZeroContribution, nUsers);
    end

    % --- Diagnostica: energia implicita da phi vs energia nativa del metodo ---
    % Pearson Key e Pearson-Sharing Rate ripartiscono nativamente l'ENERGIA ora
    % per ora, gli altri quattordici solo gli euro. Qui si misura quanto la regola
    % implicita (pesi costanti pari a phi) si discosti da quella nativa. NON e' un
    % assert: uno scarto grande e' informazione sul metodo - vuol dire che la sua
    % chiave oraria e' molto diversa da una chiave piatta - non un errore.
    nativi = struct('nome', {"Pearson Key", "Pearson-Sharing Rate"}, ...
                    'SH',   {PK.SH,         PSK.SH});
    fprintf('\n=== Energia condivisa: implicita da phi vs nativa del metodo ===\n');
    for k = 1:numel(nativi)
        idx     = find([metodi.nome] == nativi(k).nome, 1);
        implNat = sum(nativi(k).SH, 1).';
        impl    = FIND{idx}.sharedByUser;
        fprintf('  %-24s: scarto L1 = %.2f%% dell''energia condivisa annua\n', ...
                nativi(k).nome, 100 * sum(abs(impl - implNat)) / sum(implNat));
    end

    % --- Verifiche ------------------------------------------------------------
    % Dominio: gli indicatori di Dynge sono rapporti o medie pesate di rapporti,
    % quindi stanno in [0,1]. Un valore fuori significa formula sbagliata, non
    % mercato strano.
    inDomain = @(v) all(isnan(v) | (v >= -1e-12 & v <= 1 + 1e-12));
    assert(inDomain(Tfair.MinMax_pro) && inDomain(Tfair.MinMax_con) && ...
           inDomain(Tfair.QoS_orig)   && inDomain(Tfair.QoS_new)   && ...
           inDomain(Tfair.EI_orig)    && inDomain(Tfair.EI_new)    && ...
           inDomain(Tfair.Jain)       && inDomain(Tfair.Gini), ...
           'Indici di equita'': un indicatore e'' uscito da [0,1]');

    % L'Equal Split distribuisce parti uguali: il Gini di un vettore uniforme e'
    % zero esatto, quindi il suo EI originale deve valere 1. E' il test piu' netto
    % su gini_index.
    iES = find([metodi.nome] == "Equal Split", 1);
    assert(abs(Tfair.EI_orig(iES) - 1) < 1e-12, ...
           'Indici di equita'': EI originale dell''Equal Split diverso da 1');

    % La normalizzazione dell'eq. 10 di Cremers coincide con l'eq. 13 di
    % Casalicchio: MC.phi/v(N) E' la distribuzione di riferimento. Quindi la
    % Marginal Contribution ha FI nullo se tutti i contributi sono positivi, e
    % altrimenti cade nella branca degli interi con FI = numero di quote nulle.
    iMC = find([metodi.nome] == "Marginal Contribution", 1);
    if all(MC.mcRaw > 0)
        assert(abs(BM.FI(iMC)) < 1e-9, ...
               'Indici di equita'': la Marginal Contribution non ha FI = 0');
    else
        assert(BM.FI(iMC) == nUsers - sum(BM.D(:,iMC) > 1e-9), ...
               'Indici di equita'': branca degli interi dell''eq. 14 incoerente');
    end

    % L'energia implicita deve restare energia della CER: quello che si attribuisce
    % ai membri e' esattamente l'energia condivisa di comunita', ne' piu' ne' meno.
    assert(abs(sum(FIND{1}.sharedByUser) - shared_annual) < 1e-6 * max(1, shared_annual), ...
           'Indici di equita'': l''energia attribuita non somma a quella condivisa');

    % Il Nucleolo MINIMIZZA per costruzione l'eccesso della coalizione piu'
    % scontenta, e lo dichiara come surplus (segno opposto: thetaMin = -e_max). Se
    % queste due grandezze non coincidono, o l'eccesso e' calcolato su una v(S)
    % diversa da quella del gioco, oppure il Nucleolo non sta risolvendo il suo
    % problema. Il Variance Least Core deve dare lo stesso valore, avendo lo stesso
    % livello di Least Core (gia' confrontato in §3e).
    iNu  = find([metodi.nome] == "Nucleolo", 1);
    iVLC = find([metodi.nome] == "Variance Least Core", 1);
    tolEx = 1e-6 * max(1, abs(EX.vGrand));
    assert(abs(EX.maxExcess(iNu) + Nu.thetaMin) < tolEx, ...
           'Indici di equita'': eccesso massimo del Nucleolo diverso da -thetaMin');
    %
    % Il VLC va verificato con la SUA tolleranza, non con tolEx. Nucleolo ed
    % eccessi sono esatti; il VLC no, per costruzione: la row-generation
    % rilassa i vincoli del master di tolConv, quindi la sua allocazione si
    % appoggia al bordo rilassato del Least Core e l'eccesso massimo risulta
    % piu' alto di -thetaLC di esattamente quel rilassamento. Confrontarlo con
    % tolEx (= meta' di tolConv) faceva fallire l'assert su qualunque CER in
    % cui il vincolo di Least Core e' attivo, cioe' quasi sempre: era la
    % soglia a essere sbagliata, non l'allocazione. Lo scarto residuo vale
    % frazioni di centesimo di euro e non tocca nessun risultato economico.
    assert(abs(EX.maxExcess(iVLC) + VLC.thetaLC) < max(tolEx, VLC.tolConv), ...
           'Indici di equita'': eccesso massimo del VLC diverso da -thetaLC');

    % ...e deve essere il MINIMO fra tutti i metodi, di nuovo per costruzione.
    assert(EX.maxExcess(iNu) <= min(EX.maxExcess) + tolEx, ...
           'Indici di equita'': il Nucleolo non e'' il metodo con eccesso minimo');

    % --- Mappa di calore ------------------------------------------------------
    % Un pannello per DOMANDA (vedi header): uniformita', merito, stabilita'. Non
    % si possono mettere sulla stessa scala perche' hanno versi diversi - e per
    % l'eccesso di coalizione il meglio non sta ne' a 0 ne' a 1, ma il piu' in
    % basso possibile, anche molto sotto zero.
    pannelli = struct( ...
        'nome',       {'Allocazione ed equita''',                         'Disuguaglianza e distanza dal merito',            'Stabilita'' della coalizione'}, ...
        'indicatori', {["MinMax_{pro}", "MinMax_{con}", "QoS_{orig}", "QoS_{new}", ...
                        "EI_{orig}", "EI_{new}", "Jain"],                 ["Gini", "Fairness Index", "\sigma"],              ["Eccesso max [€]", "Coalizioni instabili"]}, ...
        'valori',     {[Tfair.MinMax_pro, Tfair.MinMax_con, Tfair.QoS_orig, ...
                        Tfair.QoS_new, Tfair.EI_orig, Tfair.EI_new, Tfair.Jain], ...
                                                                          [Tfair.Gini, Tfair.FairnessIndex, Tfair.Sigma],    [Tfair.EccessoMax_EUR, Tfair.CoalizioniInstabili]}, ...
        'bestIsOne',  {true,                                              false,                                             false}, ...
        'etichettaVerso', {'',                                            '',                                                'piu'' basso = piu'' stabile'});

    % Titolo su due righe: la seconda porta gli indici di COMUNITA', che non hanno
    % una colonna nella mappa perche' non dipendono dal metodo, piu' la frazione di
    % energia contendibile - senza la quale le colonne energetiche quasi costanti
    % sembrerebbero un errore invece che il risultato che sono.
    if FIG.equita
        plot_fairness_indicators([metodi.nome], pannelli, [ ...
            "Indici di equita' distributiva dei sedici modelli di ripartizione"; ...
            sprintf(['MinMax originale = %.2f (uguale per tutti)  |  Gini di eterogeneita'' = %.2f' ...
                     '  |  energia contendibile = %.1f%%'], ...
                    minMaxOrigAll(1), HET.G, 100*FIND{1}.contendibleShare)]);

        % --- Il Fairness Index, aperto per membro ----------------------------
        % La mappa qui sopra del Fairness Index tiene solo lo scalare: dice
        % QUANTO un metodo si discosta dal merito, non da che parte. BM.deviation
        % e' gia' calcolato e porta il segno membro per membro.
        plot_merit_deviation(BM, Sh.players, [metodi.nome]);

        % --- La sintesi: uniformita' contro stabilita' ------------------------
        % Le tre domande della §3t possono dare risposte opposte, e nella mappa
        % di calore stanno in pannelli separati con scale normalizzate per
        % colonna: il rapporto fra loro va ricostruito a mente. Sul piano si
        % vede, e con esso quali metodi sono scelte difendibili e quali sono
        % dominati da un altro su entrambi i criteri.
        plot_fairness_tradeoff(Tfair, Sh.vGrand, ...
            sprintf('Uniformita'' contro stabilita''  -  %s', CFG.cer.nome));
    end


    %% ========================================================================
    %  4) COSTO ENERGIA DA RETE (PUN 2025)
    %  Costo annuo di approvvigionamento per ogni utente e per ogni modalita'
    %  tariffaria, calcolato in §3a. I profili prezzo del 2025 condividono la
    %  griglia canonica.
    %  ========================================================================

    Tcost = array2table(costMat, ...
            'VariableNames', cellstr(Modalita), ...
            'RowNames', cellstr(userNames));
    Tcost{'COMUNITA', :} = sum(costMat, 1);      % riga con il totale comunita'

    % Le tre colonne sono il confronto; queste due dicono quale vale davvero.
    % La spesa annua non e' un dato della scheda: si ottiene incrociando la
    % tariffa dichiarata dal membro con il suo profilo di carico orario.
    Tcost.Tariffa   = [M.tariffa; "-"];
    Tcost.Effettivo = [costUser;  sum(costUser)];

    fprintf('\n=== Costo annuo energia da rete (PUN 2025) [€] ===\n');
    fprintf(['  Le prime tre colonne confrontano le modalita'' tariffarie; ' ...
             '"Effettivo" e'' la spesa\n  con la tariffa che ciascun membro ha ' ...
             'davvero ([MEMBRI].tariffa nella scheda).\n']);
    disp(Tcost);


    %% ========================================================================
    %  5) VISUALIZZAZIONE
    %
    %  Le tre figure "d'insieme" (mensili, PV vs domanda, profili tipo) sono
    %  quelle storiche. Le tre nuove guardano la stessa energia da tre angoli
    %  che gli aggregati mensili e le medie giornaliere non possono dare:
    %  l'ORA in cui la CER condivide, la DURATA delle grandezze in gioco, e il
    %  PREZZO a cui quell'energia viene incentivata.
    %  ========================================================================

    if FIG.energia
        plot_cer_energy(meseNomi, shared_monthly, shared_annual, ...
                        rev_shared_monthly, rev_sold_monthly, rev_tot_annual);

        plot_pv_vs_demand(gen_24x365, demand_24x365, shared_24x365, N_DAYS);

        % --- Ore sature: quelle in cui la chiave di ripartizione non conta ---
        % Stessa espressione di fairness_indicators_lem, ed e' il punto: se le
        % due divergessero, la mappa direbbe una cosa e il numero stampato in
        % §3t un'altra. L'assert lega la figura a quel numero invece di
        % lasciarle libere di scollarsi in silenzio.
        oreSature = shared > 0 & genPVSurplus >= loadTotalForShare;
        assert(sum(oreSature) == FIND{1}.nSaturatedHours, ...
               ['Mappa oraria: la maschera di saturazione non coincide con quella ' ...
                'degli indici di equita'' (§3t)']);

        % Tre stati per ora: 0 nessuna condivisione, 1 contendibile, 2 satura.
        statoOra = zeros(N_HOURS, 1);
        statoOra(shared > 0)  = 1;
        statoOra(oreSature)   = 2;

        plot_hourly_map(shared_24x365, sold_24x365, reshape(statoOra, 24, N_DAYS), ...
                        FIND{1}.contendibleShare, ANNO);

        plot_duration_curves(genPVSurplus, loadTotalForShare, shared, sold);

        plot_incentive_price(tGrid, Pz_h, P_CER_h, shared, meseNomi);
    end

    if FIG.profili
        plot_load_profiles(tGrid, loadUsers, userNames, ANNO);
    end


    %% ====================================================================
    %  6) RISULTATI DI QUESTA CER
    %
    %  L'ultima cosa del giro. Quello che serve dopo il ciclo va messo via
    %  adesso, perche' il clearvars del giro successivo cancella tutto il
    %  resto. Le tabelle si portano dietro i nomi dei membri, quindi restano
    %  leggibili anche accanto a CER di taglia diversa.
    %  ====================================================================

    RESULTS(iCER).scheda         = SCHEDA;
    RESULTS(iCER).nome           = CFG.cer.nome;
    RESULTS(iCER).nUsers         = nUsers;
    RESULTS(iCER).userNames      = userNames;
    RESULTS(iCER).Tcmp           = Tcmp;
    RESULTS(iCER).Tfair          = Tfair;
    RESULTS(iCER).metodi         = metodi;
    RESULTS(iCER).shared_annual  = shared_annual;
    RESULTS(iCER).sold_annual    = sold_annual;
    RESULTS(iCER).rev_tot_annual = rev_tot_annual;
    RESULTS(iCER).CFG            = CFG;

    % Serviti dal confronto fra CER della §7, e non ricavabili da quello che
    % c'e' gia': v(N) e' il montepremi in palio (il resto del ricavo e'
    % vendita, che sta fuori dal gioco), la frazione contendibile dice quanto
    % la scelta del metodo conti davvero, e isProsumer e' l'unico modo di
    % sommare le quote per categoria quando i membri cambiano da una CER
    % all'altra.
    RESULTS(iCER).vGrand           = Sh.vGrand;
    RESULTS(iCER).contendibleShare = FIND{1}.contendibleShare;
    RESULTS(iCER).isProsumer       = FIND{1}.isProsumer;

    % Il tempo dell'ANALISI, letto prima di salvare le figure: sono due lavori
    % di natura diversa e conviene tenerli separati. Il calcolo e' quello che
    % non si puo' evitare; l'export delle figure e' un servizio, si spegne con
    % un flag, ed e' spesso il piu' lento dei due - un PDF vettoriale con
    % migliaia di punti costa piu' di un'intera ripartizione. Sommarli darebbe
    % un numero solo, da cui non si capisce cosa valga la pena di togliere.
    tempoAnalisi = toc(T_CER);

    % --- Le figure di questa CER su file -------------------------------------
    % Una cartella per scheda, cosi' i nomi delle figure non collidono fra
    % comunita'. Chiudere le finestre e' anche cio' che fa partire pulito il
    % giro successivo: MAIN.m fa close all una volta sola, in testa.
    if FIG.esporta
        [~, nomeScheda] = fileparts(SCHEDA);
        fprintf('\n=== Figure di %s ===\n', nomeScheda);
        save_figures(fullfile(FIG.cartella, nomeScheda), ...
                     struct('chiudi', FIG.chiudi));
    end

    RESULTS(iCER).tempo_analisi_s = tempoAnalisi;
    RESULTS(iCER).tempo_figure_s  = toc(T_CER) - tempoAnalisi;

    fprintf('\n=== Tempi di %s ===\n', CFG.cer.nome);
    fprintf('  %-25s: %s\n', 'Analisi',  format_duration(RESULTS(iCER).tempo_analisi_s));
    fprintf('  %-25s: %s\n', 'Figure',   format_duration(RESULTS(iCER).tempo_figure_s));
    fprintf('  %-25s: %s\n', 'Totale CER', format_duration(toc(T_CER)));

end


%% ========================================================================
%  7) CONFRONTO FRA LE COMUNITA' ANALIZZATE
%
%  Dentro il ciclo una CER non puo' vedere le altre: il clearvars di ogni giro
%  azzera tutto, ed e' voluto. Qui invece RESULTS le ha tutte, e si puo'
%  finalmente chiedere cosa cambi al cambiare della comunita' - quanto pesa un
%  prosumer in piu' sul bilancio, sul montepremi in palio e sulle quote che
%  ciascun modello assegna.
%
%  Si confrontano solo grandezze di comunita' e grandezze NORMALIZZATE: le CER
%  hanno un numero di membri diverso, e "il terzo utente" non e' la stessa
%  persona in due schede diverse.
%  ========================================================================

if FIG.confrontoCER && N_CER > 1
    plot_cer_comparison(RESULTS);

    % Il Gini su tre assi: comunita' x metodo x indice. Il pannello (d) del
    % grafico qui sopra riassume in un numero per CER quanto la scelta del
    % metodo sposti il Gini; questo tiene tutte le coppie e mostra anche QUALE
    % metodo faccia cosa, e se l'ordine fra i metodi regga al cambio di
    % comunita'.
    plot_gini_3d(RESULTS);

    if FIG.esporta
        fprintf('\n=== Figure di confronto fra CER ===\n');
        save_figures(fullfile(FIG.cartella, "confronto"), ...
                     struct('chiudi', FIG.chiudi));
    end

end

%% ========================================================================
%  8) TEMPO DI ESECUZIONE
%
%  Il conto si chiude qui, e si chiude DAVVERO: la somma dei tempi per
%  comunita' piu' il confronto della §7 deve dare il totale, senza un residuo
%  non spiegato. E' anche il modo di accorgersi se qualcosa sta costando dove
%  non ce lo si aspetta.
%
%  Analisi e figure restano separate perche' si governano in modo diverso: il
%  calcolo e' quello che serve, l'export delle figure si spegne con FIG.esporta
%  e i grafici di dettaglio con FIG.dettaglio. Sapere quale delle due voci pesa
%  e' l'unico modo per decidere cosa togliere quando l'esecuzione e' lenta.
%  ========================================================================

tempoAnalisiTot = sum([RESULTS.tempo_analisi_s]);
tempoFigureTot  = sum([RESULTS.tempo_figure_s]);
tempoTotale     = toc(T_TOT);

% Quello che resta e' la §7 (confronto fra CER e relativo export): non
% appartiene a nessuna comunita' e non ha un cronometro proprio, ma va
% dichiarato lo stesso, altrimenti il totale non tornerebbe e non si capirebbe
% perche'.
tempoConfronto = tempoTotale - tempoAnalisiTot - tempoFigureTot;

fprintf('\n\n=== Tempo di esecuzione ===\n');
for c = 1:N_CER
    [~, nomeScheda] = fileparts(RESULTS(c).scheda);
    fprintf('  %-22s  analisi %10s   figure %10s\n', nomeScheda, ...
            format_duration(RESULTS(c).tempo_analisi_s), ...
            format_duration(RESULTS(c).tempo_figure_s));
end
% Solo ASCII nelle stringhe STAMPATE: il paragrafo e l'euro esistono nei
% commenti di questo file, ma passando dallo stdout di MATLAB in modalita'
% batch escono corrotti, e un riepilogo di tempi illeggibile e' peggio che uno
% senza simboli.
fprintf('  %-22s  %s\n', '-- somma analisi',   format_duration(tempoAnalisiTot));
fprintf('  %-22s  %s\n', '-- somma figure',    format_duration(tempoFigureTot));
fprintf('  %-22s  %s\n', '-- confronto CER',   format_duration(tempoConfronto));
fprintf('  %-22s  %s\n', 'TOTALE',             format_duration(tempoTotale));

fprintf('\n=== Analizzate %d CER in %s. I risultati sono in RESULTS. ===\n', ...
        N_CER, format_duration(tempoTotale));
