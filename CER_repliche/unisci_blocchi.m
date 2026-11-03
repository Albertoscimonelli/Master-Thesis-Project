function unisci_blocchi(radice, fileRisultati, suffisso, maxUtenti)
%UNISCI_BLOCCHI  Un solo checkpoint di MAIN2 da piu' blocchi di run della stessa replica.
%
%   unisci_blocchi(radice, fileRisultati, suffisso, maxUtenti)
%
%   I run si dividono per taglia (per esempio 5-15 membri e 18-25 membri) solo per non fare
%   un'unica esecuzione di molte ore, ma vanno letti insieme. Questa funzione:
%     1. carica RESULTS da ciascun file (checkpoint o workspace dei blocchi);
%     2. li mette nell'ordine di elenco_schede_cer per quella radice e quel tetto, cioe'
%        l'ordine che MAIN2_RIPRENDI=1 pretende, e si ferma se manca una comunita' o se
%        una compare due volte;
%     3. applica unisci_shapley_as: un solo "Shapley", esatto fino a 18 membri e Adaptive
%        Sampling oltre;
%     4. salva outputs/checkpoint_main2_<suffisso>.mat.
%   Poi MAIN2 con MAIN2_RIPRENDI=1 e MAIN2_CARTELLA=<suffisso> (stessi MAIN2_RADICE,
%   MAIN2_MAX_UTENTI, MAIN2_IND=1) trova tutte le comunita' gia' fatte e rifa' la sola
%   analisi fra comunita'.
%
%   radice        "CER_repliche/r01", oppure "" per le cartelle di sempre
%   fileRisultati string array di .mat con la variabile RESULTS
%   suffisso      come MAIN2_CARTELLA (lettere, cifre, _ e -)
%   maxUtenti     tetto di membri: 25 per la lettura unita, 18 per la vista con Nucleolo
%
%   Esempio (lettura unita della replica 1):
%     addpath('CER_repliche'); addpath('outputs/workspace/strumenti');
%     unisci_blocchi("CER_repliche/r01", ["outputs/repliche/fino15/r01/checkpoint.mat", ...
%                    "outputs/repliche/da18/r01/checkpoint.mat", ...
%                    "outputs/repliche/da20a25/r01/checkpoint.mat"], "rep01_unito", 25)
%
%   Vedi anche: unisci_shapley_as, elenco_schede_cer, MAIN2 (checkpoint e ripresa)

    radice = string(radice);
    opt = struct('conIND', true, 'maxUtenti', maxUtenti);
    if strlength(radice) > 0
        opt.cartellaBase = radice + "/CER_configuration";
        opt.cartellaPA   = radice + "/CER_configuration_PA";
        opt.cartellaIND  = radice + "/CER_configuration_IND";
    end
    schede = elenco_schede_cer(opt);

    R = [];
    for f = reshape(string(fileRisultati), 1, [])     % string prima: un char va preso intero
        K = load(f, 'RESULTS');
        if isempty(R), R = K.RESULTS; else, R = [R, K.RESULTS]; end %#ok<AGROW>
    end
    s = string({R.scheda});
    [u, ~, j] = unique(s);
    doppie = u(accumarray(j(:), 1) > 1);
    assert(isempty(doppie), 'unisci_blocchi: comunita'' in piu'' blocchi: %s', strjoin(doppie, ', '));
    [ci, pos] = ismember(schede, s);
    assert(all(ci), 'unisci_blocchi: mancano %d comunita'' dell''elenco, per esempio %s', ...
           nnz(~ci), schede(find(~ci, 1)));
    fuori = setdiff(s, schede);
    if ~isempty(fuori)
        fprintf('unisci_blocchi: %d comunita'' oltre il tetto di %d membri restano fuori\n', ...
                numel(fuori), maxUtenti);
    end
    RESULTS = unisci_shapley_as(R(pos));
    f = "outputs/checkpoint_main2_" + suffisso + ".mat";
    save(f, 'RESULTS');
    fprintf('unisci_blocchi: %d comunita'' in %s\n', numel(pos), f);
end
