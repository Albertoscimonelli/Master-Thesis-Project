function val = cer_shared_value(genAgg, loadAgg, P_CER)
%CER_SHARED_VALUE  Valore di UNA coalizione a partire dai suoi profili AGGREGATI.
%
%   E' la stessa funzione caratteristica di cer_coalition_values.m
%       v = sum_t min( gen(t), load(t) ) * P_CER(t)
%   valutata pero' su una sola coalizione, a partire dalle somme orarie gia'
%   fatte dal chiamante, invece di enumerare tutte le 2^n bitmask. Serve ai
%   metodi che valutano v SU RICHIESTA: costo O(H) per chiamata invece di
%   O(H * 2^n) una volta sola.
%
%   PERCHE' PRENDE AGGREGATI E NON UNA MASCHERA DI GIOCATORI
%     I tre metodi di Cremers et al. (Appl. Energy 331 (2023) 120328) valutano
%     v anche su coalizioni che NON sono sottoinsiemi di utenti reali: la
%     Stratified Expected Value la valuta su copie di un utente FITTIZIO medio
%     (§4.1.2 del paper), che nessuna bitmask puo' rappresentare. Poiche' la
%     nostra v dipende solo dai profili SOMMATI della coalizione, l'aggregato
%     e' l'unico ingresso di cui ha davvero bisogno, e questa firma copre
%     entrambi i casi senza duplicare la formula.
%
%   INPUT
%     genAgg  [H x 1]  eccedenza oraria aggregata della coalizione   [kWh/h]
%     loadAgg [H x 1]  carico residuo orario aggregato               [kWh/h]
%     P_CER   [H x 1]  incentivo CER orario, gia' espanso a vettore  [EUR/kWh]
%
%   OUTPUT
%     val     scalare  valore della coalizione                       [EUR]

    % Guardia contro l'espansione implicita: un vettore riga al posto di uno
    % colonna produrrebbe in silenzio una matrice [H x H] e una somma priva di
    % senso, invece di un errore. Il controllo costa nulla anche nelle decine
    % di migliaia di chiamate del campionamento adattivo.
    if ~isequal(size(genAgg), size(loadAgg)) || ~isequal(size(genAgg), size(P_CER))
        error('cer_shared_value:sizeMismatch', ...
              ['genAgg [%s], loadAgg [%s] e P_CER [%s] devono avere la stessa ' ...
               'forma di vettore colonna.'], ...
              num2str(size(genAgg)), num2str(size(loadAgg)), num2str(size(P_CER)));
    end

    val = sum(min(genAgg, loadAgg) .* P_CER);
end
