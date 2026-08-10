%% imp_tf_run.m -- ONE command: fit the impulse TF everywhere, emit the Fig-2 panels.
%
% =====================================================================================
% WHAT THIS FIGURE IS FOR  (read this first -- it is the thing that keeps getting lost)
% =====================================================================================
% The whole paper rests on one engineering premise: **the cortex, driven by this laser,
% behaves like a low-order linear time-invariant plant.** That premise is what licenses
%   - designing a PI controller for it at all,
%   - the gain-grid / auto-tuning methods figure,
%   - and the claim that the step response and the impulse response are two views of
%     ONE system (impulse tau should match the OL step tau -- see the cross-area diagram
%     at the bottom of TASKS.md).
%
% Right now that premise is demonstrated on ONE session (AL_0033 2025-01-29). One
% session is an EXAMPLE, not a claim about a preparation. A referee reading "low-order
% LTI dynamics" will ask: in how many animals, and how much does tau move between them?
%
% So the figure has to answer exactly two questions, and nothing else:
%   (i)  Is the response the same SHAPE everywhere, and does a low-order linear model
%        reproduce it?                                    -> panel 2C-i (measured vs fit)
%   (ii) Is the time constant the same NUMBER everywhere, within uncertainty?
%                                                          -> panel 2C-ii (tau forest)
% If (i) and (ii) both hold, "the plant is low-order LTI" is a claim about the
% preparation. If tau varies wildly between sessions, that is ALSO publishable -- it
% just means the controller has to be robust to a plant that moves, which is a
% different (and more interesting) Methods story.
%
% Everything else the machinery computes -- gRatio, rho, LOAO, per-amplitude poles --
% are DIAGNOSTICS that tell you whether the fit is trustworthy. They belong in a
% supplementary figure and in the console, not in the main panel. That is why the
% 6-panel [TFX] dashboard is confusing as a paper figure: it is a workbench, and it
% was never meant to be read as one statement.
%
% =====================================================================================
% USAGE
%   load_experiments.m                 % the 3 original impulse sessions
%   imp_tf_run                         % <- this. everything else is automatic.
%
% Knobs (set before running; all optional):
%   RUN_AL0048   include the AL_0048 inhibitory site as a 4th session   [default true]
%   RUN_NBOOT    bootstrap draws for the tau CIs                        [default 300]
%   RUN_EXPORT   write the PDFs                                         [default true]
%   RUN_MATCHED  ALSO fit a matched-amplitude-range set as a SECONDARY  [default false]
%                diagnostic. Off by default: restricting every session to the
%                window they all share is set by the NARROWEST session, and it
%                silently drops any session left with <2 amplitudes in range.
%                All fits use ALL amplitudes -- h(t) is amplitude-normalised, so
%                the amplitudes are already on a common scale.
%
% OUTPUT -- all into paper/images/figure2/
%   tf_shape_across_sessions.pdf   2C-i   measured vs fit, all sessions (6x4)
%   tf_tau_forest.pdf              TF-A   tau + bootstrap CI per session   (4x4)
%   tf_tau_variability.pdf         TF-B   between- vs within-session SD    (4x4)
%   tf_tau_vs_amp.pdf              TF-C   does tau move with drive?        (5x4)
%   tf_model_swap.pdf              TF-D   cross-session model-swap R^2     (4.5x4)
%   TFRUN struct in the workspace (per-session fits + the combined numbers)
%   a console summary written in the words the caption needs
%
% TF-A..D make a ROBUSTNESS argument rather than a sameness argument: each session
% gets its own controller anyway, so what has to hold is that each plant is LTI over
% its own operating range (TF-C) and that the plant family is tight enough for a
% design to transfer (TF-D). See imp_tf_robust_fig.m for the full reasoning.
% =====================================================================================

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('[TFRUN] run load_experiments.m first.');
end
if ~exist('RUN_AL0048','var') || isempty(RUN_AL0048), RUN_AL0048 = true;  end
if ~exist('RUN_NBOOT','var')  || isempty(RUN_NBOOT),  RUN_NBOOT  = 300;   end
if ~exist('RUN_EXPORT','var') || isempty(RUN_EXPORT), RUN_EXPORT = true;  end
if ~exist('fs','var')   || isempty(fs),   fs   = 35;  end
if ~exist('tWin','var') || isempty(tWin), tWin = 3.0; end

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(fullfile(root,'utils'));
outDir = fullfile(root,'paper','images','figure2');
rng(3,'twister');                     % reproducible trial bootstrap

