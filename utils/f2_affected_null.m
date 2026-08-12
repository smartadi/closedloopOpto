function A = f2_affected_null(P, opt)
%F2_AFFECTED_NULL  Stim-affected detection by a CALIBRATED test against the measured catch null.
%
% ADDITIVE, NOT A REPLACEMENT. `f2_affected` (confirmed biphasic-TF mask at a hand-set tf_sens)
% remains the default and the fallback. This is a second, independent detector built on a different
% principle, so the two can be compared on the same session.
%
% *** WHY THIS CRITERION IS THE RIGHT ONE ***
% The Global dip is EXACTLY b'e_a, where e_a is the trial-averaged evoked deflection of the
% surviving predictor pixels. So if every surviving pixel had zero trial-averaged deflection, the
% Global dip would be zero FOR ANY WEIGHTS -- capture would be 100% with no penalty and no tuning.
% Therefore:
%
%       leak > 0  <=>  some surviving pixel carries a nonzero trial-averaged deflection
%                 <=>  detection is imperfect.
%
% There is no third possibility. A pixel that is merely network-CORRELATED with the ipsi site but
% carries no stim response contributes nothing to the Global dip, however heavily it is weighted --
% and that correlation is exactly what we WANT, because it is what makes Global a good estimate of
% the ongoing activity the ipsi site would have shown.
%
% The existing detector asks "does this pixel's response match a biphasic TF shape?", which is a
% different question and passes any pixel that responds with the wrong shape. This one asks the
% question that leak actually depends on: "is this pixel's trial-averaged deflection distinguishable
% from no stimulus at all?"
%
% THE NULL IS MEASURED, NOT ASSUMED. With finite trials a truly unaffected pixel's trial average is
% not exactly zero -- ongoing activity does not fully average out over n_a trials. The catch windows
% (true 0 V or pseudo-catch, n = 55..299 here) give that floor directly: draw n_a catch windows,
% average them the same way, and you have the null distribution of the statistic AT THAT TRIAL COUNT.
%
% STOPPING CRITERION this makes available: exclude until the remaining leak falls to the catch
% floor. Below that the residual leak is irreducible finite-trial noise and no better detector
% exists for this data.
%
% STATISTIC  T_i = || e_a(i, w) ||_2 over that amplitude's FULL response window (P.scc, onset ->
% end of rebound). Shape-agnostic on purpose: a signed window mean lets a biphasic response cancel
% itself to zero and pass, which is precisely the pixel we must exclude.
%
% INPUT   P    from f2_prep
% OPTS    .q(0.05)        Benjamini-Hochberg FDR level -- the only knob, and it is a false-positive
%                         rate, so it means the same thing in every session (unlike tf_sens 1.0-3.0)
%         .nBoot(1000)  .chunk(100)  .plot(true)  .verbose(true)
%         .qGrid          FDR levels to report the sensitivity of nAff to
% OUTPUT  A  .affected [nG x nA] .nAff .unaff_pooled          (same interface as f2_affected)
%            .pval .stat .null_med .q .nAffAtQ .qGrid
%            .monotonic .monoViol .detector='null-FDR' .tf_sens=NaN
% -------------------------------------------------------------------------------------------------
if nargin < 2, opt = struct(); end
def = struct('q',0.05, 'nBoot',1000, 'chunk',100, 'plot',true, 'verbose',true, ...
             'qGrid',[0.001 0.01 0.05 0.10 0.20]);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}) || isempty(opt.(fn{i})), opt.(fn{i}) = def.(fn{i}); end
end
vb = opt.verbose;  nG = P.nG;  nA = P.nA;  Wb = P.Wb;  preN = P.preN;

%% ---- catch block: the measured null, built with the SAME operators as the stim trials ----------
onF0 = P.onF0(:);  nT0 = numel(onF0);
idx0 = onF0.' + P.rel(:);
Z0 = (P.Ug*double(P.V(:,idx0(:))) - P.mu_p)./P.sd_p;      % nG x (Wb*nT0), z-scored identically
Z0 = reshape(Z0, nG, Wb, nT0);
Z0m = reshape(Z0, nG*Wb, nT0);
clear Z0

