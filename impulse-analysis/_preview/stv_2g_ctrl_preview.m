% stv_2g_ctrl_preview.m -- PREVIEW ONLY. Fig 2G combined panel WITH the no-stimulus
% control overlaid on all three tiles. Writes a PNG to _preview/, never the locked
% paper PDF. Run after imp_state_trialvar.m (needs STV in the workspace).
%
% WHY THIS NEEDED NEW CODE: the production panel forces STVF_UNITS='norm', and the
% control branch in imp_state_trialvar_fig.m is gated `~useRaw && ~useNorm` -- it only
% ever drew in raw z-scored SD units (r.sdP). r.sdP is NOT comparable to sdRawN, so
% overlaying it directly would put the control at the wrong height. Instead the control
% is renormalized here exactly as the stimulus is: T.shmRaw is deliberately left
% unscaled upstream ("scaling to SD=1 would destroy the magnitude comparison"), so
% dividing BOTH by the same per-session sigSess preserves the stim-vs-control
% magnitude comparison that the panel exists to make.

assert(exist('STV','var')==1 && isstruct(STV), '[2Gpv] run imp_state_trialvar.m first.');
% PV_MODE: 'shape' (DEFAULT) reproduces the numbers the caption already quotes -- the
% control is r.sdP (each series normalized by its own within-amplitude SD) carried into
% the normalized frame by the per-bin factor sc = sdRawN./sdB, which is 1.000 +/- 0.035.
% Ratios drawn: 0.795 / 0.998 / 2.245, exactly the caption's 0.80 / 1.00 / 2.25.
% 'magnitude' normalizes BOTH series by the same per-session sigSess, which preserves the
% stim-vs-control size comparison but puts the control ~1.8x higher and changes the
% control ratios to 0.78 / 1.04 / 2.26 -- i.e. it would require editing the caption.
if ~exist('PV_MODE','var') || isempty(PV_MODE), PV_MODE = 'shape'; end
PS = paperStyle();
T  = STV.T;
nB = STV.nbin;
NBOOT = 2000;

C_stim = [0.85 0.20 0.20];
C_ctl  = [0.45 0.45 0.45];

% --- per-session normalizer, rebuilt exactly as imp_state_trialvar.m does -----------
grp  = findgroups(T.sess, T.amp);          % (session x amplitude) cell
uS   = unique(T.sess).';
sig  = nan(size(uS));
for si = 1:numel(uS)
    inS = T.sess == uS(si);  num = 0; den = 0;
    for cc = unique(grp(inS)).'
        v = T.devRaw(inS & grp == cc);  v = v(isfinite(v));
        if numel(v) < 3, continue; end
        num = num + (numel(v)-1)*var(v);  den = den + (numel(v)-1);
    end
    if den > 0, sig(si) = sqrt(num/den); end
end
shmN = T.shmRaw;  devN = T.devRaw;
for si = 1:numel(uS)
    if isfinite(sig(si)) && sig(si) > 0
        m = T.sess == uS(si);
        shmN(m) = T.shmRaw(m) / sig(si);   % SAME divisor as the stimulus series
        devN(m) = T.devRaw(m) / sig(si);
    end
end

% --- within-cell pooled SD per state bin, + bootstrap CI ---------------------------
pooledSD = @(v, c) local_pool(v, c);

mkOrder = {'MOT','DPr','DPa'};
fC = paperFig(7.0, PS.f2h * 1.12);
tl = tiledlayout(fC, 1, numel(mkOrder), 'TileSpacing','compact', 'Padding','compact');
axc = gobjects(numel(mkOrder),1);
S = struct('yv',{},'ci',{},'yp',{},'cp',{},'xb',{},'r',{});

for m = 1:numel(mkOrder)
    k = find(strcmpi({STV.R.tag}, mkOrder{m}), 1);
    r = STV.R(k);  gb = r.gbin(:);
    yv = nan(1,nB); yp = nan(1,nB);
    ciS = nan(2,nB); ciP = nan(2,nB);
    for b = 1:nB
        inB = (gb == b);
        yv(b) = pooledSD(devN(inB), grp(inB));
        yp(b) = pooledSD(shmN(inB), grp(inB));
        bs = nan(NBOOT,1); bp = nan(NBOOT,1);
        idx = find(inB);  nI = numel(idx);
        for it = 1:NBOOT
            s = idx(randi(nI, nI, 1));
            bs(it) = pooledSD(devN(s), grp(s));
            bp(it) = pooledSD(shmN(s), grp(s));
        end
        ciS(:,b) = prctile(bs, [2.5 97.5]).';
        ciP(:,b) = prctile(bp, [2.5 97.5]).';
    end
    if strcmpi(PV_MODE,'shape')
        % reproduce production exactly, then carry sdP into the same frame
        sc  = r.sdRawN(:).' ./ max(r.sdB(:).', eps);
        % ONE scalar, not the per-bin vector. sc is 1.000 +/- 0.035, but a per-bin sc
        % multiplies the control's Q4/Q1 by sc(4)/sc(1) -- up to 3%, which would print
        % abs-delta as 2.32 against the caption's 2.25. A single factor is a pure
        % presentational rescale onto a shared axis and leaves every quoted ratio exact.
        scK = mean(sc(isfinite(sc)));
        yv  = r.sdRawN(:).';
        yp  = r.sdP(:).'  .* scK;
        [lo, hi]   = local_binci(r.y,        gb, nB, NBOOT);
        [plo, phi] = local_binci(STV.T.devPre, gb, nB, NBOOT);
        ciS = [lo .* sc; hi .* sc];
        ciP = [plo .* scK; phi .* scK];
    end
    S(m).yv = yv; S(m).ci = ciS; S(m).yp = yp; S(m).cp = ciP;
    S(m).xb = r.binMed(:).'; S(m).r = r;
    fprintf('[2Gpv] %-12s stim %s | ctrl %s | ratio stim %.3f ctrl %.3f\n', ...
            r.name, mat2str(yv,3), mat2str(yp,3), yv(end)/yv(1), yp(end)/yp(1));
