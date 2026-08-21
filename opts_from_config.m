function opts = opts_from_config(valori, noto, mappa, opts)
%OPTS_FROM_CONFIG  Traduce le chiavi della scheda dati nei campi opts di un
%   metodo, SALTANDO quelle lasciate a '?'.
%
%   E' il punto in cui la convenzione della scheda diventa comportamento del
%   modello. Un campo non passato non e' un campo passato a zero: il metodo
%   applica il proprio default E lo dichiara come ipotesi attiva. Saltare la
%   chiave e' quindi l'unico modo corretto di dire "non lo so", ed e' anche
%   il piu' economico: nessun metodo va modificato.
%
%   INPUT
%     valori  struct dei valori letti      (es. CFG.governance)
%     noto    struct dei flag corrispondenti (es. CFG.noto.governance)
%     mappa   [k x 2] string: colonna 1 = chiave nella scheda,
%                             colonna 2 = nome del campo opts del metodo
%     opts    struct di partenza (facoltativa): i campi gia' presenti
%             restano, quelli della mappa si aggiungono
%
%   OUTPUT
%     opts    struct pronta da passare al metodo
%
%   ESEMPIO
%     opts = opts_from_config(CFG.governance, CFG.noto.governance, [
%                "ct_riserva",        "reservoirFraction"
%                "ct_quota_fissa",    "fixedFraction"    ]);
%
%   Vedi anche: load_cer_input, MAIN

    if nargin < 4 || isempty(opts), opts = struct(); end

    for k = 1:size(mappa, 1)
        chiave = mappa(k, 1);
        campo  = mappa(k, 2);

        % Assente dalla scheda, o presente ma a '?': in entrambi i casi non
        % e' un dato, e il metodo deve poterlo dichiarare come ipotesi.
        if ~isfield(valori, chiave) || ~isfield(noto, chiave) || ~noto.(chiave)
            continue;
        end

        v = valori.(chiave);
        if isnumeric(v) && all(isnan(v))
            continue;   % rete di sicurezza: un NaN non e' mai un dato
        end

        opts.(campo) = v;
    end
end
