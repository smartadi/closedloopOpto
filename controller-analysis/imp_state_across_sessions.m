%% imp_state_across_sessions.m   [IMP-XSTATE]  -- STREAM 2 (confirmatory), state arm
% Population version of internal_model_principle.m's [IMP-STATE-QUARTILE]: does the
% per-trial disturbance transmission rho_{1-3} = ||A-ref||/||G|| depend on the pre-stim
% brain state, and does the OL->CL rejection benefit survive at every state level?
%
% Shares every definition with Stream 1 -- trials via imp_build_session, rho via
% imp_reject_core, states via utils/imp_trial_states (fig-4 windows: motion energy =
% mean z-motion^2 over [-2 s, trial end]; rel delta = bandpow(2-4)/bandpow(0.4-10)
% over [-2 s, +3 s]). Nothing is redefined here, so the population number cannot drift
% from the single-session one.
%
% Two questions, two answers:
%   Q-slope  within a session, does rho rise/fall with the state?  -> per-session
%            Spearman r_s (OL and CL separately), then a session-level signrank vs 0.
%            n = #sessions, NOT #trials -- trial-level p would be pseudoreplication.
%   Q-offset does CL beat OL at EVERY state level?                 -> within-session
%            quartiles (edges pooled over OL+CL so Q1..Q4 is the same absolute state
%            for both), per-session median rho per quartile, then the OL-CL gain per
%            quartile across sessions (signrank per quartile + Friedman over quartiles
%            to ask whether the benefit itself is state-dependent).
%
% PREREQ: Stage-1/2 caches per session (build with imp_xsess_build.m).
% Run: load_sessions.m -> imp_state_across_sessions.m
% ---------------------------------------------------------------------------------

%% [XSTATE-CFG] -----------------------------------------------------------------
CFG.nSV_load = 500;  CFG.Fs = 35;  CFG.pre_s = 1.0;  CFG.resp_s = 3.0;
nBoot = 2000;  rng(7,'twister');
SESS  = 1:numel(fields);
% ADMISSION GATE (user, 2026-08-12) -- identical rule in all three cross-session scripts
% (ctrl_ols_xsess.m, imp_reject_across_sessions.m, this). A state SLOPE built on an
% under-floor Global is the worst case of all: everything the predictor misses lands in the
% residual, so if predictor weakness happens to vary with state the slope measures the model,
% not the brain. Gate first, then correlate.
r2_floor = ctrl_r2_floor();      % 0.85 on the DEPLOYED (Stage-2) predictor
USE_GATE = ctrl_gate_on();       % single project switch (utils/ctrl_gate_on.m); CTRL_GATE overrides
PS = paperStyle();  col_ol = PS.col_ol;  col_cl = PS.col_cl;

