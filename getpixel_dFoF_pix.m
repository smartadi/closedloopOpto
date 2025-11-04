function datapix = getpixel_dFoF_pix(d,mode,pixel);


% GETPIXEL_DFOF Summary of this function goes here
%   Detailed explanation goes here


% mode = 0; % from images
% mode = 1; % from svd
r=1;

serverRoot = expPath(d.mn, d.td, d.en);
% pathData = append('pixel',d.td(6:7),d.td(9:10),int2str(d.en),'.mat');



pathData_pix = append(d.mn,'pixel',d.td(6:7),d.td(9:10),int2str(d.en),'pixs','.mat');


if (exist(pathData_pix) == 0) | (r == 0)
    F = [];

    k=d.params.kernel;
    display('computing pixel vals')

    if mode==0
        source_dir ='/mnt/data/brain/';
        source_dir = append(source_dir,d.mn,'/',d.td,'/',num2str(d.en));
        a=dir([source_dir '/*']);
        out=size(a,1);

        out=out-2;
        path = append(source_dir,'/frame-');

    
        for i=1:2:out
            % for i=1:2:5000
            pathim=append(path,num2str(i-1));
            fileID = fopen(pathim,'r');
            A = fread(fileID,[560,560],'uint16')';
            % j=length(pixel);
            f=[];
            for j = 1: length(pixel)
            
            G = mean(A(pixel(2,j)-k:pixel(2,j)+k,pixel(1,j)-k:pixel(1,j)+k),'all');
    
            f = [f;G];
            end
            F = [F,f];
            
            fclose(fileID);
    
        end
    % else
    %     nSV = 500;
    %     [U, V, t, mimg] = loadUVt(serverRoot, nSV);
    %     mimg = mimg';
    %     j=1;
    %     mI = [];
    %     for i = 1:length(V)
    %         mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
    %         mI = [mI,mean(mimg_kernel,'all')];
    %         imkernel = U(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
    %         % size(imkernel)
    %         imstack = mean(imkernel,[1,2]);
    %         % size(imstack)   
    %         F = [F,reshape(imstack,[1,500])*V(:,i)];
    %     end
    % 
    % 
    end
    
    
    display('computing df/F s')

    w=d.params.horizon-1;
    Fk  = [ones(length(pixel),w),F];
    dF=[];
    Fmean=[];
    dFk=[];
    Fkmean=[];

    for i = 1:length(F)
        % for i = 1:5000
        % Add an LPF filter 
        if mode == 0

        

        Fkmean = [Fkmean,mean(Fk(:,i:i+w),2)];
        dFk = [dFk,(Fk(:,i+w)-Fkmean(:,i))./Fkmean(:,i)*100];
        else

        dFk = [dFk,(F(:,i))/mI(i)*100];
        end

    end
    
    
    save(pathData_pix,'dFk','F');
    datapix.dFk = dFk;
    % datapix.F = F;
else
    datapix = load(pathData_pix);
    % data.dFk = load(pathData).dFk;

end



