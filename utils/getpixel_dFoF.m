function [data,dFk] = getpixel_dFoF(d,mode,pixel,r);


% GETPIXEL_DFOF Summary of this function goes here
%   Detailed explanation goes here


% mode = 0; % from images
mode = 1; % from svd

%read from
r = 1

serverRoot = expPath(d.mn, d.td, d.en);
% pathData = append('pixel',d.td(6:7),d.td(9:10),int2str(d.en),'.mat');



pathData = append(d.mn,'pixel',d.td(6:7),d.td(9:10),int2str(d.en),'.mat');
dFk=[];


exist(pathData)

if (exist(pathData) == 0) | (r == 0)
    F = [];

    k=d.params.kernel;
    display('computing pixel val')

    if mode==0
        % source_dir ='/mnt/data/brain/';
        source_dir = 'C:\Users\aditya\Documents\projects\data\';
        source_dir = append(source_dir,d.mn,'\',d.td,'\',num2str(d.en));
        a=dir([source_dir '\*'])
        out=size(a,1);

        out=out-2;
        path = append(source_dir,'\frame-');
    
        for i=1:2:out
            pathim=append(path,num2str(i-1));
            fileID = fopen(pathim,'r');
            A = fread(fileID,[560,560],'uint16')';
            % j=length(pixel);
            j=1;
            G = mean(A(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k),'all');
            i
    
            F = [F,G];
            fclose(fileID);
            
    
        end
    else

        expRoot = serverRoot;
movieSuffix = 'blue';
nSV = 2000;
U = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));

%
    fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
    V = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
    t = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));


        % nSV = 2000;
        % [U, V, t, mimg] = loadUVt(serverRoot, nSV);
        % mimg = mimg';
        j=1;
        mI = [];
        for i = 1:length(V)
            mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
            mI = [mI,mean(mimg_kernel,'all')];
            imkernel = U(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
            % size(imkernel)
            imstack = mean(imkernel,[1,2]);
            % size(imstack)   
            F = [F,reshape(imstack,[1,2000])*V(:,i)];
        end


    end
    display('computing df/F')
    w=d.params.horizon-1;
    Fk  = [ones(1,w),F];
    dF=[];
    Fmean=[];
    dFk=[];
    Fkmean=[];

    for i = 1:length(F)
        % Add an LPF filter 
        if mode == 0

        Fkmean = [Fkmean,mean(Fk(i:i+w))];
        dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
        else
        dFk = [dFk,(F(i))/mI(i)*100];
        end

    end
    
    
    save(pathData,'dFk');
    data.dFk = dFk;
    data.F = F;
else
    data = load(pathData);
    % data.dFk = load(pathData).dFk;

end



if isfield(data,'dFk')== 0


    F = data.F;
    display('computing df/F')
    w=d.params.horizon-1;
    Fk  = [ones(1,w),F];
    dF=[];
    Fmean=[];
    dFk=[];
    Fkmean=[];

    for i = 1:length(F)
        % Add an LPF filter 
        if mode == 0

        Fkmean = [Fkmean,mean(Fk(i:i+w))];
        dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
        else
        dFk = [dFk,(F(i))/mI(i)*100];
        end

    end
    save(pathData,'dFk');
    data.dFk = dFk;
    data.F = F;
end
