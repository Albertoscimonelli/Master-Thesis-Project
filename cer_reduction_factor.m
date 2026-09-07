function [F, esente, info] = cer_reduction_factor(pctContoCapitale, categoria, opts)
%CER_REDUCTION_FACTOR  Fattore di riduzione F della tariffa premio per
%   contributo in conto capitale, e maschera dei membri che ne sono ESENTI
%   (Decreto CACER, DM MASE 7 dicembre 2023 n. 414, Allegato 1 par. 3, come
%   modificato dal DM 127 del 16 maggio 2025; Regole Operative GSE del
%   16 luglio 2025, par. 2.2.2.1.2 e Appendice B par. 3).
%
%   LA FORMULA
%     La tariffa premio decurtata vale  TIP_ContoCapitale = TIP * (1 - F),
%     dove F "nella generalita' dei casi varia linearmente tra 0, nel caso in
%     cui non sia previsto alcun contributo in conto capitale, e un valore pari
%     a 0,50, nel caso di contributo in conto capitale pari al 40%
%     dell'investimento" (Appendice B par. 3). Quindi
%
%         F = 0,50 * (pct / 40)        con pct in [0, 40]
%
%     Il 40% non e' un estremo scelto per comodita': e' il tetto di
%     cumulabilita' del par. 1.2.1.6: oltre quella soglia la tariffa
%     incentivante non e' cumulabile affatto, e chiedere F per pct > 40
%     significa aver gia' sbagliato altrove. Qui e' un errore, non un clamp
%     silenzioso.
%
%   L'ESENZIONE, E PERCHE' L'ELENCO SORPRENDE
%     Il fattore "non trova applicazione in relazione all'energia elettrica
%     condivisa incentivabile afferente a punti di prelievo nella titolarita'
%     di enti territoriali, enti religiosi, enti del terzo settore e
%     protezione ambientale E PERSONE FISICHE" (par. 2.2.2.1.2).
%
%     Le PERSONE FISICHE sono l'aggiunta che sfugge: non c'erano
%     nell'Allegato 1 del DM 414/2023 e sono state introdotte dal DM 127 del
%     16 maggio 2025 (Premessa delle Regole Operative, p. 5: "anche le persone
%     fisiche ora godranno dell'esclusione dall'applicazione del fattore di
%     riduzione F"). Chi cita il solo 414/2023 legge la lista PRE-127 e
%     lascia fuori la categoria piu' numerosa di una CER residenziale.
%     Conseguenza pratica: su queste schede sono esenti 4 membri su 7.
%
%   MAPPATURA SU [MEMBRI].categoria
%     domestico      -> persona fisica ................. ESENTE
%     PA             -> ente territoriale / autorita' locale ... ESENTE
%     terzo_settore  -> ente del terzo settore ......... ESENTE
%     religioso      -> ente religioso ................. ESENTE
%     ambientale     -> ente di protezione ambientale .. ESENTE
%     terziario | commerciale | industriale ............ NON esente
%
%     Le tre voci di mezzo sono state aggiunte al dominio della scheda proprio
%     per questa regola: una tipologia di CONSUMO non sa esprimere una forma
%     GIURIDICA, e un ente del terzo settore consuma come un terziario. Senza
%     di esse l'unico modo di dirlo sarebbe un flag ad hoc slegato dalla
%     categoria.
%
%   LA REGOLA DI PRIORITA', E PERCHE' QUI NON MORDE
%     Il par. 2.2.2.1.2 aggiunge che l'energia afferente a punti di prelievo di
%     enti territoriali, religiosi, del terzo settore e di protezione
%     ambientale "verra' prioritariamente allocata, nell'ambito della
%     ripartizione, agli impianti che hanno ricevuto il contributo in conto
%     capitale": e' una regola PRO-BENEFICIARIO, perche' allocare l'energia
%     esente agli impianti decurtati e' l'unico modo in cui l'esenzione produce
%     un risparmio (sugli impianti non decurtati F non si applica comunque).
%     Nel modello di questo progetto il contributo e' dichiarato per la
%     COMUNITA' e non per singolo impianto, quindi o tutti gli impianti sono
%     decurtati o nessuno: la regola di priorita' e' vacua e non c'e' nulla da
%     ordinare. Diventerebbe rilevante con un conto capitale per impianto.
%
%     Si noti l'asimmetria del testo: la regola di priorita' elenca gli enti ma
%     NON le persone fisiche - un residuo della formulazione anteriore al
%     DM 127/2025, che le persone fisiche non le contemplava.
%
%   INPUT
%     pctContoCapitale  scalare  intensita' del contributo in conto capitale,
%                                in PERCENTUALE dell'investimento [0..40].
%                                NaN o vuoto = non dichiarato -> F = 0.
%     categoria         [n x 1]  categoria di ciascun membro       (string)
%                                (da [MEMBRI].categoria)
%     opts              struct opzionale:
%                         .categorieEsenti  [1 x k] categorie esenti
%                                           (def. domestico, PA, terzo_settore,
%                                            religioso, ambientale)
%                         .Fmax             F al tetto di cumulabilita'
%                                           (def. 0.50)
%                         .pctMax           tetto di cumulabilita' in %
%                                           (def. 40)
%                         .validateSelf     auto-test analitico (def. true)
%
%   OUTPUT
%     F       scalare   fattore di riduzione, in [0, Fmax]
%     esente  [n x 1]   logico, true per i membri esenti da F
%     info    struct    .noto (il contributo era dichiarato?), .pct, .Fmax,
%                       .pctMax, .categorieEsenti, .nEsenti
%
%   Vedi anche: compute_cer_incentive, premium_excess_threshold, MAIN

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'categorieEsenti')
        opts.categorieEsenti = ["domestico", "PA", "terzo_settore", ...
                                "religioso", "ambientale"];
    end
    if ~isfield(opts, 'Fmax'),   opts.Fmax   = 0.50; end
    if ~isfield(opts, 'pctMax'), opts.pctMax = 40;   end

    % --- Maschera di esenzione ----------------------------------------------
    categoria = string(categoria(:));
    esente    = ismember(categoria, string(opts.categorieEsenti));

    % --- Fattore F -----------------------------------------------------------
    noto = ~(isempty(pctContoCapitale) || ...
             (isnumeric(pctContoCapitale) && all(isnan(pctContoCapitale))));

    if ~noto
        pct = 0;
        F   = 0;
    else
        if ~isscalar(pctContoCapitale) || ~isfinite(pctContoCapitale)
            error('cer_reduction_factor:badPercentage', ...
                  'Il contributo in conto capitale deve essere uno scalare finito.');
        end
        pct = double(pctContoCapitale);
        if pct < 0
            error('cer_reduction_factor:negativePercentage', ...
                  'Contributo in conto capitale negativo (%.2f%%).', pct);
        end
        % Oltre il tetto la tariffa non e' cumulabile: non e' un F piu' grande,
        % e' un'altra fattispecie (par. 1.2.1.6). Meglio fermarsi che decurtare
        % una tariffa a cui non si avrebbe diritto.
        if pct > opts.pctMax
            error('cer_reduction_factor:aboveCumulationCap', ...
                  ['Contributo in conto capitale al %.1f%%, oltre il tetto di ' ...
                   'cumulabilita'' del %.0f%% (Regole Operative par. 1.2.1.6): ' ...
                   'sopra quella soglia la tariffa incentivante non e'' ' ...
                   'cumulabile, quindi F non e'' definito.'], pct, opts.pctMax);
        end
        F = opts.Fmax * (pct / opts.pctMax);
    end

    info = struct('noto', noto, 'pct', pct, 'Fmax', opts.Fmax, ...
                  'pctMax', opts.pctMax, ...
                  'categorieEsenti', string(opts.categorieEsenti), ...
                  'nEsenti', sum(esente));

    if ~isfield(opts, 'validateSelf') || opts.validateSelf
        local_validate_self();
    end
