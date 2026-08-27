function elenco = save_figures(cartella, opts)
%SAVE_FIGURES  Salva su file tutte le figure aperte, una per file.
%
%   PERCHE' NON E' OGNI GRAFICO A SALVARSI DA SOLO
%     Nessuna delle funzioni plot_* restituisce un handle, e non serve che lo
%     faccia: MAIN.m apre con close all e chiude ogni giro di ciclo, quindi in
%     qualunque momento le figure aperte sono ESATTAMENTE quelle della CER in
%     corso. Raccoglierle qui evita di toccare sette funzioni di disegno per
%     aggiungere una riga di export a ciascuna, e soprattutto evita che
%     aggiungere un grafico nuovo domani richieda di ricordarsi di salvarlo.
%
%   IL NOME DEL FILE VIENE DALLA FIGURA
%     Ogni plot_* dichiara figure('Name', ...) con un nome descrittivo e
%     univoco (i grafici a rete ci mettono dentro il nome del metodo). Quel
%     nome diventa il nome del file, sanificato: cosi' la cartella di output si
%     legge senza dover aprire le immagini. Le figure senza Name prendono un
%     progressivo, ed e' il segnale che al grafico manca il Name.
%
%   DUE FORMATI, PER DUE USI
%     PDF vettoriale per la tesi (si ingrandisce senza sgranare, il testo resta
%     testo) e PNG per guardarle in fretta o incollarle in una mail. Costano
%     poco entrambi e servono in momenti diversi.
%
%   INPUT
%     cartella  string  cartella di destinazione, creata se non esiste
%     opts      struct (opzionale)
%                 .chiudi   logico  chiude le figure dopo il salvataggio
%                                   (def. false)
%                 .risoluzione  scalare  DPI del PNG (def. 200)
%                 .quiet    logico  non stampare il riepilogo (def. false)
%
%   OUTPUT
%     elenco    [k x 1] string  percorsi dei file PDF scritti

    if nargin < 2 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'chiudi'),      opts.chiudi      = false; end
    if ~isfield(opts, 'risoluzione'), opts.risoluzione = 200;   end
    if ~isfield(opts, 'quiet'),       opts.quiet       = false; end

    cartella = string(cartella);
    if ~isfolder(cartella)
        mkdir(cartella);
    end

    % Le figure vengono restituite dalla piu' recente alla piu' vecchia: si
    % rovescia l'ordine, cosi' il progressivo dei nomi mancanti segue l'ordine
    % in cui i grafici sono stati creati e non quello inverso.
    figs = flipud(findobj(groot, 'Type', 'figure'));
    if isempty(figs)
        elenco = string.empty(0, 1);
        if ~opts.quiet
            fprintf('  Nessuna figura aperta da salvare.\n');
        end
        return
    end

    elenco = strings(numel(figs), 1);
    usati  = strings(0, 1);          % nomi gia' assegnati, per i duplicati

    for k = 1:numel(figs)
        nome = local_sanitize(figs(k).Name, k);

        % Due figure con lo stesso Name si sovrascriverebbero in silenzio.
        % Meglio un suffisso: il file in piu' si nota, il file perso no.
        if any(usati == nome)
            nome = nome + "_" + string(sum(usati == nome) + 1);
        end
        usati(end+1) = nome; %#ok<AGROW>

        base = fullfile(cartella, nome);
        exportgraphics(figs(k), base + ".pdf", 'ContentType', 'vector');
        exportgraphics(figs(k), base + ".png", 'Resolution', opts.risoluzione);
        elenco(k) = base + ".pdf";
    end

    if opts.chiudi
        close(figs);
    end

    if ~opts.quiet
        fprintf('  %d figure salvate in %s\n', numel(figs), cartella);
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function nome = local_sanitize(raw, progressivo)
%LOCAL_SANITIZE  Nome di file valido a partire dal Name della figura.
%   Tiene solo lettere, cifre, '-' e '_', comprime gli spazi in underscore e
%   toglie gli accenti piu' comuni: un nome file con l'apostrofo o con la
%   barra rompe il salvataggio su Windows, e un nome file con l'accento rompe
%   la portabilita' fra sistemi.
    raw = strtrim(string(raw));
    if strlength(raw) == 0
        nome = sprintf('figura_%02d', progressivo);
        return
    end

    accentate = ["à" "è" "é" "ì" "ò" "ù" "À" "È" "É" "Ì" "Ò" "Ù"];
    semplici  = ["a" "e" "e" "i" "o" "u" "A" "E" "E" "I" "O" "U"];
    raw = replace(raw, accentate, semplici);

    raw = regexprep(char(raw), '[^A-Za-z0-9_\-]+', '_');
    raw = regexprep(raw, '_+', '_');
    raw = regexprep(raw, '^_|_$', '');

    if isempty(raw)
        nome = sprintf('figura_%02d', progressivo);
    else
        % Windows si ferma a 260 caratteri di percorso completo: un nome di
        % figura molto lungo va tagliato prima che sia il filesystem a farlo.
        nome = string(raw(1:min(end, 80)));
    end
end
