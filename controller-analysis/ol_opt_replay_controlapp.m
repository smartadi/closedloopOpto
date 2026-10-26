% ol_opt_replay_controlapp.m
% ---------------------------------------------------------------------------
% OL-optimized replay for sessions recorded by the Rainier CONTROL APP
% (Main_experiment.py --mode closed_loop, branch controlApp). Same analysis as
% ol_opt_replay_batch.m + ol_opt_replay_avginput.m (AL_0041), but those use
% loadData + the AL_0041 conventions, which do NOT hold here:
%
%   * onset = input_params.kk_onset (0-based python k -> MATLAB index +1).
%     kk is logged at trial END (~104 samples later). Verified 2026-10-25 on
%     AL_0048 2026-10-23/1: pre-onset dF/F ~0 and command 0 mW with kk_onset;
%     with kk the "pre" window sits inside the stimulus. Timeline
%     lightCommand638 rising edges land 19.7 ms (median) after the blue frame
%     at kk_onset for all 164 trials (= the documented one-sample command lag).
%   * input_params columns read BY NAME from input_params_header.csv
%     (one name per line in this version, not comma-separated).
%   * trial_type (Controller.TRIAL_TYPES): 0 Exp Start, 1 Analyze, 4 custom.
%     Analyze draws mode at random from {0, 0.5, 1} -> the interleaved OL /
%     replay / CL comparison. custom (type 4) = CL trials whose command
%     average becomes the replayed baseline. Exp Start (type 0) = gain/Kref
%     tuning, mode 1 even when Kp=Ki=0 -> excluded.
%   * commands in mW (params.mat laser_units). 1 old uval = 16.81 mW on red.
%   * --demo only adds read-only presentation panels to the live figure.
%   * signal = states.csv row 1 (control-pixel dF/F %, online trailing mean).
%
% Output -> paper/images/ol_opt_replay/<mouse>_<date>_<exp>_*.png
%   _tracking.png  galleries (OL/CL/replay) + mean+-SEM | variance(t) | RMSE
%   _avginput.png  mean command (mW) per condition + replayed avg over its CL source
% ---------------------------------------------------------------------------
clear; clc; close all;
here = fileparts(mfilename('fullpath'));
if isempty(here); here = pwd; end
root = fileparts(here);                       % brain_paper/
addpath(genpath(fullfile(root,'utils')));

outDir = fullfile(root,'paper','images','ol_opt_replay');
if ~exist(outDir,'dir'); mkdir(outDir); end

% ---- sessions (control-app format only) ----
S = { 'AL_0048','2026-10-23',1 };

Fs      = 35;
PRE_S   = 3;                 % s before onset
POST_S  = 3;                 % s after stim window ends
UVAL_MW = 16.81;             % 1 old uval in mW on the red laser
names   = {'Open-loop','Closed-loop','OL-optimized (avg-CL replay)'};
short   = {'OL','CL','replay'};
cols    = [1 0 0; 0 0.5 0; 1 0.5 0];   % red / green / orange (as AL_0041)
colCus  = [0.4 0.4 0.4];               % custom-block CL (replay source)

