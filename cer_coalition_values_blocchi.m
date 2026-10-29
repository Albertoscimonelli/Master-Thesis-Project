function [v, players, A_inc] = cer_coalition_values_blocchi(genUsers, loadUsers, userNames, P_CER, esente, F)
%CER_COALITION_VALUES_BLOCCHI  v(S) per tutte le 2^n coalizioni, a blocchi vettorizzati.
%
%   [v, players, A_inc] = cer_coalition_values_blocchi(genUsers, loadUsers, userNames, ...
%                                                      P_CER, esente, F)
%
%   Stessi argomenti, stesse uscite e stesso ordine di cer_coalition_values (vedi il suo
%   help per il gioco, il fattore F e il netting dietro al contatore), senza il ciclo sulle
%   2^n bitmask. E' l'enumerazione con cui variance_least_core_cer separa da 19 a 25
%   giocatori (enumerate_values, PR #69), resa disponibile anche a Shapley, Nucleolo ed
%   eccesso di coalizione: a 18 giocatori v(S) passa da 50-70 s a circa 1 s con F = 0.
%   Con F > 0 il guadagno e' minore (circa 4 volte a 16 giocatori): la quota esente
%   si calcola ora per ora su tutto il blocco.
%
%   L'ALGORITMO (lo stesso di enumerate_values, riga per riga)
%     Si tengono le sole ore con generazione E carico nella comunita': nelle altre
%     min(gen, load) = 0 per ogni coalizione. I primi k = min(n, 8) giocatori formano il
%     blocco "basso": i loro 2^k profili aggregati si costruiscono una volta sola
%     ([Hs x 2^k]). Per ognuna delle 2^(n-k) combinazioni dei giocatori rimanenti si somma
%     il loro profilo a tutte le colonne del blocco e si valutano 2^k coalizioni con una
%     sola operazione matriciale.
%
%   DIFFERENZE DA cer_coalition_values
%     Solo l'ordine delle somme (prima sui giocatori a blocchi, poi sulle ore con un
%     prodotto scalare): su v(S) al piu' 2e-15 relativo nei giochi di
%     test_cer_coalition_values_blocchi; su 12 schede vere (5-18 membri, con PA e
%     imprese) risultati entro 8e-14 e tabelle identiche al byte
%     (outputs/repliche/controlli_fase1/). La formula di cer_shared_value e' riscritta qui in
%     forma vettoriale, come in variance_least_core_cer: se cambia quella, vanno cambiate
%     tutte e tre.
%
%   A_inc si costruisce solo se richiesta come terzo output: a 25 giocatori sarebbe
%   [2^25 x 25], 6,7 GB.
%
%   Vedi anche: cer_coalition_values, cer_shared_value, variance_least_core_cer

    n = size(loadUsers, 2);              % un giocatore per utente

    if size(genUsers, 2) ~= n
        error('cer_coalition_values_blocchi:sizeMismatch', ...
              'genUsers ha %d colonne, loadUsers ne ha %d: serve una colonna per utente.', ...
              size(genUsers, 2), n);
    end

    % --- Fattore F ed esenzione (come in cer_coalition_values) -------------
    if nargin < 6 || isempty(F), F = 0; end
    if nargin < 5 || isempty(esente)
        esente = false(n, 1);
    else
        esente = logical(esente(:));
        if numel(esente) ~= n
            error('cer_coalition_values_blocchi:exemptSizeMismatch', ...
                  'esente ha %d elementi, i giocatori sono %d.', numel(esente), n);
        end
    end

    H = size(loadUsers, 1);
    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    % --- Valore di ogni coalizione, a blocchi -------------------------------
    keep = sum(genUsers, 2) > 0 & sum(loadUsers, 2) > 0;
    g    = genUsers(keep, :);
    l    = loadUsers(keep, :);
    p    = P_CER(keep).';                          % [1 x Hs]

    conF = F ~= 0;
    if conF
        e = l .* double(esente.');                 % carico dei soli esenti
    end

    k    = min(n, 8);                              % blocco [Hs x 256]
    nLow = 2^k;
    GL   = local_block_sums(g(:, 1:k));
    LL   = local_block_sums(l(:, 1:k));
    gH   = g(:, k+1:end);
    lH   = l(:, k+1:end);
    if conF
        EL = local_block_sums(e(:, 1:k));
        eH = e(:, k+1:end);
    end

    v = zeros(2^n, 1);
    for h = 0:(2^(n-k) - 1)
        b  = bitget(h, 1:(n-k)).';                 % giocatori "alti" presenti
        lS = LL + lH * b;
        sh = min(GL + gH * b, lS);
        if conF
            eS      = EL + eH * b;
            wEs     = zeros(size(lS));
            ok      = lS > 0;
            wEs(ok) = min(eS(ok) ./ lS(ok), 1);
            sh      = sh .* (1 - F * (1 - wEs));
        end
        v(h*nLow + (1:nLow)) = p * sh;
    end

    % --- Matrice di incidenza, solo se serve ---------------------------------
    if nargout >= 3
        masks = (0:2^n-1).';
        A_inc = zeros(2^n, n);
        for i = 1:n
            A_inc(:, i) = bitget(masks, i);
        end
    end

    players = string(userNames(:).');
end


function M = local_block_sums(A)
%LOCAL_BLOCK_SUMS  M(:, m+1) = somma delle colonne di A selezionate dalla bitmask m.

    k   = size(A, 2);
    M   = zeros(size(A, 1), 2^k);
    len = 1;
    for i = 1:k
        M(:, len+1:2*len) = M(:, 1:len) + A(:, i);
        len = 2 * len;
    end
end
