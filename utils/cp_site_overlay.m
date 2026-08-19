function H = cp_site_overlay(ax, T, dipMap, site_rc, extra_rc, opts)
%CP_SITE_OVERLAY  Laser-effect map + site markers drawn onto an existing image axes.
%
%   Sanity layer for any figure that shows a session's mean image: it puts the
%   DATA-DERIVED laser effect (the trial-averaged peri-stim inhibition map from
%   cp_find_stim_site) and the site markers on top, so the brain picture can be
%   checked against where the laser actually landed. Used while DRAWING the ROI
%   (ctrl_roi_draw_all.m -> cp_roi_masks opts.draw_overlay) -- the midline you
%   click decides which hemisphere is contra, and the only way to know you put it
%   on the right side of the laser spot is to see the spot while clicking.
%
%   Everything is mapped through the session display view T (cp_orient) before it
%   is drawn, so a marker cannot drift off the feature it marks when the view has
%   a transpose or a flip. Pass T = [] for the native frame.
%
% INPUT
%   ax        axes handle (already holding an image; hold state is preserved)
%   T         session display view from cp_orient, or [] for native
%   dipMap    [nY x nX] native inhibition map, %dF/F, NEGATIVE = inhibited
%             (cp_find_stim_site's site.map). [] = markers only.
%   site_rc   [row col] native, the data-derived laser site  -> green +
%   extra_rc  [row col] native, e.g. d.params.pixel          -> magenta x   ([] = skip)
%   opts (optional): .levels  contour levels as FRACTIONS of the map minimum
%                             (default [0.35 0.55 0.80])
%                    .color   contour colour (default [1 0.25 0.1])
%                    .label   annotate the depth (default true)
%                    .site_label / .extra_label   legend-ish text
%
% OUTPUT  H struct of the graphics handles that were created.

if nargin < 6 || isempty(opts), opts = struct(); end
if ~isfield(opts,'levels'),      opts.levels      = [0.35 0.55 0.80]; end
if ~isfield(opts,'color'),       opts.color       = [1 0.25 0.10];    end
if ~isfield(opts,'label'),       opts.label       = true;             end
if ~isfield(opts,'site_label'),  opts.site_label  = 'laser site';     end
if ~isfield(opts,'extra_label'), opts.extra_label = 'params.pixel';   end

was_held = ishold(ax);  hold(ax,'on');
H = struct('contour',[], 'site',[], 'extra',[], 'txt',[]);

% --- laser effect as contours (not a filled overlay: the brain must stay readable
% underneath, because the outline is being clicked on top of it) ------------------
depth = NaN;
if ~isempty(dipMap)
    Dd = cp_orient_img(T, dipMap);
    depth = min(Dd(:), [], 'omitnan');
    if isfinite(depth) && depth < 0
        lv = sort(opts.levels(:).' * depth);            % negative, ascending
        lv = unique(lv);
        if numel(lv) < 2, lv = [lv lv]; end             % contour needs >=2 levels
        [~, H.contour] = contour(ax, Dd, lv, 'LineWidth', 1.3, 'Color', opts.color);
    end
end

% --- markers --------------------------------------------------------------------
if ~isempty(site_rc)
    [sR, sC] = cp_orient_fwd(T, site_rc(1), site_rc(2));
    H.site = plot(ax, sC, sR, '+', 'Color', [0.1 1 0.1], 'MarkerSize', 15, 'LineWidth', 2.4);
end
if ~isempty(extra_rc)
    [eR, eC] = cp_orient_fwd(T, extra_rc(1), extra_rc(2));
    H.extra = plot(ax, eC, eR, 'x', 'Color', [1 0.2 1], 'MarkerSize', 12, 'LineWidth', 2.0);
end

if opts.label
    parts = {};
    if isfinite(depth)
        parts{end+1} = sprintf('laser effect %.2f%% dF/F (%s contours)', depth, ...
            strjoin(arrayfun(@(f) sprintf('%.0f%%',100*f), opts.levels, 'uni',0), '/'));
    end
    if ~isempty(site_rc)
        parts{end+1} = sprintf('+ %s [r%d c%d]', opts.site_label, round(site_rc(1)), round(site_rc(2)));
    end
    if ~isempty(extra_rc)
        parts{end+1} = sprintf('x %s [r%d c%d]', opts.extra_label, round(extra_rc(1)), round(extra_rc(2)));
    end
    if ~isempty(parts)
        H.txt = text(ax, 0.02, 0.02, strjoin(parts, '   '), 'Units','normalized', ...
            'Color', [1 1 0.4], 'FontSize', 8, 'FontWeight','bold', ...
            'VerticalAlignment','bottom', 'Interpreter','none');
    end
end

if ~was_held, hold(ax,'off'); end
end
