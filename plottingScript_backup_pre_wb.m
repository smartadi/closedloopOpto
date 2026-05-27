%% 
%% plotting across sessions


clc;
close all;
clear all;


%% get data
pathString = genpath('utils');
    addpath(pathString);




%%  save data as npy

mouse.m1.mn = 'AL_0033'; mouse.m1.td = '2025-01-20'; 
mouse.m1.en = 3;
mouse.m1.trials = 120;

mouse.m2.mn = 'AL_0033'; mouse.m2.td = '2025-02-12'; 
mouse.m2.en = 2;
mouse.m2.trials = 200;

mouse.m3.mn = 'AL_0033'; mouse.m3.td = '2025-02-24'; 
mouse.m3.en = 2;
mouse.m3.trials = 200;

mouse.m4.mn = 'AL_0033'; mouse.m4.td = '2025-02-26'; 
mouse.m4.en = 2;
mouse.m4.trials = 200;

mouse.m5.mn = 'AL_0033'; mouse.m5.td = '2025-03-04'; 
mouse.m5.en = 1;
mouse.m5.trials = 60;


mouse.m6.mn = 'AL_0033'; mouse.m6.td = '2025-03-05'; 
mouse.m6.en = 2;
mouse.m6.trials = 30;

mouse.m7.mn = 'AL_0033'; mouse.m7.td = '2025-03-20'; 
mouse.m7.en = 4;
mouse.m7.trials = 100;

mouse.m8.mn = 'AL_0033'; mouse.m8.td = '2025-04-15'; 
mouse.m8.en = 2;
mouse.m8.trials = 60;


mouse.m9.mn = 'AL_0039'; mouse.m9.td = '2025-04-20'; 
mouse.m9.en = 1;
mouse.m9.trials = 100;


mouse.m10.mn = 'AL_0039'; mouse.m10.td = '2025-04-19'; 
mouse.m10.en = 1;
mouse.m10.trials = 100;

mouse.m11.mn = 'AL_0039'; mouse.m11.td = '2025-04-30'; 
mouse.m11.en = 3;
mouse.m11.trials = 100;


mouse.m12.mn = 'AL_0033'; mouse.m12.td = '2025-04-19'; 
mouse.m12.en = 1;
mouse.m12.trials = 100;

mouse.m13.mn = 'AL_0039'; mouse.m13.td = '2025-04-20'; 
mouse.m13.en = 2;
mouse.m13.trials = 100;



%% Feedforward vs Feedback

% r_ctrl = 0: recompute and overwrite cache (use after changing controllerData.m)
% r_ctrl = 1: load from cache if available
r_ctrl = 1;

fields = fieldnames(mouse);
for k = 1:length(fields)
    try
        mn_k = mouse.(fields{k}).mn;
        td_k = mouse.(fields{k}).td;
        en_k = mouse.(fields{k}).en;

        pathCtrl = fullfile('data', sprintf('%sctrl%s%s%d.mat', mn_k, td_k(6:7), td_k(9:10), en_k));

        if exist(pathCtrl, 'file') && r_ctrl == 1
            tmp = load(pathCtrl);
            mouse.(fields{k}).data = tmp.data;
            if isfield(tmp, 'd')
                mouse.(fields{k}).d = tmp.d;
            else
                mouse.(fields{k}).d = initialize_data(mn_k, en_k, td_k);
                mouse.(fields{k}).d.ref = -5;
                d    = mouse.(fields{k}).d;
                data = mouse.(fields{k}).data;
                save(pathCtrl, 'd', 'data');
                fprintf('Re-saved cache with d: %s\n', fields{k});
            end
            if ~isfield(mouse.(fields{k}).d, 'ref')
                mouse.(fields{k}).d.ref = -5;
            end
            fprintf('Loaded cache: %s\n', fields{k});
        else
            mouse.(fields{k}).d = initialize_data(mn_k, en_k, td_k);

            mode = 0;  % from binary image
            r    = 1;  % use dFk cache
            mouse.(fields{k}).data = getpixel_dFoF(mouse.(fields{k}).d, mode, mouse.(fields{k}).d.params.pixel, r);

            mouse.(fields{k}).d.ref = -5;
            mouse.(fields{k}).data = controllerData(mouse.(fields{k}).data, mouse.(fields{k}).d, mouse.(fields{k}).trials);

            d    = mouse.(fields{k}).d;
            data = mouse.(fields{k}).data;
            if ~exist('data', 'dir'); mkdir('data'); end
            save(pathCtrl, 'd', 'data');
            fprintf('Saved cache: %s\n', fields{k});
        end
    catch ME
        fprintf('Skipping %s: %s\n', fields{k}, ME.message);
        mouse.(fields{k}).skip = true;
    end
end


%%
Mvarnc = [];
Mvarwc = [];
for k = 1:length(fields)
    % mouse.(fields{k}).d = initialize_data(mouse.(fields{k}).mn, mouse.(fields{k}).en, mouse.(fields{k}).td);
    
    %
    
nc =  mouse.(fields{k}).data.nc;
wc =  mouse.(fields{k}).data.wc;

    dFk = mouse.(fields{k}).data.dFk;
dur =3;
er_ncDfk=[];
vr_ncDfk=[];
pncDfk = [];
error_nc = [];
ncInp=[];

error_NC = [];


spont_dFk = []

d = mouse.(fields{k}).d;
ti = mouse.(fields{k}).d.inpTime;

