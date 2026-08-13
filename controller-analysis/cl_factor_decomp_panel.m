%% cl_factor_decomp_panel.m   [F4P1-DECOMP]  -- Fig 4 Part 1: the error decomposition panel
%
% WHAT WAS MISSING. Part 1 asks "what does the residual closed-loop error consist of?", and the
% four paired-slope panels (cl_factor_slope_panels.m) answer it one factor at a time: each shows
% whether a factor's slope survives, and whether feedback flattens it. None of them shows the
% decomposition itself -- how much of the trial-to-trial error variance each factor actually owns,
% and how that ownership CHANGES between the transient and the settled window. That number lives
% only in cl_rmse_factor_windows.m's printout and inside one tile of a 19x12 cm exploratory grid.
% This script is that one number, drawn at paper size.
%
% THE CLAIM IT MAKES. The composition of the error TURNS OVER between windows:
%   0-1 s  the error is where the trial started -- initial deviation owns it, delta is secondary.
%   1-3 s  initial deviation has decayed to nearly nothing and relative 2-4 Hz power is what is
%          left. Motion owns essentially none of it in either window.
% So the settled error the controller cannot remove is not a leftover of the transient; it is a
% different quantity, tied to ongoing 2-4 Hz activity.
%
% UNIQUE R^2, not R^2. Each bar is the drop in full-model R^2 when that ONE factor is removed
% (partial/unique R^2), so shared variance is charged to nobody and the bars do not double-count.
% They therefore sum to LESS than the full model R^2, which is printed on the panel.
%
% THE POOL. All three factors are scored on the SAME trials -- the sessions that carry motion
% (motion is the only factor with a coverage gap). One panel, one pool. The script then prints the
% all-session two-factor check: dropping motion buys back 4 sessions and moves nothing, which is
% what licenses reading the motion bar as "motion does not matter" rather than "motion was not
% measured here".
%
% Requires: load_sessions.m has run (mouse, fields in workspace).
% Measures are byte-identical to cl_rmse_factor_windows.m, so the numbers reproduce.
%
% SECTIONS: [F4P1-POOL] [F4P1-DECOMP] [F4P1-FIG] [F4P1-ROBUST]

clc; close all;
PS = paperStyle(); setPaperDefaults(); %#ok<NASGU>
if exist(fullfile('paper','images'),'dir'); paper_root='paper';
elseif exist(fullfile('..','paper','images'),'dir'); paper_root=fullfile('..','paper');
else; paper_root='paper'; warning('cannot locate paper/ -- exporting locally.'); end
outdir = fullfile(paper_root,'images','figure4');
if ~exist(outdir,'dir'); mkdir(outdir); end

FD_BOOT = 2000;   rng(0);
FD_EXPORT_PDF = false;   % PNG by default -- flip only when this is confirmed as a paper panel

% ---- constants (identical to cl_rmse_factor_windows.m) ----
Fs = 35; c0 = 36; c0_mot = 71; c0_l = 106;
mot_pre = 2; spec_pre_s = 2; spec_post_s = 3;
hi_bnd = [2 4]; tot_bnd = [0.4 10];
eE = c0 : c0+round(1*Fs);                 % transient 0 -> 1 s
lL = c0+round(1*Fs)+1 : c0+round(3*Fs);   % settled  1 -> 3 s

fitR2 = @(Xp,yp) 1 - sum((yp - [ones(size(Xp,1),1), Xp]*([ones(size(Xp,1),1), Xp]\yp)).^2) / ...
                     max(sum((yp - mean(yp)).^2), eps);

