% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

%% Single-session trace overlay â€” session 3
close all;
imp3  = allExperiments(2).imp;
uAmp3 = allExperiments(2).uAmp;
mn3   = allExperiments(2).mn;
td3   = allExperiments(2).td;
en3   = allExperiments(2).en;

PS = paperStyle();
setPaperDefaults();
figS = paperFig(PS.f2w, PS.f2h);   % 2A -- Fig-2 grid (see paperStyle f2w/f2h)
hold on;

% Model-fit window drawn LATER (after ylim is known) so it can span the full
% height; tShade = exact xlim of tf_fit.m paper figure (preWin_A=0.2 s, tFit_s=0.5 s).
% Update these values if tFit_s or preWin_A change in tf_fit.m.
tShade = [-0.2, 0.5];

% TALK VARIANT (2026-08-19, user: "i specifically want the first imp response figure to be
% drawn without the model fit window shown"). The fit window is a Methods detail -- in a talk
% it invites a question about the fit before the audience has been told there is a fit. Both
% knobs default to the paper behaviour, so nothing changes unless they are set in the base
% workspace before running.
if ~exist('TO_FITWIN','var'), TO_FITWIN = true; end   % false = no shaded window, no label
if ~exist('TO_OUTDIR','var'), TO_OUTDIR = '';   end   % non-empty = export here, not figure2/

% Pass 1: +/-1 SD across trials, shown ONLY for the lowest and highest drawn
% amplitude (subset -> keeps all 5 mean traces legible). Faint fill only, no
% outline. Drawn first so the mean traces sit on top.
tw = t_win(:).';
drawIdx  = find(arrayfun(@(i) mod(i,2)==1 && ~isempty(imp3.dfImp{i}), 1:length(uAmp3)));
shadeIdx = unique([drawIdx(1) drawIdx(end)]);   % lowest + highest amplitude
sd_alpha = 0.08;                                 % faint fill
for i = shadeIdx
    mu_i = mean(imp3.dfImp{i}, 1);              % trials x time -> 1 x time
    sd_i = std(imp3.dfImp{i}, 0, 1);           % +/-1 SD across trials
    g_i = min(1-0.1*i, 0.78);                   % cap lightest (0 mW) so its swatch shows on white
    col_i = [g_i g_i g_i];
    fill([tw fliplr(tw)], [mu_i+sd_i fliplr(mu_i-sd_i)], col_i, ...
        'FaceAlpha', sd_alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end

% Pass 2: trial-mean traces
for i = 1:length(uAmp3)
    if mod(i,2)==1 && ~isempty(imp3.dfImp{i})
        g_i = min(1-0.1*i, 0.78);               % cap lightest (0 mW) so its swatch shows on white
        plot(t_win, mean(imp3.dfImp{i}, 1), ...
            'Color',[g_i g_i g_i],'LineWidth',2, ...
            'DisplayName', sprintf('%.2f mW', uAmp3(i)/3));
    end
end
xlim([-1,1]);
lgd = legend('Box','off','Location','southwest');
paperLegend(lgd);
paperAxes(gca,'XLength',0.25,'YLength',1,'XLabel','250 ms','YLabel','1% dF/F');
% Park the legend at the extreme bottom-left of the CANVAS (user 2026-09-30): the
% traces run through the 'southeast' slot. This MUST come after paperAxes -- that
% call resizes the axes, and an auto-located legend is re-laid-out when it does,
% which silently undoes any Position set beforehand. Location='none' pins it.
drawnow; lgd.Units = 'normalized'; lgp = lgd.Position;
lgd.Location = 'none';
lgd.Position = [0.150, 0.075, lgp(3), lgp(4)];   % clear of the paperAxes scale bars

% Freeze the data-driven y-range, then draw the model-fit window spanning it
% full height and send it to the back (behind traces and SD fills).
yl_s = ylim(gca);  ylim(yl_s);
span = yl_s(2) - yl_s(1);
if TO_FITWIN
    hModelWin = patch([tShade(1) tShade(2) tShade(2) tShade(1)], ...
        [yl_s(1) yl_s(1) yl_s(2) yl_s(2)], [0.8 0.8 0.8], ...
        'FaceAlpha', 0.5, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    uistack(hModelWin, 'bottom');
end

% Stimulation: a laser-command row along the top with its one pulse at t = 0 (Anna F2.2,
% 2026-10-29: "why a dot for the laser"). A dot reads as a data point; a pulse on a baseline reads
% as the input. Width = one imaging frame (Methods: single pulse 23-28 ms), so at this x-range it
% draws as a spike, which is what an impulse is.
pulse_w = 0.025;
lz_y = yl_s(1) + 0.86*span;  lz_h = 0.09*span;
plot([-1 0 0 pulse_w pulse_w 1], lz_y + [0 0 lz_h lz_h 0 0], 'Color', 'r', ...
    'LineWidth', 0.75, 'HandleVisibility', 'off', 'Clipping', 'off');
text(-0.97, lz_y + 0.02*span, 'Laser', 'Color','r','FontSize',PS.fs,'FontWeight','bold', ...
    'HorizontalAlignment','left','VerticalAlignment','bottom','Clipping','off');
% The 'Model Fit Window' label (3.5 pt, below Nature's 5 pt floor) is gone; at 6 pt it is wider
% than the band. The caption names the band.

% TALK LEGEND (2026-08-19, user: "needs the legend shifted farther to bottom right to not
% overlap the traces, maybe make the text smaller"). The amplitude key is 5 rows deep, and at
% paper size 'southeast' still lands it on the rebound. Pushed into the bottom-right corner
% and shrunk -- on a slide the amplitudes are read off the ramp, not the numbers.
if ~TO_FITWIN
    lgd.FontSize = max(3.5, PS.fs * 0.75);
    lgd.Units = 'normalized';
    pos = lgd.Position;
    lgd.Position = [1 - pos(3) - 0.005, 0.005, pos(3), pos(4)];
end

outDirS = fullfile(paperRoot, 'images', 'figure2');
if ~isempty(TO_OUTDIR), outDirS = TO_OUTDIR; end
jnAxesAll(figS);   % rule-book font/axis pass (see utils/jnAxesAll.m)
paperExport(figS, fullfile(outDirS, sprintf('imp_single_%s_%s_en%d.pdf',mn3,td3,en3)));


%%