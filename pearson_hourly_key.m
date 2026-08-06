function [pHourly, pDaily] = pearson_hourly_key(loadUsers, Einj)
%PEARSON_HOURLY_KEY  Coefficiente di correlazione di Pearson GIORNALIERO tra
%   il profilo di consumo di ciascun utente e il profilo di immissione in
%   rete della comunita', rimappato in [0,1] ed espanso a livello orario.
%
%   E' il "peso grezzo" del metodo M3 di Gianaroli et al., Energy & Buildings
%   311 (2024) 114158 (§1 della guida di implementazione): premia chi consuma
%   proprio nelle ore in cui la comunita' ha surplus da condividere
%   (sincronismo giornaliero), a prescindere da QUANTO consuma.
%
%   PASSAGGI
%     1. Per ogni giorno d (24 ore) e ogni utente i:
%          p(i,d) = Pearson( load_i(ore di d), Einj(ore di d) )
%        Se la deviazione standard di uno dei due vettori e' nulla (utente a
%        consumo costante/nullo quel giorno, o giornata senza immissione) il
%        coefficiente non e' definito: si pone p = 0, cioe' nessuna
%        correlazione, comportamento neutro.
%     2. Rimappatura lineare da [-1,1] a [0,1]:  pRemap = (p + 1) / 2.
%        Serve perche' i pesi di una chiave di ripartizione devono essere non
%        negativi: una correlazione perfettamente opposta da' peso 0, una
%        correlazione nulla da' 0.5, una correlazione perfetta da' 1.
%     3. Espansione: tutte le 24 ore dello stesso giorno ereditano lo stesso
%        valore (il coefficiente e' costante nella giornata, cambia da un
%        giorno all'altro).
%
%   La NORMALIZZAZIONE tra utenti (eq. 4 del paper, r = p / sum_i p) NON e'
%   fatta qui di proposito: M5 combina il peso grezzo di Pearson con lo
%   sharing rate PRIMA di normalizzare, e allocate_shared_energy rinormalizza
%   comunque a ogni iterazione sui soli utenti attivi.
%
%   INPUT
%     loadUsers [H x n]   carico residuo orario di ciascun utente  [kWh/h]
%                         H deve essere un multiplo di 24
%     Einj      [H x 1]   energia immessa in rete dalla comunita'  [kWh/h]
%
%   OUTPUT
%     pHourly   [H x n]   coefficiente rimappato in [0,1], costante nelle 24
%                         ore di ciascun giorno
%     pDaily    [nGiorni x n]  coefficiente di Pearson GREZZO in [-1,1], utile
%                         per la validazione (box plot delle Fig. 11-12 del
%                         paper) e per il debug

    [H, n] = size(loadUsers);
    Einj   = Einj(:);

    if numel(Einj) ~= H
        error('pearson_hourly_key:sizeMismatch', ...
              'Einj ha %d ore, loadUsers ne ha %d.', numel(Einj), H);
    end
    if mod(H, 24) ~= 0
        error('pearson_hourly_key:notWholeDays', ...
              ['La serie ha %d ore, non un multiplo di 24: il coefficiente di ' ...
               'Pearson e'' definito su giornate intere. Completare o scartare ' ...
               'il giorno incompleto prima di chiamare questa funzione.'], H);
    end

    nDays = H / 24;

    % Riorganizzazione in giornate: elemento (h, d, i) = ora h del giorno d
    % dell'utente i (stesso reshape 24 x nGiorni usato in MAIN.m §2).
    Cd = reshape(loadUsers, 24, nDays, n);
    Ed = reshape(Einj,      24, nDays);

    Ccen = Cd - mean(Cd, 1);          % scarti dalla media giornaliera
    Ecen = Ed - mean(Ed, 1);

    num = sum(Ccen .* Ecen, 1);                            % [1 x nDays x n]
    den = sqrt(sum(Ccen.^2, 1)) .* sqrt(sum(Ecen.^2, 1));  % [1 x nDays x n]

    pDaily3 = zeros(1, nDays, n);
    ok      = den > 0;                % varianza non nulla su entrambi i lati
    pDaily3(ok) = num(ok) ./ den(ok);
    pDaily3 = max(min(pDaily3, 1), -1);   % guardia numerica sui bordi

    % Rimappatura in [0,1] ed espansione alle 24 ore della giornata
    pHourly = reshape(repmat((pDaily3 + 1) / 2, 24, 1, 1), H, n);

    pDaily = reshape(pDaily3, nDays, n);
end
