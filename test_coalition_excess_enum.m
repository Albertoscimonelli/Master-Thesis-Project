function esito = test_coalition_excess_enum(W)
%TEST_COALITION_EXCESS_ENUM  L'eccesso di coalizione senza matrice di incidenza coincide
%   con coalition_excess, a meno dell'ordine delle somme.
%
%   1) Giochi sintetici da 2 a 20 giocatori, con e senza fattore F: coalition_excess_enum
%      contro coalition_excess sulla stessa v(S), con quattro ripartizioni (uniforme,
%      pesi casuali, tutto al primo giocatore, Variance Least Core).
%   2) 25 giocatori, su 720 ore per restare in pochi secondi: il riferimento si calcola
%      a blocchi di 2^20 coalizioni con la matrice di incidenza del blocco, cioe'
%      l'aritmetica di coalition_excess senza tenere tutto in memoria.
%   3) A 20 e 25 giocatori, i due controlli che MAIN2 fa da 19 a 25 membri: eccesso
%      massimo del VLC = -thetaLC entro max(tolEx, VLC.tolConv), e nessuna ripartizione
%      non negativa con un eccesso massimo piu' basso di quello del VLC.
%   4) Il VLC con v(S) passata in opts.v, come fa MAIN2 da 19 a 25 membri, da' la stessa
%      allocazione, bit per bit, di quando la enumera da se' (20 giocatori).
%   5) Con un argomento, al posto dei casi 1-4: una comunita' vera, al piu' 20 membri
%      (il limite di coalition_excess). Dopo MAIN2, dal workspace, con i dati
%      dell'ultima comunita' analizzata:
%        W = struct('gen', genForShare, 'carico', loadForShare, 'P', P_CER_lordo, ...
%                   'esente', optF.esente, 'F', optF.F, 'nomi', string(userNames), ...
%                   'metodi', [metodi.nome], 'phi', [metodi.phi]);
%        esito = test_coalition_excess_enum(W)
%
%   Si lancia con
%       esito = test_coalition_excess_enum
%   e si ferma al primo scarto oltre tolleranza.
%
%   TOLLERANZA
%     Eccesso massimo entro 1e-12 relativo a max(1, |v(N)|). Numero di coalizioni
%     instabili identico. Coalizione peggiore identica, oppure a pari merito con quella
%     di riferimento entro la stessa tolleranza.

    rng(42);
    esito = struct('caso', {}, 'n', {}, 'scarto', {}, 'tRif_s', {}, 'tEnum_s', {});

    % --- 5) Una comunita' vera, al posto dei giochi sintetici -----------------
    if nargin >= 1 && ~isempty(W)
        n    = size(W.carico, 2);
        nome = sprintf('scheda vera n=%d', n);
        [v, ~, A] = cer_coalition_values_blocchi(W.gen, W.carico, W.nomi, W.P, W.esente, W.F);
        t  = tic;
        E0 = coalition_excess(W.phi, W.metodi, W.gen, W.carico, W.nomi, W.P, ...
                              struct('v', v, 'A_inc', A, 'quiet', true));
        tRif = toc(t);
        t  = tic;
        E1 = coalition_excess_enum(W.phi, W.metodi, v, W.nomi, struct('quiet', true));
        tEnum = toc(t);
        scarto = local_confronta(E1, E0, v, W.phi, nome);
        esito(end+1) = struct('caso', string(nome), 'n', n, 'scarto', scarto, ...
                              'tRif_s', tRif, 'tEnum_s', tEnum);
        fprintf('  %-18s scarto %.2e, %d metodi, %d coalizioni instabili in tutto\n', ...
                nome, scarto, numel(W.metodi), sum(E1.nUnstable));
        disp(table(E1.methods(:), E1.maxExcess, E0.maxExcess, E1.nUnstable, E0.nUnstable, ...
                   'VariableNames', {'Metodo', 'EccessoMax_enum', 'EccessoMax_rif', ...
                                     'Instabili_enum', 'Instabili_rif'}));
        fprintf('OK: comunita'' vera entro 1e-12.\n');
        return
    end

    % --- 1) e 3)-4): giochi sintetici contro coalition_excess -----------------
    for n = [2 3 5 8 9 12 16 18 20]
        for F = [0 0.3]
            nome = sprintf('n=%d F=%.1f', n, F);
            [gen, carico, P, esente, nomi] = local_gioco(n, 8760);
            [v, ~, A] = cer_coalition_values_blocchi(gen, carico, nomi, P, esente, F);
            VLC = variance_least_core_cer(gen, carico, nomi, P, ...
                                          struct('esente', esente, 'F', F, 'v', v));
            [phi, metodi] = local_ripartizioni(v(end), n, VLC.phi);

            t  = tic;
            E0 = coalition_excess(phi, metodi, gen, carico, nomi, P, ...
                                  struct('v', v, 'A_inc', A, 'quiet', true));
            tRif = toc(t);
            t  = tic;
            E1 = coalition_excess_enum(phi, metodi, v, nomi, struct('quiet', true));
            tEnum = toc(t);

            scarto = local_confronta(E1, E0, v, phi, nome);
            assert(isequal(E1.table.Properties.VariableNames, ...
                           E0.table.Properties.VariableNames), '%s: colonne diverse', nome);
            assert(E1.nCoalitions == E0.nCoalitions && E1.tol == E0.tol, ...
                   '%s: nCoalitions o tol diversi', nome);
            if n >= 20
                local_controlli_vlc(E1, VLC, phi, metodi, nome);
            end
            esito(end+1) = struct('caso', string(nome), 'n', n, 'scarto', scarto, ...
                                  'tRif_s', tRif, 'tEnum_s', tEnum); %#ok<AGROW>
            fprintf('  %-12s scarto %.2e   coalition_excess %6.3f s   enum %6.3f s\n', ...
                    nome, scarto, tRif, tEnum);
        end
    end

    % --- 4) VLC: v(S) passata contro enumerazione propria, 20 giocatori -------
    for F = [0 0.3]
        [gen, carico, P, esente, nomi] = local_gioco(20, 720);
        opts = struct('esente', esente, 'F', F);
        VD   = variance_least_core_cer(gen, carico, nomi, P, opts);
        optV = opts;
        optV.v = cer_coalition_values_blocchi(gen, carico, nomi, P, esente, F);
        VC   = variance_least_core_cer(gen, carico, nomi, P, optV);
        assert(isequal(VC.phi, VD.phi) && isequal(VC.thetaLC, VD.thetaLC), ...
               'VLC n=20 F=%.1f: la v(S) passata non da'' la stessa allocazione', F);
        fprintf('  VLC n=20 F=%.1f: allocazione identica bit per bit con opts.v\n', F);
    end

    % --- 2) e 3): 25 giocatori contro il riferimento a blocchi ---------------
    for F = [0 0.3]
        nome = sprintf('n=25 F=%.1f', F);
        [gen, carico, P, esente, nomi] = local_gioco(25, 720);
        t = tic;
        v = cer_coalition_values_blocchi(gen, carico, nomi, P, esente, F);
        tV = toc(t);
        VLC = variance_least_core_cer(gen, carico, nomi, P, ...
                                      struct('esente', esente, 'F', F, 'v', v));
        [phi, metodi] = local_ripartizioni(v(end), 25, VLC.phi);

        t  = tic;
        E1 = coalition_excess_enum(phi, metodi, v, nomi, struct('quiet', true));
        tEnum = toc(t);
        t  = tic;
        R  = local_riferimento_blocchi(phi, v, E1.tol);
        tRif = toc(t);

        scarto = local_confronta(E1, R, v, phi, nome);
        local_controlli_vlc(E1, VLC, phi, metodi, nome);
        esito(end+1) = struct('caso', string(nome), 'n', 25, 'scarto', scarto, ...
                              'tRif_s', tRif, 'tEnum_s', tEnum); %#ok<AGROW>
        fprintf(['  %-12s scarto %.2e   riferimento a blocchi %6.1f s   enum %5.1f s' ...
                 '   (v(S) %5.1f s)\n'], nome, scarto, tRif, tEnum, tV);
    end

    fprintf('OK: %d casi entro 1e-12, controlli del VLC superati.\n', numel(esito));
