clear all;
close all;
clc;


%%




dataStruct = load('data.mat');

% Get the fieldnames of the loaded structs
structNames = fieldnames(dataStruct);

% Preallocate cell arrays for wc and nc
wc_all = [];
nc_all = [];
group_labels = [];
d_all=[];

% Loop through each struct and collect wc and nc values
for i = 1:numel(structNames)
    currentStruct = dataStruct.(structNames{i});
    
    wc_all = [wc_all; currentStruct.wc(:)];
    nc_all = [nc_all; currentStruct.nc(:)];
    d_all = [d_all;NaN;currentStruct.wc(:);currentStruct.nc(:)
        ];
    
    % Label: 1 = wc, 2 = nc
    group_labels = [group_labels; ...
                    append('session:',num2str(i));
                    repmat({['FB_' num2str(i)]}, length(currentStruct.wc), 1);
                    repmat({['FF_' num2str(i)]}, length(currentStruct.nc), 1)];
end

% Combine all values
all_values = [wc_all; nc_all];

% Create boxplot
figure;
% boxplot(all_values, group_labels);
boxplot(d_all, group_labels,'factorgap', 15);
ylabel('Trial MSE');
title('Comparison of FB vs FF trial performance across sessions');



%%
