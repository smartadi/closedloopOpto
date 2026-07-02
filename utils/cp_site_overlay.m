function cp_site_overlay(st, mimg, px_prim, py_prim, k_prim)
% cp_site_overlay — confirm the adopted laser site sits at the crater center.
% Draws the trial-averaged peri-stim inhibition "crater" (st.map from
% cp_find_stim_site) as a translucent blue overlay on the transposed brain
% (canonical vertical view), with the adopted recording site (red +, kernel
% footprint box) and the deepest-0.5% centroid (yellow o) marked. Lets you
% eyeball that px_prim/py_prim land at the center of the laser inhibition.
%
%   st       cp_find_stim_site output (needs .map [Ny x Nx], .rowcol, .centroid, .depth)
%   mimg     mean fluorescence image (native [Ny x Nx])
%   px_prim  adopted site ROW   | py_prim adopted site COL | k_prim kernel half-width
A   = mimg.';  glo = prctile(A(:),1);  ghi = max(prctile(A(:),99), glo+eps);
g   = min(max((A - glo)/(ghi - glo), 0), 1);            % brain -> [0,1] grayscale (transposed)
mapT = st.map.';                                        % inhibition map, transposed
neg  = mapT < 0 & ~isnan(mapT);
lim  = prctile(-mapT(neg), 99);  if isempty(lim) || lim < eps, lim = 1; end
al   = zeros(size(mapT));  al(neg) = min(1, -mapT(neg)/lim);   % deeper inhibition -> more opaque

figure('Color','w','Name','cp_site_overlay: laser crater + adopted site');
image(repmat(g,1,1,3));  axis image off;  hold on;
him = imagesc(mapT);  set(him, 'AlphaData', 0.9*al);
cmap = [linspace(0.0,0.85,256)', linspace(0.15,0.92,256)', linspace(0.55,1,256)'];  % dark->light blue
colormap(gca, cmap);  clim([-lim 0]);
rectangle('Position',[px_prim-k_prim, py_prim-k_prim, 2*k_prim, 2*k_prim], ...
          'EdgeColor',[1 0.85 0], 'LineWidth',1.5);
plot(px_prim, py_prim, 'r+', 'MarkerSize',16, 'LineWidth',2.5);          % adopted site (transposed: row,col)
plot(st.centroid(1), st.centroid(2), 'yo', 'MarkerSize',10, 'LineWidth',1.5);   % deepest-0.5% centroid
cb = colorbar;  ylabel(cb, 'peri-stim \DeltaF/F (%)  [0-200 ms - baseline]', 'FontWeight','bold');
title(sprintf('[CP-SITE] laser crater + adopted site [row %d col %d]  (r+ site, yo centroid; depth %.2f%%)', ...
    px_prim, py_prim, st.depth), 'FontWeight','bold');
hold off;
end
