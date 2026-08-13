% controller-analysis/cl_rmse_factor_windows.m
% Figure-4 candidate: contribution of three factors to CL tracking error,
% decomposed by error window (early 0-1 s transient vs late 1-3 s hold).
%
% Supersedes the X3 predictor of cl_mse_factors.m. That script used
% pre-trial dF/F std, which lumps together two visually distinct kinds of
% slow activity (short-duration delta waves + long large-amplitude slow
% waves). Here X3 is DELTA-BAND POWER (1-4 Hz) measured over -2 s -> stim
% end, which resolves that activity spectrally.
%
%   X1  initial deviation  = |dF/F(onset) - ref|            [IDENTICAL to cl_mse_factors]
%   X2  motion energy      = mean z-motion^2, -2 s -> end   [IDENTICAL to cl_mse_factors]
%   X3  delta power        = log10 band power 1-4 Hz, -2 s -> stim end   [NEW]
%
% Outcomes (both from wcDfk, relative to ref):
%   RMSE_early = RMSE over 0-1 s   (inhibitory transient / descent to ref)
%   RMSE_late  = RMSE over 1-3 s   (disturbance rejection, activity settled)
%
% CONFOUND STATUS (carried from the 2026-07-01 signal-power retraction):
%   X1 and X3(absolute) are magnitudes of the same wcDfk trace as the outcome.
%   Panel F therefore recomputes delta's unique contribution under the
%   power-INDEPENDENT relative-delta ratio and a pre-stim-only window, so the
%   figure shows whether the delta effect survives magnitude control.
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
clc; close all;

PS = paperStyle();
setPaperDefaults();