%% ---- (1) session set -----------------------------------------------------------------
% AL_0048 is appended by its own loader because it is a Signals experiment that
% `loadData` cannot open (no input_params/states/params). BLI.SITES defaults to {'R'}
% = the INHIBITORY site only, matching the rest of the impulse set.
if RUN_AL0048 && ~any(arrayfun(@(A) contains(A.mn,'AL_0048'), allExperiments))
    fprintf('[TFRUN] appending AL_0048 (inhibitory site) ...\n');
    try
        run(fullfile(here,'load_bilateral_impulse.m'));
    catch ME
        % fprintf(2,...) rather than warning(): the analyzer rejects passing ME.message
        % to warning() without an identifier, and this still lands in red on the console.
        fprintf(2, ['[TFRUN] AL_0048 could not be loaded -- continuing without it.\n' ...
                    '        Reason: %s\n'], ME.message);
    end
end
nS = numel(allExperiments);
fprintf('\n[TFRUN] %d session-datasets registered:\n', nS);
for k = 1:nS
    sTag = '';
    if isfield(allExperiments,'site') && ~isempty(allExperiments(k).site)
        sTag = sprintf('  site %s', allExperiments(k).site);
    end
    fprintf('   %d  %-9s %-12s e%d%s\n', k, allExperiments(k).mn, allExperiments(k).td, ...
        allExperiments(k).en, sTag);
end
% Say plainly whether the 4th session made it in. "Only 3 sessions" must never be
% something you have to infer by counting rows.
if RUN_AL0048
    if any(arrayfun(@(A) contains(A.mn,'AL_0048'), allExperiments))
        fprintf('[TFRUN] AL_0048 present. Expected set = 4 session-datasets.\n');
    else
        fprintf(2,['[TFRUN] AL_0048 IS MISSING -- this run is 3 sessions, not 4.\n' ...
                   '        Check the [BLI] output above. Most likely: the hand-drawn ROI for\n' ...
                   '        this mouse does not exist yet (TASKS: "Draw ONE ROI for AL_0048"),\n' ...
                   '        or the lab share is unreachable.\n']);
    end
end

%% ---- (2) fit every session over ALL of its amplitudes ----------------------------------
% ALL AMPLITUDES, EVERY SESSION (user, 2026-08-10). h(t) is built from amplitude-NORMALISED
% responses (DF/uA), so every amplitude is already on a common scale and there is nothing to
% equalise by throwing data away.
%
% ⚠ WHY THE MATCHED-RANGE REFIT WAS REMOVED, not just switched off. It restricted every
% session to the amplitude window they all share, and that window is set by the NARROWEST
% session. AL_0048 fires at 0.4 / 1.0 / 1.6 V, so adding it collapses the common window to
% roughly [0.8, 1.6] V -- and `imp_tf_fit_session` returns ok=false for any session left with
% fewer than 2 amplitudes in range. The refit was therefore SILENTLY DROPPING sessions, which
% is exactly how a 4-session run reported 3. Adding a session must never remove one.
%
% The confound it was defending against (h is amp^2-weighted, so an unrestricted fit takes
% AL_0033's time constants from its ~4 V responses and AL_0041's from ~2.7 V) is real, but it
% is now DISPLAYED rather than controlled away: panel TF-C plots tau from per-amplitude refits,
% so any amplitude dependence of the dynamics is visible on the figure. Showing it beats
% hiding it behind a restriction that costs data and sessions.
%
% Set RUN_MATCHED = true to compute the matched-range fits as a SECONDARY diagnostic. They
% never become the primary set.
if ~exist('RUN_MATCHED','var') || isempty(RUN_MATCHED), RUN_MATCHED = false; end

