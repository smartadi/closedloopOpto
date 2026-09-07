%% ctrl_stimblind_audit.m   [SBA]  -- HOW STIM-BLIND IS EACH SESSION'S Global, really?
%
% A per-session viewer + cross-session verdict for the ONE property the Actual = Global + Local
% decomposition rests on: the Global predictor must NOT carry the laser-evoked response. If it
% does, laser drive is mislabelled "network-shared" and Local is under-reported -- the whole
% state-dependence / rejection story then rides on a contaminated split. This reads the Stage-2
% caches ONLY (no SVD reload) and answers, for every session, "is this Global actually blind?".
%
% TWO INDEPENDENT MEASURES OF BLINDNESS, both already in the cache:
%   OUTPUT side  leak = 100*mean(Global)/mean(Actual) over the stim window (trial-avg, baseline-
%                sub). A truly blind Global stays flat through the stim -> leak ~ 0. leak is the
%                fraction of the measured laser dip the Global REPRODUCES. HIGH leak = not blind.
%                (transient [0,dip] and sustained [0,dur] both reported.)
%   INPUT side   bleed_kept = median dip-score of the pixels KEPT as "unaffected" (pre-window SDs,
%                negative = still dipping). Says whether the pixels feeding Global are themselves
%                flat. bleed_worst = the single worst kept pixel.
%   plus         nAff = # pixels EXCLUDED. nAff == 0 means NOTHING was dropped -> the Global is
%                built from the whole grid incl. laser-driven pixels -> not blind BY CONSTRUCTION,
%                whatever its leak happens to be.
%
% WHY THIS IS SEPARATE FROM THE R^2 GATE. Admission uses held-out spont R^2 (predictor QUALITY).
% Blindness is a DIFFERENT axis (predictor PURITY). A session can pass R^2 yet leak badly, or be
% clean yet weak. The paper needs BOTH; this script is the purity axis the gate never checked.
%
% Run:  (no session load needed)  >> ctrl_stimblind_audit
% SECTIONS: [SBA-CFG] [SBA-LOAD] [SBA-VERDICT] [SBA-TABLE] [SBA-SUMMARY-FIG] [SBA-DETAIL-FIG]

%% [SBA-CFG] --------------------------------------------------------------------
clear SBA; SBA = struct();
SBA.pred     = 'ridge';        % which predictor variant to audit (project model = ridge)
if exist('SBA_PRED','var') && ~isempty(SBA_PRED); SBA.pred = SBA_PRED; end   % 'ridge'|'deflate' override
SBA.leakGood = 20;             % leak_sus <= this  -> "blind"   (%, sustained window)
SBA.leakOk   = 35;             % leak_sus <= this  -> "partial"; above -> "leaky"
SBA.bleedOk  = -2.0;           % bleed_kept >= this (less negative) -> kept pixels acceptably flat
here    = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true); here = fullfile(pwd,'controller-analysis'); end
dataDir = fullfile(here,'data');
figDir  = fullfile(here,'..','paper','images','predictor_saga');
if ~exist(figDir,'dir'); mkdir(figDir); end

%% [SBA-LOAD] ------------------------------------------------------------------
pat  = sprintf('ctrl_ols_ol_stimblind_%s_*.mat', SBA.pred);
files = dir(fullfile(dataDir, pat));
assert(~isempty(files), '[SBA] no %s caches in %s', pat, dataDir);
S = struct('tag',{},'R2',{},'pass',{},'nAff',{},'nKept',{},'affFrac',{}, ...
           'leakT',{},'leakS',{},'captT',{},'bleed',{},'bleedW',{},'detrend',{}, ...
           'Aa',{},'Gg',{},'Lo',{},'tt',{});
