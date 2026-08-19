function R = ctrl_affected_detect(periAvg, W, opts)
%CTRL_AFFECTED_DETECT  Which contra grid pixels are touched by the laser?
%
%   THE ONE PLACE THIS DECISION IS MADE. The stim-blind decomposition stands or
%   falls on this call: every pixel it marks AFFECTED is dropped from the Global
%   predictor, and every pixel it wrongly marks UNAFFECTED leaks laser drive into
%   Global and so silently shrinks Local. Before 2026-08-10 the same formula was
%   copy-pasted into ctrl_ols_ol_stimblind.m (local_dip_score) and
%   ctrl_affected_gui.m (dip_score_), which meant the threshold you tuned in the
%   GUI and the rule that actually built the predictor could drift apart. They now
%   both call this, so tuning the ALGORITHM means editing this file only.
%
%   INPUT
%     periAvg  [nG x nRel]  TRIAL-AVERAGED peri-stim traces, %dF/F, NOT
%                           baseline-subtracted (average trials first, then measure)
%     W        struct of column-index vectors into periAvg:
%                .iPre   baseline window, e.g. [-6,0) s   (wobble -> the SD normaliser)
%                .iRef   onset reference,  e.g. [-1,0) s  (the level the dip is measured from)
%                .iStim  stim window,      e.g. [0,dur] s (where the trough is looked for)
%     opts     see DEFAULTS below; unset fields are filled in.
%
%   OUTPUT  R
%     .affected [nG x 1] logical -- DROP these from the predictor
%     .unaff    [nG x 1] logical -- complement
%     .score    [nG x 1] dip score, NEGATIVE = dips (see 'dip' below)
%     .trough / .ref / .sd / .iTrough   the score's ingredients (for the GUI inspector)
%     .cosSim   [nG x 1] shape match to the dip template (NaN unless a shape method ran)
%     .method / .opts / .nAff / .note
%
%   METHODS
%     'least_affected'  (PRIMARY for controller sessions, 2026-08-10)
%        RANK-based, not an absolute cut: order pixels by dip score DESCENDING (least negative =
%        least affected) and keep the top `keep_n`. Everything else is 'affected'.
%
%        WHY THIS EXISTS. The absolute rule below asks for contra pixels the laser does not reach.
%        In controller sessions those barely exist -- the MEDIAN contra pixel dips 1-4 pre-window
%        SDs (RESEARCH 2026-08-10), because contralateral co-suppression is real and distributed.
%        A fixed threshold therefore deletes 70-99% of the grid, the predictor collapses to 2-26
%        pixels, and the deployed R^2 ends up measuring how strongly THAT SESSION co-suppresses
%        (Spearman(%flagged, R^2) = -0.819, p=0.0011, n=13) rather than anything about the model.
%        Ranking sidesteps that: you cannot get pixels that are unaffected in absolute terms, so
%        you take the least affected ones available and REPORT the residual bleed instead of
%        pretending it is zero. Two numbers must travel with any result built on this:
%        `bleed_kept` (how affected the kept set still is) and Stage 2's `leak` (how much the
%        Global trace itself dips through the stim).
%
%        K is normally not set by hand -- utils/ctrl_select_k.m sweeps it and takes the SMALLEST K
%        whose deployed held-out R^2 clears ctrl_r2_floor(), i.e. the most stim-blind pixel set
%        that is still a usable predictor.
%
%     'dip'  (the locked ABSOLUTE rule -- numerically identical to the pre-2026-08-10 code)
%        ref    = mean over iRef                      (level AT ONSET, not the long pre-mean, so a
%                                                      pixel that starts high and dips still reads
%                                                      clearly negative)
%        trough = min over a sliding wlen-sample mean across iStim
%                                                     (a transient dip that recovers before the stim
%                                                      window ends still counts)
%        sd     = std over iPre
%        score  = (trough - ref)/sd ;  AFFECTED where score < -thr   (downward only)
%
%     'dip_or_shape'  OR-gate for pixels the amplitude cut underfits. Affected if the 'dip' rule
%        fires, OR the pixel's stim-window shape matches the reference dip template
%        (cosine > cos_thr) while still dipping past a relaxed thr_lo. This is the controller-side
%        twin of the impulse pipeline's planned P3 OR-gate (TASKS: "TF affected-detection
%        SENSITIVITY"). More sensitive, so it keeps FEWER predictor pixels -- check the held-out
%        R^2 against ctrl_r2_floor() before adopting it.
%
%   Adding a method: implement it in the switch below, return the same fields, and leave 'dip'
%   untouched so previously built caches stay reproducible.

