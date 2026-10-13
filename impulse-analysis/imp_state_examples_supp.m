% IMP_STATE_EXAMPLES_SUPP  Supplementary figure: single-trial view of the Fig 2G state effect.
%
% Fig 2G says the trial-to-trial error of the impulse response grows with pre-stimulus state
% (motion, rel delta, abs delta quartiles) AND that a stimulus-free control tracks it -- i.e. a
% fixed stimulus effect riding on state-dependent ongoing activity. This producer shows what that
% looks like on single trials: the trial, the mean at its amplitude, and the same trial's
% no-stim control segment.
%
% DV (identical to imp_state_trialvar, STV_DV='l2'; asserted row-by-row against T below):
%   e      = sqrt( mean_t (x(t) - mu_amp(t))^2 ),  t in [0, 0.5) s  (18 samples at 35 Hz)
%            x = onset-referenced dF/F (col iOn == 0), mu_amp = trial mean at that amplitude
%   e_ctrl = same statistic on cols iPow(1)-18 : iPow(1)-1 (-1.514 to -1.029 s), each segment
%            referenced to its own first frame; the 18 samples end one frame before the state window.
%   Amp-0 levels and levels with < 8 trials are skipped (same as T). Amplitude mW = V/3.
%
% STATE BINS: Fig 2G's own bins -- equal-count quartiles (local_qbin) of the within-session
% percentile T.<state>z, pooled. Because the percentile is within-session, each session
% contributes ~1/4 of its trials to every quartile.
%
% TRIAL SELECTION (deterministic, no RNG):
%   * "Typical" trial (layouts A, B): in each session x quartile cell, the trial whose e is
%     closest to that cell's RMS e = sqrt(mean(e^2)) -- the quantity Fig 2G plots per bin.
%     Ties -> lowest row of T.
%   * Spread overlay (layout C): in each cell, the 5 trials at the 10/30/50/70/90th percentile
%     ranks of e (rank = round(p*(n-1))+1 of the sorted e), so the overlay samples the cell's
%     whole distribution rather than its tail.
%
% LAYOUTS (SUPP_LAYOUT, any subset of {'A','B','C'}):
%   A  abs delta only: 4 sessions x Q1..Q4, one typical trial per cell (trace view).
%   B  compact: 3 states x {Q1, Q4}, one session (SUPP_SESS), typical trial + its control.
%   C  residual overlay: 3 states x {response, control}, one session, 5 trials each for Q1 and Q4,
%      plotted as x - mu_amp (response) and c - mu_ctrl (control) on the same 0-0.5 s axis.
%
% COLOURS: quartile = purple lightness ramp (Q1 light -> Q4 dark) for the stimulated trial; the
% no-stim control is grey; the amplitude mean is black dashed. Red/blue/orange/green are NOT used
% (locked to OL / CL / OL+p / CL+p controller conditions).
%
% RUN (base workspace, after load_experiments + imp_state_trialvar with STV_DV='l2'):
%   SUPP_LAYOUT = {'A','B','C'}; imp_state_examples_supp
%   SUPP_PNG_DIR = '<dir>';  % optional: also write 300-dpi PNGs there (workshop copies)
% Writes vector PDFs to paper/images/supplementary/. Not in MANIFEST.txt: nothing is mirrored
% into figures_final until the panel is approved and listed.

%% [SUPP-0] knobs + inputs -------------------------------------------------------------------
if ~exist('SUPP_LAYOUT','var')  || isempty(SUPP_LAYOUT),  SUPP_LAYOUT  = {'A','B','C'}; end
if ~exist('SUPP_SESS','var')    || isempty(SUPP_SESS),    SUPP_SESS    = 3;  end   % Mouse 2 (AL_0033): most trials
if ~exist('SUPP_PNG_DIR','var'),                          SUPP_PNG_DIR = '';  end
if ~exist('SUPP_DISP','var')    || isempty(SUPP_DISP),    SUPP_DISP    = [-0.3 0.6]; end   % display window (s)
if ischar(SUPP_LAYOUT), SUPP_LAYOUT = {SUPP_LAYOUT}; end
assert(exist('T','var') && exist('allExperiments','var') && exist('iOn','var'), ...
    '[SUPP] run load_experiments + imp_state_trialvar (STV_DV=''l2'') first');
assert(strcmpi(STV_DV,'l2'), '[SUPP] T was built with STV_DV=''%s''; this figure needs ''l2''', STV_DV);
if ~exist('STV_REREF_ONSET','var') || isempty(STV_REREF_ONSET), STV_REREF_ONSET = true; end

