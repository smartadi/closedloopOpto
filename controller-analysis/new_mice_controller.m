% controller-analysis/new_mice_controller.m
% Controller-analysis panels for the two GOOD new mice (AL_0048, AL_0051).
% AL_0050 EXCLUDED (poor stim response, user 2026-07-30). Static-reference OL/CL.
% Onset convention (2026-07 build): input_params col2 (kk) = ABSOLUTE sample
% index into timeBlue at the trial END -> true onset = timeBlue(kk) - dur.
% Rows = mice; cols = [OL/CL trial average | across-trial variance | trial RMSE].
% Colours: OL red / CL blue (paperStyle). Not paper panels yet -> PNG.

PS = paperStyle(); setPaperDefaults();
fs = 35; PRE = 2; POST = 2;                 % window -2 .. dur+2 s

SESS = { 'AL_0048','2026-07-29',2,-5;
         'AL_0051','2026-07-29',2,-5 };
nS = size(SESS,1);

fig = figure('Color','w','Units','centimeters','Position',[1 1 21 6.5*nS]);
tl  = tiledlayout(fig, nS, 3, 'Padding','compact','TileSpacing','compact');

for s = 1:nS
    mn=SESS{s,1}; td=SESS{s,2}; en=SESS{s,3}; ref=SESS{s,4};
    d = initialize_data(mn, en, td);
    kk = round(d.input_params(:,2));
    d.stimStarts = d.timeBlue(kk) - d.params.dur;   % true onset (col2 = trial END)
    d.stimEnds   = d.timeBlue(kk);
    d.ref = ref;
    data = getpixel_dFoF(d, 1, d.params.pixel, 1); dFk = data.dFk(:)'; tB = d.timeBlue(:)';
    dur = d.params.dur; col3 = d.input_params(:,3);
    nPre=round(PRE*fs); nPost=round((dur+POST)*fs); T=(-nPre:nPost)/fs;

    grab = @(rows) cell2mat(arrayfun(@(r) local_win(dFk,tB,d.stimStarts(r),nPre,nPost), rows(:), 'uni',0));
    OL = grab(find(col3==0)); CL = grab(find(col3==1));
    OL = OL(all(isfinite(OL),2),:); CL = CL(all(isfinite(CL),2),:);
    inStim = T>=0 & T<=dur;
    rmseOL = sqrt(mean((OL(:,inStim)-ref).^2, 2));
    rmseCL = sqrt(mean((CL(:,inStim)-ref).^2, 2));
    pR = ranksum(rmseOL, rmseCL);
    fprintf('[%s] OL n=%d RMSE med=%.2f | CL n=%d RMSE med=%.2f | p=%.3g\n', ...
        mn, size(OL,1), median(rmseOL), size(CL,1), median(rmseCL), pR);

    % ---- col 1: OL vs CL trial average +/- std ----
    ax = nexttile(tl); hold(ax,'on');
    fill(ax,[T fliplr(T)],[mean(OL)+std(OL) fliplr(mean(OL)-std(OL))],PS.col_ol,'FaceAlpha',.10,'EdgeColor','none','HandleVisibility','off');
    fill(ax,[T fliplr(T)],[mean(CL)+std(CL) fliplr(mean(CL)-std(CL))],PS.col_cl,'FaceAlpha',.10,'EdgeColor','none','HandleVisibility','off');
    hO=plot(ax,T,mean(OL),'Color',PS.col_ol,'LineWidth',1.5);
    hC=plot(ax,T,mean(CL),'Color',PS.col_cl,'LineWidth',1.5);
    plot(ax,[0 dur],[ref ref],'--k','LineWidth',1.0,'HandleVisibility','off');
    xline(ax,0,'Color',[.6 .6 .6],'HandleVisibility','off'); xline(ax,dur,'Color',[.6 .6 .6],'HandleVisibility','off');
    xlim(ax,[-PRE dur+POST]); ylim(ax,[-10 6]);
    ylabel(ax,sprintf('%s   \\DeltaF/F (%%)',mn),'FontWeight','bold');
    if s==1; title(ax,'OL vs CL trial average'); legend([hO hC],{'OL','CL'},'Box','off','Location','southeast'); end
    if s==nS; xlabel(ax,'time (s)'); end
    set(ax,'Box','off','TickDir','out');

    % ---- col 2: across-trial variance over time ----
    ax = nexttile(tl); hold(ax,'on');
    plot(ax,T,var(OL,0,1),'Color',PS.col_ol,'LineWidth',1.5);
    plot(ax,T,var(CL,0,1),'Color',PS.col_cl,'LineWidth',1.5);
    xline(ax,0,'Color',[.6 .6 .6],'HandleVisibility','off'); xline(ax,dur,'Color',[.6 .6 .6],'HandleVisibility','off');
    xlim(ax,[-PRE dur+POST]); ylabel(ax,'across-trial variance');
    if s==1; title(ax,'Across-trial variance'); end
    if s==nS; xlabel(ax,'time (s)'); end
    set(ax,'Box','off','TickDir','out');

    % ---- col 3: per-trial RMSE distribution OL vs CL ----
    ax = nexttile(tl); hold(ax,'on');
    jx = @(n) (rand(n,1)-.5)*.34;
    scatter(ax,1+jx(numel(rmseOL)),rmseOL,7,PS.col_ol,'filled','MarkerFaceAlpha',.35);
    scatter(ax,2+jx(numel(rmseCL)),rmseCL,7,PS.col_cl,'filled','MarkerFaceAlpha',.35);
    plot(ax,[.65 1.35],median(rmseOL)*[1 1],'Color',PS.col_ol,'LineWidth',2.5);
    plot(ax,[1.65 2.35],median(rmseCL)*[1 1],'Color',PS.col_cl,'LineWidth',2.5);
    xlim(ax,[.5 2.5]); set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'});
    ylabel(ax,'trial RMSE (%\DeltaF/F)');
    title(ax,sprintf('RMSE  (p=%.2g)',pR));
    set(ax,'Box','off','TickDir','out');
end
title(tl,'New controller mice — per-session OL vs CL','FontWeight','bold');

outDir = fullfile(fileparts(mfilename('fullpath')),'..','paper','images','newmice');
if ~exist(outDir,'dir'); mkdir(outDir); end
outPng = fullfile(outDir,'new_mice_controller_panels.png');
exportgraphics(fig, outPng, 'Resolution', 300);
fprintf('Saved %s\n', outPng);

function w = local_win(dFk,tB,onset,nPre,nPost)
    [~,i] = min(abs(tB-onset));
    if i-nPre<1 || i+nPost>numel(dFk); w = nan(1,nPre+nPost+1); return; end
    w = dFk(i-nPre:i+nPost);
end