A = struct();
A.affected = false(nG, nA);
A.pval     = nan(nG, nA);
A.stat     = nan(nG, nA);
A.null_med = nan(nG, nA);
A.nAffAtQ  = nan(numel(opt.qGrid), nA);

if vb
    fprintf('[F2-AFFECT-NULL] %s | %d catch windows (%s) | %d bootstrap draws | FDR q = %.3f\n', ...
            P.label, nT0, P.catch_kind, opt.nBoot, opt.q);
    fprintf('   %-8s %6s %8s %10s %10s   %s\n','amp(V)','nTr','|w|','nAff','%','median p');
end

rng(31,'twister');    % local seed: the null must not depend on what ran before it

for ai = 1:nA
    if isempty(P.evZc{ai}), continue; end
    w  = P.scc{ai};  if isempty(w), w = P.dcc{ai}; end
    na = P.nT_amp(ai);
    if na < 2 || nT0 < 2, continue; end

    % observed statistic: norm of the trial-averaged deflection over the response window
    Tobs = sqrt(sum(P.evZc{ai}(:,w).^2, 2));

    % ---- bootstrap null at THIS trial count ----------------------------------------------------
    % Sampling WITH replacement: some amplitudes have more trials than there are catch windows
    % (AL_0041 e1: 59 trials vs 55 catch), so subsampling without replacement is not always defined.
    nB = opt.nBoot;  Tnull = zeros(nG, nB);
    done = 0;
    while done < nB
        m   = min(opt.chunk, nB - done);
        sel = randi(nT0, na, m);
        Wsel = sparse(sel(:), repelem(1:m, na), 1/na, nT0, m);   % nT0 x m averaging operator
        Dm  = full(Z0m * Wsel);                                   % (nG*Wb) x m
        D   = reshape(Dm, nG, Wb, m);
        D   = D - mean(D(:,1:preN,:), 2);                         % SAME baselining as the observed
        Tnull(:, done+(1:m)) = squeeze(sqrt(sum(D(:,w,:).^2, 2)));
        done = done + m;
    end

    % one-sided p: how often does no-stim noise reach this deflection? (+1 keeps p > 0)
    pv = (1 + sum(Tnull >= Tobs, 2)) / (nB + 1);
    A.pval(:,ai) = pv;  A.stat(:,ai) = Tobs;  A.null_med(:,ai) = median(Tnull, 2);
    A.affected(:,ai) = local_bh(pv, opt.q);
    for gi = 1:numel(opt.qGrid)
        A.nAffAtQ(gi,ai) = nnz(local_bh(pv, opt.qGrid(gi)));
    end
    if vb
        fprintf('   %-8.2f %6d %8d %10d %9.0f%%   %.4f\n', P.amps(ai), na, numel(w), ...
                nnz(A.affected(:,ai)), 100*nnz(A.affected(:,ai))/nG, median(pv));
    end
end
clear Z0m

A.nAff         = sum(A.affected, 1);
A.unaff_pooled = find(all(~A.affected, 2));
A.q            = opt.q;   A.qGrid = opt.qGrid;
A.detector     = 'null-FDR';  A.tf_sens = NaN;  A.saved_on = 'computed';  A.file = '';

