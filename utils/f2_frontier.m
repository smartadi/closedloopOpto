function R = f2_frontier(Q, opt)
%F2_FRONTIER  Adaptive predictor selection: MAXIMISE stim capture subject to a spontaneous-R^2 floor.
%
% THE REQUEST (user, 2026-08-11): "best possible R^2 on spontaneous (>= 0.85 at least) and maximum
% capture of stim by the residual." That is a constrained problem —
%       maximise capture      subject to      held-out spontaneous R^2 >= r2_floor
% — and this solves it by tracing the whole trade-off curve instead of guessing an operating point.
%
% *** READ THIS BEFORE QUOTING A CAPTURE NUMBER FROM HERE ***
% Selecting predictors to maximise capture makes capture a FITTED TARGET, not the independent
% measurement it is under f2_model's R^2-max rule. That is a deliberate, requested change, and it is
% only defensible because of the three guards below. Quote `capVal`, never `capSel`.
%   TRIAL SPLIT      the evoked dips used to SELECT come from trial-half A; the capture REPORTED is
%                    recomputed on half B, which the selection never saw. A penalty that merely
%                    cancels the dip it was shown collapses here. (`capSel` vs `capVal`.)
%   RANDOM CONTROL   the same penalty strength applied to RANDOM directions instead of the evoked
%                    dips. It costs the same R^2. If random buys as much capture, the method is not
%                    finding stim-carrying structure, it is just shrinking the fit.
%   CATCH            (applied downstream in f2_decomp) the final weights on no-stim windows. A
%                    selection that manufactures residual shows up there.
%
% WHY A PENALTY AND NOT A PIXEL SEARCH. Greedy backward elimination over ~300 pixels is a
% combinatorial search with a stopping rule; this is a rank-n_A update to the normal equations, so
% each point on the curve is ONE solve, the curve is deterministic, and you read the operating point
% off the frontier rather than trusting a stopping heuristic. It is also NOT the retired §17b NATIVE
% model: NATIVE imposed b'e = 0 as an exact equality, which always succeeds and therefore carries no
% information. A finite penalty makes the R^2 PRICE of blindness visible, and that price is the
% result — if capture only rises as R^2 falls, coupling is distributed and no amount of selection
% fixes it.
%
%   min_b ||y - Zb||^2 + lamR*sum(b_i/gamma_i)^2 + lamL*sum_a (b'e_a / A_a)^2
%     ->  (G + lamR*diag(1/gamma^2) + lamL*sum_a u_a u_a') b = c ,   u_a = e_a / A_a
%
% INPUT  Q  .G .c            spont Gram + cross-product (z-space, train frames)
%           .gamma .lamR     distance weights + the weighted-L2 already chosen by the R^2-max rule
%           .Zte .yte .muY .sstot     held-out SPONTANEOUS frames (a separate temporal block; this
%                                     R^2 is honest regardless of the trial split)
%           .evSel{nA} .actSel[nA]    per-pixel evoked dip + actual ipsi dip, trial-half A (SELECT)
%           .evVal{nA} .actVal[nA]    the same on half B (VALIDATE); [] -> validation skipped
%           .S                        candidate predictor indices
%           .nP                       full weight-vector length
% OPTS      .r2_floor(0.85) .grid(log sweep, dimensionless) .nRand(5) .verbose(true)
% OUTPUT R  .b .lamL .frac .r2 .capVal .capSel .curve(table) .rand .status .ampsUsed
% -------------------------------------------------------------------------------------------------
if nargin < 2, opt = struct(); end
def = struct('r2_floor',0.85, 'grid',[0 logspace(-3,4,22)], 'nRand',5, 'verbose',true, ...
             'ampFrac',0.25, 'knee_tol',0.02);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}) || isempty(opt.(fn{i})), opt.(fn{i}) = def.(fn{i}); end
end
vb = opt.verbose;  S = Q.S(:).';  nP = Q.nP;

