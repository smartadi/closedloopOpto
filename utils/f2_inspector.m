function f2_inspector(fig, IX, varargin)
%F2_INSPECTOR  Click a point in the Fig-2 state scatter -> open that TRIAL and show why it sits there.
%
% WHAT THIS ANSWERS. The state scatter reduces each trial to two numbers (a DV and a state scalar).
% When a trial sits at the edge of the cloud, the scatter cannot tell you whether that is a real
% response, a failed prediction, or a state scalar driven by one motion spike. This opens the trial
% and shows the four things needed to decide, on the SAME windows the statistics used:
%
%   (1) TRACES        actual ipsi, the stim-blind prediction, and the residual for THIS trial, with
%                     the amp-mean residual overlaid. If the prediction already fails BEFORE onset,
%                     the trial's dip deviation is baseline mis-fit, not a state effect -- that is
%                     what the pre-onset window (shaded grey) is there to let you see.
%   (2) MOTION        the raw motion trace over the exact [-2,+0.5] s window MOT sums |z| over. A
%                     high MOT built from one spike is a different animal from sustained movement.
%   (3) STATE WINDOW  the raw ipsi trace over the [-1,+0.5] s window var and delta are computed on.
%   (4) SPECTRUM      that window's power spectrum with the 1-4 Hz delta band shaded, so the delta
%                     scalars are visible as a shape rather than asserted as a number.
%
% All four windows are re-derived here from the SAME constants as utils/imp_statedep_trials.m. If
% you change a window there, change it here -- they are deliberately written out rather than shared,
% because a silent mismatch between what is tested and what is displayed is worse than a duplicate.
%
% USAGE
%   f2_inspector(fig, IX)               arm the figure for clicking (this is what f2_state does)
%   f2_inspector(fig, [], s, i, k)      open session s, trial-row i, under state k WITHOUT clicking
%
% The programmatic form is not just for tests: "show me the trial behind the biggest deviation" is
% a question you ask far more often than you can answer by aiming a mouse at a dense scatter. E.g.
%   IX = guidata(fig);  [~,i] = max(IX.sess(1).dv);  f2_inspector(fig, [], 1, i, 1)
%
% One detail figure, reused in place.
% -------------------------------------------------------------------------------------------------
if nargin >= 3
    if isempty(IX), IX = guidata(fig); end
    local_detail(IX, varargin{1}, varargin{2}, varargin{3});
    return
end
set(fig, 'WindowButtonDownFcn', @(s,~) local_click(s));
guidata(fig, IX);
fprintf(['[F2-STATE] investigator ARMED: click any point in the state scatter -> that trial''s\n' ...
         '           traces, motion window, state window and spectrum open in a detail figure.\n' ...
         '           Or jump straight to one:  f2_inspector(gcf, [], sessIdx, trialRow, stateIdx)\n']);
end

% -------------------------------------------------------------------------------------------------
function local_click(fig)
IX = guidata(fig);
ax = gca;
k  = find(IX.axes == ax, 1);                       % which state panel was clicked
if isempty(k), return; end
kk = IX.stateIdx(k);
cp = get(ax,'CurrentPoint');  xc = cp(1,1);  yc = cp(1,2);
xl = xlim(ax);  yl = ylim(ax);
xs = max(diff(xl),eps);  ys = max(diff(yl),eps);   % normalise: the two axes have different units

best = inf;  bs = 0;  bi = 0;
for s = 1:numel(IX.sess)
    X = IX.sess(s).state{kk};  Y = IX.sess(s).dv;
    if isempty(X), continue; end
    d = ((X-xc)/xs).^2 + ((Y-yc)/ys).^2;
    [dm, im] = min(d);
    if dm < best, best = dm; bs = s; bi = im; end
end
if bs == 0, return; end
if sqrt(best) > 0.06                                % clicked empty space, not a point
    fprintf('[F2-STATE] no point near the click (nearest is %.2f axis-fractions away)\n', sqrt(best));
    return
