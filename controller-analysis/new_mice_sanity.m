% controller-analysis/new_mice_sanity.m
% Load the 3 new static-reference OL/CL controller sessions (AL_0048/0050/0051,
% 2026-07-29), run them through the EXISTING controller pipeline
% (initialize_data -> getpixel_dFoF mode1 SVD -> controllerData), and plot
% OL vs CL trial-averaged dF/F per mouse so errors are visible at a glance.
%
% No loader adapter needed: controllerData splits OL/CL on input_params col3
% (nc=OL=0, wc=CL=1) and takes d.ref externally. Pixels verified = params.pixel.
% Candidate as m14/m15/m16. Not a paper panel -> PNG.

PS = paperStyle(); setPaperDefaults();
fs = 35; PRE = 2; POSTBUF = 1;               % window: -2 s .. +dur+1 s

% mn, td, en, ref  (AL_0050 intentionally ref -1; others -5)
SESS = { 'AL_0048','2026-07-29',2,-5;
         'AL_0050','2026-07-29',3,-1;
         'AL_0051','2026-07-29',2,-5 };
nS = size(SESS,1);

fig = figure('Color','w','Units','centimeters','Position',[2 2 20 7]);
tl  = tiledlayout(fig,1,nS,'Padding','compact','TileSpacing','compact');

for s = 1:nS
    mn = SESS{s,1}; td = SESS{s,2}; en = SESS{s,3}; ref = SESS{s,4};

    d = initialize_data(mn, en, td);
    % 17-col build: input_params col2 (kk) marks the trial END, not the onset,
    % so findStims mode1 puts d.stimStarts `dur` seconds late. Shift back to the
    % true stim onset before any windowing / controllerData scoring.
    d.stimStarts = d.stimStarts - d.params.dur;
    d.ref = ref;
    data = getpixel_dFoF(d, 1, d.params.pixel, 1);      % mode 1 = SVD recon
    t = size(d.input_params,1);                          % all trials valid
    cData = controllerData(data, d, t);                  % VALIDATE pipeline

    % --- direct OL/CL trial averages from dFk (independent of cData fields) ---
    dFk = data.dFk(:)'; tB = d.timeBlue(:)'; dur = d.params.dur;
    nPre = round(PRE*fs); nPost = round((dur+POSTBUF)*fs);
    T = (-nPre:nPost)/fs;
    col3 = d.input_params(:,3);
    ncR = find(col3==0); wcR = find(col3==1);
    grab = @(rows) cell2mat(arrayfun(@(r) local_win(dFk,tB,d.stimStarts(r),nPre,nPost), ...
                                     rows(:), 'uni',0));
    OL = grab(ncR); CL = grab(wcR);
    OL = OL(all(isfinite(OL),2),:); CL = CL(all(isfinite(CL),2),:);

    % peak-to-peak of the mean trace over the stim window (0..dur)
    win = T>=0 & T<=dur;
    p2p = @(M) max(mean(M,1))-min(mean(M,1));
    fprintf('[%s %s/%d] ref=%g | OL n=%d p2p=%.2f RMSE=%.2f | CL n=%d p2p=%.2f RMSE=%.2f\n', ...
        mn, td, en, ref, size(OL,1), p2p(OL(:,win)), mean(cData.er_ncDfk), ...
        size(CL,1), p2p(CL(:,win)), mean(cData.er_wcDfk));

    % --- plot ---
    ax = nexttile(tl); hold(ax,'on');
    band = @(M,c) fill(ax,[T fliplr(T)], ...
        [mean(M,1)+std(M,0,1) fliplr(mean(M,1)-std(M,0,1))], c, ...
        'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
    band(OL,PS.col_ol); band(CL,PS.col_cl);
    hOL = plot(ax,T,mean(OL,1),'Color',PS.col_ol,'LineWidth',1.5);
    hCL = plot(ax,T,mean(CL,1),'Color',PS.col_cl,'LineWidth',1.5);
    plot(ax,[0 dur],[ref ref],'--k','LineWidth',1.0,'HandleVisibility','off');
    xline(ax,0,'Color',[.5 .5 .5],'HandleVisibility','off');
    xline(ax,dur,'Color',[.5 .5 .5],'HandleVisibility','off');
    xlim(ax,[-PRE dur+POSTBUF]); ylim(ax,[-12 8]);
    title(ax,sprintf('%s  (ref %g)',mn,ref),'FontSize',8);
    xlabel(ax,'time (s)'); if s==1; ylabel(ax,'\DeltaF/F (%)'); end
    if s==1; legend([hOL hCL],{'OL','CL'},'Location','southeast','Box','off'); end
    set(ax,'Box','off','TickDir','out');
end
title(tl,'New mice — static-ref OL vs CL trial average','FontSize',9,'FontWeight','bold');

outDir = fullfile(fileparts(mfilename('fullpath')),'..','paper','images','newmice');
if ~exist(outDir,'dir'); mkdir(outDir); end
outPng = fullfile(outDir,'new_mice_ol_cl_sanity.png');
exportgraphics(fig,outPng,'Resolution',300);
fprintf('Saved %s\n', outPng);

function w = local_win(dFk,tB,onset,nPre,nPost)
    [~,i] = min(abs(tB-onset));
    if i-nPre<1 || i+nPost>numel(dFk); w = nan(1,nPre+nPost+1); return; end
    w = dFk(i-nPre:i+nPost);
end
