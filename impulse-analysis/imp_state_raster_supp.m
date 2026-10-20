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
% Grayscale map (user 2026-10-16): black = negative, mid-grey = 0, white = positive.
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
% Activity starts RS_PRE s before onset (user 2026-10-16: "activity slightly prior to stim too, to
% show the effect of stim on activity"); the deviation column stays 0 .. +0.486 s.
if ~exist('RS_PRE','var') || isempty(RS_PRE), RS_PRE = 0.2; end
iA  = (iOn - round(RS_PRE*fs)) : (iOn + floor(STV_L2_WIN*fs - 1e-9));   % -0.2 .. +0.486 s
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
if ~isempty(RS_SESS), L = imp_mouse_label(allExperiments); labS = L{RS_SESS}; end

%% ---- figure -----------------------------------------------------------------------------------
PS   = paperStyle();
tags = {'MOT','DPr','DPa'};  names = {'Motion','Rel \delta','Abs \delta power'};
cm   = gray(256);                 % user 2026-10-16: grayscale (was purple-white-orange)
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

%% ---- Fig S2 ROW STRIPS: one vector PDF per state, to sit right of the quartile tiles ----------
% (user 2026-10-16: "figure 2 S2 should contain this too ... fit the pdf version of this png to the
% right with a demarcation saying pooled trials".) Each strip = the 3 heatmaps of one state, at the
% S2 tile height with the SAME axes band (bottom 0.27*H, height 0.55*H) as imp_state_quartile_supp,
% so heatmaps line up with the quartile tiles row by row. Pooled trials (all sessions).
% HEATMAP FIDELITY: exportgraphics' vector PDF resamples every image to the on-screen pixel size
% (1516 trials -> a 125 x 106 JPEG, tested 2026-10-16). So each heatmap is ALSO written as a
% native PNG (one pixel per trial x sample, colour-mapped, lossless) and utils/pdf_swap_images.py
% swaps it into the PDF in place -- vector axes/text, exact placement, every trial kept.
if ~exist('RS_ROWS','var') || isempty(RS_ROWS), RS_ROWS = false; end   % RETIRED 2026-10-16: pooled strip replaced by per-mouse strips (imp_state_raster_peramp.m)
if RS_ROWS && isempty(RS_SESS)
    J   = jnStyle();
    if ~exist('SQ_H','var') || isempty(SQ_H), SQ_H = 2.4; end
    rDir = fullfile(RS_OUT, 'state_quartile');                        % next to the S2 quartile tiles
    global PAPER_FINAL %#ok<GVMIS,TLEV>
    nDir = fullfile(rDir, '_native');  if ~exist(nDir,'dir'), mkdir(nDir); end
    tagF = {'mot','dpr','dpa'};
    colS = {'Activity', 'Deviation from mean'};
    % TWO columns, both signed, one grey scale (user 2026-10-16: "keep only activity and deviation
    % from av, not rms" -- no-stim control dropped from the strip; Fig S2 col B carries stim/control).
    % Running-RMS display was tried the same day and rejected (RESEARCH 2026-10-16).
    if ~exist('RS_ACLIM','var') || isempty(RS_ACLIM), RS_ACLIM = 2; end
    cmA = gray(256);
    W = 4.6;  H = SQ_H;  gp = 0.12;  x0 = 0.45;  pw = (W - x0 - gp - 0.1)/2;   % cm
    pyBin = 'python';
    swp = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'utils', 'pdf_swap_images.py');
    for k = 1:3
        st  = T.([tags{k} 'z']);
        idx = find(keep & isfinite(st));
        [stS, o] = sort(st(idx));  idx = idx(o);  nT = numel(idx);
        qEdge = arrayfun(@(p) find(stS >= quantile(stS,p), 1), [0.25 0.5 0.75]);
        qMid  = [1, qEdge, nT+1];  qMid = (qMid(1:end-1) + qMid(2:end))/2;
        panels = {X(idx,:), D(idx,:)};  tx = {tA, tL};
        f = jnFig(W, H);  pngs = cell(1,2);
        for j = 1:2
            M = panels{j};  cmj = cmA;  lim = [-1 1]*RS_ACLIM;
            ax = axes(f, 'Units','centimeters', 'Position', [x0+(j-1)*(pw+gp), 0.27*H, pw, 0.55*H]);
            imagesc(ax, tx{j}, 1:nT, M);  colormap(ax, cmj);  clim(ax, lim);  hold(ax,'on');
            % quartile boundaries: white core on a black casing, visible on any grey
            xq = tx{j}([1 end]) + [-0.5 0.5]*mean(diff(tx{j}));
            for q = qEdge
                plot(ax, xq, [q q], '-', 'Color', [0 0 0], 'LineWidth', 1.0);
                plot(ax, xq, [q q], '-', 'Color', [1 1 1], 'LineWidth', 0.4);
            end
            if tx{j}(1) < 0     % stimulus onset marker on the activity column
                plot(ax, [0 0] - 0.5*mean(diff(tx{j})), [0.5 nT+0.5], '--', 'Color', [1 1 1], 'LineWidth', 0.5);
            end
            set(ax, 'YDir','normal', 'Layer','top', 'YTick', qMid, 'YTickLabel', {'Q1','Q2','Q3','Q4'}, ...
                    'XTick', [0 0.2 0.4], 'XTickLabelRotation', 0);
            if j > 1, set(ax, 'YTickLabel', []); end
            % user 2026-10-16: x label ONCE (bottom row, centred under both columns); column titles
            % one line, 5 pt. Titles are text(), not title(): jnAxes/jnAxesAll force title() to 7 pt.
            jnAxes(ax);  set(ax, 'TickLength', [0.02 0.02]);
            if k == 3 && j == 1
                xl = xlabel(ax, 'Time (s)');  xl.Units = 'centimeters';
                xl.Position(1) = pw + gp/2;
            end
            if k == 1
                text(ax, mean(tx{j}), nT + 0.04*nT, colS{j}, 'HorizontalAlignment','center', ...
                     'VerticalAlignment','bottom', 'FontName', J.font, 'FontSize', 5, ...
                     'FontWeight','bold', 'Interpreter','none', 'Clipping','off');
            end
            % native heatmap: row 1 = lowest state at the BOTTOM (YDir normal) -> top PNG row = last trial
            ci  = round((min(max(M, lim(1)), lim(2)) - lim(1)) / diff(lim) * (size(cmj,1)-1)) + 1;
            ci(~isfinite(M)) = round(size(cmj,1)/2);
            rgb = ind2rgb(flipud(ci), cmj);
            pngs{j} = fullfile(nDir, sprintf('sq_%s_raster_%d.png', tagF{k}, j));
            imwrite(rgb, pngs{j});
        end
        pdfOut = fullfile(rDir, sprintf('sq_%s_raster.pdf', tagF{k}));
        jnExport(f, pdfOut);  close(f);
        targets = {pdfOut};
        fin = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'paper','figures_final','panels', ...
                       'supp_state_quartile', sprintf('sq_%s_raster.pdf', tagF{k}));
        if ~isempty(PAPER_FINAL) && PAPER_FINAL && exist(fin,'file'), targets{end+1} = fin; end %#ok<AGROW>
        for t = 1:numel(targets)
            cmd = sprintf('"%s" -I "%s" "%s" %s', pyBin, swp, targets{t}, strjoin(strcat('"', pngs, '"'), ' '));
            [rc, msg] = system(cmd);  fprintf('%s', msg);
            assert(rc == 0, '[RS] image swap failed for %s', targets{t});
        end
    end

    % ---- colour key (shared, place once) --------------------------------------------------------
    % User 2026-10-16: smaller, no long label -- just the end values. Units are dF/F divided by
    % the session's typical error, so ends read -3 / +3 with a short "norm. dF/F" (caption defines it);
    % a bare "3 dF/F" would read as 3 % dF/F, which these values are not.
    keys = {'sq_raster_cbar.pdf', cmA, [-1 1]*RS_ACLIM, {sprintf('-%g',RS_ACLIM), sprintf('+%g',RS_ACLIM)}, 'norm. ΔF/F'};
    for kk = 1:size(keys,1)
        f = jnFig(1.9, 0.55);
        axK = axes(f, 'Units','centimeters', 'Position', [0.25 0.35 1.4 0.001], 'Visible','off');
        colormap(axK, keys{kk,2});  clim(axK, keys{kk,3});
        cb = colorbar(axK, 'Location','south', 'Units','centimeters');
        cb.Position = [0.25 0.3 1.4 0.08];
        cb.Ticks = keys{kk,3};  cb.TickLabels = keys{kk,4};
        cb.TickLength = 0;  cb.Box = 'on';  cb.AxisLocation = 'in';  cb.LineWidth = 0.25;
        cb.Label.String = keys{kk,5};  cb.Label.Interpreter = 'none';
        set(cb, 'FontSize', 5, 'FontName', J.font);  cb.Label.FontSize = 5;
        jnExport(f, fullfile(rDir, keys{kk,1}));  close(f);
    end

    % ---- "Pooled trials" demarcation: header over the raster strip + vertical separator ---------
    f = jnFig(W, 0.6);
    ax = axes(f, 'Units','normalized', 'Position', [0 0 1 1]);  hold(ax,'on');  axis(ax, [0 W 0 0.6]);  axis(ax,'off');
    plot(ax, [x0 W-0.1], [0.12 0.12], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', J.lw_ref);
    plot(ax, [x0 x0], [0.12 0.22], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', J.lw_ref);
    plot(ax, [W-0.1 W-0.1], [0.12 0.22], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', J.lw_ref);
    text(ax, (x0+W-0.1)/2, 0.3, sprintf('Pooled trials (n = %d, all sessions)', nnz(keep)), ...
         'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'FontName', J.font, ...
         'FontSize', J.fs_label, 'FontWeight', 'bold', 'Interpreter','none');
    jnExport(f, fullfile(rDir, 'sq_pooled_header.pdf'));  close(f);

    f = jnFig(0.3, 3*SQ_H + 1.2);            % hairline separator, full S2 height; trim in Illustrator
    ax = axes(f, 'Units','normalized', 'Position', [0 0 1 1]);  axis(ax, [0 1 0 1]);  axis(ax,'off');  hold(ax,'on');
    plot(ax, [0.5 0.5], [0.01 0.99], '-', 'Color', [0.55 0.55 0.55], 'LineWidth', J.lw_ref);
    jnExport(f, fullfile(rDir, 'sq_divider.pdf'));  close(f);
end

function cm = local_puor(n)
% Diverging purple (negative) - white - orange (positive).
a = [0.33 0.15 0.53];  w = [1 1 1];  b = [0.70 0.35 0.02];
h = floor(n/2);
cm = [interp1([0 1], [a; w], linspace(0,1,h)); interp1([0 1], [w; b], linspace(0,1,n-h))];
end
