function R = cl_olcl_lmm(y, cond, sess, mouse)
% CL_OLCL_LMM  Fig-3 OL-vs-CL session-aware LMM (single source, no-state analog of f4_row2_fit).
% Fits the Nick-approved, Fig-4-matching model to per-TRIAL data:
%
%     y ~ cond + (1+cond|sess) + (1|mouse)      (random OL->CL slope per session)
%
% falling back to  y ~ cond + (1|sess) + (1|mouse)  if the random-slope model
% fails to converge. cond is releveled to {OL,CL} so the reported effect is CL-OL.
%
%   R = cl_olcl_lmm(y, cond, sess, mouse)
%     y     : per-trial response (e.g. trial RMSE, or log windowed variance-contribution)
%     cond  : per-trial 'OL'/'CL' (cellstr / string / categorical)
%     sess  : per-trial session id (numeric or categorical)
%     mouse : per-trial mouse id  (cellstr / string / categorical)
%
% Returns R with:
%   gap / gapCI / gapP   cond_CL fixed effect (CL - OL; <0 = CL lower)
%   mouseSD              between-mouse random-intercept SD (~0 => not mouse-driven)
%   sessSD               session random-intercept SD
%   randslope            true if the random-slope model was used
%   n / nSess / nMouse   counts
%   lme                  the fitted model object
%
% This is the Fig-3 counterpart of utils/f4_row2_fit.m: same random-effects
% structure and fallback, minus the state (xw) term. Use it wherever a Fig-3
% panel or the Methods reports an OL-vs-CL p, so every figure shares one recipe.

tb = table(y(:), categorical(cellstr(string(cond(:)))), ...
    categorical(sess(:)), categorical(cellstr(string(mouse(:)))), ...
    'VariableNames', {'y','cond','sess','mouse'});
tb.cond = reordercats(tb.cond, {'OL','CL'});   % cond_CL = CL - OL

try   lme = fitlme(tb, 'y ~ cond + (1+cond|sess) + (1|mouse)'); rs = true;
catch, lme = fitlme(tb, 'y ~ cond + (1|sess) + (1|mouse)');      rs = false; end

C = lme.Coefficients; nm = cellstr(C.Name); gi = find(strcmp(nm,'cond_CL'),1);

% variance components (robust to the titled-dataset return shape)
mouseSD = NaN; sessSD = NaN;
try
    [~,~,S3] = covarianceParameters(lme);
    for j = 1:numel(S3)
        Tj = dataset2table_safe(S3{j});
        if ~ismember('Group', Tj.Properties.VariableNames), continue; end
        g = string(Tj.Group); ty = string(Tj.Type);
        n1 = string(Tj.Name1); n2 = string(Tj.Name2);
        isInt = (n1=="(Intercept)") & (n2=="(Intercept)") & (ty=="std");
        im = find(g=="mouse" & isInt, 1); if ~isempty(im), mouseSD = Tj.Estimate(im); end
        is = find(g=="sess"  & isInt, 1); if ~isempty(is), sessSD  = Tj.Estimate(is); end
    end
catch
end

R = struct('gap',C.Estimate(gi), 'gapCI',[C.Lower(gi) C.Upper(gi)], 'gapP',C.pValue(gi), ...
    'mouseSD',mouseSD, 'sessSD',sessSD, 'randslope',rs, ...
    'n',height(tb), 'nSess',numel(categories(tb.sess)), 'nMouse',numel(categories(tb.mouse)), ...
    'lme',lme);
end

function T = dataset2table_safe(D)
% covarianceParameters returns titled-datasets (not tables) in some releases.
try
    if istable(D), T = D; else, T = dataset2table(D); end
catch
    T = table();   % Group column absent -> caller skips
end
end
