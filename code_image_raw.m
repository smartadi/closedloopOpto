clc;
close all;
clear all;

pathA = '/media/nimbus/data/brain/AL_0033/2024_07_25/1/';
pathB = '/media/nimbus/data/brain/AL_0034/2024_07_29/1/';
pathC = '/media/nimbus/data/brain/AL_0034/2024_08_19/1/';

paths.Names = [pathA;pathB;pathC]

for a = path.Names
directory_instance = dir(a);
path.file_names.a = {directory_instance.name};
path.file_names.a(1:2)=[];
end
% file_names = cell2mat(file_names);
%%
pixel = [230,220;
        360,130;
        170,330;
        196,450]
%%
t = Tiff(append(path,cell2mat(path.file_names.a(10000))),'r');
imageData = read(t);


close all;
figure()
clims=[0,4096];
imagesc(imageData);hold on;
for i=1:4
plot(pixel(i,1),pixel(i,2),'or')
end
colorbar


%% pixelate

for a = path.Names


Fr.a = [];

% for i=1:length(file_names)
for i=1:10000
    
    t = Tiff(append(path,cell2mat(path.file_names.a(i))),'r');
    imageData = read(t);
    G=[];

    for j = 1 :length(pixel)
        G = [G;imageData(pixel(j,1),pixel(j,2))];

    end
    i
    Fr.a= [Fr.a,G];
end


end
%%save('pixel_raw.mat',"Fr");
% load('pixel_raw.mat',"Fr");
%%
close all;

Fbr = Fr(:,1:2:end);
Fvr = Fr(:,2:2:end);


figure()
plot(Fr')


figure
plot(Fbr')

figure()
plot(Fvr')
%%
close all;
t0=1000;
T=500;
figure()
plot(Fr(:,t0:t0+T)')


figure
plot(Fbr(:,t0:t0+T)')

figure()
plot(Fvr(:,t0:t0+T)')
%%
close all;
figure
plot(Fbr(1,t0:t0+T)')

figure
plot(Fbr(2,t0:t0+T)')

figure
plot(Fbr(3,t0:t0+T)')

figure
plot(Fbr(4,t0:t0+T)')


