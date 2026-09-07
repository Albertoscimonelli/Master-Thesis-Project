function [P_rif_kW, info] = cer_tip_bracket_power(impianti, potenzaImposta, opts)
%CER_TIP_BRACKET_POWER  Potenza che seleziona lo scaglione TP_base/CAP della
%   tariffa premio, presa sul SINGOLO IMPIANTO e non sulla somma di comunita'
%   (Regole Operative GSE del 16 luglio 2025, par. 2.2.2.1.2 e par. 1.2.1.2;
%   Decreto CACER, DM MASE 7 dicembre 2023 n. 414, Allegato 1).
%
%   LO SCAGLIONE E' DELL'IMPIANTO, NON DELLA COMUNITA'
%     "TP_base e' il valore base della tariffa, cosi' definito in base al valore
%     della POTENZA IMPIANTO/SEZIONE DELLA MEDESIMA UP" (par. 2.2.2.1.2), e lo
%     stesso vale per il CAP. Sommare le potenze di tutti gli impianti - come
%     faceva MAIN.m prima di questa funzione - fa scivolare l'intera comunita'
%     in uno scaglione peggiore appena il TOTALE supera i 200 kW, anche quando
%     nessun impianto ci arriva nemmeno vicino.
%
%     Non e' un caso di scuola: succedeva a due schede su sette. CER_0_7_0 ha
%     sette impianti per 225,6 kW complessivi, il maggiore da 76; CER_1_6_0 ne
%     ha sei per 213,6 kW. Entrambe finivano in 70/110 invece che in 80/120.
%
%     Il costo era esattamente 10 EUR/MWh in OGNI ora, non una media: siccome
%     CAP - TP_base vale 40 in tutti e tre gli scaglioni, la spezzata
%     min(CAP; TP_base + max(0; 180 - Pz)) di due scaglioni adiacenti e' la
%     stessa curva traslata di dieci, qualunque sia il prezzo zonale.
%
%   QUAL E' L'UNITA': IL PUNTO DI CONNESSIONE
%     "La potenza di un impianto, ai fini dell'accesso alla tariffa
%     incentivante, verra' calcolata come somma delle potenze delle sezioni che
%     compongono le unita' di produzione, alimentate dalla stessa fonte e
%     COLLEGATE ALLO STESSO PUNTO DI CONNESSIONE alla rete elettrica"
%     (par. 1.2.1.2). L'unita' non e' quindi la riga della scheda, e non e' il
%     membro: e' il POD.
%
%     La colonna [IMPIANTI].pod e' facoltativa proprio per questo. Quando c'e',
%     le righe che condividono un POD si sommano PRIMA di scegliere lo
%     scaglione; quando manca, una riga vale un impianto - che e' poi il
%     significato del suo campo id. Sulle schede attuali non c'e' e non
%     cambierebbe nulla: in CER_0_7_0 office_1_kWh possiede PV04 e PV06 da
%     50,8 kW, e 101,6 kW restano nel primo scaglione tanto sommati quanto no.
%
%     NON e' modellato l'artato frazionamento del par. 1.2.1.5, che aggrega
%     impianti della stessa fonte su particelle catastali contigue e dello
%     stesso produttore ANCHE se su POD diversi. Servirebbe la particella
%     catastale, che la scheda non porta; e la norma stessa lo esclude per gli
%     impianti "inseriti in distinti edifici/condomini", che senza il dato
%     sull'edificio non si sanno riconoscere. Vedi README par. 14.4.1.
%
%   PERCHE' UNA POTENZA SOLA, E NON UNA TARIFFA PER IMPIANTO
%     A rigore, con impianti in scaglioni diversi le tariffe sono diverse. Il
%     GSE pubblica infatti "l'energia condivisa incentivabile ripartita per UP"
%     e "il valore della tariffa premio applicata a ogni impianto incentivato"
%     (par. 2.2.2), e l'Appendice A dice come si ripartisce quell'energia: "a
%     partire dalle immissioni degli impianti di produzione entrati prima in
%     esercizio". Il contributo sarebbe allora
%
%         C_ACI = somma su p, h di   E_ACI(p,h) * TIP(p,h)
%
%     Qui non serve, perche' nessun impianto delle schede supera i 200 kW:
%     stanno tutti nel primo scaglione e la tariffa resta una sola. Invece di
%     implementare una ripartizione per UP che non cambierebbe un solo numero,
%     questa funzione VERIFICA che il caso semplice regga, e si ferma con un
%     errore parlante il giorno in cui non reggesse piu'. La regola generale e'
%     scritta per esteso in README par. 14.4.1: sta li' e non nel codice per
%     scelta, non per dimenticanza.
%
%   PERCHE' TP_base E CAP NON STANNO QUI
%     Restano in compute_cer_incentive.m. Questa funzione decide QUALE POTENZA
%     guardare, non quanto vale la tariffa. Ricopiare qui i tre valori per
%     poterli stampare darebbe due sorgenti della stessa verita', che e'
%     esattamente il modo in cui due numeri finiscono per divergere in
%     silenzio: info.scaglione dice in quale fascia si cade, e i coefficienti
%     di quella fascia continuano ad avere un solo posto dove sono scritti.
%
%   INPUT
%     impianti        table    la [IMPIANTI] della scheda (CFG.impianti).
%                              Serve la colonna kWp [kW]; id e pod se presenti.
%     potenzaImposta  scalare  [MERCATO].tip_potenza_rif_kW, se dichiarata;
%                              NaN o vuoto = non imposta -> si deriva     [kW]
%     opts            struct opzionale:
%                       .soglie        [1 x 2] confini degli scaglioni, in kW
%                                      (def. [200 600], par. 2.2.2.1.2)
%                       .validateSelf  auto-test analitico (def. true)
%
%   OUTPUT
%     P_rif_kW  scalare  potenza da passare a compute_cer_incentive       [kW]
%     info      struct   .fonte      "imposta" | "derivata"
%                        .unita      [m x 1] string, etichetta dell'unita'
%                        .potenze    [m x 1] potenza per unita'           [kW]
%                        .scaglione  [m x 1] indice di scaglione (1, 2, 3)
%                        .soglie     [1 x 2] i confini usati              [kW]
%                        .aggregato  true se la colonna pod ha unito righe
%
%   Vedi anche: compute_cer_incentive, cer_reduction_factor, load_cer_input, MAIN

    if nargin < 2, potenzaImposta = NaN; end
    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'soglie'), opts.soglie = [200 600]; end

    soglie   = double(opts.soglie(:)).';
    autotest = ~isfield(opts, 'validateSelf') || opts.validateSelf;

    % --- Potenza imposta dalla scheda: vince e chiude ------------------------
    % E' la scappatoia gia' prevista da [MERCATO].tip_potenza_rif_kW, e serve a
    % riprodurre un conguaglio GSE gia' emesso senza dover ricostruire da quale
    % configurazione di impianti fosse nato. Chi la dichiara sta dicendo "so io
    % quale scaglione voglio": non c'e' niente da derivare e niente da
    % verificare.
    imposta = ~(isempty(potenzaImposta) || ...
                (isnumeric(potenzaImposta) && all(isnan(potenzaImposta))));

    if imposta
        P_rif_kW = double(potenzaImposta);
        info = struct('fonte',     "imposta", ...
                      'unita',     "(imposta in scheda)", ...
                      'potenze',   P_rif_kW, ...
                      'scaglione', local_scaglione(P_rif_kW, soglie), ...
                      'soglie',    soglie, ...
                      'aggregato', false);
        if autotest, local_validate_self(); end
        return
    end

    % --- Un'unita' per POD, o una per riga se il POD non c'e' ----------------
    [unita, potenze, aggregato] = local_aggrega(impianti);
    scaglione = arrayfun(@(p) local_scaglione(p, soglie), potenze);

    % --- La guardia -----------------------------------------------------------
    % Da qui in poi il modello applica UNA tariffa a tutta l'energia condivisa.
    % Se gli impianti non condividono lo scaglione quell'ipotesi salta, e non
    % c'e' una potenza rappresentativa che possa salvarla: meglio fermarsi
    % rumorosamente che scegliere per conto di chi legge.
    if numel(unique(scaglione)) > 1
        righe = compose("    %-14s %8.1f kW   scaglione %d", ...
                        unita, potenze, scaglione);
        error('cer_tip_bracket_power:scaglioniMisti', ...
              ['Gli impianti della configurazione cadono in scaglioni di ' ...
               'potenza DIVERSI:\n%s\n\n' ...
               'Il modello applica una sola tariffa a tutta l''energia ' ...
               'condivisa, e con scaglioni diversi quell''ipotesi non regge ' ...
               'piu''. Il decreto vuole una tariffa per impianto e l''energia ' ...
               'condivisa ripartita per UP "a partire dalle immissioni degli ' ...
               'impianti di produzione entrati prima in esercizio" (Regole ' ...
               'Operative GSE 16/07/2025, par. 2.2.2 e Appendice A).\n' ...
               'La regola completa e'' in README par. 14.4.1: non e'' ' ...
               'implementata perche'' finora nessun impianto superava i %g kW.\n' ...
               'Scappatoia immediata: dichiarare [MERCATO].tip_potenza_rif_kW ' ...
               'per imporre uno scaglione unico, sapendo che e'' ' ...
               'un''approssimazione.'], ...
              strjoin(righe, newline), soglie(1));
    end

    % Tutte le unita' sono nello stesso scaglione, quindi qualunque potenza fra
    % le loro lo seleziona. Si prende la maggiore perche' e' la potenza di un
    % impianto VERO: se un domani la guardia dovesse sbagliare, il numero che
    % arriva a compute_cer_incentive resta quello dell'impianto piu' grande, che
    % e' l'errore prudente.
    P_rif_kW = max(potenze);

    info = struct('fonte',     "derivata", ...
                  'unita',     unita, ...
                  'potenze',   potenze, ...
                  'scaglione', scaglione, ...
                  'soglie',    soglie, ...
                  'aggregato', aggregato);

    if autotest, local_validate_self(); end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function k = local_scaglione(P_kW, soglie)
