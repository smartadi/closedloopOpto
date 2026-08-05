%% imp_tf_xsess.m -- fit the impulse LTI model on EVERY session and combine the statistics.
%
% WHAT THIS ANSWERS. Fig 2 currently rests on a transfer-function fit made on ONE session
% (selExp=3, AL_0033), and FINDINGS.md has carried "run across all 3 sessions and compare poles /
% time constants" as OPEN since 2026-05-08. "Low-order LTI dynamics" is a claim about the
% preparation; one session is an example, not a claim. This runs the same fit on all registered
% sessions and pools the statistics.
%
% It also splits the amplitude question out of the goodness-of-fit, which the single-session
% script does not do. tf_fit.m predicts amplitude a as uA(a)*h(t) and reports one R^2, so a
% response that is the right shape but the wrong SIZE and a response that is the wrong SHAPE both
% just lower R^2. Under LTI both are forbidden but they fail differently:
%     SHAPE   rho(a) = corr(y_a, h)              must be constant across amplitudes (time-invariance)
%     SIZE    gFree(a) = <y_a,h>/<h,h>           must be proportional to uA(a) (linearity)
% so both are reported per amplitude, per session, and combined. gRatio = gFree/uA is the headline
% amplitude-correctness curve: FLAT under LTI, falling where the response saturates.
%
% THREE TESTS OF LTI, in increasing strictness:
%   1. pooled R^2                one h(t) scaled by amplitude explains every amplitude
%   2. LOAO R^2                  h(t) fitted WITHOUT an amplitude still predicts it
%   3. per-amplitude poles       the time constants themselves do not move with amplitude
% A model can pass 1 and fail 3; that is the interesting case and it is why 3 is computed.
%
% USAGE
%   load_experiments.m      % builds allExperiments, fs, tWin
%   imp_tf_xsess            % this script -- no interactive steps, safe to run unattended
%
% Knobs below. Results land in the TFX struct; figures are PNG-only (not paper panels -- promote
% deliberately via PAPER.md if one earns a slot).
% -------------------------------------------------------------------------------------------------

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('[TFX] run load_experiments.m first (needs allExperiments, fs, tWin).');
end
if ~exist('fs','var')   || isempty(fs),   fs   = 35;  end
if ~exist('tWin','var') || isempty(tWin), tWin = 3.0; end

if ~exist('TFX_SEL','var')     || isempty(TFX_SEL),     TFX_SEL = 1:numel(allExperiments); end
if ~exist('TFX_PRIMARY','var') || isempty(TFX_PRIMARY)
    TFX_PRIMARY = find(arrayfun(@(A) contains(A.mn,'AL_0033'), allExperiments(TFX_SEL)), 1);
    if isempty(TFX_PRIMARY), TFX_PRIMARY = 1; end     % index INTO TFX_SEL
end
if ~exist('TFX_NBOOT','var')   || isempty(TFX_NBOOT),   TFX_NBOOT   = 300;  end   % trial bootstrap draws
if ~exist('TFX_MATCHED','var') || isempty(TFX_MATCHED), TFX_MATCHED = true; end   % common-range refit
tfxOpts = struct('maxPoles',3, ...   % sweep 1..3. 4p lets AIC overfit the clean ipsi trace.
                 'maxZeros',3, ...   % nz < np enforced -> strictly proper -> h(0)=0
                 'maxDelay',0, ...   % onset frame IS t=0; no dead time
                 'tFit_s',0.5, ...   % post-onset fit window (s)
                 'per_amp_fit',true, ...
                 'verbose',true, ...
                 'ampRange',[], ...
                 'nBoot',TFX_NBOOT);

addpath(fullfile(fileparts(mfilename('fullpath')),'..','utils'));
rng(3,'twister');                     % reproducible trial bootstrap

