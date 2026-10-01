%% imp_lagged_stimblind.m -- LAGGED (dynamic) contra->ipsi stim-blind predictor. EXPERIMENTAL.
%
% GOAL (user, 2026-09-30): capture the local stim effect COMPLETELY -- dip AND rebound -- not
% partially. The zero-lag model tops out at ~91% dip / ~34% rebound, and shrinking the pixel set to
% push capture higher destroys the predictor (held-out spont R2 0.931 -> 0.888 by K=25) and the
% capture stops carrying information (at K=35 the matched-random control MATCHES it).
%
% THE IDEA. Capture rises when the predictor is blinder; R2 falls when the predictor is weaker.
% Those are different axes and the zero-lag model conflates them, because the only way to make it
% blinder is to take pixels away, which also makes it weaker. A LAGGED model adds predictive
% capacity from the SAME clean pixels -- contra at t, t-1, ... t-L -- so we can restrict HARDER in
% space (blinder) while keeping R2 (still a good model of ongoing activity). If local capture is
% real and complete, this is the direction that should expose it.
%
% CAUSAL LAGS ONLY (contra at t-l predicts ipsi at t). An acausal lag would let contra AFTER the
% onset predict the ipsi dip, which is leak by construction: the contra co-suppression at t+k would
% be used to explain the ipsi dip at t. Causal lags before onset carry no stim at all.
%
% GUARDRAILS, all four reported on every row (a capture number without these is meaningless):
%   held-out spont R2   the model must still predict ongoing activity. If it collapses, Local =
%                       Actual - garbage ~ Actual and capture -> 100% trivially.
%   catch |ratio|<=15%  the true-0V control: no stim, so Local must be ~0.
%   MATCHED-RANDOM gap  same pixel count AND same lag count, pixels drawn at random. Capture above
%                       this baseline is the only part attributable to the SELECTION. At K=35 the
%                       zero-lag gap is already negative. [CP-STIMAFF]
%   shift-null          weights scored against a time-shifted target; must stay strongly negative.
%
% ⚠ `f2_model` RESEEDS the RNG internally (RESEARCH 2026-07-07), so every random subset used here is
% PRE-GENERATED before any model call. Drawing inside the loop returns the same permutation each
% time and silently produces byte-identical "random" draws (hit 2026-09-30).
%
% SANITY GATE. At LAGS=0 this file must reproduce f2_decomp's numbers on the same pixel set
% (dip capture 91%, rebound 34% for the TF mask). It asserts that before trusting any lagged row.
%
% RUN:  load_experiments; imp_supp_residual;  then  imp_lagged_stimblind
% KNOBS: LAG_SET | LAG_KS | LAG_NRAND | LAG_RIDGE
% --------------------------------------------------------------------------------------------------

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));

if ~exist('LAG_SET','var')   || isempty(LAG_SET),   LAG_SET   = [0 1 2 4 8];  end   % max causal lag
if ~exist('LAG_KS','var')    || isempty(LAG_KS),    LAG_KS    = [91 70 50 35]; end  % pixels kept
if ~exist('LAG_NRAND','var') || isempty(LAG_NRAND), LAG_NRAND = 4;            end
if ~exist('LAG_RIDGE','var') || isempty(LAG_RIDGE), LAG_RIDGE = [1e-3 1e-2 1e-1 1 10]; end

assert(exist('P','var')==1 && exist('A','var')==1 && exist('D','var')==1, ...
    'imp_lagged_stimblind: needs P/A/D in the workspace -- run imp_supp_residual first.');

% ---- pixel ranking: graded TF score (how many amps flagged), tie-broken by amp-graded drive -----
nAffAmps = sum(A.affected, 2);
if exist('driveG','var') && numel(driveG)==P.nG, tie = driveG; else, tie = zeros(P.nG,1); end
[~, ordTF] = sort(nAffAmps + 0.001*tie, 'ascend');

