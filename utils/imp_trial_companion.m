function C = imp_trial_companion(F2, whichState, sel, opts)
%IMP_TRIAL_COMPANION  Paper companion for the 2G/2H state scatters: ONE candidate trial,
%                     shown as actual response vs the amp-mean "prediction" + its state.
%
% THE JOB.  2G plots per-trial deviation-about-the-amplitude-mean vs MOTION; 2H plots the
% same deviation vs 2-4 Hz RELATIVE power. Each point is a trial reduced to two numbers.
% This panel de-abstracts one point: it shows the trial's ACTUAL dip trace against the
% amp-mean trace it is measured about (the "prediction against the trial average"), with
% the deviation shaded over the dip window, and beneath it the two state signals that place
% the trial on the scatter -- the raw motion trace ([-2,+0.5] s, MOT sums |z| over it) and
% the readout spectrum of the state window ([-1,+0.5] s, with the canonical 2-4 Hz band
% shaded). So a reader sees WHY this trial sits where it does on 2G and 2H at once.
%
% "prediction" here is the AMP-MEAN of the ACTUAL response (mean over trials at that
% amplitude), NOT the contra-Global of the row-4 residual analysis -- 2G/2H are the
% state-dependence of the raw trial average, so the template each trial deviates from is
% the trial average itself. (That is the one thing this differs from f2_inspector, which
% overlays the Global/Local decomposition instead.)
%
% USAGE
%   C = imp_trial_companion(F2)                      % auto-pick a MOTION exemplar, export
%   C = imp_trial_companion(F2, 'reldelta')          % auto-pick a rel-delta exemplar
%   C = imp_trial_companion(F2, 'motion', [s row])   % lock an explicit session s, trial-row
%   C = imp_trial_companion(F2, 'motion', [], struct('export',false))   % draw only
% Run `imp_fig2` once first so F2 is in the workspace. With no `sel`, the function prints a
% ranked table of candidate trials (session / amp / trial / state / deviation / dip / pre-err)
% so you can re-call with the [s row] you want as the locked paper example.
%
% INPUT
%   F2          per-session struct array from imp_fig2 (fields .label .D, D.ST with trA/MOT/DPr).
%   whichState  'motion' (2G companion) | 'reldelta' (2H companion).            [default 'motion']
%   sel         [] auto-pick; or [sessIdx trialRow] to force a specific trial.  [default []]
%   opts        .export  write the PDF                                          [default true]
%               .outdir  export folder                       [default paper/images/figure2]
%               .png     export PNG instead of PDF                              [default false]
%               .tag     filename suffix                                        [default '']
%               .topN    how many candidates to print/rank                      [default 10]
%               .statePct  state percentile floor for auto-pick (0-100)         [default 75]
%               .preMaxPct pre-error percentile ceiling for auto-pick           [default 60]
%
% OUTPUT
%   C  struct: .sess .row .amp .trial .label .stateVal .dev .dipMean .prePct .fig .file
% -------------------------------------------------------------------------------------------------
if nargin < 2 || isempty(whichState), whichState = 'motion'; end
if nargin < 3, sel = []; end
if nargin < 4, opts = struct(); end
def = struct('export',true,'outdir','','png',false,'tag','','topN',10, ...
             'statePct',75,'preMaxPct',60);
fn = fieldnames(def); for i=1:numel(fn), if ~isfield(opts,fn{i}), opts.(fn{i})=def.(fn{i}); end, end
if isempty(opts.outdir)
    here = fileparts(mfilename('fullpath'));  root = fileparts(here);
    opts.outdir = fullfile(root,'paper','images','figure2');
end

switch lower(whichState)
    case 'motion',   stField = 'MOT';  stName = 'motion (\Sigma|z|)';  stShort = 'motion';
    case {'reldelta','delta','reld'}, stField = 'DPr'; stName = 'rel 2-4 Hz power';  stShort = 'reldelta';
    otherwise, error('[COMPANION] whichState must be ''motion'' or ''reldelta''.');
end

PS = paperStyle();

% ---- gather every usable trial across sessions into one flat candidate table --------------------
Cand = struct('s',{},'row',{},'ai',{},'tj',{},'state',{},'dev',{},'dip',{},'pre',{});
for s = 1:numel(F2)
    if ~isfield(F2(s),'D') || isempty(F2(s).D), continue; end
    D = F2(s).D;  ST = D.ST;
    if ~isfield(ST,'trA') || isempty(ST.trA) || ~isfield(ST,stField), continue; end
    nRow = numel(ST.AMPi);
    ampOK = [];  if isfield(D,'ampOK'), ampOK = D.ampOK; end     % responding-amp mask if present
    for i = 1:nRow
        ai = ST.AMPi(i);  tj = ST.TRi(i);
        if ~isempty(ampOK) && ai <= numel(ampOK) && ~ampOK(ai), continue; end  % skip non-responding amps
        if ai > numel(ST.trA) || isempty(ST.trA{ai}) || tj > size(ST.trA{ai},2), continue; end
        stv = ST.(stField)(i);
        if ~isfinite(stv), continue; end
        dc = D.dcc{ai};  if isempty(dc), dc = (D.preN+1):size(ST.trA{ai},1); end
        A    = ST.trA{ai}(:,tj);
        Abar = mean(ST.trA{ai}, 2, 'omitnan');
        dev  = mean(A(dc),'omitnan') - mean(Abar(dc),'omitnan');   % signed dip deviation about the mean
        dip  = mean(Abar(dc),'omitnan');                            % amp-mean dip depth (<0 = inhibition)
        pre  = NaN;  if isfield(ST,'PRE'), pre = ST.PRE(i); end
        Cand(end+1) = struct('s',s,'row',i,'ai',ai,'tj',tj,'state',stv, ...
                             'dev',dev,'dip',dip,'pre',pre);   %#ok<AGROW>
    end
