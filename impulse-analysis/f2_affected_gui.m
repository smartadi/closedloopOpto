function f2_affected_gui()
%F2_AFFECTED_GUI  Interactive stim-affected contra-pixel SELECTOR for the impulse Fig-2 stream.
%
% The impulse twin of controller-analysis/ctrl_affected_gui.m. PRIMARY criterion is the AMP-vs-EFFECT
% MONOTONICITY gate: a pixel is stim-affected iff its dip GROWS with laser amplitude (bleed/coupling
% scale with power), which is the physically correct signature and needs no per-session absolute
% threshold. You set the gate by eye, CLICK any pixel to see its per-amp dose-response (the thing the
% gate scores), and COMMIT -- which writes data/f2_affsel_<sess>.mat. f2_affected then PREFERS that
% committed rule over the old TF mask, so the selection you tune here is exactly the one that builds
% the predictor and feeds f2_tuner. Two other methods are available for comparison: 'least_affected'
% (rank by dip, keep K / auto-K by held-out spont R^2) and 'dip' (the old absolute cut). Detection
% math lives in utils/f2_affected_detect.m -- iterate the algorithm THERE, not here.
%
% NEEDS: run `load_experiments` once first.  USAGE:  f2_affected_gui
% -------------------------------------------------------------------------------------------------
here = fileparts(mfilename('fullpath'));
if isempty(here), here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis'; end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));
dataDir = fullfile(here,'data');
if evalin('base','~exist(''allExperiments'',''var'')')
    error('f2_affected_gui: run  load_experiments  first (it loads allExperiments).');
end
ae_all = evalin('base','allExperiments');
nS = numel(ae_all);
names = arrayfun(@(a) local_name(a), ae_all, 'UniformOutput', false);

si = 1; P = []; det = []; score = []; periAvg = {};

fig = figure('Name','F2 affected-pixel selector — amp-monotonicity gate + commit','Color','w','Position',[40 40 1360 850]);
uicontrol(fig,'Style','text','Units','normalized','Position',[.010 .952 .055 .030],'String','session:', ...
    'BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold');
hSess = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.065 .955 .190 .030], ...
    'String',names,'Value',1,'Callback',@(~,~)onSession());
uicontrol(fig,'Style','text','Units','normalized','Position',[.265 .952 .050 .030],'String','method:', ...
    'BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold');
hMethod = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.315 .955 .215 .030], ...
    'String',{'monotone (amp gate)','least_affected (rank+R^2)','dip (absolute)'},'Value',1,'Callback',@(~,~)onMethod());
hParLab = uicontrol(fig,'Style','text','Units','normalized','Position',[.540 .952 .085 .030], ...
    'String','mono thr |\rho|','BackgroundColor','w','HorizontalAlignment','left');
hPar = uicontrol(fig,'Style','slider','Units','normalized','Position',[.540 .928 .190 .022], ...
    'Min',0.2,'Max',0.95,'Value',0.5,'Callback',@(~,~)onSlide());
hParVal = uicontrol(fig,'Style','text','Units','normalized','Position',[.735 .952 .045 .030], ...
    'String','0.50','BackgroundColor','w','FontWeight','bold');
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.788 .953 .066 .033], ...
    'String','AUTO','FontWeight','bold','BackgroundColor',[.85 .90 .98],'Callback',@(~,~)onAuto());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.858 .953 .066 .033], ...
    'String','COMMIT','FontWeight','bold','BackgroundColor',[.80 .92 .80],'Callback',@(~,~)onCommit());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.928 .953 .060 .033], ...
    'String','clear','Callback',@(~,~)onClear());
hStatus = uicontrol(fig,'Style','text','Units','normalized','Position',[.010 .914 .980 .030], ...
    'String','','BackgroundColor','w','HorizontalAlignment','left','FontWeight','bold','ForegroundColor',[.1 .4 .1]);

axMap   = axes('Parent',fig,'Position',[.040 .300 .430 .590]);
axPix   = axes('Parent',fig,'Position',[.545 .560 .430 .330]);
axCurve = axes('Parent',fig,'Position',[.545 .120 .430 .330]);
hTxt = uicontrol(fig,'Style','text','Units','normalized','Position',[.040 .030 .430 .235], ...
    'String','','FontName','Consolas','FontSize',9,'BackgroundColor',[.96 .96 .98], ...
    'HorizontalAlignment','left','Max',20);

