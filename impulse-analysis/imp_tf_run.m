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
%
% OUTPUT
%   paper/images/figure2/tf_shape_across_sessions.pdf   <- panel 2C-i
%   paper/images/figure2/tf_tau_forest.pdf              <- panel 2C-ii
%   TFRUN struct in the workspace (per-session fits + the combined numbers)
%   a console summary written in the words the caption needs
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
fprintf('\n[TFRUN] %d session-datasets:\n', nS);
for k = 1:nS
    fprintf('   %d  %-9s %-12s e%d\n', k, allExperiments(k).mn, allExperiments(k).td, allExperiments(k).en);
end

%% ---- (2) fit every session over the MATCHED amplitude range ---------------------------
% Why matched: h(t) is amp^2-weighted, and the sessions do not span the same drive range
% (AL_0033 0.5-4.9 V over 9 amps; AL_0041 e1 0.8-2.7 V over 4). An unrestricted fit would
% take AL_0033's time constants from its ~4 V responses and AL_0041's from ~2.7 V, so any
% tau difference could be an amplitude-range artefact rather than a session difference.
% Full-range fits are computed too, and reported as the secondary row.
opt = struct('maxPoles',3,'maxZeros',3,'maxDelay',0,'tFit_s',0.5, ...
             'per_amp_fit',true,'verbose',false,'ampRange',[],'nBoot',RUN_NBOOT);

fprintf('\n[TFRUN] full-range fits ...\n');
Sfull = cell(nS,1);
for k = 1:nS, Sfull{k} = imp_tf_fit_session(allExperiments(k), fs, tWin, opt); end
okF = cellfun(@(s) isfield(s,'ok') && s.ok, Sfull);
assert(any(okF), '[TFRUN] no session produced a usable fit.');

% Common amplitude window across the sessions that fitted.
lo = max(cellfun(@(s) min(s.ampFit), Sfull(okF)));
hi = min(cellfun(@(s) max(s.ampFit), Sfull(okF)));
if lo < hi
    fprintf('[TFRUN] matched amplitude range = [%.2f %.2f] V -- refitting ...\n', lo, hi);
    opt.ampRange = [lo hi];
    Smatch = cell(nS,1);
    for k = 1:nS, Smatch{k} = imp_tf_fit_session(allExperiments(k), fs, tWin, opt); end
    okM = cellfun(@(s) isfield(s,'ok') && s.ok, Smatch);
    if nnz(okM) < 2
        warning('[TFRUN] matched range left <2 usable sessions -- falling back to full range.');
        Sprim = Sfull;  primTag = 'full range';
    else
        Sprim = Smatch;  primTag = sprintf('matched range %.2f-%.2f V', lo, hi);
    end
else
    warning('[TFRUN] amplitude ranges do not overlap -- using full-range fits.');
    Sprim = Sfull;  Smatch = Sfull;  primTag = 'full range (no overlap)';
end

%% ---- (3) the two paper panels ---------------------------------------------------------
figs = imp_tf_paper_fig(Sprim, outDir, struct('tag','','export',RUN_EXPORT,'tmax_s',0.5));

%% ---- (4) the numbers the caption needs ------------------------------------------------
okP  = cellfun(@(s) isfield(s,'ok') && s.ok, Sprim);
idx  = find(okP);
tau1 = cellfun(@(s) s.tau(1), Sprim(okP));
sdW  = cellfun(@(s) ternNaN(isfield(s,'tauSD') && ~isempty(s.tauSD), @() s.tauSD(1)), Sprim(okP));
mice = unique(cellfun(@(s) string(s.mn), Sprim(okP)));

fprintf('\n=========================== [TFRUN] SUMMARY (%s) ===========================\n', primTag);
fprintf('%-26s %8s %8s %18s %7s %7s\n','session','order','tau1 (s)','95%% CI','R2pool','LOAO');
for j = 1:numel(idx)
    s = Sprim{idx(j)};
    ci = '        --        ';
    if isfield(s,'tauCI') && ~isempty(s.tauCI)
        ci = sprintf('[%6.3f %6.3f]', s.tauCI(1), s.tauCI(2));
    end
    fprintf('%-26s %4dp%dz %8.3f %18s %7.3f %7.3f\n', s.label, s.np, s.nz, s.tau(1), ci, ...
        pickNum(s,'R2_pool'), mean(s.R2_loao,'omitnan'));
end
sdB = std(tau1);  mW = mean(sdW,'omitnan');
fprintf('-------------------------------------------------------------------------------\n');
fprintf('tau1 across sessions : mean %.3f s,  between-session SD %.3f s\n', mean(tau1), sdB);
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
               'sdBetween',sdB,'sdWithin',mW,'figs',figs,'outDir',outDir);
fprintf('\n[TFRUN] panels -> %s\n', outDir);

function v = ternNaN(c, f)
if c, v = f(); else, v = NaN; end
end
function v = pickNum(s, fld)
if isfield(s,fld) && ~isempty(s.(fld)), v = s.(fld); else, v = NaN; end
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
