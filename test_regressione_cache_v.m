function esito = test_regressione_cache_v(filePrima, fileDopo)
%TEST_REGRESSIONE_CACHE_V  Fase 7a di MAIN2: il caching di v(S) non deve
%   cambiare NESSUN risultato.
%
%   Confronta due esecuzioni di MAIN2 sulle stesse schede, salvate con
%       matlab -batch "MAIN2; save('<file>.mat','RESULTS','-v7.3')"
%   la prima PRIMA dell'introduzione della cache (Shapley, Nucleolo ed eccesso
%   di coalizione calcolano ciascuno la propria v(S)), la seconda DOPO (v(S)
%   calcolata una volta e passata ai tre).
%
%   IL CRITERIO E' L'UGUAGLIANZA ESATTA, NON UNA TOLLERANZA
%     La cache non cambia ne' i dati ne' l'ordine delle operazioni: v(S) viene
%     dalla stessa chiamata a cer_coalition_values con gli stessi argomenti, e
%     il codice che la usa e' identico riga per riga. Ci si aspetta quindi
%     l'identita' bit per bit (isequaln), e qualunque scarto, anche a 1e-16, e'
%     un errore da capire, non rumore da tollerare.
%
%   Si escludono i soli tempi di esecuzione (tempo_analisi_s, tempo_figure_s),
%   che cambiano per definizione e sono anzi la misura del guadagno.
%
%   OUTPUT (struct esito)
%     .identico     logico, true se tutto coincide
%     .differenze   string, un elemento per (comunita', campo) che differisce
%     .tempoPrima   [nK x 1] tempi di analisi per comunita' prima [s]
%     .tempoDopo    [nK x 1] tempi di analisi per comunita' dopo  [s]

    A = load(filePrima, 'RESULTS');  A = A.RESULTS;
    B = load(fileDopo,  'RESULTS');  B = B.RESULTS;

    assert(numel(A) == numel(B), ...
           'Numero di comunita'' diverso: %d prima, %d dopo.', numel(A), numel(B));
    assert(isequal(string({A.scheda}), string({B.scheda})), ...
           'Le due esecuzioni non hanno analizzato le stesse schede nello stesso ordine.');

    esclusi = ["tempo_analisi_s", "tempo_figure_s"];
    campiA  = setdiff(string(fieldnames(A)), esclusi, 'stable');
    campiB  = setdiff(string(fieldnames(B)), esclusi, 'stable');
    assert(isequal(sort(campiA), sort(campiB)), ...
           'Le due esecuzioni hanno campi diversi in RESULTS.');

    differenze = strings(0, 1);
    for c = 1:numel(A)
        for f = campiA.'
            if ~isequaln(A(c).(f), B(c).(f))
                differenze(end+1, 1) = A(c).scheda + " ." + f; %#ok<AGROW>
            end
        end
    end

    esito.identico   = isempty(differenze);
    esito.differenze = differenze;
    esito.tempoPrima = [A.tempo_analisi_s].';
    esito.tempoDopo  = [B.tempo_analisi_s].';

    fprintf('\n=== Test di non-regressione della cache di v(S) ===\n');
    fprintf('  Comunita'' confrontate : %d\n', numel(A));
    fprintf('  Campi per comunita''   : %d (esclusi i tempi)\n', numel(campiA));
    if esito.identico
        fprintf('  ESITO                 : IDENTICO bit per bit (isequaln)\n');
    else
        fprintf('  ESITO                 : %d DIFFERENZE\n', numel(differenze));
        fprintf('    %s\n', differenze);
    end
    T = table(string({A.scheda}).', [A.nUsers].', esito.tempoPrima, esito.tempoDopo, ...
              esito.tempoPrima - esito.tempoDopo, ...
              'VariableNames', {'Scheda', 'Membri', 'Analisi_prima_s', ...
                                'Analisi_dopo_s', 'Risparmio_s'});
    disp(T);
end
