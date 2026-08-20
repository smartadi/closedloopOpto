%% state_quartile_panels.m -- OL/CL trial RMSE vs brain-state quartile, motion-clean trials
%
% The state-variable twin of the motion-quartile panel (motion_analysis.m,
% `motion_quartile_combined`): same pooled-quartile errorbar layout, same OL/CL pair,
% but the x-axis is a PRE-STIMULUS BRAIN STATE, and high-motion trials are thrown out
% first so motion cannot be doing the work.
%
%   MOT    motion                 mean z-motion, onset-2 s .. trial end -- drawn on ALL
%                                 trials, NOT the clean subset (see NOTE below)
%   PVv    pre-stimulus variance  var(dF/F) over [-PRE_S, 0) s
%   D14    relative 1-4 Hz        P(1-4)  / P(0.4-10)  over the same window
%   D12    relative 1-2 Hz        P(1-2)  / P(0.4-10)   <- the slow sub-band
%   D24    relative 2-4 Hz        P(2-4)  / P(0.4-10)   <- the hard-to-control sub-band
%                                 (the 1-2 / 2-4 split matches figure4's delta12/delta24)
%
% Plus, per state, an EXEMPLAR figure: four real trials from the bottom bin and four from
% the top bin, OL row and CL row, so the quartile means can be read against actual traces.
%
% MOTION REMOVAL: |mean z-motion over (onset-2 s .. trial end)| <= 1.5, the project-wide
% motThresh (root CLAUDE.md). Same rule as controller-analysis/trial_state_mse.m so the
% two are directly comparable. It applies to the BRAIN-STATE panels only.
% NOTE (user, 2026-08-19): the motion panel must NOT use the clean subset -- binning motion
% inside a set the same motion threshold already truncated is circular, and its "Q4" would
% be the most movement among quiet trials rather than the high-motion tail. So the motion
% panel and its exemplars are drawn on ALL trials, and only the state panels are cleaned.
% Each panel's filename and x-label say which set it used.
%
% CAVEAT worth saying out loud on a slide: pre-stimulus VARIANCE is the state that was
% retracted 2026-07-02 in the impulse stream as a signal-power confound (variance is the
% denominator of the metric it was scored against). That argument does NOT transfer
% one-for-one here -- trial RMSE is an absolute error in %dF/F, not a normalised R^2 --
% but a session whose ongoing signal is simply larger shows both a larger pre-trial
% variance and a larger tracking error, so the positive OL slope is partly a level effect.
% The relative-delta measures are POWER RATIOS and carry the cleaner claim.
%
% Lean by construction: reads only the small `data` struct from each controller cache
% (never `d`/SVD), one session at a time. m1..m13; the two 2026-07-29 mice are out.
% Only 9 of the 13 have a motion trace at all, so every panel here is n=9 sessions.
%
% Output: PNG only (not paper panels) -> talk/figure4/
% Requested by the user 2026-08-19 for the NeuroAI deck.

% cd/addpath survive load_sessions' `clearvars`; VARIABLES set before it do not.
cd('C:\Users\aditya\Documents\projects\brain_paper');
addpath(genpath(fullfile(pwd,'utils')));
addpath(fullfile(pwd,'controller-analysis'));

r_lean = 1;                 % registry only -- also wipes the workspace, so set nothing above
load_sessions;

root  = 'C:\Users\aditya\Documents\projects\brain_paper';
PS    = paperStyle(); setPaperDefaults();
outDir = fullfile(root,'talk','figure4');
if ~isfolder(outDir); mkdir(outDir); end

Fs        = 35;
dur       = 3;
NKEEP     = 13;             % m1..m13
motThresh = 1.5;
PRE_S     = 2;              % pre-onset state window (s)
nBins     = 4;
nEx       = 4;              % exemplar trials drawn per bin per condition
REF       = -5;
c0_l      = 3*Fs + 1;       % onset column in pncDfk_l (= 106)
preA      = c0_l - round(PRE_S*Fs);
preB      = c0_l - 1;
t_l       = (-3*Fs : Fs*(dur+3)) / Fs;   % pncDfk_l time axis, -3 .. dur+3 s

fields = fields(1:min(NKEEP,numel(fields)));
nS     = numel(fields);

% ---- gather, one session at a time --------------------------------------
Xo = []; Xc = [];           % nTrials x nStates
% must be seeded LOGICAL: [[]; true] resolves to double, and a double 0/1 mask then fails
% as a subscript ("indices must be positive integers or logical") on the first clean panel.
Ko = false(0,1); Kc = false(0,1);   % motion-clean mask, carried alongside rather than applied
Yo = []; Yc = [];           % trial RMSE
Po = []; Pc = [];           % trial traces (for the exemplar figures)
So = []; Sc = [];           % session index
nTot=0; nDrop=0; nUsed=0;
for k = 1:nS
    mn = mouse.(fields{k}).mn; td = mouse.(fields{k}).td; en = mouse.(fields{k}).en;
    pc = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    if ~isfile(pc); fprintf('  skip %-5s no cache\n', fields{k}); continue; end
    T = load(pc,'data'); D = T.data; clear T

    if ~isfield(D,'ncmotion') || ~any(D.ncmotion(:))
        fprintf('  skip %-5s %-8s %s  (no motion trace)\n', fields{k}, mn, td);
        clear D; continue
    end

    pnc = D.pncDfk(:, 246:end);   pwc = D.pwcDfk(:, 246:end);   % pncDfk_l: 3 s pre .. dur+3 s
    yo  = D.er_ncDfk(:);          yc  = D.er_wcDfk(:);

    % motion over (onset - 2 s) .. trial end, in the stored motion window
    nmc = size(D.ncmotion,2); ons = nmc - Fs*dur;
    wa = max(1, ons - round(2*Fs)); wb = min(nmc, ons + dur*Fs);
    mo = mean(D.ncmotion(:, wa:wb), 2);   mc = mean(D.wcmotion(:, wa:wb), 2);

    no = min([size(pnc,1) numel(yo) numel(mo)]);
    nc = min([size(pwc,1) numel(yc) numel(mc)]);
    pnc=pnc(1:no,:); yo=yo(1:no); mo=mo(1:no);
    pwc=pwc(1:nc,:); yc=yc(1:nc); mc=mc(1:nc);

    ko = abs(mo) <= motThresh;   kc = abs(mc) <= motThresh;
    nTot  = nTot + no + nc;
    nDrop = nDrop + sum(~ko) + sum(~kc);

    so = pnc(:, preA:preB);      sc = pwc(:, preA:preB);
    xo_k = [mo, var(so,0,2), relBand(so,Fs,1,4), relBand(so,Fs,1,2), relBand(so,Fs,2,4)];
    xc_k = [mc, var(sc,0,2), relBand(sc,Fs,1,4), relBand(sc,Fs,1,2), relBand(sc,Fs,2,4)];

    % Every finite trial is kept in the pool; the motion cut travels alongside as a MASK
    % (KEEPo/KEEPc) instead of being applied here. Reason: binning motion inside a set the
    % same motion threshold already truncated is circular -- its "Q4" is the most movement
    % among quiet trials (user, 2026-08-19). So the motion panel uses the FULL range and
    % only the brain-state panels use the clean subset.
    g_o = all(isfinite(xo_k),2) & isfinite(yo);
    g_c = all(isfinite(xc_k),2) & isfinite(yc);
    if sum(g_o) < 10 || sum(g_c) < 10
        fprintf('  skip %-5s %-8s %s  (only %d/%d usable trials)\n', ...
                fields{k}, mn, td, sum(g_o), sum(g_c));
        clear D pnc pwc so sc; continue
    end

    Xo=[Xo; xo_k(g_o,:)]; Xc=[Xc; xc_k(g_c,:)];      %#ok<AGROW>
    Yo=[Yo; yo(g_o)];     Yc=[Yc; yc(g_c)];          %#ok<AGROW>
    Po=[Po; pnc(g_o,:)];  Pc=[Pc; pwc(g_c,:)];       %#ok<AGROW>
    So=[So; k*ones(sum(g_o),1)];                     %#ok<AGROW>
    Sc=[Sc; k*ones(sum(g_c),1)];                     %#ok<AGROW>
    Ko=[Ko; ko(g_o)];     Kc=[Kc; kc(g_c)];          %#ok<AGROW>
    nUsed = nUsed + 1;
    fprintf('  %-5s %-8s %s e%d  OL %3d (%3d clean)  CL %3d (%3d clean)\n', ...
            fields{k}, mn, td, en, sum(g_o), sum(ko(g_o)), sum(g_c), sum(kc(g_c)));
    clear D pnc pwc so sc
end
fprintf('[SQ] %d sessions | pooled OL %d / CL %d | motion-clean OL %d / CL %d (%.1f%% cut)\n', ...
        nUsed, numel(Yo), numel(Yc), sum(Ko), sum(Kc), 100*nDrop/max(nTot,1));

% clean = false -> panel drawn on ALL trials (motion, whose own threshold defines the cut)
ST(1) = struct('key','motion', 'xlab','Motion quartile',                'ex',true,  'clean',false);
ST(2) = struct('key','prevar', 'xlab','Pre-stimulus variance quartile', 'ex',false, 'clean',true);
ST(3) = struct('key','delta',  'xlab','Relative 1-4 Hz quartile',       'ex',true,  'clean',true);
ST(4) = struct('key','delta12','xlab','Relative 1-2 Hz quartile',       'ex',false, 'clean',true);
ST(5) = struct('key','delta24','xlab','Relative 2-4 Hz quartile',       'ex',true,  'clean',true);

%% ---- one quartile panel per state ---------------------------------------
for si = 1:numel(ST)
    if ST(si).clean
        mo_ = Ko; mc_ = Kc; setLbl = 'motion-clean trials'; setTag = 'motionclean';
    else
        mo_ = true(size(Ko)); mc_ = true(size(Kc)); setLbl = 'all trials'; setTag = 'allTrials';
    end
    xo = Xo(mo_,si); xc = Xc(mc_,si);
    yo_ = Yo(mo_);   yc_ = Yc(mc_);
    Po_ = Po(mo_,:); Pc_ = Pc(mc_,:);
    So_ = So(mo_);   Sc_ = Sc(mc_);

    ss = unique([So_; Sc_]).';

    % WITHIN-SESSION quartiles, edges from that session's OL+CL trials together -- this is
    % what motion_analysis.m does, and matching it reproduces the published motion panel to
    % the decimal (verified 2026-08-19, talk/verify_motion_quartiles.m). One GLOBAL edge set
    % across the pooled trials is WRONG here: the states are not on a common scale between
    % sessions (motion medians span -0.29..-0.03, maxima 0.99..4.78), so global edges sort
    % trials by session rather than by state -- Q1 ended up fed by 7 of 9 sessions and the
    % panel grew a Q2 spike that is pure session difficulty.
    bo = nan(size(xo));  bc = nan(size(xc));
    ro = nan(size(xo));  rc = nan(size(xc));   % within-session percentile rank of the state
    for i = 1:numel(ss)
        io = So_==ss(i);  ic = Sc_==ss(i);
        e  = quantile([xo(io); xc(ic)], linspace(0,1,nBins+1));
        t  = discretize(xo(io), e);  t(isnan(t)) = nBins;  bo(io) = t;
        t  = discretize(xc(ic), e);  t(isnan(t)) = nBins;  bc(ic) = t;
        % rank, from the same combined OL+CL distribution the edges came from, so the
        % slope below is in "RMSE per full sweep of this session's state range" -- the
        % same quantity the Q1->Q4 change on the panel reports. A slope in RAW state
        % units is not comparable between sessions (their state ranges differ by 5x),
        % which is why the median raw slope used to contradict the panel it annotates.
        r  = tiedrank([xo(io); xc(ic)]);  r = r / numel(r);
        ro(io) = r(1:sum(io));  rc(ic) = r(sum(io)+1:end);
    end

    mO=nan(1,nBins); sO=nan(1,nBins); mC=nan(1,nBins); sC=nan(1,nBins);
    for b = 1:nBins
        a = yo_(bo==b); mO(b)=mean(a); sO(b)=std(a)/sqrt(numel(a));
        a = yc_(bc==b); mC(b)=mean(a); sC(b)=std(a)/sqrt(numel(a));
    end

    % per-session slope interaction (the claim: does feedback flatten this state's effect)
    slO=nan(numel(ss),1); slC=nan(numel(ss),1);
    for i = 1:numel(ss)
        io = So_==ss(i); ic = Sc_==ss(i);
        if sum(io)>5; pf=polyfit(ro(io),yo_(io),1); slO(i)=pf(1); end
        if sum(ic)>5; pf=polyfit(rc(ic),yc_(ic),1); slC(i)=pf(1); end
    end
    v = isfinite(slO) & isfinite(slC);
    pInt = signrank(slO(v), slC(v));
    % Report the MEAN slope as well as the median: the pooled quartile curve is an average
    % over sessions, so it tracks the MEAN slope, while the signed-rank test is about the
    % MEDIAN. When the two slope summaries have opposite signs the panel and the p-value are
    % answering different questions and the effect is carried by a minority of sessions.
    fprintf(['[%-7s] Q1->Q4  OL %+.2f (%.2f->%.2f)  CL %+.2f (%.2f->%.2f) | slope/rank OL ' ...
             'med %+.3g mean %+.3g  CL med %+.3g mean %+.3g | p=%.4g  [%s]%s\n'], ST(si).key, ...
             mO(end)-mO(1), mO(1), mO(end), mC(end)-mC(1), mC(1), mC(end), ...
             median(slO(v)), mean(slO(v)), median(slC(v)), mean(slC(v)), pInt, setLbl, ...
             tern(sign(median(slO(v))) ~= sign(mean(slO(v))), ...
                  '   <-- OL median and mean slope DISAGREE: a minority of sessions carries it', ''));

    fig = figure('Color','w','Units','centimeters','Position',[0 0 13 10]);
    ax = axes(fig); hold(ax,'on');
    xb = 1:nBins;
    errorbar(ax, xb-0.1, mO, sO, 'o-', 'Color',PS.col_ol, 'LineWidth',2, ...
        'MarkerSize',6, 'CapSize',4, 'DisplayName','Open-Loop');
    errorbar(ax, xb+0.1, mC, sC, 'o-', 'Color',PS.col_cl, 'LineWidth',2, ...
        'MarkerSize',6, 'CapSize',4, 'DisplayName','Closed-Loop');
    xlim(ax,[0.5 nBins+0.5]);
    xticks(ax, xb); xticklabels(ax, {'Q1 (low)','Q2','Q3','Q4 (high)'});
    legend(ax,'Box','off','Location','northwest','FontSize',6,'FontWeight','bold');
    xlabel(ax, sprintf('%s -- %s', ST(si).xlab, setLbl), 'FontWeight','bold');
    ylabel(ax, 'Trial RMSE (%\DeltaF/F)', 'FontWeight','bold');
    set(ax,'Box','off','TickDir','out');
    hold(ax,'off');
    paperExport(fig, fullfile(outDir, sprintf('state_%s_quartile_%s.png', ST(si).key, setTag)));

    %% ---- exemplar traces: bottom bin vs top bin --------------------------
    if ~ST(si).ex; continue; end
    figE = figure('Color','w','Units','centimeters','Position',[0 0 20 12]);
    tl = tiledlayout(figE, 2, 2, 'TileSpacing','compact','Padding','compact');
    rows = {'Open loop', Po_, yo_, xo, bo, PS.col_ol; 'Closed loop', Pc_, yc_, xc, bc, PS.col_cl};
    for r = 1:2
        [lbl, P, Y, X, B, col] = deal(rows{r,:});
        for q = [1 nBins]
            idx = find(B == q);
            % deterministic pick: spread across the bin's own state range, not random
            [~, ord] = sort(X(idx));
            pick = idx(ord(round(linspace(0.15, 0.85, nEx) * numel(ord))));
            axk = nexttile(tl); hold(axk,'on');
            patch(axk, [0 dur dur 0], [-14 -14 6 6], [0.93 0.93 0.93], ...
                  'EdgeColor','none', 'HandleVisibility','off');
            yline(axk, REF, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',0.9, 'HandleVisibility','off');
            for e = 1:numel(pick)
                plot(axk, t_l, P(pick(e),:), '-', 'Color',[col 0.75], 'LineWidth',0.9);
            end
            xlim(axk,[-2 dur+2]); ylim(axk,[-14 6]);
            title(axk, sprintf('%s  |  Q%d   state %.3g-%.3g   RMSE %.2f', lbl, q, ...
                  min(X(idx)), max(X(idx)), mean(Y(idx))), 'FontSize',8, 'FontWeight','bold');
            set(axk,'Box','off','TickDir','out');
            if r==2; xlabel(axk,'Time from onset (s)','FontWeight','bold'); end
            if q==1; ylabel(axk,'\DeltaF/F (%)','FontWeight','bold'); end
        end
    end
    title(tl, sprintf('%s -- %d example trials from the bottom and top quartile (%s)', ...
          ST(si).xlab, nEx, setLbl), 'FontSize',9, 'FontWeight','bold');
    paperExport(figE, fullfile(outDir, sprintf('state_%s_exemplars_Q1_Q4.png', ST(si).key)));
end
fprintf('[SQ] panels -> %s\n', outDir);

%% ---- helpers ------------------------------------------------------------
function r = relBand(SEG, Fs, lo, hi)
% Relative band power of each row: P(lo-hi) / P(0.4-10). A RATIO, so it is independent
% of the segment's overall signal power -- unlike raw variance.
    n = size(SEG,1); r = nan(n,1);
    for t = 1:n
        s = detrend(double(SEG(t,:)),'linear');
        N = numel(s); w = hann(N).';
        P = abs(fft(s.*w)).^2; P = P(1:floor(N/2)+1);
        f = (0:floor(N/2))*Fs/N;
        r(t) = sum(P(f>=lo & f<hi)) / max(sum(P(f>=0.4 & f<10)), eps);
    end
end

function s = tern(c, a, b)
    if c; s = a; else; s = b; end
end
