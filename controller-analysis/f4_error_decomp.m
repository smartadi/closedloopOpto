% controller-analysis/f4_error_decomp.m
% Fig-4 BLOCK 2 -- error-decomposition model. How much of the CL tracking error (RMSE
% to ref) is explained by the four pre-stimulus state factors, UNIQUELY and COMBINED,
% resolved by error window (early 0-1 s transient / settled 1-3 s hold), computed BOTH
% pooled across all motion-available CL trials AND per session.
%
% FOUR FACTORS (user 2026-09-15):
%   F1 init-dev   = |dF/F(onset) - ref|
%   F2 motion     = mean z-motion, -2 s -> stim end (f4_motion_stat; was ^2 until 2026-10-02)
%   F3 rel 2-4Hz  = bandpow(2-4)/bandpow(0.4-10), -2 s -> stim end   (power-independent)
%   F4 abs delta  = log10 bandpow(1-4 Hz), -2 s -> stim end          (magnitude; confounded)
%
% TWO PANELS:
%   f4_decomp_unique.pdf   -- unique R^2 of each factor (full model minus drop-one),
%                             grouped by window, pooled bar + per-session dots.
%   f4_decomp_combined.pdf -- combined R^2 of factor GROUPS (init+motion, rel+abs delta,
%                             all four = full model), grouped by window, pooled + per-session.
%
% Reuses the pool logic + bandpower of cl_rmse_factor_windows.m (kept in sync).
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;
PS = paperStyle(); setPaperDefaults();
root = 'C:\Users\aditya\Documents\projects\brain_paper';
outfig  = fullfile(root,'paper','images','figure4');
outfig2 = fullfile(root,'paper','images','figure4');      % working copy (main-text sep panel); final via paper_final_mirror
outsupp = fullfile(root,'paper','images','supplementary');   % non-main decomp panels (user 2026-09-28)
outview = fullfile(root,'controller-analysis','_preview');
if ~exist(outfig,'dir');  mkdir(outfig);  end
if ~exist(outfig2,'dir'); mkdir(outfig2); end
if ~exist(outsupp,'dir'); mkdir(outsupp); end
if ~exist(outview,'dir'); mkdir(outview); end

% ---- constants (match cl_rmse_factor_windows.m) ----
Fs=35; c0=36; c0_mot=71; c0_l=106; mot_pre=2; spec_pre_s=2; spec_post_s=3;
% MOTION STATISTIC, shared with Fig-4 Row 2 (user, 2026-10-02): 'mean' primary | 'sq' secondary.
if ~exist('F4_MOT_STAT','var') || isempty(F4_MOT_STAT), F4_MOT_STAT = 'mean'; end
% STATE WINDOW, shared with Fig-4 Row 2 via utils/f4_state_window.m (2026-10-02):
% 'peri' (published, -2..+3 s) | 'pre2' (-2 s..onset) | 'pre1' (-1 s..onset).
if ~exist('F4_STATE_WIN','var') || isempty(F4_STATE_WIN), F4_STATE_WIN = 'peri'; end
W_state = f4_state_window(F4_STATE_WIN);
fprintf('[f4_error_decomp] state window: %s\n', W_state.label);
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10];
eE = c0 : c0+round(1*Fs);                 % 0 -> 1 s
lL = c0+round(1*Fs)+1 : c0+round(3*Fs);   % 1 -> 3 s
bandpow = @(seg, lo, hi) f4_bandpow(seg, Fs, lo, hi, W_state.bandpow);   % shared estimator
fitR2 = @(Xp, yp) 1 - sum((yp - [ones(size(Xp,1),1), Xp]*([ones(size(Xp,1),1), Xp]\yp)).^2) / ...
                      max(sum((yp - mean(yp)).^2), eps);

