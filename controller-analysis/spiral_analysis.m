% spiral_analysis.m  --  Spiral wave detection + trial performance grading
% Detects spiral waves in widefield SVD data (via spirals repo) and correlates
% per-trial spiral density with trial MSE, pre-stim state, and OL vs CL outcome.
%
% Mirrors the structure of motion_analysis.m:
%   SPD-1  Pre-trial spiral density vs trial MSE (pre-stim brain state → outcome)
%   SPD-2  Trial-window spiral density vs MSE (bins, OL/CL)
%   SPD-3  Peri-trial spiral density time course (PETH, OL vs CL)
%   SPD-4  CW / CCW direction ratio OL vs CL
%   SPD-5  Spatial density map OL vs CL (brain overlay)
%
% Run from brain_paper/ root.
% Prereqs: load_sessions.m has been run (mouse, fields).
%          utils/detectSpirals.m and spirals repo must be on path.
clc;
close all;

PS = paperStyle();
setPaperDefaults();

colOL  = PS.col_ol;
colCL  = PS.col_cl;

% Path to spirals repo (detectSpirals.m addpaths this, but set here for clarity)
spirals_repo = 'C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals\spirals';
if ~exist(fullfile(spirals_repo, 'utils', 'spirals_detection', 'setSpiralDetectionParams.m'), 'file')
    error('Spirals repo not found at %s — update spirals_repo path.', spirals_repo);
end
addpath(genpath(spirals_repo));

% Detection parameters
dur_sp     = 3;       % trial duration (s) — must match dur in other scripts
window_sp  = 1;       % seconds before/after trial onset/offset to include in detection
Fs_sp      = 35;

%% Per-session spiral detection (cached)
% Runs detectSpirals for every session that has SVD data.
% Results saved to data/<session>_spirals.mat and reloaded on re-run.
% Set redetect = true to force re-detection (e.g. after changing window_sp).

redetect = false;

spd_nc = struct();   % OL density per trial, per session
spd_wc = struct();   % CL density per trial, per session

