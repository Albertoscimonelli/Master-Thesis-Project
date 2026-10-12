function OUT = ricalcola_inversioni_soglia(RESULTS, AGR, opts)
%RICALCOLA_INVERSIONI_SOGLIA  Inversioni, vincitori e interazione con la soglia
%   di rilevanza su tutti gli indicatori, SENZA rilanciare MAIN2.
%
%   Parte da RESULTS e AGR di una esecuzione (workspace salvato) e rifa' solo il
%   post-processing di MAIN2 §7b: apply_relevance_threshold, ranking_grid,
%   reversals_by_axis. Serve per riportare i risultati a piu' soglie (5/10/20%)
%   senza ripagare ore di Shapley e Nucleolo.
%
%   opts.fracEscursione  soglia sugli indicatori non in euro   (def. 0.10)
%   opts.fracVN          soglia sugli indicatori in euro       (def. 0.05)
%   opts.cartella        dove scrivere i CSV; vuoto = non scrive
%
%   OUT: .GRID .REV .AGR e .riepilogo (una riga per sweep).

    if nargin < 3 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'cartella'), opts.cartella = ""; end
    optSoglia = rmfield_if(opts, {'cartella'});

    vN  = [RESULTS.vGrand];
    AGR = apply_relevance_threshold(AGR, vN, optSoglia);

    GRID = ranking_grid(AGR, RESULTS);
    REV  = reversals_by_axis(AGR, GRID);
    assert(height(REV.inversioni) == sum(REV.sommario.nInversioni), ...
           'Inversioni: il dettaglio e il sommario non contano lo stesso numero');

    OUT = struct('GRID', GRID, 'REV', REV, 'AGR', AGR, 'riepilogo', REV.perSweep);

    if strlength(string(opts.cartella)) > 0
        save_tables(opts.cartella, struct( ...
            'inversioni_di_graduatoria', REV.inversioni, ...
            'inversioni_sommario',       REV.sommario, ...
            'inversioni_per_sweep',      REV.perSweep, ...
            'griglia_vincitori',         GRID.table, ...
            'griglia_interazione',       GRID.interazione));
    end
end
