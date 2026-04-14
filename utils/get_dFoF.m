function dFk = get_dFoF(d,pixel,serverRoot)
% GETPIXEL_DFOF Summary of this function goes here
% Detailed explanation goes here

% serverRoot = "/run/user/1000/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/AL_0039/2025-04-20/1";
serverRoot = expPath(d.mn, d.td, d.en);

% pathData = append(d.mn,'pixels',d.td(6:7),d.td(9:10),int2str(d.en),'.mat');

% source_dir ='/mnt/data/brain/';
% source_dir = append(source_dir,d.mn,'/',d.td,'/',num2str(d.en));
% a=dir([source_dir '/*']);
% out=size(a,1);
% 
% out=out-2;
% path = append(source_dir,'/frame-');

w=d.params.horizon-1;

k=d.params.kernel;

expRoot = serverRoot;
movieSuffix = 'blue';
nSV = 2000;
U = d.svd.U;
mimg = d.svd.mimg;
V = d.svd.V;
t = d.svd.t;


    F = [];
    dFk=[];

    
    pixel = d.params.pixels;


    j=1;
        % for j= 1:3
            j
    Fsvd = [];

    k=d.params.kernel;
    mimg_kernel = mimg(pixel(2)-k:pixel(2)+k,pixel(1)-k:pixel(1)+k);
    mI = mean(mimg_kernel,'all');

        for i = 1:length(V)
            mimg_kernel = mimg(pixel(2)-k:pixel(2)+k,pixel(1)-k:pixel(1)+k);
            imkernel = U(pixel(2)-k:pixel(2)+k,pixel(1)-k:pixel(1)+k,:);
            % size(imkernel)
            imstack = mean(imkernel,[1,2]);
            Fsvd = [Fsvd,reshape(imstack,[1,2000])*V(:,i)]  ;
        end
   

    Fsvd = Fsvd + mI;
    w=d.params.horizon-1;
    %
    Fk  = [ones(1,w),Fsvd];
    dFsvd=[];
    Fmean=[];

    Fkmean=[];
%
    for i = 1:length(Fsvd)
    
        Fkmean = [Fkmean,mean(Fk(i:i+w))];
        dFsvd = [dFsvd,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];

    end

    F = [F;Fsvd];
    dFk=[dFk;dFsvd];

    
    

% 
% 


