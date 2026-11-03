function RESULTS = unisci_shapley_as(RESULTS)
%UNISCI_SHAPLEY_AS  Un solo metodo "Shapley": esatto fino a 18 membri, Adaptive Sampling oltre.
%
%   RESULTS = unisci_shapley_as(RESULTS)
%
%   Nelle comunita' sopra i 18 membri MAIN2 non calcola lo Shapley esatto, e l'Adaptive
%   Sampling Shapley (AS) ne prende il posto (README §7.6.1). Senza questa funzione l'analisi
%   fra comunita' di un run che mescola le due taglie tiene i soli metodi comuni a tutte
%   (compute_indicator_agreement), cioe' l'AS ovunque e nessuno Shapley esatto: anche dove
%   l'esatto c'e'. Qui, nelle comunita' senza Shapley esatto, l'AS si rinomina "Shapley" in
%   tutti i campi che portano il nome del metodo; dove l'esatto c'e' non si tocca nulla.
%   Rilanciando MAIN2 con MAIN2_RIPRENDI=1 su questi RESULTS lo Shapley risulta presente in
%   tutte le comunita', e MAIN2 esclude da se' l'AS dove e' un duplicato (§7b).
%
%   Campi toccati (solo nelle comunita' senza Shapley esatto):
%     metodi(k).nome, Tfair.Metodo,
%     forza, forzaLorda, soglia: .methods e .table.Metodo,
%     Tcmp: colonna AdaptiveSampling_EUR -> Shapley_EUR,
%     Tfin: colonna Incentivo_AdaptiveSamplingShapley_E -> Incentivo_Shapley_E
%           (MAIN2 usa gia' l'AS come riferimento di Tfin oltre i 18 membri)
%   Il campo fase1 (confronto AS contro esatto) resta com'e'. Alla fine si controlla che il
%   nome dell'AS non compaia piu' in quelle comunita'.
%
%   Vedi anche: MAIN2 (§7b), compute_indicator_agreement, CER_repliche/README.md

    AS = "Adaptive Sampling Shapley";
    SH = "Shapley";
    for c = 1:numel(RESULTS)
        nomi = [RESULTS(c).metodi.nome];
        if any(nomi == SH)
            continue                                  % <= 18 membri: esatto presente
        end
        k = find(nomi == AS);
        assert(isscalar(k), 'unisci_shapley_as: %s senza Shapley e senza AS', RESULTS(c).etichetta);
        RESULTS(c).metodi(k).nome = SH;
        RESULTS(c).Tfair = local_colonna(RESULTS(c).Tfair, 'Metodo', AS, SH, ...
                                         RESULTS(c).etichetta + " Tfair");

        for f = ["forza", "forzaLorda", "soglia"]
            F = RESULTS(c).(f);
            if ~isstruct(F), continue, end
            dove = RESULTS(c).etichetta + " " + f;
            if isfield(F, 'methods')
                mm = string(F.methods);
                assert(nnz(mm == AS) == 1, 'unisci_shapley_as: %s.methods', dove);
                mm(mm == AS) = SH;
                if iscell(F.methods), F.methods = cellstr(mm); else, F.methods = mm; end
            end
            if isfield(F, 'table') && istable(F.table) && ...
               ismember('Metodo', F.table.Properties.VariableNames)
                F.table = local_colonna(F.table, 'Metodo', AS, SH, dove + ".table");
            end
            RESULTS(c).(f) = F;
        end

        RESULTS(c).Tcmp = local_rinomina_var(RESULTS(c).Tcmp, 'AdaptiveSampling_EUR', ...
                                             'Shapley_EUR', RESULTS(c).etichetta + " Tcmp");
        if ~isempty(RESULTS(c).Tfin)
            RESULTS(c).Tfin = local_rinomina_var(RESULTS(c).Tfin, ...
                                                 'Incentivo_AdaptiveSamplingShapley_E', ...
                                                 'Incentivo_Shapley_E', RESULTS(c).etichetta + " Tfin");
        end

        % nessun'altra traccia del nome, fuori dal confronto della fase 1
        R = rmfield(RESULTS(c), intersect(fieldnames(RESULTS(c)), {'fase1', 'CFG'}));
        assert(~local_contiene(R, AS) && ~local_contiene(R, "AdaptiveSampling"), ...
               'unisci_shapley_as: in %s il nome dell''AS resta in un campo non previsto', ...
               RESULTS(c).etichetta);
    end
end


function T = local_colonna(T, col, da, a, dove)
    m = string(T.(col));
    assert(nnz(m == da) == 1, 'unisci_shapley_as: %s', dove);
    m(m == da) = a;
    if iscell(T.(col)), T.(col) = cellstr(m); else, T.(col) = m; end
end


function T = local_rinomina_var(T, da, a, dove)
    v = T.Properties.VariableNames;
    assert(ismember(da, v) && ~ismember(a, v), 'unisci_shapley_as: %s', dove);
    T = renamevars(T, da, a);
end


function tf = local_contiene(x, s)
    tf = false;
    if isstring(x) || ischar(x) || iscellstr(x)
        tf = any(contains(string(x(:)), s), 'all');
    elseif istable(x)
        tf = any(contains(string(x.Properties.VariableNames), s));
        for v = string(x.Properties.VariableNames)
            if tf, return; end
            tf = local_contiene(x.(v), s);
        end
    elseif isstruct(x)
        for e = 1:numel(x)
            for f = string(fieldnames(x)).'
                if tf, return; end
                tf = local_contiene(x(e).(f), s);
            end
        end
    elseif iscell(x)
        for e = 1:numel(x)
            if tf, return; end
            tf = local_contiene(x{e}, s);
        end
    end
end
