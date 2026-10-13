% IMP_STATE_RASTER_SUPP  Supplementary figure: trial rasters sorted by pre-stimulus state.
%
% (user, 2026-10-12) "sort trials and stack them vertically based on the state value, then plot
% their activity using color with time left to right; a second plot showing deviation from the
% trial average on the sorted trials and a third showing the control" -- 3 states x 3 views = 9.
%
%   rows    states: motion | rel delta (2-4 / 0.4-10 Hz) | abs delta (2-4 Hz), all over [-1, 0) s
%   col 1   ACTIVITY   x(t), onset-referenced dF/F, 0 to 0.49 s (user 2026-10-12: all three
%                      columns the same 0-0.5 s length; was -1.0 to +0.5 s, which also showed
%                      the pre-onset state window)
%   col 2   DEVIATION  x(t) - mu_amp(t), 0 to 0.49 s: what the Fig 2G L2 error integrates
%   col 3   CONTROL    c(t) - mu_ctrl(t) on the 18 stim-free samples -1.51 to -1.03 s (own first
%                      frame = 0), drawn on the same 0-0.49 s axis: the Fig 2G control
% Trials: all 1516 from imp_state_trialvar (STV_DV='l2'), rows asserted against T. Sorted by the
% within-session percentile T.<state>z (user 2026-10-12: Q1 = low state at the BOTTOM, Q4 at the top), so the four sessions interleave and
% each contributes ~1/4 of every quartile. Quartile boundaries are marked on the y axis.
% SCALE: every trial is divided by its session's response RMS L2 error (sqrt(mean e^2) over the
% session), so 1 = that session's typical error and sessions with small responses (Mouse 1a/1b,
% ~1-2 %dF/F) are not washed out by Mouse 2. The control uses the SAME divisor, so col 2 and col 3
% compare magnitudes directly. One symmetric colour scale (RS_CLIM) for all nine panels.
% Diverging purple-white-orange map (red/blue are locked to OL/CL conditions).
% Heatmaps -> 300-dpi PNG (CLAUDE.md export rule); not in MANIFEST until the user approves.
%
% RUN (base workspace, after load_experiments + imp_state_trialvar):
%   imp_state_raster_supp
%   RS_SESS = 3; imp_state_raster_supp      % one session only (3 = Mouse 2)
%   RS_SMOOTH = 5; imp_state_raster_supp    % running mean over N sorted rows, display only

if ~exist('RS_SESS','var'),   RS_SESS   = [];  end      % [] = all sessions pooled
if ~exist('RS_CLIM','var')   || isempty(RS_CLIM),   RS_CLIM   = 3;  end
if ~exist('RS_SMOOTH','var') || isempty(RS_SMOOTH), RS_SMOOTH = 1;  end
if ~exist('RS_OUT','var')    || isempty(RS_OUT)
    RS_OUT = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'paper','images','supplementary');
end
if ~exist(RS_OUT,'dir'), mkdir(RS_OUT); end
assert(exist('T','var')==1 && isfield(T,'DPaz'), '[RS] run imp_state_trialvar first');

%% ---- per-trial traces, same loop order as imp_state_trialvar ---------------------------------
iA  = iOn : (iOn + floor(STV_L2_WIN*fs - 1e-9));   % 0 .. +0.486 s, same span as cols 2-3
tA  = (iA - iOn) / fs;
iL  = iOn : iOn + floor(STV_L2_WIN*fs - 1e-9);                      % 18 samples, 0 .. 0.486 s
iC  = (iPow(1) - numel(iL)) : (iPow(1) - 1);                         % -1.514 .. -1.029 s
tL  = (0:numel(iL)-1) / fs;
X = []; D = []; C = []; eR = []; sS = [];
for e = 1:numel(allExperiments)
    imp = allExperiments(e).imp;
    for a = 1:numel(imp.uAmp)
        df = imp.dfImp{a};  pk = imp.Peak_imp{a}(:);
        if isempty(df) || isempty(pk), continue; end
        n = min([size(df,1), numel(pk), size(imp.motTrace{a},1)]);
        if n < 8, continue; end
        if STV_SKIP_AMP0 && imp.uAmp{a} == 0, continue; end
        df = df(1:n,:);
        x  = df(:, iL);  c = df(:, iC);  c = c - c(:,1);
        dv = x - mean(x,1,'omitnan');   dc = c - mean(c,1,'omitnan');
        X  = [X; df(:, iA)];  D = [D; dv];  C = [C; dc];                    %#ok<AGROW>
        eR = [eR; sqrt(mean(dv.^2, 2, 'omitnan'))];  sS = [sS; repmat(e,n,1)]; %#ok<AGROW>
    end
end
assert(isequal(sS, T.sess) && max(abs(eR - T.devRaw)) < 1e-9, '[RS] rows do not match T');

% session divisor = response RMS L2 error over the session
for s = unique(sS).'
    m = sS == s;  k = sqrt(mean(eR(m).^2, 'omitnan'));
    X(m,:) = X(m,:)/k;  D(m,:) = D(m,:)/k;  C(m,:) = C(m,:)/k;
