%% imp_state_quartile_supp.m -- SUPPLEMENTARY: impulse prediction error by state quartile, per session.
%
% (user, 2026-10-15) JNeurosci-style panels, one ROW per state, for Illustrator assembly. Each row:
%   rms   RMS prediction error per quartile, per session (thin) + session mean (bold, red) and the
%         stim-free control mean (gray dashed). Session-normalised: 1 = that session's typical error.
%   ratio stim RMS / control RMS per quartile -> does the state effect exceed ongoing activity?
%   dist  per-trial error distribution per quartile and session (box 25-75, whisker 10-90, median)
%   var   VARIANCE of the per-trial error per quartile and session, 95% trial-bootstrap CI
% Each panel carries a descriptive note: Q4/Q1, geometric mean over sessions (min-max). Since
% 2026-10-16 (user: Fig 2 is descriptive groundwork) no p-values are drawn; the session-level
% tests are still computed and written to sq_stats.csv for the supporting stats table.
%
% Exploratory sibling (one big montage, more tests printed): imp_state_quartile_profile.m.
% Reads  data/fig2g_state_stats.mat (STV_R from imp_state_trialvar.m). No data reload.
% Writes paper/images/supplementary/state_quartile/sq_<state>_<panel>.pdf (+ .png), via jnExport.
%
% Sessions (STV_R.sess = allExperiments index, load_experiments.m order):
%   1 AL_0041 2025-12-02 e1 = Mouse 5a, 2 AL_0041 e2 = Mouse 5b, 3 AL_0033 2025-01-29 = Mouse 1,
%   4 AL_0048 = Mouse 3. These are the PAPER's names (stats Table 3, Fig 2B/D/E); the first
%   export (2026-10-15) used 1a/1b/2/3 and was fixed 2026-10-16.
% States: the three Fig-2G states (motion, relative delta, absolute delta). Pre-trial variance is
% the retracted power confound and is not drawn (SQ_STATES to override, e.g. {'MOT','PVv','DPa','DPr'}).
%
% RUN:  imp_state_quartile_supp
% -------------------------------------------------------------------------------------------------

root = 'C:\Users\aditya\Documents\projects\brain_paper';
addpath(fullfile(root,'utils'));
S  = load(fullfile(root,'data','fig2g_state_stats.mat'));  R = S.STV_R;
J  = jnStyle();
outDir = fullfile(root,'paper','images','supplementary','state_quartile');
if ~exist(outDir,'dir'), mkdir(outDir); end

if ~exist('SQ_STATES','var') || isempty(SQ_STATES), SQ_STATES = {'MOT','DPr','DPa'}; end
if ~exist('SQ_W','var')      || isempty(SQ_W),      SQ_W = 3.6;  end   % panel width  (cm); 3.6 x 2.8 leaves room for row gaps (user 2026-10-15)
if ~exist('SQ_H','var')      || isempty(SQ_H),      SQ_H = 2.8;  end   % panel height (cm)
SESS_LAB = {'Mouse 5a','Mouse 5b','Mouse 1','Mouse 3'};
STATE_LAB = struct('MOT','Motion','PVv','Pre-trial variance','DPa','Absolute δ power', ...
                   'DPr','Relative δ power');   % unicode + Interpreter none: tex bold spaces words apart
C_stim = J.col_ol;  C_ctl = [0.55 0.55 0.55];
C_sess = [0.30 0.45 0.70; 0.45 0.65 0.85; 0.85 0.55 0.20; 0.40 0.65 0.35];   % muted, distinct
nB = size(R(1).sdRawNs,2);  qlab = "Q"+(1:nB);