%% [F4P1-POOL] ---------------------------------------------------------------------
X1=[]; X2=[]; Xr=[]; YE=[]; YL=[]; SESS=[]; MOT=[];
for k = 1:numel(fields)
    s = mouse.(fields{k});
    if isfield(s,'skip') && s.skip;                continue; end
    if ~isfield(s,'data') || isempty(s.data);      continue; end
    dk = s.data;
    if ~isfield(dk,'wcDfk') || ~isfield(dk,'pwcDfk_l'); continue; end
    ref = s.d.ref; dur = s.d.params.dur; nT = size(dk.wcDfk,1);

    x1 = abs(dk.wcDfk(:,c0) - ref);                              % initial deviation

    hasMot = s.has_motion && isfield(dk,'wcmotion');
    x2 = nan(nT,1);
    if hasMot
        ws = max(1, c0_mot - round(mot_pre*Fs));
        we = min(size(dk.wcmotion,2), c0_mot + round(dur*Fs) - 1);
        x2 = mean(dk.wcmotion(1:nT, ws:we).^2, 2);               % motion energy
    end

    sa = c0_l - round(spec_pre_s*Fs);  sb = c0_l + round(spec_post_s*Fs);
    xr = nan(nT,1);
    for t = 1:nT
        seg   = double(dk.pwcDfk_l(t, sa:sb));
        xr(t) = fd_bp(seg,Fs,hi_bnd(1),hi_bnd(2)) / max(fd_bp(seg,Fs,tot_bnd(1),tot_bnd(2)), eps);
    end                                                          % relative 2-4 Hz

    yE = sqrt(mean((dk.wcDfk(1:nT,eE) - ref).^2, 2));
    yL = sqrt(mean((dk.wcDfk(1:nT,lL) - ref).^2, 2));

    X1=[X1;x1]; X2=[X2;x2]; Xr=[Xr;xr]; YE=[YE;yE]; YL=[YL;yL]; %#ok<AGROW>
    SESS=[SESS;repmat(k,nT,1)]; MOT=[MOT;repmat(hasMot,nT,1)];  %#ok<AGROW>
end
MOT = logical(MOT);

okAll = all(isfinite([X1 Xr YE YL]),2);                 % 2-factor pool (every session)
okMot = okAll & MOT & isfinite(X2);                     % 3-factor pool (motion-complete)
fprintf('\n[F4P1] pools: %d trials / %d sessions (2-factor, all)  |  %d trials / %d sessions (3-factor, motion)\n', ...
    nnz(okAll), numel(unique(SESS(okAll))), nnz(okMot), numel(unique(SESS(okMot))));

%% [F4P1-DECOMP] -------------------------------------------------------------------
Z  = zscore([X1(okMot), X2(okMot), Xr(okMot)]);
Yw = {YE(okMot), YL(okMot)};
fac_lbl = {'Init dev','Motion','Rel 2-4 Hz'};  fac_full = {'Initial deviation','Motion energy','Relative 2-4 Hz'};
win_lbl = {'Early 0-1 s','Late 1-3 s'};
nF = 3; nW = 2; n = size(Z,1);

Pr = nan(nF,nW); PrCI = nan(nF,nW,2); Rfull = nan(1,nW);
for o = 1:nW
    y = zscore(Yw{o});  rf = fitR2(Z,y);  Rfull(o) = rf;
    for j = 1:nF, Pr(j,o) = rf - fitR2(Z(:,setdiff(1:nF,j)), y); end
    bp = nan(FD_BOOT,nF);
    for b = 1:FD_BOOT
        ib = randsample(n,n,true); Xb = Z(ib,:); yb = y(ib); rfb = fitR2(Xb,yb);
        for j = 1:nF, bp(b,j) = rfb - fitR2(Xb(:,setdiff(1:nF,j)), yb); end
    end
    ci = prctile(bp,[2.5 97.5],1);
    PrCI(:,o,1) = ci(1,:).';  PrCI(:,o,2) = ci(2,:).';
end

fprintf('\n[F4P1] unique (partial) R^2, %d CL trials / %d sessions\n', n, numel(unique(SESS(okMot))));
fprintf('  %-20s %22s %22s\n','factor',win_lbl{:});
for j = 1:nF
    fprintf('  %-20s %8.3f [%.3f %.3f] %8.3f [%.3f %.3f]\n', fac_full{j}, ...
        Pr(j,1), PrCI(j,1,1), PrCI(j,1,2), Pr(j,2), PrCI(j,2,1), PrCI(j,2,2));
