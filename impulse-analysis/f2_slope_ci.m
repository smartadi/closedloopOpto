% impulse-analysis/f2_slope_ci.m
% Fig-2B dose-response: per-session slope with 95% CI, to back the linearity claim
% in results.tex ("slopes ... for N sessions") which currently reports point slopes
% and no CI. Replicates dose_response.m's fit EXACTLY (linear fit through the
% per-amplitude MEANS, 0-amp gap-fill markers excluded via nzMask), then adds a CI.
% Reports two CIs per session:
%   MEAN-FIT : fit through the per-amplitude means -> matches the plotted line;
%              CI has (nAmp-2) dof (what the figure's line actually is).
%   RAW-FIT  : fit through all raw per-trial points -> proper trial n, tighter CI
%              (the reviewer-facing "slope +/- CI" with real degrees of freedom).
% Requires load_experiments.m has run (allExperiments in base workspace).
clc;
assert(exist('allExperiments','var')==1,'run load_experiments first');
nExp=numel(allExperiments);
mnAll=arrayfun(@(e) allExperiments(e).mn,1:nExp,'UniformOutput',false);
try, mouseTxt=imp_mouse_label(mnAll); catch, mouseTxt=mnAll; end
uMn=unique(string(mnAll),'stable');
fprintf('\n===== Fig-2B dose-response slopes: %d sessions from %d mice =====\n',nExp,numel(uMn));
fprintf('%-10s %-8s | %-28s | %-28s | %s\n','session','mouse','MEAN-FIT slope [95%% CI]','RAW-FIT slope [95%% CI]','R2 (mean fit)');
S=struct('mn',{},'slope_mean',{},'ci_mean',{},'slope_raw',{},'ci_raw',{},'R2',{},'nTr',{});
for e=1:nExp
    av=allExperiments(e).allVals(:); gl=allExperiments(e).groupLabels(:);
    x_raw=str2double(cellstr(gl));
    keep=x_raw>0 & isfinite(av);              % drop 0-amp gap-fills + NaNs
    av=av(keep); x=x_raw(keep);
    % --- per-amplitude means (the plotted points/line) ---
    [ug,~,idx]=unique(x,'stable');
    mv=accumarray(idx,av,[],@(v) mean(v,'omitnan'));
    mdlM=fitlm(ug,mv); sM=mdlM.Coefficients.Estimate(2); ciM=coefCI(mdlM); ciM=ciM(2,:);
    R2=mdlM.Rsquared.Ordinary;
    % --- raw per-trial fit ---
    mdlR=fitlm(x,av); sR=mdlR.Coefficients.Estimate(2); ciR=coefCI(mdlR); ciR=ciR(2,:);
    fprintf('%-10s %-8s | %+.3f [%+.3f, %+.3f]      | %+.3f [%+.3f, %+.3f]      | %.3f\n', ...
        allExperiments(e).mn, mouseTxt{e}, sM,ciM(1),ciM(2), sR,ciR(1),ciR(2), R2);
    S(e)=struct('mn',allExperiments(e).mn,'slope_mean',sM,'ci_mean',ciM, ...
        'slope_raw',sR,'ci_raw',ciR,'R2',R2,'nTr',numel(av));
end
fprintf('\n-- copy-ready (MEAN-FIT, matches the plotted line) --\n');
fprintf('slopes: %s\n', strjoin(arrayfun(@(s) sprintf('%+.2f [%.2f, %.2f]',s.slope_mean,s.ci_mean(1),s.ci_mean(2)),S,'UniformOutput',false),'; '));
fprintf('R2:     %s\n', strjoin(arrayfun(@(s) sprintf('%.2f',s.R2),S,'UniformOutput',false),', '));
fprintf('-- copy-ready (RAW-FIT, proper trial n) --\n');
fprintf('slopes: %s\n', strjoin(arrayfun(@(s) sprintf('%+.2f [%.2f, %.2f]',s.slope_raw,s.ci_raw(1),s.ci_raw(2)),S,'UniformOutput',false),'; '));
fprintf('nTrials: %s\n', strjoin(arrayfun(@(s) sprintf('%d',s.nTr),S,'UniformOutput',false),', '));
