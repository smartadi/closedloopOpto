function T = ctrl_softblind_curve()
% CTRL_SOFTBLIND_CURVE  Per-session soft-blind tradeoff curves + verdicts.  [SOFTCURVE]
%
% One panel per cached session: the achievable (held-out leak, spont R^2) FRONTIER traced as the
% blinding penalty sweeps ridge (frac=1) -> deflate (frac=0). Marks the ridge end, the deployed
% op point (minleak within the R^2 floor budget), the R^2 floor (horizontal) and a leak target
% (vertical). This is the session-by-session read: does this session's curve enter the good box
% (R^2 >= floor AND held-out leak <= target)? how much R^2 does it cost to get there?
%
% Returns a table T (one row/session) and prints a verdict list:
%   WORKS     clears floor AND minleak <= LEAK_GOOD (0.25)
%   MARGINAL  clears floor but best leak in (0.25, 0.40], or needs to dip below floor to blind
%   LEAKY     clears floor but best-in-budget leak > 0.40  (Global not honestly separable)
%   NO-FLOOR  ridge R^2 < floor (predictor too weak, upstream of blinding)
%
% USAGE:  T = ctrl_softblind_curve;

here_c = fileparts(mfilename('fullpath'));
if isempty(here_c); here_c = fullfile(pwd,'controller-analysis'); end
dataDir_c = fullfile(here_c,'data');
FLOOR = ctrl_r2_floor();
LEAK_GOOD = 0.25;  LEAK_MARG = 0.40;

files_c = dir(fullfile(dataDir_c,'ctrl_ols_ol_stimblind_softblind_*.mat'));
assert(~isempty(files_c),'[SOFTCURVE] no _softblind caches -- run ctrl_softblind_batch.m first.');

S = struct('sess',{},'n',{},'ridgeR2',{},'fracs',{},'R2',{},'leakH',{}, ...
           'opR2',{},'opLeak',{},'opFrac',{},'verdict',{});
for i = 1:numel(files_c)
    D = load(fullfile(dataDir_c, files_c(i).name));
    if ~isfield(D,'RPATH') || ~isfield(D.RPATH,'SOFT'); continue; end
    P = D.RPATH.SOFT;
    r.sess = D.sess_tag;
    r.n = 0; if isfield(D,'onF'); r.n = numel(D.onF); end
    r.ridgeR2 = P.R2te_free;
    r.fracs = P.fracs(:).';  r.R2 = P.R2te(:).';  r.leakH = abs(P.leak_hold(:).');
    inb = r.R2 >= FLOOR;
    if any(inb)
        lh = r.leakH; lh(~inb) = inf; [r.opLeak, k] = min(lh);
        r.opR2 = r.R2(k); r.opFrac = r.fracs(k);
    else
        r.opLeak = NaN; r.opR2 = NaN; r.opFrac = NaN;
    end
    if r.ridgeR2 < FLOOR;                 r.verdict = 'NO-FLOOR';
    elseif r.opLeak <= LEAK_GOOD;         r.verdict = 'WORKS';
    elseif r.opLeak <= LEAK_MARG;         r.verdict = 'MARGINAL';
    else;                                 r.verdict = 'LEAKY';
    end
    S(end+1) = r; %#ok<AGROW>
end
[~,ord] = sort([S.ridgeR2],'descend'); S = S(ord);
nS = numel(S);

vcol = containers.Map({'WORKS','MARGINAL','LEAKY','NO-FLOOR'}, ...
    {[0.15 0.65 0.25],[0.90 0.65 0.10],[0.80 0.25 0.20],[0.60 0.60 0.62]});

nc = ceil(sqrt(nS)); nr = ceil(nS/nc);
fig = figure('Name','Soft-blind per-session curves','Color','w','Position',[80 60 1500 900]);
for i = 1:nS
    ax = subplot(nr,nc,i); hold(ax,'on');
    r = S(i); c = vcol(r.verdict);
    plot(ax, r.leakH, r.R2, '-', 'Color',[0.5 0.5 0.55],'LineWidth',1.0);
    plot(ax, r.leakH(1), r.R2(1), 'ks','MarkerFaceColor','w','MarkerSize',6);        % ridge end
    if ~isnan(r.opLeak)
        plot(ax, r.opLeak, r.opR2, 'o','MarkerFaceColor',c,'MarkerEdgeColor','k','MarkerSize',9);
    end
    yl = [min(0.66,min(r.R2)-0.02) max(0.96,max(r.R2)+0.02)];
    plot(ax,[0 1.2],[FLOOR FLOOR],'r--','LineWidth',0.9);                              % floor
    plot(ax,[LEAK_GOOD LEAK_GOOD],yl,'b--','LineWidth',0.8);                           % leak target
    xlim(ax,[0 1.05]); ylim(ax,yl);
    title(ax,sprintf('%s  [%s]', r.sess, r.verdict),'Interpreter','none','FontSize',8,'Color',c);
    if i> (nr-1)*nc; xlabel(ax,'held-out leak'); end
    if mod(i-1,nc)==0; ylabel(ax,'spont R^2'); end
    grid(ax,'on'); hold(ax,'off');
end
sgtitle(sprintf('Soft-blind per-session frontier  (floor %.2f, good-leak %.2f)   filled dot = op point,  square = ridge', ...
    FLOOR, LEAK_GOOD), 'Interpreter','none');

% ---- verdict table -----------------------------------------------------------
fprintf('\n== PER-SESSION SOFT-BLIND VERDICTS (floor %.2f) ==\n', FLOOR);
fprintf('%-22s %5s %8s %8s %8s %8s  %s\n','session','n','ridgeR2','opR2','opLeak','opFrac','verdict');
for i = 1:nS
    r = S(i);
    fprintf('%-22s %5d %8.3f %8.3f %8.2f %8.2f  %s\n', ...
        r.sess, r.n, r.ridgeR2, r.opR2, r.opLeak, r.opFrac, r.verdict);
end
nW = sum(strcmp({S.verdict},'WORKS'));
nM = sum(strcmp({S.verdict},'MARGINAL'));
nL = sum(strcmp({S.verdict},'LEAKY'));
nN = sum(strcmp({S.verdict},'NO-FLOOR'));
fprintf('  -> WORKS %d | MARGINAL %d | LEAKY %d | NO-FLOOR %d  (of %d cached)\n', nW,nM,nL,nN,nS);

T = struct2table(S);
end
