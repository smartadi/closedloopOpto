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
            mouse.(fields{k}).d    = tmp.d;
            mouse.(fields{k}).data = tmp.data;
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



%% analysisPlots_combined — single session
selField = 10;   % <-- change to target session index

analysisPlots_combined(mouse.(fields{selField}).data, mouse.(fields{selField}).d);

%%
Mean_var_wc = mean(Mvarwc);
Mean_var_nc = mean(Mvarnc);
tp = (-3*35 : 35*(dur+3)) / 35;   % -3s to dur+3s, guaranteed 35*(dur+6)+1 pts




%% F: Cross-session variance  (2.33" wide — matches 1/3 page column)
fig_F = figure('Color','w', 'Units','centimeters', 'Position',[0 0 3.5 3]);

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
% text(ax_var, -0.10, 0.95, 'F', 'Units','normalized', 'FontSize', 6, ...
%     'FontWeight','bold', 'Clipping','off');

exportgraphics(fig_F, 'paper/all_variance_sessions.pdf', 'ContentType','vector');

%% G: Cross-session MSE violin  (7.0" wide — fills full page width)
fig_G = figure('Color','w', 'Units','centimeters', 'Position',[0 0 9 4]);

lm_g = 0.13; rm_g = 0.05; bm_g = 0.12; tm_g = 0.08;
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
    plot(ax_mse, k - 0.1, mean(er_ncDfk), 'r*', 'LineWidth', 1.5);

    [fB, yB] = ksdensity(er_wcDfk);
    fB = fB / max(fB) * halfWidth;
    fill(ax_mse, [k + fB, k*ones(size(fB))], [yB, fliplr(yB)], ...
         colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');
    plot(ax_mse, k + 0.1, mean(er_wcDfk), 'g*', 'LineWidth', 1.5);
end
hold(ax_mse, 'off');

numExp = length(fields);
xlim(ax_mse, [0.5 numExp+0.5]);
cleanAxes(ax_mse);
text(ax_mse, -0.12, 0.5, 'Trial MSE', ...
    'Units','normalized', 'Rotation', 90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
text(ax_mse, 0.5, -0.05, 'Sessions', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', 'VerticalAlignment','top', ...
    'FontSize', 6, 'FontWeight','bold', 'Color','k', 'Clipping','off');
% text(ax_mse, 0.0, 0.95, 'G', 'Units','normalized', 'FontSize', 6, ...
%     'FontWeight','bold', 'Clipping','off');

exportgraphics(fig_G, 'paper/all_MSE_sessions.pdf', 'ContentType','image', 'Resolution',300, 'Padding','tight');




%% H: All-session trial average
fig_H = figure('Color','w', 'Units','centimeters', 'Position',[0 0 3 4]);

lm_h = 0.13; rm_h = 0.05; bm_h = 0.12; tm_h = 0.08;
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
    plot(ax_H, t1_h, abs(error_NC), 'Color', [colOL, 0.3], 'LineWidth', 0.05, 'HandleVisibility','off');
    plot(ax_H, t1_h, abs(error_WC), 'Color', [colCL, 0.3], 'LineWidth', 0.05, 'HandleVisibility','off');
end
plot(ax_H, t_h, mean(Error_nc), 'Color', colOL, 'LineWidth', 2);
plot(ax_H, t_h, mean(Error_wc), 'Color', colCL, 'LineWidth', 2);
addStimPatch(ax_H, 0, dur);
xlim(ax_H, [-0.5 dur+0.5]);
ylim(ax_H, [-1 6]);
hold(ax_H, 'off');

legend(ax_H, {'Open-Loop', 'Closed-Loop'}, ...
    'Location','northeast', 'Box','off', 'FontSize', 6, 'FontWeight','bold');
shortCornerAxes_plot(ax_H, 'XLength', 0.5, 'YLength', 1, ...
    'XLabel', '500 msec', 'YLabel', 'MSE dF/F', 'LineWidth', 2.5, 'LabelGap', 0.04);
cleanAxes(ax_H);
% text(ax_H, -0.10, 0.95, 'H', 'Units','normalized', 'FontSize', 6, ...
%     'FontWeight','bold', 'Clipping','off');
exportgraphics(fig_H, 'paper/all_average_sessions.pdf', 'ContentType','vector');





%% plot the open loop step response

close all;
fig = figure('Color','w', 'Units','centimeters', 'Position',[0 0 15 10]);
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

    % ---- Shaded mean ± std (hidden from legend)
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
     'LineWidth', 2, ...
     'Color', c, ...
     'HandleVisibility','off');
    % ---- Mean line (store handle for legend)
    hLegend(i) = plot(t, mu0, ...
                      'Color', c, ...
                      'LineWidth', 3);

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

xticks([])

% ---- Your legend style ----
lgd = legend(ax, hLegend, legTxt, ...
             'Box','off', ...
             'Color','none','FontSize', 6, 'FontWeight','bold');



lgd = legend(ax, hLegend, legTxt, 'Box','off','Color','none','Location','southeast');
lgd.ItemTokenSize = [14 6];
lgd.AutoUpdate = 'off';

% legend(ax2, [hA hD hC hB], {'Open-Loop', 'Closed-Loop','Stim', 'Ref'}, ...
%     'Location','northeast', ...
%     'Box','off', FontSize=12, FontWeight='bold')
% shortCornerAxes_plot(ax,'Frac',0.1,'XLabel','time(secs)','YLabel','dF/F  /  Variance','LineWidth',5,'LabelGap',0.05)

text(-0.1-3, 10, {'Variance', 'across trials'}, ...
    'Color','k', 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Rotation', 90, 'Clipping','off');


 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
      'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 5,'LabelGap',  0.04)

% shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Time','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)
exportgraphics(fig, 'paper/step_response.pdf', 'ContentType','image', 'Resolution',300);



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

% --- plot: mean ± SEM per field, connected by line ---
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
exportgraphics(fig, 'paper/spont_variance.pdf', 'ContentType','image', 'Resolution',300);



%% Motion vs MSE — three analysis modes

% onset_col is derived dynamically per session:
%   onset_col = size(ncmotion,2) - 35*dur
% This works regardless of which controllerData window is stored.
%
% Three modes (pre_secs=0 means start at onset, post_secs=0 means end at onset):
%   1. combined   — 2s pre-trial + full trial
%   2. pre_trial  — 3s before onset only
%   3. during     — trial onset to trial end only

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

        % derive onset column from stored window size — works for any stored window
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
    exportgraphics(figS, sprintf('paper/motion_scatter_%s.pdf', mode.label), 'ContentType','image', 'Resolution',300);

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
    xlabel(sprintf('Motion quartile — %s', strrep(mode.label,'_',' ')), 'FontWeight','bold');
    ylabel('MSE  ||e||', 'FontWeight','bold');
    set(gca, 'Box','off', 'TickDir','out');
    exportgraphics(figQ, sprintf('paper/motion_quartile_%s.pdf', mode.label), 'ContentType','vector');
end

%% Raw motion traces — sessions with face video

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
exportgraphics(fig, 'paper/motion_traces.pdf', 'ContentType','image', 'Resolution',300);

%% Interactive motion scatter — combined mode (click a point to inspect trial)
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

    % OL scatter — store per-point metadata in UserData
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

fprintf('Interactive scatter ready — click any point to inspect that trial.\n');

%% Figures I & J — Spectral heatmaps sorted by MSE (relative power: band/total)

% --- Pass 1: collect per-trial mean relative power for all sessions ---
nc_all     = [];  wc_all     = [];
nc_mse_all = [];  wc_mse_all = [];
freqCtrs   = [];

sess_nc    = cell(nSess, 1);
sess_wc    = cell(nSess, 1);
sess_valid = false(nSess, 1);

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'ncFreqSpec') || ~any(data_k.ncFreqSpec(:)), continue; end

    dur_k    = mouse.(fields{k}).d.params.dur;
    onsetBin = data_k.freqOnsetBin;
    winStart = onsetBin - 1;
    winEnd   = min(onsetBin + dur_k - 1, size(data_k.ncFreqSpec, 2));

    nc_mean = reshape(mean(data_k.ncFreqSpec(:, winStart:winEnd, :), 2), ...
                      size(data_k.ncFreqSpec, 1), []);
    wc_mean = reshape(mean(data_k.wcFreqSpec(:, winStart:winEnd, :), 2), ...
                      size(data_k.wcFreqSpec, 1), []);

    sess_nc{k}    = nc_mean;
    sess_wc{k}    = wc_mean;
    sess_valid(k) = true;
    freqCtrs      = data_k.freqBandCtrs;

    nc_all     = [nc_all;     nc_mean];
    wc_all     = [wc_all;     wc_mean];
    nc_mse_all = [nc_mse_all; data_k.er_ncDfk];
    wc_mse_all = [wc_mse_all; data_k.er_wcDfk];
end

% Color limit: 98th percentile of pooled relative power (clips outliers)
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

    ud_ol              = ud_base;
    ud_ol.sorted_order = nc_ord;
    ud_ol.trial_idx    = data_k.nc;
    ud_ol.freq_spec    = data_k.ncFreqSpec;
    ud_ol.lbl          = 'OL';

    ud_cl              = ud_base;
    ud_cl.sorted_order = wc_ord;
    ud_cl.trial_idx    = data_k.wc;
    ud_cl.freq_spec    = data_k.wcFreqSpec;
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
    cb = colorbar(ax_last); cb.Label.String = 'band/total power'; cb.FontSize = 6;
end
exportgraphics(fig_I, 'paper/freq_heatmap_sessions.png', 'Resolution', 300);
fprintf('Figure I ready — click any row to inspect that trial.\n');

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
cb = colorbar(ax_cl); cb.Label.String = 'band/total power'; cb.FontSize = 6;
exportgraphics(fig_J, 'paper/freq_heatmap_combined.png', 'Resolution', 300);

% --- Figure K: per-band mean-normalised heatmap ---
% Each band divided by its cross-trial mean (OL+CL pooled).
% Values around 1.0 = average; >1 = more power than average; <1 = less.
% All 20 bands get equal visual weight regardless of absolute power level.
band_mean    = mean([nc_all; wc_all], 1);           % 1×20 cross-trial mean per band
nc_norm_all  = nc_all  ./ band_mean;
wc_norm_all  = wc_all  ./ band_mean;
clim_norm    = prctile([nc_norm_all(:); wc_norm_all(:)], 98);

fig_K = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

ax_ol = axes(fig_K, 'Position', [lm_j,              bm_j, pw_j, ph_j]);
imagesc(ax_ol, freqCtrs, 1:size(nc_norm_all,1), nc_norm_all(nc_ord_all,:));
colormap(ax_ol, 'hot'); clim(ax_ol, [0 clim_norm]);
set(ax_ol, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6);
xlabel(ax_ol, 'Frequency (Hz)', 'FontWeight','bold');
ylabel(ax_ol, 'Trial (low \rightarrow high MSE)', 'FontWeight','bold');
title(ax_ol, 'Open-Loop  (band-normalised)', 'FontSize', 6, 'FontWeight','bold');

ax_cl = axes(fig_K, 'Position', [lm_j+pw_j+mid_gap, bm_j, pw_j, ph_j]);
imagesc(ax_cl, freqCtrs, 1:size(wc_norm_all,1), wc_norm_all(wc_ord_all,:));
colormap(ax_cl, 'hot'); clim(ax_cl, [0 clim_norm]);
set(ax_cl, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6, 'YTickLabel', {});
xlabel(ax_cl, 'Frequency (Hz)', 'FontWeight','bold');
title(ax_cl, 'Closed-Loop  (band-normalised)', 'FontSize', 6, 'FontWeight','bold');
cb = colorbar(ax_cl); cb.Label.String = 'power / mean power'; cb.FontSize = 6;
exportgraphics(fig_K, 'paper/freq_heatmap_normalised.png', 'Resolution', 300);
