% controller-analysis/f4_rel_abs_checks.m
% ============================================================================
% FIG 4 -- is relative 2-4 Hz power its own state, or absolute delta + the loop?  [F4RA]
% (2026-10-11)
%
% User hypothesis (2026-10-11): "rel 2-4 is already a case of abs delta and maybe controller
% effect anyways". Three tests, all on the Fig-4 trial pool (f4_row2_pool) and the adopted
% random-state-slope model:
%   (1) OVERLAP   within-session correlation of rel 2-4 Hz with abs 1-4 Hz, per condition and
%                 window (peri [-2,+3) vs laser-off pre2 [-2,0)).
%   (2) JOINT     y ~ cond*(xa + xr) + (1+cond+xa+xr|sess) + (1|mouse): does rel predict OL / CL
%                 error once abs is in the model? Also rel orthogonalised to abs within session.
%   (3) LOOP      does the controller itself raise rel / abs power? Per session, CL minus OL state
%                 in the laser-off window (should be ~0: same pre-onset brain) and in the peri
%                 window (contains the stimulation), and the within-trial peri-minus-pre2 change.
%   (4) SPECTRUM  CL/OL power ratio by frequency band, stimulation [0,+3) vs laser-off [-2,0).
% Needs: load_sessions.m (mouse/fields). Writes data/f4_rel_abs_checks.mat.
% ============================================================================
assert(exist('mouse','var') && exist('fields','var'), '[F4RA] run load_sessions.m first.');
bpRoot = 'C:\Users\aditya\Documents\projects\brain_paper';
[Pp,~] = f4_row2_pool(mouse, fields, 'mean', 'peri', false);
[Pq,~] = f4_row2_pool(mouse, fields, 'mean', 'pre2', false);
assert(isequaln(Pp.delta.y, Pp.absdelta.y, Pq.delta.y, Pq.absdelta.y) && ...
       isequal(Pp.delta.sess, Pq.delta.sess) && isequal(Pp.delta.cond, Pq.delta.cond), ...
       '[F4RA] rel/abs/peri/pre2 pools are not row-aligned');
WIN = struct('name',{'peri','pre2'},'P',{Pp,Pq});
OUT = struct();

%% (1) OVERLAP -----------------------------------------------------------------------------
fprintf('\n[F4RA] (1) within-session Spearman rho(rel 2-4, abs 1-4)\n');
for w = 1:2
    T = WIN(w).P.delta; xa = WIN(w).P.absdelta.x; us = unique(T.sess);
    for c = ["OL" "CL"]
        r = nan(numel(us),1);
        for i = 1:numel(us)
            m = T.sess==us(i) & T.cond==c;
            if sum(m) > 5, r(i) = corr(T.x(m), xa(m), 'Type','Spearman'); end
        end
        OUT.overlap.(WIN(w).name).(char(c)) = r;
        fprintf('   %-4s %s: median rho %+.2f  [range %+.2f..%+.2f]  (%d sessions)\n', WIN(w).name, c, ...
            median(r,'omitnan'), min(r), max(r), sum(isfinite(r)));
    end
end

