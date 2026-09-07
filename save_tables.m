function elenco = save_tables(cartella, tabelle, opts)
%SAVE_TABLES  Scrive su CSV le tabelle di risultato, una per file.
%
%   LA PRIMA PERSISTENZA NUMERICA DEL PROGETTO
%     Fino a qui la pipeline MATLAB non salvava un solo numero: nessun save,
%     nessun writetable, nessun writematrix in tutto il repository. RESULTS viveva
%     nel workspace e moriva alla chiusura di MATLAB, e l'unico output su disco
%     erano i PDF e i PNG di save_figures. Ogni cifra citata in tesi andava
%     riletta a schermo da un'esecuzione completa.
%     Questa funzione rompe quella convenzione, e la rottura va dichiarata invece
%     che infilata di soppiatto in un writetable qualunque: da qui in avanti
%     esistono risultati numerici versionati.
%
%   PERCHE' QUESTI CSV SI VERSIONANO, A DIFFERENZA DELLE FIGURE
%     Il .gitignore esclude outputs/figures/ con una motivazione precisa: pesano
%     in PNG e cambiano a ogni ritocco grafico, quindi versionarle riempirebbe la
%     storia di rumore binario. Nessuna delle due ragioni vale per un CSV ASCII da
%     poche decine di KB, che invece si legge in diff. Questi file SONO le
%     affermazioni numeriche del capitolo, e un diff su di essi e' esattamente la
%     tracciabilita' che serve.
%
%   SI ARROTONDA IN SCRITTURA, MAI NELLA STRUCT
%     La precisione di default di writetable e' di una quindicina di cifre
%     significative, e garantirebbe churn a 1e-16 a ogni riesecuzione:
%     indistinguibile, in un diff, da un cambiamento vero. Si arrotonda quindi
%     qui, e solo qui - i numeri nella struct restano interi. Gli euro a due
%     decimali fissi; tutto il resto a sei cifre SIGNIFICATIVE, con uno zero
%     vero sotto 1e-12. Il perche' di quella distinzione e' in local_arrotonda:
%     coi decimali fissi un divario di 3e-8 diventerebbe "0.000000" proprio nelle
%     righe dove serve leggerlo.
%
%   VIRGOLA E NON PUNTO E VIRGOLA
%     CSV standard separato da virgola, intestazioni e valori ASCII. Excel in
%     locale italiano chiedera' la procedura di importazione; mettere il punto e
%     virgola renderebbe il file comodo li' e non standard ovunque. Il compromesso
%     e' scritto qui invece di essere scelto in silenzio.
%
%   NON INTERROMPE MAI L'ANALISI
%     Stessa gerarchia di save_figures: ogni scrittura sta in un try, un file
%     bloccato (aperto in Excel, tipicamente) produce un warning e non un errore
%     che risale a MAIN. Perdere minuti di analisi perche' un foglio era aperto
%     sarebbe il baratto sbagliato.
%
%   INPUT
%     cartella  string  cartella di destinazione, creata se non esiste
%     tabelle   struct  un campo per file: il NOME DEL CAMPO diventa il nome del
%                       file (campo.csv), il valore e' una table
%     opts      struct (opzionale)
%                 .decimali     cifre per le colonne generiche (def. 6)
%                 .decimaliEUR  cifre per le colonne in euro    (def. 2)
%                 .quiet        non stampare il riepilogo       (def. false)
%
%   OUTPUT
%     elenco    [k x 1] string  percorsi dei file effettivamente scritti

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'decimali'),    opts.decimali    = 6;     end
    if ~isfield(opts, 'decimaliEUR'), opts.decimaliEUR = 2;     end
    if ~isfield(opts, 'zero'),        opts.zero        = 1e-12; end
    if ~isfield(opts, 'quiet'),       opts.quiet       = false; end

    if ~isstruct(tabelle) || isempty(fieldnames(tabelle))
        error('save_tables:nessunaTabella', ...
              'Il secondo argomento deve essere una struct con almeno un campo.');
    end

    cartella = string(cartella);
    if ~isfolder(cartella)
        mkdir(cartella);
    end

    nomi   = string(fieldnames(tabelle)).';
    elenco = string.empty(0, 1);
    saltate = 0;

    for nome = nomi
        T = tabelle.(nome);
        if ~istable(T)
            error('save_tables:nonEUnaTabella', ...
                  'Il campo "%s" non contiene una table.', nome);
        end

        T = local_arrotonda(T, opts.decimali, opts.decimaliEUR, opts.zero);
        percorso = fullfile(cartella, nome + ".csv");

        try
            writetable(T, percorso);
            elenco(end+1, 1) = percorso; %#ok<AGROW>
            if ~opts.quiet
                fprintf('  %-38s %6d righe x %2d colonne\n', ...
                        nome + ".csv", height(T), width(T));
            end
        catch ME
            saltate = saltate + 1;
            warning('save_tables:scritturaFallita', ...
                    'Non e'' stato possibile scrivere %s: %s', percorso, ME.message);
        end
    end

    if ~opts.quiet && saltate > 0
        fprintf('  %d tabelle saltate (vedi i warning qui sopra).\n', saltate);
    end
end


% ===========================================================================
%  FUNZIONI LOCALI
% ===========================================================================

function T = local_arrotonda(T, dec, decEUR, zero)
%LOCAL_ARROTONDA  Arrotonda le sole colonne numeriche, distinguendo gli euro dal
%   resto sul nome della colonna: e' l'unica informazione disponibile, e le
%   colonne del progetto la portano gia' (suffisso _EUR o _E).
%
%   CIFRE SIGNIFICATIVE, NON DECIMALI FISSI, PER LE COLONNE GENERICHE
%     Con i decimali fissi un divario di 3e-8 diventa "0.000000", e proprio dove
%     serve leggerlo: le inversioni di graduatoria su MinMax_con, QoS e Jain -
%     i tre indicatori che il README §7.2 dichiara quasi costanti, perche' solo
%     l'8.7% dell'energia condivisa e' contendibile - hanno divari di
%     quell'ordine. Un lettore vedrebbe "un'inversione con divario zero" e
%     concluderebbe che il codice conta il rumore, quando il divario c'e' ed e'
%     solo piccolo. Con le cifre SIGNIFICATIVE resta leggibile a ogni scala.
%
%   ...MA CON UNO ZERO VERO SOTTO SOGLIA
%     Le cifre significative da sole conserverebbero anche un 1e-32, cioe' lo
%     zero numerico dell'Equal Split sulla forza incentivante, e quel valore
%     cambia nell'ultimo bit a ogni riesecuzione: churn puro in un diff. Sotto
%     soglia si scrive zero, che e' anche cio' che quel numero significa.
%
%   Gli euro restano a decimali fissi: due centesimi sono due centesimi, e le
%   cifre significative su un importo grande darebbero una precisione finta.
    vars = string(T.Properties.VariableNames);
    for k = 1:numel(vars)
        col = T.(vars(k));
        if ~isnumeric(col) || islogical(col), continue; end
        col(abs(col) < zero) = 0;
        if endsWith(vars(k), "_EUR") || endsWith(vars(k), "_E") || ...
           contains(vars(k), "EUR")
            T.(vars(k)) = round(col, decEUR);
        else
            T.(vars(k)) = round(col, dec, 'significant');
        end
    end
end
