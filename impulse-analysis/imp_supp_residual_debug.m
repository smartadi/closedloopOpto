%% imp_supp_residual_debug.m -- DIAGNOSTIC views for the AL_0033 stim-blind residual decomposition.
%
% *** THESE ARE NOT PAPER PANELS. *** Everything here exports as PNG (project export rule: PDF is
% reserved for panels registered in PAPER.md / figures_final). Big fonts, big figures, every control
% drawn rather than summarised. The paper-standard panels are `imp_supp_residual.m`.
%
% OPERATING POINT (decided 2026-09-30, user): AL_0033 2025-01-29 e1, TF mask (`SUPP_MASK='tf'`),
% `select_mode='r2max'` -> spont R^2 0.931 | capture 91% | leak 9% | catch -2%.
%
% WHAT IT DRAWS
%   1  dbg_01_pred_spont.png     held-out spontaneous prediction: 3 windows, actual/pred/residual
%   2  dbg_02_pred_scatter.png   held-out pred-vs-actual, plus the residual's own structure
%   3  dbg_03_agl_allamps.png    trial-averaged Actual/Global/Local at EVERY amp + the catch tile
%   4  dbg_04_quartile_<state>.png   per STATE: quartile-binned residual prediction error, with the
%                                    GLOBAL negative control and the pre-stim (no-stim) error, the
%                                    raw scatter with the quartile edges, and the time-resolved
%                                    deviation trace per quartile
%   5  dbg_05_quartile_summary.png   all three states side by side, Local vs Global
%
% STATES DRAWN (user request): motion, relative delta (2-4 / 0.4-10 Hz), ABSOLUTE delta.
%   ** abs-delta is a POWER CONFOUND ** -- retracted 2026-07-01, because PreVar/abs-delta are the
%   signal's own power and are entangled with every residual-magnitude metric. It is drawn because
%   it was asked for and because seeing it move while rel-delta does or does not is exactly the
%   diagnostic; it is titled as a confound on its own face so no panel can be lifted out and quoted.
%
% DV. "Residual prediction error" = per-trial L1 deviation of the Local residual from its own
% amplitude mean (`L1DEVz`, z-scored WITHIN amplitude so the dose-response is removed and only
% trial-to-trial spread is left). Two reference series are drawn against it on every panel:
%   GLOBAL  the same statistic on the Global component -- the negative control. Global is ongoing
%           network activity and SHOULD track state; a Local effect that mirrors it is leakage.
%   PRE     the pre-onset prediction error, i.e. that trial's model quality with NO stim. If PRE
%           rises with state as fast as Local does, the "state-dependence" is the contra model
%           getting worse in that state, not the stim response changing.
%
% RUN:  load_experiments        % once
%       imp_supp_residual       % once -- leaves P/A/M/D in the workspace (reused here)
%       imp_supp_residual_debug
%
% KNOBS:  DBG_NBIN (4) | DBG_OUTDIR | DBG_SESS (3) | DBG_MASK ('tf')
% --------------------------------------------------------------------------------------------------

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));

if ~exist('DBG_NBIN','var')   || isempty(DBG_NBIN),   DBG_NBIN   = 4;    end
if ~exist('DBG_SESS','var')   || isempty(DBG_SESS),   DBG_SESS   = 3;    end
if ~exist('DBG_MASK','var')   || isempty(DBG_MASK),   DBG_MASK   = 'tf'; end
if ~exist('DBG_OUTDIR','var') || isempty(DBG_OUTDIR)
    DBG_OUTDIR = fullfile(here,'figs','supp_residual_debug');
end
if ~exist(DBG_OUTDIR,'dir'), mkdir(DBG_OUTDIR); end

COL_A = [0 0 0];  COL_G = [0.85 0.20 0.20];  COL_L = [0.10 0.40 0.85];  COL_P = [0.45 0.45 0.45];