PS      = paperStyle();
supRoot = fileparts(fileparts(mfilename('fullpath')));
supDir  = fullfile(supRoot, 'paper', 'images', 'supplementary');
if ~exist(supDir, 'dir'), mkdir(supDir); end

%% [SUPP-1] rebuild per-trial traces in T's row order ----------------------------------------
% Same loop + skips as imp_state_trialvar, so row r here is row r of T (asserted below).
nL   = 18;                                                  % [0, 0.5) s at 35 Hz
iL2s = iOn : iOn + nL - 1;
iSh  = (iPow(1) - nL) : (iPow(1) - 1);                      % no-stim control, cols 53:70
iW   = (iOn + round(SUPP_DISP(1)*fs)) : (iOn + round(SUPP_DISP(2)*fs));
tW   = (iW - iOn) / fs;
tL   = (0:nL-1) / fs;                                       % control drawn on the 0-0.5 s axis
X = []; M = []; C = []; Cm = []; A = []; sS = [];
for e = 1:numel(allExperiments)
    imp = allExperiments(e).imp;
    for a = 1:numel(imp.uAmp)
        df = imp.dfImp{a};  pk = imp.Peak_imp{a}(:);
        if isempty(df) || isempty(pk), continue; end
        n = min([size(df,1), numel(pk), size(imp.motTrace{a},1)]);
        if n < 8, continue; end
        if STV_SKIP_AMP0 && imp.uAmp{a} == 0, continue; end
        df = df(1:n, :);
        if STV_REREF_ONSET && ~all(df(:,iOn) == 0 | isnan(df(:,iOn)))
            df = df - df(:, iOn);                           % AL_0048: onset reference, as in T
        end
        x = df(:, iW);
        c = df(:, iSh) - df(:, iSh(1));                     % control: own first frame = 0
        X  = [X;  x];                                  %#ok<AGROW>
        M  = [M;  repmat(mean(x,1,'omitnan'), n, 1)];  %#ok<AGROW>
        C  = [C;  c];                                  %#ok<AGROW>
        Cm = [Cm; repmat(mean(c,1,'omitnan'), n, 1)];  %#ok<AGROW>
        A  = [A;  repmat(imp.uAmp{a}/3, n, 1)];        %#ok<AGROW>  V -> mW
        sS = [sS; repmat(e, n, 1)];                    %#ok<AGROW>
    end
end
inL = ismember(iW, iL2s);
eR  = sqrt(mean((X(:,inL) - M(:,inL)).^2, 2, 'omitnan'));
eC  = sqrt(mean((C - Cm).^2, 2, 'omitnan'));
assert(isequal(sS, T.sess), '[SUPP] row order does not match T');
assert(max(abs(eR - T.devRaw)) < 1e-9 && max(abs(eC - T.shmRaw)) < 1e-9, ...
    '[SUPP] recomputed L2 does not match T.devRaw / T.shmRaw');
fprintf('[SUPP] %d trials; e and e_ctrl match T exactly; control %.3f..%.3f s\n', ...
    numel(eR), (iSh(1)-iOn)/fs, (iSh(end)-iOn)/fs);

uS   = unique(sS).';
labF = imp_mouse_label({allExperiments.mn});
stTag  = {'MOT', 'DPr', 'DPa'};
stName = {'Motion', 'Rel. \delta power', 'Abs. \delta power'};
G = zeros(numel(eR), 3);                                    % Fig 2G quartile per trial per state
for k = 1:3
    z = T.([stTag{k} 'z']);  ok = isfinite(z);
    q = quantile(z(ok), linspace(0,1,5));  q(1) = -inf;  q(end) = inf;
    [~,~,g] = histcounts(z, q);  g(~ok) = 0;  G(:,k) = g;
end

% quartile colours: purple lightness ramp (not a controller-condition colour)
colQ  = interp1([1 4], [0.66 0.55 0.82; 0.30 0.05 0.45], 1:4);
colC  = [0.55 0.55 0.55];                                   % no-stim control
colC1 = [0.68 0.68 0.68];                                   % control, Q1 (C overlay)
colM  = [0 0 0];                                            % amplitude mean
colW  = [0.94 0.94 0.94];                                   % 0-0.5 s error window

% deterministic pickers
pickTyp = @(m) m(find(abs(eR(m) - sqrt(mean(eR(m).^2))) == min(abs(eR(m) - sqrt(mean(eR(m).^2)))), 1));
pickSpr = @(m) local_spread_pick(m, eR(m), [.1 .3 .5 .7 .9]);

