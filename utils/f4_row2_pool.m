function [POOL, meta] = f4_row2_pool(mouse, fields)
% F4_ROW2_POOL  Canonical Fig-4 Row-2 state/outcome builder.
% SINGLE SOURCE shared by f4_row2_stats.m (forest, f4_2S_stats) and
% f4_row2_quartiles.m (panels f4_2A/2B/2C) so the two never drift.
%
%   [POOL, meta] = f4_row2_pool(mouse, fields)
%
% Outcome  y = disturbance-rejection RMSE ||dFk-ref|| over [+1,+3] s (settled), RAW per trial.
% States (RAW per trial), on the OL (nc) and CL (wc) buffers, both conditions:
%   initdev = |dFk(onset) - ref|
%   motion  = MEAN z-motion over the -2..+3 s window (PLAIN mean, NO rectification)  [user 2026-09-11]
%   delta   = cl_reldelta rel 2-4 Hz over -2 s -> stim end
% A session/state contributes only if it has >= 8 finite trials in EACH condition.
%
% POOL.<state> = table with variables:
%   y     (double)  raw rejection RMSE
%   cond  (categorical OL/CL)
%   x     (double)  raw state value
%   sess  (double)  session index k
%   mouse (string)  mouse name
% meta holds the constants used, for callers that need them.
Fs=35; ref=-5; c0=36; c1=71; c2=141; dur=3; c0_mot=71; c0_l=106; c0_p=351;
relopts=struct('pre',2,'post',3);           % delta window -2 -> stim end (matches row 1)
states={'initdev','motion','delta'};
POOL=struct(); for s=states, POOL.(s{1})=table(); end

for k=1:numel(fields)
    M=mouse.(fields{k}); if ~isfield(M,'data'); continue; end; d=M.data;
    if ~isfield(d,'ncDfk')||isempty(d.ncDfk)||~isfield(d,'wcDfk')||isempty(d.wcDfk); continue; end
    yOL=sqrt(mean((d.ncDfk(:,c1:c2)-ref).^2,2));
    yCL=sqrt(mean((d.wcDfk(:,c1:c2)-ref).^2,2));

    S=struct();
    S.initdev={abs(d.ncDfk(:,c0)-ref), abs(d.wcDfk(:,c0)-ref)};
    hasM = isfield(M,'has_motion')&&M.has_motion&&isfield(d,'ncmotion')&&any(d.ncmotion(:))&&isfield(d,'wcmotion');
    if hasM
        wsO=max(1,c0_mot-round(2*Fs)); weO=min(size(d.ncmotion,2),c0_mot+round(dur*Fs)-1);
        wsC=max(1,c0_mot-round(2*Fs)); weC=min(size(d.wcmotion,2),c0_mot+round(dur*Fs)-1);
        S.motion={mean(d.ncmotion(:,wsO:weO),2), mean(d.wcmotion(:,wsC:weC),2)};   % PLAIN mean, no rectify
    else, S.motion={nan(numel(yOL),1),nan(numel(yCL),1)}; end
    if isfield(d,'pncDfk_l')&&~isempty(d.pncDfk_l)&&isfield(d,'pwcDfk_l')&&~isempty(d.pwcDfk_l)
        S.delta={cl_reldelta(d.pncDfk_l,c0_l,Fs,relopts), cl_reldelta(d.pwcDfk_l,c0_l,Fs,relopts)};
    elseif isfield(d,'pncDfk')&&~isempty(d.pncDfk)&&isfield(d,'pwcDfk')&&~isempty(d.pwcDfk)
        S.delta={cl_reldelta(d.pncDfk,c0_p,Fs,relopts), cl_reldelta(d.pwcDfk,c0_p,Fs,relopts)};
    else, S.delta={nan(numel(yOL),1),nan(numel(yCL),1)}; end

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
meta=struct('Fs',Fs,'ref',ref,'c0',c0,'c1',c1,'c2',c2,'dur',dur,'states',{states});
end
