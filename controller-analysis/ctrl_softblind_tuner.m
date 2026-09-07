function ctrl_softblind_tuner(floorArg, leakArg, noguiArg)
% CTRL_SOFTBLIND_TUNER  Interactive model tuner across ALL soft-blind sessions.  [SOFTTUNE]
%
% Reads every ctrl_ols_ol_stimblind_softblind_<sess>.mat cache and puts the WHOLE session pool in
% one cockpit. Two sliders -- the R^2 FLOOR (usability gate) and the HELD-OUT LEAK target (honesty
% gate) -- drive a live count of how many sessions clear BOTH, plus per-session detail. Drag the
% floor down and watch the usable set grow; watch the leak you pay to include each extra session.
%
% The point: the paper's session count is a POLICY, not a fixed number. This tool shows the tradeoff
% so the floor/leak decision (yours + Nick's) is made against the real curve, not a guess.
%
% Per session, from RPATH.SOFT:
%   ridgeR2   = R2te_free            spont held-out R^2 with NO blinding  (the ceiling; max over curve)
%   R2(frac)  = R2te                 spont R^2 as we blind harder (frac 1=ridge .. 0=deflate)
%   leakH(frac)= |leak_hold|         HONEST leak: d fit on ODD trials, scored on EVEN (abs value)
% Feasible at (F,T): ridgeR2 >= F  AND  min|leakH| over the curve points with R2>=F  <=  T.
%   (i.e. the session clears the floor, and within the floor budget it can be blinded to <= T.)
%
% USAGE
%   ctrl_softblind_tuner                 % GUI, defaults floor 0.85 / leak 0.25
%   ctrl_softblind_tuner(0.82, 0.30)     % GUI with presets
%   ctrl_softblind_tuner(0.82, 0.30, true)   % no GUI, just print the pool table

if nargin < 1 || isempty(floorArg); floorArg = 0.85; end
if nargin < 2 || isempty(leakArg);  leakArg  = 0.25; end
if nargin < 3 || isempty(noguiArg); noguiArg = false; end

here_t = fileparts(mfilename('fullpath'));
if isempty(here_t); here_t = fullfile(pwd,'controller-analysis'); end
dataDir_t = fullfile(here_t,'data');

% ---- load every soft-blind cache --------------------------------------------
files_t = dir(fullfile(dataDir_t,'ctrl_ols_ol_stimblind_softblind_*.mat'));
assert(~isempty(files_t), '[SOFTTUNE] no _softblind caches in %s -- run ctrl_softblind_batch.m first.', dataDir_t);
C = struct('sess',{},'ridgeR2',{},'fracs',{},'R2',{},'leakH',{},'n',{});
for i = 1:numel(files_t)
    S = load(fullfile(dataDir_t, files_t(i).name));
    if ~isfield(S,'RPATH') || ~isfield(S.RPATH,'SOFT'); continue; end
    P = S.RPATH.SOFT;
    row.sess    = S.sess_tag;
    row.ridgeR2 = P.R2te_free;
    row.fracs   = P.fracs(:).';
    row.R2      = P.R2te(:).';
    row.leakH   = abs(P.leak_hold(:).');
    if isfield(S,'onF'); row.n = numel(S.onF); else; row.n = 0; end
    C(end+1) = row; %#ok<AGROW>
end
[~,ord] = sort([C.ridgeR2],'descend'); C = C(ord);
nS = numel(C);
fprintf('[SOFTTUNE] loaded %d soft-blind sessions.\n', nS);

if noguiArg
    print_table(floorArg, leakArg);
    return;
end

% ---- GUI --------------------------------------------------------------------
fig = figure('Name','Soft-blind model tuner','Color','w','Position',[120 90 1180 720]);
axBar = axes('Parent',fig,'Position',[0.07 0.40 0.52 0.52]);
axSc  = axes('Parent',fig,'Position',[0.68 0.40 0.29 0.52]);
uicontrol(fig,'Style','text','Units','normalized','Position',[0.07 0.245 0.20 0.03], ...
    'String','R^2 floor','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
sF = uicontrol(fig,'Style','slider','Units','normalized','Position',[0.07 0.205 0.52 0.03], ...
    'Min',0.70,'Max',0.96,'Value',floorArg);
uicontrol(fig,'Style','text','Units','normalized','Position',[0.07 0.135 0.30 0.03], ...
    'String','Held-out leak target','FontWeight','bold','BackgroundColor','w','HorizontalAlignment','left');
sT = uicontrol(fig,'Style','slider','Units','normalized','Position',[0.07 0.095 0.52 0.03], ...
    'Min',0.0,'Max',1.0,'Value',leakArg);
txt = uicontrol(fig,'Style','text','Units','normalized','Position',[0.64 0.05 0.33 0.26], ...
    'String','','FontSize',10,'BackgroundColor',[0.96 0.96 0.98], ...
    'HorizontalAlignment','left','FontName','Consolas');
set(sF,'Callback',@(~,~)redraw());
set(sT,'Callback',@(~,~)redraw());
try
    addlistener(sF,'ContinuousValueChange',@(~,~)redraw());
    addlistener(sT,'ContinuousValueChange',@(~,~)redraw());
catch
end
redraw();

    function [feas, achLeak, clears] = eval_pool(F, T)
        feas = false(1,nS); achLeak = nan(1,nS); clears = false(1,nS);
        for j = 1:nS
            clears(j) = C(j).ridgeR2 >= F;
            in = C(j).R2 >= F;
            if any(in); achLeak(j) = min(C(j).leakH(in)); end
            feas(j) = clears(j) && ~isnan(achLeak(j)) && achLeak(j) <= T;
        end
    end

    function print_table(F, T)
        [feas, achLeak, clears] = eval_pool(F, T);
        fprintf('\n== SOFT-BLIND POOL @ floor=%.3f, held-out leak <=%.2f ==\n', F, T);
        fprintf('%-22s %5s %8s %9s %6s  %s\n','session','n','ridgeR2','achLeak','clears','USABLE');
        for j = 1:nS
            usm = ''; if feas(j); usm = '<== YES'; end
            fprintf('%-22s %5d %8.3f %9.2f %6d  %s\n', C(j).sess, C(j).n, C(j).ridgeR2, ...
                achLeak(j), clears(j), usm);
        end
        fprintf('  -> %d/%d clear the floor; %d/%d clear floor AND leak target.\n', ...
            nnz(clears), nS, nnz(feas), nS);
    end

    function redraw()
        F = get(sF,'Value'); T = get(sT,'Value');
        [feas, achLeak, clears] = eval_pool(F, T);
        col = zeros(nS,3);
        for j=1:nS
            if feas(j);        col(j,:) = [0.15 0.65 0.25];
            elseif clears(j);  col(j,:) = [0.90 0.65 0.10];
            else;              col(j,:) = [0.70 0.70 0.72];
            end
        end
        cla(axBar); hold(axBar,'on');
        for j=1:nS; barh(axBar, j, C(j).ridgeR2, 'FaceColor',col(j,:),'EdgeColor','none'); end
        plot(axBar,[F F],[0 nS+1],'r--','LineWidth',1.3);
        set(axBar,'YTick',1:nS,'YTickLabel',{C.sess},'YDir','reverse','TickLabelInterpreter','none');
        xlim(axBar,[0.68 0.96]); ylim(axBar,[0.4 nS+0.6]); xlabel(axBar,'ridge R^2 (spont, held-out)');
        title(axBar,sprintf('%d/%d clear floor  |  %d/%d usable (floor + leak)', ...
            nnz(clears),nS,nnz(feas),nS));
        grid(axBar,'on'); hold(axBar,'off');
        cla(axSc); hold(axSc,'on');
        for j=1:nS
            if isnan(achLeak(j)); continue; end
            plot(axSc, C(j).ridgeR2, achLeak(j), 'o','MarkerFaceColor',col(j,:), ...
                'MarkerEdgeColor','k','MarkerSize',8);
        end
        plot(axSc,[F F],[0 1.2],'r--','LineWidth',1.1);
        plot(axSc,[0.68 0.96],[T T],'b--','LineWidth',1.1);
        yhi = max([achLeak 0.3]); if isnan(yhi)||yhi<=0; yhi = 0.3; end
        xlim(axSc,[0.68 0.96]); ylim(axSc,[0 min(1.2, yhi*1.1)]);
        xlabel(axSc,'ridge R^2'); ylabel(axSc,'achievable held-out leak');
        title(axSc,'honesty frontier'); grid(axSc,'on'); hold(axSc,'off');
        usable = {C(feas).sess};
        msg = sprintf(['FLOOR   = %.3f\nLEAK <= = %.2f\n\nclear floor : %d/%d\nUSABLE      : %d/%d\n\n', ...
                       'usable sessions:\n%s'], F, T, nnz(clears), nS, nnz(feas), nS, ...
                       strjoin(usable, char(10)));
        set(txt,'String',msg);
    end
end
