function S = f2_state(F2, opt)
%F2_STATE  Fig-2 stream, STAGE 5: does the LOCAL (residual) stim effect depend on brain state?
%
% THE TEST.  partialcorr( DV_zWithinAmp , state | dev_pre[, dev_post] )   [Spearman]
% The DV is z-scored WITHIN amplitude, so the dose-response mean (the trial-averaged Local dip) is
% removed and only trial-to-trial spread around it is tested. dev_pre is the pre-onset residual
% energy = that trial's prediction quality with NO stim; partialling it out means a surviving
% effect is state-dependence of the STIM RESPONSE, not of the baseline fit. dev_post (settled tail)
% is a second stim-free probe guarding against within-trial non-stationarity across the onset.
%
% STATES. Only two are interpretable, and this file says so in the output rather than in a comment:
%   MOTION          power-independent  -> ADMISSIBLE
%   RELATIVE delta  (1-4 Hz / 0.5-30 Hz), power-independent -> ADMISSIBLE
%   pre-var, ABSOLUTE delta            -> POWER CONFOUNDS. Retracted 2026-07-01 (both are ~signal
%                                         power, entangled with the DV magnitude). Computed and
%                                         printed for completeness, never interpreted.
% Also note RESEARCH 2026-07-02: relative-delta did NOT replicate on Ye/Zhiwen AB_0004 (opposite
% sign). Do not rest a paper claim on it without that caveat.
%
% DVs. L1DEV (unsigned |r - amp-mean| = per-trial UNPREDICTABILITY) is PRIMARY, per the 2026-07-01
% A2 result: at the true laser focus the SIGNED effect collapses while L1 survives. The signed dip
% (DVz) is reported as secondary.
%
% NEGATIVE CONTROL. The identical test is run on the GLOBAL component's per-trial dip. Global is the
% ongoing network activity, which SHOULD track state -- so a Local effect that looks just like the
% Global one is not a local finding, it is leakage. This is the control that tells the two apart.
%
% INPUT   F2   struct array, one element per session, with fields .label .caveat .D (from f2_decomp)
%         opt  .plot(true) .verbose(true) .dv('L1DEVz'|'DVz'|'GAINz')
% OUTPUT  S    .per [nSess x nState] table struct | .pooled Stouffer combination | .fig
% -------------------------------------------------------------------------------------------------
if nargin < 2, opt = struct(); end
if ~isfield(opt,'plot')    || isempty(opt.plot),    opt.plot    = true; end
if ~isfield(opt,'verbose') || isempty(opt.verbose), opt.verbose = true; end
if ~isfield(opt,'dv')      || isempty(opt.dv),      opt.dv      = 'L1DEVz'; end
vb = opt.verbose;  nS = numel(F2);

STATES = { 'Motion',        'MOT', true , 'power-indep  ADMISSIBLE'
           'Rel-\delta',    'DPr', true , 'power-indep  ADMISSIBLE'
           'Pre-var',       'PVv', false, 'POWER CONFOUND -- not interpreted'
           'Abs-\delta',    'DPa', false, 'POWER CONFOUND -- not interpreted' };
nSt = size(STATES,1);
zf = @(x)(x - mean(x,'omitnan'))./max(std(x,'omitnan'), eps);

rhoL = nan(nS,nSt);  pL = nan(nS,nSt);  nOK = nan(nS,nSt);      % LOCAL residual (the finding)
rhoG = nan(nS,nSt);  pG = nan(nS,nSt);                          % GLOBAL component (the control)
rho2 = nan(nS,nSt);                                             % LOCAL, partialling pre AND post
lab  = cell(nS,1);   cav = false(nS,1);
DVall = cell(nS,1);  STall = cell(nS,nSt);

