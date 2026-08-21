function s = rmfield_if(s, campo)
%RMFIELD_IF  Toglie un campo da una struct, senza errore se non c'e'.
%
%   rmfield() solleva un errore se il campo manca, e questo costringe a
%   scrivere ovunque un isfield() di guardia. Serve quando si costruisce una
%   struct opts a partire dai dati disponibili: quali campi ci siano dipende
%   da come e' compilata la scheda, non da come e' scritto il codice.
%
%   INPUT
%     s      struct
%     campo  string o char, oppure array di nomi
%
%   OUTPUT
%     s      la struct senza quei campi

    campo = string(campo);
    for k = 1:numel(campo)
        if isfield(s, campo(k))
            s = rmfield(s, campo(k));
        end
    end
end
