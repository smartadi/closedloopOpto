% controller-analysis/f4_circularity_checks.m
% ============================================================================
% FIG 4 -- is the band-power state result circular?  [F4C]   (2026-10-10)
%
% The Fig-4 rel/abs delta states are measured on the controlled readout over [-2,+3) s, which
% shares 70 of its 175 samples with the [+1,+3] s error window, and the loop shapes that trace.
% Two candidate controls:
%   LASER-OFF WINDOW: the same readout states over [-2,0) ('pre2'), before the laser and the
%     controller act, all 15 sessions. No model needed. CONTROL row (the primary window stays
%     the locked [-2,+3); user decision 2026-10-02).
%   GLOBAL G (user question 2026-10-10): the same states on the contra-predicted Global
%     (f4_gstate_build.m caches, 13 sessions). Verified 2026-10-10 NOT to escape the problem:
%     G keeps the sample overlap, carries 6-42% of the open-loop laser dip, and in CL tracks
%     the readout's extra in-stimulation 2-4 Hz power (check b). In the laser-off window G and
%     the readout give the same numbers, so G adds nothing there. Kept as a sensitivity row.
% Every row is fitted twice: the locked model (utils/f4_row2_fit: random intercepts + random
% cond slope) and a SENSITIVITY model that adds a random state slope per session
% (1+cond+xw|sess), because the locked model's state-slope SEs are trial-level.
% Needs: load_sessions.m (mouse/fields). Writes data/f4_circularity_checks.mat.
% ============================================================================
assert(exist('mouse','var') && exist('fields','var'), '[F4C] run load_sessions.m first.');
bpRoot = 'C:\Users\aditya\Documents\projects\brain_paper';
[Pp,~] = f4_row2_pool(mouse, fields, 'mean', 'peri', true);
[Pq,~] = f4_row2_pool(mouse, fields, 'mean', 'pre2', true);
sG = unique(Pp.Gdelta.sess);  sub = @(T) T(ismember(T.sess, sG), :);
ROWS = { 'peri  readout initdev (locked)', Pp.initdev;   % Table 1 rows 1-2: random-slope sensitivity only
         'peri  readout motion  (locked)', Pp.motion;
         'peri  readout rel 2-4 (locked)', Pp.delta;
         'peri  readout abs 1-4 (locked)', Pp.absdelta;
         'pre2  readout rel 2-4',          Pq.delta;
         'pre2  readout abs 1-4',          Pq.absdelta;
         'peri  Global  rel 2-4',          Pp.Gdelta;
         'peri  Global  abs 1-4',          Pp.Gabsdelta;
         'pre2  Global  rel 2-4',          Pq.Gdelta;
         'pre2  Global  abs 1-4',          Pq.Gabsdelta;
         'peri  readout rel 2-4 (G13)',    sub(Pp.delta);
         'peri  readout abs 1-4 (G13)',    sub(Pp.absdelta) };
FIT = struct('name',{},'nS',{},'nT',{},'R',{},'RS',{});
hdr = '%-31s %3s %5s | %-29s | %-29s | %-27s\n';
fprintf(['\n[F4C] ' hdr], 'state','nS','nT','PREDICTABILITY (OL slope)','REGULARIZABILITY (CL slope)','ATTENUATION (log CL/OL)');
for i = 1:size(ROWS,1)
    T = ROWS{i,2};
    R  = rmfield(f4_row2_fit(T),'lme');
    RS = fit_rs(T);
    FIT(end+1) = struct('name',ROWS{i,1},'nS',numel(unique(T.sess)),'nT',height(T),'R',R,'RS',RS); %#ok<SAGROW>
    fprintf('%-31s %3d %5d | %+.3f [%+.2f,%+.2f] p=%-7.2g | %+.3f [%+.2f,%+.2f] p=%-7.2g | %+.3f [%+.2f,%+.2f] p=%-6.2g\n', ...
        ROWS{i,1}, FIT(end).nS, FIT(end).nT, R.slope, R.slopeCI, R.slopeP, R.reg, R.regCI, R.regP, R.att, R.attCI, R.attP);
    fprintf('%-31s %9s | %+.3f [%+.2f,%+.2f] p=%-7.2g | %+.3f [%+.2f,%+.2f] p=%-7.2g | %+.3f [%+.2f,%+.2f] p=%-6.2g\n', ...
        '   + random state slope', '', RS.slope, RS.slopeCI, RS.slopeP, RS.reg, RS.regCI, RS.regP, RS.att, RS.attCI, RS.attP);
