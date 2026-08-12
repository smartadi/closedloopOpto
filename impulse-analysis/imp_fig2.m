%% imp_fig2.m -- CLEAN Figure-2 residual stream. Four sessions, one predictor, one question.
%
% WHAT THIS IS FOR (user, 2026-08-11). Find out whether the contra->ipsi OLS model is broken, by
% building the BEST possible ipsi predictor from NON-stim-affected contra pixels -- one that
% reconstructs the ipsi trace an unstimulated brain would have produced -- so that the residual
% carries the MAXIMAL local stim effect. Then test that residual against motion and delta.
%
% THE FIVE STAGES, in order, one struct handed to the next. No shared workspace state, no eval,
% no exist('x','var') guards, no interactive gate.
%   §1 LOAD    f2_prep     4 sessions -> P (geometry, spont operators, per-amp evoked)
%   §2 AFFECT  f2_affected confirmed stim-affected layout, one figure per session
%   §3 MODEL   f2_model    M4: pooled-unaffected px -> far-from-ipsi weighted-L2 -> greedy prune
%   §4 DECOMP  f2_decomp   Actual / Global / Local  + the CATCH control
%   §5 STATE   f2_state    motion + relative delta, with the GLOBAL negative control
%
% WHAT CHANGED FROM ols_tf_pipeline.m, and why it matters for the "is it broken?" question:
%  1. The regulariser is picked by MAXIMISING held-out SPONTANEOUS R^2 (a stim-free criterion),
%     not by minimising leak. §17c0 tuned on leak and then reported leak -- circular.
%  2. ONE definition of stim-affected: the confirmed TF detector mask. §18's separate energy-based
%     bledA path is not used at all.
%  3. A CATCH-TRIAL control runs the identical decomposition on no-stim windows. If those produce
%     a Local dip, the pipeline manufactures residual. This is the decisive broken-model test.
%  4. A TIME-SHIFT null on the predictor: if a shifted ipsi target is still "predicted", the R^2
%     is slow shared structure, not coupling.
%  5. A GLOBAL negative control on every state test: if Local and Global move together, the state
%     effect is leaking through the predictor rather than being local.
%  6. Hyperparameters are resolved ONCE on the primary session and FROZEN for the rest, so the
%     pooled result is one strategy applied to four sessions, not four tuned analyses pooled.
%
% MOTION (user, 2026-08-11: "using motion is not a problem"). Both variants are run: contra-only
% (primary -- keeps the motion state test unimpeachable) and contra+motion (the predictor-quality
% question). Adding motion removes an ADDITIVE motion->ipsi term; the state test asks about a GAIN
% on the stim response, so it is not circular -- but the contra-only result is the one to quote,
% with the augmented one as the robustness check. If the two agree, the objection is answered.
%
% RUN:  imp_fig2                          (loads sessions if absent; ~minutes on the first pass)
%       F2_SEL = 3; imp_fig2              (one session)
%       F2_USE_MOTION = false; imp_fig2   (skip the augmented variant)
%
% Detection is NOT re-implemented here. If a session has no confirmed selector decision, §2 errors
% with the exact command to produce one via the validated ols_tf_pipeline detector.
% --------------------------------------------------------------------------------------------------

%% [F2-0] paths, knobs, reproducibility
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';   % section-run fallback
end
impulseDir = here;  utilsDir = fullfile(impulseDir,'..','utils');
addpath(utilsDir); addpath(genpath(utilsDir));
F2_DATADIR = fullfile(impulseDir,'data');