ST = table();
for iS = 1:numel(SQ_STATES)
    k = find(strcmp({R.tag}, SQ_STATES{iS}), 1);
    assert(~isempty(k), '[SQ] state %s not in STV_R', SQ_STATES{iS});
    r = R(k);  lab = STATE_LAB.(r.tag);  tg = lower(r.tag);
    uS = unique(r.sess(:)).';  nS = numel(uS);
    sd = r.sdRawNs;  sdP = r.sdPNs;  g = r.gbin(:);  y = r.y(:);  s = r.sess(:);

    % ---- statistics (session = unit for the across-session tests) ----------------------------
    pFR  = friedman(sd, 1, 'off');
    q4   = log(sd(:,end) ./ mean(sd(:,1:end-1),2));          [~,pQ4]  = ttest(q4);
    rr   = sd ./ sdP;
    q4c  = log(rr(:,end) ./ mean(rr(:,1:end-1),2));          [~,pQ4c] = ttest(q4c);
    vv = nan(nS,nB); vlo = vv; vhi = vv; nn = vv; pBF = nan(nS,1);
    rng(1);
    for i = 1:nS
        for b = 1:nB
            v = y(s==uS(i) & g==b);  v = v(isfinite(v));  nn(i,b) = numel(v);
            if numel(v) < 3, continue; end
            vv(i,b) = var(v);
            ci = bootci(2000, {@var, v}, 'Type','per');  vlo(i,b) = ci(1);  vhi(i,b) = ci(2);
        end
        m = s==uS(i) & g>0 & isfinite(y);
        pBF(i) = vartestn(y(m), g(m), 'TestType','BrownForsythe', 'Display','off');
    end
    q4v  = log(vv(:,end) ./ mean(vv(:,1:end-1),2));          [~,pQ4v] = ttest(q4v);
    nBF  = nnz(pBF < 0.05);
    ST = [ST; table(string(lab), exp(mean(q4)), pQ4, nnz(q4<0)*(mean(q4)<0)+nnz(q4>0)*(mean(q4)>=0), ...
          exp(mean(q4c)), pQ4c, pFR, exp(mean(q4v)), pQ4v, nBF, ...
          'VariableNames',{'state','rmsQ4','p_rmsQ4','nSessSameSign','beyondCtrl','p_beyondCtrl', ...
                           'p_friedman','varQ4','p_varQ4','nSess_BF05'})]; %#ok<AGROW>

    % ---- (1) RMS per quartile -----------------------------------------------------------------
    f = jnFig(SQ_W, SQ_H);  ax = axes(f);  hold(ax,'on');
    for i = 1:nS, plot(ax, 1:nB, sd(i,:), '-', 'Color', C_sess(i,:), 'LineWidth', J.lw_ind); end
    plot(ax, 1:nB, mean(sdP,1), '--', 'Color', C_ctl,  'LineWidth', J.lw_mean);
    plot(ax, 1:nB, mean(sd,1),  '-o', 'Color', C_stim, 'LineWidth', J.lw_mean, ...
         'MarkerSize', J.marker, 'MarkerFaceColor', C_stim);
    yline(ax, 1, ':', 'Color', [.6 .6 .6], 'LineWidth', J.lw_ref);
    local_ax(ax, nB, qlab, lab, 'Norm. RMS error');
    local_note(ax, J, local_rr(sd));   % descriptive (user 2026-10-16): no p on the panel
    jnAxes(ax);  jnExport(f, fullfile(outDir, sprintf('sq_%s_rms.pdf', tg)));  close(f);

    % ---- (2) stim / control -------------------------------------------------------------------
    f = jnFig(SQ_W, SQ_H);  ax = axes(f);  hold(ax,'on');
    for i = 1:nS, plot(ax, 1:nB, rr(i,:), '-', 'Color', C_sess(i,:), 'LineWidth', J.lw_ind); end
    plot(ax, 1:nB, mean(rr,1), '-o', 'Color', 'k', 'LineWidth', J.lw_mean, ...
         'MarkerSize', J.marker, 'MarkerFaceColor', 'k');
    yline(ax, 1, ':', 'Color', [.6 .6 .6], 'LineWidth', J.lw_ref);
    local_ax(ax, nB, qlab, lab, 'Stim / control RMS');
    local_note(ax, J, local_rr(rr));
    jnAxes(ax);  jnExport(f, fullfile(outDir, sprintf('sq_%s_ratio.pdf', tg)));  close(f);

    % ---- (3) trial-error distributions ---------------------------------------------------------
    f = jnFig(SQ_W, SQ_H);  ax = axes(f);  hold(ax,'on');
    w = 0.18;
    for i = 1:nS
        for b = 1:nB
            v = y(s==uS(i) & g==b);  v = v(isfinite(v));  if isempty(v), continue; end
            q = prctile(v,[10 25 50 75 90]);  xc = b + (i-(nS+1)/2)*w;  hw = w*0.38;
            plot(ax, [xc xc], q([1 2]), '-', 'Color', C_sess(i,:), 'LineWidth', J.lw_err);
            plot(ax, [xc xc], q([4 5]), '-', 'Color', C_sess(i,:), 'LineWidth', J.lw_err);
            patch(ax, xc+[-hw hw hw -hw], q([2 2 4 4]), C_sess(i,:), 'EdgeColor','none', 'FaceAlpha',0.6);
            plot(ax, xc+[-hw hw], q([3 3]), '-', 'Color', 'k', 'LineWidth', J.lw_err);
        end
    end
    xlim(ax, [0.45 nB+0.55]);
    local_ax(ax, nB, qlab, lab, 'Trial error');  xlim(ax, [0.45 nB+0.55]);
    jnAxes(ax);  jnExport(f, fullfile(outDir, sprintf('sq_%s_dist.pdf', tg)));  close(f);

    % ---- (4) variance of trial error -----------------------------------------------------------
    f = jnFig(SQ_W, SQ_H);  ax = axes(f);  hold(ax,'on');
    for i = 1:nS
        xo = (1:nB) + (i-(nS+1)/2)*0.1;
        errorbar(ax, xo, vv(i,:), vv(i,:)-vlo(i,:), vhi(i,:)-vv(i,:), '-o', 'Color', C_sess(i,:), ...
                 'MarkerFaceColor', C_sess(i,:), 'MarkerSize', J.marker-1, 'LineWidth', J.lw_ind, 'CapSize', 0);
    end
    plot(ax, 1:nB, mean(vv,1), '-', 'Color', 'k', 'LineWidth', J.lw_mean);
    local_ax(ax, nB, qlab, lab, 'Error variance');
    ylim(ax, [0 max(ylim(ax))]);
    local_note(ax, J, local_rr(vv));
    jnAxes(ax);  jnExport(f, fullfile(outDir, sprintf('sq_%s_var.pdf', tg)));  close(f);
