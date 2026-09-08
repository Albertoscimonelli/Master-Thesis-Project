function [discrimina, tolTie, ampiezza] = indicator_tie_tol(x, opts)
%INDICATOR_TIE_TOL  Quando due metodi vanno considerati A PARI su un indicatore,
%   e quando un indicatore non ordina proprio niente.
%
%   PERCHE' UNA FUNZIONE A SE' E NON DUE RIGHE IN CIASCUN CHIAMANTE
%     La regola dei pareggi serve a due posti diversi:
%     compute_indicator_agreement.m, per contare le coppie concordi nel tau di
%     Kendall, ed extract_ranking_reversals.m, per decidere se un cambio di segno
%     e' un'inversione vera. Se le due usassero soglie anche solo leggermente
%     diverse, la stessa coppia di metodi potrebbe risultare "a pari" per il tau e
%     "invertita" per le inversioni, e i due file direbbero cose incompatibili
%     sulla stessa configurazione senza che nessun errore lo segnali.
%
%   DUE SOGLIE, NON UNA
%     Una tolleranza assoluta unica sarebbe sbagliata, perche' gli indicatori del
%     progetto vivono su scale incomparabili: EccessoMax_EUR sta in centinaia di
%     euro, Gini in centesimi, QoS intorno a 0.99xx. La stessa soglia sarebbe
%     cieca su uno e paranoica sull'altro.
%
%     SOGLIA 1 - DISCRIMINAZIONE. L'indicatore non ordina niente se l'escursione
%     fra i metodi e' trascurabile rispetto alla sua stessa scala:
%         max(x) - min(x) <= tolAssoluta * max(1, max|x|)
%     Non e' un caso di scuola: il MinMax originale e' IDENTICO su tutti e sedici
%     i metodi per proprieta' dei flussi fisici (README §7.2), e MinMax_con, QoS e
%     Jain variano pochissimo perche' sulla community di default solo l'8.7%
%     dell'energia condivisa e' contendibile.
%
%     SOGLIA 2 - PAREGGIO FRA DUE. Dato che l'indicatore discrimina, due metodi
%     sono a pari se distano poco rispetto all'ESCURSIONE OSSERVATA:
%         |a - b| <= tolRelativa * (max(x) - min(x))
%     Adimensionale per costruzione: impedisce che una differenza a 1e-15 - cioe'
%     rumore di arrotondamento - venga letta come un'inversione di graduatoria,
%     senza pero' cancellare una differenza vera a 1e-4.
%
%   I NaN NON SONO UN CASO IPOTETICO
%     Tfair contiene gia' NaN oggi: jain_index li restituisce per costruzione
%     quando l'indice non e' definito, e l'assert di dominio della §3t li ammette
%     esplicitamente. Un solo NaN rende l'ordinamento incompleto, quindi
%     l'indicatore e' dichiarato NON DISCRIMINANTE per quella configurazione. E'
%     una scelta conservativa e va dichiarata: meglio "qui questo indicatore non
%     ordina" che una graduatoria costruita su un sottoinsieme dei metodi.
%
%   INPUT
%     x     [m x 1]  punteggi dei metodi su UN indicatore, in UNA configurazione
%     opts  struct opzionale:
%             .tolAssoluta  soglia di discriminazione (def. 1e-9)
%             .tolRelativa  soglia di pareggio (def. 1e-6)
%
%   OUTPUT
%     discrimina  logico   false se l'indicatore e' costante o contiene NaN
%     tolTie      scalare  sotto cui due punteggi sono a pari (0 se non discrimina)
%     ampiezza    scalare  max(x) - min(x), l'escursione osservata

    if nargin < 2 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'tolAssoluta'), opts.tolAssoluta = 1e-9; end
    if ~isfield(opts, 'tolRelativa'), opts.tolRelativa = 1e-6; end

    x = x(:);
    if isempty(x)
        error('indicator_tie_tol:vuoto', ...
              'Il vettore dei punteggi e'' vuoto: non c''e'' niente da ordinare.');
    end

    if any(~isfinite(x))
        discrimina = false;
        tolTie     = 0;
        ampiezza   = NaN;
        return
    end

    ampiezza   = max(x) - min(x);
    scala      = max(1, max(abs(x)));
    discrimina = ampiezza > opts.tolAssoluta * scala;

    if discrimina
        tolTie = opts.tolRelativa * ampiezza;
    else
        tolTie = 0;
    end
end
