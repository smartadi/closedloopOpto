%% ctrl_ols_xsess.m   [CTRL-XOLS]  -- COMBINED STATISTICS for the stim-blind OLS model
%
% Repeat the controller-side contra->ipsi OLS decomposition on EVERY qualifying session and
% report the combined result. This is the model itself -- predictor capacity and the
% Actual = Global + Local split, OL and CL -- not one of its downstream consequences.
%
% WHAT ALREADY EXISTED, AND WHY THIS IS SEPARATE
%   Stage 1  ctrl_ols_spont.m          spontaneous contra->ipsi OLS            (per session, cached)
%   Stage 2  ctrl_ols_ol_stimblind.m   unaffected-px refit + OL decomposition  (per session, cached)
%   Stage 3  ctrl_ols_cl_deploy.m      deploy the same Global on CL trials     (m4 ONLY, never batched)
%   imp_xsess_build.m                  builds the Stage-1/2 caches unattended
%   imp_reject_across_sessions.m       cross-session rejection rho   <- a CONSEQUENCE of the model
%   imp_state_across_sessions.m        cross-session state slopes    <- a CONSEQUENCE of the model
% Every cross-session number in the project so far is one of those consequences; the model that
% produces them has only ever been reported on m4. This script closes that gap, and in doing so
% runs Stage 3 (the CL deploy) on every session for the first time.
%
% NO REFITTING HAPPENS HERE. Sessions are read from their Stage-1/2 caches and rebuilt through
% imp_build_session.m -- the SAME front end the rejection batch uses -- so these numbers cannot
% drift from the ones already published from that path. Sessions without both caches are skipped
% and listed, which makes the printout double as the qualification audit.
%
% THREE THINGS THE COMBINED VIEW IS FOR
%   (1) Predictor capacity across sessions: full-grid ceiling R^2 (Stage 1) vs the DEPLOYED
%       unaffected-pixel R^2 (Stage 2). The gap between them is the price of stim-blindness.
%   (2) The headline split, paired OL vs CL: what fraction of the ipsi response is Local
%       (residual, = the laser / the controller) vs Global (network-shared, predictable from
%       contra that never sees the laser). Session-level inference, n = sessions.
%   (3) THE T1 OBJECTION IN ITS CROSS-SESSION FORM. "Local is just what the model failed to
%       predict" makes a hard prediction: sessions with a WEAKER predictor should report a
%       LARGER Local share. [XOLS-CAPACITY] tests exactly that (Local capture vs R2_te and vs
%       the number of unaffected pixels). A null there is the strongest available answer to the
%       objection; a positive correlation is a finding that must be reported, not buried.
%
% INFERENCE. Session-level throughout (each session = one unit): paired signrank + a bootstrap CI
% over sessions. The pooled per-trial numbers are printed too but are DESCRIPTIVE ONLY -- trials
% within a session are not independent, and one long session would otherwise carry the result.
%
% Run:  load_sessions.m  ->  imp_xsess_build.m (once, builds caches)  ->  ctrl_ols_xsess.m
%
% SECTIONS: [XOLS-CFG] [XOLS-LOOP] [XOLS-STATS] [XOLS-CAPACITY] [XOLS-FIG] [XOLS-SAVE]

%% [XOLS-CFG] --------------------------------------------------------------------
CFG = struct('nSV_load',500, 'Fs',35, 'pre_s',1.0, 'resp_s',3.0);
dip_tran_s = 0.5;      % transient window [0,dip_tran_s]s -- matches Stage 2/3
capt_min_A = 0.20;     % |mean Actual| floor (%dF/F) below which a capture RATIO is meaningless
r2_floor   = ctrl_r2_floor();   % admission gate on the DEPLOYED predictor (0.85)
USE_GATE   = true;     % false = report every session regardless (diagnostic only, never for a claim)
nBoot      = 2000;
rng(7,'twister');
SESS = 1:numel(fields);          % candidates; sessions without Stage-1/2 caches auto-skip

assert(exist('mouse','var') && exist('fields','var'), '[XOLS] run load_sessions.m first.');
PS = paperStyle();  col_ol = PS.col_ol;  col_cl = PS.col_cl;
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga');
if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [XOLS-LOOP] per session: caches -> trials -> OL and CL decomposition -----------
P = struct([]);                                   % per-session results (qualifying only)
skipped = struct('fld',{},'msg',{});
pool_Ldip_ol = []; pool_Ldip_cl = [];             % per-trial Local dips (descriptive pool)
traceOL = {}; traceCL = {};                       % trial-avg traces for the population figure

