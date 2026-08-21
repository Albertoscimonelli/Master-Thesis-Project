function H = gini_heterogeneity(userNames, opts)
%GINI_HETEROGENEITY  Indice di eterogeneita' della composizione della comunita'
%   secondo Casalicchio, Manzolini, Prina, Moser, "From investment optimization
%   to fair benefit distribution in renewable energy community modelling",
%   Applied Energy 310 (2022) 118447, eq. 10.
%
%       G = ( 1 - sum_k f_k^2 ) * m / ( m - 1 )
%
%   dove f_k e' la frequenza relativa della k-esima TIPOLOGIA di membro e m il
%   numero totale di membri.
%
%   ATTENZIONE: NON e' un Gini di reddito
%     Nonostante il nome usato nel paper, questo indice non ha nulla a che
%     vedere con l'indice di Gini di gini_index.m. E' un indice di diversita'
%     di Simpson normalizzato: misura quanto sono VARIE le tipologie dei membri
%     della comunita', non quanto e' diseguale la ripartizione dei benefici.
%     Nel paper serve a spiegare perche' comunita' piu' eterogenee sfruttano
%     meglio il Demand Side Management (§4.3: G = 0.83 contro G = 0.71).
%
%   ESTREMI
%     G = 0  massima OMOGENEITA': tutti i membri della stessa tipologia.
%     G = 1  massima ETEROGENEITA': tutte le tipologie distinte, un membro
%            ciascuna. E' il caso in cui l'indice smette di discriminare: con
%            sei membri tutti diversi vale 1 qualunque cosa siano.
%
%   TIPOLOGIE (vedi opts.memberTypes)
%     Di default la tipologia si ricava dal nome utente togliendo l'indice
%     progressivo e il suffisso "_kWh": "household_2_kWh" -> "household". Si
%     ottiene cosi' la categoria di consumo (office, small_industry, retail,
%     household), che sulla community di default da' G = 0.80.
%
%     La granularita' FINE -- i tre template LPG distinti di
%     CER_LoadProfiles/config/simulation_config.yaml (pensionati,
%     coppia_lavoratori, famiglia_1figlio) piu' i tre use case RAMP -- si passa
%     con opts.memberTypes. Su sei membri tutti distinti da' G = 1.00 esatto,
%     cioe' l'indice degenera: e' il motivo per cui il default e' la categoria
%     grossolana. La scelta e' un'IPOTESI e viene registrata in H.assumptions.
%
%   INPUT
%     userNames  [1 x m] nomi degli utenti                        (string)
%     opts       struct opzionale:
%                  .memberTypes  [1 x m] tipologia di ciascun membro, per
%                                sovrascrivere quella dedotta dai nomi
%                  .quiet        non stampare il registro ipotesi (def. false)
%
%   OUTPUT (struct H)
%     .G            scalare  indice di eterogeneita' in [0, 1]
%     .simpson      scalare  sum_k f_k^2 (indice di Simpson non normalizzato)
%     .memberTypes  [1 x m]  tipologia usata per ciascun membro
%     .types        [1 x K]  tipologie distinte trovate
%     .counts       [K x 1]  numerosita' di ciascuna tipologia
%     .freq         [K x 1]  frequenza relativa f_k
%     .nMembers     scalare  m
%     .derivedTypes logico   true se le tipologie sono state dedotte dai nomi
%     .assumptions  table    registro delle ipotesi attive
%     .table        table    riepilogo per tipologia

    if nargin < 2 || isempty(opts), opts = struct(); end

    names = string(userNames(:).');
    m     = numel(names);

    if m < 2
        error('gini_heterogeneity:tooFewMembers', ...
              ['Servono almeno 2 membri: con m = %d il fattore m/(m-1) ' ...
               'dell''eq. 10 non e'' definito.'], m);
    end

    % Snapshot PRIMA dei default: dopo, isfield direbbe true per tutto e il
    % registro non saprebbe piu' distinguere il dato fornito da quello dedotto.
    fornito = struct('memberTypes', isfield(opts, 'memberTypes'));

    if ~isfield(opts, 'quiet'), opts.quiet = false; end

    if fornito.memberTypes
        memberTypes = string(opts.memberTypes(:).');
        if numel(memberTypes) ~= m
            error('gini_heterogeneity:typeSizeMismatch', ...
                  'opts.memberTypes ha %d elementi, gli utenti sono %d.', ...
                  numel(memberTypes), m);
        end
    else
        % [IPOTESI 1] categoria di consumo dedotta dal nome utente
        memberTypes = regexprep(names, '_\d+(_kWh)?$', '');
    end

    % --- Frequenze delle tipologie distinte (eq. 10) -------------------------
    [types, ~, idx] = unique(memberTypes, 'stable');
    counts = accumarray(idx(:), 1, [numel(types) 1]);
    freq   = counts / m;

    simpson = sum(freq.^2);
    G       = (1 - simpson) * m / (m - 1);

    % --- Registro delle ipotesi ---------------------------------------------
    colonneReg = {'Id', 'Voce', 'Valore', 'ComeRimuoverla'};
    reg = struct('id', {}, 'voce', {}, 'valore', {}, 'rimozione', {});
    if ~fornito.memberTypes
        reg = local_note(reg, 1, 'Tipologia dei membri', ...
                         sprintf('categoria dedotta dai nomi (%d tipologie)', numel(types)), ...
                         ['passare opts.memberTypes con la tipologia fine ' ...
                          '(template LPG di simulation_config.yaml)']);
    end
    if isempty(reg)
        H.assumptions = table(zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
                              'VariableNames', colonneReg);
    else
        H.assumptions = sortrows(table([reg.id].', string({reg.voce}).', ...
                                       string({reg.valore}).', string({reg.rimozione}).', ...
                                       'VariableNames', colonneReg), 'Id');
    end

    H.G            = G;
    H.simpson      = simpson;
    H.memberTypes  = memberTypes;
    H.types        = types;
    H.counts       = counts;
    H.freq         = freq;
    H.nMembers     = m;
    H.derivedTypes = ~fornito.memberTypes;
    H.table        = table(types(:), counts, freq, ...
                           'VariableNames', {'Tipologia', 'Membri', 'Frequenza'});

    if ~opts.quiet && ~isempty(reg)
        fprintf('\n  Ipotesi attive (gini_heterogeneity):\n');
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