% ---- pixel traces, standardised exactly as f2_prep does -----------------------------------------
fprintf('[LAG] reconstructing contra pixel traces (%d px x %d frames)...\n', P.nG, P.nF);
X = P.Ug * double(P.V);                                   % [nG x nF] %dF/F
X = (X - P.mu_p(:)) ./ max(P.sd_p(:), eps);               % z per pixel, as in f2_prep
y = double(P.y_full(:));

tr = P.frames(P.itr);  te = P.frames(P.ite);              % spontaneous train / test frame indices
fprintf('[LAG] spont frames: %d train / %d test\n', numel(tr), numel(te));

PRE = []; SUMM = struct('K',{},'L',{},'r2',{},'dip',{},'reb',{},'cat',{},'dipR',{},'rebR',{});
rng(31);
randSets = cell(numel(LAG_KS), LAG_NRAND);                % PRE-GENERATED (f2_model/our fits reseed)
for i = 1:numel(LAG_KS)
    for d = 1:LAG_NRAND, randSets{i,d} = sort(randperm(P.nG, LAG_KS(i))).'; end
end

fprintf('\n%4s %4s | %7s %6s %6s %6s | %6s %6s | %6s %6s\n', ...
        'K','L','spontR2','DIP%','REB%','catch%','rDIP%','rREB%','dDIP','dREB');
for ik = 1:numel(LAG_KS)
    K = LAG_KS(ik);
    selTF = sort(ordTF(1:K));
    for il = 1:numel(LAG_SET)
        L = LAG_SET(il);
        [r2s, dcs, rcs, cts] = lag_run(X, y, selTF, L, tr, te, P, D, LAG_RIDGE);
        rr = nan(LAG_NRAND,2);
        for d = 1:LAG_NRAND
            [~, dr, rb, ~] = lag_run(X, y, randSets{ik,d}, L, tr, te, P, D, LAG_RIDGE);
            rr(d,:) = [dr rb];
        end
        fprintf('%4d %4d | %7.3f %6.0f %6.0f %6.0f | %6.0f %6.0f | %+6.0f %+6.0f\n', ...
                K, L, r2s, dcs, rcs, cts, median(rr(:,1)), median(rr(:,2)), ...
                dcs-median(rr(:,1)), rcs-median(rr(:,2)));
        SUMM(end+1) = struct('K',K,'L',L,'r2',r2s,'dip',dcs,'reb',rcs,'cat',cts, ...
                             'dipR',median(rr(:,1)),'rebR',median(rr(:,2))); %#ok<SAGROW>
        if K == numel(A.unaff_pooled) && L == 0, PRE = [r2s dcs rcs cts]; end
    end
end

% ---- SANITY GATE: zero lag on the TF set must reproduce f2_decomp -------------------------------
if ~isempty(PRE)
    ok = D.ampOK(:);
    ref = [median(D.capPct(ok),'omitnan'), median(100*D.Lreb(ok)./D.Areb(ok),'omitnan')];
    fprintf('\n[LAG] sanity gate (K=%d, L=0): this file %.0f/%.0f  vs  f2_decomp %.0f/%.0f (dip/reb)\n', ...
            numel(A.unaff_pooled), PRE(2), PRE(3), ref(1), ref(2));
    if max(abs([PRE(2) PRE(3)] - ref)) > 6
        fprintf(2, ['[LAG] ** GATE FAILED: the zero-lag reimplementation does not match f2_decomp.\n' ...
                    '      Every lagged row above is therefore NOT comparable to the published\n' ...
                    '      numbers and must not be quoted until this is reconciled. **\n']);
    else
        fprintf('[LAG] gate PASSED -- lagged rows are comparable to the f2_decomp numbers.\n');
    end
end
assignin('base','LAGSUMM',SUMM);
fprintf('\n[LAG] summary in LAGSUMM (struct array).\n');

%% ------------------------------------------------------------------------------------------------
function [r2, dipCap, rebCap, catRatio] = lag_run(X, y, sel, L, tr, te, P, D, ridgeGrid)
% Fit a causal-lagged ridge contra->ipsi model on spontaneous frames, then deploy it UNCHANGED on
% the stim trials and on the true-0V catch windows. Nothing here ever sees a stim sample during fit.
nS = numel(sel);  nLag = L + 1;
bad = min(tr) - L < 1 | min(te) - L < 1;
if bad, tr = tr(tr-L >= 1);  te = te(te-L >= 1); end

