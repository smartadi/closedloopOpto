function S = ctrl_seed_fc_story_summary(sessions)
%CTRL_SEED_FC_STORY_SUMMARY  Cross-session summary of ctrl_seed_fc_story (hub #32).
%   Per session: delta r (stim - base, mean over spots > 0.5 mm from the site) for raw / laser-removed /
%   GSR+laser-removed, OL and CL; and delta coherence (stim - base) vs frequency (mean over the same spots).
%   Stats across sessions: Wilcoxon signed-rank vs 0, and CL vs OL paired.
% OUT  paper/images/supp_seedfc/seedfc_story_summary.png (exploratory, not a paper panel)
if nargin < 1
    sessions = {'AL_0033_0212_e2','AL_0033_0224_e2','AL_0033_0226_e2','AL_0033_0304_e1','AL_0033_0305_e2', ...
                'AL_0033_0320_e4','AL_0033_0415_e2','AL_0033_0419_e1','AL_0039_0419_e1','AL_0039_0420_e1', ...
                'AL_0039_0420_e2','AL_0039_0430_e3'};
end
here = fileparts(mfilename('fullpath'));
vn = {'raw', 'las', 'gsr_las'}; cn = {'OL', 'CL'}; nS = numel(sessions);
for i = 1:nS
    R = load(fullfile(here, 'data', sprintf('ctrl_seed_fc_story_%s.mat', sessions{i})));
    if i == 1, f = R.f; end
    for c = 1:2
        for v = 1:3
            S.dr.(cn{c})(i, v) = R.(cn{c}).dr.(vn{v});
            dc = mean(R.(cn{c}).cstim.coh.(vn{v})(R.far, :), 1) - mean(R.(cn{c}).cbase.coh.(vn{v})(R.far, :), 1);
            S.dcoh.(cn{c}).(vn{v})(i, :) = interp1(R.f, dc, f, 'linear', NaN);
        end
    end
    S.gain(i, :) = R.CL.gain_r; S.shuf(i) = mean(R.CL.shuf_r); S.hemo(i) = R.hemo; S.nTr(i, :) = R.nTr;
    S.mouse(i) = str2double(sessions{i}(6:7));
end
S.f = f; S.sessions = sessions; S.gains = R.opt.gains;
fprintf('\n[SUMMARY] %d sessions (AL_0033 %d, AL_0039 %d); mean delta r (stim - base), signed-rank p vs 0\n', ...
    nS, nnz(S.mouse == 33), nnz(S.mouse == 39));
for v = 1:3
    for c = 1:2
        x = S.dr.(cn{c})(:, v);
        fprintf('  %-8s %s: %+.3f +- %.3f (SEM)  p=%.4f  [%d/%d sessions < 0]\n', vn{v}, cn{c}, mean(x), std(x)/sqrt(nS), ...
            signrank(x), nnz(x < 0), nS);
    end
    fprintf('  %-8s CL vs OL paired p=%.4f\n', vn{v}, signrank(S.dr.CL(:, v), S.dr.OL(:, v)));
end
fprintf('  CL raw -> las: drop shrinks in %d/%d sessions, p=%.4f\n', nnz(S.dr.CL(:,2) > S.dr.CL(:,1)), nS, ...
    signrank(S.dr.CL(:,2), S.dr.CL(:,1)));
fprintf('  shuffle < true laser removal in %d/%d sessions\n', nnz(S.shuf(:) < S.gain(:, S.gains == 1)), nS);
lo = f < 2; hi = f >= 4;
for v = 1:3
    for c = 1:2
        a = mean(S.dcoh.(cn{c}).(vn{v})(:, lo), 2); b = mean(S.dcoh.(cn{c}).(vn{v})(:, hi), 2);
        fprintf('  dcoh %-8s %s: <2 Hz %+.3f (p=%.3f) | >=4 Hz %+.3f (p=%.3f)\n', vn{v}, cn{c}, mean(a), signrank(a), mean(b), signrank(b));
    end
end

% ---- exploratory figure ----
fg = figure('Color', 'w', 'Position', [80 80 1200 380]);
col = struct('OL', [0.85 0.2 0.15], 'CL', [0.15 0.35 0.8]);              % locked: OL red, CL blue
subplot(1, 3, 1); hold on
for c = 1:2
    x = (1:3) + (c - 1.5) * 0.25;
    plot(x, S.dr.(cn{c}).', '-', 'Color', [col.(cn{c}) 0.25]);
    errorbar(x, mean(S.dr.(cn{c})), std(S.dr.(cn{c}))/sqrt(nS), 'o', 'Color', col.(cn{c}), ...
        'MarkerFaceColor', col.(cn{c}), 'LineWidth', 1.2, 'CapSize', 3);
end
yline(0, 'k:'); set(gca, 'XTick', 1:3, 'XTickLabel', {'raw', 'laser removed', '+ GSR'}); ylabel('\Deltar (stim - base)');
title(sprintf('Site-cortex coupling, %d sessions', nS)); legend({'', '', '', '', '', '', '', '', '', '', '', '', 'OL'}, 'Visible', 'off');
text(0.6, -0.33, 'red OL, blue CL', 'FontSize', 8);
subplot(1, 3, 2); hold on
plot(S.gains, S.gain.', '-', 'Color', [col.CL 0.3]); plot(S.gains, mean(S.gain), 'o-', 'Color', col.CL, 'LineWidth', 1.5, 'MarkerFaceColor', col.CL);
plot(1.55 * ones(nS, 1), S.shuf, '.', 'Color', [0.5 0.5 0.5]); errorbar(1.55, mean(S.shuf), std(S.shuf)/sqrt(nS), 'ko', 'MarkerFaceColor', 'k');
set(gca, 'XTick', [S.gains 1.55], 'XTickLabel', [arrayfun(@num2str, S.gains, 'uni', 0) {'shuf'}]);
xlabel('laser-kernel gain removed'); ylabel('CL stim r (spots > 0.5 mm)'); title('Gain sweep + shuffled-laser control');
subplot(1, 3, 3); hold on
ls = {'-', '--'};
for c = 1:2
    for v = 1:2
        m = mean(S.dcoh.(cn{c}).(vn{v})); e = std(S.dcoh.(cn{c}).(vn{v}))/sqrt(nS);
        fill([f fliplr(f)], [m-e fliplr(m+e)], col.(cn{c}), 'FaceAlpha', 0.12, 'EdgeColor', 'none');
        plot(f, m, ls{v}, 'Color', col.(cn{c}), 'LineWidth', 1.3);
    end
end
yline(0, 'k:'); set(gca, 'XScale', 'log'); xlim([f(1) 17.5]); xlabel('frequency (Hz)'); ylabel('\Deltacoherence (stim - base)');
title('solid raw, dashed laser removed');
exportgraphics(fg, fullfile(here, '..', 'paper', 'images', 'supp_seedfc', 'seedfc_story_summary.png'), 'Resolution', 300);
save(fullfile(here, 'data', 'ctrl_seed_fc_story_summary.mat'), '-struct', 'S', '-v7');
end
