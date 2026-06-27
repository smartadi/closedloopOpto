function cp_bleed_explorer(matfile)
%CP_BLEED_EXPLORER  Interactive whole-brain impulse-bleed map with a live time window.
%
%   cp_bleed_explorer(MATFILE) reloads the session SVD and shows a per-pixel bleed
%   map over the WHOLE brain (ipsi + contra). Three sliders set the time window --
%   post-onset start t0, post-onset end t1, and the pre-onset baseline length -- and
%   the map updates LIVE (each change is one matrix-vector product: window means come
%   from a cumsum of V). A metric popup switches between two definitions:
%
%     'dose-response slope'  beta = OLS slope of the per-trial [post - baseline]
%                            response on stimulus amplitude (all amps, 0..max).
%     'max-amp deviation'    Delta = mean(max-amp [post - baseline]) minus
%                            mean(amp-0 catch [post - baseline]).  Bleed = deviation
%                            from baseline at the strongest drive, with the catch
%                            (no-laser) trials as the per-pixel "no input" reference.
%
%   The "Significance" button runs the matching permutation null (1000x) + BH-FDR for
%   the CURRENT window and metric, and outlines significant pixels in green:
%     slope  -> amplitude-label shuffle;   max-amp -> max-vs-catch label shuffle.
%   Significance is cleared on any change (it is window/metric-specific).
%
%   Trials are selected PER window (a trial is used if its full [baseline, t1] span is
%   in range), so longer baselines simply drop the trials that no longer fit -- the
%   usable count is shown in the title. The green + marks the FLIPPED primary pixel.
%   Display is transposed (imagesc(mimg.')) to match cp_roi_masks.
%
%   MATFILE is cp_bleed_explorer_<sess>.mat dumped by contra_prediction [CP-BLEED].

if nargin < 1 || isempty(matfile);  error('cp_bleed_explorer: pass cp_bleed_explorer_<sess>.mat'); end
if ~exist(matfile,'file');           error('cp_bleed_explorer: file not found: %s', matfile); end
P = load(matfile);

serverRoot = expPath(P.mn, P.td, P.en);
fprintf('cp_bleed_explorer: loading SVD (%s %s e%d)...\n', P.mn, P.td, P.en);
[U_cp, V_cp, ~, mimg] = loadUVt(serverRoot, P.nSV_load);
[nY, nX] = size(mimg);  nSV = size(U_cp, 3);

% whole-brain spatial loadings + temporal cumsum (O(1) window means) ---------------
Uflat   = reshape(U_cp, nY*nX, nSV);
bidx    = P.brain_idx(:);
Ubrain  = double(Uflat(bidx, :));               % [nBrain x nSV]
mIbrain = mimg(bidx);  mIbrain(mIbrain == 0) = eps;
clear U_cp Uflat
cumV = [zeros(nSV,1), cumsum(double(V_cp), 2)]; % [nSV x (T+1)]
T    = size(V_cp, 2);  clear V_cp

amp = double(P.amp(:));
st = struct('cumV',cumV, 'Ubrain',Ubrain, 'mIbrain',mIbrain, 'bidx',bidx, ...
    'onf',P.onf(:), 'amp',amp, 'ampMax',max(amp), ...
    'nY',nY, 'nX',nX, 'Fs',P.Fs, 'T',T, ...
    'prim_row',P.prim_row, 'prim_col',P.prim_col, ...
    't0',0, 't1',500, 'pre',1000, 'mode','slope', 'sigC',[]);
fprintf('cp_bleed_explorer: %d onsets, amps %s (max=%.2g, catch n=%d)\n', ...
    numel(st.onf), num2str(unique(amp).'), st.ampMax, nnz(amp==0));

% --- figure: stacked bg(gray)/overlay(diverging) axes + controls ------------------
f = figure('Name','CP bleed explorer (FLIPPED primary)','NumberTitle','off','Color','w', ...
           'Units','normalized','Position',[0.10 0.09 0.66 0.82]);
apos = [0.06 0.27 0.80 0.67];
st.axBg = axes('Parent',f,'Units','normalized','Position',apos);
imagesc(st.axBg, mimg.');  colormap(st.axBg, gray);  axis(st.axBg,'image','off');
st.axOv = axes('Parent',f,'Units','normalized','Position',apos,'Color','none');
st.imOv = imagesc(st.axOv, nan(nX, nY));  set(st.imOv,'AlphaData',zeros(nX,nY));
axis(st.axOv,'image','off');  hold(st.axOv,'on');
nC = 256; nH = ceil(nC/2);                              % blue->white->red diverging
st.cmap = [ linspace(0.23,1,nH)', linspace(0.30,1,nH)', linspace(0.75,1,nH)'; ...
            linspace(1,0.80,nC-nH)', linspace(1,0.10,nC-nH)', linspace(1,0.10,nC-nH)' ];
colormap(st.axOv, st.cmap);
st.cb = colorbar(st.axOv, 'Position',[0.875 0.27 0.025 0.67]);
st.titH = title(st.axOv, '', 'FontWeight','bold', 'FontSize',10);
% top overlay axes: transparent-green tint marks the "bleed" (significant) pixels
st.axSig = axes('Parent',f,'Units','normalized','Position',apos,'Color','none');
st.imSig = image(st.axSig, cat(3, 0.10*ones(nX,nY), 0.95*ones(nX,nY), 0.25*ones(nX,nY)));
set(st.imSig,'AlphaData', zeros(nX,nY));
axis(st.axSig,'image','off');  hold(st.axSig,'on');
st.primMark = plot(st.axSig, P.prim_row, P.prim_col, 'm+', 'MarkerSize',12, 'LineWidth',2);
st.sigAlpha = 0.40;  st.zthr = 1.96;      % bleed = |perm z| > 1.96  (p<0.05, uncorrected)

% controls -------------------------------------------------------------------------
st.lblT0 = local_mk(f,'text',[0.06 0.165 0.18 0.032], sprintf('post start: %d ms', st.t0));
st.sldT0 = local_mk(f,'slider',[0.06 0.140 0.30 0.025], '');
set(st.sldT0,'Min',0,'Max',1000,'Value',st.t0,'SliderStep',[10/1000 100/1000],'Callback',@(s,~)local_onSlider(f));
st.lblT1 = local_mk(f,'text',[0.06 0.105 0.18 0.032], sprintf('post end: %d ms', st.t1));
st.sldT1 = local_mk(f,'slider',[0.06 0.080 0.30 0.025], '');
set(st.sldT1,'Min',50,'Max',2500,'Value',st.t1,'SliderStep',[10/2450 100/2450],'Callback',@(s,~)local_onSlider(f));
st.lblPr = local_mk(f,'text',[0.06 0.045 0.18 0.032], sprintf('baseline: %d ms', st.pre));
st.sldPr = local_mk(f,'slider',[0.06 0.020 0.30 0.025], '');
set(st.sldPr,'Min',100,'Max',2000,'Value',st.pre,'SliderStep',[10/1900 100/1900],'Callback',@(s,~)local_onSlider(f));

local_mk(f,'text',[0.42 0.165 0.18 0.032], 'metric:');
st.popMode = uicontrol(f,'Style','popupmenu','Units','normalized','Position',[0.42 0.137 0.26 0.030], ...
    'String',{'dose-response slope','max-amp deviation'},'Value',1,'FontWeight','bold', ...
    'Callback',@(s,~)local_onMode(f));
local_mk(f,'pushbutton',[0.42 0.095 0.26 0.038], 'Show bleed pixels (perm z)', @(s,~)local_onSig(f));
st.lblZ = local_mk(f,'text',[0.42 0.060 0.26 0.028], sprintf('bleed |z| >= %.2f   (left = more sensitive)', st.zthr));
st.sldZ = local_mk(f,'slider',[0.42 0.037 0.26 0.022], '');
set(st.sldZ,'Min',1.0,'Max',4.0,'Value',st.zthr,'SliderStep',[0.05/3 0.5/3],'Callback',@(s,~)local_onZthr(f));
ylabel(st.cb, '\beta  (dF/F per amp)', 'FontWeight','bold');

guidata(f, st);
local_update(f);   % initial draw
end

% ----------------------------------------------------------------------------------
function h = local_mk(f, style, pos, str, cb)
h = uicontrol(f,'Style',style,'Units','normalized','Position',pos,'String',str, ...
              'BackgroundColor','w','FontWeight','bold','HorizontalAlignment','left');
if nargin >= 5;  set(h,'Callback',cb);  end
end

% ----------------------------------------------------------------------------------
function [map, aux] = local_map(st)
% Per-window trial selection + the chosen bleed metric; aux carries dv etc. for the null.
f0 = round(st.t0  * st.Fs/1000);  f1 = round(st.t1 * st.Fs/1000);  fp = round(st.pre * st.Fs/1000);
if f1 <= f0;  f1 = f0 + 1;  end
valid = (st.onf - fp >= 1) & (st.onf + f1 <= st.T);
o     = st.onf(valid);   amp_u = st.amp(valid);
postM = (st.cumV(:, o+f1+1) - st.cumV(:, o+f0)) / (f1 - f0 + 1);   % [nSV x nUse]
preM  = (st.cumV(:, o)      - st.cumV(:, o-fp)) / fp;
dv    = postM - preM;                                             % per-trial [post - baseline] in mode space
aux   = struct('dv',dv, 'nUse',numel(o), 'mode',st.mode);
if strcmp(st.mode, 'slope')
    ac = amp_u - mean(amp_u);  den = ac.'*ac;  if den == 0; den = eps; end
    g  = (dv * ac) / den * 100;
    aux.ac = ac;  aux.den = den;
else  % max-amp deviation vs catch
    imax = amp_u == st.ampMax;   icatch = amp_u == 0;
    aux.imax = imax;  aux.icatch = icatch;  aux.nmax = nnz(imax);  aux.ncat = nnz(icatch);
    if aux.nmax == 0 || aux.ncat == 0
        g = zeros(size(dv,1), 1);
    else
        g = (mean(dv(:,imax), 2) - mean(dv(:,icatch), 2)) * 100;
    end
end
map = (st.Ubrain * g) ./ st.mIbrain;
end

% ----------------------------------------------------------------------------------
function local_onSlider(f)
st = guidata(f);
st.t0  = round(get(st.sldT0,'Value'));
st.t1  = round(get(st.sldT1,'Value'));
st.pre = round(get(st.sldPr,'Value'));
if st.t1 <= st.t0;  st.t1 = st.t0 + 50;  set(st.sldT1,'Value',st.t1);  end
set(st.lblT0,'String',sprintf('post start: %d ms', st.t0));
set(st.lblT1,'String',sprintf('post end: %d ms', st.t1));
set(st.lblPr,'String',sprintf('baseline: %d ms', st.pre));
guidata(f, st);
local_update(f);
end

% ----------------------------------------------------------------------------------
function local_onMode(f)
st = guidata(f);
if get(st.popMode,'Value') == 1;  st.mode = 'slope';  else;  st.mode = 'maxamp';  end
guidata(f, st);
local_update(f);
end

% ----------------------------------------------------------------------------------
function local_update(f)
st = guidata(f);
[map, aux] = local_map(st);
km = nan(st.nY, st.nX);  km(st.bidx) = map;  kmT = km.';
lim = prctile(abs(map), 99);  if lim < eps || isnan(lim); lim = 1; end
al = min(1, abs(kmT) ./ lim);  al(isnan(kmT)) = 0;
set(st.imOv, 'CData', kmT, 'AlphaData', al);  clim(st.axOv, [-lim, lim]);
set(st.imSig, 'AlphaData', zeros(st.nX, st.nY));   % clear stale bleed tint on any change
st.zlast = [];                                       % cached z is window/metric-specific
if strcmp(st.mode, 'slope')
    ylabel(st.cb, '\beta  (dF/F per amp)', 'FontWeight','bold');
    set(st.titH, 'String', sprintf(['SLOPE \\beta  |  post [%d,%d] ms, base %d ms  |  n=%d trials' ...
        '  |  |\\beta|_{99}=%.3g   (press Significance)'], st.t0, st.t1, st.pre, aux.nUse, lim));
else
    ylabel(st.cb, '\Delta dF/F  (max - catch)', 'FontWeight','bold');
    set(st.titH, 'String', sprintf(['MAX-AMP \\Delta (max - catch)  |  post [%d,%d] ms, base %d ms' ...
        '  |  n_{max}=%d  n_{catch}=%d  |  |\\Delta|_{99}=%.3g   (press Significance)'], ...
        st.t0, st.t1, st.pre, aux.nmax, aux.ncat, lim));
end
guidata(f, st);
end

% ----------------------------------------------------------------------------------
function local_onSig(f)
% Per-pixel permutation z; "bleed" pixels (|z| > st.zthr) are tinted transparent green.
% Null = label shuffle (slope: amplitude; max-amp: max-vs-catch) -> per-pixel null
% mean/std -> z = (observed - null mean)/null std. No clusters, no FDR -- just the tint.
st = guidata(f);
set(f, 'Pointer', 'watch');  drawnow;
[m0, aux] = local_map(st);
nP = 1000;  ch = 100;  rng(7);

% --- permutation g-vectors Gp [nSV x nP] (mode-specific label shuffle) -------------
if strcmp(aux.mode, 'slope')
    nU = numel(aux.ac);  AC = zeros(nU, nP);
    for ii = 1:nP;  AC(:,ii) = aux.ac(randperm(nU));  end
    Gp = (aux.dv * AC) / aux.den * 100;
else
    if aux.nmax == 0 || aux.ncat == 0
        set(f,'Pointer','arrow');
        warndlg('No max-amp or catch trials fit this window -- shorten the baseline/window.');  return;
    end
    pool = [find(aux.imax); find(aux.icatch)];  npool = numel(pool);  nmax = aux.nmax;  ncat = aux.ncat;
    dvp = aux.dv(:, pool);  Cm = zeros(npool, nP);
    for ii = 1:nP
        pr = randperm(npool);  Cm(pr(1:nmax), ii) = 1/nmax;  Cm(pr(nmax+1:end), ii) = -1/ncat;
    end
    Gp = (dvp * Cm) * 100;
end

% --- per-pixel null mean/std of the map (chunked) ---------------------------------
nB = numel(m0);  s1 = zeros(nB,1);  s2 = zeros(nB,1);
for c = 1:ch:nP
    k  = min(ch, nP-c+1);
    MP = (st.Ubrain * Gp(:, c:c+k-1)) ./ st.mIbrain;
    s1 = s1 + sum(MP, 2);  s2 = s2 + sum(MP.^2, 2);
end
nullmean = s1 / nP;  nullstd = sqrt(max(s2/nP - nullmean.^2, 0));  nullstd(nullstd < eps) = eps;

% --- bleed pixels = |z| over threshold -> transparent-green tint -------------------
z   = (m0 - nullmean) ./ nullstd;
st.zlast = z;                          % cache for the sensitivity slider (re-tint w/o re-perm)
sig = abs(z) > st.zthr;
sigimg = zeros(st.nY, st.nX);  sigimg(st.bidx(sig)) = 1;
set(st.imSig, 'AlphaData', sigimg.' * st.sigAlpha);
tag = 'SLOPE \beta';  if strcmp(aux.mode,'maxamp'); tag = 'MAX-AMP \Delta'; end
set(st.titH, 'String', sprintf('%s  |  post [%d,%d] ms, base %d ms  |  %d bleed px (|z|>%.2f, green)', ...
    tag, st.t0, st.t1, st.pre, nnz(sig), st.zthr));
set(f, 'Pointer', 'arrow');
guidata(f, st);
fprintf('[bleed-explorer] %s post[%d,%d] base%d: %d/%d bleed px (|z|>%.2f)\n', ...
        aux.mode, st.t0, st.t1, st.pre, nnz(sig), nB, st.zthr);
end

% ----------------------------------------------------------------------------------
function local_onZthr(f)
% Sensitivity knob: re-threshold the CACHED permutation z (no re-permuting) and
% re-tint. If no z is cached yet for this window/metric, prompt to press the button.
st = guidata(f);
st.zthr = get(st.sldZ, 'Value');
set(st.lblZ, 'String', sprintf('bleed |z| >= %.2f   (left = more sensitive)', st.zthr));
if isfield(st,'zlast') && ~isempty(st.zlast)
    sig = abs(st.zlast) > st.zthr;
    sigimg = zeros(st.nY, st.nX);  sigimg(st.bidx(sig)) = 1;
    set(st.imSig, 'AlphaData', sigimg.' * st.sigAlpha);
    tag = 'SLOPE \beta';  if strcmp(st.mode,'maxamp'); tag = 'MAX-AMP \Delta'; end
    set(st.titH, 'String', sprintf('%s  |  post [%d,%d] ms, base %d ms  |  %d bleed px (|z|>%.2f, green)', ...
        tag, st.t0, st.t1, st.pre, nnz(sig), st.zthr));
else
    set(st.titH, 'String', sprintf('bleed |z| >= %.2f set -- press "Show bleed pixels" to apply', st.zthr));
end
guidata(f, st);
end