end
local_detail(IX, bs, bi, kk);
end

% -------------------------------------------------------------------------------------------------
function local_detail(IX, s, i, kk)
S  = IX.sess(s);  D = S.D;  ST = D.ST;
ai = ST.AMPi(i);  tj = ST.TRi(i);                  % which amplitude, which trial within it
Fs = D.Fs;  preN = D.preN;  rel = D.rel(:);
if isempty(ST.trA{ai}) || tj > size(ST.trA{ai},2), return; end

A = ST.trA{ai}(:,tj);  G = ST.trG{ai}(:,tj);  R = ST.trL{ai}(:,tj);
Rbar = mean(ST.trL{ai}, 2, 'omitnan');             % amp-mean residual = the template the DV deviates from
dc = D.dcc{ai};  if isempty(dc), dc = (preN+1):numel(rel); end
tt = rel/Fs;
ion = D.onFcell{ai}(tj);

f = findall(0,'Type','figure','Tag','F2_TRIAL');
if isempty(f), f = figure('Tag','F2_TRIAL','Color','w','Position',[120 90 1180 720]); else, f = f(1); figure(f); clf(f); end

% ---- (1) traces --------------------------------------------------------------------------------
ax1 = subplot(2,2,[1 2]); hold(ax1,'on'); box(ax1,'on');
yl0 = [min([A;G;R])-0.2, max([A;G;R])+0.2];
patch(ax1, [tt(dc(1)) tt(dc(end)) tt(dc(end)) tt(dc(1))], [yl0(1) yl0(1) yl0(2) yl0(2)], ...
      [0.85 0.92 1.0], 'EdgeColor','none', 'FaceAlpha',0.7, 'HandleVisibility','off');
patch(ax1, [tt(1) 0 0 tt(1)], [yl0(1) yl0(1) yl0(2) yl0(2)], ...
      [0.92 0.92 0.92], 'EdgeColor','none', 'FaceAlpha',0.7, 'HandleVisibility','off');
plot(ax1, tt, A, 'k-','LineWidth',1.8,'DisplayName','actual ipsi');
plot(ax1, tt, G, '-','Color',[.85 .2 .2],'LineWidth',1.5,'DisplayName','stim-blind prediction (Global)');
plot(ax1, tt, R, '-','Color',[.1 .4 .85],'LineWidth',1.6,'DisplayName','residual (Local)');
plot(ax1, tt, Rbar,'--','Color',[.5 .65 .9],'LineWidth',1.3,'DisplayName','amp-mean residual');
xline(ax1,0,'k:','HandleVisibility','off'); yline(ax1,0,'k:','HandleVisibility','off');
ylim(ax1,yl0); xlabel(ax1,'t re onset (s)'); ylabel(ax1,'\DeltaF/F %');
legend(ax1,'Location','best','FontSize',7,'Box','off');   % 'southeast' landed on top of the traces
title(ax1, sprintf(['grey = pre-onset control window (fit quality, no stim)   |   blue = dip window ' ...
                    '(%.0f-%.0f ms), the DV is measured here'], 1000*tt(dc(1)), 1000*tt(dc(end))), ...
      'FontSize',8,'FontWeight','normal');

% ---- (2) motion over the EXACT window MOT sums over --------------------------------------------
ax2 = subplot(2,2,3); hold(ax2,'on'); box(ax2,'on');
motPreN = round(2*Fs);  motPostN = round(0.5*Fs);            % imp_statedep_trials windows
mw = (ion-motPreN):(ion+motPostN);
if ~isempty(D.motz) && mw(1) >= 1 && mw(end) <= numel(D.motz)
    ctx = round(1.5*Fs);
    cw  = max(1,mw(1)-ctx):min(numel(D.motz), mw(end)+ctx);
    plot(ax2, (cw-ion)/Fs, D.motz(cw), '-','Color',[.7 .7 .7],'LineWidth',0.8);
    plot(ax2, (mw-ion)/Fs, D.motz(mw), '-','Color',[.15 .55 .2],'LineWidth',1.6);
    xline(ax2,0,'k:'); yline(ax2,0,'k:');
    title(ax2, sprintf('motion  [-2,+0.5] s (green) — MOT = \\Sigma|z| = %.1f', ST.MOT(i)), ...
          'FontSize',8,'FontWeight','bold');
