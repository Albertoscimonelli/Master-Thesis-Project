function S = marginal_contribution_cer(genUsers, loadUsers, userNames, P_CER, opts)
%MARGINAL_CONTRIBUTION_CER  Ripartizione dell'incentivo CER con il metodo
%   "last marginal contribution" di Cremers, Robu, Zhang, Andoni, Norbu,
%   Flynn, "Efficient methods for approximating the Shapley value for asset
%   sharing in energy communities", Applied Energy 331 (2023) 120328
%   (§4.1.1, eq. 9-10).
%
%   IDEA
%     Lo Shapley value media il contributo marginale del giocatore su TUTTE le
%     2^n coalizioni. Questo metodo ne tiene UNA sola: l'ultima, cioe' quella
%     in cui il giocatore entra per ultimo nella grande coalizione.
%
%       MC_i = v(N) - v(N\{i})                                        (eq. 9)
%
%     Basta quindi valutare v n+1 volte invece di 2^n: la complessita' scende
%     da O(2^n) a O(n), ed e' il metodo piu' economico dei tre approssimatori
%     del paper.
%
%   NORMALIZZAZIONE (eq. 10)
%     I contributi marginali "ultimi" non sommano a v(N): a differenza dello
%     Shapley, l'efficienza NON e' una proprieta' del metodo, va imposta.
%
%       phi_i = v(N) * MC_i / sum_q MC_q
%
%     Il fattore di scala v(N)/sum(MC) e' esposto in .normFactor: misura
%     quanto il metodo grezzo si discosti dall'efficienza. Vale 1 solo per
%     caso; nel gioco CER e' tipicamente < 1, perche' ogni giocatore
%     rivendica per intero l'energia condivisa che sparirebbe senza di lui e
%     lo stesso kWh viene cosi' contato piu' volte.
%
%   COSA ASPETTARSI SU QUESTA TOPOLOGIA (leggere prima di usare i numeri)
%     Il metodo premia i giocatori INDISPENSABILI e azzera tutti gli altri.
%     Se togliendo un consumatore l'energia condivisa non cala -- perche' il
%     carico residuo degli altri e' comunque sufficiente ad assorbire tutta
%     l'eccedenza -- allora MC_i = 0 esatto e quel consumatore riceve ZERO,
%     per quanto grande sia il suo consumo. Togliendo l'unico prosumer, al
%     contrario, l'energia condivisa crolla a zero e MC vale l'intero v(N).
%     Con un solo impianto e carico abbondante la ripartizione degenera quindi
%     verso "tutto al prosumer".
%
%     Non e' un difetto dell'implementazione ma della regola, ed e' il motivo
%     per cui nel paper questo e' il metodo con l'errore piu' alto rispetto
%     allo Shapley esatto (fino al 5% con poche decine di agenti, Fig. 3a).
%     Il paper lo applica a un gioco di COSTO in cui tutti i membri sono
%     comproprietari dell'impianto condiviso, quindi nessuno e' mai del tutto
%     superfluo: la degenerazione non si presenta. Serve come benchmark di
%     riferimento -- il piu' economico e il meno accurato -- non come regola
%     di ripartizione da proporre alla CER.
%
%   VALORE DELLA GRANDE COALIZIONE  (stessa formula di cer_coalition_values,
%   valutata su richiesta da cer_shared_value senza enumerare le 2^n coalizioni)
%     v(N) = sum_t min( sum_i gen_i(t), sum_i load_i(t) ) * P_CER(t)
%
%   INPUT
%     genUsers  [H x n]   eccedenza oraria di ciascun utente      [kWh/h]
%     loadUsers [H x n]   carico residuo orario di ciascun utente [kWh/h]
%     userNames [1 x n]   nomi degli utenti                       (string)
%     P_CER     scalare o [H x 1]  incentivo CER su energia condivisa [EUR/kWh]
%     opts      struct opzionale:
%                 .F      scalare  fattore di riduzione per contributo in
%                         conto capitale (def. 0 = nessuna decurtazione)
%                 .esente [n x 1] logico, membri esenti da F. La quota esente
%                         entra in v(S) COALIZIONE PER COALIZIONE: vedi
%                         cer_shared_value.m
%
%   OUTPUT (struct S) - stessi campi degli altri metodi *_cer, per
%   compatibilita' con report_allocation.m e i grafici
%     .players     [1 x n]  nomi dei giocatori (= userNames)
%     .phi         [n x 1]  ripartizione normalizzata               [EUR]
%     .vGrand      scalare  valore della grande coalizione          [EUR]
%     .isProsumer  [n x 1]  logico, true se il giocatore ha produzione
%     .prodShare   scalare  quota totale ai prosumer                [EUR]
%     .consShare   scalare  quota totale ai consumatori puri        [EUR]
%     .mcRaw       [n x 1]  contributi marginali GREZZI, eq. 9      [EUR]
%     .normFactor  scalare  v(N) / sum(MC), fattore dell'eq. 10
%     .nullPlayers scalare  quanti giocatori hanno MC = 0 (e quindi quota nulla)
%     .table       table    riepilogo (giocatore, quota, percentuale)

    [H, n]  = size(loadUsers);
    players = string(userNames(:).');

    if size(genUsers, 2) ~= n
        error('marginal_contribution_cer:sizeMismatch', ...
              'genUsers ha %d colonne, loadUsers ne ha %d: serve una colonna per utente.', ...
              size(genUsers, 2), n);
    end
    if ~all(isfinite(genUsers), 'all') || ~all(isfinite(loadUsers), 'all')
        error('marginal_contribution_cer:nonFiniteInput', ...
              'Profili con NaN o Inf in ingresso: controllare i dati a monte.');
    end

    if isscalar(P_CER)
        P_CER = P_CER * ones(H, 1);
    else
        P_CER = P_CER(:);
    end

    if nargin < 5 || isempty(opts), opts = struct(); end

    % --- Fattore F ed esenzione ---------------------------------------------
    % Il carico dei soli membri esenti va aggregato una volta e poi scalato
    % come gli altri aggregati: togliere l'utente i vuol dire toglierlo anche
    % da qui, ma solo se i era esente.
    if ~isfield(opts, 'esente'), opts.esente = []; end
    if ~isfield(opts, 'F'),      opts.F      = 0;  end
    if isempty(opts.esente)
        esente = false(n, 1);
    else
        esente = logical(opts.esente(:));
    end
    Fred = opts.F;

    % --- Grande coalizione --------------------------------------------------
    genComm  = sum(genUsers,  2);
    loadComm = sum(loadUsers, 2);
    loadEsC  = sum(loadUsers(:, esente), 2);
    vGrand   = cer_shared_value(genComm, loadComm, P_CER, loadEsC, Fred);

    % --- Contributi marginali "ultimi" (eq. 9) ------------------------------
    % v(N\{i}) si ottiene togliendo la colonna dell'utente dagli AGGREGATI
    % gia' calcolati: n valutazioni di v da O(H) ciascuna, nessuna enumerazione.
    mc = zeros(n, 1);
    for i = 1:n
        vWithout = cer_shared_value(genComm  - genUsers(:,  i), ...
                                    loadComm - loadUsers(:, i), P_CER, ...
                                    loadEsC - loadUsers(:, i) * esente(i), Fred);
        mc(i) = vGrand - vWithout;
    end

    % La monotonia di v garantisce MC_i >= 0: un contributo negativo
    % significherebbe che togliere un utente AUMENTA l'energia condivisa,
    % cioe' profili corrotti a monte. Si tollera solo il rumore numerico.
    if any(mc < -1e-9 * max(1, abs(vGrand)))
        error('marginal_contribution_cer:negativeContribution', ...
              ['Contributo marginale negativo (min %.6g EUR): la funzione ' ...
               'caratteristica dovrebbe essere monotona, controllare i profili.'], min(mc));
    end
    mc = max(mc, 0);

    sumMC = sum(mc);
    if sumMC <= 0
        error('marginal_contribution_cer:degenerateGame', ...
              ['Tutti i contributi marginali sono nulli: nessuna energia ' ...
               'condivisa da ripartire (v(N) = %.6g EUR).'], vGrand);
    end

    % --- Normalizzazione all'efficienza (eq. 10) ----------------------------
    normFactor = vGrand / sumMC;
    phi        = normFactor * mc;

    % --- Output -------------------------------------------------------------
    isProsumer = any(genUsers > 0, 1).';        % chi porta produzione nel gioco

    S.players     = players;
    S.phi         = phi;
    S.vGrand      = vGrand;
    S.isProsumer  = isProsumer;
    S.prodShare   = sum(phi(isProsumer));
    S.consShare   = sum(phi(~isProsumer));
    S.mcRaw       = mc;
    S.normFactor  = normFactor;
    S.nullPlayers = sum(mc <= 1e-9 * max(1, abs(vGrand)));
    S.table       = table(players(:), phi, 100*phi/vGrand, ...
                          'VariableNames', ...
                          {'Giocatore', 'MarginalContribution_EUR', 'Quota_pct'});
end