if ~exist('F2_SEL','var'),        F2_SEL        = [];    end   % [] = every registered session
if ~exist('F2_USE_MOTION','var'), F2_USE_MOTION = true;  end   % also run the contra+motion variant
if ~exist('F2_BILATERAL','var'),  F2_BILATERAL  = true;  end   % append AL_0048 (inhibitory site)
if ~exist('F2_DV','var'),         F2_DV         = 'L1DEVz'; end% primary DV (see f2_state header)
% PREDICTOR SELECTION RULE. 'r2max' = pick the regulariser on held-out spontaneous R^2 alone; capture
% is then a pure MEASUREMENT. 'frontier' = maximise capture subject to R^2 >= F2_R2FLOOR (user
% request, 2026-08-11); capture becomes a FITTED TARGET and must be quoted from the held-out trial
% half, with f2_frontier's random-direction control beside it. Both are run and printed side by side
% so the price of the switch is always on the record.
if ~exist('F2_SELECT','var'),     F2_SELECT     = 'frontier'; end
if ~exist('F2_R2FLOOR','var'),    F2_R2FLOOR    = 0.85;  end
% F2_USE_AFFECT=false bypasses the TF detector and hands the FULL contra grid to the optimiser, so
% the leak penalty alone has to buy blindness. Diagnostic: compare the R^2 PRICE against the
% detector-gated run. Do not quote capture from it without that comparison.
if ~exist('F2_USE_AFFECT','var'), F2_USE_AFFECT = true;  end
% select_mode 'subspace': blindness to the WHOLE evoked response via an orthonormal basis V_k,
% so the rebound is penalised too and no window enters the fit. F2_NU sets k by variance explained.
if ~exist('F2_NU','var'),         F2_NU         = 0.90;  end
if ~exist('F2_SVW','var'),        F2_SVW        = false; end   % weight the basis by singular value
if ~exist('F2_KMAX','var'),       F2_KMAX       = [];    end   % hard cap on the subspace rank k
if ~exist('F2_PLOT','var'),       F2_PLOT       = true;  end
% Where the per-session FIT figures are written as 300-dpi PNGs. They are diagnostics, not paper
% panels, so PNG per the project export rule -- and written to disk because the thing you want to
% do with four of them is put them side by side, which you cannot do with four MATLAB windows.
if ~exist('F2_FITDIR','var'),     F2_FITDIR     = fullfile(impulseDir,'figs','fig2_fit'); end
% Reproducibility: the split-half trial permutation (§3 greedy control) and the random-exclusion
% control are seeded, so the affected set, the pruned set and the controls are identical run to run.
rng(7,'twister');

%% [F2-1] LOAD -- all four sessions
if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[F2] allExperiments absent -> load_experiments (reads SVD from the server; slow)\n');
    load_experiments
end
if F2_BILATERAL && ~any(arrayfun(@(A) strcmp(A.mn,'AL_0048'), allExperiments))
    fprintf('[F2] appending AL_0048 (inhibitory site) -> load_bilateral_impulse\n');
    load_bilateral_impulse
end
nSessAll = numel(allExperiments);
if isempty(F2_SEL), F2_SEL = 1:nSessAll; end
F2_SEL = F2_SEL(F2_SEL >= 1 & F2_SEL <= nSessAll);
% PRIMARY FIRST. The strategy (the regulariser) is resolved on the primary session and frozen for
% the rest, so the primary must be the session the project treats as primary (AL_0033), not
% whichever happens to sit at index 1.
iPrim = find(arrayfun(@(A) strcmp(A.mn,'AL_0033'), allExperiments(F2_SEL)), 1);
if ~isempty(iPrim), F2_SEL = [F2_SEL(iPrim), F2_SEL(F2_SEL ~= F2_SEL(iPrim))]; end
fprintf('\n[F2] %d session(s), primary first:\n', numel(F2_SEL));
for s = F2_SEL, fprintf('   %d  %s %s e%d\n', s, allExperiments(s).mn, allExperiments(s).td, allExperiments(s).en); end

%% [F2-2..4] per session: prep -> affected -> model -> decompose
F2      = struct('label',{},'caveat',{},'sel',{},'A',{},'M',{},'D',{},'Mmot',{},'Dmot',{});
F2_RIDGE = [];                         % frozen after the primary session
prepCfg  = struct('dataDir',F2_DATADIR);
fails    = {};

