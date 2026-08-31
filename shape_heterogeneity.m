function S = shape_heterogeneity(loadProfiles, userNames, opts)
%SHAPE_HETEROGENEITY  Eterogeneita' di FORMA dei profili di carico della comunita'.
%
%   Complemento a gini_heterogeneity.m. Quello misura quanto sono varie le
%   ETICHETTE dei membri (terziario, domestico...); questo misura quanto sono
%   diversi i loro RITMI di consumo.
%
%   COME FUNZIONA, IN UNA FRASE
%     Si divide il profilo annuale di ogni membro per il suo totale, cosi'
%     diventa un ritmo che somma a 1; poi si misura la distanza media fra tutte
%     le coppie di ritmi.
%
%     La divisione separa il QUANTO dal QUANDO: un ufficio grande e uno piccolo
%     con lo stesso andamento orario devono contare come identici in forma. Il
%     livello si misura gia' col consumo annuo, qui interessa solo la sagoma.
%
%   ESTREMI (distanza L1 fra profili normalizzati)
%     0  tutti i membri consumano con lo stesso ritmo, cambia solo la scala.
%     2  i profili non si sovrappongono mai: quando uno consuma, gli altri no.
%
%   PERCHE' SERVE
%     I meccanismi sensibili al contributo marginale (Shapley, Nucleolo,
%     Variance Least Core) danno un risultato diverso da una ripartizione
%     puramente volumetrica SOLO se i membri consumano in momenti diversi. Se
%     tutte le forme fossero uguali, ogni meccanismo collasserebbe su
%     "proporzionale al consumo" e il confronto fra famiglie di meccanismi non
%     avrebbe piu' niente da mostrare. La diversita' di forma e' quindi una
%     PRECONDIZIONE perche' la domanda di ricerca sia rispondibile, e va
%     misurata invece che data per scontata.
%
%     E' anche il controllo che intercetta il problema descritto da Marrasso:
%     profili non domestici ricostruiti tutti dagli stessi coefficienti
%     standard hanno la stessa forma e differiscono solo per scala.
%
%   PERCHE' NON BASTA L'INDICE CATEGORIALE
%     gini_heterogeneity conta le etichette. Aggiungendo alla comunita' una
%     quarta famiglia (CHR05, tre figli) il suo valore SCENDE da 0.80 a 0.71,
%     perche' aggiunge un'altra etichetta "domestico" — anche se quella
%     famiglia consuma diversamente dalle altre. I due indici vanno letti
%     insieme.
%
%   INPUT
%     loadProfiles  [H x m] profili di carico orari, una colonna per membro,
%                   nello stesso ordine di userNames. Si usano i carichi LORDI
%                   (D.loadUsers): l'indice descrive CHI c'e' nella comunita',
%                   non l'esito della condivisione.
%     userNames     [1 x m] nomi degli utenti                        (string)
%     opts          struct opzionale:
%                     .memberTypes  [1 x m] tipologia di ciascun membro, per
%                                   sovrascrivere quella dedotta dai nomi
%                     .quiet        non stampare il registro ipotesi (def. false)
%
%   OUTPUT (struct S)
%     .L1              scalare  distanza media fra TUTTE le coppie, in [0, 2]
%     .dentroTipologia scalare  media sulle coppie della STESSA tipologia
%                               (NaN se nessuna tipologia ha almeno 2 membri)
%     .traTipologie    scalare  media sulle coppie di tipologie DIVERSE
%     .matrice         [m x m]  distanze a coppie, diagonale nulla
%     .memberTypes     [1 x m]  tipologia usata per ciascun membro
%     .types           [1 x K]  tipologie distinte trovate
%     .nMembers        scalare  m
%     .assumptions     table    registro delle ipotesi attive
%     .table           table    distanza media entro ciascuna tipologia
%
%   Vedi anche: gini_heterogeneity, load_cer_data, MAIN

    if nargin < 3 || isempty(opts), opts = struct(); end

    names = string(userNames(:).');
    m     = numel(names);

    if m < 2
        error('shape_heterogeneity:tooFewMembers', ...
              'Servono almeno 2 membri per avere una coppia: m = %d.', m);
    end
    if size(loadProfiles, 2) ~= m
        error('shape_heterogeneity:sizeMismatch', ...
              'loadProfiles ha %d colonne, gli utenti sono %d.', ...
              size(loadProfiles, 2), m);
    end

    % Snapshot PRIMA dei default, come in gini_heterogeneity: dopo, isfield
    % direbbe true per tutto e il registro non distinguerebbe piu' il dato
    % fornito da quello dedotto.
    fornito = struct('memberTypes', isfield(opts, 'memberTypes'));

    if ~isfield(opts, 'quiet'), opts.quiet = false; end

    if fornito.memberTypes
        memberTypes = string(opts.memberTypes(:).');
        if numel(memberTypes) ~= m
            error('shape_heterogeneity:typeSizeMismatch', ...
                  'opts.memberTypes ha %d elementi, gli utenti sono %d.', ...
                  numel(memberTypes), m);
        end
    else
        % [IPOTESI 1] categoria di consumo dedotta dal nome utente
        memberTypes = regexprep(names, '_\d+(_kWh)?$', '');
    end

    % --- Normalizzazione a somma unitaria: da livello a forma ----------------
    totali = sum(loadProfiles, 1);
    nulli  = totali <= 0;
    if any(nulli)
        error('shape_heterogeneity:emptyProfile', ...
              ['I membri %s hanno consumo annuo nullo: la forma non e'' ' ...
               'definita.'], strjoin(names(nulli), ', '));
    end
    F = loadProfiles ./ totali;          % ogni colonna somma a 1

    % --- Distanze L1 a coppie ------------------------------------------------
    S.matrice = zeros(m, m);
    for i = 1:m-1
        for j = i+1:m
            d = sum(abs(F(:, i) - F(:, j)));
            S.matrice(i, j) = d;
            S.matrice(j, i) = d;
        end
    end

    sopra   = triu(true(m), 1);                 % ogni coppia una volta sola
    distanze = S.matrice(sopra);

    stessa  = memberTypes(:) == memberTypes(:).';
    dentroM = stessa(sopra);

    S.L1              = mean(distanze);
    S.dentroTipologia = mean(distanze(dentroM));   % NaN se non ci sono coppie
    S.traTipologie    = mean(distanze(~dentroM));

    % --- Distanza media entro ciascuna tipologia -----------------------------
    types = unique(memberTypes, 'stable');
    nPerT = zeros(numel(types), 1);
    dPerT = nan(numel(types), 1);
    for k = 1:numel(types)
        sel = memberTypes == types(k);
        nPerT(k) = sum(sel);
        if nPerT(k) >= 2
            sotto = S.matrice(sel, sel);
            dPerT(k) = mean(sotto(triu(true(nPerT(k)), 1)));
        end
    end

    % --- Registro delle ipotesi ---------------------------------------------
    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});
    if ~fornito.memberTypes
        reg = local_note(reg, 1, 'Tipologia dei membri', ...
                         sprintf('categoria dedotta dai nomi (%d tipologie)', numel(types)), ...
                         'passare opts.memberTypes con la tipologia voluta');
    end
    reg = local_note(reg, 2, 'Metrica di distanza', ...
                     'L1 fra profili normalizzati a somma unitaria', ...
                     ['L2 o distanza coseno darebbero valori diversi: la ' ...
                      'scelta va dichiarata, non e'' neutra']);

    S.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                   string({reg.valore}).', string({reg.rimozione}).', ...
                                   'VariableNames', colonneReg), 'Id');

    S.memberTypes = memberTypes;
    S.types       = types;
    S.nMembers    = m;
    S.table       = table(types(:), nPerT, dPerT, ...
                          'VariableNames', {'Tipologia', 'Membri', 'DistanzaMedia'});

    if ~opts.quiet
        fprintf('\n  Ipotesi attive (shape_heterogeneity):\n');
        for k = 1:numel(reg)
            fprintf('    [%d] %s: %s\n', reg(k).id, reg(k).voce, reg(k).valore);
        end
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function reg = local_note(reg, id, voce, valore, rimozione)
%LOCAL_NOTE  Aggiunge una voce al registro delle ipotesi ancora attive.
    reg(end+1) = struct('id', id, 'voce', voce, 'valore', valore, ...
                        'rimozione', rimozione);
end
