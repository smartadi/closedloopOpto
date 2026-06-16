% controller-analysis -- motion vs MSE: does feedback decouple tracking error
% from movement? Run from brain_paper/ root AFTER load_sessions.m (needs `mouse`).
%
% Claim under test: high-motion trials inflate OPEN-loop tracking error, but
% CLOSED-loop feedback rejects the motion disturbance so CL MSE stays low.
%
% Method (primary): within each session, regress per-trial MSE on per-trial
% motion energy separately for OL and CL. MSE is z-scored within session using
% the combined OL+CL distribution (removes session baseline, preserves the
% OL-vs-CL level difference) so slopes are comparable across sessions. The key
% statistic is the OL-CL slope difference (the motion x condition interaction),
% tested across sessions with a Wilcoxon signed-rank test. Same framework as the
% pre-stimulus-variance regression (methods: Pre-stimulus state analysis).
%
% Method (companion): pooled motion-quartile bars; within the top motion
% quartile, OL vs CL MSE compared by rank-sum.
%
% Motion window: concurrent with the trial ("during trial"), the period the
% controller is actively rejecting.

fields = fieldnames(mouse);
nSess  = numel(fields);

slope_OL = nan(nSess,1); slope_CL = nan(nSess,1);
rho_OL   = nan(nSess,1); rho_CL   = nan(nSess,1);
pool_mot = []; pool_zmse = []; pool_lbl = [];   % lbl: 0=OL, 1=CL

for k = 1:nSess
    if isfield(mouse.(fields{k}),'skip'),        continue; end
    if ~isfield(mouse.(fields{k}),'data'),       continue; end
    if ~mouse.(fields{k}).has_motion,            continue; end

    data_k = mouse.(fields{k}).data;
    dur_k  = mouse.(fields{k}).d.params.dur;
    n_cols = size(data_k.ncmotion, 2);
    onset  = n_cols - 35*dur_k;                 % during-trial window: onset..trial end
    ws = max(1, onset); we = min(n_cols, onset + dur_k*35);

    mot_ol = mean(data_k.ncmotion(:, ws:we), 2);
    mot_cl = mean(data_k.wcmotion(:, ws:we), 2);
    mse_ol = data_k.er_ncDfk(:);
    mse_cl = data_k.er_wcDfk(:);

    g_ol = isfinite(mot_ol) & isfinite(mse_ol);
    g_cl = isfinite(mot_cl) & isfinite(mse_cl);
    mot_ol=mot_ol(g_ol); mse_ol=mse_ol(g_ol);
    mot_cl=mot_cl(g_cl); mse_cl=mse_cl(g_cl);
    if numel(mse_ol) < 10 || numel(mse_cl) < 10, continue; end

    % z-score MSE within session by combined OL+CL distribution
    mu = mean([mse_ol; mse_cl]); sg = std([mse_ol; mse_cl]);
    z_ol = (mse_ol - mu)/sg;  z_cl = (mse_cl - mu)/sg;

    b_ol = polyfit(mot_ol, z_ol, 1); slope_OL(k) = b_ol(1);
    b_cl = polyfit(mot_cl, z_cl, 1); slope_CL(k) = b_cl(1);
    rho_OL(k) = corr(mot_ol, z_ol, 'Type','Spearman');
    rho_CL(k) = corr(mot_cl, z_cl, 'Type','Spearman');

    pool_mot  = [pool_mot;  mot_ol; mot_cl];     %#ok<AGROW>
    pool_zmse = [pool_zmse; z_ol;   z_cl];        %#ok<AGROW>
    pool_lbl  = [pool_lbl;  zeros(numel(z_ol),1); ones(numel(z_cl),1)]; %#ok<AGROW>
end

valid = isfinite(slope_OL) & isfinite(slope_CL);
nV    = sum(valid);

% ---- cross-session statistics ----
p_ol0  = signrank(slope_OL(valid));               % OL slope != 0 ?
p_cl0  = signrank(slope_CL(valid));               % CL slope != 0 ?
p_diff = signrank(slope_OL(valid), slope_CL(valid)); % OL vs CL slope (interaction)