%LOCAL_SCAGLIONE  Indice di scaglione: 1 fino alla prima soglia, poi 2, poi 3.
%
%   Confini INCLUSIVI verso il basso ("P_i <= 200 kW" nel par. 2.2.2.1.2), che
%   e' anche il modo in cui li scrive compute_cer_incentive: un impianto da
%   esattamente 200 kW sta nel primo scaglione.

    k = 1 + sum(P_kW > soglie);
end


function [unita, potenze, aggregato] = local_aggrega(impianti)
%LOCAL_AGGREGA  Somma i kWp delle righe che condividono un POD.
%
%   Le righe senza POD dichiarato restano ciascuna un'unita' a se': un POD
%   vuoto non e' un POD condiviso con gli altri vuoti, e' un dato che manca.
%   Cosi' una scheda compilata a meta' aggrega quello che sa e lascia stare il
%   resto, invece di fondere in un'unica unita' tutti gli impianti che tacciono.

    nomi = string(impianti.Properties.VariableNames);

    if ~ismember("kWp", nomi)
        error('cer_tip_bracket_power:kWpMancante', ...
              ['[IMPIANTI] non ha la colonna kWp: senza la potenza di ' ...
               'ciascun impianto lo scaglione della tariffa non e'' definito.']);
    end
    kWp = double(impianti.kWp(:));

    if ismember("id", nomi)
        etichetta = string(impianti.id(:));
    else
        etichetta = "riga " + string((1:numel(kWp)).');
    end

    chiave    = etichetta;      % default: una riga, un impianto
    aggregato = false;

    if ismember("pod", nomi)
        % Colonna di testo: load_cer_input riduce a stringa vuota sia '?' sia
        % '-', quindi "dichiarato" vuol dire "non vuoto".
        pod   = string(impianti.pod(:));
        haPod = ~ismissing(pod) & strlength(pod) > 0;
        chiave(haPod) = "POD " + pod(haPod);
        aggregato     = numel(unique(chiave)) < numel(chiave);
    end

    [unita, ~, g] = unique(chiave, 'stable');   % 'stable': ordine della scheda
    potenze       = accumarray(g, kWp);

    unita   = unita(:);
    potenze = potenze(:);
end


function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test analitico su casi costruiti a penna.
%
%   Convenzione del progetto (cer_reduction_factor.m, fairness_index_bm.m):
%   niente cartella di test, l'auto-test sta nel modulo ed e' acceso di
%   default. Qui costa qualche decina di operazioni su tabelle di sette righe.
%
%   Il caso 2 e' quello che conta: e' il bug che questa funzione esiste per
%   correggere, scritto coi numeri veri di CER_0_7_0.

    o = struct('validateSelf', false);
    T = @(id, kWp) table(string(id(:)), double(kWp(:)), ...
                         'VariableNames', {'id', 'kWp'});

    % --- 1) Un impianto solo: la potenza e' la sua ---------------------------
    % E' la non-regressione piu' diretta: con un impianto solo somma e singolo
    % coincidono, quindi il comportamento deve essere identico a prima.
    assert(cer_tip_bracket_power(T("PV01", 76), NaN, o) == 76, ...
           'cer_tip_bracket_power: con un impianto solo la potenza e'' la sua');

    % --- 2) Il caso CER_0_7_0: la somma cadrebbe in un altro scaglione -------
    kWp07 = [76; 12; 12; 50.8; 12; 50.8; 12];       % 225,6 kW in sette impianti
    P07   = cer_tip_bracket_power( ...
                T(["PV01";"PV02";"PV03";"PV04";"PV05";"PV06";"PV07"], kWp07), NaN, o);
    assert(P07 == 76, ...
           'cer_tip_bracket_power: deve vincere l''impianto maggiore, non la somma');
    assert(local_scaglione(sum(kWp07), [200 600]) == 2 && ...
           local_scaglione(max(kWp07), [200 600]) == 1, ...
           ['cer_tip_bracket_power: il caso di prova non discrimina piu'' - la ' ...
            'somma deve cadere in uno scaglione diverso dal singolo impianto, ' ...
            'altrimenti non sta verificando nulla']);

    % --- 3) Confini inclusivi verso il basso ---------------------------------
    assert(local_scaglione(200, [200 600]) == 1, 'a 200 kW si sta nel primo scaglione');
    assert(local_scaglione(200.1, [200 600]) == 2, 'sopra 200 kW si passa al secondo');
    assert(local_scaglione(600, [200 600]) == 2, 'a 600 kW si sta nel secondo');
    assert(local_scaglione(600.1, [200 600]) == 3, 'sopra 600 kW si passa al terzo');

    % --- 4) Il POD aggrega prima di scegliere lo scaglione -------------------
    Tpod = table(["SEZ_A"; "SEZ_B"], [12; 190], ["POD1"; "POD1"], ...
                 'VariableNames', {'id', 'kWp', 'pod'});
    [Ppod, iPod] = cer_tip_bracket_power(Tpod, NaN, o);
    assert(Ppod == 202 && iPod.scaglione == 2 && iPod.aggregato, ...
           ['cer_tip_bracket_power: due sezioni sullo stesso POD sono un solo ' ...
            'impianto da 202 kW (par. 1.2.1.2), quindi secondo scaglione']);

    % Senza la colonna pod le stesse due righe sono due impianti, entrambi nel
    % primo scaglione: e' la prova che l'aggregazione la fa il POD e non altro.
    assert(cer_tip_bracket_power(T(["SEZ_A"; "SEZ_B"], [12; 190]), NaN, o) == 190, ...
           'cer_tip_bracket_power: senza pod le righe restano impianti distinti');

    % --- 5) Scaglioni misti: errore, non una scelta silenziosa ---------------
    esito = 'nessun errore';
    try
        cer_tip_bracket_power(T(["PV01"; "PV02"], [76; 300]), NaN, o);
    catch ME
        esito = ME.identifier;
    end
    assert(strcmp(esito, 'cer_tip_bracket_power:scaglioniMisti'), ...
           ['cer_tip_bracket_power: con impianti in scaglioni diversi deve ' ...
            'fermarsi, non scegliere una potenza per conto di chi legge']);

    % --- 6) La potenza imposta vince ----------------------------------------
    [Pimp, iImp] = cer_tip_bracket_power(T(["PV01"; "PV02"], [76; 300]), 500, o);
    assert(Pimp == 500 && iImp.fonte == "imposta", ...
           ['cer_tip_bracket_power: tip_potenza_rif_kW deve avere la ' ...
            'precedenza, anche sugli scaglioni misti']);
end
