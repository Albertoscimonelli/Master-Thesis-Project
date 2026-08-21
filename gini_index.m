function g = gini_index(x)
%GINI_INDEX  Indice di Gini di una distribuzione, formula standard su vettore
%   ordinato in senso crescente (Farris, 2010).
%
%       G = 2 * sum_{h=1..m} h * x_(h) / (m * sum_h x_h)  -  (m + 1) / m
%
%   dove x_(h) e' il vettore ORDINATO in modo crescente. Vale 0 per una
%   distribuzione perfettamente uguale e tende a 1 quando tutto il valore si
%   concentra su un solo elemento.
%
%   DOVE VIENE USATO
%     - eq. 2.8 di Marrasso et al. 2025 (weighted_solidarity_cer.m), per il
%       fronte di Pareto tra equita' e reddito degli utenti a rischio;
%     - eq. 15 e 19 di Dynge & Cali 2025 (fairness_indicators_lem.m), dove
%       l'Equality Index e' definito ROVESCIATO, EI = 1 - G, cosi' che il
%       valore 1 indichi la distribuzione piu' equa come per gli altri
%       indicatori di quel paper.
%
%   CASI LIMITE
%     Vettore vuoto o somma non positiva -> 0. Non e' una scelta estetica: con
%     somma nulla il denominatore sparisce e l'indice non e' definito, mentre
%     restituire 0 ("nessuna disuguaglianza misurabile") mantiene EI = 1 e non
%     propaga NaN nelle medie pesate delle eq. 18-19.
%
%   INPUT
%     x   vettore (riga o colonna) di valori non negativi
%
%   OUTPUT
%     g   scalare, indice di Gini in [0, 1)

    if ~all(isfinite(x), 'all')
        error('gini_index:nonFiniteInput', ...
              'Vettore con NaN o Inf in ingresso: controllare i dati a monte.');
    end

    x = sort(x(:));
    m = numel(x);
    if m == 0 || sum(x) <= 0
        g = 0;
        return;
    end
    idx = (1:m).';
    g = (2 * sum(idx .* x)) / (m * sum(x)) - (m + 1) / m;
end
