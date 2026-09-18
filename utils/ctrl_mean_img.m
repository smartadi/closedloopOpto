function mimg = ctrl_mean_img(tag)
% ctrl_mean_img  Mean SVD brain image for a controller session (Fig-4 backgrounds).
% Returns the raw mean fluorescence image (blue/meanImage.npy) in NATIVE [nY x nX],
% the same frame the brain masks + grid coords live in. Cached to a small .mat so the
% figure stays offline-safe (the raw server data is lab-PC-only); on first call it
% reads from the server and writes the cache.
root='C:\Users\aditya\Documents\projects\brain_paper';
dd=fullfile(root,'controller-analysis','data');
cache=fullfile(dd,sprintf('ctrl_meanimg_%s.mat',tag));
if exist(cache,'file')
    S=load(cache,'mimg'); mimg=S.mimg; return;
end
S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)),'mn','td','en');
sr=expPath(S1.mn,S1.td,S1.en);
f=fullfile(sr,'blue','meanImage.npy');
if ~exist(f,'file'), error('ctrl_mean_img: meanImage.npy not found (%s) -- run once on the lab PC to cache.', f); end
mimg=double(readNPY(f));
save(cache,'mimg');
fprintf('[ctrl_mean_img] cached mean image -> %s\n', cache);
end
