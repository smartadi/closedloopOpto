%% imp_state_trialvar.m -- TRIAL-TO-TRIAL VARIABILITY of the impulse response vs brain state.
%
% Merges and supersedes the state parts of motion_analysis.m and prestim_variance.m, which asked the
% same question through two different scripts and one confusing DV.
%
% ================================ THE CLAIM BEING TESTED =========================================
% (user, 2026-08-12)
%   H1  higher MOTION            -> LOWER  trial-to-trial variability of the impulse response
%   H2  higher PRE-TRIAL VARIANCE-> SAME or HIGHER variability
%   H3  higher DELTA ENERGY      -> SAME or HIGHER variability
%
% *** THIS IS A CLAIM ABOUT SPREAD, NOT ABOUT MEAN, AND THE TESTS HERE ARE SCALE TESTS. ***
% Established 2026-08-12: the SIGNED deviation Peak_imp - mean(Peak_imp) has NO directional
% relationship to motion (pooled r = 0.003, p = 0.894, n = 1767). Motion compresses the deviation
% distribution SYMMETRICALLY. The old |Peak dev| analyses were therefore scale tests all along --
% abs() turned a variance effect into an apparent mean effect. This script keeps the SIGNED
% deviation for display (so the funnel is visible) and tests the SPREAD explicitly.
%
% DV        dev = Peak_imp - mean(Peak_imp)  per amplitude, SIGNED, then scaled by the within-amp SD
%           so amplitudes can be pooled. Spread statistic = |dev| (a Levene score about the within-
%           amp centre, which is 0 by construction).
%
% STATES    MOT  mean |z| motion                                    power-independent  ADMISSIBLE
%           PVv  var(dF/F)                                          POWER CONFOUND
%           DPa  absolute 1-4 Hz power                              POWER CONFOUND
%           DPr  RELATIVE delta = DPa / (0.5-30 Hz)                 power-independent  ADMISSIBLE
%
% ⚠ H2 AND H3 ARE PARTLY UNFALSIFIABLE AS STATED. Pre-trial variance and ABSOLUTE delta ARE signal
% power. The DV is a spread. A trial in a high-power state has more variance everywhere, so "higher
% pre-var -> same or higher variability" is close to true by construction and cannot discriminate a
% brain-state effect from an amplitude-of-everything effect. This is the confound retracted on
% 2026-07-01. RELATIVE delta (DPr) is the power-independent version and is the one that can actually
% test H3. Both are computed; PVv/DPa are printed and greyed in the figure, never interpreted.
%
% THE STIM-FREE CONTROL (the thing that makes this falsifiable). Every test is repeated on a
% PRE-ONSET, STIM-FREE quantity built the same way (deviation of the pre-window mean from its
% amp-mean). If a state predicts the spread of the stim-free control as strongly as it predicts the
% spread of the response, the effect is about ongoing signal amplitude, NOT about how the stimulus
% is processed. A claim survives only if STIM effect > PRE control.
%
% WINDOWS   strictly PRE-ONSET [-1, 0) s for every state marker, so no marker overlaps the response
%           window the DV is measured in. RESEARCH A4 records that strictly-pre reproduces the
%           'peri' [-1,+0.5] s result, so nothing is lost and the circularity objection is closed.
%           Set STV_STATE_WIN='peri' to compare.
%
% RUN:  load_experiments;  imp_state_trialvar
%       STV_NBIN = 5; imp_state_trialvar        % change the number of state bins
% -------------------------------------------------------------------------------------------------

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
addpath(genpath(fullfile(here,'..','utils')));
assert(exist('allExperiments','var')==1 && ~isempty(allExperiments), ...
       '[STV] allExperiments absent -- run load_experiments first.');

