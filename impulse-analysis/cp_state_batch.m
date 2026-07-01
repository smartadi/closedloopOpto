% impulse-analysis/cp_state_batch.m
% Canonical, replication-ready residual STATE-dependence analysis.
% Loops sessions, runs cp_residual_core (decontam OFF, no inspector, no figures),
% and aggregates the per-session partial(dev_stim, state | dev_pre) correlations
% into a printed table + a summary figure. This is the paper-facing output.
%
% Presettable before running:
%   sessions  (1:numel(allExperiments)) — which experiment indices to loop
%
% Prereq: load_experiments.m has been run (allExperiments in workspace).
close all; clc;
bp = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(bp, 'utils')));

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('cp_state_batch: run load_experiments.m first.');
end
if ~exist('sessions','var') || isempty(sessions)
    sessions = 1:numel(allExperiments);     % default: every loaded session
end

opts   = struct('decontam',false, 'use_motion',true, 'make_wide',false, 'plot',false);
stateL = {'Motion','PreVar','PreDelta'};
nS     = numel(sessions);

rPart = nan(nS,3); pPart = nan(nS,3);
rStim = nan(nS,3); rPre  = nan(nS,3);
nUsed = nan(nS,3); r2    = nan(nS,1); labels = strings(nS,1);

for si = 1:nS
    s = sessions(si);
    fprintf('\n=== cp_state_batch: session %d/%d (selExp=%d) ===\n', si, nS, s);
    [~, S] = cp_residual_core(allExperiments, s, opts);
    rPart(si,:) = S.r_primary;  pPart(si,:) = S.p_primary;   % PRIMARY = L1-dev (swapped 2026-07-01)
    rStim(si,:) = S.r_stim;     rPre(si,:)  = S.r_pre;
    nUsed(si,:) = S.n;          r2(si)      = S.cv_mean;
    labels(si)  = sprintf('%s %s e%d', S.mn, S.td, S.en);
end

% ---- table ----
fprintf('\n==== Residual state-dependence: partial(L1-dev, state | dev_pre) ====\n');
for si = 1:nS
    fprintf('%-22s R²=%.3f | Motion %+.3f(p=%.2g) | PreVar %+.3f(p=%.2g) | PreDelta %+.3f(p=%.2g)\n', ...
        labels(si), r2(si), rPart(si,1),pPart(si,1), rPart(si,2),pPart(si,2), rPart(si,3),pPart(si,3));
end

% ---- summary figure: partial rho per state per session (filled = p<0.05) ----
fig = paperFig(12, 8);
ax  = axes(fig); hold(ax,'on');
xj   = 1:3;
cmap = lines(max(nS,1));
for si = 1:nS
    sig = pPart(si,:) < 0.05;
    plot(ax, xj, rPart(si,:), '-o', 'Color',cmap(si,:), 'MarkerFaceColor','w', ...
        'LineWidth',1.0, 'MarkerSize',4, 'DisplayName', labels(si));
    scatter(ax, xj(sig), rPart(si,sig), 36, cmap(si,:), 'filled', ...
        'MarkerEdgeColor','k', 'HandleVisibility','off');
end
yline(ax, 0, 'k--', 'LineWidth',0.5, 'HandleVisibility','off');
set(ax, 'XTick',xj, 'XTickLabel',stateL, 'XLim',[0.5 3.5], ...
    'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
ylabel(ax, 'partial \rho (stim | pre)', 'FontSize',6, 'FontWeight','bold');
title(ax, 'Residual stim-response state-dependence (filled = p<0.05)', ...
    'FontSize',6, 'FontWeight','bold');
lg = legend(ax, 'Location','eastoutside', 'Box','off', 'FontSize',5);
try; lg.ItemTokenSize = [6 6]; catch; end
paperExport(fig, fullfile(bp,'paper','images','figure2','cp_state_batch.png'));
fprintf('\n[cp_state_batch] Exported cp_state_batch.png  (%d sessions)\n', nS);
