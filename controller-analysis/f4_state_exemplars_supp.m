% controller-analysis/f4_state_exemplars_supp.m
% SUPPLEMENTARY: the four state exemplars (high init-dev / motion / rel 2-4 Hz / abs delta)
% shown for EVERY motion session, so the reader can see the exemplar pattern is not specific to
% the one representative session used in main Fig 4A. Grid: rows = sessions, cols = 4 states.
% Best exemplar per state PER SESSION (max specificity, z within that session). Same colours as
% main Fig 4A. Requires full load_sessions.m (mouse, fields in base).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper';
outsupp=fullfile(root,'paper','images','supplementary'); if ~exist(outsupp,'dir'); mkdir(outsupp); end
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
Fs=35; c0=36; c0_mot=71; c0_l=106; c1=71; c2=141; mot_pre=2; spec_pre_s=2; spec_post_s=3;
% MOTION STATISTIC, shared with Fig-4 Row 2 (user, 2026-10-02): 'mean' primary | 'sq' secondary.
if ~exist('F4_MOT_STAT','var') || isempty(F4_MOT_STAT), F4_MOT_STAT = 'mean'; end
% STATE WINDOW, shared with the rest of Fig 4 via utils/f4_state_window.m (2026-10-02).
if ~exist('F4_STATE_WIN','var') || isempty(F4_STATE_WIN), F4_STATE_WIN = 'peri'; end
W_state = f4_state_window(F4_STATE_WIN);
fprintf('[f4_state_exemplars_supp] state window: %s\n', W_state.label);
delta_bnd=[1 4]; hi_bnd=[2 4]; tot_bnd=[0.4 10];
bp=@(seg,lo,hi) f4_bandpow(seg,Fs,lo,hi,W_state.bandpow);   % shared estimator
col=[0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];
lbl={'high initial deviation','high motion','high rel 2-4 Hz','high abs \delta'};

% ---- collect per-session exemplar picks ----
sessMn={}; picks={}; segs={}; mcount=containers.Map('KeyType','char','ValueType','double');
for k=1:numel(fields)
    s=mouse.(fields{k});
    if (isfield(s,'skip')&&s.skip)||~isfield(s,'data')||~s.has_motion; continue; end
    dk=s.data; if ~isfield(dk,'wcmotion')||~isfield(dk,'wcDfk')||isempty(dk.wcDfk)||~any(dk.wcmotion(:)); continue; end
    ref=s.d.ref; dur=s.d.params.dur; nT=size(dk.wcDfk,1);
    y=sqrt(mean((dk.wcDfk(:,c1:c2)-ref).^2,2));
    x1=abs(dk.wcDfk(:,c0)-ref);
    assert(dur == 3, 'f4_state_exemplars_supp:dur', 'f4_state_window assumes dur = 3 s (got %g)', dur);
    mc = c0_mot + W_state.mot;  mc = mc(mc>=1 & mc<=size(dk.wcmotion,2));
    % mean(z), via the SHARED utils/f4_motion_stat.m -- reconciled with Fig-4 Row 2
    % (user, 2026-10-02). F4_MOT_STAT='sq' for the secondary.
    x2=f4_motion_stat(dk.wcmotion(1:nT,mc), F4_MOT_STAT);
    % PRE-BUFFER: resolved per session (utils/pre_spec_buffer.m, 2026-10-02). No cache in
    % data/ still carries a `_l` buffer, so the hardcoded pwcDfk_l made this script dead.
    % c0_l now comes back as 106 or 351 to match whichever buffer exists; the window in
    % SECONDS is unchanged either way.
    [pbuf, c0_l] = pre_spec_buffer(dk, 'wc');
    sc = c0_l + W_state.spec;                % same window as motion (f4_state_window)
    [xrel,xdel]=deal(nan(nT,1));
    for t=1:nT
        seg=double(pbuf(t,sc));
        xdel(t)=bp(seg,delta_bnd(1),delta_bnd(2));
        xrel(t)=bp(seg,hi_bnd(1),hi_bnd(2))/max(bp(seg,tot_bnd(1),tot_bnd(2)),eps);
    end
    ok=all(isfinite([x1 x2 xrel xdel y]),2)&xdel>0; idx=find(ok);
    if numel(idx)<8; continue; end
    Z=zscore([x1(idx) x2(idx) xrel(idx) log10(xdel(idx))]);
    pk=nan(1,4);
    for j=1:4
        others=setdiff(1:4,j); spec=Z(:,j)-max(Z(:,others),[],2); spec(Z(:,j)<1)=-inf;
        [mx,ii]=max(spec); if ~isfinite(mx); [~,ii]=max(Z(:,j)); end
        pk(j)=idx(ii);
    end
    if isKey(mcount,s.mn); mcount(s.mn)=mcount(s.mn)+1; else; mcount(s.mn)=1; end
    tag=sprintf('%s %c', s.mn, 'a'+mcount(s.mn)-1);   % e.g. AL_0033 a, AL_0033 b, ...
    sessMn{end+1}=tag; picks{end+1}=pk; segs{end+1}=dk; %#ok<SAGROW>
