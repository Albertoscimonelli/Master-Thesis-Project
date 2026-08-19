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
        case "variance least core"
            c = [0.85 0.35 0.25];   % rosso mattone
        case "equal split"
            c = [0.60 0.60 0.60];   % grigio
        case "proportional to consumption"
            c = [0.90 0.70 0.15];   % giallo/ocra
        case "remuneration model 1"
            c = [0.75 0.25 0.55];   % magenta
        case "cascading tree"
            c = [0.35 0.75 0.70];   % turchese
        case "weighted solidarity"
            c = [0.95 0.55 0.55];   % rosa salmone
        case "pearson key"
            c = [0.35 0.30 0.65];   % indaco
        case "pearson-sharing rate"
            c = [0.60 0.45 0.20];   % bronzo
        case "similarity-utilization"
            c = [0.50 0.60 0.20];   % verde oliva
        % I tre metodi di Cremers et al. non sono regole di ripartizione
        % autonome ma APPROSSIMAZIONI dello Shapley: tinte chiare della stessa
        % famiglia fredda, cosi' nel grafico di confronto si leggono come un
        % gruppo accanto allo Shapley esatto (blu medio).
        case "marginal contribution"
            c = [0.55 0.78 0.95];   % azzurro chiaro
        case "stratified expected value"
            c = [0.30 0.72 0.88];   % ciano
        case "adaptive sampling shapley"
            c = [0.65 0.55 0.90];   % lavanda
        otherwise
            c = [0.55 0.35 0.75];   % viola - fallback per modelli futuri
    end
end
