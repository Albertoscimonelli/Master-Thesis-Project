function F = compute_incentive_strength(phiMat, SU, methodNames, opts)
%COMPUTE_INCENTIVE_STRENGTH  Quanto ciascuna regola di ripartizione premia il
%   comportamento virtuoso, cioe' il sincronismo fra prelievo e immissione.
%
%   Operativizza il termine "incentive strength of the rule" della domanda di
%   ricerca (§2.6 della tesi), il terzo criterio accanto all'equita' distributiva
%   e alla sostenibilita' economica della partecipazione.
%
%   CHE COSA MISURA, E CHE COSA NON MISURA
%     La definizione letterale di forza incentivante sarebbe un'ELASTICITA':
%     perturbare il profilo del membro i, ricalcolare tutte le ripartizioni e
%     leggere d(phi_i). E' fuori dallo scope dichiarato in tesi - richiederebbe
%     di simulare la risposta comportamentale nel tempo - oltre a costare n
%     riesecuzioni di Shapley, Nucleolo e VLC per comunita' e a pretendere una
%     forma arbitraria della perturbazione.
%     Qui la misura e' EX-POST e STRUTTURALE: con una sola realizzazione dei
%     profili, l'unico sostituto onesto e' la COVARIANZA TRASVERSALE fra quota e
%     virtuosita' - i membri virtuosi prendono sistematicamente di piu', o no?
%     E' letteralmente cio' che si calcola: poiche' le deviazioni dall'uniforme
%     sommano a zero, il numeratore di questa metrica E' n * cov(q_k, b).
%
%   L'ASSE DELLA VIRTUOSITA'
%     §2.6 osserva che, tolto il prezzo interno, l'allineamento temporale fra
%     prelievo e immissione e' l'UNICA dimensione lungo cui i membri
%     differiscono. Quella dimensione e' gia' calcolata da
%     similarity_utilization_cer.m, che per la regola di Bilardo (Renewable
%     Energy 255 (2025) 123756, eq. 6-8) produce giorno per giorno
%         fAll(d,m) = theta(d,m) * eta(d,m)   in [0,1]
%     con theta = similarita' coseno carico/generazione ed eta = utilizzo. Qui
%     non si ricalcola nulla: si riceve quella struct e se ne estrae il segnale.
%
%       b_i  = sum_d w_d * fAll(d,i),   w_d = dailyIncentive(d)/sum dailyIncentive
%       b_c  = b - mean(b)                                    ASSE (centrato)
%       q_k  = phi_k / sum(phi_k)                             quote del metodo k
%       u    = ones(n,1)/n
%
%       proiezione_k = <q_k - u, b_c>
%       IS_k         = proiezione_k / proiezione_rif          FORZA INCENTIVANTE
%       ALIGN_k      = proiezione_k / (||q_k - u|| * ||b_c||) ALLINEAMENTO
%       beta_k       = proiezione_k / <b_c, b_c>              pendenza grezza
%
%     I PESI SONO SULL'INCENTIVO, non uniformi, e non e' un dettaglio: un giorno
%     senza generazione ha dailyIncentive = 0, quindi peso nullo, e la
%     ripartizione uniforme di ripiego che similarity_utilization_cer usa in quei
%     giorni non puo' filtrare dentro l'asse. Per lo stesso motivo NON si usano
%     SU.thetaMean, SU.etaMean o SU.meanDailyShare: sono medie semplici, danno un
%     altro numero e non segnalerebbero nulla.
%
%     DUE ANCORE ESATTE, che in MAIN.m sono assert:
%       IS(Equal Split)            = 0   il numeratore si annulla (q_k = u)
%       IS(regola di riferimento)  = 1   il denominatore E' il suo numeratore
%     Il denominatore si costruisce sempre da SU.phi, cioe' dall'allocazione che
%     la STESSA struct ha prodotto sullo STESSO asse. Cosi' l'unita' di misura e'
%     coerente anche quando la regola di riferimento non e' fra le colonne di
%     phiMat - il caso dell'asse lordo, dove SU.phi non e' uno dei metodi in gara.
%
%   PERCHE' NON E' LA DISTANZA DAL MERITO
%     L'alternativa naturale sarebbe lo scostamento da D_cd, la distribuzione per
%     contributo marginale BC_i = v(N) - v(N\{i}) di fairness_index_bm.m. Misura
%     un'altra cosa. Togliere un membro toglie la sua generazione E il suo carico,
%     quindi BC e' dominato dalla PROPRIETA' DELL'IMPIANTO: un consumatore puro ha
%     spesso BC_i = 0 per topologia, non per comportamento (lo dice l'header di
%     fairness_index_bm e lo stampa MAIN.m §3t). I due assi sono quasi ortogonali
%     per costruzione, perche' theta e' un COSENO e ignora del tutto le grandezze
%     assolute mentre BC e' pura grandezza: un consumatore massimamente virtuoso
%     puo' avere BC = 0, un prosumer anticorrelato ha BC ~ v(N) e theta ~ 0.
%     Usare la deviazione dal merito qui ripeterebbe la colonna FairnessIndex, che
%     e' gia' in Tfair, e conterebbe la proprieta' come virtu'.
%     Che IS e FairnessIndex possano ordinare in modo OPPOSTO e' un risultato da
%     riportare, non un fastidio.
%
%   DUE NUMERI, NON UNO: INTENSITA' E DIREZIONE
%     IS dice QUANTO la regola premia la virtuosita'; ALIGN dice SE il premio e'
%     diretto alla virtuosita' a prescindere dall'intensita'. Servono entrambi:
%     una regola puo' disperdere molto le quote senza che la dispersione stia
%     sull'asse. R2 = ALIGN^2 e' la frazione della deviazione dall'uniforme che
%     giace sull'asse, ed e' il numero da usare in una mappa di calore perche' e'
%     l'unico dei tre limitato in [0,1].
%
%   PERCHE' L'INDICE NON E' LIMITATO SUPERIORMENTE
%     IS e' una PENDENZA, non una proporzione: Gini e Jain sono limitati perche'
%     misurano quote, ma costringere una misura di forza dentro [0,1]
%     distruggerebbe l'informazione che una regola puo' premiare la virtuosita'
%     il doppio di quanto la premi Bilardo. Si legge cosi': 1 = come la regola di
%     riferimento, 2 = il doppio, negativo = premia il contrario.
%     Il prezzo e' che il metro DIPENDE DALLA COMUNITA' (il denominatore e'
%     specifico della configurazione). Va benissimo per le graduatorie, che sono
%     invarianti a una scala positiva comune, ma qualunque confronto FRA comunita'
%     - un grafico "forza contro penetrazione" - deve usare .beta, non .IS.
%     Corollario da dichiarare: IS della regola di riferimento vale 1.000 in ogni
%     configurazione per costruzione, quindi e' una riga che non puo' muoversi.
%
%   PROFILI NETTI O LORDI: L'ASSE CAMBIA
%     similarity_utilization_cer calcola theta ed eta sui profili NETTI per
%     default (genForShare/loadForShare, coerenti col gioco cooperativo che gli
%     altri metodi risolvono) e sui LORDI se glielo si chiede via
%     opts.loadForFactors/opts.genForFactors, che e' la lettura letterale del
%     paper. La differenza non e' cosmetica e va conosciuta PRIMA di leggere i
%     numeri: sui profili netti il carico residuo del proprietario dell'impianto
%     e' nullo proprio nelle ore di eccedenza, quindi il numeratore del coseno va
%     a zero, la sua virtuosita' misurata crolla, e ogni regola che premia i
%     prosumer risulta fortemente NEGATIVA. E' un artefatto della convenzione, non
%     una proprieta' della regola.
%     Per questo MAIN.m calcola la metrica su ENTRAMBI gli assi e stampa il coseno
%     fra i due: se scende sotto ~0.8, la graduatoria dipende dalla convenzione e
%     la tesi deve dirlo. Il campo .fattoriLordi riporta su quale dei due si sta.
%
%   COSA ASPETTARSI SU QUESTA TOPOLOGIA (leggere prima di usare i numeri)
%     - Un membro senza carico (produttore puro, ruolo E) sta FUORI dal dominio
%       del fattore di Bilardo: theta = 0 perche' il denominatore e' nullo, eta = 1
%       perche' il ramo "needs" e' falso, quindi fAll = 0 e b = 0. Qualunque regola
%       lo paghi sembra antivirtuosa. Il campo .nVirtuositaNulla lo segnala.
%     - Se tutti i membri sono ugualmente virtuosi l'asse non esiste e la domanda
%       non e' rispondibile: IS e ALIGN valgono NaN e .identificabile e' false.
%       Restituire 0 direbbe "questa regola non premia la virtuosita'", che sarebbe
%       un'affermazione falsa invece di un'assenza di risposta. Stessa scelta di
%       jain_index.m, per lo stesso motivo.
%
%   INPUT
%     phiMat       [n x nM]  una colonna per metodo, quote in EUR
%     SU           struct    uscita di similarity_utilization_cer, con almeno
%                              .fAll           [nGiorni x n]
%                              .dailyIncentive [nGiorni x 1]
%                              .phi            [n x 1]
%                              .vGrand         scalare
%                              .players        [1 x n]
%                              .grossFactors, .nDegenerateDays
%                            Si riceve la struct INTERA e non i profili: cosi' la
%                            metrica non puo' costruire l'asse con un P_CER
%                            diverso da quello con cui SU e' stata calcolata.
%     methodNames  [1 x nM]  nomi dei metodi                            (string)
%     opts         struct opzionale:
%                    .playerNames      [1 x n] confrontati con SU.players
%                    .nomeRiferimento  regola che fissa l'unita'
%                                      (def. "Similarity-Utilization")
%                    .pesiGiornalieri  "incentivo" (def.) | "uniforme"
%                    .tolAsse          sotto cui l'asse non e' identificabile
%                                      (def. 1e-6)
%                    .tolUniforme      sotto cui una ripartizione conta come
%                                      uniforme (def. 1e-12)
%                    .tolEfficienza    tolleranza relativa su sum(phi) = v(N),
%                                      solo diagnostica (def. 1e-6)
%                    .validateSelf     esegue l'auto-test analitico (def. true)
%                    .quiet            non stampare il registro ipotesi (def. false)
%
%   OUTPUT (struct F)
%     .methods          [1 x nM] nomi dei metodi
%     .players          [1 x n]  nomi dei membri
%     .virtuosita       [n x 1]  b, media pesata di fAll, in [0,1]
%     .virtuositaC      [n x 1]  b - mean(b), l'asse
%     .normaAsse        scalare  ||b_c||
%     .D                [n x nM] q_k = phi_k / sum(phi_k)
%     .deviazione       [n x nM] q_k - u
%     .proiezione       [nM x 1] <q_k - u, b_c>  ( = n * cov(q_k, b) )
%     .beta             [nM x 1] pendenza grezza, confrontabile fra comunita'
%     .IS               [nM x 1] forza incentivante (0 = uniforme, 1 = riferimento)
%     .align            [nM x 1] coseno, in [-1,1]
%     .R2               [nM x 1] align.^2, in [0,1]
%     .rho              [nM x 1] Spearman fra quota e virtuosita' (diagnostico)
%     .iRiferimento     scalare  indice della regola di riferimento in phiMat
%                                (NaN se non e' fra i metodi in gara)
%     .proiezioneRif    scalare  il denominatore, da SU.phi
%     .identificabile   logico   false se l'asse e' sotto tolleranza
%     .fattoriLordi     logico   = SU.grossFactors
%     .nGiorniDegeneri  scalare  = SU.nDegenerateDays
%     .nVirtuositaNulla scalare  membri con b nullo
%     .scartoEfficienza [nM x 1] |sum(phi_k) - v(N)| / max(1, |v(N)|)
%     .assumptions      table    registro delle ipotesi attive
%     .table            table    riepilogo per metodo
%     .tablePlayers     table    virtuosita' per membro - chi e' virtuoso e perche'

    if nargin < 4 || isempty(opts), opts = struct(); end

    [n, nM] = size(phiMat);

    % --- Guardie sugli ingressi ---------------------------------------------
    methodNames = string(methodNames(:).');
    if numel(methodNames) ~= nM
        error('compute_incentive_strength:nameSizeMismatch', ...
              'methodNames ha %d elementi, phiMat ha %d colonne.', ...
              numel(methodNames), nM);
    end

    campiAttesi = {'fAll', 'dailyIncentive', 'phi', 'vGrand', 'players'};
    for k = 1:numel(campiAttesi)
        if ~isfield(SU, campiAttesi{k})
            error('compute_incentive_strength:suIncompleta', ...
                  ['La struct SU non ha il campo "%s": deve essere l''uscita di ' ...
                   'similarity_utilization_cer.'], campiAttesi{k});
        end
    end

    [nDays, nSU] = size(SU.fAll);
    if nSU ~= n
        error('compute_incentive_strength:sizeMismatch', ...
              'SU.fAll ha %d colonne, phiMat ha %d righe.', nSU, n);
    end
    if numel(SU.dailyIncentive) ~= nDays
        error('compute_incentive_strength:sizeMismatch', ...
              'SU.dailyIncentive ha %d elementi, SU.fAll ha %d righe.', ...
              numel(SU.dailyIncentive), nDays);
    end
    if numel(SU.phi) ~= n
        error('compute_incentive_strength:sizeMismatch', ...
              'SU.phi ha %d elementi, phiMat ha %d righe.', numel(SU.phi), n);
    end
    if ~all(isfinite(phiMat), 'all') || ~all(isfinite(SU.fAll), 'all') || ...
       ~all(isfinite(SU.dailyIncentive)) || ~all(isfinite(SU.phi))
        error('compute_incentive_strength:nonFiniteInput', ...
              'Ripartizioni o fattori con NaN o Inf: controllare i dati a monte.');
    end

    % Snapshot PRIMA dei default (vedi fairness_index_bm.m).
    tracciati = {'pesiGiornalieri', 'nomeRiferimento'};
    fornito   = struct();
    for k = 1:numel(tracciati)
        fornito.(tracciati{k}) = isfield(opts, tracciati{k});
    end

    if ~isfield(opts, 'playerNames'),     opts.playerNames     = SU.players;               end
    if ~isfield(opts, 'nomeRiferimento'), opts.nomeRiferimento = "Similarity-Utilization"; end
    if ~isfield(opts, 'pesiGiornalieri'), opts.pesiGiornalieri = "incentivo";              end
    if ~isfield(opts, 'tolAsse'),         opts.tolAsse         = 1e-6;                     end
    if ~isfield(opts, 'tolUniforme'),     opts.tolUniforme     = 1e-12;                    end
    if ~isfield(opts, 'tolEfficienza'),   opts.tolEfficienza   = 1e-6;                     end
    if ~isfield(opts, 'validateSelf'),    opts.validateSelf    = true;                     end
    if ~isfield(opts, 'quiet'),           opts.quiet           = false;                    end

    opts.pesiGiornalieri = string(opts.pesiGiornalieri);
    if ~ismember(opts.pesiGiornalieri, ["incentivo", "uniforme"])
        error('compute_incentive_strength:badPesi', ...
              'opts.pesiGiornalieri deve essere "incentivo" o "uniforme", e'' "%s".', ...
              opts.pesiGiornalieri);
    end

    % L'ordinamento dei membri e' l'unico disallineamento possibile che NON
    % darebbe errore di dimensione: phiMat e' in ordine userNames, SU.fAll in
    % ordine delle colonne di loadUsers. Oggi coincidono perche' vengono dalla
    % stessa struct D, ma un riordino futuro produrrebbe spazzatura in silenzio.
    players = string(opts.playerNames(:).');
    if numel(players) ~= n
        error('compute_incentive_strength:nameSizeMismatch', ...
              'playerNames ha %d elementi, i membri sono %d.', numel(players), n);
    end
    if ~isequal(players, string(SU.players(:).'))
        error('compute_incentive_strength:playerMismatch', ...
              ['L''ordine dei membri di phiMat non coincide con quello di SU: ' ...
               'la proiezione accoppierebbe la quota di un membro con la ' ...
               'virtuosita'' di un altro.']);
    end

    % --- Asse di virtuosita' -------------------------------------------------
    if opts.pesiGiornalieri == "incentivo"
        totInc = sum(SU.dailyIncentive);
        if totInc <= 0
            error('compute_incentive_strength:noIncentive', ...
                  ['L''incentivo giornaliero somma a %.6g <= 0: i pesi non sono ' ...
                   'definiti.'], totInc);
        end
        w = SU.dailyIncentive(:) / totInc;
    else
        w = ones(nDays, 1) / nDays;
    end

    b  = SU.fAll.' * w;            % [n x 1], in [0,1] perche' fAll lo e' e sum(w)=1
    bc = b - mean(b);
    normaAsse = norm(bc);

    if normaAsse == 0
        error('compute_incentive_strength:asseNullo', ...
              ['Tutti i membri hanno la stessa virtuosita'' misurata: l''asse non ' ...
               'esiste e la forza incentivante non e'' definita.']);
    end
    identificabile = normaAsse > opts.tolAsse;

    % --- Quote e deviazioni dall'uniforme ------------------------------------
    % Si normalizza sulla SOMMA della colonna e non su v(N): se un metodo non
    % fosse efficiente (il Cascading Tree con una riserva trattenuta > 0 lo e'
    % legittimamente), dividere per v(N) farebbe si' che la deviazione non sommi
    % piu' a zero e la proiezione acquisterebbe un termine di media spurio.
    u   = ones(n, 1) / n;
    D   = zeros(n, nM);
    for k = 1:nM
        tot = sum(phiMat(:, k));
        if tot <= 0
            error('compute_incentive_strength:nonPositiveAllocation', ...
                  ['Il metodo "%s" distribuisce un totale di %.6g <= 0: le quote ' ...
                   'non sono normalizzabili.'], methodNames(k), tot);
        end
        D(:, k) = phiMat(:, k) / tot;
    end
    Dev = D - u;

    % --- Proiezione, forza, allineamento -------------------------------------
    proiezione = (Dev.' * bc);                       % [nM x 1]

    % Il denominatore viene da SU.phi, non da una colonna di phiMat: e'
    % l'allocazione prodotta dalla STESSA struct sullo STESSO asse, quindi
    % l'unita' resta coerente anche sull'asse lordo, dove la regola di
    % riferimento non e' fra i metodi in gara.
    totRif = sum(SU.phi);
    if totRif <= 0
        error('compute_incentive_strength:nonPositiveAllocation', ...
              'La regola di riferimento distribuisce un totale di %.6g <= 0.', totRif);
    end
    devRif        = SU.phi(:) / totRif - u;
    proiezioneRif = devRif.' * bc;

    if abs(proiezioneRif) <= opts.tolAsse * normaAsse
        error('compute_incentive_strength:unitaDegenere', ...
              ['La regola di riferimento non e'' essa stessa allineata all''asse ' ...
               '(proiezione %.3g): l''unita'' di misura sarebbe priva di senso.'], ...
              proiezioneRif);
    end

    normaDev = vecnorm(Dev, 2, 1).';                 % [nM x 1]
    uniforme = normaDev <= opts.tolUniforme;

    if identificabile
        IS    = proiezione / proiezioneRif;
        align = zeros(nM, 1);                        % ripartizione uniforme: non
        align(~uniforme) = proiezione(~uniforme) ...  % c'e' direzione da allineare
                           ./ (normaDev(~uniforme) * normaAsse);
        beta  = proiezione / (normaAsse^2);
    else
        IS    = nan(nM, 1);
        align = nan(nM, 1);
        beta  = nan(nM, 1);
    end

    % Guardia numerica: il coseno resta un coseno anche dopo gli arrotondamenti.
    align = min(max(align, -1), 1);

    % --- Spearman, diagnostico ------------------------------------------------
    % Non entra in Tfair: satura (premiare il membro piu' virtuoso di +0.001 o di
    % +10x da' lo stesso rango) ed e' NaN sull'Equal Split, dove tutti i ranghi
    % sono pari - proprio dove serve l'ancora dello zero.
    rho = nan(nM, 1);
    rb  = local_rank_medio(b);
    for k = 1:nM
        if ~uniforme(k)
            rho(k) = local_pearson(local_rank_medio(D(:, k)), rb);
        end
    end

    % --- Diagnostiche ---------------------------------------------------------
    scartoEfficienza = abs(sum(phiMat, 1).' - SU.vGrand) / max(1, abs(SU.vGrand));
    nVirtuositaNulla = sum(b <= opts.tolAsse);

    iRif = find(methodNames == string(opts.nomeRiferimento), 1);
    if isempty(iRif), iRif = NaN; end

    % --- Registro delle ipotesi -----------------------------------------------
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});
    reg = local_note(reg, 1, 'Asse di virtuosita', ...
                     'fattori theta*eta di Bilardo (eq. 6-8)', ...
                     'passare una struct SU costruita su altri fattori');
    if ~fornito.pesiGiornalieri
        reg = local_note(reg, 2, 'Pesi dei giorni', ...
                         'proporzionali all''incentivo maturato', ...
                         'opts.pesiGiornalieri = "uniforme" per la media semplice');
    end
    if ~fornito.nomeRiferimento
        reg = local_note(reg, 3, 'Unita di misura', ...
                         'la regola Similarity-Utilization vale 1 per definizione', ...
                         'leggere .beta, pendenza grezza indipendente da ogni regola');
    end
    % Sempre attiva: e' il confine dello scope, non una scelta reversibile.
    reg = local_note(reg, 4, 'Misura ex-post, non elasticita', ...
                     'nessuna simulazione della risposta comportamentale', ...
                     ['perturbare il profilo di un membro e ricalcolare le ' ...
                      'ripartizioni, uscendo dallo scope dichiarato in tesi']);
    reg = local_note(reg, 5, 'Profili dei fattori', ...
                     local_etichetta_profili(SU), ...
                     ['passare loadForFactors/genForFactors a ' ...
                      'similarity_utilization_cer per l''altra convenzione']);

    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    F.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                   string({reg.valore}).', string({reg.rimozione}).', ...
                                   'VariableNames', colonneReg), 'Id');

    % --- Struttura di uscita ---------------------------------------------------
    F.methods          = methodNames;
    F.players          = players;
    F.virtuosita       = b;
    F.virtuositaC      = bc;
    F.normaAsse        = normaAsse;
    F.D                = D;
    F.deviazione       = Dev;
    F.proiezione       = proiezione;
    F.beta             = beta;
    F.IS               = IS;
    F.align            = align;
    F.R2               = align.^2;
    F.rho              = rho;
    F.iRiferimento     = iRif;
    F.proiezioneRif    = proiezioneRif;
    F.identificabile   = identificabile;
    F.pesiGiornalieri  = opts.pesiGiornalieri;
    F.fattoriLordi     = isfield(SU, 'grossFactors')     && SU.grossFactors;
    F.nGiorniDegeneri  = local_campo(SU, 'nDegenerateDays', NaN);
    F.nVirtuositaNulla = nVirtuositaNulla;
    F.scartoEfficienza = scartoEfficienza;

    F.table = table(methodNames(:), IS, align, beta, F.R2, ...
                    'VariableNames', {'Metodo', 'ForzaIncentivante', ...
                                      'Allineamento', 'Beta', 'R2'});

    thetaMedio = local_campo(SU, 'thetaMean', nan(n, 1));
    etaMedio   = local_campo(SU, 'etaMean',   nan(n, 1));
    F.tablePlayers = table(players(:), b, thetaMedio(:), etaMedio(:), ...
                           100 * SU.phi(:) / totRif, ...
                           'VariableNames', {'Giocatore', 'Virtuosita', ...
                                             'ThetaMedio', 'EtaMedio', 'QuotaRif_pct'});

    if opts.validateSelf
        local_validate_self();
    end

    if ~opts.quiet
        fprintf('\n  Ipotesi attive (compute_incentive_strength):\n');
        for k = 1:numel(reg)
            fprintf('    [%d] %s: %s\n', reg(k).id, reg(k).voce, reg(k).valore);
        end
        if ~identificabile
            fprintf(['    ATTENZIONE: l''asse di virtuosita'' ha norma %.3g, sotto la ' ...
                     'soglia %.3g.\n                I membri sono di fatto ' ...
                     'equivirtuosi: la domanda non e'' rispondibile\n' ...
                     '                e la forza incentivante vale NaN.\n'], ...
                    normaAsse, opts.tolAsse);
        end
        if nVirtuositaNulla > 0
            fprintf(['    ATTENZIONE: %d membri su %d hanno virtuosita'' nulla. Se sono ' ...
                     'produttori puri stanno\n                fuori dal dominio del ' ...
                     'fattore di Bilardo (carico nullo -> theta = 0):\n' ...
                     '                vedi "COSA ASPETTARSI" in ' ...
                     'help compute_incentive_strength.\n'], nVirtuositaNulla, n);
        end
        if any(scartoEfficienza > opts.tolEfficienza)
            fprintf(['    NOTA: %d metodi non distribuiscono esattamente v(N). Le quote ' ...
                     'sono normalizzate\n          sulla somma di colonna, quindi la ' ...
                     'proiezione resta corretta.\n'], ...
                    sum(scartoEfficienza > opts.tolEfficienza));
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function v = local_campo(S, nome, difetto)
%LOCAL_CAMPO  Campo opzionale della struct SU, con valore di ripiego.
    if isfield(S, nome), v = S.(nome); else, v = difetto; end
end

function s = local_etichetta_profili(SU)
%LOCAL_ETICHETTA_PROFILI  Su quali profili sono stati calcolati theta ed eta.
    if isfield(SU, 'grossFactors') && SU.grossFactors
        s = 'LORDI (lettura letterale del paper)';
    else
        s = 'NETTI (default del progetto, coerenti col gioco cooperativo)';
    end
end

function reg = local_note(reg, id, voce, valore, rimozione)
%LOCAL_NOTE  Aggiunge una voce al registro delle ipotesi ancora attive.
    reg(end+1) = struct('id', id, 'voce', voce, 'valore', valore, ...
                        'rimozione', rimozione);
end

function r = local_rank_medio(x)
%LOCAL_RANK_MEDIO  Ranghi con media sui pareggi, scritti a mano perche' tiedrank
%   appartiene allo Statistics Toolbox, da cui questo progetto non dipende.
    x        = x(:);
    n        = numel(x);
    [~, ord] = sort(x);
    r        = zeros(n, 1);
    r(ord)   = 1:n;

    xs = x(ord);
    i  = 1;
    while i <= n
        j = i;
        while j < n && xs(j+1) == xs(i)
            j = j + 1;
        end
        if j > i
            r(ord(i:j)) = mean(i:j);
        end
        i = j + 1;
    end
end

function c = local_pearson(x, y)
%LOCAL_PEARSON  Correlazione lineare, scritta a mano per lo stesso motivo di
%   local_rank_medio. Su ranghi medi da' lo Spearman.
    xc = x(:) - mean(x);
    yc = y(:) - mean(y);
    dx = norm(xc);
    dy = norm(yc);
    if dx == 0 || dy == 0
        c = NaN;                 % una delle due serie e' costante
    else
        c = (xc.' * yc) / (dx * dy);
    end
end

function local_validate_self()
%LOCAL_VALIDATE_SELF  Auto-test analitico su casi il cui esito si calcola a
%   penna. Copre le due ancore, la linearita' della proiezione, il verso e
%   l'invarianza per permutazione dei membri.
    tol = 1e-12;

    % Caso base: 3 membri, 2 giorni. La virtuosita' e' costruita perche' la media
    % pesata sull'incentivo dia b = [0.6; 0.3; 0.0].
    fAll = [0.8 0.4 0.0;      % giorno 1, incentivo 3
            0.0 0.0 0.0];     % giorno 2, incentivo 0 -> peso nullo
    inc  = [3; 0];
    b    = [0.8; 0.4; 0.0];   % con w = [1; 0] la media pesata e' la riga 1
    u    = ones(3,1) / 3;
    bc   = b - mean(b);

    % Regola di riferimento: quote proporzionali a b -> phi = [0.8 0.4 0.0]*k
    phiRif = [0.8; 0.4; 0.0];
    SU = struct('fAll', fAll, 'dailyIncentive', inc, 'phi', phiRif, ...
                'vGrand', sum(phiRif), 'players', ["a" "b" "c"], ...
                'grossFactors', false, 'nDegenerateDays', 1);
    devRif = phiRif/sum(phiRif) - u;
    pRif   = devRif.' * bc;

    % Quattro metodi a esito noto:
    %   uniforme          -> IS = 0    (deviazione nulla)
    %   uguale al rif.    -> IS = 1    (numeratore = denominatore)
    %   2*rif - u         -> IS = 2    (la deviazione raddoppia, e' lineare)
    %   rif specchiato    -> IS = -1   (deviazione di segno opposto)
    qUni  = u;
    qRif  = phiRif / sum(phiRif);
    qDue  = 2*qRif - u;
    qMeno = u - (qRif - u);
    phiMat = [qUni, qRif, qDue, qMeno];
    nomi   = ["Uniforme", "Riferimento", "Doppio", "Opposto"];

    o = struct('nomeRiferimento', "Riferimento", 'validateSelf', false, 'quiet', true);
    F = compute_incentive_strength(phiMat, SU, nomi, o);

    assert(abs(F.proiezioneRif - pRif) < tol, ...
           'compute_incentive_strength: denominatore diverso da quello atteso');
    assert(abs(F.IS(1) - 0)  < tol, 'compute_incentive_strength: IS uniforme diverso da 0');
    assert(abs(F.IS(2) - 1)  < tol, 'compute_incentive_strength: IS riferimento diverso da 1');
    assert(abs(F.IS(3) - 2)  < tol, 'compute_incentive_strength: IS non e'' lineare');
    assert(abs(F.IS(4) + 1)  < tol, 'compute_incentive_strength: IS non cambia segno');

    % Allineamento: 0 sull'uniforme (nessuna direzione), +1 sul riferimento,
    % -1 sull'opposto. Il coseno non distingue "doppio" da "riferimento".
    assert(abs(F.align(1))     < tol, 'compute_incentive_strength: coseno uniforme non nullo');
    assert(abs(F.align(2) - 1) < tol, 'compute_incentive_strength: coseno riferimento non 1');
    assert(abs(F.align(3) - 1) < tol, 'compute_incentive_strength: coseno del doppio non 1');
    assert(abs(F.align(4) + 1) < tol, 'compute_incentive_strength: coseno opposto non -1');
    assert(all(abs(F.align) <= 1 + tol), 'compute_incentive_strength: coseno fuori da [-1,1]');

    % La virtuosita' e' quella attesa e resta in [0,1].
    assert(max(abs(F.virtuosita - b)) < tol, ...
           'compute_incentive_strength: virtuosita'' diversa dalla media pesata attesa');
    assert(all(F.virtuosita >= -tol & F.virtuosita <= 1 + tol), ...
           'compute_incentive_strength: virtuosita'' fuori da [0,1]');

    % Le deviazioni sommano a zero: e' cio' che rende la proiezione una covarianza.
    assert(max(abs(sum(F.deviazione, 1))) < tol, ...
           'compute_incentive_strength: le quote non sommano a 1');

    % --- Invarianza per permutazione dei membri ------------------------------
    % Permutando l'ordine dei membri i risultati PER METODO non devono cambiare.
    p   = [3 1 2];
    SUp = SU;
    SUp.fAll    = SU.fAll(:, p);
    SUp.phi     = SU.phi(p);
    SUp.players = SU.players(p);
    Fp = compute_incentive_strength(phiMat(p, :), SUp, nomi, o);

    assert(max(abs(Fp.IS    - F.IS))    < tol, ...
           'compute_incentive_strength: IS non invariante per permutazione dei membri');
    assert(max(abs(Fp.align - F.align)) < tol, ...
           'compute_incentive_strength: coseno non invariante per permutazione');
    assert(max(abs(Fp.virtuosita - F.virtuosita(p))) < tol, ...
           'compute_incentive_strength: virtuosita'' non segue la permutazione');

    % --- I due estremi richiesti: sincronismo premiato contro ignorato -------
    % Una regola che segue la virtuosita' deve stare STRETTAMENTE sopra una che
    % la ignora, e quella che la ignora deve valere esattamente zero.
    assert(F.IS(2) > F.IS(1), ...
           'compute_incentive_strength: una regola virtuosa non supera quella uniforme');
end
