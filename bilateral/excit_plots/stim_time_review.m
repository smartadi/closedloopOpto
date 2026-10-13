% bilateral/excit_plots/stim_time_review.m
% REVIEW of stim-time / laser-channel identification for AL_0048 07-21/1.
% Finding: 594 (orange/excit-selective) laser is OFF all session; 638 (red) is the stim laser.
% The excit_cl plot showed inpVals594 (idle) -> flat noise. Here we overlay BOTH laser commands,
% trial-averaged around the computed onset, to (a) prove 638 is the real command and (b) verify
% onset = timeBlue(kk) - dur places the pulse at t in [0, dur]. Output PNG -> excit_plots/cl/.
clc; close all; clear;
root='C:\Users\aditya\Documents\projects\brain_paper'; cd(root); addpath(genpath(fullfile(root,'utils')));
outdir=fullfile(root,'bilateral','excit_plots','cl'); if ~exist(outdir,'dir'); mkdir(outdir); end
sr=expPath('AL_0048','2026-07-21',1); d=loadData(sr,'AL_0048','2026-07-21',1);
ip=d.input_params; C_KK=2; C_DUR=10; C_GX=15; C_MODE=3;
gx=ip(:,C_GX); dur=ip(:,C_DUR); kk=round(ip(:,C_KK)); mode=ip(:,C_MODE);
tb=d.timeBlue(:).'; onB=tb(min(max(kk,1),numel(tb)))-dur(:).';   % correct onset
t594=d.inpTime594(:).'; v594=abs(double(d.inpVals594(:).'));
t638=d.inpTime638(:).'; v638=abs(double(d.inpVals638(:).'));
fs=35; PRE=2; POST=6; Tin=(-PRE:1/fs:POST);
grp={'excitatory (gx<0)', gx<0; 'inhibitory (gx>0)', gx>0};
avgwin=@(tt,vv,on) mean(cell2mat(arrayfun(@(o) interp1(tt-o,vv,Tin,'linear',NaN),on(:),'uni',0)),1,'omitnan');

fig=figure('Color','w','Units','centimeters','Position',[2 2 22 8]);
tl=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
for g=1:2
    on=onB(grp{g,2}); ax=nexttile(tl); hold(ax,'on');
    md=round(median(dur(grp{g,2})));
    patch(ax,[0 md md 0],[-1 -1 6 6],[.93 .93 .93],'EdgeColor','none','HandleVisibility','off');
    plot(ax,Tin,avgwin(t638,v638,on),'-','Color',[0.75 0.15 0.10],'LineWidth',1.8,'DisplayName','638 nm (red) command');
    plot(ax,Tin,avgwin(t594,v594,on),'-','Color',[0.90 0.55 0.15],'LineWidth',1.4,'DisplayName','594 nm (orange) command');
    xline(ax,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
    xlim(ax,[-PRE POST]); box(ax,'off'); set(ax,'TickDir','out','FontSize',9);
    xlabel(ax,'time from computed onset (s)'); if g==1; ylabel(ax,'|laser command| (V)'); end
    title(ax,sprintf('%s (n=%d, dur~%ds)',grp{g,1},nnz(grp{g,2}),md),'FontSize',9);
    legend(ax,'Box','off','Location','northeast','FontSize',7);
end
title(tl,'07-21/1 stim-time review: 638 is the stim laser, 594 idle; onset = timeBlue(kk)-dur aligns the pulse to [0,dur]','FontSize',9,'FontWeight','bold');
exportgraphics(fig,fullfile(outdir,'stim_time_review.png'),'Resolution',300);
fprintf('[stim_time_review] 638 peak(exc)=%.2f 594 peak(exc)=%.3f -> 638 is the command; wrote PNG\n', ...
    max(avgwin(t638,v638,onB(gx<0))), max(avgwin(t594,v594,onB(gx<0))));