%% (2) JOINT model -------------------------------------------------------------------------
fprintf('\n[F4RA] (2) joint model y ~ cond*(xa + xr), random state slopes per session\n');
for w = 1:2
    T = WIN(w).P.delta;  T.xr = zwin(T.x, T.sess);  T.xa = zwin(WIN(w).P.absdelta.x, T.sess);
    T.cond = reordercats(T.cond, {'OL','CL'});
    % rel orthogonalised to abs within session (what rel carries that abs does not)
    T.xrp = zeros(height(T),1); us = unique(T.sess);
    for i = 1:numel(us), m = T.sess==us(i); b = [ones(sum(m),1) T.xa(m)] \ T.xr(m); T.xrp(m) = T.xr(m) - [ones(sum(m),1) T.xa(m)]*b; end
    T.xrp = T.xrp / std(T.xrp);
    J = struct();
    [J.relOL, J.relCL, J.relAtt, J.reRel] = joint_terms(T, 'xr');
    [J.absOL, J.absCL, J.absAtt, J.reAbs] = joint_terms(T, 'xa');
    % single-state fit on the orthogonalised rel (same model as Table 1)
    Tp = T(:, {'y','cond','sess','mouse'}); Tp.x = T.xrp;  Rp = rmfield(f4_row2_fit(Tp), 'lme');
    J.perp = Rp;
    OUT.joint.(WIN(w).name) = J;
    fprintf('   %-4s rel | OL %+.3f p=%-7.2g CL %+.3f p=%-7.2g att %+.3f p=%-7.2g  (%s)\n', WIN(w).name, ...
        J.relOL(1), J.relOL(2), J.relCL(1), J.relCL(2), J.relAtt(1), J.relAtt(2), J.reRel);
    fprintf('   %-4s abs | OL %+.3f p=%-7.2g CL %+.3f p=%-7.2g att %+.3f p=%-7.2g\n', WIN(w).name, ...
        J.absOL(1), J.absOL(2), J.absCL(1), J.absCL(2), J.absAtt(1), J.absAtt(2));
    fprintf('   %-4s rel _|_ abs (Table-1 model) | OL %+.3f p=%-7.2g CL %+.3f p=%-7.2g att %+.3f p=%-7.2g\n', WIN(w).name, ...
        Rp.slope, Rp.slopeP, Rp.reg, Rp.regP, Rp.att, Rp.attP);
end

%% (3) LOOP: does the controller move the state itself? ----------------------------------
fprintf('\n[F4RA] (3) state shift CL - OL per session (raw units; signrank over sessions)\n');
for s = ["delta" "absdelta"]
    us = unique(Pp.(s).sess);
    d = nan(numel(us), 3);   % [pre2 CL-OL, peri CL-OL, (peri-pre2) CL-OL]
    for i = 1:numel(us)
        m = Pp.(s).sess==us(i); o = m & Pp.(s).cond=='OL'; c = m & Pp.(s).cond=='CL';
        xp = Pp.(s).x; xq = Pq.(s).x; sd = std(xq(m));     % scale: laser-off SD of that session
        d(i,1) = (mean(xq(c)) - mean(xq(o))) / sd;
        d(i,2) = (mean(xp(c)) - mean(xp(o))) / sd;
        d(i,3) = (mean(xp(c)-xq(c)) - mean(xp(o)-xq(o))) / sd;
    end
    OUT.loop.(char(s)) = d;
    lab = {'laser-off [-2,0)   CL-OL', 'peri [-2,+3)      CL-OL', 'within-trial change CL-OL'};
    for j = 1:3
        fprintf('   %-8s %-27s median %+.2f SD  %2d/%d sessions >0  p=%.2g\n', s, lab{j}, ...
            median(d(:,j)), sum(d(:,j)>0), numel(us), signrank(d(:,j)));
    end
end
%% (4) LOOP, spectrally: closed-to-open-loop power ratio by frequency ------------------------
% Per session, mean PSD of the controlled readout over the stimulation window [0,+3) s and
% the laser-off window [-2,0) s, CL / OL. Ratio > 1 at a frequency = the loop leaves MORE power
% there than the open-loop input does (a sensitivity peak); laser-off should sit at ~1.
fprintf('\n[F4RA] (4) CL/OL power ratio by band, median over sessions [IQR] (signrank of log ratio)\n');
Fs = 35; c0_l = 106; fg = 0:0.05:12;
BANDS = [0.4 1; 1 2; 2 4; 4 6; 6 10];
WSP = struct('name',{'stim [0,+3)','laser-off [-2,0)'},'off',{0:104, -70:-1});
ratio = nan(numel(fields), numel(fg), 2);
for k = 1:numel(fields)
    M = mouse.(fields{k}); if ~isfield(M,'data'), continue; end; d = M.data;
    if ~isfield(d,'pncDfk_l') || isempty(d.pncDfk_l) || isempty(d.pwcDfk_l), continue; end
    for w = 1:2
        cols = c0_l + WSP(w).off;
        ratio(k,:,w) = mean_psd(d.pwcDfk_l(:,cols), Fs, fg) ./ mean_psd(d.pncDfk_l(:,cols), Fs, fg);
    end
