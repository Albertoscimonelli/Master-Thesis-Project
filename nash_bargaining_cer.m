function S = nash_bargaining_cer(genUsers, loadUsers, userNames, P_CER, opts)
%NASH_BARGAINING_CER  Ripartizione dei ricavi CER tramite la soluzione di
%   Nash Bargaining pesata (General Nash Bargaining, GNB), adattata dal
%   modello di Yan et al., "Optimal scheduling strategy and benefit
%   allocation of multiple virtual power plants based on general Nash
%   bargaining theory", Int. J. Electr. Power Energy Syst. 152 (2023) 109218.
%
%   Usa la STESSA funzione caratteristica v(S) di Shapley/Nucleolo
%   (cer_coalition_values), cosi' i tre metodi sono direttamente
%   confrontabili.
%
%   IDEA (eq. 29 del paper)
%     Il problema di bargaining generale e'
%         max prod_i (x_i - d_i)^alpha_i   s.t.  x_i >= d_i,  sum_i x_i = v(N)
%     dove d_i e' il punto di disaccordo (quanto ottiene il giocatore i se
%     NON partecipa) e alpha_i il suo potere contrattuale. Per un gioco a
%     utilita' trasferibile come questo (un'unica "torta" v(N) da dividere,
%     nessun altro vincolo congiunto) la soluzione in forma chiusa e':
%         x_i = d_i + (alpha_i / sum_j alpha_j) * (v(N) - sum_j d_j)
%     ossia ciascun giocatore incassa il proprio punto di disaccordo piu'
%     una quota del surplus proporzionale al proprio potere contrattuale.
%
%   ADATTAMENTO AL GIOCO CER (una sola grande coalizione, niente scambi
%   P2P multi-VPP come nel paper originale):
%     - Punto di disaccordo d_i = v({i}): il valore che il giocatore i
%       otterrebbe da solo. In questo gioco v({i}) = 0 per TUTTI: eccedenza e
%       carico residuo di un utente sono complementari (dove produce in
%       eccesso non ha carico da coprire), quindi da solo non condivide nulla.
%       d_i = 0 per costruzione, nessun ricavo CER senza partecipare.
%     - Potere contrattuale alpha_i = contributo marginale alla grande
%       coalizione, v(N) - v(N \ {i}): quanto la coalizione perderebbe se
%       il giocatore i si ritirasse. E' l'equivalente del "contribution
%       factor" del paper (eq. 42), qui calcolato direttamente dalla
%       funzione caratteristica gia' disponibile invece che da un indice
%       euristico basato sull'energia scambiata in P2P.
%     Con d_i = 0 la formula si riduce a x_i = alpha_i / sum(alpha) * v(N):
%     ripartizione proporzionale al contributo marginale di ciascuno.
%
%   NOTA: un prosumer che sia l'unico a produrre e' un giocatore ESSENZIALE
%   (senza di lui v(S) = 0 per qualsiasi S), quindi il suo contributo
%   marginale alpha_i = v(N) risulta molto piu' grande di quello degli altri:
%   e' una proprieta' nota e accettata in teoria dei giochi cooperativi.
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente     [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                      (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct opzionale:
%                 .F      scalare  fattore di riduzione per contributo in
%                         conto capitale (def. 0 = nessuna decurtazione)
%                 .esente [n x 1] logico, membri esenti da F. La quota esente
%                         entra in v(S) COALIZIONE PER COALIZIONE, non con la
%                         media di comunita': vedi cer_shared_value.m
%
%   OUTPUT (struct S)
%     .players    [1 x n]  nomi dei giocatori (= userNames)
%     .phi        [n x 1]  ripartizione Nash Bargaining          [EUR]
%     .vGrand     scalare  valore della grande coalizione        [EUR]
%     .isProsumer [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare  scalare  quota totale ai prosumer              [EUR]
%     .consShare  scalare  quota totale ai consumatori puri      [EUR]
%     .d          [n x 1]  punti di disaccordo (threat point)     [EUR]
%     .alpha      [n x 1]  potere contrattuale (contributo marginale) [EUR]
%     .table      table    riepilogo (giocatore, quota, percentuale, potere)

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'esente'), opts.esente = []; end
    if ~isfield(opts, 'F'),      opts.F      = 0;  end

    [v, players, ~] = cer_coalition_values(genUsers, loadUsers, userNames, ...
                                           P_CER, opts.esente, opts.F);
    n         = numel(players);
    nSub      = numel(v);
    maskGrand = nSub - 1;
    vGrand    = v(end);

    % --- Punto di disaccordo: valore stand-alone di ciascun giocatore -------
    d = zeros(n, 1);
    for i = 1:n
        maskSolo = 2^(i-1);
        d(i)     = v(maskSolo + 1);
    end

    % --- Potere contrattuale: contributo marginale alla grande coalizione ---
    alpha = zeros(n, 1);
    for i = 1:n
        maskSenza = maskGrand - 2^(i-1);
        alpha(i)  = vGrand - v(maskSenza + 1);
    end

    if sum(alpha) <= 0
        error('nash_bargaining_cer:degenerate', ...
              ['Somma dei contributi marginali non positiva: impossibile ' ...
               'ripartire (v(N) = 0?).']);
    end

    surplus = vGrand - sum(d);
    x       = d + (alpha / sum(alpha)) * surplus;

    % --- Output ---------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';   % chi porta produzione nel gioco

    S.players    = players;
    S.phi        = x;
    S.vGrand     = vGrand;
    S.isProsumer = isProsumer;
    S.prodShare  = sum(x(isProsumer));
    S.consShare  = sum(x(~isProsumer));
    S.d          = d;
    S.alpha      = alpha;
    S.table     = table(players(:), x, 100*x/vGrand, alpha, ...
                        'VariableNames', ...
                        {'Giocatore', 'NashBargaining_EUR', 'Quota_pct', 'PotereContrattuale_EUR'});
end