fprintf('\n================ [TFX] impulse LTI model across %d sessions ================\n', numel(TFX_SEL));
fprintf('FULL-RANGE fits (each session over its own amplitudes):\n');
S = cell(numel(TFX_SEL),1);
for k = 1:numel(TFX_SEL)
    S{k} = imp_tf_fit_session(allExperiments(TFX_SEL(k)), fs, tWin, tfxOpts);
end
okS = cellfun(@(s) isfield(s,'ok') && s.ok, S);
if ~any(okS), error('[TFX] no session produced a usable fit.'); end

%% ---- (0) MATCHED-RANGE refit: the only fair cross-session comparison --------------------------
% The sessions do not span the same drive range and h(t) is amp^2-weighted, so an unrestricted fit
% takes AL_0033's time constants from its 3.7-4.9 V responses and AL_0041's from ~2.7 V. Comparing
% those directly confounds session with amplitude range. Refit everything over the overlap.
SM = cell(numel(TFX_SEL),1);  commonRange = [];
if TFX_MATCHED
    lo = -inf; hi = inf;
    for k = 1:numel(TFX_SEL)
        u = allExperiments(TFX_SEL(k)).uAmp(:);  u = u(u > 0);
        if isempty(u), continue; end
        lo = max(lo, min(u));  hi = min(hi, max(u));
    end
    if isfinite(lo) && isfinite(hi) && hi > lo
        commonRange = [lo hi];
        fprintf('\nMATCHED-RANGE fits (common amplitude window %.2f-%.2f V, present in every session):\n', lo, hi);
        oM = tfxOpts;  oM.ampRange = commonRange;
        for k = 1:numel(TFX_SEL)
            SM{k} = imp_tf_fit_session(allExperiments(TFX_SEL(k)), fs, tWin, oM);
        end
    else
        fprintf('\n[TFX] no common amplitude window across these sessions -- matched refit skipped.\n');
    end
end
okM = cellfun(@(s) ~isempty(s) && isfield(s,'ok') && s.ok, SM);

%% ---- (1) model order + dynamics per session --------------------------------------------------
fprintf('\n[TFX-MODEL] selected order and dynamics per session\n');
fprintf('   %-24s %8s %10s %10s %10s %9s %9s\n','session','order','tau1 (ms)','tau2 (ms)','DC gain','R2 pool','n amps');
for k = 1:numel(S)
    if ~okS(k), fprintf('   %-24s   (no usable fit)\n', S{k}.label); continue; end
    s = S{k};  tag = '';  if k == TFX_PRIMARY, tag = '  <-- PRIMARY'; end
    t1 = NaN; t2 = NaN;
    if numel(s.tau) >= 1, t1 = 1000*s.tau(1); end
    if numel(s.tau) >= 2, t2 = 1000*s.tau(2); end
    fprintf('   %-24s %5dp%dz%dd %10.1f %10.1f %10.3f %9.3f %9d%s\n', ...
        s.label, s.np, s.nz, s.nd, t1, t2, s.dcgain, s.R2_pool, s.nAmpUsed, tag);
end

