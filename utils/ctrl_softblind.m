function S = ctrl_softblind(F, lambda_abs, d, leakW, opts)
%CTRL_SOFTBLIND  Ridge fit with a TUNABLE SOFT penalty on the contra stim direction.
%
% THE IDEA. ctrl_deflate forces d'b = 0 (a hard equality): the Global cannot transmit the stim,
% but the flatness is IMPOSED, so "Local captures ~100%" is the constraint restated, not measured
% (RESEARCH 2026-09-05; ctrl_pred_tag notes the same). ctrl_ridge leaves the leak entirely free
% (23-38% on the usable sessions). This function is the ONE knob between them:
%
%     minimise   ||y - Xb||^2 + lambda_abs*||b||^2 + leakW*(d'b)^2
%
% leakW = 0    -> plain ridge (free leak)                        [== A\ctr]
% leakW -> inf -> the hard KKT deflate solution (leak -> 0)      [== ctrl_deflate]
% leakW finite -> an EARNED operating point on the leak<->R^2 tradeoff, chosen per session.
%
% CLOSED FORM (rank-1 update of the ridge solve, no solver, no matrix rebuilt per leakW):
%     A      = Gtr + lambda_abs*I ;  b_free = A\ctr ;  Ad = A\d ;  den = d'*Ad
%     b(leakW) = b_free - Ad * ( leakW/(1+leakW*den) ) * (d'*b_free)
%     d'b      = (d'*b_free) / (1 + leakW*den)          % achieved leak driver, MONOTONE in leakW
% So one (A\d) and one A\ctr give the WHOLE sweep -- pass a vector leakW to trace the tradeoff.
%
% WHY THIS IS MORE HONEST THAN DEFLATE. The leak is not set to zero; it lands where the spont fit
% and the penalty balance, and you REPORT the number you reached. Paired with a held-out d (fit on
% one half of the trials, leak scored on the other -- caller's job, same as ctrl_deflate's guard),
% a low leak that SURVIVES the split is a measured property, not a definition. The R^2 you pay is
% read straight off the curve, so "don't lose too much spontaneous R^2" becomes a stopping rule.
%
% INPUT
%   F           Gram struct from ctrl_gram_build (Gtr,ctr,Gte,cte,sse0*,ss*,mu,sd)
%   lambda_abs  absolute ridge penalty (reuse the value ctrl_ridge_path selected)
%   d           [nG x 1] contra stim direction, z-scored regressor coords
%   leakW       scalar OR vector of leak penalties to evaluate (>= 0)
%   opts        .verbose (false)
%
% OUTPUT S (fields are [1 x numel(leakW)] where they depend on leakW)
%   .leakW      the penalties evaluated
%   .b          [nG x nW] weights per leakW  (nW = numel(leakW))
%   .proj       d'b per leakW  (achieved leak driver; ~0 at large leakW)
%   .proj_free  d'b_free (scalar, leakW=0 reference)
%   .leak_frac  proj ./ proj_free  (1 at leakW=0 -> 0 at inf; the fraction of ridge leak retained)
%   .R2te .R2tr per leakW ;  .R2te_free (scalar)
%   .r2_cost    R2te_free - R2te per leakW
%   .den        d'*(A\d) ;  .dnorm norm(d)
%
% See also CTRL_DEFLATE, CTRL_RIDGE_PATH, CTRL_GRAM_BUILD.

if nargin < 5 || isempty(opts), opts = struct(); end
if ~isfield(opts,'verbose'), opts.verbose = false; end
d = d(:);  leakW = leakW(:).';                 % row vector of penalties
nG = size(F.Gtr,1);
assert(numel(d) == nG, 'ctrl_softblind: d has %d entries, Gram is %dx%d.', numel(d), nG, nG);

A      = F.Gtr + lambda_abs*eye(nG);
b_free = A \ F.ctr;
r2 = @(b) 1 - (F.sse0te - 2*(b.'*F.cte) + b.'*F.Gte*b) / max(F.sste, eps);
r2tr = @(b) 1 - (F.sse0tr - 2*(b.'*F.ctr) + b.'*F.Gtr*b) / max(F.sstr, eps);

S = struct();
S.leakW     = leakW;
S.dnorm     = norm(d);
S.proj_free = d.' * b_free;
S.R2te_free = r2(b_free);

if S.dnorm <= eps
    % No measurable stim direction -> nothing to penalise; every leakW returns the ridge fit.
    nW = numel(leakW);
    S.den = 0;  S.b = repmat(b_free,1,nW);
    S.proj = repmat(S.proj_free,1,nW);  S.leak_frac = ones(1,nW);
    S.R2te = repmat(S.R2te_free,1,nW);  S.R2tr = repmat(r2tr(b_free),1,nW);
    S.r2_cost = zeros(1,nW);  S.degenerate = true;
    return;
end

Ad  = A \ d;
den = d.' * Ad;                                % > 0 (A is SPD)
S.den = den;

nW = numel(leakW);
S.b = zeros(nG,nW);  S.proj = zeros(1,nW);  S.R2te = zeros(1,nW);  S.R2tr = zeros(1,nW);
for k = 1:nW
    coef      = leakW(k) / (1 + leakW(k)*den);           % 0 (ridge) -> 1/den (deflate)
    b         = b_free - Ad * (coef * S.proj_free);
    S.b(:,k)  = b;
    S.proj(k) = d.' * b;                                  % == proj_free/(1+leakW*den)
    S.R2te(k) = r2(b);
    S.R2tr(k) = r2tr(b);
end
S.leak_frac = S.proj ./ S.proj_free;
S.r2_cost   = S.R2te_free - S.R2te;
S.degenerate = false;

if opts.verbose
    fprintf('[ctrl_softblind] %d leakW | d''b %.3g -> [%.3g .. %.3g] | R^2te %.3f -> [%.3f .. %.3f]\n', ...
        nW, S.proj_free, S.proj(1), S.proj(end), S.R2te_free, min(S.R2te), max(S.R2te));
end
end
