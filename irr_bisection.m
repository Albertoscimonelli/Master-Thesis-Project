function r = irr_bisection(cf)
%IRR_BISECTION  Internal Rate of Return senza dipendenza da Financial Toolbox.
%
%   r = IRR_BISECTION(cf) risolve per bisezione l'equazione
%       NPV(r) = sum_{t=0}^{n-1} cf(t+1) / (1+r)^t = 0
%   dove cf(1) e' il flusso di cassa all'anno 0 (tipicamente il CAPEX,
%   negativo) e cf(2..n) i flussi degli anni successivi.
%
%   Sostituisce la funzione irr() della Financial Toolbox (non sempre
%   disponibile) con un'implementazione autonoma. Assume un solo cambio
%   di segno nel flusso di cassa (caso tipico: investimento iniziale
%   negativo seguito da ricavi netti positivi); se la funzione NPV non
%   cambia segno nell'intervallo di tassi esplorato [-99%, 1000%],
%   restituisce NaN.
%
%   INPUT
%     cf  [1 x n] o [n x 1]  flussi di cassa, cf(1) = anno 0
%
%   OUTPUT
%     r   scalare  tasso interno di rendimento (frazione, es. 0.08 = 8%);
%                  NaN se non trovato nell'intervallo esplorato

    cf = cf(:);
    n  = numel(cf);
    t  = (0:n-1)';

    npv = @(rate) sum(cf ./ (1 + rate) .^ t);

    rLow  = -0.99;   % appena sopra -100% (evita divisione per zero)
    rHigh = 10;      % 1000%: limite superiore ragionevole per un progetto PV

    fLow  = npv(rLow);
    fHigh = npv(rHigh);

    if ~isfinite(fLow) || ~isfinite(fHigh) || sign(fLow) == sign(fHigh)
        r = NaN;     % nessuna radice nell'intervallo (o nessun cambio di segno)
        return;
    end

    tol     = 1e-8;
    maxIter = 200;
    rMid    = rLow;

    for it = 1:maxIter
        rMid = (rLow + rHigh) / 2;
        fMid = npv(rMid);

        if abs(fMid) < tol || (rHigh - rLow) / 2 < tol
            break;
        end

        if sign(fMid) == sign(fLow)
            rLow = rMid; fLow = fMid;
        else
            rHigh = rMid; fHigh = fMid;
        end
    end

    r = rMid;
end
