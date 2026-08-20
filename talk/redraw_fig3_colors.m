%% redraw_fig3_colors.m -- Fig-3 panels on the CURRENT OL/CL palette, plus a 4-window variance ratio
%
% Produces:
%   all_variance_sessions.pdf      3F  session-averaged across-trial VARIANCE trace   (recoloured)
%   all_average_sessions.pdf       3G  session-averaged error trace, MAE or RMSE      (recoloured)
%                                      -> written as all_average_sessions_rmse.pdf when
%                                         F3_METRIC = 'rmse' (the default), so the MAE panel
%                                         the paper text refers to is never overwritten
%   all_MSE_sessions.pdf           3H  per-session trial-RMSE violins                 (recoloured)
%   variance_ratio_4windows.pdf    NEW OL/CL variance ratio on the SAME four windows
%                                      the RMSE ratio panel (3J) uses
%
% WHY THE RECOLOUR: PS.col_cl changed green -> blue on 2026-07-23, but 3F/3G/3H were last
% exported 2026-07-16, so they are the only Fig-3 panels still drawing CL in green (A-E,
% 2026-08-17, are already red/blue; the ratio panels are greyscale). No analysis changes:
% same 13 sessions, same windows, same statistics.
%
% WHY THE NEW PANEL: 3I compares variance over pre / stim / post only, while 3J compares
% RMSE over pre / 0-1 s / 1-3 s / post. Putting them side by side on a slide invites the
% reader to match windows that do not match. This splits the variance stim window the same
% way, so the two ratio panels are read on one x-axis. 3I itself is left alone.
%
% WHY THIS SCRIPT AND NOT `load_sessions; variance_mse; step_response`: the full load holds
% `d` (the 2000-component SVD) for all 15 registered sessions, ~40 GB, and OOMs partway
% (RESEARCH 2026-07-30). Everything these panels need is already in the small `data` struct
% of each controller cache, so this loads `data` ONLY, one session at a time. `d` is never
% touched.
%
% Cache -> load_sessions equivalences (verified against utils/controllerData.m; the onset
% column is fixed by the slice, so none of these depend on dur):
%   pncDfk = dFk(i-350 : i+35*(dur+3))  -> pncDfk_l = pncDfk(:, 246:end)   (3 s pre)
%   ncDfk  = dFk(i-35  : i+35*(dur+1))  -> onset at col 36
%
% Sessions: m1..m13. The two 2026-07-29 mice (AL_0048/AL_0051) stay out so these keep the
% 13-session set the paper text quotes. The registry is read from load_sessions.m in lean
% mode rather than copied here -- a hand-copied table got three of the thirteen experiment
% numbers wrong on the first attempt.

% cd/addpath survive load_sessions' `clearvars`; VARIABLES set before it do not.
cd('C:\Users\aditya\Documents\projects\brain_paper');
addpath(genpath(fullfile(pwd,'utils')));
addpath(fullfile(pwd,'controller-analysis'));

% load_sessions does `clearvars`, so a caller's `F3_METRIC = 'mae'; redraw_fig3_colors` would
% be silently wiped and the default used instead. Stash it somewhere the clear cannot reach.
if exist('F3_METRIC','var') && ~isempty(F3_METRIC), setenv('F3_METRIC_STASH', F3_METRIC); end

r_lean = 1;
load_sessions;

root = 'C:\Users\aditya\Documents\projects\brain_paper';
PS = paperStyle(); setPaperDefaults();
outDir = fullfile(root,'paper','images','figure3');
if ~isfolder(outDir); mkdir(outDir); end

% F3_METRIC  'rmse' (default) or 'mae', for the 3G session-averaged error trace.
%
% MAE here is abs(mean(e over trials)) -- errors of opposite sign on different trials CANCEL,
% so the panel measures BIAS only. RMSE is sqrt(mean(e^2 over trials)) and cancels nothing:
% RMSE^2 = bias^2 + across-trial variance. Both curves therefore rise when the RMSE version is
% used, and 3G stops being independent of the variance panel 3F -- it now contains it. That is
% not a reason to avoid it (the user asked for RMSE, and RMSE is the project's error metric
% everywhere else since 2026-07-16), but say so if the two panels are shown together.
%
% The paper's Fig 3 panel is deliberately MAE and labelled MAE (root CLAUDE.md), so the RMSE
% version goes to its own filename rather than overwriting it.
F3_METRIC = getenv('F3_METRIC_STASH');
if isempty(F3_METRIC), F3_METRIC = 'rmse'; end
setenv('F3_METRIC_STASH','');          % one-shot: do not leak into the next run
useRMSE = strcmpi(F3_METRIC,'rmse');

