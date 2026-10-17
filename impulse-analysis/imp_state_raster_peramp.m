% IMP_STATE_RASTER_PERAMP  Exploratory: state-sorted trial rasters per session x stimulation amplitude.
%
% (user 2026-10-16: "create per amp plots of this and show representative ones here" -- Fig S2's
% pooled raster mixes amplitudes, so the Activity column is a speckle of shallow and deep dips.)
% One figure per session; rows = states (motion | rel delta | abs delta, pre-stim [-1,0) s), columns
% = amplitudes; each cell = Activity (-RS_PRE .. +0.486 s) | Deviation from that amplitude's mean
% (0 .. +0.486 s). Trials in a cell are sorted by the state (low at the bottom); quartile edges marked.
% RAW % dF/F, no normalization: within one session x amplitude nothing needs pooling.
% Exploratory -> PNG only (CLAUDE.md export rule); not in MANIFEST.
%
% RUN (base workspace, after load_experiments + imp_state_trialvar):
%   imp_state_raster_peramp
%   RSA_CLIM = 4; imp_state_raster_peramp     % activity colour range, +/- % dF/F
% (user 2026-10-16) Three candidate amplitudes per mouse = the session's TOP 3 (the dip is invisible
% at the lowest); deviation shown as |x - mu_amp| on a white (0) -> black (RSA_DLIM) scale, so a
% larger spread reads darker. Activity stays signed, grey, +/-RSA_CLIM.

assert(exist('T','var')==1 && isfield(T,'DPaz'), '[RSA] run imp_state_trialvar first');
if ~exist('RSA_CLIM','var') || isempty(RSA_CLIM), RSA_CLIM = 5;   end
if ~exist('RSA_DLIM','var') || isempty(RSA_DLIM), RSA_DLIM = 5;   end
if ~exist('RSA_NAMP','var') || isempty(RSA_NAMP), RSA_NAMP = 3;   end
if ~exist('RS_PRE','var')   || isempty(RS_PRE),   RS_PRE   = 0.2; end
outDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'paper','images','supplementary','state_raster_peramp');
if ~exist(outDir,'dir'), mkdir(outDir); end

%% ---- per-trial traces (raw % dF/F), same loop order as imp_state_trialvar ----------------------
iL = iOn : iOn + floor(STV_L2_WIN*fs - 1e-9);                  % 0 .. +0.486 s
iA = (iOn - round(RS_PRE*fs)) : iL(end);                        % -RS_PRE .. +0.486 s
tA = (iA - iOn)/fs;  tL = (iL - iOn)/fs;
X = []; D = []; eR = []; sS = []; aS = [];
for e = 1:numel(allExperiments)
    imp = allExperiments(e).imp;
    for a = 1:numel(imp.uAmp)
        df = imp.dfImp{a};  pk = imp.Peak_imp{a}(:);
        if isempty(df) || isempty(pk), continue; end
        n = min([size(df,1), numel(pk), size(imp.motTrace{a},1)]);
        if n < 8, continue; end
        if STV_SKIP_AMP0 && imp.uAmp{a} == 0, continue; end
        df = df(1:n,:);  x = df(:, iL);  dv = x - mean(x,1,'omitnan');
        X = [X; df(:, iA)];  D = [D; dv];                                         %#ok<AGROW>
        eR = [eR; sqrt(mean(dv.^2, 2, 'omitnan'))];                               %#ok<AGROW>
        sS = [sS; repmat(e,n,1)];  aS = [aS; repmat(imp.uAmp{a},n,1)];            %#ok<AGROW>
    end
end
assert(isequal(sS, T.sess) && max(abs(eR - T.devRaw)) < 1e-9, '[RSA] rows do not match T');

%% ---- one figure per session -------------------------------------------------------------------
L    = imp_mouse_label({allExperiments.mn});
tags = {'MOTz','DPrz','DPaz'};  names = {'Motion','Rel \delta','Abs \delta'};
cmA  = gray(256);  cmD = flipud(gray(256));
for s = unique(sS).'
    amps = unique(aS(sS == s)).';  amps = amps(max(1, end-RSA_NAMP+1):end);  nA = numel(amps);
    f  = figure('Color','w', 'Units','centimeters', 'Position', [1 1 3.2*nA + 2, 13]);
    tl = tiledlayout(f, 3, 2*nA, 'TileSpacing','tight', 'Padding','compact');
    for k = 1:3
        for ia = 1:nA
            m   = find(sS == s & aS == amps(ia) & isfinite(T.(tags{k})));
            [stS, o] = sort(T.(tags{k})(m));  m = m(o);  nT = numel(m);
            qE  = arrayfun(@(p) find(stS >= quantile(stS,p), 1), [0.25 0.5 0.75]) - 0.5;
            V   = {X(m,:), abs(D(m,:))};  tx = {tA, tL};
            cms = {cmA, cmD};  lims = {[-1 1]*RSA_CLIM, [0 RSA_DLIM]};
            for j = 1:2
                ax = nexttile(tl, (k-1)*2*nA + (ia-1)*2 + j);
                imagesc(ax, tx{j}, 1:nT, V{j});  colormap(ax, cms{j});  clim(ax, lims{j});  hold(ax,'on');
                for q = qE, plot(ax, tx{j}([1 end]), [q q], '-', 'Color', [0.9 0.2 0.2], 'LineWidth', 0.8); end
                if j == 1, xline(ax, -0.5/fs, '--', 'Color', [0.9 0.2 0.2], 'LineWidth', 0.6); end
                set(ax, 'YDir','normal', 'FontSize', 6, 'TickDir','out', 'XTick', [0 0.4], 'YTick', []);
                if k < 3, set(ax, 'XTickLabel', []); end
                if k == 1
                    ttl = {'act', '|dev|'};
                    title(ax, sprintf('%.1f V  %s', amps(ia), ttl{j}), 'FontSize', 6, 'FontWeight', 'normal');
                end
                if ia == 1 && j == 1, ylabel(ax, sprintf('%s (n=%d)', names{k}, nT), 'FontSize', 7); end
            end
        end
    end
    title(tl, sprintf('%s: top %d amplitudes, trials sorted by pre-stim state (raw %% \\DeltaF/F; red = quartile edges / onset)', ...
          L{s}, nA), 'FontSize', 8);
    cb = colorbar(nexttile(tl, 4*nA + 1), 'Location','southoutside');  cb.FontSize = 6;  cb.Label.String = 'activity (% \DeltaF/F)';
    cb = colorbar(nexttile(tl, 6*nA), 'Location','southoutside');  cb.FontSize = 6;  cb.Label.String = '|deviation| (% \DeltaF/F)';
    out = fullfile(outDir, sprintf('raster_peramp_%s.png', strrep(L{s},' ','')));
    exportgraphics(f, out, 'Resolution', 300);  close(f);
    fprintf('[RSA] %s: %d amplitudes -> %s\n', L{s}, nA, out);
end
