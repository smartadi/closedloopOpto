% impulse-analysis/imp_lds_grid.m
%
% Multi-output latent LDS on a 100-point bilateral cortical grid, fit on the AL_0033 impulse session,
% then controllability / observability analysis for ONE target grid point (user spec 2026-10-05).
%
%   x(t+1) = A x(t) + B u(t) + w(t),    y(t) = C x(t) + v(t)          NO added input delay
%   y in R^100 : %dF/F at 50 ipsi points + their 50 mirror images across the midline
%   u          : laser amplitude (V) on the onset frame (pulses ~15 ms < one 28.6 ms frame)
%   x in R^n   : n = nD + nS << 100 latent states, both orders by blocked cross-validation
% With D = 0 the pulse first shows in y one frame after onset (CB). Data: site unit response -0.016
% at lag 0, -0.04 at lag 1, trough -0.93 %dF/F per V at lag 5 -- a ramp, so the states are LATENT.
%
% WHY TWO BLOCKS (dead ends, RESEARCH 2026-10-05). (1) DMDc (x = top PCs of y): B is set by the
%   one-frame jump (~0), so B -> 0, CV impulse-response R^2 ~ 0 at every n. (2) One CVA model on
%   everything: the data are so smooth that ~40 canonical correlations exceed 0.95, and the laser's
%   share of the variance is tiny (PC1 var ~1150 vs a ~1 %dF/F/V evoked dip), so no state was ever
%   spent on the input -> again CV IR R^2 ~ 0. The input-driven part has to be identified on its own.
%
% IDENTIFICATION (only eig/svd/\ -- n4sid's MEX segfaults on this machine, see lds_ipsi.m)
%   D  (laser-driven) : ERA / Ho-Kalman on the 100-point unit impulse response (LS over all pulse
%                       amplitudes), Markov parameters h_k = C A^(k-1) B, k = 1..eraL.
%   S  (spontaneous)  : subspace ID (past/future projection, SVD) on the residual y - y_D, no input.
%   combined: A = blkdiag(A_D, A_S), B = [B_D; 0], C = [C_D C_S], Q = blkdiag(0, Q_S).
%   B_S = 0 is an IDENTIFICATION choice, not a finding. Whether spontaneous dynamics are laser-
%   reachable is therefore TESTED, not assumed: each S mode is matched to the D modes by cortical
%   pattern + time constant ('shared' table), and the reachable/spontaneous OUTPUT subspaces overlap.
%   Coordinates: C made orthonormal (QR), so |x| = |C x| -- a state's size is the size of its
%   cortical pattern, and every Gramian eigenvector is a physical map, not a basis artefact.
%
% ANALYSIS for target point i* (c = C(i*,:)):
%   Wc = sum A^k B B' A'^k   laser-reachable covariance  -> maps: eig(C Wc C')
%   Wn = sum A^k Q A'^k      spontaneous covariance      -> maps: eig(C Wn C')
%   Wo = sum A'^k c'c A^k    observability from i*       -> maps: C * eig(Wo)
%   modes (|C v_i| = 1): ctrb_i = |w_i B|^2/(1-|l_i|^2), obs_i = |c v_i|^2/(1-|l_i|^2)
%     -> graded Kalman classes co / c~o / ~co / ~c~o (threshold P.frac of the max)
%   hidden collateral : laser-reachable activity the target cannot see,      (I-Po) Wc (I-Po)
%   seen-unreachable  : target's spontaneous variance outside the laser-reachable subspace
%   Exact rank tests are meaningless on a fitted model (generic => full rank); everything is graded.
%
% Sections: [LG-SETUP] [LG-BUILD] [LG-FIT-D] [LG-FIT-S] [LG-CO] [LG-BOOT]
% Knobs: set a struct LG before running to override any field of P (e.g. LG.nD = 4; LG.targets = 52;
%   LG.ampMax = 1.1 for the bleed-free check -- bleed is present >= 1.6 V).
% Out: data/lg_grid_<tag>.mat (grid cache), data/lg_fit_<tag>.mat, figs/lg_*.png

%% [LG-SETUP] --------------------------------------------------------------------------------
if ~exist('LG','var') || ~isstruct(LG), LG = struct(); end
P = struct('mn','AL_0033', 'td','2025-01-29', 'en',1, 'nSV',500, 'nHemi',50, 'kern',2, 'Fs',35, ...
    'eraL',70, 'ndGrid',1:12, 'nD',[], ...
    'kPC',50, 'p',5, 'f',5, 'nsGrid',[2 4 6 8 10 12 15 20 25 30], 'nS',[], ...
    'nFold',5, 'hStep',10, 'irWin',[-0.5 2.5], 'irFit',[0 1], 'targets',[], 'frac',0.1, ...
    'Hobs',35, 'ampMax',inf, 'nBoot',20, 'bootBlk',60, 'seed',42, 'rebuild',false);
lgf = fieldnames(LG); for i = 1:numel(lgf), P.(lgf{i}) = LG.(lgf{i}); end
here = fileparts(mfilename('fullpath'));
if isempty(here) || startsWith(here, tempdir), here = fileparts(which('imp_lds_grid')); end
addpath(genpath(fullfile(here,'..','utils')));
dataDir = fullfile(here,'data'); figDir = fullfile(here,'figs');
if ~exist(figDir,'dir'), mkdir(figDir); end
tag = sprintf('%s_%s_e%d', P.mn, strrep(P.td(6:end),'-',''), P.en);      % AL_0033_0129_e1
sfx = ''; if isfinite(P.ampMax), sfx = sprintf('_amax%g', P.ampMax); end

%% [LG-BUILD] grid + %dF/F at each point + laser input (cached) ------------------------------
gridFile = fullfile(dataDir, sprintf('lg_grid_%s.mat', tag));
if exist(gridFile,'file') && ~P.rebuild
    G = load(gridFile);
    fprintf('[LG-BUILD] loaded cache %s\n', gridFile);
else
    m  = load(fullfile(dataDir, sprintf('cortex_mask_%s_%s_e%d.mat', P.mn, P.td, P.en)));
    rr = load(fullfile(dataDir, sprintf('cp_roi2_%s.mat', tag)));      % midline, DISPLAY coords
    st = load(fullfile(dataDir, sprintf('cp_stim_site_%s.mat', tag)));
    site = double(st.rowcol(:)).';                                     % ARRAY [row col]
    expRoot = expPath(P.mn, P.td, P.en);
    hemo = exist(fullfile(expRoot,'corr','svdTemporalComponents_corr.npy'),'file') > 0;
    fprintf('[LG-BUILD] loading SVD (%d comps) from %s | hemo-corrected V: %d\n', P.nSV, expRoot, hemo);
    [U, V, t, mimg] = cp_loadUVt(expRoot, P.nSV);
    mask = m.ctxMask;
    % orientation guard: the mask must sit on bright cortex in ARRAY coords, and contain the site
    fprintf('[LG-BUILD] mask check: mean mimg in mask %.3g vs transposed %.3g | site in mask %d\n', ...
        mean(mimg(mask)), mean(mimg(mask.')), mask(site(1),site(2)));
    assert(mask(site(1),site(2)), 'imp_lds_grid: laser site is outside the cortex mask (orientation?).');

    % midline: transposed display => display x = array ROW, display y = array COL
    midRow = @(col) interp1(rr.my, rr.mx, col, 'linear', 'extrap');
    [R, Cc] = find(mask); k = P.kern;
    side = sign(R - midRow(Cc)); ipsiSign = sign(site(1) - midRow(site(2)));
    ok  = R > k & R <= size(mask,1)-k & Cc > k & Cc <= size(mask,2)-k;
    inI = side == ipsiSign & ok;  inC = side == -ipsiSign & ok;

    rng(P.seed);
    [~, cen] = kmeans([R(inI) Cc(inI)], P.nHemi, 'Replicates', 5, 'MaxIter', 500);
    cen = round(cen);
    [~, j] = min(sum((cen - site).^2, 2)); cen(j,:) = site;            % one point ON the laser site
    mir = [round(2*midRow(cen(:,2)) - cen(:,1)) cen(:,2)];              % mirror across midline ...
    pc  = [R(inC) Cc(inC)];
    for i = 1:P.nHemi, [~, j] = min(sum((pc - mir(i,:)).^2, 2)); mir(i,:) = pc(j,:); end   % ... snap
    [~, o] = sortrows(cen(:,[2 1])); cen = cen(o,:); mir = mir(o,:);
    pts = [mir; cen];                         % 1..50 contra, 51..100 ipsi; i <-> i+50 mirror pairs
    siteIdx = P.nHemi + find(ismember(cen, site, 'rows'));

    nP = size(pts,1); Ug = zeros(nP, P.nSV); m0 = zeros(nP,1);
    for i = 1:nP
        ri = pts(i,1)+(-k:k); ci = pts(i,2)+(-k:k);
        Ug(i,:) = reshape(mean(U(ri,ci,:), [1 2]), 1, []);
        m0(i)   = mean(mimg(ri,ci), 'all');
    end
    % %dF/F per point = impulse (Fig 2) definition: F / mean-image * 100, per point's own patch
    Y = single((Ug * double(V(1:P.nSV,:))) ./ m0 * 100);
    clear U V

    [tt, v] = getTLanalog(P.mn, P.td, P.en, 'lightCommand');
    [ss, se, ua, ib] = detectStimEvents_idx(tt, v, 'AmpTol', 0.1, 'MinDist', 4);
    amp = nan(numel(ss),1); for a = 1:numel(ua), amp(ib{a}) = ua(a); end
    t = t(:); ion = interp1(t, (1:numel(t)).', ss(:), 'nearest');
    keep = amp > 0 & isfinite(ion) & ion > 1;
    hemiSide = zeros(size(mask)); hemiSide(mask) = side * ipsiSign;    % +1 ipsi, -1 contra
    G = struct('Y',Y, 't',t, 'pts',pts, 'siteIdx',siteIdx, 'site',site, 'mask',mask, ...
        'hemiSide',hemiSide, 'mimg',mimg, 'mid',[rr.mx(:) rr.my(:)], 'ion',ion(keep), ...
        'amp',amp(keep), 'durMs',1000*(se(keep)-ss(keep)), 'hemo',hemo, 'm0',m0, 'kern',k);
    save(gridFile, '-struct', 'G', '-v7.3');
    fprintf('[LG-BUILD] saved %s\n', gridFile);
end
fprintf('[LG-BUILD] %s | %d pts (site = #%d) | %d frames (%.0f min) | %d pulses, %.1f ms | hemo %d\n', ...
    tag, size(G.Y,1), G.siteIdx, size(G.Y,2), size(G.Y,2)/P.Fs/60, numel(G.ion), median(G.durMs), G.hemo);

Y = double(G.Y); [nP, T] = size(Y);
valid = all(isfinite(Y), 1); Y(:, ~valid) = 0;
Y = Y - mean(Y(:,valid), 2); Y(:, ~valid) = 0;
u = zeros(1,T); useTr = G.amp <= P.ampMax; u(G.ion(useTr)) = G.amp(useTr);
for i = find(~useTr).'                       % trials above ampMax: drop their response, not just u
    valid(G.ion(i) : min(T, G.ion(i) + round(P.irWin(2)*P.Fs))) = false;
end
rel = round(P.irWin(1)*P.Fs) : round(P.irWin(2)*P.Fs);
fitMask = rel/P.Fs >= P.irFit(1) & rel/P.Fs <= P.irFit(2);
eraMask = rel >= 1 & rel <= P.eraL;
ionU = G.ion(useTr); ampU = G.amp(useTr);
fold = min(P.nFold, ceil((1:T) / (T/P.nFold)));
gAll = unit_ir(Y, ionU, ampU, rel, valid);
fprintf('[LG-FIT] site unit response (%%dF/F per V), lags -1..6: %s\n', ...
    mat2str(gAll(G.siteIdx, find(rel==-1)+(0:7)), 2));

%% [LG-FIT-D] laser-driven block: ERA on the unit impulse response, nD by blocked CV ----------
nGd = numel(P.ndGrid); irNum = zeros(nGd,1); irNumS = zeros(nGd,1); irDen = 0; irDenS = 0;
ceilNum = 0; ceilNumS = 0; stD = true(nGd, P.nFold);
for f = 1:P.nFold
    tr = valid & fold ~= f;  te = valid & fold == f;
    gTr = unit_ir(Y, ionU, ampU, rel, tr);  gTe = unit_ir(Y, ionU, ampU, rel, te);
    irDen  = irDen  + sum(gTe(:,fitMask).^2, 'all');   irDenS = irDenS + sum(gTe(G.siteIdx,fitMask).^2);
    ceilNum  = ceilNum  + sum((gTe(:,fitMask) - gTr(:,fitMask)).^2, 'all');
    ceilNumS = ceilNumS + sum((gTe(G.siteIdx,fitMask) - gTr(G.siteIdx,fitMask)).^2);
    for in = 1:nGd
        D = era_simo(gTr(:, eraMask), P.ndGrid(in)); stD(in,f) = max(abs(eig(D.A))) < 1;
        gM = model_ir(D, rel);
        irNum(in)  = irNum(in)  + sum((gTe(:,fitMask) - gM(:,fitMask)).^2, 'all');
        irNumS(in) = irNumS(in) + sum((gTe(G.siteIdx,fitMask) - gM(G.siteIdx,fitMask)).^2);
    end
end
cv.nD = P.ndGrid; cv.r2ir = 1 - irNum/irDen; cv.r2irSite = 1 - irNumS/irDenS;
cv.ceilIr = 1 - ceilNum/irDen; cv.ceilIrSite = 1 - ceilNumS/irDenS; cv.stableD = sum(stD,2);
fprintf('[LG-FIT-D] nD           : %s\n', sprintf('%6d', P.ndGrid));
fprintf('[LG-FIT-D] IR CV all    : %s   (model-free ceiling %.3f)\n', sprintf('%6.3f', cv.r2ir), cv.ceilIr);
fprintf('[LG-FIT-D] IR CV site   : %s   (model-free ceiling %.3f)\n', sprintf('%6.3f', cv.r2irSite), cv.ceilIrSite);
fprintf('[LG-FIT-D] stable folds : %s\n', sprintf('%6d', cv.stableD));
if isempty(P.nD)          % smallest all-fold-stable nD within 0.01 of the best CV IR R^2
    okN = (cv.stableD == P.nFold).'; P.nD = P.ndGrid(find(okN & cv.r2ir.' >= max(cv.r2ir(okN)) - 0.01, 1));
end
D = era_simo(gAll(:, eraMask), P.nD);
yD = sim_lds(D, u);
fprintf('[LG-FIT-D] chosen nD = %d | driven part = %.2f%% of total variance\n', P.nD, ...
    100*sum(yD(:,valid).^2,'all') / sum(Y(:,valid).^2,'all'));

%% [LG-FIT-S] spontaneous block: subspace ID on the residual y - y_D, nS by blocked CV --------
Yres = Y - yD; nGs = numel(P.nsGrid); nMax = max(P.nsGrid);
cv.nS = P.nsGrid; cv.r2h = nan(nGs,P.nFold); cv.r2_1 = nan(nGs,P.nFold); persist = nan(1,P.nFold);
for f = 1:P.nFold
    tr = valid & fold ~= f;  te = valid & fold == f;
    E = pca_basis(Yres, tr, P.kPC); Yr = E' * Yres;
    [Kx, ~] = ss_states(Yr, hank_idx(tr, P.p, P.f), P.p, P.f, nMax);
    Xall = state_seq(Yr, Kx, P.p, valid);
    okH = movsum(double(te), [0 P.hStep]) == P.hStep+1; okH(end-P.hStep+1:end) = false;
    tH = find(okH & all(isfinite(Xall),1));
    Yh = Y(:, tH+P.hStep);
    persist(f) = 1 - sum((Yh - Y(:,tH)).^2,'all') / sum((Yh - mean(Yh,2)).^2,'all');
    for in = 1:nGs
        S = lds_fit(Yres, Xall(1:P.nsGrid(in),:), tr);
        cv.r2h(in,f)  = hstep_r2(S, Y, yD, Xall(1:S.n,:), tH, P.hStep);   % R^2 on the FULL y
        cv.r2_1(in,f) = hstep_r2(S, Y, yD, Xall(1:S.n,:), tH, 1);
    end
end
cv.persist = mean(persist);
fprintf('[LG-FIT-S] nS           : %s\n', sprintf('%6d', P.nsGrid));
fprintf('[LG-FIT-S] 1-step CV    : %s\n', sprintf('%6.3f', mean(cv.r2_1,2)));
fprintf('[LG-FIT-S] %2d-step CV   : %s   (persistence %.3f)\n', P.hStep, sprintf('%6.3f', mean(cv.r2h,2)), cv.persist);
if isempty(P.nS), [~, j] = max(mean(cv.r2h,2)); P.nS = P.nsGrid(j); end
E = pca_basis(Yres, valid, P.kPC); Yr = E' * Yres;
[Kx, sv] = ss_states(Yr, hank_idx(valid, P.p, P.f), P.p, P.f, P.nS);
Xs = state_seq(Yr, Kx, P.p, valid);
S = lds_fit(Yres, Xs, valid);
fprintf('[LG-FIT-S] chosen nS = %d | max|eig| %.3f\n', P.nS, max(abs(eig(S.A))));

%% [LG-CO] combined model + controllability / observability per target -----------------------
M = ortho_c(combine(D, S));  n = M.n; isD = [true(P.nD,1); false(P.nS,1)];
[Vm, L] = eig(M.A); lam = diag(L); Vm = Vm ./ vecnorm(Vm); Wm = inv(Vm);   % |C v| = |v| (C orthonormal)
tau = -1 ./ (P.Fs * log(abs(lam))); fHz = abs(angle(lam)) * P.Fs / (2*pi);
assert(max(abs(lam)) < 1, 'imp_lds_grid: combined A is unstable (max|eig| = %.3f).', max(abs(lam)));
Wc = dlyap(M.A, M.B*M.B');  Wn = dlyap(M.A, M.Q);
[Er, dr] = eigs_sorted(M.C*Wc*M.C');  [En, dn] = eigs_sorted(M.C*Wn*M.C');
gM = model_ir(M, rel); [~, iPk] = max(sum(gM.^2,1)); fp = gM(:,iPk);     % footprint at peak lag
Er = Er .* sign(fp.'*Er + eps);  En = En .* sign(En(G.siteIdx,:) + eps);
su2 = mean(u(valid).^2);                             % actual laser input power per frame
ctr = abs(Wm*M.B).^2 ./ (1 - abs(lam).^2);  modeD = ctr > 1e-10*max(ctr);
spn = real(diag(Wm*M.Q*Wm')) ./ (1 - abs(lam).^2);
fprintf('[LG-CO] n = %d (nD %d + nS %d) | tau D (ms) %s | tau S (ms) %s\n', n, P.nD, P.nS, ...
    mat2str(round(1000*sort(tau(modeD),'descend').')), mat2str(round(1000*sort(tau(~modeD),'descend').')));
fprintf('[LG-CO] reachable-map var share %s | laser input power %.3g V^2/frame\n', mat2str(dr(1:min(3,end)).'/sum(dr), 2), su2);
fprintf('[LG-CO] in-sample unit IR R^2 (0-%.0f s): all %.3f | site %.3f\n', P.irFit(2), ...
    1 - sum((gAll(:,fitMask)-gM(:,fitMask)).^2,'all')/sum(gAll(:,fitMask).^2,'all'), ...
    1 - sum((gAll(G.siteIdx,fitMask)-gM(G.siteIdx,fitMask)).^2)/sum(gAll(G.siteIdx,fitMask).^2));
% spontaneous variance inside the laser-reachable output subspace (top reachable maps to 95%)
kR = find(cumsum(dr)/sum(dr) >= 0.95, 1); PR = Er(:,1:kR)*Er(:,1:kR)';
cY = cov(Y(:,valid).');
fprintf('[LG-CO] reachable output subspace (95%% of Wc, %d maps) holds %.1f%% of spontaneous variance (%.1f%% expected by chance)\n', ...
    kR, 100*trace(PR*cY)/trace(cY), 100*kR/nP);
% shared-mode test: does any spontaneous mode look like a laser-driven one?
iS = find(~modeD); iDm = find(modeD); share = zeros(numel(iS), 3);
for q = 1:numel(iS)
    sim = abs(Vm(:,iDm)' * Vm(:,iS(q)));                 % |<C v_S, C v_D>| (unit cortical patterns)
    [share(q,1), j] = max(sim); share(q,2) = tau(iS(q)); share(q,3) = tau(iDm(j));
end
[~, o] = sort(share(:,1), 'descend'); share = share(o,:);
fprintf('[LG-CO] shared-mode test (top 5 S modes by pattern match): |corr| / tau_S / tau_D (ms)\n');
for q = 1:min(5, size(share,1)), fprintf('          %.2f   %5.0f   %5.0f\n', share(q,1), 1000*share(q,2), 1000*share(q,3)); end

if isempty(P.targets)                        % site, its mirror, the ipsi point farthest from site
    dS = sum((G.pts(P.nHemi+1:end,:) - G.site).^2, 2); [~, jf] = max(dS);
    P.targets = [G.siteIdx, G.siteIdx - P.nHemi, P.nHemi + jf];
end
res = struct([]);
for it = 1:numel(P.targets)
    tg = P.targets(it); r = target_co(M, tg, Wc, Wn, PR, Vm, lam, ctr, fp, P.frac, su2, P.Hobs, gM(:, rel >= 1 & rel <= P.irFit(2)*P.Fs));
    res = [res r]; %#ok<AGROW>
    fprintf(['[LG-CO] target #%d (%s): laser/spont variance at target %.3f | laser->target Hankel SV/max %s\n' ...
             '        mode classes co/c~o/~co/~c~o = %d/%d/%d/%d\n' ...
             '        from the target''s last %d frames: %.0f%% of cortical spont variance inferable | ' ...
             '%.0f%% of what it sees is laser-unreachable\n' ...
             '        collateral (0-1 s): moving the target moves the site by %.2fx; max |collateral| %.2fx at #%d\n'], ...
        tg, pt_name(tg, G, P), r.snr, mat2str((r.hsv(1:min(4,end))/r.hsv(1)).',2), ...
        sum(r.cls==3), sum(r.cls==2), sum(r.cls==1), sum(r.cls==0), P.Hobs, 100*r.obsFrac, 100*r.unrFrac, ...
        r.coll(G.siteIdx), max(abs(r.coll(setdiff(1:nP,tg)))), find(abs(r.coll) == max(abs(r.coll(setdiff(1:nP,tg)))), 1));
    plot_co(G, P, M, r, tau, fHz, ctr, Vm, Er, dr, En, dn, fp, gAll, gM, rel, tag, sfx, figDir);
end
plot_order(G, P, cv, sv, lam, tau, modeD, tag, sfx, figDir);

%% [LG-BOOT] block-bootstrap stability of the maps (primary target) -------------------------
rng(P.seed); blk = round(P.bootBlk*P.Fs); nB = floor(T/blk); r0 = res(1);
bs = nan(P.nBoot, 4);
for b = 1:P.nBoot
    pick = randi(nB, nB, 1); w = zeros(1,T);                 % frame weights = bootstrap counts
    for q = pick.', w((q-1)*blk + (1:blk)) = w((q-1)*blk + (1:blk)) + 1; end
    vb = valid & w > 0;
    Db = era_simo(unit_ir(Y, ionU, ampU, rel, vb, w(ionU)), P.nD);
    if max(abs(eig(Db.A))) >= 1, continue; end
    Yrb = Y - sim_lds(Db, u); Eb = pca_basis(Yrb, vb, P.kPC, w); Yrr = Eb' * Yrb;
    Kb = ss_states(Yrr, hank_idx(vb, P.p, P.f), P.p, P.f, P.nS, w);
    Sb = lds_fit(Yrb, state_seq(Yrr, Kb, P.p, valid), vb, w);
    Mb = ortho_c(combine(Db, Sb));
    if max(abs(eig(Mb.A))) >= 1, continue; end
    Wcb = dlyap(Mb.A, Mb.B*Mb.B'); [Erb, ~] = eigs_sorted(Mb.C*Wcb*Mb.C');
    [Vb, Lb] = eig(Mb.A); Vb = Vb ./ vecnorm(Vb); lb = diag(Lb);
    ctb = abs(Vb\Mb.B).^2 ./ (1 - abs(lb).^2); gMb = model_ir(Mb, rel); fpb = gMb(:, iPk);
    [Erb5, drb] = eigs_sorted(Mb.C*Wcb*Mb.C'); kb = find(cumsum(drb)/sum(drb) >= 0.95, 1);
    rb = target_co(Mb, r0.tg, Wcb, dlyap(Mb.A, Mb.Q), Erb5(:,1:kb)*Erb5(:,1:kb)', Vb, lb, ctb, fpb, P.frac, su2, P.Hobs, gMb(:, rel >= 1 & rel <= P.irFit(2)*P.Fs));
    bs(b,:) = abs([corr(Erb(:,1), Er(:,1)), corr(rb.obsMaps(:,1), r0.obsMaps(:,1)), ...
                   corr(rb.coll, r0.coll), corr(fpb, fp)]);
end
fprintf('[LG-BOOT] %d/%d stable block-bootstraps (%d s blocks), |r| with full fit, median [IQR]:\n', ...
    sum(~isnan(bs(:,1))), P.nBoot, P.bootBlk);
nmB = {'reachable map 1','observable map 1','collateral map','peak footprint'};
for q = 1:4, fprintf('          %-18s %.2f [%.2f %.2f]\n', nmB{q}, median(bs(:,q),'omitnan'), prctile(bs(:,q),[25 75])); end

save(fullfile(dataDir, sprintf('lg_fit_%s%s.mat', tag, sfx)), 'P', 'M', 'D', 'S', 'cv', 'sv', 'lam', ...
    'tau', 'fHz', 'modeD', 'Wc', 'Wn', 'Er', 'dr', 'En', 'dn', 'fp', 'gAll', 'gM', 'rel', 'ctr', 'spn', ...
    'share', 'res', 'bs');
fprintf('[LG] saved data/lg_fit_%s%s.mat\n', tag, sfx);

%% ===== local functions =====================================================================
function g = unit_ir(Y, ion, amp, rel, ok, wtr)
% LS unit-amplitude response pooled over amplitudes (the linear model's IR); pre-onset baseline off
if nargin < 6, wtr = ones(size(ion)); end
T = size(Y,2); num = zeros(size(Y,1), numel(rel)); den = 0; base = rel < 0;
for k = 1:numel(ion)
    i = ion(k); if wtr(k) == 0 || i+rel(1) < 1 || i+rel(end) > T || ~all(ok(i+rel)), continue; end
    seg = Y(:, i+rel); num = num + wtr(k)*amp(k) * (seg - mean(seg(:,base), 2)); den = den + wtr(k)*amp(k)^2;
end
g = num / den;
end

function D = era_simo(h, n)
% Ho-Kalman / ERA for one input: h(:,k) = C A^(k-1) B, k = 1..L
[nP, L] = size(h); r = floor((L-1)/2); s = L-1-r;
H0 = zeros(nP*r, s); H1 = H0;
for i = 1:r
    for j = 1:s, H0((i-1)*nP + (1:nP), j) = h(:, i+j-1); H1((i-1)*nP + (1:nP), j) = h(:, i+j); end
end
[Uu, Ss, Vv] = svd(H0, 'econ'); sq = sqrt(diag(Ss(1:n,1:n)));
A = diag(1./sq) * Uu(:,1:n)' * H1 * Vv(:,1:n) * diag(1./sq);
D = struct('A',A, 'B',sq .* Vv(1,1:n)', 'C',Uu(1:nP,1:n) .* sq.', 'Q',zeros(n), 'n',n);
end

function y = sim_lds(M, u)
% deterministic response: x(t+1) = A x(t) + B u(t), y(t) = C x(t), x(1) = 0
T = numel(u); X = zeros(M.n, T); x = zeros(M.n, 1);
for t = 1:T-1, x = M.A*x + M.B*u(t); X(:,t+1) = x; end
y = M.C * X;
end

function E = pca_basis(Y, ok, k, w)
if nargin < 4, w = ones(1, size(Y,2)); end
i = find(ok); S = (Y(:,i) .* w(i)) * Y(:,i)';
[E, D] = eig((S+S')/2); [~, o] = sort(diag(D), 'descend'); E = E(:, o(1:k));
end

function t = hank_idx(ok, p, f)
% first-future-sample indices t whose window t-p .. t+f-1 is entirely usable
r = conv(double(ok), ones(1, p+f), 'valid') == p+f;
t = find(r) + p;
end

function W = past_vec(Yr, t, p)
k = size(Yr,1); W = zeros(p*k, numel(t));
for j = 1:p, W((j-1)*k + (1:k), :) = Yr(:, t-j); end
end

function [Kx, sv] = ss_states(Yr, idx, p, f, n, w)
% stochastic subspace ID: SVD of cov(future, past) * cov(past)^(-1/2); x(t) = Kx * past(t), cov(x) ~ I.
% Output side is NOT whitened (N4SID-style weighting): the data are so smooth that whitening the
% future makes ~40 directions equally predictable (canonical corr > 0.95) and spends states on
% low-variance PCs; unweighted, the states go where the cortical variance is.
if nargin < 6, w = ones(1, size(Yr,2)); end
k = size(Yr,1); dP = p*k; S = zeros(dP + f*k); N = 0;
for c0 = 1:20000:numel(idx)
    t = idx(c0:min(end, c0+19999)); Yf = zeros(f*k, numel(t));
    for j = 0:f-1, Yf(j*k + (1:k), :) = Yr(:, t+j); end
    H = [past_vec(Yr, t, p); Yf]; wt = w(t);
    S = S + (H .* wt) * H'; N = N + sum(wt);
end
S = S / N; iP = 1:dP; iY = dP + (1:f*k);
Spp = S(iP,iP) + 1e-8*trace(S(iP,iP))/dP*eye(dP);
[Ip, ~] = isqrt(Spp);
[~, Sv, Vv] = svd(S(iY,iP) * Ip, 'econ');
sv = diag(Sv); Kx = Vv(:, 1:n)' * Ip;
end

function [Ai, A] = isqrt(S)
[V, D] = eig((S+S')/2); d = max(real(diag(D)), eps*max(real(diag(D))));
Ai = V * diag(1./sqrt(d)) * V'; A = V * diag(sqrt(d)) * V';
end

function X = state_seq(Yr, Kx, p, ok)
% past-only state estimate at every frame whose past window is usable (NaN elsewhere)
T = size(Yr,2); X = nan(size(Kx,1), T);
okP = [false(1,p) conv(double(ok), ones(1,p), 'valid') == p]; okP = okP(1:T);
t = find(okP);
for c0 = 1:50000:numel(t)
    tc = t(c0:min(end, c0+49999)); X(:, tc) = Kx * past_vec(Yr, tc, p);
end
end

function M = lds_fit(Y, X, ok, w)
% LS on the state sequence (no input): x(t+1) = A x(t) + w;  y(t) = C x(t) + v
if nargin < 4, w = ones(1, size(Y,2)); end
fin = all(isfinite(X), 1) & ok;
t = find(fin(1:end-1) & fin(2:end)); wt = w(t);
A = ((X(:,t+1) .* wt) * X(:,t)') / ((X(:,t) .* wt) * X(:,t)');
Wr = X(:,t+1) - A*X(:,t); Q = (Wr .* wt) * Wr' / sum(wt);
ty = find(fin); wy = w(ty);
C = ((Y(:,ty) .* wy) * X(:,ty)') / ((X(:,ty) .* wy) * X(:,ty)');
Vr = Y(:,ty) - C*X(:,ty); R = (Vr .* wy) * Vr' / sum(wy);
n = size(X,1); M = struct('A',A, 'B',zeros(n,1), 'C',C, 'Q',Q, 'R',R, 'n',n);
end

function M = combine(D, S)
M = struct('A',blkdiag(D.A, S.A), 'B',[D.B; zeros(S.n,1)], 'C',[D.C S.C], ...
           'Q',blkdiag(zeros(D.n), S.Q), 'R',S.R, 'n',D.n + S.n);
end

function M = ortho_c(M)
% similarity transform x' = R x with C = Q R (economy QR): C' = Q has orthonormal columns
[Qc, Rc] = qr(M.C, 0); M.A = Rc*M.A/Rc; M.B = Rc*M.B; M.C = Qc; M.Q = Rc*M.Q*Rc';
end

function r2 = hstep_r2(S, Y, yD, X, t0, h)
% h-step prediction of the FULL y: driven part known from u, spontaneous part from the S state
Xh = X(:, t0); for j = 1:h, Xh = S.A*Xh; end
Yt = Y(:, t0+h); Yp = yD(:, t0+h) + S.C*Xh;
r2 = 1 - sum((Yt - Yp).^2, 'all') / sum((Yt - mean(Yt,2)).^2, 'all');
end

function g = model_ir(M, rel)
% y(tau) = C A^(tau-1) B for tau >= 1, 0 at tau <= 0 (D = 0: the pulse shows one frame later)
g = zeros(size(M.C,1), numel(rel)); x = M.B;
for j = find(rel >= 1), g(:,j) = M.C*x; x = M.A*x; end
end

function r = target_co(M, tg, Wc, Wn, PR, Vm, lam, ctr, fp, frac, su2, H, gw)
% (1) MODAL Kalman classes (basis-free, |C v_i| = 1) + laser->target Hankel SVs.
% (2) OBSERVER view: what can be inferred about the cortex from the target's own trace over the
%     last H frames (laser-driven + spontaneous + measurement noise, laser at the experiment's
%     actual input power su2). Gramian eigenvectors of Wo are dual (left-eigenvector) directions --
%     not cortical patterns, and unstable under resampling -- so the maps use this instead.
%     Cov(x_t, y_tg(t-j)) = A^j Sx c'  (everything after t-j is independent of x_{t-j}).
c = M.C(tg,:); n = M.n; A = M.A;
SL = su2*Wc; Sx = SL + Wn;
GL = zeros(n,H); GN = zeros(n,H); gam = zeros(1,H); Aj = eye(n);
for j = 1:H
    GL(:,j) = Aj*SL*c'; GN(:,j) = Aj*Wn*c'; gam(j) = c*Aj*Sx*c'; Aj = A*Aj;
end
Shh = toeplitz(gam) + M.R(tg,tg)*eye(H);                       % target-history covariance
dL = GL/Shh*GL';  dN = GN/Shh*GN';                              % state variance explained
SigL = M.C*SL*M.C'; SigN = M.C*Wn*M.C';
[Eo, do] = eigs_sorted(M.C*dN*M.C');  Eo = Eo .* sign(Eo(tg,:) + eps);   % spont. seen by target
[Eb, ~]  = eigs_sorted(SigN - M.C*dN*M.C');                     % spont. the target is blind to
[Eh, ~]  = eigs_sorted(SigL - M.C*dL*M.C');  Eh = Eh .* sign(fp.'*Eh + eps);   % hidden collateral
[Es, ~]  = eigs_sorted(M.C*dL*M.C');  Es = Es .* sign(fp.'*Es + eps);   % laser part target reports
Iu = eye(size(PR,1)) - PR; Su = Iu*(M.C*dN*M.C')*Iu; [Eu, ~] = eigs_sorted(Su); Eu = Eu .* sign(Eu(tg,:) + eps);
obs = (abs(c*Vm).^2).' ./ (1 - abs(lam).^2);
cls = 2*(ctr/max(ctr) >= frac) + (obs/max(obs) >= frac);       % 3 co, 2 c~o, 1 ~co, 0 ~c~o
Wo  = dlyap(A', c'*c); hsv = sort(sqrt(abs(eig(Wc*Wo))), 'descend');
% COLLATERAL. The controller knows its own command, so laser-driven activity is not 'hidden' from
% it -- but with ONE input it cannot be shaped: moving the target drags a fixed pattern along.
% coll_j = LS gain of point j's laser response on the target's, over the first second (gw).
% NOT the DC ratio G_j(1)/G_tg(1): from impulse data the DC gain is set by the noisy slow tail
% and post-dip rebound (site DC came out POSITIVE, +1.58 %dF/F/V, against the OL step's sustained
% inhibition) -- RESEARCH 2026-10-05.
dc = M.C * ((eye(n) - A) \ M.B); coll = (gw * gw(tg,:)') / (gw(tg,:) * gw(tg,:)');
r = struct('tg',tg, 'obsMaps',Eo(:,1:3), 'do',do, 'obsFrac',trace(M.C*dN*M.C')/trace(SigN), ...
    'blindMap',Eb(:,1), 'hidMap',Eh(:,1), 'hidFrac',1 - trace(M.C*dL*M.C')/trace(SigL), 'coll',coll, 'dc',dc, ...
    'seenLMap',Es(:,1), 'unrMap',Eu(:,1), 'unrFrac',trace(Su)/trace(M.C*dN*M.C'), ...
    'snr',(c*SL*c')/(c*Wn*c' + M.R(tg,tg)), 'obs',obs, 'cls',cls, 'hsv',hsv);
end

function [E, d] = eigs_sorted(S)
[E, D] = eig((S+S')/2); [d, o] = sort(real(diag(D)), 'descend'); E = real(E(:,o));
end

function Q = orth_dirs(S, frac)
[E, d] = eigs_sorted(S); Q = E(:, d >= frac*d(1));
end

function s = pt_name(i, G, P)
if i == G.siteIdx, s = 'laser site';
elseif i == G.siteIdx - P.nHemi, s = 'site mirror (contra)';
elseif i > P.nHemi, s = 'ipsi';
else, s = 'contra';
end
end

function cm = divmap(nc)
x = linspace(-1, 1, nc).';                   % blue - white - red
cm = min(1, max(0, [interp1([-1 0 1],[0.15 1 0.75],x) interp1([-1 0 1],[0.35 1 0.15],x) interp1([-1 0 1],[0.75 1 0.15],x)]));
end

function brainmap(ax, G, vals, ttl, tg)
% interpolate the 100 grid values onto the cortex mask, per hemisphere; transposed display
img = nan(size(G.mask));
for h = [-1 1]
    inH = G.hemiSide == h; [R, Cc] = find(inH);
    if h == 1, ip = 51:100; else, ip = 1:50; end
    F = scatteredInterpolant(G.pts(ip,1), G.pts(ip,2), real(vals(ip)), 'natural', 'nearest');
    img(inH) = F(R, Cc);
end
imagesc(ax, img.', 'AlphaData', ~isnan(img.')); axis(ax, 'image', 'off'); hold(ax, 'on');
m = max(abs(img(:)), [], 'omitnan'); if m > 0, clim(ax, [-m m]); end
colormap(ax, divmap(256)); set(ax, 'Color', 'w');
plot(ax, G.mid(:,1), G.mid(:,2), 'k:', 'LineWidth', 0.5);
plot(ax, G.pts(:,1), G.pts(:,2), '.', 'Color', [0.3 0.3 0.3], 'MarkerSize', 3);
plot(ax, G.site(1), G.site(2), 'kx', 'MarkerSize', 7, 'LineWidth', 1.2);
if nargin > 4 && ~isempty(tg), plot(ax, G.pts(tg,1), G.pts(tg,2), 'o', 'Color', [0 0.6 0], 'MarkerSize', 7, 'LineWidth', 1.4); end
title(ax, ttl, 'FontSize', 8, 'FontWeight', 'normal', 'Interpreter', 'none');
end

function v = mode_map(C, vi)
% real spatial snapshot of a (possibly complex) mode, rotated to its largest real part
m = C*vi; th = -angle(sum(m.^2))/2; v = real(m*exp(1i*th));
end

function plot_co(G, P, M, r, tau, fHz, ctr, Vm, Er, dr, En, dn, fp, gAll, gM, rel, tag, sfx, figDir)
fig = figure('Color','w', 'Position', [40 40 1500 1300], 'Name', sprintf('LG target %d', r.tg));
tl = tiledlayout(fig, 4, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('%s%s | n = %d (laser-driven %d + spontaneous %d) | target #%d (%s) | x = laser site, o = target', ...
    tag, sfx, M.n, P.nD, P.nS, r.tg, pt_name(r.tg, G, P)), 'FontSize', 10, 'Interpreter', 'none');
% row 1: mode scatter | Hankel SVs | unit IR at target | peak footprint
ax = nexttile(tl); fl = 1e-4; cn = max(ctr/max(ctr), fl); on = max(r.obs/max(r.obs), fl);
scatter(ax, cn, on, 36, log10(1000*tau), 'filled', 'MarkerEdgeColor', 'k'); set(ax, 'XScale','log', 'YScale','log');
hold(ax,'on'); xline(ax, P.frac, 'k--'); yline(ax, P.frac, 'k--'); xlim(ax, [fl/2 2]); ylim(ax, [fl/2 2]);
cb = colorbar(ax); cb.Label.String = 'log_{10} \tau (ms)';
xlabel(ax, 'laser controllability (norm.; floor = not driven)'); ylabel(ax, sprintf('observability from #%d (norm.)', r.tg));
title(ax, sprintf('modes: co %d | c~o %d | ~co %d | ~c~o %d', sum(r.cls==3), sum(r.cls==2), sum(r.cls==1), sum(r.cls==0)), 'FontSize', 8, 'FontWeight','normal');
ax = nexttile(tl); hv = r.hsv(r.hsv > 1e-6*r.hsv(1)); bar(ax, hv/hv(1), 'FaceColor', [0.4 0.4 0.7]);
xlabel(ax, 'balanced state'); ylabel(ax, 'Hankel SV / max'); ylim(ax, [0 1.05]);
title(ax, sprintf('laser \\rightarrow #%d Hankel SVs', r.tg), 'FontSize', 8, 'FontWeight', 'normal');
ax = nexttile(tl); hold(ax, 'on');
plot(ax, rel/P.Fs, gAll(r.tg,:), 'k-', 'LineWidth', 1.0, 'DisplayName', 'data (all trials)');
plot(ax, rel/P.Fs, gM(r.tg,:), 'r--', 'LineWidth', 1.4, 'DisplayName', 'model C A^{\tau-1} B');
if r.tg ~= G.siteIdx, plot(ax, rel/P.Fs, gAll(G.siteIdx,:), '-', 'Color', [0.6 0.6 0.6], 'DisplayName', 'data at site'); end
xline(ax, 0, 'k:', 'HandleVisibility', 'off'); xlim(ax, [rel(1) rel(end)]/P.Fs);
xlabel(ax, 'time from pulse (s)'); ylabel(ax, '%\DeltaF/F per V'); legend(ax, 'FontSize', 7, 'Location', 'southeast');
title(ax, sprintf('unit impulse response at #%d', r.tg), 'FontSize', 8, 'FontWeight','normal');
brainmap(nexttile(tl), G, fp, 'model response at peak lag (laser footprint)', r.tg);
% row 2: laser-reachable maps 1-3 | spontaneous map 1
for q = 1:3, brainmap(nexttile(tl), G, Er(:,q), sprintf('laser-reachable %d (%.0f%%)', q, 100*dr(q)/sum(dr)), r.tg); end
brainmap(nexttile(tl), G, En(:,1), sprintf('spontaneous 1 (%.0f%%)', 100*dn(1)/sum(dn)), r.tg);
% row 3: spontaneous activity the target's trace reveals 1-3 | what it is blind to
for q = 1:3, brainmap(nexttile(tl), G, r.obsMaps(:,q), sprintf('observable from #%d: %d (%.0f%%)', r.tg, q, 100*r.do(q)/sum(r.do)), r.tg); end
brainmap(nexttile(tl), G, r.blindMap, sprintf('unobservable from #%d (%.0f%% of spont hidden)', r.tg, 100*(1-r.obsFrac)), r.tg);
% row 4: collateral of holding the target | seen-but-unreachable | driven-unseen | seen-undriven modes
brainmap(nexttile(tl), G, r.coll, sprintf('collateral per unit at #%d, 0-1 s (site %.2fx)', r.tg, r.coll(G.siteIdx)), r.tg);
brainmap(nexttile(tl), G, r.unrMap, sprintf('seen, laser-unreachable: %.0f%%', 100*r.unrFrac), r.tg);
nmC = {2,'c~o mode (driven, unseen)'; 1,'~co mode (seen; undriven BY CONSTRUCTION)'};
for q = 1:2
    ax = nexttile(tl); ii = find(r.cls == nmC{q,1});
    if isempty(ii), axis(ax,'off'); title(ax, sprintf('%s: no mode', nmC{q,2}), 'FontSize', 8, 'FontWeight','normal'); continue; end
    sc = (nmC{q,1}~=1)*ctr(ii)/max(ctr) + (nmC{q,1}~=2)*r.obs(ii)/max(r.obs);
    [~, j] = max(sc); i = ii(j);
    brainmap(ax, G, mode_map(M.C, Vm(:,i)), sprintf('%s: \\tau %.0f ms, %.1f Hz', nmC{q,2}, 1000*tau(i), fHz(i)), r.tg);
end
fn = fullfile(figDir, sprintf('lg_co_%s%s_t%d.png', tag, sfx, r.tg));
exportgraphics(fig, fn, 'Resolution', 200); fprintf('[LG-CO] wrote %s\n', fn);
end

function plot_order(G, P, cv, sv, lam, tau, modeD, tag, sfx, figDir)
fig = figure('Color','w', 'Position', [60 60 1700 380], 'Name', 'LG order');
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); imagesc(ax, G.mimg.'); colormap(ax, gray); axis(ax, 'image', 'off'); hold(ax, 'on');
plot(ax, G.mid(:,1), G.mid(:,2), 'y:');
plot(ax, G.pts(1:50,1), G.pts(1:50,2), 'c.', G.pts(51:100,1), G.pts(51:100,2), 'm.', 'MarkerSize', 10);
for i = P.targets, text(ax, G.pts(i,1)+6, G.pts(i,2), sprintf('%d', i), 'Color', 'g', 'FontSize', 8); end
plot(ax, G.site(1), G.site(2), 'rx', 'MarkerSize', 9, 'LineWidth', 1.5);
title(ax, sprintf('grid: 1-50 contra (cyan), 51-100 ipsi (magenta); site = #%d', G.siteIdx), 'FontSize', 8, 'FontWeight','normal');
ax = nexttile(tl); hold(ax, 'on');
plot(ax, cv.nD, cv.r2ir, '-s', 'LineWidth', 1.4, 'MarkerSize', 4, 'DisplayName', 'all 100 points');
plot(ax, cv.nD, cv.r2irSite, '-^', 'MarkerSize', 4, 'DisplayName', 'site');
yline(ax, cv.ceilIr, 'b--', 'DisplayName', 'model-free ceiling (all)');
yline(ax, cv.ceilIrSite, 'r--', 'DisplayName', 'model-free ceiling (site)');
xline(ax, P.nD, 'k-', 'DisplayName', 'chosen n_D'); ylim(ax, [0 1]);
xlabel(ax, 'laser-driven order n_D'); ylabel(ax, 'CV R^2 of unit impulse response (0-1 s)');
legend(ax, 'Location', 'southeast', 'FontSize', 7);
title(ax, 'driven block (ERA), blocked 5-fold CV', 'FontSize', 8, 'FontWeight','normal');
ax = nexttile(tl); hold(ax, 'on');
plot(ax, cv.nS, mean(cv.r2_1,2), '-o', 'MarkerSize', 3, 'DisplayName', '1-step');
plot(ax, cv.nS, mean(cv.r2h,2), '-o', 'MarkerSize', 3, 'LineWidth', 1.4, 'DisplayName', sprintf('%d-step', P.hStep));
yline(ax, cv.persist, 'b:', 'DisplayName', sprintf('%d-step persistence', P.hStep));
xline(ax, P.nS, 'k-', 'DisplayName', 'chosen n_S'); ylim(ax, [0 1]);
xlabel(ax, 'spontaneous order n_S'); ylabel(ax, 'CV R^2 of full y (100 points)');
legend(ax, 'Location', 'southeast', 'FontSize', 7);
title(ax, 'spontaneous block (subspace ID on residual)', 'FontSize', 8, 'FontWeight','normal');
ax = nexttile(tl); th = linspace(0, 2*pi, 200); plot(ax, cos(th), sin(th), 'k:'); hold(ax, 'on');
scatter(ax, real(lam(~modeD)), imag(lam(~modeD)), 30, [0.5 0.5 0.5], 'filled', 'DisplayName', 'spontaneous');
scatter(ax, real(lam(modeD)), imag(lam(modeD)), 50, [0.85 0.2 0.1], 'filled', 'MarkerEdgeColor', 'k', 'DisplayName', 'laser-driven');
axis(ax, 'equal'); legend(ax, 'Location', 'southwest', 'FontSize', 7); xlabel(ax, 'Re \lambda'); ylabel(ax, 'Im \lambda');
title(ax, sprintf('eigenvalues of A (n_D %d + n_S %d)', P.nD, P.nS), 'FontSize', 8, 'FontWeight','normal');
fn = fullfile(figDir, sprintf('lg_order_%s%s.png', tag, sfx));
exportgraphics(fig, fn, 'Resolution', 200); fprintf('[LG] wrote %s\n', fn);
end