end

% ---- does G carry the in-stimulation CL-OL change of the readout? (check b) ---------------
% Per session: CL-minus-OL mean state during [-2,+3) minus the same before onset [-2,0), in SD
% of the pre-window state. Leak common to OL and CL cancels, so this is a LOWER bound on how far
% G is from laser-free; it cannot separate optical leak from a real bilateral response (both
% are caused by stimulation).
CHK = struct('k',{},'dGrel',{},'dArel',{},'dGabs',{},'dAabs',{},'rhoPre',{});
for k = sG(:).'
    g  = @(P,nm,c) P.(nm).x(P.(nm).sess==k & P.(nm).cond==c);
    sh = @(nm) (mean(g(Pp,nm,'CL'))-mean(g(Pp,nm,'OL')) - (mean(g(Pq,nm,'CL'))-mean(g(Pq,nm,'OL')))) ...
               / std([g(Pq,nm,'OL'); g(Pq,nm,'CL')]);
    % (a) G vs readout rel-delta before onset, pooled OL+CL. IN-SAMPLE: the ridge training mask
    % runs to 2 frames before each onset, so this mostly shows the fit, not an independent test.
    xa = [g(Pq,'Gdelta','OL'); g(Pq,'Gdelta','CL')]; xb = [g(Pq,'delta','OL'); g(Pq,'delta','CL')];
    rp = NaN; if numel(xa)==numel(xb), rp = corr(xa, xb, 'type','Spearman','rows','complete'); end
    CHK(end+1) = struct('k',k,'dGrel',sh('Gdelta'),'dArel',sh('delta'),'dGabs',sh('Gabsdelta'), ...
        'dAabs',sh('absdelta'),'rhoPre',rp); %#ok<SAGROW>
end
C = struct2table(CHK);
fprintf('\n[F4C] in-stimulation CL-OL change (pre-SD units), median over %d sessions:\n', height(C));
fprintf('  rel 2-4: Global %+.2f (signrank p=%.2g)  readout %+.2f (p=%.2g)  per-session G/readout median %.2f, Spearman %.2f\n', ...
    median(C.dGrel), signrank(C.dGrel), median(C.dArel), signrank(C.dArel), median(C.dGrel./C.dArel), ...
    corr(C.dGrel, C.dArel, 'type','Spearman'));
fprintf('  abs 1-4: Global %+.2f (p=%.2g)  readout %+.2f (p=%.2g)\n', median(C.dGabs), signrank(C.dGabs), ...
    median(C.dAabs), signrank(C.dAabs));
fprintf('  G vs readout rel 2-4 before onset (in-sample), Spearman median %.2f\n', median(C.rhoPre));
save(fullfile(bpRoot,'data','f4_circularity_checks.mat'),'FIT','CHK');
fprintf('[F4C] -> data/f4_circularity_checks.mat\n');

function RS = fit_rs(T)
% f4_row2_fit with a random STATE slope per session added: (1+cond+xw|sess) + (1|mouse).
T.xw = zeros(height(T),1); us = unique(T.sess);
for i = 1:numel(us), m = T.sess==us(i); T.xw(m) = T.x(m)-mean(T.x(m)); end
T.xw = T.xw/std(T.xw); nS = numel(us);
f = 'y ~ cond*xw + (1+cond+xw|sess) + (1|mouse)';
RS = struct();
[RS.slope,RS.slopeCI,RS.slopeP] = term(T, {'OL','CL'}, false, f, 'xw', nS);
[RS.reg,  RS.regCI,  RS.regP]   = term(T, {'CL','OL'}, false, f, 'xw', nS);
[RS.att,  RS.attCI,  RS.attP]   = term(T, {'OL','CL'}, true,  f, 'cond_CL:xw', nS);
end
function [e,ci,p] = term(T, ord, logy, f, nm, nS)
T.cond = reordercats(T.cond, ord);
if logy, T = T(T.y>0,:); T.y = log(T.y); end
try
    l = fitlme(T, f, 'FitMethod','REML');
    [~,~,C] = fixedEffects(l,'DFMethod','Satterthwaite'); C = lmm_cluster_df(dataset2table_safe(C), nS);
    k = find(strcmp(cellstr(string(C.Name)), nm), 1);
    e = C.Estimate(k); ci = [C.LowerC(k) C.UpperC(k)]; p = C.pValueC(k);
catch ME
    warning('[F4C] random-slope fit failed (%s)', ME.message); e = NaN; ci = [NaN NaN]; p = NaN;
end
end
