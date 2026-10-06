function ctrl_mpc_fig3style(sess)
%CTRL_MPC_FIG3STYLE  Figure-3-style single-session comparison in the Fig-3 frame (rig online dF/F):
%   OL  = the RECORDED open-loop trials (separate trials; unpaired comparisons only)
%   CL  = the RECORDED closed-loop trials
%   CL+MPC  = the same CL trials replayed with preview-LQR in place of the PI (AR forecast, realistic)
%   CL+MPC* = same with a perfect preview (upper bound, faint)
%   Source: ctrl_mpc_lqr('frame','fig3','tag','_fig3',...) -- each CL trial's disturbance is its
%   recorded output minus the plant model's response to its recorded laser command.
%   Panels mirror Fig 3 A-E + ratio panels:
%     A single CL trial (recorded vs MPC replays) · B trial average +/-1 SD · C stimulation +/-1 SD
%     D variance across trials vs time · E per-trial RMSE (0-3 s) half-violins + medians
%     F/G variance and RMSE ratios vs CL by window (point estimates)
%   MPC rows are SIMULATION (model replay) -> no significance tests, stars or CIs anywhere (user 2026-10-06).
% OUT  paper/images/supp_mpc/f3s_*.png (working copies)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(fullfile(here,'..','utils'));
R = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)));
PS = paperStyle(); S = jnStyle(); rng(1);
iA = strcmp(R.modes,'x1.00'); iC = strcmp(R.modes,'x0.00');
Ys = {R.recOL, R.recCL, R.Y{iA}, R.Y{iC}};  Us = {R.recUOL, R.recUCL, R.U{iA}, R.U{iC}};
nm = {'OL','CL','CL+MPC','CL+MPC*'};
col = {PS.col_ol, PS.col_cl, [0.45 0.20 0.60], [0.80 0.65 0.90]};
tt = R.tt; ref = R.P.ref; nT = size(R.yPI,2); Wbig = 8.9; Wsm = 3.4; H = 3.4;
rm = @(Y, m) sqrt(mean((Y(m,:) - ref).^2, 1)).';     % per-trial RMSE over mask m
w03 = tt>=0 & tt<=3; w01 = tt>=0 & tt<1; w13 = tt>=1 & tt<=3;
RMc = cellfun(@(Y) rm(Y,w03), Ys, 'uni', 0);          % {OL (nOL), CL, MPC, MPC*} (CL-paired = 2..4)
RMp = [RMc{2:4}];

