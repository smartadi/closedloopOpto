%% imp_state_xsess_plot.m -- the §17c [STATEDEP] "Local dip vs brain state" figure, COMBINED across sessions.
%
% WHY THIS EXISTS. `imp_state_xsess.m` answers the cross-session question as three stacked numeric
% tables (per-session / pooled-blocked / Stouffer). That is the statistically complete form and it is
% unreadable at a glance -- you cannot see from it whether the sessions AGREE, which is the entire
% question. This script answers the same question in the form §17c already uses: the single-trial
% Local-dip-vs-state scatter, with every session on the same axes.
%
% It does NOT replace the statistics. Every rho printed here is the same partial Spearman
% `imp_state_xsess` computes; this is the visual presentation of it. Where the two disagree, the
% table is right and this script has a bug.
%
% WHAT IS PLOTTED
%   Fig 1  one panel per DRAWN state (default Motion + Rel-delta): pooled single-trial cloud,
%          COLOURED BY SESSION.
%          Thin coloured line = that session's own fit. Thick black line = pooled fit.
%          Divergent thin lines = the sessions disagree, and no combined number should be quoted.
%   Fig 2  forest plot: per-session rho +/- 95% CI per state, with the pooled rho as a diamond.
%          This is the "do they agree" read, and it is the panel to look at first.
%
% POOLING IS LEGITIMATE because each DV is z-scored WITHIN AMPLITUDE within its own session
% (imp_statedep_trials), so session and dose means are already removed. State markers enter the
% STATISTICS z-scored WITHIN SESSION for the same reason -- raw units differ between sessions and
% would otherwise smear the cloud horizontally. The DISPLAY units are chosen per state (XSP_XFORM)
% and are monotone re-scalings only, so they cannot move a per-session rho.
%
% ADMISSIBILITY (RESEARCH 2026-07-01/02): pre-var and absolute delta are SIGNAL-POWER CONFOUNDS --
% they scale with signal power, which the DV magnitude also scales with. As of 2026-08-10 they are
% NO LONGER PLOTTED (they are still computed and printed): showing them beside the real result, even
% in amber, invited the reading the amber existed to prevent. Interpret MOTION and RELATIVE DELTA.
%
% SESSION IDENTITY: index + shade ("Session 1..n"), never a date string, and the shades are the same
% paperStyle across-sessions ramp Fig 2 uses -- so session k is the same colour in both figures. The
% index -> session mapping is printed to the console for the caption.
%
% USAGE
%   1) load_experiments.m
%   2) imp_run_all  (or ols_tf_pipeline.m with RUN_ALLSESS = true)
%   3) imp_state_xsess_plot
%
%   XSP_LAYOUT = 'rows';  imp_state_xsess_plot     % one session per row, CLICKABLE trial inspector
%   XSP_DV     = 'L1DEVz';                         % unpredictability DV (see RESEARCH 2026-08-10)
%   XSP_STATES = {'MOT','PVv','DPa','DPr'};        % put the power-confound panels back
%   XSP_XFORM  = struct('MOT','rank','DPr','raw','PVv','z','DPa','z');   % display units per state
% -------------------------------------------------------------------------------------------------

if ~exist('ALLSESS','var') || isempty(ALLSESS)
    error('XSPLOT:noALLSESS', ['[XSPLOT] no ALLSESS in the workspace.\n' ...
        'Run ols_tf_pipeline.m with RUN_ALLSESS = true first, e.g.\n' ...
        '    OLS_OVERRIDE = struct(''RUN_ALLSESS'',true,''allSelExp'',[3 1 2]);\n' ...
        '    ols_tf_pipeline\n' ...
        'See imp_state_xsess.m for the CONFIRM-gate caveat if the run does not reach §18.']);
end
nS = numel(ALLSESS);
have = cellfun(@(S) isfield(S,'ST') && ~isempty(S.ST) && ~isempty(S.ST.LD), ALLSESS);
if ~all(have)
    error('XSPLOT:noST', ['[XSPLOT] ALLSESS{%s} carry no per-trial ST payload -- produced by an older ' ...
        'local_stimblind_session. Re-run §18.'], mat2str(find(~have)));
end

if ~exist('XSP_DV','var')      || isempty(XSP_DV),      XSP_DV      = 'DVz';   end  % 'DVz'|'GAINz'|'L1DEVz'
if ~exist('XSP_PRIMARY','var') || isempty(XSP_PRIMARY)
    XSP_PRIMARY = find(cellfun(@(S) contains(S.label,'AL_0033'), ALLSESS), 1);
    if isempty(XSP_PRIMARY), XSP_PRIMARY = 1; end
end
dvName = struct('DVz','DIPmean (signed)','GAINz','GAIN (template)','L1DEVz','L1DEV (unsigned)');
dvLab  = struct('DVz','Local dip dev (signed, z)','GAINz','template gain (z)','L1DEVz','L1 deviation (z)');