%% [SUPP-A] abs delta: 4 sessions x Q1..Q4, typical trial per cell ----------------------------
if any(strcmpi(SUPP_LAYOUT, 'A'))
    k = 3;  nS = numel(uS);
    fig = paperFig(16.5, 2.55*nS + 1.7);
    tl  = tiledlayout(fig, nS, 4, 'TileSpacing','compact', 'Padding','compact');
    axs = gobjects(nS, 4);
    for ii = 1:nS
        for b = 1:4
            m  = find(sS == uS(ii) & G(:,k) == b);
            r  = pickTyp(m);  eRms = sqrt(mean(eR(m).^2));  cRms = sqrt(mean(eC(m).^2));
            ax = nexttile(tl);  axs(ii,b) = ax;
            local_trial_panel(ax, tW, tL, X(r,:), M(r,:), C(r,:), colQ(b,:), colC, colM, colW, PS);
            local_note(ax, sprintf('%.2f mW\ne %.2f (cell %.2f)\ne_{ctrl} %.2f (cell %.2f)', ...
                A(r), eR(r), eRms, eC(r), cRms));
            if ii == 1, title(ax, sprintf('Abs. \\delta Q%d', b)); end
            if b == 1, ylabel(ax, {labF{uS(ii)}, '\DeltaF/F (%)'}); else, ax.YTickLabel = []; end
            if ii == nS, xlabel(ax, 'Time from onset (s)'); else, ax.XTickLabel = []; end
        end
        local_share_y(axs(ii,:), 0.42);
    end
    local_legend(axs(1,1), colQ(1,:), colC, colM, PS);
    local_export(fig, supDir, SUPP_PNG_DIR, 'supp_state_examples_optA');
end

%% [SUPP-B] compact: 3 states x {Q1, Q4}, one session, typical trial --------------------------
if any(strcmpi(SUPP_LAYOUT, 'B'))
    fig = paperFig(11.6, 9.6);
    tl  = tiledlayout(fig, 3, 2, 'TileSpacing','compact', 'Padding','compact');
    axs = gobjects(3, 2);  bb = [1 4];
    for k = 1:3
        for j = 1:2
            b  = bb(j);
            m  = find(sS == SUPP_SESS & G(:,k) == b);
            r  = pickTyp(m);  eRms = sqrt(mean(eR(m).^2));  cRms = sqrt(mean(eC(m).^2));
            ax = nexttile(tl);  axs(k,j) = ax;
            local_trial_panel(ax, tW, tL, X(r,:), M(r,:), C(r,:), colQ(b,:), colC, colM, colW, PS);
            local_note(ax, sprintf('%.2f mW\ne %.2f (cell %.2f)\ne_{ctrl} %.2f (cell %.2f)', ...
                A(r), eR(r), eRms, eC(r), cRms));
            if k == 1, title(ax, sprintf('Q%d (%s state)', b, local_tern(j==1,'low','high'))); end
            if j == 1, ylabel(ax, {stName{k}, '\DeltaF/F (%)'}); else, ax.YTickLabel = []; end
            if k == 3, xlabel(ax, 'Time from onset (s)'); else, ax.XTickLabel = []; end
        end
    end
    local_share_y(axs(:), 0.40);
    title(tl, labF{SUPP_SESS}, 'FontName','Arial', 'FontSize',7, 'FontWeight','bold');
    local_legend(axs(1,1), colQ(1,:), colC, colM, PS);
    local_export(fig, supDir, SUPP_PNG_DIR, 'supp_state_examples_optB');
end

