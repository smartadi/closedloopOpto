function ctrl_orient_checker()
% CTRL_ORIENT_CHECKER  Fix and FINALIZE each session's display orientation by eye.  [ORIENT]
%
% One job: get every session's brain map into the same anatomical frame (midline VERTICAL, anterior
% up, ipsi/readout hemisphere on the right) and SAVE that view so the tuner and every other renderer
% in the repo inherit it. It shows exactly the stim-blind pixel view used elsewhere -- mean brain
% image, contra grid colored by dip, affected pixels ringed red, laser-effect contours, laser spot
% (green +), controller output pixel (magenta x) -- with the anatomical midline drawn in cyan and a
% grey vertical reference. Rotate/flip until the cyan midline is vertical and the brain is the right
% way up, then SAVE.
%
% SAVE writes the view (incl. fine rotation) to BOTH canonical homes via cp_orient_save:
% cp_orient_ctrl_<sess>.mat and the Stage-1 Torient. Because cp_orient_img/fwd/inv now honour the
% optional rotation and every tool routes through them, the fix propagates with no Stage-1 re-run.
%
% Needs Stage-2 caches rebuilt after 2026-09-07 (ctrl_ols_ol_stimblind.m writes NATIVE geometry into
% OL.MAP). Sessions from older caches show up but are marked [legacy] and cannot be re-oriented here
% until re-run. USAGE:  ctrl_orient_checker
%
% CONTROLS  transpose | flip up/dn | flip L/R | rot +-15 | rot +-5 | reset | auto guess | SAVE
%           dip threshold slider only changes the affected-count display, not the saved view.

here = fileparts(mfilename('fullpath'));
if isempty(here); here = fullfile(pwd,'controller-analysis'); end
dataDir = fullfile(here,'data');

files = dir(fullfile(dataDir,'ctrl_ols_ol_stimblind_softblind_*.mat'));
C = struct('sess',{},'M',{}); seen = {};
for i = 1:numel(files)
    D = load(fullfile(dataDir, files(i).name));
    if ~isfield(D,'MAP') || isempty(D.MAP); continue; end
    tag = ''; if isfield(D,'sess_tag'); tag = D.sess_tag; elseif isfield(D.MAP,'sess_tag'); tag = D.MAP.sess_tag; end
    if isempty(tag); [~,fn] = fileparts(files(i).name); tag = fn; end
    if any(strcmp(tag,seen)); continue; end; seen{end+1} = tag; %#ok<AGROW>
    C(end+1).sess = tag; C(end).M = D.MAP; %#ok<AGROW>
end
assert(~isempty(C), '[ORIENT] no MAP caches found -- run ctrl_ols_ol_stimblind.m (softblind) first.');
[~,ord] = sort({C.sess}); C = C(ord);
nS = numel(C);
Tcur = cell(1,nS);                                   % per-session working view
si = 1;

fig = figure('Name','Orientation checker','Color','w','Position',[70 70 1180 820]);
axM = axes('Parent',fig,'Position',[0.30 0.06 0.68 0.88]);

uicontrol(fig,'Style','text','Units','normalized','Position',[0.03 0.94 0.10 0.03], ...
    'String','session:','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
popSess = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[0.03 0.90 0.24 0.035], ...
    'String',{C.sess},'Value',1,'Callback',@(~,~)pickSession());