if ~exist('STV_NBIN','var')      || isempty(STV_NBIN),      STV_NBIN = 4;        end
if ~exist('STV_STATE_WIN','var') || isempty(STV_STATE_WIN), STV_STATE_WIN = 'pre'; end
if ~exist('STV_NBOOT','var')     || isempty(STV_NBOOT),     STV_NBOOT = 2000;    end
% STATE SCALING (user, 2026-08-12). Default RAW: the markers keep their physical units, so an axis
% reads "motion z-score 2.5" or "pre-trial variance 20 (dF/F)^2" instead of a within-amp z that
% cannot be related to anything. Cost of raw pooling: between-session and between-amplitude offsets
% now sit in the pooled statistic, so a session that happens to have both more motion and less
% variability could create a pooled correlation on its own. That is why the pooled row is reported
% BESIDE a SESSION-STRATIFIED estimate (weighted mean of within-session rho) and the per-session
% table -- the stratified number is the one that cannot be produced by between-session structure.
% Set STV_ZSTATE=true to recover the old within-session x amplitude z-scoring.
if ~exist('STV_ZSTATE','var')    || isempty(STV_ZSTATE),    STV_ZSTATE = false;  end
if ~exist('STV_FS','var')        || isempty(STV_FS),        STV_FS = 35;         end
if ~exist('STV_PLOT','var')      || isempty(STV_PLOT),      STV_PLOT = true;     end
STV_FIGDIR = fullfile(here,'figs','state_trialvar');
if ~exist(STV_FIGDIR,'dir'), mkdir(STV_FIGDIR); end

fs   = STV_FS;
tAxis = -3 : 1/fs : 3;                       % dfImp column timebase (matches load_experiments tWin=3)
switch lower(STV_STATE_WIN)
    case 'peri', stWin = [-1.0,  0.5];
    otherwise,   stWin = [-1.0, -1/fs];      % strictly pre-onset
end
iState = tAxis >= stWin(1) & tAxis <= stWin(2);
iPreCtl = iState;                             % the stim-free control uses the same samples

MK = { 'MOT','Motion',            true,  'motion z-score'
       'PVv','Pre-trial variance',false, '(\DeltaF/F)^2'
       'DPa','Abs \delta power',  false, '(\DeltaF/F)^2'
       'DPr','Rel \delta',        true,  'fraction of 0.5-30 Hz' };
nMK = size(MK,1);
% Claim: motion DECREASES spread (trend < 0); the other three keep it SAME or HIGHER (trend >= 0).
claimDir = [-1; +1; +1; +1];

rng(7,'twister');

%% ================= (1) build the per-trial table, all sessions ==================================
T = struct('sess',[], 'amp',[], 'dev',[], 'devPre',[], 'MOT',[], 'PVv',[], 'DPa',[], 'DPr',[]);
nExp_s = numel(allExperiments);
labels = cell(nExp_s,1);
fprintf('\n[STV] state window %s = [%.2f %.2f] s | %d bins | %d bootstrap\n', ...
        upper(STV_STATE_WIN), stWin(1), stWin(2), STV_NBIN, STV_NBOOT);

for e = 1:nExp_s
    imp = allExperiments(e).imp;
    labels{e} = sprintf('%s %s e%d', allExperiments(e).mn, allExperiments(e).td, allExperiments(e).en);
    nA = numel(imp.uAmp);
    for a = 1:nA
        df = imp.dfImp{a};  pk = imp.Peak_imp{a}(:);
        if isempty(df) || isempty(pk), continue; end
        n = min([size(df,1), numel(pk), size(imp.motTrace{a},1)]);
        if n < 8, continue; end                       % need enough trials for a spread estimate
        df = df(1:n,:);  pk = pk(1:n);

        % --- DV: SIGNED deviation from the amplitude mean, scaled by within-amp SD --------------
        d  = pk - mean(pk,'omitnan');
        sd = std(d,'omitnan');   if ~isfinite(sd) || sd == 0, continue; end
        dev = d / sd;

        % --- stim-free control: same construction on the PRE-onset window mean -------------------
        pre  = mean(df(:, iPreCtl), 2, 'omitnan');
        dpc  = pre - mean(pre,'omitnan');
        sdp  = std(dpc,'omitnan');   if ~isfinite(sdp) || sdp == 0, sdp = eps; end
        devPre = dpc / sdp;

        % --- state markers, all from the SAME pre-onset window -----------------------------------
        seg  = df(:, iState);
        mot  = mean(imp.motTrace{a}(1:n, iState), 2, 'omitnan');
        pvv  = var(seg, 0, 2, 'omitnan');
        [dpa, dpr] = local_delta(seg, fs);

        T.sess   = [T.sess;   repmat(e,n,1)];
        T.amp    = [T.amp;    repmat(a,n,1)];
        T.dev    = [T.dev;    dev];
        T.devPre = [T.devPre; devPre];
        T.MOT    = [T.MOT;    mot];
        T.PVv    = [T.PVv;    pvv];
        T.DPa    = [T.DPa;    dpa];
        T.DPr    = [T.DPr;    dpr];
    end