for s = 1:nS
    D = F2(s).D;  ST = D.ST;  lab{s} = F2(s).label;  cav(s) = ~isempty(F2(s).caveat);
    if isempty(ST) || isempty(ST.LD), continue; end
    dv = ST.(opt.dv);                                            % already z-scored WITHIN amp
    % GLOBAL per-trial dip, z-scored within amp the same way -> a like-for-like control DV.
    gd = local_globaldip(ST, D.dcc);
    ctrl1 = zf(ST.PRE);
    ctrl2 = [zf(ST.PRE), zf(ST.POST)];
    DVall{s} = dv;
    for k = 1:nSt
        st = zf(ST.(STATES{k,2}));
        STall{s,k} = st;
        ok = isfinite(dv) & isfinite(st) & isfinite(ctrl1);
        nOK(s,k) = nnz(ok);
        if nnz(ok) < 12, continue; end
        [rhoL(s,k), pL(s,k)] = partialcorr(dv(ok), st(ok), ctrl1(ok), 'type','Spearman','rows','complete');
        ok2 = ok & all(isfinite(ctrl2),2);
        if nnz(ok2) >= 12
            rho2(s,k) = partialcorr(dv(ok2), st(ok2), ctrl2(ok2,:), 'type','Spearman','rows','complete');
        end
        okg = isfinite(gd) & isfinite(st) & isfinite(ctrl1);
        if nnz(okg) >= 12
            [rhoG(s,k), pG(s,k)] = partialcorr(gd(okg), st(okg), ctrl1(okg), 'type','Spearman','rows','complete');
        end
    end
end

%% ---- pooled: Stouffer over per-session Fisher-z, weighted by sqrt(n-4) -------------------------
% Stouffer, not a pooled correlation over concatenated trials: concatenating would let one long
% session dominate and would treat between-session offsets as within-session variance.
pooled = struct('z',nan(1,nSt), 'p',nan(1,nSt), 'rho_med',nan(1,nSt), ...
                'zG',nan(1,nSt), 'pG',nan(1,nSt));
pooled.state = STATES(:,1).';
for k = 1:nSt
    [pooled.z(k), pooled.p(k)] = local_stouffer(rhoL(:,k), nOK(:,k));
    [pooled.zG(k), pooled.pG(k)] = local_stouffer(rhoG(:,k), nOK(:,k));
    pooled.rho_med(k) = median(rhoL(:,k),'omitnan');
end

%% ---- report ------------------------------------------------------------------------------------
if vb
    fprintf('\n[F2-STATE] DV = %s (z within amp) | partial on dev_pre | Spearman\n', opt.dv);
    for k = 1:nSt
        fprintf('\n  --- %-12s  [%s] ---\n', STATES{k,1}, STATES{k,4});
        fprintf('     %-32s %5s %9s %9s %9s %9s\n','session','n','rho LOCAL','p','rho(+post)','rho GLOBAL');
        for s = 1:nS
            fprintf('     %-32s %5d %9.3f %9.3g %9.3f %9.3f%s\n', lab{s}, nOK(s,k), ...
                    rhoL(s,k), pL(s,k), rho2(s,k), rhoG(s,k), local_tern(cav(s),'  (caveat)',''));
        end
        fprintf('     %-32s %5s %9.3f %9.3g %9s %9.3f\n','POOLED (Stouffer z / p)','', ...
                pooled.rho_med(k), pooled.p(k), '', median(rhoG(:,k),'omitnan'));
        if ~STATES{k,3}
            fprintf(2,'     ** power confound -- reported for completeness, NOT a state-dependence claim **\n');
        elseif isfinite(pooled.p(k)) && pooled.p(k) < 0.05 && ...
               isfinite(pooled.pG(k)) && pooled.pG(k) < 0.05 && ...
               sign(pooled.z(k)) == sign(pooled.zG(k))
            fprintf(2,['     ** LOCAL and GLOBAL move the SAME way and both are significant: this is not a\n' ...
                       '        local effect, it is state-dependence leaking through the predictor. **\n']);
        end
    end
    if any(cav)
        fprintf(2,'\n  (caveat) sessions carry a readout-location caveat -- see F2(s).caveat before pooling.\n');
    end
end

