function [v, players, A_inc] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER)
%CER_COALITION_VALUES  Funzione caratteristica v(S) del gioco cooperativo CER.
%
%   Calcola il valore v(S) per OGNI coalizione S del gioco, condiviso da tutti
%   i metodi di ripartizione (Shapley, Nucleolo, Nash, ...) per garantire che
%   siano confrontabili sulla stessa base.
%
%   GIOCATORI: UN GIOCATORE PER UTENTE
%     Ogni utente della comunita' e' UN giocatore che porta con se' sia il
%     proprio carico sia la propria produzione. Un utente senza impianto ha
%     generazione nulla (puro consumatore); un utente con impianto e' un
%     PROSUMER e contribuisce a entrambi i lati del bilancio.
%
%     Non esiste piu' un giocatore "PV" aggregato: con piu' impianti di
%     proprietari diversi quel modello sommava tutte le produzioni in un unico
%     giocatore fittizio, rendendo impossibile distinguere chi avesse prodotto
%     cosa. Ora la ripartizione attribuisce nativamente il merito della
%     produzione al prosumer che la possiede.
%
%   VALORE DELLA COALIZIONE  (solo incentivo sull'energia condivisa)
%     v(S) = sum_t min( sum_{i in S} gen_i(t),  sum_{i in S} load_i(t) ) * P_CER(t)
%   P_CER puo' essere uno scalare (incentivo costante) o un vettore [H x 1]
%   (incentivo orario, es. la tariffa TIP_h di compute_cer_incentive.m).
%
%   NETTING DIETRO AL CONTATORE
%     genUsers e loadUsers sono attesi gia' al NETTO dell'autoconsumo di
%     ciascun utente (vedi load_cer_data.m): per ogni ora un utente ha
%     eccedenza OPPURE carico residuo, mai entrambi. Ne segue che v({i}) = 0
%     per ogni singolo giocatore: da solo nessuno condivide nulla, serve
%     almeno un prosumer in eccedenza e un utente con carico residuo.
%
%   INPUT
%     genUsers  [H x nU]  eccedenza oraria di ciascun utente     [kWh/h]
%                         (colonna di zeri se l'utente non ha impianti)
%     loadUsers [H x nU]  carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x nU]  nomi degli utenti                       (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%
%   OUTPUT
%     v       [2^n x 1]  valore di ogni coalizione, indicizzato dalla bitmask
%                        (bit i = giocatore i); il valore della coalizione con
%                        bitmask m si legge come v(m+1). Coalizione vuota ->
%                        v(1); grande coalizione -> v(end).
%     players [1 x n]    nomi dei giocatori (= userNames)
%     A_inc   [2^n x n]  matrice di incidenza: A_inc(m+1, i) = 1 se il
%                        giocatore i appartiene alla coalizione di bitmask m.

    n    = size(loadUsers, 2);           % un giocatore per utente
    nSub = 2^n;

    if size(genUsers, 2) ~= n
        error('cer_coalition_values:sizeMismatch', ...
              'genUsers ha %d colonne, loadUsers ne ha %d: serve una colonna per utente.', ...
              size(genUsers, 2), n);
    end

    % --- Valore di ogni coalizione ------------------------------------------
    v = zeros(nSub, 1);
    for mask = 1:(nSub - 1)             % mask = 0 -> coalizione vuota -> v = 0
        sel       = bitget(mask, 1:n) == 1;
        genS      = sum(genUsers(:,  sel), 2);
        loadS     = sum(loadUsers(:, sel), 2);
        v(mask+1) = sum(min(genS, loadS) .* P_CER(:));
    end

    % --- Matrice di incidenza coalizione/giocatore --------------------------
    masks = (0:nSub-1).';
    A_inc = zeros(nSub, n);
    for i = 1:n
        A_inc(:, i) = bitget(masks, i);
    end

    players = string(userNames(:).');
end
