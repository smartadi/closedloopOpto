%% imp_run_all.m -- run the ENTIRE OLS residual pipeline on EVERY impulse session, end to end.
%
% WHAT THIS IS. One driver for the whole impulse stream, so a full result set is reproduced by
% running one file instead of hand-editing `selExp` four times and remembering the order. Per
% session it runs the REAL single-session path -- ROI/mask selection, data-derived site, TF
% affected-pixel detection, the §10T3 selector, the session viewer, then §17d SELECT and the
% §17c/§17c2 state-dependence -- and collects the per-trial payloads into one `ALLSESS`.
%
% WHY NOT §18. §18's headless engine (`local_stimblind_session`) keys off the energy-based `bledA`
% map and never reads `affected_tf`, so its cross-session numbers come from a DIFFERENT pixel-
% exclusion criterion than the single-session analysis. Looping the single-session path removes
% that mismatch outright: every session here is decomposed by exactly the code the primary session
% is. The tf_sens cache (2026-08-05) is what makes this practical -- the selector is confirmed once
% per session and reused thereafter, so only the FIRST pass is interactive.
%
% SESSIONS (in `allExperiments` order)
%   1  AL_0041 2025-12-02 e1
%   2  AL_0041 2025-12-02 e2
%   3  AL_0033 2025-01-29 e1   <- primary
%   4  AL_0048 2026-07-15 e1 site R   <- dual-opsin, INHIBITORY side (appended by load_bilateral_impulse)
%
% ⚠ AL_0048 CAVEAT, DO NOT LOSE IT (load_bilateral_impulse.m header, RESEARCH 2026-08-02): on the
% inhibitory side the readout sits ~2.6 mm from the ILLUMINATED spot -- the calibrated spot has no
% usable dose-response (middle amplitude not even significant) while the anterior focus does, so
% SITE_MODE='response' puts the readout there. AL_0048's inhibitory "impulse response" is therefore
% the response of a CONNECTED region, not of illuminated tissue. Any TF or local-effect claim that
% includes this session must say so. It is NOT a fourth replicate of the same measurement.
%
% RUN ORDER (the TF/LTI stage runs FIRST, per user 2026-08-05)
%   imp_run_all            % this file -- does the loading, the TF stage, then the per-session sweep
% Or drive the stages yourself:
%   load_experiments; load_bilateral_impulse; imp_tf_xsess; imp_run_all
%
% FIRST PASS IS INTERACTIVE. Per session you will get: the ROI draw GUI (only if that session has no
% cached cp_roi2_*), then the §10T3 selector -- tune sensitivity, press CONFIRM. That confirmation is
% saved to data/tf_sens_<sess>.mat and every later run of that session reuses it without blocking.
% -------------------------------------------------------------------------------------------------
% clc;clear all;close all
RA_RUN_TF = false
%% [RA-CFG] knobs
if ~exist('RA_SEL','var')      || isempty(RA_SEL),      RA_SEL      = [];    end  % [] = every registered session
if ~exist('RA_RUN_TF','var')   || isempty(RA_RUN_TF),   RA_RUN_TF   = true;  end  % run imp_tf_xsess first
if ~exist('RA_RUN_PLOT','var') || isempty(RA_RUN_PLOT), RA_RUN_PLOT = true;  end  % run imp_state_xsess_plot after
if ~exist('RA_VIEWER','var')   || isempty(RA_VIEWER),   RA_VIEWER   = true;  end  % open the §8 session viewer per session
if ~exist('RA_RESELECT','var') || isempty(RA_RESELECT), RA_RESELECT = false; end  % true = ignore saved tf_sens, CONFIRM again
if ~exist('RA_BILATERAL','var')|| isempty(RA_BILATERAL),RA_BILATERAL= true;  end  % append AL_0048 (inhibitory site)
% ---- ONE STRATEGY FOR ALL SESSIONS (2026-08-05) --------------------------------------------------
% A combined cross-session state-dependence result is only interpretable if every session was analysed
% the SAME way. §17c0's ridge_pick='auto' tunes the prior per session -- that is per-dataset parameter
% selection, and pooling its outputs would mean pooling four differently-tuned analyses. So the driver
% resolves the prior ONCE and freezes it: RA_RIDGE=[] picks it on the FIRST session in RA_SEL (which is
% ordered primary-first below) and reuses that value verbatim for every later session; a numeric RA_RIDGE
% freezes that value for all, including the first. Either way the sweep still RUNS per session, so the
% per-session curve is still available for inspection -- it just does not get to move the knob.
if ~exist('RA_RIDGE','var'),     RA_RIDGE     = [];   end   % [] = pick on the primary, then freeze
if ~exist('RA_R2MIN','var')   || isempty(RA_R2MIN),   RA_R2MIN   = 0.92;  end   % R^2 floor for that one pick
if ~exist('RA_GREEDY','var')  || isempty(RA_GREEDY),  RA_GREEDY  = true;  end   % §17e pixel-pruning layer
if ~exist('RA_PRIMARY','var'), RA_PRIMARY = [];  end        % session index to resolve the strategy on

