% Regressione Fase 1: cosa cambia fra il baseline e la correzione della vendita.
SP = 'C:/Users/scimo/AppData/Local/Temp/claude/c--Users-scimo-desktop-Project/200f4791-c7f0-46bd-a06d-6c29b6499a52/scratchpad';
A = load(fullfile(SP, 'base_F1', 'run.mat'));
B = load(fullfile(SP, 'runF1.mat'));
R0 = A.RESULTS; R1 = B.RESULTS;
assert(numel(R0) == numel(R1));
P_SELL = 0.110; r = 0.04; T = 20;
annuita = (1 - (1 + r)^-T) / r;
fprintf('Fattore di annualita'' (4%%, 20 anni): %.4f\n', annuita);

ok = true;
for c = 1:numel(R0)
    a = R0(c); b = R1(c);
    [~, nome] = fileparts(char(a.scheda));
    assert(strcmp(a.scheda, b.scheda));
    % --- deve restare identico ------------------------------------------------
    idTfair = isequaln(a.Tfair, b.Tfair);
    idPhi   = isequaln([a.metodi.phi], [b.metodi.phi]);
    idTcmp  = isequaln(a.Tcmp, b.Tcmp);
    idEn    = isequaln([a.vGrand a.shared_annual a.sold_annual a.contendibleShare], ...
                       [b.vGrand b.shared_annual b.sold_annual b.contendibleShare]);
    idSog   = isequaln(a.soglia.table, b.soglia.table) && a.soglia.quotaIncentivata == b.soglia.quotaIncentivata;
    idForza = isequaln(a.forza.IS, b.forza.IS) && isequaln(a.forzaLorda.IS, b.forzaLorda.IS);
    % --- deve cambiare, di quanto atteso --------------------------------------
    dRev    = b.rev_tot_annual - a.rev_tot_annual;
    attRev  = a.shared_annual * P_SELL;
    okRev   = abs(dRev - attRev) < 1e-6 * max(1, attRev);
    % VAN: delta per membro = (vendita nuova - vecchia) x annualita', uguale per tutti i metodi
    dNPV = b.NPV - a.NPV;                       % [membri x metodi]
    costante = max(max(dNPV, [], 2) - min(dNPV, [], 2)) < 1e-6;
    dVend = b.Tfin.Vendita_E - a.Tfin.Vendita_E;
    okNPV = max(abs(dNPV(:,1) - dVend * annuita)) < 1e-6 * max(1, max(abs(dNPV(:,1))));
    consumatori = ~b.isProsumer(:);
    okCons = all(abs(dNPV(consumatori, :)) < 1e-9, 'all');
    tutto = idTfair && idPhi && idTcmp && idEn && idSog && idForza && okRev && costante && okNPV && okCons;
    ok = ok && tutto;
    fprintf(['%-11s Tfair=%d phi=%d Tcmp=%d energia=%d soglia=%d forza=%d | dRicavo %7.2f (att. %7.2f) %d | ' ...
             'dVAN uguale fra metodi=%d, = dVendita x annualita''=%d, consumatori invariati=%d | ' ...
             'dVendita max %6.1f EUR/anno, dVAN max %7.1f EUR\n'], ...
            nome, idTfair, idPhi, idTcmp, idEn, idSog, idForza, dRev, attRev, okRev, ...
            costante, okNPV, okCons, max(dVend), max(dNPV(:,1)));
end

% --- AGR: punteggi e tau identici tranne VAN_min --------------------------
jV = find(A.AGR.indicators == "VAN_min_EUR");
altri = setdiff(1:numel(A.AGR.indicators), jV);
idScores = isequaln(A.AGR.scores(:, altri, :), B.AGR.scores(:, altri, :));
idTau    = isequaln(A.AGR.tau(altri, altri, :), B.AGR.tau(altri, altri, :));
cambVAN  = ~isequaln(A.AGR.scores(:, jV, :), B.AGR.scores(:, jV, :));
fprintf('\nAGR: punteggi non-VAN identici=%d, tau non-VAN identici=%d, VAN_min cambiato=%d\n', ...
        idScores, idTau, cambVAN);
ok = ok && idScores && idTau;

% --- Prosumer con VAN negativo, prima e dopo -------------------------------
neg0 = 0; neg1 = 0; nP = 0;
for c = 1:numel(R0)
    p = R0(c).isProsumer(:);
    neg0 = neg0 + sum(R0(c).NPV(p, 1) < 0);
    neg1 = neg1 + sum(R1(c).NPV(p, 1) < 0);
    nP = nP + sum(p);
end
fprintf('Prosumer con VAN < 0 (metodo Shapley/colonna 1): prima %d su %d, dopo %d su %d\n', neg0, nP, neg1, nP);

if ok, disp('ESITO: tutte le attese verificate'); else, disp('ESITO: ATTESE VIOLATE'); end