end
ok = all(isfinite(ratio(:,:,1)),2); ratio = ratio(ok,:,:);
for w = 1:2
    for b = 1:size(BANDS,1)
        m = fg >= BANDS(b,1) & fg < BANDS(b,2);
        rb = mean(ratio(:,m,w), 2);                       % per-session band ratio
        fprintf('   %-17s %4.1f-%4.1f Hz: %.2f [%.2f %.2f]  %2d/%d sessions >1  p=%.2g\n', WSP(w).name, ...
            BANDS(b,:), median(rb), prctile(rb,25), prctile(rb,75), sum(rb>1), numel(rb), signrank(log(rb)));
    end
end
OUT.spec = struct('f',fg,'ratio',ratio,'bands',BANDS,'windows',{{WSP.name}});
save(fullfile(bpRoot,'data','f4_rel_abs_checks.mat'), 'OUT');
fprintf('[F4RA] -> data/f4_rel_abs_checks.mat\n');

% ------------------------------------------------------------------------------------------
function z = zwin(x, s)
% centre within session, scale by the pooled SD (same as f4_row2_fit's xw)
z = zeros(size(x)); us = unique(s);
for i = 1:numel(us), m = s==us(i); z(m) = x(m) - mean(x(m)); end
z = z / std(z);
end

function P = mean_psd(B, Fs, fg)
% Mean over trials (rows of B) of the linear-detrended, Hann-tapered periodogram, as a density
% in (dF/F)^2/Hz on the grid fg (same taper/normalisation as utils/f4_bandpow 'continuous').
B = double(B); B = B(all(isfinite(B),2), :);
N = size(B,2); w = hann(N)'; nfft = 4096;
X = detrend(B', 'linear')' .* w;
S = abs(fft(X, nfft, 2)).^2 / (Fs * sum(w.^2));
f = (0:nfft-1) * Fs / nfft; h = f <= Fs/2;
S = S(:, h); S(:, 2:end-1) = 2*S(:, 2:end-1);
P = interp1(f(h), mean(S,1), fg);
end

function [ol, cl, att, re] = joint_terms(T, nm)
% OL slope, CL slope (CL reference) and attenuation (log y) of state nm in the joint model.
% Returns [estimate p] pairs. Random-effects chain mirrors f4_row2_fit.
nS = numel(unique(T.sess));
chain = {'(1+cond+xa+xr|sess)','(1+cond+xa|sess)','(1+cond|sess)'};
ol = [NaN NaN]; cl = ol; att = ol; re = '';
for i = 1:numel(chain)
    f = ['y ~ cond*(xa + xr) + ' chain{i} ' + (1|mouse)'];
    try
        ol  = one(T, {'OL','CL'}, false, f, nm, nS);
        cl  = one(T, {'CL','OL'}, false, f, nm, nS);
        att = one(T, {'OL','CL'}, true,  f, ['cond_CL:' nm], nS);
        re = chain{i}; return
    catch
    end
end
end

function v = one(T, ord, logy, f, term, nS)
T.cond = reordercats(T.cond, ord);
if logy, T = T(T.y > 0, :); T.y = log(T.y); end
l = fitlme(T, f, 'FitMethod','REML');
[~,~,C] = fixedEffects(l, 'DFMethod','Satterthwaite'); C = lmm_cluster_df(dataset2table_safe(C), nS);
k = find(strcmp(cellstr(string(C.Name)), term), 1);
v = [C.Estimate(k) C.pValueC(k)];
end