fprintf('\n========= Motion -> MSE coupling (per-session slopes, MSE z within session) =========\n');
fprintf('%-4s %-20s  %-10s %-10s %-9s %-9s\n','sess','session','slopeOL','slopeCL','rhoOL','rhoCL');
fprintf('%s\n', repmat('-',1,72));
vi = find(valid)';
for k = vi
    fprintf('%-4s %s %s  %+9.3f  %+9.3f  %+8.2f %+8.2f\n', fields{k}, ...
        mouse.(fields{k}).mn, mouse.(fields{k}).td, slope_OL(k), slope_CL(k), rho_OL(k), rho_CL(k));
end
fprintf('%s\n', repmat('-',1,72));
fprintf('Sessions with motion: %d\n', nV);
fprintf('  OL slope: median %+.3f (SD-MSE per SD-motion), signrank vs 0 p=%.4f\n', median(slope_OL(valid)), p_ol0);
fprintf('  CL slope: median %+.3f,                         signrank vs 0 p=%.4f\n', median(slope_CL(valid)), p_cl0);
fprintf('  OL vs CL slope (interaction): signrank p=%.4f  [OL>CL in %d/%d sessions]\n', ...
    p_diff, sum(slope_OL(valid) > slope_CL(valid)), nV);

% ---- pooled top-quartile companion ----
qedg = quantile(pool_mot, [0 .25 .5 .75 1]);
qbin = discretize(pool_mot, qedg); qbin(isnan(qbin)) = 4;
topQ = qbin == 4;
ol_top = pool_zmse(topQ & pool_lbl==0);
cl_top = pool_zmse(topQ & pool_lbl==1);
p_topQ = ranksum(ol_top, cl_top);
fprintf('  Top motion quartile: OL z-MSE median %+.2f vs CL %+.2f, rank-sum p=%.2e\n', ...
    median(ol_top), median(cl_top), p_topQ);

% quartile means per condition
qmean_ol = arrayfun(@(b) mean(pool_zmse(qbin==b & pool_lbl==0)), 1:4);
qmean_cl = arrayfun(@(b) mean(pool_zmse(qbin==b & pool_lbl==1)), 1:4);
qsem_ol  = arrayfun(@(b) std(pool_zmse(qbin==b & pool_lbl==0))/sqrt(sum(qbin==b & pool_lbl==0)), 1:4);
qsem_cl  = arrayfun(@(b) std(pool_zmse(qbin==b & pool_lbl==1))/sqrt(sum(qbin==b & pool_lbl==1)), 1:4);

% ---- figure: quartile bars OL vs CL ----
PS = paperStyle(); setPaperDefaults();
figM = paperFig(6, 4); ax = gca; hold(ax,'on');
xq = 1:4; w = 0.35;
bar(ax, xq-w/2, qmean_ol, w, 'FaceColor', PS.col_ol, 'EdgeColor','none', 'DisplayName','Open loop');
bar(ax, xq+w/2, qmean_cl, w, 'FaceColor', PS.col_cl, 'EdgeColor','none', 'DisplayName','Closed loop');
errorbar(ax, xq-w/2, qmean_ol, qsem_ol, 'k', 'LineStyle','none','LineWidth',0.6,'HandleVisibility','off','CapSize',2);
errorbar(ax, xq+w/2, qmean_cl, qsem_cl, 'k', 'LineStyle','none','LineWidth',0.6,'HandleVisibility','off','CapSize',2);
set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'});
xlabel(ax,'Motion quartile (low \rightarrow high)','FontSize',6,'FontWeight','bold');
ylabel(ax,'Trial MSE (z, within session)','FontSize',6,'FontWeight','bold');
set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
% significance star on top quartile
yTop = max(qmean_ol(4)+qsem_ol(4), qmean_cl(4)+qsem_cl(4)) + 0.05;
if p_topQ < 1e-3, star='***'; elseif p_topQ<1e-2, star='**'; elseif p_topQ<0.05, star='*'; else, star='n.s.'; end
text(ax, 4, yTop, star, 'HorizontalAlignment','center','FontSize',7,'FontWeight','bold');
lgd = legend(ax,'Location','northwest'); paperLegend(lgd);

if isfolder('paper'), out='paper'; elseif isfolder(fullfile('..','paper')), out=fullfile('..','paper'); else, out='.'; end
if ~isfolder(fullfile(out,'images','figure4')), mkdir(fullfile(out,'images','figure4')); end
paperExport(figM, fullfile(out,'images','figure4','motion_mse_quartile_OLCL.pdf'));