end

% ---- shared legend panel (place once in Illustrator) ------------------------------------------
% Drawn as REAL line + text objects on a cm-scaled axes, not legend(): a legend() fed NaN
% placeholder lines on an invisible axes exports its text but drops the colour swatches from the
% vector PDF (user 2026-10-16: "legend pdf did not contain the colors only text").
f = jnFig(J.W_double, 0.5);
ax = axes(f, 'Units','normalized', 'Position',[0 0 1 1]);  hold(ax,'on');
axis(ax, [0 J.W_double 0 0.5]);  axis(ax, 'off');
items = [ cellfun(@(lb,c) {lb, c, '-', 'none', J.lw_mean}, SESS_LAB, num2cell(C_sess,2).', 'UniformOutput', false), ...
          {{'Session mean', C_stim, '-', 'o', J.lw_mean}}, ...
          {{'Mean (stim/control, variance)', [0 0 0], '-', 'o', J.lw_mean}}, ...
          {{'No-stimulus control', C_ctl, '--', 'none', J.lw_mean}} ];
x = 0.1;  yc = 0.25;  tok = 0.5;
for it = 1:numel(items)
    [lb, c, ls, mk, lw] = items{it}{:};
    plot(ax, x + [0 tok], [yc yc], 'LineStyle', ls, 'Color', c, 'LineWidth', lw);
    if ~strcmp(mk,'none')
        plot(ax, x + tok/2, yc, mk, 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', J.marker);
    end
    t = text(ax, x + tok + 0.1, yc, lb, 'FontSize', J.fs_annot, 'FontName', J.font, ...
             'VerticalAlignment','middle', 'Interpreter','none');
    x = t.Extent(1) + t.Extent(3) + 0.35;
end
jnExport(f, fullfile(outDir, 'sq_legend.pdf'));  close(f);

disp(ST);
writetable(ST, fullfile(outDir, 'sq_stats.csv'));
fprintf('[SQ] panels in %s\n', outDir);

% =================================================================================================
function local_ax(ax, nB, qlab, lab, yl)
xlim(ax, [0.6 nB+0.4]);  xticks(ax, 1:nB);  xticklabels(ax, qlab);
set(ax, 'Units','normalized', 'Position',[0.22 0.27 0.74 0.55]);   % fixed margins: room for labels + 2-line note
xlabel(ax, sprintf('%s quartile', strrep(strrep(strrep(lab,'Absolute','Abs.'),'Relative','Rel.'),' power','')), 'Interpreter','none');  ylabel(ax, yl, 'Interpreter','none');
end

function local_note(ax, J, str)
text(ax, 0.02, 1.0, str, 'Units','normalized', 'VerticalAlignment','bottom', ...
     'FontSize', J.fs_annot, 'FontName', J.font, 'Color', [0.15 0.15 0.15], 'Interpreter','none');
end

function s = local_rr(M)
% Descriptive panel note: Q4/Q1 per session (rows of M), geometric mean and min-max range.
% Same summary as the Fig 2G Results text; the session tests stay in sq_stats.csv / Table 4.
r = M(:,end) ./ M(:,1);  r = r(isfinite(r));
s = sprintf('Q4/Q1 %.2f (%.2f–%.2f)', exp(mean(log(r))), min(r), max(r));
end

function s = local_p(p)
if p < 0.001, s = sprintf('%.0e', p); else, s = sprintf('%.2g', p); end
end
