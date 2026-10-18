%% f4_motion_session_diag.m — Fig 4D motion: session-level vs pooled, per-session traces [F4MSD]
% Diagnostic (user 2026-10-18): "does CL performance improve with motion?" The 4D motion tile
% reports regularizability (CL slope) n.s.; earlier runs looked strong. This script puts the
% session-level and pooled-trial answers side by side and draws every session's OL/CL curve.
% Uses the SHARED pool (f4_row2_pool, 'mean' motion, 'peri' window) -> same trials as the panel.
% Requires: load_sessions.m (mouse, fields). Output: controller-analysis/_preview/ (PNG only).

assert(exist('mouse','var') && exist('fields','var'), '[F4MSD] run load_sessions.m first.');
[POOLs,~] = f4_row2_pool(mouse,fields,'mean','peri'); T = POOLs.motion;
us = unique(T.sess); nS = numel(us); PS = paperStyle();
colOL = PS.col_ol; colCL = PS.col_cl;

% ---- per session: within-session quartiles of motion (combined OL+CL edges), raw RMSE --------
qO = nan(nS,4); qC = qO; eO = qO; eC = qO; nO = qO; nC = qO; bO = nan(nS,1); bC = bO; lab = cell(nS,1);
zsf = @(v) (v-mean(v,'omitnan'))./std(v,'omitnan');
Tz = T; Tz.zx = nan(height(T),1); Tz.zy = Tz.zx;
for i = 1:nS
    m = T.sess==us(i); x = T.x(m); y = T.y(m); cl = T.cond(m)=='CL';
    e = quantile(x,[0 .25 .5 .75 1]); e(1) = -inf; e(end) = inf; q = discretize(x,e);
    for b = 1:4
        a = y(q==b & ~cl); c = y(q==b & cl);
        qO(i,b) = mean(a); eO(i,b) = std(a)/sqrt(numel(a)); nO(i,b) = numel(a);
        qC(i,b) = mean(c); eC(i,b) = std(c)/sqrt(numel(c)); nC(i,b) = numel(c);
    end
    p = polyfit(zsf(x(~cl)),y(~cl),1); bO(i) = p(1);        % %dF/F RMSE per SD motion
    p = polyfit(zsf(x(cl)), y(cl), 1); bC(i) = p(1);
    Tz.zx(m) = zsf(x); Tz.zy(m) = zsf(y);
    lab{i} = sprintf('s%d %s', us(i), strrep(char(T.mouse(find(m,1))),'AL_',''));
end

% ---- stats ------------------------------------------------------------------------------------
fprintf('\n[F4MSD] motion: %d trials, %d sessions\n', height(T), nS);
fprintf('  per-session CL slope (RMSE per SD motion): median %+.3f, %d/%d negative, signrank p=%.3g\n', ...
    median(bC), nnz(bC<0), nS, signrank(bC));
fprintf('  per-session OL slope: median %+.3f, %d/%d positive, signrank p=%.3g\n', median(bO), nnz(bO>0), nS, signrank(bO));
fprintf('  OL slope > CL slope in %d/%d sessions, signrank p=%.3g\n', nnz(bO>bC), nS, signrank(bO,bC));
% pooled-trial OLS (ignores session; the "pooled" view) on within-session z
for cc = ["OL","CL"]
    k = Tz.cond==cc; mdl = fitlm(Tz.zx(k), Tz.zy(k));
    fprintf('  POOLED trial OLS %s: slope %+.3f (z/z), t(%d)=%.2f, p=%.3g\n', cc, mdl.Coefficients.Estimate(2), ...
        mdl.DFE, mdl.Coefficients.tStat(2), mdl.Coefficients.pValue(2));