%% ---- reuse the built decomposition, or build it ------------------------------------------------
% imp_supp_residual leaves P/A/M/D in the base workspace. Rebuilding costs an SVD read, so reuse
% when the session AND the mask match what is already there; otherwise build it the same way.
haveAll = all(cellfun(@(v) evalin('base', sprintf('exist(''%s'',''var'')==1', v)), {'P','A','M','D'}));
needBuild = true;
if haveAll
    Pb = evalin('base','P');
    isTF = ~(isfield(evalin('base','A'),'isRank') && evalin('base','A').isRank);
    if strcmpi(Pb.mn,'AL_0033') && (isTF == strcmpi(DBG_MASK,'tf'))
        P = evalin('base','P'); A = evalin('base','A');
        M = evalin('base','M'); D = evalin('base','D');
        fprintf('[DBG] reusing P/A/M/D from the workspace (%s, mask %s)\n', P.label, DBG_MASK);
        needBuild = false;
    end
end
if needBuild
    fprintf('[DBG] building the decomposition (SUPP_MASK=%s) via imp_supp_residual...\n', DBG_MASK);
    assignin('base','SUPP_MASK',DBG_MASK);  assignin('base','SUPP_SESS',DBG_SESS);
    evalin('base','imp_supp_residual');
    P = evalin('base','P'); A = evalin('base','A'); M = evalin('base','M'); D = evalin('base','D');
end
assert(~isempty(D.ST) && ~isempty(D.ST.LD), 'imp_supp_residual_debug: no per-trial state payload.');

ST  = D.ST;
tt  = D.rel(:)/D.Fs;
lab = sprintf('%s  |  mask %s  |  R^2 %.3f  cap %.0f%%  leak %.0f%%  catch %+.0f%%', ...
              P.label, DBG_MASK, M.r2_spont, D.capMed, D.leakMed, 100*D.catch.ratio);
fprintf('\n[DBG] %s\n', lab);

%% ================================================================================================
%  1  held-out spontaneous prediction -- three windows
%     Three separate windows, not one long one: a single stretch can be a lucky segment, and the
%     residual row underneath is on the SAME y scale so the error is read directly rather than
%     inferred from a variance ratio.
%% ================================================================================================
yhat = P.muY + P.Zte*M.b;
res  = P.yte - yhat;
nT   = numel(P.yte);
W    = 500;
starts = round(linspace(1, max(nT-W,1), 3));

f1 = figure('Color','w','Name','[DBG] held-out spontaneous prediction','Position',[40 40 1500 820]);
T1 = tiledlayout(f1, 3, 1, 'TileSpacing','compact','Padding','compact');
for i = 1:3
    idx = starts(i):min(starts(i)+W-1, nT);
    ax = nexttile(T1); hold(ax,'on'); box(ax,'on');
    plot(ax, idx, P.yte(idx), '-','Color',COL_A,'LineWidth',1.3,'DisplayName','actual ipsi (held out)');
    plot(ax, idx, yhat(idx),  '-','Color',COL_G,'LineWidth',1.1,'DisplayName','contra prediction');
    off = min([P.yte(idx); yhat(idx)]) - (max(res(idx))-min(res(idx))) - 1;
    plot(ax, idx, res(idx)+off, '-','Color',COL_L,'LineWidth',0.9,'DisplayName','residual (offset)');
    yline(ax, off, 'k:','HandleVisibility','off');
    xlim(ax,[idx(1) idx(end)]); ylabel(ax,'\DeltaF/F (%)');
    r2w = 1 - sum(res(idx).^2)/max(sum((P.yte(idx)-mean(P.yte(idx))).^2),eps);
    title(ax, sprintf('held-out window %d/3   frames %d-%d   window R^2 = %.3f', i, idx(1), idx(end), r2w), ...
          'FontSize',11,'FontWeight','bold');
    set(ax,'FontSize',10);
    if i==1, legend(ax,'Location','northeast','FontSize',9,'Box','off'); end
    if i==3, xlabel(ax,'held-out spontaneous frame (concatenated interstim segments)'); end
end
sgtitle(f1, sprintf('%s   |   session R^2 = %.3f, shifted-target control %+.2f', lab, M.r2_spont, M.r2_shift), ...
        'FontSize',12,'FontWeight','bold');
