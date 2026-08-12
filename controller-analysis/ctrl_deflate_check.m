%% ctrl_deflate_check.m   [DEFCHK]  -- is the deflated model's flat Global EARNED or ASSUMED?
%
% The 'deflate' predictor constrains the weights orthogonal to the contra stim direction, so its
% Global is flat over the stim window and Local reads 100%. Those two numbers are the CONSTRAINT,
% not a measurement, and quoting them as a result would be circular. This script draws the numbers
% that are not circular:
%
%   (a) HELD-OUT leak removal. The constraint direction d is estimated on ODD trials and the
%       remaining leak driver is scored on EVEN trials, which the constraint never saw. Only the
%       part that survives that split is a property of the stim direction rather than of the
%       trials it was measured on.
%   (b) THE COST. Held-out spontaneous R^2, ridge vs deflate. The constraint spends prediction
%       accuracy to buy blindness; a session that pays a lot is telling you the stim direction and
%       the useful signal directions overlap there.
%   (c) THE BRACKET. Ridge leaks, so its Local share is a LOWER bound. Deflate removes the leak, so
%       its Local share is the CEILING. The truth is between them, and the width of that interval
%       is the honest uncertainty on "how local is the effect".
%
% READ-ONLY. Needs both ctrl_ols_ol_stimblind_ridge_*.mat and _deflate_*.mat on disk.
%
% SECTIONS: [DEFCHK-LOAD] [DEFCHK-FIG] [DEFCHK-REPORT]

%% [DEFCHK-LOAD] -----------------------------------------------------------------
DK_EXPORT = true;
DK_FMT    = {'png'};
dk_here = fileparts(mfilename('fullpath'));
if isempty(dk_here) || contains(dk_here,tempdir,'IgnoreCase',true) || contains(dk_here,'Editor_','IgnoreCase',true)
    dk_here = 'C:\Users\aditya\Documents\projects\brain_paper\controller-analysis';
end
dk_data = fullfile(dk_here,'data');
dk_out  = fullfile(dk_here,'..','paper','images','predictor_saga');
if DK_EXPORT && ~exist(dk_out,'dir'); mkdir(dk_out); end

dk_f = dir(fullfile(dk_data,'ctrl_ols_ol_stimblind_deflate_*.mat'));
assert(~isempty(dk_f), '[DEFCHK] no deflate caches -- build with CTRL_PRED = ''deflate''.');
DK = struct([]);
for i = 1:numel(dk_f)
    tg = erase(erase(dk_f(i).name,'ctrl_ols_ol_stimblind_deflate_'),'.mat');
    Dd = load(fullfile(dk_data,dk_f(i).name));
    rf = fullfile(dk_data, sprintf('ctrl_ols_ol_stimblind_ridge_%s.mat', tg));
    if ~exist(rf,'file'); continue; end
    Rr = load(rf, 'capt_sus','capt_tran','leak_sus','R2_te');
    D  = Dd.RPATH.DEF;
    a = struct('tag',tg);
    a.rem_hold  = 100*(1 - abs(D.holdout_ratio));   % % of the leak driver removed OUT OF SAMPLE
    a.R2_ridge  = D.R2te_free;   a.R2_defl = D.R2te;   a.cost = D.r2_cost;
    a.capt_ridge = Rr.capt_sus;  a.capt_defl = Dd.capt_sus;
    a.leak_ridge = Rr.leak_sus;
    a.capt_tran_ridge = Rr.capt_tran;  a.capt_tran_defl = Dd.capt_tran;
    if isempty(DK); DK = a; else; DK(end+1) = a; end %#ok<SAGROW>
end
assert(~isempty(DK), '[DEFCHK] no session has BOTH a ridge and a deflate cache.');
[~,ord] = sort([DK.rem_hold],'descend');  DK = DK(ord);
nS = numel(DK);
lbl = strrep({DK.tag},'_','\_');

%% [DEFCHK-FIG] ------------------------------------------------------------------
figD = figure('Color','w','Position',[40 60 1500 720]);
tl = tiledlayout(figD,2,2,'TileSpacing','compact','Padding','compact');

% (a) held-out leak removal -- the only non-circular number here
ax1 = nexttile(tl,1); hold(ax1,'on');
c = repmat([0.30 0.55 0.85], nS, 1);
c([DK.rem_hold] < 50, :) = repmat([0.85 0.45 0.20], nnz([DK.rem_hold]<50), 1);
for i=1:nS; bar(ax1, i, DK(i).rem_hold, 0.7, 'FaceColor', c(i,:), 'EdgeColor','none'); end
yline(ax1, 50, '--', 'Color',[0.6 0.6 0.6], 'Label','50%');
yline(ax1, 0,  '-',  'Color',[0.3 0.3 0.3]);
yline(ax1, median([DK.rem_hold]), '-', 'Color',[0.1 0.4 0.7], 'LineWidth',1.2, ...
    'Label',sprintf('median %.0f%%', median([DK.rem_hold])));
set(ax1,'XTick',1:nS,'XTickLabel',lbl,'XTickLabelRotation',45,'FontSize',7);
ylabel(ax1,'leak driver removed (%)');
title(ax1, sprintf('(a) HELD-OUT: d fitted on odd trials, scored on even  |  %d/%d below 50%%', ...
    nnz([DK.rem_hold]<50), nS));

