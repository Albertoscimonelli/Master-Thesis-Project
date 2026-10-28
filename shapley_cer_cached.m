function S = shapley_cer_cached(genUsers, loadUsers, userNames, P_CER, opts)
%SHAPLEY_CER_CACHED  Copia di shapley_cer.m per MAIN2 (Fase 7a) che accetta la
%   funzione caratteristica gia' calcolata, per non enumerare di nuovo le 2^n
%   coalizioni quando lo stesso v(S) serve anche a Nucleolo ed eccesso di
%   coalizione. Opzioni in piu':
%     opts.v        [2^n x 1]  v(S) da cer_coalition_values, stessi argomenti
%     opts.players  [1 x n]    secondo output di cer_coalition_values
%   Senza opts.v il comportamento e' quello di shapley_cer.m. La somma sulle
%   coalizioni e' vettorizzata (vedi sotto), quindi rispetto a shapley_cer.m
%   phi coincide a meno dell'arrotondamento, non bit per bit: il confronto
%   con l'originale e' in test_speedup_vlc_shapley.m.
%
%SHAPLEY_CER  Ripartizione dell'incentivo CER sull'energia condivisa tramite
%   Shapley value (gioco cooperativo, Moncecchi et al., Appl. Sci. 2020).
%
%   GIOCATORI
%     Un giocatore per utente: ciascuno porta con se' il proprio carico
%     residuo e la propria eccedenza di produzione (nulla se non ha impianti).
%
%   VALORE DELLA COALIZIONE  (solo incentivo sull'energia condivisa)
%     v(C) = sum_t min( sum_{i in C} gen_i(t), sum_{i in C} load_i(t) ) * P_CER(t)
%   P_CER puo' essere uno scalare o un vettore [H x 1] (incentivo orario).
%   Serve almeno un prosumer in eccedenza e almeno un utente con carico
%   residuo: da solo nessun giocatore condivide nulla, quindi v({i}) = 0.
%
%   SHAPLEY VALUE  (eq. 39 del paper)
%     phi_i = sum_{C subset N\{i}} |C|!(n-|C|-1)!/n! * (v(C+i) - v(C))
%   ossia la media, su tutti gli ordini di formazione della grande coalizione,
%   del contributo marginale del giocatore i. Con N piccolo lo Shapley e'
%   calcolato in forma ESATTA su ogni singolo utente, senza l'approssimazione
%   per gruppi adottata nel paper (necessaria solo per centinaia di utenti).
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente    [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                     (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct opzionale:
%                 .F      scalare  fattore di riduzione per contributo in
%                         conto capitale (def. 0 = nessuna decurtazione)
%                 .esente [n x 1] logico, membri esenti da F. La quota esente
%                         entra in v(C) COALIZIONE PER COALIZIONE, non con la
%                         media di comunita': vedi cer_shared_value.m
%
%   OUTPUT (struct S)
%     .players    [1 x n]  nomi dei giocatori (= userNames)
%     .phi        [n x 1]  Shapley value di ciascun giocatore   [EUR]
%     .vGrand     scalare  valore della grande coalizione       [EUR]
%     .isProsumer [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare  scalare  quota totale ai prosumer             [EUR]
%     .consShare  scalare  quota totale ai consumatori puri     [EUR]
%     .table      table    riepilogo (giocatore, quota, percentuale)

    n = size(loadUsers, 2);              % un giocatore per utente

    if n > 20
        warning('shapley_cer:bigGame', ...
            ['Gioco con %d giocatori: 2^%d coalizioni. ' ...
             'Il calcolo esatto puo'' essere oneroso; valutare il ' ...
             'raggruppamento dei consumatori.'], n, n);
    end

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'esente'), opts.esente = []; end
    if ~isfield(opts, 'F'),      opts.F      = 0;  end

    % --- Funzione caratteristica v(S) condivisa con gli altri metodi --------
    % Bitmask su n bit: bit i = giocatore i.
    if isfield(opts, 'v')
        % Cache passata dal chiamante: deve essere esattamente l'output di
        % cer_coalition_values sugli stessi argomenti, non una sua copia rifatta.
        v       = opts.v;
        players = opts.players;
        if numel(v) ~= 2^n || numel(players) ~= n
            error('shapley_cer_cached:cacheSizeMismatch', ...
                  'opts.v deve avere 2^%d elementi e opts.players %d.', n, n);
        end
    else
        [v, players] = cer_coalition_values(genUsers, loadUsers, userNames, ...
                                            P_CER, opts.esente, opts.F);
    end
    nSub = numel(v);

    % --- Pesi di Shapley w(s) = s!(n-s-1)!/n! in funzione di s = |C| ---------
    w = zeros(n, 1);
    for s = 0:(n-1)
        w(s+1) = factorial(s) * factorial(n - s - 1) / factorial(n);
    end

    % --- Calcolo dello Shapley value di ogni giocatore ----------------------
    % Vettorizzato sulle coalizioni (il doppio ciclo su n * 2^n bitmask costava
    % minuti a n = 18). Cardinalita' |C| di ogni bitmask, per raddoppio:
    % le bitmask col bit i acceso hanno un giocatore in piu' di quelle senza.
    card = zeros(nSub, 1);
    len  = 1;
    for i = 1:n
        card(len+1:2*len) = card(1:len) + 1;
        len = 2 * len;
    end
    wC = w(min(card, n-1) + 1);          % la grande coalizione non e' mai una C

    % Con v rimodellato in [bit_i x 2 x resto] la seconda dimensione e' il bit
    % i: (:,1,:) sono le C senza i, (:,2,:) le stesse C piu' i, nello stesso
    % ordine. Stessa somma del ciclo originale, in un ordine diverso: gli
    % scarti sono di arrotondamento (~1e-12 relativi), non di formula.
    v   = v(:);
    phi = zeros(n, 1);
    for i = 1:n
        bit_i  = 2^(i-1);
        V      = reshape(v,  bit_i, 2, []);
        W      = reshape(wC, bit_i, 2, []);
        phi(i) = sum(W(:, 1, :) .* (V(:, 2, :) - V(:, 1, :)), 'all');
    end

    % --- Output -------------------------------------------------------------
    vGrand = v(end);                     % grande coalizione = tutti i bit a 1

    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = phi;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(phi(isProsumer));
    S.consShare  = sum(phi(~isProsumer));
    S.table      = table(players(:), phi, 100*phi/vGrand, ...
                         'VariableNames', {'Giocatore', 'Shapley_EUR', 'Quota_pct'});
end