dbg_save(f1, DBG_OUTDIR, 'dbg_01_pred_spont');

%% ================================================================================================
%  2  held-out prediction quality: scatter + where the error lives
%% ================================================================================================
f2 = figure('Color','w','Name','[DBG] prediction quality','Position',[60 60 1400 480]);
T2 = tiledlayout(f2, 1, 3, 'TileSpacing','compact','Padding','compact');

ax = nexttile(T2); hold(ax,'on'); box(ax,'on');
ss = unique(round(linspace(1, nT, min(8000, nT))));
scatter(ax, P.yte(ss), yhat(ss), 5, COL_L, 'filled','MarkerFaceAlpha',0.12);
lims = [min([P.yte(ss);yhat(ss)]) max([P.yte(ss);yhat(ss)])];
plot(ax, lims, lims, 'k--','LineWidth',1.2);
pf = polyfit(P.yte(ss), yhat(ss), 1);
plot(ax, lims, polyval(pf,lims), '-','Color',COL_G,'LineWidth',1.4);
axis(ax,'square'); xlim(ax,lims); ylim(ax,lims); set(ax,'FontSize',10);
xlabel(ax,'actual \DeltaF/F (%)'); ylabel(ax,'predicted');
title(ax, sprintf('held-out: slope %.3f  (1 = no gain error)', pf(1)),'FontSize',11,'FontWeight','bold');

ax = nexttile(T2); hold(ax,'on'); box(ax,'on');
histogram(ax, res, 60, 'FaceColor',COL_L,'EdgeColor','none');
xline(ax, 0,'k--','LineWidth',1.2);
xlabel(ax,'residual \DeltaF/F (%)'); ylabel(ax,'held-out frames'); set(ax,'FontSize',10);
title(ax, sprintf('residual: mean %+.3f, SD %.3f', mean(res), std(res)),'FontSize',11,'FontWeight','bold');

% Is the error bigger where the signal is bigger? A rising line here is the power-confound in its
% rawest form -- it is why pre-var and abs-delta are not interpretable as state markers.
ax = nexttile(T2); hold(ax,'on'); box(ax,'on');
[bx, by, bs] = dbg_bin(abs(P.yte), abs(res), 10);
errorbar(ax, bx, by, bs, '-o','Color',COL_L,'MarkerFaceColor',COL_L,'LineWidth',1.4,'CapSize',3);
xlabel(ax,'|actual| \DeltaF/F (%)  (decile)'); ylabel(ax,'mean |residual|'); set(ax,'FontSize',10);
title(ax,'error grows with signal power (the confound)','FontSize',11,'FontWeight','bold');
sgtitle(f2, lab, 'FontSize',12,'FontWeight','bold');
dbg_save(f2, DBG_OUTDIR, 'dbg_02_pred_scatter');

%% ================================================================================================
%  3  trial-averaged Actual / Global / Local at EVERY amplitude + catch, shared y
%% ================================================================================================
nA = numel(D.trA);
allv = [];
for ai = 1:nA, allv = [allv; D.trA{ai}(:); D.trG{ai}(:); D.trL{ai}(:)]; end %#ok<AGROW>
allv = [allv; D.catch.trA(:); D.catch.trG(:); D.catch.trL(:)];
yl = [min(allv) max(allv)];  yl = yl + 0.08*diff(yl)*[-1 1];

f3 = figure('Color','w','Name','[DBG] A/G/L all amps','Position',[40 40 1560 760]);
nc = ceil((nA+1)/2);
T3 = tiledlayout(f3, 2, nc, 'TileSpacing','compact','Padding','compact');
for ai = 1:nA
    ax = nexttile(T3); hold(ax,'on'); box(ax,'on');
    dbg_tile(ax, tt, D.trA{ai}, D.trG{ai}, D.trL{ai}, D.preN, yl, [-0.4 0.8], COL_A, COL_G, COL_L);
    title(ax, sprintf('%.2f V  n=%d  cap %.0f%% leak %.0f%%%s', D.amps(ai), D.nT_amp(ai), ...
          D.capPct(ai), D.leakPct(ai), dbg_tern(D.ampOK(ai),'','  [no resp]')), ...
          'FontSize',10,'FontWeight','bold', 'Color', dbg_tern(D.ampOK(ai), [0 0 0], [.55 .55 .55]));
    set(ax,'FontSize',9);
    if ai==1, legend(ax,{'Actual','Global','Local'},'Location','southeast','FontSize',9,'Box','off'); end