end


function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test analitico su casi costruiti a penna.
%
%   Convenzione del progetto (fairness_index_bm.m, premium_excess_threshold.m):
%   niente cartella di test, l'auto-test sta nel modulo ed e' acceso di
%   default. Costa una manciata di operazioni e gira una volta per comunita'.
%
%   Copre DUE invarianti, e la seconda e' quella che conta davvero:
%     1. F cresce linearmente con il contributo, fino a 0,50 al 40%.
%     2. la quota esente che pesa sul valore e' quella della COALIZIONE. Se
%        qualcuno la sostituisse con la media di comunita' i numeri
%        resterebbero plausibili e il gioco sarebbe sbagliato, senza che
%        nessun altro controllo se ne accorga.

    tol = 1e-12;
    o   = struct('validateSelf', false);

    % --- 1) F lineare fra 0 e Fmax ------------------------------------------
    assert(cer_reduction_factor(0, "domestico", o) == 0, ...
           'cer_reduction_factor: senza contributo F deve valere 0');
    assert(abs(cer_reduction_factor(40, "domestico", o) - 0.50) < tol, ...
           'cer_reduction_factor: al 40%% di contributo F deve valere 0,50');
    assert(abs(cer_reduction_factor(20, "domestico", o) - 0.25) < tol, ...
           'cer_reduction_factor: F deve crescere LINEARMENTE (0,25 al 20%%)');
    assert(cer_reduction_factor(NaN, "domestico", o) == 0, ...
           'cer_reduction_factor: contributo non dichiarato deve dare F = 0');

    % --- 2) Chi e' esente ----------------------------------------------------
    [~, es] = cer_reduction_factor(40, ["domestico"; "PA"; "terzo_settore"; ...
                                        "religioso"; "ambientale"; ...
                                        "terziario"; "commerciale"; ...
                                        "industriale"], o);
    assert(isequal(es, [true(5,1); false(3,1)]), ...
           'cer_reduction_factor: mappatura categoria -> esenzione errata');

    % --- 3) La quota esente e' quella della coalizione ----------------------
    % Coalizione con 4 kWh condivisi a 0,10 EUR/kWh = 0,40 EUR lordi, F = 0,5.
    g = [4;4]; l = [2;2]; P = [0.1;0.1];
    assert(abs(cer_shared_value(g, l, P, zeros(2,1), 0.5) - 0.20) < tol, ...
           'cer_shared_value: senza esenti il valore deve dimezzarsi');
    assert(abs(cer_shared_value(g, l, P, l, 0.5) - 0.40) < tol, ...
           'cer_shared_value: con tutti esenti il valore NON deve decurtarsi');
    assert(abs(cer_shared_value(g, l, P, l/2, 0.5) - 0.30) < tol, ...
           ['cer_shared_value: con meta'' carico esente la decurtazione deve ' ...
            'dimezzarsi. Se qui esce 0,20 o 0,40, la quota esente non e'' ' ...
            'quella della coalizione.']);
end
