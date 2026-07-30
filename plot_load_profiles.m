function plot_load_profiles(tGrid, loadUsers, userNames, anno)
%PLOT_LOAD_PROFILES  Profili di consumo in 4 giorni tipo (uno per stagione),
%   separando utenze commerciali e residenziali.
%
%   INPUT
%     tGrid     [H x 1]  datetime  griglia oraria canonica
%     loadUsers [H x nC] carichi orari                       [kWh/h]
%     userNames [1 x nC] nomi degli utenti                   (string)
%     anno      scalare  anno di riferimento (per i giorni tipo)

    stagioni = ["Inverno (15 gen)", "Primavera (15 apr)", ...
                "Estate (15 lug)",  "Autunno (15 ott)"];
    giorni   = datetime([anno 1 15; anno 4 15; anno 7 15; anno 10 15]);

    isRes  = startsWith(userNames, 'household');
    idxRes = find(isRes);
    idxCom = find(~isRes);

    if ~isempty(idxCom)
        plot_seasonal(tGrid, loadUsers, idxCom, userNames, giorni, stagioni, ...
            'Profili commerciali', 'Profili di consumo COMMERCIALI - 4 giorni tipo');
    end
    if ~isempty(idxRes)
        plot_seasonal(tGrid, loadUsers, idxRes, userNames, giorni, stagioni, ...
            'Profili residenziali', 'Profili di consumo RESIDENZIALI - 4 giorni tipo');
    end
end


function plot_seasonal(t, dataMat, colIdx, names, giorni, stagioni, figName, figTitle)
%PLOT_SEASONAL  Traccia i profili orari di un gruppo di utenti in 4 giorni
%   tipo (uno per stagione), in un layout 2x2.

    nC   = numel(colIdx);
    cmap = lines(nC);
    figure('Name', figName, 'Color', 'w', 'Position', [120 120 1300 820]);
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    for d = 1:4
        nexttile; hold on; grid on; box on;
        maskDay = dateshift(t, 'start', 'day') == giorni(d);
        tDay    = t(maskDay);
        hAxis   = hours(tDay - dateshift(tDay(1), 'start', 'day'));
        for u = 1:nC
            plot(hAxis, dataMat(maskDay, colIdx(u)), 'Color', cmap(u,:), ...
                 'LineWidth', 1.4, 'DisplayName', strrep(names(colIdx(u)), '_', '\_'));
        end
        xlim([0 24]); xticks(0:4:24);
        xlabel('Ora del giorno [h]'); ylabel('Potenza [kW]');
        title(stagioni(d));
        if d == 1
            legend('Location', 'northeast', 'FontSize', 8);
        end
    end
    sgtitle(figTitle, 'FontSize', 13, 'FontWeight', 'bold');
end
