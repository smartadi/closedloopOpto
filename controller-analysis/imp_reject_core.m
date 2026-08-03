function R = imp_reject_core(Aol, Gol, Acl, Gcl, pre, Fs, resp_s, ref)
% IMP_REJECT_CORE  Single source of truth for the headline disturbance-rejection
% statistic used in BOTH streams:
%   Stream 1 (playground)  : internal_model_principle.m  [IMP-REJECT]
%   Stream 2 (confirmatory): imp_reject_across_sessions.m (combined, all sessions)
%
% Disturbance D_k(t) = G_k(t) (stim-blind contra prediction, zero-referenced);
% subdued error E_k(t) = A_k(t) - ref. Per-trial transmission ratio on window w:
%   rho_k = ||E_k||/||D_k|| = rms(A-ref)/rms(G).
%   rho=0 full rejection (E at ref); rho=1 disturbance passes; >1 amplified.
%   LOWER = better rejection (raw ratio, not 1-ratio).
% Two physically distinct sub-windows:
%   w_tr  = 0-1 s : laser-evoked initial deviation (common OL/CL)
%   w_rej = 1-3 s : settled -> PURE disturbance rejection (headline)
%
% Inputs: Aol/Gol [nOL x nRel], Acl/Gcl [nCL x nRel] (rows = trials, cols = the
% -pre:post sample grid), pre = #baseline samples, Fs, resp_s, ref.
% Output R: per-trial rho vectors, medians, pooled rho, disturbance/error RMS,
% the settled Global dip (network co-suppression), n, and rank-sum p-values.
% NO plotting, NO file IO -- pure function so the metric can never drift.

w_tr  = pre+1              : pre+round(1*Fs);
w_rej = pre+round(1*Fs)+1  : pre+round(resp_s*Fs);
rejW  = @(A,G,w) sqrt(mean((A(:,w)-ref).^2,2)) ./ sqrt(mean(G(:,w).^2,2));   % per-trial ||E||/||D||
poolW = @(A,G,w) sqrt(sum((A(:,w)-ref).^2,'all')/sum(G(:,w).^2,'all'));      % pooled ||E||/||D||

R.ref = ref;  R.w_tr = w_tr;  R.w_rej = w_rej;  R.resp_s = resp_s;
R.rho_ol_tr = rejW(Aol,Gol,w_tr);   R.rho_cl_tr = rejW(Acl,Gcl,w_tr);      % 0-1 s transient
R.rho_ol    = rejW(Aol,Gol,w_rej);  R.rho_cl    = rejW(Acl,Gcl,w_rej);     % 1-3 s headline
R.Dmag_ol = sqrt(mean(Gol(:,w_rej).^2,2));       R.Dmag_cl = sqrt(mean(Gcl(:,w_rej).^2,2));
R.Emag_ol = sqrt(mean((Aol(:,w_rej)-ref).^2,2)); R.Emag_cl = sqrt(mean((Acl(:,w_rej)-ref).^2,2));
R.rhoP_ol = poolW(Aol,Gol,w_rej);   R.rhoP_cl = poolW(Acl,Gcl,w_rej);

% Network co-suppression: settled Global dip (baseline-subtracted, 1-3 s mean).
% 0 => contra prediction perfectly stim-blind; <0 => contra carries stim effect.
bwin = 1:pre;
Gr_ol = Gol - mean(Gol(:,bwin),2);   Gr_cl = Gcl - mean(Gcl(:,bwin),2);
R.Gdip_ol = mean(mean(Gr_ol(:,w_rej),2));   R.Gdip_cl = mean(mean(Gr_cl(:,w_rej),2));

R.n_ol = size(Aol,1);  R.n_cl = size(Acl,1);
R.med_ol = median(R.rho_ol);  R.med_cl = median(R.rho_cl);
R.med_ol_tr = median(R.rho_ol_tr);  R.med_cl_tr = median(R.rho_cl_tr);
R.dmed = R.med_cl - R.med_ol;                                            % CL-OL median gap
if R.n_ol>0 && R.n_cl>0
    R.p_rho = ranksum(R.rho_ol,R.rho_cl);   R.p_tr = ranksum(R.rho_ol_tr,R.rho_cl_tr);
else
    R.p_rho = NaN;  R.p_tr = NaN;
end
end
