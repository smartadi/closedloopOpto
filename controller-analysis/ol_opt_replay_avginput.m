% ol_opt_replay_avginput.m
% Average INPUT (laser command) vs time for the AL_0041 OL-optimized replay set.
% Command = input_amps.csv (d.iputs), per blue frame (35 Hz), aligned at kk.
% OL (mode 0) = fixed open-loop step | CL (mode 1) = live PI feedback |
% replay (mode 0.5) = averaged-CL command played back open-loop.
% One panel per session, mean command +- SEM across trials. -> paper/images/ol_opt_replay/.
clear; clc; close all;
here = fileparts(mfilename('fullpath')); if isempty(here); here=pwd; end
root = fileparts(here); addpath(genpath(fullfile(root,'utils')));
outDir = fullfile(root,'paper','images','ol_opt_replay'); if ~exist(outDir,'dir'); mkdir(outDir); end

S = { 'AL_0041','2026-03-16',2; 'AL_0041','2026-03-19',1; ...
      'AL_0041','2026-03-23',5; 'AL_0041','2026-03-24',1 };
Fs=35; PRE_S=3; POST_S=3; modes=[0 1 0.5];
names={'OL','CL','replay'}; cols=[1 0 0;0 .5 0;1 .5 0];
nS=size(S,1); MU=cell(nS,3); SE=cell(nS,3); TAX=cell(nS,1); tags=cell(nS,1); DUR=zeros(nS,1);

for s=1:nS
    mn=S{s,1}; td=S{s,2}; en=S{s,3}; tags{s}=sprintf('%s e%d',td,en);
    d=loadData(expPath(mn,td,en),mn,td,en); nB=numel(d.timeBlue);
    u=d.iputs(:)'; u=u(1:nB);            % laser command per frame
    ip=d.input_params; kk=round(ip(:,2)); md=ip(:,3); dur=d.params.dur; DUR(s)=dur;
    nPre=round(PRE_S*Fs); nStim=round(dur*Fs); nPost=round(POST_S*Fs);
    TAX{s}=(-nPre:nStim+nPost)/Fs;
    for c=1:3
        idx=find(md==modes(c)); M=[];
        for j=1:numel(idx); i0=kk(idx(j));
            if i0-nPre>=1 && i0+nStim+nPost<=nB; M(end+1,:)=u(i0-nPre:i0+nStim+nPost); end %#ok<AGROW>
        end
        MU{s,c}=mean(M,1); SE{s,c}=std(M,0,1)/sqrt(size(M,1));
    end
end

f=figure('Color','w','Position',[50 50 1200 760]);
tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
for s=1:nS
    ax=nexttile(tl,s); hold(ax,'on'); box(ax,'off');
    tax=TAX{s}; dur=DUR(s);
    for c=1:3
        patch(ax,[tax fliplr(tax)],[MU{s,c}+SE{s,c} fliplr(MU{s,c}-SE{s,c})], ...
              cols(c,:),'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        plot(ax,tax,MU{s,c},'Color',cols(c,:),'LineWidth',1.8,'DisplayName',names{c});
    end
    xline(ax,0,'k:','HandleVisibility','off'); xline(ax,dur,'k:','HandleVisibility','off');
    xlim(ax,[-PRE_S dur+POST_S]);
    xlabel(ax,'time from onset (s)'); ylabel(ax,'laser command (a.u.)');
    title(ax,strrep(tags{s},'_','\_'),'FontWeight','normal');
    set(ax,'TickDir','out','FontSize',10);
    if s==1; legend(ax,'Location','northwest','Box','off','FontSize',9); end
end
sgtitle(f,'AL\_0041 OL-optimized replay: average input command vs time (mean \pm SEM)','FontWeight','bold','FontSize',13);
outPng=fullfile(outDir,'SUMMARY_avg_input_vs_time.png');
exportgraphics(f,outPng,'Resolution',300);
fprintf('-> %s\n',outPng); disp('DONE');
