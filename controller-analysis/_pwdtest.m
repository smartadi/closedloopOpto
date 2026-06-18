fprintf('cwd inside run: %s\n', pwd);
fprintf('isfolder data: %d\n', isfolder('data'));
fprintf('isfolder ../data: %d\n', isfolder(fullfile('..','data')));
