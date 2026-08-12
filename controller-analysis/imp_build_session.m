function S = imp_build_session(mouse, fields, selField, dataDir, cfg)
% IMP_BUILD_SESSION  Load Stage-1/2 caches + SVD, rebuild the canonical Actual
% (A = data.dFk, the scale ref=-5 lives in) and the stim-blind Global (G = Stage-2
% contra->ipsi prediction), and deal per-trial matrices for OL and CL.
%
% Shared "front end" for BOTH streams so trial construction is defined once:
%   Stream 1: internal_model_principle.m (single session, rich analysis)
%   Stream 2: imp_reject_across_sessions.m (batch, headline stat only)
%
% cfg fields: .nSV_load .Fs .pre_s .resp_s
% Returns S with .ok=true and Aol/Gol/Acl/Gcl [ntrial x nRel], nOL/nCL, pre, Fs,
% dur, ref, tt, R2_te, sess_tag, mn/td/en/selField. On any missing/incompatible
% prerequisite S.ok=false and S.msg says why (batch skips + logs, never crashes).

fld = fields{selField};
d_s = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn;  td = mouse.(fld).td;  en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
S = struct('sess_tag',sess_tag,'ok',false,'msg','','selField',selField,'mn',mn,'td',td,'en',en);

% Stage-2 cache is suffixed by predictor mode (utils/ctrl_pred_tag.m) so 'rank' and 'ridge'
% never mix: a ridge Global scored against a rank decomposition compares nothing.
[pred_suffix, pred_mode] = ctrl_pred_tag();
f1 = fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag));
f2 = fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind%s_%s.mat', pred_suffix, sess_tag));
if ~exist(f1,'file') || ~exist(f2,'file')
    S.msg = sprintf('missing Stage-1/2 cache (pred mode ''%s'')', pred_mode); return;
end
S1 = load(f1);  S2 = load(f2);
S.pred_mode = pred_mode;
if isfield(S2,'target_mode') && ~strcmp(S2.target_mode,'canonical')
    S.msg = sprintf('S2 target_mode=''%s'' (need canonical)', S2.target_mode); return;
end
if ~all(isfield(S1,{'gridIdx','px_prim','py_prim','k_prim','horizon','trial_dur'})) || ...
   ~all(isfield(S2,{'b','mu','sd','muY','Su'}))
    S.msg = 'cache missing required fields'; return;
end
if ~isfield(data,'dFk') || isempty(data.dFk); S.msg = 'no data.dFk'; return; end
if ~all(isfield(data,{'nc','wc'})) || isempty(data.nc) || isempty(data.wc)
    S.msg = 'missing OL(nc)/CL(wc) trial index'; return;
end

gridIdx=S1.gridIdx; px_prim=S1.px_prim; py_prim=S1.py_prim; k_prim=S1.k_prim;
dur=S1.trial_dur;
b=S2.b; mu=S2.mu; sd=S2.sd; muY=S2.muY; Su=S2.Su;

[U_cp,V_cp,t_svd,mimg_cp] = cp_loadUVt(expPath(mn,td,en), cfg.nSV_load, d_s.timeBlue);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); nF=min(size(V_cp,2),numel(t_full));
Xg   = double(Uflat(gridIdx,:))*V_cp;
Gall = muY + (((Xg(Su,:)-mu)./sd).')*b;                     % stim-blind Global, all frames

Fs=cfg.Fs; pre=round(cfg.pre_s*Fs); post=round(dur*Fs); rel=-pre:post;
dfk = data.dFk(:);
% data.dFk can trail the SVD by a frame or two (different readers of the same acquisition);
% clamp for a rounding-scale shortfall, skip only for a real mismatch.
if numel(dfk) < nF
    if nF - numel(dfk) > 10
        S.msg = sprintf('data.dFk %d frames shorter than SVD (%d)', nF-numel(dfk), nF); return;
    end
    nF = numel(dfk);
end
grab = @(ons) deal_trials(ons, t_full, dfk, Gall, rel, pre, post, nF);
[Aol,Gol,nOL] = grab(sort(d_s.stimStarts(data.nc(:))));
[Acl,Gcl,nCL] = grab(sort(d_s.stimStarts(data.wc(:))));
if nOL<3 || nCL<3; S.msg = sprintf('too few trials (OL %d, CL %d)', nOL, nCL); return; end

if isfield(d_s,'ref') && ~isempty(d_s.ref); ref = d_s.ref; else; ref = -5; end
if isfield(S2,'R2_te'); R2_te = S2.R2_te; else; R2_te = NaN; end

S.ok=true; S.msg='ok';
S.Aol=Aol; S.Gol=Gol; S.Acl=Acl; S.Gcl=Gcl; S.nOL=nOL; S.nCL=nCL;
S.pre=pre; S.Fs=Fs; S.dur=dur; S.resp_s=cfg.resp_s; S.ref=ref; S.tt=rel/Fs; S.R2_te=R2_te;
S.t_full=t_full; S.nF=nF; S.post=post;   % so callers (imp_trial_states) can rebuild the SAME trial order
S.px_prim=px_prim; S.py_prim=py_prim; S.k_prim=k_prim;   % geometry (for optional coupling reuse)
end

% ---- local: extract per-trial A and G aligned to onsets (matches internal_model_principle) --
function [A,G,n] = deal_trials(starts, t_full, y_full, Gall, rel, pre, post, nF)
onF = zeros(numel(starts),1);
for j=1:numel(starts), [~,onF(j)] = min(abs(t_full-starts(j))); end
onF = onF(onF>pre & onF+post<=nF);  n = numel(onF);
A = zeros(n,numel(rel)); G = zeros(n,numel(rel));
for j=1:n, A(j,:) = y_full(onF(j)+rel).'; G(j,:) = Gall(onF(j)+rel).'; end
end