end
assert(~isempty(Cand), '[COMPANION] no usable trials in F2 (need D.ST.trA populated by imp_fig2).');

stAll  = [Cand.state];  preAll = [Cand.pre];  dipAll = [Cand.dip];
pctl   = @(v,x) 100*mean(v <= x,'omitnan');
stPc   = arrayfun(@(c) pctl(stAll, c.state), Cand);
prePc  = arrayfun(@(c) pctl(preAll(isfinite(preAll)), c.pre), Cand);

% ---- pick the trial -----------------------------------------------------------------------------
if ~isempty(sel)
    s0 = sel(1);  row0 = sel(2);
    ci = find([Cand.s]==s0 & [Cand.row]==row0, 1);
    assert(~isempty(ci), '[COMPANION] session %d trial-row %d is not a usable trial.', s0, row0);
else
    % HIGH-state, TRUSTWORTHY (low pre-error), CLEAN response (deep amp-mean dip). The exemplar is
    % the deepest-dip trial among those in the top state band and the trustworthy pre-error band, so
    % the panel shows a real response placed at the informative end of the scatter -- not an outlier
    % and not a baseline mis-fit. Bands relax if too few trials qualify.
    keep = stPc >= opts.statePct & (isnan(prePc) | prePc <= opts.preMaxPct);
    if nnz(keep) < 3, keep = stPc >= max(50, opts.statePct-25); end   % relax the state floor
    if nnz(keep) < 1, keep = true(size(Cand)); end
    idx = find(keep);
    [~,o] = sort(dipAll(idx));                       % most negative dip (deepest inhibition) first
    ci = idx(o(1));
    % print the ranked shortlist so the user can lock a different one
    fprintf('\n[COMPANION] %s candidates (high state, trustworthy, clean response) -- top %d:\n', ...
            stShort, min(opts.topN,numel(idx)));
    fprintf('   #  sess  amp#  trial   %-14s statePct  dev     dip     preErrPct\n', stName);
    for r = 1:min(opts.topN, numel(idx))
        c = Cand(idx(o(r)));
        fprintf('  %2d   s%d   %2d   %4d    %12.3f   %5.0f   %+6.3f  %+6.3f   %5.0f\n', ...
                r, c.s, c.ai, c.tj, c.state, stPc(idx(o(r))), c.dev, c.dip, prePc(idx(o(r))));
    end
    fprintf('  -> using #1 (s%d, trial-row %d); re-call imp_trial_companion(F2,''%s'',[%d %d]) to lock another.\n', ...
            Cand(ci).s, Cand(ci).row, stShort, Cand(ci).s, Cand(ci).row);
end

c  = Cand(ci);
s  = c.s;  ai = c.ai;  tj = c.tj;
D  = F2(s).D;  ST = D.ST;
Fs = D.Fs;  rel = D.rel(:);  tt = rel/Fs;
A    = ST.trA{ai}(:,tj);
Abar = mean(ST.trA{ai}, 2, 'omitnan');
dc   = D.dcc{ai};  if isempty(dc), dc = (D.preN+1):numel(rel); end
ion  = D.onFcell{ai}(tj);
lab  = F2(s).label;

% ---- draw: 3 stacked paper axes -----------------------------------------------------------------
fig = paperFig(4.6, 7.2);
tl  = tiledlayout(fig, 3, 1, 'TileSpacing','compact', 'Padding','compact');

% (1) actual vs amp-mean prediction, deviation shaded over the dip window ------------------------
ax1 = nexttile(tl, 1); hold(ax1,'on');
dcx = tt(dc);
fill(ax1, [dcx; flipud(dcx)], [A(dc); flipud(Abar(dc))], [.80 .30 .30], ...
     'FaceAlpha',0.20, 'EdgeColor','none', 'HandleVisibility','off');          % the deviation
xline(ax1, 0, 'k:', 'HandleVisibility','off', 'LineWidth', PS.lw_ref);
hM = plot(ax1, tt, Abar, '--', 'Color',[.45 .45 .45], 'LineWidth', PS.lw_fit);  % amp-mean = prediction
hA = plot(ax1, tt, A,    '-',  'Color',[.10 .10 .10], 'LineWidth', PS.lw_mean); % this trial
ylabel(ax1, '\DeltaF/F (%)', 'FontSize',PS.fs, 'FontWeight',PS.fw);
set(ax1, 'FontSize',PS.fs, 'FontWeight',PS.fw, 'TickDir','out', 'Box','off', 'XTickLabel',[]);
lg = legend(ax1, [hA hM], {'trial','amp-mean'}, 'Location','northeast', 'Box','off');
lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;
title(ax1, sprintf('%s, %.2f V, trial %d', lab, D.amps(ai), tj), ...
      'FontSize',PS.fs, 'FontWeight',PS.fw, 'Interpreter','none');

