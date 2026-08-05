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
tfxOpts = struct('maxPoles',3, ...   % sweep 1..3. 4p lets AIC overfit the clean ipsi trace.
                 'maxZeros',3, ...   % nz < np enforced -> strictly proper -> h(0)=0
                 'maxDelay',0, ...   % onset frame IS t=0; no dead time
                 'tFit_s',0.5, ...   % post-onset fit window (s)
                 'per_amp_fit',true, ...
                 'verbose',true);

addpath(fullfile(fileparts(mfilename('fullpath')),'..','utils'));

fprintf('\n================ [TFX] impulse LTI model across %d sessions ================\n', numel(TFX_SEL));
S = cell(numel(TFX_SEL),1);
for k = 1:numel(TFX_SEL)
    S{k} = imp_tf_fit_session(allExperiments(TFX_SEL(k)), fs, tWin, tfxOpts);
end
okS = cellfun(@(s) isfield(s,'ok') && s.ok, S);
if ~any(okS), error('[TFX] no session produced a usable fit.'); end

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

% agreement of the slowest time constant across sessions -- the "do the dynamics replicate" number
tau1 = nan(numel(S),1);
for k = 1:numel(S), if okS(k) && ~isempty(S{k}.tau), tau1(k) = S{k}.tau(1); end, end
if nnz(isfinite(tau1)) >= 2
    fprintf('   --> slowest tau across sessions: %s ms  (mean %.1f, CV %.2f)\n', ...
        mat2str(round(1000*tau1(isfinite(tau1)).',1)), 1000*mean(tau1,'omitnan'), ...
        std(tau1,'omitnan')/max(mean(tau1,'omitnan'),eps));
    fprintf('       CV is the agreement statistic: small => the preparation has one characteristic\n');
    fprintf('       time constant; large => the "low-order LTI" claim is session-specific.\n');
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

ax2 = subplot(2,3,2); hold(ax2,'on'); box(ax2,'on');       % time constants
for k = 1:numel(S)
    if ~okS(k) || isempty(S{k}.tau), continue; end
    tt = 1000*S{k}.tau(:);
    plot(ax2, k*ones(numel(tt),1), tt, 'o', 'Color', cS(k,:), 'MarkerFaceColor', cS(k,:), 'MarkerSize',7);
end
set(ax2,'XTick',1:numel(S),'XTickLabel',cellfun(@(s)s.label(1:min(7,end)), S, 'uni',0),'FontSize',7);
ylabel(ax2,'time constant (ms)'); title(ax2,'poles \rightarrow \tau per session','FontSize',9,'FontWeight','bold');

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

TFX = struct('sessions',{S},'ok',okS,'sel',TFX_SEL,'primary',TFX_PRIMARY,'opts',tfxOpts);
fprintf('[TFX] -> TFX struct (per-session models + amplitude/shape/LOAO scores).\n');