for i = 1:numel(files)
    c = load(fullfile(dataDir, files(i).name));
    nAff = nnz(c.affected);  nKept = nnz(c.unaff);
    nRel = numel(c.Aa);  tt = ((0:nRel-1) - c.pre)/c.Fs;
    S(end+1) = struct( ...                                                    %#ok<AGROW>
        'tag', c.sess_tag, 'R2', c.R2_te, 'pass', logical(c.gate_pass), ...
        'nAff', nAff, 'nKept', nKept, 'affFrac', 100*nAff/max(nAff+nKept,1), ...
        'leakT', c.leak_tran, 'leakS', c.leak_sus, 'captT', c.capt_tran, ...
        'bleed', c.bleed_kept, 'bleedW', c.bleed_worst, ...
        'detrend', isfield(c,'DETREND_FIT'), ...   % marker only; harmless if absent
        'Aa', c.Aa(:).', 'Gg', c.Gg(:).', 'Lo', c.Lo(:).', 'tt', tt);
end
[~,ord] = sort([S.leakS]);  S = S(ord);            % best-blinded first
nS = numel(S);

%% [SBA-VERDICT] ---------------------------------------------------------------
% Blindness = does Global reproduce the laser dip? Graded by SUSTAINED LEAK (the fraction of the
% measured dip the Global carries). This is the correct axis for the RIDGE project model, which
% keeps the WHOLE grid and shrinks weights -- it never excludes pixels, so nAff==0 is by design,
% NOT a failure (the base/least_affected variant is the one that drops pixels). nAff is reported
% in its own column so "whole-grid" is visible, but the verdict rides on leak. A high-leak Global
% mislabels laser drive as network-shared and under-reports Local -- that is the thing to catch.
verdict = strings(nS,1);  tier = zeros(nS,1);     % 1 blind, 2 partial, 3 leaky
for i = 1:nS
    if S(i).leakS <= SBA.leakGood
        verdict(i) = "blind";   tier(i) = 1;
    elseif S(i).leakS <= SBA.leakOk
        verdict(i) = "partial"; tier(i) = 2;
    else
        verdict(i) = "leaky";   tier(i) = 3;
    end
end
tierCol = [0.10 0.55 0.20;    % 1 blind  green
           0.85 0.60 0.10;    % 2 partial amber
           0.80 0.20 0.15];   % 3 leaky  red
cOf = @(t) tierCol(max(min(t,3),1), :);

%% [SBA-TABLE] -----------------------------------------------------------------
fprintf('\n[SBA] Stim-blindness audit -- %d %s-predictor sessions (best-blinded first)\n', nS, SBA.pred);
fprintf('     leak = %% of the laser dip REPRODUCED by Global (0 = perfectly blind)\n');
fprintf('%-22s %6s %5s | %5s %5s | %8s | %5s | %s\n', ...
    'session','R2te','gate','leakT','leakS','excluded','bleed','verdict');
fprintf('%s\n', repmat('-',1,92));
for i = 1:nS
    exclStr = ternary(S(i).nAff==0, 'whole-grid', sprintf('%d px', S(i).nAff));
    fprintf('%-22s %6.3f %5s | %4.0f%% %4.0f%% | %8s | %5.2f | %s\n', ...
        S(i).tag, S(i).R2, ternary(S(i).pass,'PASS','fail'), S(i).leakT, S(i).leakS, ...
        exclStr, S(i).bleed, verdict(i));
end
nBlind = nnz(tier==1); nPart = nnz(tier==2); nLeak = nnz(tier==3); nWhole = nnz([S.nAff]==0);
fprintf('%s\n', repmat('-',1,92));
fprintf('[SBA] verdict (by leak): %d blind (<=%g%%), %d partial, %d leaky. %d/%d sessions exclude NO pixels (whole-grid).\n', ...
    nBlind, SBA.leakGood, nPart, nLeak, nWhole, nS);
fprintf('[SBA] of the %d sessions that PASS the R^2 gate: %d blind, %d partial, %d leaky.\n', ...
    nnz([S.pass]), nnz([S.pass]&tier'==1), nnz([S.pass]&tier'==2), nnz([S.pass]&tier'==3));
rQL = corr([S.R2].', [S.leakS].', 'type','Spearman');
fprintf('[SBA] quality<->purity tension: Spearman(R^2, leak) = %+.2f  (positive => better predictors leak MORE).\n', rQL);
audit = S; for i=1:nS, audit(i).verdict = verdict(i); audit(i).tier = tier(i); end
save(fullfile(dataDir,sprintf('ctrl_stimblind_audit_%s.mat',SBA.pred)), 'audit', 'SBA');

%% [SBA-SUMMARY-FIG] -----------------------------------------------------------
f1 = figure('Color','w','Position',[60 80 1180 460]);
tl = tiledlayout(f1,1,2,'TileSpacing','compact','Padding','compact');

nexttile(tl,1); hold on;                                    % sorted leak bars
for i=1:nS, bar(i, S(i).leakS, 'FaceColor', cOf(tier(i)), 'EdgeColor','none'); end
yline(SBA.leakGood,'--','blind','Color',[0.1 0.5 0.2],'LabelHorizontalAlignment','left');
yline(SBA.leakOk,  '--','leaky','Color',[0.8 0.2 0.15],'LabelHorizontalAlignment','left');
for i=1:nS, if ~S(i).pass, text(i, S(i).leakS+2, 'x','HorizontalAlignment','center','Color','k','FontWeight','bold'); end; end
set(gca,'XTick',1:nS,'XTickLabel',shortTags({S.tag}),'XTickLabelRotation',60,'FontSize',8);
ylabel('sustained leak  (% of laser dip in Global)'); title('Blindness per session (x = fails R^2 gate)');
box off;

nexttile(tl,2); hold on;                                    % leak vs R2 -- purity vs quality
for i=1:nS
    plot(S(i).R2, S(i).leakS, 'o', 'MarkerSize',9, 'MarkerFaceColor',cOf(tier(i)), 'MarkerEdgeColor','none');
    text(S(i).R2, S(i).leakS, ['  ' char(shortTags({S(i).tag}))], 'FontSize',7,'Color',[0.3 0.3 0.3]);
end
xline(ctrl_r2_floor(),'k--','R^2 floor'); yline(SBA.leakGood,'--','Color',[0.1 0.5 0.2]);
xlabel('deployed R^2  (predictor QUALITY)'); ylabel('sustained leak %  (predictor PURITY)');
title('Quality vs blindness (want: bottom-right)'); box off;
sgtitle(f1, sprintf('[SBA] stim-blindness audit (%s)  --  %d blind / %d partial / %d leaky  |  %d/%d exclude NO pixels (whole-grid)', ...
    SBA.pred, nBlind, nPart, nLeak, nWhole, nS));
p1 = fullfile(figDir,sprintf('ctrl_stimblind_audit_%s_summary.png',SBA.pred)); exportgraphics(f1,p1,'Resolution',220);
fprintf('[SBA-FIG] -> %s\n', p1);

%% [SBA-DETAIL-FIG] ------------------------------------------------------------
nc = ceil(sqrt(nS)); nr = ceil(nS/nc);
f2 = figure('Color','w','Position',[40 40 260*nc 200*nr]);
td = tiledlayout(f2,nr,nc,'TileSpacing','compact','Padding','compact');
for i=1:nS
    ax = nexttile(td,i); hold(ax,'on');
    tt = S(i).tt; dur_s = tt(end);
    plot(ax, tt, S(i).Aa, 'k-', 'LineWidth',1.4);
    plot(ax, tt, S(i).Gg, '-', 'Color',[0.85 0.4 0.1], 'LineWidth',1.3);   % Global -- should stay flat
    plot(ax, tt, S(i).Lo, '-', 'Color',[0.1 0.5 0.85], 'LineWidth',1.1);
    patch(ax,[0 dur_s dur_s 0],[min(ylim(ax))*[1 1] max(ylim(ax))*[1 1]],[0 0 0], ...
        'FaceAlpha',0.04,'EdgeColor','none');
    xline(ax,0,'k:'); yline(ax,0,'k:'); xlim(ax,[tt(1) dur_s]); set(ax,'FontSize',7);
    title(ax, sprintf('%s | leak %.0f%% | R^2 %.2f | %s', char(shortTags({S(i).tag})), ...
        S(i).leakS, S(i).R2, verdict(i)), 'Color', cOf(tier(i)), 'FontSize',8);
end
sgtitle(f2, '[SBA] Actual (black) / Global=orange (blind wants flat through stim) / Local (blue)');
p2 = fullfile(figDir,sprintf('ctrl_stimblind_audit_%s_traces.png',SBA.pred)); exportgraphics(f2,p2,'Resolution',200);
fprintf('[SBA-FIG] -> %s\n', p2);

%% ---- local helpers ----------------------------------------------------------
function s = ternary(c,a,b), if c, s=a; else, s=b; end, end
function out = shortTags(tags)
% AL_0033_0224_e2 -> 33-0224 ; keeps the audit axes legible
out = strings(numel(tags),1);
for k=1:numel(tags)
    t = char(tags{k});
    mn = regexp(t,'AL_0(\d\d\d)_(\d\d)(\d\d)','tokens','once');
    if isempty(mn), out(k)=string(t); else, out(k)=string(sprintf('%s-%s%s', mn{1}, mn{2}, mn{3})); end
end
end