%% A single CL trial: recorded vs MPC replays (OL is a separate trial -> not shown) ----------
[~,k] = min(sum(abs(log(RMp ./ median(RMp))), 2));
fig = jnFig(Wbig, H); ax = axes(fig); hold(ax,'on');
plot(ax,[0 3],[ref ref],'--k','LineWidth',S.lw_ref);
h = gobjects(1,4); for c = [4 2 3], h(c) = plot(ax,tt,Ys{c}(:,k),'-','Color',col{c},'LineWidth',S.lw_mean); end
finish(ax,'\DeltaF/F (%)'); title(ax, sprintf('CL trial #%d: recorded vs MPC replay', k));
lg = legend(ax,h(2:4),nm(2:4),'Box','off','Location','northeast','NumColumns',3,'FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
paperExport(fig, fullfile(figDir,'f3s_A_single_trial.png'));

%% B trial average +/- 1 SD ----------------------------------------------------------------
fig = jnFig(Wbig, H); ax = axes(fig); hold(ax,'on');
plot(ax,[0 3],[ref ref],'--k','LineWidth',S.lw_ref);
for c = 1:3, band(ax, tt, Ys{c}, col{c}, PS.fa); end
for c = [4 1 2 3], h(c) = plot(ax,tt,mean(Ys{c},2),'-','Color',col{c},'LineWidth',S.lw_mean); end
finish(ax,'\DeltaF/F (%)'); title(ax,'trial average \pm1 SD');
lg = legend(ax,h,nm,'Box','off','Location','northeast','NumColumns',4,'FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
paperExport(fig, fullfile(figDir,'f3s_B_trial_average.png'));

%% C trial-average stimulation +/- 1 SD -------------------------------------------------------
fig = jnFig(Wbig, 3.0); ax = axes(fig); hold(ax,'on');
for c = 1:3, band(ax, tt, Us{c}, col{c}, PS.fa); end
for c = [4 1 2 3], plot(ax,tt,mean(Us{c},2),'-','Color',col{c},'LineWidth',PS.lw_inp); end
finish(ax,'laser command (a.u.)'); title(ax,'stimulation');
paperExport(fig, fullfile(figDir,'f3s_C_stimulation.png'));

%% D variance across trials vs time --------------------------------------------------------
fig = jnFig(Wsm, H); ax = axes(fig); hold(ax,'on');
for c = [4 1 2 3], plot(ax,tt,var(Ys{c},0,2),'-','Color',col{c},'LineWidth',S.lw_mean); end
finish(ax,'variance (%\DeltaF/F)^2'); title(ax,'across-trial variance');
paperExport(fig, fullfile(figDir,'f3s_D_variance.png'));

%% E per-trial RMSE half-violins + paired tests ---------------------------------------------
fig = jnFig(Wsm+1.6, H); ax = axes(fig); hold(ax,'on');
for c = 1:4
    v = RMc{c}; [f, yi] = ksdensity(v, 'Support','positive'); f = 0.38*f/max(f);
    fill(ax, c - [f fliplr(0*f)], [yi fliplr(yi)], col{c}, 'FaceAlpha',0.5,'EdgeColor','none');
    scatter(ax, c + 0.08 + 0.18*rand(numel(v),1), v, 3, col{c}, 'filled','MarkerFaceAlpha',0.5);
    plot(ax, c + [-0.3 0.3], median(v)*[1 1], '-k', 'LineWidth', 0.75);
end
% simulation (MPC replays are model output) -> descriptive only: medians, no tests / stars
for c = 1:4, fprintf('[F3S] RMSE %-7s median %.2f\n', nm{c}, median(RMc{c})); end
set(ax,'XTick',1:4,'XTickLabel',nm,'XTickLabelRotation',30); xlim(ax,[0.4 4.6]); ylim(ax,[0 max(cellfun(@max,RMc))*1.05]);
ylabel(ax,'RMSE (%\DeltaF/F), 0-3 s'); jnAxes(ax);
paperExport(fig, fullfile(figDir,'f3s_E_rmse_violin.png'));

%% F/G ratios vs CL by window (point estimates; descriptive) ---------------------------------
wins = {w01, w13}; wl = {'0-1 s','1-3 s'}; comp = [1 3 4];
VR = nan(3,2); RR = VR;                                        % comp x window
for iw = 1:2
    m = wins{iw};
    for ic = 1:3
        c = comp(ic);
        VR(ic,iw) = mean(var(Ys{c}(m,:),0,2)) / mean(var(Ys{2}(m,:),0,2));
        if c == 1, RR(ic,iw) = median(rm(Ys{1},m)) / median(rm(Ys{2},m));     % OL: separate trials
        else,      RR(ic,iw) = median(rm(Ys{c},m) ./ rm(Ys{2},m)); end          % MPC: replay of the same trial
        fprintf('[F3S] %-7s/CL %s: variance ratio %.2f | RMSE ratio %.2f\n', nm{c}, wl{iw}, VR(ic,iw), RR(ic,iw));
    end
end
ratioPanel(VR, 'variance / CL variance', 'f3s_F_variance_ratio.png');
ratioPanel(RR, 'RMSE / CL RMSE', 'f3s_G_rmse_ratio.png');
fprintf('[F3S] panels -> %s\n', figDir);

% ---- nested helpers ----------------------------------------------------------------------
    function finish(ax, yl)
        xlim(ax,[0 3]); xlabel(ax,'time from onset (s)'); ylabel(ax,yl); jnAxes(ax);
    end
    function ratioPanel(X, yl, fn)
        f = jnFig(5, 4); a = axes(f); hold(a,'on');
        plot(a,[0.5 2.5],[1 1],'-','Color',PS.col_cl,'LineWidth',S.lw_ref);
        off = [-0.22 0 0.22]; hh = gobjects(1,3);
        for j = 1:3
            c = comp(j);
            hh(j) = plot(a, (1:2)+off(j), X(j,:), 'o', 'Color', col{c}, 'MarkerFaceColor', col{c}, 'MarkerSize', S.marker+1, 'LineStyle','none');
        end
        set(a,'XTick',1:2,'XTickLabel',wl,'YScale','log'); xlim(a,[0.5 2.5]);
        yl2 = [min(X(:))*0.85, max(X(:))*2.4]; ylim(a, yl2);          % headroom on top for the legend
        tk = [0.25 0.5 0.75 1 1.5 2 3 4]; set(a,'YTick',tk(tk>=yl2(1) & tk<=yl2(2)),'YTickLabel',compose('%g',tk(tk>=yl2(1) & tk<=yl2(2))));
        ylabel(a, yl); text(a, 2.45, 1, 'CL', 'HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',S.fs_annot,'Color',PS.col_cl);
        lg2 = legend(a, hh, nm(comp), 'Box','off','Location','southwest','FontSize',S.fs_annot); lg2.ItemTokenSize = S.itemtoken;
        jnAxes(a); paperExport(f, fullfile(figDir, fn));
    end
end

function band(ax, t, Y, c, fa)
mu = mean(Y,2); sd = std(Y,0,2);
fill(ax, [t; flipud(t)], [mu-sd; flipud(mu+sd)], c, 'FaceAlpha', fa, 'EdgeColor','none');
end

