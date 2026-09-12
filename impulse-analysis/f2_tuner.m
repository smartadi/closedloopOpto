function f2_tuner()
%F2_TUNER  Combined Fig-2 residual analyzer: pick a session, tune its predictor op-point, click its
%          trials, COMMIT the op-point, and run the POOLED state-dependence from the committed set.
%
% The impulse-side twin of controller-analysis/ctrl_softblind_session_tuner.m. One window:
%   top bar  : session popup | mode popup (frontier/subspace/r2max) | op-point slider | APPLY | COMMIT | POOLED
%   status   : a bold line that says exactly what op-point was RUN, when, and its R^2/capture/leak/catch
%   top-left : the Actual / Global / Local decomposition (dip vs amplitude) at the current op-point
%   top-mid  : the BRAIN WEIGHT MAP -- where the predictor draws from (weights on the cortex, sized by
%              |w|, blue<0<red; grey x = stim-affected pixels the detector excluded; red + = ipsi site)
%   top-right: two CLICKABLE state scatters -- Local residual vs Motion and vs 2-4 Hz rel-power, every
%              trial coloured by its pre-trial prediction quality. CLICK a point -> that trial's traces.
%   bottom   : live metrics (R^2 / capture / leak / catch / shift) + the committed op-point of every session.
%
% WORKFLOW
%   1. Pick a session. It loads once (~30 s); re-fits after that are instant.
%   2. Stage an op-point with the slider / mode popup, then press APPLY / RE-FIT to run it -- the button
%      turns orange ("APPLY ->") while a value is staged and green ("APPLIED") once it has run, and the
%      status line reports the result. Aim for: Global flat, Local tracks Actual, capture near 100,
%      |catch| <= 15, and (on the map) surviving weights pulled AWAY from the site. Click scatter
%      outliers to check they are real responses, not baseline mis-fits.
%   3. COMMIT -> saves data/f2_opsel_<sess>.mat. Do this for each session.
%   4. RUN POOLED STATE-DEP -> rebuilds every session at its committed op-point (default frontier 0.85 if
%      none committed) and reports the pooled Motion + Rel-delta result -- the number for the paper.
%
% NEEDS: run `load_experiments` once first.  USAGE:  f2_tuner
% -------------------------------------------------------------------------------------------------
here = fileparts(mfilename('fullpath'));
if isempty(here), here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis'; end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));
dataDir = fullfile(here,'data');
if evalin('base','~exist(''allExperiments'',''var'')')
    error('f2_tuner: run  load_experiments  first (it loads allExperiments).');
end
ae_all = evalin('base','allExperiments');
nS = numel(ae_all);
names = arrayfun(@(a) local_name(a), ae_all, 'UniformOutput', false);

% ---- shared state (populated by the nested functions) -------------------------------------------
si = 1; P = []; A = []; M = []; D = []; knobs = struct();
sess_dv = []; sess_st = {[],[]};                       % current session's DV + [motion,reldelta] (z), for click

% ---- figure + controls --------------------------------------------------------------------------
fig = figure('Name','F2 combined analyzer — tune + click + commit','Color','w','Position',[20 30 1560 950]);
uicontrol(fig,'Style','text','Units','normalized','Position',[.010 .950 .055 .030],'String','session:', ...
    'BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold');
hSess = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.065 .953 .200 .030], ...
    'String',names,'Value',1,'Callback',@(~,~)onSession());
uicontrol(fig,'Style','text','Units','normalized','Position',[.285 .950 .040 .030],'String','mode:', ...
    'BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold');
hMode = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.325 .953 .150 .030], ...
    'String',{'frontier (r2_floor)','subspace (nu)','r2max (ridge)'},'Value',1,'Callback',@(~,~)onMode());
hParamLab = uicontrol(fig,'Style','text','Units','normalized','Position',[.490 .950 .085 .030], ...
    'String','r2_floor','BackgroundColor','w','HorizontalAlignment','left');
hParam = uicontrol(fig,'Style','slider','Units','normalized','Position',[.490 .924 .210 .024], ...
    'Min',0.78,'Max',0.96,'Value',0.85,'Callback',@(~,~)onParam());