%% ---- (1b) DO THE DYNAMICS REPLICATE? between-session spread vs within-session uncertainty -----
% The decisive comparison, and the reason the bootstrap exists. Three sessions with three different
% tau values mean nothing on their own -- the question is whether they differ by MORE than the fit
% noise within each session. So:
%     between = SD of tau1 across sessions
%     within  = mean bootstrap SD of tau1 (trial resampling, order held fixed)
%     ratio   = between / within
% ratio ~ 1  -> the sessions are consistent with one shared time constant; report the pooled value.
% ratio >> 1 -> genuine inter-experiment variability; report the model FORM as general and the
%               parameter as session-specific, with the range.
% Reported for the matched-amplitude fits as PRIMARY (the like-for-like comparison) and for the
% full-range fits as secondary, because a difference in the latter can be an amplitude-range effect.
fprintf('\n[TFX-REPLICATE] does the slowest time constant replicate across sessions?\n');
sets = {'FULL range', S, okS; 'MATCHED range', SM, okM};
tau1F = nan(numel(S),1);  tau1M = nan(numel(S),1);
for si = 1:size(sets,1)
    lbl = sets{si,1};  SS = sets{si,2};  oo = sets{si,3};
    if ~any(oo), continue; end
    t1 = nan(numel(SS),1);  sd1 = nan(numel(SS),1);  ci1 = nan(numel(SS),2);
    for k = 1:numel(SS)
        if ~oo(k) || isempty(SS{k}.tau), continue; end
        t1(k) = SS{k}.tau(1);
        if isfield(SS{k},'tauSD') && ~isempty(SS{k}.tauSD), sd1(k) = SS{k}.tauSD(1); end
        if isfield(SS{k},'tauCI') && ~isempty(SS{k}.tauCI), ci1(k,:) = SS{k}.tauCI(1,:); end
    end
    if si == 1, tau1F = t1; else, tau1M = t1; end
    fprintf('   %s:\n', lbl);
    for k = 1:numel(SS)
        if ~isfinite(t1(k)), continue; end
        tag = '';  if k == TFX_PRIMARY, tag = '  <-- PRIMARY'; end
        if isfinite(ci1(k,1))
            fprintf('      %-24s tau1 = %6.1f ms  [95%% CI %6.1f  %6.1f]%s\n', ...
                SS{k}.label, 1000*t1(k), 1000*ci1(k,1), 1000*ci1(k,2), tag);
        else
            fprintf('      %-24s tau1 = %6.1f ms  (no CI)%s\n', SS{k}.label, 1000*t1(k), tag);
        end
    end
    if nnz(isfinite(t1)) >= 2
        btw = std(t1,'omitnan');  wth = mean(sd1,'omitnan');
        fprintf('      between-session SD %.1f ms | mean within-session (bootstrap) SD %.1f ms', 1000*btw, 1000*wth);
        if isfinite(wth) && wth > 0
            r = btw/wth;
            fprintf(' | ratio %.2f -> %s\n', r, ternstr_tfx(r < 1.5, ...
                'CONSISTENT with one shared time constant', 'genuine inter-experiment variability'));
        else
            fprintf(' | ratio n/a (no bootstrap)\n');
        end
        fprintf('      mean %.1f ms, range %.1f-%.1f ms, CV %.2f\n', 1000*mean(t1,'omitnan'), ...
            1000*min(t1), 1000*max(t1), std(t1,'omitnan')/max(mean(t1,'omitnan'),eps));
    end
end

% pairwise, non-parametric: fraction of bootstrap draws in which one session's tau exceeds another's
fprintf('\n[TFX-PAIRWISE] P(tau1_i > tau1_j) from the trial bootstrap (matched range where available)\n');
fprintf('   0.5 = indistinguishable; near 0 or 1 = the sessions really differ.\n');
SP = SM;  okP = okM;  if ~any(okM), SP = S; okP = okS; end
for i = 1:numel(SP)
    for j = i+1:numel(SP)
        if ~okP(i) || ~okP(j), continue; end
        if ~isfield(SP{i},'tauBoot') || isempty(SP{i}.tauBoot) || ...
           ~isfield(SP{j},'tauBoot') || isempty(SP{j}.tauBoot), continue; end
        bi = SP{i}.tauBoot(:,1);  bj = SP{j}.tauBoot(:,1);
        n  = min(numel(bi), numel(bj));
        v  = isfinite(bi(1:n)) & isfinite(bj(1:n));
        if nnz(v) < 20, continue; end
        p  = mean(bi(v) > bj(v));
        fprintf('   %-22s vs %-22s  P = %.3f%s\n', SP{i}.label, SP{j}.label, p, ...
            ternstr_tfx(p < 0.05 || p > 0.95, '  *', ''));
    end
end

