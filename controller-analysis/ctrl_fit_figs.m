%% ctrl_fit_figs.m   [FITFIG]  -- per-session PREDICTION and KERNEL for the contra->ipsi model
%
% One figure per session answering the two questions the R^2 number alone cannot:
%   (left)  does the held-out prediction actually track the ipsi trace, or is R^2 being carried
%           by a few excursions? Drawn from the cached test block -- data the fit never saw.
%   (right) WHERE does the prediction come from? The fitted weight map on the contra grid, i.e.
%           the kernel. A predictor leaning on a handful of extreme weights is a different object
%           from one with a smooth distributed map, and R^2 does not distinguish them.
%
% READS ONLY -- no session is opened. The held-out snippet is cached by Stage 2 as OL.VAL
% (added 2026-08-12; before that the prediction existed only inside the run that made it).
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
FF_SNIP_S = 60;            % seconds of the test block to draw

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
fprintf('  %-24s %7s %7s %6s %8s %9s\n','session','R2_te','rho','nPx','||b||','lambda');
for ff_i = 1:numel(ff_files)
    S2 = load(fullfile(dataDir, ff_files(ff_i).name));
    ff_tag = erase(erase(erase(ff_files(ff_i).name,'ctrl_ols_ol_stimblind'),[pred_suffix '_']),'.mat');
    if startsWith(ff_tag,'_'); ff_tag = ff_tag(2:end); end
    if ~isfield(S2,'VAL')
        fprintf('  %-24s SKIP (cache predates the VAL snippet -- rebuild this session)\n', ff_tag);
        continue
    end
    V = S2.VAL;  Fs = S2.Fs;
    ff_n  = min(numel(V.yte), round(FF_SNIP_S*Fs));
    ff_t  = (0:ff_n-1)/Fs;
    ff_rho = corr(V.yte(:), V.yhat(:));
    ff_lam = NaN;
    if isfield(S2,'bnorm'); ff_nrm = S2.bnorm; else; ff_nrm = norm(S2.b); end
    if isfield(S2,'lambda'); ff_lam = S2.lambda; end

    figF = figure('Color','w','Position',[60 70 1250 460]);
    tl = tiledlayout(figF,1,2,'TileSpacing','compact','Padding','compact');

    % --- (left) held-out prediction ------------------------------------------------
    ax1 = nexttile(tl,1); hold(ax1,'on');
    plot(ax1, ff_t, V.yte(1:ff_n),  '-', 'Color',[0.15 0.15 0.15], 'LineWidth',1.4);
    plot(ax1, ff_t, V.yhat(1:ff_n), '-', 'Color',[0.85 0.35 0.05], 'LineWidth',1.1);
    xlabel(ax1,'time in held-out block (s)'); ylabel(ax1,'ipsi \DeltaF/F (%)');
    legend(ax1,{'actual','predicted from contra'},'Box','off','Location','best','FontSize',8);
    xlim(ax1,[0 ff_t(end)]);
    title(ax1, sprintf('held-out R^2 = %.3f   (\\rho = %.3f)', V.R2_te, ff_rho));

    % --- (right) the kernel: fitted weights on the contra grid ---------------------
    % Su indexes into the grid, so weights are scattered at their own grid coordinates. A
    % DIVERGING scale centred on zero: sign matters (which contra regions push the estimate up
    % vs down), and a one-sided colormap would hide it.
    ax2 = nexttile(tl,2); hold(ax2,'on');
    ff_b = zeros(numel(S2.gridIdx),1);  ff_b(S2.Su) = S2.b;
    ff_lim = max(abs(ff_b));  if ff_lim == 0 || ~isfinite(ff_lim); ff_lim = 1; end
    scatter(ax2, S2.grC, S2.grR, 26, ff_b, 'filled');
    plot(ax2, S2.px_prim, S2.py_prim, 'kp', 'MarkerSize',13, 'MarkerFaceColor',[1 1 0.2]);
    colormap(ax2, local_diverging());  clim(ax2, ff_lim*[-1 1]);
    cb = colorbar(ax2);  cb.Label.String = 'weight';
    axis(ax2,'image');  set(ax2,'YDir','reverse');
    xlabel(ax2,'column (px)'); ylabel(ax2,'row (px)');
    title(ax2, sprintf('kernel: %d px, ||b|| = %.1f, max|b| = %.2f', ...
        numel(S2.Su), ff_nrm, max(abs(S2.b))));

    ff_hdr = sprintf('[FITFIG] %s   mode=%s', strrep(ff_tag,'_','\_'), pred_mode);
    if isfinite(ff_lam); ff_hdr = sprintf('%s  \\lambda=%.3g', ff_hdr, ff_lam); end
    if V.R2_te < r2_floor; ff_hdr = sprintf('%s   [BELOW FLOOR %.2f]', ff_hdr, r2_floor); end
    sgtitle(figF, ff_hdr);
    if FF_EXPORT
        for ff_k = 1:numel(FF_FMT)
            exportgraphics(figF, fullfile(outDir, ...
                sprintf('ctrl_fit_%s%s.%s', ff_tag, pred_suffix, FF_FMT{ff_k})), 'Resolution',300);
        end
    end

    ff_j = numel(FF)+1;
    FF(ff_j).sess_tag = ff_tag;  FF(ff_j).R2_te = V.R2_te;  FF(ff_j).rho = ff_rho;
    FF(ff_j).nPx = numel(S2.Su); FF(ff_j).bnorm = ff_nrm;   FF(ff_j).lambda = ff_lam;
    if isfield(S2,'leak_sus');   FF(ff_j).leak = S2.leak_sus; else; FF(ff_j).leak = NaN; end
    if isfield(S2,'catch_falls');FF(ff_j).catch_falls = S2.catch_falls; else; FF(ff_j).catch_falls = NaN; end
    fprintf('  %-24s %7.3f %7.3f %6d %8.1f %9.3g\n', ff_tag, V.R2_te, ff_rho, numel(S2.Su), ff_nrm, ff_lam);
end

%% [FITFIG-REPORT] --------------------------------------------------------------
assert(~isempty(FF), '[FITFIG] no cache carried a VAL snippet -- rebuild Stage 2.');
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
function C = local_diverging()
% Blue-white-red, built inline so no toolbox colormap is assumed.
n = 128;
t = linspace(0,1,n).';
C = [ [0.02+0.98*t, 0.19+0.81*t, 0.38+0.62*t];      % blue -> white
      [1-0.0*t,     1-0.81*t,    1-0.85*t     ] ];  % white -> red
end
