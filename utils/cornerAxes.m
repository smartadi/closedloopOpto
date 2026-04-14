function cornerAxes(ax)
    if nargin < 1
        ax = gca;
    end

    ax.Box = 'off';
    ax.TickDir = 'out';
    ax.LineWidth = 1.2;
    ax.FontSize = 12;
    ax.FontName = 'Arial';

    ax.XColor = 'k';
    ax.YColor = 'k';

    ax.XRuler.Axle.Visible = 'off';
    ax.YRuler.Axle.Visible = 'off';
end
