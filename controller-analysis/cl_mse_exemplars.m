% controller-analysis/cl_mse_exemplars.m
% Exemplar CL trials illustrating each factor's contribution to trial RMSE.
%
% Companion to cl_mse_factors.m -- SAME three predictors, same windows:
%   X1 -- |dF/F at stim onset - ref|     (initial deviation)
%   X2 -- z-motion energy, 2 s pre -> trial end
%   X3 -- pre-trial dF/F std, 1 s before onset  (LF/slow-variance proxy)
%
% Selects ISOLATING exemplars: trials high on ONE factor and low on the other
% two, so each row shows that factor's contribution with the others held down.
% Feasible because the predictors are near-uncorrelated (r = 0.03 / 0.18 / -0.06).
%
% Row 0 is a low-everything / low-error reference trial for visual contrast.
%
% NOTE ON INTERPRETATION: X1's sample sits INSIDE the RMSE window, and X3 is a
% magnitude of the same dFk trace as the outcome. The onset marker and the
% shaded RMSE window are drawn deliberately so this is visible rather than
% hidden -- for a high-X1 trial the marker sits inside the shading.
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;

PS = paperStyle();
setPaperDefaults();

if exist(fullfile('paper','images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
    warning('cl_mse_exemplars: cannot locate paper/ -- exporting locally.');
end

% ---- constants (mirror cl_mse_factors.m) ----
Fs        = 35;
c0        = 36;    % onset col in wcDfk
c0_mot    = 71;    % onset col in wcmotion
c0_l      = 106;   % onset col in pwcDfk_l  (3 s pre)
pre_s     = 1;     % X3 window
mot_pre_s = 2;     % X2 window start

disp_pre_s  = 2;   % display window: stim -2 s
disp_post_s = 5;   % ... to stim end (+3 s) + 2 s

%% -- Pool CL trials, keeping session + trial provenance -------------------

Y=[]; X1=[]; X2=[]; X3=[]; SESS=[]; TRI=[];

for k = 1:numel(fields)
    s = mouse.(fields{k});
    if isfield(s,'skip') && s.skip;      continue; end
    if ~isfield(s,'data');               continue; end
    if ~s.has_motion;                    continue; end
    dk = s.data;
    if ~isfield(dk,'wcmotion');          continue; end

    ref_k = s.d.ref;
    dur_k = s.d.params.dur;
    nT    = size(dk.wcDfk, 1);

    x1_k = abs(dk.wcDfk(:, c0) - ref_k);

    ws = max(1, c0_mot - round(mot_pre_s * Fs));
    we = min(size(dk.wcmotion, 2), c0_mot + round(dur_k * Fs) - 1);
    x2_k = mean(dk.wcmotion(1:nT, ws:we) .^ 2, 2);

    pre_end   = c0 - 1;
    pre_start = max(1, c0 - round(pre_s * Fs));
    x3_k = std(dk.wcDfk(1:nT, pre_start:pre_end), 0, 2);

    n_use = min([numel(dk.er_wcDfk), numel(x1_k), numel(x2_k), numel(x3_k)]);

    Y    = [Y;    dk.er_wcDfk(1:n_use)];  %#ok<*AGROW>
    X1   = [X1;   x1_k(1:n_use)];
    X2   = [X2;   x2_k(1:n_use)];
    X3   = [X3;   x3_k(1:n_use)];
    SESS = [SESS; repmat(k, n_use, 1)];
    TRI  = [TRI;  (1:n_use)'];
end

ok = all(isfinite([Y X1 X2 X3]), 2);
Y=Y(ok); X1=X1(ok); X2=X2(ok); X3=X3(ok); SESS=SESS(ok); TRI=TRI(ok);
n = numel(Y);
fprintf('\n[cl_mse_exemplars] %d valid CL trials pooled.\n', n);

Z  = zscore([X1 X2 X3]);      % [n x 3]
Yz = (Y - mean(Y)) / std(Y);

fac_names  = {'Initial deviation', 'Motion energy', 'Pre-trial std'};
fac_short  = {'X1 onset dev', 'X2 motion', 'X3 pre-std'};
fac_cols   = [0.20 0.40 0.75; 0.75 0.40 0.10; 0.20 0.60 0.35];

%% -- Select isolating exemplars -------------------------------------------
% high on target factor, low on the other two; relax thresholds if starved.

nEx  = 3;                       % exemplars per factor
pick = nan(3, nEx);

for j = 1:3
    oth = setdiff(1:3, j);
    got = [];
    for hi_p = [85 80 75 70]                       % target-factor percentile
        for lo_p = [50 60 70]                      % other-factors ceiling
            hi_thr = prctile(Z(:,j),   hi_p);
            lo_thr = prctile(Z(:,oth), lo_p);
            cand = find(Z(:,j) >= hi_thr & ...
                        Z(:,oth(1)) <= lo_thr(1) & ...
                        Z(:,oth(2)) <= lo_thr(2));
            if numel(cand) >= nEx
                [~, ord] = sort(Z(cand,j), 'descend');
                got = cand(ord(1:nEx));
                break
            end
        end
        if ~isempty(got); break; end
    end
    if isempty(got)
        [~, ord] = sort(Z(:,j), 'descend');        % fallback: purest available
        got = ord(1:nEx);
        warning('cl_mse_exemplars: no isolating trials for %s; using top-z.', fac_names{j});
    end
    pick(j,:) = got(:)';
end

fprintf('\nSelected exemplars (z-scores | RMSE):\n');
fprintf('  %-18s  %-6s %-6s %-6s  %-7s  %s\n', 'row', 'zX1','zX2','zX3','RMSE','session/trial');
for j = 1:3
    for i = 1:nEx
        t = pick(j,i);
        fprintf('  %-18s  %+6.2f %+6.2f %+6.2f  %7.2f  %s tr%d\n', ...
            ternL(i==1, fac_names{j}, ''), Z(t,1),Z(t,2),Z(t,3), Y(t), fields{SESS(t)}, TRI(t));
    end
end
fprintf('\nPool RMSE: mean %.2f  median %.2f  sd %.2f\n', mean(Y), median(Y), std(Y));

%% -- Figure: 3 factor rows x nEx exemplar trials --------------------------

tvec  = (-disp_pre_s : 1/Fs : disp_post_s)';                 % dF/F time base
dcols = (c0_l - disp_pre_s*Fs) : (c0_l + disp_post_s*Fs);

rows   = num2cell(pick, 2);      % 3 factor rows (reference row removed)
rowlbl = fac_names;
rowcol = fac_cols;               % blue / orange / green

% common y-scale across all rows: scan every plotted trace
gmn = inf; gmx = -inf;
for t = pick(:)'
    seg = mouse.(fields{SESS(t)}).data.pwcDfk_l(TRI(t), dcols);
    gmn = min(gmn, min(seg)); gmx = max(gmx, max(seg));
end
pad = 0.10*(gmx-gmn); yl = [gmn-pad, gmx+pad];

fig = paperFig(19, 11);
tl  = tiledlayout(fig, 3, nEx, 'TileSpacing','compact', 'Padding','compact');

for r = 1:3
    idxr = rows{r}; if iscell(idxr); idxr = idxr{1}; end
    for i = 1:numel(idxr)
        t   = idxr(i);
        dk  = mouse.(fields{SESS(t)}).data;
        ref = mouse.(fields{SESS(t)}).d.ref;
        tr  = TRI(t);
        trace = dk.pwcDfk_l(tr, dcols);

        ax = nexttile(tl); hold(ax,'on');

        % RMSE window shading (0 -> +3 s) -- the outcome window
        patch(ax, [0 3 3 0], [yl(1) yl(1) yl(2) yl(2)], [0.88 0.88 0.88], ...
              'EdgeColor','none', 'FaceAlpha', 0.5);
        % reference level
        plot(ax, tvec([1 end]), [ref ref], '--', 'Color',[0.3 0.3 0.3], 'LineWidth', PS.lw_ref);
        % dF/F trace (row colour)
        plot(ax, tvec, trace, '-', 'Color', rowcol(r,:), 'LineWidth', PS.lw_mean);
        % X1 onset sample marker
        plot(ax, 0, dk.wcDfk(tr, c0), 'o', 'MarkerSize', 4, ...
             'MarkerFaceColor', rowcol(r,:), 'MarkerEdgeColor','k', 'LineWidth', 0.5);

        ylim(ax, yl); xlim(ax, [-disp_pre_s disp_post_s]);
        set(ax,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold','YColor',[0 0 0]);

        % z-contributions: colour each by its factor, bold the row's own factor
        text(ax,0.02,0.95,'z','Units','normalized','FontSize',5,'FontWeight','bold','Color',[0.3 0.3 0.3]);
        zx = [0.09 0.25 0.41];
        for jj = 1:3
            fw = 'normal'; if jj==r; fw = 'bold'; end
            text(ax, zx(jj), 0.95, sprintf('%+.1f',Z(t,jj)), 'Units','normalized', ...
                 'FontSize',5,'FontWeight',fw,'Color',rowcol(jj,:));
        end
        text(ax,0.62,0.95,sprintf('RMSE %.1f',Y(t)),'Units','normalized', ...
             'FontSize',5,'FontWeight','bold','Color',[0.1 0.1 0.1]);
        % session/trial tag
        text(ax,0.02,0.06,sprintf('%s tr%d',fields{SESS(t)},tr),'Units','normalized', ...
             'FontSize',4.5,'Color',[0.5 0.5 0.5]);

        if i == 1
            ylabel(ax, sprintf('%s\n\\DeltaF/F (%%)', rowlbl{r}), ...
                   'FontSize',6,'FontWeight','bold','Color',rowcol(r,:));
        end
        if r == 3; xlabel(ax,'time from onset (s)','FontSize',5,'FontWeight','bold'); end
        hold(ax,'off');
    end
end

title(tl, sprintf('CL trial exemplars by error factor  (n=%d trials, 9 sessions)', n), ...
    'FontSize',7,'FontWeight','bold');

paperExport(fig, fullfile(paper_root,'images','figure4','cl_mse_exemplars.png'));
fprintf('\n[cl_mse_exemplars] Exported cl_mse_exemplars.png\n');

function s = ternL(c, a, b); if c; s=a; else; s=b; end; end