end
ax = nexttile(T3); hold(ax,'on'); box(ax,'on');
dbg_tile(ax, tt, D.catch.trA, D.catch.trG, D.catch.trL, D.preN, yl, [-0.4 0.8], COL_A, COL_G, COL_L);
set(ax,'XColor',[.15 .45 .15],'YColor',[.15 .45 .15],'LineWidth',1.4,'FontSize',9);
title(ax, sprintf('CATCH %s  n=%d   %.0f%% of stim Local', D.catch.kind, D.catch.nT, 100*D.catch.ratio), ...
      'FontSize',10,'FontWeight','bold','Color',[.15 .45 .15]);
xlabel(T3,'time from laser onset (s)','FontSize',11,'FontWeight','bold');
ylabel(T3,'\DeltaF/F (%)','FontSize',11,'FontWeight','bold');
sgtitle(f3, lab, 'FontSize',12,'FontWeight','bold');
dbg_save(f3, DBG_OUTDIR, 'dbg_03_agl_allamps');

%% ================================================================================================
%  4  QUARTILE-BINNED residual prediction error vs state
%% ================================================================================================
zf  = @(x)(x - mean(x,'omitnan'))./max(std(x,'omitnan'), eps);
dvL = ST.L1DEVz;                                   % Local residual, |dev| from amp-mean, z-in-amp
dvG = dbg_globaldv(ST.trG, D.dcc);                 % SAME statistic on Global -> the control
dvP = zf(ST.PRE);                                  % pre-onset (no-stim) prediction error

% Labels carry NO "(z)": ST.MOT/DPr/DPa are stored in RAW units (f2_state z-scores them at use).
% The quartile binning is done on the raw value, so the scatter axis must read raw too.
STATES = { 'MOT', 'motion',                            'ADMISSIBLE (power-independent)',        'motion'
           'DPr', 'relative \delta (2-4 / 0.4-10 Hz)', 'ADMISSIBLE (power-independent)',        'reldelta'
           'DPa', 'absolute \delta (2-4 Hz power)',    'POWER CONFOUND -- not interpretable',   'absdelta' };

nb = DBG_NBIN;
SUM = struct('name',{},'rhoL',{},'pL',{},'rhoG',{},'pG',{},'rhoP',{},'qL',{},'qG',{},'qP',{},'qSE',{});