end


function scarto = local_confronta(E1, R, v, phi, nome)
%LOCAL_CONFRONTA  E1 (coalition_excess_enum) contro il riferimento R: eccesso massimo,
%   numero di coalizioni instabili, coalizione peggiore (o una a pari merito).
    tolS   = 1e-12 * max(1, abs(v(end)));
    scarto = max(abs(E1.maxExcess - R.maxExcess)) / max(1, abs(v(end)));
    assert(scarto <= 1e-12, '%s: eccesso massimo diverso (scarto %.3g)', nome, scarto);
    assert(isequal(E1.nUnstable(:), R.nUnstable(:)), ...
           '%s: numero di coalizioni instabili diverso', nome);
    assert(isequal(E1.isStable(:), R.nUnstable(:) == 0), '%s: isStable diverso', nome);
    for k = 1:size(phi, 2)
        if ~isequal(E1.worstMask(k, :), R.worstMask(k, :))
            e1 = local_eccesso(v, phi(:, k), E1.worstMask(k, :));
            assert(abs(e1 - R.maxExcess(k)) <= tolS, ...
                   '%s: coalizione peggiore diversa e non a pari merito (metodo %d)', nome, k);
        end
    end
end


function local_controlli_vlc(E, VLC, phi, metodi, nome)
%LOCAL_CONTROLLI_VLC  I due controlli di MAIN2 da 19 a 25 membri.
    iVLC   = find(metodi == "Variance Least Core", 1);
    tolEx  = 1e-6 * max(1, abs(E.vGrand));
    tolVLC = max(tolEx, VLC.tolConv);
    assert(abs(E.maxExcess(iVLC) + VLC.thetaLC) < tolVLC, ...
           '%s: eccesso massimo del VLC diverso da -thetaLC', nome);
    nonNeg = all(phi >= 0, 1);
    assert(E.maxExcess(iVLC) <= min(E.maxExcess(nonNeg)) + tolVLC, ...
           '%s: una ripartizione non negativa e'' piu'' stabile del VLC', nome);