set(fig,'WindowButtonDownFcn',@(s,~)onClick());
onSession();

% =================================================================================================
    function onSession()
        si = get(hSess,'Value');
        fprintf('[f2_affected_gui] loading %s ...\n', names{si});
        P = f2_prep(ae_all(si), struct('dataDir',dataDir,'verbose',false));
        sel = loadSel(P.sess_tag);
        if ~isempty(sel), setMethodParam(sel); else, setMethodParam(struct('method','monotone','mono_thr',0.5)); end
        runDetect();
    end

    function onMethod(), applyMethodRange(); runDetect(); end
    function onSlide(),  set(hParVal,'String',sprintf('%.3g',get(hPar,'Value'))); runDetect(); end

    function applyMethodRange()
        switch get(hMethod,'Value')
            case 1, set(hParLab,'String','mono thr |\rho|'); set(hPar,'Min',0.2,'Max',0.95);
            case 2, set(hParLab,'String','keep K');          set(hPar,'Min',5,'Max',max(P.nG,6));
            case 3, set(hParLab,'String','dip thr');         set(hPar,'Min',0.5,'Max',3.0);
        end
        v = min(max(get(hPar,'Value'), get(hPar,'Min')), get(hPar,'Max'));
        set(hPar,'Value',v);  set(hParVal,'String',sprintf('%.3g',v));
    end

    function setMethodParam(sel)
        switch lower(sel.method)
            case 'monotone',       set(hMethod,'Value',1);
            case 'least_affected', set(hMethod,'Value',2);
            case 'dip',            set(hMethod,'Value',3);
        end
        applyMethodRange();
        p = local_selparam(sel);
        if ~isnan(p), set(hPar,'Value', min(max(p,get(hPar,'Min')),get(hPar,'Max'))); end
        set(hParVal,'String',sprintf('%.3g',get(hPar,'Value')));
    end

    function o = buildOpts()
        o = struct('verbose',false);
        v = get(hPar,'Value');
        switch get(hMethod,'Value')
            case 1, o.method='monotone';       o.mono_thr = v;
            case 2, o.method='least_affected'; o.keep_n   = round(v);
            case 3, o.method='dip';            o.thr      = v;
        end
    end

    function runDetect()
        det = f2_affected_detect(P, buildOpts());
        score = det.score;  periAvg = det.periAvg;
        drawMap();  drawCurve();  report('');
        cla(axPix); title(axPix,'click a pixel on the map -> its per-amp dose-response (what the gate scores)','FontSize',9);
    end

    function onAuto()
        if get(hMethod,'Value') ~= 2
            report('AUTO applies to least_affected only (auto-K by held-out R^2); monotone/dip use the slider.');
            return
        end
        set(hStatus,'String','sweeping K for the spont-R^2 floor ...','ForegroundColor',[.1 .1 .1]); drawnow;
        det = f2_affected_detect(P, struct('method','least_affected','verbose',false));
        score = det.score;  periAvg = det.periAvg;
        set(hPar,'Value', min(max(det.K,get(hPar,'Min')),get(hPar,'Max')));  set(hParVal,'String',sprintf('%d',det.K));
        drawMap();  drawCurve();
        report(local_tern(det.K_reachable, sprintf('AUTO-K = %d (smallest K clearing R^2 floor)', det.K), ...
                          sprintf('AUTO-K = %d — NO K clears the floor; this is the ceiling', det.K)));
    end

    function onCommit()
        sel = buildOpts();  sel = rmfield(sel,'verbose');
        sel.saved_on = datestr(now);  sel.tag = P.sess_tag;
        f = fullfile(dataDir, sprintf('f2_affsel_%s.mat', P.sess_tag));  save(f,'sel');
        fprintf('[f2_affected_gui] COMMIT %s : %s %s -> %s\n', P.label, sel.method, mat2str(local_selparam(sel)), f);
        report('COMMITTED — f2_affected / f2_tuner now use this selection.');
    end

    function onClear()
        f = fullfile(dataDir, sprintf('f2_affsel_%s.mat', P.sess_tag));
        if exist(f,'file'), delete(f); fprintf('[f2_affected_gui] cleared %s\n', P.label); end
        report('committed selection cleared -> f2_affected reverts to the TF mask.');
    end

    function drawMap()
        keep = ~any(det.affected,2);
        cla(axMap); hold(axMap,'on');
        image(axMap, repmat(P.dspImg,[1 1 3])); axis(axMap,'image','off'); set(axMap,'YDir','reverse');
        scatter(axMap, P.dspGc, P.dspGr, 16, score, 'filled', 'MarkerFaceAlpha',0.85);
        if strcmpi(det.method,'monotone')
            colormap(axMap, local_div());  clim(axMap, [-1 1]);          % rho: blue<0 (affected) .. red>0
        else
            try colormap(axMap, flipud(parula)); catch; end
            cl = [min(score,[],'omitnan') 0];  if diff(cl)<=0, cl = [-1 0]; end;  clim(axMap, cl);
        end
        plot(axMap, P.dspGc(keep), P.dspGr(keep), 'o','MarkerEdgeColor',[0 .55 0],'MarkerSize',7,'LineWidth',1.0);
        plot(axMap, P.dspSc, P.dspSr, 'r+','MarkerSize',15,'LineWidth',2.0);
        title(axMap, sprintf('%s | %s: %d affected, %d kept (green ring = predictor)  + = site', ...
              P.label, det.method, nnz(~keep), nnz(keep)), 'FontSize',9,'FontWeight','bold');
    end

    function drawCurve()
        cla(axCurve); hold(axCurve,'on'); box(axCurve,'on');
        if strcmpi(det.method,'least_affected') && isstruct(det.curve) && ~isempty(det.curve.K)
            plot(axCurve, det.curve.K, det.curve.r2, '-o','Color',[.4 .4 .5],'MarkerSize',3,'MarkerFaceColor',[.6 .6 .7]);
            yline(axCurve, det.opts.r2_floor, 'k--','LineWidth',1.0);
            plot(axCurve, det.K, det.r2_at_K, 'p','MarkerSize',15,'MarkerFaceColor',[.95 .75 .1],'MarkerEdgeColor','k');
            xlabel(axCurve,'K (pixels kept)'); ylabel(axCurve,'held-out spont R^2');
            title(axCurve,'auto-K sweep: smallest K clearing the floor (star)','FontSize',9,'FontWeight','bold');
        else
            % distribution of the gate score across pixels, with the cut line -> see where it lands
            histogram(axCurve, score, 40, 'FaceColor',[.6 .6 .7],'EdgeColor','none');
            if strcmpi(det.method,'monotone')
                xline(axCurve, -det.opts.mono_thr, 'r-','LineWidth',1.5);
                xlabel(axCurve,'amp-vs-dip Spearman \rho  (< -thr = affected)');
                title(axCurve,'monotonicity distribution (red = gate; left of it = affected)','FontSize',9,'FontWeight','bold');
            else
                xline(axCurve, -det.opts.thr, 'r-','LineWidth',1.5);
                xlabel(axCurve,'worst-amp dip score  (< -thr = affected)');
                title(axCurve,'dip-score distribution (red = gate)','FontSize',9,'FontWeight','bold');
            end
            ylabel(axCurve,'pixels');
        end
    end

    function onClick()
        if ~isequal(gca, axMap), return; end
        cp = get(axMap,'CurrentPoint');  xc = cp(1,1);  yc = cp(1,2);
        d = (P.dspGc(:)-xc).^2 + (P.dspGr(:)-yc).^2;  [dm, pix] = min(d);
        if dm > (0.03*max(size(P.dspImg)))^2, return; end
        cla(axPix); hold(axPix,'on'); box(axPix,'on');
        tt = P.rel(:)/P.Fs;  co = lines(numel(periAvg));
        for ai = 1:numel(periAvg)
            if isempty(periAvg{ai}), continue; end
            tr = periAvg{ai}(pix,:).';  tr = tr - mean(tr(1:P.preN));
            plot(axPix, tt, tr, '-','Color',co(ai,:),'LineWidth',1.0,'DisplayName',sprintf('%.2g V',P.amps(ai)));
            dc = P.dcc{ai};  if ~isempty(dc), plot(axPix, tt(dc), tr(dc), '.','Color',co(ai,:),'MarkerSize',6,'HandleVisibility','off'); end
        end
        xline(axPix,0,'k:','HandleVisibility','off'); yline(axPix,0,'k:','HandleVisibility','off');
        xlabel(axPix,'t re onset (s)'); ylabel(axPix,'\DeltaF/F %'); legend(axPix,'Location','southwest','FontSize',6,'Box','off');
        kept = ~any(det.affected(pix,:));
        title(axPix, sprintf('pixel #%d: amp-\\rho %+.2f, worst dip %+.2f  ->  %s', ...
              pix, det.mono(pix), det.poolScore(pix), local_tern(kept,'KEPT (predictor)','AFFECTED (dropped)')), ...
              'FontSize',9,'FontWeight','bold','Color', local_tern(kept,[0 .45 0],[.6 0 0]));
    end

    function report(note)
        keep = ~any(det.affected,2);
        set(hStatus,'String', sprintf('%s | %d affected / %d kept | residual dip bleed of kept set %+.2f   %s', ...
            det.method, nnz(~keep), nnz(keep), det.bleed_kept, note), 'ForegroundColor',[.1 .4 .1]);
        L = {};
        L{end+1} = sprintf('SESSION: %s   method: %s', P.label, det.method);
        L{end+1} = sprintf('   %d of %d pixels kept as the Global predictor set (%.0f%%)', nnz(keep), P.nG, 100*nnz(keep)/P.nG);
        L{end+1} = sprintf('   residual dip bleed of KEPT set: median %+.2f, worst %+.2f', det.bleed_kept, det.bleed_worst);
        if strcmpi(det.method,'monotone')
            L{end+1} = '   affected = amp-vs-dip Spearman rho <= -thr AND dips at the strongest amp';
        end
        L{end+1} = '';
        L{end+1} = 'COMMITTED SELECTIONS (COMMIT writes f2_affsel_<sess>.mat; f2_affected prefers it):';
        for k = 1:nS
            s = loadSel(local_tag(ae_all(k)));
            hn = ''; if k==si, hn = '  <- current'; end
            if isempty(s), L{end+1} = sprintf('   %d  %-26s  TF mask (not committed)%s', k, names{k}, hn); %#ok<AGROW>
            else, L{end+1} = sprintf('   %d  %-26s  %s %s%s', k, names{k}, s.method, mat2str(local_selparam(s)), hn); %#ok<AGROW>
            end
        end
        set(hTxt,'String',L);
    end

    function sel = loadSel(tag)
        sel = [];
        f = fullfile(dataDir, sprintf('f2_affsel_%s.mat', tag));
        if exist(f,'file'), Sx = load(f); if isfield(Sx,'sel'), sel = Sx.sel; end, end
    end
end

% ================================ local helpers ===================================================
function s = local_name(ae)
tag = ''; if isfield(ae,'site') && ~isempty(ae.site), tag = sprintf(' [%s]', ae.site); end
s = sprintf('%s  %s  e%d%s', ae.mn, ae.td, ae.en, tag);
end

function tag = local_tag(ae)
if isfield(ae,'sess_tag') && ~isempty(ae.sess_tag), tag = ae.sess_tag;
else, tag = sprintf('%s_%s%s_e%d', ae.mn, ae.td(6:7), ae.td(9:10), ae.en); end
end

function p = local_selparam(sel)
% the single tuned number a committed selection carries, whatever its method
if isfield(sel,'mono_thr') && ~isempty(sel.mono_thr)
    p = sel.mono_thr;
elseif isfield(sel,'keep_n') && ~isempty(sel.keep_n)
    p = sel.keep_n;
elseif isfield(sel,'thr') && ~isempty(sel.thr)
    p = sel.thr;
else
    p = NaN;
end
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end

function C = local_div()
n = 128;  t = linspace(0,1,n).';  o = ones(n,1);
C = [ t, t, o ; o, flipud(t), flipud(t) ];   % blue -> white -> red
end
