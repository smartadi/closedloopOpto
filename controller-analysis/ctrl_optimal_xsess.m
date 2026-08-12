%% ctrl_optimal_xsess.m   [OPT-XSESS]  -- STAGE 4b ACROSS SESSIONS: how much better could a
%                                        controller do if it were handed the disturbance?
%
% The argument for MPC, made quantitatively and on every qualifying session instead of on m4.
% For each session: take the identified laser->ipsi plant, take the disturbance the PI
% controller was actually fighting, and solve for the command a controller WOULD have played
% if it had known that disturbance -- once clairvoyantly (the ceiling) and once causally with
% a receding horizon (what is actually implementable). The three-way gap is the whole point:
%
%     RMSE(PI)  -  RMSE(causal MPC)     what a better controller design recovers
%     RMSE(causal) - RMSE(non-causal)   the price of causality (delay + no preview)
%     RMSE(non-causal)                  IRREDUCIBLE -- one-sided actuation and plant limits.
%                                       No controller of any design beats this.
%
% WHERE THE DISTURBANCE COMES FROM -- this is the modelling choice, and both are computed
%   'residual'  d = y_PI - H*u_PI, measured from the PI trials themselves. Absorbs plant
%               mismatch, so the "optimal" controller is partly correcting the plant model and
%               its advantage is FLATTERED. This is what the m4 workbench has always used.
%   'global'    d = the contra-predicted Global (Stage-3 GgAbs), i.e. the counterfactual ipsi
%               trace with no laser. This is the version that is a real PROPOSAL rather than a
%               bound: Global is derived from the OTHER hemisphere, which never sees the laser,
%               so it is available in real time and a preview controller could actually use it.
%               It carries no plant mismatch, so its numbers are the honest ones -- and if the
%               'global' gap is close to the 'residual' gap, the ceiling is not an artefact of
%               letting the optimizer fix the plant model.
% Reporting both is the point. A gap that exists ONLY under 'residual' is a modelling result,
% not a control result.
%
% ONE-SIDED ACTUATION. The laser only inhibits (0 <= u <= u_max), so wherever the disturbance
% already sits past the reference no command helps and the error is irreducible by construction.
% frac_u0 -- the fraction of the horizon where the clairvoyant optimum plays u = 0 -- is
% reported per session and is the honest denominator for every "could do better" claim.
%
% SCOPE / CAVEAT. Everything here is TRIAL-AVERAGED (y_PI, u_PI and Global are trial averages
% from the Stage-3 cache), so this bounds the achievable improvement on the AVERAGE trial, not
% trial by trial. Per-trial is a strictly bigger claim and is not made here.
%
% BUILDS WHAT IT NEEDS. Stage 3 (ctrl_ols_cl_deploy) and Stage 4a (ctrl_lti_sysid) have only
% ever run on m4; this script runs them per session via the CTRL_SELFIELD override, then calls
% the SHARED solver utils/ctrl_opt_solve.m -- the same kernel ctrl_optimal_control.m uses, so a
% population number can never come from a different QP than the single-session number.
%
% QUALIFICATION. Same gate as every other cross-session controller script: the deployed Stage-2
% predictor must clear ctrl_r2_floor(). Under 'global' this is not optional -- the disturbance
% IS the predictor's output, so an under-floor session would be optimizing against noise.
%
% Run:  load_sessions.m -> ctrl_residual_build.m -> ctrl_optimal_xsess.m
%
% PANEL SET (user, 2026-08-12): ONE session shown as the demo, then combined-session stats.
%   f4_mpc_traces_<src>      DEMO: disturbance vs PI vs MPC vs ceiling, one session
%   f4_mpc_command_<src>     DEMO: the commands themselves -- where the ceiling holds u=0,
%                            nothing can be done, and that is visible rather than asserted
%   f4_mpc_rmse_<src>        COMBINED: per-session PI -> MPC -> ceiling, paired
%   f4_mpc_budget_<src>      COMBINED: MPC gain | price of causality | irreducible, per session
%   f4_mpc_saturation_<src>  COMBINED: ceiling gain vs how much of the horizon is u=0
% PNG-first: OX.FMT = {'png'} for review, {'pdf','png'} once approved.
%
% SECTIONS: [OPTX-CFG] [OPTX-LOOP] [OPTX-STATS] [OPTX-FIG] [OPTX-SAVE]

