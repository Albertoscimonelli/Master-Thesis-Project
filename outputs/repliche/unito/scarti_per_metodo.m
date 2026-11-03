function scarti_per_metodo(fVecchio, fNuovo)
% Per taglia e metodo: scarto massimo sulle quote, in rapporto a v(N). Per il VLC lo si
% confronta con la sua tolleranza di convergenza tolConv = 2e-6 * max(1, v(N)).
V = load(fVecchio, 'RESULTS'); V = V.RESULTS;
N = load(fNuovo, 'RESULTS');   N = N.RESULTS;
etV = string({V.etichetta});
righe = {};
for c = 1:numel(N)
    a = N(c); b = V(etV == string(a.etichetta));
    n = numel(a.Tcmp.Giocatore);
    vN = max(1, abs(sum(a.metodi(1).phi)));      % efficienza: ogni metodo somma a v(N)
    for k = 1:numel(a.metodi)
        j = find([b.metodi.nome] == a.metodi(k).nome, 1);
        if isempty(j), continue; end
        d = max(abs(a.metodi(k).phi(:) - b.metodi(j).phi(:))) / vN;
        righe(end+1, :) = {n, a.metodi(k).nome, d}; %#ok<AGROW>
    end
end
T = cell2table(righe, 'VariableNames', {'n', 'Metodo', 'scarto'});
G = groupsummary(T, {'n', 'Metodo'}, 'max', 'scarto');
G = G(G.max_scarto > 1e-11, :);
if isempty(G)
    fprintf('Tutti i metodi entro 1e-11 di v(N) a ogni taglia.\n');
else
    disp(G(:, {'n', 'Metodo', 'max_scarto'}));
end
fprintf('Soglia di convergenza del VLC: 2e-6 di v(N) (tolConv = 2 * tolRel * v(N)).\n');
end
