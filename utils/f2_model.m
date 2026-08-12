function M = f2_model(P, A, opt)
%F2_MODEL  Fig-2 stream, STAGE 3: the best ipsi predictor built from NON-stim-affected contra px.
%
% GOAL (user, 2026-08-11): the best possible ipsi predictor -- one that reconstructs the ipsi trace
% a NON-stim-affected brain would have produced, so that Actual - Prediction (the residual) carries
% the MAXIMAL stim effect. Model M4 = pooled-unaffected pixel set -> weighted-L2 (far-from-ipsi)
% spont fit -> greedy pruning of the pixels that still carry stim.
%
% *** THE ONE THING THAT CHANGED FROM ols_tf_pipeline.m §17c0 ***
% The old §17c0 picked its regulariser by MINIMISING LEAK subject to an R^2 floor. Leak is the
% quantity the analysis then reports as an honest readout -- you cannot tune on it and quote it.
% Here the regulariser is picked by MAXIMISING HELD-OUT SPONTANEOUS R^2, a criterion computed on
% stim-free frames that never sees the dip. Leak is then a pure measurement. This is the difference
% between "the residual is big because we tuned for it" and "the residual is big".
%
% Blindness is therefore earned by PIXEL SELECTION only -- the TF detector's exclusion (Stage 2)
% and, optionally, greedy pruning -- never by a constraint on the weights. Greedy can genuinely
% FAIL, and says so; that failure is a result (coupling is distributed), not a bug.
%
% CONTROLS RETURNED (all of them are how you find out the model is broken):
%   .r2_shift    prediction scored against a time-SHIFTED ipsi trace. Must collapse to ~0. If a
%                shifted target is still "predicted", the design is tracking slow shared structure
%                (drift, hemodynamics), not contra->ipsi coupling, and every R^2 here is inflated.
%   .greedy.rand random-exclusion control: drop the same COUNT at random. If greedy does not beat
%                random it is losing predictors, not finding stim-carrying ones ([CP-STIMAFF], S14).
%   .greedy.leakVal  blindness measured on the HELD-OUT trial half. In-sample blindness that does
%                not transfer was overfitting the trial average.
%
% INPUT   P  from f2_prep        A  from f2_affected
%         opt .use_motion(false)  add the motion trace as an extra regressor (index nP = nG+1).
%                                 It is never distance-penalised and never pruned -- it is a
%                                 nuisance covariate, not a candidate stim-carrier.
%             .ridge_grid  fractions of mean(diag(Gz)) to sweep
%             .ridge_fixed []     [] = pick by max held-out spont R^2; numeric = freeze it
%             .penNear(2.0) .penFar(0.2)   distance-prior endpoints (weight cost at ipsi / farthest)
%             .greedy_on(true) .greedy_tol(0.05) .greedy_r2floor(0.98) .greedy_batch(0.01)
%             .nShift(5)  time-shift null repeats     .verbose(true)
% OUTPUT  M  .b [nP x 1] weights | .S kept pixels | .ridge .lam | .r2_spont .r2_shift
%            .r2_pre .r2_post [nA] | .leak [nA] | .sweep table | .greedy | .use_motion .nP
% -------------------------------------------------------------------------------------------------
if nargin < 3, opt = struct(); end
def = struct('use_motion',false, 'ridge_grid',[0 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 0.1 0.3 1 3], ...
             'ridge_fixed',[], 'penNear',2.0, 'penFar',0.2, 'greedy_on',true, 'greedy_tol',0.05, ...
             'greedy_r2floor',0.98, 'greedy_batch',0.01, 'greedy_nRand',5, 'nShift',5, 'verbose',true, ...
             'select_mode','r2max', 'r2_floor',0.85);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}), opt.(fn{i}) = def.(fn{i}); end
    if isempty(opt.(fn{i})) && ~strcmp(fn{i},'ridge_fixed'), opt.(fn{i}) = def.(fn{i}); end
end
vb = opt.verbose;  nA = P.nA;  nG = P.nG;

%% ---- (a) working design: contra only, or contra + motion -------------------------------------
use_mot = opt.use_motion && P.haveMot;
if opt.use_motion && ~P.haveMot
    warning('f2_model: use_motion requested but %s has no motion trace -> contra-only.', P.label);
end
if use_mot
    Gz = P.Gz_a;  cz = P.cz_a;  Zte = P.Zte_a;  nP = nG+1;
else
    Gz = P.Gz;    cz = P.cz;    Zte = P.Zte;    nP = nG;
end

