function paperLegend(lgd)
% PAPERLEGEND  Apply standard legend formatting to a legend handle.
% Usage:  lgd = legend(ax, ...);
%         paperLegend(lgd);
%
% Sets: Box off, FontSize, FontWeight, ItemTokenSize — all from paperStyle().
PS = paperStyle();
lgd.Box           = 'off';
lgd.FontSize      = PS.fs;
lgd.FontWeight    = PS.fw;
lgd.ItemTokenSize = PS.lgd_token;
end