%% [RA-LOAD] build allExperiments (3 original sessions + AL_0048 R)
if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[RA] allExperiments absent -> running load_experiments (reads SVD from the server; slow)\n');
    load_experiments
end
if RA_BILATERAL && ~any(arrayfun(@(A) strcmp(A.mn,'AL_0048'), allExperiments))
    fprintf('[RA] appending AL_0048 (inhibitory site) -> load_bilateral_impulse\n');
    load_bilateral_impulse
end
RA_n = numel(allExperiments);
if isempty(RA_SEL), RA_SEL = 1:RA_n; end
RA_SEL = RA_SEL(RA_SEL >= 1 & RA_SEL <= RA_n);
% PRIMARY FIRST: the strategy is resolved on this session, so it must be the one the project treats as
% primary (AL_0033), not whichever happens to sit at index 1.
if isempty(RA_PRIMARY)
    RA_PRIMARY = find(arrayfun(@(A) strcmp(A.mn,'AL_0033'), allExperiments(RA_SEL)), 1);
    if isempty(RA_PRIMARY), RA_PRIMARY = 1; else, RA_PRIMARY = RA_SEL(RA_PRIMARY); end
end
if ismember(RA_PRIMARY, RA_SEL), RA_SEL = [RA_PRIMARY, RA_SEL(RA_SEL ~= RA_PRIMARY)]; end

RA_lab = cell(RA_n,1);
for RA_k = 1:RA_n
    A_ = allExperiments(RA_k);
    if isfield(A_,'site') && ~isempty(A_.site), RA_lab{RA_k} = sprintf('%s %s e%d [%s]', A_.mn, A_.td, A_.en, A_.site);
    else,                                       RA_lab{RA_k} = sprintf('%s %s e%d',      A_.mn, A_.td, A_.en); end
end
fprintf('\n[RA] %d session(s) queued:\n', numel(RA_SEL));
for RA_k = RA_SEL, fprintf('   %d  %s\n', RA_k, RA_lab{RA_k}); end

%% [RA-TF] cross-session impulse LTI / TF stage -- runs BEFORE the residual sweep
% imp_tf_xsess defaults TFX_SEL = 1:numel(allExperiments), so AL_0048 is included automatically now
% that the loader has appended it. Non-interactive; safe to run unattended.
if RA_RUN_TF
    fprintf('\n[RA] === STAGE A: impulse LTI / TF across sessions (imp_tf_xsess) ===\n');
    try
        imp_tf_xsess
    catch RA_err
        warning('[RA] imp_tf_xsess FAILED (%s) -- continuing to the residual sweep.\n%s', ...
                RA_err.identifier, RA_err.message);
    end
end