%% ---- (2) amplitude correctness ---------------------------------------------------------------
% gRatio = gFree/uA. Under LTI this is flat at 1 (h was amplitude-normalised). A falling ratio is
% compression. Reported per amplitude, then summarised as the proportionality slope + the fraction
% of the amplitude range over which the ratio stays within tolerance of its low-amplitude value.
fprintf('\n[TFX-AMP] amplitude correctness: free gain vs commanded amplitude\n');
fprintf('   gRatio = gFree/amp (flat = linear).  rho = corr(response, h) = SHAPE agreement.\n');
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};
    fprintf('   %s   slope %.3f (R2 %.3f)\n', s.label, s.linSlope, s.linR2);
    fprintf('      %-8s','amp(V)');  fprintf('%7.2f', s.uA);  fprintf('\n');
    fprintf('      %-8s','gRatio');  fprintf('%7.2f', s.gRatio);  fprintf('\n');
    fprintf('      %-8s','rho');     fprintf('%7.2f', s.rho);     fprintf('\n');
    fprintf('      %-8s','R2 lti');  fprintf('%7.2f', s.R2);      fprintf('\n');
    fprintf('      %-8s','R2 free'); fprintf('%7.2f', s.R2free);  fprintf('\n');
    % where does proportionality break? first amplitude whose ratio drops below LIN_TOL of the
    % low-amplitude plateau (median of the lowest half of the amplitudes)
    v = isfinite(s.gRatio) & s.uA > 0;
    if nnz(v) >= 3
        uv = s.uA(v);  gv = s.gRatio(v);
        base = median(gv(uv <= median(uv)));
        brk = find(gv < 0.8*base & uv > median(uv), 1, 'first');
        if isempty(brk)
            fprintf('      --> proportional across the whole tested range (no >20%% drop)\n');
        else
            fprintf('      --> departs from proportional above ~%.2f V (gRatio %.2f vs plateau %.2f)\n', ...
                uv(max(brk-1,1)), gv(brk), base);
        end
    end
end

%% ---- (3) LOAO generalisation ------------------------------------------------------------------
fprintf('\n[TFX-LOAO] leave-one-amplitude-out: does h fitted WITHOUT an amplitude predict it?\n');
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};
    fprintf('   %s\n', s.label);
    fprintf('      %-8s','amp(V)');   fprintf('%7.2f', s.uA);       fprintf('\n');
    fprintf('      %-8s','R2 full');  fprintf('%7.2f', s.R2);       fprintf('\n');
    fprintf('      %-8s','R2 loao');  fprintf('%7.2f', s.R2_loao);  fprintf('\n');
    d = s.R2 - s.R2_loao;
    fprintf('      --> median full-minus-LOAO gap %.3f (large gap at strong amps => amplitude-dependent dynamics)\n', ...
        median(d,'omitnan'));
end

%% ---- (4) do the DYNAMICS move with amplitude? -------------------------------------------------
fprintf('\n[TFX-TAUAMP] per-amplitude refits: slowest time constant vs amplitude (ms)\n');
fprintf('   Constant => time-invariant. Systematic drift => not LTI in the amplitude dimension,\n');
fprintf('   even where the pooled R2 looks good. NaN = that amplitude''s own fit failed (low SNR).\n');
for k = 1:numel(S)
    if ~okS(k) || ~isfield(S{k},'tau_amp'), continue; end
    s = S{k};
    fprintf('   %s\n', s.label);
    fprintf('      %-8s','amp(V)'); fprintf('%8.2f', s.uA); fprintf('\n');
    fprintf('      %-8s','tau1');   fprintf('%8.1f', 1000*s.tau_amp(:,1)); fprintf('\n');
    tv = s.tau_amp(:,1);  gd = isfinite(tv) & s.uA > 0;
    if nnz(gd) >= 3
        rr = corr(s.uA(gd), tv(gd), 'type','Spearman');
        fprintf('      --> Spearman(tau1, amplitude) = %+.2f  (0 = time-invariant)\n', rr);
    end
end

%% ---- (5) combined figure ----------------------------------------------------------------------
figT = figure('Color','w','Name','[TFX] impulse LTI model across sessions','Position',[40 50 1400 760]);
cS = lines(max(numel(S),3));

