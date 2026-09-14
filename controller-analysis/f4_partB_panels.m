% controller-analysis/f4_partB_panels.m
% ============================================================================
% FIGURE 4 -- PART 1 (Block B) PAPER PANELS  [F4B]
% "Distinct brain-state features shape the closed-loop tracking error."
%
% Story: three near-independent per-trial features -- initial deviation,
% motion energy, relative 2-4 Hz power -- each contribute to CL trial RMSE.
% A linear model quantifies each factor's UNIQUE contribution (partial R^2),
% resolved into an early transient (0-1 s) and a settled window (1-3 s).
%
% THREE PREDICTORS (identical across every panel here -- the 2026-09-08 fix):
%   X1  initial deviation  = |wcDfk(onset) - ref|
%   X2  motion             = mean rectified movement mean(max(mot,0)), -2 s -> stim end
%   X3  rel 2-4 Hz power   = cl_reldelta(pwcDfk_l), -2 s -> stim end   [CANONICAL]
% The exemplar panel is now aligned to X3 = rel 2-4 Hz (was pre-trial std in the
% retired cl_mse_exemplars.m), so exemplars and the R^2 model show the SAME three
% features.
%
% OUTPUTS (paper/images/figure4/, vector PDF at paperStyle):
%   f4B_exemplars.pdf       (A) one isolating CL trial per factor  [~13 x 4.2 cm]
%   f4B_decomp_windows.pdf  (B) partial R^2 per factor x window -- HEADLINE  [6 x 4.5 cm]
%   f4B_delta_robust.pdf    (C) delta unique R^2: abs / rel / pre-stim x window  [6 x 4.5 cm]
% Burst gallery (delta_burst_gallery.png, cl_delta_burst_explore.m) stays a PNG
% supplement -- not rebuilt here.
%
% Cohort: motion-/spectrum-complete CL trials (the has_motion sessions).
% Requires: load_sessions.m has run (mouse, fields in workspace).
% ============================================================================
clc; close all;

PS = paperStyle(); setPaperDefaults();

assert(exist('mouse','var') && exist('fields','var'), '[F4B] run load_sessions.m first.');

if exist(fullfile('paper','images'),'dir');            paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir');   paper_root = fullfile('..','paper');
else;  paper_root = 'paper'; warning('[F4B] cannot locate paper/ -- exporting locally.'); end
outdir = fullfile(paper_root,'images','figure4');
if ~exist(outdir,'dir'); mkdir(outdir); end

% ---- constants ----
Fs      = 35;
c0      = 36;    % onset col in wcDfk
c0_mot  = 71;    % onset col in wcmotion
c0_l    = 106;   % onset col in the legacy pwcDfk_l (3 s pre-buffer)
c0_p    = 351;   % onset col in pwcDfk/pncDfk (controllerData 10 s pre-buffer: dFk(i-350:i+..)).
% Current caches store pwcDfk, NOT the legacy _l variants -> pick_pwc() (EOF) returns whichever
% CL delta buffer a session actually has + its onset col, so no cache rebuild is needed
% (mirrors the f4_row2_quartiles.m fallback, RESEARCH 2026-09-12).
mot_pre = 2;     % motion window start (s before onset)
relopts = struct('pre',2,'post',3);   % rel 2-4 Hz window: -2 s -> stim end (dur=3)
% Frequency-band specificity panel (2026-09-13): relative power (band / 0.4-10 Hz total) in
% each band, same -2->stim-end window. Shows the CL-error effect is slow-band-specific
% (<4 Hz), not broadband. Bands kept <=8 Hz so the numerator stays inside the total band.
bands_hz  = {[0.4 1],[1 2],[2 4],[4 8]};   band_lbl = {'0.4-1','1-2','2-4','4-8'};

eE = c0            : c0+round(1*Fs);          % 0 -> 1 s   (early transient)
lL = c0+round(1*Fs)+1 : c0+round(3*Fs);       % 1 -> 3 s   (settled)

% factor colours (shared with cl_rmse_factor_windows): blue / orange / purple
col   = [0.20 0.40 0.75; 0.75 0.40 0.10; 0.55 0.25 0.60];
col_e = [0.35 0.55 0.85];    % early window
col_l = [0.15 0.25 0.55];    % late window
pred_names = {'Initial dev','Motion','Rel 2-4 Hz'};