% (2) motion over the exact [-2,+0.5] s window --------------------------------------------------
ax2 = nexttile(tl, 2); hold(ax2,'on');
motPreN = round(2*Fs);  motPostN = round(0.5*Fs);
mw = (ion-motPreN):(ion+motPostN);
if ~isempty(D.motz) && mw(1) >= 1 && mw(end) <= numel(D.motz)
    ctx = round(1.0*Fs);
    cw  = max(1,mw(1)-ctx):min(numel(D.motz), mw(end)+ctx);
    plot(ax2, (cw-ion)/Fs, D.motz(cw), '-', 'Color',[.72 .72 .72], 'LineWidth',0.6);
    plot(ax2, (mw-ion)/Fs, D.motz(mw), '-', 'Color',[.15 .55 .20], 'LineWidth',PS.lw_fit);
    xline(ax2,0,'k:','LineWidth',PS.lw_ref);
    title(ax2, sprintf('motion   MOT = %.1f', ST.MOT(c.row)), ...
          'FontSize',PS.fs, 'FontWeight',PS.fw);
else
    text(ax2,0.5,0.5,'no motion trace','Units','normalized','HorizontalAlignment','center', ...
         'FontSize',PS.fs); axis(ax2,'off');
end
ylabel(ax2, 'motion (z)', 'FontSize',PS.fs, 'FontWeight',PS.fw);
set(ax2, 'FontSize',PS.fs, 'FontWeight',PS.fw, 'TickDir','out', 'Box','off', 'XTickLabel',[]);

% (3) spectrum of the [-1,+0.5] s state window, 2-4 Hz shaded ------------------------------------
ax3 = nexttile(tl, 3); hold(ax3,'on');
vd_preN = round(1*Fs);  vd_postN = round(0.5*Fs);
gp = (ion-vd_preN):(ion+vd_postN);
if gp(1) >= 1 && gp(end) <= D.nF
    sp = double(D.y_full(gp));
    nW = numel(sp);  w = hann(nW);  W = sum(w.^2);
    nfft = 2^nextpow2(nW);  fr = (0:nfft-1)'/nfft*Fs;  nB = floor(nfft/2)+1;
    Xf = fft(sp(:).*w, nfft);  pw = abs(Xf(1:nB)).^2 * 2/(Fs*W);
    fb = fr(1:nB);  keep = fb <= 10;                 % canonical rel-delta denom is 0.4-10 Hz
    ar = area(ax3, [2 4], [max(pw(keep)) max(pw(keep))], 'FaceColor',[1 .88 .70], ...
              'EdgeColor','none','HandleVisibility','off');  uistack(ar,'bottom');
    plot(ax3, fb(keep), pw(keep), '-', 'Color',[.25 .25 .25], 'LineWidth',PS.lw_fit);
    set(ax3,'YScale','log'); xlim(ax3,[0 10]);
    title(ax3, sprintf('rel 2-4 Hz = %.3f', ST.DPr(c.row)), ...
          'FontSize',PS.fs, 'FontWeight',PS.fw);
else
    text(ax3,0.5,0.5,'state window off-record','Units','normalized','HorizontalAlignment','center', ...
         'FontSize',PS.fs); axis(ax3,'off');
end
xlabel(ax3, 'Hz', 'FontSize',PS.fs, 'FontWeight',PS.fw);
ylabel(ax3, '(\DeltaF/F)^2 Hz^{-1}', 'FontSize',PS.fs, 'FontWeight',PS.fw);
set(ax3, 'FontSize',PS.fs, 'FontWeight',PS.fw, 'TickDir','out', 'Box','off');

% ---- export -------------------------------------------------------------------------------------
sfx = opts.tag;  if ~isempty(sfx) && sfx(1) ~= '_', sfx = ['_' sfx]; end
ext = '.pdf';  if opts.png, ext = '.png'; end
file = fullfile(opts.outdir, sprintf('imp_state_companion_%s%s%s', stShort, sfx, ext));
if opts.export
    if ~exist(opts.outdir,'dir'), mkdir(opts.outdir); end
    if opts.png, exportgraphics(fig, file, 'Resolution',300); else, paperExport(fig, file); end
    fprintf('[COMPANION] wrote %s  (s%d %.2f V trial %d | %s %.3f | dev %+.3f)\n', ...
            file, s, D.amps(ai), tj, stShort, c.state, c.dev);
end

C = struct('sess',s,'row',c.row,'amp',D.amps(ai),'trial',tj,'label',lab, ...
           'stateVal',c.state,'dev',c.dev,'dipMean',c.dip,'prePct',prePc(ci), ...
           'fig',fig,'file',file);
end