Ztr = lag_design(X, sel, L, tr);          % [nTr x nS*nLag]
Zte = lag_design(X, sel, L, te);
ytr = y(tr);  yte = y(te);
mu  = mean(ytr);  ytrc = ytr - mu;

% ridge picked on HELD-OUT spontaneous R2 only -- nothing in the selection sees the dip (r2max)
G = Ztr.'*Ztr;  c = Ztr.'*ytrc;  dg = mean(diag(G));
best = -inf;  b = zeros(size(G,1),1);
for lam = ridgeGrid
    bb = (G + lam*dg*eye(size(G,1))) \ c;
    pr = mu + Zte*bb;
    rr = 1 - sum((yte-pr).^2)/max(sum((yte-mean(yte)).^2), eps);
    if rr > best, best = rr; b = bb; end
end
r2 = best;

% ---- deploy on stim trials, per amplitude --------------------------------------------------------
nA = numel(D.amps);  preN = P.preN;
Ad = nan(nA,1); Ld = nan(nA,1); Ar = nan(nA,1); Lr = nan(nA,1);
for ai = 1:nA
    on = P.onFcell{ai};  if isempty(on), continue; end
    [aT, gT] = lag_evoked(X, y, sel, L, on, P, mu, b);
    aT = aT - mean(aT(1:preN));  gT = gT - mean(gT(1:preN));
    lT = aT - gT;
    dc = D.dcc{ai};  rc = P.rcc{ai};
    if ~isempty(dc), Ad(ai) = mean(aT(dc));  Ld(ai) = mean(lT(dc)); end
    if ~isempty(rc), Ar(ai) = mean(aT(rc));  Lr(ai) = mean(lT(rc)); end
end
ok = D.ampOK(:);
dipCap = median(100*Ld(ok)./Ad(ok), 'omitnan');
rebCap = median(100*Lr(ok)./Ar(ok), 'omitnan');

% ---- catch control: the SAME weights on true-0V windows -----------------------------------------
[a0, g0] = lag_evoked(X, y, sel, L, P.onF0, P, mu, b);
a0 = a0 - mean(a0(1:preN));  g0 = g0 - mean(g0(1:preN));  l0 = a0 - g0;
dcRef = D.dcc{find(ok,1)};  if isempty(dcRef), dcRef = (preN+1):numel(a0); end
% Ratio against the MEDIAN stim Local dip over responding amps -- same definition as f2_decomp, so
% the 15% threshold means the same thing here as everywhere else in the stream.
LdipMed  = median(Ld(ok),'omitnan');
catRatio = 100 * mean(l0(dcRef)) / LdipMed;
end

function Z = lag_design(X, sel, L, fr)
% [numel(fr) x numel(sel)*(L+1)], column block l = pixel traces at frame (fr - l). CAUSAL.
nS = numel(sel);  Z = zeros(numel(fr), nS*(L+1));
for l = 0:L
    Z(:, l*nS+(1:nS)) = X(sel, fr - l).';
end
end

function [aT, gT] = lag_evoked(X, y, sel, L, on, P, mu, b)
% Trial-averaged actual and predicted peri-stim traces for one set of onsets.
rel = P.rel(:);  Wb = numel(rel);  on = on(:).';
% Drop onsets whose window (including the deepest lag) would run off either end of the recording.
on = on(on + min(rel) - L >= 1 & on + max(rel) <= P.nF);
nS = numel(sel);
idx = on + rel;                                        % [Wb x nTr]
aT  = mean(double(y(idx)), 2);
Zw  = zeros(Wb*numel(on), nS*(L+1));
for l = 0:L
    Zw(:, l*nS+(1:nS)) = X(sel, idx(:) - l).';
end
gT = mean(reshape(mu + Zw*b, Wb, numel(on)), 2);
end
