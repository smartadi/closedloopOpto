function dF = pixdff(U,V,pixel)

    % ---- checks ----
    if numel(pixel) ~= 2
        error('Pixel must be [row col]');
    end
    
    r = pixel(1);
    c = pixel(2);

    if r < 1 || r > size(U,1) || c < 1 || c > size(U,2)
        error('Pixel out of bounds');
    end

    % ---- extract spatial weights for this pixel ----
    u_pix = squeeze(U(r,c,:));   % K x 1

    % ---- reconstruct ----
    dF = (u_pix.' * V)*100;         % 1 x T
end