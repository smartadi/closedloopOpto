function data = getpixels_dFoF(d,serverRoot)
% GETPIXEL_DFOF Summary of this function goes here
%   Detailed explanation goes here

% serverRoot = "/run/user/1000/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/AL_0039/2025-04-20/1";
serverRoot = expPath(d.mn, d.td, d.en);

pathData = append(d.mn,'pixels',d.td(6:7),d.td(9:10),int2str(d.en),'.mat');

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
U = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));

%
    fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
    V = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
    t = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));




if exist(pathData) == 0
    F = [];
    dFk=[];

    
    pixel = d.params.pixels
    % pixel = d.params.pixels_contra;


    for j= 1:length(pixel)
        % for j= 1:3
            j
    Fsvd = [];

    k=d.params.kernel;
    mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
    mI = mean(mimg_kernel,'all');

        for i = 1:length(V)
            mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
            imkernel = U(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
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

    end
    
    save(pathData,'dFk');
    data.dFk = dFk;
    data.F = F;
else
% 
     data.dFk = load(pathData).dFk;
% 
end

