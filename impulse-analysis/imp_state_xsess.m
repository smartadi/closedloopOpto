%% imp_state_xsess.m -- combine the LOCAL-response state-dependence across the impulse sessions.
%
% WHY THIS EXISTS. Every state-dependence number in the project so far is ONE session (AL_0033
% 2025-01-29). Its two surviving effects are small (STATEDEP-VAR Rel-delta rho=+0.113, p=0.025) and
% one of them has already failed to replicate twice elsewhere (cp_zhiwen_predq on AB_0004, and
% AL_0048 2026-07-15). A single-session p just below 0.05 is not a finding; the question this
% script answers is whether the effect is there when the other sessions are allowed to speak.
%
% ROLES (user, 2026-08-03): the primary session stays primary and is reported on its own; the other
% sessions ADD TO THE STATISTICS -- they are not averaged into it and they do not silently outvote
% it. So every number is reported three ways:
%   PER SESSION       each session's own rho / p, primary marked. Nothing is hidden inside a pool.
%   POOLED-BLOCKED    all trials at once, partialling session dummies as well as prediction error,
%                     so a between-session offset cannot masquerade as a state effect.
%   STOUFFER          Fisher-z combination of the per-session rho (weights sqrt(n_i-3)). This is
%                     the honest "add to the statistics" number: it asks whether the sessions AGREE,
%                     and one session cannot carry it by having more trials than the rest combined.
% Pooling is legitimate here only because each DV is already z-scored WITHIN AMPLITUDE within its
% own session (imp_statedep_trials), so session and dose means are removed before anything is mixed.
%
% ADMISSIBILITY, unchanged (RESEARCH 2026-07-01/02): pre-var and absolute delta are SIGNAL-POWER
% CONFOUNDS -- they scale with signal power, which the DV magnitude also scales with, so a positive
% rho there is close to tautological. They are computed and printed, and they are NOT a finding.
% Interpret MOTION and RELATIVE DELTA only.
%
% USAGE
%   1) load_experiments.m                       % builds allExperiments (1,2 = AL_0041 e1/e2; 3 = AL_0033)
%   2) in ols_tf_pipeline.m set  RUN_ALLSESS = true;  allSelExp = XS_SEL;  then run it
%   3) imp_state_xsess                          % consumes ALLSESS from the base workspace
% Each ALLSESS{si}.ST comes from utils/imp_statedep_trials.m -- the SAME function the interactive
% §17c uses, so these numbers are directly comparable to the single-session printout.
% -------------------------------------------------------------------------------------------------

if ~exist('ALLSESS','var') || isempty(ALLSESS)
    error('XSESS:noALLSESS', ['[XSESS] no ALLSESS in the workspace.\n' ...
        'Run ols_tf_pipeline.m with RUN_ALLSESS = true and allSelExp = the sessions you want, e.g.\n' ...
        '    OLS_OVERRIDE = struct(''RUN_ALLSESS'',true,''allSelExp'',[3 1 2],''affect_mode'',''matched'');\n' ...
        '    ols_tf_pipeline\n' ...
        'RUN_ALLSESS ALONE IS NOT ENOUGH: with the default affect_mode=''tf'' the script BLOCKS at the\n' ...
        '§10T3 selector (uiwait) and never reaches §18, so no ALLSESS is created and no error is raised.\n' ...
        'Either press "CONFIRM selection & build model" on that figure, or pass affect_mode=''matched''\n' ...
        'as above to skip the gate (§18 keys off the energy-based bledA map, not affected_tf, so the\n' ...
        'cross-session numbers are the same either way). ALLSESS must be in the SAME MATLAB session.']);
end
nS = numel(ALLSESS);
have = cellfun(@(S) isfield(S,'ST') && ~isempty(S.ST) && ~isempty(S.ST.LD), ALLSESS);
if ~all(have)
    error(['[XSESS] ALLSESS{%s} carry no per-trial ST payload -- they were produced by an older ' ...
           'local_stimblind_session. Re-run §18.'], mat2str(find(~have)));
end

if ~exist('XS_PRIMARY','var') || isempty(XS_PRIMARY)
    XS_PRIMARY = find(cellfun(@(S) contains(S.label,'AL_0033'), ALLSESS), 1);
    if isempty(XS_PRIMARY), XS_PRIMARY = 1; end
end
if ~exist('XS_NPERM','var')  || isempty(XS_NPERM),  XS_NPERM = 2000; end
rng(11,'twister');                                   % same seed as the single-session §17c2

STATES = {'Motion',           'MOT', true
          'Pre-var',          'PVv', false
          'Pre-delta (abs)',  'DPa', false
          'Rel-delta',        'DPr', true};
