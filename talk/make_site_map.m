%% make_site_map.m -- the stim site and what it does, for the impulse dataset
%
% One frame: the trial-averaged peri-stim response of AL_0033 2025-01-29 e1 at the strongest
% amplitude, in the CANONICAL transposed view (brain vertical), with the data-derived laser
% site marked. This is the picture the impulse panels are measurements OF -- the talk shows
% the traces without ever showing where on the cortex they come from.
%
% Map = mean dF/F over 0-200 ms post-onset minus the -500..0 ms baseline (the project's
% locked inhibition-energy window), reconstructed inside the brain mask.
%
% Site is the CACHED data-derived pixel [row 373, col 353] -- NOT params.pixel, which the
% load/save schemes flip. On a transposed axis it is marked plot(row, col). See
% impulse-analysis/CLAUDE.md "Stim site & display orientation".
%
% Requires allExperiments in the base workspace (run load_experiments first).

root = 'C:\Users\aditya\Documents\projects\brain_paper';
addpath(genpath(fullfile(root,'utils')));
outDir = fullfile(root,'talk');

A    = allExperiments(3);
ampI = numel(A.uAmp);                                  % strongest amplitude
bm   = logical(A.brainMask(:));
sz   = size(A.mimg);

map = nan(sz);
map(bm) = double(A.imp.resp_map{ampI}) - double(A.imp.base_map{ampI});

% Cached data-derived site (row, col) in the NATIVE frame.
S  = load(fullfile(root,'impulse-analysis','data','cp_stim_site_AL_0033_0129_e1.mat'));
rc = S.rowcol;
fprintf('[SITEMAP] %s %s e%d | amp %.1f V | site [row %d col %d] | depth %.2f %%dF/F\n', ...
        A.mn, A.td, A.en, A.uAmp(ampI), rc(1), rc(2), map(rc(1), rc(2)));

fig = figure('Color','w','Units','pixels','Position',[100 100 900 900]);
ax  = axes(fig);
imagesc(ax, map');                                     % TRANSPOSED = canonical view
axis(ax,'image'); axis(ax,'off'); hold(ax,'on');

% Diverging map centred on zero, clipped to a symmetric robust range so the inhibition blob
% is not swamped by a couple of vessel pixels.
v  = map(isfinite(map));
lim = prctile(abs(v), 99.5);
clim(ax, [-lim lim]);
% Diverging blue-white-red, built here rather than relying on brewermap being installed
% (it is not, and the silent fallback to flipud(jet) painted the whole hemisphere red).
% NEGATIVE = BLUE: inhibition is what this figure is about, so it gets the cool end.
nHalf = 128;
ramp  = linspace(0,1,nHalf)';
cmap  = [ [0.03+0.97*ramp, 0.19+0.81*ramp, 0.42+0.58*ramp] ;      % blue -> white
          [ones(nHalf,1), 1-0.90*ramp, 1-0.93*ramp] ];             % white -> red
colormap(ax, cmap);

% Grey out everything off-brain rather than letting NaN take the axes colour.
set(ax,'Color',[1 1 1]);
alphaMask = double(isfinite(map'));
set(findobj(ax,'Type','image'), 'AlphaData', alphaMask);

% Site marker: plot(row, col) on the transposed axis.
plot(ax, rc(1), rc(2), 'o', 'MarkerSize', 24, 'LineWidth', 3.5, 'MarkerEdgeColor', [1 1 1]);
plot(ax, rc(1), rc(2), 'o', 'MarkerSize', 24, 'LineWidth', 1.6, 'MarkerEdgeColor', [0 0 0]);
text(ax, rc(1)+32, rc(2)-22, 'laser site', 'Color','k', 'FontSize',22, 'FontWeight','bold');

cb = colorbar(ax, 'eastoutside');
cb.Label.String = '\DeltaF/F (%)';
cb.FontSize = 18;  cb.Label.FontSize = 20;
title(ax, sprintf('%s  %s   %.1f V   mean 0–200 ms', A.mn, A.td, A.uAmp(ampI)), ...
      'FontSize', 20, 'FontWeight','bold', 'Interpreter','none');   % AL_0033, not AL-sub-0

exportgraphics(fig, fullfile(outDir,'PANEL_site_map.png'), 'Resolution', 400);
fprintf('[SITEMAP] wrote %s\n', fullfile(outDir,'PANEL_site_map.png'));