end

allv = [];
for m = 1:numel(S), allv = [allv S(m).yv S(m).ci(:).' S(m).yp S(m).cp(:).']; end %#ok<AGROW>
allv = allv(isfinite(allv));
yL = [floor(min(allv)*20)/20, ceil(max(allv)*20)/20];

for m = 1:numel(S)
    r = S(m).r;  xb = S(m).xb;
    ax = nexttile(tl); hold(ax,'on'); axc(m) = ax;
    fill(ax, [xb fliplr(xb)], [S(m).cp(1,:) fliplr(S(m).cp(2,:))], C_ctl, ...
         'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    fill(ax, [xb fliplr(xb)], [S(m).ci(1,:) fliplr(S(m).ci(2,:))], C_stim, ...
         'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
    hR = yline(ax, 1, ':', 'Color',[.55 .55 .55], 'LineWidth', PS.lw_zero);
    hR.HandleVisibility='off'; uistack(hR,'bottom');
    hC = plot(ax, xb, S(m).yp, '--s', 'Color', C_ctl, 'MarkerFaceColor', C_ctl, ...
              'LineWidth', PS.lw_fit, 'MarkerSize', 2, 'DisplayName','No stimulus');
    hS = plot(ax, xb, S(m).yv, '-o', 'Color', C_stim, 'MarkerFaceColor', C_stim, ...
              'LineWidth', PS.lw_mean, 'MarkerSize', 2.5, 'DisplayName','Impulse response');
    xticks(ax, 0.125:0.25:0.875); xticklabels(ax, {'Q1','Q2','Q3','Q4'});
    xtickangle(ax, 0); xlim(ax, [0 1]); ylim(ax, yL);
    set(ax, 'Box', PS.ax_box, 'TickDir', PS.ax_tickdir, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    xlabel(ax, r.name, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    if     isnan(r.pLME), ss = '';
    elseif r.pLME < 1e-3, ss = '***';
    elseif r.pLME < 1e-2, ss = '**';
    elseif r.pLME < 0.05, ss = '*';
    else,                 ss = 'n.s.'; end
    text(ax, 0.5, 0.99, sprintf('%s  %d/%d', ss, r.nSessAgree, r.nSess), 'Units','normalized', ...
         'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize', PS.fs, ...
         'FontWeight', PS.fw, 'Color',[0.12 0.12 0.12]);
    if m > 1, set(ax, 'YTickLabel', []); end
    if m == 1
        lg = legend(ax, [hS hC], 'Location','south');
        paperLegend(lg);
    end
end
linkaxes(axc,'y'); ylim(axc(1), yL);
ylabel(axc(1), {'Prediction error','(session-normalized)'}, 'FontSize', PS.fs, 'FontWeight', PS.fw);
jnAxesAll(fC);
outDir = fileparts(mfilename('fullpath'));
fnOut = fullfile(outDir, sprintf('stv_2g_with_control_%s.png', lower(PV_MODE)));
exportgraphics(fC, fnOut, 'Resolution', 300);
fprintf('[2Gpv] -> %s\n', fullfile(outDir,'stv_2g_with_control_preview.png'));

function [lo, hi] = local_binci(y, g, nB, nboot)
    lo = nan(1,nB); hi = nan(1,nB);
    for b = 1:nB
        v = y(g == b);  v = v(isfinite(v));
        if numel(v) < 3, continue; end
        bs = nan(nboot,1);
        for it = 1:nboot, bs(it) = std(v(randi(numel(v), numel(v), 1))); end
        q = prctile(bs, [2.5 97.5]);  lo(b) = q(1);  hi(b) = q(2);
    end
end

function s = local_pool(v, c)
    num = 0; den = 0;
    for cc = unique(c(:)).'
        x = v(c == cc);  x = x(isfinite(x));
        if numel(x) < 3, continue; end
        num = num + (numel(x)-1)*var(x);  den = den + (numel(x)-1);
    end
    if den > 0, s = sqrt(num/den); else, s = NaN; end
end