for q = 1:numel(F2_SEL)
    sel = F2_SEL(q);
    try
        P = f2_prep(allExperiments(sel), prepCfg);

        % --- §2 stim-affected layout (confirmed detector mask; one figure per session) -----------
        A = f2_affected(P, struct('plot',F2_PLOT));

        % --- §3 M4 predictor, contra only (PRIMARY) ---------------------------------------------
        mopt = struct('use_motion',false, 'ridge_fixed',F2_RIDGE, ...
                      'select_mode',F2_SELECT, 'r2_floor',F2_R2FLOOR, ...
                      'use_affected',F2_USE_AFFECT, 'nu',F2_NU, 'sv_weight',F2_SVW, 'kmax',F2_KMAX);
        M = f2_model(P, A, mopt);
        if isempty(F2_RIDGE)
            F2_RIDGE = M.ridge;        % FREEZE: every later session inherits this verbatim
            fprintf(2,'[F2] strategy frozen on %s: ridge = %.4g -> applied to all later sessions\n', ...
                    P.label, F2_RIDGE);
        end

        % --- §4 decomposition + catch control ---------------------------------------------------
        D = f2_decomp(P, M);

        % --- the FIT figure. Drawn HERE, inside the loop, because the held-out design Zte (~80 MB)
        % is deliberately not carried on the result structs -- the only place the spontaneous fit
        % can be plotted is while this session is still in memory.
        if F2_PLOT
            f2_fitfig(P, A, M, D, struct('export', F2_FITDIR));
            % In subspace mode the object worth inspecting per session is the basis, not the mask:
            % spectrum, V_1..V_k mapped on the brain, the surviving weight map, and the frontier.
            if ~isempty(M.subspace)
                f2_subfig(P, M.subspace, M.frontier, M, struct('export', F2_FITDIR));
            end
        end

        % --- the motion-augmented VARIANT (robustness, not the headline) -------------------------
        Mm = []; Dm = [];
        if F2_USE_MOTION && P.haveMot
            fprintf('\n[F2] --- motion-augmented variant (robustness) ---\n');
            Mm = f2_model(P, A, struct('use_motion',true, 'ridge_fixed',F2_RIDGE));
            Dm = f2_decomp(P, Mm, struct('verbose',false));
            fprintf('   contra-only  spont R^2 %.4f | median capture %3.0f%% | catch %+.0f%%\n', ...
                    M.r2_spont,  D.capMed,  100*D.catch.ratio);
            fprintf('   +motion      spont R^2 %.4f | median capture %3.0f%% | catch %+.0f%%   (dR^2 = %+.4f)\n', ...
                    Mm.r2_spont, Dm.capMed, 100*Dm.catch.ratio, Mm.r2_spont-M.r2_spont);
        end

        k = numel(F2)+1;
        F2(k).label = P.label;  F2(k).caveat = P.caveat;  F2(k).sel = sel;
        F2(k).A = A;  F2(k).M = M;  F2(k).D = D;  F2(k).Mmot = Mm;  F2(k).Dmot = Dm;
        clear P                                        % release the session's SVD before the next one
    catch ME
        fails{end+1} = sprintf('%s %s e%d -- %s: %s', allExperiments(sel).mn, allExperiments(sel).td, ...
                               allExperiments(sel).en, ME.identifier, ME.message);  %#ok<SAGROW>
        warning('[F2] session %d FAILED: %s', sel, ME.message);
    end
end

%% [F2-5] cross-session summary table -- the sheet that answers "is the OLS broken?"
fprintf('\n[F2] ================= PREDICTOR / DECOMPOSITION SUMMARY =================\n');
fprintf('%-30s %6s %6s %8s %8s %8s %6s %8s %8s %8s %-14s\n', ...
        'session','cand','kept','spontR2','shiftR2','preR2','amps','capture%','leak%','catch%','greedy');
