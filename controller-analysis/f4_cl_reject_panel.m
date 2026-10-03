function f4_cl_reject_panel()
% F4_CL_REJECT_PANEL  Fig-4 4H: CL disturbance rejection, EVERY reacher session.
% Per session: geometric mean RR +/- 1 SD (log) of per-trial RR = ||A-r||^2/||D||^2
% (settled 1-3 s, leak-corrected D). RR<1 = rejection. Stat = session-aware LMM
% (log(RR) ~ 1 + (1|mouse)+(1|mouse:session)); band = LMM geomean RR + 95% CI.
% Non-reachers (settled |mean A_CL-ref|>1.5) excluded. Run f4_cl_reject_lmm.m first.
here = fileparts(mfilename('fullpath'));
if isempty(here); here = fullfile(pwd,'controller-analysis'); end
dataDir = fullfile(here,'data');  figDir = fullfile(here,'..','paper','images','figure4');  % working copy; final panel via paper_final_mirror
if ~exist(figDir,'dir'); mkdir(figDir); end
addpath(fullfile(here,'..','utils'));
PS = paperStyle(); S = jnStyle();
L = load(fullfile(dataDir,'f4_cl_reject_lmm.mat'));   % T (logRR,sess,mouse), est, se, p1
T = L.T;  gmLMM = exp(L.est);  ciLMM = exp([L.est-1.96*L.se, L.est+1.96*L.se]);

u = unique(cellstr(T.sess),'stable');  nS = numel(u);
gm=nan(nS,1); lo=nan(nS,1); hi=nan(nS,1); nt=nan(nS,1);
for i=1:nS
    lr = T.logRR(T.sess==u{i});  m=mean(lr); s=std(lr);
    gm(i)=exp(m); lo(i)=exp(m-s); hi(i)=exp(m+s); nt(i)=numel(lr);
end
% ---- x labels = m<mouse#><session-letter> (user 2026-09-28), replacing the date tag ----
% mouse# = ascending unique mouse by AL number; letter = session order (by tag/date) within mouse.
mtok  = regexp(u,'^AL_\d+','match','once');     % mouse token per session, e.g. 'AL_0033'
umice = unique(mtok);                            % sorted -> AL_0033=m1, AL_0039=m2, AL_0048=m3 ...
lab = strings(nS,1);
for mi=1:numel(umice)
    sIdx = find(strcmp(mtok,umice{mi}));         % this mouse's sessions
    [~,so]=sort(u(sIdx)); sIdx=sIdx(so);         % chronological (tag) order within mouse
    for k=1:numel(sIdx), lab(sIdx(k))=sprintf('Mouse%d%c',mi,'a'+k-1); end
end
[gm,ord]=sort(gm); lo=lo(ord); hi=hi(ord); nt=nt(ord); lab=lab(ord);

fig = jnFig(jnPanelWidth('double',3), S.rowH);  ax=axes(fig); hold(ax,'on');   % 5.53 x 3.3 cm
% LMM CI band + geomean
patch(ax,[0.3 nS+0.7 nS+0.7 0.3],[ciLMM(1) ciLMM(1) ciLMM(2) ciLMM(2)],[0.85 0.90 0.98],'EdgeColor','none');
plot(ax,[0.3 nS+0.7],gmLMM*[1 1],'-','Color',PS.col_cl,'LineWidth',1.0);
% RR = 1 (no rejection)
plot(ax,[0.3 nS+0.7],[1 1],'--','Color',[0.55 0.55 0.55],'LineWidth',PS.lw_ref);
% per-session geometric mean +/- 1 SD (log)
for i=1:nS
    plot(ax,[i i],[lo(i) hi(i)],'-','Color',PS.col_cl,'LineWidth',0.9);
end
scatter(ax,1:nS,gm,20,PS.col_cl,'filled','MarkerEdgeColor','none');

set(ax,'YScale','log','XTick',1:nS,'XTickLabel',cellstr(lab),'XTickLabelRotation',45, ...
    'TickLabelInterpreter','none','FontSize',PS.fs,'FontWeight',PS.fw,'LineWidth',0.75,'TickDir','out','Box','off', ...
    'YTick',[0.25 0.5 1 2]);
xlim(ax,[0.3 nS+0.7]); ylim(ax,[0.22 2.9]);
ylabel(ax,'rejection ratio (RR)','FontSize',PS.fs,'FontWeight',PS.fw);   % self-explanatory words; RR=||A-r||^2/||D||^2 defined in caption
% title states the claim; a single significance star marks the LMM one-sided RR<1 test.
star = repmat('*',1,(L.p1<0.05)+(L.p1<0.01)+(L.p1<0.001)); if isempty(star), star='n.s.'; end
title(ax,sprintf('CL rejects disturbances %s',star));

jnAxes(ax);
paperExport(fig, fullfile(figDir,'f4_cl_reject_RR.pdf'));   % exact-page vector (Option 2)
paperExport(fig, fullfile(figDir,'f4_cl_reject_RR.png'));
fprintf('[f4-CL-REJECT] %d sessions, LMM geomean RR=%.2f [%.2f,%.2f], p=%.2g; per-session geomean range %.2f-%.2f\n', ...
    nS, gmLMM, ciLMM(1), ciLMM(2), L.p1, min(gm), max(gm));
end
