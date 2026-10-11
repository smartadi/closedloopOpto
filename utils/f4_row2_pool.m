function [POOL, meta] = f4_row2_pool(mouse, fields, motstat, statewin, withG)
% F4_ROW2_POOL  Canonical Fig-4 Row-2 state/outcome builder.
% SINGLE SOURCE shared by f4_row2_stats.m (forest, f4_2S_stats) and
% f4_row2_quartiles.m (panels f4_2A/2B/2C) so the two never drift.
%
%   [POOL, meta] = f4_row2_pool(mouse, fields, motstat, statewin, withG)
%
% motstat selects the motion statistic: 'mean' (DEFAULT, primary) or 'sq' (secondary).
%   'mean' -> mean of the z-scored motion energy over the window
%   'sq'   -> mean of its square
%
% Outcome  y = disturbance-rejection RMSE ||dFk-ref|| over [+1,+3] s (settled), RAW per trial.
% States (RAW per trial), on the OL (nc) and CL (wc) buffers, both conditions:
%   initdev = |dFk(onset) - ref|
%   motion  = MEAN z-motion over the -2..+3 s window (PLAIN mean; see motstat)  [user 2026-10-02]
%   delta   = cl_reldelta rel 2-4 Hz over -2 s -> stim end
%   absdelta = log10 abs 1-4 Hz power, same window
% withG (default false; 2026-10-10): ALSO build Gdelta / Gabsdelta = the same two band-power
%   states computed on the stim-blind contra-predicted Global G (f4_gstate_build.m caches,
%   controller-analysis/data/f4_gstate_<tag>.mat, G aligned to the readout onset) instead of
%   the controlled readout. Sessions without a cache (no ridge model: m1, m13) get NaN and drop.
% A session/state contributes only if it has >= 8 finite trials in EACH condition.
%
% POOL.<state> = table with variables:
%   y     (double)  raw rejection RMSE
%   cond  (categorical OL/CL)
%   x     (double)  raw state value
%   sess  (double)  session index k
%   mouse (string)  mouse name
% meta holds the constants used, for callers that need them.
if nargin < 3 || isempty(motstat), motstat = 'mean'; end
% statewin: 'peri' (DEFAULT, published -2..+3 s) | 'pre2' | 'pre1' -- see f4_state_window.m
if nargin < 4 || isempty(statewin), statewin = 'peri'; end
if nargin < 5 || isempty(withG), withG = false; end
gDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'controller-analysis','data');
W = f4_state_window(statewin);
motstat = validatestring(lower(motstat), {'mean','sq'}, mfilename, 'motstat');
Fs=35; ref=-5; c0=36; c1=71; c2=141; dur=3; c0_mot=71; c0_l=106; c0_p=351;
relopts=struct('pre',2,'post',3,'rel_idx',W.spec,'bandpow',W.bandpow);   % window from f4_state_window (default = legacy -2..+3 s)
states={'initdev','motion','delta','absdelta'};   % absdelta = log10 abs 1-4 Hz power (same window as rel)
if withG, states=[states {'Gdelta','Gabsdelta'}]; end
POOL=struct(); for s=states, POOL.(s{1})=table(); end
adlog=@(v) reshape(log10(max(double(v(:)),eps)),[],1);

