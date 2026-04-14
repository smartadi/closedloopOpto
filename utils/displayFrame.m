function displayFrame(mn, td, en, d, frame)
    % source_dir = '/mnt/data/brain/';
    source_dir = 'C:\Users\aditya\Documents\projects\data\';
    source_dir = append(source_dir, mn, '\', td, '\', num2str(en))
    a = dir([source_dir '/*']);
    out = size(a, 1);
    
    out = out - 2;

    % pixel = [163,300];
    path = append(source_dir, '\frame-');
    i = 5003;
    pathim = append(path, num2str(i - 1));
    fileID = fopen(pathim, 'r');
    A = fread(fileID, [560, 560], 'uint16')';
    fclose(fileID);
    
    close all;
    figure();
    imagesc(A); hold on;

    % plot(d.params.pixels(:, 1), d.params.pixels(:, 2), 'og'); hold on;
    plot(frame(:, 1), frame(:, 2)', 'ok', 'LineWidth', 2);hold on
    % plot(frame(1, 1), frame(2, 1)', 'or', 'LineWidth', 2);
    % plot(d.params.pixel(:, 1), d.params.pixel(:, 2), 'or'); hold on;
    clim([0 4000]);
    colorbar;
    impixelinfo;
end

