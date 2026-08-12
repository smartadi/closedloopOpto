%% ctrl_fit_figs.m   [FITFIG]  -- per-session PREDICTION and KERNEL for the contra->ipsi model
%
% One figure per session answering the two questions the R^2 number alone cannot:
%   (left)  the OL TRIAL-AVERAGED decomposition: Actual, Global (the stim-blind contra
%           prediction = what the site would have done with no laser) and Local = Actual-Global,
%           with +/-SEM. This is where the model either works or visibly does not: Global should
%           stay near zero through the laser window, and whatever it dips is leak.
%   (right) WHERE does the prediction come from? The fitted weight map on the contra grid, i.e.
%           the kernel. A predictor leaning on a handful of extreme weights is a different object
%           from one with a smooth distributed map, and R^2 does not distinguish them.
%
% READS ONLY -- no session is opened, and every field used has always been in the Stage-2 cache
% (Aa/Gg/Lo, A_tr/G_tr, rel, capt/leak), so every session on disk draws without a rebuild.
%
% MODE AWARE. Reads whichever Stage-2 caches the CTRL_PRED switch selects (see
% utils/ctrl_pred_tag.m): 'rank' = pixel selection, 'ridge' = whole grid + shrinkage. Run it
% once per mode to compare the two side by side; the file names carry the mode.
%
% SECTIONS: [FITFIG-CFG] [FITFIG-LOOP] [FITFIG-REPORT]

%% [FITFIG-CFG] -----------------------------------------------------------------
FF_EXPORT = true;
FF_FMT    = {'png'};       % review format; these are diagnostics, not paper panels
if exist('F4_FMT','var') && ~isempty(F4_FMT); FF_FMT = F4_FMT; end

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
[pred_suffix, pred_mode] = ctrl_pred_tag();
outDir = fullfile(here,'..','paper','images','predictor_saga','fits');
if FF_EXPORT && ~exist(outDir,'dir'); mkdir(outDir); end
r2_floor = ctrl_r2_floor();