%% ---- which amplitudes may enter the penalty ---------------------------------------------------
% leak_a = (b'e_a)/A_a has A_a in the DENOMINATOR, so an amplitude that produced no response would
% dominate the objective with a ratio built out of noise. Restrict to amps whose actual dip reaches
% a fraction of the strongest -- a within-session relative rule, needing no external calibration.
aRef  = max(abs(Q.actSel));
useA  = find(abs(Q.actSel) >= opt.ampFrac*aRef & isfinite(Q.actSel));
if isempty(useA), useA = find(isfinite(Q.actSel)); end
R.ampsUsed = useA;

% u_a = e_a / A_a  -> b'u_a IS the leak fraction at amp a, so every amp enters on the same scale.
U = zeros(numel(S), numel(useA));
for q = 1:numel(useA)
    a = useA(q);  U(:,q) = Q.evSel{a}(S) / Q.actSel(a);
end
Puu = U*U.';                                        % rank-|useA| penalty operator, on S only

%% ---- does the stim direction TRANSFER between trial halves? -------------------------------------
% The penalty removes the direction e_a estimated on half A. That is only worth anything if half B
% points the same way; if it does not, the penalty silenced half-A noise and capVal will collapse.
% Reported as BOTH:
%   cosine   raw vector alignment -- what the penalty actually acts on, but inflated by the
%            common-mode (every contra pixel dips together, so any two dips share a large offset)
%   Pearson  the same with the common-mode removed -- alignment of the SPATIAL PATTERN, which is
%            the part that can distinguish stim-carrying structure from a global shift
R.transfer = struct('cos',[], 'r',[], 'amps',useA);
if isfield(Q,'evVal') && ~isempty(Q.evVal)
    tc = nan(1,numel(useA));  tr = nan(1,numel(useA));
    for q = 1:numel(useA)
        a  = useA(q);
        ea = Q.evSel{a}(S);  ea = ea(:);
        eb = Q.evVal{a}(S);  eb = eb(:);
        tc(q) = (ea.'*eb) / max(norm(ea)*norm(eb), eps);
        tr(q) = corr(ea, eb);
    end
    R.transfer.cos = tc;  R.transfer.r = tr;
end

Gs   = Q.G(S,S) + Q.lamR*diag(1./max(Q.gamma(S),eps).^2);
cs   = Q.c(S);
% Dimensionless grid: scale so frac=1 makes the leak penalty comparable in size to the data term.
scl  = mean(diag(Q.G(S,S))) / max(mean(diag(Puu)), eps);

r2of = @(b) 1 - sum((Q.yte - (Q.muY + Q.Zte*b)).^2)/Q.sstot;
capf = @(b,ev,ac) 100*(1 - mean(arrayfun(@(a) (b.'*ev{a})/ac(a), useA)));

%% ---- sweep the frontier ------------------------------------------------------------------------
g   = opt.grid(:).';  nG_ = numel(g);
r2v = nan(nG_,1);  cS = nan(nG_,1);  cV = nan(nG_,1);  nAct = nan(nG_,1);  wd = nan(nG_,1);
haveVal = isfield(Q,'evVal') && ~isempty(Q.evVal);
if vb
    fprintf('\n[F2-FRONTIER] maximise capture s.t. held-out spont R^2 >= %.2f | %d candidate px | amps %s\n', ...
            opt.r2_floor, numel(S), mat2str(useA));
    fprintf('   %-10s %10s %12s %12s   %s\n','leakPen','spontR2','capture% SEL','capture% VAL','<- quote VAL');
end
if vb && ~isempty(R.transfer.cos)
    fprintf('   DIRECTION TRANSFER halfA->halfB, per amp:  cos %s | pattern r %s\n', ...
            mat2str(round(R.transfer.cos,2)), mat2str(round(R.transfer.r,2)));
    if median(R.transfer.r,'omitnan') < 0.2
        fprintf(2,['   ** the SPATIAL PATTERN of the evoked dip does not reproduce across trial halves\n' ...
                   '      (median r %.2f): there is no stable direction to silence here. **\n'], ...
                   median(R.transfer.r,'omitnan'));
    end
end
for k = 1:nG_
    b = zeros(nP,1);
    b(S) = (Gs + g(k)*scl*Puu) \ cs;
    r2v(k) = r2of(b);
    cS(k)  = capf(b, Q.evSel, Q.actSel);
    if haveVal, cV(k) = capf(b, Q.evVal, Q.actVal); end
    nAct(k) = nnz(abs(b(S)) > 1e-3*max(abs(b(S))));
    % NOTE the (:) on both operands. Without them one side is a row and MATLAB BROADCASTS to an
    % n-by-n matrix, so sum() returns a vector into a scalar slot -- which errors far from here.
    if isfield(Q,'dist')
        aw = abs(b(S));  aw = aw(:);  dS = Q.dist(S);  dS = dS(:);
        if sum(aw) > 0, wd(k) = sum(aw.*dS)/sum(aw); end
    end
    if vb
        fprintf('   %-10.4g %10.4f %12.0f %12.0f\n', g(k), r2v(k), cS(k), cV(k));
    end
end

%% ---- PICK: the KNEE of the feasible curve, NOT its strongest point ------------------------------
% The obvious rule -- "largest penalty that still clears the floor" -- is WRONG here, and the sweep
% shows why: in most sessions R^2 is still ~0.92-0.98 at the far end of the grid, so the floor never
% binds and the rule walks to lamL -> inf. In that limit the penalty becomes the exact equality
% b'e_a = 0, i.e. the retired 17b NATIVE constraint, which always succeeds and so carries no
% information (capSel is pinned at 100% by construction). Take instead the CHEAPEST penalty that has
% already bought essentially all the available capture -- the knee. Selection uses capSel only, so
% capVal below stays a genuine held-out number.
ok = find(r2v >= opt.r2_floor);
if isempty(ok)
    [~, iB] = max(r2v);  status = 'FLOOR_UNREACHABLE';
    warning(['[F2-FRONTIER] NO grid point reaches spont R^2 >= %.2f (best %.4f). Falling back to the ' ...
             'best-R^2 point; the floor was not met, so do not read the capture as constrained.'], ...
             opt.r2_floor, r2v(iB));
else
    cMax = max(cS(ok));
    kn   = ok(cS(ok) >= cMax - opt.knee_tol*abs(cMax));
    iB   = kn(1);                                    % grid ascends -> first = cheapest
    status = 'OK';
    if iB == numel(g)
        status = 'GRID_EDGE';
        warning(['[F2-FRONTIER] the knee sits at the LAST grid point -- the penalty is effectively the ' ...
                 'NATIVE hard constraint. Widen opt.grid or distrust capSel here.']);
    end
end
bBest = zeros(nP,1);
bBest(S) = (Gs + g(iB)*scl*Puu) \ cs;

%% ---- RANDOM-DIRECTION CONTROL at the SAME penalty strength --------------------------------------
% Penalise random directions of the same rank instead of the evoked dips. The R^2 cost is comparable
% by construction; if the capture gain is too, then the method is shrinking the fit rather than
% removing stim-carrying structure -- the [CP-STIMAFF] (S14) failure mode.
rng(23,'twister');                                   % local seed: control must not depend on call order
if haveVal, evRep = Q.evVal; acRep = Q.actVal; else, evRep = Q.evSel; acRep = Q.actSel; end
rr2 = nan(opt.nRand,1);  rcap = nan(opt.nRand,1);
for it = 1:opt.nRand
    Ur = randn(numel(S), numel(useA));
    Ur = Ur ./ max(vecnorm(Ur), eps) .* vecnorm(U);   % match the column norms of the real penalty
    br = zeros(nP,1);
    br(S) = (Gs + g(iB)*scl*(Ur*Ur.')) \ cs;
    rr2(it)  = r2of(br);
    rcap(it) = capf(br, evRep, acRep);                % scored the same way the real number is
end

R.b = bBest;  R.frac = g(iB);  R.lamL = g(iB)*scl;  R.status = status;
R.r2 = r2v(iB);  R.capSel = cS(iB);  R.capVal = cV(iB);  R.nAct = nAct(iB);
R.r2_price = r2v(1) - r2v(iB);        % R^2 given up to buy blindness -- the informative quantity
R.cap_gain = cV(iB) - cV(1);          % capture bought on HELD-OUT trials, vs the unpenalised fit
R.curve = struct('frac',g(:), 'r2',r2v, 'capSel',cS, 'capVal',cV, 'nAct',nAct, 'wdist',wd, ...
                 'iPick',iB, 'r2_floor',opt.r2_floor);
R.rand = struct('r2',rr2, 'cap',rcap, 'r2_mean',mean(rr2,'omitnan'), 'cap_mean',mean(rcap,'omitnan'));

if vb
    fprintf(2,'   [PICK knee] leakPen %.4g -> spont R^2 %.4f (floor %.2f) | capture SEL %.0f%% / VAL %.0f%%\n', ...
            R.frac, R.r2, opt.r2_floor, R.capSel, R.capVal);
    fprintf(['   PRICE OF BLINDNESS: R^2 %.4f -> %.4f (cost %.4f) buys held-out capture %.0f%% -> %.0f%%' ...
             ' (gain %+.0f pts)\n'], r2v(1), R.r2, R.r2_price, cV(1), R.capVal, R.cap_gain);
    fprintf('   RANDOM-direction control at the same strength: R^2 %.4f, capture %.0f%%\n', ...
            R.rand.r2_mean, R.rand.cap_mean);
    if isfinite(R.capVal) && R.capVal > 105
        fprintf(2,['   ** capture %.0f%% EXCEEDS 100%%: Global moves the WRONG way on held-out trials.\n' ...
                   '      That is overshoot from an over-strong penalty, not extra evidence. **\n'], R.capVal);
    end
    if isfinite(R.rand.cap_mean) && R.rand.cap_mean >= R.capVal - 5
        fprintf(2,['   ** random directions buy the SAME capture at the same R^2 cost: this is shrinkage,\n' ...
                   '      not removal of stim-carrying structure. Do NOT treat the residual as validated. **\n']);
    end
    if isfinite(R.capVal) && isfinite(R.capSel) && R.capVal < 0.6*R.capSel
        fprintf(2,['   ** capture did NOT transfer to held-out trials (%.0f%% VAL vs %.0f%% SEL): the penalty\n' ...
                   '      cancelled the trial-average dip it was shown, not a reproducible one. **\n'], ...
                   R.capVal, R.capSel);
    end
end
end
