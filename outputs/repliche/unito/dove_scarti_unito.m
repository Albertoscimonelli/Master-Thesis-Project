function dove_scarti_unito(fVecchio, fNuovo)
% Per taglia: scarto relativo massimo su quote (metodi.phi), Tfair (senza stabilita'), NPV, e
% dove cadono le differenze di forza (campi e valori).
STAB = ["EccessoMax_EUR", "CoalizioniInstabili", "EccessoMax_pct_vN"];
V = load(fVecchio, 'RESULTS'); V = V.RESULTS;
N = load(fNuovo, 'RESULTS');   N = N.RESULTS;
etV = string({V.etichetta});
n = zeros(numel(N), 1); dphi = n; dtf = n; dnpv = n; df = n;
for c = 1:numel(N)
    a = N(c); b = V(etV == string(a.etichetta));
    n(c) = numel(a.Tcmp.Giocatore);
    pa = [a.metodi.phi]; pb = [b.metodi.phi];
    dphi(c) = max(abs(pa(:) - pb(:)) ./ max(1, abs(pb(:))));
    keep = setdiff(string(a.Tfair.Properties.VariableNames), STAB, 'stable');
    x = a.Tfair(:, keep); y = b.Tfair(:, keep); d = 0;
    for v = keep
        if isnumeric(x.(v))
            m = ~isnan(y.(v));
            d = max([d; abs(x.(v)(m) - y.(v)(m)) ./ max(1, abs(y.(v)(m)))]);
        end
    end
    dtf(c) = d;
    dnpv(c) = max(abs(a.NPV(:) - b.NPV(:)) ./ max(1, abs(b.NPV(:))), [], 'omitnan');
    fa = a.forza; fb = b.forza; d = 0;
    for f = string(fieldnames(fa)).'
        if isnumeric(fa.(f)) && isequal(size(fa.(f)), size(fb.(f)))
            x = double(fa.(f)); y = double(fb.(f)); m = ~isnan(y);
            d = max([d; abs(x(m) - y(m)) ./ max(1, abs(y(m)))]);
        elseif ~isequaln(fa.(f), fb.(f))
            d = Inf;
        end
    end
    df(c) = d;
end
for t = unique(n).'
    s = n == t;
    fprintf('n=%2d (%3d comunita''): quote %.1e | Tfair %.1e | NPV %.1e | forza diversa in %d\n', ...
            t, nnz(s), max(dphi(s)), max(dtf(s)), max(dnpv(s)), nnz(df(s)));
end
end
