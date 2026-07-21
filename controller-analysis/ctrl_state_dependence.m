% ctrl_state_dependence.m -- STAGE 5: state dependence of the OL vs CL residual.
%
% QUESTION (user, 2026-07-20)
%   Does the ongoing brain STATE predict the trial's outcome, and does closed-loop control
%   DECOUPLE that dependence? Two distinct sub-questions, both answerable from the Stage 2/3
%   per-trial decomposition (Actual = Global + Local):
%
%   Q1 (residual / gain modulation): does the laser's LOCAL effect depend on the ongoing state?
%       In OL the command is a fixed step, so any Local-vs-state slope is genuine state-dependent
%       actuator gain. In CL the command adapts, so the slope mixes gain and controller action.
%   Q2 (decoupling, the "K2 OL vs CL slope" open question): does the pre-stim state predict where
%       the signal ENDS UP? Steep OL slope + flat CL slope = the controller absorbing brain state.
%
% WHY THIS NEEDS ABSOLUTE TRACES
%   The Stage 2/3 caches store per-trial BASELINE-SUBTRACTED traces, which forces the pre-stim
%   level to 0 by construction -- unusable as a state regressor. So we rebuild absolute Actual and
%   Global here from the Stage 1/2 predictor and slice both OL and CL identically.
%
% MEASURES (per trial)
%   state:    s_lvl = mean ABSOLUTE Global over [-1,0]s      (ongoing level at onset)
%             s_var = var of ABSOLUTE Actual over [-1,0]s     (pre-stim fluctuation)
%             s_dst = mean baseline-sub Global over [0,dur]s  (state excursion during trial)
%   outcome:  o_loc = mean baseline-sub Local over [0,dur]s   (the laser's own effect)  <- residual
%             o_act = mean ABSOLUTE Actual over [1,dur]s      (where the signal landed)
%
% STATS  OLS slope + Pearson r + p per (state,outcome) pair, per condition; OL-vs-CL slope
%   difference tested by bootstrap over trials (nBoot resamples, percentile CI).
%   CAVEAT: single session, n=1 animal -- descriptive, not a population claim.
%
% PREREQS  Stage 1 + Stage 2 caches; `mouse`,`fields` in the workspace.
% SECTIONS: [CFG] [LOAD] [TRIALS] [MEASURES] [STATS] [FIG] [SAVE]

%% [CTRL-SD-CFG] ----------------------------------------------------------------
selField  = 4;
nSV_load  = 500;
Fs        = 35;
pre_s     = 1.0;         % per-trial baseline / pre-stim window [-1,0] s
ss_s      = 1.0;         % steady-state window starts here [ss_s, dur] s
nBoot     = 5000;
rng(7,'twister');

assert(exist('mouse','var') && exist('fields','var'), '[CTRL-SD] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [CTRL-SD-LOAD] ---------------------------------------------------------------
fld = fields{selField};
d_s = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
S1 = load(fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag)));
S2 = load(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', sess_tag)));
gridIdx=S1.gridIdx; px_prim=S1.px_prim; py_prim=S1.py_prim; k_prim=S1.k_prim;
horizon=S1.horizon; dur=S1.trial_dur;
b=S2.b; mu=S2.mu; sd=S2.sd; muY=S2.muY; Su=S2.Su;

[U_cp,V_cp,t_svd,mimg_cp] = loadUVt(expPath(mn,td,en), nSV_load);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); nF=min(size(V_cp,2),numel(t_full));
[y_full,ok] = local_svd_rolling_dfk(Uflat,V_cp,mimg_cp,px_prim,py_prim,k_prim,horizon,nY,nX);
assert(ok,'[CTRL-SD] target rebuild failed.');
Xg = double(Uflat(gridIdx,:))*V_cp;
Gall = muY + (((Xg(Su,:)-mu)./sd).')*b;                    % stim-blind Global, all frames

%% [CTRL-SD-TRIALS] extract ABSOLUTE per-trial A and G, both conditions ---------
pre=round(pre_s*Fs); post=round(dur*Fs); rel=-pre:post;
bwin=1:pre; twin=pre+1:pre+post; sswin=pre+round(ss_s*Fs)+1:pre+post;
grab = @(ons) deal_trials(ons, t_full, y_full, Gall, rel, pre, post, nF);
[Aol,Gol,nOL] = grab(sort(d_s.stimStarts(data.nc(:))));
[Acl,Gcl,nCL] = grab(sort(d_s.stimStarts(data.wc(:))));
fprintf('[CTRL-SD] %s | OL %d trials | CL %d trials\n', sess_tag, nOL, nCL);

%% [CTRL-SD-MEASURES] -----------------------------------------------------------
meas = @(A,G) struct( ...
    's_lvl', mean(G(:,bwin),2), ...                        % ongoing level at onset (absolute)
    's_var', var(A(:,bwin),0,2), ...                       % pre-stim fluctuation (absolute)
    's_dst', mean(G(:,twin)-mean(G(:,bwin),2),2), ...      % state excursion during trial (bs)
    'o_loc', mean((A(:,twin)-mean(A(:,bwin),2)) - (G(:,twin)-mean(G(:,bwin),2)),2), ... % Local (bs)
    'o_act', mean(A(:,sswin),2));                          % where it landed (absolute)
M.OL = meas(Aol,Gol);  M.CL = meas(Acl,Gcl);

%% [CTRL-SD-STATS] --------------------------------------------------------------
pairs = { 's_lvl','o_loc','pre-stim Global level  ->  Local (residual)'
          's_var','o_loc','pre-stim variance      ->  Local (residual)'
          's_dst','o_loc','during-trial Global    ->  Local (residual)'
          's_lvl','o_act','pre-stim Global level  ->  final level (decoupling)' };
fprintf('\n[CTRL-SD] slope (outcome per unit state), Pearson r, p  --  OL vs CL\n');
fprintf('   %-46s %18s %18s   %s\n','pair','OL  slope [r, p]','CL  slope [r, p]','dSlope 95%% CI');
R = struct();
for i = 1:size(pairs,1)
    sx=pairs{i,1}; sy=pairs{i,2};
    [bo,ro,po] = lin_(M.OL.(sx), M.OL.(sy));
    [bc,rc,pc] = lin_(M.CL.(sx), M.CL.(sy));
    db = zeros(nBoot,1);
    for k2 = 1:nBoot
        io = randi(nOL,nOL,1); ic = randi(nCL,nCL,1);
        db(k2) = lin_(M.CL.(sx)(ic), M.CL.(sy)(ic)) - lin_(M.OL.(sx)(io), M.OL.(sy)(io));
    end
    ci = prctile(db,[2.5 97.5]);
    sig = ternS(ci(1)>0 || ci(2)<0, '  *', '');
    fprintf('   %-46s %7.3f [%+.2f,%.3f] %7.3f [%+.2f,%.3f]   [%+.3f,%+.3f]%s\n', ...
        pairs{i,3}, bo,ro,po, bc,rc,pc, ci(1),ci(2), sig);
    R(i).pair=pairs{i,3}; R(i).sx=sx; R(i).sy=sy;
    R(i).b_OL=bo; R(i).r_OL=ro; R(i).p_OL=po;
    R(i).b_CL=bc; R(i).r_CL=rc; R(i).p_CL=pc; R(i).dCI=ci;
end
fprintf('   (* = OL/CL slope difference excludes 0)   n_OL=%d n_CL=%d, single session\n', nOL, nCL);

%% [CTRL-SD-FIG] ----------------------------------------------------------------
figS = figure('Color','w','Position',[40 60 1500 780]);
tl = tiledlayout(figS,2,2,'TileSpacing','compact','Padding','compact');
for i = 1:size(pairs,1)
    ax=nexttile(tl,i); hold(ax,'on');
    sx=pairs{i,1}; sy=pairs{i,2};
    scat_(ax, M.OL.(sx), M.OL.(sy), [.25 .25 .25], 'OL');
    scat_(ax, M.CL.(sx), M.CL.(sy), [0.1 0.5 0.85], 'CL');
    xlabel(ax, strrep(sx,'_','\_')); ylabel(ax, strrep(sy,'_','\_'));
    title(ax, sprintf('%s\nOL b=%.3f (r=%.2f)   CL b=%.3f (r=%.2f)', ...
        pairs{i,3}, R(i).b_OL, R(i).r_OL, R(i).b_CL, R(i).r_CL), 'FontSize',9);
    legend(ax,'Location','best','Box','off','FontSize',8);
end
sgtitle(figS, sprintf('[CTRL-SD] Stage 5 state dependence of the residual  %s  (OL n=%d, CL n=%d)', ...
    strrep(sess_tag,'_','\_'), nOL, nCL));
fig_png = fullfile(fig_dir, sprintf('ctrl_state_dependence_%s.png', sess_tag));
exportgraphics(figS, fig_png, 'Resolution', 300);
fprintf('[CTRL-SD-FIG] -> %s\n', fig_png);

%% [CTRL-SD-SAVE] ---------------------------------------------------------------
SD = struct('sess_tag',sess_tag,'nOL',nOL,'nCL',nCL,'M',M,'R',R, ...
    'pre_s',pre_s,'ss_s',ss_s,'dur',dur,'Fs',Fs,'nBoot',nBoot);
sd_file = fullfile(dataDir, sprintf('ctrl_state_dependence_%s.mat', sess_tag));
save(sd_file,'-struct','SD','-v7.3');
fprintf('[CTRL-SD-SAVE] -> %s\n\n', sd_file);

%% ---- helpers -----------------------------------------------------------------
function [A,G,n] = deal_trials(starts, t_full, y_full, Gall, rel, pre, post, nF)
onF = zeros(numel(starts),1);
for j=1:numel(starts), [~,onF(j)] = min(abs(t_full-starts(j))); end
onF = onF(onF>pre & onF+post<=nF);  n = numel(onF);
A = zeros(n,numel(rel)); G = zeros(n,numel(rel));
for j=1:n, A(j,:) = y_full(onF(j)+rel).'; G(j,:) = Gall(onF(j)+rel).'; end
end

function [b,r,p] = lin_(x,y)
x=x(:); y=y(:); ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
if numel(x)<3, b=NaN; r=NaN; p=NaN; return; end
X=[ones(numel(x),1) x]; c=X\y; b=c(2);
[rr,pp]=corrcoef(x,y); r=rr(1,2); p=pp(1,2);
end

function scat_(ax,x,y,col,name)
scatter(ax,x,y,14,col,'filled','MarkerFaceAlpha',0.45,'DisplayName',name);
ok=isfinite(x)&isfinite(y); if nnz(ok)<3, return; end
xs=linspace(min(x(ok)),max(x(ok)),20).'; X=[ones(nnz(ok),1) x(ok)]; c=X\y(ok);
plot(ax,xs,c(1)+c(2)*xs,'-','Color',col,'LineWidth',1.8,'HandleVisibility','off');
end

function s=ternS(c,a,b); if c, s=a; else, s=b; end; end

function [y, ok] = local_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
y = nan(size(V,2),1);  ok = false;
if prow<1||prow>nY||pcol<1||pcol>nX; return; end
kr = max(1,prow-k):min(nY,prow+k);  kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;
Fraw = mI + Fsvd(:);
w = max(1, round(horizon)-1);  T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w,1);
base = (cs(ii+1)-cs(lo))./(ii-lo+1);
y = (Fraw - base)./base*100;  y(1:w) = NaN;
ok = true;
end
