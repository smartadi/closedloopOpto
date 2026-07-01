function cp_bleed_control(R)
% cp_bleed_control — is the residual's state-dependence a BLEED artifact?
% ------------------------------------------------------------------------------
% The residual (local stim effect) is actual_ipsi - contra_prediction. Stim leaks
% ipsi->contra, so the contra PREDICTOR partly "sees" the stim and absorbs part of
% the local response. If that leakage (bleed) is itself brain-state-dependent, a
% state-modulated ABSORPTION could masquerade as a state-modulated LOCAL response,
% i.e. fake the headline (pre-stim var/delta -> weaker local gain). Two controls:
%
%   CONTROL A (bleed vs state, on stim trials, aligned to R.devL1 [PRIMARY DV]):
%     A1 coupling    corr(bleed, state)                 — is bleed itself state-dep?
%     A2 baseline    partial(gain, state | dev_pre)     — the headline number
%     A3 survival    partial(gain, state | dev_pre, bleed) — does it survive controlling bleed?
%     A4 interaction gain ~ state*bleed (standardized)  — does state act THROUGH bleed?
%   The confound is REJECTED when A1 is weak AND A3 ~ A2 (headline unchanged by bleed)
%   AND A4 interaction is n.s.
%
%   CONTROL B (catch-trial null, amp 0, no stim -> no local response, no bleed):
%     corr(residual dip energy, state)  should be NULL.
%     corr(bleed-axis activity, state)  diagnoses state-related contra activity absent stim.
%
% Needs R from cp_residual_core with R.bleed and R.catch (added 2026-07-01).
if ~isfield(R,'bleed') || ~isfield(R,'catch')
    error('cp_bleed_control: R lacks .bleed/.catch — re-run [CP-SETUP] with the updated cp_residual_core.');
end
S = {'PreVar', R.pv, R.okV, 'Pre-stim var (z)'; ...
     'PreDelta', R.dp, R.okD, 'Pre-stim \delta (z)'};
zf = @(x)(x-mean(x,'omitnan'))/max(std(x,'omitnan'),eps);

fprintf('\n[CP-BLEEDCTRL] %s %s e%d — is residual state-dep a bleed artifact?\n', R.mn, R.td, R.en);
fprintf('  (confound REJECTED if coupling weak, survival ~ baseline, interaction n.s.)\n');
res = struct();
for s = 1:2
    nm = S{s,1};  st = S{s,2};  ok = S{s,3} & isfinite(R.bleed);
    g = R.devL1(ok);  x = st(ok);  b = R.bleed(ok);  dP = R.devP(ok);   % DV = L1-dev (PRIMARY, swapped 2026-07-01)
    [rA1,pA1] = corr(b, x, 'type','Spearman','rows','complete');                 % bleed vs state
    [rA2,pA2] = partialcorr(g, x, dP,       'type','Spearman','rows','complete'); % baseline (headline)
    [rA3,pA3] = partialcorr(g, x, [dP b],   'type','Spearman','rows','complete'); % + bleed control
    mdl = fitlm([zf(x) zf(b) zf(x).*zf(b)], zf(g), ...
                'VarNames',{'state','bleed','state_x_bleed','L1dev'});
    bi  = mdl.Coefficients.Estimate(4);  pi_ = mdl.Coefficients.pValue(4);        % interaction
    fprintf('  %-8s  n=%d\n', nm, sum(ok));
    fprintf('     A1 bleed~state          rho=%+.3f p=%.2g   %s\n', rA1,pA1, verdict_weak(rA1,pA1));
    fprintf('     A2 L1dev~state|pre      rho=%+.3f p=%.2g   (headline)\n', rA2,pA2);
    fprintf('     A3 L1dev~state|pre,bleed rho=%+.3f p=%.2g   %s\n', rA3,pA3, verdict_surv(rA2,rA3,pA3));
    fprintf('     A4 state x bleed       beta=%+.3f p=%.2g   %s\n', bi,pi_, verdict_int(pi_));
    rej = (abs(rA1) < 0.10 || pA1 > 0.05) && (pA3 < 0.05 && abs(rA3) >= 0.6*abs(rA2));
    fprintf('     => %s\n', ternary(rej, ...
        'CONFOUND REJECTED: bleed not state-dep & effect survives bleed control (A4 is moderation, not mediation).', ...
        'CONFOUND NOT cleared: inspect A1/A3.'));
    res(s).nm=nm; res(s).rA1=rA1;res(s).pA1=pA1; res(s).rA2=rA2; res(s).rA3=rA3;res(s).pA3=pA3; res(s).bi=bi;res(s).pi=pi_;
    res(s).x=x; res(s).b=b; res(s).xlab=S{s,4};
end