% ---- WHICH STATES ARE DRAWN (user, 2026-08-10) --------------------------------------------------
% Pre-var and absolute pre-delta are NOT drawn any more. They are the signal-power confounds
% retracted on 2026-07-01/02: they scale with signal power, which the DV magnitude also scales with,
% so a positive rho there is close to tautological. Drawing them in amber next to the real result
% invited exactly the reading the amber was meant to prevent. They are still COMPUTED and still
% PRINTED in the console table below, marked -- the record is kept, it just is not a panel.
% Set XSP_STATES = {'MOT','PVv','DPa','DPr'} to put them back on the figure.
if ~exist('XSP_STATES','var') || isempty(XSP_STATES), XSP_STATES = {'MOT','DPr'}; end

% ---- LAYOUT (user, 2026-08-10) ------------------------------------------------------------------
% 'combined'  the default: every session on ONE pair of axes, which answers "do they agree".
% 'rows'      ONE SESSION PER ROW, states across columns, and the points are CLICKABLE. Use this
%             when a pooled cloud looks wrong and you need to know whether it is the analysis or the
%             data -- a pooled scatter can only tell you a correlation is odd, never which trial made
%             it odd. Click any point and you get that trial: actual vs its stim-blind EXPECTED
%             response, the LOCAL RESIDUAL that the DV is computed from, and the raw trace behind
%             whichever STATE panel you clicked (motion trace for Motion, the ipsi trace with the
%             delta window shaded for Rel-delta), plus where that trial sits in the session's own
%             distribution of the state. Rows mode also prints a MOTION DIMENSION AUDIT (below).
if ~exist('XSP_LAYOUT','var') || isempty(XSP_LAYOUT), XSP_LAYOUT = 'combined'; end

% ---- X-AXIS UNITS PER STATE -- DISPLAY ONLY (user, 2026-08-10) ----------------------------------
% 'rank'  within-session percentile (0-100). For MOTION: the raw marker is extremely heavy-tailed
%         (a handful of trials near 15, everything else bunched at the bottom), so on a linear axis
%         the cloud is a wall at x~0 with a few far-right outliers and nothing is readable. Ranking
%         is the RIGHT fix rather than a cosmetic one: the statistic reported here is a partial
%         SPEARMAN, which is computed on ranks, so the percentile axis shows precisely what the test
%         sees. Nothing is hidden -- an outlier trial is still the rightmost point, it just no longer
%         owns 90% of the axis.
% 'raw'   native units, no z. For REL-DELTA: it is already a RATIO (delta power / 0.5-30 Hz power),
%         i.e. dimensionless and directly comparable between sessions, so z-scoring it destroyed a
%         meaningful unit and replaced it with "SDs from this session's mean", which is what made
%         the panel hard to read.
% 'z'     z within session (the old behaviour, kept for the power-confound markers).
% INVARIANCE, the reason this is safe: within a session all three are MONOTONE transforms of each
% other, so every PER-SESSION rho and every per-session CI in the forest is bit-identical whichever
% is chosen. Only the pooled least-squares LINE moves (it is a visual summary, not the statistic);
% the pooled rho printed and diamonded is still computed on the z values, exactly as imp_state_xsess
% does it, so the two scripts cannot drift apart.
if ~exist('XSP_XFORM','var') || isempty(XSP_XFORM)
    XSP_XFORM = struct('MOT','rank', 'PVv','z', 'DPa','z', 'DPr','raw');
end

% state code -> display name, admissible?, class
STATES = {'MOT','Motion',            true , 'power-indep'
          'PVv','Pre-var',           false, 'POWER-CONFOUND'
          'DPa','Pre-\delta (abs)',  false, 'POWER-CONFOUND'
          'DPr','Rel-\delta',        true , 'power-indep'};
