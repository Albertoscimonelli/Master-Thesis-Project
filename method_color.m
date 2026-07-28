function c = method_color(method)
%METHOD_COLOR  Colore RGB coerente per un modello di ripartizione dei
%   benefici, condiviso da tutti i grafici (confronto a colonne, grafici a
%   rete). Aggiungere un nuovo modello = aggiungere una riga qui, senza
%   dover toccare i colori nei singoli grafici sparsi nel codice.
%
%   INPUT   method  string  nome del modello (case-insensitive)
%   OUTPUT  c       [1x3]   colore RGB in [0,1]

    switch lower(string(method))
        case "shapley"
            c = [0.20 0.55 0.85];   % blu medio
        case "nucleolo"
            c = [0.08 0.25 0.55];   % blu scuro
        case "nash bargaining"
            c = [0.20 0.60 0.30];   % verde
        otherwise
            c = [0.55 0.35 0.75];   % viola - fallback per modelli futuri
    end
end
