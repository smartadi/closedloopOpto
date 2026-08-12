function SS = f2_subspace(P, S, opt)
%F2_SUBSPACE  Build the STIM-EVOKED SUBSPACE from split-half peri-stim trajectories.
%
% Replaces the single window-averaged dip vector (e_a = mean over dcc) with an orthonormal basis for
% the directions in contra space along which the stimulus writes its signature ACROSS THE WHOLE
% RESPONSE -- suppression, recovery and rebound together.
%
% WHY THIS EXISTS. The window-mean formulation had two defects that share one cause:
%   (1) the REBOUND was never represented, so the residual carried the dip and not the recovery
%       (measured 2026-08-11: dip capture 95% vs rebound capture 37% on AL_0033);
%   (2) the dip window is DATA-DRIVEN and its width runs inversely to amplitude, so weak amplitudes
%       got wide windows, diluted means, and were pushed below the response threshold.
% Keeping the trajectory instead of its mean removes both: there is no window inside the fit.
%
%   W   = [ E_1/s_1 , E_2/s_2 , ... ]            E_a: nS x Tw(a),  s_a = ||alpha_a||
%   W   = V*Sigma*Q'                             thin SVD
%   k   = smallest rank explaining >= nu of sum(sigma^2)
%   V_k = first k left singular vectors          -> penalty operator Pi_k = V_k*V_k' (a PROJECTOR)
%
% Dividing by s_a (the magnitude of the ACTUAL ipsi response at that amplitude) is the trajectory
% analogue of the old e_a/A_a: it puts every amplitude on the same footing so a strong amplitude
% cannot dominate the basis purely by being large.
%
% *** THE SPLIT IS NOT OPTIONAL ***  V_k is built from trial-half A ONLY. Half B never touches the
% basis and exists solely to score it. A basis fitted to a trial average it is then evaluated on
% would report ~100% capture by construction.
%
% INPUT  P    f2_prep struct (needs .evZcA/.evZcB/.aAcA/.aAcB/.scc/.nA/.nG)
%        S    candidate pixel indices (into the grid) the weights are supported on
% OPTS   .nu(0.90)      variance-explained threshold that sets k
%        .kmax([])      hard cap on k ([] = none)
%        .ampFrac(0.25) keep amps whose ||alpha_a|| reaches this fraction of the strongest
%        .verbose(true)
% OUTPUT SS  .Vk [nS x k] .sv .k .nu .cumvar .ampsUsed .EA/.aA/.EB/.aB (cells, restricted to S)
%            .win (cell) .sA .sB .kAtNu (k for a range of nu, for the viewer)
% -------------------------------------------------------------------------------------------------
if nargin < 3, opt = struct(); end
def = struct('nu',0.90, 'kmax',[], 'ampFrac',0.25, 'verbose',true, 'sv_weight',false);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}), opt.(fn{i}) = def.(fn{i}); end
end
vb = opt.verbose;  S = S(:).';  nS = numel(S);

%% ---- (a) which amplitudes have a usable trial split, and did they respond ----------------------
cand = find(~cellfun(@isempty, P.evZcA(:).') & ~cellfun(@isempty, P.evZcB(:).'));
EA = {}; aA = {}; EB = {}; aB = {}; win = {}; sA = []; sB = []; keep = [];
for a = cand
    w = P.scc{a};
    if isempty(w), continue; end
    ea = P.evZcA{a}(S, w);   al = P.aAcA{a}(w);   al = al(:);
    eb = P.evZcB{a}(S, w);   bl = P.aAcB{a}(w);   bl = bl(:);
    if ~all(isfinite(ea(:))) || ~all(isfinite(eb(:))), continue; end
    keep(end+1) = a;              %#ok<AGROW>
    EA{end+1} = ea;  aA{end+1} = al;  sA(end+1) = norm(al);   %#ok<AGROW>
    EB{end+1} = eb;  aB{end+1} = bl;  sB(end+1) = norm(bl);   %#ok<AGROW>
    win{end+1} = w;               %#ok<AGROW>
end
if isempty(keep)
    error('f2_subspace: no amplitude has a usable trial split in %s.', P.label);
end

% ||alpha_a|| is a NORM, so unlike the signed dip mean it cannot be near zero because a response
% was biphasic and cancelled itself. A small norm here really does mean "this amplitude did little".
ok = sA >= opt.ampFrac*max(sA);
if ~any(ok), ok = true(size(sA)); end
EA = EA(ok); aA = aA(ok); EB = EB(ok); aB = aB(ok); win = win(ok);
sA = sA(ok);  sB = sB(ok);  SS.ampsUsed = keep(ok);

%% ---- (b) stack the normalised trajectories and take the thin SVD -------------------------------
W = zeros(nS, sum(cellfun(@(e) size(e,2), EA)));
j = 1;
for q = 1:numel(EA)
    nc = size(EA{q},2);
    W(:, j:j+nc-1) = EA{q} / max(sA(q), eps);
    j = j + nc;
end
[V, Sig, ~] = svd(W, 'econ');
sv = diag(Sig);
cumvar = cumsum(sv.^2) / max(sum(sv.^2), eps);

k = find(cumvar >= opt.nu, 1, 'first');
if isempty(k), k = numel(sv); end
if ~isempty(opt.kmax), k = min(k, opt.kmax); end
k = max(1, min(k, min(nS-1, numel(sv))));      % must leave a non-empty complement to solve in

% ENERGY WEIGHTING. An ORTHONORMAL V_k penalises every retained direction equally, so V_1 (which
% may carry 80% of the stim energy) and V_3 (3%) are treated as equally important to suppress. That
% discards exactly the magnitude information the old e_a/A_a penalty carried. sv_weight=true scales
% the columns by their singular values, making the penalty b'*V*Sigma^2*V'*b -- i.e. proportional to
% how much stim energy each direction actually holds. Woodbury does not require orthonormality.
if opt.sv_weight
    SS.Vk = V(:,1:k) .* (sv(1:k).' / max(sv(1), eps));
else
    SS.Vk = V(:,1:k);
end
SS.sv = sv;  SS.k = k;  SS.nu = opt.nu;  SS.cumvar = cumvar;
SS.EA = EA;  SS.aA = aA;  SS.EB = EB;  SS.aB = aB;  SS.win = win;  SS.sA = sA;  SS.sB = sB;
SS.S = S;  SS.nS = nS;

% k as a function of nu, so the viewer can show how arbitrary (or not) the choice is
nuGrid = [0.70 0.80 0.85 0.90 0.95 0.99];
SS.nuGrid = nuGrid;
SS.kAtNu  = arrayfun(@(u) local_first(cumvar >= u, numel(sv)), nuGrid);

if vb
    fprintf('[F2-SUBSPACE] %d px | amps %s | window %d-%d frames | W is %dx%d\n', ...
            nS, mat2str(SS.ampsUsed), min(cellfun(@numel,win)), max(cellfun(@numel,win)), size(W,1), size(W,2));
    fprintf('   singular values (first 8): %s\n', mat2str(round(sv(1:min(8,end)).',3)));
    fprintf('   k(nu): ');
    fprintf('%.2f->%d  ', [nuGrid; SS.kAtNu]);
    fprintf('\n   PICK nu = %.2f -> k = %d  (%.1f%% of stim-evoked energy, %d-dim complement left)\n', ...
            opt.nu, k, 100*cumvar(k), nS-k);
end
end

% -------------------------------------------------------------------------------------------------
function i = local_first(mask, dflt)
i = find(mask, 1, 'first');
if isempty(i), i = dflt; end
end
