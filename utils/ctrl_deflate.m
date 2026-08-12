function D = ctrl_deflate(F, lambda_abs, d, opts)
%CTRL_DEFLATE  Ridge fit constrained to be BLIND to the contralateral stim direction.
%
% THE PROBLEM IT SOLVES. Global is meant to be the counterfactual "what the site would have done
% with no laser". It is not: it dips during the stim, and that dip (the "leak") is subtracted out
% of Local, understating the local effect. Across 13 controller sessions the leak is predicted by
% ONE scalar -- the alignment of the weights with the per-pixel contra co-suppression pattern:
%     Spearman(leak%, b'*dip)      = -0.91        Spearman(Global trough, b'*dip) = 0.89
%     Spearman(leak%, ||b||)       =  0.51
% Shrinkage (ridge) only ever reached this indirectly, by shrinking every direction at once
% including the ones carrying the signal. This constrains the offending direction alone.
%
% THE CONSTRAINT.  minimise  ||y - Xb||^2 + lambda||b||^2   subject to   d'b = 0
% where d is the contra stim-response direction in the SAME z-scored coordinates as the
% regressors. One linear equality, so it is closed-form -- no solver:
%     A    = Gtr + lambda*I
%     b_c  = b_ridge - A\d * (d'*(A\d))^{-1} * (d'*b_ridge)
% b_c is the ridge solution projected onto the null space of d in the A-metric. To first order the
% Global response to the stim pattern is then exactly zero, by construction rather than by tuning.
%
% ⚠ WHAT THIS COSTS, AND WHY IT IS NOT CIRCULAR.
%   d is estimated from STIM trials -- it has to be, because contra co-suppression only exists
%   while the laser is on. So the predictor is no longer stim-blind in the strict sense the ridge
%   and rank models were: it is fit on laser-off frames only, but the direction it is forbidden to
%   use was measured with the laser on. That is a real methodological change and must be stated.
%   The circularity worry is that forcing Global flat mechanically inflates Local -- i.e. that the
%   answer is being defined rather than measured. The guard is opts.d_hold: estimate d on one half
%   of the trials and report the leak on the OTHER half. A leak reduction that survives that split
%   is a property of the stim direction, not of the trials it was measured on. The caller is
%   expected to use it; this function returns whatever d it is handed.
%
% INPUT
%   F           Gram struct from ctrl_gram_build (same object the ridge path uses)
%   lambda_abs  ABSOLUTE ridge penalty (i.e. lambda_rel * mean(diag(F.Gtr))), so the caller can
%               reuse the value ctrl_ridge_path already selected
%   d           [nG x 1] contra stim direction in z-scored regressor coordinates
%   opts        .verbose (true)
%
% OUTPUT D
%   .b          constrained weights          .b_free  the unconstrained ridge weights
%   .R2te .R2tr                              .R2te_free .R2tr_free
%   .proj_free  d'*b_free   (the leak driver before)   .proj  d'*b  (~0 by construction)
%   .r2_cost    R2te_free - R2te             .dnorm   norm(d)
%
% See also CTRL_RIDGE_PATH, CTRL_GRAM_BUILD.

if nargin < 4 || isempty(opts), opts = struct(); end
if ~isfield(opts,'verbose'), opts.verbose = true; end

nG = size(F.Gtr,1);
d  = d(:);
assert(numel(d) == nG, 'ctrl_deflate: d has %d entries, Gram is %dx%d.', numel(d), nG, nG);

A = F.Gtr + lambda_abs*eye(nG);
b_free = A \ F.ctr;

r2 = @(b, sse0, c, G, ss) 1 - (sse0 - 2*(b.'*c) + b.'*G*b) / max(ss, eps);

dn = norm(d);
if dn <= eps
    % No measurable stim direction on this session -- nothing to deflate. Return the ridge fit
    % rather than dividing by zero, and say so.
    D = struct('b',b_free,'b_free',b_free,'degenerate',true);
    D.proj_free = 0;  D.proj = 0;  D.dnorm = 0;
else
    Ad   = A \ d;
    den  = d.' * Ad;
    b_c  = b_free - Ad * ((d.' * b_free) / den);
    D = struct('b',b_c,'b_free',b_free,'degenerate',false);
    D.proj_free = d.' * b_free;   D.proj = d.' * b_c;   D.dnorm = dn;
end

D.R2te      = r2(D.b,      F.sse0te, F.cte, F.Gte, F.sste);
D.R2tr      = r2(D.b,      F.sse0tr, F.ctr, F.Gtr, F.sstr);
D.R2te_free = r2(D.b_free, F.sse0te, F.cte, F.Gte, F.sste);
D.R2tr_free = r2(D.b_free, F.sse0tr, F.ctr, F.Gtr, F.sstr);
D.r2_cost   = D.R2te_free - D.R2te;
D.lambda_abs = lambda_abs;
D.nrm = norm(D.b);  D.nrm_free = norm(D.b_free);

if opts.verbose
    fprintf(['[ctrl_deflate] d''b: %.3g -> %.3g  |  held-out R^2 %.3f -> %.3f (cost %.3f)  |  ' ...
             '||b|| %.1f -> %.1f\n'], D.proj_free, D.proj, D.R2te_free, D.R2te, D.r2_cost, ...
             D.nrm_free, D.nrm);
    if D.degenerate
        fprintf(2, ['[ctrl_deflate] ⚠ the stim direction is numerically zero on this session -- ' ...
                    'nothing was deflated and this is the plain ridge fit.\n']);
    end
end
end
