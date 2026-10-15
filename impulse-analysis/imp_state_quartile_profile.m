%% imp_state_quartile_profile.m -- FULL per-quartile profile of impulse prediction error vs state.
%
% (user, 2026-10-15) Fig 2G reports only Q4/Q1 and a linear slope. If the spread of the prediction
% error changes quartile-to-quartile WITHOUT a monotone trend (e.g. a step only in Q4), the slope
% undersells it. This reads the saved 2G stats and shows / tests all four quartiles.
%
% Reads  data/fig2g_state_stats.mat (STV_R, written by imp_state_trialvar.m). No data reload.
% DV     R.y = per-trial L2 prediction error (0-0.5 s) of the amplitude-mean predictor, scaled per
%        (session x amplitude) cell -- the same DV as 2G. R.sdRawNs / R.sdPNs = per-session,
%        per-quartile RMS of the response / stim-free control (session-normalised, ~1 = typical).
% Tests  per state:
%   KW    within each session, Kruskal-Wallis of trial errors across the 4 quartiles (trials are
%         independent WITHIN a session); session p's combined by Stouffer (one-sided not assumed).
%   FR    session level: Friedman on the 4 sessions x 4 quartiles RMS matrix (n=4, low power).
%   Q4    session level: t-test across sessions of log(RMS Q4 / mean RMS Q1..Q3).
%   CTRL  same Q4 contrast on response/control ratio -> does the quartile shape exceed the control?
%   VAR   (user 2026-10-15) VARIANCE of the per-trial error y within each quartile, per session,
%         with a 95% trial-bootstrap CI. Within-session Brown-Forsythe across quartiles (Stouffer);
%         session-level t on log(var Q4 / mean var Q1..Q3). Table -> imp_state_quartile_var.csv.
%         Stim only: the saved stats hold no per-trial control error.
%
% RUN:  imp_state_quartile_profile
% -------------------------------------------------------------------------------------------------

root = 'C:\Users\aditya\Documents\projects\brain_paper';
S = load(fullfile(root,'data','fig2g_state_stats.mat'));  R = S.STV_R;
outDir = fullfile(root,'paper','images','figure2');  if ~exist(outDir,'dir'), mkdir(outDir); end

nK = numel(R);  nB = size(R(1).sdRawNs,2);
cS = lines(4);  cStim = [0.15 0.35 0.75];  cCtl = [0.5 0.5 0.5];
VT = table();
QP = [];