fprintf('\n[CTRL-XOLS] scanning %d candidate sessions (deployed-R^2 floor %.2f, gate %s)...\n', ...
    numel(SESS), r2_floor, ternstr_gate(USE_GATE,'ON','OFF'));
fprintf('  %-22s %5s %5s %7s %7s %6s %7s %7s %7s\n', ...
    'session','nOL','nCL','R2ceil','R2depl','nUnaf','LocOL%','LocCL%','closed');
for s = SESS
    % Lazy load: each cached `d` carries the full SVD (1-3.5 GB), so holding all 15 OOMs.
    fld_s = fields{s};  freeAfter = false;
    if ~isfield(mouse.(fld_s),'d') || isempty(mouse.(fld_s).d)
        pth_s = fullfile(fileparts(here),'data', sprintf('%sctrl%s%s%d.mat', ...
            mouse.(fld_s).mn, mouse.(fld_s).td(6:7), mouse.(fld_s).td(9:10), mouse.(fld_s).en));
        if ~exist(pth_s,'file')
            skipped(end+1) = struct('fld',fld_s,'msg','no controller cache'); %#ok<SAGROW>
            fprintf('  %-22s  SKIP (no controller cache)\n', fld_s);  continue;
        end
        tmp_s = load(pth_s);
        if ~isfield(tmp_s,'d')
            skipped(end+1) = struct('fld',fld_s,'msg','cache has no d'); %#ok<SAGROW>
            fprintf('  %-22s  SKIP (cache has no d)\n', fld_s);  clear tmp_s;  continue;
        end
        mouse.(fld_s).d = tmp_s.d;  mouse.(fld_s).data = tmp_s.data;  clear tmp_s;
        if ~isfield(mouse.(fld_s).d,'ref'); mouse.(fld_s).d.ref = -5; end
        freeAfter = true;
    end

    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    if freeAfter; mouse.(fld_s) = rmfield(mouse.(fld_s), {'d','data'}); end
    if ~S.ok
        skipped(end+1) = struct('fld',S.sess_tag,'msg',S.msg); %#ok<SAGROW>
        fprintf('  %-22s  SKIP (%s)\n', S.sess_tag, S.msg);  continue;
    end

    % --- windows, identical to Stage 2/3 so the numbers are comparable -----------
    pre = S.pre;  post = S.post;  Fs = S.Fs;
    bwin = 1:pre;                                   % baseline [-1,0]s
    twin = pre+1 : pre+round(dip_tran_s*Fs);        % transient [0,0.5]s
    swin = pre+1 : pre+post;                        % sustained [0,dur]s
    D_ol = local_decomp(S.Aol, S.Gol, bwin, twin, swin, capt_min_A);
    D_cl = local_decomp(S.Acl, S.Gcl, bwin, twin, swin, capt_min_A);

    % --- control-agnostic check: the SAME Global on OL and CL trials -------------
    % Global is built only from pixels that never respond to the laser, so it should read the
    % same ongoing network state in both conditions. A low correlation here means the predictor
    % is picking up something condition-specific and the decomposition is not comparable.
    rG = corr(D_ol.Aa_G(:), D_cl.Aa_G(:));

    % --- absolute units: what the controller actually closed --------------------
    % Global_CL is the counterfactual "ipsi with no controller input", so its distance from ref
    % is the error the controller had to remove, and Actual_CL's distance is what it left.
    act_abs  = mean(D_cl.AaAbs(swin));
    glob_abs = mean(D_cl.GgAbs(swin));
    err_noctrl = abs(glob_abs - S.ref);
    err_ctrl   = abs(act_abs  - S.ref);

    % --- predictor capacity, straight from the caches ---------------------------
    f1 = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', S.sess_tag));
    f2 = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_%s.mat', ctrl_pred_tag(), S.sess_tag));
    q1 = load(f1, 'R2_te','R2_tr','nActive','nG','used_corr','fit_mode');
    q2 = load(f2, 'R2_te','R2_tr','aff_dip_thr','affected','unaff');

    % --- ADMISSION GATE ------------------------------------------------------
    % A predictor below the floor assigns its own error to Local, so it cannot contribute to a
    % combined Local-share statistic. Excluded and listed, never silently pooled.
    r2_depl_s = fld_or(q2,'R2_te',NaN);
    if USE_GATE && ~(r2_depl_s >= r2_floor)
        skipped(end+1) = struct('fld',S.sess_tag, ...
            'msg',sprintf('deployed R^2 %.3f < floor %.2f -- retune the threshold (ctrl_affected_gui.m)', ...
                          r2_depl_s, r2_floor)); %#ok<SAGROW>
        fprintf('  %-22s  SKIP (deployed R^2 %.3f < floor %.2f)\n', S.sess_tag, r2_depl_s, r2_floor);
        continue;
    end

    k = numel(P)+1;
    P(k).sess_tag = S.sess_tag;  P(k).selField = s;  P(k).mn = S.mn;  P(k).td = S.td;
    P(k).nOL = S.nOL;  P(k).nCL = S.nCL;  P(k).ref = S.ref;
    P(k).R2_ceil  = fld_or(q1,'R2_te',NaN);      % full-grid Stage-1 ceiling
    P(k).R2_ceil_tr = fld_or(q1,'R2_tr',NaN);
    P(k).nG       = fld_or(q1,'nG',NaN);
    P(k).nActive  = fld_or(q1,'nActive',NaN);
    P(k).fit_mode = fld_or(q1,'fit_mode','');
    P(k).used_corr = fld_or(q1,'used_corr',NaN);  % hemo-corrected SVD? (covariate, see below)
    P(k).R2_depl  = fld_or(q2,'R2_te',NaN);      % DEPLOYED unaffected-px predictor
    P(k).R2_depl_tr = fld_or(q2,'R2_tr',NaN);
    P(k).aff_thr  = fld_or(q2,'aff_dip_thr',NaN);
    P(k).nUnaff   = nnz(fld_or(q2,'unaff',[]));
    P(k).nAff     = nnz(fld_or(q2,'affected',[]));
    P(k).capt_ol_tran = D_ol.capt_tran;  P(k).capt_ol_sus = D_ol.capt_sus;
    P(k).capt_cl_tran = D_cl.capt_tran;  P(k).capt_cl_sus = D_cl.capt_sus;
    P(k).leak_ol_sus  = D_ol.leak_sus;   P(k).leak_cl_sus = D_cl.leak_sus;
    P(k).A_ol_sus = D_ol.A_sus;  P(k).G_ol_sus = D_ol.G_sus;  P(k).L_ol_sus = D_ol.L_sus;
    P(k).A_cl_sus = D_cl.A_sus;  P(k).G_cl_sus = D_cl.G_sus;  P(k).L_cl_sus = D_cl.L_sus;
    P(k).trough_ol = D_ol.trough;  P(k).trough_cl = D_cl.trough;
    P(k).rG = rG;
    P(k).act_abs = act_abs;  P(k).glob_abs = glob_abs;
    P(k).err_noctrl = err_noctrl;  P(k).err_ctrl = err_ctrl;  P(k).closed = err_noctrl - err_ctrl;
    P(k).Ldip_ol = D_ol.Ldip;  P(k).Ldip_cl = D_cl.Ldip;

    pool_Ldip_ol = [pool_Ldip_ol; D_ol.Ldip];  %#ok<AGROW>
    pool_Ldip_cl = [pool_Ldip_cl; D_cl.Ldip];  %#ok<AGROW>
    traceOL{k} = struct('tt',S.tt,'A',D_ol.Aa,'G',D_ol.Aa_G,'L',D_ol.Lo); %#ok<SAGROW>
    traceCL{k} = struct('tt',S.tt,'A',D_cl.Aa,'G',D_cl.Aa_G,'L',D_cl.Lo); %#ok<SAGROW>

    fprintf('  %-22s %5d %5d %7.3f %7.3f %6d %7.0f %7.0f %+7.2f\n', ...
        S.sess_tag, S.nOL, S.nCL, P(k).R2_ceil, P(k).R2_depl, P(k).nUnaff, ...
        P(k).capt_ol_sus, P(k).capt_cl_sus, P(k).closed);