%% ── Pool CL trials (per-session tagged) ─────────────────────────────────────
X1=[];X2=[];Xrel=[];Xdel=[]; YE=[];YL=[]; SESS=[];
for k=1:numel(fields)
    s=mouse.(fields{k});
    if (isfield(s,'skip')&&s.skip)||~isfield(s,'data')||~s.has_motion; continue; end
    dk=s.data; if ~isfield(dk,'wcmotion'); continue; end
    ref=s.d.ref; dur=s.d.params.dur; nT=size(dk.wcDfk,1);
    x1=abs(dk.wcDfk(:,c0)-ref);
    assert(dur == 3, 'f4_error_decomp:dur', 'f4_state_window assumes dur = 3 s (got %g)', dur);
    mc = c0_mot + W_state.mot;  mc = mc(mc>=1 & mc<=size(dk.wcmotion,2));   % 'peri' == legacy 1:175
    % mean(z), via the SHARED utils/f4_motion_stat.m -- reconciled with Fig-4 Row 2
    % (user, 2026-10-02). Was mean(z^2); the window already matched Row 2 (cols 1:175,
    % -2.000 to +2.971 s, verified for all 15 sessions). F4_MOT_STAT='sq' for the secondary.
    x2=f4_motion_stat(dk.wcmotion(1:nT,mc), F4_MOT_STAT);
    % PRE-BUFFER: resolved per session (utils/pre_spec_buffer.m, 2026-10-02). No cache in
    % data/ still carries a `_l` buffer, so the hardcoded pwcDfk_l made this script dead.
    % c0_l now comes back as 106 or 351 to match whichever buffer exists; the window in
    % SECONDS is unchanged either way.
    [pbuf, c0_l] = pre_spec_buffer(dk, 'wc');
    sc = c0_l + W_state.spec;                % 'peri' == legacy c0_l-70 : c0_l+105
    assert(sc(1) >= 1 && sc(end) <= size(pbuf,2), 'f4_error_decomp:win', 'state window off the buffer');
    [xrel,xdel]=deal(nan(nT,1));
    for t=1:nT
        seg=double(pbuf(t,sc));
        xdel(t)=bandpow(seg,delta_bnd(1),delta_bnd(2));
        xrel(t)=bandpow(seg,hi_bnd(1),hi_bnd(2))/max(bandpow(seg,tot_bnd(1),tot_bnd(2)),eps);
    end
    yE=sqrt(mean((dk.wcDfk(1:nT,eE)-ref).^2,2));
    yL=sqrt(mean((dk.wcDfk(1:nT,lL)-ref).^2,2));
    m=nT;
    X1=[X1;x1(1:m)];X2=[X2;x2(1:m)];Xrel=[Xrel;xrel(1:m)];Xdel=[Xdel;xdel(1:m)]; %#ok<*AGROW>
    YE=[YE;yE(1:m)];YL=[YL;yL(1:m)];SESS=[SESS;repmat(k,m,1)];
end
ok=all(isfinite([X1 X2 Xrel Xdel YE YL]),2)&Xdel>0; f=@(v)v(ok);
[X1,X2,Xrel,Xdel,YE,YL,SESS]=deal(f(X1),f(X2),f(Xrel),f(Xdel),f(YE),f(YL),f(SESS));
Xall=[X1 X2 Xrel log10(Xdel)];                         % F1..F4 (abs delta as log10)
fac_lbl={'init-dev','motion','rel 2-4Hz','abs \delta'};
usess=unique(SESS); nS=numel(usess); n=numel(YE);
assert_pooled(n,  'f4_error_decomp CL trials');
assert_pooled(nS, 'f4_error_decomp motion sessions');
fprintf('[f4_error_decomp] %d CL trials, %d motion sessions.\n', n, nS);

%% ── R^2 machinery, run for THREE delta options ──────────────────────────────
% Columns of Xall: 1=init-dev 2=motion 3=rel-2-4Hz 4=abs-delta.
% Modes give the user options: keep only ONE delta, or BOTH.
Wout={YE,YL}; win_lbl={'0-1 s','1-3 s'};
col_e=[0.35 0.55 0.85]; col_l=[0.15 0.25 0.55];
minTr=12;   % 2026-09-28 (user): include EVERY motion session in the per-session decomp
            % (was 25, which silently dropped the 16-trial session AL_0033_0305 -> only 6 of 7).
            % 12 is a safe floor for a 3-4 factor per-session unique-R^2 fit.
