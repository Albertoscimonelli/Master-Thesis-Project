function [v, players, A_inc] = cer_coalition_values(genPV, loadUsers, userNames, P_CER)
%CER_COALITION_VALUES  Funzione caratteristica v(S) del gioco cooperativo CER.
%
%   Calcola il valore v(S) per OGNI coalizione S del gioco, condiviso da tutti
%   i metodi di ripartizione (Shapley, Nucleolus, ...) per garantire che siano
%   confrontabili sulla stessa base.
%
%   GIOCATORI
%     1 produttore (impianto PV) + N consumatori. Il produttore e' il
%     giocatore 1; i consumatori i giocatori 2..N+1.
%
%   VALORE DELLA COALIZIONE  (solo incentivo sull'energia condivisa)
%     v(S) = 0                                       se il PV non e' in S
%     v(S) = sum_t min(genPV(t), load_S(t)) * P_CER   altrimenti
%   dove load_S(t) e' la somma dei carichi dei soli consumatori presenti in S.
%
%   INPUT
%     genPV     [H x 1]   generazione PV oraria               [kWh/h]
%     loadUsers [H x nC]  carichi orari dei consumatori        [kWh/h]
%     userNames [1 x nC]  nomi dei consumatori                 (string)
%     P_CER     scalare   incentivo CER su energia condivisa   [EUR/kWh]
%
%   OUTPUT
%     v       [2^n x 1]  valore di ogni coalizione, indicizzato dalla bitmask
%                        (bit 1 = produttore, bit k+1 = consumatore k); il
%                        valore della coalizione con bitmask m si legge come
%                        v(m+1). Coalizione vuota -> v(1); grande coalizione
%                        -> v(end).
%     players [1 x n]    nomi dei giocatori ("PV" + consumatori)
%     A_inc   [2^n x n]  matrice di incidenza: A_inc(m+1, i) = 1 se il
%                        giocatore i appartiene alla coalizione di bitmask m.

    genPV = genPV(:);                    % vettore colonna [H x 1]
    nC    = size(loadUsers, 2);          % numero consumatori
    n     = nC + 1;                      % giocatori totali (PV = giocatore 1)
    nSub  = 2^n;

    % --- Valore per ogni sottoinsieme di CONSUMATORI (il PV e' un on/off) ----
    vCons = zeros(2^nC, 1);              % indicizzato dalla bitmask consumatori
    for cm = 1:(2^nC - 1)               % cm = 0 -> nessun consumatore -> v = 0
        sel         = bitget(cm, 1:nC) == 1;
        loadC       = sum(loadUsers(:, sel), 2);
        vCons(cm+1) = sum(min(genPV, loadC)) * P_CER;
    end

    % --- Valore di ogni coalizione completa (PV + consumatori) --------------
    v = zeros(nSub, 1);
    for mask = 0:(nSub - 1)
        if bitget(mask, 1) == 1                 % produttore presente
            consMask  = bitshift(mask, -1);     % toglie il bit del produttore
            v(mask+1) = vCons(consMask + 1);
        end
        % produttore assente -> v resta 0
    end

    % --- Matrice di incidenza coalizione/giocatore --------------------------
    masks = (0:nSub-1).';
    A_inc = zeros(nSub, n);
    for i = 1:n
        A_inc(:, i) = bitget(masks, i);
    end

    players = ["PV", string(userNames(:).')];
end