end
nS = numel(P);
assert(nS >= 1, ['[XOLS] no session had usable Stage-1/2 caches -- run imp_xsess_build.m first ' ...
                 '(and draw one ROI per new mouse).']);

%% [XOLS-STATS] combined inference ------------------------------------------------
R2_ceil = [P.R2_ceil].';  R2_depl = [P.R2_depl].';
capt_ol = [P.capt_ol_sus].';  capt_cl = [P.capt_cl_sus].';
closed  = [P.closed].';  err_nc = [P.err_noctrl].';  err_c = [P.err_ctrl].';
rGs     = [P.rG].';
mice    = unique({P.mn});

% (i) SESSION-LEVEL -- each session one unit ------------------------------------
bothCapt = isfinite(capt_ol) & isfinite(capt_cl);
if nnz(bothCapt) >= 2
    p_capt = signrank(capt_ol(bothCapt), capt_cl(bothCapt));
else
    p_capt = NaN;
end
dCapt = capt_cl - capt_ol;                       % CL minus OL Local share
ci_dCapt  = local_boot_ci(dCapt(bothCapt), nBoot);
ci_capt_ol = local_boot_ci(capt_ol(isfinite(capt_ol)), nBoot);
ci_capt_cl = local_boot_ci(capt_cl(isfinite(capt_cl)), nBoot);
ci_closed  = local_boot_ci(closed(isfinite(closed)), nBoot);
bothErr = isfinite(err_nc) & isfinite(err_c);
if nnz(bothErr) >= 2
    p_closed = signrank(closed(bothErr));                     % H0: median closed = 0
    p_err    = signrank(err_nc(bothErr), err_c(bothErr));     % paired, same sessions both sides
