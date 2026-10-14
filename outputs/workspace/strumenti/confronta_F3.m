% Regressione Fase 3 (inclusione): si aggiunge una colonna, il resto non si muove.
SP = 'C:/Users/scimo/AppData/Local/Temp/claude/c--Users-scimo-desktop-Project/200f4791-c7f0-46bd-a06d-6c29b6499a52/scratchpad';
A = load(fullfile(SP, 'base_F3', 'run.mat'));
B = load(fullfile(SP, 'runF3.mat'));
ok = true;
fprintf('%-11s %5s %4s %10s %8s  %s\n', 'Scheda', 'n', 'NVu', 'Tfair=', 'ES=1', 'Inclusione min..max (metodi)');
for c = 1:numel(A.RESULTS)
    a = A.RESULTS(c); b = B.RESULTS(c);
    [~, nome] = fileparts(char(a.scheda));
    inc = b.Tfair.InclusioneLIHC;
    Tb = b.Tfair; Tb.InclusioneLIHC = [];
    idT = isequaln(a.Tfair, Tb) && isequaln([a.metodi.phi], [b.metodi.phi]) && isequaln(a.NPV, b.NPV);
    iES = find(b.Tfair.Metodo == "Equal Split", 1);
    nanTutti = all(isnan(inc));
    esUno = nanTutti || abs(inc(iES) - 1) < 1e-12;
    ok = ok && idT && esUno;
    if nanTutti
        fprintf('%-11s %5d %4s %10d %8d  NaN (nessun vulnerabile)\n', nome, b.nUsers, '0', idT, esUno);
    else
        [mn, im] = min(inc); [mx, iM] = max(inc);
        fprintf('%-11s %5d %4s %10d %8d  %.2f (%s) .. %.2f (%s)\n', nome, b.nUsers, '>=1', idT, esUno, ...
                mn, b.Tfair.Metodo(im), mx, b.Tfair.Metodo(iM));
    end
end
GA = A.AGR; GB = B.AGR;
okI = isequal(setdiff(GB.indicators, GA.indicators), "InclusioneLIHC") && all(ismember(GA.indicators, GB.indicators));
[~, iI] = ismember(GA.indicators, GB.indicators);
okS = isequaln(GA.scores, GB.scores(:, iI, :)) && isequaln(GA.tau, GB.tau(iI, iI, :)) ...
      && isequaln(GA.tolTie, GB.tolTie(iI, :)) && isequal(GA.methods, GB.methods);
fprintf('\nUnico indicatore nuovo = InclusioneLIHC: %d; punteggi, tau e tolleranze degli altri identici: %d\n', okI, okS);
jI = find(GB.indicators == "InclusioneLIHC");
fprintf('Comunita'' in cui l''inclusione discrimina: %d su %d\n', nnz(GB.discrimina(jI, :)), numel(GB.schede));
ok = ok && okI && okS;
if ok, disp('ESITO: tutte le attese verificate'); else, disp('ESITO: ATTESE VIOLATE'); end
