% f2b_trial_counts.m -- trial counts per session x amplitude behind Fig 2B (and Fig 2G).
% Requires: load_experiments.m has been run (allExperiments).
% Counts = non-NaN evoked-suppression values per nonzero amplitude, i.e. exactly what
% dose_response.m averages. Amplitudes are command volts; mW = V/3 (paper convention).
% Writes data/fig2b_trial_counts.csv, read by paper-writing/paper_stats_tex.m (Table S1).
here = fileparts(which('f2b_trial_counts'));
mouseTxt = imp_mouse_label(allExperiments);   % paper-wide session labels (utils/paper_session_label.m)
rows = {};
for e = 1:numel(allExperiments)
    g = allExperiments(e).groupLabels;  v = allExperiments(e).allVals;
    [ug,~,ix] = unique(g, 'stable');
    n  = accumarray(ix(:), ~isnan(v(:)));
    aV = str2double(cellstr(ug));
    [aV,o] = sort(aV);  n = n(o);  k = aV > 0;
    aV = aV(k);  n = n(k);
    for j = 1:numel(aV)
        rows(end+1,:) = {mouseTxt{e}, allExperiments(e).mn, allExperiments(e).td, ...
                         aV(j), aV(j)/3, n(j)}; %#ok<SAGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'label','mouse','date','amp_V','amp_mW','n'});
out = fullfile(here, '..', 'data', 'fig2b_trial_counts.csv');
writetable(T, out);
fprintf('[f2b] %d session x amplitude rows, %d trials -> %s\n', height(T), sum(T.n), out);