else
    p_closed = NaN;  p_err = NaN;
end
% (ii) POOLED per-trial -- descriptive only ------------------------------------
p_pool_dip = ranksum(pool_Ldip_ol, pool_Ldip_cl);

fprintf('\n[CTRL-XOLS] COMBINED stim-blind OLS model, %d sessions / %d mice (%s)\n', ...
    nS, numel(mice), strjoin(mice,', '));
fprintf('  PREDICTOR CAPACITY (held-out spontaneous R^2)\n');
fprintf('    full-grid ceiling (Stage 1)      : %.3f +/- %.3f   [%.3f .. %.3f]\n', ...
    mean(R2_ceil,'omitnan'), std(R2_ceil,'omitnan'), min(R2_ceil), max(R2_ceil));
fprintf('    DEPLOYED unaffected-px (Stage 2) : %.3f +/- %.3f   [%.3f .. %.3f]\n', ...
    mean(R2_depl,'omitnan'), std(R2_depl,'omitnan'), min(R2_depl), max(R2_depl));
fprintf('    cost of stim-blindness (ceiling - deployed): %.3f +/- %.3f\n', ...
    mean(R2_ceil-R2_depl,'omitnan'), std(R2_ceil-R2_depl,'omitnan'));
fprintf('    unaffected px kept: %d .. %d of %d..%d grid (fixed aff_dip_thr, NOT re-tuned per session)\n', ...
    min([P.nUnaff]), max([P.nUnaff]), min([P.nG]), max([P.nG]));
fprintf('  DECOMPOSITION (sustained [0,%gs], trial-avg, baseline-sub)\n', CFG.resp_s);
fprintf('    OL: Actual %+.2f = Global %+.2f + Local %+.2f  -> Local %.0f%% +/- %.0f  95%%CI [%.0f, %.0f]\n', ...
    mean([P.A_ol_sus]), mean([P.G_ol_sus]), mean([P.L_ol_sus]), ...
    mean(capt_ol,'omitnan'), std(capt_ol,'omitnan'), ci_capt_ol(1), ci_capt_ol(2));
fprintf('    CL: Actual %+.2f = Global %+.2f + Local %+.2f  -> Local %.0f%% +/- %.0f  95%%CI [%.0f, %.0f]\n', ...
    mean([P.A_cl_sus]), mean([P.G_cl_sus]), mean([P.L_cl_sus]), ...
    mean(capt_cl,'omitnan'), std(capt_cl,'omitnan'), ci_capt_cl(1), ci_capt_cl(2));
fprintf('    CL-OL Local share: %+.1f pts  95%%CI [%+.1f, %+.1f]  (signrank p=%.3g, n=%d)\n', ...
    mean(dCapt,'omitnan'), ci_dCapt(1), ci_dCapt(2), p_capt, nnz(bothCapt));