% (b) what it costs
ax2 = nexttile(tl,2); hold(ax2,'on');
plot(ax2, 1:nS, [DK.R2_ridge], 'o-', 'Color',[0.35 0.35 0.35], 'MarkerFaceColor',[0.35 0.35 0.35], ...
    'MarkerSize',4, 'DisplayName','ridge');
plot(ax2, 1:nS, [DK.R2_defl],  's-', 'Color',[0.85 0.35 0.05], 'MarkerFaceColor',[0.85 0.35 0.05], ...
    'MarkerSize',4, 'DisplayName','deflate');
yline(ax2, ctrl_r2_floor(), ':', 'Color',[0.7 0 0], 'Label','0.85 floor','HandleVisibility','off');
set(ax2,'XTick',1:nS,'XTickLabel',lbl,'XTickLabelRotation',45,'FontSize',7);
ylabel(ax2,'held-out spontaneous R^2');
legend(ax2,'Box','off','Location','southwest','FontSize',7);
title(ax2, sprintf('(b) the price of blindness  |  median cost %.3f, worst %.3f', ...
    median([DK.cost]), max([DK.cost])));

% (c) THE BRACKET -- ridge Local is a floor, deflate Local is the ceiling
ax3 = nexttile(tl,3); hold(ax3,'on');
for i = 1:nS
    plot(ax3, [i i], [DK(i).capt_ridge DK(i).capt_defl], '-', 'Color',[0.7 0.7 0.7], ...
        'LineWidth',3, 'HandleVisibility','off');   % else 13 grey bars land in the legend
end
plot(ax3, 1:nS, [DK.capt_ridge], 'o', 'Color',[0.35 0.35 0.35], 'MarkerFaceColor',[0.35 0.35 0.35], ...
    'MarkerSize',5, 'DisplayName','ridge (leak present -> LOWER bound)');
plot(ax3, 1:nS, [DK.capt_defl], 's', 'Color',[0.85 0.35 0.05], 'MarkerFaceColor',[0.85 0.35 0.05], ...
    'MarkerSize',5, 'DisplayName','deflate (leak removed -> CEILING)');
set(ax3,'XTick',1:nS,'XTickLabel',lbl,'XTickLabelRotation',45,'FontSize',7);
ylabel(ax3,'Local share, sustained (%)');  ylim(ax3,[0 110]);
legend(ax3,'Box','off','Location','southeast','FontSize',7);
title(ax3, '(c) the bracket on "how local is the effect" -- truth lies inside the grey bar');

% (d) is the removal buying anything real? removal vs the leak it started from
ax4 = nexttile(tl,4); hold(ax4,'on');
scatter(ax4, [DK.leak_ridge], [DK.rem_hold], 46, [DK.cost], 'filled');
colormap(ax4, parula);  cb = colorbar(ax4);  cb.Label.String = 'R^2 cost';
yline(ax4, 50, '--', 'Color',[0.6 0.6 0.6]);
for i=1:nS
    text(ax4, DK(i).leak_ridge, DK(i).rem_hold, ['  ' lbl{i}], 'FontSize',6, 'Color',[0.3 0.3 0.3]);
end
[rho_dk,p_dk] = corr([DK.leak_ridge].', [DK.rem_hold].', 'type','Spearman');
xlabel(ax4,'ridge Global leak (%), i.e. the dip to be removed');
ylabel(ax4,'held-out leak removed (%)');
title(ax4, sprintf('(d) sessions with a BIGGER dip lose more of it: r_s = %.2f, p = %.3f', rho_dk, p_dk));

sgtitle(figD, ['[DEFCHK] deflate: Global flat and Local 100% are the CONSTRAINT, not a result. ' ...
               'These four panels are what is actually measured.'], 'FontWeight','bold');
if DK_EXPORT
    for k = 1:numel(DK_FMT)
        exportgraphics(figD, fullfile(dk_out, ['ctrl_deflate_check.' DK_FMT{k}]), 'Resolution',300);
    end
end

%% [DEFCHK-REPORT] ---------------------------------------------------------------
fprintf('\n[DEFCHK] %d sessions with both models\n', nS);
fprintf('  %-20s %8s %8s %8s %9s %9s\n','session','rem_hold','R2ridge','R2defl','Loc_ridge','Loc_defl');
for i=1:nS
    fprintf('  %-20s %7.0f%% %8.3f %8.3f %8.0f%% %8.0f%%\n', DK(i).tag, DK(i).rem_hold, ...
        DK(i).R2_ridge, DK(i).R2_defl, DK(i).capt_ridge, DK(i).capt_defl);
end
fprintf('\n  held-out removal : median %.0f%%  range %.0f..%.0f%%   (%d/%d below 50%%)\n', ...
    median([DK.rem_hold]), min([DK.rem_hold]), max([DK.rem_hold]), nnz([DK.rem_hold]<50), nS);
fprintf('  R^2 cost         : median %.3f  worst %.3f\n', median([DK.cost]), max([DK.cost]));
fprintf('  Local bracket    : ridge %.0f%% -> deflate %.0f%% (median), median width %.0f pts\n', ...
    median([DK.capt_ridge]), median([DK.capt_defl]), median([DK.capt_defl]-[DK.capt_ridge]));
fprintf('  leak vs removal  : Spearman %.2f (p=%.3f)\n', rho_dk, p_dk);
fprintf('[DEFCHK] figure -> %s\n', dk_out);
