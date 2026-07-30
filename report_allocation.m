function report_allocation(S, nome, extra)
%REPORT_ALLOCATION  Stampa il riepilogo di una ripartizione e ne verifica
%   l'efficienza. Condiviso da tutti i modelli di ripartizione, che
%   restituiscono la stessa struttura di base.
%
%   Le righe specifiche di un singolo metodo (surplus minimo del Nucleolo,
%   iterazioni del Variance Least Core, ...) NON sono gestite qui con rami
%   condizionali: il chiamante le formatta e le passa in "extra". Cosi'
%   questa funzione non deve sapere nulla dei singoli metodi.
%
%   INPUT
%     S      struct  risultato di un metodo *_cer, con almeno i campi
%                    .table .phi .vGrand .prodShare .consShare
%     nome   string  nome del metodo (intestazione e messaggi di errore)
%     extra  string array (opzionale) righe gia' formattate, stampate dopo
%                    le quote; usare "" o omettere se non servono

    if nargin < 3, extra = string.empty; end
    extra = string(extra);      % accetta anche char array da sprintf

    fprintf('\n=== Distribuzione %s dell''incentivo CER condivisa ===\n', nome);
    disp(S.table);
    fprintf('  %-25s: EUR %9.2f\n', 'Valore grande coalizione', S.vGrand);
    fprintf('  %-25s: EUR %9.2f  (%.1f%%)\n', 'Quota prosumer', ...
            S.prodShare, 100*S.prodShare/S.vGrand);
    fprintf('  %-25s: EUR %9.2f  (%.1f%%)\n', 'Quota consumatori puri', ...
            S.consShare, 100*S.consShare/S.vGrand);

    for k = 1:numel(extra)
        fprintf('%s\n', extra(k));
    end

    % Efficienza: tutto il valore della grande coalizione e' distribuito.
    assert(abs(sum(S.phi) - S.vGrand) < 1e-6, ...
           '%s: somma delle quote diversa dal valore della grande coalizione', nome);
end