fprintf('\n[DBG] quartile-binned residual prediction error vs state (n bins = %d)\n', nb);
for k = 1:size(STATES,1)
    fld = STATES{k,1};  nameFull = STATES{k,2};  flagTxt = STATES{k,3};
    st  = ST.(fld);
    ok  = isfinite(dvL) & isfinite(dvG) & isfinite(dvP) & isfinite(st);
    stz = zf(st);

    [rL,pL] = partialcorr(dvL(ok), stz(ok), dvP(ok), 'type','Spearman','rows','complete');
    [rG,pG] = partialcorr(dvG(ok), stz(ok), dvP(ok), 'type','Spearman','rows','complete');
    [rP,pP] = corr(dvP(ok), stz(ok), 'type','Spearman','rows','complete');

    g = dbg_qbin(st(ok), nb);
    [qL,sL,nL] = dbg_qstat(dvL(ok), g, nb);
    [qG,sG,~ ] = dbg_qstat(dvG(ok), g, nb);
    [qP,sP,~ ] = dbg_qstat(dvP(ok), g, nb);
    pKW = kruskalwallis(dvL(ok), g, 'off');

    fprintf('   %-34s  Local rho=%+.3f p=%.3g | Global rho=%+.3f p=%.3g | PRE rho=%+.3f p=%.3g | KW p=%.3g  [%s]\n', ...
            nameFull, rL, pL, rG, pG, rP, pP, pKW, flagTxt);

    isConf = contains(flagTxt,'CONFOUND');
    fh = figure('Color','w','Name',sprintf('[DBG] quartile %s', fld),'Position',[50 50 1500 860]);
    TQ = tiledlayout(fh, 2, 3, 'TileSpacing','compact','Padding','compact');

    % (a) the quartile plot itself
    ax = nexttile(TQ, 1, [1 2]); hold(ax,'on'); box(ax,'on');
    xq = 1:nb;
    errorbar(ax, xq, qL, sL, '-o','Color',COL_L,'MarkerFaceColor',COL_L,'LineWidth',1.8,'CapSize',4, ...
             'DisplayName','LOCAL residual |dev|  (the finding)');
    errorbar(ax, xq, qG, sG, '--s','Color',COL_G,'MarkerFaceColor',COL_G,'LineWidth',1.5,'CapSize',4, ...
             'DisplayName','GLOBAL |dev|  (negative control)');
    errorbar(ax, xq, qP, sP, ':^','Color',COL_P,'MarkerFaceColor',COL_P,'LineWidth',1.5,'CapSize',4, ...
             'DisplayName','PRE-stim error  (model quality, no stim)');
    yline(ax, 0, 'k:','HandleVisibility','off');
    % Single-line tick labels: a '\n' inside an XTickLabel cell is split across TICKS by MATLAB,
    % which silently relabelled Q1..Q4 as Q1 / n=187 / Q2 / n=187.
    set(ax,'XTick',xq,'XTickLabel',arrayfun(@(i)sprintf('Q%d (n=%d)',i,nL(i)),xq,'uni',0),'FontSize',10);
    xlim(ax,[0.6 nb+0.4]);
    xlabel(ax, sprintf('%s quartile (low -> high)', nameFull));
    ylabel(ax,'z-scored |deviation| (within amp)');
    legend(ax,'Location','best','FontSize',9,'Box','off');
    ttl = sprintf('%s   |   Local \\rho=%+.3f p=%.3g   Global \\rho=%+.3f   KW p=%.3g', ...
                  nameFull, rL, pL, rG, pKW);
    title(ax, ttl, 'FontSize',12,'FontWeight','bold', 'Color', dbg_tern(isConf,[.75 .35 0],[0 0 0]));

    % (b) raw scatter with the quartile edges drawn on it -- so the binning is auditable
    ax = nexttile(TQ, 3); hold(ax,'on'); box(ax,'on');
    scatter(ax, st(ok), dvL(ok), 6, COL_L,'filled','MarkerFaceAlpha',0.18);
    ed = quantile(st(ok), (1:nb-1)/nb);
    for e = ed(:).', xline(ax, e, '-','Color',[.5 .5 .5],'LineWidth',1.0); end
    % Motion is threshold-shaped (RESEARCH 2026-08-xx: median -0.196, only ~3% of trials past
    % z=1.5), so a full-range x axis compresses every quartile edge into one sliver. Clip the view
    % to the 99th percentile and SAY so -- the binning itself still uses all trials.
    xhi = quantile(st(ok), 0.99);
    if xhi > min(st(ok)) && max(st(ok)) > 2*xhi
        xlim(ax, [min(st(ok)) xhi]);
        title(ax, sprintf('raw trials + quartile edges  (x clipped at p99; %d/%d off-scale)', ...
              nnz(st(ok) > xhi), nnz(ok)), 'FontSize',10,'FontWeight','bold');
    else
        title(ax,'raw trials + quartile edges','FontSize',11,'FontWeight','bold');
    end
    xlabel(ax, sprintf('%s  (raw)', nameFull)); ylabel(ax,'Local |dev| (z)'); set(ax,'FontSize',10);

    % (c) time-resolved: mean |Local(t) - amp-mean| per quartile. Shows WHERE in the trial the
    %     state effect sits -- a state effect confined to the pre-onset window is a model-quality
    %     effect, not a stim-response effect, and only a time-resolved view can tell them apart.
    ax = nexttile(TQ, 4, [1 3]); hold(ax,'on'); box(ax,'on');
    cmapQ = [0.10 0.40 0.85; 0.35 0.60 0.90; 0.85 0.55 0.35; 0.85 0.20 0.20];
    idxOK = find(ok);
    for q = 1:nb
        sel = idxOK(g == q);
        Wt  = dbg_devtrace(ST, D, sel);
        cq  = cmapQ(min(q,size(cmapQ,1)),:);
        plot(ax, tt, Wt, '-','Color',cq,'LineWidth',1.6,'DisplayName',sprintf('Q%d (n=%d)',q,numel(sel)));
    end
    xline(ax, 0, 'k:','LineWidth',1.0,'HandleVisibility','off');
    xlim(ax,[-0.4 0.8]); xlabel(ax,'time from laser onset (s)');
    ylabel(ax,'mean |Local(t) - amp mean|  (\DeltaF/F %)');
    legend(ax,'Location','northeast','FontSize',9,'Box','off'); set(ax,'FontSize',10);
    title(ax,'time-resolved deviation by state quartile (pre-onset separation = model quality, not stim)', ...
          'FontSize',11,'FontWeight','bold');

    sg = sprintf('%s        [ %s ]', lab, flagTxt);
    sgtitle(fh, sg, 'FontSize',12,'FontWeight','bold', 'Color', dbg_tern(isConf,[.75 .35 0],[0 0 0]));
    dbg_save(fh, DBG_OUTDIR, sprintf('dbg_04_quartile_%s', STATES{k,4}));

    SUM(k) = struct('name',nameFull,'rhoL',rL,'pL',pL,'rhoG',rG,'pG',pG,'rhoP',rP, ...
                    'qL',qL,'qG',qG,'qP',qP,'qSE',sL);
