function imp_state_var_combined(R, paperRoot)
% IMP_STATE_VAR_COMBINED  Fig 2G panel: motion | rel-delta | abs-delta, shared y-axis.
%   imp_state_var_combined()             % reads data/fig2g_state_stats.mat (STV_R)
%   imp_state_var_combined(R, paperRoot) % R = STV.R, as imp_state_trialvar_fig.m passes it
%
% Extracted 2026-10-16 from imp_state_trialvar_fig.m so 2G can be rebuilt from the saved stats
% without reloading the data. Same drawing as before, minus the inference marks:
% DESCRIPTIVE PANEL (user 2026-10-16: Fig 2 is groundwork, Fig 3 carries the claims). No stars,
% no k/N sessions; the per-session slope test lives only in the stats table (Table 4, supporting).
%
% Thin lines = each session's own quartile curve (normalized to that session's typical error);
% bold = their EQUAL-WEIGHT mean; dashed = stim-free control mean. No CI band: with four sessions
% the individual curves are the uncertainty.
% Export: paper/images/figure2/imp_state_var_combined.pdf via paperExport (-> figures_final when
% global PAPER_FINAL is true; the panel is in MANIFEST.txt).
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(R)
    S = load(fullfile(root,'data','fig2g_state_stats.mat'));  R = S.STV_R;
end
if nargin < 2 || isempty(paperRoot), paperRoot = fullfile(root,'paper'); end
addpath(fullfile(root,'utils'));
PS = paperStyle();

mkOrder = {'MOT','DPr','DPa'};                       % motion | rel-delta | abs-delta
% Axis names by frequency, not Greek band (Anna F2.7, 2026-10-29: "just say 2-4hz power instead
% of del ... what is relative vs absolute supposed to be"). The text gives frequencies, and
% "delta" invited "why not alpha?". The caption defines relative = fraction of 0.4-10 Hz power.
% The cached R.name strings still say \delta; they are not used for the panel.
en = char(8211);
% "Relative 2-4 Hz power" on one line ran into its neighbour at 6 pt, so the qualifier goes below.
xName = containers.Map(mkOrder, {{'Motion'}, {['2' en '4 Hz power'], '(relative)'}, ...
                                 {['2' en '4 Hz power'], '(absolute)'}});
idx = arrayfun(@(t) find(strcmpi({R.tag}, t{1}), 1), mkOrder, 'UniformOutput', false);
idx = [idx{:}];
if numel(idx) < 2, error('[2G] fewer than two of %s in R', strjoin(mkOrder,'/')); end
if ~isfield(R,'sdRawNs'), error('[2G] R.sdRawNs missing -- rerun imp_state_trialvar.m (2026-10-10 or later).'); end
if ~isfield(R,'sdPNs'),   error('[2G] R.sdPNs missing -- rerun imp_state_trialvar.m (2026-10-12 or later).'); end

wC = 7.0;            % 3 tiles sharing one y-axis; only the leftmost tile carries y ticks
fC = paperFig(wC, PS.f2h * 1.12);   % tiled layout crops tighter; extra height equalises A-E
tl = tiledlayout(fC, 1, numel(idx), 'TileSpacing','compact', 'Padding','compact');
axc = gobjects(numel(idx),1);
C_thin = [0.78 0.78 0.78];  C_mean = [0 0 0];  C_ctl = [0.30 0.30 0.30];
allC = [];
for m = 1:numel(idx)
    v = R(idx(m)).sdRawNs;                    allC = [allC v(isfinite(v)).']; %#ok<AGROW>
    v = mean(R(idx(m)).sdPNs, 1, 'omitnan');  allC = [allC v(isfinite(v))];  %#ok<AGROW>
end
yLimC = [floor(min(allC)*10)/10, ceil(max(allC)*10)/10];
for m = 1:numel(idx)
    r = R(idx(m));
    xb = r.binMed(:).';  Ys = r.sdRawNs;  yv = mean(Ys, 1, 'omitnan');
    ax = nexttile(tl);  hold(ax,'on');  axc(m) = ax;
    hR = yline(ax, 1, ':', 'Color',[.55 .55 .55], 'LineWidth', PS.lw_zero); hR.HandleVisibility='off';
    for ii = 1:size(Ys,1)
        plot(ax, xb, Ys(ii,:), '-o', 'Color', C_thin, 'MarkerFaceColor', C_thin, ...
             'MarkerEdgeColor','none', 'MarkerSize', 1.6, 'LineWidth', PS.lw_trial*1.5, 'HandleVisibility','off');
    end
    yc = mean(r.sdPNs, 1, 'omitnan');
    hC = plot(ax, xb, yc, '--o', 'Color', C_ctl, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', C_ctl, ...
              'LineWidth', PS.lw_mean*0.7, 'MarkerSize', 2.2);
    hS = plot(ax, xb, yv, '-o', 'Color', C_mean, 'MarkerFaceColor', C_mean, 'LineWidth', PS.lw_mean, 'MarkerSize', 2.5);
    if m == 2   % legend in the rel-delta tile: its lower half is empty
        lg = legend(ax, [hS hC], {'Stim','No stim'}, 'Location','south', 'Box','off', ...
                    'FontSize', PS.fs, 'FontWeight', PS.fw);
        lg.ItemTokenSize = [6 6];
    end
    xticks(ax, 0.125:0.25:0.875);  xticklabels(ax, {'Q1','Q2','Q3','Q4'});
    xtickangle(ax, 0);
    xlim(ax, [0 1]);  ylim(ax, yLimC);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, xName(r.tag), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    if m > 1, set(ax, 'YTickLabel', [], 'YTick', [], 'YColor', 'none'); end
    fprintf('[2G] %-16s session-mean Q4/Q1 %.2f | per session %s | no-stim control Q4/Q1 %.2f\n', ...
            r.tag, yv(end)/yv(1), mat2str(Ys(:,end)./Ys(:,1), 2), yc(end)/yc(1));
end
linkaxes(axc, 'y');  ylim(axc(1), yLimC);
ylabel(axc(1), {'Trial-to-trial variability','(\times session typical)'}, 'FontSize', PS.fs, 'FontWeight', PS.fw);
title(tl, 'State dependence of stimulation response', 'FontSize', PS.fs, 'FontWeight', PS.fw);
pdfDir = fullfile(paperRoot,'images','figure2');
if ~exist(pdfDir,'dir'), mkdir(pdfDir); end
jnAxesAll(fC);
paperExport(fC, fullfile(pdfDir, 'imp_state_var_combined.pdf'));
fprintf('[2G] combined state panel -> %s\n', fullfile(pdfDir, 'imp_state_var_combined.pdf'));
end