for k = 1:length(fields)
    fn = fields{k};
    if isfield(mouse.(fn), 'skip') && mouse.(fn).skip; continue; end
    if ~isfield(mouse.(fn).d, 'svd')
        fprintf('[SPD] Skipping %s -- no SVD.\n', fn); continue;
    end

    d_sp    = mouse.(fn).d;
    data_sp = mouse.(fn).data;
    mn_sp   = mouse.(fn).mn;
    td_sp   = mouse.(fn).td;
    en_sp   = mouse.(fn).en;

    cache_path = fullfile('data', sprintf('%sspirals%s%s%d.mat', ...
        mn_sp, td_sp(6:7), td_sp(9:10), en_sp));

    if exist(cache_path, 'file') && ~redetect
        tmp = load(cache_path);
        spirals_k = tmp.spirals_k;
        fprintf('[SPD] Loaded spiral cache: %s\n', fn);
    else
        fprintf('[SPD] Detecting spirals: %s ...\n', fn);
        U_sp = d_sp.svd.U;
        V_sp = d_sp.svd.V;
        t_sp = d_sp.timeBlue(:)';

        % Combine all trial onsets (OL + CL) for a single detection pass
        all_tr_sp   = [data_sp.nc(:); data_sp.wc(:)];
        allStarts   = d_sp.stimStarts(all_tr_sp);
        allEnds     = allStarts + dur_sp;

        server_root = fullfile('data', sprintf('%s_%s_%d', mn_sp, td_sp, en_sp));
        if ~exist(server_root, 'dir'); mkdir(server_root); end
        spirals_k   = detectSpirals(U_sp, V_sp, t_sp, allStarts, allEnds, window_sp, server_root);

        % Tag each detected spiral with its condition (OL or CL)
        % detectSpirals .trial column indexes into all_tr_sp (1..nTr_total)
        nNc_sp = numel(data_sp.nc);
        if ~isempty(spirals_k)
            spirals_k.is_ol = spirals_k.trial <= nNc_sp;
            % Remap trial → session-level trial index within nc/wc
            spirals_k.trial_nc = nan(height(spirals_k), 1);
            spirals_k.trial_wc = nan(height(spirals_k), 1);
            ol_rows = spirals_k.trial <= nNc_sp;
            cl_rows = spirals_k.trial >  nNc_sp;
            spirals_k.trial_nc(ol_rows) = spirals_k.trial(ol_rows);
            spirals_k.trial_wc(cl_rows) = spirals_k.trial(cl_rows) - nNc_sp;
        end

        save(cache_path, 'spirals_k');
        fprintf('[SPD] Saved: %s\n', cache_path);
    end

    % Per-trial spiral density (spirals per second in the trial window)
    nNc_k = numel(data_sp.nc);
    nWc_k = numel(data_sp.wc);

    dens_nc_k = zeros(nNc_k, 1);
    dens_wc_k = zeros(nWc_k, 1);

    if ~isempty(spirals_k)
        for j = 1:nNc_k
            mask = spirals_k.is_ol & spirals_k.trial_nc == j & ...
                   spirals_k.t_rel >= 0 & spirals_k.t_rel <= dur_sp;
            dens_nc_k(j) = sum(mask) / dur_sp;
        end
        for j = 1:nWc_k
            mask = ~spirals_k.is_ol & spirals_k.trial_wc == j & ...
                   spirals_k.t_rel >= 0 & spirals_k.t_rel <= dur_sp;
            dens_wc_k(j) = sum(mask) / dur_sp;
        end
    end

    % Pre-trial spiral density (window_sp seconds before onset)
    pre_dens_nc_k = zeros(nNc_k, 1);
    pre_dens_wc_k = zeros(nWc_k, 1);
    if ~isempty(spirals_k)
        for j = 1:nNc_k
            mask = spirals_k.is_ol & spirals_k.trial_nc == j & ...
                   spirals_k.t_rel >= -window_sp & spirals_k.t_rel < 0;
            pre_dens_nc_k(j) = sum(mask) / window_sp;
        end
        for j = 1:nWc_k
            mask = ~spirals_k.is_ol & spirals_k.trial_wc == j & ...
                   spirals_k.t_rel >= -window_sp & spirals_k.t_rel < 0;
            pre_dens_wc_k(j) = sum(mask) / window_sp;
        end
    end

    spd_nc.(fn).dens     = dens_nc_k;
    spd_nc.(fn).pre_dens = pre_dens_nc_k;
    spd_nc.(fn).mse      = data_sp.er_ncDfk;
    spd_wc.(fn).dens     = dens_wc_k;
    spd_wc.(fn).pre_dens = pre_dens_wc_k;
    spd_wc.(fn).mse      = data_sp.er_wcDfk;
    spd_nc.(fn).spirals  = spirals_k;

    fprintf('[SPD] %s -- OL %.2f sp/s  CL %.2f sp/s\n', fn, ...
        mean(dens_nc_k), mean(dens_wc_k));
end

% Pool across sessions
nc_dens_c = {}; nc_pre_c = {}; nc_mse_c = {};
wc_dens_c = {}; wc_pre_c = {}; wc_mse_c = {};

for k = 1:length(fields)
    fn = fields{k};
    if ~isfield(spd_nc, fn); continue; end
    nc_dens_c{end+1} = spd_nc.(fn).dens;
    nc_pre_c{end+1}  = spd_nc.(fn).pre_dens;
    nc_mse_c{end+1}  = spd_nc.(fn).mse(:);
    wc_dens_c{end+1} = spd_wc.(fn).dens;
    wc_pre_c{end+1}  = spd_wc.(fn).pre_dens;
    wc_mse_c{end+1}  = spd_wc.(fn).mse(:);
end

all_nc_dens = vertcat(nc_dens_c{:});
all_nc_pre  = vertcat(nc_pre_c{:});
all_nc_mse  = vertcat(nc_mse_c{:});
all_wc_dens = vertcat(wc_dens_c{:});
all_wc_pre  = vertcat(wc_pre_c{:});
all_wc_mse  = vertcat(wc_mse_c{:});

