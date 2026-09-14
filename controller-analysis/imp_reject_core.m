function R = imp_reject_core(Aol, Gol, Acl, Gcl, pre, Fs, resp_s, ref)
% IMP_REJECT_CORE  Single source of truth for the disturbance-rejection statistics
% used in BOTH streams:
%   Stream 1 (playground)  : internal_model_principle.m  [IMP-REJECT]
%   Stream 2 (confirmatory): imp_reject_across_sessions.m (combined, all sessions)
%
% ---------------------------------------------------------------------------
% THREE METRICS ARE RETURNED.  SR is the reporting metric (2026-09-11); ER and
% RHO are kept so every earlier number stays reproducible.  NOT interchangeable.
% ---------------------------------------------------------------------------
%
% (0) SR  -- FLUCTUATION-ENERGY RATIO  [PRIMARY, 2026-09-11]
%       SR_k = ||A_k - <A_k>||^2 / ||G_k - <G_k>||^2      (each centred on its
%              OWN within-window mean <.>, per trial, over window w)
%     A proper disturbance-rejection ratio.  The counterfactual G is the no-stim
%     prediction and therefore sits around BASELINE (~0), while A is held at the
%     setpoint ref=-5 -- so ||G-ref||^2 (ER) and ||G||^2 (RHO) both compare terms
%     living in DIFFERENT reference frames, and ER's denominator is dominated by
%     the constant (0-ref)^2 offset, i.e. by SETPOINT TRACKING, not rejection.
%     SR removes the arbitrary DC from BOTH signals (centre each on its own mean)
%     so only the STATE-DRIVEN FLUCTUATION remains in numerator and denominator.
%       SR  = 1  -> the output fluctuates as much as the disturbance (no rejection)
%       SR < 1  -> disturbance fluctuation suppressed;  1-SR = fraction rejected
%     This is the empirical closed-loop sensitivity |S|^2 (fluctuation energy).
%     A = G + L by construction, so SR<1 REQUIRES the controller action L to be
%     anti-correlated with G -- exactly the signature of active rejection; in OL,
%     L does not cancel G and SR ~ 1.  Setpoint tracking (does A reach ref) is a
%     SEPARATE claim, carried by RMSE-to-ref in Fig-4 Rows 1-2, and is NOT mixed in.
%
% (1) ER  -- ENERGY RATIO  [prior primary, Nick 2026-07-28]
%       ER_k = ||A_k - ref||^2 / ||G_k - ref||^2
%     Numerator   = energy of the error that REMAINS with the controller running.
%     Denominator = energy of the error that WOULD have occurred with no control,
%                   i.e. the counterfactual contra-predicted ipsi G against the
%                   same target.
%       ER = 1  -> controller did no work   (holds IDENTICALLY when A == G)
%       ER < 1  -> controller gain          (disturbance energy suppressed)
%       ER > 1  -> controller made it worse
%     This is the squared sensitivity |S|^2 in energy terms.
%
%     *** WHY THE DENOMINATOR CHANGED, AND WHY IT MATTERS ***
%     RHO (below) divides by ||G||, i.e. G referenced to ZERO, not to ref.  Under
%     that normalisation a do-nothing controller does NOT return 1 -- it returns
%     ||G-ref||/||G||, which depends on how far the brain's natural level sits from
%     the target and therefore drifts with the session, the mouse and the state.
%     That is exactly why the published levels look the way they do (OL 1.306,
%     CL 0.879): the *level* of RHO was never interpretable, only the OL-vs-CL
%     contrast was.  ER fixes the reference frame, so the number 1 has a meaning
%     and "the controller does work" becomes readable off a single condition.
%
% (2) RHO -- transmission ratio  [LEGACY, superseded but retained]
%       rho_k = ||A_k - ref|| / ||G_k||        (amplitude, not energy)
%     rho=0 full rejection; LOWER = better.  All numbers logged before 2026-08-10
%     (incl. the 7/7 signrank p=0.0156 batch and the m4 p=1.6e-6 headline) are in
%     these units.  Do NOT mix the two in one sentence.
%
% ---------------------------------------------------------------------------
% WINDOWS.  Three, all returned:
%   w_tr   = 0-1 s : laser-evoked initial deviation (common to OL and CL)
%   w_rej  = 1-3 s : settled -> PURE disturbance rejection (RHO headline)
%   w_stim = 0-3 s : the whole stim window (ER primary -- Nick asked for the
%                    stim window, and ER is well-posed on it because both
%                    numerator and denominator share the reference)
%
% Inputs: Aol/Gol [nOL x nRel], Acl/Gcl [nCL x nRel] (rows = trials, cols = the
% -pre:post sample grid), pre = #baseline samples, Fs, resp_s, ref.
% Output R: per-trial ER and rho vectors, medians, IQRs, pooled values,
% disturbance/error magnitudes, the settled Global dip, n, and rank-sum p-values.
% NO plotting, NO file IO -- pure function so the metric can never drift.
%
% NOTE (2026-08-10): internal_model_principle.m previously carried an INLINE copy
% of the rho lambdas rather than calling this function, so the "single source of
% truth" above was aspirational.  It now calls this.  Keep it that way.

