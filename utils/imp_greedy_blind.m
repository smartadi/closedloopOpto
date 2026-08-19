function R = imp_greedy_blind(P, opts)
%IMP_GREEDY_BLIND  POOLED greedy pruning of contra predictors until the spont-trained fit is stim-BLIND.
%
% PURPOSE. Find ONE pixel set S (pooled over amplitudes) whose plain spont-trained prediction of the ipsi
% site carries as little of the stim dip as possible, WITHOUT touching the weights. Everything here drops
% pixels; the weights are always the unconstrained weighted-ridge spont fit on whatever survives.
%
% WHY THIS IS NOT THE RETIRED KKT MODEL. §17b NATIVE imposed b'*evDip = 0 as an exact equality -- one
% linear constraint on a vector with hundreds of free parameters, so it ALWAYS succeeds and its ~100%
% dip capture carries no information. Greedy can genuinely FAIL: if no subset achieves the tolerance
% without destroying held-out spontaneous R^2, this function says so (`status`) instead of returning a
% blinded-but-useless predictor. Capture is therefore still not the informative number -- the informative
% numbers are (a) the R^2 PRICE of blindness and (b) whether that price beats a random-exclusion control.
%
% TWO CONTROLS, MANDATORY, because selection uses stim data (evDip):
%   RANDOM EXCLUSION   drop the same COUNT at random and trace leak-vs-R^2 for both. If greedy does not
%                      beat random it is not finding stim-carrying pixels, it is just losing predictors.
%                      This is exactly what [CP-STIMAFF] (S14) found in the RRR lineage, so it is the
%                      known failure mode, not a hypothetical one.
%   TRIAL SPLIT        selection uses evDip from ONE half of the trials; the reported leak is recomputed
%                      on the HELD-OUT half. With hundreds of candidates a greedy search can cancel the
%                      dip by chance; blindness that does not transfer was overfitting the trial average.
%                      R.leakVal is the honest number. R.leakSel is in-sample and must not be quoted.
%
% INPUT  P  .Gz [nG x nG] .cz [nG x 1]     spont Gram + cross-product (z-space, train frames)
%           .gamma [nG x 1]                distance weights (LARGE far from ipsi, small near) -- same
%                                          convention as select_wlasso; the fit below is EXACTLY that
%                                          function's no-sparsity branch, written in b-space.
%           .lam                           weighted-L2 strength (select_ridge scaled), >=0
%           .Zte [nTe x nG] .yte .muY .sstot   held-out SPONTANEOUS frames for R^2
%           .evDipSel {nA}[nG x 1] .actDipSel [nA]   per-amp per-pixel evoked dip + actual ipsi dip (SELECT half)
%           .evDipVal {nA}[nG x 1] .actDipVal [nA]   same on the VALIDATION half ([] -> validation skipped)
%           .U                             pooled candidate pixel set (indices into 1..nG)
% OPTS      .tol (0.10) mean |leak| target | .r2_floor (0.90) fraction of the full-set R^2 below which
%           the search FAILS | .batch_frac (0.01) fraction of the live set dropped per step | .nRand (5)
%           random-control repeats | .minPx (20) | .verbose (true)
%
% OUTPUT R  .S .b .status ('CONVERGED'|'FAILED_R2'|'FAILED_EXHAUSTED') .r2_full .r2_blind
%           .leakSel .leakVal [nA] .traj .rand .nDropped .nStart
% -------------------------------------------------------------------------------------------------
if nargin < 2, opts = struct(); end
gv = @(f,d) local_def(opts,f,d);
tol = gv('tol',0.10);  r2_floor = gv('r2_floor',0.90);  batch_frac = gv('batch_frac',0.01);
nRand = gv('nRand',5);  minPx = gv('minPx',20);  verbose = gv('verbose',true);

nG = size(P.Gz,1);  nA = numel(P.evDipSel);
U  = P.U(:).';
if numel(U) < minPx
    R = struct('S',U,'b',zeros(nG,1),'status','FAILED_EXHAUSTED','r2_full',NaN,'r2_blind',NaN, ...
               'leakSel',nan(nA,1),'leakVal',nan(nA,1),'traj',[],'rand',[],'nDropped',0,'nStart',numel(U));
    return
end

