% impulse-analysis/cp_doseresponse.m
% Absolute local-response DOSE-RESPONSE (amplitude vs residual energy), WITH bleed
% comp. This is the one analysis that genuinely needs decontamination: bleed comp
% sets the absolute residual MAGNITUDE (it cancels in the within-amp state metrics,
% so it is irrelevant to cp_state_batch, but essential here).
%
% Presettable before running:
%   selExp (3) — experiment index
%
% Prereq: load_experiments.m has been run (allExperiments in workspace).
close all; clc;
bp = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(genpath(fullfile(bp, 'utils')));

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('cp_doseresponse: run load_experiments.m first.');
end
if ~exist('selExp','var') || isempty(selExp), selExp = 3; end

opts   = struct('decontam',true, 'use_motion',true, 'make_wide',false, 'plot',true);
[R, ~] = cp_residual_core(allExperiments, selExp, opts);

% ---- per-amplitude residual dip energy (0-200 ms), physical ΔF/F units ----
ia  = R.ia_imp;  nA = numel(ia);
amp = R.uAmp(ia);
resE_mu = nan(nA,1); resE_se = nan(nA,1); actE_mu = nan(nA,1);
for k = 1:nA
    Rm = R.res_imp{ia(k)};  Am = R.act_imp{ia(k)};
    e  = mean(Rm(:,R.iDip), 2, 'omitnan');             % per-trial residual energy
    resE_mu(k) = mean(e, 'omitnan');
    resE_se(k) = std(e, 'omitnan') / sqrt(max(sum(isfinite(e)),1));
    actE_mu(k) = mean(mean(Am(:,R.iDip), 2, 'omitnan'), 'omitnan');
end

fig = paperFig(6, 4);
ax  = axes(fig); hold(ax,'on');
plot(ax, amp, actE_mu, '-o', 'Color',[0.55 0.55 0.55], 'MarkerFaceColor',[0.55 0.55 0.55], ...
    'LineWidth',1.0, 'MarkerSize',3, 'DisplayName','Actual ipsi');
errorbar(ax, amp, resE_mu, resE_se, '-o', 'Color',[0.85 0.2 0.1], 'MarkerFaceColor',[0.85 0.2 0.1], ...
    'LineWidth',1.2, 'MarkerSize',3, 'CapSize',2, 'DisplayName','Residual (local)');
yline(ax, 0, 'k--', 'LineWidth',0.4, 'HandleVisibility','off');
set(ax, 'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
xlabel(ax, 'Amplitude (V)', 'FontSize',6, 'FontWeight','bold');
ylabel(ax, '0-200 ms \DeltaF/F (%)', 'FontSize',6, 'FontWeight','bold');
title(ax, sprintf('%s %s e%d  dose-response (bleed-comp)', R.mn, R.td, R.en), ...
    'FontSize',6, 'FontWeight','bold');
lg = legend(ax, 'Location','southwest', 'Box','off', 'FontSize',5);
try; lg.ItemTokenSize = [6 6]; catch; end
paperExport(fig, fullfile(bp,'paper','images','figure2','cp_doseresponse.png'));
fprintf('[cp_doseresponse] Exported cp_doseresponse.png\n');