%% ---- one figure: admissible states only, sessions overlaid --------------------------------------
fig = [];
if opt.plot
    kShow = find([STATES{:,3}]);                                  % Motion + Rel-delta
    fig = figure('Color','w','Name','[F2-STATE] residual stim effect vs brain state — CLICK a point', ...
                 'Position',[80 80 520*numel(kShow) 440]);
    cols = lines(nS);
    axList = gobjects(numel(kShow),1);
    for q = 1:numel(kShow)
        k = kShow(q);  ax = subplot(1,numel(kShow),q);  hold(ax,'on');  box(ax,'on');
        axList(q) = ax;
        for s = 1:nS
            if isempty(DVall{s}) || isempty(STall{s,k}), continue; end
            scatter(ax, STall{s,k}, DVall{s}, 9, cols(s,:), 'filled', 'MarkerFaceAlpha',0.35, ...
                    'DisplayName', sprintf('%s  \\rho=%.2f', lab{s}, rhoL(s,k)));
        end
        yline(ax,0,'k:','HandleVisibility','off');  xline(ax,0,'k:','HandleVisibility','off');
        xlabel(ax, sprintf('%s (z)', STATES{k,1}));
        ylabel(ax, sprintf('%s  (z within amp)', strrep(opt.dv,'z','')));
        title(ax, sprintf('%s   pooled Stouffer p = %.3g   (median \\rho %.2f)\nGLOBAL control: median \\rho %.2f', ...
              STATES{k,1}, pooled.p(k), pooled.rho_med(k), median(rhoG(:,k),'omitnan')), ...
              'FontSize',9,'FontWeight','bold');
        legend(ax,'Location','best','FontSize',6,'Box','off');
    end
    sgtitle(sprintf(['LOCAL stim effect (residual, DV = %s) vs brain state — partial on pre-onset prediction ' ...
                     'error\nGLOBAL control in the titles: if it matches, the effect is not local' ...
                     '\nCLICK any point to open that trial'], opt.dv), 'FontWeight','bold','FontSize',10);

    % ---- arm the clickable trial investigator (utils/f2_inspector.m) ---------------------------
    % A point in this scatter is two reduced numbers; the investigator re-opens the trial behind it
    % so an outlier can be diagnosed as a real response, a failed prediction, or a state scalar
    % built from a single motion spike. Sessions with no usable ST are skipped rather than indexed.
    keep = find(~cellfun(@isempty, DVall(:).'));
    if ~isempty(keep)
        SS = struct('label',{},'D',{},'dv',{},'state',{});
        for s = keep
            SS(end+1).label = lab{s};        %#ok<AGROW>
            SS(end).D     = F2(s).D;
            SS(end).dv    = DVall{s};
            SS(end).state = STall(s,:);
        end
        % Fields assigned one at a time, NOT via struct(...): struct() distributes cell and
        % struct-array values into a struct ARRAY, so struct('sess',SS) would have produced one
        % IX per session with a scalar .sess each -- and the click handler would have indexed junk.
        IX = struct();
        IX.sess       = SS;
        IX.axes       = axList;
        IX.stateIdx   = kShow(:);
        IX.stateNames = STATES(:,1).';
        IX.dv         = opt.dv;
        f2_inspector(fig, IX);
    end
end

S = struct('dv',opt.dv, 'rhoLocal',rhoL, 'pLocal',pL, 'rhoLocal_prepost',rho2, ...
           'rhoGlobal',rhoG, 'pGlobal',pG, 'n',nOK, 'pooled',pooled, 'fig',fig);
S.states = STATES;      % assigned after struct() so the 4x4 cell is a FIELD, not a struct array
S.labels = lab;
end

% -------------------------------------------------------------------------------------------------
function gd = local_globaldip(ST, dcc)
% Per-trial GLOBAL dip, z-scored WITHIN amp -- the like-for-like control DV for the Local one.
gd = [];
for ai = 1:numel(ST.trG)
    G = ST.trG{ai};  if isempty(G), continue; end
    dc = dcc{ai};    if isempty(dc), dc = 1:size(G,1); end
    v = mean(G(dc,:), 1).';
    gd = [gd; (v - mean(v,'omitnan'))./max(std(v,'omitnan'),eps)];   %#ok<AGROW>
end
end

function [z, p] = local_stouffer(rho, n)
% Stouffer over per-session Fisher-z statistics.
%   z_i = atanh(rho_i) * sqrt(n_i - 4)      (n-3 for Fisher's z, one more df for the partialled covariate)
%   Z   = sum(z_i) / sqrt(k)
% Sessions combine with EQUAL weight; the per-session n already enters through z_i. Combining this
% way rather than pooling concatenated trials stops one long session from dominating and stops
% between-session offsets being counted as within-session variance.
ok = isfinite(rho) & isfinite(n) & n > 6;
if ~any(ok), z = NaN; p = NaN; return; end
zi = atanh(max(min(rho(ok),1-1e-12),-1+1e-12)) .* sqrt(max(n(ok)-4,1));
z  = sum(zi)/sqrt(numel(zi));
p  = 2*(1 - normcdf(abs(z)));
end

function s = local_tern(c,a,b)
if c, s = a; else, s = b; end
end
