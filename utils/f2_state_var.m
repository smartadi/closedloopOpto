function SV = f2_state_var(F2, opt)
%F2_STATE_VAR  Does the VARIANCE of the local residual depend on brain state?
%
% COMPANION to f2_state, not a replacement. f2_state asks whether the residual's LEVEL tracks state
% (partial Spearman on a per-trial scalar). This asks whether its SPREAD does -- a state can leave
% the mean local effect untouched while making it more or less reproducible, and that is a different
% claim about the brain than "the effect gets bigger".
%
% TWO SENSES OF "VARIANCE", computed separately because they can disagree and mean different things:
%
%   (1) ACROSS-TRIAL  (PRIMARY).  Bin trials by state, then measure the spread of the per-trial
%       residual dip WITHIN each bin. Answers: "in this state, how reproducible is the local effect
%       from trial to trial?" Tested with Brown-Forsythe (a median-centred Levene, so it does not
%       assume normality) plus Spearman of bin-SD against bin index for a monotone trend.
%
%   (2) WITHIN-TRIAL  (SECONDARY).  Variance of each trial's residual trace across the dip window --
%       how ROUGH the residual is inside a single trial, rather than how much trials differ. Treated
%       as an ordinary per-trial DV and run through the same partial Spearman as f2_state.
%
% *** THE GLOBAL NEGATIVE CONTROL IS THE POINT ***  Every quantity is computed identically on the
% GLOBAL component. Global is ongoing network activity and SHOULD track state, so a Local variance
% effect that matches its Global partner is leakage through the predictor, not a local finding. The
% control is reported beside every number rather than left for the reader to run.
%
% *** dev_pre IS REGRESSED OUT FIRST ***  Trials differ in how well the predictor was doing BEFORE
% the stim arrived. Without removing that, "residual variance is higher in state X" can just mean
% "the fit is worse in state X", which is a statement about the model, not the stimulus. The DV is
% therefore the residual of a linear fit on z(PRE) before any spread is measured.
%
% STATES (same admissibility ledger as f2_state -- see RESEARCH 2026-07-01):
%   MOT, DPr (relative delta)  power-independent -> ADMISSIBLE
%   PVv, DPa                   POWER CONFOUNDS   -> computed, printed, never interpreted. These are
%                              near-tautological here: both ARE signal power, and the DV is a
%                              variance, so a positive result is expected and means nothing.
%
% INPUT   F2   struct array (one element per session) with .label .caveat .D  (from f2_decomp)
%         opt  .nbin(4) state bins | .plot(true) .verbose(true) .win('dip'|'resp')
% OUTPUT  SV   .per(s) per-session results | .states .labels .fig
% -------------------------------------------------------------------------------------------------
if nargin < 2, opt = struct(); end
def = struct('nbin',4, 'plot',true, 'verbose',true, 'win','dip');
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opt,fn{i}) || isempty(opt.(fn{i})), opt.(fn{i}) = def.(fn{i}); end
end
vb = opt.verbose;  nS = numel(F2);  nb = opt.nbin;

STATES = { 'Motion',     'MOT', true
           'Rel-\delta', 'DPr', true
           'Pre-var',    'PVv', false
           'Abs-\delta', 'DPa', false };
nSt = size(STATES,1);

SV = struct('states',{STATES}, 'labels',{cell(nS,1)}, 'fig',[], 'nbin',nb);
SV.per = struct('label',{},'caveat',{},'binSD_L',{},'binSD_G',{},'bfp_L',{},'bfp_G',{}, ...
                'trend_L',{},'trend_G',{},'rhoW_L',{},'pW_L',{},'rhoW_G',{},'n',{});

