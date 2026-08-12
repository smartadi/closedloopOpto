function P = ctrl_ridge_path(F, Xg, frames, rel, bwin, swin, opts)
%CTRL_RIDGE_PATH  Ridge path for the contra->ipsi predictor, with lambda picked STIM-BLIND.
%
% THE ALTERNATIVE MODEL to pixel selection. Instead of asking which contra pixels the laser
% touches and dropping them, this keeps the WHOLE grid and shrinks the weights, then picks the
% shrinkage from laser-OFF data alone.
%
% WHY. On the impulse side the Global leak turned out to scale with ||b||, not with which pixels
% were included: ridge 0 -> leak 94%, ridge 0.3 -> leak 7%, for a 4% cost in prediction amplitude
% (RESEARCH 2026-08-11). Mechanism: the stim signature lives in the small-eigenvalue,
% high-collinearity directions of the contra Gram, nearly orthogonal to the dominant spontaneous
% covariance -- so a variance prior removes it almost for free. That also explains retroactively
% why dropping pixels ever helped: fewer pixels = less collinearity = smaller ||b||. Pixel
% selection was an indirect, per-session, uncalibrated regulariser. This is the direct one.
% The controller-side evidence for the same mechanism (2026-08-12 cache audit): the three sessions
% whose selector stopped early (~100-150 of ~450 px) leak 14-17%, while every session pushed to the
% full grid chasing R^2 leaks 25-66%.
%
% HOW LAMBDA IS CHOSEN -- the CATCH-FLOOR rule, and why not R^2.
%   Held-out spontaneous R^2 is maximised at lambda ~ 0, so it cannot pick the shrinkage: it is
%   blind to the very thing lambda is for. Instead the operator is applied to CATCH windows --
%   peri-stim-shaped windows drawn entirely from laser-off frames -- and baselined identically to
%   a real trial. Under a perfect operator a catch window yields zero deflection; what it actually
%   yields is the operator's own spurious swing, which falls as lambda grows. Lambda is taken where
%   that swing STOPS falling (within `tol` of its asymptote over the sweep).
%   This rule never looks at a stim trial, so it cannot launder stim information into the model --
%   which is the whole property pixel-dropping was there to provide.
%
%   ⚠ NOT ASSUMED TO WORK. On the impulse side a FIXED lambda=0.3 did NOT hold across sessions
%   (RESEARCH 2026-08-11) -- which is exactly why lambda is selected per session here, and why
%   P.catch_falls is returned: if the catch swing does not fall with lambda on a session, the
%   premise fails there and the caller must say so rather than quietly taking the knee.
%
% INPUT
%   F       Gram struct from ctrl_gram_build (FULL grid), giving R^2 with no frame access
%   Xg      [nG x T] contra grid timecourses, whole session
%   frames  [1 x nF] spontaneous (laser-off) frame indices, from Stage 1
%   rel     [1 x nRel] peri-stim sample offsets (the real trial window shape)
%   bwin    column indices into rel used as the per-trial baseline
%   swin    column indices into rel scored as the stim window
%   opts    .lambdas   ridge grid, RELATIVE to mean(diag(Gtr))   (default logspace(-8,1,28))
%           .nCatch    number of catch windows                   (default 200)
%           .tol       "stopped falling" tolerance, fraction     (default 0.10)
%           .seed      rng seed for catch draws                  (default 7)
%           .verbose                                             (default true)
%
% OUTPUT P
%   .lambda_star .b_star .R2te_star .catch_star .nrm_star
%   .lambdas .R2te .R2tr .nrm .catchdef      the full path (belongs in the supplementary)
%   .catch_falls  false if the catch swing never drops meaningfully -> premise failed here
%   .nCatch .scale                            scale = mean(diag(Gtr)), lambda_abs = lambda*scale

if nargin < 7 || isempty(opts), opts = struct(); end
if ~isfield(opts,'lambdas'), opts.lambdas = logspace(-8,1,28); end
if ~isfield(opts,'nCatch'),  opts.nCatch  = 200;   end
if ~isfield(opts,'tol'),     opts.tol     = 0.10;  end
if ~isfield(opts,'tol_r2'),  opts.tol_r2  = 0.02;  end
if ~isfield(opts,'seed'),    opts.seed    = 7;     end
if ~isfield(opts,'verbose'), opts.verbose = true;  end