nSt = size(STATES,1);
zf  = @(x)(x-mean(x,'omitnan'))./max(std(x,'omitnan'),eps);
sIdx = cellfun(@(c) find(strcmp(STATES(:,1),c),1), XSP_STATES(:).', 'UniformOutput',false);
if any(cellfun(@isempty, sIdx))
    error('XSPLOT:badState','XSP_STATES entry ''%s'' is not a state code -- use any of: %s.', ...
          XSP_STATES{find(cellfun(@isempty,sIdx),1)}, strjoin(STATES(:,1).', ', '));
end
sIdx = cell2mat(sIdx);

% ---- gather: DV + PRE + per-session states (G = z, for STATS;  Gx = display units) ---------------
G = struct('sess',[],'DV',[],'PRE',[]);  Gx = struct();
for s = 1:nSt, G.(STATES{s,1}) = [];  Gx.(STATES{s,1}) = []; end
labels = cell(nS,1);  nTr = zeros(nS,1);
for si = 1:nS
    ST = ALLSESS{si}.ST;  n = numel(ST.LD);  labels{si} = ALLSESS{si}.label;  nTr(si) = n;
    G.sess = [G.sess; si*ones(n,1)];
    G.DV   = [G.DV;   ST.(XSP_DV)(:)];
    G.PRE  = [G.PRE;  ST.PRE(:)];
    for s = 1:nSt
        raw = ST.(STATES{s,1})(:);
        if all(~isfinite(raw)), v = nan(n,1);  vx = nan(n,1);        % all-NaN state stays NaN
        else,                   v = zf(raw);   vx = xsp_disp(raw, XSP_XFORM.(STATES{s,1})); end
        G.(STATES{s,1})  = [G.(STATES{s,1});  v];                    % z WITHIN session -> statistics
        Gx.(STATES{s,1}) = [Gx.(STATES{s,1}); vx];                   % display units    -> axes only
    end
end
% Session identity is carried by INDEX + SHADE, not by a date string (same policy as Fig 2, 2026-08-10):
% the index means the same session and the same colour in every panel, which a truncated label does not.
sessName = arrayfun(@(k) sprintf('Session %d',k), 1:nS, 'UniformOutput',false);
Dum = zeros(numel(G.sess), nS-1);                       % session dummies for the pooled-blocked partial
for si = 1:nS-1, Dum(:,si) = double(G.sess==si); end

% ---- per-session and pooled partial Spearman (identical definition to imp_state_xsess) ----------
rho = nan(nSt,nS);  lo = nan(nSt,nS);  hi = nan(nSt,nS);  nEff = zeros(nSt,nS);
rhoPool = nan(nSt,1);  pPool = nan(nSt,1);
for s = 1:nSt
    stAll = G.(STATES{s,1});
    for si = 1:nS
        m = G.sess==si & isfinite(G.DV) & isfinite(stAll) & isfinite(G.PRE);
        if nnz(m) > 10
            rho(s,si) = partialcorr(G.DV(m), stAll(m), G.PRE(m), 'type','Spearman');
            nEff(s,si) = nnz(m);
            z = atanh(rho(s,si));  se = 1/sqrt(max(nnz(m)-3,1));   % Fisher-z 95% CI
            lo(s,si) = tanh(z-1.96*se);  hi(s,si) = tanh(z+1.96*se);
        end
    end
    m = isfinite(G.DV) & isfinite(stAll) & isfinite(G.PRE);
    if nnz(m) > 10
        [rhoPool(s), pPool(s)] = partialcorr(G.DV(m), stAll(m), [G.PRE(m) Dum(m,:)], 'type','Spearman');
    end
end

fprintf('\n=========== [XSPLOT] Local-dip (%s) vs state across %d sessions ===========\n', dvName.(XSP_DV), nS);
fprintf('  partial Spearman, dev_pre controlled; pooled additionally blocks session dummies.\n');
% The figures say "Session k". Print the mapping here -- it is what the caption needs, and it is the
% only place the full session identity now appears.
fprintf('  session index -> session (this mapping is the figure legend):\n');
for si = 1:nS, fprintf('     Session %d = %s  (n=%d trials)\n', si, labels{si}, nTr(si)); end
fprintf('  %-18s %10s | %s\n','state','pooled', strjoin(cellfun(@(k)sprintf('%14s',sprintf('Session %d',k)), num2cell(1:nS),'UniformOutput',false),' '));
for s = 1:nSt
    fprintf('  %-18s %+10.3f | ', regexprep(STATES{s,2},'\\',''), rhoPool(s));
    fprintf('%+14.3f ', rho(s,:));
    if ~STATES{s,3}, fprintf('   <- %s, NOT a finding', STATES{s,4}); end
    fprintf('\n');
end
agree = arrayfun(@(s) all(sign(rho(s,isfinite(rho(s,:))))==sign(rhoPool(s))), 1:nSt);
fprintf('  sign agreement across sessions: %s\n', strjoin(cellfun(@(a,b) sprintf('%s=%s',regexprep(a,'\\',''), ...
        ternstr_xsp(b,'YES','NO')), STATES(:,2).', num2cell(agree), 'UniformOutput',false), '  '));

% ---- Fig 1: pooled scatter, one panel per DRAWN state, coloured by session ----------------------
% Colours are the Fig-2 across-sessions ramp (paperStyle sessGrad, navy -> cyan): same session index
% -> same shade in the TF panels and here, so identity carries between figures.
PS   = paperStyle;
cols = PS.sessGrad(nS);
nDraw = numel(sIdx);
if strcmpi(XSP_LAYOUT,'combined')
fig1 = figure('Color','w','Name','[XSPLOT] Local dip vs brain state — all sessions', ...
              'Position',[30 90 max(420,380*nDraw) 380]);
for j = 1:nDraw
    s = sIdx(j);
    ax = subplot(1,nDraw,j); hold(ax,'on'); box(ax,'on');
    stAll = Gx.(STATES{s,1});                       % DISPLAY units (see XSP_XFORM)
    for si = 1:nS
        m = G.sess==si & isfinite(G.DV) & isfinite(stAll);
        if nnz(m) < 3, continue; end
        scatter(ax, stAll(m), G.DV(m), 10, cols(si,:), 'filled', 'MarkerFaceAlpha',0.35, ...
                'DisplayName',sprintf('%s (n=%d)',sessName{si},nnz(m)));
        pc = polyfit(stAll(m), G.DV(m), 1);  xx = linspace(min(stAll(m)),max(stAll(m)),2);
        plot(ax, xx, polyval(pc,xx), '-', 'Color',cols(si,:), 'LineWidth',1.1, 'HandleVisibility','off');
    end
    m = isfinite(G.DV) & isfinite(stAll);
    if nnz(m) > 2
        pc = polyfit(stAll(m), G.DV(m), 1);  xx = linspace(prctile(stAll(m),1),prctile(stAll(m),99),2);
        plot(ax, xx, polyval(pc,xx), 'k-', 'LineWidth',2.2, 'DisplayName','pooled fit');
    end
    yline(ax,0,'k:','HandleVisibility','off');
    tcol = [0 0 0];  if ~STATES{s,3}, tcol = [.6 .3 0]; end
    title(ax, sprintf('%s   \\rho_{pool}=%+.2f', STATES{s,2}, rhoPool(s)), 'FontSize',9,'FontWeight','bold','Color',tcol);
    xlabel(ax, xsp_xlabel(STATES{s,1}, STATES{s,2}, XSP_XFORM.(STATES{s,1})));
    if ~STATES{s,3}
        text(ax, 0.98, 0.02, STATES{s,4}, 'Units','normalized','HorizontalAlignment','right', ...
             'FontSize',7,'Color',[.6 .3 0]);
    end
    if j==1, ylabel(ax, dvLab.(XSP_DV)); legend(ax,'Location','southwest','FontSize',6); end
end
sgtitle(fig1, sprintf(['XSPLOT  —  single-trial %s vs brain state, %d sessions on shared axes  ' ...
    '(thin = per-session fit, thick black = pooled;  DV z-within-amp)'], dvName.(XSP_DV), nS), ...
    'FontWeight','bold','FontSize',9);

else   % ===================== XSP_LAYOUT = 'rows':  one session per ROW, CLICKABLE ================
% Each session gets its own row and its own axes, so nothing is superimposed and a session with a
% degenerate marker (all-NaN motion, a single dominating outlier, a constant) is visible AS ITSELF
% instead of being absorbed into a pooled cloud. Every point is a trial and every point is clickable.
%
% MOTION DIMENSION AUDIT (printed first, on purpose). The MOT scalar is
%   sum(|motz(onset-2s : onset+0.5s)|)
% indexed with IMAGING-FRAME indices into a motion vector. If motz is on a different cadence or a
% different length from the imaging frames, that indexing silently reads the wrong samples -- no
% error, no NaN, just a number that is not motion at that trial. The audit prints, per session, the
% lengths being indexed against each other and how many trials fell in range, so a cadence mismatch
% shows up as a number rather than as a hunch about a scatter plot.
fprintf('\n  ---- MOTION dimension audit (rows mode) ----------------------------------------\n');
fprintf('  %-10s %10s %10s %8s %10s %12s %10s\n', ...
        'session','numel(motz)','nFrames','Fs','win(smp)','trials finite','MOT range');
for si = 1:nS
    Sv = ALLSESS{si};  STv = Sv.ST;
    nmz = numel(xsp_getf(Sv,'motz',[]));   nfr = xsp_getf(Sv,'nF',NaN);   fsv = xsp_getf(Sv,'Fs',NaN);
    wsm = round(2*fsv) + round(0.5*fsv) + 1;
    fin = nnz(isfinite(STv.MOT));
    if fin > 0, rngs = sprintf('%.3g..%.3g', min(STv.MOT), max(STv.MOT)); else, rngs = 'all NaN'; end
    fprintf('  Session %-2d %10d %10s %8.2f %10s %6d/%-5d %10s\n', si, nmz, ...
            xsp_num2s(nfr), fsv, xsp_num2s(wsm), fin, numel(STv.MOT), rngs);
    if nmz > 0 && isfinite(nfr) && abs(nmz - nfr)/max(nfr,1) > 0.02
        fprintf(2,['     ** numel(motz)=%d vs nFrames=%d differ by >2%%. The MOT window is indexed with\n' ...
                   '        FRAME indices, so unless these are the same cadence this session''s motion\n' ...
                   '        scalar is reading the wrong samples. Check before interpreting its rho. **\n'], nmz, nfr);
    end
    if fin < numel(STv.MOT)
        fprintf('     (%d trial(s) NaN -- window fell outside the motion trace; they drop out of rho)\n', ...
                numel(STv.MOT) - fin);
    end
end

fig1 = figure('Color','w','Name','[XSPLOT] per-session rows — CLICK a point to open that trial', ...
              'Position',[20 40 max(460,420*nDraw) min(1000, 240*nS + 90)]);
axG = gobjects(nS, nDraw);
for si = 1:nS
    for j = 1:nDraw
        s = sIdx(j);
        ax = subplot(nS, nDraw, (si-1)*nDraw + j);  hold(ax,'on');  box(ax,'on');
        axG(si,j) = ax;
        stAll = Gx.(STATES{s,1});
        m = G.sess==si & isfinite(G.DV) & isfinite(stAll);
        if nnz(m) >= 3
            scatter(ax, stAll(m), G.DV(m), 14, cols(si,:), 'filled', 'MarkerFaceAlpha',0.45);
            pc = polyfit(stAll(m), G.DV(m), 1);  xx = linspace(min(stAll(m)),max(stAll(m)),2);
            plot(ax, xx, polyval(pc,xx), '-', 'Color',cols(si,:), 'LineWidth',1.6);
        else
            text(ax, 0.5, 0.5, 'no usable trials', 'Units','normalized', 'HorizontalAlignment','center', ...
                 'Color',[.6 .3 .3], 'FontSize',9);
        end
        yline(ax,0,'k:');
        if isfinite(rho(s,si))
            title(ax, sprintf('%s — %s:  \\rho=%+.3f [%+.2f, %+.2f], n=%d', sessName{si}, STATES{s,2}, ...
                  rho(s,si), lo(s,si), hi(s,si), nEff(s,si)), 'FontSize',8,'FontWeight','bold');
        else
            title(ax, sprintf('%s — %s:  \\rho undefined', sessName{si}, STATES{s,2}), ...
                  'FontSize',8,'FontWeight','bold','Color',[.6 .3 .3]);
        end
        if si==nS, xlabel(ax, xsp_xlabel(STATES{s,1}, STATES{s,2}, XSP_XFORM.(STATES{s,1}))); end
        if j==1,   ylabel(ax, dvLab.(XSP_DV)); end
    end
end
sgtitle(fig1, sprintf(['XSPLOT rows  —  %s vs state, one session per row.  ' ...
    'CLICK any point: that trial''s actual vs expected, its residual, and the raw state trace behind it.'], ...
    dvName.(XSP_DV)), 'FontWeight','bold','FontSize',9);

% Payload for the click callback. Everything the inspector draws is carried here, so the callback
% never reaches into the base workspace (which would break the moment the figure outlives the run).
XSPC = struct('axG',axG, 'nS',nS, 'nDraw',nDraw, 'sIdx',sIdx, 'STATES',{STATES}, ...
              'sessName',{sessName}, 'labels',{labels}, 'cols',cols, 'ALLSESS',{ALLSESS}, ...
              'sess',G.sess, 'DV',G.DV, 'Gx',Gx, 'dvLab',dvLab.(XSP_DV), 'dvName',dvName.(XSP_DV), ...
              'xform',XSP_XFORM);
guidata(fig1, XSPC);
set(fig1, 'WindowButtonDownFcn', @xsp_rows_click);
fprintf('\n  [XSPLOT rows] click any point to open that trial (actual / expected / residual / state).\n');
end

% ---- Fig 2: forest plot -- per-session rho +/- 95% CI vs the pooled value -----------------------
fig2 = figure('Color','w','Name','[XSPLOT] per-session rho vs pooled (forest)','Position',[60 60 780 420]);
ax = axes(fig2); hold(ax,'on'); box(ax,'on');
yt = [];  ytl = {};  row = 0;
for j = 1:nDraw
    s = sIdx(j);
    for si = 1:nS
        if ~isfinite(rho(s,si)), continue; end
        row = row + 1;
        plot(ax, [lo(s,si) hi(s,si)], [row row], '-', 'Color',cols(si,:), 'LineWidth',1.4);
        plot(ax, rho(s,si), row, 'o', 'Color',cols(si,:), 'MarkerFaceColor',cols(si,:), 'MarkerSize',5);
        yt(end+1) = row; %#ok<SAGROW>
        ytl{end+1} = sprintf('%s — %s (n=%d)', regexprep(STATES{s,2},'\\',''), sessName{si}, nEff(s,si)); %#ok<SAGROW>
    end
    if isfinite(rhoPool(s))
        row = row + 1;
        plot(ax, rhoPool(s), row, 'd', 'Color','k', 'MarkerFaceColor','k', 'MarkerSize',7);
        yt(end+1) = row; %#ok<SAGROW>
        ytl{end+1} = sprintf('%s — POOLED (p=%.3g)', regexprep(STATES{s,2},'\\',''), pPool(s)); %#ok<SAGROW>
    end
    row = row + 0.8;
end
xline(ax, 0, 'k-', 'LineWidth',1.2);
set(ax,'YTick',yt,'YTickLabel',ytl,'FontSize',7,'YDir','reverse');
ylim(ax,[0 row+1]);  xlabel(ax,'partial Spearman \rho (dev\_pre controlled)');
title(ax, sprintf('%s — per-session \\rho with 95%% CI; diamond = pooled (session-blocked)', dvName.(XSP_DV)), ...
      'FontSize',9,'FontWeight','bold');
grid(ax,'on');

XSPLOT = struct('dv',XSP_DV,'states',{STATES(:,1).'},'drawn',{XSP_STATES},'xform',XSP_XFORM, ...
                'labels',{labels},'sessName',{sessName},'nTrials',nTr, ...
                'rho',rho,'ciLo',lo,'ciHi',hi,'nEff',nEff,'rhoPooled',rhoPool,'pPooled',pPool, ...
                'signAgree',agree,'primary',XSP_PRIMARY);
fprintf('  -> XSPLOT struct + 2 figures. Read Fig 2 first: if a state''s per-session CIs do not overlap\n');
fprintf('     each other, the pooled number is describing a disagreement, not an effect.\n');
fprintf('     Drawn: %s. %s computed and tabled above but NOT plotted (power confounds).\n', ...
        strjoin(XSP_STATES,' + '), strjoin(setdiff(STATES(:,1).', XSP_STATES),' + '));

function s = ternstr_xsp(c, a, b)
if c, s = a; else, s = b; end
end

function v = xsp_getf(S, f, d)
if isstruct(S) && isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = d; end
end

function s = xsp_num2s(v)
if isfinite(v), s = sprintf('%d', round(v)); else, s = '?'; end
end

function xsp_rows_click(fig, ~)
% ROWS-MODE INSPECTOR. Click a point in any panel -> open that ONE trial, four ways:
%   (1) ACTUAL vs EXPECTED   the trial's ipsi trace against the stim-blind prediction. If these
%                            already diverge before onset, the trial's DV is a prediction failure,
%                            not a stim effect -- which is exactly what PRE partials out, and why
%                            you want to SEE it rather than trust the partial.
%   (2) LOCAL RESIDUAL       actual - expected, i.e. the quantity the DV is a reduction of, with the
%                            dip window marked. The amp-mean residual is drawn behind it so
%                            "deviation from the amp template" is visible as a distance.
%   (3) STATE RAW TRACE      whichever state panel was clicked: the MOTION trace for Motion (with the
%                            [-2,+0.5] s integration window shaded), or the ipsi trace with the
%                            [-1,+0.5] s spectral window shaded for Rel-delta. This is the panel that
%                            answers "is this scalar measuring what I think it is".
%   (4) STATE DISTRIBUTION   where this trial sits among that session's trials.
% The window constants mirror imp_statedep_trials.m (motion [-2,+0.5] s, var/delta [-1,+0.5] s). They
% are duplicated here for DRAWING only -- if they ever change there, change them here too or the
% shading will lie about what was integrated.
C = guidata(fig);  ax = get(fig,'CurrentAxes');
[r, c] = find(C.axG == ax, 1);
if isempty(r), return; end
s = C.sIdx(c);  code = C.STATES{s,1};  si = r;

cp = get(ax,'CurrentPoint');  xc = cp(1,1);  yc = cp(1,2);
loc = find(C.sess == si);                       % rows of the pooled vectors owned by this session
x = C.Gx.(code)(loc);  y = C.DV(loc);
ok = isfinite(x) & isfinite(y);
xl = get(ax,'XLim');  yl = get(ax,'YLim');
d = ((x-xc)/max(diff(xl),eps)).^2 + ((y-yc)/max(diff(yl),eps)).^2;  d(~ok) = inf;
[dm, kLoc] = min(d);  if ~isfinite(dm), return; end

S  = C.ALLSESS{si};  ST = S.ST;
ai = ST.AMPi(kLoc);  tj = ST.TRi(kLoc);         % amp index + trial index within that amp
A  = ST.trA{ai};  YG = ST.trG{ai};  RL = ST.trL{ai};
if isempty(A) || tj > size(A,2)
    warning('[XSPLOT] %s trial %d: no stored traces (wantTraces was false).', C.sessName{si}, kLoc);  return
end
Fs   = xsp_getf(S,'Fs',NaN);
rel  = xsp_getf(S,'rel',[]);
if ~isempty(rel) && isfinite(Fs), tt = rel(:)/Fs;  xlabS = 't re onset (s)';
else,                             tt = (1:size(A,1)).';  xlabS = 'sample in window'; end
dc = [];  ic = xsp_getf(S,'inhCols',{});
if iscell(ic) && numel(ic) >= ai, dc = ic{ai}; end
if isempty(dc), dc = 1:size(A,1); end
amps = xsp_getf(S,'amps',nan(ai,1));
ampv = NaN;  if numel(amps) >= ai, ampv = amps(ai); end

figure('Color','w','Position',[180 90 1000 620], 'Name', ...
    sprintf('[XSPLOT] %s — %.2f V, trial %d  (%s)', C.sessName{si}, ampv, tj, regexprep(C.STATES{s,2},'\\','')));

% (1) actual vs expected -------------------------------------------------------------------------
a1 = subplot(2,2,1); hold(a1,'on'); box(a1,'on');
plot(a1, tt, mean(A,2,'omitnan'),  '-','Color',[.65 .65 .65],'LineWidth',1.1,'DisplayName','amp-avg actual');
plot(a1, tt, A(:,tj),  'k-','LineWidth',1.9,'DisplayName','actual (this trial)');
plot(a1, tt, YG(:,tj), '-','Color',[.85 .2 .2],'LineWidth',1.6,'DisplayName','expected (stim-blind)');
xline(a1,0,'k:','HandleVisibility','off'); yline(a1,0,'k:','HandleVisibility','off');
legend(a1,'Location','best','FontSize',7);  ylabel(a1,'ipsi \DeltaF/F %');  xlabel(a1,xlabS);
title(a1, sprintf('%s — %.2f V, trial %d', C.sessName{si}, ampv, tj), 'FontSize',9,'FontWeight','bold');

% (2) local residual -----------------------------------------------------------------------------
a2 = subplot(2,2,2); hold(a2,'on'); box(a2,'on');
plot(a2, tt, mean(RL,2,'omitnan'), '-','Color',[.6 .75 1],'LineWidth',1.2,'DisplayName','amp-avg residual');
plot(a2, tt, RL(:,tj), '-','Color',[.1 .4 .85],'LineWidth',1.9,'DisplayName','residual (this trial)');
xline(a2, tt(dc(1)),  'm:','HandleVisibility','off');
xline(a2, tt(dc(end)),'m:','HandleVisibility','off');
xline(a2,0,'k:','HandleVisibility','off'); yline(a2,0,'k:','HandleVisibility','off');
legend(a2,'Location','best','FontSize',7);  ylabel(a2,'residual \DeltaF/F %');  xlabel(a2,xlabS);
title(a2, sprintf('LOCAL residual  (magenta = dip window, the DV''s support)   %s = %+.2f', ...
      C.dvName, C.DV(loc(kLoc))), 'FontSize',9,'FontWeight','bold');

% (3) the STATE, as a raw trace ------------------------------------------------------------------
a3 = subplot(2,2,3); hold(a3,'on'); box(a3,'on');
stateVal = ST.(code)(kLoc);
switch code
    case 'MOT'
        motz = xsp_getf(S,'motz',[]);  onF = xsp_getf(S,'onF',{});
        if ~isempty(motz) && iscell(onF) && numel(onF) >= ai && ~isempty(rel)
            on = onF{ai}(:);  IDX = on.' + rel(:);          % [Wb x nT]
            okI = IDX >= 1 & IDX <= numel(motz);
            M = nan(size(IDX));  M(okI) = motz(IDX(okI));
            plot(a3, tt, mean(M,2,'omitnan'), '-','Color',[.65 .65 .65],'LineWidth',1.1,'DisplayName','amp-avg motion');
            plot(a3, tt, M(:,tj), '-','Color',[.85 .45 .1],'LineWidth',1.9,'DisplayName','motion (this trial)');
            % shade the ACTUAL integration window [-2,+0.5] s. If it runs past the plotted window the
            % title says so -- the scalar then includes samples this panel cannot show, which is the
            % first thing to check when a motion rho looks impossible.
            w0 = -2;  w1 = 0.5;  yl3 = ylim(a3);
            patch(a3, [max(w0,tt(1)) min(w1,tt(end)) min(w1,tt(end)) max(w0,tt(1))], ...
                     [yl3(1) yl3(1) yl3(2) yl3(2)], [.95 .90 .78], 'EdgeColor','none', ...
                     'FaceAlpha',0.5, 'HandleVisibility','off');
            uistack(findobj(a3,'Type','patch'),'bottom');
            covered = (tt(1) <= w0) && (tt(end) >= w1);
            title(a3, sprintf('MOTION trace   scalar = %.3g (\\Sigma|z| over [%.1f,%.1f] s)%s', ...
                  stateVal, w0, w1, ternstr_xsp(covered,'', '   ** window EXTENDS BEYOND this view **')), ...
                  'FontSize',9,'FontWeight','bold','Color',ternstr_xsp(covered,[0 0 0],[.7 .25 0]));
            ylabel(a3,'motion (z)');
            legend(a3,'Location','best','FontSize',7);
        else
            text(a3, .5, .5, {'no motion trace stored for this session'; ...
                 '(re-run imp_run_all so ALLSESS carries motz/onF)'}, 'Units','normalized', ...
                 'HorizontalAlignment','center','FontSize',9,'Color',[.6 .3 .3]);
            title(a3, sprintf('MOTION scalar = %.3g', stateVal), 'FontSize',9,'FontWeight','bold');
        end
    otherwise            % DPr / DPa / PVv are all computed from the ipsi trace over [-1,+0.5] s
        plot(a3, tt, A(:,tj), 'k-','LineWidth',1.6,'DisplayName','ipsi (this trial)');
        w0 = -1;  w1 = 0.5;  yl3 = ylim(a3);
        patch(a3, [max(w0,tt(1)) min(w1,tt(end)) min(w1,tt(end)) max(w0,tt(1))], ...
                 [yl3(1) yl3(1) yl3(2) yl3(2)], [.88 .93 .82], 'EdgeColor','none', ...
                 'FaceAlpha',0.5,'HandleVisibility','off');
        uistack(findobj(a3,'Type','patch'),'bottom');
        covered = (tt(1) <= w0) && (tt(end) >= w1);
        title(a3, sprintf('%s = %.4g   (from the ipsi trace over [%.1f,%.1f] s)%s', ...
              regexprep(C.STATES{s,2},'\\',''), stateVal, w0, w1, ...
              ternstr_xsp(covered,'','   ** window EXTENDS BEYOND this view **')), ...
              'FontSize',9,'FontWeight','bold','Color',ternstr_xsp(covered,[0 0 0],[.7 .25 0]));
        ylabel(a3,'ipsi \DeltaF/F %');
        legend(a3,'Location','best','FontSize',7);
end
xline(a3,0,'k:','HandleVisibility','off');  xlabel(a3,xlabS);

% (4) where this trial sits in the session's own distribution of the state -------------------------
a4 = subplot(2,2,4); hold(a4,'on'); box(a4,'on');
allv = ST.(code)(:);  allv = allv(isfinite(allv));
if ~isempty(allv)
    histogram(a4, allv, max(8,round(sqrt(numel(allv)))), 'FaceColor',C.cols(si,:), 'EdgeColor','none');
    xline(a4, stateVal, 'r-', 'LineWidth',2);
    pct = 100*mean(allv <= stateVal);
    title(a4, sprintf('%s across %s:  this trial = %.3g  (%.0fth pct of %d)', ...
          regexprep(C.STATES{s,2},'\\',''), C.sessName{si}, stateVal, pct, numel(allv)), ...
          'FontSize',9,'FontWeight','bold');
else
    text(a4,.5,.5,'state is all-NaN for this session','Units','normalized', ...
         'HorizontalAlignment','center','Color',[.6 .3 .3],'FontSize',9);
end
xlabel(a4, sprintf('%s (raw units)', regexprep(C.STATES{s,2},'\\','')));  ylabel(a4,'trials');

fprintf('  [XSPLOT click] %s (%s) | amp %.2f V, trial %d | %s = %.4g | %s = %+.3f\n', ...
        C.sessName{si}, C.labels{si}, ampv, tj, regexprep(C.STATES{s,2},'\\',''), stateVal, ...
        C.dvName, C.DV(loc(kLoc)));
drawnow;
end

function y = xsp_disp(v, mode)
% DISPLAY-ONLY re-scaling of a state marker. Every option is MONOTONE within a session, so no
% per-session rho or CI in the forest can move; only the shape of the cloud does. See XSP_XFORM.
switch lower(mode)
    case 'rank'                     % within-session percentile -- what the Spearman test sees
        y = nan(size(v));  m = isfinite(v);
        if any(m), y(m) = 100*(tiedrank(v(m)) - 0.5)/nnz(m); end
    case 'log'                      % signed log1p, for heavy tails you still want on a value axis
        y = sign(v).*log10(1 + abs(v));
    case 'raw'
        y = v;
    otherwise                       % 'z'
        y = (v - mean(v,'omitnan'))./max(std(v,'omitnan'),eps);
end
end

function L = xsp_xlabel(code, name, mode)
nm = regexprep(name,'\\','');
switch lower(mode)
    case 'rank', L = sprintf('%s  (within-session percentile)', nm);
    case 'log',  L = sprintf('%s  (signed log_{10})', nm);
    case 'raw'
        if strcmp(code,'DPr'), L = 'Rel-\delta   (\delta power / 0.5–30 Hz power)';
        else,                  L = sprintf('%s  (raw units)', nm); end
    otherwise,   L = sprintf('%s  (z, within session)', nm);
end
end