ff_files = dir(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_*.mat', pred_suffix)));
% '_ridge' caches also match the bare 'rank' glob, so filter them out when in rank mode
if isempty(pred_suffix)
    ff_files = ff_files(~contains({ff_files.name},'_ridge_'));
end
assert(~isempty(ff_files), ['[FITFIG] no Stage-2 caches for pred mode ''%s''. ' ...
    'Build them first (ctrl_residual_build.m with CTRL_PRED = ''%s'').'], pred_mode, pred_mode);
fprintf('\n[FITFIG] pred mode ''%s'' | %d sessions | -> %s\n', pred_mode, numel(ff_files), outDir);

%% [FITFIG-LOOP] ----------------------------------------------------------------
FF = struct([]);
fprintf('  %-24s %7s %6s %7s %7s %6s %8s %9s\n', ...
    'session','R2_te','nTr','Local%','leak%','nPx','||b||','lambda');
for ff_i = 1:numel(ff_files)
    S2 = load(fullfile(dataDir, ff_files(ff_i).name));
    ff_tag = erase(erase(erase(ff_files(ff_i).name,'ctrl_ols_ol_stimblind'),[pred_suffix '_']),'.mat');
    if startsWith(ff_tag,'_'); ff_tag = ff_tag(2:end); end
    % NO SESSION IS SILENTLY DROPPED -- excluded sessions are exactly the ones worth looking at.
    % Everything drawn here comes from fields Stage 2 has always cached, so every session on disk
    % can be drawn without a rebuild.
    Fs = S2.Fs;
    ff_r2 = NaN;  if isfield(S2,'R2_te'); ff_r2 = S2.R2_te; end
    ff_tt = S2.rel/Fs;                       % peri-stim time, 0 = laser onset
    ff_lam = NaN;
    if isfield(S2,'bnorm'); ff_nrm = S2.bnorm; else; ff_nrm = norm(S2.b); end
    if isfield(S2,'lambda'); ff_lam = S2.lambda; end

    figF = figure('Color','w','Position',[60 70 1250 460]);
    tl = tiledlayout(figF,1,2,'TileSpacing','compact','Padding','compact');

    % --- (left) OL TRIAL-AVERAGED decomposition ------------------------------------
    % Actual = the measured ipsi response to the open-loop laser step.
    % Global = what the stim-blind contra predictor says the site would have done with no laser
    %          (i.e. the ongoing network state) -- it SHOULD sit near zero through the stim.
    % Local  = Actual - Global, the part of the response the laser produced locally.
    % All three are per-trial baseline-subtracted on [-1,0] s before averaging (Stage 2's own
    % convention), so the panel reads as deviation from each trial's own pre-stim level.
    ax1 = nexttile(tl,1); hold(ax1,'on');
    ff_nT = size(S2.A_tr,1);
    semf  = @(M) std(M,0,1)/sqrt(max(size(M,1),1));
    ff_sA = semf(S2.A_tr);  ff_sG = semf(S2.G_tr);
    ff_dur = ff_tt(end);
    % y-limits from the TRACES, and the laser patch is then drawn to those limits. Drawing the
    % patch at some huge fixed height and calling ylim('auto') does not work: the patch is a data
    % object like any other, so auto-scaling includes it and the traces collapse to a flat line.
    ff_all = [S2.Aa+ff_sA, S2.Aa-ff_sA, S2.Gg+ff_sG, S2.Gg-ff_sG, S2.Lo];
    ff_lo = min(ff_all);  ff_hi = max(ff_all);
    ff_pad = 0.08*max(ff_hi-ff_lo, eps);
    ff_yl  = [ff_lo-ff_pad, ff_hi+ff_pad];
    patch(ax1, [0 ff_dur ff_dur 0], ff_yl([1 1 2 2]), [0.85 0.90 1.0], ...
        'EdgeColor','none','FaceAlpha',0.35,'HandleVisibility','off');   % laser ON
    fill(ax1,[ff_tt fliplr(ff_tt)],[S2.Aa+ff_sA fliplr(S2.Aa-ff_sA)],[0.15 0.15 0.15], ...
        'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    fill(ax1,[ff_tt fliplr(ff_tt)],[S2.Gg+ff_sG fliplr(S2.Gg-ff_sG)],[0.45 0.45 0.45], ...
        'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(ax1, ff_tt, S2.Aa, '-', 'Color',[0.10 0.10 0.10], 'LineWidth',1.6);
    plot(ax1, ff_tt, S2.Gg, '-', 'Color',[0.45 0.45 0.45], 'LineWidth',1.3);
    plot(ax1, ff_tt, S2.Lo, '-', 'Color',[0.85 0.35 0.05], 'LineWidth',1.3);
    yline(ax1, 0, ':', 'Color',[0.5 0.5 0.5], 'HandleVisibility','off');
    xline(ax1, 0, '-', 'Color',[0.4 0.4 0.4], 'HandleVisibility','off');
    xlim(ax1,[ff_tt(1) ff_tt(end)]);
    ylim(ax1, 'auto');   % after the patch, so the patch does not set the range
    yl = ylim(ax1);  ylim(ax1, yl);
    xlabel(ax1,'time from laser onset (s)');  ylabel(ax1,'\DeltaF/F (%), baseline-sub');
    legend(ax1,{'Actual','Global (no-laser prediction)','Local = A-G'}, ...
        'Box','off','Location','southeast','FontSize',8);
    title(ax1, sprintf('OL trial avg, n=%d  |  Local %.0f%% / Global leak %.0f%% (sustained)', ...
        ff_nT, S2.capt_sus, S2.leak_sus));

    % --- (right) the kernel: fitted weights on the contra grid ---------------------
    % Su indexes into the grid, so weights are scattered at their own grid coordinates. A
    % DIVERGING scale centred on zero: sign matters (which contra regions push the estimate up
    % vs down), and a one-sided colormap would hide it.
    ax2 = nexttile(tl,2); hold(ax2,'on');
    ff_b = zeros(numel(S2.gridIdx),1);  ff_b(S2.Su) = S2.b;
    ff_lim = max(abs(ff_b));  if ff_lim == 0 || ~isfinite(ff_lim); ff_lim = 1; end

    % BRAIN UNDERLAY, so the orientation can be checked by eye instead of trusted.
    % Stage 1 cached ipsi_mask/contra_mask in mimg's NATIVE [nY x nX], and the ROI file stores
    % the drawn outline with bx = native ROW and by = native COLUMN (cp_roi_masks.m: "(bx,by) is
    % numerically already native (row,col)"). This axes is (x = column, y = row), so the masks go
    % in as-is via image() while the outline/midline need their pair swapped.
    % Drawn as TRUECOLOR RGB, not indexed: one axes has one colormap, and that one is the
    % diverging weight scale. An indexed background would hijack it.
    ff_hemi = local_hemi(dataDir, S2.sess_tag);
    if ~isempty(ff_hemi)
        ff_bg = ones([size(ff_hemi.ipsi) 3]);
        ff_bg = local_paint(ff_bg, ff_hemi.contra, [0.87 0.90 0.95]);   % model INPUT half
        ff_bg = local_paint(ff_bg, ff_hemi.ipsi,   [0.96 0.93 0.88]);   % half holding the site
        image(ax2, ff_bg);
        if ~isempty(ff_hemi.bx)
            plot(ax2, ff_hemi.by, ff_hemi.bx, '-', 'Color',[0.55 0.55 0.55], 'LineWidth',0.8);
            plot(ax2, ff_hemi.my, ff_hemi.mx, '--','Color',[0.20 0.60 0.70], 'LineWidth',1.2);
        end
        ff_bb = local_bbox(ff_hemi.ipsi | ff_hemi.contra, 15);
        xlim(ax2, ff_bb(3:4));  ylim(ax2, ff_bb(1:2));
    end
    scatter(ax2, S2.grC, S2.grR, 26, ff_b, 'filled');
    if ~isempty(ff_hemi)   % labels AFTER the scatter, or the weights bury them
        [ff_cR,ff_cC] = local_centroid(ff_hemi.contra);
        [ff_iR,ff_iC] = local_centroid(ff_hemi.ipsi);
        text(ax2, ff_cC, ff_cR, 'contra', 'Color',[0.15 0.25 0.50], 'FontSize',9, ...
            'FontWeight','bold','HorizontalAlignment','center', ...
            'BackgroundColor',[1 1 1 ], 'Margin',1);
        text(ax2, ff_iC, ff_iR, 'ipsi',   'Color',[0.55 0.32 0.10], 'FontSize',9, ...
            'FontWeight','bold','HorizontalAlignment','center', ...
            'BackgroundColor',[1 1 1], 'Margin',1);
    end
    % px_prim is the ROW and py_prim the COLUMN (ctrl_ols_ol_stimblind.m passes them in that
    % order to cp_orient_fwd(Tor,row,col)), so the site goes at x = py_prim, y = px_prim --
    % the same (col,row) convention as the scatter above. Swapping them mislocates the site,
    % which is exactly the check this panel exists to make.
    plot(ax2, S2.py_prim, S2.px_prim, 'kp', 'MarkerSize',13, 'MarkerFaceColor',[1 1 0.2]);
    colormap(ax2, local_diverging());  clim(ax2, ff_lim*[-1 1]);
    cb = colorbar(ax2);  cb.Label.String = 'weight';
    axis(ax2,'image');  set(ax2,'YDir','reverse');
    xlabel(ax2,'column (px)'); ylabel(ax2,'row (px)');
    title(ax2, sprintf('kernel: %d px, ||b|| = %.1f, max|b| = %.2f', ...
        numel(S2.Su), ff_nrm, max(abs(S2.b))));

    ff_hdr = sprintf('[FITFIG] %s   mode=%s', strrep(ff_tag,'_','\_'), pred_mode);
    if isfinite(ff_lam); ff_hdr = sprintf('%s  \\lambda=%.3g', ff_hdr, ff_lam); end
    if isfield(S2,'lambda_at_edge') && S2.lambda_at_edge
        ff_hdr = sprintf('%s   [lambda AT GRID EDGE]', ff_hdr);
    end
    if ff_r2 < r2_floor; ff_hdr = sprintf('%s   [BELOW FLOOR %.2f]', ff_hdr, r2_floor); end
    sgtitle(figF, ff_hdr);
    if FF_EXPORT
        for ff_k = 1:numel(FF_FMT)
            exportgraphics(figF, fullfile(outDir, ...
                sprintf('ctrl_fit_%s%s.%s', ff_tag, pred_suffix, FF_FMT{ff_k})), 'Resolution',300);
        end
    end

    ff_j = numel(FF)+1;
    FF(ff_j).sess_tag = ff_tag;  FF(ff_j).R2_te = ff_r2;  FF(ff_j).nTrials = ff_nT;
    FF(ff_j).capt_sus = S2.capt_sus;  FF(ff_j).capt_tran = S2.capt_tran;
    FF(ff_j).nPx = numel(S2.Su); FF(ff_j).bnorm = ff_nrm;   FF(ff_j).lambda = ff_lam;
    if isfield(S2,'leak_sus');   FF(ff_j).leak = S2.leak_sus; else; FF(ff_j).leak = NaN; end
    if isfield(S2,'catch_falls');FF(ff_j).catch_falls = S2.catch_falls; else; FF(ff_j).catch_falls = NaN; end
    fprintf('  %-24s %7.3f %6d %7.0f %7.0f %6d %8.1f %9.3g\n', ff_tag, ff_r2, ff_nT, ...
        S2.capt_sus, S2.leak_sus, numel(S2.Su), ff_nrm, ff_lam);
end

%% [FITFIG-REPORT] --------------------------------------------------------------
assert(~isempty(FF), '[FITFIG] no Stage-2 cache could be drawn.');
fprintf('\n[FITFIG] mode ''%s'': %d/%d sessions clear the R^2 floor (%.2f)\n', ...
    pred_mode, nnz([FF.R2_te] >= r2_floor), numel(FF), r2_floor);
fprintf('  held-out R^2 : median %.3f, range %.3f-%.3f\n', ...
    median([FF.R2_te]), min([FF.R2_te]), max([FF.R2_te]));
fprintf('  Global leak  : median %.1f%%, range %.1f-%.1f%%\n', ...
    median([FF.leak],'omitnan'), min([FF.leak]), max([FF.leak]));
if any(~isnan([FF.catch_falls])) && any([FF.catch_falls] == 0)
    fprintf(2, ['  ⚠ catch swing did NOT fall with lambda on %d session(s) -- shrinkage buys no ' ...
                'blindness there; do not claim stim-blindness for them.\n'], nnz([FF.catch_falls]==0));
end
save(fullfile(dataDir, sprintf('ctrl_fit_figs%s.mat', pred_suffix)), 'FF');
fprintf('[FITFIG] figures -> %s\n', outDir);

%% ---- local functions (must sit at EOF in a script) ---------------------------
function H = local_hemi(dataDir, tag)
% Hemisphere masks + drawn outline for the brain underlay. Returns [] rather than erroring:
% a missing Stage-1 or ROI cache should cost the underlay, not the figure.
H = [];
f1 = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', tag));
if ~exist(f1,'file'); return; end
S1 = load(f1, 'ipsi_mask','contra_mask');
if ~isfield(S1,'ipsi_mask') || ~isfield(S1,'contra_mask'); return; end
H = struct('ipsi',S1.ipsi_mask, 'contra',S1.contra_mask, 'bx',[],'by',[],'mx',[],'my',[]);
f2 = fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', tag));
if exist(f2,'file')
    R = load(f2, 'bx','by','mx','my');
    H.bx = R.bx;  H.by = R.by;  H.mx = R.mx;  H.my = R.my;   % bx/mx = ROW, by/my = COLUMN
end
end

function bg = local_paint(bg, mask, rgb)
for c = 1:3
    ch = bg(:,:,c);  ch(mask) = rgb(c);  bg(:,:,c) = ch;
end
end

function [r,c] = local_centroid(mask)
[rr,cc] = find(mask);
r = mean(rr);  c = mean(cc);
end

function bb = local_bbox(mask, pad)
[rr,cc] = find(mask);
bb = [max(1,min(rr)-pad), max(rr)+pad, max(1,min(cc)-pad), max(cc)+pad];
end

function C = local_diverging()
% Blue-white-red, built inline so no toolbox colormap is assumed.
n = 128;
t = linspace(0,1,n).';
C = [ [0.02+0.98*t, 0.19+0.81*t, 0.38+0.62*t];      % blue -> white
      [1-0.0*t,     1-0.81*t,    1-0.85*t     ] ];  % white -> red
end