end

%% ================================================================================================
%  5  summary: the three states side by side
%% ================================================================================================
f5 = figure('Color','w','Name','[DBG] quartile summary','Position',[60 60 1500 480]);
T5 = tiledlayout(f5, 1, 3, 'TileSpacing','compact','Padding','compact');
for k = 1:numel(SUM)
    ax = nexttile(T5); hold(ax,'on'); box(ax,'on');
    xq = 1:nb;
    errorbar(ax, xq, SUM(k).qL, SUM(k).qSE, '-o','Color',COL_L,'MarkerFaceColor',COL_L, ...
             'LineWidth',1.8,'CapSize',4,'DisplayName','Local');
    plot(ax, xq, SUM(k).qG, '--s','Color',COL_G,'MarkerFaceColor',COL_G,'LineWidth',1.5,'DisplayName','Global');
    plot(ax, xq, SUM(k).qP, ':^','Color',COL_P,'MarkerFaceColor',COL_P,'LineWidth',1.5,'DisplayName','PRE');
    yline(ax, 0,'k:','HandleVisibility','off');
    set(ax,'XTick',xq,'FontSize',10); xlim(ax,[0.6 nb+0.4]);
    xlabel(ax,'state quartile'); if k==1, ylabel(ax,'z |deviation|'); end
    isConf = contains(SUM(k).name,'absolute');
    title(ax, sprintf('%s\nLocal \\rho=%+.3f (p=%.3g) | Global \\rho=%+.3f', SUM(k).name, ...
          SUM(k).rhoL, SUM(k).pL, SUM(k).rhoG), 'FontSize',11,'FontWeight','bold', ...
          'Color', dbg_tern(isConf,[.75 .35 0],[0 0 0]));
    if k==1, legend(ax,'Location','best','FontSize',9,'Box','off'); end
end
sgtitle(f5, sprintf('%s   |   quartile-binned residual prediction error', lab),'FontSize',12,'FontWeight','bold');
dbg_save(f5, DBG_OUTDIR, 'dbg_05_quartile_summary');