w_tr   = pre+1              : pre+round(1*Fs);
w_rej  = pre+round(1*Fs)+1  : pre+round(resp_s*Fs);
w_stim = pre+1              : pre+round(resp_s*Fs);

% --- ENERGY RATIO (primary). Both terms referenced to ref => A==G gives exactly 1.
erW   = @(A,G,w) sum((A(:,w)-ref).^2,2) ./ sum((G(:,w)-ref).^2,2);            % per trial
erP   = @(A,G,w) sum((A(:,w)-ref).^2,'all') ./ sum((G(:,w)-ref).^2,'all');    % pooled
% --- LEGACY transmission ratio (amplitude, zero-referenced denominator).
rejW  = @(A,G,w) sqrt(mean((A(:,w)-ref).^2,2)) ./ sqrt(mean(G(:,w).^2,2));
poolW = @(A,G,w) sqrt(sum((A(:,w)-ref).^2,'all')/sum(G(:,w).^2,'all'));
% --- SR: fluctuation-energy ratio (PRIMARY). Each signal centred on its OWN
%     within-window mean per trial => the setpoint/baseline DC drops from both,
%     leaving only the state-driven fluctuation. Frame-consistent by construction.
srW   = @(A,G,w) sum((A(:,w)-mean(A(:,w),2)).^2,2) ./ sum((G(:,w)-mean(G(:,w),2)).^2,2);
srP   = @(A,G,w) sum((A(:,w)-mean(A(:,w),2)).^2,'all') ./ sum((G(:,w)-mean(G(:,w),2)).^2,'all');
% --- RR: RESPONSE/DISTURBANCE ENERGY RATIO  [Fig-4 Row-3 SELECTED metric, user 2026-09-11]
%       RR_k = ||A_k - ref||^2 / ||G_k||^2       (response energy over disturbance energy)
%     Numerator   = residual response energy that REMAINS around the setpoint (A vs ref).
%     Denominator = the disturbance's own excursion energy, referenced to ZERO (the
%                   counterfactual "no-laser" level the contra prediction sits at), NOT to
%                   ref -- the user's call: "we are over-estimating the disturbance if we
%                   reference G to ref; disturbance energy = global minus zero, response
%                   energy = response minus reference". Identically = rho^2 (rho=||A-ref||/||G||),
%                   so on the settled window rr_*_rej == rho_*.^2 (single source, no drift).
%       RR = 1  -> response fluctuates as much as the disturbance
%       RR < 1  -> disturbance energy suppressed (active rejection);  RR > 1 -> amplified
rrW   = @(A,G,w) sum((A(:,w)-ref).^2,2) ./ sum(G(:,w).^2,2);
rrP   = @(A,G,w) sum((A(:,w)-ref).^2,'all') ./ sum(G(:,w).^2,'all');

R.ref = ref;  R.w_tr = w_tr;  R.w_rej = w_rej;  R.w_stim = w_stim;  R.resp_s = resp_s;

