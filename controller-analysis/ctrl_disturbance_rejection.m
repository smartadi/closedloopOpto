% ctrl_disturbance_rejection.m -- CL vs OL disturbance rejection, per-session + pooled.  [DISTREJ]
%
% The optogenetic laser is the DISTURBANCE; the question is whether the closed-loop controller
% rejects it and holds the readout at the reference (d.ref = -5 %dF/F) better than open loop.
%
% METRIC (locked, RESEARCH 2026-07-16 / controller-analysis CLAUDE.md): per-trial RMSE of the
% readout dFk to the reference, sample-normalised (%dF/F). Two windows on the trial slice ncDfk/
% wcDfk (col 36 = onset t=0, col 71 = +1 s, col 141 = +3 s @35 Hz):
%    [+1,+3] s  (cols 71:141)  PRIMARY -- disturbance-rejection window, skips the inhibitory transient
%    [0,+3]  s  (cols 36:141)  secondary -- full post-onset window (reported alongside)
% OL = no-controller trials (data.nc), CL = with-controller trials (data.wc).
%
% POOLING (user 2026-09-07): SESSION is the unit. Each of the 13 controller sessions (m1..m13,
% AL_0033+AL_0039; the 2026-07 new mice m14/m15 are a different rig build and excluded) contributes
% ONE mean OL and ONE mean CL RMSE; the pooled test is a Wilcoxon SIGNED-RANK on those 13 pairs,
% and the pooled effect is the median across-session ratio OL/CL (>1 => CL rejects better). A
% pooled-trial rank-sum is printed as a secondary, pseudoreplicated cross-check only.
%
% Per-session panel also carries a within-session rank-sum (OL trials vs CL trials).
% PNG only (not a committed paper panel yet). USAGE: run load_sessions.m, then this.

assert(exist('mouse','var') && exist('fields','var'), '[DISTREJ] run load_sessions.m first.');

SESS   = 1:numel(fields);               % all loaded sessions incl. new-rig m14/m15 (user "add al48 al51" 2026-09-07)
ref    = -5;
c0=36; c1=71; c2=141;                   % onset / +1 s / +3 s columns in ncDfk/wcDfk
colOL  = [0.85 0.16 0.14];              % OL = red (locked scheme)
colCL  = [0.13 0.34 0.79];              % CL = blue
here_dr = fileparts(mfilename('fullpath')); if isempty(here_dr); here_dr = fullfile(pwd,'controller-analysis'); end
figdir  = fullfile(here_dr,'..','paper','images','figure4');   % Fig-4 Block A (moved from figure3/ 2026-09-07)

R = struct('k',{},'sess',{},'nOL',{},'nCL',{}, ...
           'OL13',{},'CL13',{},'r13',{},'p13',{},'OL03',{},'CL03',{},'r03',{}, ...
           'olTr13',{},'clTr13',{});
for k = SESS
    M = mouse.(fields{k}); if ~isfield(M,'data'), continue; end; d = M.data;
    if ~isfield(d,'ncDfk') || ~isfield(d,'wcDfk') || isempty(d.ncDfk) || isempty(d.wcDfk), continue; end
    olW = sqrt(mean((d.ncDfk(:,c1:c2) - ref).^2, 2));   % per-trial RMSE, [+1,+3]s
    clW = sqrt(mean((d.wcDfk(:,c1:c2) - ref).^2, 2));
    olF = sqrt(mean((d.ncDfk(:,c0:c2) - ref).^2, 2));   % per-trial RMSE, [0,+3]s
    clF = sqrt(mean((d.wcDfk(:,c0:c2) - ref).^2, 2));
    r = struct();                                       % fresh (avoid stale field order across runs)
    r.k=k; r.sess=sprintf('%s_%s%s',M.mn,M.td(6:7),M.td(9:10));
    r.nOL=numel(olW); r.nCL=numel(clW);
    r.OL13=mean(olW); r.CL13=mean(clW); r.r13=r.OL13/r.CL13;
    r.p13 = local_ranksum(olW, clW);                    % within-session, OL vs CL trials
    r.OL03=mean(olF); r.CL03=mean(clF); r.r03=r.OL03/r.CL03;
    r.olTr13=olW(:); r.clTr13=clW(:);
    R(end+1)=r; %#ok<AGROW>
end
nS = numel(R);
assert(nS>0,'[DISTREJ] no sessions with OL+CL trials found.');

