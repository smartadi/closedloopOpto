function RT = f4_supp_reject_trials(mouse, fields)
% F4_SUPP_REJECT_TRIALS  Supplementary S4: single trials behind the Fig-4G rejection ratio.
%   RT = f4_supp_reject_trials(mouse, fields)   % after load_sessions.m
%
% Fig.~4G reduces every trial to one number, RR = ||A-r||^2/||D||^2, and a ratio hides what the
% two traces look like. Each tile here is ONE trial and draws EXACTLY the two traces that ratio
% compares (user 2026-10-09), so both live on one zero baseline:
%   colour  A - r, the tracking error (red open loop, blue closed loop). 0 = on the reference.
%   grey    D, the disturbance: the stimulation-blind contralateral prediction G referenced to its
%           own 1 s pre-onset baseline, minus the session-mean open-loop laser leak. The leak term
%           is subtracted only while the laser is on (0..dur); outside stimulation D is just the
%           baseline-referenced prediction, because there is no laser to leak.
% Full strength inside the RR window [+1,+3] s (grey band) -- the only samples the ratio uses.
% Everything else, from 3 s before onset to 2 s after stimulation ends, is drawn in a light tint
% for context only.
%
% RR IS COMPUTED EXACTLY AS IN f4_cl_reject_lmm.m -- settled window [+1,+3] s, D referenced to its
% own pre-stimulus baseline and leak-corrected by the session-mean open-loop dip -- so a tile
% labelled RR = 0.31 is literally one of the trials inside the Fig-4G statistic. This is the whole
% point of the figure and the reason it does not reuse ctrl_reject_trial_gallery.m, whose ER is a
% different quantity (||A-ref||^2/||G-ref||^2 over 0-3 s, no leak correction).
%
% Trials are drawn at RR percentiles so each strip spans that session's range rather than
% flattering it: leftmost tile = among its best rejection, rightmost = among its worst.
%
% Panels (one PDF each, assembled into S4 in Illustrator -- never montaged here, see MANIFEST):
%   s4_reject_trials_<sess>.pdf   2 rows (OL, CL) x 3 RR percentiles, one per session.
% Sessions: three from the analysed pool (one per mouse) plus AL_0051, which the standing-offset
% criterion excludes, so the Discussion can show WHY it is excluded rather than assert it.
%
% Set the global PAPER_FINAL = true to mirror into paper/figures_final (MANIFEST-gated).
if nargin < 2 || isempty(mouse) || isempty(fields)
    assert(evalin('base','exist(''mouse'',''var'') && exist(''fields'',''var'')'), ...
        'run load_sessions.m first, or pass (mouse, fields)');
    mouse = evalin('base','mouse');  fields = evalin('base','fields');
end
here = fileparts(mfilename('fullpath'));  dataDir = fullfile(here,'data');
bpData = fullfile(fileparts(here),'data');
outdir = fullfile(fileparts(here),'paper','images','supplementary');
if ~exist(outdir,'dir'); mkdir(outdir); end
PS = paperStyle();

% pre_s = 3 s of context so the pre-onset overlap of A and G is visible; RR itself is unaffected,
% because its window is defined relative to the onset sample, not to the start of the trace.
CFG = struct('nSV_load',500, 'Fs',35, 'pre_s',3.0, 'resp_s',3.0, 'post_extra_s',2.0);
% post_extra_s only lengthens the drawn trace; wr/bwin below are indexed from onset, so RR is
% untouched (verified: session medians still reproduce production).
REF = -5;  PCT = [10 50 90];

% One session per mouse from the analysed pool, then the excluded one. Chosen for median RR near
% the cohort median rather than for the prettiest trials.
WANT = {'AL_0033_0226_e2','AL_0039_0420_e1','AL_0048_0729_e2','AL_0051_0729_e2'};
RT = struct('tag',{},'medRR_ol',{},'medRR_cl',{},'gdip',{},'R2te',{},'excluded',{});

