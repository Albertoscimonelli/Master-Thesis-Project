function esporta_run_livelli(fileMat, cartella)
%ESPORTA_RUN_LIVELLI  esporta_run con le etichette giuste anche per i livelli con imprese.
%   Uso, dalla root del progetto:
%       addpath(pwd); addpath('outputs/workspace/strumenti');
%       esporta_run_livelli('outputs/workspace/run_2026-10-28_fino25_unito_completo.mat', ...
%                           'outputs/workspace/export_fino25_unito')
%
%   esporta_run scrive in punteggi_orientati.csv la composizione come "PA" + LIV(l).livello,
%   che va bene per i livelli 0-3 ma per l'asse imprese da' "PA10", "PA21", ... invece di
%   "ND1", "ND2_PA1". Gli altri quattro file prendono l'etichetta da RESULTS(c).etichetta e
%   sono gia' giusti. Questa funzione chiama esporta_run e poi rinomina la sola colonna
%   Composizione di punteggi_orientati.csv con etichetta_livello, lo stesso nome delle
%   cartelle delle tabelle. Non tocca nient'altro.
    esporta_run(fileMat, cartella);
    f = fullfile(cartella, 'punteggi_orientati.csv');
    T = readtable(f, 'TextType', 'string');
    codice = str2double(extractAfter(T.Composizione, "PA"));
    assert(all(isfinite(codice)), 'esporta_run_livelli: Composizione inattesa in %s', f);
    T.Composizione = etichetta_livello(codice);
    writetable(T, f);

    % controllo: stesse etichette di comunita.csv (che vengono da RESULTS)
    C = readtable(fullfile(cartella, 'comunita.csv'), 'TextType', 'string');
    assert(isempty(setxor(unique(T.Composizione), unique(C.Composizione))), ...
           'esporta_run_livelli: livelli diversi fra punteggi_orientati.csv e comunita.csv');
    fprintf('Etichette dei livelli corrette in %s\n', f);
end
