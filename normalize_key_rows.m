function r = normalize_key_rows(w)
%NORMALIZE_KEY_ROWS  Normalizza ora per ora i pesi di una chiave dinamica:
%   r(t,i) = w(t,i) / sum_i w(t,i)   (eq. 4 di Gianaroli et al., 2024)
%   cosi' che sum_i r(t,i) = 1 per ogni ora, come richiesto da una chiave di
%   ripartizione.
%
%   E' usata dai metodi a chiave dinamica (pearson_key_cer.m,
%   pearson_sharing_key_cer.m) per RESTITUIRE la chiave teorica a scopo di
%   ispezione e validazione. La ripartizione vera non passa da qui:
%   allocate_shared_energy.m rinormalizza da sola a ogni iterazione sui soli
%   utenti non ancora cappati al proprio consumo.
%
%   Nelle ore in cui tutti i pesi sono nulli (nessuna immissione, o caso
%   degenere) la chiave non e' definita: si usa la ripartizione uniforme 1/n
%   invece di propagare NaN. In quelle ore l'energia condivisa e' comunque
%   nulla, quindi la scelta non ha effetto sui risultati.
%
%   INPUT   w   [H x n]  pesi non normalizzati (>= 0)
%   OUTPUT  r   [H x n]  chiave normalizzata, sum(r, 2) = 1

    n     = size(w, 2);
    sw    = sum(w, 2);
    r     = repmat(1/n, size(w));
    valid = sw > 0;
    r(valid, :) = w(valid, :) ./ sw(valid);
end
