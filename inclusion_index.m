function S = inclusion_index(phi, isVulnerable, methodNames, opts)
%INCLUSION_INDEX  Inclusione dei membri in poverta' energetica: quanta parte
%   del montepremi ciascun metodo da' ai vulnerabili LIHC, rispetto a quanti
%   sono.
%
%       Incl_k = ( sum_{i in V} phi_ik / sum_i phi_ik ) / ( |V| / n )
%
%   dove V e' l'insieme dei membri vulnerabili secondo l'indice LIHC
%   (lihc_index.m, la stessa classificazione del Tri-level EP).
%
%   COME SI LEGGE
%     1   i vulnerabili ricevono in proporzione al loro numero: e' il valore
%         dell'Equal Split, per costruzione;
%     > 1 ricevono di piu' (fino a n/|V|, se prendono tutto);
%     < 1 ricevono di meno (0 se non prendono niente).
%     Esempio: 10 membri, 1 vulnerabile, v(N) = 500 EUR. Un metodo che gli da'
%     50 EUR vale (50/500)/(1/10) = 1; uno che gliene da' 25 vale 0,5.
%
%   PERCHE' UN RAPPORTO E NON LA QUOTA NUDA
%     Con 1 vulnerabile su 10 una quota del 10% e' neutra, con 3 su 10 e' una
%     penalizzazione. Dividendo per la quota di membri il valore neutro resta 1
%     a ogni composizione, e le comunita' si confrontano fra loro. E' la stessa
%     normalizzazione delle quote ai prosumer in sintesi_risultati.m.
%
%   CASI LIMITE, E PERCHE' NaN
%     Nessun vulnerabile: l'indicatore non e' definito e vale NaN per tutti i
%     metodi. Zero direbbe "i vulnerabili sono esclusi", che e' falso: non ci
%     sono. compute_indicator_agreement tratta la colonna come non
%     discriminante in quella comunita', come fa con il VAN mancante.
%     Tutti vulnerabili: vale 1 per tutti i metodi (nessuno puo' favorirli
%     rispetto agli altri).
%
%   DIPENDE DA DATI ANCORA SEGNAPOSTO (al 13/10/2026)
%     Chi e' vulnerabile lo decidono tre parametri di scenario_economico.txt
%     oggi a '?': mediana nazionale della spesa energetica (P50), soglia di
%     poverta' per percettore (y*) e markup dal PUN alla bolletta. Finche'
%     restano a '?' il Tri-level usa i propri default e li dichiara; MAIN2.m
%     §3t li ristampa accanto a questo indicatore (README §7.7).
%
%   INPUT
%     phi           [n x m]  quote dei metodi, una colonna per metodo [EUR]
%     isVulnerable  [n x 1]  logico, membri LIHC
%     methodNames   [1 x m]  string
%     opts          .validateSelf  auto-test analitico (def. true)
%
%   OUTPUT (struct S)
%     .index             [m x 1]  Incl_k
%     .quotaVulnerabili  [m x 1]  quota di v(N) ai vulnerabili, in [0,1]
%     .quotaMembri       scalare  |V| / n
%     .nVulnerable       scalare  |V|
%     .methods           [1 x m]  string
%
%   Vedi anche: lihc_index, tri_level_ep_cer, compute_indicator_agreement

    if nargin < 4 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'validateSelf'), opts.validateSelf = true; end
    if opts.validateSelf, local_validate_self(); end

    [n, m] = size(phi);
    isVulnerable = logical(isVulnerable(:));
    if numel(isVulnerable) ~= n
        error('inclusion_index:dimensioni', ...
              'isVulnerable ha %d elementi, phi ha %d membri.', numel(isVulnerable), n);
    end
    methodNames = string(methodNames(:).');
    if numel(methodNames) ~= m
        error('inclusion_index:nomi', '%d nomi per %d metodi.', numel(methodNames), m);
    end

    nVu   = sum(isVulnerable);
    totale = sum(phi, 1).';
    if nVu == 0
        quota = nan(m, 1);
        idx   = nan(m, 1);
    else
        quota = sum(phi(isVulnerable, :), 1).' ./ totale;
        idx   = quota / (nVu / n);
    end

    S.index            = idx;
    S.quotaVulnerabili = quota;
    S.quotaMembri      = nVu / n;
    S.nVulnerable      = nVu;
    S.methods          = methodNames;
end


function local_validate_self()
% Casi costruiti a penna: 5 membri, il secondo e il quarto vulnerabili.
    v   = logical([0 1 0 1 0]).';
    phi = [ 20 20 20 20 20      % uguale per tutti         -> 1
             0 50  0 50  0      % tutto ai vulnerabili     -> 5/2
            25  0 25  0 50      % niente ai vulnerabili    -> 0
            10 30 10 30 20 ].'; % 60% a 2/5 dei membri     -> 1.5
    S = inclusion_index(phi, v, ["U" "T" "Z" "M"], struct('validateSelf', false));
    atteso = [1; 2.5; 0; 1.5];
    assert(max(abs(S.index - atteso)) < 1e-12, 'inclusion_index: auto-test fallito');

    S0 = inclusion_index(phi, false(5, 1), ["U" "T" "Z" "M"], struct('validateSelf', false));
    assert(all(isnan(S0.index)), 'inclusion_index: senza vulnerabili deve valere NaN');

    S1 = inclusion_index(phi, true(5, 1), ["U" "T" "Z" "M"], struct('validateSelf', false));
    assert(max(abs(S1.index - 1)) < 1e-12, 'inclusion_index: tutti vulnerabili deve valere 1');
end