end
nS=numel(picks); fprintf('[f4_exemplars_supp] %d motion sessions.\n',nS);
assert_pooled(nS, 'f4_state_exemplars_supp motion sessions');

% ---- grid: rows = sessions, cols = 4 states ----
fig=paperFig(16, 2.7*nS); tl=tiledlayout(fig,nS,4,'TileSpacing','compact','Padding','compact');
tv=(-spec_pre_s:1/Fs:spec_post_s).'; yl=[-16 10];
for r=1:nS
    dk=segs{r}; ref=-5; pk=picks{r};
    for j=1:4
        ax=nexttile(tl); tri=pk(j); hold(ax,'on');
        [eb, ec] = pre_spec_buffer(dk, 'wc');
        seg=eb(tri, ec-spec_pre_s*Fs : ec+spec_post_s*Fs);
        patch(ax,[0 3 3 0],[yl(1) yl(1) yl(2) yl(2)],[.9 .9 .9],'EdgeColor','none','FaceAlpha',.5,'HandleVisibility','off');
        plot(ax,tv([1 end]),[ref ref],'--','Color',[.3 .3 .3],'LineWidth',PS.lw_ref,'HandleVisibility','off');
        xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
        plot(ax,tv,seg,'-','Color',col(j,:),'LineWidth',PS.lw_mean);
        xlim(ax,[-spec_pre_s spec_post_s]); ylim(ax,yl);
        if r==1; title(ax,lbl{j},'FontSize',PS.fs,'FontWeight',PS.fw,'Color',col(j,:)); end
        if j==1
            ylabel(ax,strrep(sessMn{r},'_','\_'),'FontSize',PS.fs,'FontWeight',PS.fw);
            shortCornerAxes_plot(ax,'Corner','bl','XLength',1,'YLength',5,'XLabel','1 s','YLabel','5%', ...
                'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);
        else
            shortCornerAxes_plot(ax,'Corner','bl','XLength',1,'YLength',0,'XLabel','1 s', ...
                'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);
        end
    end
end
exportgraphics(fig,fullfile(outsupp,'f4_exemplars_sessions.pdf'),'ContentType','vector');
exportgraphics(fig,fullfile(outview,'f4_exemplars_sessions.png'),'Resolution',180);
fprintf('[f4_exemplars_supp] wrote %d-session exemplar grid -> %s\n',nS,outsupp);

% ================== SUPPLEMENTARY PANELS: ONE STRIP PER SESSION ==============
% S6 and S7 become ONE supplementary figure assembled in Illustrator (user,
% 2026-10-05: "figure 11, 12 can be put together but we need smaller panels and
% better assembly"). The grid above stays as the working contact sheet; THESE are
% the files that get pulled.
%
% WHY A STRIP PER SESSION, NOT A PANEL PER CELL. The four cells in a row share a
% session, a y-scale and a scale bar; splitting them would make the assembler
% re-establish by hand an alignment the figure already has, 44 times. The session
% is also the axis along which you would actually reorder or drop something. So the
% unit is the row: 11 files, stacked.
%
% SIZE. The contact sheet is 16 x 29.7 cm -- a full page before S7 is placed. At
% 1.3 cm per strip the stack is 12 x 14.3 cm, leaving room for the S7 trio beneath.
%
% NO TITLES ON ANY STRIP. Putting the four state labels on the first strip alone
% would make its crop taller than the other ten and the stack would not align (the
% same trap the S3 node panels hit). The column labels are set once, in Illustrator,
% above the stack; the traces are colour-coded by state as well, so the mapping is
% recoverable from the panel itself. The console prints label + colour below.
%
% NO INTERNAL MOUSE NAMES (user, 2026-10-05). The strips are labelled "Session k",
% burned in at the top-left of the first cell so it cannot change the crop. The
% k -> mouse/session mapping is printed, for the caption.
if ~exist('F4_SUPP_STRIPS','var') || isempty(F4_SUPP_STRIPS), F4_SUPP_STRIPS = true; end
if F4_SUPP_STRIPS
    fprintf('\n[f4_exemplars_supp] --- supplementary strips ---\n');
    fprintf('  column order / colour:\n');
    for j = 1:4
        fprintf('    %d  %-26s rgb(%.2f %.2f %.2f)\n', j, lbl{j}, col(j,:));
    end
    % Pad the y-limits 4%. The tight crop was landing on 18 pt for some strips and
    % 19 pt for others -- a 0.35 mm jitter that accumulates down an 11-strip stack --
    % because in the strips whose trace runs to the clip boundary the stroke reaches
    % the box edge and the content bbox rounds up a point. A little headroom keeps
    % every strip's extent set by the stimulus patch alone, so all eleven crop alike.
    % The scale panel below uses the SAME limits, so 5% stays 5%.
    % Identical y-limits on all eleven strips -- this is what makes one scale bar
    % legitimate for the whole stack. A 4% pad keeps traces off the clip boundary,
    % which is what was making the tight crop round to 18 pt on some strips and
    % 19 pt on others.
    %
    % The reserved-band idea (a taller ylS with the bar drawn inside it) was tried
    % and dropped: it cost ~40% of every strip's height to serve one panel, and the
    % bar's labels still fell outside the band. The bar is drawn BELOW the axes
    % instead -- see the S11 block -- which lengthens only the LAST strip's page,
    % downward. That is harmless: strips are stacked and aligned from the top, so
    % extra margin hanging off the bottom of the bottom panel disturbs nothing.
    ylS = yl + [-1 1]*0.04*diff(yl);
    % WINDOW: 2 s before the stimulus and 2 s after it (user, 2026-10-05: "show
    % stim -2 to stim +2"). The stimulus runs 0-3 s, so that is t = -2 to +5 s.
    % The old -2 to +3 ended EXACTLY at stimulus offset, so the strips showed the
    % controller holding the reference and then stopped -- the release back toward
    % baseline, which is half of what makes a trial readable, was never on screen.
    % The buffer carries 6 s post-onset, so +5 is real data, not padding.
    % NOTE this is a DISPLAY window only. The state-measure window stays [-2,+3) s
    % (locked decision), and the exemplar PICKING above is untouched.
    post_sS = 5;
    tvS = (-spec_pre_s:1/Fs:post_sS).';
    for r = 1:nS
        fS = paperFig(12, 1.3);
        tS = tiledlayout(fS, 1, 4, 'TileSpacing','compact', 'Padding','compact');
        dk = segs{r}; ref = -5; pk = picks{r};
        for j = 1:4
            ax = nexttile(tS); hold(ax,'on');
            [eb, ec] = pre_spec_buffer(dk, 'wc');
            seg = eb(pk(j), ec-spec_pre_s*Fs : ec+post_sS*Fs);
            patch(ax, [0 3 3 0], [ylS(1) ylS(1) ylS(2) ylS(2)], [.9 .9 .9], ...
                'EdgeColor','none', 'FaceAlpha',.5, 'HandleVisibility','off');
            plot(ax, tvS([1 end]), [ref ref], '--', 'Color',[.3 .3 .3], ...
                'LineWidth',PS.lw_ref, 'HandleVisibility','off');
            xline(ax, 0, ':', 'Color',[.6 .6 .6], 'HandleVisibility','off');
            plot(ax, tvS, seg, '-', 'Color', col(j,:), 'LineWidth', PS.lw_mean);
            xlim(ax, [-spec_pre_s post_sS]); ylim(ax, ylS);
            axis(ax, 'off');
            if j == 1
                % Label OUTSIDE the axes, on the left. Inside, at 1.3 cm tall, it
                % printed straight across the trace. Every strip gets one, so the
                % crops stay equal -- the S3 node panels showed what happens when
                % only the first panel of a stack carries extra content. S%02d
                % rather than "Session %d" so the string width is constant too.
                text(ax, -0.075, 0.5, sprintf('S%02d', r), 'Units','normalized', ...
                    'VerticalAlignment','middle', 'HorizontalAlignment','right', ...
                    'FontSize', PS.fs, 'FontWeight', PS.fw);
                % SCALE BAR ON THE BOTTOM-LEFT PANEL OF THE WHOLE STACK (user,
                % 2026-10-05: "put the short corner axis on s11 initial dev plot so
                % it seems like it carries over to others"). One bar under the last
                % strip reads as the scale for the column -- and for the stack,
                % since every strip shares these limits -- the way a corner axis on
                % the bottom-left panel of any multi-panel figure does.
                % It sits in the reserved band added to ylS below, so S11's content
                % box is the same as every other strip's and the stack still aligns.
                if r == nS
                    % House corner-axis form (1 s x 5% L, labels outside the arms),
                    % drawn by hand rather than via shortCornerAxes_plot because it
                    % has to sit BELOW the data box: the helper places the bar a
                    % fraction INSIDE the axes, which at 1.3 cm puts it straight on
                    % the trace and the reference line. Clipping is off so the arms
                    % and labels survive outside ylim. It is still in DATA units, so
                    % 1 s and 5% are exactly 1 s and 5% of these axes.
                    xb = -spec_pre_s + 0.10;              % just inside the left edge
                    yb = ylS(1) - 0.10*diff(ylS);         % one step below the box
                    plot(ax, [xb xb+1], [yb yb], '-', 'Color','k', ...
                        'LineWidth', PS.sca_lw, 'Clipping','off', 'HandleVisibility','off');
                    plot(ax, [xb xb], [yb yb+5], '-', 'Color','k', ...
                        'LineWidth', PS.sca_lw, 'Clipping','off', 'HandleVisibility','off');
                    text(ax, xb+0.5, yb - 0.06*diff(ylS), '1 s', 'Clipping','off', ...
                        'HorizontalAlignment','center', 'VerticalAlignment','top', ...
                        'FontSize', PS.fs, 'FontWeight', PS.fw);
                    text(ax, xb - 0.12, yb + 2.5, '5%', 'Clipping','off', ...
                        'HorizontalAlignment','right', 'VerticalAlignment','middle', ...
                        'FontSize', PS.fs, 'FontWeight', PS.fw);
                end
            end
        end
        paperExport(fS, fullfile(outsupp, sprintf('supp_f4_exemplar_%02d.pdf', r)));
        fprintf('  S%02d  <-  %s\n', r, sessMn{r});
    end


    fprintf('[f4_exemplars_supp] %d session strips -> %s\n', nS, outsupp);
end


function p=local_bandpow(seg,Fs,lo,hi)
    seg=detrend(double(seg(:)).','linear'); N=numel(seg); w=hannwin(N).';
    P=abs(fft(seg.*w)).^2; P=P(1:floor(N/2)+1); fr=(0:floor(N/2))*Fs/N; p=sum(P(fr>=lo&fr<hi));
end
