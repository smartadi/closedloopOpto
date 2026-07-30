% controller-analysis/new_mice_paper_panels.m
% PAPER-styled single-session controller panels for the two good new mice
% (AL_0048, AL_0051; AL_0050 excluded). Static-reference OL/CL, ref -5.
% Per mouse -> 3 vector PDFs (+ PNG previews) in paper/images/newmice/<mn>/:
%   ctrl_trialavg_<mn>.pdf   OL/CL trial average +/-std + ref  (6 x 4)
%   ctrl_variance_<mn>.pdf   across-trial variance over time   (5.5 x 4)
%   ctrl_rmse_<mn>.pdf       per-trial RMSE half-violins        (4.2 x 5.4)
% Colours OL=red / CL=blue (paperStyle). Onset: col2(kk)=trial-END abs index,
% onset = timeBlue(kk)-dur. Exported to newmice/ so Fig 3 panels are untouched.

PS = paperStyle(); setPaperDefaults();
fs = 35; PRE = 3; POST = 3;
EXPORT = true; EXPORT_PNG = true;

SESS = { 'AL_0048','2026-07-29',2,-5;
         'AL_0051','2026-07-29',2,-5 };
COLS = [PS.col_ol; PS.col_cl]; SHORT = {'OL','CL'};

for s = 1:size(SESS,1)
    mn=SESS{s,1}; td=SESS{s,2}; en=SESS{s,3}; ref=SESS{s,4};
    d = initialize_data(mn, en, td);
    kk = round(d.input_params(:,2));
    d.stimStarts = d.timeBlue(kk) - d.params.dur; d.stimEnds = d.timeBlue(kk); d.ref = ref;
    data = getpixel_dFoF(d, 1, d.params.pixel, 1); dFk = data.dFk(:)'; tB = d.timeBlue(:)';
    dur = d.params.dur; col3 = d.input_params(:,3); x1=0; x2=dur;
    nPre=round(PRE*fs); nPost=round((dur+POST)*fs); T=(-nPre:nPost)/fs;

    grab = @(rows) cell2mat(arrayfun(@(r) local_win(dFk,tB,d.stimStarts(r),nPre,nPost), rows(:), 'uni',0));
    OL = grab(find(col3==0)); CL = grab(find(col3==1));
    OL = OL(all(isfinite(OL),2),:); CL = CL(all(isfinite(CL),2),:);
    inStim = T>=0 & T<=dur;
    rmseV = { sqrt(mean((OL(:,inStim)-ref).^2,2)), sqrt(mean((CL(:,inStim)-ref).^2,2)) };
    try; pR = ranksum(rmseV{1},rmseV{2}); catch; pR = NaN; end

    outDir = fullfile(fileparts(mfilename('fullpath')),'..','paper','images','newmice',mn);
    if ~exist(outDir,'dir'); mkdir(outDir); end
    exp2 = @(fig,base) deal_export(fig, outDir, base, EXPORT, EXPORT_PNG);

    %% Panel 1: OL/CL trial average +/- std --------------------------------
    figB = paperFig(6,4);
    ax = axes(figB,'Position',[0.12 0.14 0.84 0.78]); hold(ax,'on');
    plot(ax,T,zeros(size(T)),'k','LineWidth',PS.lw_zero,'HandleVisibility','off');
    fill(ax,[T fliplr(T)],[mean(OL)+std(OL) fliplr(mean(OL)-std(OL))],PS.col_ol,'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
    fill(ax,[T fliplr(T)],[mean(CL)+std(CL) fliplr(mean(CL)-std(CL))],PS.col_cl,'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
    hO=plot(ax,T,mean(OL),'Color',PS.col_ol,'LineWidth',PS.lw_mean);
    hC=plot(ax,T,mean(CL),'Color',PS.col_cl,'LineWidth',PS.lw_mean);
    plot(ax,[0 dur],[ref ref],'--k','LineWidth',PS.lw_ref,'HandleVisibility','off');
    ylim(ax,[-9 5]); xlim(ax,[-PRE dur+POST]);
    addStimPatch(ax,x1,x2); uistack(findobj(ax,'Type','line'),'top'); hold(ax,'off');
    paperAxes(ax,'XLength',1,'YLength',3,'XLabel','1 s','YLabel','3% dF/F');
    lg=legend([hO hC],SHORT,'Location','southeast'); paperLegend(lg);
    text(ax,0.5,1.06,mn,'Units','normalized','HorizontalAlignment','center','Interpreter','none','Clipping','off');
    exp2(figB,sprintf('ctrl_trialavg_%s',mn));

    %% Panel 2: across-trial variance over time ----------------------------
    figD = paperFig(5.5,4);
    ax = axes(figD,'Position',[0.13 0.14 0.83 0.80]); hold(ax,'on');
    plot(ax,T,var(OL,0,1),'Color',PS.col_ol,'LineWidth',PS.lw_mean);
    plot(ax,T,var(CL,0,1),'Color',PS.col_cl,'LineWidth',PS.lw_mean);
    yl = ylim(ax); ylim(ax,[0 yl(2)]); xlim(ax,[-PRE dur+POST]);
    addStimPatch(ax,x1,x2); uistack(findobj(ax,'Type','line'),'top'); hold(ax,'off');
    paperAxes(ax,'XLength',1,'YLength',10,'XLabel','1 s','YLabel','10');
    text(ax,-0.12,0.5,'Variance across trials','Units','normalized','Rotation',90, ...
        'HorizontalAlignment','center','VerticalAlignment','middle','Clipping','off');
    exp2(figD,sprintf('ctrl_variance_%s',mn));

    %% Panel 3: per-trial RMSE half-violins --------------------------------
    figE = paperFig(4.2,5.4);
    ax = axes(figE,'Position',[0.15 0.13 0.80 0.77]); hold(ax,'on'); hw=0.34;
    allR = cell2mat(rmseV(:)); rTop = prctile(allR,95);
    for m=1:2
        [fk,yk] = ksdensity(rmseV{m}); fk = fk/max(fk)*hw;
        fill(ax,[m-fk, m*ones(size(fk))],[yk fliplr(yk)],COLS(m,:),'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
        plot(ax,m+0.12,median(rmseV{m}),'*','Color',COLS(m,:),'MarkerSize',4,'LineWidth',0.75,'HandleVisibility','off');
    end
    xlim(ax,[0.4 2.6]); ylim(ax,[0 rTop]); hold(ax,'off');
    for m=1:2
        text(ax,m,-0.02*rTop,SHORT{m},'HorizontalAlignment','center','VerticalAlignment','top', ...
            'FontSize',PS.fs,'FontWeight',PS.fw,'Clipping','off');
    end
    text(ax,-0.14,0.5,'Trial RMSE (% dF/F)','Units','normalized','Rotation',90, ...
        'HorizontalAlignment','center','VerticalAlignment','middle','Clipping','off');
    text(ax,0.5,1.03,sprintf('p = %.2g',pR),'Units','normalized','HorizontalAlignment','center','Clipping','off');
    paperAxes(ax,'XLength',0.5,'YLength',2,'XLabel','','YLabel','2');
    exp2(figE,sprintf('ctrl_rmse_%s',mn));

    fprintf('[%s] OL n=%d (RMSE %.2f) | CL n=%d (RMSE %.2f) | p=%.3g | -> %s\n', ...
        mn, size(OL,1), median(rmseV{1}), size(CL,1), median(rmseV{2}), pR, outDir);
end

function local_export = deal_export(fig, outDir, base, EXPORT, EXPORT_PNG)
    local_export = [];
    if EXPORT; paperExport(fig, fullfile(outDir,[base '.pdf'])); end
    if EXPORT_PNG; paperExport(fig, fullfile(outDir,[base '.png'])); end
end

function w = local_win(dFk,tB,onset,nPre,nPost)
    [~,i] = min(abs(tB-onset));
    if i-nPre<1 || i+nPost>numel(dFk); w = nan(1,nPre+nPost+1); return; end
    w = dFk(i-nPre:i+nPost);
end