%% ---- MONOTONICITY: a physics check the detector must pass ---------------------------------------
% A stronger stimulus cannot drive FEWER contra pixels. Any decrease with amplitude is detector
% noise, not physiology. The TF detector fails this in 3 of 4 sessions; it is checked here so the
% failure is a reported property rather than something you have to notice by eye.
use = find(~cellfun(@isempty, P.evZc(:).'));
nn  = A.nAff(use);
A.monoViol = find(diff(nn) < 0);
A.monotonic = isempty(A.monoViol);
if vb
    fprintf('   pooled UNAFFECTED (candidate predictors, all amps): %d px (%.0f%%)\n', ...
            numel(A.unaff_pooled), 100*numel(A.unaff_pooled)/nG);
    fprintf('   nAff at q = ');  fprintf('%.3f:%d  ', [opt.qGrid(:).'; sum(A.nAffAtQ,2).']);  fprintf('(summed over amps)\n');
    if A.monotonic
        fprintf('   MONOTONIC in amplitude: yes\n');
    else
        fprintf(2,'   ** NOT monotonic: nAff DROPS at amp step(s) %s -> detector noise at this q **\n', ...
                mat2str(A.monoViol));
    end
    if numel(A.unaff_pooled) < 20
        fprintf(2,['   ** only %d pooled-unaffected px: at this q the predictor set is nearly empty, so\n' ...
                   '      any R^2 or capture from it is about a degenerate model. Raise q or drop amps. **\n'], ...
                   numel(A.unaff_pooled));
    end
end

%% ---- figure -------------------------------------------------------------------------------------
A.fig = [];
if ~opt.plot, return; end
nC = min(nA,3);  nR = ceil(nA/nC) + 1;
A.fig = figure('Color','w','Name',sprintf('[F2-AFFECT-NULL] %s', P.label), ...
               'Position',[60 60 420*nC 300*nR]);
for ai = 1:nA
    ax = subplot(nR,nC,ai);  hold(ax,'on');
    image(ax, repmat(P.dspImg,[1 1 3]));  axis(ax,'image','off');  set(ax,'YDir','reverse');
    a = A.affected(:,ai);
    scatter(ax, P.dspGc(~a), P.dspGr(~a), 10, [0.78 0.78 0.78],'filled', ...
            'MarkerEdgeColor',[0.45 0.45 0.45],'LineWidth',0.2);
    scatter(ax, P.dspGc(a),  P.dspGr(a),  16, 'k','filled','MarkerEdgeColor','k');
    plot(ax, P.dspSc, P.dspSr, 'r+','MarkerSize',12,'LineWidth',1.6);
    title(ax, sprintf('%.2f V   %d/%d affected  (n=%d)', P.amps(ai), A.nAff(ai), nG, P.nT_amp(ai)), ...
          'FontSize',9,'FontWeight','bold');
end
% sensitivity of the count to q -- the analogue of the k(nu) panel, and the thing tf_sens never showed
ax = subplot(nR,nC,nA+1); hold(ax,'on'); box(ax,'on');
for gi = 1:numel(opt.qGrid)
    plot(ax, P.amps, A.nAffAtQ(gi,:), '-o','LineWidth',1.3,'MarkerSize',3.5, ...
         'DisplayName',sprintf('q = %.3f', opt.qGrid(gi)));
end
xlabel(ax,'amplitude (V)'); ylabel(ax,'affected px');
legend(ax,'Location','northwest','FontSize',6,'Box','off');
title(ax, sprintf('sensitivity to q  |  monotonic: %s', local_tern(A.monotonic,'YES','NO')), ...
      'FontSize',9,'FontWeight','bold');

sgtitle(sprintf(['%s  —  stim-AFFECTED by CALIBRATED NULL test (black), FDR q = %.3f' ...
                 '\nnull = %d catch windows resampled to each amplitude''s trial count;' ...
                 '  pooled unaffected = %d px;  red + = ipsi site'], ...
                 P.label, opt.q, nT0, numel(A.unaff_pooled)), 'FontWeight','bold','FontSize',10);
end

% -------------------------------------------------------------------------------------------------
function m = local_bh(p, q)
%LOCAL_BH  Benjamini-Hochberg step-up. Controls the expected FALSE-DISCOVERY rate among the pixels
% called affected -- so q is "what fraction of my exclusions am I willing to have been unnecessary",
% which is a statement about this analysis, not about a detector gain.
p = p(:);  n = numel(p);
[ps, ord] = sort(p, 'ascend');
kk = find(ps <= (1:n).'/n * q, 1, 'last');
m = false(n,1);
if ~isempty(kk), m(ord(1:kk)) = true; end
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
