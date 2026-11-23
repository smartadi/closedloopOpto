% paper-writing/fig2g_text_numbers.m
% Numbers quoted in the JN Fig 2G Results paragraph (results.tex 98-103), read from the saved Fig 2G
% run. Nothing is fitted or tested here: per-session quartile values of the normalized variability
% (STV_R.sdRawNs, 1 = the session's typical trial, the thin lines of Fig 2G) and the session-level
% ratios in STATS_TABLE.csv. Written 2026-11-23 for the 11-14 windows ([-2,0) s, 1-4 Hz;
% RESEARCH L-2026-11-14-b) when drafting the JN text (L-2026-11-23-c).
% Rows of sdRawNs are the sorted session indices of imp_state_trialvar.m, which are, in the order of
% imp_state_quartile_supp.m SESS_ID: Mouse 5a, 5b, 1b, 3c.
% IN  data/fig2g_state_stats.mat (STV_R), paper-writing/STATS_TABLE.csv. OUT printout only.
root = 'C:\Users\aditya\Documents\projects\brain_paper';
S = load(fullfile(root, 'data', 'fig2g_state_stats.mat'));  R = S.STV_R;
lab = {'Mouse 5a', 'Mouse 5b', 'Mouse 1b', 'Mouse 3c'};
for t = {'MOT', 'DPr', 'DPa'}
    r = R(strcmp({R.tag}, t{1}));  q = r.sdRawNs;               % sessions x quartiles (Q1..Q4)
    assert(isequal(size(q), [4 4]), 'expected 4 sessions x 4 quartiles');
    [~, iMin] = min(q, [], 2);  [~, iMax] = max(q, [], 2);
    mono = all(diff(q, 1, 2) > 0, 2);
    fprintf('\n%s (rows %s)\n', t{1}, strjoin(lab, ', '));  disp(round(q, 3));
    fprintf('  top quartile lowest in %d/4 sessions; highest in %d/4; increasing Q1->Q4 in %d/4 (%s)\n', ...
        nnz(iMin == 4), nnz(iMax == 4), nnz(mono), strjoin(lab(mono), ', '));
    fprintf('  Q4 range, all sessions %.2f-%.2f; Q1-Q3 range, all sessions %.2f-%.2f\n', ...
        min(q(:,4)), max(q(:,4)), min(q(:,1:3), [], 'all'), max(q(:,1:3), [], 'all'));
    k = iMin == 4;                                               % sessions where the top quartile is lowest
    if any(k) && ~all(k)
        fprintf('  where Q4 is lowest (%s): Q4 %.2f-%.2f, Q1-Q3 %.2f-%.2f\n', strjoin(lab(k), ', '), ...
            min(q(k,4)), max(q(k,4)), min(q(k,1:3), [], 'all'), max(q(k,1:3), [], 'all'));
        for i = find(~k)'
            fprintf('  %s: Q1..Q4 = %s\n', lab{i}, mat2str(round(q(i,:), 2)));
        end
    end
end

T = readtable(fullfile(root, 'paper-writing', 'STATS_TABLE.csv'), 'TextType', 'string');
ids = ["2G_MOT_ratio" "2G_DPr_ratio" "2G_DPa_ratio" "2G_MOT_ctrlratio" "2G_DPr_ctrlratio" ...
       "2G_DPa_ctrlratio" "2G_MOT_stimctrl" "2G_DPr_stimctrl" "2G_DPa_stimctrl" "2G_ctl_resp_spread"];
fprintf('\nSTATS_TABLE.csv (effect, ci_lo-ci_hi = range over sessions)\n');
for id = ids
    g = T(T.id == id, :);
    fprintf('  %-20s %.2f (%.2f-%.2f)\n', id, g.effect, g.ci_lo, g.ci_hi);
end