t = mouse.(fields{k}).d.timeBlue;
for j = 1: length(nc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(nc(j))));
    er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pncDfk = [pncDfk; dFk(i-35*3:i+35*(dur+3))];


    error_nc = [error_nc;dFk(i:i+35*(dur))+5];

    spont_dFk = [spont_dFk;dFk(i-(6*35):i-1)];


    [a i2] = min(abs(ti - d.stimStarts(nc(j))));
    
    
    ncInp = [ncInp; d.inpVals(i2:i2+dur*2000)'];

end


wcInp=[];

er_wcDfk=[];
vr_wcDfk=[];
pwcDfk = [];
error_wc = [];
for j = 1: length(wc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(wc(j))));
    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pwcDfk = [pwcDfk; dFk(i-35*3:i+35*(dur+3))];

    error_wc = [error_wc;dFk(i:i+35*(dur))+5];

    spont_dFk = [spont_dFk;dFk(i-(6*35):i-1)];

    [a i2] = min(abs(ti - d.stimStarts(wc(j))));
    
    
    wcInp = [wcInp; d.inpVals(i2:i2+dur*2000)'];
end

mouse.(fields{k}).data.er_wcDfk_l = er_wcDfk;
mouse.(fields{k}).data.er_ncDfk_l = er_ncDfk;
mouse.(fields{k}).data.pwcDfk_l = pwcDfk;

mouse.(fields{k}).data.error_nc = error_nc;

mouse.(fields{k}).data.vr_wcDfk_l = var(pwcDfk);
mouse.(fields{k}).data.vr_ncDfk_l = var(pncDfk);
mouse.(fields{k}).data.pncDfk_l = pncDfk;

mouse.(fields{k}).data.error_wc = error_wc;


mouse.(fields{k}).data.ncInp = ncInp;
mouse.(fields{k}).data.wcInp = wcInp;

mouse.(fields{k}).data.spont_dFk = spont_dFk;

Mvarnc = [Mvarnc;mouse.(fields{k}).data.vr_ncDfk_l];
Mvarwc = [Mvarwc;mouse.(fields{k}).data.vr_wcDfk_l];
end



%% analysisPlots_combined -> single session
selField = 10;   % <-- change to target session index

analysisPlots_combined(mouse.(fields{selField}).data, mouse.(fields{selField}).d);

%% SVD frame -- single session  (3 cm by 3 cm, high-res PDF)
d_sel        = mouse.(fields{selField}).d;
svdData.U    = d_sel.svd.U;
svdData.V    = d_sel.svd.V;
svdData.mimg = d_sel.svd.mimg;

displayFrame(mouse.(fields{selField}).mn, ...
             mouse.(fields{selField}).td, ...
             mouse.(fields{selField}).en, ...
             d_sel, d_sel.params.pixels, svdData);

fig_frame = gcf;
ax_frame  = gca;
colorbar('off');
set(ax_frame, 'XTick',[], 'YTick',[], 'DataAspectRatio',[1 1 1], 'Position',[0 0 1 1]);
set(fig_frame, 'Units','centimeters', 'Position',[0 0 3 3]);
exportgraphics(fig_frame, ...
    sprintf('paper/images/figure1/svd_frame_%s_%s.pdf', mouse.(fields{selField}).mn, mouse.(fields{selField}).td), ...
    'ContentType','image', 'Resolution',600, 'Padding','tight');

%%


%%
Mean_var_wc = mean(Mvarwc);
Mean_var_nc = mean(Mvarnc);
tp = (-3*35 : 35*(dur+3)) / 35;   % -3s to dur+3s, guaranteed 35*(dur+6)+1 pts




%% F: Cross-session variance  (2.33" wide -- matches 1/3 page column)
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
shortCornerAxes_plot(ax_var, 'XLength', 1, 'YLength', 0.01, ...
    'XLabel', '1 sec', 'YLabel', ' ', 'LineWidth', 2.5, 'LabelGap', 0.04);
cleanAxes(ax_var);
text(ax_var, -0.12, 0.5, {'Average of Session'; 'Variance across trials'}, ...
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');

exportgraphics(fig_F, 'paper/images/figure3/all_variance_sessions.pdf', 'ContentType','vector');


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

fig_Fr = paperFig(6, 4);
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
ax_fr.FontSize = 6; ax_fr.FontWeight = 'bold';
ax_fr.Box = 'off'; ax_fr.TickDir = 'out';
ylabel(ax_fr, 'OL/CL variance ratio', 'FontSize',6, 'FontWeight','bold');
legend(ax_fr, 'Box','off', 'FontSize',6, 'FontWeight','bold', 'Location','best');
exportgraphics(fig_Fr, 'paper/images/figure3/variance_ratio_by_window.pdf', 'ContentType','vector');

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
PS_ov = paperStyle();
fig_ov = paperFig(6, 4);
ax_ov  = axes(fig_ov, 'Units','normalized', 'Position',[0.18 0.05 0.79 0.88]);
hold(ax_ov, 'on');

idx_all_sl = tp >= -3 & tp <= dur+3;
tp_all_sl  = tp(idx_all_sl);

% Faint per-session variance traces
for s = 1:nV_ov
    plot(ax_ov, tp_all_sl, Mvarnc_v(s, idx_all_sl), ...
        'Color',[col_ol_ov, 0.25], 'LineWidth',PS_ov.lw_trial, 'HandleVisibility','off');
end

% Cross-session mean variance trace + SEM ribbon
mu_all_sl  = mean(Mvarnc_v(:, idx_all_sl), 1);
sem_all_sl = std(Mvarnc_v(:, idx_all_sl), 0, 1) / sqrt(nV_ov);
fill(ax_ov, [tp_all_sl, fliplr(tp_all_sl)], ...
    [mu_all_sl+sem_all_sl, fliplr(mu_all_sl-sem_all_sl)], ...
    col_ol_ov, 'FaceAlpha',PS_ov.fa, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax_ov, tp_all_sl, mu_all_sl, 'Color',col_ol_ov, 'LineWidth',PS_ov.lw_mean, ...
    'DisplayName','OL mean');

% Mean slope lines per window (dashed black, excluded from legend)
plot(ax_ov, tp_pre_sl,  polyval(p_mean_pre_sl,  tp_pre_sl),  'k--', 'LineWidth',PS_ov.lw_fit, 'HandleVisibility','off');
plot(ax_ov, tp_stim_sl, polyval(p_mean_stim_sl, tp_stim_sl), 'k--', 'LineWidth',PS_ov.lw_fit, 'HandleVisibility','off');
plot(ax_ov, tp_post_sl, polyval(p_mean_post_sl, tp_post_sl), 'k--', 'LineWidth',PS_ov.lw_fit, 'HandleVisibility','off');

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
    'FontSize',PS_ov.fs, 'FontWeight',PS_ov.fw, 'Color','k', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
text(ax_ov, x_mid_stim, y_bot, sprintf('slope=%+.2f', p_mean_stim_sl(1)), ...
    'FontSize',PS_ov.fs, 'FontWeight',PS_ov.fw, 'Color','k', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
text(ax_ov, x_mid_post, y_bot, sprintf('slope=%+.2f', p_mean_post_sl(1)), ...
    'FontSize',PS_ov.fs, 'FontWeight',PS_ov.fw, 'Color','k', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');

hold(ax_ov, 'off');
xlim(ax_ov, [-3 dur+3]);

lgd_ov = legend(ax_ov, 'Box','off', 'FontSize',PS_ov.fs, 'FontWeight',PS_ov.fw, 'Location','northeast');
lgd_ov.ItemTokenSize = [6 6];

cleanAxes(ax_ov);
text(ax_ov, -0.10, 0.5, {'Variance across trials' ;'for all sessions'}, ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',PS_ov.fs, 'FontWeight',PS_ov.fw, 'Color','k', 'Clipping','off');
shortCornerAxes_plot(ax_ov, 'XLength',1, 'YLength',0.01, 'XLabel','1 s', 'YLabel',' ', ...
    'LineWidth',PS_ov.sca_lw, 'LabelGap',PS_ov.sca_gap, 'FontSize',PS_ov.fs, 'FontWeight',PS_ov.fw);

exportgraphics(fig_ov, 'paper/images/figure2/onset_variance_slope.pdf', 'ContentType','vector');
fprintf('Variance slope figure ready\n');

%% G: Cross-session MSE violin  (7.0" wide -- fills full page width)
fig_G = paperFig(8, 4);

lm_g = 0.10; rm_g = 0.05; bm_g = 0.12; tm_g = 0.08;
ax_mse = axes(fig_G, 'Position', [lm_g, bm_g, 1-lm_g-rm_g, 1-bm_g-tm_g]);
hold(ax_mse, 'on');

halfWidth = 0.3;
alphaFill = 0.5;
colA = [1 0 0];
colB = [0 0.5 0];

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

exportgraphics(fig_G, 'paper/images/figure3/all_MSE_sessions.pdf', 'ContentType','image', 'Resolution',300, 'Padding','tight');


%% G2: Windowed MSE -- t = +1 to +3 s (Nick 2026-05-08) vs full window t = 0â€“3 s
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

fig_G2a = figure('Color','w','Units','centimeters','Position',[0 0 8 5]);
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
plot(ax_G2a,t_g2_av,mu_nc_g2,'r','LineWidth',2,'DisplayName','OL mean');
fill(ax_G2a,[t_g2_av,fliplr(t_g2_av)],[mu_wc_g2+sem_wc_g2,fliplr(mu_wc_g2-sem_wc_g2)],...
    [0 0.5 0],'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
plot(ax_G2a,t_g2_av,mu_wc_g2,'Color',[0 0.5 0],'LineWidth',2,'DisplayName','CL mean');

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
fig_G2b = figure('Color','w','Units','centimeters','Position',[0 0 nC_g2*5 nR_g2*4]);
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
exportgraphics(fig_G2b,'paper/MSE_vs_trial_number.png','Resolution',300);


%% G2r: OL/CL ratio by window -- Option A (ratio line plot)
% Y-axis is dimensionless OL/CL ratio: >1 means CL better.
% Comparing ratios across windows is valid regardless of absolute level.
fig_G2r = paperFig(6, 4);
ax_g2r = axes(fig_G2r,'Units','normalized','Position',[0.18 0.14 0.78 0.78]);
hold(ax_g2r,'on');

r_e_all = zeros(1, nValid_g2);
r_w_all = zeros(1, nValid_g2);
ki_r = 0;
for k = 1:length(fields)
    if isfield(mouse.(fields{k}),'skip') && mouse.(fields{k}).skip; continue; end
    ki_r = ki_r + 1;
    enc_e = mouse.(fields{k}).data.er_ncDfk_e;
    ewc_e = mouse.(fields{k}).data.er_wcDfk_e;
    enc_w = mouse.(fields{k}).data.er_ncDfk_w;
    ewc_w = mouse.(fields{k}).data.er_wcDfk_w;
    r_e_all(ki_r) = mean(enc_e) / mean(ewc_e);
    r_w_all(ki_r) = mean(enc_w) / mean(ewc_w);
    plot(ax_g2r, [1 2], [r_e_all(ki_r) r_w_all(ki_r)], ...
        '-o', 'Color',[0.6 0.6 0.6], 'MarkerSize',3, ...
        'MarkerFaceColor',[0.6 0.6 0.6], 'LineWidth',0.6, 'HandleVisibility','off');
end
% Mean line
plot(ax_g2r, [1 2], [mean(r_e_all) mean(r_w_all)], 'k-o', ...
    'LineWidth',1.5, 'MarkerSize',5, 'MarkerFaceColor','k', 'DisplayName','Mean');
yline(ax_g2r, 1, 'k--', 'LineWidth',0.75, 'HandleVisibility','off');
hold(ax_g2r,'off');

xlim(ax_g2r, [0.5 2.5]);
ax_g2r.XTick = [1 2]; ax_g2r.XTickLabel = {'0-1 s','1-3 s'};
ax_g2r.FontSize = 6; ax_g2r.FontWeight = 'bold'; ax_g2r.Box = 'off'; ax_g2r.TickDir = 'out';
ylabel(ax_g2r, 'OL/CL RMS ratio', 'FontSize',6, 'FontWeight','bold');
legend(ax_g2r, 'Box','off', 'FontSize',6, 'FontWeight','bold', 'Location','best');
exportgraphics(fig_G2r, 'paper/images/figure3/MSE_ratio_by_window.pdf', 'ContentType','vector');


%% G2v: Windowed MSE violin -- Option B (grouped per session, both windows)
% Both windows use RMS (sample-normalised) so absolute values are comparable.
% Level difference between windows reflects transient vs steady-state, not
% window-length bias. Compare OL-CL gap within each window pair.
fig_G2v = figure('Color','w','Units','centimeters','Position',[0 0 9 4]);
lm_gv = 0.13; rm_gv = 0.03; bm_gv = 0.14; tm_gv = 0.08;
ax_gv = axes(fig_G2v,'Position',[lm_gv bm_gv 1-lm_gv-rm_gv 1-bm_gv-tm_gv]);
hold(ax_gv,'on');

hw_gv = 0.35; al_e = 0.65; al_w = 0.35;   % early=opaque, late=transparent
colA_gv = [1 0 0]; colB_gv = [0 0.5 0];
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
ax_gv.FontSize = 6; ax_gv.FontWeight = 'bold'; ax_gv.Box = 'off'; ax_gv.TickDir = 'out';
ylabel(ax_gv, 'RMS MSE (\DeltaF/F)', 'FontSize',6, 'FontWeight','bold');

% Legend: OL/CL colour + early/late alpha
patch(ax_gv,NaN,NaN,colA_gv,'FaceAlpha',al_e,'EdgeColor','none','DisplayName','OL 0-1 s');
patch(ax_gv,NaN,NaN,colB_gv,'FaceAlpha',al_e,'EdgeColor','none','DisplayName','CL 0-1 s');
patch(ax_gv,NaN,NaN,colA_gv,'FaceAlpha',al_w,'EdgeColor','none','DisplayName','OL 1-3 s');
patch(ax_gv,NaN,NaN,colB_gv,'FaceAlpha',al_w,'EdgeColor','none','DisplayName','CL 1-3 s');
lgd_gv = legend(ax_gv,'Box','off','FontSize',6,'FontWeight','bold','Location','northeast');
lgd_gv.ItemTokenSize = [8 4];
exportgraphics(fig_G2v,'paper/MSE_windowed_violin.png','Resolution',300);


%% H: All-session trial average
PS_H = paperStyle();
fig_H = paperFig(3, 4);

lm_h = 0.18; rm_h = 0.05; bm_h = 0.12; tm_h = 0.08;
ax_H = axes(fig_H, 'Position', [lm_h, bm_h, 1-lm_h-rm_h, 1-bm_h-tm_h]);

t1_h = (-3*35 : 35*(dur+3)) / 35;
t_h  = 0 : 1/35 : dur;
colOL = [1 0 0];
colCL = [0 0.5 0];

Error_nc = [];
Error_wc = [];

hold(ax_H, 'on');
for k = 1:length(fields)
    error_NC = mean(mouse.(fields{k}).data.pncDfk_l - ...
        [mouse.(fields{k}).data.pncDfk_l(:,1:35*3), ...
         -5*ones(length(mouse.(fields{k}).data.nc), 35*3), ...
         mouse.(fields{k}).data.pncDfk_l(:,35*6+1:end)]);
    error_WC = mean(mouse.(fields{k}).data.pwcDfk_l - ...
        [mouse.(fields{k}).data.pwcDfk_l(:,1:35*3), ...
         -5*ones(length(mouse.(fields{k}).data.wc), 35*3), ...
         mouse.(fields{k}).data.pwcDfk_l(:,35*6+1:end)]);
    error_nc = mean(mouse.(fields{k}).data.error_nc);
    error_wc = mean(mouse.(fields{k}).data.error_wc);
    Error_nc = [Error_nc; abs(error_nc)];
    Error_wc = [Error_wc; abs(error_wc)];
    plot(ax_H, t1_h, abs(error_NC), 'Color', [colOL, PS_H.fa], 'LineWidth', PS_H.lw_trial, 'HandleVisibility','off');
    plot(ax_H, t1_h, abs(error_WC), 'Color', [colCL, PS_H.fa], 'LineWidth', PS_H.lw_trial, 'HandleVisibility','off');
end
plot(ax_H, t_h, mean(Error_nc), 'Color', colOL, 'LineWidth', PS_H.lw_mean);
plot(ax_H, t_h, mean(Error_wc), 'Color', colCL, 'LineWidth', PS_H.lw_mean);
addStimPatch(ax_H, 0, dur);
xlim(ax_H, [-0.5 dur+0.5]);
ylim(ax_H, [-0.25 6]);
hold(ax_H, 'off');

lgd_H = legend(ax_H, {'Open-Loop', 'Closed-Loop'}, ...
    'Location','northeast', 'Box','off', 'FontSize',PS_H.fs, 'FontWeight',PS_H.fw);
lgd_H.ItemTokenSize = [6 6];
cleanAxes(ax_H);
shortCornerAxes_plot(ax_H, 'XLength',0.5, 'YLength',1, ...
    'XLabel','500 ms', 'YLabel','MSE dF/F', ...
    'LineWidth',PS_H.sca_lw, 'LabelGap',PS_H.sca_gap, 'FontSize',PS_H.fs, 'FontWeight',PS_H.fw);
% text(ax_H, -0.10, 0.95, 'H', 'Units','normalized', 'FontSize', 6, ...
%     'FontWeight','bold', 'Clipping','off');
exportgraphics(fig_H, 'paper/images/figure3/all_average_sessions.pdf', 'ContentType','vector');




%% plot the open loop step response

close all;
PW = 6; PH = 4;
fig = figure('Color','w');
fig.Units = 'centimeters';  fig.PaperUnits = 'centimeters';
fig.Position = [0 0 PW PH];
fig.PaperSize = [PW PH];  fig.PaperPosition = [0 0 PW PH];
hold on;

set(gcf, 'Renderer', 'opengl')

t = -3:1/35:(dur+3);

% ---- Your three indices ----
custom_idx = [4 9 11];   % change as needed


% custom_idx = [3 6 8];   % change as needed

% ---- Your experimental colors ----
expColors = [0.2 0.4 0.8;
             0.8 0.2 0.2;
             0.2 0.8 0.4];

ax = gca;

hLegend = gobjects(length(custom_idx),1);
legTxt  = strings(length(custom_idx),1);
t0 = 0:1/35:3;
for i = 1:length(custom_idx)
% for i = 1:1

    k = custom_idx(i);
    e_nc = mouse.(fields{k}).data.pncDfk_l;   % n x t

    mu  = mean(e_nc, 1);
    sig = std(e_nc, 0, 1);

    % mu0  = mu - mean(mu);
    mu0  = mu;
    up0  = (mu + sig) - mean(mu);
    low0 = (mu - sig) - mean(mu);

    c = expColors(i,:);

    % ---- Shaded mean +/- std (hidden from legend)
    hfill = fill([t fliplr(t)], ...
                 [up0 fliplr(low0)], ...
                 c, ...
                 'EdgeColor','none', ...
                 'FaceAlpha',0.15);
    hfill.HandleVisibility = 'off';
    uistack(hfill,'bottom');


alphaVal = 0.6;
cLight = alphaVal * c + (1-alphaVal) * [1 1 1];   % blend toward white


plot(t,2+var(e_nc),'Color', c, ...
                      'LineWidth', 1)

plot(t0, ...
     ones(1,numel(t0)) * mean(mu(3*35:6*35)), ...
     'LineWidth', 1, ...
     'Color', c, ...
     'HandleVisibility','off');
    % ---- Mean line (store handle for legend)
    hLegend(i) = plot(t, mu0, ...
                      'Color', c, ...
                      'LineWidth', 1);

    % legTxt(i) = fields{k};   % or custom label
    legTxt{i} = sprintf('Session %d',i);
end


t0 = 0:1/35:3;
% Zero line (hidden from legend)
% h0 = plot(t0, -5*ones(1, numel(t0)), '--k', 'LineWidth', 2);
% h0.HandleVisibility = 'off';

yl = ylim;
patch([0 3 3 0], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none', ...
      'HandleVisibility','off');

xlim([-3 dur+3])
xticks([])
 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
      'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 2, 'LabelGap', 0.05)
% ---- Your legend style ----
lgd = legend(ax, hLegend, legTxt, ...
             'Box','off','Color','none','FontSize',6,'FontWeight','bold', ...
             'Location','southeast');
lgd.ItemTokenSize = [6 6];
lgd.AutoUpdate = 'off';

% legend(ax2, [hA hD hC hB], {'Open-Loop', 'Closed-Loop','Stim', 'Ref'}, ...
%     'Location','northeast', ...
%     'Box','off', FontSize=12, FontWeight='bold')
% shortCornerAxes_plot(ax,'Frac',0.1,'XLabel','time(secs)','YLabel','dF/F  /  Variance','LineWidth',5,'LabelGap',0.05)

text(-0.1-3, 10, {'Variance', 'across trials'}, ...
    'Color','k', 'FontSize', 7, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Rotation', 90, 'Clipping','off');




% shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Time','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)
exportgraphics(fig, 'paper/images/figure2/step_response.pdf', 'ContentType','image', 'Resolution',300);



%%
close all;

n_sample   = 3;                          % number of fields to sample
custom_idx = randperm(13, n_sample);     % random sample of n ints from 1:13



batch_sizes = 10:10:100;
m_repeats   = 500;          % number of random draws per batch size

colors = lines(length(custom_idx));



all_data  = cell(length(custom_idx), length(batch_sizes));  % {field, batchsize} -> m values

for i = 1:length(custom_idx)
    spont_dFk = mouse.(fields{custom_idx(i)}).data.spont_dFk;   % trials x time
    n_trials  = size(spont_dFk, 1);

    for bi = 1:length(batch_sizes)
        n = batch_sizes(bi);
        vals = zeros(m_repeats, 1);
        for r = 1:m_repeats
            idx  = randperm(n_trials, min(n, n_trials));
            batch = spont_dFk(idx, :);          % n x time
            % vals(r) = sum(var(batch, 0, 1));    % sum of per-timepoint variance across trials

            vals(r) = sum(var(batch));    % sum of per-timepoint variance across trials
        end
        all_data{i, bi} = vals;
    end
end

% --- plot: mean +/- SEM per field, connected by line ---
x_positions = 1:length(batch_sizes);
capWidth     = 0.2;



fig = figure('Color','w', 'Units','centimeters', 'Position',[0 0 15 10]); hold on

hLegend = gobjects(length(custom_idx), 1);
legTxt  = cell(length(custom_idx), 1);

% --- first pass: collect raw means to compute per-field grand mean ---
rawMeans = zeros(length(custom_idx), 1);
allMeanVals = zeros(length(custom_idx), length(batch_sizes));
allSemVals  = zeros(length(custom_idx), length(batch_sizes));

for i = 1:length(custom_idx)
    for bi = 1:length(batch_sizes)
        vals = all_data{i, bi};
        allMeanVals(i, bi) = mean(vals);
        allSemVals(i, bi)  = std(vals) / sqrt(m_repeats);
    end
    rawMeans(i) = mean(allMeanVals(i, :));
end

% --- second pass: min-max normalize then scale by grand mean ---
% curves span [0, rawMean] so y-amplitude encodes mean variance
for i = 1:length(custom_idx)
    c = colors(i,:);

    mn = min(allMeanVals(i,:));
    mx = max(allMeanVals(i,:));
    scale = mx - mn + eps;
    meanVals = ((allMeanVals(i,:) - mn) / scale) * rawMeans(i);
    semVals  = (allSemVals(i,:) / scale) * rawMeans(i);

    xpos = x_positions;

    % SEM bars with caps
    for bi = 1:length(batch_sizes)
        plot([xpos(bi) xpos(bi)], [meanVals(bi)-semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)-semVals(bi), meanVals(bi)-semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)+semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot(xpos(bi), meanVals(bi), 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', c, 'HandleVisibility','off');
    end

    % Connecting line through means
    hLegend(i) = plot(xpos, meanVals, '-', 'LineWidth', 2.0, 'Color', c);
    legTxt{i}  = sprintf('Session %d', i);
end

ax = gca;
ax.LineWidth  = 1.5;
ax.FontName   = 'Arial';
ax.FontSize   = 6;
ax.FontWeight = 'bold';
ax.TickDir    = 'out';
ax.Box        = 'off';
ax.XColor = 'k';              % keep ticks and labels visible
ax.YColor = 'none';           % hide y axis line and ticks
ax.XAxis.LineWidth = 0.001;    % make x axis spine invisible without hiding ticks

% ticks only at 20,40,60,80,100
tick_bs  = [20 40 60 80 100];
tick_pos = x_positions(ismember(batch_sizes, tick_bs));
xticks(tick_pos);
xticklabels(arrayfun(@num2str, tick_bs, 'UniformOutput', false));
ax.XAxis.TickLength = [0.02 0.02];

% y label only, no ticks or axis line
yticks([]);
yl = ylabel('Normalized variance', 'FontName','Arial', 'FontSize',6, 'FontWeight','bold');
yl.Color = 'k';
xl = xlabel('Batch size (trials)', 'FontName','Arial', 'FontSize',6, 'FontWeight','bold');
xl.Color = 'k';

lgd = legend(ax, hLegend, legTxt, 'Box','off', 'Color','none');
lgd.ItemTokenSize = [14 6];
lgd.AutoUpdate = 'off';
exportgraphics(fig, 'paper/spont_variance.png', 'Resolution',300);





%% Pre-stim state vs trial MSE -- OL/CL all sessions pooled
% Scientific question: does trial MSE scale with how far ΔF/F was from the
% reference at stim onset?  OL: no feedback → expect positive slope.
% CL: feedback active → slope should be attenuated or flat.
%
% X: |ΔF/F at stim onset − ref|  (abs, %)     = abs(ncDfk(:, c0_g2) − d.ref)
% Y: trial MSE (t = 0 to +3 s)                = er_ncDfk / er_wcDfk
% Requires G2 section to have run first (c0_g2 = 36 defined there).

allNcDev_ps = [];  allNcMse_ps = [];
allWcDev_ps = [];  allWcMse_ps = [];

for k = 1:length(fields)
    if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
    if ~isfield(mouse.(fields{k}), 'data');                           continue; end
    dk_ps  = mouse.(fields{k}).data;
    ref_ps = mouse.(fields{k}).d.ref;

    allNcDev_ps = [allNcDev_ps; abs(dk_ps.ncDfk(:, c0_g2) - ref_ps)];
    allNcMse_ps = [allNcMse_ps; dk_ps.er_ncDfk];
    allWcDev_ps = [allWcDev_ps; abs(dk_ps.wcDfk(:, c0_g2) - ref_ps)];
    allWcMse_ps = [allWcMse_ps; dk_ps.er_wcDfk];
end

% --- bin pooled trials into 4 quartiles of |deviation| (edges from OL+CL combined) ---
nBins_ps  = 4;
edges_ps  = quantile([allNcDev_ps; allWcDev_ps], linspace(0, 1, nBins_ps+1));

binIdx_nc_ps = discretize(allNcDev_ps, edges_ps);
binIdx_nc_ps(isnan(binIdx_nc_ps)) = nBins_ps;
binIdx_wc_ps = discretize(allWcDev_ps, edges_ps);
binIdx_wc_ps(isnan(binIdx_wc_ps)) = nBins_ps;

nc_bin_ps = cell(nBins_ps, 1);
wc_bin_ps = cell(nBins_ps, 1);
for b = 1:nBins_ps
    nc_bin_ps{b} = allNcMse_ps(binIdx_nc_ps == b);
    wc_bin_ps{b} = allWcMse_ps(binIdx_wc_ps == b);
end

nc_mean_ps = cellfun(@mean,                       nc_bin_ps);
nc_sem_ps  = cellfun(@(x) std(x)/sqrt(numel(x)), nc_bin_ps);
wc_mean_ps = cellfun(@mean,                       wc_bin_ps);
wc_sem_ps  = cellfun(@(x) std(x)/sqrt(numel(x)), wc_bin_ps);


% --- paper figure → Figure 4 ---
PS_ps      = paperStyle();
fig_ps_mse = paperFig(6, 4);
ax_ps      = axes(fig_ps_mse, 'Units','normalized', 'Position',[0.18 0.22 0.76 0.60]);
hold(ax_ps, 'on');

xb_ps = 1:nBins_ps;
errorbar(ax_ps, xb_ps - 0.1, nc_mean_ps, nc_sem_ps, 'o-', 'Color', colOL, ...
    'LineWidth', PS_ps.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName','OL');
errorbar(ax_ps, xb_ps + 0.1, wc_mean_ps, wc_sem_ps, 'o-', 'Color', colCL, ...
    'LineWidth', PS_ps.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName','CL');


xlim(ax_ps, [0.5, nBins_ps + 0.5]);
xticks(ax_ps, xb_ps);
xticklabels(ax_ps, {'Q1','Q2','Q3','Q4'});
lgd_ps = legend(ax_ps, 'Box','off', 'Location','northwest', ...
    'FontSize', PS_ps.fs, 'FontWeight', PS_ps.fw);
lgd_ps.ItemTokenSize = [6 6];
xlabel(ax_ps, '|{\DeltaF/F} at onset \minus ref| quartile', ...
    'FontSize', PS_ps.fs, 'FontWeight', PS_ps.fw);
ylabel(ax_ps, 'Trial MSE (t = 0 to +3 s)', ...
    'FontSize', PS_ps.fs, 'FontWeight', PS_ps.fw);
set(ax_ps, 'Box','off', 'TickDir','out', 'FontSize', PS_ps.fs, 'FontWeight', PS_ps.fw);
hold(ax_ps, 'off');


exportgraphics(fig_ps_mse, 'paper/images/figure4/prestim_dev_vs_mse.pdf', 'ContentType','vector');

%% Motion vs MSE -- three analysis modes
% onset_col is derived dynamically per session:
%   onset_col = size(ncmotion,2) - 35*dur
% This works regardless of which controllerData window is stored.
%
% Three modes (pre_secs=0 means start at onset, post_secs=0 means end at onset):
%   1. combined   -- 2s pre-trial + full trial
%   2. pre_trial  -- 3s before onset only
%   3. during     -- trial onset to trial end only

motModes(1).label     = 'combined';
motModes(1).pre_secs  = 2;
motModes(1).post_secs = -1;   % -1 = use dur (trial end) per session

motModes(2).label     = 'pre_trial_3s';
motModes(2).pre_secs  = 3;
motModes(2).post_secs = 0;

motModes(3).label     = 'during_trial';
motModes(3).pre_secs  = 0;
motModes(3).post_secs = -1;

colOL = [1 0 0];
colCL = [0 0.5 0];
nBins = 4;
nSess = length(fields);
nCols = 4;
nRows = ceil(nSess / nCols);

for m = 1:length(motModes)
    mode = motModes(m);

    allBin_nc_mse = cell(nBins, 1);
    allBin_wc_mse = cell(nBins, 1);
    for b = 1:nBins; allBin_nc_mse{b} = []; allBin_wc_mse{b} = []; end

    PW_fS = nCols*7.5; PH_fS = nRows*7.5;
    figS = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW_fS PH_fS]);

    spIdx = 0;
    for k = 1:nSess
        if isfield(mouse.(fields{k}), 'skip'),       continue; end
        if ~isfield(mouse.(fields{k}), 'data'),      continue; end
        if ~any(mouse.(fields{k}).data.ncmotion(:)), continue; end

        data_k  = mouse.(fields{k}).data;
        dur_k   = mouse.(fields{k}).d.params.dur;
        n_cols  = size(data_k.ncmotion, 2);

        % derive onset column from stored window size -- works for any stored window
        onset_col = n_cols - 35 * dur_k;

        post_cols = dur_k * 35;
        if mode.post_secs ~= -1; post_cols = round(mode.post_secs * 35); end

        win_start = max(1,      onset_col - round(mode.pre_secs  * 35));
        win_end   = min(n_cols, onset_col + post_cols);

        % raw z-scored mean over selected window
        ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
        wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);
        enc = data_k.er_ncDfk;
        ewc = data_k.er_wcDfk;

        allMot = [ncm; wcm];
        allMse = [enc; ewc];
        allLbl = [zeros(numel(ncm),1); ones(numel(wcm),1)];

        edges  = quantile(allMot, [0 0.25 0.5 0.75 1]);
        binIdx = discretize(allMot, edges);
        binIdx(isnan(binIdx)) = nBins;

        spIdx = spIdx + 1;
        ax = subplot(nRows, nCols, spIdx); hold on;

        scatter(ax, ncm, enc, 20, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.6, 'HandleVisibility','off');
        scatter(ax, wcm, ewc, 20, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.6, 'HandleVisibility','off');

        xAll = [ncm; wcm];
        xr   = linspace(min(xAll), max(xAll), 100);
        if numel(ncm) > 1
            plot(ax, xr, polyval(polyfit(ncm, enc, 1), xr), '-', 'Color', colOL, 'LineWidth', 1.5, 'HandleVisibility','off');
        end
        if numel(wcm) > 1
            plot(ax, xr, polyval(polyfit(wcm, ewc, 1), xr), '-', 'Color', colCL, 'LineWidth', 1.5, 'HandleVisibility','off');
        end

        title(ax, sprintf('%s %s e%d', mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en), ...
            'FontSize', 6, 'FontWeight','bold', 'Interpreter','none');
        set(ax, 'Box','off', 'TickDir','out', 'XTick',[], 'YTick',[]);

        for b = 1:nBins
            allBin_nc_mse{b} = [allBin_nc_mse{b}; allMse(binIdx == b & allLbl == 0)];
            allBin_wc_mse{b} = [allBin_wc_mse{b}; allMse(binIdx == b & allLbl == 1)];
        end
    end

    xlabel(ax, 'Motion (z-scored)', 'FontWeight','bold', 'FontSize', 6);
    ylabel(ax, 'MSE ||e||',         'FontWeight','bold', 'FontSize', 6);
    exportgraphics(figS, sprintf('paper/motion_scatter_%s.png', mode.label), 'Resolution',300);

    % pooled quartile figure for this mode
    figQ = figure('Color','w', 'Units','centimeters', 'Position',[0 0 13 10]);
    hold on;

    nc_pool_mean = cellfun(@mean,                       allBin_nc_mse);
    nc_pool_sem  = cellfun(@(x) std(x)/sqrt(numel(x)), allBin_nc_mse);
    wc_pool_mean = cellfun(@mean,                       allBin_wc_mse);
    wc_pool_sem  = cellfun(@(x) std(x)/sqrt(numel(x)), allBin_wc_mse);

    xb = 1:nBins;
    errorbar(xb-0.1, nc_pool_mean, nc_pool_sem, 'o-', 'Color', colOL, ...
        'LineWidth', 2, 'MarkerSize', 6, 'CapSize', 4, 'DisplayName', 'Open-Loop');
    errorbar(xb+0.1, wc_pool_mean, wc_pool_sem, 'o-', 'Color', colCL, ...
        'LineWidth', 2, 'MarkerSize', 6, 'CapSize', 4, 'DisplayName', 'Closed-Loop');

    xlim([0.5 nBins+0.5]);
    xticks(xb);
    xticklabels({'Q1 (low)', 'Q2', 'Q3', 'Q4 (high)'});
    legend('Box','off', 'Location','northwest', 'FontSize', 6, 'FontWeight','bold');
    xlabel(sprintf('Motion quartile -- %s', strrep(mode.label,'_',' ')), 'FontWeight','bold');
    ylabel('MSE  ||e||', 'FontWeight','bold');
    set(gca, 'Box','off', 'TickDir','out');
    exportgraphics(figQ, sprintf('paper/motion_quartile_%s.png', mode.label), 'Resolution',300);

    % ---- paper panel (combined mode only) → Figure 4 ----
    if strcmp(mode.label, 'combined')
        PS     = paperStyle();
        figQp  = paperFig(6, 4);
        ax_qp  = axes(figQp); hold(ax_qp, 'on');

        errorbar(ax_qp, xb-0.1, nc_pool_mean, nc_pool_sem, 'o-', 'Color', colOL, ...
            'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName', 'Open-Loop');
        errorbar(ax_qp, xb+0.1, wc_pool_mean, wc_pool_sem, 'o-', 'Color', colCL, ...
            'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName', 'Closed-Loop');

        xlim(ax_qp, [0.5 nBins+0.5]);
        xticks(ax_qp, xb);
        xticklabels(ax_qp, {'Q1','Q2','Q3','Q4'});
        lgd_qp = legend(ax_qp, 'Box','off', 'Location','northwest', ...
            'FontSize', PS.fs, 'FontWeight', PS.fw);
        lgd_qp.ItemTokenSize = [6 6];
        xlabel(ax_qp, 'Motion quartile (combined window)', ...
            'FontSize', PS.fs, 'FontWeight', PS.fw);
        ylabel(ax_qp, 'MSE ||e|| (t = 0 to +3 s)', ...
            'FontSize', PS.fs, 'FontWeight', PS.fw);
        set(ax_qp, 'Box','off', 'TickDir','out', ...
            'FontSize', PS.fs, 'FontWeight', PS.fw);
        exportgraphics(figQp, 'paper/images/figure4/motion_quartile_combined.pdf', ...
            'ContentType', 'vector');
    end
end

%% Raw motion traces -- sessions with face video

sessColors = lines(nSess);

fig = figure('Color','w', 'Units','centimeters', 'Position',[0 0 35 6]);
hold on;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'd'),    continue; end
    if ~any(mouse.(fields{k}).d.motion(:)), continue; end

    t_k = mouse.(fields{k}).d.timeBlue;
    m_k = mouse.(fields{k}).d.motion;
    nPts = min(numel(t_k), numel(m_k));
    t_k  = t_k(1:nPts);
    m_k  = m_k(1:nPts);
    plot(t_k - t_k(1), m_k, 'Color', [sessColors(k,:) 0.7], 'LineWidth', 0.8, ...
        'DisplayName', sprintf('%s %s e%d', mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en));
end

legend('Box','off', 'Location','eastoutside', 'FontSize',6, 'Interpreter','none');
xlabel('Time (s)',           'FontWeight','bold');
ylabel('Motion (z-scored)',  'FontWeight','bold');
set(gca, 'Box','off', 'TickDir','out');
exportgraphics(fig, 'paper/motion_traces.png', 'Resolution',300);

%% Combined motion vs MSE -- all sessions pooled (combined window)
iMode = motModes(1);   % 2 s pre + full trial

allNcMot = []; allNcMse = [];
allWcMot = []; allWcMse = [];

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),       continue; end
    if ~isfield(mouse.(fields{k}), 'data'),      continue; end
    if ~any(mouse.(fields{k}).data.ncmotion(:)), continue; end

    data_k    = mouse.(fields{k}).data;
    dur_k     = mouse.(fields{k}).d.params.dur;
    n_cols    = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;
    post_cols = dur_k * 35;
    win_start = max(1,      onset_col - round(iMode.pre_secs * 35));
    win_end   = min(n_cols, onset_col + post_cols);

    allNcMot = [allNcMot; mean(data_k.ncmotion(:, win_start:win_end), 2)];
    allNcMse = [allNcMse; data_k.er_ncDfk];
    allWcMot = [allWcMot; mean(data_k.wcmotion(:, win_start:win_end), 2)];
    allWcMse = [allWcMse; data_k.er_wcDfk];
end

figC = figure('Color','w', 'Units','centimeters', 'Position',[0 0 6 4]);
hold on;

scatter(allNcMot, allNcMse, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');
scatter(allWcMot, allWcMse, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');

xAll = [allNcMot; allWcMot];
xr   = linspace(min(xAll), max(xAll), 100);
pNC = [0 0]; pWC = [0 0];
if numel(allNcMot) > 1
    pNC = polyfit(allNcMot, allNcMse, 1);
    plot(xr, polyval(pNC, xr), '-', 'Color', colOL, 'LineWidth', 1.5, 'DisplayName','Open-Loop');
end
if numel(allWcMot) > 1
    pWC = polyfit(allWcMot, allWcMse, 1);
    plot(xr, polyval(pWC, xr), '-', 'Color', colCL, 'LineWidth', 1.5, 'DisplayName','Closed-Loop');
end

ax = gca;
xl = xlim(ax); yl = ylim(ax);
text(xl(2), yl(2) - 0.05*(yl(2)-yl(1)), sprintf('slope OL = %.3f', pNC(1)), ...
    'Color', colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(xl(2), yl(2) - 0.18*(yl(2)-yl(1)), sprintf('slope CL = %.3f', pWC(1)), ...
    'Color', colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
xlabel('Motion (z-scored)', 'FontWeight','bold', 'FontSize',6);
ylabel('MSE  ||e||',        'FontWeight','bold', 'FontSize',6);
set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
exportgraphics(figC, 'paper/motion_mse_combined.png', 'Resolution',300);

%% Onset deviation vs windowed MSE scatter (fig_onset_dev)
% Scientific question: does OL MSE increase steeply with initial deviation
% while CL MSE stays flat? A flat CL slope = feedback decouples initial
% brain state from outcome.
%
% X: |ΔF/F at t=0 (stim onset)| = abs(ncDfk(:, c0_g2)) / abs(wcDfk(:, c0_g2))
% Y: windowed MSE t=+1 to +3 s   = er_ncDfk_w / er_wcDfk_w (from G2 section)
% Requires G2 section to have run first (er_ncDfk_w stored in mouse.*.data).

% Pool across all sessions
allNcDev_od  = [];   allNcMse_od  = [];
allWcDev_od  = [];   allWcMse_od  = [];

for k = 1:length(fields)
    if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
    if ~isfield(mouse.(fields{k}), 'data');                           continue; end
    dk_od = mouse.(fields{k}).data;
    if ~isfield(dk_od, 'er_ncDfk_w') || ~isfield(dk_od, 'er_wcDfk_w'); continue; end

    % |ΔF/F at stim onset| -- c0_g2 = col 36 = t=0
    nc_dev_od = abs(dk_od.ncDfk(:, c0_g2));
    wc_dev_od = abs(dk_od.wcDfk(:, c0_g2));

    allNcDev_od = [allNcDev_od; nc_dev_od];
    allNcMse_od = [allNcMse_od; dk_od.er_ncDfk_w];
    allWcDev_od = [allWcDev_od; wc_dev_od];
    allWcMse_od = [allWcMse_od; dk_od.er_wcDfk_w];
end

fig_onset_dev = paperFig(6, 4);
ax_od = axes(fig_onset_dev, 'Units','normalized', 'Position',[0.18 0.18 0.78 0.74]);
hold(ax_od, 'on');

scatter(ax_od, allNcDev_od, allNcMse_od, 8, colOL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');
scatter(ax_od, allWcDev_od, allWcMse_od, 8, colCL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');

% Linear regression for OL
pNC_od = [0 0];  rSq_NC_od = 0;  slope_se_NC_od = 0;
if numel(allNcDev_od) > 2
    X_nc_od  = [ones(numel(allNcDev_od),1), allNcDev_od];
    b_nc_od  = X_nc_od \ allNcMse_od;
    yhat_nc  = X_nc_od * b_nc_od;
    ss_res   = sum((allNcMse_od - yhat_nc).^2);
    ss_tot   = sum((allNcMse_od - mean(allNcMse_od)).^2);
    rSq_NC_od = 1 - ss_res / ss_tot;
    % SE of slope via OLS formula
    sigma2_nc    = ss_res / (numel(allNcMse_od) - 2);
    slope_se_NC_od = sqrt(sigma2_nc / sum((allNcDev_od - mean(allNcDev_od)).^2));
    pNC_od = [b_nc_od(2), b_nc_od(1)];   % [slope, intercept]
    xr_nc  = linspace(min(allNcDev_od), max(allNcDev_od), 100);
    plot(ax_od, xr_nc, pNC_od(1)*xr_nc + pNC_od(2), '-', ...
        'Color', colOL, 'LineWidth', 1.2, 'DisplayName','OL fit');
end

% Linear regression for CL
pWC_od = [0 0];  rSq_WC_od = 0;  slope_se_WC_od = 0;
if numel(allWcDev_od) > 2
    X_wc_od  = [ones(numel(allWcDev_od),1), allWcDev_od];
    b_wc_od  = X_wc_od \ allWcMse_od;
    yhat_wc  = X_wc_od * b_wc_od;
    ss_res_w = sum((allWcMse_od - yhat_wc).^2);
    ss_tot_w = sum((allWcMse_od - mean(allWcMse_od)).^2);
    rSq_WC_od = 1 - ss_res_w / ss_tot_w;
    sigma2_wc    = ss_res_w / (numel(allWcMse_od) - 2);
    slope_se_WC_od = sqrt(sigma2_wc / sum((allWcDev_od - mean(allWcDev_od)).^2));
    pWC_od = [b_wc_od(2), b_wc_od(1)];
    xr_wc  = linspace(min(allWcDev_od), max(allWcDev_od), 100);
    plot(ax_od, xr_wc, pWC_od(1)*xr_wc + pWC_od(2), '-', ...
        'Color', colCL, 'LineWidth', 1.2, 'DisplayName','CL fit');
end

% Annotations: slope ± SE and r² for each condition
xl_od = xlim(ax_od);  yl_od = ylim(ax_od);
text(ax_od, xl_od(1), yl_od(2), ...
    sprintf('OL: slope=%.3f+/-%.3f, r^2=%.2f', pNC_od(1), slope_se_NC_od, rSq_NC_od), ...
    'Color', colOL, 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top');
text(ax_od, xl_od(1), yl_od(2) - 0.14*(yl_od(2)-yl_od(1)), ...
    sprintf('CL: slope=%.3f+/-%.3f, r^2=%.2f', pWC_od(1), slope_se_WC_od, rSq_WC_od), ...
    'Color', colCL, 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top');

lgd_od = legend(ax_od, 'Box','off', 'Location','southeast', 'FontSize',6, 'FontWeight','bold');
lgd_od.ItemTokenSize = [6 6];
xlabel(ax_od, '|{\DeltaF/F} at stim onset| (%)',  'FontWeight','bold', 'FontSize',6);
ylabel(ax_od, 'Trial MSE (t=+1 to +3 s)',          'FontWeight','bold', 'FontSize',6);
set(ax_od, 'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
hold(ax_od, 'off');

exportgraphics(fig_onset_dev, 'paper/onset_dev_vs_mse.png', 'Resolution',300);
fprintf('onset_dev_vs_mse: OL slope=%.4f+/-%.4f r2=%.3f  CL slope=%.4f+/-%.4f r2=%.3f\n', ...
    pNC_od(1), slope_se_NC_od, rSq_NC_od, pWC_od(1), slope_se_WC_od, rSq_WC_od);

%% Interactive motion scatter -- combined mode (click a point to inspect trial)
% Uses motModes(1) window. Click any point to open a dFk + input trace figure.
close all;
iMode       = motModes(1);
colOL       = [1 0 0];
colCL       = [0 0.5 0];

figI = figure('Color','w', 'Name','Interactive Motion Scatter');
figI.Units    = 'inches';
figI.Position = [1, 1, nCols*3, nRows*3];

spIdx = 0;
for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),       continue; end
    if ~isfield(mouse.(fields{k}), 'data'),      continue; end
    if ~any(mouse.(fields{k}).data.ncmotion(:)), continue; end

    data_k  = mouse.(fields{k}).data;
    dur_k   = mouse.(fields{k}).d.params.dur;
    n_cols  = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;

    post_cols = dur_k * 35;
    win_start = max(1,      onset_col - round(iMode.pre_secs * 35));
    win_end   = min(n_cols, onset_col + post_cols);

    ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
    wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);
    enc = data_k.er_ncDfk;
    ewc = data_k.er_wcDfk;

    spIdx = spIdx + 1;
    ax = subplot(nRows, nCols, spIdx); hold on;

    % OL scatter -- store per-point metadata in UserData
    ud_nc = struct( ...
        'field',    repmat(fields(k), numel(data_k.nc), 1), ...
        'stim_idx', num2cell(data_k.nc(:)), ...
        'lbl',      repmat({'OL'}, numel(data_k.nc), 1), ...
        'mse',      num2cell(enc(:)));
    sc_nc = scatter(ax, ncm, enc, 25, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.6);
    sc_nc.UserData    = ud_nc;
    sc_nc.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    % CL scatter
    ud_wc = struct( ...
        'field',    repmat(fields(k), numel(data_k.wc), 1), ...
        'stim_idx', num2cell(data_k.wc(:)), ...
        'lbl',      repmat({'CL'}, numel(data_k.wc), 1), ...
        'mse',      num2cell(ewc(:)));
    sc_wc = scatter(ax, wcm, ewc, 25, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.6);
    sc_wc.UserData    = ud_wc;
    sc_wc.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    title(ax, sprintf('%s %s e%d', mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en), ...
        'FontSize', 7, 'FontWeight','bold', 'Interpreter','none');
    set(ax, 'Box','off', 'TickDir','out', 'XTick',[], 'YTick',[]);
end

xlabel(ax, 'Motion (z-scored)', 'FontWeight','bold', 'FontSize', 9);
ylabel(ax, 'MSE ||e||',         'FontWeight','bold', 'FontSize', 9);

fprintf('Interactive scatter ready -- click any point to inspect that trial.\n');

%% Figures I & J -- Spectral heatmaps sorted by MSE (absolute power: S_bands)
% ncFreqPow/wcFreqPow store raw FFT^2 power (no band/total normalization).
% Old caches that only have ncFreqSpec (relative) are used as fallback.

% --- Pass 1: collect per-trial mean power for all sessions ---
nc_all     = [];  wc_all     = [];
nc_mse_all = [];  wc_mse_all = [];
freqCtrs   = [];

sess_nc    = cell(nSess, 1);
sess_wc    = cell(nSess, 1);
sess_valid = false(nSess, 1);
use_abs_power = false;   % set true once any session has ncFreqPow

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;

    % Prefer absolute power; fall back to relative if cache is old
    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;
        wc_spec = data_k.wcFreqPow;
        use_abs_power = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec;
        wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k    = mouse.(fields{k}).d.params.dur;
    onsetBin = data_k.freqOnsetBin;
    winStart = onsetBin - 1;
    winEnd   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean = reshape(mean(nc_spec(:, winStart:winEnd, :), 2), size(nc_spec, 1), []);
    wc_mean = reshape(mean(wc_spec(:, winStart:winEnd, :), 2), size(wc_spec, 1), []);

    sess_nc{k}    = nc_mean;
    sess_wc{k}    = wc_mean;
    sess_valid(k) = true;
    freqCtrs      = data_k.freqBandCtrs;

    nc_all     = [nc_all;     nc_mean];
    wc_all     = [wc_all;     wc_mean];
    nc_mse_all = [nc_mse_all; data_k.er_ncDfk];
    wc_mse_all = [wc_mse_all; data_k.er_wcDfk];
end

if use_abs_power
    cbar_label = 'Power (\DeltaF/F)^2 Hz^{-1}';
else
    cbar_label = 'band/total power';
end

% Color limit: 98th percentile of pooled power (clips outliers)
clim_val = prctile([nc_all(:); wc_all(:)], 98);

% --- Figure I: per-session heatmaps, shared color scale, interactive ---
nSess_f  = 4;
nRows_f  = ceil(sum(sess_valid) / nSess_f);

lm       = 0.03;   rm      = 0.05;
tm       = 0.04;   bm      = 0.05;
sess_gap = 0.022;
pair_gap = 0.003;
row_gap  = 0.10;

pw = (1 - lm - rm - nSess_f*pair_gap - (nSess_f-1)*sess_gap) / (nSess_f*2);
ph = (1 - tm - bm - (nRows_f-1)*row_gap) / nRows_f;

fig_I = figure('Color','w', 'Units','centimeters', 'Position',[0 0 nSess_f*11.4 nRows_f*8.9]);

sessIdx = 0;
ax_last = [];

for k = 1:nSess
    if ~sess_valid(k); continue; end
    data_k = mouse.(fields{k}).data;

    nc_mean = sess_nc{k};
    wc_mean = sess_wc{k};

    [~, nc_ord] = sort(data_k.er_ncDfk, 'ascend');
    [~, wc_ord] = sort(data_k.er_wcDfk, 'ascend');

    sessIdx  = sessIdx + 1;
    row      = floor((sessIdx-1) / nSess_f);
    col_pair = mod(sessIdx-1,    nSess_f);

    x_ol = lm + col_pair * (2*pw + pair_gap + sess_gap);
    x_cl = x_ol + pw + pair_gap;
    y    = 1 - tm - (row+1)*ph - row*row_gap;

    sesslabel = sprintf('%s %s e%d', mouse.(fields{k}).mn, ...
        mouse.(fields{k}).td, mouse.(fields{k}).en);

    ud_base.d            = mouse.(fields{k}).d;
    ud_base.dFk          = data_k.dFk;
    ud_base.freqBandCtrs = freqCtrs;
    ud_base.freqOnsetBin = data_k.freqOnsetBin;

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec_k = data_k.ncFreqPow;
        wc_spec_k = data_k.wcFreqPow;
    else
        nc_spec_k = data_k.ncFreqSpec;
        wc_spec_k = data_k.wcFreqSpec;
    end

    ud_ol              = ud_base;
    ud_ol.sorted_order = nc_ord;
    ud_ol.trial_idx    = data_k.nc;
    ud_ol.freq_spec    = nc_spec_k;
    ud_ol.lbl          = 'OL';

    ud_cl              = ud_base;
    ud_cl.sorted_order = wc_ord;
    ud_cl.trial_idx    = data_k.wc;
    ud_cl.freq_spec    = wc_spec_k;
    ud_cl.lbl          = 'CL';

    ax_ol = axes(fig_I, 'Position', [x_ol, y, pw, ph]);
    im_ol = imagesc(ax_ol, freqCtrs, 1:size(nc_mean,1), nc_mean(nc_ord,:));
    colormap(ax_ol, 'hot'); clim(ax_ol, [0 clim_val]);
    title(ax_ol, [sesslabel '  OL'], 'FontSize', 6, 'FontWeight','bold', 'Interpreter','none');
    set(ax_ol, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6);
    im_ol.ButtonDownFcn = @(s,e) heatmapClickCallback(s, e, ud_ol);

    ax_cl = axes(fig_I, 'Position', [x_cl, y, pw, ph]);
    im_cl = imagesc(ax_cl, freqCtrs, 1:size(wc_mean,1), wc_mean(wc_ord,:));
    colormap(ax_cl, 'hot'); clim(ax_cl, [0 clim_val]);
    title(ax_cl, [sesslabel '  CL'], 'FontSize', 6, 'FontWeight','bold', 'Interpreter','none');
    set(ax_cl, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6, 'YTickLabel', {});
    im_cl.ButtonDownFcn = @(s,e) heatmapClickCallback(s, e, ud_cl);

    ax_last = ax_cl;
end

if ~isempty(ax_last)
    cb = colorbar(ax_last); cb.Label.String = cbar_label; cb.FontSize = 6;
end
exportgraphics(fig_I, 'paper/freq_heatmap_sessions.png', 'Resolution', 300);
fprintf('Figure I ready -- click any row to inspect that trial.\n');

% --- Figure J: combined heatmap (all sessions pooled, raw MSE sort) ---
[~, nc_ord_all] = sort(nc_mse_all, 'ascend');
[~, wc_ord_all] = sort(wc_mse_all, 'ascend');

lm_j = 0.08; rm_j = 0.12; bm_j = 0.10; tm_j = 0.06; mid_gap = 0.04;
pw_j = (1 - lm_j - rm_j - mid_gap) / 2;
ph_j = 1 - tm_j - bm_j;

fig_J = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

ax_ol = axes(fig_J, 'Position', [lm_j,              bm_j, pw_j, ph_j]);
imagesc(ax_ol, freqCtrs, 1:size(nc_all,1), nc_all(nc_ord_all,:));
colormap(ax_ol, 'hot'); clim(ax_ol, [0 clim_val]);
set(ax_ol, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6);
xlabel(ax_ol, 'Frequency (Hz)', 'FontWeight','bold');
ylabel(ax_ol, 'Trial (low \rightarrow high MSE)', 'FontWeight','bold');
title(ax_ol, 'Open-Loop', 'FontSize', 6, 'FontWeight','bold');

ax_cl = axes(fig_J, 'Position', [lm_j+pw_j+mid_gap, bm_j, pw_j, ph_j]);
imagesc(ax_cl, freqCtrs, 1:size(wc_all,1), wc_all(wc_ord_all,:));
colormap(ax_cl, 'hot'); clim(ax_cl, [0 clim_val]);
set(ax_cl, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6, 'YTickLabel', {});
xlabel(ax_cl, 'Frequency (Hz)', 'FontWeight','bold');
title(ax_cl, 'Closed-Loop', 'FontSize', 6, 'FontWeight','bold');
cb = colorbar(ax_cl); cb.Label.String = cbar_label; cb.FontSize = 6;
exportgraphics(fig_J, 'paper/freq_heatmap_combined.png', 'Resolution', 300);

% Figure K removed -- band-normalised view is redundant when using absolute power (S_bands).

%% Figure J2 -- MSE-sorted spectral heatmap, motion-clean trials (|z-motion| <= 1.5)
motThresh  = 0.5;
iMode_j2   = motModes(1);   % 2 s pre + full trial

nc_all_m = []; wc_all_m = [];
nc_mse_m = []; wc_mse_m = [];
n_exc_nc = 0;  n_exc_wc = 0;
n_tot_nc = 0;  n_tot_wc = 0;
freqCtrs_m = [];
use_abs_m  = false;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;

    if ~isfield(data_k, 'ncmotion') || ~any(data_k.ncmotion(:)), continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;
        wc_spec = data_k.wcFreqPow;
        use_abs_m = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec;
        wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    n_cols    = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;
    win_start = max(1,      onset_col - round(iMode_j2.pre_secs * 35));
    win_end   = min(n_cols, onset_col + dur_k * 35);

    ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
    wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);

    nc_keep = abs(ncm) <= motThresh;
    wc_keep = abs(wcm) <= motThresh;

    n_tot_nc = n_tot_nc + numel(ncm);
    n_tot_wc = n_tot_wc + numel(wcm);
    n_exc_nc = n_exc_nc + sum(~nc_keep);
    n_exc_wc = n_exc_wc + sum(~wc_keep);

    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nc_all_m = [nc_all_m; nc_mean_k(nc_keep, :)];
    wc_all_m = [wc_all_m; wc_mean_k(wc_keep, :)];
    nc_mse_m = [nc_mse_m; data_k.er_ncDfk(nc_keep)];
    wc_mse_m = [wc_mse_m; data_k.er_wcDfk(wc_keep)];

    freqCtrs_m = data_k.freqBandCtrs;
end

fprintf('Motion-clean: OL %d/%d kept (%.0f%% excluded)  CL %d/%d kept (%.0f%% excluded)\n', ...
    n_tot_nc - n_exc_nc, n_tot_nc, 100*n_exc_nc/max(n_tot_nc,1), ...
    n_tot_wc - n_exc_wc, n_tot_wc, 100*n_exc_wc/max(n_tot_wc,1));

if ~isempty(nc_all_m) && ~isempty(freqCtrs_m)
    [~, nc_ord_m] = sort(nc_mse_m, 'ascend');
    [~, wc_ord_m] = sort(wc_mse_m, 'ascend');

    clim_m = prctile([nc_all_m(:); wc_all_m(:)], 98);
    if use_abs_m
        cbar_lbl_m = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_m = 'band/total power';
    end

    lm_j2 = 0.08; rm_j2 = 0.12; bm_j2 = 0.10; tm_j2 = 0.06; mid_gap2 = 0.04;
    pw_j2 = (1 - lm_j2 - rm_j2 - mid_gap2) / 2;
    ph_j2 = 1 - tm_j2 - bm_j2;

    fig_J2 = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol2 = axes(fig_J2, 'Position', [lm_j2,                bm_j2, pw_j2, ph_j2]);
    imagesc(ax_ol2, freqCtrs_m, 1:size(nc_all_m,1), nc_all_m(nc_ord_m,:));
    colormap(ax_ol2, 'hot'); clim(ax_ol2, [0 clim_m]);
    set(ax_ol2, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize',6);
    xlabel(ax_ol2, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol2, 'Trial (low \rightarrow high MSE)', 'FontWeight','bold');
    title(ax_ol2, sprintf('Open-Loop  (motion-clean, |z| \\leq %.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');

    ax_cl2 = axes(fig_J2, 'Position', [lm_j2+pw_j2+mid_gap2, bm_j2, pw_j2, ph_j2]);
    imagesc(ax_cl2, freqCtrs_m, 1:size(wc_all_m,1), wc_all_m(wc_ord_m,:));
    colormap(ax_cl2, 'hot'); clim(ax_cl2, [0 clim_m]);
    set(ax_cl2, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize',6, 'YTickLabel',{});
    xlabel(ax_cl2, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl2, sprintf('Closed-Loop  (motion-clean, |z| \\leq %.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    cb2 = colorbar(ax_cl2); cb2.Label.String = cbar_lbl_m; cb2.FontSize = 6;

    exportgraphics(fig_J2, 'paper/freq_heatmap_motionclean.png', 'Resolution',300);
    % fprintf('Figure J2 saved ->' paper/freq_heatmap_motionclean.png\n');
end

%% Figures K1 & K2 -- Pre-stim dFk variance as trial sort key (all trials)
% K1: OL|CL spectral heatmap sorted by 3-s pre-onset dFk variance, MSE shown as side strip
% K2: pre-stim variance vs MSE scatter with regression slopes

preSamples_k = 3 * 35;   % 3 s pre-onset at 35 Hz

nc_all_k1 = []; wc_all_k1 = [];
nc_mse_k1 = []; wc_mse_k1 = [];
nc_var_k1 = []; wc_var_k1 = [];
freqCtrs_k1 = [];
use_abs_k1  = false;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;  wc_spec = data_k.wcFreqPow;
        use_abs_k1 = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec; wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nSamp_k  = min(preSamples_k, size(data_k.pncDfk_l, 2));
    var_nc_k = var(data_k.pncDfk_l(:, 1:nSamp_k), [], 2);
    var_wc_k = var(data_k.pwcDfk_l(:, 1:nSamp_k), [], 2);

    nNC = min([size(nc_mean_k,1), numel(var_nc_k), numel(data_k.er_ncDfk)]);
    nWC = min([size(wc_mean_k,1), numel(var_wc_k), numel(data_k.er_wcDfk)]);

    nc_all_k1 = [nc_all_k1; nc_mean_k(1:nNC, :)];
    wc_all_k1 = [wc_all_k1; wc_mean_k(1:nWC, :)];
    nc_mse_k1 = [nc_mse_k1; data_k.er_ncDfk(1:nNC)];
    wc_mse_k1 = [wc_mse_k1; data_k.er_wcDfk(1:nWC)];
    nc_var_k1 = [nc_var_k1; var_nc_k(1:nNC)];
    wc_var_k1 = [wc_var_k1; var_wc_k(1:nWC)];
    freqCtrs_k1 = data_k.freqBandCtrs;
end

% Figure K1
if ~isempty(nc_all_k1) && ~isempty(freqCtrs_k1)
    [~, nc_ord_k1] = sort(nc_var_k1, 'ascend');
    [~, wc_ord_k1] = sort(wc_var_k1, 'ascend');

    clim_k1    = prctile([nc_all_k1(:); wc_all_k1(:)], 98);
    mse_lim_k1 = prctile([nc_mse_k1;   wc_mse_k1],    98);
    if use_abs_k1
        cbar_lbl_k1 = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_k1 = 'band/total power';
    end

    lm_k1=0.07; rm_k1=0.08; bm_k1=0.10; tm_k1=0.06;
    mse_w_k1=0.025; gap_k1=0.008; pair_gap_k1=0.05;
    pw_k1 = (1 - lm_k1 - rm_k1 - 2*mse_w_k1 - 2*gap_k1 - pair_gap_k1) / 2;
    ph_k1 = 1 - tm_k1 - bm_k1;

    x_ol_h = lm_k1;
    x_ol_s = x_ol_h + pw_k1 + gap_k1;
    x_cl_h = x_ol_s + mse_w_k1 + pair_gap_k1;
    x_cl_s = x_cl_h + pw_k1 + gap_k1;

    fig_K1 = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol_k1 = axes(fig_K1, 'Position', [x_ol_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_ol_k1, freqCtrs_k1, 1:size(nc_all_k1,1), nc_all_k1(nc_ord_k1,:));
    colormap(ax_ol_k1, 'hot'); clim(ax_ol_k1, [0 clim_k1]);
    set(ax_ol_k1, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_k1, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_k1, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_k1, 'Open-Loop', 'FontSize',6, 'FontWeight','bold');

    ax_ol_ms = axes(fig_K1, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_ms, 1, 1:numel(nc_mse_k1), nc_mse_k1(nc_ord_k1));
    colormap(ax_ol_ms, 'parula'); clim(ax_ol_ms, [0 mse_lim_k1]);
    set(ax_ol_ms, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_ms, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_k1 = axes(fig_K1, 'Position', [x_cl_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_cl_k1, freqCtrs_k1, 1:size(wc_all_k1,1), wc_all_k1(wc_ord_k1,:));
    colormap(ax_cl_k1, 'hot'); clim(ax_cl_k1, [0 clim_k1]);
    set(ax_cl_k1, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_k1, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_k1, 'Closed-Loop', 'FontSize',6, 'FontWeight','bold');
    cb_k1 = colorbar(ax_cl_k1); cb_k1.Label.String = cbar_lbl_k1; cb_k1.FontSize = 6;

    ax_cl_ms = axes(fig_K1, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_ms, 1, 1:numel(wc_mse_k1), wc_mse_k1(wc_ord_k1));
    colormap(ax_cl_ms, 'parula'); clim(ax_cl_ms, [0 mse_lim_k1]);
    set(ax_cl_ms, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_ms, 'MSE', 'FontSize',6, 'FontWeight','bold');

    exportgraphics(fig_K1, 'paper/freq_heatmap_prestimvar.png', 'Resolution',300);
    % fprintf('Figure K1 saved ->' paper/freq_heatmap_prestimvar.png\n');
end

% Figure K2 -- pre-stim variance vs MSE scatter
if ~isempty(nc_var_k1)
    fig_K2 = figure('Color','w', 'Units','centimeters', 'Position',[0 0 6 4]);
    hold on;

    scatter(nc_var_k1, nc_mse_k1, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');
    scatter(wc_var_k1, wc_mse_k1, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');

    xAll_k2 = [nc_var_k1; wc_var_k1];
    xr_k2   = linspace(min(xAll_k2), max(xAll_k2), 100);
    pNC_k2  = [0 0]; pWC_k2 = [0 0];
    if numel(nc_var_k1) > 1
        pNC_k2 = polyfit(nc_var_k1, nc_mse_k1, 1);
        plot(xr_k2, polyval(pNC_k2, xr_k2), '-', 'Color',colOL, 'LineWidth',1.5, 'DisplayName','Open-Loop');
    end
    if numel(wc_var_k1) > 1
        pWC_k2 = polyfit(wc_var_k1, wc_mse_k1, 1);
        plot(xr_k2, polyval(pWC_k2, xr_k2), '-', 'Color',colCL, 'LineWidth',1.5, 'DisplayName','Closed-Loop');
    end

    ax_k2 = gca; xl_k2 = xlim(ax_k2); yl_k2 = ylim(ax_k2);
    text(xl_k2(2), yl_k2(2) - 0.05*(yl_k2(2)-yl_k2(1)), sprintf('slope OL = %.3f', pNC_k2(1)), ...
        'Color',colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
    text(xl_k2(2), yl_k2(2) - 0.18*(yl_k2(2)-yl_k2(1)), sprintf('slope CL = %.3f', pWC_k2(1)), ...
        'Color',colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim dFk variance (3 s)', 'FontWeight','bold', 'FontSize',6);
    ylabel('MSE  ||e||',                   'FontWeight','bold', 'FontSize',6);
    set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
    exportgraphics(fig_K2, 'paper/prestimvar_mse.png', 'Resolution',300);
    % fprintf('Figure K2 saved ->' paper/prestimvar_mse.pdf\n');
end

%% K1z & K2z -- Pre-stim variance sort: per-frequency z-scored spectrum + quintile MSE bars
% K1z: same trial sort as K1 (ascending pre-stim variance) but spectrum z-scored
%   per frequency band across all pooled OL+CL trials. Blue-white-red diverging
%   colormap reveals 2-4 Hz elevation relative to the cross-trial mean.
%   MSE strip uses 'hot' colormap for stronger contrast.
% K2z: pre-stim variance binned into quintiles; grouped OL vs CL bars of mean
%   MSE +/- SEM. Makes the OL-CL gap directly visible per brain-state tier.

if ~isempty(nc_all_k1) && ~isempty(freqCtrs_k1)

    % Per-frequency z-score: normalise each freq band across all pooled trials
    all_spec_z = [nc_all_k1; wc_all_k1];
    mu_f_z     = mean(all_spec_z, 1);
    sig_f_z    = std(all_spec_z, 0, 1) + eps;
    nc_z_k1    = (nc_all_k1 - mu_f_z) ./ sig_f_z;
    wc_z_k1    = (wc_all_k1 - mu_f_z) ./ sig_f_z;

    clim_z    = max(prctile(abs([nc_z_k1(:); wc_z_k1(:)]), 98), 0.1);
    mse_lim_z = prctile([nc_mse_k1; wc_mse_k1], 98);

    [~, nc_ord_z] = sort(nc_var_k1, 'ascend');
    [~, wc_ord_z] = sort(wc_var_k1, 'ascend');

    % Blue-white-red diverging colormap
    nC = 256;
    cmap_bwr = [linspace(0,1,nC/2)', linspace(0,1,nC/2)', ones(nC/2,1); ...
                ones(nC/2,1), linspace(1,0,nC/2)', linspace(1,0,nC/2)'];

    % Layout identical to K1
    lm_z=0.07; rm_z=0.08; bm_z=0.10; tm_z=0.06;
    mse_w_z=0.025; gap_z=0.008; pair_gap_z=0.05;
    pw_z = (1 - lm_z - rm_z - 2*mse_w_z - 2*gap_z - pair_gap_z) / 2;
    ph_z = 1 - tm_z - bm_z;
    x_ol_hz = lm_z;
    x_ol_sz = x_ol_hz + pw_z + gap_z;
    x_cl_hz = x_ol_sz + mse_w_z + pair_gap_z;
    x_cl_sz = x_cl_hz + pw_z + gap_z;

    fig_K1z = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol_z = axes(fig_K1z, 'Position', [x_ol_hz, bm_z, pw_z, ph_z]);
    imagesc(ax_ol_z, freqCtrs_k1, 1:size(nc_z_k1,1), nc_z_k1(nc_ord_z,:));
    colormap(ax_ol_z, cmap_bwr);  clim(ax_ol_z, [-clim_z, clim_z]);
    set(ax_ol_z, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_z, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_z, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_z, 'Open-Loop  (z-score per freq)', 'FontSize',6, 'FontWeight','bold');

    ax_ol_msz = axes(fig_K1z, 'Position', [x_ol_sz, bm_z, mse_w_z, ph_z]);
    imagesc(ax_ol_msz, 1, 1:numel(nc_mse_k1), nc_mse_k1(nc_ord_z));
    colormap(ax_ol_msz, 'hot');  clim(ax_ol_msz, [0 mse_lim_z]);
    set(ax_ol_msz, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_msz, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_z = axes(fig_K1z, 'Position', [x_cl_hz, bm_z, pw_z, ph_z]);
    imagesc(ax_cl_z, freqCtrs_k1, 1:size(wc_z_k1,1), wc_z_k1(wc_ord_z,:));
    colormap(ax_cl_z, cmap_bwr);  clim(ax_cl_z, [-clim_z, clim_z]);
    set(ax_cl_z, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_z, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_z, 'Closed-Loop  (z-score per freq)', 'FontSize',6, 'FontWeight','bold');
    cb_z = colorbar(ax_cl_z);
    cb_z.Label.String = 'Power z-score';  cb_z.FontSize = 6;

    ax_cl_msz = axes(fig_K1z, 'Position', [x_cl_sz, bm_z, mse_w_z, ph_z]);
    imagesc(ax_cl_msz, 1, 1:numel(wc_mse_k1), wc_mse_k1(wc_ord_z));
    colormap(ax_cl_msz, 'hot');  clim(ax_cl_msz, [0 mse_lim_z]);
    set(ax_cl_msz, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_msz, 'MSE', 'FontSize',6, 'FontWeight','bold');

    % exportgraphics(fig_K1z, 'paper/freq_heatmap_prestimvar_zscore.png', 'Resolution',300);
    fprintf('Figure K1z ready\n');
end

% Figure K2z -- quintile bar chart
if ~isempty(nc_var_k1)
    nBins   = 5;
    edges_z = prctile([nc_var_k1; wc_var_k1], linspace(0, 100, nBins+1));
    edges_z(1) = -inf;  edges_z(end) = inf;

    nc_mse_bins = cell(nBins,1);  wc_mse_bins = cell(nBins,1);
    for b = 1:nBins
        nc_mse_bins{b} = nc_mse_k1(nc_var_k1 >= edges_z(b) & nc_var_k1 < edges_z(b+1));
        wc_mse_bins{b} = wc_mse_k1(wc_var_k1 >= edges_z(b) & wc_var_k1 < edges_z(b+1));
    end
    nc_mu_z  = cellfun(@mean, nc_mse_bins);
    wc_mu_z  = cellfun(@mean, wc_mse_bins);
    nc_sem_z = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), nc_mse_bins);
    wc_sem_z = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), wc_mse_bins);

    bw = 0.35;
    fig_K2z = figure('Color','w', 'Units','centimeters', 'Position',[0 0 8 5]);
    hold on;
    bar((1:nBins) - bw/2, nc_mu_z, bw, 'FaceColor',colOL, 'EdgeColor','none', 'DisplayName','Open-Loop');
    bar((1:nBins) + bw/2, wc_mu_z, bw, 'FaceColor',colCL, 'EdgeColor','none', 'DisplayName','Closed-Loop');
    errorbar((1:nBins) - bw/2, nc_mu_z, nc_sem_z, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    errorbar((1:nBins) + bw/2, wc_mu_z, wc_sem_z, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    set(gca, 'XTick',1:nBins, ...
        'XTickLabel', arrayfun(@(b) sprintf('Q%d',b), 1:nBins, 'UniformOutput',false), ...
        'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim variance quintile  (Q1 = low)', 'FontWeight','bold', 'FontSize',6);
    ylabel('Mean MSE  ||e||',                        'FontWeight','bold', 'FontSize',6);
    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    title('MSE by pre-stim variance quintile', 'FontSize',6, 'FontWeight','bold');
    % exportgraphics(fig_K2z, 'paper/prestimvar_mse_binned.pdf', 'ContentType','vector');
    fprintf('Figure K2z ready\n');
end

%% K2i -- Interactive pooled pre-stim variance scatter
% Click any point to open plotSingleTrial (dFk trace + motion + input).
% Pools all sessions; OL red, CL green -- same layout as K2 but interactive.

ud_nc_i = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
ud_wc_i = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
nc_var_i = [];  nc_mse_i = [];
wc_var_i = [];  wc_mse_i = [];

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end

    nSamp_k  = min(preSamples_k, size(data_k.pncDfk_l, 2));
    var_nc_k = var(data_k.pncDfk_l(:, 1:nSamp_k), [], 2);
    var_wc_k = var(data_k.pwcDfk_l(:, 1:nSamp_k), [], 2);

    nNC = min([numel(var_nc_k), numel(data_k.er_ncDfk), numel(data_k.nc)]);
    nWC = min([numel(var_wc_k), numel(data_k.er_wcDfk), numel(data_k.wc)]);

    nc_var_i = [nc_var_i; var_nc_k(1:nNC)];
    nc_mse_i = [nc_mse_i; data_k.er_ncDfk(1:nNC)];
    wc_var_i = [wc_var_i; var_wc_k(1:nWC)];
    wc_mse_i = [wc_mse_i; data_k.er_wcDfk(1:nWC)];

    for j = 1:nNC
        ud_nc_i(end+1) = struct('field', fields{k}, 'stim_idx', data_k.nc(j), ...
            'lbl', 'OL', 'mse', data_k.er_ncDfk(j));
    end
    for j = 1:nWC
        ud_wc_i(end+1) = struct('field', fields{k}, 'stim_idx', data_k.wc(j), ...
            'lbl', 'CL', 'mse', data_k.er_wcDfk(j));
    end
end

fig_K2i = figure('Color','w', 'Name','Interactive Pre-Stim Var Scatter');
fig_K2i.Units    = 'inches';
fig_K2i.Position = [1, 1, 6, 5];
hold on;

sc_nc_i = scatter(nc_var_i, nc_mse_i, 20, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName','OL');
sc_nc_i.UserData      = ud_nc_i;
sc_nc_i.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

sc_wc_i = scatter(wc_var_i, wc_mse_i, 20, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName','CL');
sc_wc_i.UserData      = ud_wc_i;
sc_wc_i.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

legend('Box','off', 'Location','northwest', 'FontSize',9, 'FontWeight','bold');
xlabel('Pre-stim dFk variance (3 s)', 'FontWeight','bold');
ylabel('MSE  ||e||',                   'FontWeight','bold');
title('Pre-stim variance vs MSE -- click to inspect trial', 'FontSize',9);
set(gca, 'Box','off', 'TickDir','out');
fprintf('K2i ready -- click any point to inspect that trial.\n');

%% Figures K1m & K2m -- Pre-stim variance sorted, motion-clean (|z-motion| <= motThresh)
nc_all_k1m = []; wc_all_k1m = [];
nc_mse_k1m = []; wc_mse_k1m = [];
nc_var_k1m = []; wc_var_k1m = [];
freqCtrs_k1m = [];
use_abs_k1m  = false;
n_exc_nc_k1m = 0; n_exc_wc_k1m = 0;
n_tot_nc_k1m = 0; n_tot_wc_k1m = 0;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end
    if ~isfield(data_k, 'ncmotion')  || ~any(data_k.ncmotion(:)),  continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;  wc_spec = data_k.wcFreqPow;
        use_abs_k1m = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec; wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    n_cols    = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;
    win_start = max(1,      onset_col - round(iMode_j2.pre_secs * 35));
    win_end   = min(n_cols, onset_col + dur_k * 35);

    ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
    wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);

    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nSamp_k  = min(preSamples_k, size(data_k.pncDfk_l, 2));
    var_nc_k = var(data_k.pncDfk_l(:, 1:nSamp_k), [], 2);
    var_wc_k = var(data_k.pwcDfk_l(:, 1:nSamp_k), [], 2);

    nNC = min([size(nc_mean_k,1), numel(var_nc_k), numel(ncm), numel(data_k.er_ncDfk)]);
    nWC = min([size(wc_mean_k,1), numel(var_wc_k), numel(wcm), numel(data_k.er_wcDfk)]);

    nc_keep = abs(ncm(1:nNC)) <= motThresh;
    wc_keep = abs(wcm(1:nWC)) <= motThresh;

    n_tot_nc_k1m = n_tot_nc_k1m + nNC;
    n_tot_wc_k1m = n_tot_wc_k1m + nWC;
    n_exc_nc_k1m = n_exc_nc_k1m + sum(~nc_keep);
    n_exc_wc_k1m = n_exc_wc_k1m + sum(~wc_keep);

    nc_all_k1m = [nc_all_k1m; nc_mean_k(nc_keep, :)];
    wc_all_k1m = [wc_all_k1m; wc_mean_k(wc_keep, :)];
    nc_mse_k1m = [nc_mse_k1m; data_k.er_ncDfk(nc_keep)];
    wc_mse_k1m = [wc_mse_k1m; data_k.er_wcDfk(wc_keep)];
    nc_var_k1m = [nc_var_k1m; var_nc_k(nc_keep)];
    wc_var_k1m = [wc_var_k1m; var_wc_k(wc_keep)];
    freqCtrs_k1m = data_k.freqBandCtrs;
end

fprintf('K1m motion-clean: OL %d/%d kept (%.0f%% excl)  CL %d/%d kept (%.0f%% excl)\n', ...
    n_tot_nc_k1m - n_exc_nc_k1m, n_tot_nc_k1m, 100*n_exc_nc_k1m/max(n_tot_nc_k1m,1), ...
    n_tot_wc_k1m - n_exc_wc_k1m, n_tot_wc_k1m, 100*n_exc_wc_k1m/max(n_tot_wc_k1m,1));

% Figure K1m
if ~isempty(nc_all_k1m) && ~isempty(freqCtrs_k1m)
    [~, nc_ord_k1m] = sort(nc_var_k1m, 'ascend');
    [~, wc_ord_k1m] = sort(wc_var_k1m, 'ascend');

    clim_k1m    = prctile([nc_all_k1m(:); wc_all_k1m(:)], 98);
    mse_lim_k1m = prctile([nc_mse_k1m;   wc_mse_k1m],    98);
    if use_abs_k1m
        cbar_lbl_k1m = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_k1m = 'band/total power';
    end

    fig_K1m = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol_k1m = axes(fig_K1m, 'Position', [x_ol_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_ol_k1m, freqCtrs_k1m, 1:size(nc_all_k1m,1), nc_all_k1m(nc_ord_k1m,:));
    colormap(ax_ol_k1m, 'hot'); clim(ax_ol_k1m, [0 clim_k1m]);
    set(ax_ol_k1m, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_k1m, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_k1m, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_k1m, sprintf('Open-Loop  (motion-clean, |z|\\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');

    ax_ol_msm = axes(fig_K1m, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_msm, 1, 1:numel(nc_mse_k1m), nc_mse_k1m(nc_ord_k1m));
    colormap(ax_ol_msm, 'parula'); clim(ax_ol_msm, [0 mse_lim_k1m]);
    set(ax_ol_msm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_msm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_k1m = axes(fig_K1m, 'Position', [x_cl_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_cl_k1m, freqCtrs_k1m, 1:size(wc_all_k1m,1), wc_all_k1m(wc_ord_k1m,:));
    colormap(ax_cl_k1m, 'hot'); clim(ax_cl_k1m, [0 clim_k1m]);
    set(ax_cl_k1m, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_k1m, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_k1m, sprintf('Closed-Loop  (motion-clean, |z|\\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    cb_k1m = colorbar(ax_cl_k1m); cb_k1m.Label.String = cbar_lbl_k1m; cb_k1m.FontSize = 6;

    ax_cl_msm = axes(fig_K1m, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_msm, 1, 1:numel(wc_mse_k1m), wc_mse_k1m(wc_ord_k1m));
    colormap(ax_cl_msm, 'parula'); clim(ax_cl_msm, [0 mse_lim_k1m]);
    set(ax_cl_msm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_msm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    exportgraphics(fig_K1m, 'paper/freq_heatmap_prestimvar_motclean.png', 'Resolution',300);
    % fprintf('Figure K1m saved ->' paper/freq_heatmap_prestimvar_motclean.png\n');
end

% Figure K2m -- motion-clean pre-stim variance vs MSE scatter
if ~isempty(nc_var_k1m)
    fig_K2m = figure('Color','w', 'Units','centimeters', 'Position',[0 0 6 4]);
    hold on;

    scatter(nc_var_k1m, nc_mse_k1m, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');
    scatter(wc_var_k1m, wc_mse_k1m, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');

    xAll_k2m = [nc_var_k1m; wc_var_k1m];
    xr_k2m   = linspace(min(xAll_k2m), max(xAll_k2m), 100);
    pNC_k2m  = [0 0]; pWC_k2m = [0 0];
    if numel(nc_var_k1m) > 1
        pNC_k2m = polyfit(nc_var_k1m, nc_mse_k1m, 1);
        plot(xr_k2m, polyval(pNC_k2m, xr_k2m), '-', 'Color',colOL, 'LineWidth',1.5, 'DisplayName','Open-Loop');
    end
    if numel(wc_var_k1m) > 1
        pWC_k2m = polyfit(wc_var_k1m, wc_mse_k1m, 1);
        plot(xr_k2m, polyval(pWC_k2m, xr_k2m), '-', 'Color',colCL, 'LineWidth',1.5, 'DisplayName','Closed-Loop');
    end

    ax_k2m = gca; xl_k2m = xlim(ax_k2m); yl_k2m = ylim(ax_k2m);
    text(xl_k2m(2), yl_k2m(2) - 0.05*(yl_k2m(2)-yl_k2m(1)), sprintf('slope OL = %.3f', pNC_k2m(1)), ...
        'Color',colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
    text(xl_k2m(2), yl_k2m(2) - 0.18*(yl_k2m(2)-yl_k2m(1)), sprintf('slope CL = %.3f', pWC_k2m(1)), ...
        'Color',colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim dFk variance (3 s)', 'FontWeight','bold', 'FontSize',6);
    ylabel('MSE  ||e||',                   'FontWeight','bold', 'FontSize',6);
    set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
    exportgraphics(fig_K2m, 'paper/prestimvar_mse_motclean.png', 'Resolution',300);
    % fprintf('Figure K2m saved ->' paper/prestimvar_mse_motclean.pdf\n');
end
%% K1zm & K2zm -- Pre-stim variance sort: z-scored spectrum + quintile bars, motion-clean
% Same as K1z/K2z but operating on motion-excluded trials (|z-motion| <= motThresh).
% Uses nc_all_k1m / wc_all_k1m accumulated in the K1m section above.

if ~isempty(nc_all_k1m) && ~isempty(freqCtrs_k1m)

    % Per-frequency z-score across pooled motion-clean trials
    all_spec_zm = [nc_all_k1m; wc_all_k1m];
    mu_f_zm     = mean(all_spec_zm, 1);
    sig_f_zm    = std(all_spec_zm, 0, 1) + eps;
    nc_zm       = (nc_all_k1m - mu_f_zm) ./ sig_f_zm;
    wc_zm       = (wc_all_k1m - mu_f_zm) ./ sig_f_zm;

    clim_zm    = max(prctile(abs([nc_zm(:); wc_zm(:)]), 98), 0.1);
    mse_lim_zm = prctile([nc_mse_k1m; wc_mse_k1m], 98);

    [~, nc_ord_zm] = sort(nc_var_k1m, 'ascend');
    [~, wc_ord_zm] = sort(wc_var_k1m, 'ascend');

    % Blue-white-red diverging colormap (same as K1z)
    nC_zm = 256;
    cmap_bwr_m = [linspace(0,1,nC_zm/2)', linspace(0,1,nC_zm/2)', ones(nC_zm/2,1); ...
                  ones(nC_zm/2,1), linspace(1,0,nC_zm/2)', linspace(1,0,nC_zm/2)'];

    lm_zm=0.07; rm_zm=0.08; bm_zm=0.10; tm_zm=0.06;
    mse_w_zm=0.025; gap_zm=0.008; pair_gap_zm=0.05;
    pw_zm = (1 - lm_zm - rm_zm - 2*mse_w_zm - 2*gap_zm - pair_gap_zm) / 2;
    ph_zm = 1 - tm_zm - bm_zm;
    x_ol_hzm = lm_zm;
    x_ol_szm = x_ol_hzm + pw_zm + gap_zm;
    x_cl_hzm = x_ol_szm + mse_w_zm + pair_gap_zm;
    x_cl_szm = x_cl_hzm + pw_zm + gap_zm;

    fig_K1zm = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol_zm = axes(fig_K1zm, 'Position', [x_ol_hzm, bm_zm, pw_zm, ph_zm]);
    imagesc(ax_ol_zm, freqCtrs_k1m, 1:size(nc_zm,1), nc_zm(nc_ord_zm,:));
    colormap(ax_ol_zm, cmap_bwr_m);  clim(ax_ol_zm, [-clim_zm, clim_zm]);
    set(ax_ol_zm, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_zm, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_zm, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_zm, sprintf('Open-Loop  (z-score, motion-clean |z|\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');

    ax_ol_mszm = axes(fig_K1zm, 'Position', [x_ol_szm, bm_zm, mse_w_zm, ph_zm]);
    imagesc(ax_ol_mszm, 1, 1:numel(nc_mse_k1m), nc_mse_k1m(nc_ord_zm));
    colormap(ax_ol_mszm, 'hot');  clim(ax_ol_mszm, [0 mse_lim_zm]);
    set(ax_ol_mszm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_mszm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_zm = axes(fig_K1zm, 'Position', [x_cl_hzm, bm_zm, pw_zm, ph_zm]);
    imagesc(ax_cl_zm, freqCtrs_k1m, 1:size(wc_zm,1), wc_zm(wc_ord_zm,:));
    colormap(ax_cl_zm, cmap_bwr_m);  clim(ax_cl_zm, [-clim_zm, clim_zm]);
    set(ax_cl_zm, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_zm, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_zm, sprintf('Closed-Loop  (z-score, motion-clean |z|\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    cb_zm = colorbar(ax_cl_zm);
    cb_zm.Label.String = 'Power z-score';  cb_zm.FontSize = 6;

    ax_cl_mszm = axes(fig_K1zm, 'Position', [x_cl_szm, bm_zm, mse_w_zm, ph_zm]);
    imagesc(ax_cl_mszm, 1, 1:numel(wc_mse_k1m), wc_mse_k1m(wc_ord_zm));
    colormap(ax_cl_mszm, 'hot');  clim(ax_cl_mszm, [0 mse_lim_zm]);
    set(ax_cl_mszm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_mszm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    % exportgraphics(fig_K1zm, 'paper/freq_heatmap_prestimvar_zscore_motclean.png', 'Resolution',300);
    fprintf('Figure K1zm ready (motion-clean z-score heatmap)\n');
end

% Figure K2zm -- quintile bars, motion-clean
if ~isempty(nc_var_k1m)
    nBins_zm  = 5;
    edges_zm  = prctile([nc_var_k1m; wc_var_k1m], linspace(0, 100, nBins_zm+1));
    edges_zm(1) = -inf;  edges_zm(end) = inf;

    nc_mse_binsm = cell(nBins_zm,1);  wc_mse_binsm = cell(nBins_zm,1);
    for b = 1:nBins_zm
        nc_mse_binsm{b} = nc_mse_k1m(nc_var_k1m >= edges_zm(b) & nc_var_k1m < edges_zm(b+1));
        wc_mse_binsm{b} = wc_mse_k1m(wc_var_k1m >= edges_zm(b) & wc_var_k1m < edges_zm(b+1));
    end
    nc_mu_zm  = cellfun(@mean, nc_mse_binsm);
    wc_mu_zm  = cellfun(@mean, wc_mse_binsm);
    nc_sem_zm = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), nc_mse_binsm);
    wc_sem_zm = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), wc_mse_binsm);

    bw_zm = 0.35;
    fig_K2zm = figure('Color','w', 'Units','centimeters', 'Position',[0 0 8 5]);
    hold on;
    bar((1:nBins_zm) - bw_zm/2, nc_mu_zm, bw_zm, 'FaceColor',colOL, 'EdgeColor','none', 'DisplayName','Open-Loop');
    bar((1:nBins_zm) + bw_zm/2, wc_mu_zm, bw_zm, 'FaceColor',colCL, 'EdgeColor','none', 'DisplayName','Closed-Loop');
    errorbar((1:nBins_zm) - bw_zm/2, nc_mu_zm, nc_sem_zm, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    errorbar((1:nBins_zm) + bw_zm/2, wc_mu_zm, wc_sem_zm, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    set(gca, 'XTick',1:nBins_zm, ...
        'XTickLabel', arrayfun(@(b) sprintf('Q%d',b), 1:nBins_zm, 'UniformOutput',false), ...
        'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim variance quintile  (Q1 = low, motion-clean)', 'FontWeight','bold', 'FontSize',6);
    ylabel('Mean MSE  ||e||',                                       'FontWeight','bold', 'FontSize',6);
    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    title(sprintf('MSE by pre-stim variance quintile  (motion-clean |z|\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    % exportgraphics(fig_K2zm, 'paper/prestimvar_mse_binned_motclean.pdf', 'ContentType','vector');
    fprintf('Figure K2zm ready (motion-clean quintile bars)\n');
end


%% Figures K1w, K2w, K2iw -- same as K1/K2/K2i but variance over pre+trial window
% pncDfk_l layout: [3 s pre | dur s trial | 3 s post] at 35 Hz.
% Pre-only used cols 1:105. Here we extend to cols 1:(3+dur_loop)*35 to include the trial.
% This captures both resting state AND stimulus-evoked variability as the sort feature.

durLoop          = 3;           % hard-coded dur used when building pncDfk_l
preTrialSamples  = (3 + durLoop) * 35;   % = 210 samples

nc_all_kw = []; wc_all_kw = [];
nc_mse_kw = []; wc_mse_kw = [];
nc_var_kw = []; wc_var_kw = [];
ud_nc_kw  = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
ud_wc_kw  = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
freqCtrs_kw = [];
use_abs_kw  = false;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;  wc_spec = data_k.wcFreqPow;
        use_abs_kw = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec; wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nSamp_kw  = min(preTrialSamples, size(data_k.pncDfk_l, 2));
    var_nc_k  = var(data_k.pncDfk_l(:, 1:nSamp_kw), [], 2);
    var_wc_k  = var(data_k.pwcDfk_l(:, 1:nSamp_kw), [], 2);

    nNC = min([size(nc_mean_k,1), numel(var_nc_k), numel(data_k.er_ncDfk), numel(data_k.nc)]);
    nWC = min([size(wc_mean_k,1), numel(var_wc_k), numel(data_k.er_wcDfk), numel(data_k.wc)]);

    nc_all_kw = [nc_all_kw; nc_mean_k(1:nNC, :)];
    wc_all_kw = [wc_all_kw; wc_mean_k(1:nWC, :)];
    nc_mse_kw = [nc_mse_kw; data_k.er_ncDfk(1:nNC)];
    wc_mse_kw = [wc_mse_kw; data_k.er_wcDfk(1:nWC)];
    nc_var_kw = [nc_var_kw; var_nc_k(1:nNC)];
    wc_var_kw = [wc_var_kw; var_wc_k(1:nWC)];
    freqCtrs_kw = data_k.freqBandCtrs;

    for j = 1:nNC
        ud_nc_kw(end+1) = struct('field', fields{k}, 'stim_idx', data_k.nc(j), ...
            'lbl', 'OL', 'mse', data_k.er_ncDfk(j));
    end
    for j = 1:nWC
        ud_wc_kw(end+1) = struct('field', fields{k}, 'stim_idx', data_k.wc(j), ...
            'lbl', 'CL', 'mse', data_k.er_wcDfk(j));
    end
end

% Figure K1w -- heatmap sorted by pre+trial variance
if ~isempty(nc_all_kw) && ~isempty(freqCtrs_kw)
    [~, nc_ord_kw] = sort(nc_var_kw, 'ascend');
    [~, wc_ord_kw] = sort(wc_var_kw, 'ascend');

    clim_kw    = prctile([nc_all_kw(:); wc_all_kw(:)], 98);
    mse_lim_kw = prctile([nc_mse_kw;   wc_mse_kw],    98);
    if use_abs_kw
        cbar_lbl_kw = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_kw = 'band/total power';
    end

    fig_K1w = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol_kw = axes(fig_K1w, 'Position', [x_ol_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_ol_kw, freqCtrs_kw, 1:size(nc_all_kw,1), nc_all_kw(nc_ord_kw,:));
    colormap(ax_ol_kw, 'hot'); clim(ax_ol_kw, [0 clim_kw]);
    set(ax_ol_kw, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_kw, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_kw, 'Trial (low \rightarrow high pre+trial var)', 'FontWeight','bold');
    title(ax_ol_kw, 'Open-Loop  (pre+trial var)', 'FontSize',6, 'FontWeight','bold');

    ax_ol_msw = axes(fig_K1w, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_msw, 1, 1:numel(nc_mse_kw), nc_mse_kw(nc_ord_kw));
    colormap(ax_ol_msw, 'parula'); clim(ax_ol_msw, [0 mse_lim_kw]);
    set(ax_ol_msw, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_msw, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_kw = axes(fig_K1w, 'Position', [x_cl_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_cl_kw, freqCtrs_kw, 1:size(wc_all_kw,1), wc_all_kw(wc_ord_kw,:));
    colormap(ax_cl_kw, 'hot'); clim(ax_cl_kw, [0 clim_kw]);
    set(ax_cl_kw, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_kw, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_kw, 'Closed-Loop  (pre+trial var)', 'FontSize',6, 'FontWeight','bold');
    cb_kw = colorbar(ax_cl_kw); cb_kw.Label.String = cbar_lbl_kw; cb_kw.FontSize = 6;

    ax_cl_msw = axes(fig_K1w, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_msw, 1, 1:numel(wc_mse_kw), wc_mse_kw(wc_ord_kw));
    colormap(ax_cl_msw, 'parula'); clim(ax_cl_msw, [0 mse_lim_kw]);
    set(ax_cl_msw, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_msw, 'MSE', 'FontSize',6, 'FontWeight','bold');

    exportgraphics(fig_K1w, 'paper/freq_heatmap_pretrial_var.png', 'Resolution',300);
    % fprintf('Figure K1w saved ->' paper/freq_heatmap_pretrial_var.png\n');
end

% Figure K2w -- pre+trial variance vs MSE scatter
if ~isempty(nc_var_kw)
    fig_K2w = figure('Color','w', 'Units','centimeters', 'Position',[0 0 6 4]);
    hold on;

    scatter(nc_var_kw, nc_mse_kw, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');
    scatter(wc_var_kw, wc_mse_kw, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');

    xAll_kw = [nc_var_kw; wc_var_kw];
    xr_kw   = linspace(min(xAll_kw), max(xAll_kw), 100);
    pNC_kw  = [0 0]; pWC_kw = [0 0];
    if numel(nc_var_kw) > 1
        pNC_kw = polyfit(nc_var_kw, nc_mse_kw, 1);
        plot(xr_kw, polyval(pNC_kw, xr_kw), '-', 'Color',colOL, 'LineWidth',1.5, 'DisplayName','Open-Loop');
    end
    if numel(wc_var_kw) > 1
        pWC_kw = polyfit(wc_var_kw, wc_mse_kw, 1);
        plot(xr_kw, polyval(pWC_kw, xr_kw), '-', 'Color',colCL, 'LineWidth',1.5, 'DisplayName','Closed-Loop');
    end

    ax_kw = gca; xl_kw = xlim(ax_kw); yl_kw = ylim(ax_kw);
    text(xl_kw(2), yl_kw(2) - 0.05*(yl_kw(2)-yl_kw(1)), sprintf('slope OL = %.3f', pNC_kw(1)), ...
        'Color',colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
    text(xl_kw(2), yl_kw(2) - 0.18*(yl_kw(2)-yl_kw(1)), sprintf('slope CL = %.3f', pWC_kw(1)), ...
        'Color',colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    xlabel('dFk variance (pre+trial, 6 s)', 'FontWeight','bold', 'FontSize',6);
    ylabel('MSE  ||e||',                    'FontWeight','bold', 'FontSize',6);
    set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
    exportgraphics(fig_K2w, 'paper/pretrial_var_mse.png', 'Resolution',300);
    % fprintf('Figure K2w saved ->' paper/pretrial_var_mse.pdf\n');
end

% Figure K2iw -- interactive pre+trial variance scatter
if ~isempty(nc_var_kw)
    fig_K2iw = figure('Color','w', 'Name','Interactive Pre+Trial Var Scatter');
    fig_K2iw.Units    = 'inches';
    fig_K2iw.Position = [1, 1, 6, 5];
    hold on;

    sc_nc_kw = scatter(nc_var_kw, nc_mse_kw, 20, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.5, 'DisplayName','OL');
    sc_nc_kw.UserData      = ud_nc_kw;
    sc_nc_kw.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    sc_wc_kw = scatter(wc_var_kw, wc_mse_kw, 20, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.5, 'DisplayName','CL');
    sc_wc_kw.UserData      = ud_wc_kw;
    sc_wc_kw.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    legend('Box','off', 'Location','northwest', 'FontSize',9, 'FontWeight','bold');
    xlabel('dFk variance (pre+trial, 6 s)', 'FontWeight','bold');
    ylabel('MSE  ||e||',                    'FontWeight','bold');
    title('Pre+trial variance vs MSE -- click to inspect trial', 'FontSize',9);
    set(gca, 'Box','off', 'TickDir','out');
    fprintf('K2iw ready -- click any point to inspect that trial.\n');
end

%% Widebrain prediction -- contralateral ARX model (delay embedding)
% Predictor pixels = contralateral primary + grid around it.
% Model trained on spontaneous (pre-trial) data, applied to OL and CL trials.
% Residual (actual -' predicted) captures stimulus + controller effect.
close all;

selField = 12;

% â”€â”€ Parameters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
wb_sel      = selField;   % session to analyse (m10, AL_0039 2025-04-19)
pY          = 0;          % no AR self-lags -- prediction purely from contralateral pixels
pX          = 5;          % lags per contralateral predictor (~143 ms at 35 Hz)
Fs_wb       = 35;
dur_wb      = 3;          % trial duration (s)
spont_pre   = 6;          % spontaneous window before each trial (s)
k_wb         = 1;     % SVD kernel half-size (3x3 patch)
nPred        = 10;    % total predictor pixels (1 contra-primary + nPred-1 random)
redefine_roi = true;  % set false once midline + ROI are confirmed correct
mlag_wb      = max(pY, pX);

% â”€â”€ Session + SVD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
d_wb       = mouse.(fields{wb_sel}).d;
data_wb    = mouse.(fields{wb_sel}).data;

% SVD may be absent from old caches -- reload initialize_data if needed
if ~isfield(d_wb, 'svd')
    fprintf('SVD missing from cache for %s -- reloading...\n', fields{wb_sel});
    d_wb = initialize_data(mouse.(fields{wb_sel}).mn, mouse.(fields{wb_sel}).en, mouse.(fields{wb_sel}).td);
end

% If SVD still absent (files not on server for this session), scan loaded sessions
if ~isfield(d_wb, 'svd')
    fprintf('SVD unavailable for %s -- scanning other sessions...\n', fields{wb_sel});
    found = false;
    for k = 1:length(fields)
        if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
        if isfield(mouse.(fields{k}).d, 'svd')
            wb_sel  = k;
            d_wb    = mouse.(fields{k}).d;
            data_wb = mouse.(fields{k}).data;
            fprintf('Using session %s (%s %s e%d) for widebrain prediction.\n', ...
                fields{k}, mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en);
            found = true;
            break;
        end
    end
    if ~found
        error('No session with SVD data found. Re-run the loading block to populate d.svd.');
    end
end
U_wb       = d_wb.svd.U;      % [nY nX nSV]
V_wb       = d_wb.svd.V;      % [nSV nFrames]
mimg_wb    = d_wb.svd.mimg;   % [nY nX]
[nY_wb, nX_wb] = size(mimg_wb);
nSV_wb     = size(U_wb, 3);
nFrames    = size(V_wb, 2);
horizon_wb = double(d_wb.params.horizon);
brain_mask = mimg_wb > prctile(mimg_wb(:), 20);
w_r        = horizon_wb - 1;
idx_r      = 1:nFrames;

% pixel stores [row, col]
py_prim = double(d_wb.params.pixel(1));   % row
px_prim = double(d_wb.params.pixel(2));   % col

% â”€â”€ Combined interactive: midline + contralateral ROI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
% One figure: click midline (2 pts, Enter) ->' polygon outline (n pts, Enter).
% Results saved to midline.mat + contra_pixels.mat.  Set redefine_roi=false to skip.
if redefine_roi
    if exist('midline.mat',       'file'); delete('midline.mat');       end
    if exist('contra_pixels.mat', 'file'); delete('contra_pixels.mat'); end
end

if ~exist('midline.mat','file') || ~exist('contra_pixels.mat','file')
    fig_roi = figure('Color','k', 'Name','Define midline + contralateral ROI');
    imagesc(mimg_wb'); colormap(fig_roi, gray);
    clim([prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
    axis image off; hold on;

    % â”€â”€ Step 1: midline (exactly 2 clicks) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    title('STEP 1 -- Click 2 points along the MIDLINE, then press Enter', ...
        'Color','w', 'FontSize',10, 'FontWeight','bold');
    [xd1, yd1] = ginput(2);
    % transposed display: xd=original row, yd=original col -- swap to (col, row)
    x_ml = yd1; y_ml = xd1;
    if abs(y_ml(2)-y_ml(1)) > abs(x_ml(2)-x_ml(1))
        midline.a = (x_ml(2)-x_ml(1))/(y_ml(2)-y_ml(1));
        midline.b = x_ml(1) - midline.a*y_ml(1);
        midline.type = 'x_of_y';
    else
        midline.a = (y_ml(2)-y_ml(1))/(x_ml(2)-x_ml(1));
        midline.b = y_ml(1) - midline.a*x_ml(1);
        midline.type = 'y_of_x';
    end
    midline.img_size = [nY_wb, nX_wb];
    save('midline.mat', 'midline');

    % Overlay midline on same figure
    if strcmp(midline.type, 'x_of_y')
        t = linspace(1, nY_wb, 300);
        plot(t, midline.a*t + midline.b, 'w--', 'LineWidth', 1.5);
    else
        t = linspace(1, nX_wb, 300);
        plot(midline.a*t + midline.b, t, 'w--', 'LineWidth', 1.5);
    end
    fprintf('Midline saved (type=%s  a=%.4f  b=%.4f)\n', midline.type, midline.a, midline.b);

    % â”€â”€ Step 2: polygon outline of contralateral hemisphere â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    title('STEP 2 -- Click boundary of CONTRALATERAL hemisphere, press Enter to finish', ...
        'Color','c', 'FontSize',10, 'FontWeight','bold');
    [xd2, yd2] = ginput;   % unlimited clicks, Enter to finish
    % Close polygon for display and inpolygon
    xd2 = [xd2; xd2(1)];  yd2 = [yd2; yd2(1)];
    plot(xd2, yd2, 'c-', 'LineWidth', 1.5);
    drawnow; pause(0.4);
    close(fig_roi);

    % Convert polygon back to original (col, row) space
    poly_col = yd2;   % original cols
    poly_row = xd2;   % original rows

    % â”€â”€ Build mask via inpolygon (no toolbox needed) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    % Grid in display space (transposed): xg = original rows, yg = original cols
    [xg, yg] = meshgrid(1:nY_wb, 1:nX_wb);
    in_poly   = inpolygon(xg(:), yg(:), xd2, yd2);
    in_poly   = reshape(in_poly, nX_wb, nY_wb)';   % back to [nY x nX] original space

    % Intersect with brain mask; enforce boundary margin
    valid_mask = in_poly & brain_mask;
    valid_mask(1:k_wb+1, :)   = false;
    valid_mask(end-k_wb:end,:) = false;
    valid_mask(:, 1:k_wb+1)   = false;
    valid_mask(:, end-k_wb:end)= false;

    [rows_v, cols_v] = find(valid_mask);
    if isempty(rows_v)
        error('No valid pixels found inside the drawn polygon. Try a larger region.');
    end

    % Compute contralateral primary pixel (reflection across midline)
    ml    = midline;
    denom = 1 + ml.a^2;
    if strcmp(ml.type, 'x_of_y')
        D    = px_prim - ml.a*py_prim - ml.b;
        px_c = round(px_prim - 2*D / denom);
        py_c = round(py_prim + 2*ml.a*D / denom);
    else
        D    = ml.a*px_prim - py_prim + ml.b;
        px_c = round(px_prim - 2*ml.a*D / denom);
        py_c = round(py_prim + 2*D / denom);
    end
    px_c = max(k_wb+1, min(nX_wb-k_wb, double(px_c)));
    py_c = max(k_wb+1, min(nY_wb-k_wb, double(py_c)));

    % Pseudo-random grid: evenly spaced across ROI bounding box, then jittered,
    % then snapped to nearest valid pixel via dsearchn.
    n_grid   = nPred - 1;
    n_side   = ceil(sqrt(n_grid));
    r_min = min(rows_v); r_max = max(rows_v);
    c_min = min(cols_v); c_max = max(cols_v);
    % Divide bounding box into n_side equal cells; place nodes at cell centres
    % so outermost points are half a cell away from the boundary.
    r_spacing = (r_max - r_min) / n_side;
    c_spacing = (c_max - c_min) / n_side;
    r_lin = r_min + r_spacing * (0.5 : 1 : n_side - 0.5);
    c_lin = c_min + c_spacing * (0.5 : 1 : n_side - 0.5);
    [cg, rg] = meshgrid(c_lin, r_lin);
    rg = rg(:); cg = cg(:);
    jitter = 0.3;
    rg = round(rg + jitter * r_spacing * (2*rand(size(rg)) - 1));
    cg = round(cg + jitter * c_spacing * (2*rand(size(cg)) - 1));
    rg = max(k_wb+1, min(nY_wb-k_wb, rg));
    cg = max(k_wb+1, min(nX_wb-k_wb, cg));
    valid_pts = double([rows_v, cols_v]);
    query_pts = double([rg, cg]);
    snap_idx  = dsearchn(valid_pts, query_pts);
    snapped_rows = rows_v(snap_idx);
    snapped_cols = cols_v(snap_idx);
    [~, ui] = unique([snapped_rows, snapped_cols], 'rows', 'stable');
    snapped_rows = snapped_rows(ui(1:min(n_grid, numel(ui))));
    snapped_cols = snapped_cols(ui(1:min(n_grid, numel(ui))));
    pred_py = [py_c; snapped_rows];
    pred_px = [px_c; snapped_cols];

    save('contra_pixels.mat', 'pred_px', 'pred_py', 'poly_col', 'poly_row');
    fprintf('Saved %d predictor pixels to contra_pixels.mat\n', length(pred_px));
else
    ml  = load('midline.mat'); ml = ml.midline;
    tmp = load('contra_pixels.mat');
    pred_px  = tmp.pred_px;  pred_py  = tmp.pred_py;
    poly_col = tmp.poly_col; poly_row = tmp.poly_row;

    % Recompute contra-primary for display
    denom = 1 + ml.a^2;
    if strcmp(ml.type, 'x_of_y')
        D    = px_prim - ml.a*py_prim - ml.b;
        px_c = round(px_prim - 2*D / denom);
        py_c = round(py_prim + 2*ml.a*D / denom);
    else
        D    = ml.a*px_prim - py_prim + ml.b;
        px_c = round(px_prim - 2*ml.a*D / denom);
        py_c = round(py_prim + 2*D / denom);
    end
end
nPred = length(pred_px);
% fprintf('Primary (%d,%d) ->' contra (%d,%d)  |  %d predictor pixels\n', ...
%     py_prim, px_prim, py_c, px_c, nPred);

% â”€â”€ Pixel map: verify selection on transposed brain image â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
fig_pmap = figure('Color','k', 'Name','Widebrain predictor pixels');
fig_pmap.Units = 'centimeters'; fig_pmap.Position = [0 0 10 8];
ax_pm = axes(fig_pmap, 'Position',[0 0 1 0.88]);
imagesc(ax_pm, mimg_wb');
colormap(ax_pm, gray);
clim(ax_pm, [prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
axis(ax_pm, 'image', 'off');
hold(ax_pm, 'on');

% Midline (transposed display: x=row, y=col)
if strcmp(ml.type, 'x_of_y')
    t = linspace(1, nY_wb, 300);
    plot(ax_pm, t, ml.a*t + ml.b, 'w--', 'LineWidth', 1.2);
else
    t = linspace(1, nX_wb, 300);
    plot(ax_pm, ml.a*t + ml.b, t, 'w--', 'LineWidth', 1.2);
end

% Polygon outline (poly_row/poly_col are in original space; display needs swap)
plot(ax_pm, poly_row, poly_col, 'c-', 'LineWidth', 1.2);

% Pixels (transposed display: scatter(row, col))
scatter(ax_pm, pred_py(2:end), pred_px(2:end), 50, ...
    'o','filled','MarkerFaceColor',[0.2 0.6 1],'MarkerEdgeColor','w','LineWidth',0.5);
scatter(ax_pm, py_c,    px_c,    100, ...
    's','filled','MarkerFaceColor',[0 0.9 1],  'MarkerEdgeColor','w','LineWidth',1.5);
scatter(ax_pm, py_prim, px_prim, 100, ...
    's','filled','MarkerFaceColor',[1 0.3 0.3],'MarkerEdgeColor','w','LineWidth',1.5);

legend(ax_pm, {'Midline','ROI outline','Random contra','Contra primary','Primary'}, ...
    'TextColor','w','Color','none','EdgeColor','none','FontSize',6,'FontWeight','bold', ...
    'Location','south','Orientation','horizontal');
hold(ax_pm, 'off');
fprintf('Pixel map ready. Set redefine_roi=false then run the regression cell.\n');

% â”€â”€ Extract dFk via SVD projection (cached) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
mn_wb   = mouse.(fields{wb_sel}).mn;
td_wb   = mouse.(fields{wb_sel}).td;
en_wb   = mouse.(fields{wb_sel}).en;
path_wb = fullfile('data', sprintf('%swb%s%s%d.mat', mn_wb, td_wb(6:7), td_wb(9:10), en_wb));

if exist(path_wb,'file') && ~redefine_roi
    tmp    = load(path_wb);
    y_full = tmp.y_full;
    X_full = tmp.X_full;
    fprintf('Loaded dFk cache: %s\n', path_wb);
else
    fprintf('Computing SVD pixel dFk (%d pixels) ...\n', nPred+1);

    % Primary pixel
    mI_p    = mean(mimg_wb(py_prim-k_wb:py_prim+k_wb, px_prim-k_wb:px_prim+k_wb), 'all');
    ikern_p = U_wb(py_prim-k_wb:py_prim+k_wb, px_prim-k_wb:px_prim+k_wb, :);
    ist_p   = reshape(mean(ikern_p, [1 2]), [1, nSV_wb]);
    F_p     = ist_p * V_wb + mI_p;
    Fk_p    = [ones(1,w_r)*mI_p, F_p];
    cs_p    = [0, cumsum(Fk_p)];
    Fm_p    = (cs_p(idx_r+w_r+1) - cs_p(idx_r)) / (w_r+1);
    y_full  = ((F_p - Fm_p) ./ Fm_p * 100)';

    % Contralateral predictor pixels
    X_full = zeros(nFrames, nPred);
    for j = 1:nPred
        cx = pred_px(j); cy = pred_py(j);
        mI_j    = mean(mimg_wb(cy-k_wb:cy+k_wb, cx-k_wb:cx+k_wb), 'all');
        ikern_j = U_wb(cy-k_wb:cy+k_wb, cx-k_wb:cx+k_wb, :);
        ist_j   = reshape(mean(ikern_j, [1 2]), [1, nSV_wb]);
        F_j     = ist_j * V_wb + mI_j;
        Fk_j    = [ones(1,w_r)*mI_j, F_j];
        cs_j    = [0, cumsum(Fk_j)];
        Fm_j    = (cs_j(idx_r+w_r+1) - cs_j(idx_r)) / (w_r+1);
        X_full(:,j) = ((F_j - Fm_j) ./ Fm_j * 100)';
    end

    save(path_wb, 'y_full', 'X_full', 'pred_px', 'pred_py');
    fprintf('Saved dFk cache: %s\n', path_wb);
end
%% OL step TF fit -- fixed 2p1z, three sessions; separate interactive validation figure
% Fits a fixed 2-pole 1-zero TF to the OL trial average for sessions [4 9 11].
% Main figure (nSess x 2): col 1 = OL traces + TF fit, col 2 = CL mean vs OL-TF pred.
% Separate interactive figure: trial R^2 vs trial MSE (OL + CL), click -> plotSingleTrial.

ol_sess_idx = [4 9 11];   % matches custom_idx in OL step response plot
Fs_ol  = 35;   Ts_ol = 1/Fs_ol;
Fs_in  = 2000;
nPre_ol  = 5;             % zero-prepend length (> model order for clean initialisation)
tfOpt_ol = tfestOptions('EnforceStability', false, 'Display', 'off');

nSess_ol  = numel(ol_sess_idx);
ol_colors = [0.2 0.4 0.8;
             0.8 0.2 0.2;
             0.2 0.7 0.3];

% Accumulation arrays for interactive validation figure
ud_nc_tf   = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
ud_wc_tf   = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
r2_nc_all  = [];  mse_nc_all = [];
r2_wc_all  = [];  mse_wc_all = [];

fig_ol = figure;
tlo_ol = tiledlayout(nSess_ol, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

rng('shuffle');   % ensure different random trial pick on every run

% Paper-level figure: OL trial average + TF fit, -1 to +1 s, one column per session
PS = paperStyle();
fig_tf_paper = paperFig(10, 4);
tlo_tf_paper = tiledlayout(fig_tf_paper, 1, nSess_ol, 'TileSpacing','compact','Padding','compact');

for si = 1:nSess_ol
    fld       = fields{ol_sess_idx(si)};
    d_ol      = mouse.(fld).d;
    data_ol_s = mouse.(fld).data;
    dur_ol    = d_ol.params.dur;
    col_s     = ol_colors(si, :);

    ncDfk_ol = data_ol_s.ncDfk;
    ncInp_ol = data_ol_s.ncInp;
    nNc_ol   = size(ncDfk_ol, 1);

    fprintf('\n-- Session %d: %s  %s  en%d  (%d OL trials  dur=%d s)\n', ...
        si, mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en, nNc_ol, dur_ol);

    if nNc_ol == 0
        warning('No OL trials in %s -- skipping.', fld);
        nexttile(tlo_ol); nexttile(tlo_ol); nexttile(tlo_ol);
        continue
    end

    % Downsample input 2 kHz -> 35 Hz
    ncInp_ds = resample(ncInp_ol', Fs_ol, Fs_in)';
    nSamp_ol = min(dur_ol*Fs_ol + 1, size(ncInp_ds, 2));
    ncInp_ds = ncInp_ds(:, 1:nSamp_ol);

    % Baseline correct: pre-onset window = first Fs_ol columns (t = -1 to 0 s)
    iOn_ol      = Fs_ol + 1;
    baseline_ol = mean(ncDfk_ol(:, 1:iOn_ol-1), 2);
    ncDfk_bc    = ncDfk_ol - baseline_ol;
    u_pre       = zeros(iOn_ol-1, 1);   % laser off before stim onset

    % Post-onset OL window (t = 0 to dur s)
    y_trials_ol = ncDfk_bc(:, iOn_ol : iOn_ol + nSamp_ol - 1);
    t_ol        = (0 : nSamp_ol-1) / Fs_ol;

    % Trial average
    y_mean_ol = mean(y_trials_ol, 1)';
    y_sem_ol  = std(y_trials_ol, 0, 1)' / sqrt(nNc_ol);
    u_mean_ol = mean(ncInp_ds, 1)';

    % Fit fixed 2p1z TF on OL trial average
    u_fit_ol   = [zeros(nPre_ol,1); u_mean_ol];
    y_fit_ol   = [zeros(nPre_ol,1); y_mean_ol];
    data_id_ol = iddata(y_fit_ol, u_fit_ol, Ts_ol);
    data_id_ol.Tstart = -nPre_ol * Ts_ol;
    best_ol = tfest(data_id_ol, 2, 1, tfOpt_ol);

    % OL mean prediction -- x0 from findstates on mean pre-onset window
    y_pre_ol_mean = mean(ncDfk_bc(:, 1:iOn_ol-1), 1)';
    x0_ol = findstates(best_ol, iddata(y_pre_ol_mean, u_pre, Ts_ol));
    yp_ol = sim(best_ol, iddata([], u_mean_ol, Ts_ol), x0_ol).OutputData;
    yp_ol = yp_ol + (y_mean_ol(1) - yp_ol(1));   % anchor at actual y_0

    SS_res = sum((y_mean_ol - yp_ol).^2, 'omitnan');
    SS_tot = sum((y_mean_ol - mean(y_mean_ol,'omitnan')).^2, 'omitnan');
    R2_ol  = 1 - SS_res / max(SS_tot, eps);

    p_ol   = pole(best_ol);
    tau_ol = sort(abs(1 ./ real(p_ol(real(p_ol) < 0))));
    fprintf('  2p1z  R2=%.3f  tau =', R2_ol);
    if ~isempty(tau_ol), fprintf('  %.3f s', tau_ol); end
    fprintf('\n');

    % Trial-level OL R^2 and accumulate UserData for interactive figure
    nNC_ud = min(nNc_ol, numel(data_ol_s.er_ncDfk));
    R2_ol_trials = nan(nNC_ud, 1);
    for j = 1:nNC_ud
        u_j = ncInp_ds(j,:)';
        y_j = y_trials_ol(j,:)';
        x0_j = findstates(best_ol, iddata(ncDfk_bc(j, 1:iOn_ol-1)', u_pre, Ts_ol));
        yp_j = sim(best_ol, iddata([], u_j, Ts_ol), x0_j).OutputData;
        ss_res_j = sum((y_j - yp_j).^2, 'omitnan');
        ss_tot_j = sum((y_j - mean(y_j,'omitnan')).^2, 'omitnan');
        R2_ol_trials(j) = 1 - ss_res_j / max(ss_tot_j, eps);
        ud_nc_tf(end+1) = struct('field', fld, 'stim_idx', data_ol_s.nc(j), ...
            'lbl', 'OL', 'mse', data_ol_s.er_ncDfk(j));
    end
    r2_nc_all  = [r2_nc_all;  R2_ol_trials];
    mse_nc_all = [mse_nc_all; data_ol_s.er_ncDfk(1:nNC_ud)];
    fprintf('  OL trial-level R2: med=%.3f  IQR=%.3f\n', median(R2_ol_trials,'omitnan'), iqr(R2_ol_trials));

    % Panel 1: OL trial traces + mean +/- SEM + TF fit
    ax_ol = nexttile(tlo_ol);
    hold(ax_ol, 'on');
    for j = 1:nNc_ol
        plot(ax_ol, t_ol, y_trials_ol(j,:), ...
            'Color', [col_s, 0.15], 'LineWidth', 0.4, 'HandleVisibility', 'off');
    end
    fill(ax_ol, [t_ol, fliplr(t_ol)], ...
        [(y_mean_ol+y_sem_ol)', fliplr((y_mean_ol-y_sem_ol)')], ...
        col_s, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax_ol, t_ol, y_mean_ol, 'Color', col_s, 'LineWidth', 2, 'DisplayName', 'OL mean');
    plot(ax_ol, t_ol, yp_ol, 'k--', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('TF 2p1z  R^2=%.2f', R2_ol));
    u_sc = max(abs(y_mean_ol)) / max(abs(u_mean_ol) + eps);
    plot(ax_ol, t_ol, u_mean_ol*u_sc, 'Color', [0.6 0.6 0.6], ...
        'LineWidth', 1, 'LineStyle', ':', 'DisplayName', 'Input (scaled)');
    xline(ax_ol, dur_ol, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xlabel(ax_ol, 'Time (s)', 'FontWeight', 'bold', 'FontSize', 6);
    ylabel(ax_ol, 'dF/F (%)', 'FontWeight', 'bold', 'FontSize', 6);
    legend(ax_ol, 'Box', 'off', 'FontSize', 6, 'Location', 'best');
    title(ax_ol, sprintf('Session %d -- %s  %s  en%d  (n=%d OL)', ...
        si, mouse.(fld).mn, mouse.(fld).td, mouse.(fld).en, nNc_ol), ...
        'FontSize', 6, 'FontWeight', 'bold');
    set(ax_ol, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

    % CL data prep
    wcDfk_ol = data_ol_s.wcDfk;
    wcInp_ol = data_ol_s.wcInp;
    nWc_ol   = size(wcDfk_ol, 1);
    wcInp_ds = resample(wcInp_ol', Fs_ol, Fs_in)';
    wcInp_ds = wcInp_ds(:, 1:nSamp_ol);
    baseline_wc = mean(wcDfk_ol(:, 1:iOn_ol-1), 2);
    wcDfk_bc    = wcDfk_ol - baseline_wc;
    y_trials_wc = wcDfk_bc(:, iOn_ol : iOn_ol + nSamp_ol - 1);
    y_mean_wc   = mean(y_trials_wc, 1)';
    y_sem_wc    = std(y_trials_wc, 0, 1)' / sqrt(nWc_ol);
    u_mean_wc   = mean(wcInp_ds, 1)';

    % CL mean prediction using OL model -- x0 from findstates on mean pre-onset window
    y_pre_wc_mean = mean(wcDfk_bc(:, 1:iOn_ol-1), 1)';
    x0_wc = findstates(best_ol, iddata(y_pre_wc_mean, u_pre, Ts_ol));
    yp_wc = sim(best_ol, iddata([], u_mean_wc, Ts_ol), x0_wc).OutputData;
    yp_wc = yp_wc + (y_mean_wc(1) - yp_wc(1));   % anchor at actual y_0

    SS_res_wc = sum((y_mean_wc - yp_wc).^2, 'omitnan');
    SS_tot_wc = sum((y_mean_wc - mean(y_mean_wc,'omitnan')).^2, 'omitnan');
    R2_wc     = 1 - SS_res_wc / max(SS_tot_wc, eps);
    fprintf('  CL mean pred  R2=%.3f  (n=%d CL trials)\n', R2_wc, nWc_ol);

    % Trial-level CL R^2 and accumulate UserData for interactive figure
    nWC_ud = min(nWc_ol, numel(data_ol_s.er_wcDfk));
    R2_cl_trials = nan(nWC_ud, 1);
    for j = 1:nWC_ud
        u_j = wcInp_ds(j,:)';
        y_j = y_trials_wc(j,:)';
        x0_j = findstates(best_ol, iddata(wcDfk_bc(j, 1:iOn_ol-1)', u_pre, Ts_ol));
        yp_j = sim(best_ol, iddata([], u_j, Ts_ol), x0_j).OutputData;
        ss_res_j = sum((y_j - yp_j).^2, 'omitnan');
        ss_tot_j = sum((y_j - mean(y_j,'omitnan')).^2, 'omitnan');
        R2_cl_trials(j) = 1 - ss_res_j / max(ss_tot_j, eps);
        ud_wc_tf(end+1) = struct('field', fld, 'stim_idx', data_ol_s.wc(j), ...
            'lbl', 'CL', 'mse', data_ol_s.er_wcDfk(j));
    end
    r2_wc_all  = [r2_wc_all;  R2_cl_trials];
    mse_wc_all = [mse_wc_all; data_ol_s.er_wcDfk(1:nWC_ud)];
    fprintf('  CL trial-level R2: med=%.3f  IQR=%.3f\n', median(R2_cl_trials,'omitnan'), iqr(R2_cl_trials));

    % Panel 2: CL actual vs OL-TF prediction (mean)
    ax_wc = nexttile(tlo_ol);
    hold(ax_wc, 'on');
    plot(ax_wc, t_ol, y_mean_ol, 'Color', [col_s, 0.3], 'LineWidth', 1, 'DisplayName', 'OL mean (ref)');
    fill(ax_wc, [t_ol, fliplr(t_ol)], ...
        [(y_mean_wc+y_sem_wc)', fliplr((y_mean_wc-y_sem_wc)')], ...
        colCL, 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax_wc, t_ol, y_mean_wc,  'Color', colCL, 'LineWidth', 2, 'DisplayName', 'CL actual');
    plot(ax_wc, t_ol, yp_wc, 'k--', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('OL-TF(CL mean input)  R^2=%.2f', R2_wc));
    u_sc_wc = max(abs(y_mean_wc)) / max(abs(u_mean_wc) + eps);
    plot(ax_wc, t_ol, u_mean_wc*u_sc_wc, 'Color', [0.6 0.6 0.6], ...
        'LineWidth', 1, 'LineStyle', ':', 'DisplayName', 'CL input (scaled)');
    xline(ax_wc, dur_ol, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xlabel(ax_wc, 'Time (s)', 'FontWeight', 'bold', 'FontSize', 6);
    ylabel(ax_wc, 'dF/F (%)', 'FontWeight', 'bold', 'FontSize', 6);
    legend(ax_wc, 'Box', 'off', 'FontSize', 6, 'Location', 'best');
    title(ax_wc, sprintf('CL actual vs OL-TF pred  (n=%d CL)', nWc_ol), ...
        'FontSize', 6, 'FontWeight', 'bold');
    set(ax_wc, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

    % Panel 3: random CL trial vs OL-TF prediction
    ti   = randi(nWc_ol);
    u_st = wcInp_ds(ti, :)';
    y_st = y_trials_wc(ti, :)';
    x0_st = findstates(best_ol, iddata(wcDfk_bc(ti, 1:iOn_ol-1)', u_pre, Ts_ol));
    yp_st = sim(best_ol, iddata([], u_st, Ts_ol), x0_st).OutputData;
    yp_st = yp_st + (y_st(1) - yp_st(1));   % anchor at actual y_0

    ax_st = nexttile(tlo_ol);
    hold(ax_st, 'on');
    plot(ax_st, t_ol, y_st, 'Color', colCL, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('CL trial %d', ti));
    plot(ax_st, t_ol, yp_st, 'k--', 'LineWidth', 1.5, 'DisplayName', 'OL-TF pred');
    u_sc_st = max(abs(y_st)) / max(abs(u_st) + eps);
    plot(ax_st, t_ol, u_st*u_sc_st, 'Color', [0.6 0.6 0.6], ...
        'LineWidth', 1, 'LineStyle', ':', 'DisplayName', 'Input (scaled)');
    xline(ax_st, dur_ol, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
    xlabel(ax_st, 'Time (s)', 'FontWeight', 'bold', 'FontSize', 6);
    ylabel(ax_st, 'dF/F (%)', 'FontWeight', 'bold', 'FontSize', 6);
    legend(ax_st, 'Box', 'off', 'FontSize', 6, 'Location', 'best');
    title(ax_st, sprintf('CL trial %d vs OL-TF pred', ti), ...
        'FontSize', 6, 'FontWeight', 'bold');
    set(ax_st, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

    % Paper panel: OL trial average -1 to stimend+1 s + TF pred (zero input post-stim)
    n_post_extra = Fs_ol;                                    % 35 pts = 1 s post-stim
    t_pre_w      = ((0:iOn_ol-2) / Fs_ol) - 1;             % -1 to -1/35 s  (35 pts)
    t_stim_w     = (0:nSamp_ol-1) / Fs_ol;                 % 0 to dur_ol s
    t_post_extra = ((1:n_post_extra) / Fs_ol) + dur_ol;    % dur_ol+1/35 to dur_ol+1 s
    t_w_full     = [t_pre_w, t_stim_w, t_post_extra];

    pre_mn_w   = mean(ncDfk_bc(:, 1:iOn_ol-1), 1);
    pre_sem_w  = std(ncDfk_bc(:, 1:iOn_ol-1), 0, 1);

    % Post-stim actual data (if ncDfk_bc extends beyond stim window)
    col_post_s = iOn_ol + nSamp_ol;
    col_post_e = col_post_s + n_post_extra - 1;
    if size(ncDfk_bc, 2) >= col_post_e
        y_post_w   = mean(ncDfk_bc(:, col_post_s:col_post_e), 1);
        sem_post_w = std(ncDfk_bc(:, col_post_s:col_post_e), 0, 1);
    else
        y_post_w   = nan(1, n_post_extra);
        sem_post_w = nan(1, n_post_extra);
    end

    y_std_ol_w = std(y_trials_ol, 0, 1);                   % std for paper panel shading
    y_w_full   = [pre_mn_w,  y_mean_ol',  y_post_w];
    sem_w_full = [pre_sem_w, y_std_ol_w,  sem_post_w];

    % TF prediction: actual stim input then zero for 1 s post-stim
    u_pred_ext = [u_mean_ol; zeros(n_post_extra, 1)];
    yp_ext     = sim(best_ol, iddata([], u_pred_ext, Ts_ol), x0_ol).OutputData;
    yp_ext     = yp_ext + (y_mean_ol(1) - yp_ext(1));      % anchor at onset
    t_pred_ext = [t_stim_w, t_post_extra];

    ax_p = nexttile(tlo_tf_paper);
    hold(ax_p, 'on');

    % Stim window shading (t=0 to dur_ol s)
    patch(ax_p, [0 dur_ol dur_ol 0], [-8 -8 5 5], [0.85 0.85 0.85], ...
        'FaceAlpha',0.5,'EdgeColor','none','HandleVisibility','off');

    % OL mean +/- SEM
    fill(ax_p, [t_w_full, fliplr(t_w_full)], ...
        [y_w_full+sem_w_full, fliplr(y_w_full-sem_w_full)], ...
        col_s, 'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    plot(ax_p, t_w_full, y_w_full, 'Color',col_s, 'LineWidth',1.5);

    % TF prediction over stim + 1 s post-stim (zero input after stim end)
    plot(ax_p, t_pred_ext, yp_ext, 'k--', 'LineWidth',1.2);

    xline(ax_p, 0,      'Color',[0.5 0.5 0.5], 'LineWidth',0.5, 'HandleVisibility','off');
    xline(ax_p, dur_ol, 'Color',[0.5 0.5 0.5], 'LineWidth',0.5, 'HandleVisibility','off');
    yline(ax_p, 0,      'Color',[0.7 0.7 0.7], 'LineWidth',0.5, 'HandleVisibility','off');
    hold(ax_p, 'off');
    set(ax_p, 'Box','off','XTick',[],'YTick',[],'XColor','none','YColor','none', ...
        'XLim',[-1 dur_ol+1],'YLim',[-8 5],'Clipping','off');

    % Corner scalebar on first panel only
    if si == 1
        shortCornerAxes_plot(ax_p, 'XLength',1, 'YLength',3, ...
            'XLabel','1 s', 'YLabel','3% dF/F', 'FontSize',PS.fs, 'FontWeight',PS.fw, 'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap);
    end
end

exportgraphics(fig_tf_paper, 'paper/images/figure2/ol_tf_trial_avg.pdf', 'ContentType','vector');
fprintf('OL TF paper figure (trial avg -1 to +1 s) ready\n');

% Interactive validation figure -- trial R^2 vs trial MSE, click -> plotSingleTrial
fig_tf_i = figure('Color', 'w', 'Name', 'TF Validation -- trial R^2 vs MSE (click to inspect)');
fig_tf_i.Units    = 'inches';
fig_tf_i.Position = [1, 1, 6, 5];
hold on;

sc_nc_tf = scatter(r2_nc_all, mse_nc_all, 20, colOL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.5, 'DisplayName', 'OL');
sc_nc_tf.UserData      = ud_nc_tf;
sc_nc_tf.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

sc_wc_tf = scatter(r2_wc_all, mse_wc_all, 20, colCL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.5, 'DisplayName', 'CL');
sc_wc_tf.UserData      = ud_wc_tf;
sc_wc_tf.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

xline(0, 'k:', 'LineWidth', 0.75, 'HandleVisibility', 'off');
legend('Box', 'off', 'Location', 'northwest', 'FontSize', 9, 'FontWeight', 'bold');
xlabel('OL-TF trial R^2',   'FontWeight', 'bold');
ylabel('Trial MSE  ||e||',  'FontWeight', 'bold');
title('TF validation -- click any point to inspect trial', 'FontSize', 9);
set(gca, 'Box', 'off', 'TickDir', 'out');
fprintf('TF validation figure ready -- click any point to inspect that trial.\n');

% exportgraphics(fig_ol, 'paper/ol_tf_three_sessions.pdf', 'ContentType', 'vector');


%% Widebrain prediction -- ARX regression
% Requires the pixel-selection cell above to have been run first.
% Fits contralateral-only ARX model on spontaneous data, applies to OL/CL trials.

% â”€â”€ Spontaneous windows (6 s pre-trial, all trials pooled) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
t_wb       = d_wb.timeBlue;
all_trials = [data_wb.nc(:); data_wb.wc(:)];
pre_frames = spont_pre * Fs_wb;

y_spont = []; X_spont = [];
for j = 1:length(all_trials)
    [~, i_on] = min(abs(t_wb - d_wb.stimStarts(all_trials(j))));
    i0 = i_on - pre_frames; i1 = i_on - 1;
    if i0 < 1; continue; end
    y_spont = [y_spont; y_full(i0:i1)];
    X_spont = [X_spont; X_full(i0:i1,:)];
end

% â”€â”€ Fit ARX on spontaneous data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
[Phi_s, y_s] = buildLagMatrix(y_spont, X_spont, pY, pX);
beta         = Phi_s \ y_s;
y_hat_s      = Phi_s * beta;
R2_spont     = 1 - sum((y_s - y_hat_s).^2) / sum((y_s - mean(y_s)).^2);
fprintf('ARX  R^2_spont=%.3f  (pY=%d  pX=%d  nPred=%d)\n', R2_spont, pY, pX, nPred);

% â”€â”€ Apply model to OL trials â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
trial_frames = dur_wb * Fs_wb;   % 105 frames
outlen       = trial_frames;     % buildLagMatrix drops first mlag_wb; output = trial_frames

pred_nc   = nan(length(data_wb.nc), outlen);
actual_nc = nan(length(data_wb.nc), outlen);
for j = 1:length(data_wb.nc)
    [~, i_on] = min(abs(t_wb - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on - mlag_wb; i1 = i_on + trial_frames - 1;
    if i0 < 1 || i1 > nFrames; continue; end
    [Phi_t, y_t]   = buildLagMatrix(y_full(i0:i1), X_full(i0:i1,:), pY, pX);
    pred_nc(j,:)   = Phi_t * beta;
    actual_nc(j,:) = y_t;
end

% â”€â”€ Apply model to CL trials â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
pred_wc   = nan(length(data_wb.wc), outlen);
actual_wc = nan(length(data_wb.wc), outlen);
for j = 1:length(data_wb.wc)
    [~, i_on] = min(abs(t_wb - d_wb.stimStarts(data_wb.wc(j))));
    i0 = i_on - mlag_wb; i1 = i_on + trial_frames - 1;
    if i0 < 1 || i1 > nFrames; continue; end
    [Phi_t, y_t]   = buildLagMatrix(y_full(i0:i1), X_full(i0:i1,:), pY, pX);
    pred_wc(j,:)   = Phi_t * beta;
    actual_wc(j,:) = y_t;
end

R2_nc = 1 - sum((actual_nc(:)-pred_nc(:)).^2,'omitnan') / ...
             sum((actual_nc(:)-mean(actual_nc(:),'omitnan')).^2,'omitnan');
R2_wc = 1 - sum((actual_wc(:)-pred_wc(:)).^2,'omitnan') / ...
             sum((actual_wc(:)-mean(actual_wc(:),'omitnan')).^2,'omitnan');
fprintf('  R^2_OL=%.3f   R^2_CL=%.3f\n', R2_nc, R2_wc);

% â”€â”€ Figure: 4-panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
t_trial = (0:outlen-1) / Fs_wb;
colOL   = [1 0 0];
colCL   = [0 0.5 0];
colPrd  = [0.2 0.2 0.8];

fig_wb = paperFig(12, 8);
lm_wb  = 0.10; rm_wb = 0.05; bm_wb = 0.12; tm_wb = 0.08;
gx     = 0.08; gy    = 0.15;
pw_wb  = (1 - lm_wb - rm_wb - gx) / 2;
ph_wb  = (1 - bm_wb - tm_wb - gy) / 2;

% Panel A -- Spontaneous: actual vs predicted (sample window)
ax_A = axes(fig_wb, 'Position', [lm_wb,           bm_wb+ph_wb+gy, pw_wb, ph_wb]);
n_show = min(3*Fs_wb, length(y_s));
t_show = (0:n_show-1) / Fs_wb;
hold(ax_A,'on');
plot(ax_A, t_show, y_s(1:n_show),     'Color',[0 0 0],  'LineWidth',1,   'DisplayName','Actual');
plot(ax_A, t_show, y_hat_s(1:n_show), 'Color', colPrd,  'LineWidth',1,   'DisplayName','Predicted');
hold(ax_A,'off');
legend(ax_A,'Box','off','FontSize',6,'Location','best');
title(ax_A, sprintf('Spontaneous  R^2=%.2f', R2_spont), 'FontSize',6,'FontWeight','bold');

% Panel B -- OL: mean actual vs mean predicted
ax_B = axes(fig_wb, 'Position', [lm_wb+pw_wb+gx,  bm_wb+ph_wb+gy, pw_wb, ph_wb]);
hold(ax_B,'on');
plot(ax_B, t_trial, mean(actual_nc,1,'omitnan'), 'Color',colOL,  'LineWidth',1.5, 'DisplayName','OL actual');
plot(ax_B, t_trial, mean(pred_nc,  1,'omitnan'), 'Color',colPrd, 'LineWidth',1,   'DisplayName','Predicted','LineStyle','--');
addStimPatch(ax_B, 0, dur_wb);
hold(ax_B,'off');
legend(ax_B,'Box','off','FontSize',6,'Location','best');
title(ax_B, sprintf('Open-Loop  R^2=%.2f', R2_nc), 'FontSize',6,'FontWeight','bold');

% Panel C -- CL: mean actual vs mean predicted
ax_C = axes(fig_wb, 'Position', [lm_wb,           bm_wb, pw_wb, ph_wb]);
hold(ax_C,'on');
plot(ax_C, t_trial, mean(actual_wc,1,'omitnan'), 'Color',colCL,  'LineWidth',1.5, 'DisplayName','CL actual');
plot(ax_C, t_trial, mean(pred_wc,  1,'omitnan'), 'Color',colPrd, 'LineWidth',1,   'DisplayName','Predicted','LineStyle','--');
addStimPatch(ax_C, 0, dur_wb);
hold(ax_C,'off');
legend(ax_C,'Box','off','FontSize',6,'Location','best');
title(ax_C, sprintf('Closed-Loop  R^2=%.2f', R2_wc), 'FontSize',6,'FontWeight','bold');

% Panel D -- Residual OL vs CL (actual -' predicted)
ax_D = axes(fig_wb, 'Position', [lm_wb+pw_wb+gx,  bm_wb, pw_wb, ph_wb]);
hold(ax_D,'on');
plot(ax_D, t_trial, mean(actual_nc-pred_nc,1,'omitnan'), 'Color',colOL, 'LineWidth',1.5, 'DisplayName','OL residual');
plot(ax_D, t_trial, mean(actual_wc-pred_wc,1,'omitnan'), 'Color',colCL, 'LineWidth',1.5, 'DisplayName','CL residual');
yline(ax_D, 0, 'k--', 'HandleVisibility','off');
addStimPatch(ax_D, 0, dur_wb);
hold(ax_D,'off');
legend(ax_D,'Box','off','FontSize',6,'Location','best');
title(ax_D, 'Residual: actual - predicted', 'FontSize',6,'FontWeight','bold');

for axi = [ax_A ax_B ax_C ax_D]
    set(axi, 'FontSize',6,'FontWeight','bold','Box','off','TickDir','out');
    ylabel(axi, 'dF/F (%)', 'FontSize',6,'FontWeight','bold');
    xlabel(axi, 'Time (s)', 'FontSize',6,'FontWeight','bold');
end




% =============================================================================
%  WIDEBRAIN PREDICTION — COMPLETION PLAN (Nick decisions: Apr-27 + May-11)
%  Prereqs: widebrain ARX sections above must have been run first.
%  Variables expected in workspace:
%    pred_nc, pred_wc       — pink predictions [nTrial × outlen]
%    actual_nc, actual_wc   — actual OL/CL dF/F [nTrial × outlen]
%    beta, Phi_s            — ARX weights + design matrix (from spontaneous fit)
%    d_wb, data_wb          — session struct for wb_sel
%    y_full, X_full         — full timeseries and contralateral predictor matrix
%    R2_spont, R2_nc, R2_wc — fit quality from pink layer
%    t_trial, Fs_wb, dur_wb, mlag_wb, outlen
%    colOL, colCL, colPrd
% =============================================================================

%% [WB-1] Pink layer — consolidate, add motion co-predictor, verify R²_spont, export
% Nick Apr-27: "fit on non-control data, apply to control, characterise residuals"
%
% Steps:
%   1. Set redefine_roi = false once ROI files are confirmed (midline.mat, contra_pixels.mat).
%   2. Rebuild X_full with motion energy as an additional predictor column:
%        mot_wb   = d_wb.motion(:);                     % z-scored motion timeseries
%        X_full_m = [X_full, mot_wb(1:size(X_full,1))]; % append column
%      Then refit beta using X_full_m instead of X_full.
%   3. Re-run buildLagMatrix + ARX fit on spontaneous windows with new X_full_m.
%   4. Assert R2_spont > 0.3 — if not, check pixel selection or increase nPred.
%        if R2_spont < 0.3
%            warning('R2_spont = %.3f -- below threshold, check predictor pixels', R2_spont);
%        end
%   5. Re-apply to OL/CL trials to get updated pred_nc, pred_wc.
%   6. Export the 4-panel figure (currently missing exportgraphics call):
%        exportgraphics(fig_wb, 'paper/images/figure4/wb_arx_4panel.pdf', 'ContentType','vector');

%% [WB-2] Orange layer — mean OL residual added to pink
% Intuition: pink removes spontaneous contralateral drive.
% What remains in OL trials is the average stimulus-evoked response.
% Orange = pink + that average residual, applied to both OL and CL.
%
% Implementation:
%   ol_resid_mean = mean(actual_nc - pred_nc, 1, 'omitnan');   % [1 × outlen]
%
%   pred_nc_orange = pred_nc + ol_resid_mean;                  % broadcast [nNc × outlen]
%   pred_wc_orange = pred_wc + ol_resid_mean;                  % same mean impulse for CL
%
%   R2_nc_orange = 1 - sum((actual_nc(:) - pred_nc_orange(:)).^2,'omitnan') / ...
%                      sum((actual_nc(:) - mean(actual_nc(:),'omitnan')).^2,'omitnan');
%   R2_wc_orange = 1 - sum((actual_wc(:) - pred_wc_orange(:)).^2,'omitnan') / ...
%                      sum((actual_wc(:) - mean(actual_wc(:),'omitnan')).^2,'omitnan');
%   fprintf('Orange:  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_orange, R2_wc_orange);
%
% Expected: R2_nc_orange >> R2_nc (orange much better for OL — it was built from OL residual).
%           R2_wc_orange < R2_nc_orange (CL suppresses the mean impulse, so orange overshoots).
%
% Figure (2 panels, paperFig(12, 4)):
%   Left:  t_trial vs mean OL actual (red), mean pink pred (blue--), mean orange pred (orange)
%   Right: t_trial vs mean CL actual (green), mean pink pred (blue--), mean orange pred (orange)
%   addStimPatch for each panel.

%% [WB-3] Red layer — per-trial TF response to actual laser
% Nick May-11: "add exact per-trial laser sequence via TF model; check match to CL traces"
%
% Requires: a 2p1z TF fit for the wb_sel session specifically.
% (best_ol in workspace is the last session of ol_sess_idx = [4 9 11] — may not match wb_sel.)
%
% Step A — Fit TF for wb_sel session:
%   ncDfk_wb    = data_wb.ncDfk;                        % [nNc × W_dfk]
%   ncInp_wb    = data_wb.ncInp;                        % [nNc × W_inp]
%   iOn_wb      = 36;                                   % c0_g2 — onset column in ncDfk
%   y_mean_wb   = mean(ncDfk_wb(:, iOn_wb : iOn_wb + dur_wb*Fs_wb - 1), 1)';
%   u_mean_wb   = downsample(mean(ncInp_wb, 1)', round(2000/Fs_wb));
%   u_mean_wb   = u_mean_wb(1:dur_wb*Fs_wb);
%   nPre_wb     = 5;
%   data_id_wb  = iddata([zeros(nPre_wb,1); y_mean_wb], [zeros(nPre_wb,1); u_mean_wb], 1/Fs_wb);
%   best_wb     = tfest(data_id_wb, 2, 1, tfestOptions('EnforceStability',false,'Display','off'));
%   fprintf('wb TF poles: '); disp(pole(best_wb)');
%
% Step B — Per-trial laser response for OL:
%   laser_resp_nc = zeros(size(pred_nc));
%   for j = 1:size(pred_nc, 1)
%       u_j = downsample(data_wb.ncInp(j,:)', round(2000/Fs_wb));
%       u_j = u_j(1:outlen);
%       laser_resp_nc(j,:) = lsim(best_wb, u_j, t_trial)';
%   end
%
% Step C — Per-trial laser response for CL:
%   laser_resp_wc = zeros(size(pred_wc));
%   for j = 1:size(pred_wc, 1)
%       u_j = downsample(data_wb.wcInp(j,:)', round(2000/Fs_wb));
%       u_j = u_j(1:outlen);
%       laser_resp_wc(j,:) = lsim(best_wb, u_j, t_trial)';
%   end
%
% Step D — Combine:
%   pred_nc_red = pred_nc + laser_resp_nc;
%   pred_wc_red = pred_wc + laser_resp_wc;
%
%   R2_nc_red = 1 - sum((actual_nc(:)-pred_nc_red(:)).^2,'omitnan') / ...
%                   sum((actual_nc(:)-mean(actual_nc(:),'omitnan')).^2,'omitnan');
%   R2_wc_red = 1 - sum((actual_wc(:)-pred_wc_red(:)).^2,'omitnan') / ...
%                   sum((actual_wc(:)-mean(actual_wc(:),'omitnan')).^2,'omitnan');
%   fprintf('Red:  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_red, R2_wc_red);
%
% Key check: R2_wc_red > R2_wc_orange (per-trial laser improves CL prediction vs mean impulse).
%            If not, TF model for wb_sel session needs refitting or session is wrong.

%% [WB-4] Three-layer overlay figure — paper panel
% Nick May-11: single figure showing pink / orange / red vs actual for OL and CL.
%
% Layout: paperFig(12, 4), two panels side by side.
%   Left panel — OL actual vs three predictions:
%     plot mean(actual_nc)          colOL,  lw=1.5, 'OL actual'
%     plot mean(pred_nc)            pink,   lw=1.0, '--', 'Pink (contra)'
%     plot mean(pred_nc_orange)     orange, lw=1.0, '--', 'Orange (+mean stim)'
%     plot mean(pred_nc_red)        red,    lw=1.0, '--', 'Red (+laser TF)'
%     addStimPatch; shaded ±SEM on actual trace only
%
%   Right panel — CL actual vs pink and red:
%     plot mean(actual_wc)          colCL,  lw=1.5, 'CL actual'
%     plot mean(pred_wc)            pink,   lw=1.0, '--', 'Pink (contra)'
%     plot mean(pred_wc_red)        red,    lw=1.0, '--', 'Red (+laser TF)'
%     (orange omitted — built from OL residual, not meaningful for CL comparison)
%     addStimPatch; shaded ±SEM on actual trace only
%
% Colour assignments:
%   colPink   = [0.85 0.6  0.7];
%   colOrange = [0.9  0.55 0.1];
%   colRed    = [0.8  0.1  0.1];
%
% Export:
%   exportgraphics(fig_wb_layers, 'paper/images/figure4/wb_three_layers.pdf', 'ContentType','vector');

%% [WB-5] Post-hoc optimal laser — MPC motivation
% Nick May-11: "compute post-hoc optimal laser sequence for representative trials;
%               quantify gap vs actual controller; frame as MPC motivation."
%
% Formulation (unconstrained least-squares per trial):
%   Given: y_pink_j(t) — pink prediction for trial j [outlen × 1]
%          H — Toeplitz matrix of TF impulse response (lower-triangular) [outlen × outlen]
%          ref = d_wb.ref
%   Find:  u*(t) = argmin ||y_pink_j + H*u - ref||²
%   Solution: u* = H \ (ref*ones(outlen,1) - y_pink_j)   (pseudoinverse, unconstrained)
%
% Build H (impulse response matrix):
%   h = impulseest(best_wb, outlen);   % or: h = impulse(best_wb, t_trial);
%   H = toeplitz(h, [h(1); zeros(outlen-1,1)]);
%
% Per OL trial:
%   u_opt_nc = zeros(size(pred_nc));
%   for j = 1:size(pred_nc,1)
%       u_opt_nc(j,:) = (H \ (ref*ones(outlen,1) - pred_nc(j,:)'))';
%   end
%   y_opt_nc = pred_nc + (H * u_opt_nc')';   % predicted outcome with optimal laser
%
% Metrics to report:
%   mse_actual_cl  = mean(data_wb.er_wcDfk);          % actual CL MSE
%   mse_opt        = mean(vecnorm(y_opt_nc - ref, 2, 2));  % optimal MSE (OL trials, optimal laser)
%   gap_ratio      = mse_actual_cl / mse_opt;          % >1 = controller suboptimal
%   fprintf('MPC gap: actual CL MSE / optimal = %.2f\n', gap_ratio);
%
% Figure: scatter per-trial MSE_optimal vs MSE_actual_CL (one point per trial)
%         diagonal line = parity; points above = controller underperforms optimal
%   paperFig(6,4); export to paper/images/figure4/wb_mpc_gap.pdf
%
% Note: u* will be unconstrained (can be negative / large) — add box constraints
%       [0, max_laser_power] for a realistic bound before reporting the gap.
% =============================================================================

