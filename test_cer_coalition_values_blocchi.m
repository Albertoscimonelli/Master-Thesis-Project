function esito = test_cer_coalition_values_blocchi()
%TEST_CER_COALITION_VALUES_BLOCCHI  L'enumerazione a blocchi di v(S) coincide con il ciclo
%   di cer_coalition_values, a meno dell'ordine delle somme.
%
%   1) v(S) a blocchi contro cer_coalition_values: giochi sintetici da 1 a 16 giocatori,
%      con e senza fattore F, tariffa oraria e costante, piu' due casi limite (nessun
%      impianto; nessuna ora con produzione e carico insieme).
%   2) players e A_inc identici a cer_coalition_values.
%   3) Il Variance Least Core con la v(S) a blocchi passata in opts.v da' la stessa
%      allocazione, bit per bit, di quando enumera da se': l'algoritmo e' lo stesso di
%      enumerate_values.
%   4) Tempi dei due calcoli.
%
%   Si lancia con
%       esito = test_cer_coalition_values_blocchi
%   e si ferma al primo scarto oltre tolleranza.
%
%   TOLLERANZA
%     1e-11 relativo al massimo |v(S)|: le formule sono le stesse, cambia l'ordine delle
%     somme (scarti attesi dell'ordine di 1e-13).

    rng(42);
    H   = 8760;
    tol = 1e-11;
    esito = struct('caso', {}, 'scarto', {}, 'tCiclo_s', {}, 'tBlocchi_s', {});

    casi = {};
    for n = [1 5 8 9 12 14 16]
        for F = [0 0.3]
            casi{end+1} = struct('nome', sprintf('n=%d F=%.1f', n, F), 'n', n, ...
                                 'F', F, 'tipo', "normale"); %#ok<AGROW>
        end
    end
    casi{end+1} = struct('nome', 'n=10 P costante', 'n', 10, 'F', 0, 'tipo', "Pcostante");
    casi{end+1} = struct('nome', 'n=10 senza impianti', 'n', 10, 'F', 0.3, 'tipo', "senzaPV");
    casi{end+1} = struct('nome', 'n=6 nessuna ora utile', 'n', 6, 'F', 0, 'tipo', "notte");

    for c = 1:numel(casi)
        K = casi{c};
        [gen, carico, P, esente, nomi] = local_gioco(K.n, H);
        switch K.tipo
            case "Pcostante", P = 0.11;
            case "senzaPV",   gen(:) = 0;
            case "notte",     carico(gen > 0) = 0;  gen(1:2:end, :) = 0;  carico(2:2:end, :) = 0;
        end

        t = tic;
        [v0, pl0, A0] = cer_coalition_values(gen, carico, nomi, P, esente, K.F);
        tCiclo = toc(t);
        t = tic;
        [v1, pl1, A1] = cer_coalition_values_blocchi(gen, carico, nomi, P, esente, K.F);
        tBlocchi = toc(t);

        assert(isequal(size(v1), size(v0)), '%s: v di dimensione diversa', K.nome);
        scarto = max(abs(v1 - v0)) / max(1, max(abs(v0)));
        assert(scarto <= tol, '%s: scarto %.3g', K.nome, scarto);
        assert(isequal(pl1, pl0), '%s: players diversi', K.nome);
        assert(isequal(A1, A0), '%s: A_inc diversa', K.nome);
        if K.tipo ~= "normale"
            assert(all(v1 == 0) == all(v0 == 0), '%s: zeri diversi', K.nome);
        end
        esito(end+1) = struct('caso', string(K.nome), 'scarto', scarto, ...
                              'tCiclo_s', tCiclo, 'tBlocchi_s', tBlocchi); %#ok<AGROW>
        fprintf('  %-22s scarto %.2e   ciclo %7.2f s   blocchi %6.3f s\n', ...
                K.nome, scarto, tCiclo, tBlocchi);
    end

    % --- 3) VLC: v(S) a blocchi passata contro enumerazione propria ----------
    for F = [0 0.3]
        [gen, carico, P, esente, nomi] = local_gioco(14, H);
        opts = struct('esente', esente, 'F', F);
        VD   = variance_least_core_cer(gen, carico, nomi, P, opts);
        optV = opts;
        optV.v = cer_coalition_values_blocchi(gen, carico, nomi, P, esente, F);
        VC   = variance_least_core_cer(gen, carico, nomi, P, optV);
        assert(isequal(VC.phi, VD.phi) && isequal(VC.thetaLC, VD.thetaLC), ...
               'VLC n=14 F=%.1f: la v(S) a blocchi non e'' quella di enumerate_values', F);
        fprintf('  VLC n=14 F=%.1f: allocazione identica bit per bit\n', F);
    end

    fprintf('OK: %d casi entro %.0e, VLC identico.\n', numel(esito), tol);
end


function [gen, carico, P, esente, nomi] = local_gioco(n, H)
%LOCAL_GIOCO  Lo stesso gioco sintetico di test_speedup_vlc_shapley: un terzo dei
%   giocatori ha un impianto, tutti hanno un carico, netting dietro al contatore.
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