for k = 1:numel(F2)
    M = F2(k).M;  D = F2(k).D;
    g = 'OFF';
    if isstruct(M.greedy) && isfield(M.greedy,'status'), g = M.greedy.status; end
    fprintf('%-30s %6d %6d %8.4f %+8.4f %8.3f %3d/%-2d %8.0f %8.0f %+8.0f %-14s\n', ...
        F2(k).label, M.nCand, numel(M.S), M.r2_spont, M.r2_shift, median(M.r2_pre,'omitnan'), ...
        nnz(D.ampOK), numel(D.ampOK), D.capMed, D.leakMed, 100*D.catch.ratio, g);
end
fprintf(['\nHOW TO READ THIS ROW BY ROW:\n' ...
         '  spontR2  held-out SPONTANEOUS R^2 -- the criterion the regulariser was picked on.\n' ...
         '  shiftR2  same weights vs a time-SHIFTED ipsi target. MUST be ~0. If not, spontR2 is\n' ...
         '           inflated by slow shared structure and the model IS broken.\n' ...
         '  capture  Local dip as %% of Actual. NOT tuned for -- it is a measurement here.\n' ...
         '  catch    Local dip on NO-STIM windows, as %% of the median stim Local dip. MUST be ~0.\n' ...
         '           If it is not, the decomposition manufactures residual and capture is void.\n' ...
         '  greedy   CONVERGED = a blind pixel set was found. FAILED_* = none exists at this R^2\n' ...
         '           floor, which is an identifiability result (coupling is distributed), not a bug.\n']);
% CATCH VERDICT, stated once and unmissably. A session that fails here has a Local dip on no-stim
% windows, so its capture number is an artefact of the decomposition and must not reach the paper.
badCatch = find(arrayfun(@(x) abs(x.D.catch.ratio) > 0.15, F2));
if isempty(badCatch)
    fprintf('\n  CATCH VERDICT: all %d session(s) clean -> the residual is a stim effect, not manufactured.\n', numel(F2));
else
    fprintf(2,'\n  CATCH VERDICT: %d session(s) FAIL -- their capture/leak numbers are VOID:\n', numel(badCatch));
    for k = badCatch
        fprintf(2,'     %-30s catch Local = %+.0f%% of its stim Local dip (n=%d %s windows)\n', ...
                F2(k).label, 100*F2(k).D.catch.ratio, F2(k).D.catch.nT, F2(k).D.catch.kind);
    end
end
for k = 1:numel(F2)
    if ~isempty(F2(k).caveat), fprintf(2,'  [CAVEAT] %s: %s\n', F2(k).label, F2(k).caveat); end
end
if ~isempty(fails)
    fprintf(2,'\n[F2] %d session(s) EXCLUDED -- every number above is over the survivors only:\n', numel(fails));
    for i = 1:numel(fails), fprintf(2,'   %s\n', fails{i}); end
end

%% [F2-6] STATE -- residual vs motion and delta
if ~isempty(F2)
    F2_STATE = f2_state(F2, struct('dv',F2_DV,'plot',F2_PLOT));
    if F2_USE_MOTION && any(arrayfun(@(x) ~isempty(x.Dmot), F2))
        fprintf(['\n[F2] === same state test on the MOTION-AUGMENTED residual (robustness) ===\n' ...
                 '     If this agrees with the table above, "motion is in the predictor" does not\n' ...
                 '     change the conclusion and the objection is answered.\n']);
        ok = arrayfun(@(x) ~isempty(x.Dmot), F2);
        Fm = F2(ok);  for i = 1:numel(Fm), Fm(i).D = Fm(i).Dmot; end
        F2_STATE_MOT = f2_state(Fm, struct('dv',F2_DV,'plot',false));
    end
end
fprintf('\n[F2] done. Structs: F2 (per session), F2_STATE (state result).\n');
