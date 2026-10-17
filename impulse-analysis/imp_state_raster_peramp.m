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
% Activity: blue (negative, the dip) - white - red (positive) (user 2026-10-16: "non grayscale
% colour bar for activity, like blue to red"); |deviation| stays white -> black.
cmA  = local_bwr(256);  cmD = flipud(gray(256));
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
                for q = qE, plot(ax, tx{j}([1 end]), [q q], '-', 'Color', [0 0 0], 'LineWidth', 0.8); end
                if j == 1, xline(ax, -0.5/fs, '--', 'Color', [0 0 0], 'LineWidth', 0.6); end
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
    title(tl, sprintf('%s: top %d amplitudes, trials sorted by pre-stim state (raw %% \\DeltaF/F; black = quartile edges / onset)', ...
          L{s}, nA), 'FontSize', 8);
    cb = colorbar(nexttile(tl, 4*nA + 1), 'Location','southoutside');  cb.FontSize = 6;  cb.Label.String = 'activity (% \DeltaF/F)';
    cb = colorbar(nexttile(tl, 6*nA), 'Location','southoutside');  cb.FontSize = 6;  cb.Label.String = '|deviation| (% \DeltaF/F)';
    out = fullfile(outDir, sprintf('raster_peramp_%s.png', strrep(L{s},' ','')));
    exportgraphics(f, out, 'Resolution', 300);  close(f);
    fprintf('[RSA] %s: %d amplitudes -> %s\n', L{s}, nA, out);
end

%% ---- Fig S2 strips: ONE amplitude per mouse (rule: each session's SECOND-highest) -------------
% (user 2026-10-16: "Put one amplitude per mouse into Fig S2, chosen by rule (each mouse's
% second-highest amplitude), as activity + |dev| strips".) Replaces the pooled strip, which mixed
% amplitudes. Full width (17.6 cm), one strip per state: 4 mice x {Activity, |Deviation|}.
% Native PNGs swapped into the PDF (utils/pdf_swap_images.py) so every trial is kept losslessly.
if ~exist('RSA_S2','var') || isempty(RSA_S2), RSA_S2 = true; end
% RSA_S2_AMP: 'second' (FINAL rule, in MANIFEST) | 'top' (highest amplitude; comparison copy,
% written with a _top suffix and NOT mirrored to figures_final)
if ~exist('RSA_S2_AMP','var') || isempty(RSA_S2_AMP), RSA_S2_AMP = 'second'; end
sfx = '';  if strcmp(RSA_S2_AMP, 'top'), sfx = '_top'; end
if RSA_S2
    J    = jnStyle();
    global PAPER_FINAL %#ok<GVMIS,TLEV>
    root = fileparts(fileparts(mfilename('fullpath')));
    rDir = fullfile(root, 'paper','images','supplementary','state_quartile');
    nDir = fullfile(rDir, '_native');  if ~exist(nDir,'dir'), mkdir(nDir); end
    swp  = fullfile(root, 'utils', 'pdf_swap_images.py');
    tagF = {'mot','dpr','dpa'};  rowN = {'Motion','Rel. \delta','Abs. \delta'};
    sOrd = unique(sS).';                                  % load order = Mouse 5a, 5b, 1, 3
    W = J.W_double;  H = 3.0;  hH = 2.0;  y0 = 0.5;  x0 = 0.6;  gG = 0.35;  gW = 0.08;   % hH = heatmap height (cm)
    pw = (W - x0 - 0.1 - 3*gG - 4*gW) / 8;               % cm per heatmap
    cms = {cmA, cmD};  lims = {[-1 1]*RSA_CLIM, [0 RSA_DLIM]};  colT = {'Activity', '|Deviation|'};
    for k = 1:3
        f = jnFig(W, H);  pngs = {};
        for is = 1:numel(sOrd)
            s = sOrd(is);  amps = unique(aS(sS == s));  if strcmp(RSA_S2_AMP,'top'), a2 = amps(end); else, a2 = amps(end-1); end
            m = find(sS == s & aS == a2 & isfinite(T.(tags{k})));
            [stS, o] = sort(T.(tags{k})(m));  m = m(o);  nT = numel(m);
            qE = arrayfun(@(p) find(stS >= quantile(stS,p), 1), [0.25 0.5 0.75]) - 0.5;
            qM = [0.5, qE, nT+0.5];  qM = (qM(1:end-1) + qM(2:end))/2;
            V  = {X(m,:), abs(D(m,:))};  tx = {tA, tL};
            for j = 1:2
                xp = x0 + (is-1)*(2*pw + gW + gG) + (j-1)*(pw + gW);
                ax = axes(f, 'Units','centimeters', 'Position', [xp, y0, pw, hH]);
                imagesc(ax, tx{j}, 1:nT, V{j});  colormap(ax, cms{j});  clim(ax, lims{j});  hold(ax,'on');
                dt = mean(diff(tx{j}));  xq = tx{j}([1 end]) + [-0.5 0.5]*dt;
                for q = qE                                   % white core on black casing
                    plot(ax, xq, [q q], '-', 'Color', [0 0 0], 'LineWidth', 1.0);
                    plot(ax, xq, [q q], '-', 'Color', [1 1 1], 'LineWidth', 0.4);
                end
                if j == 1, plot(ax, [0 0] - 0.5*dt, [0.5 nT+0.5], '--', 'Color', [0 0 0], 'LineWidth', 0.5); end
                set(ax, 'YDir','normal', 'Layer','top', 'YTick', qM, 'YTickLabel', {'Q1','Q2','Q3','Q4'}, ...
                        'XTick', [0 0.2 0.4], 'XTickLabelRotation', 0, 'XLim', xq);
                if ~(is == 1 && j == 1), set(ax, 'YTickLabel', []); end
                if k < 3, set(ax, 'XTickLabel', []); end
                jnAxes(ax);  set(ax, 'TickLength', [0.02 0.02]);
                if is == 1 && j == 1, ylabel(ax, rowN{k}); end
                if k == 1                                    % column + mouse headers, top strip only
                    text(ax, mean(xq), nT*1.03, colT{j}, 'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                         'FontName', J.font, 'FontSize', 5, 'Interpreter','none', 'Clipping','off');
                    if j == 1
                        text(ax, xq(2) + (gW/2)/pw*diff(xq), nT*1.16, sprintf('%s, %.1f V (n = %d)', L{s}, a2, nT), ...
                             'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'FontName', J.font, ...
                             'FontSize', 6, 'FontWeight','bold', 'Interpreter','none', 'Clipping','off');
                    end
                end
                if k == 3 && is == 1 && j == 1               % one time label, centred under the strip
                    xl = xlabel(ax, 'Time from stimulus onset (s)');  xl.Units = 'centimeters';
                    xl.Position(1) = (x0 + (W - x0 - 0.1)/2) - xp;
                end
                % native heatmap: row 1 = lowest state at the BOTTOM -> top PNG row = last trial
                ci = round((min(max(V{j}, lims{j}(1)), lims{j}(2)) - lims{j}(1)) / diff(lims{j}) * 255) + 1;
                ci(~isfinite(V{j})) = 128;
                pngs{end+1} = fullfile(nDir, sprintf('sq_%s_rmice%s_%d_%d.png', tagF{k}, sfx, is, j)); %#ok<AGROW>
                imwrite(ind2rgb(flipud(ci), cms{j}), pngs{end});
            end
        end
        pdfOut = fullfile(rDir, sprintf('sq_%s_rmice%s.pdf', tagF{k}, sfx));
        jnExport(f, pdfOut);  close(f);
        fin = fullfile(root, 'paper','figures_final','panels','supp_state_quartile', sprintf('sq_%s_rmice%s.pdf', tagF{k}, sfx));
        targets = {pdfOut};
        if ~isempty(PAPER_FINAL) && PAPER_FINAL && exist(fin,'file'), targets{end+1} = fin; end %#ok<AGROW>
        for t = 1:numel(targets)
            [rc, msg] = system(sprintf('python -I "%s" "%s" %s', swp, targets{t}, strjoin(strcat('"', pngs, '"'), ' ')));
            fprintf('%s', msg);  assert(rc == 0, '[RSA] image swap failed for %s', targets{t});
        end
    end
    % colour keys (place once): activity signed, |deviation| sequential
    keys = {'sq_rmice_cbar_act.pdf', cmA, lims{1}, 'Activity (% ΔF/F)'; ...
            'sq_rmice_cbar_dev.pdf', cmD, lims{2}, '|Deviation| (% ΔF/F)'};
    for kk = 1:2
        f = jnFig(1.9, 0.55);
        axK = axes(f, 'Units','centimeters', 'Position', [0.25 0.35 1.4 0.001], 'Visible','off');
        colormap(axK, keys{kk,2});  clim(axK, keys{kk,3});
        cb = colorbar(axK, 'Location','south', 'Units','centimeters');  cb.Position = [0.25 0.3 1.4 0.08];
        cb.Ticks = keys{kk,3};  cb.TickLength = 0;  cb.Box = 'on';  cb.LineWidth = 0.25;  cb.AxisLocation = 'in';
        cb.Label.String = keys{kk,4};  cb.Label.Interpreter = 'none';
        set(cb, 'FontSize', 5, 'FontName', J.font);  cb.Label.FontSize = 5;
        jnExport(f, fullfile(rDir, keys{kk,1}));  close(f);
    end
end

function cm = local_bwr(n)
% Diverging blue (negative) - white - red (positive), ColorBrewer RdBu end points.
a = [0.13 0.40 0.67];  w = [1 1 1];  b = [0.70 0.09 0.17];
h = floor(n/2);
cm = [interp1([0 1], [a; w], linspace(0,1,h)); interp1([0 1], [w; b], linspace(0,1,n-h))];
end
