%% define_midline.m
% Display mean widefield image and interactively mark the cortical midline.
% Click two points along the midline (top → bottom), then press Enter.
% Saves midline parameters to midline.mat for use in contralateral analysis.

clc; close all;
addpath(genpath('utils'));

%% Load one representative session (SVD data only)
mn = 'AL_0033'; td = '2025-01-20'; en = 3;
fprintf('Loading session %s %s exp %d ...\n', mn, td, en);
d = initialize_data(mn, en, td);
mimg = d.svd.mimg;

%% Display mean image
fig = figure('Name', 'Define cortical midline', 'Color', 'k');
imagesc(mimg);
colormap gray;
clim([prctile(mimg(:), 1), prctile(mimg(:), 99)]);
axis image off;
title('Click 2 points along the midline (top → bottom), then press Enter', ...
    'Color', 'w', 'FontSize', 11);

%% Interactive: click two points
disp('Click two points along the cortical midline, then press Enter.');
[x_pts, y_pts] = ginput(2);

%% Fit a line through the two clicked points (parametric)
x1 = x_pts(1); y1 = y_pts(1);
x2 = x_pts(2); y2 = y_pts(2);

% Midline as a linear function: x = a*y + b  (vertical-ish line)
if abs(y2 - y1) > abs(x2 - x1)
    % Mostly vertical — parameterise x as function of y
    a = (x2 - x1) / (y2 - y1);   % slope (dx/dy)
    b = x1 - a * y1;              % intercept
    midline_type = 'x_of_y';      % x = a*y + b
else
    % Mostly horizontal — parameterise y as function of x
    a = (y2 - y1) / (x2 - x1);
    b = y1 - a * x1;
    midline_type = 'y_of_x';
end

%% Overlay the fitted midline on the image
[ny, nx] = size(mimg);
hold on;
if strcmp(midline_type, 'x_of_y')
    y_span = [1, ny];
    x_span = a * y_span + b;
else
    x_span = [1, nx];
    y_span = a * x_span + b;
end
plot(x_span, y_span, 'r-', 'LineWidth', 2);
scatter(x_pts, y_pts, 60, 'r', 'filled');
title('Midline defined — close figure to confirm', 'Color', 'w', 'FontSize', 11);

%% Save
midline.a    = a;
midline.b    = b;
midline.type = midline_type;
midline.pts  = [x_pts, y_pts];   % [x1 x2; y1 y2] clicked points
midline.mn   = mn;
midline.td   = td;
midline.img_size = [ny, nx];

save('midline.mat', 'midline');
fprintf('Midline saved to midline.mat\n');
fprintf('  type: %s,  a = %.4f,  b = %.4f\n', midline_type, a, b);
fprintf('  x at midpoint y: %.1f px\n', a * (ny/2) + b);
