clc;
close all;
clear all;

path = '/home/nimbus/Documents/Brain/data/2024-08-04/temp/';

directory_instance = dir(path);
file_names = {directory_instance.name};
file_names(1:2)=[];

% file_names = cell2mat(file_names);
%%
pixel = [230,220;
        360,130;
        170,330;
        196,450]
%%
    t = Tiff(append(path,cell2mat(file_names(10000))),'r');
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
% Fr=[];
% 
% for i=1:length(file_names)
% %for i=1:1000
% 
%     t = Tiff(append(path,cell2mat(file_names(i))),'r');
%     imageData = read(t);
%     G=[];
% 
%     for j = 1 :length(pixel)
%         G = [G;imageData(pixel(j,1),pixel(j,2))];
% 
%     end
%     i
%     Fr = [Fr,G];
% end



%%save('pixel_raw.mat',"Fr");
load('pixel_raw.mat',"Fr");
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
load("pixel_real.mat")
%%

Fb = F(:,1:2:end);
Fv = F(:,2:2:end);


figure()
plot(F')


figure
plot(Fb')

figure()
plot(Fv')

%%

F=[]

load("pixel_var.mat")
%%

Fb = F(:,1:2:end);
Fv = F(:,2:2:end);
%%

t0=10000
T=500

close all
figure()
plot(F(:,t0:t0+2*T)')


figure
plot(Fb(:,t0:t0+T)')

figure()
plot(Fv(:,t0:t0+T)')




figure()
plot(Fr(:,t0:t0+2*T)')


figure
plot(Fbr(:,t0:t0+T)')

figure()
plot(Fvr(:,t0:t0+T)')
