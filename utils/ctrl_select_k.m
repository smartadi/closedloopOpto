function K = ctrl_select_k(F, score, opts)
%CTRL_SELECT_K  How many of the least-affected contra pixels should the predictor keep?
%
%   Picks K for ctrl_affected_detect's 'least_affected' rule as the SMALLEST K whose deployed
%   held-out R^2 clears ctrl_r2_floor(). Smallest K = fewest pixels = the most stim-blind
%   predictor that is still good enough to be a Global model, which is exactly the tradeoff the
%   decomposition needs resolved.
%
%   WHY K AND NOT A THRESHOLD. An absolute dip cut asks for contra pixels the laser does not
%   reach; in controller sessions the median contra pixel dips 1-4 SDs, so the cut deletes 70-99%
%   of the grid and the deployed R^2 ends up tracking co-suppression severity rather than model
%   quality (Spearman -0.819, p=0.0011, n=13; RESEARCH 2026-08-10). Ranking removes that coupling:
%   every session keeps a set chosen the same way, and the residual bleed is reported instead of
%   assumed away.
%
%   BOTH DIRECTIONS ARE REPORTED, and both are needed to read any result built on this:
%     more K -> better R^2, but MORE laser bleed in the predictor (Global dips, Local under-reports)
%     less K -> blinder predictor, but weaker R^2 (Global misses, Local over-reports)
%   The returned curve is that tradeoff, and belongs in the supplementary.
%
% INPUT
%   F      Gram struct from ctrl_gram_build.m
%   score  [nG x 1] dip score from ctrl_affected_detect (negative = dips)
%   opts (optional): .floor      R^2 to clear                     (default ctrl_r2_floor())
%                    .nCoarse    coarse sweep resolution          (default 40)
%                    .Kmin       smallest K considered            (default 10)
%                    .max_bleed  hard guard, matches detect       (default Inf)
%                    .verbose    print the sweep                  (default true)
%
% OUTPUT  K (struct)
%   .K_star     the chosen K -> pass as ctrl_affected_detect opts.keep_n
%   .R2_star .bleed_star .Su_star
%   .reachable  false if NO K clears the floor. Then K_star is the best-R^2 K (the session's
%               ceiling) and the caller MUST NOT treat the session as admitted.
%   .R2_ceiling R^2 using the whole grid -- the hard upper bound for this session
%   .Kgrid .R2curve .bleedcurve   the full swept tradeoff
%
%   R^2(K) is not guaranteed monotone, so the search is coarse-then-exhaustive INSIDE the
%   bracketing interval rather than a bisection: the exact smallest clearing K is found within the
%   bracket, and the full curve is returned so an earlier isolated crossing would still be visible.

if nargin < 3 || isempty(opts), opts = struct(); end
if ~isfield(opts,'floor'),     opts.floor     = ctrl_r2_floor(); end
if ~isfield(opts,'nCoarse'),   opts.nCoarse   = 40;    end
if ~isfield(opts,'Kmin'),      opts.Kmin      = 10;    end
if ~isfield(opts,'max_bleed'), opts.max_bleed = Inf;   end
if ~isfield(opts,'verbose'),   opts.verbose   = true;  end

score = score(:);
nG = numel(score);
% SAME ordering ctrl_affected_detect uses -- least negative (least affected) first. Membership is
% still decided there; this function only chooses the COUNT.
[~, ord] = sort(score, 'descend');
if isfinite(opts.max_bleed)
    ord = ord(score(ord) > -opts.max_bleed);      % guard applied before counting
end
nAvail = numel(ord);
Kmin = max(1, min(opts.Kmin, nAvail));

evalK = @(k) local_eval(F, ord, score, k);

% --- coarse sweep -----------------------------------------------------------------
Kc = unique(round(linspace(Kmin, nAvail, max(2,opts.nCoarse))));
R2c = nan(size(Kc));  BLc = nan(size(Kc));
for i = 1:numel(Kc)
    [R2c(i), BLc(i)] = evalK(Kc(i));
end

% --- exact smallest clearing K, searched inside the bracket ------------------------
hit = find(R2c >= opts.floor, 1, 'first');
Kgrid = Kc;  R2curve = R2c;  bleedcurve = BLc;
if ~isempty(hit)
    lo = Kmin;  if hit > 1, lo = Kc(hit-1)+1; end
    Kf = lo:(Kc(hit)-1);
    if ~isempty(Kf)
        R2f = nan(size(Kf));  BLf = nan(size(Kf));
        for i = 1:numel(Kf)
            [R2f(i), BLf(i)] = evalK(Kf(i));
        end
        [Kgrid, si] = sort([Kc, Kf]);
        R2curve = [R2c, R2f];  R2curve = R2curve(si);
        bleedcurve = [BLc, BLf]; bleedcurve = bleedcurve(si);
    end
end

K = struct();
K.Kgrid = Kgrid;  K.R2curve = R2curve;  K.bleedcurve = bleedcurve;
K.floor = opts.floor;  K.nG = nG;  K.nAvail = nAvail;  K.max_bleed = opts.max_bleed;
[K.R2_ceiling, ~] = evalK(nAvail);

ok = find(R2curve >= opts.floor, 1, 'first');
if isempty(ok)
    % No pixel set on this session can clear the floor. Report the best available and flag it --
    % a session whose own ceiling is below the floor is a finding, not something to tune away.
    [K.R2_star, bi] = max(R2curve);
    K.K_star    = Kgrid(bi);
    K.bleed_star = bleedcurve(bi);
    K.reachable = false;
else
    K.K_star    = Kgrid(ok);
    K.R2_star   = R2curve(ok);
    K.bleed_star = bleedcurve(ok);
    K.reachable = true;
end
K.Su_star = sort(ord(1:K.K_star));

if opts.verbose
    fprintf(['[ctrl_select_k] grid %d px (%d available after max_bleed) | ceiling R^2 %.3f | ' ...
             'floor %.2f\n'], nG, nAvail, K.R2_ceiling, opts.floor);
    if K.reachable
        fprintf('[ctrl_select_k] K* = %d  ->  held-out R^2 %.3f, residual bleed (median kept score) %+.2f\n', ...
            K.K_star, K.R2_star, K.bleed_star);
    else
        fprintf(2, ['[ctrl_select_k] NO K clears the floor (best %.3f at K=%d). This session''s own ' ...
                    'ceiling is below %.2f -- it cannot be admitted at any pixel count.\n'], ...
            K.R2_star, K.K_star, opts.floor);
    end
end
end

% ---- local ------------------------------------------------------------------------
function [r2te, bleed] = local_eval(F, ord, score, k)
Su = ord(1:min(k, numel(ord)));
[~, r2te] = ctrl_fitsub(F, Su);
bleed = median(score(Su));
end
