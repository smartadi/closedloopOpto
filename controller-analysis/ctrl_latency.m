% controller-analysis/ctrl_latency.m
% Hardware loop latency of the closed-loop controller: time from the camera
% exposure of the frame a command was computed from, to the moment that command
% appears on the laser (Timeline lightCommand channel, 2 kHz = 0.5 ms grid).
%
% Which frame drove which command (rig code, StLab_Rainier experiment_core):
%   mp_controller._mp_reader releases frame_sem for blue frame k and then reads
%   STATE_UVAL straight away, before Process B (mp_control.py) has finished frame
%   k. So input_amps(k) is the command B computed from blue frame k-1
%   (and wrote to serial). Confirmed in the data: the laser level after each edge matches
%   input_amps(src+1) (Spearman 0.998) far better than input_amps(src) (0.80).
%
% Latency = laser edge time - exposure START of the source blue frame.
% Exposure = 11 ms, blue frames every ~28.6 ms (70 Hz trigger, blue/violet alternate).
% Not a paper panel -> PNG.

mn = 'AL_0051'; td = '2026-07-29'; en = 2;      % latest controller build (17-col input_params)
p  = expPath(mn, td, en);
STEP_V = 0.1;                                    % "real" laser step (noise MAD ~0.003 V)

%% [LAT-LOAD]
ip   = readmatrix(fullfile(p,'input_params.csv'));
amps = readmatrix(fullfile(p,'input_amps.csv'),'FileType','text','Delimiter',' '); amps = amps(:);
rd   = @(n) double(readNPY(fullfile(p,[n '.raw.npy'])));
lasA = {rd('lightCommand594'), rd('lightCommand638')};
[~,ci] = max(cellfun(@max, lasA)); las = lasA{ci};  % channel that actually fired
ex   = rd('widefieldExposure');
ts   = readNPY(fullfile(p,'lightCommand594.timestamps_Timeline.npy'));
t    = interp1(ts(:,1), ts(:,2), (0:numel(las)-1)', 'linear', 'extrap');

er = find(ex(2:end) > 1 & ex(1:end-1) <= 1) + 1;   % exposure starts (blue first)
ef = find(ex(2:end) <= 1 & ex(1:end-1) > 1) + 1;
tB = t(er(1:2:end));                                % blue exposure starts == timeBlue
expDur = median(t(ef(1:2:200)) - t(er(1:2:200)));
kk = ip(:,2); dur = ip(:,10); md = ip(:,3);         % kk = trial END frame; md 0=OL 1=CL

%% [LAT-EDGES] every laser step inside a trial window
dl = diff(las); e = find(abs(dl) > 0.03) + 1; e = e([true; diff(e) > 4]);
te = t(e);
lv  = @(x) interp1(t, las, x, 'linear');
amp = abs(lv(te + 0.004) - lv(te - 0.002));
trl = zeros(size(te));
for i = 1:numel(kk)
    w = te >= tB(kk(i) - dur(i)*35 - 3) & te <= tB(kk(i) + 3);
    trl(w) = i;
end
keep = trl > 0 & amp > STEP_V;
te = te(keep); amp = amp(keep); trl = trl(keep); mdE = md(trl);

j   = discretize(te, [tB; inf]);                    % latest blue exposure before edge
ph  = (te - tB(j)) * 1e3;
src = j; src(ph < 15) = j(ph < 15) - 1;             % source frame (edge can land after next exposure)
lat = (te - tB(src)) * 1e3;
pv  = lv(te + 0.004);
rhoOK  = corr(pv, amps(src+1), 'type', 'Spearman');
rhoOff = corr(pv, amps(src),   'type', 'Spearman');

%% [LAT-REPORT]
fprintf('\n[LAT] %s %s/%d  laser ch %d nm  exposure %.1f ms  blue period %.2f ms\n', ...
    mn, td, en, 594 + 44*(ci==2), expDur*1e3, 1e3*median(diff(tB)));
fprintf('[LAT] command->frame mapping: rho(laser, amps(k)) = %.4f   (off-by-one: %.4f)\n', rhoOK, rhoOff);
lab = {'OL','CL'};
for m = [0 1]
    x = lat(mdE == m);
    fprintf('[LAT] %s: n=%4d  median %.1f ms  IQR [%.1f %.1f]  95/99%% [%.1f %.1f]  max %.1f  late(>1 period) %.1f%%\n', ...
        lab{m+1}, numel(x), median(x), prctile(x,25), prctile(x,75), prctile(x,95), prctile(x,99), max(x), ...
        100*mean(x > 1e3*median(diff(tB))));
end
fprintf('[LAT] from exposure END: median %.1f ms;  from exposure MIDPOINT: median %.1f ms\n', ...
    median(lat) - expDur*1e3, median(lat) - expDur*1e3/2);

%% [LAT-FIG]
PS = paperStyle(); setPaperDefaults();
fig = figure('Color','w','Units','centimeters','Position',[2 2 18 5.5]);
tl  = tiledlayout(fig,1,3,'Padding','compact','TileSpacing','compact');
TB  = 1e3*median(diff(tB));

% A: one OL onset, raw traces
nexttile; hold on
i0 = find(md == 0, 1); k1 = kk(i0) - dur(i0)*35; ko = k1 - 4 + find(amps(k1-3:k1+5) > 0, 1);   % first frame logging the ON command
t0 = tB(ko - 1); w = t >= t0 - 0.035 & t <= t0 + 0.075;
xx = (t(w) - t0)*1e3;
eb = er(1:2:end); ebT = (t(eb) - t0)*1e3; ebT = ebT(ebT > -40 & ebT < 75);
for q = ebT'
    c = [.6 .75 1]; if abs(q) < 1, c = [0 .45 .95]; end
    patch([q q+expDur*1e3 q+expDur*1e3 q], [0 0 1.45 1.45], c, 'EdgeColor','none','FaceAlpha',.5);
end
plot(xx, las(w), 'k', 'LineWidth', 1.2);
tl1 = (te(find(mdE==0 & abs(te - t0) < 0.06, 1)) - t0)*1e3;
if ~isempty(tl1), xline(tl1, 'r', 'LineWidth', 1); end
xlabel('time from source-frame exposure (ms)'); ylabel('laser cmd (V)');
title(sprintf('OL onset: %.1f ms', tl1)); xlim([-35 75]); ylim([0 1.5]); box off

% B: latency histogram OL vs CL
nexttile; hold on
edges = 14:1:46;
histogram(lat(mdE==1), edges, 'Normalization','probability','FaceColor',[0 .45 .95],'EdgeColor','none');
histogram(lat(mdE==0), edges, 'Normalization','probability','FaceColor',[.9 .1 .1],'EdgeColor','none','FaceAlpha',.6);
xline(TB, 'k--'); xline(expDur*1e3, ':', 'Color',[.5 .5 .5]);
lg = legend({sprintf('CL (n=%d)',sum(mdE==1)), sprintf('OL (n=%d)',sum(mdE==0)), 'next blue exp.', 'exposure end'}, ...
    'Box','off','Location','northeast'); lg.ItemTokenSize = [6 6];
xlabel('latency (ms)'); ylabel('fraction of laser updates');
title(sprintf('median %.1f ms', median(lat))); box off

% C: stability across the session
nexttile; hold on
scatter((te - te(1))/60, lat, 3, mdE, 'filled', 'MarkerFaceAlpha', .4); colormap(gca, [.9 .1 .1; 0 .45 .95]);
yline(TB, 'k--');
xlabel('session time (min)'); ylabel('latency (ms)'); ylim([10 50]); box off
title('across session')

title(tl, sprintf('%s %s/%d - frame exposure to laser latency', mn, td, en), 'Interpreter','none');
outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'paper', 'images', 'latency');
if ~exist(outDir, 'dir'), mkdir(outDir); end
exportgraphics(fig, fullfile(outDir, sprintf('ctrl_latency_%s.png', mn)), 'Resolution', 300);