fig = figure('Color','w','Units','centimeters','Position',[2 2 34 6*nK]);
tl  = tiledlayout(fig, nK, 4, 'TileSpacing','compact','Padding','compact');
for k = 1:nK
    r = R(k);  uS = unique(r.sess(:)).';  nS = numel(uS);
    sd = r.sdRawNs;  sdP = r.sdPNs;  g = r.gbin(:);  y = r.y(:);  s = r.sess(:);

    % --- tests --------------------------------------------------------------------------------
    pKW = nan(nS,1);  zKW = nan(nS,1);
    for i = 1:nS
        m = s==uS(i) & g>0 & isfinite(y);
        pKW(i) = kruskalwallis(y(m), g(m), 'off');
        zKW(i) = norminv(1 - pKW(i));
    end
    pKWst = 1 - normcdf(sum(zKW)/sqrt(nS));
    pFR   = friedman(sd, 1, 'off');
    q4    = log(sd(:,end) ./ mean(sd(:,1:end-1),2));      [~,pQ4]  = ttest(q4);
    rr    = sd ./ sdP;
    q4c   = log(rr(:,end) ./ mean(rr(:,1:end-1),2));      [~,pQ4c] = ttest(q4c);
    qp = struct('name',r.name,'sd',sd,'sdP',sdP,'pKW',pKW,'pKWst',pKWst,'pFR',pFR, ...
                   'q4',exp(q4),'pQ4',pQ4,'q4c',exp(q4c),'pQ4c',pQ4c);
    fprintf(['[QP] %-20s RMS Q1..Q4 mean %s | ctrl %s\n' ...
             '     within-sess KW p %s  (Stouffer %.3g) | Friedman p %.3g\n' ...
             '     Q4/mean(Q1-3) per sess %s  p=%.3g | vs control %s  p=%.3g\n'], ...
            r.name, mat2str(mean(sd,1),3), mat2str(mean(sdP,1),3), mat2str(pKW.',2), pKWst, pFR, ...
            mat2str(exp(q4).',3), pQ4, mat2str(exp(q4c).',3), pQ4c);

    % --- (1) per-session quartile RMS, response vs control -------------------------------------
    ax = nexttile(tl); hold(ax,'on');
    for i = 1:nS, plot(ax, 1:nB, sd(i,:), '-', 'Color',[cS(i,:) 0.6], 'LineWidth',0.8); end
    plot(ax, 1:nB, mean(sd,1),  '-o', 'Color',cStim, 'LineWidth',2, 'MarkerFaceColor',cStim);
    plot(ax, 1:nB, mean(sdP,1), '--s','Color',cCtl,  'LineWidth',1.5,'MarkerFaceColor','w');
    yline(ax,1,':k');  xlim(ax,[0.6 nB+0.4]); xticks(ax,1:nB); xticklabels(ax,"Q"+(1:nB));
    ylabel(ax,'RMS error (x typical)');
    title(ax, {r.name, sprintf('within-sess KW p=%.2g | Friedman p=%.2g', pKWst, pFR)}, 'Interpreter','tex','FontSize',8);
    if k==1, legend(ax,[compose('S%d',1:nS) {'mean stim','mean ctrl'}],'Location','southwest','Box','off'); end

    % --- (2) response / control per quartile --------------------------------------------------
    ax = nexttile(tl); hold(ax,'on');
    for i = 1:nS, plot(ax, 1:nB, rr(i,:), '-', 'Color',[cS(i,:) 0.6], 'LineWidth',0.8); end
    plot(ax, 1:nB, mean(rr,1), '-o','Color','k','LineWidth',2,'MarkerFaceColor','k');
    yline(ax,1,':k'); xlim(ax,[0.6 nB+0.4]); xticks(ax,1:nB); xticklabels(ax,"Q"+(1:nB));
    ylabel(ax,'stim RMS / control RMS');
    title(ax, {sprintf('Q4 / Q1-3: stim %.2f (p=%.2g)', exp(mean(q4)), pQ4), ...
               sprintf('beyond control %.2f (p=%.2g)', exp(mean(q4c)), pQ4c)}, 'FontSize',8);

    % --- (3) trial-level error distribution per quartile, per session --------------------------
    ax = nexttile(tl); hold(ax,'on');
    w = 0.18;
    for i = 1:nS
        for b = 1:nB
            v = y(s==uS(i) & g==b);  v = v(isfinite(v));  if isempty(v), continue; end
            q = prctile(v,[10 25 50 75 90]);  xc = b + (i-(nS+1)/2)*w;
            plot(ax,[xc xc],q([1 5]),'-','Color',cS(i,:));
            rectangle(ax,'Position',[xc-w/2.5 q(2) 2*w/2.5 q(4)-q(2)],'EdgeColor',cS(i,:),'FaceColor',[cS(i,:) 0.25]);
            plot(ax,xc+[-1 1]*w/2.5,[q(3) q(3)],'-','Color',cS(i,:),'LineWidth',1.5);
        end
    end
    xlim(ax,[0.4 nB+0.6]); xticks(ax,1:nB); xticklabels(ax,"Q"+(1:nB));
    ylabel(ax,'per-trial error (scaled)'); title(ax,{'trial errors per session','10/25/50/75/90th pct'},'FontSize',8);

    % --- (4) VARIANCE of trial error per quartile, per session, 95% bootstrap CI ---------------
    vv = nan(nS,nB);  vlo = vv;  vhi = vv;  nn = vv;  pBF = nan(nS,1);
    for i = 1:nS
        for b = 1:nB
            v = y(s==uS(i) & g==b);  v = v(isfinite(v));  nn(i,b) = numel(v);
            if numel(v) < 3, continue; end
            vv(i,b) = var(v);
            ci = bootci(2000, {@var, v}, 'Type','per');  vlo(i,b) = ci(1);  vhi(i,b) = ci(2);
        end
        m = s==uS(i) & g>0 & isfinite(y);
        pBF(i) = vartestn(y(m), g(m), 'TestType','BrownForsythe', 'Display','off');
    end
    zBF  = norminv(1 - max(pBF, realmin));  pBFst = 1 - normcdf(sum(zBF)/sqrt(nS));
    q4v  = log(vv(:,end) ./ mean(vv(:,1:end-1),2));  [~,pQ4v] = ttest(q4v);
    qp.var = vv;  qp.varCI = cat(3,vlo,vhi);  qp.pBF = pBF;  qp.pBFst = pBFst;
    qp.q4v = exp(q4v);  qp.pQ4v = pQ4v;
    fprintf('     VAR of trial error Q1..Q4 per sess:\n');
    for i = 1:nS
        fprintf('       S%d  %s   n %s   BF p=%.2g\n', i, mat2str(vv(i,:),3), mat2str(nn(i,:)), pBF(i));
    end
    fprintf('       Stouffer BF p=%.3g | Q4/Q1-3 var %s  p=%.3g\n', pBFst, mat2str(exp(q4v).',3), pQ4v);
    for i = 1:nS
        for b = 1:nB
            VT = [VT; table(string(r.name), i, b, nn(i,b), vv(i,b), vlo(i,b), vhi(i,b), pBF(i), ...
                  'VariableNames',{'state','session','quartile','n','var','ci_lo','ci_hi','pBF_sess'})]; %#ok<AGROW>
        end
    end

    QP = [QP qp]; %#ok<AGROW>
    ax = nexttile(tl); hold(ax,'on');
    for i = 1:nS
        xo = (1:nB) + (i-(nS+1)/2)*0.12;
        errorbar(ax, xo, vv(i,:), vv(i,:)-vlo(i,:), vhi(i,:)-vv(i,:), '-o', 'Color',cS(i,:), ...
                 'MarkerFaceColor',cS(i,:), 'MarkerSize',3, 'LineWidth',0.8, 'CapSize',2);
    end
    plot(ax, 1:nB, mean(vv,1), '-', 'Color','k', 'LineWidth',2);
    xlim(ax,[0.5 nB+0.5]); xticks(ax,1:nB); xticklabels(ax,"Q"+(1:nB));
    ylabel(ax,'variance of trial error');
    title(ax, {sprintf('variance per session (95%% CI) | BF p=%.2g', pBFst), ...
               sprintf('Q4 / Q1-3 var %.2f (p=%.2g)', exp(mean(q4v)), pQ4v)}, 'FontSize',8);
end
writetable(VT, fullfile(outDir,'imp_state_quartile_var.csv'));
title(tl, 'Impulse prediction error by state quartile (Fig 2G data, 4 sessions, 1516 trials)');
fn = fullfile(outDir,'imp_state_quartile_profile.png');
exportgraphics(fig, fn, 'Resolution', 300);
fprintf('[QP] saved %s\n', fn);
