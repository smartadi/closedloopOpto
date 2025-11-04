% analyze raw image:
clc;
clear all;
close all;

path = '/home/nimbus/Documents/Brain/data/AB_0032/2024-07-11/1/frame-'
num = 1
pathim=append(path,num2str(num));
fileID = fopen(pathim,'r');
A = fread(fileID,[560,560],'int16')';


%%
pixel = [230,220;
        360,130;
        170,330;
        196,450]
%%

% %%
% close all
% 
% 
% figure()
% clims = [0 2000]
% imagesc(A);hold on
% plot(pixel(1,1),pixel(1,2),'or')
% colorbar
% impixelinfo
% 
% 
% 
% %%
% source_dir ='/home/nimbus/Documents/Brain/data/AB_0032/2024-07-11/1/'
% a=dir([source_dir '/*'])
% out=size(a,1)
% 
% out=out-2;
% 
% 
% F = []
% for i=1:out
%     pathim=append(path,num2str(i-1));
%     fileID = fopen(pathim,'r');
%     A = fread(fileID,[560,560],'int16')';
%     G=[];
%     for j = 1 :length(pixel)
%         G = [G;A(pixel(j,1),pixel(j,2))];
%     end
%     i
%     F = [F,G];
% end
% 
% 
% 
% %%
% figure()
% plot(F)
% %%
% save("pixel_var.mat")

%%
mn = 'AB_0032'; td = '2024-06-25'; 
en = 1;

serverRoot = expPath(mn, td, en)

%% preprocess video

colors = {'blue', 'violet'};
computeWidefieldTimestamps(serverRoot, colors);

nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);

uu = reshape(U(:,:,1:500),560*560,500);
%% svdViewer
load(fullfile(serverRoot, 'blue', 'dataSummary.mat'));
svdViewer(U, Sv(1:nSV), V, 1/mean(diff(t)))



%% pixelate
F=[];
F2=[];
for i=1:nFrames
    Im = reshape(uu*V(:,i),[560,560])+mimg;
    Im2 = reshape(uu*V(:,i),[560,560]);
    G=[];
    G2=[];
    for j = 1 :length(pixel)
        G = [G;Im(pixel(j,1),pixel(j,2))];
        G2 = [G2;Im2(pixel(j,1),pixel(j,2))];
    end
    i
    F = [F,G];
    F2 = [F2,G2];
end



save('pixel_real.mat',"F","F2");


% load('pixel_real.mat');
%%

close all
figure()
plot(F(:,1:500)')


figure()
plot(F2(:,1:500)')

%%
Fb = F(:,1:2:end);
Fv = F(:,2:2:end);

%%
close all
figure()
plot(Fb(:,1:100)')

figure()
plot(Fv(:,1:100)')

%%
close all;
fc = 10;
n = 2;
fs = 35;
[b,a] = butter(4,0.5);
yb = filter(b,a,Fb);
yv = filter(b,a,Fv);



figure()
plot(yb(:,1:500)')


figure()
plot(yv(:,1:500)')
%%

close all

figure()
clims = [0 2000]
imagesc(Im);hold on

plot(pixel(:,1),pixel(:,2),'or')
colorbar
impixelinfo

