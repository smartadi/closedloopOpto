function y = inverse_transform_vec(y_scaled, scaler)
    switch scaler.type
        case 'zscore'
            y = y_scaled .* scaler.sd + scaler.mu;
        case 'log1p_z'
            % Rare for y, but included for completeness
            y = exp(y_scaled .* scaler.sd + scaler.mu) - 1;
        otherwise
            error('No inverse defined for this scaler.type.');
    end
end