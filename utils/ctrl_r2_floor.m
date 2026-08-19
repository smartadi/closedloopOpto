function r2 = ctrl_r2_floor()
%CTRL_R2_FLOOR  Minimum held-out spontaneous R^2 a contra->ipsi predictor must reach.
%
% SINGLE SOURCE OF TRUTH for the quality gate (user, 2026-08-05). A pixel set that predicts the
% ipsi site worse than this is not admitted as a Global model: the decomposition Actual = Global +
% Local assigns everything the predictor MISSES to Local, so a weak Global manufactures a large
% Local out of prediction error alone. The gate is what stops that.
%
% APPLIES TO the DEPLOYED model -- the unaffected-pixel set actually used to build Global -- not
% to the full-grid ceiling. The ceiling is reported alongside it (the difference is the price of
% stim-blindness) but is not gated.
%
% READ THIS BEFORE RAISING IT. The gate and the headline pull in opposite directions: every extra
% predictor that lifts R^2 gives Global more capacity to explain the ipsi response, which shrinks
% Local. Report the pair, never the Local share alone.
%
% History: 0.90 requested, then set to 0.85 (user, 2026-08-05) -- m4's full-grid ceiling is 0.874
% held-out and the deployed stim-blind model reaches 0.855, so 0.90 was above the measured ceiling
% of the current predictor.

r2 = 0.85;
end
