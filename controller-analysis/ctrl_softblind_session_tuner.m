function ctrl_softblind_session_tuner()
% CTRL_SOFTBLIND_SESSION_TUNER  Per-session interactive op-point tuner with all knobs.  [SOFTSESS]
%
% Pick ONE session and tune it against its own data, live, with no session reload:
%   PANELS   (left)  Actual / Global / Local decomposition at the current blinding op point
%            (mid)   its leak <-> R^2 frontier, ridge / auto-op / current markers + gate lines
%            (right) STIM-BLIND PIXEL VIEW on the mean brain image: contra grid pixels colored by
%                    dip score, affected pixels (dip < -threshold) ringed red, the DATA-DERIVED
%                    laser-effect contours + laser spot (green +) and the controller OUTPUT pixel
%                    d.params.pixel (magenta x) -- so you can eyeball whether the readout sat on the
%                    laser spot. The map is drawn in the FINALIZED per-session view (cp_pixel_overlay
%                    through the saved cp_orient T); fix orientation in ctrl_orient_checker, not here.
%   KNOBS    op point / R^2 floor / leak target / dip threshold ; snap to auto op.
%   COMMIT   'COMMIT op point' saves the current op (its leak-fraction) to data/ctrl_opsel_<sess>.mat;
%            ctrl_ols_ol_stimblind then DEPLOYS that op (overriding the auto rule) on the next re-run,
%            so the hand-picked point persists into the deployed Global/Local + all downstream metrics.
%            The tuner reopens each session at its committed op (magenta diamond). 'clear committed'
%            deletes the file and reverts to the auto rule. Floor/leak-target/dip are display-only.
%
% Needs caches rebuilt after 2026-09-07 (ctrl_ols_ol_stimblind.m writes OL.SWEEP + OL.MAP incl. the
% laser-spot layer). USAGE:  ctrl_softblind_session_tuner

here_s = fileparts(mfilename('fullpath'));
if isempty(here_s); here_s = fullfile(pwd,'controller-analysis'); end
dataDir_s = fullfile(here_s,'data');

files_s = dir(fullfile(dataDir_s,'ctrl_ols_ol_stimblind_softblind_*.mat'));
C = struct('sess',{},'S',{},'M',{});
for i = 1:numel(files_s)
    D = load(fullfile(dataDir_s, files_s(i).name));
    if ~isfield(D,'SWEEP') || isempty(D.SWEEP); continue; end
    C(end+1).sess = D.sess_tag; C(end).S = D.SWEEP; %#ok<AGROW>
    if isfield(D,'MAP') && ~isempty(D.MAP); C(end).M = D.MAP; else; C(end).M = []; end
end
assert(~isempty(C), '[SOFTSESS] no caches carry SWEEP yet -- re-run under CTRL_PRED=''softblind'' first.');
[~,ord] = sort(cellfun(@(s)s.R2te(1), {C.S}),'descend'); C = C(ord);
nS = numel(C);
si = 1; Tload = cell(1,nS);                             % current session; per-session FINALIZED view
FLOOR0 = ctrl_r2_floor();
dataDir_t = dataDir_s;                                  % where cp_orient_ctrl_<sess>.mat lives

fig = figure('Name','Soft-blind session tuner','Color','w','Position',[55 60 1520 800]);
axD = axes('Parent',fig,'Position',[0.045 0.42 0.26 0.52]);
axF = axes('Parent',fig,'Position',[0.365 0.42 0.185 0.52]);
axM = axes('Parent',fig,'Position',[0.61 0.36 0.36 0.60]);

uicontrol(fig,'Style','text','Units','normalized','Position',[0.045 0.955 0.08 0.03], ...
    'String','session:','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
popSess = uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[0.12 0.958 0.24 0.03], ...
    'String',{C.sess},'Value',1,'Callback',@(~,~)pickSession());

[sldOp , ~   ] = mkslider('op point   (left ridge/free  ->  right deflate/max-blind)', 0.30, 1, numel(C(1).S.fracs), C(1).S.sel_idx);
[sldFl , txFl] = mkslider('R^2 floor', 0.22, 0.70, 0.96, FLOOR0);
[sldLk , txLk] = mkslider('leak target', 0.14, 0.0, 1.0, 0.25);
[sldDp , txDp] = mkslider('dip threshold (affected cut)', 0.06, 0.3, 4.0, defthr());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[0.35 0.11 0.10 0.045], ...
    'String','snap to auto op','Callback',@(~,~)snapAuto());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[0.35 0.06 0.10 0.045], ...
    'String','COMMIT op point','FontWeight','bold','BackgroundColor',[0.80 0.92 0.80], ...
    'Callback',@(~,~)commitOp());
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[0.35 0.012 0.10 0.043], ...
    'String','clear committed','Callback',@(~,~)clearOp());
% orientation is FINALIZED in ctrl_orient_checker and read here (saved cp_orient view). Fix it there.
uicontrol(fig,'Style','text','Units','normalized','Position',[0.61 0.305 0.30 0.026], ...
    'String','orientation: finalized in ctrl_orient_checker (read-only here)', ...
    'FontAngle','italic','BackgroundColor','w','HorizontalAlignment','left','ForegroundColor',[0.4 0.4 0.45]);
