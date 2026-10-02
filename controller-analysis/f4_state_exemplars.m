% controller-analysis/f4_state_exemplars.m
% Fig-4 ROW 1 composite -- pre-stimulus state -> CL tracking error.
%   tiles 1-4  exemplar CL trials, one per pre-stim state (high init-dev / motion / rel 2-4 Hz /
%              abs delta), each SPECIFIC to that state (high in it, low in the others). Scale-bar
%              (shortCornerAxes_plot) axes; the state COLOUR is shared with the R^2 bar (tile 6).
%   tile 5     the representative error model equation (RMSE ~ the four states), terms colour-coded.
%   tile 6     R^2 explained bar: each state's own-model unique R^2 (paper 'sep' framing), coloured
%              to match the exemplars, with the full 4-factor model R^2 marked.
% One pooled build (CL trials, all four states aligned per trial) drives BOTH the exemplar picks
% and the R^2/equation, so the panel can never disagree with itself.
% Requires full load_sessions.m (mouse, fields in base).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper';
outfig=fullfile(root,'paper','figures_v2','figure4');   % jn* v2 output
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
Fs=35; c0=36; c0_mot=71; c0_l=106; c1=71; c2=141; mot_pre=2; spec_pre_s=2; spec_post_s=3;
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10];
bp=@(seg,lo,hi) local_bandpow(seg,Fs,lo,hi);