fprintf('[SPD] Pooled -- OL %d trials  CL %d trials\n', numel(all_nc_dens), numel(all_wc_dens));

%% [SPD-1] Pre-trial spiral density vs trial MSE
% Does the brain state (spiral activity) before the stimulus predict trial outcome?
% Analogous to pre-stim deviation analysis in motion_analysis.m.
% OL: expect positive slope (more pre-stim spirals -> harder starting state -> higher MSE).
% CL: slope should be attenuated if feedback compensates regardless of starting state.

nBins_sp  = 4;
edges_pre = quantile([all_nc_pre; all_wc_pre], linspace(0,1,nBins_sp+1));
edges_pre(end) = edges_pre(end) + eps;   % include max

bin_nc_pre = discretize(all_nc_pre, edges_pre);
bin_nc_pre(isnan(bin_nc_pre)) = nBins_sp;
bin_wc_pre = discretize(all_wc_pre, edges_pre);
bin_wc_pre(isnan(bin_wc_pre)) = nBins_sp;

nc_pre_m = nan(nBins_sp,1); nc_pre_se = nan(nBins_sp,1);
wc_pre_m = nan(nBins_sp,1); wc_pre_se = nan(nBins_sp,1);
for b = 1:nBins_sp
    v = all_nc_mse(bin_nc_pre==b); nc_pre_m(b)=mean(v); nc_pre_se(b)=std(v)/sqrt(numel(v));
    v = all_wc_mse(bin_wc_pre==b); wc_pre_m(b)=mean(v); wc_pre_se(b)=std(v)/sqrt(numel(v));
end

% Regression line for slope test (OL vs CL)
xc_pre  = (1:nBins_sp)';
p_nc_pre = polyfit(xc_pre, nc_pre_m, 1);
p_wc_pre = polyfit(xc_pre, wc_pre_m, 1);

fig_sp1 = paperFig(8, 5);
lm1=0.14; rm1=0.04; bm1=0.22; tm1=0.12;
ax_sp1 = axes(fig_sp1,'Position',[lm1, bm1, 1-lm1-rm1, 1-bm1-tm1]);
hold(ax_sp1,'on');
errorbar(ax_sp1, xc_pre-0.1, nc_pre_m, nc_pre_se, 'o-', 'Color',colOL, ...
    'LineWidth',PS.lw_mean, 'MarkerSize',4, 'MarkerFaceColor',colOL, 'CapSize',4, ...
    'DisplayName','OL');
errorbar(ax_sp1, xc_pre+0.1, wc_pre_m, wc_pre_se, 'o-', 'Color',colCL, ...
    'LineWidth',PS.lw_mean, 'MarkerSize',4, 'MarkerFaceColor',colCL, 'CapSize',4, ...
    'DisplayName','CL');