hParamVal = uicontrol(fig,'Style','text','Units','normalized','Position',[.705 .950 .045 .030], ...
    'String','0.85','BackgroundColor','w','FontWeight','bold');
% APPLY = the explicit "run this op-point" trigger. The slider only STAGES a value; nothing is
% fitted until APPLY is pressed, and the button + status line report exactly what was run and when.
hApply = uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.700 .922 .115 .030], ...
    'String','APPLY / RE-FIT','FontWeight','bold','BackgroundColor',[.85 .90 .98],'Callback',@(~,~)onApply());
hCommit = uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.825 .951 .070 .033], ...
    'String','COMMIT','FontWeight','bold','BackgroundColor',[.80 .92 .80],'Callback',@(~,~)onCommit());
hClearOp = uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.900 .951 .070 .033], ...
    'String','clear op','Callback',@(~,~)onClearOp());
hPooled = uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.825 .912 .145 .034], ...
    'String','RUN POOLED STATE-DEP','FontWeight','bold','BackgroundColor',[.84 .88 .98],'Callback',@(~,~)onPooled());
% CANDIDATE-PIXEL SET: whether the TF affected-mask is used at all. 'detector-excluded' drops the
% flagged pixels before fitting (the current behaviour). 'ALL pixels' bypasses the mask and hands the
% whole grid to the optimiser -- the controller-style path, where blindness must come from the model
% (subspace deflation removes the stim direction) rather than from trusting a per-session mask.
uicontrol(fig,'Style','text','Units','normalized','Position',[.010 .886 .078 .026],'String','candidates:', ...
    'BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold');
hCand = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.090 .888 .300 .026], ...
    'String',{'detector-excluded (TF mask)','ALL pixels — no mask (model must deflate)'}, ...
    'Value',1,'Callback',@(~,~)onCand());
hStatus = uicontrol(fig,'Style','text','Units','normalized','Position',[.010 .860 .960 .024], ...
    'String','','BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold','ForegroundColor',[.1 .4 .1]);

% row 1 : decomposition | leak-vs-R^2 FRONTIER (controller-style) | brain weight map
% row 2 : per-amp trial-averaged Actual/Global/Local TRACES (+ catch) -- the visual investigator
% row 3 : the two clickable state scatters ;  bottom : the metrics / committed-op text
axDec  = axes('Parent',fig,'Position',[.045 .690 .245 .180]);
axFron = axes('Parent',fig,'Position',[.375 .690 .235 .180]);
axMap  = axes('Parent',fig,'Position',[.695 .680 .275 .200]);
nTile = 6;  axTile = gobjects(1,nTile);            % up to 5 responding amps + 1 catch tile
for ti = 1:nTile
    axTile(ti) = axes('Parent',fig,'Position',[.045 + (ti-1)*.152, .470, .140, .155]);
end
axMot  = axes('Parent',fig,'Position',[.075 .270 .280 .150]);
axRel  = axes('Parent',fig,'Position',[.410 .270 .280 .150]);
hTxt = uicontrol(fig,'Style','text','Units','normalized','Position',[.045 .015 .925 .235], ...
    'String','','FontName','Consolas','FontSize',9,'BackgroundColor',[.96 .96 .98], ...
    'HorizontalAlignment','left','Max',20);

set(fig,'WindowButtonDownFcn',@(s,~)onClick());
onSession();                                            % load session 1 and draw

