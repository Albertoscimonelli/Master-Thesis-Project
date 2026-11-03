function confronta_risultati_stabilita(fVecchio, fNuovo)
% Comunita' per comunita' (stessa etichetta), RESULTS nuovo contro un run di riferimento.
% Le colonne di stabilita' di Tfair (eccesso massimo, coalizioni instabili) si escludono
% dal confronto e si riportano a parte: nel riferimento a 20-25 membri sono NaN.
% Ogni altro campo deve coincidere: si elencano quelli diversi, con lo scarto relativo.
STAB = ["EccessoMax_EUR", "CoalizioniInstabili", "EccessoMax_pct_vN"];
V = load(fVecchio, 'RESULTS'); V = V.RESULTS;
N = load(fNuovo, 'RESULTS');   N = N.RESULTS;
etV = string({V.etichetta});
diversi = containers.Map('KeyType', 'char', 'ValueType', 'double');
for c = 1:numel(N)
    j = find(etV == string(N(c).etichetta), 1);
    assert(~isempty(j), 'manca %s nel riferimento', N(c).etichetta);
    a = N(c); b = V(j);
    for f = string(fieldnames(a)).'
        x = a.(f); y = b.(f);
        if f == "Tfair"
            keep = setdiff(string(x.Properties.VariableNames), STAB, 'stable');
            x = x(:, keep); y = y(:, keep);
        end
        if isequaln(x, y), continue; end
        d = local_scarto(x, y);
        k = char(f);
        if ~isKey(diversi, k), diversi(k) = 0; end
        diversi(k) = max(diversi(k), d);
    end
    T = a.Tfair;
    fprintf('%-24s n=%2d  eccesso max: VLC %9.2f  min %9.2f  max %9.2f EUR | instabili: %s\n', ...
            a.etichetta, numel(a.Tcmp.Giocatore), ...
            T.EccessoMax_EUR(T.Metodo == "Variance Least Core"), min(T.EccessoMax_EUR), ...
            max(T.EccessoMax_EUR), mat2str(T.CoalizioniInstabili.'));
    assert(all(isfinite(T.EccessoMax_EUR)) && all(isfinite(T.CoalizioniInstabili)), ...
           '%s: stabilita'' non calcolata', a.etichetta);
    if ismember("EccessoMax_EUR", string(b.Tfair.Properties.VariableNames)) && ...
            all(isfinite(b.Tfair.EccessoMax_EUR))
        fprintf('    (nel riferimento la stabilita'' c''era: scarto %.2e)\n', ...
                max(abs(T.EccessoMax_EUR - b.Tfair.EccessoMax_EUR)));
    end
end
fprintf('Comunita'' confrontate: %d\n', numel(N));
k = keys(diversi);
if isempty(k)
    fprintf('Tutti i campi coincidono (isequaln), stabilita'' esclusa.\n');
else
    for i = 1:numel(k)
        fprintf('  campo diverso: %-28s scarto relativo massimo %.2e\n', k{i}, diversi(k{i}));
    end
end
end

function d = local_scarto(x, y)
% Scarto relativo massimo fra due valori della stessa forma; Inf se non confrontabili.
d = Inf;
try
    if istable(x)
        d = 0;
        for v = string(x.Properties.VariableNames)
            d = max(d, local_scarto(x.(v), y.(v)));
        end
    elseif isstruct(x)
        if ~isequal(size(x), size(y)), return; end
        d = 0;
        for i = 1:numel(x)
            for f = string(fieldnames(x)).'
                d = max(d, local_scarto(x(i).(f), y(i).(f)));
            end
        end
    elseif isnumeric(x) || islogical(x)
        x = double(x); y = double(y);
        if ~isequal(size(x), size(y)) || ~isequal(isnan(x), isnan(y)), return; end
        m = ~isnan(x);
        d = max([0; abs(x(m) - y(m)) ./ max(1, abs(y(m)))]);
    elseif isequaln(x, y)
        d = 0;
    end
catch
    d = Inf;
end
end