else
    text(ax2,0.5,0.5,'no motion trace for this session','HorizontalAlignment','center'); axis(ax2,'off');
end
xlabel(ax2,'t re onset (s)'); ylabel(ax2,'motion (z)');

% ---- (3)+(4) the var/delta window and its spectrum ----------------------------------------------
vd_preN = round(1*Fs);  vd_postN = round(0.5*Fs);            % imp_statedep_trials windows
gp = (ion-vd_preN):(ion+vd_postN);
ax3 = subplot(2,2,4); hold(ax3,'on'); box(ax3,'on');
if gp(1) >= 1 && gp(end) <= D.nF
    sp = double(D.y_full(gp));
    nW = numel(sp);  w = hann(nW);  W = sum(w.^2);
    nfft = 2^nextpow2(nW);  fr = (0:nfft-1)'/nfft*Fs;  nB = floor(nfft/2)+1;
    X = fft(sp(:).*w, nfft);  pw = abs(X(1:nB)).^2 * 2/(Fs*W);
    fb = fr(1:nB);  keep = fb <= 30;
    ar = area(ax3, [1 4], [max(pw(keep)) max(pw(keep))], 'FaceColor',[1 .9 .75], ...
              'EdgeColor','none','HandleVisibility','off');  uistack(ar,'bottom');
    plot(ax3, fb(keep), pw(keep), '-','Color',[.3 .3 .3],'LineWidth',1.3);
    set(ax3,'YScale','log'); xlim(ax3,[0 30]);
    xlabel(ax3,'Hz'); ylabel(ax3,'power (\DeltaF/F)^2 Hz^{-1}');
    title(ax3, sprintf('spectrum of [-1,+0.5] s   |   \\delta abs %.3g, REL %.3f, var %.3g', ...
          ST.DPa(i), ST.DPr(i), ST.PVv(i)), 'FontSize',8,'FontWeight','bold');
else
    text(ax3,0.5,0.5,'state window runs off the recording','HorizontalAlignment','center'); axis(ax3,'off');
end

% ---- header: every number the statistics used, for THIS trial ------------------------------------
stName = IX.stateNames{kk};                       % carries TeX (e.g. 'Rel-\delta') for the figure
stCon  = strrep(strrep(stName,'\delta','delta'),'\','');   % ...stripped for the console line
pctl = @(v,x) 100*mean(v <= x, 'omitnan');
sgtitle(f, sprintf(['%s   —   %.2f V, trial %d of %d   (movie frame %d)\n' ...
    'DV %s = %+.2f (%.0fth pctile)   |   %s = %+.2f   |   Local dip = %+.3f %%\\DeltaF/F\n' ...
    'prediction error: pre %.3f (%.0fth pctile — HIGH means this trial''s deviation is untrustworthy), post %.3f'], ...
    S.label, D.amps(ai), tj, size(ST.trA{ai},2), ion, ...
    strrep(IX.dv,'z',''), ST.(IX.dv)(i), pctl(ST.(IX.dv), ST.(IX.dv)(i)), ...
    stName, S.state{kk}(i), ST.LD(i), ...
    ST.PRE(i), pctl(ST.PRE, ST.PRE(i)), ST.POST(i)), 'FontWeight','bold','FontSize',9);

fprintf(['[F2-TRIAL] %s | %.2f V trial %d | %s %+.2f | DV %+.2f | Local dip %+.3f | ' ...
         'pre-err %.3f (%.0fth pctile)\n'], S.label, D.amps(ai), tj, stCon, S.state{kk}(i), ...
         ST.(IX.dv)(i), ST.LD(i), ST.PRE(i), pctl(ST.PRE, ST.PRE(i)));
end
