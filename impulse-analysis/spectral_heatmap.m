% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

%% Interactive freq heatmap â€” click a trial row to open detail view

%
% Same layout as static heatmap above.
% Click any row â†’ impulseDetailCallback opens a 3-panel figure:
%   top: dF/F trial trace + amp-mean Â± SD
%   mid: z-scored motion trace
%   bot: per-trial vs mean absolute band power

t_win_imp = -tWin : 1/35 : tWin;   % time vector matching df_imp columns

for expIdx = 1:nExp

    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Shared color limit for this experiment
    all_freq_e = vertcat(imp_e.freqSpec{:});
    clim_e     = prctile(all_freq_e(:), 98);

    nCols_f = min(nAmp_e, 4);
    nRows_f = ceil(nAmp_e / nCols_f);

    fig_fi = figure('Color','w');
    fig_fi.Units    = 'inches';
    fig_fi.Position = [2, 2, nCols_f*3.5, nRows_f*3];
    sgtitle(sprintf('%s  %s  e%d â€” click trial row for detail', ...
        allExperiments(expIdx).mn, allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 10, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        dev_i  = imp_e.Peak_imp_dev{iAmp}(:);
        freq_i = imp_e.freqSpec{iAmp};
        nUse   = min(numel(dev_i), size(freq_i,1));
        if nUse < 2, continue; end
        dev_i  = dev_i(1:nUse);
        freq_i = freq_i(1:nUse, :);

        [~, sOrd] = sort(dev_i, 'ascend');

        ax = subplot(nRows_f, nCols_f, iAmp);
        hImg = imagesc(ax, freqBandCtrs, 1:nUse, freq_i(sOrd, :));
        colormap(ax, 'hot');
        clim(ax, [0 clim_e]);
        cb = colorbar(ax);  cb.Label.String = 'Power (\DeltaF/F)^2 Hz^{-1}';
        xlabel(ax, 'Frequency (Hz)', 'FontSize', 8);
        ylabel(ax, 'Trial (sorted by dev)', 'FontSize', 8);
        title(ax, sprintf('%.2f V  (n=%d)  [click]', imp_e.uAmp{iAmp}, nUse), ...
            'FontSize', 8, 'FontWeight','bold');
        set(ax, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 8);
        xticks(ax, 0:2:10);

        % Capture per-iteration values for the closure
        c_ax   = ax;
        c_sOrd = sOrd;
        c_imp  = imp_e;
        c_iAmp = iAmp;
        c_twin = t_win_imp;
        set(hImg, 'ButtonDownFcn', ...
            @(~,~) impulseDetailCallback(c_ax, c_sOrd, c_imp, c_iAmp, c_twin));
    end
end