modes = {'both','rel','abs'};
modeCols = {[1 2 3 4], [1 2 3], [1 2 4]};
modeFac  = {fac_lbl, fac_lbl([1 2 3]), fac_lbl([1 2 4])};
% combined groups per mode (indices into the mode's own column subset)
modeGrp  = {{[1 2],[3 4],[1 2 3 4]}, {[1 2],[1 2 3]}, {[1 2],[1 2 3]}};
modeGrpL = {{'init+motion','rel+abs \delta','all four'}, ...
            {'init+motion','all three'}, {'init+motion','all three'}};

% STATE COLOURS, shared with the exemplar strips (user, 2026-10-05: "for error comp
% plots re draw with the corrsponding state exemlar colors"). Same four RGBs as
% f4_state_exemplars_supp.m: init-dev, motion, rel 2-4 Hz, abs delta. Each bar then
% names its factor by colour as well as by tick label, so a reader can carry the
% identity straight across from the exemplar rows above it in the assembled figure.
% Moved ABOVE the mode loop (it used to be defined just before the 'sep' panel).
FCfac=[0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];

DEC = struct();   % stash per-mode results for the comparison + cache
for mi=1:numel(modes)
    mo=modes{mi}; cols=modeCols{mi}; fl=modeFac{mi}; nF=numel(cols);
    grp=modeGrp{mi}; grpL=modeGrpL{mi};
    Xm=Xall(:,cols);
    Up=nan(nF,2); Cp=nan(numel(grp),2);
    for w=1:2
        y=Wout{w}; Z=zscore(Xm); rf=fitR2(Z,y);
        for j=1:nF, Up(j,w)=rf-fitR2(Z(:,setdiff(1:nF,j)),y); end
        for g=1:numel(grp), Cp(g,w)=fitR2(Z(:,grp{g}),y); end
    end
    Us=nan(nF,2,nS); Cs=nan(numel(grp),2,nS); okS=false(nS,1);
    for si=1:nS
        ix=SESS==usess(si); if nnz(ix)<minTr; continue; end
        okS(si)=true; Xs=zscore(Xm(ix,:));
        for w=1:2
            y=Wout{w}(ix); rf=fitR2(Xs,y);
            for j=1:nF, Us(j,w,si)=rf-fitR2(Xs(:,setdiff(1:nF,j)),y); end
            for g=1:numel(grp), Cs(g,w,si)=fitR2(Xs(:,grp{g}),y); end
        end
    end
    nSok=nnz(okS);
    fprintf('\n==== MODE ''%s'' (%d factors) | UNIQUE R^2 (0-1 / 1-3), pooled ====\n',mo,nF);
    for j=1:nF, fprintf('  %-11s %6.3f %6.3f\n',fl{j},Up(j,1),Up(j,2)); end
    fprintf('  COMBINED:\n');
    for g=1:numel(grp), fprintf('  %-13s %6.3f %6.3f\n',grpL{g},Cp(g,1),Cp(g,2)); end
    % NON-MAIN decomp panels -> supplementary (only 'sep' unique-R^2 is the main-text panel).
    draw_grouped(Up, Us(:,:,okS), fl, {col_e,col_l}, win_lbl, 'unique R^2', ...
        sprintf('Unique R^2 [\\delta: %s] (n=%d, %d sess)',mo,n,nSok), PS, ...
        fullfile(outsupp,sprintf('f4_decomp_unique_%s.pdf',mo)), ...
        fullfile(outview,sprintf('f4_decomp_unique_%s.png',mo)));
    % SUPPLEMENTARY PANEL (2026-10-05): the same numbers, bare and narrow, for the
    % combined S6+S7 figure assembled in Illustrator. The wide titled version above
    % is kept because the current LaTeX still includes it; retire it once the
    % assembly replaces fig:f4_unique.
    % Width scales with the factor count so the BARS are the same size in all three
    % panels -- the panels themselves differ in width because 'both' has four factors
    % and the other two have three, which is the content, not an inconsistency.
    modeTag = {'rel + abs', 'rel only', 'abs only'};
    draw_grouped(Up, Us(:,:,okS), fl, {col_e,col_l}, win_lbl, 'unique R^2', '', PS, ...
        fullfile(outsupp,sprintf('supp_f4_unique_%s.pdf',mo)), ...
        fullfile(outview,sprintf('supp_f4_unique_%s.png',mo)), FCfac(cols,:), 1.05*nF+1.1, ...
        struct('bare',true,'tag',modeTag{mi},'hCm',2.8));
    draw_grouped(Cp, Cs(:,:,okS), grpL, {col_e,col_l}, win_lbl, 'combined R^2', ...
        sprintf('Combined R^2 [\\delta: %s]',mo), PS, ...
        fullfile(outsupp,sprintf('f4_decomp_combined_%s.pdf',mo)), ...
        fullfile(outview,sprintf('f4_decomp_combined_%s.png',mo)));
    DEC.(mo)=struct('Up',Up,'Cp',Cp,'Us',Us,'Cs',Cs,'okS',okS,'fac',{fl},'grp',{grpL},'nSok',nSok);
end

%% ── MODE 'sep': 4 bars, but rel & abs delta each in its OWN init+motion+delta model ──────────
% (user 2026-09-21) rel-2-4 and abs-delta are collinear, so a single 4-factor model makes them
% cannibalise each other (abs wins, rel -> 0). Here each delta's unique R^2 is taken over the
% SAME init+motion base but in its own 3-factor model, so both are shown "separately" without
% competing: u_init/u_motion from the rel model; u_rel from {init,motion,rel}; u_abs from
% {init,motion,abs}. This is the Panel-B main-text decomposition.
%   Xall cols: 1=init 2=motion 3=rel-2-4 4=abs-delta(log10)
sepU = @(Z,y) [ fitR2(Z(:,[1 2 3]),y)-fitR2(Z(:,[2 3]),y); ...   % init  (rel model)
                fitR2(Z(:,[1 2 3]),y)-fitR2(Z(:,[1 3]),y); ...   % motion(rel model)
                fitR2(Z(:,[1 2 3]),y)-fitR2(Z(:,[1 2]),y); ...   % rel   (unique over init+motion)
                fitR2(Z(:,[1 2 4]),y)-fitR2(Z(:,[1 2]),y) ];     % abs   (unique over init+motion)
Usep=nan(4,2);
for w=1:2, Usep(:,w)=sepU(zscore(Xall),Wout{w}); end
okSsep=false(nS,1); UsepS=nan(4,2,nS);
for si=1:nS
    ix=SESS==usess(si); if nnz(ix)<minTr; continue; end
    okSsep(si)=true; Zs=zscore(Xall(ix,:));
    for w=1:2, UsepS(:,w,si)=sepU(Zs,Wout{w}(ix)); end
end
nSsep=nnz(okSsep);
fprintf('\n==== MODE ''sep'' (each delta in its own init+motion+d model) | UNIQUE R^2 (0-1 / 1-3) ====\n');
for j=1:4, fprintf('  %-11s %6.3f %6.3f\n',fac_lbl{j},Usep(j,1),Usep(j,2)); end
draw_grouped(Usep, UsepS(:,:,okSsep), fac_lbl, {col_e,col_l}, win_lbl, 'unique R^2', ...
    sprintf('Unique R^2 (n=%d, %d sess)',n,nSsep), PS, ...
    fullfile(outfig2,'f4_decomp_unique_sep.pdf'), fullfile(outview,'f4_decomp_unique_sep.png'), FCfac, 5.5);
DEC.sep=struct('Up',Usep,'Us',UsepS,'okS',okSsep,'fac',{fac_lbl},'nSok',nSsep);

save(fullfile(root,'controller-analysis','data','f4_error_decomp.mat'), ...
    'DEC','usess','win_lbl','n','nS','minTr','fac_lbl');
% ---- standalone legend for the bare supplementary trio ----------------------
% The three panels above carry no legend so their crops stay comparable; the key is
% exported once and placed once. Grey swatches, because in these panels the bar
% COLOUR encodes the factor (x axis) and only the light/dark split encodes the window.
fLg = jnFig(3.0, 0.9); axLg = axes(fLg); hold(axLg,'on'); axis(axLg,'off');
h1 = patch(axLg, nan, nan, [.72 .72 .72], 'EdgeColor','none');
h2 = patch(axLg, nan, nan, [.35 .35 .35], 'EdgeColor','none');
lgS = legend([h1 h2], win_lbl, 'FontSize', PS.fs, 'Box','off', 'Location','west');
lgS.ItemTokenSize = [6 6];
paperExport(fLg, fullfile(outsupp,'supp_f4_unique_legend.pdf'));
fprintf('[f4_error_decomp] bare S7 trio + legend -> %s\n', outsupp);

fprintf('\n[f4_error_decomp] wrote unique+combined panels for %d delta modes -> %s\n', numel(modes), outfig);

%% ---- helpers ----
function draw_grouped(P, Ps, xlbl, wcol, wlbl, ylab, ttl, PS, pdfpath, pngpath, faceRGB, wCm, opt)
    % P: nItem x 2(win) pooled ; Ps: nItem x 2 x nSess per-session
    % faceRGB (optional): nItem x 3 base colours -> 0-1 s bar = lighter, 1-3 s = darker.
    % wCm (optional): figure width (cm).
    % opt (optional): .bare   - no title, no legend, no ylabel (supplementary panels
    %                           that are assembled side by side: three copies of the
    %                           same legend and y-label is noise, and a legend on one
    %                           panel only would change that panel's crop so the row
    %                           would no longer align. Set them once in Illustrator;
    %                           supp_f4_unique_legend.pdf carries the key.)
    %                 .tag    - short string burned in at the top-left, so a bare
    %                           panel can still be told from its siblings.
    %                 .hCm    - figure height (cm).
    if nargin<11, faceRGB=[]; end
    if nargin<13 || isempty(opt), opt=struct(); end
    bare = isfield(opt,'bare') && opt.bare;
    nI=size(P,1);
    if nargin<12 || isempty(wCm), wCm=max(6,1.7*nI+2); end
    hCm=3.3; if isfield(opt,'hCm') && ~isempty(opt.hCm), hCm=opt.hCm; end
    f=jnFig(wCm,hCm); ax=axes(f); hold(ax,'on');   % jn* v2 sizing
    yline(ax,0,'-','Color',[.6 .6 .6],'LineWidth',0.5,'HandleVisibility','off');
    hb=bar(ax,P,'grouped','EdgeColor','none');
    if ~isempty(faceRGB)
        lightC=1-0.55*(1-faceRGB); darkC=0.70*faceRGB;   % light = 0-1 s, dark = 1-3 s
        hb(1).FaceColor='flat'; hb(1).CData=lightC;
        hb(2).FaceColor='flat'; hb(2).CData=darkC;
    else
        hb(1).FaceColor=wcol{1}; hb(2).FaceColor=wcol{2};
    end
    nser=2;
    for w=1:nser   % 1 SD error bar on each bar (across-session spread), replaces scatter (user 2026-09-29)
        xE=hb(w).XEndPoints;               % exact grouped-bar centres for this series
        sd=nan(1,nI);
        for j=1:nI
            v=squeeze(Ps(j,w,:)); v=v(isfinite(v));
            if ~isempty(v); sd(j)=std(v); end
        end
        errorbar(ax,xE,P(:,w).',sd,'LineStyle','none','Color',[.25 .25 .25], ...
            'LineWidth',0.6,'CapSize',2,'HandleVisibility','off');
    end
    set(ax,'XTick',1:nI,'XTickLabel',xlbl,'Box','off','TickDir','out', ...
        'FontSize',PS.fs,'FontWeight',PS.fw,'TickLabelInterpreter','tex'); xtickangle(ax,18);
    if ~bare, ylabel(ax,ylab,'FontSize',PS.fs,'FontWeight',PS.fw); end
    if bare
        if isfield(opt,'tag') && ~isempty(opt.tag)
            % A SHORT TITLE, not text inside the axes. Burned in at the top-left it
            % landed on the y-axis and the first bar. All three panels get one, so
            % equal-height titles do not disturb their relative crops.
            title(ax,opt.tag,'FontSize',PS.fs,'FontWeight',PS.fw);
        end
        hold(ax,'off'); jnAxes(ax); paperExport(f,pdfpath); paperExport(f,pngpath); return
    end
    if ~isempty(faceRGB)   % neutral light/dark swatches for the window legend (bars are per-factor)
        h1=patch(ax,nan,nan,[.72 .72 .72],'EdgeColor','none'); h2=patch(ax,nan,nan,[.35 .35 .35],'EdgeColor','none');
        lg=legend([h1 h2],wlbl,'FontSize',PS.fs,'Box','off','Location','northeast');
    else
        lg=legend(ax,hb,wlbl,'FontSize',PS.fs,'Box','off','Location','northeast');
    end
    lg.ItemTokenSize=[6 6];
    title(ax,ttl,'FontSize',PS.fs,'FontWeight',PS.fw); hold(ax,'off');
    jnAxes(ax);
    paperExport(f,pdfpath); paperExport(f,pngpath);
end
function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg);
    w=hannwin(N).'; P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1);
    fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo & fr<hi));
end