end
fprintf('  %-20s %8.3f%22s%8.3f\n','FULL MODEL R^2', Rfull(1), '', Rfull(2));
fprintf('  init-dev collapse early->late : %.3f -> %.3f  (%.1fx)\n', Pr(1,1), Pr(1,2), Pr(1,1)/max(Pr(1,2),eps));
fprintf('  delta share of full model     : early %.0f%% -> late %.0f%%\n', ...
    100*Pr(3,1)/max(Rfull(1),eps), 100*Pr(3,2)/max(Rfull(2),eps));

%% [F4P1-FIG] ----------------------------------------------------------------------
gE = [0.45 0.75 0.50];  gL = [0.10 0.45 0.20];    % early(light)/late(dark) green -- matches
cols = [gE; gL];                                  % factor_slope_initdev's window idiom
bw = 0.36;  xc = 1:nF;

fig = paperFig(6,4); ax = gca; hold(ax,'on');
yline(ax,0,'-','Color',[0.6 0.6 0.6],'LineWidth',0.5,'HandleVisibility','off');
hB = gobjects(1,nW);
for o = 1:nW
    xo = xc + (o-1.5)*bw;
    hB(o) = bar(ax, xo, Pr(:,o), bw*0.92, 'FaceColor', cols(o,:), 'EdgeColor','none', ...
        'DisplayName', win_lbl{o});
    errorbar(ax, xo, Pr(:,o), Pr(:,o)-PrCI(:,o,1), PrCI(:,o,2)-Pr(:,o), 'k', ...
        'LineStyle','none','LineWidth',0.5,'CapSize',2,'HandleVisibility','off');
end
set(ax,'XTick',xc,'XTickLabel',fac_lbl,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlim(ax,[0.5 nF+0.5]);
ylabel(ax,'Unique R^2','FontSize',6,'FontWeight','bold');
yl = ylim(ax); ylim(ax,[min(yl(1),0) yl(2)+0.20*range(yl)]); yl = ylim(ax);
text(ax, nF+0.42, yl(2), sprintf('R^2_{full}  %.2f / %.2f', Rfull(1), Rfull(2)), ...
    'HorizontalAlignment','right','VerticalAlignment','top','FontSize',5,'FontWeight','bold', ...
    'Color',[0.35 0.35 0.35]);
lg = legend(ax, hB, 'Location','northoutside','Orientation','horizontal'); paperLegend(lg);
paperExport(fig, fullfile(outdir,'f4p1_error_decomp.png'));
if FD_EXPORT_PDF; paperExport(fig, fullfile(outdir,'f4p1_error_decomp.pdf')); end
close(fig);

%% [F4P1-ROBUST] -------------------------------------------------------------------
% Does gating on motion cost anything? Re-score the two power-independent factors on every
% session. If the answer barely moves, the motion bar reads as "motion does not matter" rather
% than "these are the sessions where motion happened to be recorded".
Z2 = zscore([X1(okAll), Xr(okAll)]);  Y2 = {YE(okAll), YL(okAll)};
fprintf('\n[F4P1-ROBUST] two-factor model, motion gate OFF: %d trials / %d sessions\n', ...
    nnz(okAll), numel(unique(SESS(okAll))));
fprintf('  %-12s %10s %12s %12s\n','window','full R^2','init-dev','rel 2-4 Hz');
for o = 1:nW
    y = zscore(Y2{o}); rf = fitR2(Z2,y);
    fprintf('  %-12s %10.3f %12.3f %12.3f\n', win_lbl{o}, rf, rf-fitR2(Z2(:,2),y), rf-fitR2(Z2(:,1),y));
end
fprintf('  (gated equivalents: %.3f / %.3f full, %.3f / %.3f init-dev, %.3f / %.3f delta)\n', ...
    Rfull(1), Rfull(2), Pr(1,1), Pr(1,2), Pr(3,1), Pr(3,2));
fprintf('\n[F4P1] panel -> %s\n', fullfile(outdir,'f4p1_error_decomp.png'));

%% ---- helpers ----
function p = fd_bp(seg,Fs,lo,hi)
seg = detrend(double(seg(:)).','linear'); N = numel(seg);
w = hann(N).'; P = abs(fft(seg.*w)).^2; P = P(1:floor(N/2)+1);
fr = (0:floor(N/2))*Fs/N;  p = sum(P(fr>=lo & fr<hi));
end