%% [RA-SWEEP] per-session full pipeline
% Each pass runs ols_tf_pipeline in THIS workspace with selExp_override set, then harvests the two
% payloads the cross-session stage needs: §17d SELECT (the stim-blind decomposition) and §17c's
% per-trial ST (the state-dependence engine output, identical to what §18 used to hand over).
fprintf('\n[RA] === STAGE B: full residual pipeline, session by session ===\n');
ALLSESS = cell(numel(RA_SEL),1);
RA_ok   = false(numel(RA_SEL),1);
RA_msg  = repmat({''}, numel(RA_SEL), 1);
for RA_i = 1:numel(RA_SEL)
    RA_s = RA_SEL(RA_i);
    fprintf('\n[RA] ---- session %d/%d: %s ----\n', RA_i, numel(RA_SEL), RA_lab{RA_s});
    selExp_override = RA_s;
    OLS_OVERRIDE = struct('RUN_ALLSESS',false, ...            % §18 deliberately unused (see header)
                          'RUN_SESSION_VIEWER',RA_VIEWER, ...
                          'tf_reuseSens',~RA_RESELECT, ...    % false -> CONFIRM again for this session
                          'greedy_on',RA_GREEDY);
    if isempty(RA_RIDGE)
        % First session (the primary) resolves the prior; every later session inherits it verbatim.
        OLS_OVERRIDE.ridge_pick  = 'auto';
        OLS_OVERRIDE.ridge_r2min = RA_R2MIN;
    else
        OLS_OVERRIDE.ridge_pick   = 'off';                    % sweep still runs; it just cannot move the knob
        OLS_OVERRIDE.select_ridge = RA_RIDGE;
    end
    try
        ols_tf_pipeline
        if isempty(RA_RIDGE) && exist('select_ridge','var')
            RA_RIDGE = select_ridge;                          % FREEZE for the remaining sessions
            fprintf(2,'[RA] strategy frozen from %s: select_ridge = %.4g (R^2 floor %.2f) -> applied to all later sessions\n', ...
                    RA_lab{RA_s}, RA_RIDGE, RA_R2MIN);
        end
        S_ = struct();
        S_.label = RA_lab{RA_s};  S_.selExp = RA_s;
        S_.mn = allExperiments(RA_s).mn;  S_.td = allExperiments(RA_s).td;  S_.en = allExperiments(RA_s).en;
        if exist('STIMBLIND_SELECT','var') && isstruct(STIMBLIND_SELECT)
            S_.amps      = STIMBLIND_SELECT.amps;
            S_.Actual    = STIMBLIND_SELECT.ActualDip;   S_.Global = STIMBLIND_SELECT.GlobalDip;
            S_.Local     = STIMBLIND_SELECT.LocalDip;
            S_.trA = STIMBLIND_SELECT.trA;  S_.trG = STIMBLIND_SELECT.trG;  S_.trL = STIMBLIND_SELECT.trL;
            S_.r2pre     = STIMBLIND_SELECT.r2pre;       S_.r2post = STIMBLIND_SELECT.r2post;
            S_.nUse      = STIMBLIND_SELECT.nUse;
            S_.medLocalPct  = STIMBLIND_SELECT.medDipCapPct;
            S_.medLeakPct   = STIMBLIND_SELECT.medDipLeakPct;
        end
        if exist('ST_','var') && isstruct(ST_), S_.ST = ST_; end            % §17c per-trial payload
        % ---- VIEW PAYLOAD for the cross-session trial inspector (imp_state_xsess_plot rows mode) ----
        % ST_ carries the per-trial traces but not the timebase they live on, nor the raw motion trace
        % the MOT scalar is reduced from. Without these the inspector can only draw sample indices and
        % can never show WHY a trial's motion scalar is what it is -- which is the one thing you look at
        % an outlier trial to find out. Small (one vector per session); harvested defensively so an
        % older pipeline that lacks any of them still yields a usable (degraded) inspector.
        if exist('rel','var'),       S_.rel     = rel(:);   end
        if exist('preN','var'),      S_.preN    = preN;     end
        if exist('Wb','var'),        S_.Wb      = Wb;       end
        if exist('Fs','var'),        S_.Fs      = Fs;       end
        if exist('inhCols','var'),   S_.inhCols = inhCols;  end
        if exist('motz_full','var'), S_.motz    = motz_full; end
        if exist('onFcell','var'),   S_.onF     = onFcell;  end
        if exist('nF_m','var'),      S_.nF      = nF_m;     end
        if exist('tf_sens','var'), S_.tf_sens = tf_sens; end
        if exist('affected','var'), S_.nAffected = sum(affected,1); end
        % Record the strategy this session actually ran under, so the combined result can be audited
        % rather than assumed identical. imp_state_xsess_plot should refuse to pool a mixed set.
        if exist('select_ridge','var'), S_.select_ridge = select_ridge; end
        if exist('select_l1frac','var'), S_.select_l1frac = select_l1frac; end
        if exist('GREEDY','var') && isstruct(GREEDY)
            S_.greedy_status = GREEDY.status;  S_.greedy_kept = numel(GREEDY.S);
            S_.greedy_r2 = [GREEDY.r2_full GREEDY.r2_blind];
            S_.greedy_leakVal = mean(abs(GREEDY.leakVal),'omitnan');
            S_.greedy_randLeak = GREEDY.rand.leak_mean;
        else
            S_.greedy_status = 'OFF';
        end
        ALLSESS{RA_i} = S_;
        RA_ok(RA_i) = isfield(S_,'ST') && ~isempty(S_.ST);
        if ~RA_ok(RA_i), RA_msg{RA_i} = 'ran, but §17c produced no ST payload'; end
    catch RA_err
        RA_msg{RA_i} = sprintf('%s: %s', RA_err.identifier, RA_err.message);
        warning('[RA] session %s FAILED -- %s', RA_lab{RA_s}, RA_msg{RA_i});
    end