for s = 1:size(S,1)
    mn = S{s,1}; td = S{s,2}; en = S{s,3};
    tag = sprintf('%s_%s_%d', mn, td, en);
    fprintf('\n==== %s ====\n', tag);
    D = fullfile(expPath(mn,td,en));

    % ---- load ----
    hdr = strsplit(strtrim(fileread(fullfile(D,'input_params_header.csv'))));
    T   = array2table(readmatrix(fullfile(D,'input_params.csv')),'VariableNames',hdr);
    P   = load(fullfile(D,'params.mat'));
    assert(strcmp(P.laser_units,'mW'),'%s: expected mW commands',tag);
    nK  = sum(readNPY(fullfile(D,'blueFrames.indexes.npy'))==1) - 2;  % trim padding
    Y   = readmatrix(fullfile(D,'states.csv'),'Delimiter',' ','FileType','text');
    U   = readmatrix(fullfile(D,'input_amps.csv'),'Delimiter',' ','FileType','text');
    y   = Y(1,1:nK);  u = U(1,1:nK);
    A   = readmatrix(fullfile(D,'custom_mw_trial_avg.csv'));   % [time_s avg_mw]
    dur = unique(T.dur); assert(isscalar(dur));
    fprintf('  laser %s, cap %.1f mW, calib QC passed = %d\n', P.laser_name, P.laser_max_mw, P.laser_calib_qcPassed);

    k0  = T.kk_onset + 1;                     % MATLAB index of onset sample
    ana = T.trial_type == 1;                  % Analyze block (interleaved)
    sel = { ana & T.mode==0, ana & T.mode==1, ana & T.mode==0.5 };
    cus = T.trial_type == 4 & T.mode == 1;    % replay source trials

    nPre  = round(PRE_S*Fs);
    nStim = round(dur*Fs);
    nPost = round(POST_S*Fs);
    tax   = (-nPre : (nStim+nPost)) / Fs;
    stimIx = (nPre+1) : (nPre+1+nStim);       % [0, dur] samples for RMSE
    cut = @(x,i0) x(i0-nPre : i0+nStim+nPost);

    % ---- per-condition trial matrices ----
    C = struct();
    for c = 1:3
        idx = find(sel{c});
        M = cell2mat(arrayfun(@(i) cut(y,k0(i)), idx, 'UniformOutput', false));
        Mu = cell2mat(arrayfun(@(i) cut(u,k0(i)), idx, 'UniformOutput', false));
        r = T.ref(idx);
        rmse = sqrt(mean((M(:,stimIx) - r).^2, 2));
        C(c).M = M; C(c).Mu = Mu; C(c).rmse = rmse; C(c).n = numel(idx);
        C(c).mean = mean(M,1); C(c).sem = std(M,0,1)/sqrt(C(c).n);
        C(c).var = var(M,0,1); C(c).ref = median(r);
        fprintf('  %-28s n=%3d  RMSE=%.2f +- %.2f   pre-baseline %.2f %%  cmd %.1f mW\n', ...
            names{c}, C(c).n, mean(rmse), std(rmse), mean(M(:,1:nPre),'all'), mean(Mu(:,stimIx),'all'));
    end
    Mcus = cell2mat(arrayfun(@(i) cut(u,k0(i)), find(cus), 'UniformOutput', false));
    refLevel = C(1).ref;

    % replayed waveform vs the CL average it was built from + vs what was played.
    % avg_mw(1) is the kk_onset sample (light still off: custom trials are
    % recorded from one sample before the light), and replay plays avg_mw(1)
    % as its first on-sample -> replay light is 1 sample (28.6 ms) later than
    % the CL trials it was averaged from. Find that lag rather than assume it.
    avgMw = A(:,2)';  nA = numel(avgMw);
    cusAvg = mean(Mcus(:, nPre+(1:nA)), 1);
    fprintf('  custom avg file vs custom-trial mean: max|diff| = %.3g mW (n=%d)\n', max(abs(avgMw-cusAvg)), size(Mcus,1));
    lags = -2:3;
    lagErr = arrayfun(@(L) max(abs(mean(C(3).Mu(:, nPre+L+(1:nA)),1) - avgMw)), lags);
    [~,b] = min(lagErr); repLag = lags(b);
    fprintf('  replay played = custom avg file delayed %d sample(s): max|diff| = %.3g mW\n', repLag, lagErr(b));
    fprintf('  RMSE ranksum p: CL vs replay %.3g | OL vs replay %.3g | OL vs CL %.3g\n', ...
        ranksum(C(2).rmse, C(3).rmse), ranksum(C(1).rmse, C(3).rmse), ranksum(C(1).rmse, C(2).rmse));
    v = @(c) mean(C(c).var(stimIx));
    fprintf('  mean across-trial var 0-3 s: OL %.2f | CL %.2f | replay %.2f (%%dF/F)^2\n', v(1), v(2), v(3));

    % ================= FIGURE 1: tracking =================
    f = figure('Color','w','Position',[60 60 1350 720]);
    tl = tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
    yl = [-12 8];
    for c = 1:3
        ax = nexttile(tl,c); hold(ax,'on'); box(ax,'off');
        plot(ax, tax, C(c).M', 'Color',[cols(c,:) 0.15],'LineWidth',0.4);
        plot(ax, tax, C(c).mean, 'Color',cols(c,:),'LineWidth',2.5);
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

    ax = nexttile(tl,4); hold(ax,'on'); box(ax,'off');
    for c = 1:3
        patch(ax,[tax fliplr(tax)], ...
              [C(c).mean+C(c).sem fliplr(C(c).mean-C(c).sem)], ...
              cols(c,:),'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        plot(ax,tax,C(c).mean,'Color',cols(c,:),'LineWidth',2,'DisplayName',names{c});
    end
    plot(ax,[0 dur],[refLevel refLevel],'--k','LineWidth',1.2,'HandleVisibility','off');
    yline(ax,0,'k-','HandleVisibility','off'); xline(ax,0,'k:','HandleVisibility','off');
    xlim(ax,[-PRE_S dur+POST_S]); ylim(ax,[refLevel-1 2]);
    xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
    title(ax,'mean \pm SEM','FontWeight','normal');
    legend(ax,'Location','southwest','Box','off','FontSize',8);
    set(ax,'TickDir','out','FontSize',10);

    ax = nexttile(tl,5); hold(ax,'on'); box(ax,'off');
    vmax = max([C.var])*1.05;
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

    ax = nexttile(tl,6); hold(ax,'on'); box(ax,'off');
    for c = 1:3
        r = C(c).rmse; x = c + (rand(numel(r),1)-0.5)*0.35;
        scatter(ax,x,r,10,cols(c,:),'filled','MarkerFaceAlpha',0.35);
        errorbar(ax,c,mean(r),std(r),'ko','MarkerFaceColor',cols(c,:), ...
                 'MarkerSize',8,'LineWidth',1.2,'CapSize',6);
    end
    set(ax,'XTick',1:3,'XTickLabel',short,'TickDir','out','FontSize',10);
    xlim(ax,[0.5 3.5]); ylabel(ax,'per-trial RMSE to ref, 0-3 s (%\DeltaF/F)');
    title(ax,'tracking error','FontWeight','normal');

    sgtitle(f,{sprintf('OL-optimized replay  |  %s  |  ref=%g%%\\DeltaF/F, dur=%gs, Kp=%g Ki=%g Kref=%g', ...
            strrep(tag,'_','\_'), refLevel, dur, T.Kp(find(ana,1)), T.Ki(find(ana,1)), T.Kref(find(ana,1))), ...
            'Analyze block only (interleaved, trial\_type 1); onset = kk\_onset; signal = states.csv (online \DeltaF/F)'}, ...
            'FontWeight','bold','FontSize',12);
    outPng = fullfile(outDir,[tag '_tracking.png']);
    exportgraphics(f,outPng,'Resolution',300);
    fprintf('  -> %s\n', outPng);

    % ================= FIGURE 2: average input =================
    f2 = figure('Color','w','Position',[80 80 1200 460]);
    tl2 = tiledlayout(f2,1,2,'TileSpacing','compact','Padding','compact');

    ax = nexttile(tl2,1); hold(ax,'on'); box(ax,'off');
    for c = 1:3
        mu = mean(C(c).Mu,1); se = std(C(c).Mu,0,1)/sqrt(C(c).n);
        patch(ax,[tax fliplr(tax)],[mu+se fliplr(mu-se)],cols(c,:), ...
              'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        plot(ax,tax,mu,'Color',cols(c,:),'LineWidth',1.8,'DisplayName',sprintf('%s (n=%d)',short{c},C(c).n));
    end
    xline(ax,0,'k:','HandleVisibility','off'); xline(ax,dur,'k:','HandleVisibility','off');
    xlim(ax,[-1 dur+1]); xlabel(ax,'time from onset (s)'); ylabel(ax,'laser command (mW)');
    title(ax,'Analyze block: mean command \pm SEM','FontWeight','normal');
    legend(ax,'Location','northeast','Box','off','FontSize',9);
    set(ax,'TickDir','out','FontSize',10);
    ylm = ylim(ax);
    yyaxis(ax,'right'); ylim(ax,ylm/UVAL_MW);       % same scale, in old uval
    ax.YAxis(2).Color = [.3 .3 .3]; ylabel(ax,'old uval equivalent (mW \div 16.81)');
    yyaxis(ax,'left');

    ax = nexttile(tl2,2); hold(ax,'on'); box(ax,'off');
    mu = mean(Mcus,1); se = std(Mcus,0,1)/sqrt(size(Mcus,1));
    patch(ax,[tax fliplr(tax)],[mu+se fliplr(mu-se)],colCus, ...
          'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    plot(ax,tax,mu,'Color',colCus,'LineWidth',2.5,'DisplayName',sprintf('CL, custom block (n=%d)',size(Mcus,1)));
    plot(ax,tax,mean(C(2).Mu,1),'Color',cols(2,:),'LineWidth',1.2,'DisplayName','CL, Analyze block');
    plot(ax,A(:,1),avgMw,'--','Color',[0 0 0],'LineWidth',1.5,'DisplayName','custom\_mw\_trial\_avg (saved)');
    plot(ax,tax,mean(C(3).Mu,1),'Color',cols(3,:),'LineWidth',1.2, ...
         'DisplayName',sprintf('replay, as played (+%d sample = %.1f ms)',repLag,1e3*repLag/Fs));
    xline(ax,0,'k:','HandleVisibility','off'); xline(ax,dur,'k:','HandleVisibility','off');
    xlim(ax,[-1 dur+1]); xlabel(ax,'time from onset (s)'); ylabel(ax,'laser command (mW)');
    title(ax,'replayed input vs the CL average it was built from','FontWeight','normal');
    legend(ax,'Location','northeast','Box','off','FontSize',9);
    set(ax,'TickDir','out','FontSize',10);

    sgtitle(f2,{sprintf('%s  |  average input (red 638 nm, mW)', strrep(tag,'_','\_')), ...
        'calibration laserModCalib638 (2026-10-06) FAILED QC: mW values approximate, worst at low power'}, ...
        'FontWeight','bold','FontSize',12);
    outPng = fullfile(outDir,[tag '_avginput.png']);
    exportgraphics(f2,outPng,'Resolution',300);
    fprintf('  -> %s\n', outPng);
end
disp('ALL DONE');
