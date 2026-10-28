function esito = test_speedup_vlc_shapley()
%TEST_SPEEDUP_VLC_SHAPLEY  Le due accelerazioni di MAIN2 non cambiano i
%   risultati oltre l'arrotondamento.
%
%   1) shapley_cer_cached vettorizzato contro shapley_cer (doppio ciclo
%      originale), con e senza fattore F.
%   2) variance_least_core_cer con la separazione per enumerazione (default
%      fino a 25 giocatori, con v(S) enumerata da se' o passata in opts.v)
%      contro la separazione MILP di prima (opts.denseMaxPlayers = 0).
%   3) Tempo della nuova separazione su un gioco sintetico da 25 giocatori.
%
%   Giochi sintetici, un anno orario, seme fisso. Si lancia con
%       esito = test_speedup_vlc_shapley
%   e si ferma al primo scarto oltre tolleranza.
%
%   TOLLERANZE
%     Shapley: 1e-9 relativo a v(N). Le formule sono identiche, cambia solo
%     l'ordine delle somme.
%     VLC: 1e-5 relativo a v(N). La soluzione e' unica, ma esce da linprog,
%     quadprog e intlinprog con tolleranza 1e-6 * v(N) (opts.tolRel).

    rng(42);
    H      = 8760;
    tolSh  = 1e-9;
    tolVLC = 1e-5;
    esito  = struct('n', {}, 'F', {}, 'scartoShapley', {}, 'scartoVLC', {}, ...
                    'tMILP_s', {}, 'tDenso_s', {});

    for n = [5 8 11 14]
        [gen, carico, P, esente, nomi] = gioco_sintetico(n, H);
        for F = [0 0.3]
            opts = struct('esente', esente, 'F', F);

            % --- Shapley: vettorizzato contro il ciclo originale -------------
            [v, players] = cer_coalition_values(gen, carico, nomi, P, esente, F);
            optC   = opts;  optC.v = v;  optC.players = players;
            ShOld  = shapley_cer(gen, carico, nomi, P, opts);
            ShNew  = shapley_cer_cached(gen, carico, nomi, P, optC);
            dSh    = max(abs(ShNew.phi - ShOld.phi)) / ShOld.vGrand;
            assert(dSh <= tolSh, 'Shapley n=%d F=%.1f: scarto %.3g', n, F, dSh);

            % --- VLC: enumerazione contro MILP (solo F = 0, l'unico caso in
            %     cui il MILP esiste) e contro la v(S) passata dal chiamante ---
            t = tic;
            VD = variance_least_core_cer(gen, carico, nomi, P, opts);
            tDenso = toc(t);
            optV = opts;  optV.v = v;
            VC = variance_least_core_cer(gen, carico, nomi, P, optV);
            dVLC = max(abs(VD.phi - VC.phi)) / VD.vGrand;
            assert(dVLC <= tolVLC, 'VLC n=%d F=%.1f, cache contro enumerazione: scarto %.3g', ...
                   n, F, dVLC);

            tMILP = NaN;
            if F == 0
                optM = opts;  optM.denseMaxPlayers = 0;
                t = tic;
                VM = variance_least_core_cer(gen, carico, nomi, P, optM);
                tMILP = toc(t);
                dVLC = max([abs(VD.phi - VM.phi) / VD.vGrand; ...
                            abs(VD.thetaLC - VM.thetaLC) / VD.vGrand]);
                assert(dVLC <= tolVLC, 'VLC n=%d, enumerazione contro MILP: scarto %.3g', ...
                       n, dVLC);
            end

            esito(end+1) = struct('n', n, 'F', F, 'scartoShapley', dSh, ...
                                  'scartoVLC', dVLC, 'tMILP_s', tMILP, ...
                                  'tDenso_s', tDenso); %#ok<AGROW>
            fprintf('  n = %2d  F = %.1f   Shapley %.1e   VLC %.1e   tempo VLC: MILP %7.1f s, enumerazione %6.1f s\n', ...
                    n, F, dSh, dVLC, tMILP, tDenso);
        end
    end

    % --- Scala: 25 giocatori, solo la nuova strada (il MILP qui costa decine
    %     di minuti, vedi README 7.11.2) ---------------------------------------
    [gen, carico, P, esente, nomi] = gioco_sintetico(25, H);
    t = tic;
    V25 = variance_least_core_cer(gen, carico, nomi, P, struct('esente', esente, 'F', 0));
    fprintf('  n = 25  F = 0.0   VLC con enumerazione: %.1f s (%d + %d iterazioni)\n', ...
            toc(t), V25.iterLC, V25.iterVLC);

    fprintf('  OK: nessuno scarto oltre tolleranza.\n');
end


function [gen, carico, P, esente, nomi] = gioco_sintetico(n, H)
%GIOCO_SINTETICO  Un terzo dei giocatori ha un impianto (profilo solare con
%   rumore), tutti hanno un carico; netting dietro al contatore come in
%   load_cer_data, quindi in ogni ora un utente ha eccedenza OPPURE carico.
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
