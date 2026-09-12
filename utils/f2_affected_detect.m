function R = f2_affected_detect(P, opts)
%F2_AFFECTED_DETECT  RANK-based stim-affected contra-pixel detector for the impulse Fig-2 stream.
%
% Replaces the brittle ABSOLUTE TF-sensitivity cut (a per-session tf_sens threshold, "mostly wrong in
% a lot of sessions"). The PRIMARY criterion is the AMP-vs-EFFECT MONOTONICITY gate: a pixel is stim-
% affected iff its dip GROWS monotonically with laser amplitude (Spearman(amp, per-amp dip) <= -thr),
% because bleed and optical/vascular coupling scale with power -- that dose-response shape, not an
% absolute dip size, is the physically correct signature and it does not depend on a per-session
% threshold. (This is the amp-graded signal cp_stimaffect [CP-BLEED] tests; here it gates selection.)
%
% PER-AMP DIP (delegated to ctrl_affected_detect so there is ONE dip-score formula in the repo): on
% the trial-averaged per-amp peri-stim %dF/F trace of each pixel, score = (dip - onset_ref)/pre_SD,
% "dip" = mean over that amp's inhibition window P.dcc (0-200 ms) = f2's inhibition energy. The gate
% correlates that per-amp dip against amplitude; a guard also requires the pixel to actually dip at
% the strongest amp (min_dip) so a monotone-but-flat pixel is not flagged.
%
% METHODS (opts.method)
%   'monotone'       (DEFAULT) affected where Spearman(amp,dip) <= -mono_thr AND dips at strongest amp.
%   'least_affected' RANK by worst-amp dip, keep the K least-affected; K = opts.keep_n, or auto (the
%                    smallest K whose held-out spont R^2, from f2_model, clears opts.r2_floor).
%   'dip'            absolute cut: worst-amp dip score < -opts.thr (the old brittle rule, for compare).
%
% INPUT  P     from f2_prep
%        opts  .method(monotone) .mono_thr(0.5) .min_dip(0.3)
%              .keep_n [] .keep_frac [] .r2_floor(0.85) .nCoarse(30) .Kmin(8) .thr(1.33)  .verbose(true)
% OUTPUT R     f2_affected-COMPATIBLE so f2_model / f2_tuner consume it interchangeably:
%              .affected [nG x nA] logical (pooled mask replicated per amp), .unaff_pooled, .nAff,
%              .tf_sens (NaN -- not a TF cut), .saved_on, .file ('' -- in-memory)
%              plus rank extras: .score .rank .K .K_reachable .r2_at_K .bleed_kept .curve .method
% -------------------------------------------------------------------------------------------------
if nargin < 2 || isempty(opts), opts = struct(); end
def = struct('method','monotone','mono_thr',0.5,'min_dip',0.3, ...
             'keep_n',[],'keep_frac',[],'r2_floor',0.85, ...
             'nCoarse',30,'Kmin',8,'thr',1.33,'verbose',true);
fn = fieldnames(def);
for i = 1:numel(fn)
    % Fill any field the caller left out; also fill empties EXCEPT keep_n/keep_frac, whose emptiness
    % is meaningful ([] = choose K automatically).
    absent = ~isfield(opts, fn{i});
    emptyButFillable = ~absent && isempty(opts.(fn{i})) && ~ismember(fn{i}, {'keep_n','keep_frac'});
    if absent || emptyButFillable, opts.(fn{i}) = def.(fn{i}); end
end

nG = P.nG;  nA = P.nA;  preN = P.preN;  Wb = P.Wb;

% ---- per-amp trial-averaged peri-stim %dF/F per pixel, then the pooled dip score ------------------
% Score each amplitude separately (via the shared ctrl_affected_detect), then pool by the worst amp.
iPre = 1:preN;  iRef = 1:preN;                        % impulse pre-window is short; ref = pre-mean, SD = pre-wobble
scoreAmp = nan(nG, nA);  periAvgC = cell(nA,1);
for ai = 1:nA
    on = P.onFcell{ai};  if isempty(on), continue; end
    idx = on(:).' + P.rel(:);                         % [Wb x nTr] frame indices
    per = P.Ug * double(P.V(:, idx(:)));              % [nG x Wb*nTr] reconstructed %dF/F
    per = reshape(per, nG, Wb, numel(on));
    periAvg = mean(per, 3);                           % [nG x Wb] trial-averaged, NOT baseline-subtracted
    periAvgC{ai} = periAvg;
    dc = P.dcc{ai};  if isempty(dc), dc = (preN+1):Wb; end
    W = struct('iPre',iPre, 'iRef',iRef, 'iStim',dc);
    Rai = ctrl_affected_detect(periAvg, W, struct('method','dip','thr',opts.thr,'wlen',numel(dc)));
    scoreAmp(:,ai) = Rai.score;                       % (mean over dc - pre-mean)/pre-SD ; negative = dips
end
poolScore = min(scoreAmp, [], 2, 'omitnan');          % worst (most negative) amp per pixel -- dip magnitude
poolScore(~isfinite(poolScore)) = 0;

% ---- amp-vs-effect MONOTONICITY: Spearman(amplitude, per-amp dip) per pixel ----------------------
% The physically-correct signature of a stim-driven / bleed pixel is that its effect GROWS with laser
% power (bleed & optical/vascular coupling scale with amplitude -- locked finding). rho near -1 = the
% dip deepens monotonically with amplitude = affected; rho >= 0 = flat / inconsistent = NOT stim-
% driven, keep it. This needs no absolute dip threshold (which differs per session and was "mostly
% wrong in a lot of sessions") -- the shape of the dose-response decides.
va = find(any(isfinite(scoreAmp),1) & isfinite(P.amps(:).'));
mono = zeros(nG,1);
if numel(va) >= 3
    avec = reshape(P.amps(va), [], 1);               % [nva x 1] column (orientation-safe)
    mono = corr(avec, scoreAmp(:,va).', 'type','Spearman','rows','pairwise').';
end
mono(~isfinite(mono)) = 0;

curve = struct('K',[],'r2',[]);  K_reachable = true;  r2_at_K = NaN;
switch lower(opts.method)
    case 'monotone'
        [~,aMax] = max(P.amps(:));  dipStrong = scoreAmp(:,aMax);        % dips at the strongest amp?
        affVec = (mono(:) <= -opts.mono_thr) & (dipStrong(:) < -opts.min_dip);
        affVec(~isfinite(affVec)) = false;
        score = mono;                                                    % GUI colours by monotonicity
        [~, ord] = sort(mono, 'descend');                               % least affected (rho>=0) first
        K = nnz(~affVec);
    case 'least_affected'
        score = poolScore;
        [~, ord] = sort(poolScore, 'descend');                          % least negative (least affected) first
        if ~isempty(opts.keep_n) || ~isempty(opts.keep_frac)
            K = opts.keep_n;  if isempty(K), K = round(opts.keep_frac*nG); end
            K = max(5, min(nG, round(K)));
            r2_at_K = local_r2_at(P, ord, K);
        else
            [K, curve, K_reachable, r2_at_K] = local_autoK(P, ord, opts);
        end
        affVec = true(nG,1);  affVec(ord(1:K)) = false;
    case 'dip'
        score = poolScore;
        affVec = poolScore < -opts.thr;
        [~, ord] = sort(poolScore, 'descend');  K = nnz(~affVec);
    otherwise
        error('f2_affected_detect: unknown method ''%s'' (monotone | least_affected | dip).', opts.method);
end
rank = zeros(nG,1);  rank(ord) = (1:nG).';
keep = ~affVec;
affected = repmat(affVec(:), 1, nA);                  % pooled mask -> same at every amp

R = struct();
R.affected     = affected;
R.unaff_pooled = find(keep);
R.nAff         = sum(affected, 1);
R.tf_sens      = NaN;                                 % not a TF cut
R.saved_on     = datestr(now);
R.file         = '';
R.score        = score;                              % method-dependent map score (mono, or dip magnitude)
R.mono         = mono;                               % amp-vs-effect Spearman rho (always computed)
R.poolScore    = poolScore;                          % worst-amp dip magnitude (always computed)
R.rank         = rank;
R.ord          = ord;
R.K            = K;
R.K_reachable  = K_reachable;
R.r2_at_K      = r2_at_K;
R.bleed_kept   = median(poolScore(keep),'omitnan');   % residual dip magnitude of the KEPT set (report it)
R.bleed_worst  = min(poolScore(keep),[],'omitnan');
R.curve        = curve;
R.method       = lower(opts.method);
R.opts         = opts;
R.scoreAmp     = scoreAmp;                            % [nG x nA] per-amp dip score (for the selector GUI)
R.periAvg      = periAvgC;                            % {nA} trial-avg peri-stim %dF/F per pixel (click view)

if opts.verbose
    fprintf('[f2_affected_detect] %s | method=%s | %d affected, %d kept of %d px (%.0f%% kept)\n', ...
            P.label, R.method, sum(affVec), K, nG, 100*K/nG);
    switch R.method
        case 'monotone'
            fprintf('   amp-monotonicity gate: rho <= -%.2f AND dips at strongest amp | residual dip bleed %+.2f\n', ...
                    opts.mono_thr, R.bleed_kept);
        case 'least_affected'
            if K_reachable
                fprintf('   held-out spont R^2 at K = %.3f (floor %.2f) | residual dip bleed %+.2f\n', ...
                        r2_at_K, opts.r2_floor, R.bleed_kept);
            else
                fprintf(2,'   ** NO K clears the floor %.2f (best %.3f) -- treat with care **\n', opts.r2_floor, r2_at_K);
            end
        case 'dip'
            fprintf('   absolute dip cut: score < -%.2f | residual dip bleed %+.2f\n', opts.thr, R.bleed_kept);
    end
end
end

% ================================================================================================
function r2 = local_r2_at(P, ord, K)
% Held-out spontaneous R^2 for the keep-set of the K least-affected pixels, via f2_model (r2max).
keep = false(P.nG,1);  keep(ord(1:min(K,numel(ord)))) = true;
A = struct('affected', repmat(~keep,1,P.nA), 'unaff_pooled', find(keep), ...
           'nAff', sum(~keep)*ones(1,P.nA), 'tf_sens', NaN, 'saved_on','', 'file','');
try
    M = f2_model(P, A, struct('select_mode','r2max','use_affected',true,'use_motion',false,'verbose',false));
    r2 = M.r2_spont;
catch
    r2 = NaN;                                          % too few px / degenerate -> not a usable K
end
end

function [Kstar, curve, reachable, r2star] = local_autoK(P, ord, opts)
% Smallest K whose held-out spont R^2 clears opts.r2_floor. Coarse sweep, then the exact smallest K
% inside the clearing bracket (R^2(K) is not guaranteed monotone).
nAvail = numel(ord);
Kmin = max(5, min(opts.Kmin, nAvail));
Kc = unique(round(linspace(Kmin, nAvail, max(2, opts.nCoarse))));
r2c = arrayfun(@(k) local_r2_at(P, ord, k), Kc);
hit = find(r2c >= opts.r2_floor, 1, 'first');
Kgrid = Kc;  r2grid = r2c;
if ~isempty(hit)
    lo = Kmin;  if hit > 1, lo = Kc(hit-1)+1; end
    Kf = lo:(Kc(hit)-1);
    if ~isempty(Kf)
        r2f = arrayfun(@(k) local_r2_at(P, ord, k), Kf);
        [Kgrid, si] = sort([Kc, Kf]);  r2grid = [r2c, r2f];  r2grid = r2grid(si);
    end
end
curve = struct('K', Kgrid, 'r2', r2grid);
ok = find(r2grid >= opts.r2_floor, 1, 'first');
if isempty(ok)
    [r2star, bi] = max(r2grid);  Kstar = Kgrid(bi);  reachable = false;
else
    Kstar = Kgrid(ok);  r2star = r2grid(ok);  reachable = true;
end
end