end

%% [RA-REPORT] what actually completed
fprintf('\n[RA] ================= sweep summary =================\n');
for RA_i = 1:numel(RA_SEL)
    S_ = ALLSESS{RA_i};
    if RA_ok(RA_i)
        fprintf('   OK    %-30s | tf_sens %.2f | %d amps | median Local %.0f%% (leak %.0f%%) | %d trials\n', ...
            S_.label, getfielddef(S_,'tf_sens',NaN), numel(getfielddef(S_,'amps',[])), ...
            getfielddef(S_,'medLocalPct',NaN), getfielddef(S_,'medLeakPct',NaN), numel(S_.ST.LD));
    else
        fprintf('   FAIL  %-30s | %s\n', RA_lab{RA_SEL(RA_i)}, RA_msg{RA_i});
    end
end
ALLSESS = ALLSESS(RA_ok);                       % only complete sessions go downstream
fprintf('   -> ALLSESS holds %d usable session(s)\n', numel(ALLSESS));

% ---- STRATEGY AUDIT: prove every pooled session ran the same analysis ---------------------------
if ~isempty(ALLSESS)
    fprintf('\n[RA] strategy actually used per session (must be identical to pool):\n');
    fprintf('   %-30s %12s %10s %-16s %10s\n','session','select_ridge','l1frac','greedy','kept px');
    rgs = nan(numel(ALLSESS),1);  l1s = nan(numel(ALLSESS),1);
    for RA_i = 1:numel(ALLSESS)
        S_ = ALLSESS{RA_i};
        rgs(RA_i) = getfielddef(S_,'select_ridge',NaN);  l1s(RA_i) = getfielddef(S_,'select_l1frac',NaN);
        fprintf('   %-30s %12.4g %10.3g %-16s %10s\n', S_.label, rgs(RA_i), l1s(RA_i), ...
                getfielddef_s(S_,'greedy_status','?'), num2str(getfielddef(S_,'greedy_kept',NaN)));
    end
    if numel(unique(rgs(isfinite(rgs)))) > 1 || numel(unique(l1s(isfinite(l1s)))) > 1
        warning(['[RA] sessions did NOT run the same strategy (select_ridge or l1frac differs). A combined ' ...
                 'state-dependence result over these would pool differently-tuned analyses -- fix by passing ' ...
                 'a numeric RA_RIDGE before pooling.']);
    else
        fprintf('   -> identical across sessions: safe to pool.\n');
    end
end
if any(~RA_ok)
    fprintf('   -> %d session(s) EXCLUDED. Every cross-session number below is over the survivors only.\n', nnz(~RA_ok));
end
if any(cellfun(@(S) contains(S.label,'AL_0048'), ALLSESS))
    fprintf(2,['   -> AL_0048 is INCLUDED: its inhibitory readout is ~2.6 mm from the illuminated spot,\n' ...
               '      so it measures a CONNECTED region, not illuminated tissue. Not a plain 4th replicate.\n']);
end

%% [RA-COMBINE] cross-session state-dependence, as the combined STATEDEP plot
if RA_RUN_PLOT && ~isempty(ALLSESS)
    fprintf('\n[RA] === STAGE C: combined state-dependence (imp_state_xsess_plot) ===\n');
    imp_state_xsess_plot
end

function v = getfielddef(S, f, d)
if isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = d; end
if numel(v) > 1, v = median(double(v),'omitnan'); end
end

function v = getfielddef_s(S, f, d)
if isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = d; end
end