DVS    = {'DIPmean','DVz'; 'GAIN','GAINz'; 'L1DEV','L1DEVz'};
nSt = size(STATES,1);  nDv = size(DVS,1);

fprintf('\n================ [XSESS] state-dependence across %d impulse sessions ================\n', nS);
for si = 1:nS
    tag = '';  if si==XS_PRIMARY, tag = '   <-- PRIMARY'; end
    ST = ALLSESS{si}.ST;
    fprintf('  s%d  %-26s  %4d trials, %d amps | motion %s%s\n', si, ALLSESS{si}.label, ...
        numel(ST.LD), numel(ALLSESS{si}.amps), ...
        ternstr_xs(any(isfinite(ST.MOT)), sprintf('%d finite', nnz(isfinite(ST.MOT))), 'NaN'), tag);
end

%% ---- gather per-trial vectors, tagged by session -----------------------------------------------
G = struct('sess',[],'PRE',[],'AMPi',[]);
for f = {'DVz','GAINz','L1DEVz','LD','MOT','PVv','DPa','DPr'}, G.(f{1}) = []; end
for si = 1:nS
    ST = ALLSESS{si}.ST;  n = numel(ST.LD);
    G.sess = [G.sess; si*ones(n,1)];  G.PRE = [G.PRE; ST.PRE];  G.AMPi = [G.AMPi; ST.AMPi];
    for f = {'DVz','GAINz','L1DEVz','LD','MOT','PVv','DPa','DPr'}
        G.(f{1}) = [G.(f{1}); ST.(f{1})];
    end
end
% session dummies (nS-1 columns) -> partialling them blocks between-session offsets
Dum = zeros(numel(G.sess), max(nS-1,0));
for si = 1:nS-1, Dum(:,si) = double(G.sess==si); end

%% ---- (1) STATEDEP: does the MEAN local response shift with state? ------------------------------
% Per-session partial Spearman(DV, state | pre-onset prediction error), then pooled + Stouffer.
fprintf('\n[XSESS-MEAN] partial Spearman( DV , state | pre-error )   [* = p<0.05]\n');
MEAN_rho = nan(nDv,nSt,nS);  MEAN_n = nan(nDv,nSt,nS);
MEAN_pool = nan(nDv,nSt);  MEAN_poolp = nan(nDv,nSt);
MEAN_stz = nan(nDv,nSt);   MEAN_stp = nan(nDv,nSt);
for d = 1:nDv
    fprintf('  -- DV %s\n', DVS{d,1});
    fprintf('     %-18s %s %12s %10s %12s %10s   %s\n', 'state', ...
        sprintf('%9s','per-session rho'), 'pooled', 'p(pool)', 'Stouffer z', 'p(comb)', 'class');
    for s = 1:nSt
        stf = STATES{s,2};
        rr = nan(nS,1);  nn = nan(nS,1);
        for si = 1:nS
            ST = ALLSESS{si}.ST;
            x = ST.(DVS{d,2});  y = ST.(stf);  z = ST.PRE;
            ok = isfinite(x) & isfinite(y) & isfinite(z);
            if nnz(ok) > 10
                rr(si) = partialcorr(x(ok), y(ok), z(ok), 'type','Spearman');
                nn(si) = nnz(ok);
            end
        end
        MEAN_rho(d,s,:) = rr;  MEAN_n(d,s,:) = nn;
        % pooled, blocking session
        X = G.(DVS{d,2});  Y = G.(stf);  Z = [G.PRE, Dum];
        ok = all(isfinite([X Y Z]),2);
        if nnz(ok) > 20
            [MEAN_pool(d,s), MEAN_poolp(d,s)] = partialcorr(X(ok), Y(ok), Z(ok,:), 'type','Spearman');
        end
        [MEAN_stz(d,s), MEAN_stp(d,s)] = stouffer_xs(rr, nn);
        fprintf('     %-18s %s %+12.3f %10.4f %+12.2f %10.4f   %s%s\n', STATES{s,1}, ...
            sprintf_rho_xs(rr, XS_PRIMARY), MEAN_pool(d,s), MEAN_poolp(d,s), ...
            MEAN_stz(d,s), MEAN_stp(d,s), ...
            ternstr_xs(STATES{s,3},'power-indep','POWER-CONFOUND'), ...
            ternstr_xs(MEAN_stp(d,s)<0.05,' *',''));
    end
end

%% ---- (2) STATEDEP-VAR: does the VARIABILITY of the local response rise with state? -------------
% The headline single-session finding is heteroscedastic, not a mean shift, so this is the test that
% matters. Same held-out construction as §17c2: amp-means come from a TRAIN half, |deviation| and the
% statistic are evaluated on the TEST half only, and the null shuffles state labels WITHIN SESSION
% (shuffling across sessions would let between-session differences manufacture a signal).
fprintf('\n[XSESS-VAR] held-out partial Spearman( |Local-dip deviation| , state | pre-error ), perm N=%d\n', XS_NPERM);
fprintf('     %-18s %s %12s %10s %12s %10s   %s\n', 'state', sprintf('%9s','per-session rho'), ...
        'pooled', 'perm p', 'Stouffer z', 'p(comb)', 'class');