end


function [phi, metodi] = local_ripartizioni(vN, n, phiVLC)
%LOCAL_RIPARTIZIONI  Quattro ripartizioni efficienti e non negative di v(N).
    w      = rand(n, 1);
    primo  = [vN; zeros(n - 1, 1)];
    phi    = [vN / n * ones(n, 1), vN * w / sum(w), primo, phiVLC(:)];
    metodi = ["Uniforme", "Pesi casuali", "Tutto al primo", "Variance Least Core"];
end


function R = local_riferimento_blocchi(phi, v, tol)
%LOCAL_RIFERIMENTO_BLOCCHI  Eccesso massimo, posizione e conteggio con la matrice di
%   incidenza, come coalition_excess, ma 2^20 coalizioni alla volta.
    n  = size(phi, 1);
    nM = size(phi, 2);
    passo = 2^20;
    R.maxExcess = -Inf(nM, 1);
    R.nUnstable = zeros(nM, 1);
    idx = zeros(nM, 1);
    for s = 0:passo:(2^n - 1)
        m = (s:min(s + passo, 2^n) - 1).';
        A = zeros(numel(m), n);
        for i = 1:n
            A(:, i) = bitget(m, i);
        end
        e = v(m + 1) - A * phi;
        e(m == 0 | m == 2^n - 1, :) = -Inf;
        [mx, j] = max(e, [], 1);
        nuovo = mx(:) > R.maxExcess;          % strettamente: fra i pari resta il primo
        R.maxExcess(nuovo) = mx(nuovo);
        idx(nuovo) = m(j(nuovo));
        R.nUnstable = R.nUnstable + sum(e > tol, 1).';
    end
    R.worstMask = false(nM, n);
    for k = 1:nM
        R.worstMask(k, :) = bitget(idx(k), 1:n) == 1;
    end
end


function e = local_eccesso(v, x, mask)
%LOCAL_ECCESSO  e_S per una sola coalizione, dalla sua composizione.
    m = sum(2.^(find(mask) - 1));
    e = v(m + 1) - sum(x(mask));
end


function [gen, carico, P, esente, nomi] = local_gioco(n, H)
%LOCAL_GIOCO  Lo stesso gioco sintetico di test_cer_coalition_values_blocchi: un terzo
%   dei giocatori ha un impianto, tutti hanno un carico, netting dietro al contatore.
    ore   = (0:H-1).';
    sole  = max(0, sin(pi * (mod(ore, 24) - 6) / 12));
    nPV   = max(1, round(n / 3));
    prod  = zeros(H, n);
    prod(:, 1:nPV) = sole .* (2 + 3 * rand(1, nPV)) .* (0.6 + 0.4 * rand(H, nPV));
    cons  = 0.3 + rand(H, n);
    gen   = max(prod - cons, 0);
    carico  = max(cons - prod, 0);
    P     = 0.08 + 0.04 * rand(H, 1);
    esente = rand(n, 1) < 0.7;
    nomi  = "U" + string(1:n);
end
