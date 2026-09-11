clear; clc;

% =========================================================================
%  test_shapley_permutations.m
%
%  Test indipendente di shapley_cer.m: enumerazione BRUTA di tutti gli n!
%  ordini di formazione della grande coalizione, confrontata con la formula
%  chiusa pesata sui sottoinsiemi che shapley_cer.m usa davvero.
%
%  [standalone: NON invocato da MAIN.m, solo per test]
%
%  PERCHE'
%    shapley_cer.m calcola
%      phi_i = sum_{C subset N\{i}} |C|!(n-|C|-1)!/n! * (v(C+i) - v(C))
%    che e' la riscrittura chiusa - via i pesi w(s) = s!(n-s-1)!/n! - della
%    definizione originale dello Shapley value:
%      phi_i = (1/n!) * sum_{ordine pi su N} [v(pred_pi(i) + i) - v(pred_pi(i))]
%    cioe' la MEDIA, su tutti gli n! ordini in cui i giocatori potrebbero
%    unirsi alla coalizione, del contributo marginale di i in quell'ordine.
%    Le due formule sono matematicamente equivalenti (il peso w(s) e' esatta-
%    mente la probabilita' che un ordine casuale presenti a i un predecessore
%    di cardinalita' s), ma sono due CALCOLI indipendenti: la formula chiusa
%    itera sulle 2^n coalizioni, quella per permutazioni sulle n! sequenze.
%    Un bug nei pesi w(s) di shapley_cer.m supererebbe comunque i suoi stessi
%    assert interni (efficienza, null player, simmetria: sono proprieta' che
%    la formula chiusa rispetta per costruzione qualunque sia w(s), purche'
%    normalizzato). Solo il confronto con un secondo algoritmo che non
%    condivide i pesi puo' scoprirlo. Vedi GUIDA_modelli_distribuzione.md §4.
%
%  COSA VALIDA (i quattro punti della sezione "Validazione effettuata")
%    1) coincidenza numerica fra le due formule, su un gioco con generazione
%       e carico non banali          -> tolAbs assoluta
%    2) efficienza: sum(phi) = v(N)                    (entrambe le formule)
%    3) null player: giocatore senza gen ne' carico -> phi = 0 esatto
%    4) simmetria: due consumatori con carico identico -> stessa quota
%
%  Il gioco e' SINTETICO e piccolo (n = 6, quindi n! = 720 ordini): basta a
%  contenere un prosumer, tre consumatori (due identici), e un null player,
%  restando comunque abbastanza economico da enumerare 720 ordini in pochi
%  secondi. Riusa cer_coalition_values.m per costruire v(S) una sola volta
%  (le 2^n = 64 coalizioni), poi la stessa v e' letta sia dalla formula
%  chiusa (dentro shapley_cer) sia dal ciclo sulle permutazioni: cosi' il
%  confronto isola l'ALGORITMO di aggregazione, non la funzione caratteristica
%  (che è condivisa e non è oggetto di questo test).
% =========================================================================

rng(42);

%% --- Gioco sintetico: 6 giocatori, 24 ore -------------------------------
H = 24;
n = 6;

userNames = ["PV_1", "Consumer_A", "Consumer_B", "Consumer_C", "Small_load", "Null_player"];

genUsers  = zeros(H, n);
loadUsers = zeros(H, n);

genUsers(:, 1)  = 3 + 2   * rand(H, 1);   % PV_1: unico prosumer del gioco
loadUsers(:, 2) = 1 + 1   * rand(H, 1);   % Consumer_A
loadUsers(:, 3) = loadUsers(:, 2);        % Consumer_B: IDENTICO ad A -> simmetria
loadUsers(:, 4) = 0.5 + 2 * rand(H, 1);   % Consumer_C
loadUsers(:, 5) = 0.2 + 0.3 * rand(H, 1); % Small_load
% colonne 6 (Null_player): restano a zero -> non porta ne' gen ne' carico

P_CER = 0.10;   % EUR/kWh, incentivo costante

%% --- Shapley esatto (formula chiusa, shapley_cer.m) ---------------------
Sh = shapley_cer(genUsers, loadUsers, userNames, P_CER);
phiFormula = Sh.phi;
vGrand     = Sh.vGrand;