fprintf('    pooled per-trial Local dip (transient): OL %+.2f | CL %+.2f  (rank-sum p=%.3g, DESCRIPTIVE)\n', ...
    median(pool_Ldip_ol), median(pool_Ldip_cl), p_pool_dip);
fprintf('  CONTROL-AGNOSTIC CHECK  corr(Global_OL, Global_CL): %.2f +/- %.2f  [%.2f .. %.2f]\n', ...
    mean(rGs,'omitnan'), std(rGs,'omitnan'), min(rGs), max(rGs));
fprintf('  ABSOLUTE (sustained, ref %.1f%%): no-control error %.2f +/- %.2f  vs  controlled %.2f +/- %.2f\n', ...
    mean([P.ref]), mean(err_nc,'omitnan'), std(err_nc,'omitnan'), mean(err_c,'omitnan'), std(err_c,'omitnan'));
fprintf('    controller closed %.2f%% dF/F  95%%CI [%.2f, %.2f]  (signrank p=%.3g; closed>0 in %d/%d)\n', ...
    mean(closed,'omitnan'), ci_closed(1), ci_closed(2), p_closed, nnz(closed>0), nS);
fprintf('    paired no-control vs controlled error: signrank p=%.3g\n', p_err);

% Hemodynamic-correction covariate: the 5 sessions with no corr/ folder went through the
% detrend-only branch of cp_loadUVt. Different preprocessing must not be silently pooled.
uc = [P.used_corr];
if numel(unique(uc(isfinite(uc)))) > 1
    gA = uc==1;  gB = uc==0;
    fprintf('  HEMO-CORRECTION SPLIT (covariate): corrected n=%d Local %.0f%% / R2depl %.3f | uncorrected n=%d Local %.0f%% / R2depl %.3f\n', ...
        nnz(gA), mean(capt_ol(gA),'omitnan'), mean(R2_depl(gA),'omitnan'), ...
        nnz(gB), mean(capt_ol(gB),'omitnan'), mean(R2_depl(gB),'omitnan'));
    if nnz(gA)>=2 && nnz(gB)>=2
        fprintf('    rank-sum on Local capture: p=%.3g (n small -- descriptive)\n', ...
            ranksum(capt_ol(gA), capt_ol(gB)));
    end
else
    fprintf('  HEMO-CORRECTION SPLIT: all %d sessions on the same branch (used_corr=%d) -- no covariate.\n', ...
        nS, uc(1));
end
if numel(mice) < 2
    fprintf('  ** n=%d sessions but n=1 MOUSE (%s) -- this is NOT an animal-level result. **\n', nS, mice{1});
end