% ---- orientation buttons ----
uicontrol(fig,'Style','text','Units','normalized','Position',[0.03 0.845 0.24 0.03], ...
    'String','orient (make cyan midline vertical):','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
mkbtn(0.03, 0.80, 0.115, 'transpose',  @()tog('tr'));
mkbtn(0.155,0.80, 0.115, 'flip up/dn', @()tog('fu'));
mkbtn(0.03, 0.755,0.115, 'flip L/R',   @()tog('fl'));
mkbtn(0.155,0.755,0.115, 'cp_orient auto', @()cpOrientAuto());
mkbtn(0.03, 0.705,0.055, 'rot -15',    @()nudge(-15));
mkbtn(0.088,0.705,0.055, 'rot +15',    @()nudge(+15));
mkbtn(0.155,0.705,0.055, 'rot -5',     @()nudge(-5));
mkbtn(0.213,0.705,0.055, 'rot +5',     @()nudge(+5));
mkbtn(0.03, 0.655,0.055, 'rot -1',     @()nudge(-1));
mkbtn(0.088,0.655,0.055, 'rot +1',     @()nudge(+1));
mkbtn(0.155,0.655,0.115, 'reset',      @()resetT());

% ---- dip threshold (display only) ----
uicontrol(fig,'Style','text','Units','normalized','Position',[0.03 0.585 0.24 0.03], ...
    'String','dip threshold (affected cut, display only):','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
sldDp = uicontrol(fig,'Style','slider','Units','normalized','Position',[0.03 0.555 0.21 0.03], ...
    'Min',0.3,'Max',4.0,'Value',1.33,'Callback',@(~,~)redraw());
txDp = uicontrol(fig,'Style','text','Units','normalized','Position',[0.245 0.555 0.03 0.03], ...
    'String','','BackgroundColor','w');
try; addlistener(sldDp,'ContinuousValueChange',@(~,~)redraw()); catch; end

% ---- save + readout ----
btnSave = uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[0.03 0.485 0.24 0.05], ...
    'String','SAVE this orientation (everywhere)','FontWeight','bold', ...
    'BackgroundColor',[0.80 0.92 0.80],'Callback',@(~,~)saveT());
txt = uicontrol(fig,'Style','text','Units','normalized','Position',[0.03 0.06 0.24 0.40], ...
    'String','','FontSize',9,'BackgroundColor',[0.96 0.96 0.98], ...
    'HorizontalAlignment','left','FontName','Consolas');

pickSession();

    function mkbtn(x,y,w,lab,cb)
        uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[x y w 0.04], ...
            'String',lab,'Callback',@(~,~)cb());
    end
    function pickSession()
        si = get(popSess,'Value');
        Tcur{si} = startT(C(si).sess, C(si).M);
        redraw();
    end
    function T = startT(sess, M)                     % seed from saved standalone view, else MAP.Tor
        T = [];
        f = fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess));
        if exist(f,'file'); S = load(f,'T'); if isfield(S,'T'); T = S.T; end; end
        if isempty(T) && isfield(M,'Tor') && ~isempty(M.Tor); T = M.Tor; end
        if isempty(T)                                % legacy: synthesize an identity view
            if isfield(M,'mimg_native'); [h,w]=size(M.mimg_native); else; [h,w]=size(M.img); end
            T = struct('tr',false,'fu',false,'fl',false,'rot',0,'H',h,'W',w,'Hd',h,'Wd',w,'mid_disp_col',(w+1)/2);
        end
        if ~isfield(T,'rot'); T.rot = 0; end
    end
    function tog(fld)
        T = Tcur{si}; T.(fld) = ~T.(fld);
        if strcmp(fld,'tr'); if T.tr; T.Hd=T.W; T.Wd=T.H; else; T.Hd=T.H; T.Wd=T.W; end; end
        Tcur{si} = T; redraw();
    end
    function nudge(dd);   T=Tcur{si}; if ~isfield(T,'rot');T.rot=0;end; T.rot=T.rot+dd; Tcur{si}=T; redraw(); end
    function resetT();    Tcur{si} = startFresh(C(si).M); redraw(); end
    function T = startFresh(M)
        if isfield(M,'Tor') && ~isempty(M.Tor); T = M.Tor; if ~isfield(T,'rot');T.rot=0;end
        else; if isfield(M,'mimg_native'); [h,w]=size(M.mimg_native); else; [h,w]=size(M.img); end
            T = struct('tr',false,'fu',false,'fl',false,'rot',0,'H',h,'W',w,'Hd',h,'Wd',w,'mid_disp_col',(w+1)/2); end
    end
    function cpOrientAuto()                          % objective dihedral frame from the image (cp_orient)
        M = C(si).M;
        if ~(isfield(M,'mimg_native') && ~isempty(M.mimg_native))
            warndlg('Legacy cache (no native image) -- re-run ctrl_ols_ol_stimblind first.','no native'); return;
        end
        rotKeep = 0; if isfield(Tcur{si},'rot'); rotKeep = Tcur{si}.rot; end
        try
            T = cp_orient(double(M.mimg_native), M.siteRn, M.siteCn, ...
                          struct('cache_file','','confirm',false,'verbose',false));
            T.rot = rotKeep;                         % keep any fine rotation the user already dialed
            Tcur{si} = T; redraw();
        catch ME
            warndlg(sprintf('cp_orient failed: %s', ME.message),'cp_orient failed');
        end
    end
    function saveT()
        M = C(si).M;
        if ~(isfield(M,'mimg_native') && ~isempty(M.mimg_native))
            warndlg('This session is a legacy cache (no native geometry). Re-run ctrl_ols_ol_stimblind for it, then re-orient.','legacy cache'); return;
        end
        try
            p = cp_orient_save(C(si).sess, Tcur{si}, dataDir);
            C(si).M.Tor = Tcur{si};                   % reflect saved state in memory
            s1s = 'S1 updated'; if isempty(p.s1_file); s1s = 'S1 MISSING'; end
            set(txt,'String',sprintf('SAVED %s\n%s\n%s', C(si).sess, local_name(Tcur{si}), s1s));
        catch ME
            warndlg(sprintf('save failed: %s', ME.message),'save failed');
        end
    end
    function redraw()
        M = C(si).M; T = Tcur{si}; dipThr = get(sldDp,'Value');
        set(txDp,'String',sprintf('%.2f',dipThr));
        info = cp_pixel_overlay(axM, M, T, struct('dipThr',dipThr));
        vert = ''; if isfield(T,'rot'); vert = sprintf('%+g deg', T.rot); end
        dppstr = 'n/a'; if isfinite(info.dPP); dppstr = sprintf('%.0f px', info.dPP); end
        reo = 'YES'; if ~info.can_reorient; reo = 'NO (legacy)'; end
        set(txt,'String',sprintf([ ...
            'session   : %s\nview      : %s\nrotation  : %s\ncan re-orient: %s\n\n', ...
            'affected  : %d/%d px @dip %.2f\noutput<->laser: %s\n\n', ...
            'GOAL: cyan midline VERTICAL,\nbrain anterior UP, readout\nhemisphere on the RIGHT.\n', ...
            'Then press SAVE.'], ...
            C(si).sess, local_name(T), vert, reo, info.nAff, info.nPx, dipThr, dppstr));
    end
    function s = local_name(T)
        p={}; if T.tr;p{end+1}='transpose';end; if T.fu;p{end+1}='flipud';end; if T.fl;p{end+1}='fliplr';end
        if isempty(p); s='native'; else; s=strjoin(p,'+'); end
    end
end