nG    = size(F.Gtr,1);
scale = mean(diag(F.Gtr));
lams  = opts.lambdas(:).';
nL    = numel(lams);

%% ---- catch windows: peri-stim-shaped, drawn entirely from laser-off frames ----
% A window is admissible only if EVERY sample it needs is spontaneous, so no catch window can
% straddle a laser epoch. Drawn from the spontaneous set the predictor was fitted on, which is
% what makes the whole selection stim-blind.
% ⚠ WHY opts.spontMask EXISTS (2026-08-12). `frames` is NOT usable for this on every session.
% ctrl_ols_spont caps the spontaneous set at maxFrm = 60000 with
%     frames = frames(round(linspace(1,numel(frames),maxFrm)))
% -- an evenly spaced DECIMATION. Above the cap that leaves no two consecutive samples anywhere,
% so no peri-stim-shaped window is ever fully inside `frames` and this function used to abort with
% "0 admissible catch windows". It failed on exactly the four sessions at the 60000 cap
% (0212, 0224, 0226, AL_0039_0419) and succeeded on every session below it -- which is why the
% ridge build silently covered only 9 of 13 sessions and the reason was never recorded.
% The caller therefore passes the UN-decimated laser-off mask, rebuilt from the stim onsets. The
% ridge fit itself still uses the decimated `frames` via the Gram; only window admissibility needs
% contiguity, and contiguity is a property of the recording, not of the subsample.
if isfield(opts,'spontMask') && ~isempty(opts.spontMask)
    isSpont = false(1, numel(opts.spontMask)+max(rel)+1);
    isSpont(1:numel(opts.spontMask)) = logical(opts.spontMask(:).');
    frames = find(isSpont);
else
    isSpont = false(1, max(frames)+max(rel)+1);
    isSpont(frames) = true;
end
lo = 1 - min(rel);  hi = numel(isSpont) - max(rel);
cand = frames(frames >= lo & frames <= hi);
ok = false(size(cand));
for i = 1:numel(cand)
    ok(i) = all(isSpont(cand(i)+rel));
end
cand = cand(ok);
rs = RandStream('twister','Seed',opts.seed);          % local stream: does not disturb global rng
if numel(cand) > opts.nCatch
    cOn = cand(randperm(rs, numel(cand), opts.nCatch));
else
    cOn = cand;                                        % take them all if the session is short
end
nC = numel(cOn);
assert(nC >= 10, ['ctrl_ridge_path: only %d admissible catch windows -- too few to calibrate. ' ...
    'Check the Stage-1 spontaneous frame list.'], nC);

% Catch windows in Z space, ONCE (independent of lambda): the operator is linear, so the whole
% path is a matrix product against these rather than nL rebuilds.
Zc = zeros(nC*numel(rel), nG);
for j = 1:nC
    W = ((Xg(:, cOn(j)+rel) - F.mu)./F.sd).';          % [nRel x nG], train z-score
    Zc((j-1)*numel(rel)+(1:numel(rel)), :) = W;
end

%% ---- sweep -------------------------------------------------------------------
R2te = nan(1,nL);  R2tr = nan(1,nL);  nrm = nan(1,nL);  catchdef = nan(1,nL);
B = zeros(nG, nL);
I = eye(nG);
for i = 1:nL
    b = (F.Gtr + lams(i)*scale*I) \ F.ctr;
    B(:,i) = b;
    R2tr(i) = 1 - (F.sse0tr - 2*(b.'*F.ctr) + b.'*F.Gtr*b) / max(F.sstr, eps);
    R2te(i) = 1 - (F.sse0te - 2*(b.'*F.cte) + b.'*F.Gte*b) / max(F.sste, eps);
    nrm(i)  = norm(b);
    % catch deflection: predict, reshape to windows, baseline like a real trial, score the stim
    % window. Magnitude, not signed -- a biphasic swing must not cancel itself to zero and pass.
    g = reshape(Zc*b, numel(rel), nC).';                % [nC x nRel]
    g = g - mean(g(:,bwin), 2);
    catchdef(i) = mean(abs(mean(g(:,swin), 2)));
end

%% ---- pick lambda: smallest lambda whose catch swing has stopped falling -------
cmin = min(catchdef);  cmax = max(catchdef);
P = struct();
% ⚠ CORRECTED 2026-08-12 -- the first version of this rule was WRONG and the error is instructive.
% It took "smallest lambda whose catch swing is within tol of the swept MINIMUM". But the catch
% swing is the deflection of an operator whose weights are being shrunk toward zero: it decreases
% MONOTONICALLY to 0 as lambda grows, because a null operator deflects by nothing. Its minimum is
% therefore always at the top of the grid, and the rule selected the largest lambda available --
% 5 of 9 sessions railed at lambda = 10 with ||b|| ~ 0.1 and R^2 collapsing to 0.43-0.69. A
% criterion that is minimised by the trivial model cannot select a model.
%
% The rule now trades the two against each other, which is what the impulse-side result actually
% says ("a 4% loss of prediction amplitude buys a 13x reduction in leak"): take the LARGEST
% lambda -- the most shrinkage, so the least leak -- that still holds held-out R^2 within
% `tol_r2` of its own maximum. Prediction quality is the constraint; blindness is what is bought
% with the slack. The catch swing is then REPORTED at that lambda rather than optimised, and
% catch_falls stays as the diagnostic saying whether shrinkage bought anything at all.
r2max = max(R2te);
ok_r2 = find(R2te >= r2max - opts.tol_r2);
ix = ok_r2(end);                       % largest admissible lambda
P.catch_falls = (cmax - cmin) > opts.tol*max(abs(cmax), eps);   % did the swing move at all?
P.r2_max = r2max;  P.r2_cost = r2max - R2te(ix);
% A pick sitting on either end of the grid means the grid, not the data, chose it.
P.at_edge = (ix == 1) || (ix == nL);

P.lambdas = lams;  P.R2te = R2te;  P.R2tr = R2tr;  P.nrm = nrm;  P.catchdef = catchdef;
P.scale = scale;  P.nCatch = nC;  P.ix = ix;
P.lambda_star = lams(ix);   P.lambda_abs = lams(ix)*scale;
P.b_star = B(:,ix);  P.R2te_star = R2te(ix);  P.R2tr_star = R2tr(ix);
P.catch_star = catchdef(ix);  P.nrm_star = nrm(ix);
P.R2te_at0 = R2te(1);  P.catch_at0 = catchdef(1);  P.nrm_at0 = nrm(1);

if opts.verbose
    fprintf(['[ctrl_ridge_path] %d px | %d catch windows | lambda* = %.3g (x mean diag) | ' ...
             'held-out R^2 %.3f\n'], nG, nC, P.lambda_star, P.R2te_star);
    fprintf(['                  vs lambda~0: R^2 %.3f -> %.3f (%.1f%% cost), ' ...
             'catch swing %.4f -> %.4f (%.1fx), ||b|| %.1f -> %.1f\n'], ...
        P.R2te_at0, P.R2te_star, 100*(P.R2te_at0-P.R2te_star)/max(abs(P.R2te_at0),eps), ...
        P.catch_at0, P.catch_star, P.catch_at0/max(P.catch_star,eps), P.nrm_at0, P.nrm_star);
    fprintf('                  R^2 cost vs its own max: %.3f (tol %.3f)\n', P.r2_cost, opts.tol_r2);
    if ~P.catch_falls
        fprintf(2, ['[ctrl_ridge_path] ⚠ the catch swing does NOT move with lambda on this ' ...
                    'session -- shrinkage buys no measurable blindness here. Do not claim ' ...
                    'stim-blindness for this session.\n']);
    end
    if P.at_edge
        fprintf(2, ['[ctrl_ridge_path] ⚠ lambda* sits at the EDGE of the swept grid -- the grid ' ...
                    'chose it, not the data. Widen opts.lambdas before using this session.\n']);
    end
end
end