if nargin < 3 || isempty(opts), opts = struct(); end
% ---- DEFAULTS ----------------------------------------------------------------
if ~isfield(opts,'method'),  opts.method  = 'dip';  end
if ~isfield(opts,'thr'),     opts.thr     = 1.33;   end   % |score| cut (see ctrl_affected_gui slider)
if ~isfield(opts,'wlen'),    opts.wlen    = 17;     end   % trough sliding window, SAMPLES (~0.5 s @35 Hz)
if ~isfield(opts,'cos_thr'), opts.cos_thr = 0.40;   end   % 'dip_or_shape': shape-match cut
if ~isfield(opts,'thr_lo'),  opts.thr_lo  = [];     end   % 'dip_or_shape': relaxed amplitude cut
if ~isfield(opts,'tmpl'),    opts.tmpl    = [];     end   % 'dip_or_shape': reference dip [1 x numel(iStim)]
if ~isfield(opts,'tmpl_q'),  opts.tmpl_q  = 0.02;   end   % ... learned from the deepest tmpl_q fraction
if ~isfield(opts,'keep_n'),    opts.keep_n    = [];   end % 'least_affected': how many px to keep
if ~isfield(opts,'keep_frac'), opts.keep_frac = [];   end % ... or as a fraction of the grid
if ~isfield(opts,'max_bleed'), opts.max_bleed = Inf;  end % ... hard guard: never keep score < -max_bleed
if isempty(opts.thr_lo),     opts.thr_lo  = 0.5*opts.thr; end
opts.wlen = max(1, round(opts.wlen));

nG = size(periAvg,1);

% ---- the dip score (shared by every method) ----------------------------------
ref = mean(periAvg(:,W.iRef), 2);
sd  = std(periAvg(:,W.iPre), 0, 2) + eps;
Wm  = movmean(periAvg(:,W.iStim), opts.wlen, 2);
[trough, iTr] = min(Wm, [], 2);
score = (trough - ref) ./ sd;

cosSim = nan(nG,1);
tmpl   = [];

% Rank once, for every method: 1 = least affected. Reported even under 'dip' so the two rules can
% be compared on the same session without refitting.
[~, ord] = sort(score, 'descend');          % least negative (least affected) first
rank = zeros(nG,1);  rank(ord) = (1:nG).';

switch lower(opts.method)
    case 'least_affected'
        K = opts.keep_n;
        if isempty(K) && ~isempty(opts.keep_frac), K = round(opts.keep_frac*nG); end
        if isempty(K), error('ctrl_affected_detect: ''least_affected'' needs opts.keep_n or opts.keep_frac.'); end
        K = max(1, min(nG, round(K)));
        keep = false(nG,1);  keep(ord(1:K)) = true;
        % Optional hard floor: a pixel suppressed past max_bleed is never admitted, however few
        % pixels that leaves. Off by default (Inf) -- K alone is normally the whole control.
        if isfinite(opts.max_bleed)
            keep = keep & (score > -opts.max_bleed);
        end
        affected = ~keep;
        note = sprintf('keep the %d least-affected of %d px', nnz(keep), nG);
        if isfinite(opts.max_bleed)
            note = sprintf('%s (max_bleed %.2f)', note, opts.max_bleed);
        end

    case 'dip'
        affected = score < -opts.thr;
        note = sprintf('score < -%.2f', opts.thr);

    case 'dip_or_shape'
        % Template = mean stim-window shape of the pixels that dip hardest, unit-normalised.
        S = periAvg(:,W.iStim) - ref;                       % onset-referenced stim traces
        tmpl = opts.tmpl;
        if isempty(tmpl)
            nSeed = max(3, round(opts.tmpl_q*nG));
            [~,ord] = sort(score,'ascend');                 % most negative first
            tmpl = mean(S(ord(1:min(nSeed,nG)),:), 1);
        end
        tmpl = tmpl(:).';
        tn = norm(tmpl);
        if tn > 0
            rn = sqrt(sum(S.^2,2));  rn(rn==0) = eps;
            cosSim = (S*tmpl(:)) ./ (rn*tn);
        end
        hardDip  = score < -opts.thr;
        shapeHit = (cosSim > opts.cos_thr) & (score < -opts.thr_lo);
        affected = hardDip | shapeHit;
        note = sprintf('score < -%.2f  OR  (cos > %.2f AND score < -%.2f)', ...
            opts.thr, opts.cos_thr, opts.thr_lo);

    otherwise
        error(['ctrl_affected_detect: unknown method ''%s'' ' ...
               '(have: least_affected, dip, dip_or_shape).'], opts.method);
end

R = struct();
R.affected = affected(:);
R.unaff    = ~R.affected;
R.score    = score(:);
R.trough   = trough(:);
R.ref      = ref(:);
R.sd       = sd(:);
R.iTrough  = iTr(:);
R.cosSim   = cosSim(:);
R.rank     = rank;                         % 1 = least affected
R.method   = lower(opts.method);
R.opts     = opts;
R.nAff     = nnz(R.affected);
R.nKept    = nnz(R.unaff);
R.nG       = nG;
R.note     = note;
% RESIDUAL BLEED. How affected the KEPT (predictor) pixels still are. Under an absolute rule this
% is bounded by -thr by construction; under 'least_affected' it is free, and is the number that
% says how far from stim-blind the predictor really is. Report it with every Local share.
if any(R.unaff)
    R.bleed_kept  = median(score(R.unaff));
    R.bleed_worst = min(score(R.unaff));
else
    R.bleed_kept = NaN;  R.bleed_worst = NaN;
end
R.tmpl = tmpl;                 % [] unless a shape method learned/used one
end
