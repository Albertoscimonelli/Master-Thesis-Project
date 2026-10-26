function s = etichetta_livello(lv)
%ETICHETTA_LIVELLO  Nome del livello di composizione dal suo codice numerico.
%
%   Il codice e' quello di elenco_schede_cer: 10*k + p, con k imprese (ND) e p PA.
%     0  -> "PA0"   (solo domestici: e' il nome che le tabelle del confronto
%                    con / senza PA usano da sempre per il livello 0)
%     2  -> "PA2"
%     10 -> "ND1"
%     21 -> "ND2_PA1"
%   Accetta un vettore e restituisce un string array della stessa forma.
%
%   Vedi anche: elenco_schede_cer, MAIN2, confronto_pa

    s = strings(size(lv));
    for i = 1:numel(lv)
        k = floor(lv(i) / 10);
        p = mod(lv(i), 10);
        assert(lv(i) >= 0 && lv(i) == round(lv(i)), ...
               'etichetta_livello: codice non valido (%g).', lv(i));
        if k == 0
            s(i) = "PA" + p;
        elseif p == 0
            s(i) = "ND" + k;
        else
            s(i) = "ND" + k + "_PA" + p;
        end
    end
end