% Distance prior: penalty grows toward the ipsi site, so near-ipsi predictors (the ones most likely
% to be stim-contaminated) are expensive and distal ones cheap. gamma = 1/penalty, applied as a
% WEIGHTED L2 -- it shrinks near-ipsi weights, it never zeros one, so no pixel is silently removed.
dn    = (P.selDist - min(P.selDist)) / max(max(P.selDist)-min(P.selDist), eps);
pen   = opt.penNear*(1-dn) + opt.penFar*dn;
gamma = 1./pen(:);
if use_mot, gamma(nP) = max(gamma); end            % motion: cheapest possible -> effectively unpenalised

U = A.unaff_pooled(:).';                            % candidate predictors: unaffected at EVERY amp
if use_mot, U = [U, nP]; end
assert(numel(U) >= 5, 'f2_model: only %d candidate predictors for %s.', numel(U), P.label);

mdG   = mean(diag(Gz));
fitb  = @(S,lam) local_fit(Gz, cz, S, gamma, lam, nP);
r2of  = @(b) 1 - sum((P.yte - (P.muY + Zte*b)).^2)/P.sstot;

%% ---- (b) per-amp leak helper (a MEASUREMENT -- never a selection criterion) --------------------
% leak_a = (dip of the prediction) / (dip of the actual ipsi) over that amp's inhibition window.
% Local = Actual - Global exactly, so capture = 1 - leak.
evDip = cell(nA,1);  actDip = nan(nA,1);
for ai = 1:nA
    if isempty(P.evZc{ai}), continue; end
    dc = P.dcc{ai};
    e = mean(P.evZc{ai}(:,dc), 2);
    if use_mot, e(nP,1) = mean(P.evMot(dc,ai)); end
    evDip{ai} = e;  actDip(ai) = mean(P.aAc{ai}(dc));
