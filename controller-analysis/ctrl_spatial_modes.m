% ctrl_spatial_modes.m -- STAGE 5b: spatial interpretation of the ipsi readout.
%
% WHAT THIS ANSWERS (user 2026-07-28)
%   "Can we treat contra as an OBSERVATION SPACE, so that the activity the controller
%    regulates gets a SPATIAL interpretation?"
%   Stage 5a established the licence for this: contra carries no temporal information
%   beyond the ipsi readout's own past (gain ~ +0.009), i.e. contra and ipsi are two
%   VIEWS OF ONE SHARED LATENT STATE -- ipsi views it in time, contra views it in space.
%   That redundancy is what makes a spatial decomposition of ipsi well posed.
%
% THE TWO DECOMPOSITIONS, AND WHY ONLY ONE GETS PLOTTED
%   Observability is about output energy accumulated over time, so a state direction v
%   generates the contra TRAJECTORY  C_contra A^k v,  k = 0,1,2,...  For a general
%   direction (balanced, or an eigenvector of a raw Gramian) A^k v is NOT proportional to
%   v, so the spatial pattern MORPHS as it decays and a single image is a snapshot, not a
%   mode. Eigenmodes of A are the unique exception: A^k v_i = lam_i^k v_i, so the pattern
%   is TIME-INVARIANT and only amplitude/phase evolve. Hence:
%     GRAMIANS -> scalars (rankings, error bars).      EIGENMODES -> the pictures.
%   A raw Gramian's eigenvectors are also realization-dependent (under x -> Tx,
%   Wo -> T^-T Wo T^-1, whose eigenvectors are NOT T*v), so they are not plotted at all.
%   The one Gramian object that IS invariant and IS spatially meaningful is the
%   GENERALIZED eigenproblem  Wo_contra v = lam Wo_ipsi v: a similarity transform hits
%   both Gramians identically, so lam is basis-free. Large lam = directions contra sees
%   well and the single ipsi readout sees poorly.
%
% CIRCULARITY GUARD
%   The latent state was identified with contra channels AS OUTPUTS, so "is x observable
%   from contra" is near-tautological. The non-circular question is: of the state that
%   actually DRIVES IPSI, how much does contra observe? Every observability number below
%   is therefore reported ALONGSIDE that mode's ipsi variance share, and the summary
%   statistic is ipsi-share-weighted.
%
% PREREQS  Stage 5a cache (ctrl_subspace_id.m) -- everything here is read from it.
%          No SVD reload, no refit.
% SECTIONS [CFG] [LOAD] [MODAL] [GRAM] [MAPS] [TABLE] [FIG-MODAL] [FIG-MAPS]
%          [FIG-PATTERN] [SAVE]

%% [CTRL-MODE-CFG] --------------------------------------------------------------
sess_tag = 'AL_0033_0226_e2';
nShow    = 6;            % mode groups to render as spatial maps
tolImag  = 1e-8;         % |imag(lam)| above this = oscillatory mode
rng(7,'twister');

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga');
if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-MODE-LOAD] -------------------------------------------------------------
sid_file = fullfile(dataDir, sprintf('ctrl_subspace_id_%s.mat', sess_tag));
assert(exist(sid_file,'file')>0, '[CTRL-MODE] Stage 5a cache missing: %s', sid_file);
S = load(sid_file);
A = S.A; B = S.B; C = S.C; D = S.D; K = S.K;
nx = S.nx; iZ = S.iZ; Ts = S.Ts; Fs = S.Fs;
Cz = C(iZ,:);  Cc = C(1:iZ-1,:);                    % ipsi row / contra block
yscale = S.yscale(:);  Wmix = S.Wmix;  sd_c = S.sd_c(:);
Su = S.Su(:);  grR = S.grR(:);  grC = S.grC(:);  mimg = S.mimg;
fprintf('\n[CTRL-MODE] %s | nx=%d | %d contra channels | %d contra px\n', ...
    sess_tag, nx, iZ-1, numel(Su));

