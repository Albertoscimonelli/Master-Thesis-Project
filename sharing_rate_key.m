function [SR, ratio] = sharing_rate_key(loadUsers, Einj, xi, mode)
%SHARING_RATE_KEY  "Sharing rate" orario di ciascun utente: peso che premia chi
%   consuma fino a concorrenza dell'energia immessa in rete dalla comunita' e
%   penalizza chi, in quella stessa ora, la supera.
%
%   E' il peso grezzo del metodo M4 di Gianaroli, Ricci, Sdringola, Ancona,
%   Branchini, Melino, "Development of dynamic sharing keys: Algorithms
%   supporting management of renewable energy community and collective self
%   consumption", Energy & Buildings 311 (2024) 114158 (eq. 5 e Fig. 3). Qui
%   NON e' esposto come metodo di ripartizione a se': serve come componente
%   del metodo M5 (pearson_sharing_key_cer.m), che lo combina con la chiave
%   di Pearson. Sta in un helper proprio perche' M5 non duplichi il calcolo.
%
%   FORMULA (default "fig3")
%     ratio(t,i) = load_i(t) / Einj(t)
%
%     SR(t,i) = ratio(t,i)                       se ratio < 1   (retta crescente)
%     SR(t,i) = exp( -xi * (ratio(t,i) - 1) )    se ratio >= 1  (decadimento esp.)
%
%   La funzione e' continua e vale 1 nel punto di massimo ratio = 1, dove il
%   consumo dell'utente eguaglia l'immissione della comunita'. Sotto quella
%   soglia il peso e' semplicemente proporzionale al consumo (chi consuma di
%   piu' condivide di piu', come nel metodo M1 del paper); sopra, il peso
%   decade esponenzialmente per disincentivare il sovraconsumo nelle ore di
%   scarsita'.
%
%   CALIBRAZIONE DI xi
%     Il paper la fissa imponendo SR = 0.5 quando ratio = 1.5 (consumo del 50%
%     superiore all'energia disponibile):
%       0.5 = exp(-xi*0.5)  ->  xi = ln(2)/0.5 ~= 1.386   (default)
%
%   NOTA SULL'EQ. 5 STAMPATA NEL PAPER (importante)
%     L'eq. 5 come composta tipograficamente associa le due espressioni alle
%     condizioni OPPOSTE rispetto a tutto il resto dell'articolo:
%       "exp(-xi*(ratio-1)) se ratio < 1 ;  ratio se ratio >= 1"
%     Che si tratti di un refuso e' dimostrato da tre riscontri concordi:
%       1. Fig. 3 mostra una retta crescente da (0,0) a (1,1) etichettata
%          C_ij/E_inj,j e, oltre ratio = 1, la curva esponenziale decrescente;
%       2. il testo (§2.1.4): "the assumed sharing rate follows an increasing
%          LINEAR trend if the ratio ... is less than 1, while it follows an
%          exponentially decreasing trend if the ratio is greater than 1";
%       3. l'esempio numerico a tre utenti (§2.2, Fig. 8): con C = [0.72 0.24
%          1.56] kWh ed Einj = 1.32 kWh il paper attribuisce SR = 78% a u3
%          (ratio = 1.18, ramo esponenziale) e ripartisce [0.48 0.16 0.68] kWh.
%          Solo la formula implementata qui riproduce quei valori; la versione
%          letterale dell'eq. 5 darebbe [0.72 0.24 0.36].
%     La versione letterale resta disponibile con mode = "eq5" per poterle
%     confrontare, ma NON e' quella con cui il paper ha prodotto i risultati.
%
%   CASI LIMITE
%     Einj(t) <= 0 (es. ore notturne): il rapporto non e' definito e comunque
%     non c'e' energia da condividere in quell'ora. Si pone SR = 0, ed e'
%     allocate_shared_energy a garantire SH = 0 su quelle ore.
%     load_i(t) = 0 con Einj(t) > 0: ratio = 0 e SR = 0, peso nullo - coerente
%     (chi non consuma non puo' ricevere energia condivisa, e verrebbe comunque
%     cappato a 0 dall'algoritmo di ripartizione).
%
%   INPUT
%     loadUsers [H x n]   carico residuo orario di ciascun utente  [kWh/h]
%     Einj      [H x 1]   energia immessa in rete dalla comunita'  [kWh/h]
%     xi        scalare   costante di decadimento esponenziale (opzionale,
%                         default ln(2)/0.5 ~= 1.386)
%     mode      string    "fig3" (default) | "eq5" - vedi la nota sopra
%
%   OUTPUT
%     SR        [H x n]   sharing rate orario, non normalizzato tra utenti
%     ratio     [H x n]   rapporto consumo/immissione (0 dove Einj <= 0)

    [H, n] = size(loadUsers);
    Einj   = Einj(:);

    if numel(Einj) ~= H
        error('sharing_rate_key:sizeMismatch', ...
              'Einj ha %d ore, loadUsers ne ha %d.', numel(Einj), H);
    end
    if nargin < 3 || isempty(xi),   xi   = log(2) / 0.5;      end
    if nargin < 4 || isempty(mode), mode = "fig3";            end
    mode = lower(string(mode));

    if ~isscalar(xi) || ~(xi > 0)
        error('sharing_rate_key:invalidXi', ...
              'xi deve essere uno scalare positivo (default ln(2)/0.5 ~= 1.386).');
    end
    if ~ismember(mode, ["fig3", "eq5"])
        error('sharing_rate_key:invalidMode', ...
              'mode deve essere "fig3" (default) o "eq5", non "%s".', mode);
    end

    % Ore senza immissione: rapporto non definito -> nessun peso (SH sara' 0)
    hasInj = Einj > 0;

    ratio = zeros(H, n);
    if any(hasInj)
        ratio(hasInj, :) = loadUsers(hasInj, :) ./ Einj(hasInj);
    end

    below = ratio < 1;

    SR = zeros(H, n);
    if mode == "fig3"
        SR(below)  = ratio(below);                          % retta crescente
        SR(~below) = exp(-xi * (ratio(~below) - 1));        % decadimento esp.
    else
        SR(below)  = exp(-xi * (ratio(below) - 1));         % eq. 5 letterale
        SR(~below) = ratio(~below);
    end

    SR(~hasInj, :) = 0;
end