end
fprintf('[STV] %d trials from %d sessions\n', numel(T.dev), numel(unique(T.sess)));

% Analysis copy of each marker: RAW by default (interpretable units), or z-scored within
% session x amplitude if STV_ZSTATE. See the knob's comment for what raw costs and how it is
% controlled for.
grp = findgroups(T.sess, T.amp);
for k = 1:nMK
    if STV_ZSTATE
        T.([MK{k,1} 'z']) = local_zby(T.(MK{k,1}), grp);
    else
        T.([MK{k,1} 'z']) = double(T.(MK{k,1})(:));
    end
end
fprintf('[STV] state scaling: %s\n', local_tern(STV_ZSTATE, 'z-scored within session x amp', 'RAW (physical units)'));

%% ================= (2) the scale tests ===========================================================
R = struct();
fprintf('\n%-22s %7s %9s %9s %8s %6s | %8s %11s | %7s %6s  %s\n', ...
        'state','n','rho|dev|','p','strat','agree','SDratio','CI95','BF p','trend','verdict');
for k = 1:nMK
    st = T.([MK{k,1} 'z']);
    ok = isfinite(st) & isfinite(T.dev);
    x  = st(ok);  y = T.dev(ok);  yp = T.devPre(ok);

    % --- primary: continuous scale test (Levene score |dev| vs state) -------------------------
    [rho,  p ]  = corr(abs(y),  x, 'type','Spearman');
    [rhoP, pP]  = corr(abs(yp), x, 'type','Spearman');    % stim-free control

    % --- SESSION-STRATIFIED rho: weighted mean of the WITHIN-session correlations ---------------
    % With RAW states the pooled rho can in principle be manufactured by between-session offsets
    % (a session with more motion AND less variability would do it). This estimate never compares
    % one session to another, so if it agrees with the pooled number that explanation is dead.
    uSs = unique(T.sess).';
    rs = nan(1,numel(uSs));  ws = zeros(1,numel(uSs));
    for ii = 1:numel(uSs)
        mm = (T.sess == uSs(ii)) & ok;
        if nnz(mm) < 20, continue; end
        rs(ii) = corr(abs(T.dev(mm)), st(mm), 'type','Spearman');
        ws(ii) = nnz(mm);
    end
    keepS = isfinite(rs) & ws > 0;   rs = rs(keepS);  ws = ws(keepS);
    rhoStrat = sum(rs.*ws) / max(sum(ws), eps);
    nSessAgree = nnz(sign(rs) == sign(rhoStrat));

    % --- POWER-PARTIALLED rho: what survives once signal amplitude is removed ------------------
    % log(pre-trial variance) is the gain axis. Absolute delta partials to ~0 here because it IS
    % power; anything that survives is carrying information beyond loudness.
    lgP = log(max(T.PVv(ok), eps));
    if strcmp(MK{k,1},'PVv')       % partialling pre-var on itself is degenerate, not a result
        rhoPow = NaN; pPow = NaN; rhoPowC = NaN; pPowC = NaN;
    else
        [rhoPow,  pPow ] = partialcorr(abs(y),  x, lgP, 'type','Spearman');
        [rhoPowC, pPowC] = partialcorr(abs(yp), x, lgP, 'type','Spearman');
    end

    % --- binned SD curve + Brown-Forsythe ------------------------------------------------------
    g   = local_qbin(x, STV_NBIN);
    sdB = arrayfun(@(b) std(y(g==b), 'omitnan'),  1:STV_NBIN);
    sdP = arrayfun(@(b) std(yp(g==b),'omitnan'),  1:STV_NBIN);
    bf  = local_bftest(y,  g);
    bfP = local_bftest(yp, g);
    trend  = corr((1:STV_NBIN).', sdB(:), 'type','Spearman');
    trendP = corr((1:STV_NBIN).', sdP(:), 'type','Spearman');

    % --- effect size: SD(top bin)/SD(bottom bin) with a bootstrap CI ---------------------------
    rat = sdB(end)/max(sdB(1),eps);
    bs  = nan(STV_NBOOT,1);
    nO  = numel(y);
    for b = 1:STV_NBOOT
        s  = randi(nO, nO, 1);
        gb = local_qbin(x(s), STV_NBIN);
        lo = std(y(s(gb==1)),'omitnan');  hi = std(y(s(gb==STV_NBIN)),'omitnan');
        bs(b) = hi/max(lo,eps);
    end
    ci = quantile(bs, [0.025 0.975]);

    % --- claim check ---------------------------------------------------------------------------
    % A claim passes only if (a) the spread moves in the predicted direction, (b) it is
    % significant, and (c) it beats the stim-free control -- otherwise it is ongoing signal power.
    if claimDir(k) < 0
        moved = rho < 0 && p < 0.05 && ci(2) < 1;
    else
        moved = rho >= 0 || p >= 0.05;                 % "same or higher" -> only a DECREASE fails
    end
    beatsCtl = abs(rho) > abs(rhoP);
    if ~MK{k,3}
        verdict = 'CONFOUND - not interpreted';
    elseif moved && beatsCtl
        verdict = 'PASS';
    elseif moved
        verdict = 'pass, but NOT above stim-free control';
    else
        verdict = 'FAIL';
    end

    fprintf('%-22s %7d %9.3f %9.3g %8.3f %4d/%d | %8.2f %5.2f-%5.2f | %7.4f %6.2f  %s\n', ...
            MK{k,2}, nnz(ok), rho, p, rhoStrat, nSessAgree, numel(rs), ...
            rat, ci(1), ci(2), bf, trend, verdict);
    fprintf('%-22s %7s %9.3f %9.3g %8s %6s | %8s %11s | %7.4f %6.2f   <- STIM-FREE CONTROL\n', ...
            '  (pre-onset ctrl)','', rhoP, pP, '', '', '', '', bfP, trendP);
    if isfinite(rhoPow)
        fprintf('%-22s %7s %9.3f %9.3g %8s %6s | %8s %11s | %7s %6s   <- POWER-PARTIALLED (ctrl %+.3f)\n', ...
                '  (| log PreVar)','', rhoPow, pPow, '', '', '', '', '', '', rhoPowC);
    else
        fprintf('%-22s %7s %9s %9s %8s %6s | %8s %11s | %7s %6s   <- POWER-PARTIALLED n/a (marker IS the covariate)\n', ...
                '  (| log PreVar)','', '--','--','', '', '', '', '', '');
    end

    R(k).tag=MK{k,1}; R(k).name=MK{k,2}; R(k).adm=MK{k,3};
    R(k).rho=rho; R(k).p=p; R(k).rhoP=rhoP; R(k).pP=pP;
    R(k).sdB=sdB; R(k).sdP=sdP; R(k).bf=bf; R(k).bfP=bfP;
    R(k).trend=trend; R(k).trendP=trendP; R(k).ratio=rat; R(k).ci=ci;
    R(k).verdict=verdict; R(k).x=x; R(k).y=y; R(k).n=nnz(ok);
    R(k).rhoStrat=rhoStrat; R(k).rhoPerSess=rs; R(k).nSessAgree=nSessAgree;
    R(k).rhoPow=rhoPow; R(k).pPow=pPow; R(k).rhoPowC=rhoPowC; R(k).pPowC=pPowC;
    R(k).binMed = arrayfun(@(b) median(x(g==b),'omitnan'), 1:STV_NBIN);   % raw value per bin
    R(k).units = MK{k,4};
end

%% ================= (2b) MOTION: threshold split, because quantile bins are degenerate ===========
% RAW motion is threshold-shaped: median -0.196, q75 -0.158, and only ~3% of trials exceed z=1.5.
% Equal-count quartiles therefore put bins 1-3 inside a 0.10-wide sliver of motion and the "trend"
% across them is noise -- the real contrast is top-tail vs the rest. This uses the LOCKED project
% constant motThresh = 1.5 (root CLAUDE.md) so the split is not a free parameter chosen here.
if ~exist('STV_MOTTHR','var') || isempty(STV_MOTTHR), STV_MOTTHR = 1.5; end
hiM = T.MOT > STV_MOTTHR;
MTS = struct('thr',STV_MOTTHR,'nLo',nnz(~hiM),'nHi',nnz(hiM));
MTS.sdLo   = std(T.dev(~hiM),'omitnan');     MTS.sdHi   = std(T.dev(hiM),'omitnan');
MTS.sdLoP  = std(T.devPre(~hiM),'omitnan');  MTS.sdHiP  = std(T.devPre(hiM),'omitnan');
MTS.ratio  = MTS.sdHi/max(MTS.sdLo,eps);     MTS.ratioP = MTS.sdHiP/max(MTS.sdLoP,eps);
MTS.p  = local_bftest(T.dev,    double(hiM));
MTS.pP = local_bftest(T.devPre, double(hiM));
fprintf(['\nMOTION THRESHOLD SPLIT at z > %.1f   (n low %d, n high %d)\n' ...
         '   impulse response   SD %.3f -> %.3f   ratio %.2f   BF p %.3g\n' ...
         '   STIM-FREE control  SD %.3f -> %.3f   ratio %.2f   BF p %.3g\n'], ...
         STV_MOTTHR, MTS.nLo, MTS.nHi, MTS.sdLo, MTS.sdHi, MTS.ratio, MTS.p, ...
         MTS.sdLoP, MTS.sdHiP, MTS.ratioP, MTS.pP);
if MTS.ratioP <= MTS.ratio * 1.10
    fprintf(2,['   ** the STIM-FREE control compresses by the SAME factor (%.2f vs %.2f).\n' ...
               '      Motion reduces the variability of the ONGOING SIGNAL, and the impulse\n' ...
               '      response inherits it -- this is NOT a statement about stimulus processing. **\n'], ...
               MTS.ratioP, MTS.ratio);
end
MTS.perSess = nan(numel(unique(T.sess)),1);
uSm = unique(T.sess).';
for i = 1:numel(uSm)
    kk = T.sess == uSm(i);
    if nnz(kk & hiM) < 8, continue; end
    MTS.perSess(i) = std(T.dev(kk & hiM),'omitnan') / max(std(T.dev(kk & ~hiM),'omitnan'), eps);
end

%% ================= (3) per-session replication of the admissible markers ========================
uS = unique(T.sess).';
fprintf('\nPER-SESSION rho(|dev|, state)   [admissible markers only]\n');
fprintf('%-28s %6s', 'session', 'n');
adm = find([MK{:,3}]);
for k = adm, fprintf(' %14s', MK{k,2}); end
fprintf('\n');
PS_rho = nan(numel(uS), nMK);
for i = 1:numel(uS)
    m = T.sess == uS(i);
    fprintf('%-28s %6d', labels{uS(i)}, nnz(m));
    for k = 1:nMK
        st = T.([MK{k,1} 'z']);
        okk = m & isfinite(st) & isfinite(T.dev);
        if nnz(okk) < 20, continue; end
        [rr, pp] = corr(abs(T.dev(okk)), st(okk), 'type','Spearman');
        PS_rho(i,k) = rr;
        if ismember(k, adm)
            star = '';  if pp < 0.05, star = '*'; end
            fprintf(' %13s', sprintf('%+.3f%s', rr, star));
        end
    end
    fprintf('\n');
end

%% ================= (4) figures ===================================================================
if STV_PLOT
    C.stim=[0.80 0.15 0.15]; C.ctl=[0.55 0.55 0.55];
    % PLOT ONLY THE ADMISSIBLE MARKERS (user, 2026-08-12). Pre-trial variance and absolute delta
    % are still computed and printed above -- they belong in the record -- but they are not drawn,
    % because a panel of a quantity that IS signal power plotted against a spread invites exactly
    % the reading the confound forbids. Set STV_PLOTCONF=true to draw all four.
    if ~exist('STV_PLOTCONF','var') || isempty(STV_PLOTCONF), STV_PLOTCONF = false; end
    if STV_PLOTCONF, kShow = 1:nMK; else, kShow = find([MK{:,3}]); end
    nC = numel(kShow);
    f1 = figure('Color','w','Position',[40 40 460*nC 720], ...
                'Name','[STV] trial variability vs brain state');
    tl = tiledlayout(f1, 3, nC, 'Padding','compact','TileSpacing','compact');

    for ci = 1:nC
        k  = kShow(ci);
        gc = local_tern(MK{k,3}, [0 0 0], [0.55 0.55 0.55]);

        % row 1 -- the funnel: SIGNED dev vs state, with the binned +/-SD envelope
        ax = nexttile(tl, ci); hold(ax,'on'); box(ax,'on');
        scatter(ax, R(k).x, R(k).y, 5, [0.55 0.65 0.85], 'filled', 'MarkerFaceAlpha',0.30);
        bc = local_bincentres(R(k).x, STV_NBIN);
        plot(ax, bc,  R(k).sdB, '-o','Color',C.stim,'MarkerFaceColor',C.stim,'LineWidth',1.6,'MarkerSize',4);
        plot(ax, bc, -R(k).sdB, '-o','Color',C.stim,'MarkerFaceColor',C.stim,'LineWidth',1.6,'MarkerSize',4);
        yline(ax,0,'k:'); ylim(ax,[-4 4]); xlim(ax, quantile(R(k).x,[0.005 0.995]));
        xlabel(ax, sprintf('%s  (%s)', MK{k,2}, MK{k,4}));
        if ci==1, ylabel(ax,'signed dev (within-amp SD)'); end
        title(ax, sprintf('%s   n=%d', MK{k,2}, R(k).n), 'FontSize',9, 'Color',gc);

        % row 2 -- spread vs state, STIM against the STIM-FREE control
        ax = nexttile(tl, nC+ci); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
        % x placed at each bin's MEDIAN RAW VALUE, so the drop can be read against real units
        % ("SD falls between motion 0.2 and motion 2.5") rather than against a bin index.
        bm = R(k).binMed;
        plot(ax, bm, R(k).sdB, '-o','Color',C.stim,'MarkerFaceColor',C.stim, ...
             'LineWidth',1.8,'MarkerSize',5,'DisplayName','impulse response');
        plot(ax, bm, R(k).sdP, '--s','Color',C.ctl,'MarkerFaceColor',C.ctl, ...
             'LineWidth',1.4,'MarkerSize',4,'DisplayName','pre-onset (stim-free)');
        xticks(ax, round(bm,2,'significant'));
        xlim(ax, [min(bm) - 0.08*range(bm), max(bm) + 0.08*range(bm)]);
        xlabel(ax, sprintf('%s  (%s), bin median', MK{k,2}, MK{k,4}));
        if ci==1, ylabel(ax,'SD of dev'); legend(ax,'Location','best','Box','off','FontSize',7); end
        title(ax, sprintf('BF p = %.4g (ctrl %.4g)\ntrend %+.2f (ctrl %+.2f)', ...
              R(k).bf, R(k).bfP, R(k).trend, R(k).trendP), 'FontSize',8.5, 'Color',gc);

        % row 3 -- effect size with bootstrap CI, against the claim's prediction
        ax = nexttile(tl, 2*nC+ci); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
        % STIM bar beside its STIM-FREE control bar -- the comparison the verdict rests on
        bar(ax, 1, R(k).ratio, 0.5, 'FaceColor', C.stim, 'EdgeColor','none');
        errorbar(ax, 1, R(k).ratio, R(k).ratio-R(k).ci(1), R(k).ci(2)-R(k).ratio, ...
                 'k','LineStyle','none','LineWidth',1.2,'CapSize',10);
        ratP = R(k).sdP(end)/max(R(k).sdP(1),eps);
        bar(ax, 2, ratP, 0.5, 'FaceColor', C.ctl, 'EdgeColor','none');
        yline(ax, 1, 'k-','LineWidth',1);
        if claimDir(k) < 0, ptxt = 'claim: < 1'; else, ptxt = 'claim: \geq 1'; end
        xticks(ax,[1 2]); xticklabels(ax,{sprintf('stim %.2f',R(k).ratio), sprintf('ctrl %.2f',ratP)});
        xlim(ax,[0.4 2.6]);
        if ci==1, ylabel(ax,'SD ratio  top / bottom bin'); end
        title(ax, sprintf(['%s   strat \\rho %+.3f (%d/%d sess)   ' ...
              '\\rho|power %+.3f (ctrl %+.3f)\n%s'], ...
              ptxt, R(k).rhoStrat, R(k).nSessAgree, numel(R(k).rhoPerSess), ...
              R(k).rhoPow, R(k).rhoPowC, R(k).verdict), 'FontSize',8.5, 'Color',gc);
    end

    sgtitle(f1, sprintf(['Trial-to-trial VARIABILITY of the impulse response vs brain state   ' ...
        '(%d trials, %d sessions, state window [%.2f %.2f] s)\n' ...
        'RED = impulse response      GREY = SAME window, NO STIMULUS (the control)\n' ...
        'If grey tracks red, the state changes the ONGOING signal, not stimulus processing.'], ...
        numel(T.dev), numel(uS), stWin(1), stWin(2)), 'FontWeight','bold','FontSize',10);

    exportgraphics(f1, fullfile(STV_FIGDIR,'stv_claim.png'), 'Resolution',300);

    % ---- per-session replication -----------------------------------------------------------------
    f2 = figure('Color','w','Position',[60 60 640 420],'Name','[STV] per-session');
    ax = axes(f2); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    cols = lines(nMK);
    for k = 1:nMK
        if ~MK{k,3}, continue; end
        plot(ax, 1:numel(uS), PS_rho(:,k), '-o','Color',cols(k,:),'MarkerFaceColor',cols(k,:), ...
             'LineWidth',1.6,'MarkerSize',5,'DisplayName',MK{k,2});
    end
    hz = yline(ax,0,'k-'); hz.HandleVisibility = 'off';
    xticks(ax,1:numel(uS)); xticklabels(ax, labels(uS)); xtickangle(ax,20);
    ylabel(ax,'\rho( |dev| , state )'); ylim(ax,[-0.5 0.5]);
    legend(ax,'Location','best','Box','off','FontSize',8);
    title(ax, ['Per-session replication, ADMISSIBLE markers only' newline ...
               'H1 needs Motion BELOW zero in every session'], 'FontWeight','bold','FontSize',10);
    exportgraphics(f2, fullfile(STV_FIGDIR,'stv_persession.png'), 'Resolution',300);
end

STV = struct('T',T,'R',R,'labels',{labels},'PS_rho',PS_rho,'stWin',stWin,'nbin',STV_NBIN, ...
             'motSplit',MTS,'zstate',STV_ZSTATE);
fprintf('\n[STV] figures -> %s\n[STV] struct: STV\n', STV_FIGDIR);

%% ================================= local functions ==============================================
function p = local_bftest(y, g)
%LOCAL_BFTEST  Brown-Forsythe (median-centred Levene, so no normality assumption). NaN if undefined.
p = NaN;
try
    p = vartestn(y, g, 'TestType','BrownForsythe', 'Display','off');
catch
end
end

function [dpa, dpr] = local_delta(seg, fs)
%LOCAL_DELTA  absolute 1-4 Hz power and its RELATIVE share of 0.5-30 Hz, per trial (rows of seg).
% Mean-removed + Hann so the DC term and edge leakage do not land in the delta band.
n = size(seg,2);
w = hann(n).';
x = seg - mean(seg, 2, 'omitnan');
x(~isfinite(x)) = 0;
X = abs(fft(x .* w, [], 2)).^2;
f = (0:n-1) * (fs/n);
half = 1:floor(n/2);
f = f(half);  X = X(:,half);
bD = f >= 1   & f <= 4;
bT = f >= 0.5 & f <= 30;
dpa = sum(X(:,bD), 2);
dpr = dpa ./ max(sum(X(:,bT), 2), eps);
end

function z = local_zby(x, g)
x = double(x(:));  z = nan(size(x));
for u = unique(g(:)).'
    m = g(:) == u;
    s = std(x(m),'omitnan');
    if ~isfinite(s) || s == 0, z(m) = 0; else, z(m) = (x(m) - mean(x(m),'omitnan'))/s; end
end
end

function g = local_qbin(x, nb)
% equal-COUNT bins, so every bin's SD is estimated from the same number of trials
q = quantile(x, linspace(0,1,nb+1));  q(1) = -inf; q(end) = inf;
[~,~,g] = histcounts(x, q);
g = max(min(g, nb), 1);
end

function c = local_bincentres(x, nb)
q = quantile(x, linspace(0,1,nb+1));
c = (q(1:end-1) + q(2:end)) / 2;
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