opt = struct('maxPoles',3,'maxZeros',3,'maxDelay',0,'tFit_s',0.5, ...
             'per_amp_fit',true,'verbose',true,'ampRange',[],'nBoot',RUN_NBOOT);

fprintf('\n[TFRUN] fitting %d sessions over ALL amplitudes ...\n', nS);
Sprim = cell(nS,1);
for k = 1:nS, Sprim{k} = imp_tf_fit_session(allExperiments(k), fs, tWin, opt); end
Sfull = Sprim;  primTag = 'all amplitudes';

% ---- session accounting: a dropped session must be LOUD, never inferred from a count ----
okF = cellfun(@(s) isfield(s,'ok') && s.ok, Sprim);
fprintf('\n[TFRUN] session accounting: %d registered -> %d fitted, %d DROPPED\n', ...
    nS, nnz(okF), nnz(~okF));
for k = 1:nS
    if okF(k)
        fprintf('   OK      %-26s  %d amps used, range %.2f-%.2f V\n', Sprim{k}.label, ...
            Sprim{k}.nAmpUsed, min(Sprim{k}.ampFit), max(Sprim{k}.ampFit));
    else
        fprintf(2,'   DROPPED %-26s  <- see the [TF] line above for the reason\n', ...
            sprintf('%s %s e%d', allExperiments(k).mn, allExperiments(k).td, allExperiments(k).en));
    end
end
assert(any(okF), '[TFRUN] no session produced a usable fit.');
if nnz(~okF) > 0
    fprintf(2,['[TFRUN] %d session(s) did not fit. Do NOT report the surviving count as the\n' ...
               '        dataset size without saying why the others dropped.\n'], nnz(~okF));
end

Smatch = {};
if RUN_MATCHED
    lo = max(cellfun(@(s) min(s.ampFit), Sprim(okF)));
    hi = min(cellfun(@(s) max(s.ampFit), Sprim(okF)));
    if lo < hi
        fprintf('\n[TFRUN] SECONDARY diagnostic: matched range [%.2f %.2f] V ...\n', lo, hi);
        optM = opt;  optM.ampRange = [lo hi];  optM.nBoot = 0;
        Smatch = cell(nS,1);
        for k = 1:nS, Smatch{k} = imp_tf_fit_session(allExperiments(k), fs, tWin, optM); end
        okM = cellfun(@(s) isfield(s,'ok') && s.ok, Smatch);
        fprintf('[TFRUN] matched-range fits usable in %d/%d sessions (primary set is unaffected).\n', ...
            nnz(okM), nS);
    else
        fprintf(2,'[TFRUN] amplitude ranges do not overlap -- matched diagnostic skipped.\n');
    end
end

%% ---- (3) the paper panels --------------------------------------------------------------
% 2C-i  : shape overlay, measured vs fit, all sessions.
% TF-A..D : the time-constant / variability / robustness block (see imp_tf_robust_fig).
figs = imp_tf_paper_fig(Sprim, outDir, struct('tag','','export',RUN_EXPORT,'tmax_s',0.5));
RB   = imp_tf_robust_fig(Sprim, outDir, struct('tag','','export',RUN_EXPORT,'amp_norm',true));

