function fig2_jn_panels()
% FIG2_JN_PANELS  Lay out the seven JN Fig 2 panels from the .fig files of fig2_jn_capture.m.
%
% JN draft only (Aditya, 2026-11-03). Restyles what the producers drew: canvas, plot box, type sizes,
% legend positions and wording. No data value is touched, and panel letters and content stay the same
% so the vetted caption still holds. Output: paper/figures_final/jn/fig2/*.pdf, exact-size canvases, so
% plot boxes line up across a row when the assembly places them. Fonts per FIGURE_RULEBOOK: 7 pt bold
% labels and titles, 6 pt ticks and annotation. Panel letters are added at assembly.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'utils')));
src = fullfile(root,'paper','figures_final','jn','fig2','src');
out = fullfile(root,'paper','figures_final','jn','fig2');
global PAPER_LABSTYLE                          %#ok<GVMIS> lab-style comparison run (sls_style_fig), 2026-11-05
if ~isempty(PAPER_LABSTYLE) && PAPER_LABSTYLE
    out = fullfile(root,'paper','figures_labstyle','jn','fig2');
    if ~exist(out,'dir'), mkdir(out); end
end
en = char(8211);

H = 3.0;  y0 = 0.72;  yh = 1.90;              % row height; plot box bottom and height (cm)

%% A: traces at five amplitudes; the key goes in a right margin, off the traces
f = open_panel(src,'A',4.1,H);  a = only_ax(f);
all = findall(a);
yNew = [-8.3 5.89];                            % lowest SD edge is -8.05; the old limit left a gap below it
shift = yNew(1) + 0.3 - (-10);
for o = all'
    switch o.Type
        case 'patch'
            if max(o.YData(:)) == 5.89 || abs(max(o.YData(:)) - a.YLim(2)) < 1e-6  % fit-window band
                o.YData(o.YData < 0) = yNew(1);  o.FaceAlpha = 0.28;
            end
        case 'line'
            if numel(o.XData) == 2 && all_equal(o.Color,[0 0 0]) && min(o.YData) == -10   % scale bars
                o.YData = o.YData + shift;  o.LineWidth = 1.0;
            elseif numel(o.XData) > 100
                o.LineWidth = 1.0;
            end
        case 'text'
            s = string(o.String);
            if contains(s,'dF/F'), o.String = ['1% ' char(916) 'F/F']; o.Position(2) = -10 + shift; o.FontWeight = 'bold'; end
            if contains(s,'250 ms'), o.Position(2) = -10.8 + shift + 0.2; end
    end
end
a.YLim = yNew;
pin(a,[0.34 0.38 2.72 2.26]);
lg = findall(f,'Type','legend');
lg.ItemTokenSize = [6 6];  lg.FontSize = 6;  lg.FontWeight = 'bold';
lg.Location = 'none';  pin(lg,[3.02 0.70 1.08 1.30]);
save_panel(f, out, 'A');

%% B: suppression vs laser power, real axes
f = open_panel(src,'B',3.7,H);  a = only_ax(f);
jnAxes(a);
pin(a,[0.98 y0 2.66 yh]);
for o = findall(a)'
    switch o.Type
        case 'line'
            if numel(o.XData) == 100, o.LineWidth = 1.0; elseif numel(o.XData) == 2, o.LineWidth = 0.5; end
        case 'text'
            s = strjoin(string(o.String),'|');
            if contains(s,'Evoked')
                o.String = {'Evoked suppression', ['(% \DeltaF/F, 0' en '200 ms)']};
                o.Units = 'centimeters';  o.Position = [-0.70 yh/2-0.10 0];  o.FontSize = 7;   % 0.10 cm down: centred on the box, the long line touched the top of the page
            end
    end
end
% one row per mouse; the pitch keeps 6 pt rows apart at this box height
yy = struct('m5a',-1.68,'m5b',-2.04,'m1b',-2.40,'m3c',-2.76);
for o = findall(a,'Type','text')'
    s = string(o.String);
    if isscalar(s) && startsWith(s,'Mouse')
        k = lower(strrep(s,'Mouse ','m'));  o.Position(1:2) = [0.30 yy.(k)];  o.FontSize = 6;   % lower left, below the steep Mouse 3c line
    end
end
a.XLabel.String = 'Laser power (mW)';
save_panel(f, out, 'B');

%% C: held-out fit, one session; the key sits in the empty lower right
f = open_panel(src,'C',4.9,H);  a = only_ax(f);
for o = findall(a,'Type','text')', if startsWith(string(o.String),'Mouse'), delete(o); end, end
jnAxes(a);
pin(a,[0.82 y0 3.98 yh]);
a.YTick = -4:2:2;  a.XLabel.String = 'Time from onset (s)';
a.Title.String = 'Held-out LTI fit, Mouse 1b';
lg = findall(f,'Type','legend');
lg.ItemTokenSize = [7 6];  lg.FontSize = 6;  lg.FontWeight = 'bold';
lg.Location = 'none';  pin(lg,[2.60 0.80 2.20 0.98]);
save_panel(f, out, 'C');

%% D: held-out R2 per session; short title, level ticks
f = open_panel(src,'D',3.3,H);  a = only_ax(f);
jnAxes(a);
pin(a,[0.72 y0 2.52 yh]);
a.XAxis.FontSize = 6;  xtickangle(a,0);  a.YTick = 0.2:0.2:1;
a.YLabel.String = 'Held-out R^2';  a.Title.String = 'LTI validation';
for o = findall(a,'Type','text')', o.FontSize = 6; end
for o = findall(a,'Type','line')', if numel(o.XData) == 2, o.LineWidth = 0.75; end, end
save_panel(f, out, 'D');

%% E: model swap; larger cell numbers
f = open_panel(src,'E',4.7,H);  a = only_ax(f);
jnAxes(a);
pin(a,[1.08 y0 2.60 yh]);
a.XLabel.String = 'Applied to session';  a.YLabel.String = 'Model from session';
for o = findall(a,'Type','text')', o.FontSize = 6; end
cb = findall(f,'Type','colorbar');
pin(cb,[3.76 y0 0.13 yh]);
cb.Ticks = 0:0.5:1;  cb.FontSize = 6;  cb.FontWeight = 'normal';  cb.Label.FontSize = 6;  cb.Label.FontWeight = 'bold';
save_panel(f, out, 'E');

%% F: time constants; same row order as D and E, key in the band below the rows
f = open_panel(src,'F',3.5,H);  a = only_ax(f);
jnAxes(a);
a.YDir = 'reverse';  a.YLim = [0.4 5.1];
a.XLabel.String = '';  a.Title.String = '';     % stored label positions do not follow the flipped axis
text(a, 0.5, -0.22, '\tau (s)', 'Units','normalized', 'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize',7, 'FontWeight','bold');
text(a, 0.5, 1.03, 'Timescales', 'Units','normalized', 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'FontSize',7, 'FontWeight','bold');
pin(a,[0.72 y0 2.68 yh]);
for o = findall(a,'Type','text')', if contains(string(o.String),' s') && ~contains(string(o.String),'tau'), o.FontSize = 6;  o.Position(1:2) = [0.122 0.60]; end, end
lg = findall(f,'Type','legend');
lg.ItemTokenSize = [6 6];  lg.FontSize = 6;  lg.FontWeight = 'bold';  lg.Orientation = 'horizontal';
lg.Location = 'none';  pin(lg,[1.05 0.74 2.30 0.24]);
save_panel(f, out, 'F');

%% G: state dependence; one-line axis names by frequency, legend off the data
f = open_panel(src,'G',8.4,H);
tl = findall(f,'Type','tiledlayout');
ax = flipud(findall(f,'Type','axes'));         % motion, relative, absolute
names = {'Motion', ['Relative 2' en '4 Hz'], ['Absolute 2' en '4 Hz']};
order = zeros(1,3);
for k = 1:3
    xl = strjoin(string(ax(k).XLabel.String),' ');
    if contains(xl,'Motion'), order(k) = 1; elseif contains(xl,'relative'), order(k) = 2; else, order(k) = 3; end
end
[~,ix] = sort(order);  ax = ax(ix);
delete(findall(f,'Type','legend'));
for k = 1:3
    jnAxes(ax(k));  ax(k).XLabel.String = names{k};
    if k > 1, set(ax(k),'YTick',[],'YColor','none'); end
end
ax(1).YTick = 0.5:0.5:1.5;
ax(1).YLabel.String = {'Trial-to-trial', 'variability (\times typical)'};
title(tl, '');  title(ax(2), 'Response variability by state', 'FontSize', 7, 'FontWeight', 'bold');
tl.TileSpacing = 'compact';
tl.Units = 'centimeters';  tl.InnerPosition = [1.12 y0 7.20 yh];
lns = findobj(ax(1),'Type','line','Marker','o','-depth',1);
hS = lns(arrayfun(@(l) strcmp(l.LineStyle,'-') && all_equal(l.Color,[0 0 0]), lns));
hC = lns(arrayfun(@(l) strcmp(l.LineStyle,'--'), lns));
lg = legend(ax(1), [hS hC], {'Stim','Stimulus-free'}, 'Box','off', 'FontSize',6, 'FontWeight','bold');
lg.ItemTokenSize = [8 6];
drawnow;
lg.Location = 'none';  pin(lg,[1.14 y0+0.12 1.60 0.48]);
save_panel(f, out, 'G');
end

% ---------------------------------------------------------------------------------------------------
function f = open_panel(src, n, W, H)
o = openfig(fullfile(src,[n '.fig']),'invisible');
f = figure('Visible','off','MenuBar','none','ToolBar','none','Units','centimeters','Color','w', ...
           'Position',[2 2 12 6],'UserData',[W H]);
kids = allchild(o);
keep = kids(ismember(string(get(kids,'Type')), ["axes" "legend" "colorbar" "tiledlayout"]));
copyobj(keep, f);
close(o);
end

function pin(h, pos)
% Fix a position in cm for good. The stored axes keep an outer-position constraint, and MATLAB's lazy layout
% then shrank the plot box by a different amount from one run to the next. save_panel re-applies and checks it.
if isprop(h,'PositionConstraint'), h.PositionConstraint = 'innerposition'; end
h.Units = 'centimeters';  h.Position = pos;  setappdata(h,'pinned',pos);
end

function a = only_ax(f)
a = findall(f,'Type','axes');
assert(isscalar(a));
end

function tf = all_equal(a,b)
tf = isequal(a(:)',b(:)');
end

function save_panel(f, out, n)
% print on a page the same size as the 12 x 6 cm window, then fig2_jn_crop.py keeps the bottom-left canvas
% and checks the type sizes. Not exportgraphics, which scaled by an on-screen window size that changed
% between calls (type came out 5.5 or 8.5 pt instead of 6). print scales positions by page/window, so the
% window size is checked too.
W = f.UserData(1);  H = f.UserData(2);
global PAPER_LABSTYLE                          %#ok<GVMIS>
if ~isempty(PAPER_LABSTYLE) && PAPER_LABSTYLE, sls_style_fig(f); end
drawnow;
pinned = findall(f,'-function',@(h) isappdata(h,'pinned'));
for h = pinned', h.Position = getappdata(h,'pinned'); end
drawnow;
for h = pinned'
    p = getappdata(h,'pinned');  q = h.Position;
    if strcmp(h.Type,'legend')      % a legend sizes itself to its text around the requested centre
        q = q(1:2) + q(3:4)/2;  p = p(1:2) + p(3:4)/2;
    end
    assert(norm(q - p) < 0.02, '[F2JN] %s: %s moved to %s', n, h.Type, mat2str(h.Position,4));
end
assert(all(abs(f.Position(3:4) - [12 6]) < 0.05), '[F2JN] %s: window is %.2f x %.2f', n, f.Position(3:4));
set(f,'PaperUnits','centimeters','PaperPositionMode','manual','PaperSize',[12 6],'PaperPosition',[0 0 12 6],'InvertHardcopy','off');
% print sometimes squeezes the page vertically by 9%, at random: check each print and print again if so
pdf = fullfile(out,[n '.pdf']);
chk = fullfile(fileparts(mfilename('fullpath')),'fig2_jn_boxcheck.py');
for attempt = 1:10
    print(f, pdf, '-dpdf', '-vector');
    [st, txt] = system(sprintf('python -X utf8 -I "%s" "%s" %s', chk, pdf, n));
    if st == 0, break; end
    f.Position(4) = 6.05;  drawnow;  f.Position(4) = 6;  drawnow;   % force a new layout of the window
end
assert(st == 0, '[F2JN] %s failed the box check after %d prints: %s', n, attempt, txt);
if attempt > 1, fprintf('[F2JN] %s needed %d prints\n', n, attempt); end
fid = fopen(fullfile(out,[n '.size']),'w');  fprintf(fid,'%.4f %.4f', W, H);  fclose(fid);
fprintf('[F2JN] %s canvas %.2f x %.2f cm\n', n, W, H);
close(f);
end
