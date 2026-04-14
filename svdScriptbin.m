% TO BE USED WITH Aditya's exeriments
clc;
clear all;
close all

pathString = genpath('utils');
addpath(pathString);
% addpath(genpath(fullfile('C:\Users\SteinmetzLab\Documents\github\')));
% addpath(genpath(fullfile('C:\Users\SteinmetzLab\Documents\MATLAB\Github')));
%% 
% pause(3600*4);

allPaths = {};


% allPaths{end+1} = 'AL_0033\2025-03-17\1';
% allPaths{end+1} = 'AL_0033\2025-03-20\4';
% allPaths{end+1} = 'default\2025-03-05\3';
% allPaths{end+1} = 'AL_0033\2025-04-15\1';
% allPaths{end+1} = 'AL_0033\2025-04-20\2';
% allPaths{end+1} = 'AL_0039\2025-04-20\1';
% allPaths{end+1} = 'AL_0039\2025-04-20\2';
allPaths{end+1} = 'AL_0033\2025-04-20\2';
% allPaths{end+1} = 'AL_0039\2025-04-30\3';
% allPaths{end+1} = 'test\2025-04-30\3';
% allPaths{end+1} = 'AL_0039\2025-04-19\1';

% 
% allPaths{end+1} = 'AL_0041\2025-11-12\1';
% allPaths{end+1} = 'AL_0041\2025-11-12\2';

% allPaths{end+1} = 'AL_0041\2025-12-02\1';
% allPaths{end+1} = 'AL_0041\2025-12-02\2';

% allPaths{end+1} = 'AL_0033\2025-01-18\1';

for ii=1:size(allPaths,2)
    close all;
    try
        currentPath = allPaths{ii};
        fprintf(1, 'start %s\n', currentPath);
        loadAndSVDfbin(currentPath);
        fprintf(1, 'Done with %s\n', currentPath);
    catch me
        fprintf(1, 'Error with %s\n', currentPath);
        disp(me)
    end



%%
 
% thisPath = append(allPaths{ii},'\');
% serverRoot = 'Y:\Subjects\';
% serverRoot = append(serverRoot,thisPath);
% addpath(genpath('C:\Users\SteinmetzLab\Documents\MATLAB\Github'));
% %% load into dat
% dpath = "C:\Users\SteinmetzLab\Documents\im_cature\data\";
% dpath = append(dpath,thisPath,'*');
% status = movefile(dpath,serverRoot)  ;

end