dur   = 3;
REF   = -5;
Fs    = 35;
NKEEP = 13;
fields = fields(1:min(NKEEP,numel(fields)));
nS = numel(fields);

Mvarnc = []; Mvarwc = [];              % 3F + ratio panel
Error_nc = []; Error_wc = [];          % 3G bold means
ENC = cell(nS,1); EWC = cell(nS,1);    % 3G faint per-session traces
ERnc = cell(nS,1); ERwc = cell(nS,1);  % 3H violins
W = struct('pre',[],'early',[],'late',[],'post',[]);   % per-session window means
Vnc = W; Vwc = W;

for k = 1:nS
    mn = mouse.(fields{k}).mn; td = mouse.(fields{k}).td; en = mouse.(fields{k}).en;
    pc = fullfile(root,'data', sprintf('%sctrl%s%s%d.mat', mn, td(6:7), td(9:10), en));
    if ~isfile(pc); error('missing cache: %s', pc); end
    T = load(pc,'data');  D = T.data;  clear T

    pnc = D.pncDfk(:, 246:end);   pwc = D.pwcDfk(:, 246:end);   % 3 s pre .. dur+3 s
    vnc = var(pnc);               vwc = var(pwc);
    Mvarnc = [Mvarnc; vnc];       Mvarwc = [Mvarwc; vwc];        %#ok<AGROW>

    enc = D.ncDfk(:, 36:141) - REF;  ewc = D.wcDfk(:, 36:141) - REF;
    % across-TRIAL error at each sample: RMS (keeps trial-to-trial spread) or
    % abs-of-mean (cancels it). See the F3_METRIC note at the top.
    if useRMSE
        Error_nc = [Error_nc; sqrt(mean(enc.^2,1))];             %#ok<AGROW>
        Error_wc = [Error_wc; sqrt(mean(ewc.^2,1))];             %#ok<AGROW>
    else
        Error_nc = [Error_nc; abs(mean(enc,1))];                 %#ok<AGROW>
        Error_wc = [Error_wc; abs(mean(ewc,1))];                 %#ok<AGROW>
    end

    % full-window error against the step reference (pre/post cancel by construction)
    ref_nc = [pnc(:,1:105), REF*ones(size(pnc,1),105), pnc(:,211:end)];
    ref_wc = [pwc(:,1:105), REF*ones(size(pwc,1),105), pwc(:,211:end)];
    if useRMSE
        ENC{k} = sqrt(mean((pnc - ref_nc).^2, 1));
        EWC{k} = sqrt(mean((pwc - ref_wc).^2, 1));
    else
        ENC{k} = abs(mean(pnc - ref_nc, 1));
        EWC{k} = abs(mean(pwc - ref_wc, 1));
    end

    ERnc{k} = D.er_ncDfk(:);  ERwc{k} = D.er_wcDfk(:);
    fprintf('  %-8s %s e%d  nc=%3d wc=%3d\n', mn, td, en, size(pnc,1), size(pwc,1));
    clear D pnc pwc enc ewc ref_nc ref_wc
end
fprintf('[F3] %d sessions loaded (data only, no d)\n', nS);

Mean_var_nc = mean(Mvarnc,1);  Mean_var_wc = mean(Mvarwc,1);
tp   = (-3*Fs : Fs*(dur+3)) / Fs;
t1_h = tp;
t_h  = 0 : 1/Fs : dur;