%% [SUPP-C] residual overlay: 3 states x {response, control}, Q1 vs Q4 -----------------------
% Plots the DV's integrand directly: x - mu_amp (response) and c - mu_ctrl (control) over the
% 18 samples. If the stimulus adds a fixed effect on top of ongoing activity, the two columns
% should look alike and both should widen from Q1 to Q4.
if any(strcmpi(SUPP_LAYOUT, 'C'))
    fig = paperFig(11.6, 9.0);
    tl  = tiledlayout(fig, 3, 2, 'TileSpacing','compact', 'Padding','compact');
    axs = gobjects(3, 2);
    for k = 1:3
        for j = 1:2
            ax = nexttile(tl);  axs(k,j) = ax;  hold(ax, 'on');
            yline(ax, 0, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', PS.lw_zero);
            txt = cell(1, 2);
            for bq = [1 4]
                m  = find(sS == SUPP_SESS & G(:,k) == bq);
                rr = pickSpr(m);
                if j == 1
                    Y = X(rr, inL) - M(rr, inL);   cc = colQ(bq,:);  v = eR(m);
                else
                    Y = C(rr, :)   - Cm(rr, :);    cc = local_tern(bq==1, colC1, colC*0.55);  v = eC(m);
                end
                plot(ax, tL, Y.', '-', 'Color', cc, 'LineWidth', PS.lw_trial + 0.2);
                txt{1 + (bq==4)} = sprintf('\\color[rgb]{%.2f %.2f %.2f}Q%d RMS %.2f', cc, bq, sqrt(mean(v.^2)));
            end
            local_note(ax, strjoin(txt, newline));
            xlim(ax, [0 tL(end)]);
            if k == 1, title(ax, local_tern(j==1, 'Response: x - \mu_{amp}', 'No-stim control: c - \mu_{ctrl}')); end
            if j == 1, ylabel(ax, {stName{k}, 'Residual \DeltaF/F (%)'}); else, ax.YTickLabel = []; end
            if k == 3, xlabel(ax, local_tern(j==1, 'Time from onset (s)', 'Time in segment (s)')); else, ax.XTickLabel = []; end
        end
    end
    local_share_y(axs(:), 0.30, true);
    title(tl, sprintf('%s: 5 trials per quartile (10-90th pct of e)', labF{SUPP_SESS}), ...
        'FontName','Arial', 'FontSize',7, 'FontWeight','bold');
    local_export(fig, supDir, SUPP_PNG_DIR, 'supp_state_examples_optC');
end

%% ===== local functions =======================================================================
function r = local_spread_pick(m, v, p)
[~, o] = sort(v);  n = numel(v);
r = m(o(round(p*(n-1)) + 1));
end

function local_trial_panel(ax, tW, tL, x, mu, c, colT, colC, colM, colW, PS)
hold(ax, 'on');
patch(ax, [0 0.5 0.5 0], [-1e3 -1e3 1e3 1e3], colW, 'EdgeColor','none', 'HandleVisibility','off');
yline(ax, 0, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
plot(ax, tL, c,  '-',  'Color', colC, 'LineWidth', PS.lw_inp,  'Tag','ctrl');
plot(ax, tW, mu, '--', 'Color', colM, 'LineWidth', PS.lw_ref,  'Tag','mean');
plot(ax, tW, x,  '-',  'Color', colT, 'LineWidth', PS.lw_mean, 'Tag','trial');
xlim(ax, [tW(1) tW(end)]);  xticks(ax, [0 0.5]);
end

function local_note(ax, s)
text(ax, 0.98, 0.98, s, 'Units','normalized', 'HorizontalAlignment','right', ...
    'VerticalAlignment','top', 'FontName','Arial', 'FontSize',5.5, 'FontWeight','normal', ...
    'Interpreter','tex', 'Margin',0.5);
end

function local_share_y(axs, headroom, symmetric)
% shared limits over the plotted traces, with top headroom for the in-panel note
if nargin < 3, symmetric = false; end
v = [];
for ax = axs(:).'
    h = findobj(ax, 'Type','line');
    for hh = h(:).', v = [v, hh.YData]; end %#ok<AGROW>
end
v = v(isfinite(v));  lo = min(v);  hi = max(v);
if symmetric, lo = -max(abs([lo hi])); hi = -lo; end
span = hi - lo;
set(axs, 'YLim', [lo - 0.04*span, hi + headroom*span/(1-headroom)]);
end

function local_legend(ax, colT, colC, colM, PS)
h = [plot(ax, nan, nan, '-',  'Color', colT, 'LineWidth', PS.lw_mean), ...
     plot(ax, nan, nan, '--', 'Color', colM, 'LineWidth', PS.lw_ref), ...
     plot(ax, nan, nan, '-',  'Color', colC, 'LineWidth', PS.lw_inp)];
lg = legend(ax, h, {'Trial (light Q1 \rightarrow dark Q4)', 'Mean at that amplitude', ...
    'Same trial, no-stim control (-1.51 to -1.03 s)'}, ...
    'Orientation','horizontal', 'Box','off', 'FontName','Arial', 'FontSize',6, 'FontWeight','normal');
lg.ItemTokenSize = PS.lgd_token;
lg.Layout.Tile = 'south';          % outside the panels: never covers a trace
end

function local_export(fig, supDir, pngDir, name)
jnAxesAll(fig);
paperExport(fig, fullfile(supDir, [name '.pdf']));
if ~isempty(pngDir), paperExport(fig, fullfile(pngDir, [name '.png']), 300); end
end

function s = local_tern(c, a, b)
if c, s = a; else, s = b; end
end