ax1 = subplot(2,3,1); hold(ax1,'on'); box(ax1,'on');       % normalised h(t), all sessions
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};  hn = s.h/max(abs(s.h));
    plot(ax1, 1000*s.tPost, hn, '-', 'Color', cS(k,:), 'LineWidth', 1.6, 'DisplayName', s.label);
end
yline(ax1,0,'k:'); xlabel(ax1,'time from onset (ms)'); ylabel(ax1,'h(t), peak-normalised');
title(ax1,'fitted impulse response (shape)','FontSize',9,'FontWeight','bold');
legend(ax1,'Location','southeast','FontSize',6,'Box','off');

ax2 = subplot(2,3,2); hold(ax2,'on'); box(ax2,'on');       % tau forest: matched (filled) vs full (open)
% This is the panel that answers "do the dynamics replicate": per-session tau1 with a bootstrap CI,
% against a band for the cross-session mean +/- SD. Overlapping CIs => one shared time constant.
if any(okM)
    tm = 1000*tau1M(isfinite(tau1M));
    if numel(tm) >= 2
        yl = [mean(tm)-std(tm), mean(tm)+std(tm)];
        patch(ax2, [0.4 numel(S)+0.6 numel(S)+0.6 0.4], [yl(1) yl(1) yl(2) yl(2)], ...
              [0.85 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.5, 'HandleVisibility','off');
        yline(ax2, mean(tm), '-', 'Color',[0.45 0.45 0.45], 'LineWidth',1, 'HandleVisibility','off');
    end
end
for k = 1:numel(S)
    if okM(k) && ~isempty(SM{k}.tau)                                   % matched range = PRIMARY
        y = 1000*SM{k}.tau(1);
        if isfield(SM{k},'tauCI') && ~isempty(SM{k}.tauCI)
            plot(ax2, [k k]-0.12, 1000*SM{k}.tauCI(1,:), '-', 'Color', cS(k,:), 'LineWidth',1.4);
        end
        plot(ax2, k-0.12, y, 'o', 'Color', cS(k,:), 'MarkerFaceColor', cS(k,:), 'MarkerSize',7);
    end
    if okS(k) && ~isempty(S{k}.tau)                                    % full range = secondary
        y = 1000*S{k}.tau(1);
        if isfield(S{k},'tauCI') && ~isempty(S{k}.tauCI)
            plot(ax2, [k k]+0.12, 1000*S{k}.tauCI(1,:), '-', 'Color', cS(k,:), 'LineWidth',1.0);
        end
        plot(ax2, k+0.12, y, 'o', 'Color', cS(k,:), 'MarkerFaceColor','w', 'MarkerSize',6, 'LineWidth',1.1);
    end
end
xlim(ax2,[0.4 numel(S)+0.6]);
set(ax2,'XTick',1:numel(S),'XTickLabel',cellfun(@(s)s.label(1:min(7,end)), S, 'uni',0),'FontSize',7);
ylabel(ax2,'\tau_1 (ms)');
ttl2 = '\tau_1 per session (filled = matched range)';
if ~isempty(commonRange), ttl2 = sprintf('\\tau_1: matched %.1f-%.1f V (filled) vs full (open)', commonRange); end
title(ax2, ttl2, 'FontSize',9,'FontWeight','bold');

ax3 = subplot(2,3,3); hold(ax3,'on'); box(ax3,'on');       % AMPLITUDE CORRECTNESS: gFree vs amp
mx = 0;
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};  v = isfinite(s.gFree) & s.uA > 0;
    plot(ax3, s.uA(v), s.gFree(v), 'o-', 'Color', cS(k,:), 'MarkerFaceColor', cS(k,:), ...
         'LineWidth',1.3,'MarkerSize',5,'DisplayName',s.label);
    mx = max([mx; s.uA(v)]);