txt = uicontrol(fig,'Style','text','Units','normalized','Position',[0.47 0.005 0.13 0.30], ...
    'String','','FontSize',9,'BackgroundColor',[0.96 0.96 0.98], ...
    'HorizontalAlignment','left','FontName','Consolas');
redraw();

    function thr = defthr()
        if ~isempty(C(1).M) && isfield(C(1).M,'thr'); thr = C(1).M.thr; else; thr = 1.33; end
    end
    function [sld, tx] = mkslider(lab, y, lo, hi, val)
        uicontrol(fig,'Style','text','Units','normalized','Position',[0.045 y+0.035 0.30 0.028], ...
            'String',lab,'FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
        sld = uicontrol(fig,'Style','slider','Units','normalized','Position',[0.045 y 0.28 0.03], ...
            'Min',lo,'Max',hi,'Value',val,'Callback',@(~,~)redraw());
        tx  = uicontrol(fig,'Style','text','Units','normalized','Position',[0.33 y 0.03 0.03], ...
            'String','','BackgroundColor','w','HorizontalAlignment','left');
        try; addlistener(sld,'ContinuousValueChange',@(~,~)redraw()); catch; end
    end
    function pickSession()
        si = get(popSess,'Value');
        nW = numel(C(si).S.fracs);
        op0 = C(si).S.sel_idx;                       % open at the COMMITTED op if one exists, else auto
        cf = committedFrac(C(si).sess);
        if ~isnan(cf); [~,op0] = min(abs(C(si).S.fracs(:) - cf)); end
        set(sldOp,'Max',nW,'Min',1,'Value',op0,'SliderStep',[1/(nW-1) 2/(nW-1)]);
        if ~isempty(C(si).M) && isfield(C(si).M,'thr'); set(sldDp,'Value',C(si).M.thr); end
        redraw();
    end
    function snapAuto();  set(sldOp,'Value',autoOp(C(si).S,get(sldFl,'Value'))); redraw(); end
    function f = opselFile(sess);  f = fullfile(dataDir_t, sprintf('ctrl_opsel_%s.mat', sess)); end
    function cf = committedFrac(sess)
        cf = NaN; f = opselFile(sess);
        if exist(f,'file'); Sv = load(f,'sel_frac'); if isfield(Sv,'sel_frac'); cf = Sv.sel_frac; end; end
    end
    function commitOp()
        S = C(si).S; op = max(1,min(numel(S.fracs), round(get(sldOp,'Value'))));
        sel_frac = S.fracs(op); sel_idx = op; %#ok<NASGU>
        sel_leak = abs(S.leak_hold(op)); sel_R2 = S.R2te(op); %#ok<NASGU>
        committed = datestr(now,'yyyy-mm-dd HH:MM'); sess = C(si).sess; %#ok<NASGU,TNOW1>
        save(opselFile(C(si).sess),'sel_frac','sel_idx','sel_leak','sel_R2','committed','sess');
        redraw();
    end
    function clearOp()
        f = opselFile(C(si).sess); if exist(f,'file'); delete(f); end
        set(sldOp,'Value', autoOp(C(si).S, get(sldFl,'Value'))); redraw();
    end
    function T = finalT(k)                        % FINALIZED view: saved cp_orient view, else MAP.Tor
        if ~isempty(Tload{k}); T = Tload{k}; return; end
        T = []; f = fullfile(dataDir_t, sprintf('cp_orient_ctrl_%s.mat', C(k).sess));
        if exist(f,'file'); Sv = load(f,'T'); if isfield(Sv,'T'); T = Sv.T; end; end
        if isempty(T) && ~isempty(C(k).M) && isfield(C(k).M,'Tor'); T = C(k).M.Tor; end
        Tload{k} = T;
    end
    function a = autoOp(S,F)
        inB = S.R2te >= F;
        if any(inB); lh = abs(S.leak_hold); lh(~inB) = inf; [~,a] = min(lh); else; a = 1; end
    end
    function redraw()
        S = C(si).S;  M = C(si).M;
        op = max(1,min(numel(S.fracs), round(get(sldOp,'Value'))));
        F  = get(sldFl,'Value');  Tlk = get(sldLk,'Value');  dipThr = get(sldDp,'Value');
        set(txFl,'String',sprintf('%.2f',F)); set(txLk,'String',sprintf('%.2f',Tlk)); set(txDp,'String',sprintf('%.2f',dipThr));
        Aa = S.Aa(:).'; tt = S.tt(:).'; Gg = S.Gsweep(op,:); Lo = Aa - Gg;
        R2 = S.R2te(op); lk = abs(S.leak_hold(op)); auto = autoOp(S,F);
        clears = S.R2te(1) >= F;  capt = @(w) 100*mean(Lo(w))/mean(Aa(w));
        cf = committedFrac(C(si).sess); cIdx = NaN;
        if ~isnan(cf); [~,cIdx] = min(abs(S.fracs(:)-cf)); end
        tagOp = ''; if ~isnan(cIdx) && op==cIdx; tagOp='  [COMMITTED]'; elseif op==auto; tagOp='  [AUTO]'; end

        % --- decomposition ---
        cla(axD); hold(axD,'on');
        plot(axD,tt,Aa,'k-','LineWidth',1.8); plot(axD,tt,Gg,'-','Color',[0.85 0.4 0.1],'LineWidth',1.5);
        plot(axD,tt,Lo,'-','Color',[0.1 0.5 0.85],'LineWidth',1.5);
        xline(axD,0,'k:'); yline(axD,0,'k:'); xlim(axD,[-S.pre_s S.dur]);
        xlabel(axD,'time from stim (s)'); ylabel(axD,'\DeltaF/F (%)');
        legend(axD,{'Actual','Global','Local'},'Box','off','Location','southwest');
        title(axD,sprintf('%s   op %d/%d (frac %.2f)%s',C(si).sess,op,numel(S.fracs),S.fracs(op), ...
            tagOp),'Interpreter','none'); grid(axD,'on'); hold(axD,'off');

        % --- frontier ---
        cla(axF); hold(axF,'on');
        plot(axF,abs(S.leak_hold),S.R2te,'-','Color',[0.6 0.6 0.65],'LineWidth',1.0);
        plot(axF,abs(S.leak_hold(1)),S.R2te(1),'ks','MarkerFaceColor','w','MarkerSize',7);
        plot(axF,abs(S.leak_hold(auto)),S.R2te(auto),'o','MarkerFaceColor',[0.2 0.7 0.3],'MarkerEdgeColor','k','MarkerSize',8);
        if ~isnan(cIdx)   % committed op (magenta diamond)
            plot(axF,abs(S.leak_hold(cIdx)),S.R2te(cIdx),'d','MarkerFaceColor',[0.9 0.2 0.9],'MarkerEdgeColor','k','MarkerSize',10);
        end
        plot(axF,lk,R2,'o','MarkerFaceColor',[0.85 0.2 0.2],'MarkerEdgeColor','k','MarkerSize',11);
        plot(axF,[0 1.1],[F F],'r--','LineWidth',1.0); plot(axF,[Tlk Tlk],[0.6 1.0],'b--','LineWidth',0.9);
        xlim(axF,[0 1.05]); ylim(axF,[min(0.66,min(S.R2te)-0.02) max(0.96,max(S.R2te)+0.02)]);
        xlabel(axF,'held-out leak'); ylabel(axF,'spont R^2'); title(axF,'frontier (red=current)');
        grid(axF,'on'); hold(axF,'off');

        % --- stim-blind pixel view (FINALIZED orientation from ctrl_orient_checker) ---
        nAff = NaN; nPx = NaN; dPP = NaN; Tv = finalT(si);
        if ~isempty(M) && (isfield(M,'mimg_native') || isfield(M,'img'))
            info = cp_pixel_overlay(axM, M, Tv, struct('dipThr',dipThr));
            cb = colorbar(axM,'eastoutside'); cb.Label.String='dip score';
            nAff = info.nAff; nPx = info.nPx; dPP = info.dPP;
        else
            cla(axM); text(0.5,0.5,'no pixel map cached','Parent',axM,'HorizontalAlignment','center'); axis(axM,'off');
        end

        vv = tern(~clears,'NO-FLOOR', tern(lk<=0.25,'BLIND', tern(lk<=0.40,'MARGINAL','LEAKY')));
        affstr = ''; if ~isnan(nAff); affstr=sprintf('%d/%d (%.0f%%)',nAff,nPx,100*nAff/nPx); end
        ppstr  = 'n/a'; if isfinite(dPP); ppstr=sprintf('%.0f px',dPP); end
        if isnan(cIdx); cstr='none (uses auto rule)';
        else; cstr=sprintf('frac %.2f (idx %d)%s', S.fracs(cIdx), cIdx, tern(op==cIdx,' = current','')); end
        msg = sprintf(['session : %s\nop point: %d/%d (frac %.2f)\ncommitted: %s\norient  : %s\n\n', ...
            'spont R^2     : %.3f (floor %.2f)\nheld-out leak : %.2f (targ %.2f)\nclears floor  : %d\n', ...
            'Local capture : %3.0f%% tran / %3.0f%% sust\nstate @ op    : %s\n\n', ...
            'affected px @dip %.2f: %s\noutput px<->laser spot: %s'], ...
            C(si).sess, op, numel(S.fracs), S.fracs(op), cstr, viewName(Tv), R2, F, lk, Tlk, clears, ...
            capt(S.twin), capt(S.swin), vv, dipThr, affstr, ppstr);
        set(txt,'String',msg);
    end
    function y = tern(c,a,b); if c; y=a; else; y=b; end; end
    function s = viewName(T)
        if isempty(T); s = 'native (none saved)'; return; end
        p={}; if T.tr;p{end+1}='transpose';end; if T.fu;p{end+1}='flipud';end; if T.fl;p{end+1}='fliplr';end
        if isempty(p); s='native'; else; s=strjoin(p,'+'); end
        if isfield(T,'rot') && T.rot~=0; s=sprintf('%s + rot %+g', s, T.rot); end
    end
end
