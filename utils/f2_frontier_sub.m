function R = f2_frontier_sub(Q, SS, opt)
%F2_FRONTIER_SUB  Sweep the blindness penalty against a stim-evoked SUBSPACE, via Woodbury.
%
%   min_b  ||y - Zb||^2 + lamR*sum(b_i/gamma_i)^2 + lamL*||V_k' b||^2
%     ->   (M + lamL*V_k*V_k') b = c ,      M = G + lamR*diag(1/gamma^2)
%
% Because V_k is nS-by-k with k << nS, the Woodbury identity turns the whole frontier into ONE
% Cholesky plus a k-by-k solve per grid point:
%
%   b(lamL) = u - Psi*( lamL^-1*I_k + Sm )^-1 * V_k'*u ,   u = M\c ,  Psi = M\V_k ,  Sm = V_k'*Psi
%
% so the cost of the entire sweep is the cost of a single unpenalised fit. V_k being ORTHONORMAL
% also means the penalty's eigenvalues are exactly lamL, which is why this needs no equivalent of
% the old `scl` fudge -- lamL is quoted as a fraction of trace(M)/nS and means the same thing in
% every session.
%
% CAPTURE IS NOW A PROJECTION, not a window mean:
%   g_a = E_a'*b        Global evoked trajectory
%   eta_a = <alpha_a,g_a> / <alpha_a,alpha_a>          leak fraction, window-free
%   capture_a = 1 - eta_a
% This is the same geometry the penalty acts in, and it reduces to the old scalar leak when the
% trajectory collapses to one window mean -- so old numbers stay comparable.
%
% GUARDS (unchanged in spirit, all still required before quoting anything):
%   TRIAL SPLIT     V_k and the SELECT capture come from half A; capVal is rescored on half B.
%   RANDOM CONTROL  a random ORTHONORMAL basis of the same rank k at the same lamL. Same R^2 cost by
%                   construction; if it buys the same capture, this is shrinkage, not blindness.
%   lamL -> inf     is the exact constraint V_k'b = 0, always satisfiable since k < nS. In-sample
%                   capture is pinned at 100% there BY CONSTRUCTION -- read the knee, never the end.
%
% INPUT  Q   .G .c .gamma .lamR .Zte .yte .muY .sstot .S .nP  (as f2_frontier)
%            .r2pre  OPTIONAL function handle b -> median pre-stim R^2 on stim trials
%        SS  f2_subspace output
% OPTS   .r2_floor(0.85) .grid .knee_tol(0.02) .nRand(5) .verbose(true)
% OUTPUT R   .b .frac .lamL .r2 .capSel .capVal .r2_price .cap_gain .curve .rand .status .k
% -------------------------------------------------------------------------------------------------
if nargin < 3, opt = struct(); end
def = struct('r2_floor',0.85, 'grid',[0 logspace(-3,4,22)], 'knee_tol',0.02, 'nRand',5, 'verbose',true);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}) || isempty(opt.(fn{i})), opt.(fn{i}) = def.(fn{i}); end
end
vb = opt.verbose;  S = Q.S(:).';  nP = Q.nP;  nS = numel(S);
Vk = SS.Vk;  k = SS.k;

%% ---- one factorisation, reused for every grid point --------------------------------------------
M   = Q.G(S,S) + Q.lamR*diag(1./max(Q.gamma(S),eps).^2);
M   = (M + M.')/2;                                   % symmetrise: mldivide picks a better path
u   = M \ Q.c(S);
Psi = M \ Vk;
Sm  = Vk.' * Psi;  Sm = (Sm + Sm.')/2;
Vu  = Vk.' * u;
scl = trace(M)/nS;                                   % lamL grid is a fraction of this

r2of = @(b) 1 - sum((Q.yte - (Q.muY + Q.Zte*b)).^2)/Q.sstot;
% NOTE: local_cap / local_solve are LOCAL functions, deliberately not nested. A nested function
% shares the parent workspace, so a helper that uses `g` for the Global trajectory or `q` as a loop
% counter silently overwrites the sweep's grid array and loop index -- which is exactly what
% happened on the first run here (every leakPen printed as -0.05065).

%% ---- sweep --------------------------------------------------------------------------------------
fg = opt.grid(:).';  nG_ = numel(fg);
r2v = nan(nG_,1); cS = nan(nG_,1); cV = nan(nG_,1); rpre = nan(nG_,1);
havePre = isfield(Q,'r2pre') && ~isempty(Q.r2pre);
if vb
    fprintf('\n[F2-FRONTIER-SUB] rank-%d stim subspace | %d px | amps %s | floor R^2 >= %.2f\n', ...
            k, nS, mat2str(SS.ampsUsed), opt.r2_floor);
    fprintf('   %-10s %9s %9s %13s %13s\n','leakPen','spontR2','preR2','capture% SEL','capture% VAL');
end
for q = 1:nG_
    bS = local_solve(fg(q), u, Psi, Sm, Vu, scl, k);
    b  = zeros(nP,1);  b(S) = bS;
    r2v(q) = r2of(b);
    cS(q)  = local_cap(bS, SS.EA, SS.aA);
    cV(q)  = local_cap(bS, SS.EB, SS.aB);
    if havePre, rpre(q) = Q.r2pre(b); end
    if vb
        fprintf('   %-10.4g %9.4f %9.4f %13.0f %13.0f\n', fg(q), r2v(q), rpre(q), cS(q), cV(q));
    end