if exist(fullfile('paper','images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper'; warning('cannot locate paper/ -- exporting locally.');
end

% ---- constants ----
Fs      = 35;
c0      = 36;    % onset col, wcDfk
c0_mot  = 71;    % onset col, wcmotion
c0_l    = 106;   % onset col, pwcDfk_l
mot_pre = 2;
spec_pre_s = 2; spec_post_s = 3;        % delta window: -2 -> stim end (dur=3)
slow_bnd = [0.4 1]; delta_bnd = [1 4]; hi_bnd = [2 4]; tot_bnd = [0.4 10];

% RMSE sub-windows (cols in wcDfk, non-overlapping)
eE = c0 : c0+round(1*Fs);               % 0 -> 1 s
lL = c0+round(1*Fs)+1 : c0+round(3*Fs); % 1 -> 3 s

% ---- band-power helper: linear-detrend, Hann, one-sided periodogram ----
bandpow = @(seg, lo, hi) local_bandpow(seg, Fs, lo, hi);

fitR2 = @(Xp, yp) ...
    1 - sum((yp - [ones(size(Xp,1),1), Xp] * ([ones(size(Xp,1),1), Xp] \ yp)).^2) / ...
        max(sum((yp - mean(yp)).^2), eps);

%% ── Pool CL trials ──────────────────────────────────────────────────────────
X1=[]; X2=[]; Xdel=[]; Xrel=[]; Xpre=[]; Xslow=[];
YE=[]; YL=[]; YF=[]; SESS=[]; TRI=[];

for k = 1:numel(fields)
    s = mouse.(fields{k});
    if isfield(s,'skip') && s.skip;  continue; end
    if ~isfield(s,'data');           continue; end
    if ~s.has_motion;                continue; end
    dk = s.data; if ~isfield(dk,'wcmotion'); continue; end
    ref = s.d.ref; dur = s.d.params.dur; nT = size(dk.wcDfk,1);

    % X1 initial deviation
    x1 = abs(dk.wcDfk(:,c0) - ref);

    % X2 motion energy, -2 -> stim end
    ws = max(1, c0_mot - round(mot_pre*Fs));
    we = min(size(dk.wcmotion,2), c0_mot + round(dur*Fs) - 1);
    x2 = mean(dk.wcmotion(1:nT, ws:we).^2, 2);

    % spectral window on pwcDfk_l: -2 -> stim end
    sa = c0_l - round(spec_pre_s*Fs);
    sb = c0_l + round(spec_post_s*Fs);
    pa = c0_l - round(spec_pre_s*Fs);      % pre-only end at onset
    pb = c0_l;

    [xdel, xrel, xslow, xpre] = deal(nan(nT,1));
    for t = 1:nT
        seg  = double(dk.pwcDfk_l(t, sa:sb));
        pseg = double(dk.pwcDfk_l(t, pa:pb));
        pd = bandpow(seg, delta_bnd(1), delta_bnd(2));
        ps = bandpow(seg, slow_bnd(1),  slow_bnd(2));
        pt = bandpow(seg, tot_bnd(1),   tot_bnd(2));
        xdel(t)  = pd;
        xslow(t) = ps;
        xrel(t)  = bandpow(seg,hi_bnd(1),hi_bnd(2)) / max(pt, eps);  % relative 2-4 Hz (hard-to-control sub-band)
        xpre(t)  = bandpow(pseg, delta_bnd(1), delta_bnd(2));  % delta, pre-stim only
    end

    % outcomes
    yE = sqrt(mean((dk.wcDfk(1:nT,eE) - ref).^2, 2));
    yL = sqrt(mean((dk.wcDfk(1:nT,lL) - ref).^2, 2));
    yF = dk.er_wcDfk(1:nT);

    m = min([nT numel(yF)]);
    X1=[X1;x1(1:m)]; X2=[X2;x2(1:m)]; Xdel=[Xdel;xdel(1:m)]; %#ok<*AGROW>
    Xrel=[Xrel;xrel(1:m)]; Xpre=[Xpre;xpre(1:m)]; Xslow=[Xslow;xslow(1:m)];
    YE=[YE;yE(1:m)]; YL=[YL;yL(1:m)]; YF=[YF;yF(1:m)];
    SESS=[SESS;repmat(k,m,1)]; TRI=[TRI;(1:m)'];
end

ok = all(isfinite([X1 X2 Xdel Xrel Xpre Xslow YE YL YF]),2) & Xdel>0 & Xpre>0;
f = @(v) v(ok);
[X1,X2,Xdel,Xrel,Xpre,Xslow,YE,YL,YF,SESS,TRI] = ...
    deal(f(X1),f(X2),f(Xdel),f(Xrel),f(Xpre),f(Xslow),f(YE),f(YL),f(YF),f(SESS),f(TRI));
n = numel(YE);
fprintf('\n[cl_rmse_factor_windows] %d valid CL trials.\n', n);

% Predictor matrices (X1 raw, X2 raw energy [matches cl_mse_factors], X3 = log10 delta)
Ld = log10(Xdel);                            % kept for the robustness panel
Zabs = zscore([X1, X2, Xrel]);               % primary model -- RELATIVE 2-4 Hz (power-independent)
pred_names = {'Initial dev','Motion','Rel 2-4 Hz'};

%% ── Collinearity ─────────────────────────────────────────────────────────────
R = corr([X1 X2 Ld]);
fprintf('\nPredictor correlations (X1, X2, log-delta):\n'); disp(round(R,3));
fprintf('corr(log-delta, log-slow)      = %.3f\n', corr(Ld, log10(Xslow)));
fprintf('corr(log-delta, relative-delta)= %.3f\n', corr(Ld, Xrel));

%% ── Windowed decomposition: partial R² per factor × window ──────────────────
outs = {YE, YL, YF}; out_names = {'RMSE 0-1 s','RMSE 1-3 s','RMSE 0-3 s'};
nBoot = 2000; rng(0);

Pr    = nan(3,3);     % factor × outcome   (partial/unique R²)
PrCI  = nan(3,3,2);   % + bootstrap CI
Rfull = nan(1,3);
for o = 1:3
    y = zscore(outs{o});
    rf = fitR2(Zabs, y); Rfull(o) = rf;
    for j = 1:3
        oth = setdiff(1:3,j);
        Pr(j,o) = rf - fitR2(Zabs(:,oth), y);
    end
    bp = nan(nBoot,3);
    for b = 1:nBoot
        ib = randsample(n,n,true); Xb = Zabs(ib,:); yb = y(ib);
        rfb = fitR2(Xb, yb);
        for j = 1:3, bp(b,j) = rfb - fitR2(Xb(:,setdiff(1:3,j)), yb); end
    end
    ci = prctile(bp,[2.5 97.5],1);
    PrCI(:,o,1) = ci(1,:).'; PrCI(:,o,2) = ci(2,:).';
end

fprintf('\nPartial (unique) R² by window:\n');
fprintf('  %-14s %8s %8s %8s\n','factor',out_names{:});
for j=1:3
    fprintf('  %-14s %8.3f %8.3f %8.3f\n', pred_names{j}, Pr(j,1),Pr(j,2),Pr(j,3));
end
fprintf('  %-14s %8.3f %8.3f %8.3f\n','FULL MODEL R2', Rfull);

%% ── Delta confound robustness: abs vs relative vs pre-only, per window ──────
% unique R² of the delta predictor holding X1,X2 fixed, under 3 definitions
delvar = {Ld, Xrel, log10(Xpre)}; del_lbl = {'delta abs','delta rel','delta pre'};
Drob = nan(3,2);   % definition × window(early,late)
for d = 1:3
    Xd = zscore([X1, X2, delvar{d}]);
    for o = 1:2
        y = zscore(outs{o}); rf = fitR2(Xd,y);
        Drob(d,o) = rf - fitR2(Xd(:,[1 2]), y);
    end
end
fprintf('\nDelta unique R² (holding init-dev + motion) by definition × window:\n');
fprintf('  %-11s %10s %10s\n','def','early 0-1','late 1-3');
for d=1:3, fprintf('  %-11s %10.3f %10.3f\n', del_lbl{d}, Drob(d,1), Drob(d,2)); end

%% ── Pick the two activity-type exemplars ────────────────────────────────────
frac_slow = Xslow ./ (Xslow + Xdel);
hp = (Xslow + Xdel) >= prctile(Xslow+Xdel, 75);   % genuinely high slow-wave power
cand = find(hp);
[~,is] = max(frac_slow(cand)); ex_slow = cand(is);   % slow-wave dominated
[~,id] = min(frac_slow(cand)); ex_delt = cand(id);   % fast-delta dominated
fprintf('\nExemplars: slow-dom %s tr%d (fracSlow %.2f) | delta-dom %s tr%d (fracSlow %.2f)\n', ...
    fields{SESS(ex_slow)},TRI(ex_slow),frac_slow(ex_slow), ...
    fields{SESS(ex_delt)},TRI(ex_delt),frac_slow(ex_delt));

%% ── FIGURE (2×3 Figure-4 candidate) ─────────────────────────────────────────
col = [0.20 0.40 0.75;   % init dev  (blue)
       0.75 0.40 0.10;   % motion    (orange)
       0.55 0.25 0.60];  % delta     (purple)
col_e = [0.35 0.55 0.85]; col_l = [0.15 0.25 0.55];   % early / late
tvec = (-spec_pre_s : 1/Fs : spec_post_s).';

fig = paperFig(19, 12);
tl = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');

% (A) slow-wave exemplar
ax=nexttile(tl); plot_ex(ax, mouse, fields, SESS, TRI, ex_slow, c0_l, spec_pre_s, spec_post_s, Fs, [0.55 0.25 0.60], PS);
title(ax,sprintf('Slow-wave trial (f_{slow}=%.2f)',frac_slow(ex_slow)),'FontSize',6,'FontWeight','bold');
% (B) delta exemplar
ax=nexttile(tl); plot_ex(ax, mouse, fields, SESS, TRI, ex_delt, c0_l, spec_pre_s, spec_post_s, Fs, [0.35 0.45 0.70], PS);
title(ax,sprintf('Delta-wave trial (f_{slow}=%.2f)',frac_slow(ex_delt)),'FontSize',6,'FontWeight','bold');

% (C) power spectra of the two exemplars
ax=nexttile(tl); hold(ax,'on');
for ii=1:2
    idx = [ex_slow ex_delt]; cc = [0.55 0.25 0.60; 0.35 0.45 0.70];
    dk=mouse.(fields{SESS(idx(ii))}).data;
    seg=double(dk.pwcDfk_l(TRI(idx(ii)), c0_l-spec_pre_s*Fs : c0_l+spec_post_s*Fs));
    [Pxx,fx]=local_psd(seg,Fs);
    plot(ax, fx, 10*log10(Pxx+eps), '-', 'Color', cc(ii,:), 'LineWidth', PS.lw_mean);
end
yl=ylim(ax);
patch(ax,[slow_bnd fliplr(slow_bnd)],[yl(1) yl(1) yl(2) yl(2)],[0.55 0.25 0.60],'FaceAlpha',0.08,'EdgeColor','none');
patch(ax,[delta_bnd fliplr(delta_bnd)],[yl(1) yl(1) yl(2) yl(2)],[0.35 0.45 0.70],'FaceAlpha',0.08,'EdgeColor','none');
xlim(ax,[0 8]); set(ax,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
xlabel(ax,'Hz','FontSize',6,'FontWeight','bold'); ylabel(ax,'power (dB)','FontSize',6,'FontWeight','bold');
title(ax,'Exemplar spectra','FontSize',6,'FontWeight','bold');
text(ax,1.05,yl(1)+0.9*range(yl),'slow','Color',[0.55 0.25 0.60],'FontSize',5,'FontWeight','bold');
text(ax,2.2,yl(1)+0.9*range(yl),'delta','Color',[0.35 0.45 0.70],'FontSize',5,'FontWeight','bold');
hold(ax,'off');

% (D) predictor correlation heatmap
ax=nexttile(tl);
bwr = interp1([0 .5 1],[0.18 0.33 0.78;1 1 1;0.84 0.19 0.15],linspace(0,1,256));
imagesc(ax,R); colormap(ax,bwr); clim(ax,[-1 1]); axis(ax,'square');
set(ax,'XTick',1:3,'YTick',1:3,'XTickLabel',pred_names,'YTickLabel',pred_names, ...
    'TickLabelInterpreter','none','FontSize',5,'FontWeight','bold'); xtickangle(ax,20);
for i=1:3
    for jj=1:3
        cij='k'; if abs(R(i,jj))>0.55, cij='w'; end
        text(ax,jj,i,sprintf('%.2f',R(i,jj)),'HorizontalAlignment','center','FontSize',5,'FontWeight','bold','Color',cij);
    end
end
title(ax,'Predictor collinearity','FontSize',6,'FontWeight','bold');

% (E) MAIN: partial R² grouped bars, 3 factors × 2 windows
ax=nexttile(tl); hold(ax,'on');
M = Pr(:,1:2);                         % 3×2 (early,late)
hb = bar(ax, M, 'grouped', 'EdgeColor','none'); hb(1).FaceColor=col_e; hb(2).FaceColor=col_l;
ngr=3; nser=2; gw=min(0.8, nser/(nser+1.5));
for j=1:nser
    xc = (1:ngr) - gw/2 + (2*j-1)*gw/(2*nser);
    errorbar(ax, xc, M(:,j), M(:,j)-PrCI(:,j,1), PrCI(:,j,2)-M(:,j), ...
        'k','linestyle','none','LineWidth',0.7,'CapSize',3,'HandleVisibility','off');
end
set(ax,'XTick',1:3,'XTickLabel',pred_names,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
xtickangle(ax,20);
ylabel(ax,'Partial R^2 (unique)','FontSize',6,'FontWeight','bold');
lg=legend(ax,{'0-1 s','1-3 s'},'FontSize',5,'Box','off','Location','northwest'); lg.ItemTokenSize=[6 6];
title(ax,sprintf('Factor contribution by window (R^2_{full}: %.2f / %.2f)',Rfull(1),Rfull(2)), ...
    'FontSize',6,'FontWeight','bold');
hold(ax,'off');

% (F) delta robustness: abs / rel / pre-only × window
ax=nexttile(tl); hold(ax,'on');
yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5,'HandleVisibility','off');
hb=bar(ax, Drob, 'grouped','EdgeColor','none'); hb(1).FaceColor=col_e; hb(2).FaceColor=col_l;
set(ax,'XTick',1:3,'XTickLabel',{'absolute','relative','pre-stim'}, ...
    'Box','off','TickDir','out','FontSize',5,'FontWeight','bold'); xtickangle(ax,20);
ylabel(ax,'Delta unique R^2','FontSize',6,'FontWeight','bold');
lg=legend(ax,hb,{'0-1 s','1-3 s'},'FontSize',5,'Box','off','Location','northeast'); lg.ItemTokenSize=[6 6];
title(ax,'Delta effect vs magnitude control','FontSize',6,'FontWeight','bold');
hold(ax,'off');

% Session count was hardcoded '9' until 2026-08-13 -- it had been true when written and silently
% went stale as sessions were added/removed. Compute it, so the title cannot lie again.
title(tl, sprintf(['CL error factors by window  (n=%d trials, %d sessions)   ' ...
    'delta = RELATIVE power 2-4 Hz / 0.4-10 Hz, -2 s to stim end'], n, numel(unique(SESS))), ...
    'FontSize',7,'FontWeight','bold');

paperExport(fig, fullfile(paper_root,'images','figure4','cl_rmse_factor_windows.png'));
fprintf('\n[cl_rmse_factor_windows] Exported cl_rmse_factor_windows.png\n');

% cache
save(fullfile('data','cl_rmse_factor_windows.mat'), ...
    'Pr','PrCI','Rfull','Drob','R','pred_names','out_names','n', ...
    'X1','X2','Xdel','Xrel','Xpre','Xslow','YE','YL','YF','SESS','TRI');

%% ---- helpers ----
function p = local_bandpow(seg, Fs, lo, hi)
    seg = detrend(double(seg(:)).','linear'); N=numel(seg);
    w = hann(N).'; P = abs(fft(seg.*w)).^2; P = P(1:floor(N/2)+1);
    fr = (0:floor(N/2))*Fs/N; p = sum(P(fr>=lo & fr<hi));
end
function [P,fr] = local_psd(seg, Fs)
    seg = detrend(double(seg(:)).','linear'); N=numel(seg);
    w = hann(N).'; P = abs(fft(seg.*w)).^2; P = P(1:floor(N/2)+1);
    fr = (0:floor(N/2))*Fs/N;
end
function plot_ex(ax, mouse, fields, SESS, TRI, t, c0_l, pre, post, Fs, cc, PS)
    dk=mouse.(fields{SESS(t)}).data; ref=mouse.(fields{SESS(t)}).d.ref;
    tv=(-pre:1/Fs:post).'; seg=dk.pwcDfk_l(TRI(t), c0_l-pre*Fs : c0_l+post*Fs);
    hold(ax,'on');
    patch(ax,[0 3 3 0],[-16 -16 10 10],[0.85 0.85 0.85],'EdgeColor','none','FaceAlpha',0.45);
    plot(ax,tv([1 end]),[ref ref],'--','Color',[0.3 0.3 0.3],'LineWidth',PS.lw_ref);
    plot(ax,tv,seg,'-','Color',cc,'LineWidth',PS.lw_mean);
    xlim(ax,[-pre post]); ylim(ax,[-16 10]);
    set(ax,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
    xlabel(ax,'time from onset (s)','FontSize',6,'FontWeight','bold');
    ylabel(ax,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
    hold(ax,'off');
end
