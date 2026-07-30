function plot_cer_energy(meseNomi, shared_monthly, shared_annual, ...
                         rev_shared_monthly, rev_sold_monthly, rev_tot_annual)
%PLOT_CER_ENERGY  Grafici mensili della CER: energia condivisa e ricavi.
%
%   INPUT
%     meseNomi           [12 x 1] string  nomi dei mesi
%     shared_monthly     [12 x 1]  energia condivisa per mese      [kWh]
%     shared_annual      scalare   totale annuo condiviso          [kWh]
%     rev_shared_monthly [12 x 1]  ricavo da energia condivisa     [EUR]
%     rev_sold_monthly   [12 x 1]  ricavo da energia venduta       [EUR]
%     rev_tot_annual     scalare   ricavo totale annuo             [EUR]

    % --- Energia condivisa mensile + totale annuo ---------------------------
    figure('Name', 'Energia condivisa CER', 'Color', 'w');
    bar(1:12, shared_monthly, 'FaceColor', [0.20 0.60 0.30]);
    grid on; box on;
    xticks(1:12); xticklabels(meseNomi); xtickangle(45);
    ylabel('Energia condivisa [kWh]');
    title(sprintf('Energia condivisa mensile  |  Totale annuo = %.0f kWh', shared_annual));

    % --- Ricavi mensili (condivisa vs venduta) ------------------------------
    figure('Name', 'Ricavi CER', 'Color', 'w');
    bar(1:12, [rev_shared_monthly, rev_sold_monthly], 'stacked');
    grid on; box on;
    xticks(1:12); xticklabels(meseNomi); xtickangle(45);
    ylabel('Ricavo [€]');
    legend('Energia condivisa', 'Energia venduta', 'Location', 'northwest');
    title(sprintf('Ricavi mensili  |  Totale annuo = €%.0f', rev_tot_annual));
end