%% ---- 3F: cross-session variance ----------------------------------------
fig_F = paperFig(3, 3.5);
lm2 = 0.13; rm2 = 0.05; bm2 = 0.12; tm2 = 0.08;
ax_var = axes(fig_F, 'Position', [lm2, bm2, 1-lm2-rm2, 1-bm2-tm2]);
hold(ax_var,'on');
plot(ax_var, tp, Mean_var_nc, 'Color',PS.col_ol, 'LineWidth', 1.5);
plot(ax_var, tp, Mean_var_wc, 'Color',PS.col_cl, 'LineWidth', 1.5);
xline(ax_var, 0,   'LineWidth', 0.75, 'HandleVisibility','off');
xline(ax_var, dur, 'LineWidth', 0.75, 'HandleVisibility','off');
ylim(ax_var, [-2 12]); xlim(ax_var, [-3 dur+3]);
addStimPatch(ax_var, 0, dur);
uistack(findobj(ax_var,'Type','line'), 'top');
hold(ax_var,'off');
paperAxes(ax_var, 'XLength', 1, 'YLength', 0.01, 'XLabel', '1 s', 'YLabel', ' ');
text(ax_var, -0.12, 0.5, {'Average of Session'; 'Variance across trials'}, ...
    'Units','normalized', 'Rotation', 90, 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'FontSize',6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
paperExport(fig_F, fullfile(outDir, 'all_variance_sessions.pdf'));

%% ---- 3G: all-session trial average (MAE or RMSE) ------------------------
fig_H = paperFig(3, 4);
lm_h = 0.18; rm_h = 0.05; bm_h = 0.12; tm_h = 0.08;
ax_H = axes(fig_H, 'Position', [lm_h, bm_h, 1-lm_h-rm_h, 1-bm_h-tm_h]);
hold(ax_H,'on');
for k = 1:nS
    plot(ax_H, t1_h, ENC{k}, 'Color', [PS.col_ol, PS.fa], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
    plot(ax_H, t1_h, EWC{k}, 'Color', [PS.col_cl, PS.fa], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
end
plot(ax_H, t_h, mean(Error_nc,1), 'Color', PS.col_ol, 'LineWidth', PS.lw_mean);
plot(ax_H, t_h, mean(Error_wc,1), 'Color', PS.col_cl, 'LineWidth', PS.lw_mean);
addStimPatch(ax_H, 0, dur);
% RMSE folds in the across-trial spread, so it runs well above the MAE curve -- take the
% limit from the data instead of the MAE-era hardcoded 6, or the traces clip
yTop = max([6, 1.08*max([Error_nc(:); Error_wc(:)])]);
xlim(ax_H, [-0.5 dur+0.5]); ylim(ax_H, [-0.25 yTop]);
hold(ax_H,'off');
lgd_H = legend(ax_H, {'Open-Loop','Closed-Loop'}, 'Location','northeast');
paperLegend(lgd_H);
if useRMSE
    yLab = 'RMSE dF/F';  fnH = 'all_average_sessions_rmse.pdf';
else
    yLab = 'MAE dF/F';   fnH = 'all_average_sessions.pdf';
end
paperAxes(ax_H, 'XLength',0.5, 'YLength',1, 'XLabel','500 ms', 'YLabel',yLab);
paperExport(fig_H, fullfile(outDir, fnH));

% report both the chosen metric and what the other one would have given, so the swap is
% auditable from the log rather than only from the picture
iStim = t_h >= 0 & t_h <= dur;
fprintf('[F3G] %s | stim-window mean  OL %.3f  CL %.3f  (%.0f%% lower)\n', upper(F3_METRIC), ...
        mean(mean(Error_nc(:,iStim),1)), mean(mean(Error_wc(:,iStim),1)), ...
        100*(1 - mean(mean(Error_wc(:,iStim),1))/mean(mean(Error_nc(:,iStim),1))));

%% ---- 3H: cross-session trial-RMSE violin --------------------------------
fig_G = paperFig(7.8, 4);
lm_g = 0.10; rm_g = 0.05; bm_g = 0.12; tm_g = 0.08;
ax_mse = axes(fig_G, 'Position', [lm_g, bm_g, 1-lm_g-rm_g, 1-bm_g-tm_g]);
hold(ax_mse,'on');
halfWidth = 0.3; alphaFill = 0.5;
colA = PS.col_ol; colB = PS.col_cl;
for k = 1:nS
    [fA, yA] = ksdensity(ERnc{k}); fA = fA / max(fA) * halfWidth;
    fill(ax_mse, [k - fA, k*ones(size(fA))], [yA, fliplr(yA)], colA, ...
        'FaceAlpha', alphaFill, 'EdgeColor','none');
    plot(ax_mse, k - 0.1, mean(ERnc{k}), '*', 'Color',colA, 'LineWidth',0.5, 'MarkerSize',3);
    [fB, yB] = ksdensity(ERwc{k}); fB = fB / max(fB) * halfWidth;
    fill(ax_mse, [k + fB, k*ones(size(fB))], [yB, fliplr(yB)], colB, ...
        'FaceAlpha', alphaFill, 'EdgeColor','none');
    plot(ax_mse, k + 0.1, mean(ERwc{k}), '*', 'Color',colB, 'LineWidth',0.5, 'MarkerSize',3);
end
hold(ax_mse,'off');
xlim(ax_mse, [0.5 nS+0.5]);
cleanAxes(ax_mse);
text(ax_mse, -0.06, 0.5, 'Trial RMSE', 'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
text(ax_mse, 0.5, -0.02, 'Sessions', 'Units','normalized', ...
    'HorizontalAlignment','center', 'VerticalAlignment','top', ...
    'FontSize',6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
paperExport(fig_G, fullfile(outDir, 'all_MSE_sessions.pdf'));

%% ---- NEW: OL/CL variance ratio on the RMSE panel's four windows ---------
% Same window edges as G2r in variance_mse.m, so this panel and MSE_ratio_by_window.pdf
% share an x-axis: pre (-3..0 s), early stim (0..1 s), late stim (1..3 s), post (3..6 s).
iw = { tp >= -3 & tp < 0
       tp >=  0 & tp <= 1
       tp >   1 & tp <= dur
       tp >  dur & tp <= dur+3 };
wlab = {'Pre','0-1 s','1-3 s','Post'};
nW = numel(iw);

good = any(Mvarnc > 0, 2) & any(Mvarwc > 0, 2);
Vo = nan(sum(good), nW);  Vc = nan(sum(good), nW);
Ao = Mvarnc(good,:);  Ac = Mvarwc(good,:);
for w = 1:nW
    Vo(:,w) = mean(Ao(:, iw{w}), 2);
    Vc(:,w) = mean(Ac(:, iw{w}), 2);
end
Rv = Vo ./ Vc;
pw = arrayfun(@(w) signrank(Vo(:,w), Vc(:,w)), 1:nW);
stars = @(p) repmat('*', 1, (p<0.001)*3 + (p>=0.001 && p<0.01)*2 + (p>=0.01 && p<0.05)*1);
fprintf('\n[F3] OL/CL VARIANCE ratio, %d sessions\n', size(Rv,1));
for w = 1:nW
    fprintf('   %-6s ratio %.2f   (OL %.2f vs CL %.2f)   signrank p = %.4g %s\n', ...
        wlab{w}, mean(Rv(:,w)), mean(Vo(:,w)), mean(Vc(:,w)), pw(w), stars(pw(w)));
end

fig_Vr = paperFig(5, 4);
ax_vr = axes(fig_Vr,'Units','normalized','Position',[0.18 0.14 0.78 0.78]);
hold(ax_vr,'on');
for s = 1:size(Rv,1)
    plot(ax_vr, 1:nW, Rv(s,:), '-o', 'Color',[0.6 0.6 0.6], 'MarkerSize',3, ...
        'MarkerFaceColor',[0.6 0.6 0.6], 'LineWidth',0.6, 'HandleVisibility','off');
end
plot(ax_vr, 1:nW, mean(Rv,1), 'k-o', 'LineWidth',1.5, 'MarkerSize',5, ...
    'MarkerFaceColor','k', 'DisplayName','Mean');
yline(ax_vr, 1, 'k--', 'LineWidth',0.75, 'HandleVisibility','off');
hold(ax_vr,'off');
xlim(ax_vr, [0.5 nW+0.5]);
ax_vr.XTick = 1:nW; ax_vr.XTickLabel = wlab;
ylabel(ax_vr, 'OL/CL variance ratio', 'FontWeight','bold');
lgd_vr = legend(ax_vr, 'Location','best'); paperLegend(lgd_vr);
yl = ylim(ax_vr);
sy = yl(2) + 0.04*(yl(2)-yl(1));
ylim(ax_vr, [yl(1), yl(2) + 0.12*(yl(2)-yl(1))]);
for w = 1:nW
    ss = stars(pw(w));
    if ~isempty(ss)
        text(ax_vr, w, sy, ss, 'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
            'FontSize',6, 'FontWeight','bold', 'Color','k');
    end
end
paperExport(fig_Vr, fullfile(outDir, 'variance_ratio_4windows.pdf'));

fprintf('[F3] re-exported 3F / 3G / 3H + variance_ratio_4windows -> %s\n', outDir);
