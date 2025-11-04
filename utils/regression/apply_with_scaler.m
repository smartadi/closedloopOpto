function x = apply_with_scaler(x, scaler)
    switch scaler.type
        case 'zscore'
            x = (x - scaler.mu) ./ scaler.sd;
        case 'log1p_z'
            x = log1p(max(x,0));
            x = (x - scaler.mu) ./ scaler.sd;
        case 'z_of_custom'
            % we don't know pre_fun here; we only z-score with stored params
            x = (x - scaler.mu) ./ scaler.sd;
        otherwise
            error('No forward transform defined for this scaler.type: %s', scaler.type);
    end
end