%% [XOLS-CAPACITY] is Local just what the predictor missed? (the T1 objection) ----
% If Local were a modeling residual rather than the laser's own effect, a weaker predictor would
% leave more behind: Local capture would rise as R2_te falls (negative rho), and would fall with
% the number of unaffected pixels available. Both are tested; with n = nS sessions this is
% low-powered, so the honest reading of a null is "no evidence for", not "evidence against".
cap_tests = struct('name',{},'rho',{},'p',{});
if nS >= 4
    [rr,pp] = corr(R2_depl, capt_ol, 'type','Spearman','rows','complete');
    cap_tests(end+1) = struct('name','Local_OL vs deployed R2', 'rho',rr, 'p',pp);
    [rr,pp] = corr([P.nUnaff].', capt_ol, 'type','Spearman','rows','complete');
    cap_tests(end+1) = struct('name','Local_OL vs #unaffected px', 'rho',rr, 'p',pp);
    [rr,pp] = corr(R2_depl, capt_cl, 'type','Spearman','rows','complete');
    cap_tests(end+1) = struct('name','Local_CL vs deployed R2', 'rho',rr, 'p',pp);
    [rr,pp] = corr(R2_depl, closed, 'type','Spearman','rows','complete');
    cap_tests(end+1) = struct('name','closed-error vs deployed R2', 'rho',rr, 'p',pp);
    fprintf('\n[XOLS-CAPACITY] does the Local share track predictor capacity? (Spearman, n=%d sessions)\n', nS);
    for i = 1:numel(cap_tests)
        fprintf('    %-30s rho %+.3f  p %.3g\n', cap_tests(i).name, cap_tests(i).rho, cap_tests(i).p);
    end
    fprintf('    (a NEGATIVE rho on the first two rows is what "Local is a modeling residual" predicts)\n');
else
    fprintf('\n[XOLS-CAPACITY] skipped -- needs >=4 sessions (have %d).\n', nS);
end

%% [XOLS-FIG] --------------------------------------------------------------------
figX = figure('Color','w','Position',[30 40 1560 820]);
tl = tiledlayout(figX,2,3,'TileSpacing','compact','Padding','compact');
cG = [0.85 0.4 0.1];  cL = [0.1 0.5 0.85];

% (a) predictor capacity: ceiling vs deployed, per session
ax = nexttile(tl,1); hold(ax,'on'); box(ax,'on');
bar(ax, 1:nS, [R2_ceil R2_depl], 0.8);
set(ax,'XTick',1:nS,'XTickLabel',{P.sess_tag},'XTickLabelRotation',60, ...
    'TickLabelInterpreter','none','FontSize',7);
ylabel(ax,'held-out spontaneous R^2'); ylim(ax,[0 1]);
legend(ax,{'full grid (ceiling)','unaffected px (deployed)'},'Box','off','Location','south','FontSize',7);
title(ax,sprintf('(a) predictor capacity  (deployed %.2f\\pm%.2f)', ...
    mean(R2_depl,'omitnan'), std(R2_depl,'omitnan')),'FontWeight','normal');

% (b) paired Local share, OL vs CL
ax = nexttile(tl,2); hold(ax,'on'); box(ax,'on');
for k = 1:nS
    plot(ax,[1 2],[capt_ol(k) capt_cl(k)],'-','Color',[.7 .7 .7],'LineWidth',0.8);
end
scatter(ax,ones(nS,1),capt_ol,34,col_ol,'filled','MarkerFaceAlpha',.8);
scatter(ax,2*ones(nS,1),capt_cl,34,col_cl,'filled','MarkerFaceAlpha',.8);
plot(ax,[1 2],[mean(capt_ol,'omitnan') mean(capt_cl,'omitnan')],'-k','LineWidth',2);
yline(ax,100,':','Color',[.6 .6 .6]);  yline(ax,50,':','Color',[.85 .85 .85]);
set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(ax,[0.6 2.4]);
ylabel(ax,'Local share of Actual (%, sustained)');
title(ax,sprintf('(b) Local vs network-shared  (signrank p=%.2g)',p_capt),'FontWeight','normal');

% (c) population trial-average decomposition (session-mean traces +/- SEM across sessions)
ax = nexttile(tl,3); hold(ax,'on'); box(ax,'on');
[ttC, Mol] = local_stack(traceOL);  [~, Mcl] = local_stack(traceCL);
local_band(ax, ttC, Mol.A, [0 0 0], '-');   local_band(ax, ttC, Mol.G, cG, '-');
local_band(ax, ttC, Mcl.A, [0 0 0], '--');  local_band(ax, ttC, Mcl.G, cG, '--');
xline(ax,0,'k:'); yline(ax,0,'k:');
xlabel(ax,'time from stim (s)'); ylabel(ax,'\DeltaF/F (%) (baseline-sub)');
legend(ax,{'Actual OL','Global OL','Actual CL','Global CL'},'Box','off','Location','southwest','FontSize',7);
title(ax,sprintf('(c) population mean \\pm SEM (n=%d sessions)',nS),'FontWeight','normal');

% (d) absolute units: the error the controller closed
ax = nexttile(tl,4); hold(ax,'on'); box(ax,'on');
for k = 1:nS
    plot(ax,[1 2],[err_nc(k) err_c(k)],'-','Color',[.7 .7 .7],'LineWidth',0.8);
end
scatter(ax,ones(nS,1),err_nc,34,cG,'filled','MarkerFaceAlpha',.8);
scatter(ax,2*ones(nS,1),err_c,34,col_cl,'filled','MarkerFaceAlpha',.8);
plot(ax,[1 2],[mean(err_nc,'omitnan') mean(err_c,'omitnan')],'-k','LineWidth',2);
yline(ax,0,':','Color',[.5 .5 .5]);
set(ax,'XTick',[1 2],'XTickLabel',{'no control','controlled'}); xlim(ax,[0.6 2.4]);
ylabel(ax,sprintf('|level - ref| (%%\\DeltaF/F), sustained'));
title(ax,sprintf('(d) closed %.2f%% [%.2f, %.2f], p=%.2g',mean(closed,'omitnan'),ci_closed(1),ci_closed(2),p_closed), ...
    'FontWeight','normal');

% (e) the T1 test: Local share vs predictor capacity
ax = nexttile(tl,5); hold(ax,'on'); box(ax,'on');
scatter(ax,R2_depl,capt_ol,44,col_ol,'filled','MarkerFaceAlpha',.85);
scatter(ax,R2_depl,capt_cl,44,col_cl,'filled','MarkerFaceAlpha',.85);
for k = 1:nS
    text(ax,R2_depl(k),capt_ol(k),sprintf('  %s',P(k).sess_tag(end-6:end)), ...
        'FontSize',6,'Interpreter','none','Color',[.4 .4 .4]);
end
xlabel(ax,'deployed held-out R^2'); ylabel(ax,'Local share (%, sustained)');
if ~isempty(cap_tests)
    title(ax,sprintf('(e) T1 check: OL \\rho=%+.2f (p=%.2g)',cap_tests(1).rho,cap_tests(1).p),'FontWeight','normal');
else
    title(ax,'(e) T1 check (too few sessions)','FontWeight','normal');
end
legend(ax,{'OL','CL'},'Box','off','Location','best','FontSize',7);

% (f) pooled per-trial Local dip distributions (descriptive)
ax = nexttile(tl,6); hold(ax,'on'); box(ax,'on');
scatter(ax,1+0.10*randn(numel(pool_Ldip_ol),1),pool_Ldip_ol,9,col_ol,'filled','MarkerFaceAlpha',.22);
scatter(ax,2+0.10*randn(numel(pool_Ldip_cl),1),pool_Ldip_cl,9,col_cl,'filled','MarkerFaceAlpha',.22);
plot(ax,[0.7 1.3],median(pool_Ldip_ol)*[1 1],'-k','LineWidth',2);
plot(ax,[1.7 2.3],median(pool_Ldip_cl)*[1 1],'-k','LineWidth',2);
yline(ax,0,':','Color',[.5 .5 .5]);
set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(ax,[0.5 2.5]);
ylabel(ax,'per-trial Local dip (%\DeltaF/F, transient)');
title(ax,sprintf('(f) pooled trials (%d OL / %d CL, DESCRIPTIVE)', ...
    numel(pool_Ldip_ol), numel(pool_Ldip_cl)),'FontWeight','normal');

sgtitle(figX, sprintf(['[CTRL-XOLS] stim-blind OLS model across %d sessions / %d mice   ' ...
    'deployed R^2 %.2f   Local OL %.0f%% vs CL %.0f%% (p=%.2g)   closed %.2f%% (p=%.2g)'], ...
    nS, numel(mice), mean(R2_depl,'omitnan'), mean(capt_ol,'omitnan'), mean(capt_cl,'omitnan'), ...
    p_capt, mean(closed,'omitnan'), p_closed));
xpng = fullfile(fig_dir,'ctrl_ols_xsess.png');
exportgraphics(figX, xpng, 'Resolution',300);
fprintf('\n[CTRL-XOLS] figure -> %s\n', xpng);

%% [XOLS-SAVE] -------------------------------------------------------------------
XO = struct('CFG',CFG,'dip_tran_s',dip_tran_s,'capt_min_A',capt_min_A,'nBoot',nBoot, ...
    'r2_floor',r2_floor,'USE_GATE',USE_GATE, ...
    'nS',nS,'mice',{mice},'P',P,'skipped',skipped, ...
    'R2_ceil',R2_ceil,'R2_depl',R2_depl,'capt_ol',capt_ol,'capt_cl',capt_cl, ...
    'dCapt',dCapt,'ci_dCapt',ci_dCapt,'p_capt',p_capt, ...
    'closed',closed,'ci_closed',ci_closed,'p_closed',p_closed,'p_err',p_err, ...
    'err_noctrl',err_nc,'err_ctrl',err_c,'rG',rGs, ...
    'pool_Ldip_ol',pool_Ldip_ol,'pool_Ldip_cl',pool_Ldip_cl,'p_pool_dip',p_pool_dip, ...
    'cap_tests',cap_tests);
save(fullfile(dataDir,'ctrl_ols_xsess.mat'),'XO');
fprintf('[CTRL-XOLS] struct -> data/ctrl_ols_xsess.mat  (%d qualifying, %d skipped)\n', nS, numel(skipped));
if ~isempty(skipped)
    fprintf('  skipped:\n');
    for i = 1:numel(skipped)
        fprintf('    %-22s %s\n', skipped(i).fld, skipped(i).msg);
    end
    fprintf('  (missing Stage-1/2 caches are built by imp_xsess_build.m; a new MOUSE needs one drawn ROI first)\n');
end

%% ---- local functions -----------------------------------------------------------
function D = local_decomp(A, G, bwin, twin, swin, capt_min)
% Actual = Global + Local on one session's trials. Baseline-subtraction and the two windows are
% IDENTICAL to ctrl_ols_ol_stimblind.m / ctrl_ols_cl_deploy.m, so per-session numbers from this
% batch and from the interactive stages must agree exactly.
A_b = A - mean(A(:,bwin),2);
G_b = G - mean(G(:,bwin),2);
L_b = A_b - G_b;
D.Aa   = mean(A_b,1);   D.Aa_G = mean(G_b,1);   D.Lo = mean(L_b,1);
D.AaAbs = mean(A,1);    D.GgAbs = mean(G,1);
% Capture is a RATIO, so it is only meaningful where the denominator (the Actual response) is
% actually a response. Near zero it explodes; report NaN rather than a large meaningless number.
capt = @(w) local_ratio(mean(D.Lo(w)), mean(D.Aa(w)), capt_min);
leak = @(w) local_ratio(mean(D.Aa_G(w)), mean(D.Aa(w)), capt_min);
D.capt_tran = capt(twin);  D.capt_sus = capt(swin);
D.leak_tran = leak(twin);  D.leak_sus = leak(swin);
D.A_sus = mean(D.Aa(swin));  D.G_sus = mean(D.Aa_G(swin));  D.L_sus = mean(D.Lo(swin));
D.A_tran = mean(D.Aa(twin)); D.G_tran = mean(D.Aa_G(twin)); D.L_tran = mean(D.Lo(twin));
[D.trough, D.iTrough] = min(D.Aa);
D.Ldip = mean(L_b(:,twin),2);          % per-trial Local dip (transient)
end

function r = local_ratio(num, den, floor_abs)
if abs(den) < floor_abs, r = NaN; else, r = 100*num/den; end
end

function ci = local_boot_ci(x, nBoot)
% Percentile bootstrap over SESSIONS (not trials) -- the unit of independence here.
x = x(isfinite(x));
if numel(x) < 2, ci = [NaN NaN]; return; end
b = zeros(nBoot,1);
for i = 1:nBoot, b(i) = mean(x(randi(numel(x),numel(x),1))); end
ci = prctile(b,[2.5 97.5]);
end

function [tt, M] = local_stack(tr)
% Stack per-session trial-average traces onto a common time base. Sessions can differ in trial
% duration, so crop to the shortest; all share pre_s=1 and Fs, so onset is already aligned.
n = numel(tr);
L = min(cellfun(@(s) numel(s.A), tr));
tt = tr{1}.tt(1:L);
Am = zeros(n,L); Gm = zeros(n,L); Lm = zeros(n,L);
for k = 1:n
    Am(k,:) = tr{k}.A(1:L);  Gm(k,:) = tr{k}.G(1:L);  Lm(k,:) = tr{k}.L(1:L);
end
M = struct('A',Am,'G',Gm,'L',Lm);
end

function local_band(ax, tt, M, col, ls)
% mean +/- SEM ACROSS SESSIONS
m = mean(M,1);  se = std(M,0,1)/sqrt(size(M,1));
fill(ax,[tt fliplr(tt)],[m+se fliplr(m-se)],col,'FaceAlpha',0.12,'EdgeColor','none', ...
    'HandleVisibility','off');
plot(ax,tt,m,'LineStyle',ls,'Color',col,'LineWidth',1.6);
end

function v = fld_or(q, name, dflt)
if isfield(q,name) && ~isempty(q.(name)), v = q.(name); else, v = dflt; end
end

function s = ternstr_gate(c, a, b)
if c, s = a; else, s = b; end
end
