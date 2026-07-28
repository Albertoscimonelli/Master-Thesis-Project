function [playersOut, phiOut, mergedIdx] = merge_pv_owner(players, phi, pvOwner)
%MERGE_PV_OWNER  Unisce il giocatore "PV" (produttore) con il giocatore
%   proprietario dell'impianto in un unico giocatore "<proprietario> + PV",
%   perche' rappresentano la STESSA azienda/persona: senza questa fusione i
%   grafici mostrano un cerchio/colonna "PV" con un grande beneficio e il
%   proprietario a fianco con un beneficio quasi nullo (il suo carico e'
%   quasi tutto autoconsumato, vedi MAIN.m §1b), come se fossero due entita'
%   diverse.
%
%   INPUT
%     players [1 x n] string   nomi dei giocatori (players(1) = "PV")
%     phi     [n x 1] double   beneficio per giocatore [EUR]
%     pvOwner string           nome del proprietario dell'impianto PV; ""
%                               se non univoco (piu' impianti/proprietari)
%
%   OUTPUT
%     playersOut  [1 x m] string   m = n-1 se la fusione e' avvenuta, n altrimenti
%     phiOut      [m x 1] double   beneficio (somma delle due quote per il fuso)
%     mergedIdx   indice del giocatore fuso in playersOut ([] se non fuso)

    players = players(:).';
    phi     = phi(:);

    idxPV    = find(players == "PV", 1);
    idxOwner = find(players == pvOwner, 1);

    if pvOwner ~= "" && ~isempty(idxPV) && ~isempty(idxOwner) && idxOwner ~= idxPV
        mergedLabel = strrep(pvOwner, "_kWh", "") + " + PV";
        mergedPhi   = phi(idxPV) + phi(idxOwner);

        keep = true(1, numel(players));
        keep([idxPV idxOwner]) = false;

        playersOut = [players(keep), mergedLabel];
        phiOut     = [phi(keep); mergedPhi];
        mergedIdx  = numel(playersOut);
    else
        playersOut = players;
        phiOut     = phi;
        mergedIdx  = [];
    end
end
