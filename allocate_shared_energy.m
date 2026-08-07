function SH = allocate_shared_energy(loadUsers, Einj, w)
%ALLOCATE_SHARED_ENERGY  Ripartisce ORA PER ORA l'energia condivisa della
%   comunita' tra gli utenti secondo una chiave dinamica w(t,i), rispettando
%   il vincolo fisico SH(t,i) <= loadUsers(t,i): nessuno puo' ricevere piu'
%   energia condivisa di quanta ne consumi realmente in quell'ora.
%
%   E' l'algoritmo iterativo del flowchart di Fig. 2 di Gianaroli, Ricci,
%   Sdringola, Ancona, Branchini, Melino, "Development of dynamic sharing keys: Algorithms
%   supporting management of renewable energy community and collective self
%   consumption", Energy & Buildings 311 (2024) 114158. E' COMUNE a tutti i
%   metodi a chiave dinamica del paper (M3 Pearson, M4 sharing rate, M5
%   combinazione dei due): cambia solo la matrice dei pesi in ingresso, non
%   l'algoritmo di ripartizione, ed e' per questo che sta in un helper a se'.
%
%   LOGICA (per ogni ora t)
%     1. Einj(t) >= sum_i load_i(t)  ->  caso banale: SH(t,i) = load_i(t) per
%        tutti (l'immissione basta a coprire l'intero carico residuo).
%     2. Einj(t) <= 0  oppure  carico totale nullo  ->  SH(t,:) = 0 (non c'e'
%        energia condivisa da attribuire).
%     3. Altrimenti si distribuisce Einj(t) in proporzione a w(t,:); chi
%        supererebbe il proprio consumo viene "cappato" al consumo e messo
%        fuori gioco, e il residuo si ridistribuisce tra i rimanenti
%        rinormalizzando i pesi. Si itera finche' l'energia e' esaurita o
%        nessuno sfora piu' (al massimo n iterazioni: ogni giro ne cappa
%        almeno uno).
%
%   Per costruzione l'esito soddisfa  sum_i SH(t,i) = min(Einj(t), sum_i
%   load_i(t))  per ogni ora, cioe' esattamente l'energia condivisa di
%   comunita' gia' calcolata in MAIN.m §2: e' quello che rende questi metodi
%   confrontabili con gli altri, che partono dallo stesso v(N).
%
%   PESI NON NORMALIZZATI
%     w NON deve essere normalizzato dal chiamante: la normalizzazione viene
%     rifatta comunque a ogni iterazione sui soli utenti ancora attivi.
%     Valori negativi vengono azzerati. Se in un'ora tutti i pesi degli
%     utenti attivi sono nulli (caso degenere: p = -1 per tutti in M3, o
%     underflow dell'esponenziale in M4/M5) il residuo verrebbe perso e
%     l'efficienza sum(phi) = v(N) violata: in quel caso si ripiega sul
%     margine residuo (load - SH), che e' l'unico riparto sempre definito e
%     che non puo' sforare il cap.
%
%   INPUT
%     loadUsers [H x n]   carico residuo orario di ciascun utente  [kWh/h]
%     Einj      [H x 1]   energia immessa in rete dalla comunita'  [kWh/h]
%     w         [H x n]   pesi della chiave dinamica (>= 0, non normalizzati)
%
%   OUTPUT
%     SH        [H x n]   energia condivisa attribuita a ciascun utente [kWh/h]

    [H, n] = size(loadUsers);
    Einj   = Einj(:);

    if numel(Einj) ~= H
        error('allocate_shared_energy:sizeMismatch', ...
              'Einj ha %d ore, loadUsers ne ha %d.', numel(Einj), H);
    end
    if ~isequal(size(w), [H n])
        error('allocate_shared_energy:weightSizeMismatch', ...
              'La matrice dei pesi deve essere [%d x %d], e'' [%d x %d].', ...
              H, n, size(w, 1), size(w, 2));
    end
    % Senza questo controllo un NaN in ingresso si propagherebbe fino alle
    % verifiche finali, che lo segnalerebbero come violazione del cap: una
    % diagnosi fuorviante rispetto alla causa vera (dati sporchi a monte).
    if ~all(isfinite(loadUsers), 'all') || ~all(isfinite(Einj)) || ~all(isfinite(w), 'all')
        error('allocate_shared_energy:nonFiniteInput', ...
              ['Ingressi con NaN o Inf (carichi: %d, immissione: %d, pesi: %d ' ...
               'valori non finiti): controllare i profili a monte.'], ...
              sum(~isfinite(loadUsers), 'all'), sum(~isfinite(Einj)), ...
              sum(~isfinite(w), 'all'));
    end

    SH      = zeros(H, n);
    maxIter = n + 5;          % sicurezza anti-loop-infinito (bastano n giri)

    for t = 1:H
        Ct   = loadUsers(t, :);
        Et   = Einj(t);
        sumC = sum(Ct);

        if Et <= 0 || sumC <= 0
            continue                     % niente da condividere in quest'ora
        end
        if Et >= sumC
            SH(t, :) = Ct;               % l'immissione copre tutto il carico
            continue
        end

        % Tolleranza RELATIVA alla scala dell'ora: una soglia assoluta fissa
        % sarebbe sotto il rumore numerico su ore con carichi grandi e sopra
        % il valore stesso su ore con carichi minimi.
        tol = 1e-12 * sumC;

        wt     = max(w(t, :), 0);
        SHt    = zeros(1, n);
        active = true(1, n);
        RES    = Et;

        for k = 1:maxIter
            wAct = wt .* active;
            sumW = sum(wAct);
            if sumW <= 0
                break                    % nessun peso utile: vedi chiusura
            end

            SHtemp = SHt + (wAct / sumW) * RES;
            over   = SHtemp > Ct + tol;

            SHt(~over)   = SHtemp(~over);
            SHt(over)    = Ct(over);      % cap al consumo reale
            active(over) = false;         % ...e fuori dalle rinormalizzazioni

            RES = Et - sum(SHt);
            if ~any(over) || RES <= tol
                break                    % distribuzione stabile / esaurita
            end
        end

        % Chiusura: se e' rimasta energia non attribuita (pesi tutti nulli tra
        % gli attivi, o uscita per maxIter) la si assegna in proporzione al
        % margine residuo. Non puo' sforare il cap: RES < sum(margini) perche'
        % qui siamo nel ramo Et < sumC.
        if RES > tol
            head    = max(Ct - SHt, 0);
            sumHead = sum(head);
            if sumHead > 0
                SHt = SHt + head * (RES / sumHead);
            end
        end

        SH(t, :) = SHt;
    end

    % --- Verifiche di coerenza (casi limite della guida) -------------------
    tolChk = 1e-6 * max(1, max(Einj));
    assert(all(SH <= loadUsers + tolChk, 'all'), ...
           'allocate_shared_energy: energia condivisa maggiore del consumo per qualche utente/ora');
    assert(max(abs(sum(SH, 2) - min(Einj, sum(loadUsers, 2)))) <= tolChk, ...
           'allocate_shared_energy: la somma oraria non coincide con l''energia condivisa di comunita''');
end