% ---- Control B: catch-trial null --------------------------------------------
C = R.catch;  okc = isfinite(C.res);
[rcv,pcv] = corr(C.res(okc), C.pv(okc), 'type','Spearman','rows','complete');
[rcd,pcd] = corr(C.res(okc), C.dp(okc), 'type','Spearman','rows','complete');
okb = isfinite(C.bleed);
[rbv,~]   = corr(C.bleed(okb), C.pv(okb), 'type','Spearman','rows','complete');
[rbd,~]   = corr(C.bleed(okb), C.dp(okb), 'type','Spearman','rows','complete');
fprintf('  CATCH (amp0, n=%d, no stim):  res~var rho=%+.3f p=%.2g | res~delta rho=%+.3f p=%.2g   %s\n', ...
        C.n, rcv,pcv, rcd,pcd, verdict_weak(max(abs([rcv rcd])),min([pcv pcd])));
fprintf('     bleed-axis~state (catch):  var rho=%+.3f | delta rho=%+.3f (contra state activity absent stim)\n', rbv, rbd);

% ---- Figure -----------------------------------------------------------------
fig = paperFig(22, 12);
for s = 1:2
    ax1 = subplot(2,3,(s-1)*3+1); hold(ax1,'on');            % A1 bleed vs state
    scatter(ax1, res(s).x, res(s).b, 7, [0.5 0.5 0.5], 'filled','MarkerFaceAlpha',0.3);
    pc = polyfit(res(s).x,res(s).b,1); xl=[min(res(s).x) max(res(s).x)];
    plot(ax1, xl, polyval(pc,xl), 'r-','LineWidth',1.2);
    title(ax1, sprintf('bleed vs %s  \\rho=%+.2f p=%.2g', res(s).nm, res(s).rA1, res(s).pA1), 'FontSize',6,'FontWeight','bold');
    xlabel(ax1, res(s).xlab,'FontSize',6,'FontWeight','bold'); ylabel(ax1,'contra bleed (z)','FontSize',6,'FontWeight','bold');
    set(ax1,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');

    ax2 = subplot(2,3,(s-1)*3+2); hold(ax2,'on');            % A2 vs A3 partial bars
    bar(ax2, [1 2], [res(s).rA2 res(s).rA3], 0.6, 'FaceColor',[0.3 0.55 0.85],'EdgeColor','none');
    set(ax2,'XTick',[1 2],'XTickLabel',{'| pre','| pre,bleed'},'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    title(ax2, sprintf('%s partial(L1dev)  A4 int p=%.2g', res(s).nm, res(s).pi), 'FontSize',6,'FontWeight','bold');
    ylabel(ax2,'\rho','FontSize',6,'FontWeight','bold'); yline(ax2,0,'k-','LineWidth',0.4);

    ax3 = subplot(2,3,(s-1)*3+3); hold(ax3,'on');            % Control B catch null
    if s==1, cx = R.catch.pv; xlab='catch Pre-stim var (z)'; else, cx = R.catch.dp; xlab='catch Pre-stim \delta (z)'; end
    okc = isfinite(R.catch.res)&isfinite(cx);
    scatter(ax3, cx(okc), R.catch.res(okc), 7, [0.6 0.3 0.3],'filled','MarkerFaceAlpha',0.4);
    if sum(okc)>2, pc=polyfit(cx(okc),R.catch.res(okc),1); xl=[min(cx(okc)) max(cx(okc))]; plot(ax3,xl,polyval(pc,xl),'r-','LineWidth',1.2); end
    [rc,pcc]=corr(cx(okc),R.catch.res(okc),'type','Spearman','rows','complete');
    title(ax3, sprintf('CATCH null  \\rho=%+.2f p=%.2g', rc, pcc), 'FontSize',6,'FontWeight','bold');
    xlabel(ax3, xlab,'FontSize',6,'FontWeight','bold'); ylabel(ax3,'residual dip (\DeltaF/F %)','FontSize',6,'FontWeight','bold');
    set(ax3,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
end
sgtitle(fig, sprintf('CP-BLEEDCTRL  %s %s e%d  (col1 bleed~state | col2 L1dev partial ±bleed | col3 catch null)', ...
    R.mn, R.td, R.en), 'FontSize',6,'FontWeight','bold','Interpreter','tex');
paperExport(fig, fullfile(R.paper_root,'images','figure2','cp_bleed_control.png'));
fprintf('[CP-BLEEDCTRL] Exported cp_bleed_control.png\n');
end

% -- verdict helpers -----------------------------------------------------------
function s = verdict_weak(r,p)
if abs(r) < 0.08 || p > 0.05, s = '-> bleed NOT state-dep (good)'; else, s = '-> bleed IS state-dep (check A3)'; end
end
function s = verdict_surv(r2,r3,p3)
if p3 < 0.05 && abs(r3) > 0.6*abs(r2), s = '-> SURVIVES (not bleed-driven)'; else, s = '-> weakened by bleed control'; end
end
function s = verdict_int(p)
if p > 0.05, s = '-> no interaction (good)'; else, s = '-> state MODERATES bleed coupling (2ndary; not mediation)'; end
end
function s = ternary(c,a,b), if c, s=a; else, s=b; end, end
