function adj = holm_adjust(p)
% HOLM_ADJUST  Holm step-down adjusted p-values, same order as the input (twin of stats_v2/tests.py holm).
p = double(p(:));  m = numel(p);
[~, order] = sort(p);
adj = nan(m, 1);  running = 0;
for i = 1:m
    running = max(running, min(1, (m - i + 1) * p(order(i))));
    adj(order(i)) = running;
end
end