% ---------------- SR: PRIMARY (0-3 s stim window) + the two sub-windows --------
R.sr_ol      = srW(Aol,Gol,w_stim);  R.sr_cl      = srW(Acl,Gcl,w_stim);   % 0-3 s PRIMARY
R.sr_ol_tr   = srW(Aol,Gol,w_tr);    R.sr_cl_tr   = srW(Acl,Gcl,w_tr);     % 0-1 s
R.sr_ol_rej  = srW(Aol,Gol,w_rej);   R.sr_cl_rej  = srW(Acl,Gcl,w_rej);    % 1-3 s
R.srP_ol     = srP(Aol,Gol,w_stim);  R.srP_cl     = srP(Acl,Gcl,w_stim);
R.sr_med_ol  = median(R.sr_ol);   R.sr_iqr_ol = iqr(R.sr_ol);
R.sr_med_cl  = median(R.sr_cl);   R.sr_iqr_cl = iqr(R.sr_cl);
R.sr_q_ol    = prctile(R.sr_ol,[25 50 75]);
R.sr_q_cl    = prctile(R.sr_cl,[25 50 75]);
% Fraction of disturbance fluctuation rejected (1 - pooled SR), per condition.
R.rej_frac_ol = 1 - R.srP_ol;   R.rej_frac_cl = 1 - R.srP_cl;

% ---------------- ER: primary (0-3 s stim window) + the two sub-windows --------
R.er_ol      = erW(Aol,Gol,w_stim);  R.er_cl      = erW(Acl,Gcl,w_stim);   % 0-3 s PRIMARY
R.er_ol_tr   = erW(Aol,Gol,w_tr);    R.er_cl_tr   = erW(Acl,Gcl,w_tr);     % 0-1 s
R.er_ol_rej  = erW(Aol,Gol,w_rej);   R.er_cl_rej  = erW(Acl,Gcl,w_rej);    % 1-3 s
R.erP_ol     = erP(Aol,Gol,w_stim);  R.erP_cl     = erP(Acl,Gcl,w_stim);

% Nick asked for median +/- IQR reported separately per condition.
R.er_med_ol = median(R.er_ol);   R.er_iqr_ol = iqr(R.er_ol);
R.er_med_cl = median(R.er_cl);   R.er_iqr_cl = iqr(R.er_cl);
R.er_q_ol   = prctile(R.er_ol,[25 50 75]);
R.er_q_cl   = prctile(R.er_cl,[25 50 75]);
% Fraction of trials on which the controller actually did work (ER < 1).
R.er_frac_ol = mean(R.er_ol < 1);   R.er_frac_cl = mean(R.er_cl < 1);

% ---------------- RR: response/disturbance energy ratio (Fig-4 Row-3 selected) --
% Settled 1-3 s is the locked disturbance-rejection window (skips the inhibitory onset
% transient); 0-3 s and 0-1 s kept for reference. rr_*_rej == rho_*.^2 by construction.
R.rr_ol      = rrW(Aol,Gol,w_rej);   R.rr_cl      = rrW(Acl,Gcl,w_rej);    % 1-3 s PRIMARY
R.rr_ol_tr   = rrW(Aol,Gol,w_tr);    R.rr_cl_tr   = rrW(Acl,Gcl,w_tr);     % 0-1 s
R.rr_ol_full = rrW(Aol,Gol,w_stim);  R.rr_cl_full = rrW(Acl,Gcl,w_stim);   % 0-3 s reference
R.rrP_ol     = rrP(Aol,Gol,w_rej);   R.rrP_cl     = rrP(Acl,Gcl,w_rej);
R.rr_med_ol  = median(R.rr_ol);   R.rr_iqr_ol = iqr(R.rr_ol);
R.rr_med_cl  = median(R.rr_cl);   R.rr_iqr_cl = iqr(R.rr_cl);
% PHI = 1 - RR : rejection FRACTION (fraction of disturbance energy removed).
%   phi = 1  -> perfect rejection (response energy -> 0)
%   phi = 0  -> no rejection (response energy == disturbance energy)
%   phi < 0  -> amplification (response bigger than the disturbance)
% Reporting form for the Fig-4 headline (1 = perfect, up = better); same object as RR
% (monotone), so every OL-vs-CL statistic is identical. NOTE: per-trial phi is UNBOUNDED
% below (tiny per-trial ||G||^2 -> huge RR -> very negative phi), so report phi at the
% SESSION/summary level and keep RR (log) for any per-trial view.
R.rjf_ol     = 1 - R.rr_ol;    R.rjf_cl     = 1 - R.rr_cl;         % per-trial (settled)
R.rjf_med_ol = 1 - R.rr_med_ol;  R.rjf_med_cl = 1 - R.rr_med_cl;   % = median-based fraction

