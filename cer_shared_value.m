function val = cer_shared_value(genAgg, loadAgg, P_CER, loadEsAgg, F)
%CER_SHARED_VALUE  Valore di UNA coalizione a partire dai suoi profili AGGREGATI.
%
%   E' la stessa funzione caratteristica di cer_coalition_values.m
%       v = sum_t min( gen(t), load(t) ) * P_CER(t)
%   valutata pero' su una sola coalizione, a partire dalle somme orarie gia'
%   fatte dal chiamante, invece di enumerare tutte le 2^n bitmask. Serve ai
%   metodi che valutano v SU RICHIESTA: costo O(H) per chiamata invece di
%   O(H * 2^n) una volta sola.
%
%   FATTORE F: LA QUOTA ESENTE E' DELLA COALIZIONE, NON DELLA COMUNITA'
%     Con un contributo in conto capitale la tariffa premio e' decurtata del
%     fattore F, che pero' NON si applica all'energia afferente a punti di
%     prelievo esenti (persone fisiche ed enti: vedi cer_reduction_factor.m).
%     Il valore diventa allora
%
%       v = sum_t min(gen, load) * P_CER(t) * [1 - F * (1 - wEs(t))]
%       wEs(t) = quota ESENTE del carico residuo della coalizione nell'ora t
%
%     wEs va calcolata sulla COALIZIONE, non sulla comunita': v(S) e' il
%     contro-fattuale "quanto varrebbe S da sola", e S da sola avrebbe la
%     propria composizione. Sulle schede di questo progetto la quota esente
%     passa da 0% (coalizioni di sole imprese) a 100% (di sole famiglie)
%     contro l'1-20% della comunita' intera: usare la quota di comunita'
%     sottostimerebbe le coalizioni ricche di esenti e farebbe sembrare la
%     CER piu' stabile di quanto sia. Vedi README par. 7.5.
%
%     Il chiamante passa quindi, oltre agli aggregati di generazione e carico,
%     anche l'aggregato del carico dei soli membri ESENTI della coalizione.
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
%     genAgg    [H x 1]  eccedenza oraria aggregata della coalizione   [kWh/h]
%     loadAgg   [H x 1]  carico residuo orario aggregato               [kWh/h]
%     P_CER     [H x 1]  incentivo CER orario, gia' espanso a vettore  [EUR/kWh]
%     loadEsAgg [H x 1]  carico residuo aggregato dei soli membri ESENTI
%                        della coalizione (facoltativo, serve solo se F > 0)
%     F         scalare  fattore di riduzione in [0,1] (def. 0 = nessuna
%                        decurtazione, ed e' il comportamento storico)
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

    % Senza contributo in conto capitale non c'e' decurtazione e non c'e' nulla
    % da esentare: si esce dal ramo veloce, che e' anche quello percorso dalle
    % decine di migliaia di chiamate del campionamento adattivo quando la
    % scheda non dichiara il conto capitale.
    if nargin < 5 || isempty(F) || F == 0
        val = sum(min(genAgg, loadAgg) .* P_CER);
        return
    end

    if nargin < 4 || isempty(loadEsAgg)
        error('cer_shared_value:missingExemptLoad', ...
              ['Con F = %.3f serve anche il carico aggregato dei membri ' ...
               'esenti della coalizione: senza, la quota esente non e'' ' ...
               'definita e F verrebbe applicato a tutti.'], F);
    end
    if ~isequal(size(loadEsAgg), size(loadAgg))
        error('cer_shared_value:exemptSizeMismatch', ...
              'loadEsAgg [%s] e loadAgg [%s] devono avere la stessa forma.', ...
              num2str(size(loadEsAgg)), num2str(size(loadAgg)));
    end

    % Quota esente ORA PER ORA della coalizione. Nelle ore a carico nullo non
    % c'e' energia condivisa da attribuire e wEs resta 0: il fattore moltiplica
    % comunque uno zero, quindi il valore non conta, ma lasciarlo NaN
    % propagherebbe fino alla somma.
    wEs = zeros(size(loadAgg));
    ok  = loadAgg > 0;
    wEs(ok) = min(loadEsAgg(ok) ./ loadAgg(ok), 1);

    val = sum(min(genAgg, loadAgg) .* P_CER .* (1 - F * (1 - wEs)));
end
