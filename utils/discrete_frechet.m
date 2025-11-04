% File: discrete_frechet.m
function dist = discrete_frechet(P, Q)
    

    P = P - mean(P);
    Q = Q - mean(Q);
    
    
    % Inputs: P and Q are vectors (1D signals)
    n = length(P);
    m = length(Q);
    ca = -ones(n, m);  % Cache matrix

    function d = c(i, j)
        if ca(i,j) > -1
            d = ca(i,j);
        elseif i == 1 && j == 1
            d = norm(P(1) - Q(1));
        elseif i > 1 && j == 1
            d = max(c(i-1,1), norm(P(i)-Q(1)));
        elseif i == 1 && j > 1
            d = max(c(1,j-1), norm(P(1)-Q(j)));
        else
            d = max(min([c(i-1,j), c(i-1,j-1), c(i,j-1)]), norm(P(i)-Q(j)));
        end
        ca(i,j) = d;
    end

    dist = c(n, m);
end

