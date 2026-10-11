function AGR = apply_relevance_threshold(AGR, vN, opts)
%APPLY_RELEVANCE_THRESHOLD  Soglia di rilevanza pratica su TUTTI gli indicatori.
%
%   COSA RISOLVE
%     La tolleranza di pareggio di compute_indicator_agreement e' solo numerica
%     (1e-6 dell'escursione): due metodi che differiscono di un millesimo di
%     Gini risultano "in ordine", e ogni scambio di posto fra loro conta come
%     inversione di graduatoria. Con quella tolleranza, su 20 comunita' il 100%
%     dei cambi di segno viene contato; con una soglia del 10% dell'escursione
%     ne sopravvive il 42%. MAIN2 §7b applicava la soglia di rilevanza al solo
%     EccessoMax_EUR (5% di v(N)). Qui la stessa idea vale per ogni indicatore.
%
%   DUE REGOLE, A SECONDA DELL'UNITA'
%     Indicatori in EURO ANNUI (opts.indicatoriEuro, def. EccessoMax_EUR):
%         tol = max(tol_corrente, fracVN * v(N))        def. fracVN = 0.05
%       e' la regola gia' in MAIN2: una differenza minore del 5% del montepremi
%       non cambia in modo apprezzabile la convenienza di nessuno.
%     TUTTI GLI ALTRI (adimensionali, VAN su 20 anni, forza incentivante):
%         tol = max(tol_corrente, fracEscursione * (max - min))   def. 0.10
%       il 5% di v(N) non ha senso per un indice in [0,1] o per un VAN in euro
%       su venti anni. La scala naturale e' l'ESCURSIONE dell'indicatore fra i
%       metodi della stessa comunita': due metodi a meno del 10% dell'ampiezza
%       osservata sono a pari. E' una scelta di modello, non un dato: la soglia
%       e' un parametro, e conviene riportare i risultati anche a 5% e 20%.
%
%   COSA NON TOCCA
%     Il tau-b di Kendall resta calcolato con la tolleranza numerica di
%     compute_indicator_agreement: la soglia agisce su cio' che leggono
%     extract_ranking_reversals, ranking_grid e reversals_by_axis (AGR.tolTie).
%     Idempotente: si puo' applicare due volte, la tolleranza non scende mai.
%
%   INPUT
%     AGR   struct di compute_indicator_agreement
%     vN    [1 x nK] v(N) di ciascuna comunita', nello stesso ordine di AGR.schede
%     opts  struct opzionale:
%             .fracEscursione  def. 0.10
%             .fracVN          def. 0.05
%             .indicatoriEuro  def. "EccessoMax_EUR"
%             .validateSelf    def. true
%
%   OUTPUT
%     AGR   con .tolTie rialzata e il campo .regolaSoglia ([nI x 1] string:
%           "vN" o "escursione"), da riportare nei metodi della tesi.
%
%   Vedi anche: compute_indicator_agreement, indicator_tie_tol, MAIN2 (§7b)

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'fracEscursione'), opts.fracEscursione = 0.10; end
    if ~isfield(opts, 'fracVN'),         opts.fracVN         = 0.05; end
    if ~isfield(opts, 'indicatoriEuro'), opts.indicatoriEuro = "EccessoMax_EUR"; end
    if ~isfield(opts, 'validateSelf'),   opts.validateSelf   = true; end

    if opts.validateSelf
        local_validate_self();
    end

    [~, nI, nK] = size(AGR.scores);
    vN = vN(:).';
    if numel(vN) ~= nK
        error('apply_relevance_threshold:dimensioni', ...
              'vN ha %d elementi, ma le comunita'' sono %d.', numel(vN), nK);
    end

    euro = ismember(string(AGR.indicators(:)), string(opts.indicatoriEuro(:)));
    AGR.regolaSoglia = repmat("escursione", nI, 1);
    AGR.regolaSoglia(euro) = "vN";

    for c = 1:nK
        for j = 1:nI
            if ~AGR.discrimina(j, c), continue; end
            x = AGR.scores(:, j, c);
            if euro(j)
                nuova = opts.fracVN * vN(c);
            else
                nuova = opts.fracEscursione * (max(x) - min(x));
            end
            AGR.tolTie(j, c) = max(AGR.tolTie(j, c), nuova);
        end
    end
end


function local_validate_self()
% Caso a penna: due comunita', due indicatori (uno adimensionale, uno in euro).
    A = struct();
    A.indicators = ["Gini", "EccessoMax_EUR"];
    A.scores = zeros(3, 2, 2);
    A.scores(:, 1, 1) = [0.10; 0.15; 0.50];     % escursione 0.40 -> tol 0.04
    A.scores(:, 2, 1) = [0; 10; 100];           % vN = 200 -> tol 10
    A.scores(:, :, 2) = A.scores(:, :, 1);
    A.discrimina = [true true; true false];     % EccessoMax non discrimina in c=2
    A.tolTie = 1e-6 * ones(2, 2);
    B = apply_relevance_threshold(A, [200 200], struct('validateSelf', false));
    assert(abs(B.tolTie(1, 1) - 0.04) < 1e-12, 'soglia: 10%% dell''escursione');
    assert(abs(B.tolTie(2, 1) - 10) < 1e-12,   'soglia: 5%% di v(N) sull''euro');
    assert(B.tolTie(2, 2) == 1e-6,             'soglia: indicatore piatto non toccato');
    C = apply_relevance_threshold(B, [200 200], struct('validateSelf', false));
    assert(isequal(B.tolTie, C.tolTie),        'soglia: non e'' idempotente');
    assert(isequal(B.regolaSoglia, ["escursione"; "vN"]), 'soglia: regole');
end