% ---- pooled stats (SESSION as unit) -----------------------------------------------------------
OLs=[R.OL13]; CLs=[R.CL13];  d13 = OLs-CLs;
p_paired13 = local_signrank(OLs, CLs);
ratios13   = OLs./CLs;  medR13 = median(ratios13);
OLs0=[R.OL03]; CLs0=[R.CL03];  p_paired03 = local_signrank(OLs0,CLs0); medR03=median(OLs0./CLs0);
% secondary pooled-trial rank-sum (pseudoreplicated)
allOL=vertcat(R.olTr13); allCL=vertcat(R.clTr13); p_pool_trials=local_ranksum(allOL,allCL);

fprintf('\n================ DISTURBANCE REJECTION (ref=%g, RMSE to ref) ================\n',ref);
fprintf('%-4s %-16s %5s %5s | %6s %6s %5s %8s | %6s %6s %5s\n', ...
    'k','session','nOL','nCL','OL_13','CL_13','R_13','p_with','OL_03','CL_03','R_03');
for i=1:nS
    r=R(i);
    fprintf('%-4d %-16s %5d %5d | %6.3f %6.3f %5.2f %8.1g | %6.3f %6.3f %5.2f\n', ...
        r.k,r.sess,r.nOL,r.nCL,r.OL13,r.CL13,r.r13,r.p13,r.OL03,r.CL03,r.r03);
end
nBetter13 = sum(ratios13>1);
fprintf(['\n[POOLED, n=%d sessions, paired signed-rank]\n' ...
    '  [+1,+3]s : OL %.3f+-%.3f  vs  CL %.3f+-%.3f  | median ratio %.2fx | p=%.3g | CL better in %d/%d\n' ...
    '  [0,+3]s  : OL %.3f+-%.3f  vs  CL %.3f+-%.3f  | median ratio %.2fx | p=%.3g\n' ...
    '  (secondary) pooled-trial rank-sum [+1,+3]s: p=%.3g  (%d OL vs %d CL trials, pseudoreplicated)\n'], ...
    nS, mean(OLs),std(OLs)/sqrt(nS), mean(CLs),std(CLs)/sqrt(nS), medR13, p_paired13, nBetter13,nS, ...
    mean(OLs0),std(OLs0)/sqrt(nS), mean(CLs0),std(CLs0)/sqrt(nS), medR03, p_paired03, ...
    p_pool_trials, numel(allOL), numel(allCL));

% ================ FIGURE 1 : per-session OL vs CL ============================================
f1 = local_fig(9,5);
ax1 = axes(f1,'Units','normalized','Position',[0.11 0.17 0.86 0.74]); hold(ax1,'on');
x = 1:nS;
for i=1:nS
    plot(ax1,[x(i) x(i)],[R(i).OL13 R(i).CL13],'-','Color',[0.75 0.75 0.78],'LineWidth',0.8);
end
eOL = arrayfun(@(r) std(r.olTr13)/sqrt(r.nOL), R);
eCL = arrayfun(@(r) std(r.clTr13)/sqrt(r.nCL), R);
hOL = errorbar(ax1,x,OLs,eOL,'o','Color',colOL,'MarkerFaceColor',colOL,'MarkerSize',5,'CapSize',3,'LineStyle','none');
hCL = errorbar(ax1,x,CLs,eCL,'o','Color',colCL,'MarkerFaceColor',colCL,'MarkerSize',5,'CapSize',3,'LineStyle','none');
set(ax1,'XTick',x,'XTickLabel',{R.sess},'XTickLabelRotation',45,'FontSize',6.5);
ylabel(ax1,'RMSE to ref (%\DeltaF/F), [+1,+3]s','FontSize',7);
xlim(ax1,[0.5 nS+0.5]); yl1=ylim(ax1); ylim(ax1,[yl1(1) yl1(2)+0.25*diff(yl1)]);
title(ax1,sprintf('Disturbance rejection per session (median %.2f\\times, p=%.2g)',medR13,p_paired13),'FontSize',8);
legend([hOL hCL],{'OL (no controller)','CL (controller)'},'Box','off','Location','northeast','FontSize',6.5);
local_save(f1, fullfile(figdir,'disturbance_rejection_persession.png'));

% ================ FIGURE 2 : pooled paired slope ============================================
f2 = local_fig(5,5);
ax2 = axes(f2,'Units','normalized','Position',[0.20 0.15 0.74 0.76]); hold(ax2,'on');
jit = (rand(1,nS)-0.5)*0;              % no jitter (deterministic); keep endpoints on 1 and 2
for i=1:nS
    plot(ax2,[1 2],[R(i).OL13 R(i).CL13],'-','Color',[0.72 0.72 0.75],'LineWidth',0.8);
    plot(ax2,1,R(i).OL13,'o','Color',colOL,'MarkerFaceColor',colOL,'MarkerSize',4);
    plot(ax2,2,R(i).CL13,'o','Color',colCL,'MarkerFaceColor',colCL,'MarkerSize',4);