for s = 1:nS
    D = F2(s).D;  ST = D.ST;
    SV.labels{s} = F2(s).label;
    R = struct('label',F2(s).label, 'caveat',F2(s).caveat, ...
               'binSD_L',nan(nSt,nb), 'binSD_G',nan(nSt,nb), 'bfp_L',nan(1,nSt), 'bfp_G',nan(1,nSt), ...
               'trend_L',nan(1,nSt), 'trend_G',nan(1,nSt), ...
               'rhoW_L',nan(1,nSt), 'pW_L',nan(1,nSt), 'rhoW_G',nan(1,nSt), 'n',nan(1,nSt));
    if isempty(ST) || isempty(ST.LD), SV.per(s) = R; continue; end

    ampi = ST.AMPi;
    % ---- per-trial scalars, z-scored WITHIN amplitude (removes the dose-response mean) ----------
    ldL = local_zwithin(ST.LD, ampi);                      % local dip, per trial
    gdT = local_traceDip(ST.trG, D.dcc, ampi);             % global dip, per trial (the CONTROL)
    ldG = local_zwithin(gdT, ampi);
    % within-trial roughness of each trial's trace
    wvL = local_zwithin(local_traceVar(ST.trL, D.dcc, opt.win, D.rel, D.preN), ampi);
    wvG = local_zwithin(local_traceVar(ST.trG, D.dcc, opt.win, D.rel, D.preN), ampi);

    pre = local_z(ST.PRE);
    % dev_pre removed BEFORE any spread is measured -- see header
    ldL = local_deflate(ldL, pre);   ldG = local_deflate(ldG, pre);
    wvL = local_deflate(wvL, pre);   wvG = local_deflate(wvG, pre);

    for k = 1:nSt
        st = local_z(ST.(STATES{k,2}));
        ok = isfinite(ldL) & isfinite(st) & isfinite(pre);
        R.n(k) = nnz(ok);
        if nnz(ok) < 4*nb, continue; end

        % ---- (1) ACROSS-TRIAL spread by state bin --------------------------------------------
        g = local_qbin(st(ok), nb);
        [R.binSD_L(k,:), R.bfp_L(k)] = local_spread(ldL(ok), g, nb);
        [R.binSD_G(k,:), R.bfp_G(k)] = local_spread(ldG(ok), g, nb);
        R.trend_L(k) = corr((1:nb).', R.binSD_L(k,:).', 'type','Spearman');
        R.trend_G(k) = corr((1:nb).', R.binSD_G(k,:).', 'type','Spearman');

        % ---- (2) WITHIN-TRIAL roughness as an ordinary DV -------------------------------------
        okw = ok & isfinite(wvL);
        if nnz(okw) >= 12
            [R.rhoW_L(k), R.pW_L(k)] = corr(wvL(okw), st(okw), 'type','Spearman');
            R.rhoW_G(k) = corr(wvG(okw), st(okw), 'type','Spearman');
        end
    end
    SV.per(s) = R;
end

%% ---- report -------------------------------------------------------------------------------------
if vb
    for s = 1:nS
        R = SV.per(s);
        fprintf('\n[F2-STATE-VAR] %s%s\n', R.label, local_tern(isempty(R.caveat),'',' (CAVEATED)'));
        fprintf('   DV = per-trial LOCAL dip, z within amp, dev_pre regressed out | %d state bins\n', nb);
        fprintf('   %-12s %6s | %-28s %8s %7s | %8s %7s | %s\n', ...
                'state','n','across-trial SD by bin (Local)','BF p','trend','BF p(G)','trend(G)','admissible');
        for k = 1:nSt
            if ~isfinite(R.bfp_L(k)), continue; end
            fprintf('   %-12s %6d | %-28s %8.4f %7.2f | %8.4f %7.2f | %s\n', ...
                strrep(STATES{k,1},'\delta','d'), R.n(k), ...
                strtrim(sprintf('%.2f ', R.binSD_L(k,:))), R.bfp_L(k), R.trend_L(k), ...
                R.bfp_G(k), R.trend_G(k), ...
                local_tern(STATES{k,3},'YES','POWER CONFOUND -- not interpreted'));
        end
        fprintf('   within-trial roughness (secondary): ');
        for k = 1:nSt
            if isfinite(R.rhoW_L(k))
                fprintf('%s rho=%+.3f(p=%.3g,G%+.3f)  ', strrep(STATES{k,1},'\delta','d'), ...
                        R.rhoW_L(k), R.pW_L(k), R.rhoW_G(k));
            end
        end
        fprintf('\n');
        for k = 1:2
            if isfinite(R.bfp_L(k)) && R.bfp_L(k) < 0.05 && R.bfp_G(k) < 0.05
                fprintf(2,'   ** %s: Local BF p=%.4f but GLOBAL control ALSO significant (p=%.4f)\n', ...
                    strrep(STATES{k,1},'\delta','d'), R.bfp_L(k), R.bfp_G(k));
                fprintf(2,'      -> variance effect is shared with Global = leakage, NOT a local finding **\n');
            end
        end
    end
end

%% ---- figure --------------------------------------------------------------------------------------
if ~opt.plot, return; end
SV.fig = figure('Color','w','Position',[50 50 380*nSt 640], ...
                'Name',sprintf('[F2-STATE-VAR] %s', strjoin(SV.labels,' | ')));
tl = tiledlayout(SV.fig, 2, nSt, 'Padding','compact','TileSpacing','compact');
CL = [0.80 0.15 0.15];  CG = [0.45 0.45 0.45];