%% [OPTX-CFG] -------------------------------------------------------------------
clear OX; OX = struct();
OX.sess      = [];             % [] = every session with a Stage-2 cache; or explicit indices
OX.dsrc      = {'residual','global'};   % disturbance sources to compute (both = the honest pair)
OX.uMaxMode  = 'CL';           % 'CL' = the PI's own usage ceiling (same-budget, fair) | 'HW'
OX.lam       = 1e-4;           % input regularization (conditioning only)
OX.Hp        = 35;             % causal MPC horizon (samples, 1 s)
OX.force_s3  = false;          % rebuild Stage-3 (CL deploy) even if cached
OX.force_s4a = false;          % rebuild Stage-4a (LTI plant) even if cached
OX.USE_GATE  = true;           % ctrl_r2_floor admission gate -- see header
OX.EXPORT    = true;
% REVIEW WORKFLOW (user, 2026-08-12): PNG first, approve, THEN vector PDFs. Flip to
% {'pdf','png'} once the panels are signed off -- same code path, so what was approved is
% exactly what gets exported.
OX.FMT       = {'png'};        % {'png'} = review | {'pdf','png'} = final
OX.exemplar  = 'AL_0033_0226_e2';   % the SINGLE SESSION shown as the demo (output + command
                                    % traces). Falls back to the first qualifying session.

Fs = 35;  ref_level = -5;
r2_floor = ctrl_r2_floor();
PS = paperStyle(); setPaperDefaults();
W = 6; H_cm = 4;