% ---- pool CL trials: 4 states + outcome (rejection RMSE), aligned per trial ----
X1=[];X2=[];Xrel=[];Xdel=[];Y=[];SESS=[];TRI=[];
for k=1:numel(fields)
    s=mouse.(fields{k});
    if (isfield(s,'skip')&&s.skip)||~isfield(s,'data')||~s.has_motion; continue; end
    dk=s.data; if ~isfield(dk,'wcmotion')||~isfield(dk,'wcDfk')||isempty(dk.wcDfk); continue; end
    ref=s.d.ref; dur=s.d.params.dur; nT=size(dk.wcDfk,1);
    y=sqrt(mean((dk.wcDfk(:,c1:c2)-ref).^2,2));               % settled 1-3 s rejection RMSE
    x1=abs(dk.wcDfk(:,c0)-ref);                               % initial deviation
    ws=max(1,c0_mot-round(mot_pre*Fs)); we=min(size(dk.wcmotion,2),c0_mot+round(dur*Fs)-1);
    x2=mean(dk.wcmotion(1:nT,ws:we).^2,2);                    % motion energy
    sa=c0_l-round(spec_pre_s*Fs); sb=c0_l+round(spec_post_s*Fs);
    [xrel,xdel]=deal(nan(nT,1));
    for t=1:nT
        seg=double(dk.pwcDfk_l(t,sa:sb));
        xdel(t)=bp(seg,delta_bnd(1),delta_bnd(2));            % abs 1-4 Hz power
        xrel(t)=bp(seg,hi_bnd(1),hi_bnd(2))/max(bp(seg,tot_bnd(1),tot_bnd(2)),eps);  % rel 2-4 Hz
    end
    X1=[X1;x1];X2=[X2;x2];Xrel=[Xrel;xrel];Xdel=[Xdel;xdel];Y=[Y;y]; %#ok<*AGROW>
    SESS=[SESS;repmat(k,nT,1)];TRI=[TRI;(1:nT)'];
end
ok=all(isfinite([X1 X2 Xrel Xdel Y]),2)&Xdel>0; f=@(v)v(ok);
[X1,X2,Xrel,Xdel,Y,SESS,TRI]=deal(f(X1),f(X2),f(Xrel),f(Xdel),f(Y),f(SESS),f(TRI));
Z=zscore([X1 X2 Xrel log10(Xdel)]); yz=zscore(Y);            % z of the 4 states + outcome
lbl={'high init-dev','high motion','high rel 2-4 Hz','high abs \delta'};   % short titles: fit tile width, match panel-C labels
eqlbl={'init-dev','motion','rel \delta','abs \delta'};
col=[0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];   % SHARED state colours

% ---- error model: standardized betas + per-state R^2 (paper 'sep' framing) ----
fitR2=@(Xp,yp) 1 - sum((yp-[ones(size(Xp,1),1) Xp]*([ones(size(Xp,1),1) Xp]\yp)).^2)/sum((yp-mean(yp)).^2);
beta=[ones(size(Z,1),1) Z]\yz;                                % standardized coefficients (b0 + 4)
R2full=fitR2(Z,yz);
% each delta over the SAME init+motion base, in its own 3-factor model (rel & abs are collinear,
% so a single 4-factor model makes abs cannibalise rel -- user 2026-09-21). init/motion from rel model.
sepR2=[ fitR2(Z(:,[1 2 3]),yz)-fitR2(Z(:,[2 3]),yz); ...     % init
        fitR2(Z(:,[1 2 3]),yz)-fitR2(Z(:,[1 3]),yz); ...     % motion
        fitR2(Z(:,[1 2 3]),yz)-fitR2(Z(:,[1 2]),yz); ...     % rel (unique over init+motion)
        fitR2(Z(:,[1 2 4]),yz)-fitR2(Z(:,[1 2]),yz) ];       % abs (unique over init+motion)
fprintf('[f4_state_exemplars] nCL=%d | full R^2=%.3f | sep R^2 init %.3f mot %.3f rel %.3f abs %.3f\n', ...
    size(Z,1), R2full, sepR2);

% ---- pick a SPECIFIC exemplar per state: max (z_target - max other z), z_target>1 ----
pick=nan(1,4);
for j=1:4
    others=setdiff(1:4,j); spec=Z(:,j)-max(Z(:,others),[],2); spec(Z(:,j)<1)=-inf;
    [~,pick(j)]=max(spec);
end

% ================= FIGURE: 1 x 6 row =================
fig=jnFig(7.5,3.3); tl=tiledlayout(fig,1,4,'TileSpacing','compact','Padding','tight');  % jn* row-1 LEFT (exemplars 7.5 + eqn 3.0 + unique-R^2 5.5); tight-crop export = no clip
tv=(-spec_pre_s:1/Fs:spec_post_s).'; yl=[-16 10];

% ----- tiles 1-4: exemplars -----
for j=1:4
    ax=nexttile(tl); i=pick(j); dk=mouse.(fields{SESS(i)}).data; ref=mouse.(fields{SESS(i)}).d.ref;
    seg=dk.pwcDfk_l(TRI(i), c0_l-spec_pre_s*Fs : c0_l+spec_post_s*Fs);
    hold(ax,'on');
    patch(ax,[0 3 3 0],[yl(1) yl(1) yl(2) yl(2)],[.9 .9 .9],'EdgeColor','none','FaceAlpha',.5,'HandleVisibility','off');
    plot(ax,tv([1 end]),[ref ref],'--','Color',[.3 .3 .3],'LineWidth',PS.lw_ref,'HandleVisibility','off');
    xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
    if j==2 && isfield(dk,'wcmotion')                        % z-motion overlay for the motion exemplar
        wm=dk.wcmotion(TRI(i), c0_mot-mot_pre*Fs : min(size(dk.wcmotion,2),c0_mot+spec_post_s*Fs));
        tvm=(-mot_pre:1/Fs:spec_post_s).'; tvm=tvm(1:numel(wm));
        wmz=(wm-mean(wm))/max(std(wm),eps); wmz=wmz*2 - 11;
        plot(ax,tvm,wmz,'-','Color',[.55 .55 .55],'LineWidth',0.8);
        text(ax,-1.9,-8,'z-motion','Color',[.5 .5 .5],'FontSize',PS.fs-1,'FontWeight',PS.fw);
    end
    plot(ax,tv,seg,'-','Color',col(j,:),'LineWidth',PS.lw_mean);
    xlim(ax,[-spec_pre_s spec_post_s]); ylim(ax,yl);
    title(ax,lbl{j},'FontSize',PS.fs,'FontWeight',PS.fw,'Color',col(j,:));
    if j==1     % scale bars only on the first tile (shared axes across the row)
        shortCornerAxes_plot(ax,'Corner','bl','XLength',1,'YLength',5,'XLabel','1 s','YLabel','5%', ...
            'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);
    else
        shortCornerAxes_plot(ax,'Corner','bl','XLength',1,'YLength',0,'XLabel','1 s', ...
            'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);
    end
end

% tiles 5 (error-model equation) and 6 (R^2 explained bar) REMOVED 2026-09-28 (user):
% row-1 is now [state exemplars | decomp unique-R^2 (f4_error_decomp)] -- the R^2 bars live in
% the separate decomp panel (recoloured by factor), so exemplars = 4 bigger trials only.

paperExport(fig,fullfile(outfig,'f4_state_exemplars.pdf'));   % exact-page vector (Option 2)
paperExport(fig,fullfile(outview,'f4_state_exemplars.png'));
fprintf('[f4_state_exemplars] wrote row-1 composite -> %s\n',outfig);

function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg); w=hannwin(N).';
    P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1); fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo&fr<hi));
end
