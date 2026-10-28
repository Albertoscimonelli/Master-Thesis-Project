function esito = confronto_speedup_vlc(fileVecchio, fileNuovo, tolRel)
%CONFRONTO_SPEEDUP_VLC  Confronta due checkpoint di MAIN2 comunita' per
%   comunita': quello del run precedente allo speedup (VLC con separazione
%   MILP, Shapley a doppio ciclo) e quello rifatto con il codice nuovo
%   (separazione per enumerazione fino a 25 membri, Shapley vettorizzato).
%
%   Si confrontano, per ogni comunita' presente in entrambi (abbinate per
%   etichetta): vGrand, NPV e tutte le colonne numeriche di Tcmp, Tfair e
%   Tfin. Lo scarto e' relativo al massimo valore assoluto della grandezza
%   nella comunita' (scala comune: un valore vicino a zero non gonfia lo
%   scarto), con un pavimento di 1 EUR per le grandezze nulle.
%
%   esito = confronto_speedup_vlc()                 checkpoint di default
%   esito = confronto_speedup_vlc(vecchio, nuovo, tolRel)
%
%   OUTPUT  table, una riga per comunita': scarto massimo, grandezza in cui
%           cade, tempi di analisi prima e dopo, ok/non ok rispetto a tolRel.

    if nargin < 1 || isempty(fileVecchio)
        fileVecchio = "outputs/checkpoint_main2_solo2025_IND.mat";
    end
    if nargin < 2 || isempty(fileNuovo)
        fileNuovo = "outputs/checkpoint_main2_confronto_speedup.mat";
    end
    if nargin < 3 || isempty(tolRel), tolRel = 1e-6; end

    A = load(fileVecchio, 'RESULTS');  A = A.RESULTS;
    B = load(fileNuovo,   'RESULTS');  B = B.RESULTS;
    etA = string({A.etichetta});
    etB = string({B.etichetta});

    comuni = etA(ismember(etA, etB));
    nC     = numel(comuni);
    scarto = zeros(nC, 1);
    dove   = strings(nC, 1);
    tPrima = zeros(nC, 1);
    tDopo  = zeros(nC, 1);
    nUt    = zeros(nC, 1);

    for k = 1:nC
        a = A(etA == comuni(k));
        b = B(etB == comuni(k));
        nUt(k)    = a.nUsers;
        tPrima(k) = a.tempo_analisi_s;
        tDopo(k)  = b.tempo_analisi_s;

        [s, d]   = scarto_rel(a.vGrand, b.vGrand, "vGrand");
        [s2, d2] = scarto_rel(a.NPV, b.NPV, "NPV");
        [s, d]   = peggiore(s, d, s2, d2);
        for nomeT = ["Tcmp", "Tfair", "Tfin"]
            TA = a.(nomeT);  TB = b.(nomeT);
            for c = string(TA.Properties.VariableNames)
                if ~isnumeric(TA.(c)) || ~ismember(c, TB.Properties.VariableNames)
                    continue
                end
                [s2, d2] = scarto_rel(TA.(c), TB.(c), nomeT + "." + c);
                [s, d]   = peggiore(s, d, s2, d2);
            end
        end
        scarto(k) = s;
        dove(k)   = d;
    end

    ok = scarto <= tolRel;
    esito = table(comuni(:), nUt, scarto, dove, tPrima, tDopo, ok, ...
        'VariableNames', {'comunita', 'membri', 'scarto_rel', 'grandezza', ...
                          'tempo_prima_s', 'tempo_ora_s', 'ok'});

    fprintf('\n=== Confronto speedup VLC/Shapley: %d comunita'' in comune ===\n', nC);
    disp(esito);
    fprintf('  Tolleranza relativa: %.0e   ->   %d ok, %d oltre\n', ...
            tolRel, sum(ok), sum(~ok));
    fprintf('  Tempo di analisi: prima %.2f h, ora %.2f h (x%.1f)\n', ...
            sum(tPrima)/3600, sum(tDopo)/3600, sum(tPrima)/sum(tDopo));
end


function [s, d] = scarto_rel(x, y, nome)
%SCARTO_REL  Massimo scarto assoluto fra x e y, diviso per la scala della
%   grandezza (max |x|, almeno 1). NaN nello stesso posto contano come uguali;
%   un NaN da una parte sola o dimensioni diverse danno scarto Inf.

    d = nome;
    if ~isequal(size(x), size(y))
        s = Inf;
        return
    end
    x = double(x(:));  y = double(y(:));
    nx = isnan(x);  ny = isnan(y);
    if any(nx ~= ny)
        s = Inf;
        return
    end
    x = x(~nx);  y = y(~ny);
    if isempty(x)
        s = 0;
        return
    end
    s = max(abs(x - y)) / max(1, max(abs(x)));
end


function [s, d] = peggiore(s, d, s2, d2)
%PEGGIORE  Tiene lo scarto piu' grande e la grandezza in cui cade.

    if s2 > s
        s = s2;
        d = d2;
    end
end
