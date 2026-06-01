% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

%% F: Cross-session variance  (2.33" wide -- matches 1/3 page column)
PS = paperStyle();
setPaperDefaults();
fig_F = paperFig(3, 3.5);

lm2 = 0.13; rm2 = 0.05; bm2 = 0.12; tm2 = 0.08;
ax_var = axes(fig_F, 'Position', [lm2, bm2, 1-lm2-rm2, 1-bm2-tm2]);

hold(ax_var, 'on');
plot(ax_var, tp, Mean_var_nc, 'r',               'LineWidth', 1.5);
plot(ax_var, tp, Mean_var_wc, 'Color',[0,0.5,0], 'LineWidth', 1.5);
xline(ax_var, 0,   'LineWidth', 0.75, 'HandleVisibility','off');
xline(ax_var, dur, 'LineWidth', 0.75, 'HandleVisibility','off');
ylim(ax_var, [-2 12]);
xlim(ax_var, [-3 dur+3]);
addStimPatch(ax_var, 0, dur);
uistack(findobj(ax_var,'Type','line'), 'top');
hold(ax_var, 'off');
paperAxes(ax_var, 'XLength', 1, 'YLength', 0.01, 'XLabel', '1 s', 'YLabel', ' ');
text(ax_var, -0.12, 0.5, {'Average of Session'; 'Variance across trials'}, ...
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');

paperExport(fig_F, 'paper/images/figure3/all_variance_sessions.pdf');


%% Fr: Cross-session OL/CL variance ratio -- pre / stim / post windows
valid_rows_f = any(Mvarnc > 0, 2) & any(Mvarwc > 0, 2);
Mvarnc_f = Mvarnc(valid_rows_f, :);
Mvarwc_f = Mvarwc(valid_rows_f, :);
nSess_f  = size(Mvarnc_f, 1);

idx_pre_f  = tp >= -3 & tp <  0;
idx_stim_f = tp >=  0 & tp <= dur;
idx_post_f = tp >  dur & tp <= dur+3;

r_pre_f  = mean(Mvarnc_f(:, idx_pre_f),  2) ./ mean(Mvarwc_f(:, idx_pre_f),  2);
r_stim_f = mean(Mvarnc_f(:, idx_stim_f), 2) ./ mean(Mvarwc_f(:, idx_stim_f), 2);
r_post_f = mean(Mvarnc_f(:, idx_post_f), 2) ./ mean(Mvarwc_f(:, idx_post_f), 2);

% Wilcoxon signed-rank tests: OL variance vs CL variance per window
% Test whether variance ratio differs from 1 (OL != CL).
% For each window, collect per-session OL and CL mean variance, then test.
varnc_pre_f  = mean(Mvarnc_f(:, idx_pre_f),  2);
varnc_stim_f = mean(Mvarnc_f(:, idx_stim_f), 2);
varnc_post_f = mean(Mvarnc_f(:, idx_post_f), 2);
varwc_pre_f  = mean(Mvarwc_f(:, idx_pre_f),  2);
varwc_stim_f = mean(Mvarwc_f(:, idx_stim_f), 2);
varwc_post_f = mean(Mvarwc_f(:, idx_post_f), 2);

p_fr_pre  = signrank(varnc_pre_f,  varwc_pre_f);
p_fr_stim = signrank(varnc_stim_f, varwc_stim_f);
p_fr_post = signrank(varnc_post_f, varwc_post_f);

stars_fr = @(p) repmat('*', 1, (p < 0.001)*3 + (p >= 0.001 && p < 0.01)*2 + (p >= 0.01 && p < 0.05)*1);

fig_Fr = paperFig(5, 4);
ax_fr = axes(fig_Fr, 'Units','normalized', 'Position',[0.18 0.14 0.78 0.78]);
hold(ax_fr, 'on');

for s = 1:nSess_f
    plot(ax_fr, [1 2 3], [r_pre_f(s) r_stim_f(s) r_post_f(s)], ...
        '-o', 'Color',[0.6 0.6 0.6], 'MarkerSize',3, ...
        'MarkerFaceColor',[0.6 0.6 0.6], 'LineWidth',0.6, 'HandleVisibility','off');
end
plot(ax_fr, [1 2 3], [mean(r_pre_f) mean(r_stim_f) mean(r_post_f)], ...
    'k-o', 'LineWidth',1.5, 'MarkerSize',5, 'MarkerFaceColor','k', 'DisplayName','Mean');
yline(ax_fr, 1, 'k--', 'LineWidth',0.75, 'HandleVisibility','off');
hold(ax_fr, 'off');

xlim(ax_fr, [0.5 3.5]);
ax_fr.XTick = [1 2 3]; ax_fr.XTickLabel = {'Pre','Stim','Post'};
ylabel(ax_fr, 'OL/CL variance ratio', 'FontWeight','bold');
lgd_fr = legend(ax_fr, 'Location','best'); paperLegend(lgd_fr);

% Add significance stars above each window point
yl_fr = ylim(ax_fr);
star_y_fr = yl_fr(2) + 0.04 * (yl_fr(2) - yl_fr(1));
ylim(ax_fr, [yl_fr(1), yl_fr(2) + 0.12 * (yl_fr(2) - yl_fr(1))]);
fr_pvals = {p_fr_pre, p_fr_stim, p_fr_post};
for wi = 1:3
    ss = stars_fr(fr_pvals{wi});
    if ~isempty(ss)
        text(ax_fr, wi, star_y_fr, ss, 'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', 'FontSize',6, 'FontWeight','bold', 'Color','k');
    end
end

paperExport(fig_Fr, 'paper/images/figure3/variance_ratio_by_window.pdf');

%% Variance slope test -- OL: linear trend in variance across pre / stim / post windows
% Three windows: pre (-3 to 0 s), stim (0 to dur s), post (dur to dur+3 s).
% Slope ~ 0 means flat variance; compare windows to characterise onset and recovery.
% Reports per-session slopes + cross-session mean +/- SEM for use in results_edit.tex L50.

col_ol_ov = [0.2 0.4 0.8];

valid_rows_ov = any(Mvarnc > 0, 2);
Mvarnc_v      = Mvarnc(valid_rows_ov, :);
nV_ov         = size(Mvarnc_v, 1);

idx_pre_sl  = tp >= -3  & tp <= 0;
idx_stim_sl = tp >= 0   & tp <= dur;
idx_post_sl = tp >= dur & tp <= dur+3;
tp_pre_sl   = tp(idx_pre_sl);
tp_stim_sl  = tp(idx_stim_sl);
tp_post_sl  = tp(idx_post_sl);

% Per-session linear slopes (polyfit degree 1, slope = coefficient(1))
slope_pre_sl  = zeros(nV_ov, 1);
slope_stim_sl = zeros(nV_ov, 1);
slope_post_sl = zeros(nV_ov, 1);
for s = 1:nV_ov
    p_pre_s  = polyfit(tp_pre_sl,  Mvarnc_v(s, idx_pre_sl),  1);
    p_stim_s = polyfit(tp_stim_sl, Mvarnc_v(s, idx_stim_sl), 1);
    p_post_s = polyfit(tp_post_sl, Mvarnc_v(s, idx_post_sl), 1);
    slope_pre_sl(s)  = p_pre_s(1);
    slope_stim_sl(s) = p_stim_s(1);
    slope_post_sl(s) = p_post_s(1);
end

% Cross-session mean fit (fit to the mean variance trace)
mu_pre_sl  = mean(Mvarnc_v(:, idx_pre_sl),  1);
mu_stim_sl = mean(Mvarnc_v(:, idx_stim_sl), 1);
mu_post_sl = mean(Mvarnc_v(:, idx_post_sl), 1);
p_mean_pre_sl  = polyfit(tp_pre_sl,  mu_pre_sl,  1);
p_mean_stim_sl = polyfit(tp_stim_sl, mu_stim_sl, 1);
p_mean_post_sl = polyfit(tp_post_sl, mu_post_sl, 1);

% Console report
fprintf('\nVariance slope test  (OL only, n=%d sessions)\n', nV_ov);
fprintf('  Sess   slope_pre   slope_stim   slope_post\n');
for s = 1:nV_ov
    fprintf('  %2d     %+.4f      %+.4f       %+.4f\n', s, slope_pre_sl(s), slope_stim_sl(s), slope_post_sl(s));
end
fprintf('  Mean   %+.4f      %+.4f       %+.4f\n', mean(slope_pre_sl), mean(slope_stim_sl), mean(slope_post_sl));
fprintf('  SEM    %+.4f      %+.4f       %+.4f\n', std(slope_pre_sl)/sqrt(nV_ov), std(slope_stim_sl)/sqrt(nV_ov), std(slope_post_sl)/sqrt(nV_ov));

% ---- Paper figure: variance trace with fitted slope lines ------------------
fig_ov = paperFig(6, 4);
ax_ov  = axes(fig_ov, 'Units','normalized', 'Position',[0.18 0.05 0.79 0.88]);
hold(ax_ov, 'on');

idx_all_sl = tp >= -3 & tp <= dur+3;
tp_all_sl  = tp(idx_all_sl);

% Faint per-session variance traces
for s = 1:nV_ov
    plot(ax_ov, tp_all_sl, Mvarnc_v(s, idx_all_sl), ...
        'Color',[col_ol_ov, 0.25], 'LineWidth',PS.lw_trial, 'HandleVisibility','off');
end

% Cross-session mean variance trace + SEM ribbon
mu_all_sl  = mean(Mvarnc_v(:, idx_all_sl), 1);
sem_all_sl = std(Mvarnc_v(:, idx_all_sl), 0, 1) / sqrt(nV_ov);
fill(ax_ov, [tp_all_sl, fliplr(tp_all_sl)], ...
    [mu_all_sl+sem_all_sl, fliplr(mu_all_sl-sem_all_sl)], ...
    col_ol_ov, 'FaceAlpha',PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax_ov, tp_all_sl, mu_all_sl, 'Color',col_ol_ov, 'LineWidth',PS.lw_mean, ...
    'DisplayName','OL mean');

% Mean slope lines per window (dashed black, excluded from legend)
plot(ax_ov, tp_pre_sl,  polyval(p_mean_pre_sl,  tp_pre_sl),  'k--', 'LineWidth',PS.lw_fit, 'HandleVisibility','off');
plot(ax_ov, tp_stim_sl, polyval(p_mean_stim_sl, tp_stim_sl), 'k--', 'LineWidth',PS.lw_fit, 'HandleVisibility','off');
plot(ax_ov, tp_post_sl, polyval(p_mean_post_sl, tp_post_sl), 'k--', 'LineWidth',PS.lw_fit, 'HandleVisibility','off');

% Expand ylim downward first, then draw stim patch against final bounds
yl_ov = ylim(ax_ov);
ylim(ax_ov, [yl_ov(1) - 0.05*(yl_ov(2)-yl_ov(1)), yl_ov(2)]);
yl_ov = ylim(ax_ov);
patch(ax_ov, [0 dur dur 0], [yl_ov(1) yl_ov(1) yl_ov(2) yl_ov(2)], ...
    [0.85 0.85 0.85], 'FaceAlpha',0.5, 'EdgeColor','none', 'HandleVisibility','off');
uistack(findobj(ax_ov, 'Type','patch', 'FaceColor',[0.85 0.85 0.85]), 'bottom');

% Slope annotations at bottom of each region
x_mid_pre  = -1.5;
x_mid_stim = dur / 2;
x_mid_post = dur + 1.5;
y_bot = yl_ov(1);
text(ax_ov, x_mid_pre,  y_bot, sprintf('slope=%+.2f', p_mean_pre_sl(1)), ...
    'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','k', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
text(ax_ov, x_mid_stim, y_bot, sprintf('slope=%+.2f', p_mean_stim_sl(1)), ...
    'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','k', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
text(ax_ov, x_mid_post, y_bot, sprintf('slope=%+.2f', p_mean_post_sl(1)), ...
    'FontSize',PS.fs, 'FontWeight',PS.fw, 'Color','k', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');

hold(ax_ov, 'off');
xlim(ax_ov, [-3 dur+3]);

lgd_ov = legend(ax_ov, 'Location','northeast'); paperLegend(lgd_ov);

text(ax_ov, -0.10, 0.5, {'Variance across trials' ;'for all sessions'}, ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'Color','k', 'Clipping','off');
paperAxes(ax_ov, 'XLength',1, 'YLength',0.01, 'XLabel','1 s', 'YLabel',' ');

paperExport(fig_ov, 'paper/images/figure2/onset_variance_slope.pdf');
fprintf('Variance slope figure ready\n');

%% G: Cross-session MSE violin  (7.0" wide -- fills full page width)
fig_G = paperFig(8, 4);

lm_g = 0.10; rm_g = 0.05; bm_g = 0.12; tm_g = 0.08;
ax_mse = axes(fig_G, 'Position', [lm_g, bm_g, 1-lm_g-rm_g, 1-bm_g-tm_g]);
hold(ax_mse, 'on');

halfWidth = 0.3;
alphaFill = 0.5;
colA = PS.col_ol;
colB = PS.col_cl;

for k = 1:length(fields)
    if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
    er_ncDfk = mouse.(fields{k}).data.er_ncDfk;
    er_wcDfk = mouse.(fields{k}).data.er_wcDfk;

    [fA, yA] = ksdensity(er_ncDfk);
    fA = fA / max(fA) * halfWidth;
    fill(ax_mse, [k - fA, k*ones(size(fA))], [yA, fliplr(yA)], ...
         colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');
    plot(ax_mse, k - 0.1, mean(er_ncDfk), 'r*', 'LineWidth', 0.5, 'MarkerSize',3);

    [fB, yB] = ksdensity(er_wcDfk);
    fB = fB / max(fB) * halfWidth;
    fill(ax_mse, [k + fB, k*ones(size(fB))], [yB, fliplr(yB)], ...
         colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');
    plot(ax_mse, k + 0.1, mean(er_wcDfk), 'g*', 'LineWidth', 0.5, 'MarkerSize',3);
end
hold(ax_mse, 'off');

numExp = length(fields);
xlim(ax_mse, [0.5 numExp+0.5]);
cleanAxes(ax_mse);
text(ax_mse, -0.06, 0.5, 'Trial MSE', ...
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
text(ax_mse, 0.5, -0.02, 'Sessions', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', 'VerticalAlignment','top', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
% text(ax_mse, 0.0, 0.95, 'G', 'Units','normalized', 'FontSize', 6, ...
%     'FontWeight','bold', 'Clipping','off');

paperExport(fig_G, 'paper/images/figure3/all_MSE_sessions.pdf');


%% G2: Windowed MSE -- t = +1 to +3 s (Nick 2026-05-08) vs full window t = 0Ã¢â‚¬â€œ3 s
% Slices already-loaded ncDfk/wcDfk -- no cache regeneration needed.
% ncDfk col 36 = onset (t=0), col 71 = t=+1 s, col 141 = t=+3 s  (dur=3, 35 Hz).

ref_g2  = -5;
c0_g2   = 36;    % onset col in ncDfk
c1w_g2  = 71;    % t = +1 s
c2w_g2  = 141;   % t = +3 s
hw_g2   = 0.3;   % half-violin width
al_g2   = 0.5;   % fill alpha

% --- G2a: trial-average traces OL vs CL across sessions ---
% Full [0,+3]s trace with grey shading on the [+1,+3]s MSE window.
% Per-session faint lines + cross-session mean +/- SEM. Reference at -5%%.

t_g2_av  = (0 : c2w_g2 - c0_g2) / 35;   % 0 to 3 s, 106 pts
nc_tr_g2 = [];   wc_tr_g2 = [];

fprintf('\nMSE window comparison (RMS, ref = -5)\n');
fprintf('%-4s  %6s %6s %5s | %6s %6s %5s\n','ses','OL_03','CL_03','R_03','OL_13','CL_13','R_13');

nSess_g2 = length(fields);
for k = 1:nSess_g2
    if isfield(mouse.(fields{k}),'skip') && mouse.(fields{k}).skip; continue; end
    dk = mouse.(fields{k}).data;

    enc_f = sqrt(mean((dk.ncDfk(:, c0_g2:c2w_g2) - ref_g2).^2, 2));
    ewc_f = sqrt(mean((dk.wcDfk(:, c0_g2:c2w_g2) - ref_g2).^2, 2));
    enc_w = sqrt(mean((dk.ncDfk(:, c1w_g2:c2w_g2) - ref_g2).^2, 2));
    ewc_w = sqrt(mean((dk.wcDfk(:, c1w_g2:c2w_g2) - ref_g2).^2, 2));

    mouse.(fields{k}).data.er_ncDfk_w = enc_w;
    mouse.(fields{k}).data.er_wcDfk_w = ewc_w;

    enc_e = sqrt(mean((dk.ncDfk(:, c0_g2:c1w_g2) - ref_g2).^2, 2));
    ewc_e = sqrt(mean((dk.wcDfk(:, c0_g2:c1w_g2) - ref_g2).^2, 2));
    mouse.(fields{k}).data.er_ncDfk_e = enc_e;
    mouse.(fields{k}).data.er_wcDfk_e = ewc_e;

    nc_tr_g2 = [nc_tr_g2; mean(dk.ncDfk(:, c0_g2:c2w_g2), 1)];
    wc_tr_g2 = [wc_tr_g2; mean(dk.wcDfk(:, c0_g2:c2w_g2), 1)];

    fprintf('%4d  %6.3f %6.3f %5.2f | %6.3f %6.3f %5.2f\n', k, ...
        mean(enc_f), mean(ewc_f), mean(enc_f)/mean(ewc_f), ...
        mean(enc_w), mean(ewc_w), mean(enc_w)/mean(ewc_w));
end

nS_g2   = size(nc_tr_g2, 1);
mu_nc_g2  = mean(nc_tr_g2, 1);  sem_nc_g2 = std(nc_tr_g2, 0, 1) / sqrt(nS_g2);
mu_wc_g2  = mean(wc_tr_g2, 1);  sem_wc_g2 = std(wc_tr_g2, 0, 1) / sqrt(nS_g2);

fig_G2a = paperFig(8, 5);
ax_G2a  = axes(fig_G2a,'Units','normalized','Position',[0.14 0.18 0.80 0.72]);
hold(ax_G2a,'on');

% Grey shading for the [+1,+3]s windowed MSE region
yp_g2 = [-30 -30 30 30];
patch(ax_G2a,[1 3 3 1], yp_g2,[0.88 0.88 0.88],'FaceAlpha',0.5,'EdgeColor','none','HandleVisibility','off');

% Faint per-session traces
for s = 1:nS_g2
    plot(ax_G2a,t_g2_av,nc_tr_g2(s,:),'Color',[1 0 0 0.12],'LineWidth',0.4,'HandleVisibility','off');
    plot(ax_G2a,t_g2_av,wc_tr_g2(s,:),'Color',[0 0.5 0 0.12],'LineWidth',0.4,'HandleVisibility','off');
end

% Cross-session mean +/- SEM
fill(ax_G2a,[t_g2_av,fliplr(t_g2_av)],[mu_nc_g2+sem_nc_g2,fliplr(mu_nc_g2-sem_nc_g2)],...
    [1 0 0],'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
plot(ax_G2a,t_g2_av,mu_nc_g2,'r','LineWidth',1.5,'DisplayName','OL mean');
fill(ax_G2a,[t_g2_av,fliplr(t_g2_av)],[mu_wc_g2+sem_wc_g2,fliplr(mu_wc_g2-sem_wc_g2)],...
    [0 0.5 0],'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
plot(ax_G2a,t_g2_av,mu_wc_g2,'Color',[0 0.5 0],'LineWidth',1.5,'DisplayName','CL mean');

yline(ax_G2a,ref_g2,'k--','LineWidth',0.75,'HandleVisibility','off');   % reference
xline(ax_G2a,1,'Color',[0.5 0.5 0.5],'LineStyle',':','LineWidth',0.75,'HandleVisibility','off');
hold(ax_G2a,'off');
legend(ax_G2a,'Box','off','FontSize',6,'Location','best');
xlabel(ax_G2a,'Time (s)','FontWeight','bold','FontSize',6);
ylabel(ax_G2a,'dF/F (%)', 'FontWeight','bold','FontSize',6);
title(ax_G2a,sprintf('Trial averages  (n=%d sess,  grey=[+1,+3]s MSE window)', nS_g2),...
    'FontSize',6,'FontWeight','bold');
set(ax_G2a,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
% exportgraphics(fig_G2a,'paper/MSE_window_comparison.pdf','ContentType','vector');

% --- G2b: windowed MSE vs trial number (per session) ---
nValid_g2 = sum(cellfun(@(f) ~(isfield(mouse.(f),'skip') && mouse.(f).skip), fields));
nC_g2 = min(4, nValid_g2);
nR_g2 = ceil(nValid_g2 / nC_g2);
fig_G2b = paperFig(nC_g2*5, nR_g2*4);
ki_g2 = 0;
for k = 1:length(fields)
    if isfield(mouse.(fields{k}),'skip') && mouse.(fields{k}).skip; continue; end
    ki_g2 = ki_g2 + 1;
    ax_s = subplot(nR_g2, nC_g2, ki_g2);
    hold(ax_s,'on');
    dk = mouse.(fields{k}).data;
    scatter(ax_s, dk.nc, dk.er_ncDfk_w, 8, [1 0 0],   'filled','MarkerFaceAlpha',0.5);
    scatter(ax_s, dk.wc, dk.er_wcDfk_w, 8, [0 0.5 0], 'filled','MarkerFaceAlpha',0.5);
    hold(ax_s,'off');
    cleanAxes(ax_s);
    title(ax_s, sprintf('S%d', k),'FontSize',6,'FontWeight','bold');
    xlabel(ax_s,'Trial #','FontSize',6,'FontWeight','bold');
    if mod(ki_g2-1, nC_g2) == 0
        ylabel(ax_s,'RMS MSE (\DeltaF/F)','FontSize',6,'FontWeight','bold');
    end
end
paperExport(fig_G2b,'paper/MSE_vs_trial_number.png');


%% G2r: OL/CL ratio by window -- 4 windows: pre / 0-1 s / 1-3 s / post
% Y-axis is dimensionless OL/CL ratio: >1 means CL better.
% Windows: pre (-3 to 0 s), early stim (0-1 s), late stim (1-3 s), post (3 to 6 s).
% ncDfk layout: col 1 = t=-1s, col 36 = onset (t=0), col 71 = t=+1s,
%               col 141 = t=+3s (end of stim, dur=3s), col 176 = t=+4s (end of ncDfk).
% Pre-stim uses pncDfk_l cols 1:105 (3s*35Hz pre-onset).
% Post-stim uses ncDfk cols 142:end (beyond t=+3s, ~1 s available in ncDfk).
ref_g2r = -5;
c0_g2r  = 36;   % onset col in ncDfk
c1_g2r  = 71;   % t = +1 s
c2_g2r  = 141;  % t = +3 s (end of stim)
Fs_g2r  = 35;

r_pre_g2r   = zeros(1, nValid_g2);
r_early_g2r = zeros(1, nValid_g2);  % 0-1 s
r_late_g2r  = zeros(1, nValid_g2);  % 1-3 s
r_post_g2r  = zeros(1, nValid_g2);

ki_r = 0;
for k = 1:length(fields)
    if isfield(mouse.(fields{k}),'skip') && mouse.(fields{k}).skip; continue; end
    ki_r = ki_r + 1;
    dk = mouse.(fields{k}).data;

    % Pre-stim: 3 s pre-onset from pncDfk_l (cols 1:3*Fs_g2r)
    pre_cols = 1 : 3*Fs_g2r;
    if isfield(dk,'pncDfk_l') && size(dk.pncDfk_l,2) >= max(pre_cols)
        enc_pre = sqrt(mean((dk.pncDfk_l(:, pre_cols) - ref_g2r).^2, 2));
        ewc_pre = sqrt(mean((dk.pwcDfk_l(:, pre_cols) - ref_g2r).^2, 2));
    else
        % fallback: first 35 cols of ncDfk (1 s pre-onset)
        enc_pre = sqrt(mean((dk.ncDfk(:, 1:c0_g2r-1) - ref_g2r).^2, 2));
        ewc_pre = sqrt(mean((dk.wcDfk(:, 1:c0_g2r-1) - ref_g2r).^2, 2));
    end

    % Early stim: 0-1 s (cols c0_g2r to c1_g2r in ncDfk)
    enc_e = sqrt(mean((dk.ncDfk(:, c0_g2r:c1_g2r) - ref_g2r).^2, 2));
    ewc_e = sqrt(mean((dk.wcDfk(:, c0_g2r:c1_g2r) - ref_g2r).^2, 2));

    % Late stim: 1-3 s (cols c1_g2r+1 to c2_g2r in ncDfk)
    enc_w = sqrt(mean((dk.ncDfk(:, c1_g2r+1:c2_g2r) - ref_g2r).^2, 2));
    ewc_w = sqrt(mean((dk.wcDfk(:, c1_g2r+1:c2_g2r) - ref_g2r).^2, 2));

    % Post-stim: cols c2_g2r+1 to end of ncDfk (~1 s)
    nc_ncols = size(dk.ncDfk, 2);
    wc_ncols = size(dk.wcDfk, 2);
    if nc_ncols > c2_g2r && wc_ncols > c2_g2r
        enc_post = sqrt(mean((dk.ncDfk(:, c2_g2r+1:nc_ncols) - ref_g2r).^2, 2));
        ewc_post = sqrt(mean((dk.wcDfk(:, c2_g2r+1:wc_ncols) - ref_g2r).^2, 2));
    else
        enc_post = enc_w;  ewc_post = ewc_w;  % fallback: repeat late window
    end

    r_pre_g2r(ki_r)   = mean(enc_pre)  / mean(ewc_pre);
    r_early_g2r(ki_r) = mean(enc_e)    / mean(ewc_e);
    r_late_g2r(ki_r)  = mean(enc_w)    / mean(ewc_w);
    r_post_g2r(ki_r)  = mean(enc_post) / mean(ewc_post);
end

fig_G2r = paperFig(5, 4);
ax_g2r = axes(fig_G2r,'Units','normalized','Position',[0.18 0.14 0.78 0.78]);
hold(ax_g2r,'on');

for ki = 1:nValid_g2
    plot(ax_g2r, [1 2 3 4], ...
        [r_pre_g2r(ki) r_early_g2r(ki) r_late_g2r(ki) r_post_g2r(ki)], ...
        '-o', 'Color',[0.6 0.6 0.6], 'MarkerSize',3, ...
        'MarkerFaceColor',[0.6 0.6 0.6], 'LineWidth',0.6, 'HandleVisibility','off');
end
% Mean line
plot(ax_g2r, [1 2 3 4], ...
    [mean(r_pre_g2r) mean(r_early_g2r) mean(r_late_g2r) mean(r_post_g2r)], 'k-o', ...
    'LineWidth',1.5, 'MarkerSize',5, 'MarkerFaceColor','k', 'DisplayName','Mean');
yline(ax_g2r, 1, 'k--', 'LineWidth',0.75, 'HandleVisibility','off');
hold(ax_g2r,'off');

xlim(ax_g2r, [0.5 4.5]);
ax_g2r.XTick = [1 2 3 4];
ax_g2r.XTickLabel = {'Pre','0-1 s','1-3 s','Post'};
ylabel(ax_g2r, 'OL/CL RMS ratio', 'FontWeight','bold');
lgd_g2r = legend(ax_g2r, 'Location','best'); paperLegend(lgd_g2r);
paperExport(fig_G2r, 'paper/images/figure3/MSE_ratio_by_window.pdf');


%% G2v: Windowed MSE violin -- Option B (grouped per session, both windows)
% Both windows use RMS (sample-normalised) so absolute values are comparable.
% Level difference between windows reflects transient vs steady-state, not
% window-length bias. Compare OL-CL gap within each window pair.
fig_G2v = paperFig(9, 4);
lm_gv = 0.13; rm_gv = 0.03; bm_gv = 0.14; tm_gv = 0.08;
ax_gv = axes(fig_G2v,'Position',[lm_gv bm_gv 1-lm_gv-rm_gv 1-bm_gv-tm_gv]);
hold(ax_gv,'on');

hw_gv = 0.35; al_e = 0.65; al_w = 0.35;   % early=opaque, late=transparent
colA_gv = PS.col_ol; colB_gv = PS.col_cl;
xt_gv = zeros(1, nValid_g2);               % tick positions (session centres)

ki_gv = 0;
for k = 1:length(fields)
    if isfield(mouse.(fields{k}),'skip') && mouse.(fields{k}).skip; continue; end
    ki_gv = ki_gv + 1;
    enc_e = mouse.(fields{k}).data.er_ncDfk_e;
    ewc_e = mouse.(fields{k}).data.er_wcDfk_e;
    enc_w = mouse.(fields{k}).data.er_ncDfk_w;
    ewc_w = mouse.(fields{k}).data.er_wcDfk_w;

    x_e = 3*(ki_gv-1) + 1;   % 0-1 s pair centre
    x_w = 3*(ki_gv-1) + 2;   % 1-3 s pair centre
    xt_gv(ki_gv) = (x_e + x_w) / 2;

    % 0-1 s pair (opaque)
    [fA,yA] = ksdensity(enc_e); fA = fA/max(fA)*hw_gv;
    fill(ax_gv,[x_e-fA, x_e*ones(size(fA))],[yA,fliplr(yA)],colA_gv,'FaceAlpha',al_e,'EdgeColor','none','HandleVisibility','off');
    plot(ax_gv, x_e-0.12, mean(enc_e), 'r.', 'MarkerSize',5,'HandleVisibility','off');
    [fB,yB] = ksdensity(ewc_e); fB = fB/max(fB)*hw_gv;
    fill(ax_gv,[x_e+fB, x_e*ones(size(fB))],[yB,fliplr(yB)],colB_gv,'FaceAlpha',al_e,'EdgeColor','none','HandleVisibility','off');
    plot(ax_gv, x_e+0.12, mean(ewc_e), 'g.', 'MarkerSize',5,'HandleVisibility','off');

    % 1-3 s pair (semi-transparent)
    [fA,yA] = ksdensity(enc_w); fA = fA/max(fA)*hw_gv;
    fill(ax_gv,[x_w-fA, x_w*ones(size(fA))],[yA,fliplr(yA)],colA_gv,'FaceAlpha',al_w,'EdgeColor','none','HandleVisibility','off');
    plot(ax_gv, x_w-0.12, mean(enc_w), 'r.', 'MarkerSize',5,'HandleVisibility','off');
    [fB,yB] = ksdensity(ewc_w); fB = fB/max(fB)*hw_gv;
    fill(ax_gv,[x_w+fB, x_w*ones(size(fB))],[yB,fliplr(yB)],colB_gv,'FaceAlpha',al_w,'EdgeColor','none','HandleVisibility','off');
    plot(ax_gv, x_w+0.12, mean(ewc_w), 'g.', 'MarkerSize',5,'HandleVisibility','off');
end
nV_gv = ki_gv;
hold(ax_gv,'off');

% Session x-ticks
xlim(ax_gv, [0.3, 3*nV_gv-0.3]);
ax_gv.XTick = xt_gv; ax_gv.XTickLabel = arrayfun(@(n) sprintf('S%d',n), 1:nV_gv, 'UniformOutput',false);
ylabel(ax_gv, 'RMS MSE (\DeltaF/F)', 'FontWeight','bold');

% Legend: OL/CL colour + early/late alpha
patch(ax_gv,NaN,NaN,colA_gv,'FaceAlpha',al_e,'EdgeColor','none','DisplayName','OL 0-1 s');
patch(ax_gv,NaN,NaN,colB_gv,'FaceAlpha',al_e,'EdgeColor','none','DisplayName','CL 0-1 s');
patch(ax_gv,NaN,NaN,colA_gv,'FaceAlpha',al_w,'EdgeColor','none','DisplayName','OL 1-3 s');
patch(ax_gv,NaN,NaN,colB_gv,'FaceAlpha',al_w,'EdgeColor','none','DisplayName','CL 1-3 s');
lgd_gv = legend(ax_gv,'Location','northeast'); paperLegend(lgd_gv);
paperExport(fig_G2v,'paper/MSE_windowed_violin.png');
