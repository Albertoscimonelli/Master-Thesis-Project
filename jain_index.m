function j = jain_index(x)
%JAIN_INDEX  Indice di equita' di Jain (Jain, Chiu, Hawe 1998), il nucleo del
%   Quality of Service usato da Dynge & Cali 2025 (eq. 12 e 18).
%
%       J = ( sum_h x_h )^2 / ( m * sum_h x_h^2 )
%
%   Vale 1 quando tutti gli elementi sono uguali (allocazione perfettamente
%   equa) e 1/m nel caso peggiore, quando tutto il valore va a un solo
%   elemento. Non e' quindi normalizzato a [0,1] ma a [1/m, 1]: con sei utenti
%   il minimo raggiungibile e' 0.167, non 0. Va tenuto presente leggendo i
%   risultati -- un QoS di 0.20 su sei membri e' quasi il peggio possibile,
%   non "il 20% di equita'".
%
%   INTERPRETAZIONE USATA NEL PAPER
%     Dynge & Cali leggono J come la frazione di partecipanti che percepisce
%     il mercato come equo (§6.1.2: "four of the market participants (40%)
%     perceive the market as fair"). E' la lettura classica di Jain: m*J e' il
%     numero equivalente di elementi che si dividono la risorsa in parti
%     uguali.
%
%   CASI LIMITE
%     Vettore vuoto o tutto nullo -> NaN. A differenza del Gini qui NON si
%     ripiega su un valore convenzionale: un'allocazione in cui nessuno riceve
%     nulla non e' "perfettamente equa", e mascherarla con 1 falserebbe le
%     medie pesate dell'eq. 18. Il chiamante deve decidere cosa farne.
%
%   INPUT
%     x   vettore (riga o colonna) di valori non negativi
%
%   OUTPUT
%     j   scalare in [1/m, 1], oppure NaN se x e' vuoto o identicamente nullo

    if ~all(isfinite(x), 'all')
        error('jain_index:nonFiniteInput', ...
              'Vettore con NaN o Inf in ingresso: controllare i dati a monte.');
    end

    x = x(:);
    m = numel(x);
    den = m * sum(x.^2);
    if m == 0 || den <= 0
        j = NaN;
        return;
    end
    j = (sum(x))^2 / den;
end