for k=1:numel(fields)
    M=mouse.(fields{k}); if ~isfield(M,'data'); continue; end; d=M.data;
    if ~isfield(d,'ncDfk')||isempty(d.ncDfk)||~isfield(d,'wcDfk')||isempty(d.wcDfk); continue; end
    yOL=sqrt(mean((d.ncDfk(:,c1:c2)-ref).^2,2));
    yCL=sqrt(mean((d.wcDfk(:,c1:c2)-ref).^2,2));

    S=struct();
    S.initdev={abs(d.ncDfk(:,c0)-ref), abs(d.wcDfk(:,c0)-ref)};
    hasM = isfield(M,'has_motion')&&M.has_motion&&isfield(d,'ncmotion')&&any(d.ncmotion(:))&&isfield(d,'wcmotion');
    if hasM
        mcO = c0_mot + W.mot;  mcO = mcO(mcO>=1 & mcO<=size(d.ncmotion,2));   % 'peri' == legacy 1:175
        mcC = c0_mot + W.mot;  mcC = mcC(mcC>=1 & mcC<=size(d.wcmotion,2));
        % PRIMARY = mean(z); 'sq' = mean(z^2), the secondary. The 2026-10-01 switch to
        % the mean square is RETRACTED -- see utils/f4_motion_stat.m for why mean(z) is
        % the monotone statistic, and why both callers must share one function.
        S.motion = f4_motion_stat(d.ncmotion(:,mcO), d.wcmotion(:,mcC), motstat);
    else, S.motion={nan(numel(yOL),1),nan(numel(yCL),1)}; end
    if isfield(d,'pncDfk_l')&&~isempty(d.pncDfk_l)&&isfield(d,'pwcDfk_l')&&~isempty(d.pwcDfk_l)
        [rO,cO]=cl_reldelta(d.pncDfk_l,c0_l,Fs,relopts); [rC,cC]=cl_reldelta(d.pwcDfk_l,c0_l,Fs,relopts);
    elseif isfield(d,'pncDfk')&&~isempty(d.pncDfk)&&isfield(d,'pwcDfk')&&~isempty(d.pwcDfk)
        [rO,cO]=cl_reldelta(d.pncDfk,c0_p,Fs,relopts); [rC,cC]=cl_reldelta(d.pwcDfk,c0_p,Fs,relopts);
    else, rO=nan(numel(yOL),1); rC=nan(numel(yCL),1); cO.delta=rO; cC.delta=rC; end
    S.delta={rO,rC};
    S.absdelta={adlog(cO.delta), adlog(cC.delta)};   % same window as rel (W.spec), abs 1-4 Hz power (log10)
    if withG   % same estimator + window on the Global G (onset column 71 of GncA/GwcA, rel -70:104)
        gf=fullfile(gDir,sprintf('f4_gstate_%s_%s%s_e%d.mat',M.mn,M.td(6:7),M.td(9:10),M.en));
        if exist(gf,'file')
            Gc=load(gf,'GncA','GwcA');
            assert(size(Gc.GncA,1)==numel(yOL) && size(Gc.GwcA,1)==numel(yCL), 'f4_row2_pool:Grows');
            % one NaN pad column: cl_reldelta's legacy [-pre,+post] range check reaches col 176
            % (warning only; rel_idx = W.spec selects cols 1:175 for 'peri')
            pad=@(X)[X nan(size(X,1),1)];
            [gO,gcO]=cl_reldelta(pad(Gc.GncA),71,Fs,relopts); [gC,gcC]=cl_reldelta(pad(Gc.GwcA),71,Fs,relopts);
            S.Gdelta={gO,gC}; S.Gabsdelta={adlog(gcO.delta), adlog(gcC.delta)};
        else
            S.Gdelta={nan(numel(yOL),1),nan(numel(yCL),1)}; S.Gabsdelta=S.Gdelta;
        end
    end

    for s=states, nm=s{1};
        xO=S.(nm){1}; xC=S.(nm){2};
        if all(isnan(xO))||all(isnan(xC)); continue; end
        okO=isfinite(yOL)&isfinite(xO); okC=isfinite(yCL)&isfinite(xC);
        if nnz(okO)<8||nnz(okC)<8; continue; end
        t=table([yOL(okO);yCL(okC)], ...
                categorical([zeros(nnz(okO),1);ones(nnz(okC),1)],[0 1],{'OL','CL'}), ...
                [xO(okO);xC(okC)], ...
                repmat(k,nnz(okO)+nnz(okC),1), ...
                repmat(string(M.mn),nnz(okO)+nnz(okC),1), ...
                'VariableNames',{'y','cond','x','sess','mouse'});
        POOL.(nm)=[POOL.(nm); t];
    end
end
meta=struct('Fs',Fs,'ref',ref,'c0',c0,'c1',c1,'c2',c2,'dur',dur, ...
            'motstat',motstat,'statewin',W.name,'statewin_label',W.label,'states',{states});
end