end

%% ---- PICK: knee of the SELECT curve inside the feasible set ------------------------------------
ok = find(r2v >= opt.r2_floor);
if isempty(ok)
    [~, iB] = max(r2v);  status = 'FLOOR_UNREACHABLE';
    warning('[F2-FRONTIER-SUB] no grid point reaches R^2 >= %.2f (best %.4f).', opt.r2_floor, r2v(iB));
else
    cMax = max(cS(ok));
    kn = ok(cS(ok) >= cMax - opt.knee_tol*abs(cMax));
    iB = kn(1);  status = 'OK';
    if iB == nG_, status = 'GRID_EDGE'; end
end
bBest = zeros(nP,1);  bBest(S) = local_solve(fg(iB), u, Psi, Sm, Vu, scl, k);

%% ---- RANDOM-DIRECTION CONTROL: same rank, same strength, orthonormal ---------------------------
rng(23,'twister');
rr2 = nan(opt.nRand,1);  rcap = nan(opt.nRand,1);
for it = 1:opt.nRand
    [Vr,~] = qr(randn(nS,k), 0);                      % random orthonormal basis, same rank
    Pr = M \ Vr;  Sr = Vr.'*Pr;  Sr = (Sr+Sr.')/2;  Ur = Vr.'*u;
    brS = local_solve(fg(iB), u, Pr, Sr, Ur, scl, k);
    br = zeros(nP,1);  br(S) = brS;
    rr2(it)  = r2of(br);
    rcap(it) = local_cap(brS, SS.EB, SS.aB);               % scored exactly as the real number is
end

R.b = bBest;  R.frac = fg(iB);  R.lamL = fg(iB)*scl;  R.status = status;  R.k = k;
R.r2 = r2v(iB);  R.capSel = cS(iB);  R.capVal = cV(iB);  R.r2pre = rpre(iB);
R.r2_price = r2v(1) - r2v(iB);   R.cap_gain = cV(iB) - cV(1);
R.curve = struct('frac',fg(:), 'r2',r2v, 'capSel',cS, 'capVal',cV, 'r2pre',rpre, ...
                 'iPick',iB, 'r2_floor',opt.r2_floor);
R.rand = struct('r2',rr2, 'cap',rcap, 'r2_mean',mean(rr2,'omitnan'), 'cap_mean',mean(rcap,'omitnan'));
R.ampsUsed = SS.ampsUsed;

if vb
    fprintf(2,'   [PICK knee] leakPen %.4g -> spont R^2 %.4f | preR2 %.3f | capture SEL %.0f%% / VAL %.0f%%\n', ...
            R.frac, R.r2, R.r2pre, R.capSel, R.capVal);
    fprintf(['   PRICE OF BLINDNESS: R^2 %.4f -> %.4f (cost %.4f) buys held-out capture %.0f%% -> %.0f%%' ...
             ' (gain %+.0f pts)\n'], r2v(1), R.r2, R.r2_price, cV(1), R.capVal, R.cap_gain);
    fprintf('   RANDOM orthonormal basis, same rank %d, same strength: R^2 %.4f, capture %.0f%%\n', ...
            k, R.rand.r2_mean, R.rand.cap_mean);
    if isfinite(R.rand.cap_mean) && R.rand.cap_mean >= R.capVal - 5
        fprintf(2,['   ** a RANDOM subspace buys the same capture at the same R^2 cost: shrinkage, not\n' ...
                   '      blindness. Do NOT treat the residual as validated. **\n']);
    end
    if isfinite(R.capVal) && isfinite(R.capSel) && R.capVal < 0.6*R.capSel
        fprintf(2,['   ** capture did NOT transfer to held-out trials (%.0f%% VAL vs %.0f%% SEL): the basis\n' ...
                   '      cancelled the trial average it was built from, not a reproducible response. **\n'], ...
                   R.capVal, R.capSel);
    end
    if strcmp(status,'GRID_EDGE')
        fprintf(2,'   ** knee sits at the LAST grid point -- effectively the hard constraint. Widen opt.grid. **\n');
    end
end
end

% -------------------------------------------------------------------------------------------------
function c = local_cap(bS, E, al)
% Window-free capture: eta = <alpha, g> / <alpha, alpha> averaged over amplitudes, g = E'*b.
e = nan(1, numel(E));
for j = 1:numel(E)
    gj   = E{j}.' * bS;
    e(j) = (al{j}.' * gj) / max(al{j}.' * al{j}, eps);
end
c = 100*(1 - mean(e));
end

function bS = local_solve(f, u, Psi, Sm, Vu, scl, k)
% Woodbury update. At f=0 the penalty vanishes and the correction is exactly zero, but forming
% eye(k)/0 would put Inf into the k-by-k solve, so short-circuit rather than rely on it.
if f <= 0, bS = u; return; end
bS = u - Psi * ((eye(k)/(f*scl) + Sm) \ Vu);
end
