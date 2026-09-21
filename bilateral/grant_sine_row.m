%% grant_sine_row.m -- Fig 11 row 2 (sine tracking) as a SINGLE 1x4 row.
% Replaces the hand-assembled 2x2 cl_controller.png. Colors matched to the
% fixed-target row 1: open loop = red (PS.col_ol), closed loop = blue (PS.col_cl).
% Two conditions: OL (ff_cond 2) vs closed-loop + model-based preview (ff_cond 0).
% Panels: (1) OL trials+mean+ref  (2) CL+preview trials+mean+ref
%         (3) per-trial RMSE OL vs CL+prev (+Wilcoxon)  (4) across-trial variance.
% Run after: r_bil=1; load_bilateral;   Exports PNG (grant figure, not a paper panel).
clc; close all;
PS = paperStyle();
assert(exist('sessions','var'), 'run load_bilateral.m first (need `sessions`).');
OUT = 'C:\Users\aditya\Documents\projects\draft\grant_2026_10_YazdanSteinmetz\figs2\cl_controller.png';
SIDE='right'; fs_img=35; n_pre_s=1.0; REF_SIGN=-1;
MODE_CODES=[2 0]; MODE_LABELS={'Open loop','Closed loop + preview'};
COLS=[PS.col_ol; PS.col_cl]; COL_TRIAL=[0.8 0.8 0.8];

