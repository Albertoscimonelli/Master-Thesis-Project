function s = format_duration(secondi)
%FORMAT_DURATION  Una durata in secondi resa nell'unita' che si legge meglio.
%
%   PERCHE' NON BASTA STAMPARE I SECONDI
%     "412.7 s" costringe chi legge a fare una divisione a mente per capire se
%     sono sette minuti o sette ore. Le cifre in piu' non aggiungono nulla:
%     su una durata di minuti i decimi di secondo sono rumore, e su una di ore
%     lo sono anche i secondi. La soglia si sceglie percio' sul valore, non
%     una volta per tutte.
%
%   INPUT
%     secondi  scalare  durata                                    [s]
%
%   OUTPUT
%     s        string   la stessa durata, formattata
%
%   Esempi
%     format_duration(3.7)    -> "3.7 s"
%     format_duration(95)     -> "1 min 35 s"
%     format_duration(4830)   -> "1 h 20 min"

    if ~isscalar(secondi) || ~isnumeric(secondi) || ~isfinite(secondi)
        s = "n/d";
        return
    end

    secondi = double(secondi);
    if secondi < 0
        s = "n/d";                    % un orologio che va all'indietro non si stampa
        return
    end

    if secondi < 60
        s = sprintf('%.1f s', secondi);
    elseif secondi < 3600
        m = floor(secondi / 60);
        r = round(secondi - 60*m);
        if r == 60                    % l'arrotondamento puo' portare a "3 min 60 s"
            m = m + 1; r = 0;
        end
        s = sprintf('%d min %02d s', m, r);
    else
        h = floor(secondi / 3600);
        m = round((secondi - 3600*h) / 60);
        if m == 60
            h = h + 1; m = 0;
        end
        s = sprintf('%d h %02d min', h, m);
    end

    s = string(s);
end
