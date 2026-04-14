function loadAndSVDfbin(thisPath)
%% TO BE USED WITH Aditya's exeriments
% display('a')
% addpath(genpath('C:\Users\SteinmetzLab\Documents\MATLAB\Github'));
%% load into dat
rootDir = fullfile('C:\Users\aditya\Documents\projects\data\', thisPath);
display('1')
tempProcDir = 'C:\Users\aditya\Documents\projects\temproc'; mkdir(tempProcDir)
display('2')
p = dat.paths();
display('3')
root = {fullfile(p.mainRepository, thisPath, 'blue'),...
    fullfile(p.mainRepository, thisPath, 'violet')};
tarFile = fullfile(p.mainRepository, thisPath, 'widefield.tar');
display('3')
%% Check the blue/violet/widefield exposure to figure out which frames have
% display('b')
serverRoot = fullfile(p.mainRepository, thisPath);

blue = readNPY(fullfile(serverRoot,'blueLEDmonitor.raw.npy'));
violet = readNPY(fullfile(serverRoot,'violetLEDmonitor.raw.npy'));
wideExp = readNPY(fullfile(serverRoot,'widefieldExposure.raw.npy'));
ts = readNPY(fullfile(serverRoot,'widefieldExposure.timestamps_Timeline.npy'));
t = tsToT(ts,size(wideExp,1));

blue = conv(blue, gausswin(5), 'same');
violet = conv(violet, gausswin(5), 'same');

figure()
plot(blue,'b');hold on;
plot(violet,'k');hold on;

disp('4')

[frameTimes, blueFrames, violetFrames, doubleFrames, blankFrames] = alignBlueVioletExposures(blue,violet,wideExp,t);
if any(doubleFrames)
    warning(sprintf('Found %i double frames -- the script should deal with these properly, but be aware that some frames have duplicates',sum(doubleFrames)));
end

% for now: remove all doubled frames
blueFrames(doubleFrames) = 0;
violetFrames(doubleFrames) = 0;

writeNPY(frameTimes,fullfile(serverRoot,'frameTimes.timestamps.npy'));
writeNPY(blueFrames,fullfile(serverRoot,'blueFrames.indexes.npy'));
writeNPY(violetFrames,fullfile(serverRoot,'violetFrames.indexes.npy'));

%%
% display('c')
% blue or violet in them
isBlueViolet = true; 

fn = dir(fullfile(rootDir, 'frame-0')); 
oneImid = fopen(fullfile(rootDir, fn.name));
oneIm = fread(oneImid,[560,560],'uint16')';
rootFn = fn.name(1:end-9);
% display('d')
allFn = dir(fullfile(rootDir, '*'));
fh = figure; fh.Color = 'k';
if isBlueViolet
    subplot(2,1,1); 
    im1 = imagesc(oneIm);caxis([-7000 7000]/2);axis image;%colormap(colormap_blueblackred);
    axis off; 
    subplot(2,1,2); 
    im2 = imagesc(oneIm); caxis([-7000 7000]/2);axis image;%colormap(colormap_blueblackred);
    axis off; 
else
    im1 = imagesc(oneIm'); caxis([-7000 7000]);axis image; %colormap(colormap_blueblackred); 
end
fclose(oneImid)
% display('e')
% checkBVW version:
nFr = [sum(blueFrames) sum(violetFrames)];
% oriinal code:
% nFr = [ceil(numel(allFn)/2), floor(numel(allFn)/2)];
 
dOne = double(oneIm); 

mnIm = zeros(size(oneIm)); 
if isBlueViolet
    mnIm2 = zeros(size(oneIm));
    blueId = fopen(fullfile(tempProcDir, 'blue.dat'), 'w');
    violetId = fopen(fullfile(tempProcDir, 'violet.dat'), 'w');
else
    tempId = fopen(fullfile(rootDir, 'temp.dat'), 'w');
end
allFn(1)=[]
allFn(1)=[]
% 
% allFn(1).name
% allFn(2).name
% allFn(3).name
% 
% allFn(1).folder
% allFn(2).folder
% allFn(3).folder


display('f')

(min([size(blueFrames,1) numel(allFn)]))
% blueFrames
% violetFrames
a = fullfile(rootDir, 'frame-');
for q = 1:(min([size(blueFrames,1) numel(allFn)]))
    
%     thisIm = imread(fullfile(rootDir, sprintf('%s%s.tiff', rootFn, num2str(q,'%04.f'))));
    
    thisid = fopen(append(a,num2str(q-1)),'r');
    thisIm = fread(thisid,[560,560],'uint16')';
    
%     thisIm = imread(fullfile(rootDir, sprintf('%s%s.tiff', rootFn, num2str(q,'%04.f'))));

    
    
%     if isBlueViolet
        if blueFrames(q)
            fwrite(blueId, thisIm, 'uint16'); 
            mnIm = mnIm + double(thisIm); 
        else
            fwrite(violetId, thisIm, 'uint16'); 
            mnIm2 = mnIm2 + double(thisIm); 
%         else
%             warning('UNASSIGNED FRAME!! May be blank -- ignoring');
        end
%     else
%         fwrite(tempId, thisIm, 'uint16'); 
    
%         mnIm = mnIm + double(thisIm); 
%     end
    
    
%     if isBlueViolet
%         if blueFrames(q)
%             fwrite(blueId, thisIm, 'uint16'); 
%             mnIm = mnIm + double(thisIm); 
%         elseif violetFrames(q)
%             fwrite(violetId, thisIm, 'uint16'); 
%             mnIm2 = mnIm2 + double(thisIm); 
%         else
%             warning('UNASSIGNED FRAME!! May be blank -- ignoring');
%         end
%     else
%         fwrite(tempId, thisIm, 'uint16'); 
%     
%         mnIm = mnIm + double(thisIm); 
%     end
% %     if mod(q, 100)==0
%         if isBlueViolet
%             set(im1, 'CData', double(lastIm)-mnIm/q*2); title(q)
%             set(im2, 'CData', double(thisIm)-mnIm2/q*2); title(q)
%         else
%             set(im1, 'CData', double(thisIm)-mnIm/q); title(q)
%         end
%         drawnow;
%     end
    lastIm = thisIm;
    fclose(thisid);

end
% display('g')
if isBlueViolet
    mnIm = mnIm./nFr(1); 
    mnIm2 = mnIm2./nFr(2);
    fclose(blueId)
    fclose(violetId)
else
    mnIm = mnIm./numel(allFn); 
    fclose(tempId)
end

vids = {};
if any(blueFrames)
    vids{end+1} = 'blue';
end
if any(violetFrames)
    vids{end+1} = 'violet';
end
display('g1')
%% save mean
mnImg = {mnIm, mnIm2}; 

for v = 1:2
    mkdir(root{v})
    fnMeanImage = fullfile(root{v}, ['meanImage']);
    writeNPY(mnImg{v}, [fnMeanImage '.npy']);
end

%% perform SVD
display('g2')
svdOps.NavgFramesSVD = 5000;
svdOps.verbose = true;
svdOps.nSVD = 2000;
svdOps.useGPU = true;


mnImg = {mnIm, mnIm2}; 
display('g3')
for v = 1:length(vids)
    fprintf(1, ['svd on ' vids{v} '\n']);
%     

    svdOps.yrange = 1:size(oneIm,1); % subselection/ROI of image to use
    svdOps.xrange = 1:size(oneIm,2);
    svdOps.RegFile = fullfile(tempProcDir, sprintf('%s.dat',vids{v}));
    svdOps.Nframes = nFr(v); % number of frames in whole movie
    svdOps.mimg = mnImg{v};
        
    tic
    [U, Sv, V, totalVar] = get_svdcomps(svdOps);
    toc   
    
    mkdir(root{v});
    fnU = fullfile(root{v}, ['svdSpatialComponents']);
    fnV = fullfile(root{v}, ['svdTemporalComponents']);
    writeUVtoNPY(U, V, fnU, fnV);

    nFrames     =nFr(v);
    save(fullfile(root{v}, ['dataSummary']), 'Sv', 'svdOps', 'totalVar', 'nFrames');
    svdViewer(U, Sv, V, 35, totalVar)

end
display('g4')
%%

addpath(genpath('C:\Users\SteinmetzLab\Documents\github\nickBox'))
tic

% short note here: we're writing files to a .tar, which has NO compression
% so it only serves to bundle up all the images into one file and transfer.
% In tests with small numbers of files, a fast compressed version takes ~4x
% as long but only saves about 25% of the file size. So we're skipping
% that. More ideally we'd have written the images into a single file during
% acquisition, in which case we'd be ready here to send that single file to
% google drive directly, skipping the server. 
if ~isfile(tarFile)
    status = my7zTar(tarFile, {[rootDir '\']});
else
    status = 0;
end
toc

%%
% now we will try two ways to determine that this has been successful: check
% that tar file is at least as big as the local directory (it ought to be a
% bit bigger); and check that status came back 0
if status>0
    fprintf(1, 'Returned status was %d, so the local files will NOT be deleted\n', status); 
else
    d = dir(rootDir);
    localSize = sum([d.bytes]);
    dt = dir(tarFile);
    serverSize = dt.bytes;
    if serverSize<=localSize
        fprintf(1, 'The server file does not look big enough to have all the images in it, so local files will NOT be deleted\n'); 
        fprintf(1, '  local: %d bytes; server: %d bytes; diff: %d bytes (must be negative)\n', ...
            localSize, serverSize, localSize-serverSize); 
    else
        % now we can delete the local files
        fprintf(1, 'Transfer to server of raw data appears successful. Deleting %s...\n', rootDir); 
        tic
        delete(fullfile(rootDir, '*')); 
        toc;        
    end
end

% Run hemoCorrect
computeWidefieldTimestamps(serverRoot, vids);
if any(violetFrames)
    hemoCorrect(serverRoot,500);
end

end

