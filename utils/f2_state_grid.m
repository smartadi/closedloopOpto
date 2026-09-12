function f2_state_grid(F2, F2_STATE, opt)
%F2_STATE_GRID  4x2 CLICKABLE state-dependence grid: rows = sessions, cols = [Motion, Rel-delta].
%
% Each panel scatters the Local-residual DV (L1-dev, z-within-amp) against a brain-state scalar,
% with every trial COLOURED BY ITS PRE-TRIAL PREDICTION QUALITY (pre-onset residual energy, ST.PRE,
% shown as a within-session percentile: LOW = the predictor tracked ipsi well before the stim, so the
% trial's dip deviation is trustworthy; HIGH = the baseline fit was poor, so its deviation is suspect
% and is exactly what the partial-on-pre-error control removes).
%
% CLICK any point -> f2_inspector opens THAT trial: actual ipsi, stim-blind prediction (Global),
% residual (Local), the motion window, the state window and its spectrum. This is the same detail
% view f2_state arms, but here each axis maps to ONE session so the four sessions are separable.
%
% USAGE   f2_state_grid(F2, F2_STATE)                     % arm + draw, no export
%         f2_state_grid(F2, F2_STATE, struct('outdir',D)) % also export <D>/state_dep_grid_4x2.png
%
% INPUT   F2        per-session struct array from imp_fig2 (needs .D.ST with L1DEVz, PRE, MOT, DPr)
%         F2_STATE  the f2_state result (for per-session partial rho/p + Global control in titles)
%         opt .outdir  folder to export the PNG into (optional) .dv ('L1DEVz')
% -------------------------------------------------------------------------------------------------
if nargin < 3, opt = struct(); end
if ~isfield(opt,'dv')    || isempty(opt.dv),    opt.dv = 'L1DEVz'; end
if ~isfield(opt,'outdir'),                      opt.outdir = ''; end

nS = numel(F2);
stateFld  = {'MOT','DPr'};
stateName = {'Motion', 'Rel-\delta (2-4 Hz)'};
stateCol  = [1 2];                                  % columns into F2_STATE.states / rhoLocal
zf = @(x)(x - mean(x,'omitnan'))./max(std(x,'omitnan'), eps);

fig = figure('Color','w','Name','[F2-STATE GRID] click a trial -> residual trace', ...
             'Position',[60 40 900 1120]);
axList = gobjects(nS*2,1);  axSess = zeros(nS*2,1);  axState = zeros(nS*2,1);
SS = struct('label',{},'D',{},'dv',{},'state',{});

for s = 1:nS
    ST  = F2(s).D.ST;
    dv  = ST.(opt.dv)(:);
    pre = ST.PRE(:);
    prc = 100 * (tiedrank(pre) / max(numel(pre),1));         % pre-quality percentile (low = good)
    stZ = cell(1,2);
    for k = 1:2
        stZ{k} = zf(ST.(stateFld{k})(:));
        p = (s-1)*2 + k;
        ax = subplot(nS, 2, p);  hold(ax,'on');  box(ax,'on');
        ok = isfinite(dv) & isfinite(stZ{k}) & isfinite(prc);
        scatter(ax, stZ{k}(ok), dv(ok), 16, prc(ok), 'filled', 'MarkerFaceAlpha',0.7);
        pf = polyfit(stZ{k}(ok), dv(ok), 1);  xl = [min(stZ{k}(ok)) max(stZ{k}(ok))];
        plot(ax, xl, polyval(pf,xl), 'r-', 'LineWidth',1.4);
        yline(ax,0,'k:','HandleVisibility','off');  xline(ax,0,'k:','HandleVisibility','off');
        caxis(ax,[0 100]);  colormap(ax, flipud(parula));    % low pctile (good fit) = bright
        rl = F2_STATE.rhoLocal(s,stateCol(k));
        pl = F2_STATE.pLocal(s,stateCol(k));
        rg = F2_STATE.rhoGlobal(s,stateCol(k));
        sig = ''; if isfinite(pl) && pl < 0.05, sig = ' *'; end
        title(ax, sprintf('%s   \\rho=%+.3f p=%.3g%s  (Glob %+.3f)', ...
              stateName{k}, rl, pl, sig, rg), 'FontSize',8,'FontWeight','bold');
        if k == 1
            ylabel(ax, sprintf('%s\nL1-dev (z)', local_short(F2(s).label)), 'FontSize',8);
        end
        if s == nS, xlabel(ax, sprintf('%s (z)', stateName{k}), 'FontSize',8); end
        axList(p) = ax;  axSess(p) = s;  axState(p) = k;
    end
    SS(s).label = F2(s).label;
    SS(s).D     = F2(s).D;
    SS(s).dv    = dv;
    SS(s).state = stZ;                                   % z-scored, matches the plotted coordinates
end

cb = colorbar(axList(2), 'Position',[0.93 0.11 0.015 0.8]);
cb.Label.String = 'pre-trial prediction error (percentile) — low = trustworthy';
cb.Label.FontSize = 8;
sgtitle(sprintf(['Residual state-dependence, all %d sessions — trials coloured by PRE-TRIAL prediction ' ...
                 'quality\nCLICK a point -> that trial''s actual / Global / Local traces'], nS), ...
        'FontWeight','bold','FontSize',10);

% ---- arm the click handler: each axis -> one (session, state) ----------------------------------
IX = struct();
IX.sess       = SS;
IX.axes       = axList;
IX.axSess     = axSess;
IX.axState    = axState;
IX.stateNames = {'Motion','Rel-\delta'};
IX.dv         = opt.dv;
set(fig, 'WindowButtonDownFcn', @(src,~) local_grid_click(src));
guidata(fig, IX);
fprintf(['[F2-STATE GRID] armed: click any point -> f2_inspector opens that trial''s residual trace.\n' ...
         '   Or jump straight to one:  f2_inspector(gcf, [], sessIdx, trialRow, stateIdx)\n']);

if ~isempty(opt.outdir)
    if ~exist(opt.outdir,'dir'), mkdir(opt.outdir); end
    fn = fullfile(opt.outdir, 'state_dep_grid_4x2.png');
    exportgraphics(fig, fn, 'Resolution',200);
    fprintf('[F2-STATE GRID] exported -> %s\n', fn);
end
end

% -------------------------------------------------------------------------------------------------
function local_grid_click(fig)
IX = guidata(fig);  ax = gca;
a = find(IX.axes == ax, 1);
if isempty(a), return; end
s = IX.axSess(a);  kk = IX.axState(a);
cp = get(ax,'CurrentPoint');  xc = cp(1,1);  yc = cp(1,2);
xl = xlim(ax);  yl = ylim(ax);  xs = max(diff(xl),eps);  ys = max(diff(yl),eps);
X = IX.sess(s).state{kk};  Y = IX.sess(s).dv;
d = ((X-xc)/xs).^2 + ((Y-yc)/ys).^2;
[dm, im] = min(d);
if sqrt(dm) > 0.06
    fprintf('[F2-STATE GRID] no point near the click (nearest %.2f axis-fractions away)\n', sqrt(dm));
    return
end
f2_inspector(fig, [], s, im, kk);
end

function s = local_short(lbl)
% "AL_0033 2025-01-29 e1" -> "AL_0033 e1"; keep any [site] tag.
tok = regexp(lbl, '^(AL_\d+).*?(e\d+)(\s*\[[^\]]*\])?$', 'tokens', 'once');
if isempty(tok), s = lbl; else, s = strtrim([tok{1} ' ' tok{2} tok{3}]); end
end
