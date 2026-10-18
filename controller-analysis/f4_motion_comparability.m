%% f4_motion_comparability.m — is Fig 4D motion comparable across sessions? [F4MC]
% User 2026-10-18: "do other sessions' Q4 even qualify as high motion?" Fig 4D bins motion
% within session on a trace that initialize_data.m z-scores over the WHOLE recording, so a
% session's Q4 means "busy for this mouse today", not busy in absolute terms. Here each trial's
% motion is mapped back to raw face-energy (motEngF, same downsample + medfilt as
% initialize_data) and expressed as fold over that session's quiet baseline (median energy of
% the whole recording). A fold is unit-free, so camera gain/ROI cancel; z does not (the SD
% grows with how much the mouse moved). Reads motEngF from the server (read-only) or the local
% motion_cache. Requires load_sessions.m. Output: _preview/f4_motion_comparability.png.

assert(exist('mouse','var') && exist('fields','var'), '[F4MC] run load_sessions.m first.');
[POOLs,~] = f4_row2_pool(mouse,fields,'mean','peri'); T = POOLs.motion;
us = unique(T.sess); nS = numel(us); PS = paperStyle();
mcDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'data','motion_cache');

R = struct('lab',{},'zq',{},'fq',{},'fold',{},'q',{},'mu',{},'sd',{},'med',{},'fracBusy',{});
for i = 1:nS
    k = us(i); M = mouse.(fields{k}); m = T.sess==k; x = T.x(m);
    tag = sprintf('%s_%s_%s', char(M.mn), char(M.td), num2str(M.en));
    fl = fullfile(mcDir,[tag '_motEngF.npy']); fs = fullfile(expPath(M.mn,M.td,M.en),'motEngF.npy');
    if isfile(fl), E = readNPY(fl); elseif isfile(fs), E = readNPY(fs); else
        warning('[F4MC] no motEngF for %s', tag); continue; end
    E = medfilt1(downsample(double(E(:)),2),5);            % = initialize_data before zscore
    mu = mean(E); sd = std(E); md = median(E);
    fold = (x*sd + mu)/md;                                 % trial mean energy / quiet baseline
    e = quantile(x,[0 .25 .5 .75 1]); e([1 end]) = [-inf inf]; q = discretize(x,e);
    R(end+1) = struct('lab',sprintf('s%d %s',k,strrep(char(M.mn),'AL_','')), ...
        'zq',arrayfun(@(b) mean(x(q==b)),1:4), 'fq',arrayfun(@(b) median(fold(q==b)),1:4), ...
        'fold',fold,'q',q,'mu',mu,'sd',sd,'med',md,'fracBusy',mean(E > 2*md)); %#ok<SAGROW>
end
nR = numel(R);
fprintf('\n[F4MC] trial motion by within-session quartile (z = whole-recording z; fold = energy / session median)\n');
fprintf('%-10s | %-27s | %-27s | sd/med  rec>2x\n','session','Q1..Q4 mean z','Q1..Q4 median fold');
for i = 1:nR, r = R(i);
    fprintf('%-10s | %s| %s| %5.2f  %4.0f%%\n', r.lab, sprintf('%+6.2f ',r.zq), sprintf('%6.2f ',r.fq), r.sd/r.med, 100*r.fracBusy);
end
% common, cross-session criterion: pool all trials' fold, call the top quartile of the POOL "high"
allF = vertcat(R.fold); thr = quantile(allF,0.75);
fprintf('\npooled fold Q4 threshold = %.2f x baseline\n', thr);
for i = 1:nR, r = R(i);
    fprintf('%-10s  own-Q4 trials above pooled threshold: %3.0f%%   (all trials above: %3.0f%%)\n', ...
        r.lab, 100*mean(r.fold(r.q==4) > thr), 100*mean(r.fold > thr));
end

% ---- figure: per-session distribution of trial fold, own quartile edges marked ----------------
fig = figure('Color','w','Units','centimeters','Position',[2 2 18 8]); ax = axes(fig); hold(ax,'on');
for i = 1:nR, r = R(i);
    for b = 1:4
        v = r.fold(r.q==b); c = interp1([1 4],[0.75 0.75 0.75; 0.85 0.33 0.10],b);
        scatter(ax, i + 0.28*(rand(size(v))-0.5), v, 6, c, 'filled', 'MarkerFaceAlpha',0.6);
    end
    plot(ax, i+[-0.3 0.3], [1 1]*min(r.fold(r.q==4)), 'k-', 'LineWidth',1);   % own Q4 lower edge
end
yline(ax, thr, 'r--', sprintf('pooled Q4 (%.1fx)',thr), 'FontSize',6, 'LabelHorizontalAlignment','left');
yline(ax, 1, 'k:');
set(ax,'YScale','log','XTick',1:nR,'XTickLabel',{R.lab},'FontSize',6,'Box','off'); xtickangle(ax,40);
ylabel(ax,'Trial motion energy / session baseline (fold, log)');
title(ax,'Fig 4D motion: trial motion per session, grey Q1 \rightarrow orange Q4 (own edges); black bar = own Q4 lower edge','FontSize',7);
out = fullfile(fileparts(mfilename('fullpath')),'_preview'); if ~exist(out,'dir'), mkdir(out); end
exportgraphics(fig, fullfile(out,'f4_motion_comparability.png'), 'Resolution',300);
fprintf('[F4MC] -> %s\n', fullfile(out,'f4_motion_comparability.png'));

% ---- rebin on the COMMON threshold (high = fold > pooled Q4), OL vs CL within session ---------
% Sessions need >= 4 high trials per condition. Tests the CL/OL ratio (attenuation) high vs low.
lr = nan(nR,2); dO = nan(nR,1); dC = dO;
for i = 1:nR
    m = find(T.sess==us(i)); y = T.y(m); cl = T.cond(m)=='CL'; hi = R(i).fold > thr;
    if nnz(hi&~cl) < 4 || nnz(hi&cl) < 4, continue; end
    oL = mean(y(~hi&~cl)); cL = mean(y(~hi&cl)); oH = mean(y(hi&~cl)); cH = mean(y(hi&cl));
    lr(i,:) = log([cL/oL cH/oH]); dO(i) = oH-oL; dC(i) = cH-cL;
    fprintf('%-10s OL %.2f->%.2f  CL %.2f->%.2f  CL/OL %.2f->%.2f\n', R(i).lab, oL,oH, cL,cH, cL/oL, cH/oH);
end
ok = all(isfinite(lr),2); dl = lr(ok,2)-lr(ok,1);
fprintf('[F4MC] common threshold: CL/OL lower in high motion %d/%d, GM x%.2f, signrank p=%.3g\n', ...
    nnz(dl<0), nnz(ok), exp(mean(dl)), signrank(dl));
fprintf('[F4MC] OL rises %d/%d p=%.3g | CL falls %d/%d p=%.3g\n', nnz(dO(ok)>0), nnz(ok), signrank(dO(ok)), ...
    nnz(dC(ok)<0), nnz(ok), signrank(dC(ok)));