assert(exist('mouse','var') && exist('fields','var'), '[XSTATE] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

STATES = {'motion energy', 'rel \delta power (2-4 Hz)'};
nSt = numel(STATES);

%% [XSTATE-LOOP] ----------------------------------------------------------------
P = struct([]);            % per-session results
skipped = struct('fld',{},'msg',{});
gate_txt = {'OFF','ON'};   % indexed by logical+1 (script local functions must sit at EOF)
fprintf('\n[IMP-XSTATE] scanning %d candidate sessions  (R^2 gate %s, floor %.2f)...\n', ...
    numel(SESS), gate_txt{USE_GATE+1}, r2_floor);
for s = SESS
    fld_s = fields{s};  freeAfter = false;
    if ~isfield(mouse.(fld_s),'d') || isempty(mouse.(fld_s).d)
        pth_s = fullfile(fileparts(here),'data', sprintf('%sctrl%s%s%d.mat', ...
            mouse.(fld_s).mn, mouse.(fld_s).td(6:7), mouse.(fld_s).td(9:10), mouse.(fld_s).en));
        if ~exist(pth_s,'file'); continue; end
        tmp_s = load(pth_s);
        if ~isfield(tmp_s,'d'); clear tmp_s; continue; end
        mouse.(fld_s).d = tmp_s.d;  mouse.(fld_s).data = tmp_s.data;  clear tmp_s;
        if ~isfield(mouse.(fld_s).d,'ref'); mouse.(fld_s).d.ref = -5; end
        freeAfter = true;
    end
    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    gateFail = S.ok && USE_GATE && ~(S.R2_te >= r2_floor);   % tested before the core runs
    stateOK = false;
    if S.ok && ~gateFail
        R  = imp_reject_core(S.Aol, S.Gol, S.Acl, S.Gcl, S.pre, S.Fs, CFG.resp_s, S.ref);
        % same t_full/pre/post/nF the trial builder used -> identical trial order
        ST = imp_trial_states(mouse.(fld_s).d, mouse.(fld_s).data, ...
                              S.t_full, S.pre, S.post, S.nF, S.Fs);
        stateOK = (ST.n_ol == R.n_ol) && (ST.n_cl == R.n_cl);
    end
    if freeAfter; mouse.(fld_s) = rmfield(mouse.(fld_s), {'d','data'}); end
    if ~S.ok
        skipped(end+1) = struct('fld',S.sess_tag,'msg',S.msg); %#ok<SAGROW>
        fprintf('  %-22s SKIP (%s)\n', S.sess_tag, S.msg);  continue;
    end
    if gateFail
        skipped(end+1) = struct('fld',S.sess_tag, ...
            'msg',sprintf('deployed R^2 %.3f < floor %.2f', S.R2_te, r2_floor)); %#ok<SAGROW>
        fprintf('  %-22s SKIP (deployed R^2 %.3f < floor %.2f)\n', S.sess_tag, S.R2_te, r2_floor);
        continue;
    end
    if ~stateOK
        skipped(end+1) = struct('fld',S.sess_tag,'msg','state/rho trial mismatch'); %#ok<SAGROW>
        fprintf('  %-22s SKIP (state/rho trial mismatch OL %d/%d CL %d/%d)\n', ...
            S.sess_tag, ST.n_ol, R.n_ol, ST.n_cl, R.n_cl);  continue;
    end

    k = numel(P)+1;
    P(k).sess_tag = S.sess_tag;  P(k).mn = S.mn;  P(k).selField = s;
    P(k).n_ol = R.n_ol;  P(k).n_cl = R.n_cl;  P(k).R2_te = S.R2_te;
    P(k).haveMot = ST.haveMot;
    sv_ol = {ST.mot_ol, ST.delt_ol};  sv_cl = {ST.mot_cl, ST.delt_cl};
    for j = 1:nSt
        so = sv_ol{j}(:);  sc = sv_cl{j}(:);
        [P(k).rs_ol(j), P(k).p_ol(j)] = corr(so, R.rho_ol, 'type','Spearman','rows','complete');
        [P(k).rs_cl(j), P(k).p_cl(j)] = corr(sc, R.rho_cl, 'type','Spearman','rows','complete');
        % within-session quartiles, edges pooled over OL+CL (same absolute state both arms)
        allv = [so; sc];  allv = allv(isfinite(allv));
        if numel(allv) < 8
            P(k).q_med_ol(j,:) = nan(1,4);  P(k).q_med_cl(j,:) = nan(1,4);  continue;
        end
        ed = quantile(allv,[0 .25 .5 .75 1]);  ed(1) = -inf;  ed(end) = inf;
        qo = discretize(so,ed);  qc = discretize(sc,ed);
        for q = 1:4
            yo = R.rho_ol(qo==q);  yc = R.rho_cl(qc==q);
            P(k).q_med_ol(j,q) = median(yo(isfinite(yo)));
            P(k).q_med_cl(j,q) = median(yc(isfinite(yc)));
        end
    end
    fprintf('  %-22s nOL %3d nCL %3d | mot r_s OL %+.2f CL %+.2f | del r_s OL %+.2f CL %+.2f\n', ...
        S.sess_tag, R.n_ol, R.n_cl, P(k).rs_ol(1), P(k).rs_cl(1), P(k).rs_ol(2), P(k).rs_cl(2));
end
nS = numel(P);
assert(nS >= 1, ['[XSTATE] no session qualified. Either the Stage-1/2 caches are missing ' ...
    '(build them: ctrl_roi_draw_all -> ctrl_residual_build), or every deployed predictor is ' ...
    'below the R^2 floor (%.2f). Set USE_GATE=false to see the ungated numbers -- ' ...
    'DIAGNOSTIC ONLY, they are not reportable.'], r2_floor);

%% [XSTATE-STATS] ---------------------------------------------------------------
fprintf('\n[IMP-XSTATE] state-dependence of rho_{1-3}, %d sessions (session-level inference)\n', nS);
XST = struct('state',{},'mean_rs_ol',{},'mean_rs_cl',{},'ci_ol',{},'ci_cl',{}, ...
             'p_ol',{},'p_cl',{},'q_gain',{},'p_q',{},'p_fried',{});
for j = 1:nSt
    ro = arrayfun(@(p) p.rs_ol(j), P).';   rc = arrayfun(@(p) p.rs_cl(j), P).';
    okj = isfinite(ro) & isfinite(rc);  ro = ro(okj);  rc = rc(okj);
    bo = zeros(nBoot,1);  bc = zeros(nBoot,1);
    for b = 1:nBoot, ix = randi(numel(ro),numel(ro),1); bo(b) = mean(ro(ix)); bc(b) = mean(rc(ix)); end
    pj_ol = NaN;  pj_cl = NaN;
    if numel(ro) >= 3, pj_ol = signrank(ro); pj_cl = signrank(rc); end
    % quartile gains (OL-CL) per session, then per-quartile signrank + Friedman over Q
    Go = cell2mat(arrayfun(@(p) p.q_med_ol(j,:), P, 'uni',0).');
    Gc = cell2mat(arrayfun(@(p) p.q_med_cl(j,:), P, 'uni',0).');
    gq = Go - Gc;                                   % [nS x 4] rejection gain per quartile
    pq = nan(1,4);
    for q = 1:4
        v = gq(isfinite(gq(:,q)), q);
        if numel(v) >= 3, pq(q) = signrank(v); end
    end
    rowsOK = all(isfinite(gq),2);
    p_fr = NaN;
    if nnz(rowsOK) >= 3, p_fr = friedman(gq(rowsOK,:), 1, 'off'); end

    k = numel(XST)+1;
    XST(k).state = STATES{j};
    XST(k).mean_rs_ol = mean(ro);  XST(k).mean_rs_cl = mean(rc);
    XST(k).ci_ol = prctile(bo,[2.5 97.5]);  XST(k).ci_cl = prctile(bc,[2.5 97.5]);
    XST(k).p_ol = pj_ol;  XST(k).p_cl = pj_cl;
    XST(k).q_gain = gq;   XST(k).p_q = pq;  XST(k).p_fried = p_fr;
    XST(k).q_med_ol = Go; XST(k).q_med_cl = Gc;  XST(k).rs_ol = ro;  XST(k).rs_cl = rc;

    fprintf('  %-26s OL mean r_s %+.3f CI [%+.3f %+.3f] p=%.3g | CL %+.3f CI [%+.3f %+.3f] p=%.3g\n', ...
        STATES{j}, mean(ro), XST(k).ci_ol, pj_ol, mean(rc), XST(k).ci_cl, pj_cl);
    fprintf('  %-26s rejection gain (OL-CL) by quartile: %s  (signrank p %s; Friedman over Q p=%.3g)\n', ...
        '', sprintf('%+.3f ', mean(gq(rowsOK,:),1)), sprintf('%.3g ', pq), p_fr);
end

%% [XSTATE-FIG] -----------------------------------------------------------------
figS = figure('Color','w','Position',[40 60 640*nSt 760]);
tl = tiledlayout(figS, 2, nSt, 'TileSpacing','compact','Padding','compact');
for j = 1:nSt
    % (top) per-session quartile curves, mean +/- SEM across sessions
    ax = nexttile(tl, j); hold(ax,'on');
    Go = XST(j).q_med_ol;  Gc = XST(j).q_med_cl;
    mo = mean(Go,1,'omitnan');  eo = std(Go,0,1,'omitnan')./sqrt(sum(isfinite(Go),1));
    mc = mean(Gc,1,'omitnan');  ec = std(Gc,0,1,'omitnan')./sqrt(sum(isfinite(Gc),1));
    for k = 1:size(Go,1)
        plot(ax,(1:4)-0.06,Go(k,:),'-','Color',[col_ol .25],'LineWidth',0.6,'HandleVisibility','off');
        plot(ax,(1:4)+0.06,Gc(k,:),'-','Color',[col_cl .25],'LineWidth',0.6,'HandleVisibility','off');
    end
    errorbar(ax,(1:4)-0.06,mo,eo,'-o','Color',col_ol,'LineWidth',1.8,'MarkerFaceColor',col_ol,'CapSize',4,'DisplayName','OL');
    errorbar(ax,(1:4)+0.06,mc,ec,'-o','Color',col_cl,'LineWidth',1.8,'MarkerFaceColor',col_cl,'CapSize',4,'DisplayName','CL');
    yline(ax,1,'--','Color',[.7 .7 .7],'HandleVisibility','off');
    set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out');
    xlim(ax,[0.5 4.5]);  xlabel(ax,sprintf('%s  (low \\rightarrow high)',STATES{j}));
    if j==1; ylabel(ax,'transmission  ||E|| / ||D||'); legend(ax,'Location','best','Box','off'); end
    title(ax,sprintf('gain by Q: %s (Friedman p=%.2g)', sprintf('%+.2f ',mean(XST(j).q_gain,1,'omitnan')), XST(j).p_fried), ...
        'FontWeight','normal');

    % (bottom) per-session Spearman r_s, OL vs CL, with the session-level mean
    ax2 = nexttile(tl, nSt + j); hold(ax2,'on');
    ro = XST(j).rs_ol;  rc = XST(j).rs_cl;  n = numel(ro);
    for k = 1:n
        plot(ax2,[1 2],[ro(k) rc(k)],'-','Color',[.75 .75 .75],'LineWidth',0.8,'HandleVisibility','off');
    end
    scatter(ax2,ones(n,1),ro,36,col_ol,'filled','MarkerFaceAlpha',.8);
    scatter(ax2,2*ones(n,1),rc,36,col_cl,'filled','MarkerFaceAlpha',.8);
    plot(ax2,[0.8 1.2],mean(ro)*[1 1],'-k','LineWidth',2);
    plot(ax2,[1.8 2.2],mean(rc)*[1 1],'-k','LineWidth',2);
    yline(ax2,0,':','Color',[.4 .4 .4]);
    set(ax2,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out');  xlim(ax2,[0.6 2.4]);
    ylabel(ax2,sprintf('Spearman r_s  (rho vs %s)', STATES{j}));
    title(ax2,sprintf('OL %+.2f (p=%.2g) | CL %+.2f (p=%.2g)', ...
        mean(ro), XST(j).p_ol, mean(rc), XST(j).p_cl),'FontWeight','normal');
end
sgtitle(figS, sprintf('[IMP-XSTATE] rejection vs pre-stim state, %d sessions (%s)', ...
    nS, strjoin(unique({P.mn}),', ')), 'FontWeight','bold');
spng = fullfile(fig_dir,'imp_state_across_sessions.png');
exportgraphics(figS, spng, 'Resolution',300);
fprintf('[IMP-XSTATE] figure -> %s\n', spng);

%% [XSTATE-SAVE] ----------------------------------------------------------------
XS_STATE = struct('CFG',CFG,'nS',nS,'P',P,'XST',XST,'states',{STATES}, ...
    'r2_floor',r2_floor,'USE_GATE',USE_GATE,'skipped',skipped);
save(fullfile(dataDir,'imp_state_across_sessions.mat'),'XS_STATE');
fprintf('[IMP-XSTATE] struct -> data/imp_state_across_sessions.mat (%d qualifying, %d skipped)\n', ...
    nS, numel(skipped));
if ~isempty(skipped)
    fprintf('  skipped:\n');
    for i = 1:numel(skipped)
        fprintf('    %-22s %s\n', skipped(i).fld, skipped(i).msg);
    end
end