fitb  = @(S) local_fit(P.Gz, P.cz, S, P.gamma, P.lam, nG);
r2of  = @(b) 1 - sum((P.yte - (P.muY + P.Zte*b)).^2)/P.sstot;
leakf = @(b,ev,ad) cellfun(@(e) (b.'*e), ev(:)).' ./ ad(:).';

S = U;  b = fitb(S);  r2_full = r2of(b);
leak0 = leakf(b, P.evDipSel, P.actDipSel);
traj  = [numel(U)-numel(S), r2_full, mean(abs(leak0))];

if verbose
    fprintf('[GREEDY-BLIND] pooled start: %d px | spont R^2 %.4f | mean |leak| %.3f (target %.2f, R^2 floor %.0f%% of full)\n', ...
            numel(S), r2_full, mean(abs(leak0)), tol, 100*r2_floor);
end

dropped = [];                       % every exit path below assigns `status` before breaking
while true
    b = fitb(S);  r2 = r2of(b);  lk = leakf(b, P.evDipSel, P.actDipSel);
    traj(end+1,:) = [numel(U)-numel(S), r2, mean(abs(lk))]; %#ok<AGROW>
    if mean(abs(lk)) <= tol,        status = 'CONVERGED';  break; end
    if r2 < r2_floor*r2_full,       status = 'FAILED_R2';  break; end
    if numel(S) <= minPx,           status = 'FAILED_EXHAUSTED';  break; end
    % --- score each live pixel: leak contribution per unit held-out R^2 cost --------------------
    g  = P.gamma(S);
    M  = P.Gz(S,S) + P.lam*diag(1./max(g,eps).^2);
    bS = M \ P.cz(S);
    Minv = inv(M);                              % only diag(Minv) is needed (leave-one-out denominators)
    contrib = zeros(numel(S),1);
    for a = 1:nA, contrib = contrib + (bS.*P.evDipSel{a}(S))/P.actDipSel(a); end
    contrib = contrib/nA;                       % signed: sum over pixels = mean leak, so >0 = adds leak
    cost  = bS.^2 ./ max(diag(Minv), eps);      % leave-one-covariate-out R^2 price of removing this pixel
    score = contrib ./ (cost + eps);
    cand  = find(contrib > 0);                  % only pixels that actually push the leak
    if isempty(cand), status = 'FAILED_EXHAUSTED'; break; end
    m = max(1, round(batch_frac*numel(S)));
    [~, ord] = sort(score(cand), 'descend');
    kill = cand(ord(1:min(m,numel(cand))));
    dropped = [dropped, S(kill)]; %#ok<AGROW>
    S(kill) = [];
end

% --- forward refinement: re-admit dip-safe pixels that IMPROVE R^2 without breaking blindness -----
if strcmp(status,'CONVERGED') && ~isempty(dropped)
    meanEv = zeros(nG,1);
    for a = 1:nA, meanEv = meanEv + abs(P.evDipSel{a})/abs(P.actDipSel(a)); end
    [~,oa] = sort(meanEv(dropped),'ascend');  candBack = dropped(oa);
    bBest = fitb(S);  r2Best = r2of(bBest);
    for q = candBack
        St = [S, q];  bt = fitb(St);
        if mean(abs(leakf(bt,P.evDipSel,P.actDipSel))) <= tol && r2of(bt) > r2Best
            S = St;  r2Best = r2of(bt);
        end
    end
end

b = fitb(S);  r2_blind = r2of(b);
leakSel = leakf(b, P.evDipSel, P.actDipSel);
if isfield(P,'evDipVal') && ~isempty(P.evDipVal)
    leakVal = leakf(b, P.evDipVal, P.actDipVal);           % HONEST: selection never saw these trials
else
    leakVal = nan(1,nA);
end

% --- RANDOM-EXCLUSION CONTROL: same drop COUNT, pixels chosen at random --------------------------
nDrop = numel(U) - numel(S);
randR2 = nan(nRand,1);  randLeak = nan(nRand,1);
for it = 1:nRand
    p  = randperm(numel(U));
    Sr = U(sort(p(1:max(minPx, numel(U)-nDrop))));
    br = fitb(Sr);
    randR2(it)   = r2of(br);
    randLeak(it) = mean(abs(leakf(br, P.evDipSel, P.actDipSel)));
end

R = struct('S',S,'b',b,'status',status,'r2_full',r2_full,'r2_blind',r2_blind, ...
           'leakSel',leakSel(:),'leakVal',leakVal(:),'traj',traj,'nDropped',nDrop,'nStart',numel(U), ...
           'rand',struct('r2',randR2,'leak',randLeak,'r2_mean',mean(randR2),'leak_mean',mean(randLeak)), ...
           'tol',tol,'r2_floor',r2_floor,'dropped',dropped);

if verbose
    fprintf('[GREEDY-BLIND] %s | kept %d/%d px | spont R^2 %.4f -> %.4f (%.1f%% of full)\n', ...
            status, numel(S), numel(U), r2_full, r2_blind, 100*r2_blind/max(r2_full,eps));
    fprintf('               mean |leak| in-sample %.3f | HELD-OUT %.3f  <- quote this one\n', ...
            mean(abs(leakSel)), mean(abs(leakVal)));
    fprintf('               RANDOM control at the same drop count: R^2 %.4f, mean |leak| %.3f\n', ...
            mean(randR2), mean(randLeak));
    if mean(randLeak) <= mean(abs(leakSel)) + 0.02
        fprintf(2,['               ** greedy did NOT beat random exclusion -- it is losing predictors, not\n' ...
                   '                  finding stim-carrying ones. Do not treat the residual as validated. **\n']);
    end
    if any(isfinite(leakVal)) && mean(abs(leakVal)) > 2*max(mean(abs(leakSel)),0.01)
        fprintf(2,['               ** blindness did NOT transfer to held-out trials (%.3f vs %.3f in-sample):\n' ...
                   '                  the selection overfit the trial average. **\n'], mean(abs(leakVal)), mean(abs(leakSel)));
    end
end
end

% ---------------------------------------------------------------------------------------------
function b = local_fit(Gz, cz, S, gamma, lam, nG)
% Weighted-ridge spont fit on S, in b-space. Identical to select_wlasso's l1frac<=0 branch:
% min ||y - Z_S b||^2 + lam*sum (b_i/gamma_i)^2  ->  (G_S + lam*diag(1/gamma^2)) b = c_S.
% NO sparsity and NO constraint on the dip -- blindness comes only from WHICH pixels are in S.
b = zeros(nG,1);
if isempty(S), return; end
g = gamma(S);
b(S) = (Gz(S,S) + lam*diag(1./max(g,eps).^2)) \ cz(S);
end

function v = local_def(o, f, d)
if isfield(o,f) && ~isempty(o.(f)), v = o.(f); else, v = d; end
end
