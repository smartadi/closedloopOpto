function addStimPatch(ax, x1, x2)
yl = ylim(ax);
patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
    [0.9 0.9 0.9], 'FaceAlpha', 0.3, 'EdgeColor','none');
end