%% --- Stessa v(S), riusata dal ciclo sulle permutazioni -------------------
% bitmask su n bit: v(mask+1) = valore della coalizione di bitmask "mask"
[v, ~] = cer_coalition_values(genUsers, loadUsers, userNames, P_CER);

%% --- Enumerazione di tutti gli n! ordini ---------------------------------
orders  = perms(1:n);          % [n! x n], una riga per ordine
nOrders = size(orders, 1);
assert(nOrders == factorial(n), ...
    'test_shapley_permutations:permsCount', ...
    'perms(1:n) ha restituito %d righe, attese %d = %d!.', nOrders, factorial(n), n);

sumMarg = zeros(n, 1);

for r = 1:nOrders
    order = orders(r, :);
    mask  = 0;                 % coalizione vuota all'inizio dell'ordine
    for k = 1:n
        i        = order(k);
        newMask  = mask + 2^(i - 1);
        marg     = v(newMask + 1) - v(mask + 1);
        sumMarg(i) = sumMarg(i) + marg;
        mask     = newMask;
    end
end

phiPerm = sumMarg / nOrders;

%% --- 1) Coincidenza fra le due formule -----------------------------------
tolAbs  = 1e-9;   % EUR - ben oltre la precisione doppia su importi di questo ordine
diffMax = max(abs(phiPerm - phiFormula));
assert(diffMax < tolAbs, ...
    'test_shapley_permutations:formulaMismatch', ...
    ['Scarto massimo fra formula chiusa e media sulle permutazioni: %.3e EUR ' ...
     '(tolleranza %.3e). Le due formule dovrebbero coincidere esattamente.'], ...
    diffMax, tolAbs);

%% --- 2) Efficienza: sum(phi) = v(N), su entrambe le formule --------------
assert(abs(sum(phiFormula) - vGrand) < tolAbs, ...
    'test_shapley_permutations:notEfficientFormula', ...
    'sum(phi) della formula chiusa non coincide con v(N).');
assert(abs(sum(phiPerm) - vGrand) < tolAbs, ...
    'test_shapley_permutations:notEfficientPerm', ...
    'sum(phi) della media sulle permutazioni non coincide con v(N).');

%% --- 3) Null player: Null_player non porta ne' gen ne' carico ------------
idxNull = find(userNames == "Null_player");
assert(abs(phiPerm(idxNull)) < tolAbs, ...
    'test_shapley_permutations:nullPlayer', ...
    'Null_player ha quota %.3e EUR, atteso 0.', phiPerm(idxNull));

%% --- 4) Simmetria: Consumer_A e Consumer_B hanno carico identico ---------
idxA = find(userNames == "Consumer_A");
idxB = find(userNames == "Consumer_B");
assert(abs(phiPerm(idxA) - phiPerm(idxB)) < tolAbs, ...
    'test_shapley_permutations:symmetry', ...
    'Consumer_A (%.6f EUR) e Consumer_B (%.6f EUR) dovrebbero ricevere la stessa quota.', ...
    phiPerm(idxA), phiPerm(idxB));

%% --- Riepilogo -------------------------------------------------------------
fprintf('\n=== test_shapley_permutations: SUPERATO ===\n');
fprintf('  Giocatori: %d, ordini enumerati: %d!  = %d\n', n, n, nOrders);
fprintf('  v(N) = %.6f EUR\n', vGrand);
fprintf('  Scarto max formula chiusa vs permutazioni: %.3e EUR (tol %.3e)\n', diffMax, tolAbs);
fprintf('  Efficienza:  sum(phi) - v(N) = %.3e EUR (entrambe le formule)\n', ...
    abs(sum(phiPerm) - vGrand));
fprintf('  Null player (%s): phi = %.3e EUR\n', userNames(idxNull), phiPerm(idxNull));
fprintf('  Simmetria (%s vs %s): %.6f vs %.6f EUR\n', ...
    userNames(idxA), userNames(idxB), phiPerm(idxA), phiPerm(idxB));

disp(table(userNames(:), phiFormula, phiPerm, phiFormula - phiPerm, ...
    'VariableNames', {'Giocatore', 'Shapley_formula_EUR', 'Shapley_permutazioni_EUR', 'Scarto_EUR'}));