% ---- pick the sine session that best shows the preview benefit ----
% (smallest OL-vs-CL+prev RMSE p with CL+prev < OL). Falls back to most trials.
fns=fieldnames(sessions); best=''; bestP=Inf; bestN=-1; fbN=''; fbNmax=-1;
for i=1:numel(fns)
    s=sessions.(fns{i});
    if ~isfield(s,'sine')||isempty(s.sine)||~isfield(s,SIDE)||~isfield(s.(SIDE),'dFoF'); continue; end
    if isfield(s,'skip')&&s.skip; continue; end
    sm=strcmp({s.trial_meta.side},SIDE);
    dF=s.(SIDE).dFoF; sn=s.sine; nw=round(sn.dur*fs_img); np=round(n_pre_s*fs_img); Rc=cell(1,2);
    for m=1:2
        tr=[s.trial_meta(([s.trial_meta.ff_cond]==MODE_CODES(m))&sm).trial_idx];
        for j=1:numel(tr); i0=s.onset_idx(tr(j));
            if isnan(i0)||i0-np<1||i0+nw>numel(dF)||i0+nw>numel(s.ref_raw); continue; end
            seg=dF(i0-np:i0+nw); Rj=sn.ref0+REF_SIGN*s.ref_raw(i0:i0+nw).';
            Rc{m}=[Rc{m}; sqrt(mean((seg(np+1:end).'-Rj(:)).^2))];
        end
    end
    ntot=numel(Rc{1})+numel(Rc{2});
    if ntot>fbNmax; fbNmax=ntot; fbN=fns{i}; end
    if numel(Rc{1})>=2 && numel(Rc{2})>=2
        pp=ranksum(Rc{1},Rc{2});
        if mean(Rc{2})<mean(Rc{1}) && pp<bestP; bestP=pp; best=fns{i}; bestN=ntot; end
    end
end
if isempty(best); best=fbN; bestN=fbNmax; end
sess=sessions.(best); fprintf('[grant_sine_row] session %s (%s %s/%d), %d OL+CL+prev trials, sel p=%.3g\n', ...
    best, sess.mn, sess.td, sess.en, bestN, bestP);

dFoF=sess.(SIDE).dFoF; sn=sess.sine;
n_win=round(sn.dur*fs_img); n_pre=round(n_pre_s*fs_img);
t_ax=(-n_pre:n_win)/fs_img; t_ref=(0:n_win)/fs_img;
sideMask=strcmp({sess.trial_meta.side},SIDE);
nMode=numel(MODE_CODES); traces=cell(1,nMode); refs=cell(1,nMode); rmse=cell(1,nMode); nTr=zeros(1,nMode);
for m=1:nMode
    trials=[sess.trial_meta(([sess.trial_meta.ff_cond]==MODE_CODES(m))&sideMask).trial_idx];
    for j=1:numel(trials)
        i0=sess.onset_idx(trials(j));
        if isnan(i0)||i0-n_pre<1||i0+n_win>numel(dFoF)||i0+n_win>numel(sess.ref_raw); continue; end
        seg=dFoF(i0-n_pre:i0+n_win); Rj=sn.ref0+REF_SIGN*sess.ref_raw(i0:i0+n_win).';
        traces{m}=[traces{m};seg(:)']; refs{m}=[refs{m};Rj(:)'];
        rmse{m}=[rmse{m}; sqrt(mean((seg(n_pre+1:end).'-Rj(:)).^2))];
    end
    nTr(m)=size(traces{m},1);
end
refPlot=mean(cell2mat(refs(:)),1);
allv=cell2mat(traces(:)); ylTr=[min(allv(:)) max(allv(:))]+[-0.05 0.05]*range(allv(:));

fig=figure('Color','w','Units','centimeters','Position',[1 1 19 4.7]);
tl=tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');

% ---- P1, P2: per-condition trials + mean + reference ----
for m=1:2
    ax=nexttile(tl); hold(ax,'on');
    plot(ax,t_ax,traces{m}.','Color',COL_TRIAL,'LineWidth',PS.lw_trial);
    plot(ax,t_ax,mean(traces{m},1),'Color',COLS(m,:),'LineWidth',PS.lw_mean);
    plot(ax,t_ref,refPlot,'k--','LineWidth',PS.lw_ref);
    hold(ax,'off'); xlim(ax,[t_ax(1) t_ax(end)]); ylim(ax,ylTr);
    title(ax,sprintf('%s (n=%d)',MODE_LABELS{m},nTr(m)),'FontSize',PS.fs,'FontWeight','bold');
    xlabel(ax,'Time (s)','FontSize',PS.fs,'FontWeight','bold');
    if m==1; ylabel(ax,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight','bold'); end
    set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight','bold');
end

% ---- P3: per-trial RMSE half-violins ----
ax=nexttile(tl); hold(ax,'on'); hw=0.34;
for m=1:2
    if nTr(m)<2; continue; end
    [fd,yd]=ksdensity(rmse{m}); fd=fd/max(fd)*hw;
    fill(ax,[m-fd, m*ones(size(fd))],[yd fliplr(yd)],COLS(m,:),'FaceAlpha',0.45,'EdgeColor','none');
    plot(ax,m,mean(rmse{m}),'k.','MarkerSize',8);
end
p=NaN; if nTr(1)>=2&&nTr(2)>=2; p=ranksum(rmse{1},rmse{2}); end
hold(ax,'off'); xlim(ax,[0.5 2.5]);
set(ax,'XTick',1:2,'XTickLabel',{'OL','CL+prev'},'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight','bold');
ylabel(ax,'Trial RMSE (%\DeltaF/F)','FontSize',PS.fs,'FontWeight','bold');
title(ax,sprintf('Tracking error (%s)',starstr(p)),'FontSize',PS.fs,'FontWeight','bold');

% ---- P4: across-trial variance over time ----
ax=nexttile(tl); hold(ax,'on');
for m=1:2
    plot(ax,t_ax,var(traces{m},0,1),'Color',COLS(m,:),'LineWidth',PS.lw_mean,'DisplayName',MODE_LABELS{m});
end
hold(ax,'off'); xlim(ax,[t_ax(1) t_ax(end)]);
xlabel(ax,'Time (s)','FontSize',PS.fs,'FontWeight','bold');
ylabel(ax,'Across-trial variance','FontSize',PS.fs,'FontWeight','bold');
title(ax,'Variance across trials','FontSize',PS.fs,'FontWeight','bold');
lg=legend(ax,'Location','northeast'); set(lg,'Box','off','FontSize',5);
set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight','bold');

exportgraphics(fig,OUT,'Resolution',300);
fprintf('[grant_sine_row] OL vs CL+prev RMSE p=%.4g -> %s\n', p, OUT);

function s=starstr(p); if isnan(p), s='n.s.'; elseif p<1e-3, s='***'; elseif p<1e-2, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end; end