end
plot(ax3, [0 mx], [0 mx], 'k--', 'LineWidth',1, 'DisplayName','LTI (slope 1)');
xlabel(ax3,'commanded amplitude (V)'); ylabel(ax3,'free gain  <y,h>/<h,h>');
title(ax3,'AMPLITUDE CORRECTNESS','FontSize',9,'FontWeight','bold');
legend(ax3,'Location','northwest','FontSize',6,'Box','off');

ax4 = subplot(2,3,4); hold(ax4,'on'); box(ax4,'on');       % gRatio -> flat under LTI
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};  v = isfinite(s.gRatio) & s.uA > 0;
    plot(ax4, s.uA(v), s.gRatio(v), 'o-', 'Color', cS(k,:), 'MarkerFaceColor', cS(k,:), ...
         'LineWidth',1.3,'MarkerSize',5);
end
yline(ax4,1,'k--','LineWidth',1);
xlabel(ax4,'amplitude (V)'); ylabel(ax4,'gain / amplitude');
title(ax4,'proportionality (flat = linear)','FontSize',9,'FontWeight','bold');

ax5 = subplot(2,3,5); hold(ax5,'on'); box(ax5,'on');       % shape agreement vs amplitude
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};  v = isfinite(s.rho) & s.uA > 0;
    plot(ax5, s.uA(v), s.rho(v), 'o-', 'Color', cS(k,:), 'MarkerFaceColor', cS(k,:), ...
         'LineWidth',1.3,'MarkerSize',5);
end
ylim(ax5,[0 1]); xlabel(ax5,'amplitude (V)'); ylabel(ax5,'corr(response, h)');
title(ax5,'shape agreement (flat = time-invariant)','FontSize',9,'FontWeight','bold');

ax6 = subplot(2,3,6); hold(ax6,'on'); box(ax6,'on');       % full vs LOAO
for k = 1:numel(S)
    if ~okS(k), continue; end
    s = S{k};  v = isfinite(s.R2_loao);
    plot(ax6, s.uA(v), s.R2(v),      'o-', 'Color', cS(k,:), 'LineWidth',1.3,'MarkerFaceColor',cS(k,:),'MarkerSize',5);
    plot(ax6, s.uA(v), s.R2_loao(v), 's--','Color', cS(k,:), 'LineWidth',1.1,'MarkerSize',5);
end
ylim(ax6,[0 1]); xlabel(ax6,'amplitude (V)'); ylabel(ax6,'R^2');
title(ax6,'full (solid) vs LOAO (dashed)','FontSize',9,'FontWeight','bold');

sgtitle(figT, sprintf(['TFX  impulse LTI model, %d sessions  —  top: fitted dynamics.  ' ...
    'bottom: is the response the RIGHT AMPLITUDE and the RIGHT SHAPE at every drive level?'], ...
    nnz(okS)), 'FontWeight','bold','FontSize',10);

outDir = fullfile(fileparts(mfilename('fullpath')),'..','paper','images','figure2');
if ~exist(outDir,'dir'), outDir = fileparts(mfilename('fullpath')); end
outPng = fullfile(outDir, 'tfx_lti_across_sessions.png');
try
    exportgraphics(figT, outPng, 'Resolution', 300);
    fprintf('\n[TFX] figure -> %s\n', outPng);
catch ME
    fprintf('\n[TFX] figure export skipped (%s)\n', ME.message);
end

TFX = struct('sessions',{S},'ok',okS,'matched',{SM},'okMatched',okM,'commonRange',commonRange, ...
             'tau1_full',tau1F,'tau1_matched',tau1M, ...
             'sel',TFX_SEL,'primary',TFX_PRIMARY,'opts',tfxOpts,'nBoot',TFX_NBOOT);
fprintf('[TFX] -> TFX struct (full + matched-range models, tau CIs, amplitude/shape/LOAO scores).\n');

% ---- local helpers -------------------------------------------------------------------------------
function s = ternstr_tfx(c, a, b),  if c, s = a; else, s = b; end,  end
