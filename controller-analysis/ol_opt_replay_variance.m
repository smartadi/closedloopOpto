% ol_opt_replay_variance.m
% Across-trial variance comparison for the AL_0041 OL-optimized replay set.
% Conditions: OL (mode 0), CL (mode 1), replay (mode 0.5).
% Variance = var across trials at each time sample. Summarised over the
% SETTLED stim window [+0.15, 3.0] s (skips the ~2-3-frame laser onset bleed);
% baseline window [-3, -0.15] s for the stim/baseline ratio.
% Outputs to paper/images/ol_opt_replay/.
clear; clc; close all;
here = fileparts(mfilename('fullpath')); if isempty(here); here=pwd; end
root = fileparts(here); addpath(genpath(fullfile(root,'utils')));
outDir = fullfile(root,'paper','images','ol_opt_replay'); if ~exist(outDir,'dir'); mkdir(outDir); end

S = { 'AL_0041','2026-03-16',2; 'AL_0041','2026-03-19',1; ...
      'AL_0041','2026-03-23',5; 'AL_0041','2026-03-24',1 };
Fs=35; PRE_S=3; POST_S=3; modes=[0 1 0.5];
names={'OL','CL','replay'}; cols=[1 0 0;0 .5 0;1 .5 0];
SKIP_S = 0.15;                                  % skip onset bleed

nS=size(S,1);
Vstim = nan(nS,3); Vbase = nan(nS,3);           % mean across-trial variance
VC = cell(nS,3);                                % variance time-courses
tags = cell(nS,1);

for s=1:nS
    mn=S{s,1}; td=S{s,2}; en=S{s,3}; tags{s}=sprintf('%s_e%d',td,en);
    d=loadData(expPath(mn,td,en),mn,td,en); nB=numel(d.timeBlue);
    y=d.states(:)'; y=y(1:nB); ip=d.input_params; kk=round(ip(:,2)); md=ip(:,3);
    dur=d.params.dur;
    nPre=round(PRE_S*Fs); nStim=round(dur*Fs); nPost=round(POST_S*Fs);
    tax=(-nPre:nStim+nPost)/Fs;
    stimIx = tax>=SKIP_S & tax<=dur;
    baseIx = tax>=-PRE_S & tax<=-SKIP_S;
    for c=1:3
        idx=find(md==modes(c)); M=[];
        for j=1:numel(idx); i0=kk(idx(j));
            if i0-nPre>=1 && i0+nStim+nPost<=nB; M(end+1,:)=y(i0-nPre:i0+nStim+nPost); end %#ok<AGROW>
        end
        v=var(M,0,1); VC{s,c}=v;
        Vstim(s,c)=mean(v(stimIx)); Vbase(s,c)=mean(v(baseIx));
    end
    fprintf('%s  stim-window across-trial var  OL=%.2f  CL=%.2f  replay=%.2f\n',tags{s},Vstim(s,1),Vstim(s,2),Vstim(s,3));
end
Vratio = Vstim./Vbase;

% ================= FIGURE =================
f=figure('Color','w','Position',[60 60 1250 420]);
tl=tiledlayout(f,1,3,'TileSpacing','compact','Padding','compact');

% (a) grouped bar: stim-window across-trial variance
ax=nexttile(tl,1); b=bar(ax,Vstim,'grouped'); for c=1:3; b(c).FaceColor=cols(c,:); end
set(ax,'XTickLabel',strrep(tags,'_','\_'),'TickDir','out'); box(ax,'off');
ylabel(ax,'across-trial variance (%\DeltaF/F)^2'); title(ax,'(a) stim window [+0.15, 3] s','FontWeight','normal');
legend(ax,names,'Location','northoutside','Orientation','horizontal','Box','off');

% (b) stim/baseline variance ratio (controls for baseline state differences)
ax=nexttile(tl,2); b=bar(ax,Vratio,'grouped'); for c=1:3; b(c).FaceColor=cols(c,:); end
yline(ax,1,':','Color',[.4 .4 .4],'HandleVisibility','off');
set(ax,'XTickLabel',strrep(tags,'_','\_'),'TickDir','out'); box(ax,'off');
ylabel(ax,'stim / baseline variance ratio'); title(ax,'(b) variance change vs pre-stim','FontWeight','normal');

% (c) pooled: mean +- SEM across sessions per condition (stim window)
ax=nexttile(tl,3); hold(ax,'on'); box(ax,'off');
mu=mean(Vstim,1); se=std(Vstim,0,1)/sqrt(nS);
for c=1:3
    bar(ax,c,mu(c),0.6,'FaceColor',cols(c,:),'EdgeColor','none');
    errorbar(ax,c,mu(c),se(c),'k','LineWidth',1.2,'CapSize',8);
    plot(ax,c+zeros(nS,1),Vstim(:,c),'ko','MarkerFaceColor','w','MarkerSize',5);
end
set(ax,'XTick',1:3,'XTickLabel',names,'TickDir','out'); xlim(ax,[0.5 3.5]);
ylabel(ax,'across-trial variance (%\DeltaF/F)^2'); title(ax,'(c) session mean \pm SEM','FontWeight','normal');

sgtitle(f,'AL\_0041 OL-optimized replay: trial-to-trial variance (OL vs CL vs replay)','FontWeight','bold','FontSize',13);
outPng=fullfile(outDir,'SUMMARY_variance_across_sessions.png');
exportgraphics(f,outPng,'Resolution',300);
fprintf('\n-> %s\n',outPng);

% quick paired sign test CL<OL and CL<replay on stim-window variance
fprintf('\nCL vs OL   : CL lower in %d/%d sessions\n', sum(Vstim(:,2)<Vstim(:,1)), nS);
fprintf('CL vs replay: CL lower in %d/%d sessions\n', sum(Vstim(:,2)<Vstim(:,3)), nS);
disp('DONE');