end
mOL=mean(OLs); mCL=mean(CLs); sOL=std(OLs)/sqrt(nS); sCL=std(CLs)/sqrt(nS);
errorbar(ax2,0.82,mOL,sOL,'o','Color','k','MarkerFaceColor',colOL,'MarkerSize',8,'LineWidth',1.4,'CapSize',6);
errorbar(ax2,2.18,mCL,sCL,'o','Color','k','MarkerFaceColor',colCL,'MarkerSize',8,'LineWidth',1.4,'CapSize',6);
plot(ax2,[0.82 2.18],[mOL mCL],'k-','LineWidth',1.6);
set(ax2,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontSize',8); xlim(ax2,[0.4 2.6]);
ylabel(ax2,'RMSE to ref (%\DeltaF/F), [+1,+3]s','FontSize',7.5);
yl=ylim(ax2); ylim(ax2,[yl(1) yl(2)+0.22*diff(yl)]); yl=ylim(ax2);
text(ax2,1.5,yl(2)-0.02*diff(yl),sprintf('p=%.2g   median %.2f\\times   n=%d',p_paired13,medR13,nS), ...
    'HorizontalAlignment','center','VerticalAlignment','top','FontSize',7);
title(ax2,'Pooled (session-paired)','FontSize',8);
local_save(f2, fullfile(figdir,'disturbance_rejection_pooled.png'));

% ---- PAPER PANEL (PDF, paper style) of the pooled paired plot (format still TBD with user) -----
fp = local_fig(4.5,5);
axp = axes(fp,'Units','normalized','Position',[0.26 0.15 0.70 0.74]); hold(axp,'on');
for i=1:nS; plot(axp,[1 2],[R(i).OL13 R(i).CL13],'-','Color',[0.72 0.72 0.75],'LineWidth',0.5); end
plot(axp,ones(1,nS),OLs,'o','Color',colOL,'MarkerFaceColor',colOL,'MarkerSize',3);
plot(axp,2*ones(1,nS),CLs,'o','Color',colCL,'MarkerFaceColor',colCL,'MarkerSize',3);
errorbar(axp,0.83,mOL,sOL,'o','Color','k','MarkerFaceColor',colOL,'MarkerSize',6,'LineWidth',1.2,'CapSize',5);
errorbar(axp,2.17,mCL,sCL,'o','Color','k','MarkerFaceColor',colCL,'MarkerSize',6,'LineWidth',1.2,'CapSize',5);
plot(axp,[0.83 2.17],[mOL mCL],'k-','LineWidth',1.3);
set(axp,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontName','Arial','FontSize',6,'FontWeight','bold','LineWidth',0.75,'TickDir','out','Box','off');
xlim(axp,[0.5 2.5]); ylp=ylim(axp); ylim(axp,[ylp(1) ylp(2)+0.16*diff(ylp)]); ylp=ylim(axp);
ylabel(axp,'RMSE to ref (%\DeltaF/F)','FontName','Arial','FontSize',6,'FontWeight','bold');
text(axp,1.5,ylp(2),sprintf('%.2f\\times, p=%.1g',medR13,p_paired13),'HorizontalAlignment','center', ...
    'VerticalAlignment','top','FontName','Arial','FontSize',6,'FontWeight','bold');
paperExport(fp, fullfile(figdir,'disturbance_rejection_pooled_panel.pdf'));

DISTREJ = struct('R',R,'p_paired13',p_paired13,'medR13',medR13,'p_paired03',p_paired03, ...
                 'medR03',medR03,'p_pool_trials',p_pool_trials,'ref',ref,'nS',nS);
fprintf('\n[DISTREJ] figures -> %s\n', figdir);

% ---- local helpers (graceful without toolboxes / paper helpers) -------------------------------
function p = local_signrank(a,b)
    try, p = signrank(a,b); catch, [~,p] = ttest(a,b); end     % paired
end
function p = local_ranksum(a,b)
    try, p = ranksum(a,b); catch, [~,p] = ttest2(a,b); end     % unpaired
end
function f = local_fig(wcm,hcm)
    if exist('paperFig','file'), f = paperFig(wcm,hcm); else
        f = figure('Color','w','Units','centimeters','Position',[3 3 wcm hcm]); end
end
function local_save(f,p)
    if ~exist(fileparts(p),'dir'), mkdir(fileparts(p)); end
    exportgraphics(f,p,'Resolution',300);
    fprintf('[DISTREJ]   %s\n',p);
end
