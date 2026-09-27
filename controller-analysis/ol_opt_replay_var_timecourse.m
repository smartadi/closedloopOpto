% ol_opt_replay_var_timecourse.m
% Across-trial variance vs TIME for the AL_0041 OL-optimized replay set.
% One panel per session, overlaying OL (mode 0) / CL (mode 1) / replay (0.5).
% Outputs to paper/images/ol_opt_replay/.
clear; clc; close all;
here = fileparts(mfilename('fullpath')); if isempty(here); here=pwd; end
root = fileparts(here); addpath(genpath(fullfile(root,'utils')));
outDir = fullfile(root,'paper','images','ol_opt_replay'); if ~exist(outDir,'dir'); mkdir(outDir); end

S = { 'AL_0041','2026-03-16',2; 'AL_0041','2026-03-19',1; ...
      'AL_0041','2026-03-23',5; 'AL_0041','2026-03-24',1 };
Fs=35; PRE_S=3; POST_S=3; modes=[0 1 0.5];
names={'OL','CL','replay'}; cols=[1 0 0;0 .5 0;1 .5 0];
nS=size(S,1); VC=cell(nS,3); TAX=cell(nS,1); tags=cell(nS,1); DUR=zeros(nS,1);

for s=1:nS
    mn=S{s,1}; td=S{s,2}; en=S{s,3}; tags{s}=sprintf('%s e%d',td,en);
    d=loadData(expPath(mn,td,en),mn,td,en); nB=numel(d.timeBlue);
    y=d.states(:)'; y=y(1:nB); ip=d.input_params; kk=round(ip(:,2)); md=ip(:,3);
    dur=d.params.dur; DUR(s)=dur;
    nPre=round(PRE_S*Fs); nStim=round(dur*Fs); nPost=round(POST_S*Fs);
    TAX{s}=(-nPre:nStim+nPost)/Fs;
    for c=1:3
        idx=find(md==modes(c)); M=[];
        for j=1:numel(idx); i0=kk(idx(j));
            if i0-nPre>=1 && i0+nStim+nPost<=nB; M(end+1,:)=y(i0-nPre:i0+nStim+nPost); end %#ok<AGROW>
        end
        VC{s,c}=var(M,0,1);
    end
end

f=figure('Color','w','Position',[50 50 1200 760]);
tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
for s=1:nS
    ax=nexttile(tl,s); hold(ax,'on'); box(ax,'off');
    tax=TAX{s}; dur=DUR(s);
    vmax=max([VC{s,1} VC{s,2} VC{s,3}])*1.05;
    patch(ax,[0 dur dur 0],[0 0 vmax vmax],[.9 .9 .9],'FaceAlpha',0.3,'EdgeColor','none','HandleVisibility','off');
    for c=1:3
        plot(ax,tax,VC{s,c},'Color',cols(c,:),'LineWidth',1.8,'DisplayName',names{c});
    end
    xline(ax,0,'k:','HandleVisibility','off');
    xlim(ax,[-PRE_S dur+POST_S]); ylim(ax,[0 vmax]);
    xlabel(ax,'time from onset (s)'); ylabel(ax,'across-trial variance (%\DeltaF/F)^2');
    title(ax,strrep(tags{s},'_','\_'),'FontWeight','normal');
    set(ax,'TickDir','out','FontSize',10);
    if s==1; legend(ax,'Location','northwest','Box','off','FontSize',9); end
end
sgtitle(f,'AL\_0041 OL-optimized replay: across-trial variance vs time (OL / CL / replay)','FontWeight','bold','FontSize',13);
outPng=fullfile(outDir,'SUMMARY_variance_vs_time.png');
exportgraphics(f,outPng,'Resolution',300);
fprintf('-> %s\n',outPng); disp('DONE');