plot(ax_sp1, xc_pre, polyval(p_nc_pre, xc_pre), '--', 'Color',colOL, 'LineWidth',0.8, 'HandleVisibility','off');
plot(ax_sp1, xc_pre, polyval(p_wc_pre, xc_pre), '--', 'Color',colCL, 'LineWidth',0.8, 'HandleVisibility','off');
hold(ax_sp1,'off');
set(ax_sp1, 'XTick', 1:nBins_sp, 'XTickLabel', {'Q1','Q2','Q3','Q4'});
xlabel(ax_sp1, 'Pre-trial spiral density (quartile)', 'FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax_sp1, 'Trial MSE (\DeltaF/F)^2',            'FontSize',PS.fs,'FontWeight',PS.fw);
title(ax_sp1, sprintf('Pre-trial spirals → MSE  (OL slope=%.3f  CL slope=%.3f)', ...
    p_nc_pre(1), p_wc_pre(1)), 'FontSize',PS.fs,'FontWeight',PS.fw);
lg_sp1 = legend(ax_sp1,'Location','northwest','Box','off','FontSize',PS.fs);
try; lg_sp1.ItemTokenSize=[6 6]; catch; end
paperExport(fig_sp1, 'paper/images/figure4/spd_pretrial_vs_mse.png');
fprintf('[SPD-1] OL slope=%.4f  CL slope=%.4f\n', p_nc_pre(1), p_wc_pre(1));

%% [SPD-2] Trial-window spiral density vs MSE (OL/CL quartile bins)
% Does spiral density DURING the trial correlate with MSE?
% OL: stimulus drives activity -> more spirals during larger responses.
% CL: if feedback suppresses spirals, CL trials should show lower density
%     especially in high-MSE bins (controller partially failing -> spirals persist).

edges_tr = quantile([all_nc_dens; all_wc_dens], linspace(0,1,nBins_sp+1));
edges_tr(end) = edges_tr(end) + eps;

bin_nc_tr = discretize(all_nc_dens, edges_tr);
bin_nc_tr(isnan(bin_nc_tr)) = nBins_sp;
bin_wc_tr = discretize(all_wc_dens, edges_tr);
bin_wc_tr(isnan(bin_wc_tr)) = nBins_sp;

nc_tr_m = nan(nBins_sp,1); nc_tr_se = nan(nBins_sp,1);
wc_tr_m = nan(nBins_sp,1); wc_tr_se = nan(nBins_sp,1);
for b = 1:nBins_sp
    v = all_nc_mse(bin_nc_tr==b); nc_tr_m(b)=mean(v); nc_tr_se(b)=std(v)/sqrt(numel(v));
    v = all_wc_mse(bin_wc_tr==b); wc_tr_m(b)=mean(v); wc_tr_se(b)=std(v)/sqrt(numel(v));
end

p_nc_tr = polyfit(xc_pre, nc_tr_m, 1);
p_wc_tr = polyfit(xc_pre, wc_tr_m, 1);

fig_sp2 = paperFig(8, 5);
ax_sp2 = axes(fig_sp2,'Position',[lm1, bm1, 1-lm1-rm1, 1-bm1-tm1]);
hold(ax_sp2,'on');
errorbar(ax_sp2, xc_pre-0.1, nc_tr_m, nc_tr_se, 'o-', 'Color',colOL, ...
    'LineWidth',PS.lw_mean, 'MarkerSize',4, 'MarkerFaceColor',colOL, 'CapSize',4, 'DisplayName','OL');
errorbar(ax_sp2, xc_pre+0.1, wc_tr_m, wc_tr_se, 'o-', 'Color',colCL, ...
    'LineWidth',PS.lw_mean, 'MarkerSize',4, 'MarkerFaceColor',colCL, 'CapSize',4, 'DisplayName','CL');
plot(ax_sp2, xc_pre, polyval(p_nc_tr, xc_pre), '--','Color',colOL,'LineWidth',0.8,'HandleVisibility','off');
plot(ax_sp2, xc_pre, polyval(p_wc_tr, xc_pre), '--','Color',colCL,'LineWidth',0.8,'HandleVisibility','off');
hold(ax_sp2,'off');
set(ax_sp2,'XTick',1:nBins_sp,'XTickLabel',{'Q1','Q2','Q3','Q4'});
xlabel(ax_sp2,'Trial spiral density (quartile)',    'FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax_sp2,'Trial MSE (\DeltaF/F)^2',           'FontSize',PS.fs,'FontWeight',PS.fw);
title(ax_sp2, sprintf('Trial spirals → MSE  (OL slope=%.3f  CL slope=%.3f)', ...
    p_nc_tr(1), p_wc_tr(1)), 'FontSize',PS.fs,'FontWeight',PS.fw);
lg_sp2 = legend(ax_sp2,'Location','northwest','Box','off','FontSize',PS.fs);
try; lg_sp2.ItemTokenSize=[6 6]; catch; end
paperExport(fig_sp2,'paper/images/figure4/spd_trial_vs_mse.png');
fprintf('[SPD-2] OL slope=%.4f  CL slope=%.4f\n', p_nc_tr(1), p_wc_tr(1));

%% [SPD-3] OL vs CL overall spiral density comparison (bar + scatter)
% Direct test: does the closed-loop controller reduce spiral density?
% One data point per session: mean density during trial window.

fn_valid = fieldnames(spd_nc);
sess_nc_dens = cellfun(@(f) mean(spd_nc.(f).dens, 'omitnan'), fn_valid);
sess_wc_dens = cellfun(@(f) mean(spd_wc.(f).dens, 'omitnan'), fn_valid);

[~, p_paired] = ttest(sess_nc_dens(:), sess_wc_dens(:));
fprintf('[SPD-3] OL=%.3f  CL=%.3f sp/s  paired t-test p=%.4f\n', ...
    mean(sess_nc_dens), mean(sess_wc_dens), p_paired);

fig_sp3 = paperFig(7, 5);
lm3=0.18; bm3=0.22;
ax_sp3 = axes(fig_sp3,'Position',[lm3, bm3, 1-lm3-0.05, 1-bm3-0.12]);
hold(ax_sp3,'on');
nSess_sp = numel(sess_nc_dens);
for s = 1:nSess_sp
    plot(ax_sp3, [1 2], [sess_nc_dens(s) sess_wc_dens(s)], 'o-', ...
        'Color',[0.6 0.6 0.6],'LineWidth',0.6,'MarkerSize',3,'HandleVisibility','off');
end
errorbar(ax_sp3, 1, mean(sess_nc_dens), std(sess_nc_dens)/sqrt(nSess_sp), 'o', ...
    'Color',colOL,'LineWidth',PS.lw_mean,'MarkerSize',5,'MarkerFaceColor',colOL,...
    'CapSize',4,'DisplayName','OL');
errorbar(ax_sp3, 2, mean(sess_wc_dens), std(sess_wc_dens)/sqrt(nSess_sp), 'o', ...
    'Color',colCL,'LineWidth',PS.lw_mean,'MarkerSize',5,'MarkerFaceColor',colCL,...
    'CapSize',4,'DisplayName','CL');
if p_paired < 0.05
    ymax_sp3 = max([sess_nc_dens, sess_wc_dens]) * 1.1;
    plot(ax_sp3,[1 2],[ymax_sp3 ymax_sp3],'k-','LineWidth',0.8,'HandleVisibility','off');
    text(ax_sp3, 1.5, ymax_sp3*1.03, sprintf('p=%.3f',p_paired), ...
        'HorizontalAlignment','center','FontSize',PS.fs,'FontWeight',PS.fw);
end
hold(ax_sp3,'off');
set(ax_sp3,'XTick',[1 2],'XTickLabel',{'OL','CL'},'XLim',[0.5 2.5]);
ylabel(ax_sp3,'Spiral density (sp/s)','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax_sp3,'Trial-window spiral density','FontSize',PS.fs,'FontWeight',PS.fw);
paperExport(fig_sp3,'paper/images/figure4/spd_ol_vs_cl.png');

%% [SPD-4] Peri-trial spiral density PETH (OL vs CL)
% Time course of spiral rate relative to trial onset, averaged across sessions.
% Reveals whether spirals are suppressed during the CL trial window or only
% after opto onset, and how quickly the pre-stim level recovers.

bin_width = 0.5;   % seconds per PETH bin
t_peth    = -(window_sp) : bin_width : (dur_sp + window_sp);
nBins_peth = numel(t_peth) - 1;
t_centers  = t_peth(1:end-1) + bin_width/2;

peth_nc_all = nan(nSess_sp, nBins_peth);
peth_wc_all = nan(nSess_sp, nBins_peth);
sess_count  = 0;

for k = 1:length(fields)
    fn = fields{k};
    if ~isfield(spd_nc, fn); continue; end
    spk = spd_nc.(fn).spirals;
    if isempty(spk) || ~istable(spk); continue; end
    sess_count = sess_count + 1;

    % OL trials
    ol_rows = spk.is_ol;
    t_ol    = spk.t_rel(ol_rows);
    nNc_k   = numel(spd_nc.(fn).dens);
    for b = 1:nBins_peth
        peth_nc_all(sess_count, b) = sum(t_ol >= t_peth(b) & t_ol < t_peth(b+1)) / ...
            (nNc_k * bin_width);
    end

    % CL trials
    cl_rows = ~spk.is_ol;
    t_cl    = spk.t_rel(cl_rows);
    nWc_k   = numel(spd_wc.(fn).dens);
    for b = 1:nBins_peth
        peth_wc_all(sess_count, b) = sum(t_cl >= t_peth(b) & t_cl < t_peth(b+1)) / ...
            (nWc_k * bin_width);
    end
end
peth_nc_all = peth_nc_all(1:sess_count, :);
peth_wc_all = peth_wc_all(1:sess_count, :);

peth_nc_m  = mean(peth_nc_all, 1, 'omitnan');
peth_nc_se = std(peth_nc_all,  0, 1, 'omitnan') / sqrt(sess_count);
peth_wc_m  = mean(peth_wc_all, 1, 'omitnan');
peth_wc_se = std(peth_wc_all,  0, 1, 'omitnan') / sqrt(sess_count);

fig_sp4 = paperFig(10, 5);
lm4=0.12; rm4=0.04; bm4=0.20; tm4=0.12;
ax_sp4 = axes(fig_sp4,'Position',[lm4, bm4, 1-lm4-rm4, 1-bm4-tm4]);
hold(ax_sp4,'on');
patch(ax_sp4,[t_centers,fliplr(t_centers)], ...
    [peth_nc_m+peth_nc_se, fliplr(peth_nc_m-peth_nc_se)], ...
    colOL,'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
patch(ax_sp4,[t_centers,fliplr(t_centers)], ...
    [peth_wc_m+peth_wc_se, fliplr(peth_wc_m-peth_wc_se)], ...
    colCL,'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
plot(ax_sp4, t_centers, peth_nc_m, 'Color',colOL,'LineWidth',PS.lw_mean,'DisplayName','OL');
plot(ax_sp4, t_centers, peth_wc_m, 'Color',colCL,'LineWidth',PS.lw_mean,'DisplayName','CL');
xline(ax_sp4, 0,      'k--','LineWidth',PS.lw_ref,'HandleVisibility','off');
xline(ax_sp4, dur_sp, 'k:','LineWidth',0.6,'HandleVisibility','off');
hold(ax_sp4,'off');
xlabel(ax_sp4,'Time relative to stim onset (s)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax_sp4,'Spiral density (sp/s)',           'FontSize',PS.fs,'FontWeight',PS.fw);
title(ax_sp4,'Peri-trial spiral density (PETH)',  'FontSize',PS.fs,'FontWeight',PS.fw);
lg_sp4 = legend(ax_sp4,'Location','best','Box','off','FontSize',PS.fs);
try; lg_sp4.ItemTokenSize=[6 6]; catch; end
paperExport(fig_sp4,'paper/images/figure4/spd_peth.png');

%% [SPD-5] CW / CCW direction ratio -- OL vs CL
% direction = +1 (CW) or -1 (CCW) in the spirals table.
% A change in the CW:CCW ratio between OL and CL would indicate the
% controller biases propagation direction, not just density.

cw_nc = 0; ccw_nc = 0; cw_wc = 0; ccw_wc = 0;
for k = 1:length(fields)
    fn = fields{k};
    if ~isfield(spd_nc, fn); continue; end
    spk = spd_nc.(fn).spirals;
    if isempty(spk) || ~istable(spk); continue; end
    ol_rows = spk.is_ol;
    cw_nc  = cw_nc  + sum( spk.direction(ol_rows) > 0);
    ccw_nc = ccw_nc + sum( spk.direction(ol_rows) < 0);
    cw_wc  = cw_wc  + sum(~spk.is_ol & spk.direction > 0);
    ccw_wc = ccw_wc + sum(~spk.is_ol & spk.direction < 0);
end
ratio_nc = cw_nc / max(ccw_nc, 1);
ratio_wc = cw_wc / max(ccw_wc, 1);
fprintf('[SPD-5] CW:CCW -- OL %.2f  CL %.2f\n', ratio_nc, ratio_wc);

fig_sp5 = paperFig(6, 5);
lm5=0.18; bm5=0.22;
ax_sp5 = axes(fig_sp5,'Position',[lm5, bm5, 1-lm5-0.06, 1-bm5-0.12]);
hold(ax_sp5,'on');
bar_data_sp5 = [cw_nc, ccw_nc; cw_wc, ccw_wc];
bar_data_sp5 = bar_data_sp5 ./ sum(bar_data_sp5, 2);   % normalise to fraction
b_sp5 = bar(ax_sp5, bar_data_sp5, 'stacked');
b_sp5(1).FaceColor = [0.3 0.6 1.0]; b_sp5(1).EdgeColor = 'none';  % CW blue
b_sp5(2).FaceColor = [1.0 0.5 0.2]; b_sp5(2).EdgeColor = 'none';  % CCW orange
hold(ax_sp5,'off');
set(ax_sp5,'XTick',[1 2],'XTickLabel',{'OL','CL'},'YLim',[0 1]);
ylabel(ax_sp5,'Fraction of spirals','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax_sp5,'CW (blue) vs CCW (orange) spirals','FontSize',PS.fs,'FontWeight',PS.fw);
paperExport(fig_sp5,'paper/images/figure4/spd_cw_ccw.png');

%% [SPD-6] MSE-sorted trial heatmap coloured by spiral density
% Sort OL and CL trials by MSE (ascending) and show spiral density as colour.
% Analogous to the spectral heatmap sorted by MSE in spectral_mse_sort.m.
% Reveals whether high-MSE trials cluster with high spiral density.

[~, ord_nc] = sort(all_nc_mse);
[~, ord_wc] = sort(all_wc_mse);

fig_sp6 = paperFig(12, 5);
lm6=0.08; rm6=0.10; bm6=0.18; tm6=0.12; gx6=0.08;
pw6 = (1-lm6-rm6-gx6)/2; ph6 = 1-bm6-tm6;

for iP = 1:2
    ax6 = axes(fig_sp6,'Position',[lm6+(iP-1)*(pw6+gx6), bm6, pw6, ph6]);
    if iP == 1
        dens_sorted = all_nc_dens(ord_nc);
        mse_sorted  = all_nc_mse(ord_nc);
        col6 = colOL; lbl6 = 'OL';
    else
        dens_sorted = all_wc_dens(ord_wc);
        mse_sorted  = all_wc_mse(ord_wc);
        col6 = colCL; lbl6 = 'CL';
    end
    nT6 = numel(mse_sorted);

    yyaxis(ax6, 'left');
    scatter(ax6, 1:nT6, mse_sorted, 4, dens_sorted, 'filled');
    colormap(ax6, parula);
    cb6 = colorbar(ax6);
    ylabel(cb6,'Spiral density (sp/s)','FontSize',PS.fs,'FontWeight',PS.fw);
    clim(ax6, [0 max([all_nc_dens; all_wc_dens]) + eps]);
    ylabel(ax6, 'Trial MSE (\DeltaF/F)^2','FontSize',PS.fs,'FontWeight',PS.fw);
    xlabel(ax6, 'Trial rank (by MSE)','FontSize',PS.fs,'FontWeight',PS.fw);
    title(ax6, lbl6,'FontSize',PS.fs,'FontWeight',PS.fw);
    set(ax6,'Box','off','TickDir','out','YColor',col6);
    yyaxis(ax6, 'right'); set(ax6,'YTick',[],'YColor','none');
end
paperExport(fig_sp6,'paper/images/figure4/spd_mse_sorted.png');
fprintf('[SPD-6] Saved spd_mse_sorted.png\n');

fprintf('\n[SPD] All figures saved to paper/images/figure4/\n');
