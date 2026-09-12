function KP = f2_knob_pass(ae, dataDir, configs)
%F2_KNOB_PASS  Quick predictor-knob sweep for ONE impulse session (no freeze, no state test).
%
% Loads the session design (f2_prep) + affected mask (f2_affected) ONCE, then runs f2_model+f2_decomp
% for each candidate knob setting and prints the HONEST metrics side by side so a good operating point
% can be picked by eye WITHOUT looking at capture as a target:
%   spontR2  held-out spontaneous R^2 (stim-free; must stay high)
%   shift    time-shift null (must be ~0 / negative)
%   catch%   no-stim Local dip as % of stim Local (must be ~0, |.|<=15)
%   capMed   median capture over responding amps  (the OUTCOME, not the target)
%   leakMed  median leak
%   wdist    mean |weight|-weighted distance of predictors from the ipsi site (px) -- higher = more distal/blind
%
% INPUT  ae       one allExperiments entry
%        dataDir  impulse-analysis/data
%        configs  struct array; each element has .name plus any f2_model opt fields
%                 (select_mode, ridge_fixed, r2_floor, penNear, penFar, nu, ...).
% OUTPUT KP        struct array with .name .M .D per config (for plotting / export).
% -------------------------------------------------------------------------------------------------
P = f2_prep(ae, struct('dataDir',dataDir,'verbose',false));
A = f2_affected(P, struct('plot',false));
nResp = @(D) nnz(D.ampOK);
fprintf('\n==== %s ====  (%d unaffected px = %.0f%% of grid, %d amps)\n', ...
        P.label, numel(A.unaff_pooled), 100*numel(A.unaff_pooled)/P.nG, P.nA);
fprintf('%-14s %8s %8s %7s %7s %7s %7s %6s\n', ...
        'config','spontR2','shift','catch%','cap%','leak%','wdist','nAmp');
KP = struct('name',{},'M',{},'D',{});
for c = 1:numel(configs)
    mopt = configs(c);  nm = mopt.name;  mopt = rmfield(mopt,'name');
    mopt.use_motion = false;  mopt.verbose = false;
    try
        M = f2_model(P, A, mopt);
        D = f2_decomp(P, M, struct('verbose',false));
        aw = abs(M.b(1:P.nG));
        wd = sum(aw.*P.selDist(:)) / max(sum(aw), eps);
        fprintf('%-14s %8.4f %+8.3f %+7.0f %7.0f %7.0f %7.0f %6d\n', ...
                nm, M.r2_spont, M.r2_shift, 100*D.catch.ratio, D.capMed, D.leakMed, wd, nResp(D));
        KP(c).name = nm;  KP(c).M = M;  KP(c).D = D;
    catch ME
        fprintf('%-14s  FAILED: %s\n', nm, ME.message);
    end
end
KP(1).P = P;  KP(1).A = A;      % keep P/A on the first element so a chosen config can be re-plotted
end