for s = 1:numel(fields)
    fld = fields{s}; M = mouse.(fld); freeAfter = false;
    tg = sprintf('%s_%s%s_e%d', M.mn, M.td(6:7), M.td(9:10), M.en);
    if ~any(strcmp(tg, WANT)); continue; end
    if ~isfield(M,'d') || isempty(M.d)
        pth = fullfile(bpData, sprintf('%sctrl%s%s%d.mat', M.mn, M.td(6:7), M.td(9:10), M.en));
        if ~exist(pth,'file'); continue; end
        tmp = load(pth); if ~isfield(tmp,'d'); clear tmp; continue; end
        mouse.(fld).d = tmp.d; mouse.(fld).data = tmp.data; clear tmp;
        if ~isfield(mouse.(fld).d,'ref'); mouse.(fld).d.ref = -5; end
        freeAfter = true;
    end
    B = imp_build_session(mouse, fields, s, dataDir, CFG);
    if freeAfter; mouse.(fld) = rmfield(mouse.(fld),{'d','data'}); end
    if ~B.ok; fprintf('  %-22s SKIP (%s)\n', tg, B.msg); continue; end

    pre = B.pre; Fs = B.Fs; ref = B.ref;
    wr  = pre + round(1*Fs) + 1 : pre + round(CFG.resp_s*Fs);      % settled [+1,+3] s
    % BASELINE MUST MATCH PRODUCTION, NOT THE DISPLAY WINDOW. f4_cl_reject_lmm builds the session
    % with pre_s = 1, so its baseline is the 1 s immediately before onset. Drawing 3 s of context
    % would otherwise silently widen the baseline, shifting D, the leak term and every printed RR
    % (measured: AL_0048 CL 0.75 -> 1.04). Take the last 1 s of the wider pre-window instead.
    bwin = pre - round(1*Fs) + 1 : pre;

    % --- disturbance and RR, identical to f4_cl_reject_lmm.m ---------------------
    Gr_ol  = B.Gol - mean(B.Gol(:,bwin),2);
    gdipOL = mean(mean(Gr_ol(:,wr),2));                   % session-mean OL dip = laser leak
    Gr_cl  = B.Gcl - mean(B.Gcl(:,bwin),2);
    D_cl   = Gr_cl - gdipOL;   D_ol = Gr_ol - gdipOL;
    rr_cl  = sum((B.Acl(:,wr)-ref).^2,2) ./ sum(D_cl(:,wr).^2,2);
    rr_ol  = sum((B.Aol(:,wr)-ref).^2,2) ./ sum(D_ol(:,wr).^2,2);

    okO = isfinite(rr_ol) & rr_ol>0;  okC = isfinite(rr_cl) & rr_cl>0;
    pick = @(v,ok) arrayfun(@(p) nearest_ok(v, ok, prctile(v(ok),p)), PCT);
    iOL = pick(rr_ol, okO);  iCL = pick(rr_cl, okC);

    % standing-offset share, the quantity the exclusion rule uses (Methods)
    Aset = mean(mean(B.Acl(:,wr),2));
    biasFrac = (Aset-REF)^2 / mean(mean((B.Acl(:,wr)-ref).^2,2));
    excluded = biasFrac > 1/3;

    % ---------------------------- draw ------------------------------------------
    % Leak correction applies only while the laser is on; elsewhere D = baseline-referenced G.
    onMask = B.tt >= 0 & B.tt <= B.dur;
    Dt_ol = Gr_ol - gdipOL*onMask;   Dt_cl = Gr_cl - gdipOL*onMask;
    assert(isequal(Dt_cl(:,wr), D_cl(:,wr)) && isequal(Dt_ol(:,wr), D_ol(:,wr)));
    Eol = B.Aol - ref;  Ecl = B.Acl - ref;
    % ONE y-range for all six tiles, so a row of tiles is actually comparable.
    sel = [Eol(iOL,:); Dt_ol(iOL,:); Ecl(iCL,:); Dt_cl(iCL,:)];
    lo = min([sel(:); 0]); hi = max([sel(:); 0]); pad = 0.08*max(hi-lo, eps);
    ylc = [lo-pad, hi+pad];
    win = [1 CFG.resp_s];

    fig = jnFig(11.0, 5.2);
    tl  = tiledlayout(fig, 2, numel(PCT), 'TileSpacing','compact','Padding','tight');
    for c = 1:numel(PCT)
        tile(nexttile(tl,c), B.tt, Eol(iOL(c),:), Dt_ol(iOL(c),:), PS.col_ol, B.dur, win, ...
            sprintf('RR %.2f', rr_ol(iOL(c))), c==1, PS, ylc, tern(c==1,'open loop',''));
        tile(nexttile(tl,numel(PCT)+c), B.tt, Ecl(iCL(c),:), Dt_cl(iCL(c),:), PS.col_cl, B.dur, win, ...
            sprintf('RR %.2f', rr_cl(iCL(c))), c==1, PS, ylc, tern(c==1,'closed loop',''));
    end
    xlabel(tl,'time from laser onset (s)','FontSize',PS.fs,'FontWeight','bold');
    ylabel(tl,'A-r and D (%\DeltaF/F)','FontSize',PS.fs,'FontWeight','bold');
    title(tl, sprintf('%s%s', strrep(tg,'_','\_'), tern(excluded,' -- excluded','')), ...
        'FontSize',PS.fs,'FontWeight','bold');

    fn = fullfile(outdir, sprintf('s4_reject_trials_%s.pdf', tg));
    try
        paperExport(fig, fn);
        paperExport(fig, strrep(fn,'.pdf','.png'));
    catch ME, warning('[S4] export skip %s (%s)', tg, ME.message); end
    close(fig);

    RT(end+1) = struct('tag',tg,'medRR_ol',median(rr_ol(okO)),'medRR_cl',median(rr_cl(okC)), ...
        'gdip',gdipOL,'R2te',B.R2_te,'excluded',excluded); %#ok<AGROW>
    fprintf('  %-22s med RR  OL %.2f  CL %.2f | leak %.2f %%dF/F | R2te %.2f | offset %.0f%%%s\n', ...
        tg, median(rr_ol(okO)), median(rr_cl(okC)), gdipOL, B.R2_te, 100*biasFrac, ...
        tern(excluded,'  EXCLUDED',''));