end
keep = true(size(sS));  if ~isempty(RS_SESS), keep = sS == RS_SESS; end
labS = 'all sessions';
if ~isempty(RS_SESS), L = imp_mouse_label({allExperiments.mn}); labS = L{RS_SESS}; end

%% ---- figure -----------------------------------------------------------------------------------
PS   = paperStyle();
tags = {'MOT','DPr','DPa'};  names = {'Motion','Rel \delta','Abs \delta power'};
cm   = local_puor(256);
f    = paperFig(8, 14);    % user 2026-10-12: x squished (17 -> 11 -> 8 cm) so the 18-frame columns read less blocky
tl   = tiledlayout(f, 3, 3, 'TileSpacing','compact', 'Padding','compact');
colT = {'Activity','Deviation','No-stim control'};   % short: 11 cm wide (caption defines each)
for k = 1:3
    st = T.([tags{k} 'z']);
    idx = find(keep & isfinite(st));
    [stS, o] = sort(st(idx));  idx = idx(o);                 % row 1 = lowest state; YDir normal puts it at the bottom
    nT = numel(idx);
    qEdge = arrayfun(@(p) find(stS >= quantile(stS,p), 1), [0.25 0.5 0.75]);
    panels = {X(idx,:), D(idx,:), C(idx,:)};  tx = {tA, tL, tL};
    for j = 1:3
        M = panels{j};
        if RS_SMOOTH > 1, M = movmean(M, RS_SMOOTH, 1, 'omitnan'); end
        ax = nexttile(tl);
        imagesc(ax, tx{j}, 1:nT, M);  colormap(ax, cm);  clim(ax, [-1 1]*RS_CLIM);
        hold(ax,'on');
        for q = qEdge, yline(ax, q, '-', 'Color', [0 0 0], 'LineWidth', 0.4); end
        qMid = [1, qEdge, nT+1];  qMid = (qMid(1:end-1) + qMid(2:end))/2;
        set(ax, 'YTick', qMid, 'YTickLabel', {'Q1','Q2','Q3','Q4'}, 'TickDir','out', 'Box','off', ...
                'FontSize', PS.fs, 'FontWeight', PS.fw, 'Layer','top', 'YDir','normal');
        if j > 1, set(ax, 'YTickLabel', []); end
        if j == 1, ylabel(ax, {names{k}, 'trials sorted by state'}, 'FontSize', PS.fs, 'FontWeight', PS.fw); end
        if k == 1, title(ax, colT{j}, 'FontSize', PS.fs, 'FontWeight', PS.fw); end
        if k == 3
            if j == 3, xlabel(ax, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
            else,      xlabel(ax, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw); end
        else
            set(ax, 'XTickLabel', []);
        end
    end
end
% Short, thin, centred colour key (user 2026-10-12: "shorter color bar, make it look stylish").
% A tile-assigned colorbar always spans the whole layout, so the key hangs off a hidden helper
% axes below the grid instead, and is positioned by hand.
tl.OuterPosition = [0 0.075 1 0.925];                  % leave a strip under the grid
axK = axes(f, 'Position', [0.35 0.02 0.30 0.001], 'Visible','off');
colormap(axK, cm);  clim(axK, [-1 1]*RS_CLIM);
cb = colorbar(axK, 'Location','south');
cb.Position     = [0.33 0.045 0.34 0.008];             % ~1/3 of the width, hairline-thin
cb.Ticks        = [-RS_CLIM 0 RS_CLIM];
cb.TickLabels   = {sprintf('-%g',RS_CLIM), '0', sprintf('+%g',RS_CLIM)};
cb.TickLength   = 0;  cb.Box = 'off';  cb.AxisLocation = 'in';   % ticks + label BELOW the strip (for a 'south' key, 'out' points up into the grid)
cb.Label.String = '\DeltaF/F (\times session typical error)';
set(cb, 'FontSize', PS.fs, 'FontWeight', PS.fw);
title(tl, sprintf('Trials sorted by pre-stimulus state (n = %d)', nnz(keep)), ...
      'FontSize', PS.fs, 'FontWeight', PS.fw);
jnAxesAll(f);
sfx = '';  if ~isempty(RS_SESS), sfx = sprintf('_s%d', RS_SESS); end
out = fullfile(RS_OUT, ['supp_state_raster' sfx '.png']);
paperExport(f, out, 300);   % 300-dpi PNG (heatmap rule); mirrors to figures_final if in MANIFEST
fprintf('[RS] %s (%d trials, clim +/-%g, smooth %d) -> %s\n', labS, nnz(keep), RS_CLIM, RS_SMOOTH, out);

function cm = local_puor(n)
% Diverging purple (negative) - white - orange (positive).
a = [0.33 0.15 0.53];  w = [1 1 1];  b = [0.70 0.35 0.02];
h = floor(n/2);
cm = [interp1([0 1], [a; w], linspace(0,1,h)); interp1([0 1], [w; b], linspace(0,1,n-h))];
end