% ---------------- RHO: legacy, unchanged ---------------------------------------
R.rho_ol_tr = rejW(Aol,Gol,w_tr);   R.rho_cl_tr = rejW(Acl,Gcl,w_tr);
R.rho_ol    = rejW(Aol,Gol,w_rej);  R.rho_cl    = rejW(Acl,Gcl,w_rej);
R.rhoP_ol   = poolW(Aol,Gol,w_rej); R.rhoP_cl   = poolW(Acl,Gcl,w_rej);
R.med_ol    = median(R.rho_ol);     R.med_cl    = median(R.rho_cl);
R.med_ol_tr = median(R.rho_ol_tr);  R.med_cl_tr = median(R.rho_cl_tr);
R.dmed      = R.med_cl - R.med_ol;                                       % CL-OL median gap

% ---------------- magnitudes (1-3 s, unchanged) --------------------------------
R.Dmag_ol = sqrt(mean(Gol(:,w_rej).^2,2));       R.Dmag_cl = sqrt(mean(Gcl(:,w_rej).^2,2));
R.Emag_ol = sqrt(mean((Aol(:,w_rej)-ref).^2,2)); R.Emag_cl = sqrt(mean((Acl(:,w_rej)-ref).^2,2));
% Disturbance magnitude in the ER reference frame (denominator of ER, 0-3 s).
R.Dref_ol = sqrt(mean((Gol(:,w_stim)-ref).^2,2));
R.Dref_cl = sqrt(mean((Gcl(:,w_stim)-ref).^2,2));

% Network co-suppression: settled Global dip (baseline-subtracted, 1-3 s mean).
% 0 => contra prediction perfectly stim-blind; <0 => contra carries stim effect.
bwin = 1:pre;
Gr_ol = Gol - mean(Gol(:,bwin),2);   Gr_cl = Gcl - mean(Gcl(:,bwin),2);
R.Gdip_ol = mean(mean(Gr_ol(:,w_rej),2));   R.Gdip_cl = mean(mean(Gr_cl(:,w_rej),2));

R.n_ol = size(Aol,1);  R.n_cl = size(Acl,1);
if R.n_ol>0 && R.n_cl>0
    R.p_rho = ranksum(R.rho_ol,R.rho_cl);   R.p_tr = ranksum(R.rho_ol_tr,R.rho_cl_tr);
    R.p_er  = ranksum(R.er_ol, R.er_cl);                       % OL vs CL, per-trial
    R.p_sr  = ranksum(R.sr_ol, R.sr_cl);                       % OL vs CL, per-trial (PRIMARY)
    R.p_rr  = ranksum(R.rr_ol, R.rr_cl);                       % OL vs CL, per-trial (settled RR)
    % Does each condition reject at all?  One-sample test of SR/ER against 1.
    R.p_er_ol1 = signrank(R.er_ol,1);   R.p_er_cl1 = signrank(R.er_cl,1);
    R.p_sr_ol1 = signrank(R.sr_ol,1);   R.p_sr_cl1 = signrank(R.sr_cl,1);
else
    R.p_rho = NaN;  R.p_tr = NaN;  R.p_er = NaN;  R.p_sr = NaN;  R.p_rr = NaN;
    R.p_er_ol1 = NaN;  R.p_er_cl1 = NaN;  R.p_sr_ol1 = NaN;  R.p_sr_cl1 = NaN;
end
end