for k = 1:nSt
    ax = nexttile(tl, k); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    for s = 1:nS
        R = SV.per(s);
        if ~isfinite(R.bfp_L(k)), continue; end
        plot(ax, 1:nb, R.binSD_L(k,:), '-o','Color',CL,'MarkerFaceColor',CL,'LineWidth',1.8, ...
             'MarkerSize',4.5,'DisplayName','LOCAL residual');
        plot(ax, 1:nb, R.binSD_G(k,:), '--s','Color',CG,'MarkerFaceColor',CG,'LineWidth',1.4, ...
             'MarkerSize',4,'DisplayName','GLOBAL (control)');
    end
    xlim(ax,[0.7 nb+0.3]); xticks(ax,1:nb);
    xlabel(ax,sprintf('%s bin (low \\rightarrow high)', STATES{k,1}));
    if k==1, ylabel(ax,'across-trial SD of residual dip'); legend(ax,'Location','best','Box','off','FontSize',7); end
    R = SV.per(1);
    ttl = sprintf('%s   BF p = %.4f  (G %.4f)', STATES{k,1}, R.bfp_L(k), R.bfp_G(k));
    if ~STATES{k,3}, ttl = sprintf('%s\nPOWER CONFOUND -- not interpreted', ttl); end
    title(ax, ttl, 'FontSize',9, 'Color', local_tern(STATES{k,3},[0 0 0],[0.55 0.55 0.55]));
end

for k = 1:nSt
    ax = nexttile(tl, nSt+k); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    R = SV.per(1);
    b = bar(ax, [R.rhoW_L(k) R.rhoW_G(k)], 0.6, 'FaceColor','flat');
    b.CData = [CL; CG];
    xticks(ax,[1 2]); xticklabels(ax,{'Local','Global'}); yline(ax,0,'k-');
    ylabel(ax,'\rho (within-trial roughness vs state)');
    ttl = sprintf('%s   p = %.3g', STATES{k,1}, R.pW_L(k));
    if ~STATES{k,3}, ttl = [ttl ' -- CONFOUND']; end %#ok<AGROW>
    title(ax, ttl, 'FontSize',9, 'Color', local_tern(STATES{k,3},[0 0 0],[0.55 0.55 0.55]));
end

sgtitle(SV.fig, sprintf(['VARIANCE of the local residual vs brain state  —  %s' ...
   '\ntop: across-trial spread by state bin (PRIMARY)   bottom: within-trial roughness (secondary)' ...
   '\ndev_pre regressed out first;  GREY = GLOBAL negative control — if it matches, the effect is not local'], ...
   strjoin(SV.labels,' | ')), 'FontWeight','bold','FontSize',10);
end

% =================================================================================================
function z = local_z(x)
x = double(x(:));
z = (x - mean(x,'omitnan')) ./ max(std(x,'omitnan'), eps);
end

function z = local_zwithin(x, ampi)
% z-score WITHIN amplitude: removes the dose-response mean AND the per-amp scale, so trials from
% different amplitudes can be pooled into one spread measurement without the dose curve dominating.
x = double(x(:));  z = nan(size(x));
for a = unique(ampi(:)).'
    m = ampi(:) == a;
    z(m) = (x(m) - mean(x(m),'omitnan')) ./ max(std(x(m),'omitnan'), eps);
end
end

function r = local_deflate(y, x)
% remove the linear part of y explained by x (dev_pre), keeping NaNs where they were
r = y;  ok = isfinite(y) & isfinite(x);
if nnz(ok) < 3, return; end
X = [ones(nnz(ok),1), x(ok)];
r(ok) = y(ok) - X*(X\y(ok));
end

function v = local_traceDip(tr, dcc, ampi)
% per-trial mean over that amplitude's dip window, concatenated in ST's row order
v = nan(numel(ampi),1);  o = 0;
for ai = 1:numel(tr)
    if isempty(tr{ai}), continue; end
    dc = dcc{ai};  n = size(tr{ai},2);
    v(o+(1:n)) = mean(tr{ai}(dc,:), 1).';
    o = o + n;
end
end

function v = local_traceVar(tr, dcc, win, rel, preN)
% per-trial VARIANCE of the trace across the chosen window (how rough this trial's residual is)
n_tot = 0;
for ai = 1:numel(tr), if ~isempty(tr{ai}), n_tot = n_tot + size(tr{ai},2); end, end
v = nan(n_tot,1);  o = 0;
for ai = 1:numel(tr)
    if isempty(tr{ai}), continue; end
    if strcmpi(win,'resp'), w = (preN+1):numel(rel); else, w = dcc{ai}; end
    n = size(tr{ai},2);
    v(o+(1:n)) = var(tr{ai}(w,:), 0, 1).';
    o = o + n;
end
end

function g = local_qbin(x, nb)
% equal-count bins by state quantile. Equal COUNT (not equal width) so every bin's SD is estimated
% from the same number of trials -- otherwise a sparse tail bin looks noisy purely from small n.
q = quantile(x, linspace(0,1,nb+1));
q(1) = -inf; q(end) = inf;
[~,~,g] = histcounts(x, q);
g = max(min(g, nb), 1);
end

function [sd, p] = local_spread(y, g, nb)
sd = nan(1,nb);
for b = 1:nb, sd(b) = std(y(g==b), 'omitnan'); end
p = NaN;
try
    p = vartestn(y, g, 'TestType','BrownForsythe', 'Display','off');
catch
end
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
