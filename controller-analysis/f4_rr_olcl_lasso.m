% controller-analysis/f4_rr_olcl_lasso.m
% Fig 4H open-loop comparison with the LASSO disturbance (research-hub #100): the OL vs CL rejection
% ratio, offset share and fluctuation ratio of f4_rr_denominator_check.m, with only the disturbance
% changed from the ridge Stage-2 caches to the lasso Global of ctrl_sparse_kernel_cl.m.
%
% Math approved by Aditya 2026-11-22: "Approve" (method block in the brain_paper session chat;
% RESEARCH L-2026-11-22-i). No new formula: f4_rr_denominator_check.m, unchanged, on C.trial column 2.
%   w        (1, 3] s after onset (C.trial.wr, 70 frames); b = [-1, 0) s (1:C.trial.pre); r = -5 %dF/F
%   Gr_c     G_c - mean_b(G_c) per trial, c = OL, CL
%   g_dip    mean over OL trials of mean_w(Gr_OL), the session's laser leak
%   D_c      Gr_c - g_dip
%   trial    msD = mean_w(D^2); msErr = mean_w((A - r)^2) = (mean_w A - r)^2 + var_w(A) = bias2 + fluct
%   session  over trials with finite msErr and msD > 0, OL and CL separately:
%            RR = median(msErr/msD), RR_fluct = median(fluct/msD), offShare = median(bias2)/median(msErr)
%   gate     biasFrac = (mean over CL trials of mean_w A - r)^2 / mean(msErr_CL) <= 1/3
%   tests    over the gated sessions, Wilcoxon signed-rank one-sided OL > CL on RR, on offShare and on
%            log RR_fluct (V, exact p); the two-sided p is printed next to each
% CHECKS   in every session the recomputed CL D and per-trial RR equal C.trial.D and C.trial.rr, and
%          biasFrac and the gate equal C.biasFrac and C.in4H.
% Reads data/ctrl_sparse_kernel_cl_<tag>.mat only. OUT data/f4_rr_olcl_lasso.mat (RRD, OC), and
% data/f4_rr_olcl_lasso_sessions.csv.
root = 'C:\Users\aditya\Documents\projects\brain_paper';
dd   = fullfile(root, 'controller-analysis', 'data');
addpath(fullfile(root, 'utils'));
REF = -5;  BIAS_MAX = 1/3;  m = 2;                       % column 2 of C.trial = lasso
Ls = dir(fullfile(dd, 'ctrl_sparse_kernel_cl_AL_*.mat'));
assert(~isempty(Ls), 'run ctrl_sparse_kernel_cl.m first');

RRD = struct('tag', {}, 'label', {}, 'nOL', {}, 'nCL', {}, 'RR_cl', {}, 'RR_ol', {}, 'RRfluct_cl', {}, ...
    'RRfluct_ol', {}, 'offShare_cl', {}, 'offShare_ol', {}, 'biasFrac', {}, 'keep', {});
for i = 1:numel(Ls)
    S = load(fullfile(dd, Ls(i).name));  C = S.C;  tr = C.trial;
    assert(tr.ref == REF, '%s: reference %g, expected %g', C.session, tr.ref, REF);
    b = 1:tr.pre;  wr = tr.wr;
    Aol = tr.Aol;  Acl = tr.Acl;  Gol = tr.Gol(:,:,m);  Gcl = tr.Gcl(:,:,m);

    % --- disturbance, as f4_rr_denominator_check.m builds it ---
    Gr_ol = Gol - mean(Gol(:,b), 2);
    gdip  = mean(mean(Gr_ol(:,wr), 2));
    Gr_cl = Gcl - mean(Gcl(:,b), 2);
    D_cl  = Gr_cl - gdip;  D_ol = Gr_ol - gdip;
    msD_cl = mean(D_cl(:,wr).^2, 2);  msD_ol = mean(D_ol(:,wr).^2, 2);

    % --- numerator, split into standing offset and fluctuation ---
    [msE_cl, b2_cl, fl_cl] = err_split(Acl(:,wr), REF);
    [msE_ol, b2_ol, fl_ol] = err_split(Aol(:,wr), REF);
    ok_cl = isfinite(msE_cl) & isfinite(msD_cl) & msD_cl > 0;
    ok_ol = isfinite(msE_ol) & isfinite(msD_ol) & msD_ol > 0;
    biasFrac = (mean(mean(Acl(:,wr), 2)) - REF)^2 / mean(msE_cl(ok_cl));

    % --- CHECKS against the saved lasso run ---
    Ds = tr.D(:,:,m);  f = isfinite(Ds) & isfinite(D_cl);
    assert(isequal(isfinite(Ds(:,wr)), isfinite(D_cl(:,wr))) && max(abs(Ds(f) - D_cl(f))) < 1e-9, ...
        '%s: recomputed CL D differs from C.trial.D', C.session);
    rrS = tr.rr(:, m);  rr = msE_cl ./ msD_cl;  g = isfinite(rrS);
    assert(isequal(g, isfinite(rr)) && max(abs(rrS(g) - rr(g)) ./ rrS(g)) < 1e-9, ...
        '%s: recomputed per-trial RR differs from C.trial.rr', C.session);
    assert(abs(biasFrac - C.biasFrac) < 1e-9 && (biasFrac <= BIAS_MAX) == logical(C.in4H), ...
        '%s: biasFrac or gate differs from the saved run', C.session);

    RRD(end+1) = struct('tag', C.session, 'label', paper_session_label(C.session), ...
        'nOL', nnz(ok_ol), 'nCL', nnz(ok_cl), ...
        'RR_cl', median(msE_cl(ok_cl) ./ msD_cl(ok_cl)), 'RR_ol', median(msE_ol(ok_ol) ./ msD_ol(ok_ol)), ...
        'RRfluct_cl', median(fl_cl(ok_cl) ./ msD_cl(ok_cl)), 'RRfluct_ol', median(fl_ol(ok_ol) ./ msD_ol(ok_ol)), ...
        'offShare_cl', median(b2_cl(ok_cl)) / median(msE_cl(ok_cl)), ...
        'offShare_ol', median(b2_ol(ok_ol)) / median(msE_ol(ok_ol)), ...
        'biasFrac', biasFrac, 'keep', biasFrac <= BIAS_MAX); %#ok<SAGROW>
end
fprintf('[olcl-lasso] checks passed in %d sessions (CL D, per-trial RR, biasFrac, gate)\n', numel(RRD));

% ---- per session ----
fprintf('\n%-17s %-9s %4s %4s %6s %6s %7s %7s %6s %6s %6s %4s\n', 'session', 'label', 'nOL', 'nCL', ...
    'RR_OL', 'RR_CL', 'off_OL', 'off_CL', 'fl_OL', 'fl_CL', 'bias', 'in');
for r = RRD
    fprintf('%-17s %-9s %4d %4d %6.2f %6.2f %6.0f%% %6.0f%% %6.2f %6.2f %5.0f%% %4d\n', r.tag, r.label, r.nOL, ...
        r.nCL, r.RR_ol, r.RR_cl, 100*r.offShare_ol, 100*r.offShare_cl, r.RRfluct_ol, r.RRfluct_cl, 100*r.biasFrac, r.keep);
end

% ---- the gated sessions, OL vs CL, paired ----
K = RRD([RRD.keep]);  nK = numel(K);
x = {[K.RR_ol], [K.offShare_ol], log([K.RRfluct_ol])};
y = {[K.RR_cl], [K.offShare_cl], log([K.RRfluct_cl])};
nm = {'RR', 'offShare', 'RR_fluct'};
OC = struct('name', nm, 'med_ol', {median([K.RR_ol]), median([K.offShare_ol]), median([K.RRfluct_ol])}, ...
    'med_cl', {median([K.RR_cl]), median([K.offShare_cl]), median([K.RRfluct_cl])}, ...
    'k', [], 'n', nK, 'V', [], 'p1', [], 'p2', []);
fprintf('\n[olcl-lasso] %d gated sessions (excluded: %s)\n', nK, strjoin({RRD(~[RRD.keep]).label}, ', '));
for j = 1:3
    [p1, ~, st] = signrank(x{j}, y{j}, 'tail', 'right');
    p2 = signrank(x{j}, y{j});
    OC(j).k = sum(y{j} < x{j});  OC(j).V = st.signedrank;  OC(j).p1 = p1;  OC(j).p2 = p2;
    fprintf('  %-9s median OL %.4f vs CL %.4f; CL lower in %d/%d; V = %d, one-sided p = %.3g, two-sided p = %.3g\n', ...
        nm{j}, OC(j).med_ol, OC(j).med_cl, OC(j).k, nK, OC(j).V, p1, p2);
end
save(fullfile(dd, 'f4_rr_olcl_lasso.mat'), 'RRD', 'OC');
writetable(struct2table(RRD), fullfile(dd, 'f4_rr_olcl_lasso_sessions.csv'));
fprintf('[olcl-lasso] saved data/f4_rr_olcl_lasso.mat and data/f4_rr_olcl_lasso_sessions.csv\n');

function [ms, bias2, fluct] = err_split(A, ref)
% f4_rr_denominator_check.m err_split, unchanged: mean((A - ref)^2) = (trial mean - ref)^2 + variance
mA    = mean(A, 2);
bias2 = (mA - ref).^2;
fluct = mean((A - mA).^2, 2);
ms    = bias2 + fluct;
end