fitR2 = @(Xp, yp) ...
    1 - sum((yp - [ones(size(Xp,1),1), Xp] * ([ones(size(Xp,1),1), Xp] \ yp)).^2) / ...
        max(sum((yp - mean(yp)).^2), eps);

%% ── Pool CL trials ──────────────────────────────────────────────────────────
X1=[]; X2=[]; Xrel=[]; Xdel=[]; nB=numel(bands_hz); Xbnd=cell(1,nB); [Xbnd{:}]=deal([]);
YE=[]; YL=[]; YF=[]; SESS=[]; TRI=[];

for k = 1:numel(fields)
    s = mouse.(fields{k});
    if isfield(s,'skip') && s.skip;  continue; end
    if ~isfield(s,'data');           continue; end
    if ~s.has_motion;                continue; end
    dk = s.data; if ~isfield(dk,'wcmotion'); continue; end
    % ref/dur from d when present; else the locked project defaults (d is not held in the
    % lean data-only load path -- ref=-5 and dur=3 are project-wide, see root CLAUDE.md).
    if isfield(s,'d') && isfield(s.d,'ref') && ~isempty(s.d.ref); ref = s.d.ref; else; ref = -5; end
    if isfield(s,'d') && isfield(s.d,'params') && isfield(s.d.params,'dur'); dur = s.d.params.dur; else; dur = 3; end
    nT = size(dk.wcDfk,1);

    % X1 initial deviation
    x1 = abs(dk.wcDfk(:,c0) - ref);

    % X2 motion = mean RECTIFIED movement over -2 s -> stim end (amount of movement;
    % linear, not squared -- see 2026-09-11 metric decision: motion is a sparse bursty
    % index with a no-move floor + positive spikes, so mean(max(.,0)) = average movement).
    ws = max(1, c0_mot - round(mot_pre*Fs));
    we = min(size(dk.wcmotion,2), c0_mot + round(dur*Fs) - 1);
    x2 = mean(max(dk.wcmotion(1:nT, ws:we), 0), 2);

    % X3 rel 2-4 Hz (canonical) + absolute delta (comp) for the abs-vs-rel confound control,
    % + relative power in each band for the frequency-specificity panel.
    [dbuf, c0_d]      = pick_pwc(dk, c0_l, c0_p);   % legacy _l else pwcDfk@351 (field-rot fallback)
    if isempty(dbuf);  continue;  end
    [xrel, comp]      = cl_reldelta(dbuf, c0_d, Fs, relopts);
    xdel = comp.delta(:);         % absolute 2-4 Hz power, -2 -> stim end
    xb   = nan(size(dbuf,1), nB); % relative power per band, same window
    for b = 1:nB
        ob = relopts; ob.hi = bands_hz{b};
        xb(:,b) = cl_reldelta(dbuf, c0_d, Fs, ob);
    end

    % outcomes
    yE = sqrt(mean((dk.wcDfk(1:nT,eE) - ref).^2, 2));
    yL = sqrt(mean((dk.wcDfk(1:nT,lL) - ref).^2, 2));
    yF = dk.er_wcDfk(1:nT);

    m = min([nT numel(yF) numel(xrel)]);
    X1=[X1;x1(1:m)]; X2=[X2;x2(1:m)]; Xrel=[Xrel;xrel(1:m)]; Xdel=[Xdel;xdel(1:m)]; %#ok<*AGROW>
    for b=1:nB; Xbnd{b}=[Xbnd{b};xb(1:m,b)]; end
    YE=[YE;yE(1:m)]; YL=[YL;yL(1:m)]; YF=[YF;yF(1:m)];
    SESS=[SESS;repmat(k,m,1)]; TRI=[TRI;(1:m)'];
end

ok = all(isfinite([X1 X2 Xrel Xdel YE YL YF]),2) & Xdel>0;
for b=1:nB; ok = ok & isfinite(Xbnd{b}); end
f = @(v) v(ok);
[X1,X2,Xrel,Xdel,YE,YL,YF,SESS,TRI] = ...
    deal(f(X1),f(X2),f(Xrel),f(Xdel),f(YE),f(YL),f(YF),f(SESS),f(TRI));
for b=1:nB; Xbnd{b}=f(Xbnd{b}); end
n   = numel(YE); nS = numel(unique(SESS));
fprintf('\n[F4B] %d valid CL trials / %d sessions.\n', n, nS);

Z = zscore([X1, X2, Xrel]);     % primary design matrix

%% ── Windowed decomposition: partial (unique) R^2 per factor × window ────────
outs = {YE, YL}; out_names = {'RMSE 0-1 s','RMSE 1-3 s'};
nBoot = 2000; rng(0);
Pr    = nan(3,2);            % factor × window (early,late)
PrCI  = nan(3,2,2);
Rfull = nan(1,2);
for o = 1:2
    y = outs{o};                          % RAW RMSE (never z-scored; 2026-08-13 rule)
    rf = fitR2(Z,y); Rfull(o) = rf;
    for j = 1:3
        Pr(j,o) = rf - fitR2(Z(:,setdiff(1:3,j)), y);
    end
    bp2 = nan(nBoot,3);
    for b = 1:nBoot
        ib = randsample(n,n,true); Xb = Z(ib,:); yb = y(ib);
        rfb = fitR2(Xb,yb);
        for j = 1:3, bp2(b,j) = rfb - fitR2(Xb(:,setdiff(1:3,j)), yb); end
    end
    ci = prctile(bp2,[2.5 97.5],1);
    PrCI(:,o,1) = ci(1,:).'; PrCI(:,o,2) = ci(2,:).';
end
fprintf('\nPartial (unique) R^2 by window:\n  %-12s %10s %10s\n','factor',out_names{:});
for j=1:3, fprintf('  %-12s %10.3f %10.3f\n', pred_names{j}, Pr(j,1),Pr(j,2)); end
fprintf('  %-12s %10.3f %10.3f\n','FULL R2', Rfull);

%% ── Delta robustness: abs vs rel unique R^2 × window (power-confound control) ──
% pre-stim-only definition dropped 2026-09-13 (user: not relevant). Keeps the abs-vs-rel
% contrast = the power-confound control (absolute 2-4 Hz power is entangled with signal power;
% relative = the canonical clean choice).
delvar = {log10(Xdel), Xrel}; del_lbl = {'absolute','relative'};
Drob = nan(numel(delvar),2);
for d = 1:numel(delvar)
    Xd = zscore([X1, X2, delvar{d}]);
    for o = 1:2
        y = outs{o}; rf = fitR2(Xd,y);
        Drob(d,o) = rf - fitR2(Xd(:,[1 2]), y);
    end
end
fprintf('\nDelta unique R^2 (holding init-dev + motion):\n  %-9s %10s %10s\n','def','early','late');
for d=1:numel(delvar), fprintf('  %-9s %10.3f %10.3f\n', del_lbl{d}, Drob(d,1), Drob(d,2)); end

%% ── Frequency-band specificity: relative-power unique R^2 per band × window ──
% Is the CL-error effect specific to a slow band, or broadband? Relative power (band/total)
% for each band, unique R^2 holding init-dev + motion. Power-independent (relative), so it
% is not the abs-power confound. (2026-09-13, replaces the pre-stim delta bar.)
Dband = nan(nB,2);
for b = 1:nB
    Xb = zscore([X1, X2, Xbnd{b}]);
    for o = 1:2
        y = outs{o}; Dband(b,o) = fitR2(Xb,y) - fitR2(Xb(:,[1 2]), y);
    end
end
fprintf('\nBand specificity: relative-power unique R^2 (holding init-dev + motion):\n  %-8s %10s %10s\n','band(Hz)','0-1s','1-3s');
for b=1:nB, fprintf('  %-8s %10.3f %10.3f\n', band_lbl{b}, Dband(b,1), Dband(b,2)); end

%% ── Select isolating exemplars from a SINGLE session ────────────────────────
% All three exemplars come from one session so the grey trial-average is the
% SAME across the three panels. Pick the session whose three isolating trials
% (high on target, low on the other two; pooled z) are JOINTLY best-isolated
% (maximize the weakest of the three).
EXEMPLAR_SESSION = 'm11';   % locked canonical exemplar session (user pick 2026-09-11).
                            % '' -> auto-pick the jointly best-isolated session.
isoPick = @(idx) arrayfun(@(j) localBestIso(Z,idx,j), 1:3);      % 3 trial indices
uS = unique(SESS); bestScore = -inf; pick = nan(3,1); bestS = uS(1);
sForced = find(strcmp(fields, EXEMPLAR_SESSION), 1);
if ~isempty(EXEMPLAR_SESSION) && ~isempty(sForced) && any(SESS==sForced)
    idx = find(SESS==sForced); p3 = isoPick(idx).';
    s3 = arrayfun(@(j) Z(p3(j),j), 1:3);
    pick = p3; bestS = sForced; bestScore = min(s3);
    fprintf('\nForced exemplar session %s (min isolation z=%.2f)\n', fields{bestS}, bestScore);
else
    if ~isempty(EXEMPLAR_SESSION)
        warning('[F4B] EXEMPLAR_SESSION ''%s'' not in cohort -> auto-picking.', EXEMPLAR_SESSION);
    end
    for si = uS.'
        idx = find(SESS==si);
        p3 = isoPick(idx).'; s3 = arrayfun(@(j) Z(p3(j),j), 1:3);
        sc = min(s3);                                          % weakest-isolated factor
        if sc > bestScore, bestScore = sc; pick = p3; bestS = si; end
    end
    fprintf('\nSame-session exemplars from %s (min isolation z=%.2f)\n', fields{bestS}, bestScore);
end
fprintf('\nExemplars (z1,z2,zrel | RMSE):\n');
for j=1:3
    t=pick(j);
    fprintf('  %-12s %+5.2f %+5.2f %+5.2f | %5.2f  %s tr%d\n', pred_names{j}, ...
        Z(t,1),Z(t,2),Z(t,3), YF(t), fields{SESS(t)}, TRI(t));
end

%% ══ PANEL A: exemplar trials (1×3, Fig-3 corner-axis style) ═════════════════
titA = {'Initial deviation','Motion','Rel 2-4 Hz'};   % state display names
disp_pre = 2; disp_post = 5;
tvec  = (-disp_pre : 1/Fs : disp_post).';
dcols_at = @(c0d) (c0d - disp_pre*Fs) : (c0d + disp_post*Fs);   % onset col varies per buffer type
% shared y-scale across the 3 traces
gmn=inf; gmx=-inf;
for j=1:3
    dkj = mouse.(fields{SESS(pick(j))}).data;
    [dbj, c0dj] = pick_pwc(dkj, c0_l, c0_p);
    seg = dbj(TRI(pick(j)), dcols_at(c0dj));
    gmn=min(gmn,min(seg)); gmx=max(gmx,max(seg));
end
pad = 0.10*(gmx-gmn); yl = [gmn-pad, gmx+pad];

figA = paperFig(8.4, 4.2);
tlA  = tiledlayout(figA,1,3,'TileSpacing','compact','Padding','compact');
for j=1:3
    t   = pick(j); dk = mouse.(fields{SESS(t)}).data; sj = mouse.(fields{SESS(t)});
    if isfield(sj,'d') && isfield(sj.d,'ref') && ~isempty(sj.d.ref); ref = sj.d.ref; else; ref = -5; end
    [dbt, c0dt] = pick_pwc(dk, c0_l, c0_p); dcols = dcols_at(c0dt);
    trace = dbt(TRI(t), dcols);
    ax = nexttile(tlA); hold(ax,'on');
    xlim(ax,[-disp_pre disp_post]); ylim(ax,yl);
    addStimPatch(ax, 0, 3);                                   % laser window, Fig-3 grey
    plot(ax,tvec([1 end]),[ref ref],'--','Color',[0.35 0.35 0.35],'LineWidth',PS.lw_ref);
    mtr = mean(dbt(:,dcols),1,'omitnan');                     % this session's trial-average CL response
    plot(ax,tvec,mtr,'-','Color',[0.60 0.60 0.60],'LineWidth',1.0);
    plot(ax,tvec,trace,'-','Color',col(j,:),'LineWidth',PS.lw_mean);
    plot(ax,0,dk.wcDfk(TRI(t),c0),'o','MarkerSize',3,'MarkerFaceColor',col(j,:),'MarkerEdgeColor','k','LineWidth',0.4);
    uistack(findobj(ax,'Type','line'),'top');                 % data over patch
    title(ax,titA{j},'FontSize',PS.fs,'FontWeight','bold','Color',col(j,:));
    if j==1, text(ax,0.30,0.90,'avg trial','Units','normalized','FontSize',4.5,'FontWeight','bold','Color',[0.55 0.55 0.55]); end
    text(ax,0.04,0.08,sprintf('RMSE %.1f',YF(t)),'Units','normalized', ...
        'FontSize',5,'FontWeight','bold','Color',[0.15 0.15 0.15]);
    if j==1                                                   % scale bars only on the first
        paperAxes(ax,'XLength',1,'YLength',5,'XLabel','1 s','YLabel','5%');
    else                                                      % shared scale -> bars suppressed
        paperAxes(ax,'XLength',0,'YLength',0);
    end
    hold(ax,'off');
end
try, paperExport(figA, fullfile(outdir,'f4_1A_error_states.pdf'));
catch, try, paperExport(figA, fullfile(outdir,'f4_1A_error_states_avg.pdf')); catch ME, warning('[F4B] skip A (%s)',ME.message); end; end

%% ══ PANEL B: unique R^2 by state (state-coloured; early tint / late full hue) ═
staten  = {'init dev','motion','2-4 Hz'};
lighten = @(c) c + (1-c)*0.55;                    % early-window tint of a state hue
figB = paperFig(5, 4.2); axB = axes(figB); hold(axB,'on');
bw = 0.34; xoff = 0.19; ymax = max(PrCI(:))*1.14;
for g=1:3
    ce = lighten(col(g,:)); cl = col(g,:);        % early tint / late full
    rectangle(axB,'Position',[g-xoff-bw/2, 0, bw, max(Pr(g,1),1e-4)],'FaceColor',ce,'EdgeColor','none');
    rectangle(axB,'Position',[g+xoff-bw/2, 0, bw, max(Pr(g,2),1e-4)],'FaceColor',cl,'EdgeColor','none');
    errorbar(axB, g-xoff, Pr(g,1), Pr(g,1)-PrCI(g,1,1), PrCI(g,1,2)-Pr(g,1),'k','LineStyle','none','LineWidth',0.6,'CapSize',2.5);
    errorbar(axB, g+xoff, Pr(g,2), Pr(g,2)-PrCI(g,2,1), PrCI(g,2,2)-Pr(g,2),'k','LineStyle','none','LineWidth',0.6,'CapSize',2.5);
    text(axB, g, -0.045*ymax, staten{g},'Color',col(g,:),'FontSize',PS.fs,'FontWeight','bold', ...
        'HorizontalAlignment','center','VerticalAlignment','top');
end
xlim(axB,[0.45 3.55]); ylim(axB,[0 ymax]);
set(axB,'XTick',[],'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight','bold');
ylabel(axB,'R^2 explained','FontSize',PS.fs,'FontWeight','bold');
% window shade legend (generic light/dark = early/late)
xL=0.60; yT=ymax*0.99; sw=0.15; sh=ymax*0.05;
rectangle(axB,'Position',[xL yT-sh sw sh],'FaceColor',[0.72 0.72 0.72],'EdgeColor','none');
text(axB,xL+sw+0.06,yT-sh/2,'0-1 s','FontSize',4.5,'FontWeight','bold','Color',[0.35 0.35 0.35],'VerticalAlignment','middle');
rectangle(axB,'Position',[xL yT-2.5*sh sw sh],'FaceColor',[0.35 0.35 0.35],'EdgeColor','none');
text(axB,xL+sw+0.06,yT-2.0*sh,'1-3 s','FontSize',4.5,'FontWeight','bold','Color',[0.35 0.35 0.35],'VerticalAlignment','middle');
text(axB,3.5,yT,sprintf('R^2_{full} %.2f / %.2f',Rfull(1),Rfull(2)),'FontSize',4.5,'FontWeight','bold', ...
    'Color',[0.55 0.55 0.55],'HorizontalAlignment','right','VerticalAlignment','top');
hold(axB,'off');
try, paperExport(figB, fullfile(outdir,'f4_1C_uniqueR2.pdf')); catch ME, warning('[F4B] skip B (%s)',ME.message); end

% [Shared-variance / commonality panel REMOVED 2026-09-11 -- user: not helpful.
%  Row-1 variance story = the two-window unique-R^2 bars (Panel B, f4_1C_uniqueR2).
%  The one real predictor overlap (init-dev & 2-4 Hz, r=-0.23, commonality ~ -0.06 =
%  suppression) is a caption note, not a panel. Numbers live in RESEARCH.md 2026-09-11.]

%% ══ PANEL C: delta robustness (supplementary) ══════════════════════════════
figC = paperFig(6, 4.5); axC = axes(figC); hold(axC,'on');
yline(axC,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5,'HandleVisibility','off');
hc = bar(axC, Drob, 'grouped','EdgeColor','none'); hc(1).FaceColor=col_e; hc(2).FaceColor=col_l;
set(axC,'XTick',1:numel(del_lbl),'XTickLabel',del_lbl,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xtickangle(axC,20);
ylabel(axC,'Delta unique R^2','FontSize',6,'FontWeight','bold');
lg=legend(axC,hc,{'0-1 s','1-3 s'},'FontSize',5,'Box','off','Location','northeast'); lg.ItemTokenSize=[6 6];
title(axC,'Delta effect vs magnitude control','FontSize',6,'FontWeight','bold');
hold(axC,'off');
try, paperExport(figC, fullfile(outdir,'f4_1S_delta_robust.pdf')); catch ME, warning('[F4B] skip S (%s)',ME.message); end

%% ══ PANEL T: frequency-band specificity (relative power) ════════════════════
figT = paperFig(6, 4.5); axT = axes(figT); hold(axT,'on');
yline(axT,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5,'HandleVisibility','off');
ht = bar(axT, Dband, 'grouped','EdgeColor','none'); ht(1).FaceColor=col_e; ht(2).FaceColor=col_l;
set(axT,'XTick',1:nB,'XTickLabel',band_lbl,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(axT,'band (Hz)','FontSize',6,'FontWeight','bold');
ylabel(axT,'unique R^2','FontSize',6,'FontWeight','bold');
lg=legend(axT,ht,{'0-1 s','1-3 s'},'FontSize',5,'Box','off','Location','northeast'); lg.ItemTokenSize=[6 6];
title(axT,'Frequency-band specificity','FontSize',6,'FontWeight','bold');
hold(axT,'off');
try, paperExport(figT, fullfile(outdir,'f4_1T_bands.pdf')); catch ME, warning('[F4B] skip T (%s)',ME.message); end

%% ── cache ───────────────────────────────────────────────────────────────────
save(fullfile('data','f4_partB_panels.mat'), ...
    'Pr','PrCI','Rfull','Drob','Dband','band_lbl','pred_names','out_names','n','nS', ...
    'X1','X2','Xrel','Xdel','Xbnd','YE','YL','YF','SESS','TRI','pick');
fprintf('\n[F4B] exported 4 paper panels -> %s\n', outdir);

% ── local helper ─────────────────────────────────────────────────────────────
function t = localBestIso(Z, idx, j)
% Best isolating trial for factor j within pooled indices idx:
% highest z on j among trials that are low (<=0.5) on the other two factors.
oth  = setdiff(1:3, j);
cand = idx(Z(idx,oth(1))<=0.5 & Z(idx,oth(2))<=0.5);
if isempty(cand), cand = idx; end
[~,mi] = max(Z(cand,j));
t = cand(mi);
end

function [dbuf, c0d] = pick_pwc(dk, c0_l, c0_p)
% CL pre-buffered dFk trace + its onset column, tolerating the cache field rot:
% current caches store pwcDfk (10 s pre, onset col c0_p=351); older ones stored the
% legacy pwcDfk_l (3 s pre, onset col c0_l=106). Mirrors the f4_row2_quartiles.m
% fallback so the delta state needs no cache rebuild (RESEARCH 2026-09-12).
if isfield(dk,'pwcDfk_l') && ~isempty(dk.pwcDfk_l)
    dbuf = dk.pwcDfk_l; c0d = c0_l;
elseif isfield(dk,'pwcDfk') && ~isempty(dk.pwcDfk)
    dbuf = dk.pwcDfk;   c0d = c0_p;
else
    dbuf = []; c0d = NaN;
end
end
