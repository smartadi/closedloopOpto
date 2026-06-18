%% data_overview.m  --  Widefield + opto input data overview
% Mirrors the structure of YE-et-al-2023-spirals/data_overview.m, adapted
% for closed-loop opto widefield experiments.
%
% Sections:
%   §1  Example dF/F frames around a stim onset
%   §2  Opto input signal + widefield pixel trace aligned to stim onset
%   §3  Spiral detection preview (single session, subset of trials)
%
% Run from brain_paper/ root directory.

clc; close all;
addpath(genpath('utils'));

%% ── Session to inspect ─────────────────────────────────────────────────────
mn = 'AL_0033';   % mouse name
td = '2025-02-12'; % session date (yyyy-mm-dd)
en = 2;            % experiment folder number

d = initialize_data(mn, en, td);

U    = d.svd.U;       % [ny × nx × nSV]
V    = d.svd.V;       % [nSV × nFrames]
t    = d.timeBlue(:)';
mimg = d.svd.mimg;    % mean image [ny × nx]

nSV  = 50;            % components used (>99 % variance)
dV   = [zeros(nSV,1), diff(V(1:nSV,:), [], 2)];
U1   = U(:,:,1:nSV);

%% §1  Example dF/F frames (8 frames starting 2 s after first stim onset) ──
t0_ex  = d.stimStarts(1);
[~, f0] = min(abs(t - t0_ex));
frames  = f0 + (0:7);   % 8 consecutive frames post-onset

U2D   = reshape(U1, size(U,1)*size(U,2), nSV);
trace = U2D * dV(:, frames);                          % [nPix × 8]
trace = reshape(trace, size(U,1), size(U,2), 8);      % [ny × nx × 8]
trace = trace ./ mimg;                                % dF/F

cmin = min(trace(:)); cmax = max(trace(:));
fig1 = figure('Renderer','painters','Position',[100 100 1000 300]);
for i = 1:8
    ax = subplot(1,8,i);
    imagesc(squeeze(trace(:,:,i)));
    caxis([cmin cmax]); axis image; axis off;
    title(sprintf('%.2f s', t(frames(i)) - t0_ex), 'FontSize',7);
end
h = axes(fig1,'visible','off');
c = colorbar(h,'Position',[0.93 0.35 0.01 0.30]);
caxis([cmin cmax]);
c.Label.String = 'dF/F';
sgtitle('§1  Example frames after stim onset', 'FontSize',9);

%% §2  Opto input signal + widefield pixel trace aligned to stim onset ──────
% Shows the first closed-loop trial (if available) or first OL trial.
% Mirrors the widefield-vs-MUA panel in the original data_overview.m.

px = round(d.params.pixels(1,:));   % control pixel [row, col]

pre_s  = 3;   % seconds before onset to show
post_s = 6;   % seconds after  onset to show

t0_tr  = d.stimStarts(1);
[~,f1] = min(abs(t - (t0_tr - pre_s)));
[~,f2] = min(abs(t - (t0_tr + post_s)));

pixTrace = squeeze(U1(px(1), px(2), :))' * dV(:, f1:f2);   % [1 × nFrames]
pixTrace = pixTrace ./ mimg(px(1), px(2));

t_ax = t(f1:f2) - t0_tr;   % time relative to onset

% Find corresponding opto input samples in the same window
i1_inp = find(d.inpTime >= t0_tr - pre_s, 1);
i2_inp = find(d.inpTime <= t0_tr + post_s, 1, 'last');
t_inp  = d.inpTime(i1_inp:i2_inp) - t0_tr;
inp    = d.inpVals(i1_inp:i2_inp);

fig2 = figure('Renderer','painters','Position',[100 100 900 400]);

subplot(2,1,1);
plot(t_inp, inp, 'b', 'LineWidth',1);
xline(0,'k--','LineWidth',1);
xlabel('Time re. stim onset (s)');
ylabel('Input (a.u.)');
title('Opto input signal');
xlim([-pre_s, post_s]);

subplot(2,1,2);
plot(t_ax, pixTrace*100, 'r', 'LineWidth',1);
xline(0,'k--','LineWidth',1);
xlabel('Time re. stim onset (s)');
ylabel('dF/F (%)');
title(sprintf('Widefield pixel [%d,%d]', px(1), px(2)));
xlim([-pre_s, post_s]);

sgtitle('§2  Input signal vs widefield pixel trace', 'FontSize',9);

%% §3  Spiral detection preview (first 10 trials) ───────────────────────────
% Runs detectSpirals on a small trial subset so you can verify the detection
% pipeline before committing to a full session run in spiral_analysis.m.

spirals_repo = 'C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals\spirals';
if ~exist(fullfile(spirals_repo,'utils','spirals_detection','setSpiralDetectionParams.m'),'file')
    error('Spirals repo not found at %s — update spirals_repo path.', spirals_repo);
end
addpath(genpath(spirals_repo));

dur_sp    = 3;   % trial duration (s)
window_sp = 1;   % peri-trial padding (s)
nTrialPreview = min(10, numel(d.stimStarts));

tStarts_pr = d.stimStarts(1:nTrialPreview);
tEnds_pr   = tStarts_pr + dur_sp;

server_root = fullfile('data', sprintf('%s_%s_%d', mn, td, en));
if ~exist(server_root, 'dir'); mkdir(server_root); end
spirals_pr  = detectSpirals(U1, V(1:nSV,:), t, tStarts_pr, tEnds_pr, window_sp, server_root);

fprintf('\n§3  Spiral preview: %d spirals in %d trials\n', height(spirals_pr), nTrialPreview);

if ~isempty(spirals_pr) && istable(spirals_pr)
    fig3 = figure('Renderer','painters','Position',[100 100 500 400]);
    edges_peth = -window_sp : 0.5 : dur_sp + window_sp;
    counts     = histcounts(spirals_pr.t_rel, edges_peth);
    t_centers  = edges_peth(1:end-1) + 0.25;
    bar(t_centers, counts / nTrialPreview, 'FaceColor',[0.4 0.6 0.9],'EdgeColor','none');
    xline(0,     'k--','LineWidth',1);
    xline(dur_sp,'k:','LineWidth',0.8);
    xlabel('Time re. stim onset (s)');
    ylabel('Spirals / trial');
    title(sprintf('§3  Peri-stim spiral rate (first %d trials)', nTrialPreview));
end
