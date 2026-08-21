function M = align_members_to_users(CFG, userNames)
%ALIGN_MEMBERS_TO_USERS  Riordina i membri della scheda dati sull'ordine
%   delle colonne dei profili di carico.
%
%   L'identita' dei giocatori nasce dal CSV: load_cer_data prende come utente
%   OGNI colonna numerica di profili_tutti.csv, e quell'ordine e' l'ordine di
%   tutti i vettori [nUsers x 1] del progetto. La scheda dati e' scritta a
%   mano e puo' elencare i membri in tutt'altro ordine. Questa funzione fa
%   combaciare le due cose, una volta sola, in un punto solo.
%
%   Riporta INSIEME tutti i disallineamenti, con i nomi. Il controllo che
%   sostituisce (MAIN.m, tabella RATED_LOAD_KW) si fermava al primo nome
%   mancante: su una comunita' di sessanta membri significava sessanta
%   esecuzioni per scoprire sessanta refusi.
%
%   INPUT
%     CFG        struct restituita da load_cer_input
%     userNames  [1 x nUsers] string, da load_cer_data (ordine del CSV)
%
%   OUTPUT (struct M) - ogni campo e' [nUsers x 1] nell'ordine di userNames
%     .tabella         la table dei membri, riordinata
%     .nome            nome_csv
%     .ruolo .categoria .tariffa           string
%     .P_prel_kW                           double, potenza impegnata [kW]
%     .n_comp .n_perc                      double
%     .reddito_EUR .gas_kWh                double
%     .quota_inv_EUR .mutuo_EUR_anno       double
%     .isHousehold                         logical (categoria == "domestico")
%     .noto            flag per colonna ereditati da CFG.noto.membri: true
%                      solo se NESSUNA cella di quella colonna vale '?'
%
%   Vedi anche: load_cer_input, load_cer_data, MAIN

    userNames = string(userNames(:)).';
    T         = CFG.membri;
    nomiSched = T.nome_csv(:).';

    % --- Corrispondenza fra le due liste ------------------------------------
    mancanti = setdiff(userNames, nomiSched, 'stable');   % nel CSV, non in scheda
    in_piu   = setdiff(nomiSched, userNames, 'stable');   % in scheda, non nel CSV

    if ~isempty(mancanti) || ~isempty(in_piu)
        msg = "La scheda dati e i profili di carico descrivono comunita' diverse:";
        if ~isempty(mancanti)
            msg = msg + newline + newline + ...
                  sprintf('  %d colonne del CSV senza una riga in [MEMBRI]:', numel(mancanti)) + ...
                  newline + sprintf('    %s\n', mancanti);
        end
        if ~isempty(in_piu)
            msg = msg + newline + ...
                  sprintf('  %d righe di [MEMBRI] senza una colonna nel CSV:', numel(in_piu)) + ...
                  newline + sprintf('    %s\n', in_piu);
        end
        msg = msg + newline + ...
              "  I profili si rigenerano da CER_LoadProfiles/config/simulation_config.yaml.";
        error('align_members_to_users:disallineamento', '%s', msg);
    end

    % --- Riordino ------------------------------------------------------------
    [~, ordine] = ismember(userNames, nomiSched);
    T = T(ordine, :);

    M.tabella = T;
    M.nome    = T.nome_csv;

    % Colonne sempre presenti (load_cer_input le impone)
    M.ruolo     = T.ruolo;
    M.categoria = T.categoria;
    M.tariffa   = T.tariffa;
    M.P_prel_kW = T.P_prel_kW;

    % Colonne facoltative: assenti dalla scheda -> vettore di NaN, cosi' il
    % chiamante puo' sempre indicizzarle senza controllare prima se esistono.
    facoltative = ["n_comp", "n_perc", "reddito_EUR", "gas_kWh", ...
                   "quota_inv_EUR", "mutuo_EUR_anno"];
    presenti = string(T.Properties.VariableNames);
    for c = facoltative
        if ismember(c, presenti)
            M.(c) = T.(c);
        else
            M.(c) = nan(height(T), 1);
        end
    end

    M.isHousehold = (T.categoria == "domestico");

    % --- Flag di disponibilita' ---------------------------------------------
    % Ereditati dalla scheda, con due aggiunte che il parser non puo' sapere:
    % una colonna facoltativa assente non e' nota, e le quote di investimento
    % tutte a zero non sono un dato di proprieta' ma la sua assenza.
    M.noto = CFG.noto.membri;
    for c = facoltative
        if ~ismember(c, presenti)
            M.noto.(c) = false;
        end
    end
    if M.noto.quota_inv_EUR && all(M.quota_inv_EUR == 0 | isnan(M.quota_inv_EUR))
        M.noto.quota_inv_EUR = false;
    end
end