assert(exist('mouse','var') && exist('fields','var'), '[OPTX] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
outDir  = fullfile(here,'..','paper','images','figure4');
if OX.EXPORT && ~exist(outDir,'dir'); mkdir(outDir); end
if isempty(OX.sess); OX.sess = 1:numel(fields); end

%% [OPTX-LOOP] ------------------------------------------------------------------
R = struct([]);  skipped = struct('fld',{},'msg',{});
EX = struct();   % exemplar traces for the story panel
gate_txt = {'OFF','ON'};   % indexed by logical+1 (script local functions must sit at EOF)
fprintf('\n[OPTX] %d candidate sessions | gate %s (floor %.2f) | u_max=%s | sources: %s\n', ...
    numel(OX.sess), gate_txt{OX.USE_GATE+1}, r2_floor, OX.uMaxMode, strjoin(OX.dsrc,'+'));

for ox_s = OX.sess
    ox_f  = fields{ox_s};
    ox_mn = mouse.(ox_f).mn;  ox_td = mouse.(ox_f).td;  ox_en = mouse.(ox_f).en;
    ox_tag = sprintf('%s_%s%s_e%d', ox_mn, ox_td(6:7), ox_td(9:10), ox_en);

    f2 = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', ox_tag));
    if ~exist(f2,'file')
        skipped(end+1) = struct('fld',ox_tag,'msg','no Stage-2 cache'); %#ok<SAGROW>
        continue
    end
    q2 = load(f2,'R2_te');
    if OX.USE_GATE && ~(isfield(q2,'R2_te') && q2.R2_te >= r2_floor)
        skipped(end+1) = struct('fld',ox_tag, ...
            'msg',sprintf('deployed R^2 %.3f < floor %.2f', q2.R2_te, r2_floor)); %#ok<SAGROW>
        fprintf('  %-22s SKIP (deployed R^2 %.3f < floor %.2f)\n', ox_tag, q2.R2_te, r2_floor);
        continue
    end

    % --- lazy session load (each cached d is 1-3.5 GB; holding them all OOMs) ---
    ox_free = false;
    if ~isfield(mouse.(ox_f),'d') || isempty(mouse.(ox_f).d)
        ox_p = fullfile(fileparts(here),'data', ...
            sprintf('%sctrl%s%s%d.mat', ox_mn, ox_td(6:7), ox_td(9:10), ox_en));
        if ~exist(ox_p,'file')
            skipped(end+1) = struct('fld',ox_tag,'msg','no controller cache'); %#ok<SAGROW>
            continue
        end
        ox_tmp = load(ox_p);
        if ~isfield(ox_tmp,'d')
            skipped(end+1) = struct('fld',ox_tag,'msg','cache has no d'); %#ok<SAGROW>
            clear ox_tmp; continue
        end
        mouse.(ox_f).d = ox_tmp.d;  mouse.(ox_f).data = ox_tmp.data;  clear ox_tmp;
        if ~isfield(mouse.(ox_f).d,'ref'); mouse.(ox_f).d.ref = -5; end
        ox_free = true;
    end

    % --- Stage 3 + Stage 4a, built here if missing (CTRL_SELFIELD override) ----
    ox_err = '';
    try
        f3  = fullfile(dataDir, sprintf('ctrl_ols_cl_deploy_%s.mat', ox_tag));
        f4a = fullfile(dataDir, sprintf('ctrl_lti_%s.mat',          ox_tag));
        CTRL_SELFIELD = ox_s;                                     % read by both stage scripts
        if OX.force_s3  || ~exist(f3,'file')
            fprintf('  %-22s building Stage 3 (CL deploy)...\n', ox_tag);
            run(fullfile(here,'ctrl_ols_cl_deploy.m'));
        end
        if OX.force_s4a || ~exist(f4a,'file')
            fprintf('  %-22s building Stage 4a (LTI plant)...\n', ox_tag);
            run(fullfile(here,'ctrl_lti_sysid.m'));
        end
        CTRL_SELFIELD = ox_s;   % the stage scripts share the base workspace -- restore it
    catch ME
        ox_err = sprintf('stage build failed: %s', ME.message);
    end
    if ox_free; mouse.(ox_f) = rmfield(mouse.(ox_f), {'d','data'}); end
    if ~isempty(ox_err)
        skipped(end+1) = struct('fld',ox_tag,'msg',ox_err); %#ok<SAGROW>
        fprintf('  %-22s SKIP (%s)\n', ox_tag, ox_err);  continue
    end

    % --- assemble the horizon -------------------------------------------------
    S3 = load(f3);  LT = load(f4a);
    pre = S3.pre;  dur = S3.dur;  N = round(dur*Fs);
    switch upper(OX.uMaxMode)
        case 'CL', u_max = LT.uMaxCL;
        case 'HW', u_max = LT.uMaxHW;
        otherwise, error('[OPTX] bad uMaxMode ''%s''.', OX.uMaxMode);
    end
    y_PI = S3.AaAbs(pre+1:pre+N);  y_PI = y_PI(:);       % PI-controlled ipsi, absolute trial avg
    u_PI = LT.u_CL(pre+1:pre+N);   u_PI = u_PI(:);       % the PI's own laser command
    rvec = ref_level*ones(N,1);
    [~, Hm] = ctrl_plant_markov(LT, N);                  % shared plant build

    D_ALL = struct('residual', y_PI - Hm*u_PI, ...
                   'global',   reshape(S3.GgAbs(pre+1:pre+N),[],1));

    k = numel(R)+1;
    R(k).sess_tag = ox_tag;  R(k).mn = ox_mn;  R(k).selField = ox_s;
    R(k).N = N;  R(k).dur = dur;  R(k).u_max = u_max;  R(k).R2_te = q2.R2_te;
    R(k).rmse_PI = local_rmse(y_PI, rvec, [], Fs);
    R(k).rmse_s_PI = local_rmse(y_PI, rvec, 1, Fs);

    for j = 1:numel(OX.dsrc)
        src = OX.dsrc{j};
        dv  = D_ALL.(src);
        O = ctrl_opt_solve(LT, dv, rvec, u_max, ...
                struct('lam',OX.lam,'Hp',OX.Hp,'u_init',u_PI,'causal',true));
        R(k).(src) = struct( ...
            'rmse_nc',   local_rmse(O.y_nc, rvec, [], Fs), ...
            'rmse_ca',   local_rmse(O.y_ca, rvec, [], Fs), ...
            'rmse_s_nc', local_rmse(O.y_nc, rvec, 1, Fs), ...
            'rmse_s_ca', local_rmse(O.y_ca, rvec, 1, Fs), ...
            'frac_u0',   O.frac_u0, ...
            'exitflag',  O.exitflag_nc, ...
            'd_mean',    mean(dv), 'd_min', min(dv), 'd_max', max(dv));
        if strcmp(ox_tag, OX.exemplar) || (~isfield(EX,'sess_tag') && k==1)
            EX.(src) = struct('y_nc',O.y_nc,'y_ca',O.y_ca,'u_nc',O.u_nc,'u_ca',O.u_ca,'d',dv);
        end
    end
    if strcmp(ox_tag, OX.exemplar) || (~isfield(EX,'sess_tag') && k==1)
        EX.sess_tag = ox_tag;  EX.y_PI = y_PI;  EX.u_PI = u_PI;
        EX.tt = (1:N).'/Fs;  EX.r = rvec;  EX.u_max = u_max;
    end

    fprintf('  %-22s N=%3d u_max=%.3f | PI %.3f', ox_tag, N, u_max, R(k).rmse_s_PI);
    for j = 1:numel(OX.dsrc)
        src = OX.dsrc{j};
        fprintf(' | %s: ca %.3f nc %.3f (u=0 %.0f%%)', src(1:3), ...
            R(k).(src).rmse_s_ca, R(k).(src).rmse_s_nc, 100*R(k).(src).frac_u0);
    end
    fprintf('\n');
    clear S3 LT
end
nS = numel(R);
assert(nS >= 1, ['[OPTX] no session qualified. Rebuild the Stage-2 caches ' ...
    '(ctrl_residual_build.m) or check the R^2 floor (%.2f).'], r2_floor);

%% [OPTX-STATS] -----------------------------------------------------------------
% The decomposition, per source. All on the STEADY window [1,dur]s, the project's
% disturbance-rejection convention -- the transient is the actuator's own step, not tracking.
rmse_s_PI = [R.rmse_s_PI].';
ST = struct();
for j = 1:numel(OX.dsrc)
    src = OX.dsrc{j};
    sub = [R.(src)];
    ca  = [sub.rmse_s_ca].';   nc = [sub.rmse_s_nc].';
    T = struct();
    T.rmse_ca = ca;  T.rmse_nc = nc;
    T.gap_real   = rmse_s_PI - ca;      % what a realizable MPC recovers from the PI
    T.gap_total  = rmse_s_PI - nc;      % what ANY controller could recover
    T.price_caus = ca - nc;             % cost of not seeing the future
    T.frac_u0    = [sub.frac_u0].';
    T.pct_real   = 100*(1 - ca./rmse_s_PI);
    T.pct_total  = 100*(1 - nc./rmse_s_PI);
    if nS >= 2
        T.p_real  = signrank(ca, rmse_s_PI);
        T.p_total = signrank(nc, rmse_s_PI);
    else
        T.p_real = NaN;  T.p_total = NaN;
    end
    ST.(src) = T;

    fprintf('\n[OPTX-%s] steady-window RMSE to ref (%%dF/F), n=%d sessions\n', upper(src), nS);
    fprintf('   PI (measured)      %.3f +/- %.3f\n', mean(rmse_s_PI), std(rmse_s_PI));
    fprintf('   causal MPC         %.3f +/- %.3f   (%.1f%% better, signrank p=%.3g)\n', ...
        mean(ca), std(ca), mean(T.pct_real), T.p_real);
    fprintf('   non-causal ceiling %.3f +/- %.3f   (%.1f%% better, signrank p=%.3g)\n', ...
        mean(nc), std(nc), mean(T.pct_total), T.p_total);
    fprintf('   price of causality %.3f +/- %.3f\n', mean(T.price_caus), std(T.price_caus));
    fprintf('   u=0 (irreducible)  %.0f%% +/- %.0f%% of the horizon\n', ...
        100*mean(T.frac_u0), 100*std(T.frac_u0));
    fprintf('   MPC better than PI in %d/%d sessions\n', nnz(T.gap_real > 0), nS);
end
if numel(OX.dsrc) == 2
    a = ST.(OX.dsrc{1}).pct_total;  b = ST.(OX.dsrc{2}).pct_total;
    fprintf(['\n[OPTX-COMPARE] ceiling under %s vs %s: %.1f%% vs %.1f%%.\n' ...
        '   A gap that survives under ''global'' is a CONTROL result; one that appears only\n' ...
        '   under ''residual'' is the optimizer repairing the plant model. Read them together.\n'], ...
        OX.dsrc{1}, OX.dsrc{2}, mean(a), mean(b));
end

%% [OPTX-FIG] -------------------------------------------------------------------
src_main = OX.dsrc{end};        % 'global' when both are computed -- the honest one leads
T = ST.(src_main);
ix_ex = NaN;                    % row of R the demo session occupies, for its own numbers
if isfield(EX,'sess_tag')
    ix_ex = find(strcmp({R.sess_tag}, EX.sess_tag), 1);
end

% (A) exemplar traces: what the controller was fighting, and what it could have done
if isfield(EX,'sess_tag') && ~isempty(ix_ex) && ~isnan(ix_ex)
    figA = paperFig(W, H_cm); axA = axes(figA); hold(axA,'on');
    E = EX.(src_main);
    plot(axA, EX.tt, EX.r, '--', 'Color',[.45 .45 .45],'LineWidth',PS.lw_ref);
    plot(axA, EX.tt, E.d,   '-', 'Color',[.60 .60 .60],'LineWidth',PS.lw_fit);   % disturbance
    plot(axA, EX.tt, EX.y_PI,'-', 'Color',PS.col_cl,   'LineWidth',PS.lw_mean);  % PI
    plot(axA, EX.tt, E.y_ca,'-',  'Color',[0.85 0.45 0.00],'LineWidth',PS.lw_fit);
    plot(axA, EX.tt, E.y_nc,':',  'Color',[0.10 0.30 0.70],'LineWidth',PS.lw_fit);
    xlabel(axA,'time (s)','FontSize',PS.fs,'FontWeight',PS.fw);
    ylabel(axA,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw);
    set(axA,'FontSize',PS.fs,'FontWeight',PS.fw);
    lg = legend(axA,{'ref','disturbance','PI','MPC','ceiling'},'Location','best','Box','off');
    lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs;
    title(axA, EX.sess_tag,'FontSize',PS.fs,'FontWeight',PS.fw,'Interpreter','none');
    cleanAxes(axA);
    deal_export(figA, outDir, sprintf('f4_mpc_traces_%s',src_main), OX.EXPORT, OX.FMT);

    % (A2) the COMMANDS, same session. This is the panel that makes the MPC argument legible:
    % where the optimum sits at u=0 the disturbance is already past the reference and no laser
    % command helps, so that stretch of error is irreducible no matter how good the controller.
    figA2 = paperFig(W, H_cm); axA2 = axes(figA2); hold(axA2,'on');
    yline(axA2, EX.u_max, ':', 'Color',[.6 .6 .6],'LineWidth',PS.lw_zero,'HandleVisibility','off');
    plot(axA2, EX.tt, EX.u_PI, '-', 'Color',PS.col_cl,        'LineWidth',PS.lw_mean);
    plot(axA2, EX.tt, E.u_ca,  '-', 'Color',[0.85 0.45 0.00], 'LineWidth',PS.lw_fit);
    plot(axA2, EX.tt, E.u_nc,  ':', 'Color',[0.10 0.30 0.70], 'LineWidth',PS.lw_fit);
    xlabel(axA2,'time (s)','FontSize',PS.fs,'FontWeight',PS.fw);
    ylabel(axA2,'laser command','FontSize',PS.fs,'FontWeight',PS.fw);
    set(axA2,'FontSize',PS.fs,'FontWeight',PS.fw);
    lg2 = legend(axA2,{'PI','MPC','ceiling'},'Location','best','Box','off');
    lg2.ItemTokenSize = PS.lgd_token;  lg2.FontSize = PS.fs;
    title(axA2, sprintf('u=0 on %.0f%%', 100*R(ix_ex).(src_main).frac_u0), ...
        'FontSize',PS.fs,'FontWeight',PS.fw);
    cleanAxes(axA2);
    deal_export(figA2, outDir, sprintf('f4_mpc_command_%s',src_main), OX.EXPORT, OX.FMT);

    fprintf('\n[OPTX-DEMO] %s (single-session demo, %s disturbance)\n', EX.sess_tag, src_main);
    fprintf('  steady RMSE: PI %.3f | MPC %.3f | ceiling %.3f   (u=0 on %.0f%% of the horizon)\n', ...
        rmse_s_PI(ix_ex), T.rmse_ca(ix_ex), T.rmse_nc(ix_ex), 100*T.frac_u0(ix_ex));
end

% (B) per-session paired RMSE: PI -> causal MPC -> ceiling
figB = paperFig(W, H_cm); axB = axes(figB); hold(axB,'on');
Y = [rmse_s_PI, T.rmse_ca, T.rmse_nc];
for k = 1:nS
    plot(axB, 1:3, Y(k,:), '-', 'Color',[.72 .72 .72],'LineWidth',PS.lw_trial*1.5);
end
CC = [PS.col_cl; 0.85 0.45 0.00; 0.10 0.30 0.70];
for m = 1:3
    scatter(axB, m*ones(nS,1), Y(:,m), 12, CC(m,:),'filled','MarkerFaceAlpha',.85);
end
plot(axB, 1:3, median(Y,1), '-k','LineWidth',PS.lw_mean);
set(axB,'XTick',1:3,'XTickLabel',{'PI','MPC','ceil'},'FontSize',PS.fs,'FontWeight',PS.fw);
xlim(axB,[0.7 3.3]);
ylabel(axB,'RMSE (%\DeltaF/F)','FontSize',PS.fs,'FontWeight',PS.fw);
title(axB,sprintf('n=%d, p=%.2g', nS, T.p_real),'FontSize',PS.fs,'FontWeight',PS.fw);
cleanAxes(axB);
deal_export(figB, outDir, sprintf('f4_mpc_rmse_%s',src_main), OX.EXPORT, OX.FMT);

% (C) error budget: what MPC recovers | price of causality | irreducible
figC = paperFig(W, H_cm); axC = axes(figC); hold(axC,'on');
[~,ord] = sort(rmse_s_PI,'descend');
Bar = [T.gap_real(ord), T.price_caus(ord), T.rmse_nc(ord)];
hb = bar(axC, 1:nS, Bar, 0.72, 'stacked','EdgeColor','none');
hb(1).FaceColor = [0.85 0.45 0.00];      % recovered by a realizable MPC
hb(2).FaceColor = [0.55 0.70 0.85];      % price of causality
hb(3).FaceColor = [0.72 0.72 0.72];      % irreducible
set(axC,'XTick',[],'FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axC,'session','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axC,'RMSE budget (%\DeltaF/F)','FontSize',PS.fs,'FontWeight',PS.fw);
lg = legend(axC,{'MPC gain','causality','irreducible'},'Location','best','Box','off');
lg.ItemTokenSize = PS.lgd_token;  lg.FontSize = PS.fs;
cleanAxes(axC);
deal_export(figC, outDir, sprintf('f4_mpc_budget_%s',src_main), OX.EXPORT, OX.FMT);

% (D) the one-sided-actuation panel: how much of the horizon nothing can be done about
figD = paperFig(W, H_cm); axD = axes(figD); hold(axD,'on');
scatter(axD, 100*T.frac_u0, T.pct_total, 14, [0.25 0.25 0.25],'filled','MarkerFaceAlpha',.8);
xlabel(axD,'horizon with u=0 (%)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axD,'ceiling gain (%)','FontSize',PS.fs,'FontWeight',PS.fw);
set(axD,'FontSize',PS.fs,'FontWeight',PS.fw);
if nS >= 4
    [rs_u,p_u] = corr(T.frac_u0, T.pct_total,'type','Spearman','rows','complete');
    title(axD,sprintf('r_s=%+.2f, p=%.2g', rs_u, p_u),'FontSize',PS.fs,'FontWeight',PS.fw);
else
    rs_u = NaN; p_u = NaN;
    title(axD,sprintf('n=%d', nS),'FontSize',PS.fs,'FontWeight',PS.fw);
end
cleanAxes(axD);
deal_export(figD, outDir, sprintf('f4_mpc_saturation_%s',src_main), OX.EXPORT, OX.FMT);

%% [OPTX-SAVE] ------------------------------------------------------------------
OPTX = struct('OX',OX,'nS',nS,'R',R,'ST',ST,'skipped',skipped, ...
    'r2_floor',r2_floor,'rmse_s_PI',rmse_s_PI,'src_main',src_main, ...
    'rs_u0',rs_u,'p_u0',p_u,'EX',EX);
save(fullfile(dataDir,'ctrl_optimal_xsess.mat'),'OPTX','-v7.3');
fprintf('\n[OPTX] struct -> data/ctrl_optimal_xsess.mat  (%d qualifying, %d skipped)\n', ...
    nS, numel(skipped));
if ~isempty(skipped)
    fprintf('  skipped:\n');
    for i = 1:numel(skipped)
        fprintf('    %-22s %s\n', skipped(i).fld, skipped(i).msg);
    end
end
fprintf('[OPTX] panels -> %s\n', outDir);

%% ---- local functions (must sit at EOF in a script) ---------------------------
function e = local_rmse(y, r, t0, Fs)
% RMSE of y against r. t0=[] -> full horizon; t0=1 -> the settled [1,dur]s window, the
% project's disturbance-rejection convention (skips the actuator's own transient).
y = y(:);  r = r(:);
if isempty(t0)
    w = 1:numel(y);
else
    w = (round(t0*Fs)+1):numel(y);
end
e = sqrt(mean((y(w) - r(w)).^2));
end

function deal_export(fig, outDir, base, EXPORT, FMT)
if ~EXPORT; return; end
for i = 1:numel(FMT)
    paperExport(fig, fullfile(outDir,[base '.' FMT{i}]));
end
end