%% [CTRL-MODE-MODAL] ------------------------------------------------------------
[V, Lam] = eig(A);
lam = diag(Lam);
V   = V ./ vecnorm(V,2,1);                          % unit-norm eigenvectors (fixes the scale
Wl  = inv(V);                                       %  convention so ||C v|| is comparable)

tau = -Ts ./ log(min(abs(lam), 1-eps));             % decay time constant (s)
frq = abs(angle(lam)) / (2*pi*Ts);                  % oscillation frequency (Hz)

% OBSERVABILITY -- noise-weighted (Fisher-information form), NOT raw gain.
% Raw ||C_contra v|| sums 8 channels against the ipsi row's 1, so contra would beat ipsi
% by channel count alone. Weighting each channel by its own innovations variance makes the
% comparison fair: extra channels help only to the extent their noise permits.
Sig = S.NoiseVariance;  Sig = (Sig+Sig.')/2;
Wc_n = chol(inv(Sig(1:iZ-1,1:iZ-1) + 1e-12*eye(iZ-1)));   % Sig_contra^{-1/2}
wz_n = 1/sqrt(Sig(iZ,iZ));                                % Sig_ipsi^{-1/2}
obs_c = vecnorm(Wc_n*(Cc*V), 2, 1).';               % modal observability from CONTRA
obs_z = abs(wz_n*(Cz*V)).';                         % modal observability from IPSI

% CONTROLLABILITY -- PBH cosine, which is invariant to eigenvector scaling. |w_i'B| alone
% depends on the normalization of the left eigenvectors and is not comparable across modes.
ctrb  = abs(Wl*B) ./ (vecnorm(Wl,2,2) * max(norm(B),eps));
fprintf('[CTRL-MODE] cond(V) = %.3g  (higher => eigenvectors less orthogonal)\n', cond(V));

% Ipsi variance share per mode, from the stationary state covariance driven by the
% identified innovations. P solves P = A P A' + K Sig K'; in modal coordinates q = V^-1 x,
% var(z) = (Cz V) Pq (Cz V)' with Pq = Wl P Wl'. Diagonal terms = per-mode contribution;
% the off-diagonal energy is reported so the reader knows how much the split leaves out.
P   = dlyap(A, K*Sig*K.');
Pq  = Wl * P * Wl';
cz  = (Cz*V).';                                     % [nx x 1] modal gain onto ipsi
contrib  = real(conj(cz) .* diag(Pq) .* cz);        % per-mode own-variance contribution
var_z_md = real((Cz*V) * Pq * (Cz*V)');             % total, cross terms included
xsum = sum(contrib)/max(var_z_md,eps);
fprintf('[CTRL-MODE] modal contributions sum to %.0f%% of model ipsi variance.\n', 100*xsum);
if xsum > 1.25 || xsum < 0.75
    fprintf(['            ** modes are strongly NON-ORTHOGONAL: the excess is cancelling cross terms.\n' ...
             '               Read the shares below as "how much variance this mode carries on its own",\n' ...
             '               NOT as an additive partition of the signal. **\n']);
end

% group conjugate pairs into one physical mode
grp = zeros(nx,1);  g = 0;
for i = 1:nx
    if grp(i), continue; end
    g = g + 1;  grp(i) = g;
    if abs(imag(lam(i))) > tolImag
        [~, j] = min(abs(lam - conj(lam(i))) + 1e9*(grp~=0));
        if j ~= i && abs(imag(lam(j))) > tolImag, grp(j) = g; end
    end
end
nG_md = g;
M = struct('idx',{},'lam',{},'tau',{},'frq',{},'share',{},'obs_c',{},'obs_z',{},'ctrb',{},'osc',{});
for q = 1:nG_md
    ii = find(grp == q);
    M(q).idx = ii;              M(q).lam = lam(ii(1));
    M(q).tau = tau(ii(1));      M(q).frq = frq(ii(1));
    M(q).share = sum(contrib(ii)) / max(sum(contrib), eps);
    M(q).obs_c = max(obs_c(ii)); M(q).obs_z = max(obs_z(ii));
    M(q).ctrb  = max(ctrb(ii));  M(q).osc = abs(imag(lam(ii(1)))) > tolImag;
end
[~, ord] = sort([M.share], 'descend');  M = M(ord);

%% [CTRL-MODE-GRAM] Gramians -> scalars only ------------------------------------
% Noise-weighted, for the same reason as the modal measures above: raw C'C would let the
% 8-channel contra block outscore the 1-channel ipsi readout on channel count alone.
Wo_c = dlyap(A.', (Wc_n*Cc).'*(Wc_n*Cc));
Wo_z = dlyap(A.', (wz_n*Cz).'*(wz_n*Cz));
Wc   = dlyap(A, B*B.');
[~, hsvals] = balreal(ss(A,B,C,D,Ts));              % Hankel SVs (invariant). NOT named `hsv`
                                                    % -- that would shadow the colormap.

reg = 1e-8 * trace(Wo_z)/nx;
[Vg, Lg] = eig(Wo_c, Wo_z + reg*eye(nx));
lg = real(diag(Lg));  [lg, og] = sort(lg,'descend');  Vg = real(Vg(:,og));
fprintf('[CTRL-MODE] generalized eig (contra vs ipsi observability): max %.3g, median %.3g, min %.3g\n', ...
    lg(1), median(lg), lg(end));
fprintf('[CTRL-MODE] Hankel SVs (top 6): %s\n', mat2str(round(hsvals(1:min(6,numel(hsvals))).',3)));

% ipsi-share-weighted observability = the circularity-guarded summary
w_share = [M.share].';
fprintf('[CTRL-MODE] ipsi-share-weighted observability: contra %.3f | ipsi %.3f\n', ...
    sum(w_share.*[M.obs_c].'), sum(w_share.*[M.obs_z].'));

%% [CTRL-MODE-MAPS] project state directions into contra PIXEL space ------------
% v (state) -> C_contra v (channel) -> yscale (physical channel) -> Wmix (z-scored px)
% -> sd_c (%dF/F px).  Wmix has orthonormal columns, so the POD step is exact within the
% retained subspace. NOTE the map is blind by construction to the stim-affected midline
% cluster (excluded at Stage 2) and to whatever falls outside the retained POD subspace.
proj = @(v) sd_c .* (Wmix * (yscale(1:iZ-1) .* (Cc*v)));

MAP = zeros(numel(Su), numel(M));  PHS = zeros(numel(Su), numel(M));
for q = 1:numel(M)
    pm = proj(V(:, M(q).idx(1)));
    MAP(:,q) = abs(pm);
    PHS(:,q) = angle(pm);
    if ~M(q).osc, MAP(:,q) = real(pm); PHS(:,q) = 0; end   % real mode: signed map
end
MAPg = zeros(numel(Su), min(3,nx));                        % generalized-eig directions
for q = 1:size(MAPg,2), MAPg(:,q) = real(proj(Vg(:,q))); end

%% [CTRL-MODE-TABLE] ------------------------------------------------------------
fprintf('\n  mode   tau(s)   freq(Hz)   ipsi share   obs_contra   obs_ipsi   ctrb(laser)   type\n');
for q = 1:numel(M)
    if M(q).osc, kind = 'oscillatory'; else, kind = 'relaxation'; end
    fprintf('  %3d   %6.3f   %7.2f   %9.1f%%   %10.3f   %8.3f   %11.3f   %s\n', q, M(q).tau, ...
        M(q).frq, 100*M(q).share, M(q).obs_c, M(q).obs_z, M(q).ctrb, kind);
end

%% [CTRL-MODE-FIG-MODAL] --------------------------------------------------------
f1 = figure('Color','w','Position',[40 40 1400 760]);
t1 = tiledlayout(f1,2,2,'TileSpacing','compact','Padding','compact');

nexttile(t1,1); hold on;                                   % eigenvalues
th = linspace(0,2*pi,300); plot(cos(th),sin(th),'k:');
sz = 40 + 400*[M.share];
scatter(real([M.lam]), imag([M.lam]), sz, [M.obs_c], 'filled', 'MarkerEdgeColor','k');
cb = colorbar; cb.Label.String = 'contra observability'; colormap(gca, parula);
axis equal; grid on; xlabel('Re(\lambda)'); ylabel('Im(\lambda)');
title('latent modes (size = ipsi variance share)');

nexttile(t1,2);                                            % ipsi share vs tau
bar(100*[M.share], 'FaceColor',[0.3 0.5 0.8]); grid on;
set(gca,'XTick',1:numel(M), 'XTickLabel', arrayfun(@(q) sprintf('%.2fs', M(q).tau), 1:numel(M), 'UniformOutput',false));
xtickangle(45); ylabel('% of ipsi variance'); xlabel('mode (labelled by \tau)');
title('what the regulated signal is made of');

nexttile(t1,3); hold on;                                   % the circularity-guarded plot
scatter([M.obs_z], [M.obs_c], sz, 100*[M.share], 'filled', 'MarkerEdgeColor','k');
lm = max([[M.obs_z] [M.obs_c]]); plot([0 lm],[0 lm],'k--');
cb2 = colorbar; cb2.Label.String = '% ipsi variance';
xlabel('noise-weighted observability from IPSI'); ylabel('from CONTRA (8 ch)'); grid on;
set(gca,'XScale','log','YScale','log');
title('above the line = contra sees it better than the ipsi readout');

nexttile(t1,4); hold on;                                   % Gramian scalars
yyaxis left;  plot(hsvals,'o-','LineWidth',1.4); ylabel('Hankel SV'); set(gca,'YScale','log');
yyaxis right; plot(lg,'s--','LineWidth',1.2); ylabel('gen. eig (contra/ipsi obs)'); set(gca,'YScale','log');
xlabel('index'); grid on; title('Gramian scalars (invariant)');

sgtitle(f1, sprintf('[CTRL-MODE] Stage 5b modal structure  %s  (n_x=%d)', strrep(sess_tag,'_','\_'), nx));
p1 = fullfile(fig_dir, sprintf('ctrl_spatial_modes_summary_%s.png', sess_tag));
exportgraphics(f1, p1, 'Resolution', 300);  fprintf('[CTRL-MODE-FIG] -> %s\n', p1);

%% [CTRL-MODE-FIG-MAPS] ---------------------------------------------------------
nS = min(nShow, numel(M));
f2 = figure('Color','w','Position',[40 40 320*nS 640]);
t2 = tiledlayout(f2,2,nS,'TileSpacing','compact','Padding','compact');
for q = 1:nS
    nexttile(t2,q);
    local_brainmap(mimg, grR(Su), grC(Su), MAP(:,q), local_divmap(), true);
    title(sprintf('mode %d: \\tau=%.2fs%s\n%.0f%% of ipsi var', q, M(q).tau, ...
        local_freqstr(M(q)), 100*M(q).share), 'FontSize', 9);
    nexttile(t2, nS+q);
    if M(q).osc
        local_brainmap(mimg, grR(Su), grC(Su), PHS(:,q), hsv(256), false);
        title('phase (rad)', 'FontSize', 9);
    else
        local_brainmap(mimg, grR(Su), grC(Su), MAP(:,q), local_divmap(), true);
        title('(relaxation mode: no phase)', 'FontSize', 9);
    end
end
sgtitle(f2, sprintf('[CTRL-MODE] contra spatial footprint per latent mode  %s   (top row: amplitude, bottom: phase)', ...
    strrep(sess_tag,'_','\_')));
p2 = fullfile(fig_dir, sprintf('ctrl_spatial_modes_maps_%s.png', sess_tag));
exportgraphics(f2, p2, 'Resolution', 300);  fprintf('[CTRL-MODE-FIG] -> %s\n', p2);

%% [CTRL-MODE-FIG-PATTERN] filter vs forward pattern ----------------------------
f3 = figure('Color','w','Position',[40 40 1300 420]);
t3 = tiledlayout(f3,1,3,'TileSpacing','compact','Padding','compact');
nexttile(t3,1);
local_brainmap(mimg, grR(Su), grC(Su), S.filt, local_divmap(), true);
title(sprintf('FILTER  b  (what was being plotted)\nnot spatially interpretable'), 'FontSize',10);
nexttile(t3,2);
local_brainmap(mimg, grR(Su), grC(Su), S.patt, local_divmap(), true);
title(sprintf('PATTERN  a = cov(x, yhat)  (Haufe)\nthis is the map'), 'FontSize',10);
nexttile(t3,3);
scatter(S.filt, S.patt, 14, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha',0.5); grid on;
xlabel('filter weight b'); ylabel('forward pattern a');
title(sprintf('\\rho = %+.3f   (sign flips: %.0f%% of px)', S.rho_ab, ...
    100*nnz(sign(S.filt)~=sign(S.patt))/numel(S.filt)), 'FontSize',10);
sgtitle(f3, sprintf('[CTRL-MODE] Stage-2 predictor: filter vs forward pattern  %s', strrep(sess_tag,'_','\_')));
p3 = fullfile(fig_dir, sprintf('ctrl_spatial_pattern_%s.png', sess_tag));
exportgraphics(f3, p3, 'Resolution', 300);  fprintf('[CTRL-MODE-FIG] -> %s\n', p3);

%% [CTRL-MODE-SAVE] -------------------------------------------------------------
MD = struct();
MD.sess_tag=sess_tag; MD.nx=nx; MD.Ts=Ts;
MD.lam=lam; MD.V=V; MD.Wl=Wl; MD.tau=tau; MD.frq=frq;
MD.obs_c=obs_c; MD.obs_z=obs_z; MD.ctrb=ctrb; MD.contrib=contrib; MD.var_z_md=var_z_md;
MD.modes=M; MD.grp=grp;
MD.Wo_c=Wo_c; MD.Wo_z=Wo_z; MD.Wc=Wc; MD.hsv=hsv; MD.gen_eig=lg; MD.gen_dir=Vg;
MD.MAP=MAP; MD.PHS=PHS; MD.MAPg=MAPg; MD.Su=Su; MD.grR=grR; MD.grC=grC;
md_file = fullfile(dataDir, sprintf('ctrl_spatial_modes_%s.mat', sess_tag));
save(md_file, '-struct', 'MD', '-v7.3');
fprintf('[CTRL-MODE-SAVE] -> %s\n\n', md_file);

%% ---- helpers -----------------------------------------------------------------
function local_brainmap(mimg, rr, cc, vals, cmap, symmetric)
% gray brain + scatter of grid nodes coloured by vals
g = mat2gray(mimg, [prctile(mimg(:),1) prctile(mimg(:),99)]);
image(repmat(g,1,1,3)); axis image ij off; hold on;
if symmetric
    cl = max(abs(vals(:))) * [-1 1];  if cl(2)==0, cl = [-1 1]; end
else
    cl = [min(vals(:)) max(vals(:))];  if diff(cl)==0, cl = cl + [-1 1]; end
end
scatter(cc, rr, 26, vals, 'filled');
colormap(gca, cmap); clim(cl); colorbar;
end

function cm = local_divmap()
% blue-white-red diverging
n = 128;
b = [linspace(0.10,1,n).' linspace(0.30,1,n).' linspace(0.70,1,n).'];
r = [linspace(1,0.75,n).' linspace(1,0.10,n).' linspace(1,0.15,n).'];
cm = [b; r];
end

function s = local_freqstr(mq)
if mq.osc, s = sprintf(', %.1f Hz', mq.frq); else, s = ''; end
end