fprintf('\n[DBG] PNGs written to %s\n', DBG_OUTDIR);

%% ------------------------------------------------------------------------------------------------
%  helpers
%% ------------------------------------------------------------------------------------------------
function dbg_tile(ax, tt, a, g, r, preN, yl, xl, cA, cG, cL)
bl = @(v) v(:) - mean(v(1:max(preN,1)));
plot(ax, tt, bl(a), '-','Color',cA,'LineWidth',1.6);
plot(ax, tt, bl(g), '-','Color',cG,'LineWidth',1.3);
plot(ax, tt, bl(r), '-','Color',cL,'LineWidth',1.3);
xline(ax, 0, ':','Color',[.4 .4 .4]);  yline(ax, 0, ':','Color',[.4 .4 .4]);
xlim(ax, xl); ylim(ax, yl);
end

function dbg_save(fh, outdir, name)
% PNG at 300 dpi. These are diagnostics -- the project export rule reserves PDF for paper panels.
f = fullfile(outdir, [name '.png']);
exportgraphics(fh, f, 'Resolution', 300);
fprintf('   -> %s\n', f);
end

function gd = dbg_globaldv(tr, dcc)
% Global control DV, MATCHED to the Local DV (unsigned |dev| from the amp mean, z within amp). A
% signed Global against an unsigned Local made every control look small -- RESEARCH 2026-08-12.
gd = [];
for ai = 1:numel(tr)
    G = tr{ai};  if isempty(G), continue; end
    dc = dcc{ai};  if isempty(dc), dc = 1:size(G,1); end
    Gd = G(dc,:);  mu = mean(Gd, 2);
    v  = mean(abs(Gd - mu), 1).';
    gd = [gd; (v - mean(v,'omitnan'))./max(std(v,'omitnan'),eps)]; %#ok<AGROW>
end
end

function W = dbg_devtrace(ST, D, sel)
% Mean over the selected trials of |Local(t) - that amplitude's mean Local(t)|. Built per amplitude
% and then pooled, so the dose-response is removed exactly the way the scalar DV removes it.
nB = numel(D.rel);  acc = zeros(nB,1);  cnt = 0;
for ai = 1:numel(ST.trL)
    L = ST.trL{ai};  if isempty(L), continue; end
    inA = sel(ST.AMPi(sel) == ai);
    if isempty(inA), continue; end
    tix = ST.TRi(inA);
    tix = tix(tix >= 1 & tix <= size(L,2));
    if isempty(tix), continue; end
    mu  = mean(L, 2);
    acc = acc + sum(abs(L(:,tix) - mu), 2);
    cnt = cnt + numel(tix);
end
W = acc / max(cnt,1);
end

function g = dbg_qbin(x, nb)
x = x(:);  q = [-inf; quantile(x, (1:nb-1)/nb).'; inf];
g = zeros(numel(x),1);
for i = 1:nb, g(x > q(i) & x <= q(i+1)) = i; end
g(g==0) = 1;
end

function [m, se, n] = dbg_qstat(y, g, nb)
m = nan(nb,1); se = nan(nb,1); n = zeros(nb,1);
for i = 1:nb
    v = y(g==i);  v = v(isfinite(v));
    n(i) = numel(v);
    if n(i) >= 2, m(i) = mean(v); se(i) = std(v)/sqrt(n(i)); end
end
end

function [bx, by, bs] = dbg_bin(x, y, nb)
x = x(:); y = y(:);
q = [-inf; quantile(x, (1:nb-1)/nb).'; inf];
bx = nan(nb,1); by = nan(nb,1); bs = nan(nb,1);
for i = 1:nb
    m = x > q(i) & x <= q(i+1);
    if nnz(m) < 3, continue; end
    bx(i) = mean(x(m)); by(i) = mean(y(m)); bs(i) = std(y(m))/sqrt(nnz(m));
end
ok = isfinite(bx); bx = bx(ok); by = by(ok); bs = bs(ok);
end

function v = dbg_tern(c, a, b)
if c, v = a; else, v = b; end
end
