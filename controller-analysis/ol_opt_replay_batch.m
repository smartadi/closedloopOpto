% ol_opt_replay_batch.m
% ---------------------------------------------------------------------------
% AL_0041 "OL-optimized" replay experiment: OL vs CL vs (avg-CL-command
% replayed open-loop). Three interleaved conditions coded in input_params
% column 3 (mode):  0 = open-loop, 1 = closed-loop (PI), 0.5 = averaged CL
% command played back open-loop (the "OL-optimized" / feedforward control).
%
% Signal = the control-pixel dF/F the controller regulated online, stored per
% blue frame in states.csv (d.states) -- NO SVD load, NO pixel click needed.
% Onset frame = input_params col 2 (kk), ABSOLUTE index (AL_0041 convention;
% verified empirically: pre-onset baselines ~0, replay dip lands on ref).
%
% Produces, per session, one PNG in paper/images/ol_opt_replay/ :
%   row1  OL / CL / replay trial galleries (faint trials + bold mean + ref)
%   row2  mean overlay (+-SEM) | across-trial variance(t) | per-trial RMSE
% Plus a cross-session RMSE summary PNG.
%
% Run from brain_paper/ root (or anywhere -- it addpaths utils).
% ---------------------------------------------------------------------------
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
if isempty(here); here = pwd; end
root = fileparts(here);                       % brain_paper/
addpath(genpath(fullfile(root,'utils')));

outDir = fullfile(root,'paper','images','ol_opt_replay');
if ~exist(outDir,'dir'); mkdir(outDir); end

% ---- sessions ----
S = { 'AL_0041','2026-03-16',2; ...
      'AL_0041','2026-03-19',1; ...
      'AL_0041','2026-03-23',5; ...
      'AL_0041','2026-03-24',1 };

Fs      = 35;
PRE_S   = 3;                 % s before onset
POST_S  = 3;                 % s after stim window ends
modes   = [0 1 0.5];         % OL, CL, replay  (plot/column order)
names   = {'Open-loop','Closed-loop','OL-optimized (avg-CL replay)'};
cols    = [1 0 0; 0 0.5 0; 1 0.5 0];   % red / green / orange

SUM = struct('tag',{},'rmse',{},'grp',{},'n',{});  % cross-session collector

