function [Phi, y_out, maxLag, seg_ids, t_local] = buildLagMatrix_segments(y_mat, X_tensor, pY, pX)
% y_mat   : L x S
% X_tensor: L x n x S (or [] if none)
% Returns stacked rows across segments, with lags built *within* each segment.
    if nargin < 2 || isempty(X_tensor), X_tensor = []; end
    if nargin < 3, pY = 0; end
    if nargin < 4, pX = 0; end
    [L, S] = size(y_mat);
    n = size(X_tensor,2);
    maxLag = max(pY, pX);

    if maxLag == 0
        rows = L*S;
        Phi = ones(rows, 1 + (n>0)*n);
        y_out = zeros(rows,1);
        seg_ids = zeros(rows,1);
        t_local = zeros(rows,1);
        r0 = 0;
        for s = 1:S
            idx = (1:L) + r0;
            y_out(idx)   = y_mat(:,s);
            seg_ids(idx) = s;
            t_local(idx) = (1:L)';
            if ~isempty(X_tensor)
                Phi(idx,2:end) = X_tensor(:,:,s);
            end
            r0 = r0 + L;
        end
        return;
    end

    rows_per_seg = L - maxLag;
    total_rows   = rows_per_seg * S;

    Phi = ones(total_rows, 1 + pY + n*pX);
    y_out   = zeros(total_rows,1);
    seg_ids = zeros(total_rows,1);
    t_local = zeros(total_rows,1);

    r0 = 0;
    for s = 1:S
        idxY = (maxLag+1):L;
        K = numel(idxY);
        rows = (1:K) + r0;

        y_out(rows) = y_mat(idxY, s);
        seg_ids(rows) = s;
        t_local(rows) = idxY(:);

        col = 2;
        % y-lags
        for l = 1:pY
            Phi(rows, col) = y_mat(idxY - l, s);
            col = col + 1;
        end
        % X-lags
        if ~isempty(X_tensor) && pX > 0
            for j = 1:n
                for l = 1:pX
                    Phi(rows, col) = X_tensor(idxY - l, j, s);
                    col = col + 1;
                end
            end
        end

        r0 = r0 + K;
    end
end