% held-out split + |deviation| about TRAIN amp-means, done independently within each session
devHO = nan(numel(G.LD),1);  teMask = false(numel(G.LD),1);
for si = 1:nS
    inS = find(G.sess==si);
    for a = unique(G.AMPi(inS)).'
        ia = inS(G.AMPi(inS)==a);
        te = ia(2:2:end);  tr = setdiff(ia, te);
        teMask(te) = true;
        if ~isempty(tr), devHO(te) = abs(G.LD(te) - mean(G.LD(tr),'omitnan')); end
    end
end

VAR_rho = nan(nSt,nS);  VAR_n = nan(nSt,nS);
VAR_pool = nan(nSt,1);  VAR_permp = nan(nSt,1);
VAR_stz = nan(nSt,1);   VAR_stp = nan(nSt,1);
VAR_null = cell(nSt,1);
for s = 1:nSt
    stf = STATES{s,2};  ST_all = G.(stf);
    % per session
    for si = 1:nS
        m = teMask & G.sess==si & isfinite(devHO) & isfinite(ST_all) & isfinite(G.PRE);
        if nnz(m) > 10
            VAR_rho(s,si) = partialcorr(devHO(m), ST_all(m), G.PRE(m), 'type','Spearman');
            VAR_n(s,si) = nnz(m);
        end
    end
    % pooled (session blocked) + within-session permutation null
    m = teMask & isfinite(devHO) & isfinite(ST_all) & isfinite(G.PRE);
    idx = find(m);
    if numel(idx) > 20
        Zc = [G.PRE(idx), Dum(idx,:)];
        VAR_pool(s) = partialcorr(devHO(idx), ST_all(idx), Zc, 'type','Spearman');
        sIdx = G.sess(idx);
        nul = nan(XS_NPERM,1);
        for k = 1:XS_NPERM
            perm = (1:numel(idx)).';
            for si = 1:nS                                   % shuffle WITHIN session only
                w = find(sIdx==si);
                if numel(w) > 1, perm(w) = w(randperm(numel(w))); end
            end
            nul(k) = partialcorr(devHO(idx), ST_all(idx(perm)), Zc, 'type','Spearman');
        end
        VAR_permp(s) = (1 + sum(abs(nul) >= abs(VAR_pool(s)))) / (XS_NPERM+1);
        VAR_null{s} = nul;
    end
    [VAR_stz(s), VAR_stp(s)] = stouffer_xs(VAR_rho(s,:).', VAR_n(s,:).');
    fprintf('     %-18s %s %+12.3f %10.4f %+12.2f %10.4f   %s%s\n', STATES{s,1}, ...
        sprintf_rho_xs(VAR_rho(s,:).', XS_PRIMARY), VAR_pool(s), VAR_permp(s), ...
        VAR_stz(s), VAR_stp(s), ternstr_xs(STATES{s,3},'power-indep','POWER-CONFOUND'), ...
        ternstr_xs(VAR_permp(s)<0.05,' *',''));
end
fprintf(['   rho>0 => the local response is MORE VARIABLE when the state marker is high.\n' ...
         '   Read Motion and Rel-delta only; the two POWER-CONFOUND rows are printed as a control,\n' ...
         '   and their significance is expected and uninformative.\n']);

%% ---- (3) forest plot: per-session rho with the combined estimate -------------------------------
% One panel per state. Points = per-session rho (primary filled), vertical band = pooled estimate.
% The point of the figure is agreement, not magnitude: sessions scattered on both sides of zero is
% a null however small the pooled p is.
figXS = figure('Color','w','Name','[XSESS] state-dependence across sessions','Position',[50 70 1250 620]);
for s = 1:nSt
    % variability (headline)
    ax = subplot(2,nSt,s); hold(ax,'on'); box(ax,'on');
    forest_xs(ax, VAR_rho(s,:).', VAR_pool(s), XS_PRIMARY, nS);
    title(ax, sprintf('%s\nVAR  pooled %+.3f (p=%.3f)', STATES{s,1}, VAR_pool(s), VAR_permp(s)), ...
          'FontSize',9,'FontWeight','bold', 'Color', ternclr_xs(STATES{s,3}));
    if s==1, ylabel(ax,'session'); end
    xlabel(ax,'partial \rho  (|dev| vs state)');
    % mean shift, L1DEV row (the DV the 2026-07-01 A2 result favours)
    ax2 = subplot(2,nSt,nSt+s); hold(ax2,'on'); box(ax2,'on');
    forest_xs(ax2, squeeze(MEAN_rho(3,s,:)), MEAN_pool(3,s), XS_PRIMARY, nS);
    title(ax2, sprintf('L1DEV mean-shift\npooled %+.3f (p=%.3f)', MEAN_pool(3,s), MEAN_poolp(3,s)), ...
          'FontSize',9,'FontWeight','bold','Color', ternclr_xs(STATES{s,3}));
    if s==1, ylabel(ax2,'session'); end
    xlabel(ax2,'partial \rho');
end
sgtitle(sprintf(['XSESS  %d impulse sessions  —  top: local-response VARIABILITY vs state (held-out);  ' ...
    'bottom: L1DEV mean shift.  Filled = primary (%s).  Interpret Motion + Rel-\\delta only.'], ...
    nS, ALLSESS{XS_PRIMARY}.label), 'FontWeight','bold','FontSize',10);

XSESS = struct('sessions',{cellfun(@(S)S.label, ALLSESS, 'uni',0)}, 'primary',XS_PRIMARY, ...
               'stateLabel',{STATES(:,1)}, 'stateAdmissible',{cell2mat(STATES(:,3))}, ...
               'dvLabel',{DVS(:,1)}, ...
               'MEAN_rho',MEAN_rho,'MEAN_pool',MEAN_pool,'MEAN_poolp',MEAN_poolp, ...
               'MEAN_stz',MEAN_stz,'MEAN_stp',MEAN_stp, ...
               'VAR_rho',VAR_rho,'VAR_pool',VAR_pool,'VAR_permp',VAR_permp, ...
               'VAR_stz',VAR_stz,'VAR_stp',VAR_stp,'nPerm',XS_NPERM);
fprintf('\n[XSESS] -> XSESS struct (per-session + pooled + Stouffer, mean & variability).\n');

%% ---- local helpers ------------------------------------------------------------------------------
function s = ternstr_xs(c, a, b),  if c, s = a; else, s = b; end,  end
function c = ternclr_xs(adm),      if adm, c = [0 0 0]; else, c = [0.55 0.33 0.05]; end,  end

function s = sprintf_rho_xs(rr, prim)
% per-session rho as one compact column; the primary session is bracketed so it stays visible.
s = '';
for i = 1:numel(rr)
    if isnan(rr(i)), t = '   n/a ';
    elseif i==prim,  t = sprintf('[%+.3f]', rr(i));
    else,            t = sprintf(' %+.3f ', rr(i));
    end
    s = [s t]; %#ok<AGROW>
end
end

function [z, p] = stouffer_xs(rr, nn)
% Fisher-z combination of independent per-session partial correlations, weighted by sqrt(n_i-3).
% Asks whether the SESSIONS AGREE. A single large session cannot dominate the way it does in a
% pooled correlation, which is precisely why it is reported alongside the pool and not instead.
ok = isfinite(rr) & isfinite(nn) & nn > 4;
if nnz(ok) < 1, z = NaN; p = NaN; return; end
r  = max(min(rr(ok), 1-1e-9), -1+1e-9);
zi = atanh(r);  df = nn(ok) - 3;
% Fisher z_i has sd 1/sqrt(n_i-3), so the STANDARD NORMAL per session is Z_i = z_i*sqrt(n_i-3).
% Combining those with weights w_i = sqrt(n_i-3) gives  sum((n_i-3)*z_i)/sqrt(sum(n_i-3)),
% i.e. the inverse-variance-weighted mean Fisher z expressed as a z-score.
z = sum(df.*zi)/sqrt(sum(df));
p = 2*(1 - normcdf(abs(z)));
end

function forest_xs(ax, rr, pooled, prim, nS)
for i = 1:nS
    if ~isfinite(rr(i)), continue; end
    if i==prim, plot(ax, rr(i), i, 'o', 'MarkerSize',9,'MarkerFaceColor',[.15 .35 .8],'MarkerEdgeColor','k');
    else,       plot(ax, rr(i), i, 'o', 'MarkerSize',8,'MarkerFaceColor','w','MarkerEdgeColor',[.15 .35 .8],'LineWidth',1.2);
    end
end
if isfinite(pooled)
    xline(ax, pooled, '-', 'Color',[.85 .2 .2], 'LineWidth',1.6);
end
xline(ax, 0, 'k:');
ylim(ax, [0.4 nS+0.6]);  set(ax,'YTick',1:nS,'YDir','reverse','FontSize',8);
xl = max([0.25; abs(rr(isfinite(rr))); abs(pooled)])*1.25;  xlim(ax, [-xl xl]);
end