end
okA   = find(~cellfun(@isempty, evDip(:).'));
leakf = @(b) arrayfun(@(a) (b.'*evDip{a})/actDip(a), okA);

%% ---- (c) REGULARISER SWEEP -- picked on held-out SPONTANEOUS R^2, never on leak ---------------
grid_ = opt.ridge_grid(:).';  nRG = numel(grid_);
sw = struct('ridge',grid_(:), 'r2',nan(nRG,1), 'leak',nan(nRG,1), 'wdist',nan(nRG,1));
if vb
    fprintf('\n[F2-MODEL] %s%s | %d candidate px\n', P.label, local_tern(use_mot,' (+motion)',''), numel(U));
    fprintf('   ridge sweep -- PICK = argmax held-out SPONTANEOUS R^2 (leak is measured, not targeted)\n');
    fprintf('   %-12s %10s %10s %10s   %s\n','ridge','spontR2','leak%','capture%','mean |w| dist from ipsi (px)');
end
for ri = 1:nRG
    b = fitb(U, max(1e-6,grid_(ri))*mdG);
    sw.r2(ri)   = r2of(b);
    sw.leak(ri) = 100*median(leakf(b),'omitnan');
    aw = abs(b(1:nG));
    if sum(aw) > 0, sw.wdist(ri) = sum(aw.*P.selDist(:))/sum(aw); end
    if vb
        fprintf('   %-12.4g %10.4f %10.1f %10.1f   %.1f\n', ...
                grid_(ri), sw.r2(ri), sw.leak(ri), 100-sw.leak(ri), sw.wdist(ri));
    end
end
if isempty(opt.ridge_fixed)
    [~, iB] = max(sw.r2);  ridge = grid_(iB);
    if vb, fprintf(2,'   [PICK] ridge = %.4g  ->  held-out spont R^2 %.4f (max)  |  leak %.0f%% (measured)\n', ...
                   ridge, sw.r2(iB), sw.leak(iB)); end
else
    [~, iB] = min(abs(grid_ - opt.ridge_fixed));  ridge = opt.ridge_fixed;
    if vb, fprintf('   [PICK] ridge FROZEN at %.4g (spont R^2 %.4f, leak %.0f%%)\n', ...
                   ridge, sw.r2(iB), sw.leak(iB)); end
end
lam = max(1e-6, ridge)*mdG;

%% ---- (c2) SPLIT-HALF evoked dips -- built ONCE, used by BOTH selectors -------------------------
% Selection sees trial-half A; blindness/capture is REPORTED on half B. Every method below that
% touches stim data goes through this split, so none of them can be scored on the trials that
% chose them. Built here rather than inside the greedy block because frontier mode needs it too
% and greedy may be off.
hv = find(~cellfun(@isempty, P.evZcA(:).'));
hv = hv(ismember(hv, okA));
evS = {};  acS = [];  evV = {};  acV = [];
if numel(hv) >= 2
    nH = numel(hv);
    evS = cell(nH,1);  acS = nan(1,nH);  evV = cell(nH,1);  acV = nan(1,nH);
    for q = 1:nH
        a = hv(q);  dc = P.dcc{a};
        evS{q} = local_dipvec(P.evZcA{a}, dc, P.evMot(:,a), use_mot, nP);
        evV{q} = local_dipvec(P.evZcB{a}, dc, P.evMot(:,a), use_mot, nP);
        acS(q) = mean(P.aAcA{a}(dc));
        acV(q) = mean(P.aAcB{a}(dc));
    end
end

%% ---- (d) GREEDY pruning: remove the pixels that still carry stim, without touching weights ----
S = U;  G = [];
if opt.greedy_on
    if numel(hv) >= 2
        GP = struct('Gz',Gz,'cz',cz,'gamma',gamma,'lam',lam,'Zte',Zte,'yte',P.yte,'muY',P.muY, ...
                    'sstot',P.sstot,'evDipSel',{evS},'actDipSel',acS, ...
                    'evDipVal',{evV},'actDipVal',acV,'U',U);
        % Seeded HERE so the random-EXCLUSION control is a function of this session alone. Seeding
        % only in the driver made the control's numbers depend on how much RNG earlier stages had
        % consumed, so the same session reported different control values depending on whether the
        % motion variant was run. The verdict never changed, but a control that moves run-to-run is
        % not a control.
        rng(11,'twister');
        G = imp_greedy_blind(GP, struct('tol',opt.greedy_tol,'r2_floor',opt.greedy_r2floor, ...
                                        'batch_frac',opt.greedy_batch,'nRand',opt.greedy_nRand, ...
                                        'verbose',vb));
        if use_mot && ~ismember(nP, G.S), G.S = [G.S, nP]; end   % motion is a covariate, never pruned
        % ADOPT the pruned set only if the search actually converged. A FAILED search returns the
        % set it happened to stop at -- keeping it would silently ship a worse predictor.
        if strcmp(G.status,'CONVERGED')
            S = G.S;
        elseif vb
            fprintf(2,'   greedy %s -> keeping the FULL unaffected set (the pruned set is not adopted)\n', G.status);
        end
    elseif vb
        fprintf('   greedy skipped: only %d amps have a usable trial split\n', numel(hv));
    end
end

%% ---- (d2) FRONTIER mode: maximise capture subject to a spontaneous-R^2 floor -------------------
% opt.select_mode 'r2max'    (default) weights are the plain weighted-L2 fit; capture is a pure
%                            MEASUREMENT because nothing in the selection ever saw the dip.
%                 'frontier' adds a leak penalty and picks the strongest one that still clears
%                            opt.r2_floor -- i.e. maximise capture s.t. R^2 >= floor (user request,
%                            2026-08-11). Capture then becomes a FITTED TARGET; f2_frontier's
%                            trial-split and random-direction controls are what keep it meaningful.
FR = [];
if strcmpi(opt.select_mode,'frontier')
    if numel(evS) < 2
        warning(['f2_model: frontier mode needs a trial split for honest validation and %s has too ' ...
                 'few usable amps -- falling back to r2max.'], P.label);
    else
        Q = struct('G',Gz, 'c',cz, 'gamma',gamma, 'lamR',lam, 'Zte',Zte, 'yte',P.yte, ...
                   'muY',P.muY, 'sstot',P.sstot, 'S',S, 'nP',nP, 'dist',[P.selDist(:); 0]);
        Q.dist = Q.dist(1:nP);
        Q.evSel = evS;  Q.actSel = acS;  Q.evVal = evV;  Q.actVal = acV;
        FR = f2_frontier(Q, struct('r2_floor',opt.r2_floor, 'verbose',vb));
    end
end

%% ---- (e) final fit + honest metrics -----------------------------------------------------------
if ~isempty(FR)
    b = FR.b;                                   % frontier weights (same candidate set S)
else
    b = fitb(S, lam);
end
r2_spont = r2of(b);
leak     = nan(nA,1);  leak(okA) = leakf(b);

% TIME-SHIFT NULL. Score the same prediction against a circularly shifted ipsi trace. A real
% contra->ipsi predictor tracks y at ZERO lag and nothing else, so shifted R^2 must be ~0 or
% negative. A shifted R^2 that stays high means the fit is riding slow shared structure (drift,
% hemodynamics, bleaching) and the headline R^2 is inflated.
yhat = P.muY + Zte*b;  nTe = numel(P.yte);
shifts = round(linspace(0.15, 0.85, opt.nShift) * nTe);
r2s = nan(opt.nShift,1);
for k = 1:opt.nShift
    ysh = circshift(P.yte, shifts(k));
    r2s(k) = 1 - sum((ysh - yhat).^2)/max(sum((ysh-mean(ysh)).^2), eps);
end
r2_shift = median(r2s);

% HONEST per-frame pre/post-stim prediction R^2 on RAW trial frames (never on the trial average,
% which outside the stim window is noise-vs-noise and reads a meaningless 0.16-0.56).
r2f = @(y,yh) 1 - sum((y(:)-yh(:)).^2)/max(sum((y(:)-mean(y(:))).^2), eps);
r2_pre = nan(nA,1);  r2_post = nan(nA,1);
for ai = 1:nA
    if isempty(P.Zpre{ai}), continue; end
    Zp = P.Zpre{ai};   if use_mot, Zp = [Zp; P.mpre{ai}(:).'];  end   %#ok<AGROW>
    Zq = P.Zpost{ai};  if use_mot, Zq = [Zq; P.mpost{ai}(:).']; end   %#ok<AGROW>
    r2_pre(ai)  = r2f(P.ypre{ai},  P.muY + (Zp.'*b));
    r2_post(ai) = r2f(P.ypost{ai}, P.muY + (Zq.'*b));
end

M = struct('b',b, 'S',S, 'nP',nP, 'use_motion',use_mot, 'gamma',gamma, ...
           'ridge',ridge, 'lam',lam, 'sweep',sw, 'greedy',G, 'frontier',FR, ...
           'select_mode',lower(opt.select_mode), ...
           'r2_spont',r2_spont, 'r2_shift',r2_shift, 'r2_shift_all',r2s, ...
           'r2_pre',r2_pre, 'r2_post',r2_post, 'leak',leak, 'nAct',nnz(b(1:nG)), ...
           'nCand',numel(U), 'label',P.label, 'caveat',P.caveat);

% Split-half evoked dip vectors, retained so the "does the stim direction TRANSFER between trial
% halves" question can be answered without re-running prep (which reloads the SVD). Wrapped in
% cells: struct() distributes a bare cell array across elements and would make M a 1xN struct array.
M.evSel = {evS};  M.evVal = {evV};  M.actSel = acS;  M.actVal = acV;

if vb
    fprintf('   FINAL  %d/%d px | held-out spont R^2 %.4f | pre %.3f / post %.3f | median leak %.0f%% (capture %.0f%%)\n', ...
        numel(S), numel(U), r2_spont, median(r2_pre,'omitnan'), median(r2_post,'omitnan'), ...
        100*median(leak,'omitnan'), 100-100*median(leak,'omitnan'));
    fprintf('   time-shift null R^2 = %+.4f  ', r2_shift);
    if r2_shift > 0.1
        fprintf(2,'** NOT ~0: the predictor tracks a shifted target too, so this R^2 is inflated by slow shared structure **\n');
    else
        fprintf('(collapses as it must -> the R^2 above is genuine zero-lag coupling)\n');
    end
end
end

% -------------------------------------------------------------------------------------------------
function b = local_fit(Gz, cz, S, gamma, lam, nP)
% Weighted-L2 spont fit restricted to S:  min ||y - Z_S b||^2 + lam*sum (b_i/gamma_i)^2
%   -> (G_S + lam*diag(1/gamma^2)) b_S = c_S.
% No sparsity and NO constraint on the dip: blindness comes only from WHICH pixels are in S.
% Identical to select_wlasso's l1frac<=0 branch and to imp_greedy_blind's internal fit, so the
% sweep, the search and the final model are all the same estimator.
b = zeros(nP,1);
if isempty(S), return; end
g = gamma(S);
b(S) = (Gz(S,S) + lam*diag(1./max(g,eps).^2)) \ cz(S);
end

function e = local_dipvec(evZ, dc, evM, use_mot, nP)
% Per-pixel evoked dip vector for one amp, with the motion row appended when the design is augmented.
% The motion row uses the FULL-trial evoked in both halves: motion is a nuisance covariate that
% greedy never prunes, so it plays no part in the split-half blindness test it would contaminate.
e = mean(evZ(:,dc), 2);
if use_mot, e(nP,1) = mean(evM(dc)); end
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