end
fprintf('[S4] panels -> %s\n', outdir);
end

% ---------------------------------- helpers ------------------------------------
function i = nearest_ok(v, ok, target)
v(~ok) = NaN;  [~,i] = min(abs(v - target));
end

function tile(ax, tt, E, D, cA, dur, win, ttl, showY, PS, yl, rowlab)
hold(ax,'on');
% RR window shaded; laser-on period marked by a bar along the top edge.
patch(ax, win([1 2 2 1]), yl([1 1 2 2]), [0.90 0.90 0.90], 'EdgeColor','none');
plot(ax, [0 dur], yl([2 2]) - 0.01*diff(yl), '-', 'Color',[0.55 0.70 1.00], 'LineWidth',2.0);
yline(ax, 0, '--', 'Color',[0.25 0.25 0.25], 'LineWidth',PS.lw_ref);
lite = @(c) c + 0.65*(1-c);                       % tint toward white for out-of-window context
cD = [0.35 0.35 0.35];
in = tt >= win(1) & tt <= win(2);
Do = D; Do(in & [in(2:end) false] & [false in(1:end-1)]) = NaN;   % keep window edges so lines join
Eo = E; Eo(isnan(Do)) = NaN;
Di = D; Di(~in) = NaN;  Ei = E; Ei(~in) = NaN;
plot(ax, tt, Do, '-', 'Color',lite(cD), 'LineWidth',0.6);
plot(ax, tt, Eo, '-', 'Color',lite(cA), 'LineWidth',0.8);
plot(ax, tt, Di, '-', 'Color',cD, 'LineWidth',0.8);
plot(ax, tt, Ei, '-', 'Color',cA, 'LineWidth',1.2);
ylim(ax, yl); xlim(ax, [tt(1) tt(end)]);
title(ax, ttl, 'FontSize',PS.fs, 'FontWeight','bold');
set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw,'Layer','top');
jnAxes(ax);
if ~showY; set(ax,'YTickLabel',[]); end
if ~isempty(rowlab)
    text(ax, tt(1)+0.15, yl(2)-0.08*diff(yl), rowlab, 'Color',cA, 'FontSize',PS.fs, ...
        'FontWeight','bold', 'VerticalAlignment','top');
end
end

function s = tern(c,a,b), if c, s=a; else, s=b; end, end