% =================================================================================================
%                                       NESTED FUNCTIONS
% =================================================================================================
    function onSession()
        si = get(hSess,'Value');
        fprintf('[f2_tuner] loading %s ...\n', names{si});
        P = f2_prep(ae_all(si), struct('dataDir',dataDir,'verbose',false));
        A = f2_affected(P, struct('plot',false));
        op = loadOp(P.sess_tag);
        if ~isempty(op)
            useM = ~isfield(op,'use_affected') || op.use_affected;
            set(hCand,'Value', 2 - double(useM));           % true->1 (mask), false->2 (all px)
            setModeParam(op.select_mode, op.param);
        else
            set(hCand,'Value',1);
            setModeParam('frontier', 0.85);
        end
        onApply();                                          % fit + draw the loaded op-point immediately
    end

    % The slider and mode popup only STAGE a value -- they do not fit. This makes "did my parameter
    % run?" unambiguous: the staged value turns the APPLY button orange ("APPLY ->"), and only
    % pressing it fits the model and stamps the status line. onApply is the single fit trigger.
    function onMode(),  applyModeRange(); syncKnobs(); markDirty(); end
    function onParam(), syncKnobs(); markDirty(); end
    function onCand(),  syncKnobs(); markDirty(); end

    function markDirty()
        set(hApply,'BackgroundColor',[.98 .82 .45],'String','APPLY ->');
        set(hStatus,'String', sprintf('staged: %s %s=%s   — press APPLY / RE-FIT to run it', ...
            knobs.select_mode, get(hParamLab,'String'), get(hParamVal,'String')), 'ForegroundColor',[.6 .35 0]);
    end

    function onApply()
        set(hStatus,'String','fitting ...','ForegroundColor',[.1 .1 .1]); drawnow;
        refit(); redraw();
        set(hApply,'BackgroundColor',[.72 .90 .72],'String','APPLIED');
        set(hStatus,'String', sprintf('RAN  %s : %s %s=%s   at %s   ->  R^2 %.3f | capture %.0f%% | leak %.0f%% | catch %+.0f%%', ...
            P.label, knobs.select_mode, get(hParamLab,'String'), get(hParamVal,'String'), datestr(now,'HH:MM:SS'), ...
            M.r2_spont, D.capMed, D.leakMed, 100*D.catch.ratio), 'ForegroundColor',[.1 .4 .1]);
    end

    function applyModeRange()
        switch get(hMode,'Value')
            case 1, set(hParamLab,'String','r2_floor');    set(hParam,'Min',0.78,'Max',0.96);
            case 2, set(hParamLab,'String','nu (deflate)'); set(hParam,'Min',0.80,'Max',0.98);
            case 3, set(hParamLab,'String','ridge');        set(hParam,'Min',0.00,'Max',0.10);
        end
    end

    function setModeParam(mode, param)
        switch lower(mode)
            case 'frontier', set(hMode,'Value',1);
            case 'subspace', set(hMode,'Value',2);
            case 'r2max',    set(hMode,'Value',3);
        end
        applyModeRange();
        set(hParam,'Value', min(max(param, get(hParam,'Min')), get(hParam,'Max')));
        syncKnobs();
    end

    function syncKnobs()
        v = get(hParam,'Value');  set(hParamVal,'String',sprintf('%.3g',v));
        knobs = struct('use_motion',false,'verbose',false);
        knobs.use_affected = (get(hCand,'Value') == 1);    % 1 = use TF mask ; 2 = all pixels, no mask
        switch get(hMode,'Value')
            case 1, knobs.select_mode = 'frontier'; knobs.r2_floor    = v;
            case 2, knobs.select_mode = 'subspace'; knobs.nu          = v;
            case 3, knobs.select_mode = 'r2max';    knobs.ridge_fixed = v;
        end
    end

    function refit()
        M = f2_model(P, A, knobs);
        D = f2_decomp(P, M, struct('verbose',false));
    end

    function redraw()
        amps = D.amps(:);                              % use f2_decomp's own per-amp dips (== f2_fitfig)
        cla(axDec); hold(axDec,'on'); box(axDec,'on');
        plot(axDec, amps, D.Adip(:), 'ko-','LineWidth',1.6,'DisplayName','Actual');
        plot(axDec, amps, D.Gdip(:), 'rs-','LineWidth',1.3,'DisplayName','Global (leak)');
        plot(axDec, amps, D.Ldip(:), 'b^-','LineWidth',1.3,'DisplayName','Local (residual)');
        ok = D.ampOK(:);                               % ring the amps that actually responded
        plot(axDec, amps(ok), D.Adip(ok), 'ko','MarkerSize',10,'HandleVisibility','off');
        yline(axDec,0,'k:','HandleVisibility','off');
        xlabel(axDec,'amplitude (V)'); ylabel(axDec,'dip \DeltaF/F %');
        title(axDec,'decomposition (Global flat + Local tracks Actual = clean)','FontSize',9,'FontWeight','bold');
        legend(axDec,'Location','best','FontSize',7,'Box','off');
        drawFrontier();
        drawTraces();
        drawMap();
        drawScatter(axMot,'MOT','Motion',1);
        drawScatter(axRel,'DPr','Rel-\delta (2-4 Hz)',2);
        updateSummary('');
    end

    function drawTraces()
        % Per-amp TRIAL-AVERAGED decomposition traces (Actual/Global/Local over time), drawn exactly
        % like f2_fitfig's row 3 so the shape -- not just the dip scalar -- can be eyeballed: does
        % Global stay flat through the dip window (blue shaded) while Local carries the deflection?
        % The last tile is the CATCH control on the same axes, for a same-scale sanity comparison.
        tt = D.rel(:)/D.Fs;  preN = D.preN;
        ok = find(D.ampOK(:).');  if isempty(ok), ok = 1:numel(D.amps); end
        nShow = min(nTile-1, numel(ok));                 % reserve the last tile for the catch control
        pick = ok(unique(round(linspace(1, numel(ok), nShow))));
        for t = 1:nTile, cla(axTile(t)); legend(axTile(t),'off'); set(axTile(t),'Visible','on'); end
        for q = 1:numel(pick)
            ai = pick(q);  ax = axTile(q);  hold(ax,'on');  box(ax,'on');
            local_agl(ax, tt, D.trA{ai}, D.trG{ai}, D.trL{ai}, D.dcc{ai}, preN);
            title(ax, sprintf('%.2g V  (cap %.0f%% / leak %.0f%%)', D.amps(ai), D.capPct(ai), D.leakPct(ai)), ...
                  'FontSize',7,'FontWeight','bold');
            xlabel(ax,'t re onset (s)','FontSize',7);
            if q == 1
                ylabel(ax,'\DeltaF/F %','FontSize',7);
                legend(ax,{'Actual','Global','Local'},'FontSize',5,'Location','southeast','Box','off');
            end
        end
        axc = axTile(numel(pick)+1);  hold(axc,'on');  box(axc,'on');
        local_agl(axc, tt, D.catch.trA, D.catch.trG, D.catch.trL, D.dcc{pick(1)}, preN);
        cc = [0 .45 0];  if abs(D.catch.ratio) > 0.15, cc = [.75 0 0]; end
        title(axc, sprintf('CATCH (%s, n=%d): %+.0f%% of stim Local', D.catch.kind, D.catch.nT, 100*D.catch.ratio), ...
              'FontSize',7,'FontWeight','bold','Color',cc);
        xlabel(axc,'t re onset (s)','FontSize',7);
        for t = numel(pick)+2 : nTile, cla(axTile(t)); set(axTile(t),'Visible','off'); end
    end

    function drawFrontier()
        % CONTROLLER-STYLE view: the leak<->R^2 frontier the op-point sits on. Each dot is one leak
        % penalty; x = held-out capture (VAL, i.e. 100-leak), y = held-out spontaneous R^2. Raising
        % capture (blinding the predictor) costs R^2 -- the curve IS that trade. The star is the knee
        % f2_frontier auto-picks at your r2_floor (dashed line); the grey x is the random-direction
        % control at the same strength -- if it sits ON the curve, the "capture" is shrinkage, not
        % removal of stim structure. r2max mode has no frontier (it is the max-R^2 endpoint).
        cla(axFron); hold(axFron,'on'); box(axFron,'on');
        FR = M.frontier;
        if isempty(FR) || ~isstruct(FR) || ~isfield(FR,'curve') || isempty(FR.curve)
            axis(axFron,[0 1 0 1]);
            text(axFron,0.5,0.55,{'\bfr2max mode','max held-out R^2 point,','no leak-vs-R^2 frontier.', ...
                 'switch to frontier / subspace','to see the trade-off'}, ...
                 'HorizontalAlignment','center','FontSize',8);
            set(axFron,'XTick',[],'YTick',[]);
            title(axFron,'frontier: leak-blindness vs spont R^2','FontSize',9,'FontWeight','bold');
            return
        end
        C = FR.curve;  cap = C.capVal(:);  r2 = C.r2(:);  ok = isfinite(cap) & isfinite(r2);
        plot(axFron, cap(ok), r2(ok), '-o','Color',[.55 .55 .6],'MarkerSize',3, ...
             'MarkerFaceColor',[.7 .7 .75],'DisplayName','frontier sweep');
        yline(axFron, C.r2_floor, 'k--','LineWidth',1.0,'DisplayName','R^2 floor');
        if isfield(FR,'rand') && isfinite(FR.rand.cap_mean)
            plot(axFron, FR.rand.cap_mean, FR.rand.r2_mean, 'x','Color',[.2 .2 .2], ...
                 'MarkerSize',10,'LineWidth',1.4,'DisplayName','random ctrl');
        end
        iP = C.iPick;
        if ~isempty(iP) && iP>=1 && iP<=numel(cap)
            plot(axFron, cap(iP), r2(iP), 'p','MarkerSize',15,'MarkerFaceColor',[.95 .75 .1], ...
                 'MarkerEdgeColor','k','LineWidth',1.0,'DisplayName','chosen (knee)');
        end
        xlabel(axFron,'held-out capture % (=100-leak)'); ylabel(axFron,'spont R^2');
        legend(axFron,'Location','southwest','FontSize',6,'Box','off');
        title(axFron, sprintf('frontier: R^2 price %.3f buys %+.0f pts capture', ...
              FR.r2_price, FR.cap_gain), 'FontSize',9,'FontWeight','bold');
    end

    function drawMap()
        % WHERE the current op-point predicts FROM (same overlay as f2_fitfig): predictor weights
        % scattered on the brain, sized by |weight|, blue<0<red; grey x = pixels the TF detector
        % excluded (stim-affected); red + = the ipsi readout/laser site. As the op-point deflates
        % or the r2_floor rises, watch the surviving weights pull AWAY from the site (more blind).
        bPix = M.b(1:P.nG);  act = find(bPix ~= 0);
        cla(axMap); hold(axMap,'on');
        image(axMap, repmat(P.dspImg,[1 1 3])); axis(axMap,'image','off'); set(axMap,'YDir','reverse');
        if ~isempty(act)
            w = bPix(act);  amax = max(abs(w));
            sz = 6 + 60*abs(w)/max(amax,eps);
            scatter(axMap, P.dspGc(act), P.dspGr(act), sz, w, 'filled', 'MarkerEdgeColor',[.3 .3 .3],'LineWidth',0.2);
            colormap(axMap, local_div());  clim(axMap, [-amax amax]);
        end
        exc = find(any(A.affected,2));
        useMask = ~isfield(knobs,'use_affected') || knobs.use_affected;
        if useMask, xcol = [.2 .2 .2]; else, xcol = [.75 .75 .75]; end   % greyed out when mask ignored
        plot(axMap, P.dspGc(exc), P.dspGr(exc), 'x','Color',xcol,'MarkerSize',3,'LineWidth',0.4);
        plot(axMap, P.dspSc, P.dspSr, 'r+','MarkerSize',13,'LineWidth',1.8);
        aw = abs(bPix);  wd = sum(aw.*P.selDist(:)) / max(sum(aw),eps);  % mean |w|-weighted dist from site (px)
        if useMask, maskStr = sprintf('%d TF-excluded', numel(exc));
        else,       maskStr = sprintf('mask IGNORED (%d flagged, kept)', numel(exc)); end
        title(axMap, sprintf('predictor weights: %d active | %s | mean dist %.0f px  (+ = site)', ...
              numel(act), maskStr, wd), 'FontSize',8,'FontWeight','bold');
    end

    function drawScatter(ax, fld, name, kk)
        ST = D.ST;  dv = ST.L1DEVz(:);  st = local_z(ST.(fld)(:));  pre = ST.PRE(:);
        prc = 100 * tiedrank(pre) / max(numel(pre),1);
        cla(ax); hold(ax,'on'); box(ax,'on');
        ok = isfinite(dv) & isfinite(st) & isfinite(prc);
        scatter(ax, st(ok), dv(ok), 16, prc(ok), 'filled', 'MarkerFaceAlpha',0.7);
        clim(ax,[0 100]); try colormap(ax, flipud(parula)); catch; end
        if nnz(ok) > 2
            pf = polyfit(st(ok), dv(ok), 1); xl = [min(st(ok)) max(st(ok))];
            plot(ax, xl, polyval(pf,xl), 'r-','LineWidth',1.3);
        end
        yline(ax,0,'k:','HandleVisibility','off'); xline(ax,0,'k:','HandleVisibility','off');
        [rl,pl] = local_partial(dv, st, local_z(ST.PRE(:)));
        xlabel(ax, sprintf('%s (z)', name)); ylabel(ax,'L1-dev (z within amp)');
        title(ax, sprintf('%s   \\rho=%+.3f  p=%.3g   (click a point)', name, rl, pl),'FontSize',9,'FontWeight','bold');
        sess_dv = dv;  sess_st{kk} = st;                 % stash for the click handler
    end

    function onClick()
        ax = gca;
        if isequal(ax,axMot)
            kk = 1;
        elseif isequal(ax,axRel)
            kk = 2;
        else
            return
        end
        cp = get(ax,'CurrentPoint'); xc = cp(1,1); yc = cp(1,2);
        xl = xlim(ax); yl = ylim(ax); xs = max(diff(xl),eps); ys = max(diff(yl),eps);
        X = sess_st{kk}; Y = sess_dv;
        d = ((X-xc)/xs).^2 + ((Y-yc)/ys).^2; [dm, im] = min(d);
        if sqrt(dm) > 0.06, return; end
        s1 = struct('label',P.label); s1.D = D; s1.dv = D.ST.L1DEVz(:); s1.state = {sess_st{1}, sess_st{2}};
        IX = struct('sess',s1, 'stateNames',{{'Motion','Rel-\delta'}}, 'dv','L1DEVz');
        f2_inspector(fig, IX, 1, im, kk);                % explicit IX -> no guidata collision with the GUI
    end

    function onCommit()
        op = struct('select_mode',knobs.select_mode,'tag',P.sess_tag,'saved_on',datestr(now), ...
                    'use_affected',knobs.use_affected);      % record whether the TF mask was used
        switch knobs.select_mode
            case 'frontier', op.param = knobs.r2_floor;
            case 'subspace', op.param = knobs.nu;
            case 'r2max',    op.param = knobs.ridge_fixed;
        end
        f = fullfile(dataDir, sprintf('f2_opsel_%s.mat', P.sess_tag));
        save(f, 'op');
        fprintf('[f2_tuner] COMMIT %s : %s param=%.3g mask=%d -> %s\n', ...
                P.label, op.select_mode, op.param, op.use_affected, f);
        updateSummary('committed.');
    end

    function onClearOp()
        f = fullfile(dataDir, sprintf('f2_opsel_%s.mat', P.sess_tag));
        if exist(f,'file'), delete(f); fprintf('[f2_tuner] cleared committed op for %s\n', P.label); end
        updateSummary('committed op cleared -> reverts to default frontier 0.85.');
    end

    function onPooled()
        set(hTxt,'String','[f2_tuner] running POOLED state-dep across all sessions at committed op-points ...');
        drawnow;
        F2arr = struct('label',{},'caveat',{},'D',{});
        used = cell(nS,1);
        for k = 1:nS
            Pk = f2_prep(ae_all(k), struct('dataDir',dataDir,'verbose',false));
            Ak = f2_affected(Pk, struct('plot',false));
            opk = loadOp(Pk.sess_tag);
            mo = struct('use_motion',false,'verbose',false);
            if isempty(opk)
                mo.select_mode = 'frontier'; mo.r2_floor = 0.85; mo.use_affected = true;
                used{k} = 'frontier 0.85, TF-mask (default)';
            else
                mo.select_mode = opk.select_mode;
                mo.use_affected = ~isfield(opk,'use_affected') || opk.use_affected;
                switch opk.select_mode
                    case 'frontier', mo.r2_floor    = opk.param;
                    case 'subspace', mo.nu          = opk.param;
                    case 'r2max',    mo.ridge_fixed = opk.param;
                end
                mstr = 'TF-mask'; if ~mo.use_affected, mstr = 'no-mask'; end
                used{k} = sprintf('%s %.3g, %s (committed)', opk.select_mode, opk.param, mstr);
            end
            Mk = f2_model(Pk, Ak, mo);  Dk = f2_decomp(Pk, Mk, struct('verbose',false));
            F2arr(end+1) = struct('label',Pk.label,'caveat',Pk.caveat,'D',Dk); %#ok<AGROW>
            clear Pk
        end
        Sres = f2_state(F2arr, struct('dv','L1DEVz','plot',true,'verbose',true));
        assignin('base','F2_STATE_committed', Sres);
        assignin('base','F2_committed', F2arr);
        L = {'POOLED STATE-DEP at committed op-points (also saved to base: F2_STATE_committed):',''};
        for k = 1:nS, L{end+1} = sprintf('   %-26s  %s', F2arr(k).label, used{k}); end %#ok<AGROW>
        L{end+1} = '';
        L{end+1} = sprintf('   MOTION    pooled p = %.3g   (median rho %+.3f)', Sres.pooled.p(1), Sres.pooled.rho_med(1));
        L{end+1} = sprintf('   REL-DELTA pooled p = %.3g   (median rho %+.3f)', Sres.pooled.p(2), Sres.pooled.rho_med(2));
        set(hTxt,'String',L);
        fprintf('[f2_tuner] POOLED: Motion p=%.3g | Rel-delta p=%.3g\n', Sres.pooled.p(1), Sres.pooled.p(2));
    end

    function updateSummary(note)
        L = {};
        useMask = ~isfield(knobs,'use_affected') || knobs.use_affected;
        candStr = 'TF-mask'; if ~useMask, candStr = 'ALL px (no mask)'; end
        L{end+1} = sprintf('CURRENT: %s', P.label);
        L{end+1} = sprintf('   op-point: %s  %s=%.3g   | candidates: %s', ...
                            knobs.select_mode, get(hParamLab,'String'), get(hParam,'Value'), candStr);
        L{end+1} = sprintf('   spont R^2 %.3f | capture %3.0f%% | leak %3.0f%% | catch %+3.0f%% | shift %+.2f', ...
                            M.r2_spont, D.capMed, D.leakMed, 100*D.catch.ratio, M.r2_shift);
        if ~useMask && strcmpi(knobs.select_mode,'r2max')
            L{end+1} = '   ** ALL px + r2max = NO blinding (Global absorbs the stim) -> use subspace/frontier to deflate **';
        end
        if abs(D.catch.ratio) > 0.15
            L{end+1} = '   ** catch FAILS (|.|>15%) -> this op-point manufactures residual, do not commit **';
        end
        % detector coverage: amps with ZERO stim-affected px. Benign when they are the NON-responding
        % (low) amps -- those are the ones dropped from capture/leak anyway. Only a problem if a
        % RESPONDING amp has none (detector too insensitive -> retune tf_sens in ols_tf_pipeline 10T3).
        zAmp = find(A.nAff(:).' == 0);
        if ~isempty(zAmp)
            resp = D.ampOK(:).';  danger = intersect(zAmp, find(resp));
            L{end+1} = sprintf('   detector: amps %s have 0 affected px (tf_sens %.2f)', mat2str(zAmp), A.tf_sens);
            if isempty(danger)
                L{end+1} = '      -> all are NON-responding amps (benign: dropped from capture/leak anyway)';
            else
                L{end+1} = sprintf('      ** amps %s RESPOND yet show 0 affected px -> tf_sens too high, RETUNE **', mat2str(danger));
            end
        end
        if ~isempty(P.caveat), L{end+1} = sprintf('   [caveat] %s', P.caveat); end
        L{end+1} = '';
        L{end+1} = 'COMMITTED OP-POINTS (COMMIT to save; RUN POOLED uses these):';
        for k = 1:nS
            opk = loadOp(local_tag(ae_all(k)));
            if isempty(opk)
                s = 'not committed -> default frontier 0.85 (TF-mask)';
            else
                mstr = 'TF-mask'; if isfield(opk,'use_affected') && ~opk.use_affected, mstr = 'no-mask'; end
                s = sprintf('%s %.3g, %s', opk.select_mode, opk.param, mstr);
            end
            here_now = ''; if k==si, here_now = '  <- current'; end
            L{end+1} = sprintf('   %d  %-26s  %s%s', k, names{k}, s, here_now); %#ok<AGROW>
        end
        if nargin>=1 && ~isempty(note), L{end+1} = ''; L{end+1} = ['[' note ']']; end
        set(hTxt,'String',L);
    end

    function op = loadOp(tag)
        op = [];
        f = fullfile(dataDir, sprintf('f2_opsel_%s.mat', tag));
        if exist(f,'file'), Sx = load(f); if isfield(Sx,'op'), op = Sx.op; end, end
    end
end

% ================================ local (non-nested) helpers ======================================
function s = local_name(ae)
tag = ''; if isfield(ae,'site') && ~isempty(ae.site), tag = sprintf(' [%s]', ae.site); end
s = sprintf('%s  %s  e%d%s', ae.mn, ae.td, ae.en, tag);
end

function tag = local_tag(ae)
% Mirror f2_prep's sess_tag so committed-op status can be shown WITHOUT loading the session.
if isfield(ae,'sess_tag') && ~isempty(ae.sess_tag), tag = ae.sess_tag;
else, tag = sprintf('%s_%s%s_e%d', ae.mn, ae.td(6:7), ae.td(9:10), ae.en); end
end

function z = local_z(x)
z = (x - mean(x,'omitnan')) ./ max(std(x,'omitnan'), eps);
end

function [rho, p] = local_partial(dv, st, ctrl)
ok = isfinite(dv) & isfinite(st) & isfinite(ctrl);
if nnz(ok) < 12, rho = NaN; p = NaN; return; end
[rho, p] = partialcorr(dv(ok), st(ok), ctrl(ok), 'type','Spearman','rows','complete');
end

function C = local_div()
% Blue-white-red diverging map (matches f2_fitfig) so a predictor weight's SIGN reads at a glance.
n = 128;  t = linspace(0,1,n).';  o = ones(n,1);
C = [ t, t, o ; o, flipud(t), flipud(t) ];
end

function local_agl(ax, tt, Aq, Gq, Lq, dc, preN)
% One Actual/Global/Local trace panel with the dip window shaded -- identical convention to
% f2_fitfig's local_agl, so the tuner tiles and the diagnostic figure are read the same way.
if isempty(Aq), text(ax,0.5,0.5,'n/a','HorizontalAlignment','center','Units','normalized'); axis(ax,'off'); return; end
yl = [min([Aq;Gq;Lq])-0.15, max([Aq;Gq;Lq])+0.15];
if isempty(dc), dc = (preN+1):numel(tt); end
patch(ax, [tt(dc(1)) tt(dc(end)) tt(dc(end)) tt(dc(1))], [yl(1) yl(1) yl(2) yl(2)], ...
      [.85 .92 1], 'EdgeColor','none','FaceAlpha',0.7,'HandleVisibility','off');
plot(ax, tt, Aq, 'k-','LineWidth',1.5);
plot(ax, tt, Gq, '-','Color',[.85 .2 .2],'LineWidth',1.2);
plot(ax, tt, Lq, '-','Color',[.1 .4 .85],'LineWidth',1.3);
xline(ax,0,'k:','HandleVisibility','off'); yline(ax,0,'k:','HandleVisibility','off');
xlim(ax,[-0.4 0.8]); ylim(ax,yl);
end
