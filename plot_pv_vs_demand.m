function plot_pv_vs_demand(gen_24x365, demand_24x365, shared_24x365, nDays)
%PLOT_PV_VS_DEMAND  Andamento annuale (media giornaliera) di produzione PV,
%   richiesta della comunita' ed energia condivisa.
%
%   INPUT
%     gen_24x365    [24 x nDays]  produzione PV oraria             [kWh/h]
%     demand_24x365 [24 x nDays]  richiesta oraria comunita'       [kWh/h]
%     shared_24x365 [24 x nDays]  energia condivisa oraria         [kWh/h]
%     nDays         scalare       giorni dell'anno

    genDayMean    = mean(gen_24x365,    1);
    demDayMean    = mean(demand_24x365, 1);
    sharedDayMean = mean(shared_24x365, 1);

    figure('Name', 'PV vs Richiesta comunita', 'Color', 'w');
    hold on; grid on; box on;
    area(1:nDays, genDayMean, 'FaceAlpha', 0.30, 'FaceColor', [1.0 0.8 0.0], ...
         'EdgeColor', [0.9 0.6 0.0], 'DisplayName', 'Produzione PV');
    area(1:nDays, sharedDayMean, 'FaceAlpha', 0.45, 'FaceColor', [0.2 0.6 0.3], ...
         'EdgeColor', 'none', 'DisplayName', 'Energia condivisa');
    plot(1:nDays, demDayMean, 'Color', [0.1 0.3 0.7], 'LineWidth', 1.6, ...
         'DisplayName', 'Richiesta comunita');
    xlabel('Giorno dell''anno'); ylabel('Potenza media giornaliera [kW]');
    xlim([1 nDays]);
    legend('Location', 'northwest');
    title('Produzione PV, richiesta comunita ed energia condivisa');
end