end
k = Tz.cond=="CL"; e = quantile(Tz.zx(k),[0 .25 .5 .75 1]); e([1 end]) = [-inf inf];
qq = discretize(Tz.zx(k),e); yy = Tz.zy(k);
fprintf('  POOLED CL Q1..Q4 mean z-RMSE: %s; Q4 vs Q1 ranksum p=%.3g\n', ...
    sprintf('%+.2f ', arrayfun(@(b) mean(yy(qq==b)),1:4)), ranksum(yy(qq==4),yy(qq==1)));
% session-aware LMM, CL reference (the panel's regularizability) with and without random slope
Tl = T; Tl.cond = categorical(Tl.cond,{'CL','OL'}); Tl.xw = nan(height(Tl),1);
for i = 1:nS, m = Tl.sess==us(i); Tl.xw(m) = zsf(Tl.x(m)); end
Tl.sess = categorical(Tl.sess); Tl.mouse = categorical(Tl.mouse);
fm = {'y ~ cond*xw + (1+cond|sess) + (1|mouse)', ...
      'y ~ cond*xw + (1+cond|sess) + (xw-1|sess) + (1|mouse)'};
for f = 1:2
    L = fitlme(Tl, fm{f}, 'FitMethod','REML');
    [~,~,st] = fixedEffects(L,'DFMethod','satterthwaite'); r = strcmp(st.Name,'xw');
    fprintf('  LMM %-55s CL slope %+.3f p=%.3g (df %.1f)\n', fm{f}, st.Estimate(r), st.pValue(r), st.DF(r));
end

% ---- figure: one tile per session + slope summary --------------------------------------------
fig = figure('Color','w','Units','centimeters','Position',[2 2 24 13]);
tl = tiledlayout(fig,3,5,'TileSpacing','compact','Padding','compact');
for i = 1:nS
    ax = nexttile(tl); hold(ax,'on');
    errorbar(ax,(1:4)-0.06,qO(i,:),eO(i,:),'-o','Color',colOL,'MarkerFaceColor',colOL,'MarkerSize',3,'LineWidth',1.2,'CapSize',0);
    errorbar(ax,(1:4)+0.06,qC(i,:),eC(i,:),'-o','Color',colCL,'MarkerFaceColor',colCL,'MarkerSize',3,'LineWidth',1.2,'CapSize',0);
    title(ax, sprintf('%s  n=%d/%d', lab{i}, sum(nO(i,:)), sum(nC(i,:))), 'FontSize',7, 'Interpreter','none');
    text(ax,0.03,0.97,sprintf('b_{OL}%+.2f  b_{CL}%+.2f',bO(i),bC(i)),'Units','normalized', ...
        'VerticalAlignment','top','FontSize',6);
    xlim(ax,[0.6 4.4]); set(ax,'XTick',1:4,'FontSize',6,'Box','off');
    if mod(i-1,5)==0, ylabel(ax,'RMSE (%\DeltaF/F)'); end
end
ax = nexttile(tl,[1 2]); hold(ax,'on');
plot(ax,[1 2],[bO bC]','-','Color',[0.6 0.6 0.6],'LineWidth',0.5);
scatter(ax,ones(nS,1),bO,14,colOL,'filled'); scatter(ax,2*ones(nS,1),bC,14,colCL,'filled');
yline(ax,0,'k-'); xlim(ax,[0.6 2.4]); set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontSize',6,'Box','off');
ylabel(ax,'RMSE slope per SD motion');
title(ax,sprintf('CL %d/%d neg, p=%.2f; OL>CL %d/%d, p=%.3f',nnz(bC<0),nS,signrank(bC),nnz(bO>bC),nS,signrank(bO,bC)),'FontSize',7);
xlabel(tl,'Motion quartile (within session)','FontSize',7);
title(tl,'Fig 4D motion: per-session OL (red) / CL (blue) RMSE by motion quartile, mean \pm trial SEM','FontSize',8);
out = fullfile(fileparts(mfilename('fullpath')),'_preview'); if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out,'f4_motion_session_diag.png'), 'Resolution',300);
fprintf('[F4MSD] -> %s\n', fullfile(out,'f4_motion_session_diag.png'));