%% ---- (4) the numbers the caption needs ------------------------------------------------
okP  = cellfun(@(s) isfield(s,'ok') && s.ok, Sprim);
idx  = find(okP);
% pickTau, not s.tau(1): tau is empty whenever the selected model has no stable pole
% (tau = -1/Re(p) is only taken over poles with Re(p) < 0), so a marginally-stable or
% unstable fit would crash the summary rather than report itself as NaN.
tau1 = cellfun(@pickTau, Sprim(okP));
sdW  = cellfun(@(s) ternNaN(isfield(s,'tauSD') && ~isempty(s.tauSD), @() s.tauSD(1)), Sprim(okP));
% UniformOutput=false then concatenate: cellfun's uniform mode is fussy about string
% scalars across releases, and this cannot silently return the wrong shape.
mnAll = cellfun(@(s) string(s.mn), Sprim(okP), 'UniformOutput', false);
mice  = unique([mnAll{:}]);

fprintf('\n=========================== [TFRUN] SUMMARY (%s) ===========================\n', primTag);
fprintf('%-26s %8s %8s %18s %7s %7s\n','session','order','tau1 (s)','95%% CI','R2pool','LOAO');
for j = 1:numel(idx)
    s = Sprim{idx(j)};
    ci = '        --        ';
    if isfield(s,'tauCI') && ~isempty(s.tauCI)
        ci = sprintf('[%6.3f %6.3f]', s.tauCI(1), s.tauCI(2));
    end
    fprintf('%-26s %4dp%dz %8.3f %18s %7.3f %7.3f\n', s.label, s.np, s.nz, pickTau(s), ci, ...
        pickNum(s,'R2_pool'), mean(pickVec(s,'R2_loao'),'omitnan'));
end
sdB = std(tau1,'omitnan');  mW = mean(sdW,'omitnan');
fprintf('-------------------------------------------------------------------------------\n');
fprintf('tau1 across sessions : mean %.3f s,  between-session SD %.3f s\n', mean(tau1,'omitnan'), sdB);
if any(~isfinite(tau1))
    fprintf('  !! %d of %d sessions returned NO STABLE POLE -- excluded from the tau stats above.\n', ...
        nnz(~isfinite(tau1)), numel(tau1));
end
fprintf('mean within-session bootstrap SD  : %.3f s\n', mW);
if isfinite(mW) && mW > 0
    fprintf('between/within ratio : %.2f   -> %s\n', sdB/mW, verdictRatio(sdB/mW));
end
fprintf('n = %d session-datasets from %d MICE (%s)\n', numel(idx), numel(mice), strjoin(cellstr(mice),', '));
fprintf(['\nCAPTION MUST STATE: AL_0041 e1/e2 are the SAME animal, so the between-session\n' ...
         'spread mixes within- and between-animal variability. AL_0048 is inhibitory-side\n' ...
         'only and its readout sits ~2.6 mm from the illuminated spot, so it measures a\n' ...
         'CONNECTED region -- flag it if this panel backs an actuator-TF claim.\n']);

TFRUN = struct('Sprim',{Sprim},'Sfull',{Sfull},'primTag',primTag,'tau1',tau1, ...
               'sdBetween',sdB,'sdWithin',mW,'figs',figs,'robust',RB,'outDir',outDir);
fprintf('\n[TFRUN] panels -> %s\n', outDir);

function v = ternNaN(c, f)
if c, v = f(); else, v = NaN; end
end
function v = pickNum(s, fld)
if isfield(s,fld) && ~isempty(s.(fld)), v = s.(fld); else, v = NaN; end
end
function v = pickVec(s, fld)
if isfield(s,fld) && ~isempty(s.(fld)), v = s.(fld); else, v = NaN; end
end
function t = pickTau(s)
% Slowest time constant, or NaN when the model has no stable pole.
if isfield(s,'tau') && ~isempty(s.tau), t = s.tau(1); else, t = NaN; end
end
function s = verdictRatio(r)
if r < 1.5
    s = 'consistent with ONE shared time constant';
elseif r < 3
    s = 'mild inter-session variability';
else
    s = 'GENUINE inter-session variability -- report tau as a range, not a value';
end
end
