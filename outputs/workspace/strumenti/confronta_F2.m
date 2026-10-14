% Regressione Fase 2 (pulizia): cosa deve restare e cosa deve cambiare.
SP = 'C:/Users/scimo/AppData/Local/Temp/claude/c--Users-scimo-desktop-Project/200f4791-c7f0-46bd-a06d-6c29b6499a52/scratchpad';
A = load(fullfile(SP, 'base_F2', 'run.mat'));
B = load(fullfile(SP, 'runF2.mat'));
ok = true;
for c = 1:numel(A.RESULTS)
    a = A.RESULTS(c); b = B.RESULTS(c);
    [~, nome] = fileparts(char(a.scheda));
    Tb = b.Tfair;
    pctOk = max(abs(Tb.EccessoMax_pct_vN - 100 * Tb.EccessoMax_EUR / b.vGrand), [], 'omitnan') < 1e-12 ...
            || all(isnan(Tb.EccessoMax_pct_vN));
    Tb.EccessoMax_pct_vN = [];
    idT  = isequaln(a.Tfair, Tb);
    idP  = isequaln([a.metodi.phi], [b.metodi.phi]) && isequaln(a.NPV, b.NPV) && isequaln(a.Tcmp, b.Tcmp);
    ok = ok && pctOk && idT && idP;
    fprintf('%-11s Tfair (senza la colonna nuova) identica=%d, colonna %%vN corretta=%d, quote/VAN/Tcmp identici=%d\n', ...
            nome, idT, pctOk, idP);
end

GA = A.AGR; GB = B.AGR;
fprintf('\nMetodi prima (%d): %s\nMetodi dopo  (%d): %s\n', numel(GA.methods), strjoin(GA.methods, ', '), ...
        numel(GB.methods), strjoin(GB.methods, ', '));
fprintf('Indicatori prima (%d): %s\nIndicatori dopo  (%d): %s\n', numel(GA.indicators), ...
        strjoin(GA.indicators, ', '), numel(GB.indicators), strjoin(GB.indicators, ', '));
okM = isequal(setdiff(GA.methods, GB.methods), "Adaptive Sampling Shapley") && all(ismember(GB.methods, GA.methods));
okI = isequal(sort(setdiff(GA.indicators, GB.indicators)), sort(["ForzaIncentivante_lordo", "QuoteNulle"]));
[~, iM] = ismember(GB.methods, GA.methods);
[~, iI] = ismember(GB.indicators, GA.indicators);
okS = isequaln(GA.scores(iM, iI, :), GB.scores);
nTol = nnz(abs(GA.tolTie(iI, :) - GB.tolTie) > 1e-12);
fprintf('Metodi esclusi = solo AS: %d; indicatori esclusi = QuoteNulle + IS lordo: %d; punteggi dei rimasti identici: %d\n', okM, okI, okS);
fprintf('Tolleranze di pareggio cambiate (escursione senza AS): %d su %d (indicatore x comunita'')\n', nTol, numel(GB.tolTie));
ok = ok && okM && okI && okS;

% tau medio prima/dopo fra gli indicatori rimasti
tA = mean(GA.tau(iI, iI, :), 3, 'omitnan'); tB = mean(GB.tau, 3, 'omitnan');
d = abs(tA - tB); d(logical(eye(size(d)))) = 0;
fprintf('Variazione massima del tau medio fra indicatori rimasti: %.3f (media %.3f)\n', max(d(:)), mean(d(:), 'omitnan'));

if ok, disp('ESITO: tutte le attese verificate'); else, disp('ESITO: ATTESE VIOLATE'); end