for s = 1:size(S,1)
    mn = S{s,1}; td = S{s,2}; en = S{s,3};
    tag = sprintf('%s_%s_e%d', mn, td, en);
    fprintf('\n==== %s ====\n', tag);

    d  = loadData(expPath(mn,td,en), mn, td, en);
    nB = numel(d.timeBlue);
    y  = d.states(:)';  y = y(1:nB);            % control-pixel dF/F (%)
    ip = d.input_params;
    kk = round(ip(:,2));                        % onset frame (absolute)
    md = ip(:,3);
    refcol = ip(:,7);                           % per-trial setpoint (%dF/F)
    dur = d.params.dur;

    nPre  = round(PRE_S*Fs);
    nStim = round(dur*Fs);
    nPost = round(POST_S*Fs);
    W     = nPre + nStim + nPost + 1;           % window length
    tax   = (-nPre : (nStim+nPost)) / Fs;       % time axis (s)
    stimIx = (nPre+1) : (nPre+1+nStim);         % [0, dur] samples for RMSE

    % ---- per-condition trial matrices ----
    C = struct();
    for c = 1:numel(modes)
        idx = find(md==modes(c));
        M = []; rmse = []; refs = [];
        for j = 1:numel(idx)
            i0 = kk(idx(j));
            if i0-nPre < 1 || i0+nStim+nPost > nB; continue; end
            seg = y(i0-nPre : i0+nStim+nPost);
            M(end+1,:) = seg;                                   %#ok<AGROW>
            r = refcol(idx(j));
            e = seg(stimIx) - r;
            rmse(end+1,1) = norm(e)/sqrt(numel(e));             %#ok<AGROW>
            refs(end+1,1) = r;                                  %#ok<AGROW>
        end
        C(c).M = M; C(c).rmse = rmse; C(c).n = size(M,1);
        C(c).mean = mean(M,1); C(c).sem = std(M,0,1)/sqrt(size(M,1));
        C(c).var  = var(M,0,1); C(c).ref = median(refs);
        fprintf('  %-28s n=%3d  RMSE=%.2f\n', names{c}, C(c).n, mean(rmse));
        SUM(end+1) = struct('tag',tag,'rmse',rmse,'grp',c,'n',C(c).n); %#ok<AGROW>
    end
    refLevel = C(1).ref;

    % ================= FIGURE =================
    f = figure('Color','w','Position',[60 60 1350 720]);
    tl = tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');

    % ---- row 1: galleries ----
    for c = 1:3
        ax = nexttile(tl,c); hold(ax,'on'); box(ax,'off');
        M = C(c).M;
        plot(ax, tax, M', 'Color',[cols(c,:) 0.10],'LineWidth',0.4);
        plot(ax, tax, C(c).mean, 'Color',cols(c,:),'LineWidth',2.5);
        yl = [-10 10];
        patch(ax,[0 dur dur 0],[yl(1) yl(1) yl(2) yl(2)],[.9 .9 .9], ...
              'FaceAlpha',0.30,'EdgeColor','none');
        plot(ax,[0 dur],[refLevel refLevel],'--k','LineWidth',1.5);
        yline(ax,0,'k-'); xline(ax,0,'k:'); xline(ax,dur,'k:');
        uistack(findobj(ax,'Type','line'),'top');
        xlim(ax,[-PRE_S dur+POST_S]); ylim(ax,yl);
        title(ax,sprintf('%s  (n=%d)',names{c},C(c).n),'FontWeight','normal');
        if c==1; ylabel(ax,'\DeltaF/F (%)'); end
        xlabel(ax,'time from onset (s)');
        set(ax,'TickDir','out','FontSize',10);
    end

    % ---- row 2a: mean overlay +- SEM ----
    ax = nexttile(tl,4); hold(ax,'on'); box(ax,'off');
    for c = 1:3
        patch(ax,[tax fliplr(tax)], ...
              [C(c).mean+C(c).sem fliplr(C(c).mean-C(c).sem)], ...
              cols(c,:),'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        plot(ax,tax,C(c).mean,'Color',cols(c,:),'LineWidth',2,'DisplayName',names{c});
    end
    plot(ax,[0 dur],[refLevel refLevel],'--k','LineWidth',1.2,'HandleVisibility','off');
    yline(ax,0,'k-','HandleVisibility','off'); xline(ax,0,'k:','HandleVisibility','off');
    xlim(ax,[-PRE_S dur+POST_S]);
    xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
    title(ax,'mean \pm SEM','FontWeight','normal');
    legend(ax,'Location','southwest','Box','off','FontSize',8);
    set(ax,'TickDir','out','FontSize',10);

    % ---- row 2b: across-trial variance(t) ----
    ax = nexttile(tl,5); hold(ax,'on'); box(ax,'off');
    vmax = max([C(1).var C(2).var C(3).var])*1.05;
    patch(ax,[0 dur dur 0],[0 0 vmax vmax], ...
          [.9 .9 .9],'FaceAlpha',0.30,'EdgeColor','none','HandleVisibility','off');
    for c = 1:3
        plot(ax,tax,C(c).var,'Color',cols(c,:),'LineWidth',2,'DisplayName',names{c});
    end
    xline(ax,0,'k:','HandleVisibility','off');
    xlim(ax,[-PRE_S dur+POST_S]); ylim(ax,[0 vmax]);
    xlabel(ax,'time from onset (s)'); ylabel(ax,'across-trial variance (%\DeltaF/F)^2');
    title(ax,'trial-to-trial variance','FontWeight','normal');
    set(ax,'TickDir','out','FontSize',10);

    % ---- row 2c: per-trial RMSE ----
    ax = nexttile(tl,6); hold(ax,'on'); box(ax,'off');
    for c = 1:3
        r = C(c).rmse; x = c + (rand(numel(r),1)-0.5)*0.35;
        scatter(ax,x,r,10,cols(c,:),'filled','MarkerFaceAlpha',0.35);
        errorbar(ax,c,mean(r),std(r),'ko','MarkerFaceColor',cols(c,:), ...
                 'MarkerSize',8,'LineWidth',1.2,'CapSize',6);
    end
    set(ax,'XTick',1:3,'XTickLabel',{'OL','CL','replay'},'TickDir','out','FontSize',10);
    xlim(ax,[0.5 3.5]); ylabel(ax,'per-trial RMSE to ref (%\DeltaF/F)');
    title(ax,'tracking error','FontWeight','normal');

    sgtitle(f,sprintf('OL-optimized replay  |  %s  |  ref=%g%%\\DeltaF/F, dur=%gs', ...
            strrep(tag,'_','\_'), refLevel, dur),'FontWeight','bold','FontSize',13);

    outPng = fullfile(outDir,[tag '.png']);
    exportgraphics(f,outPng,'Resolution',300);
    fprintf('  -> %s\n', outPng);
end

% ================= CROSS-SESSION RMSE SUMMARY =================
fS = figure('Color','w','Position',[80 80 700 460]); ax = axes(fS); hold(ax,'on'); box(ax,'off');
tags = unique({SUM.tag},'stable'); nT = numel(tags);
grpMean = nan(nT,3);
for t = 1:nT
    for c = 1:3
        m = arrayfun(@(x) strcmp(x.tag,tags{t}) && x.grp==c, SUM);
        if any(m); grpMean(t,c) = mean(SUM(find(m,1)).rmse); end
    end
end
b = bar(ax, grpMean, 'grouped');
for c=1:3; b(c).FaceColor = cols(c,:); end
set(ax,'XTick',1:nT,'XTickLabel',strrep(strrep(tags,'AL_0041_',''),'_','\_'),'TickDir','out');
ylabel(ax,'mean per-trial RMSE to ref (%\DeltaF/F)');
legend(ax,{'Open-loop','Closed-loop','OL-optimized (replay)'},'Location','northoutside','Orientation','horizontal','Box','off');
title(ax,'AL\_0041 OL-optimized replay: tracking error across sessions','FontWeight','bold');
outPng = fullfile(outDir,'SUMMARY_rmse_across_sessions.png');
exportgraphics(fS,outPng,'Resolution',300);
fprintf('\nSUMMARY -> %s\n', outPng);
disp('ALL DONE');
