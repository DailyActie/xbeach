function ploterr()
varname={['HRMS_H_I'],['HRMS_L_O'],['URMS'],['URMS_L_O'],['U_M_E_A_N'],['SEDERO'],['VOL'],['R']}
sens='\gamma';
x=0.5:0.01:0.55;
for j=1:length(varname)
    fname=[varname{j} '.err'];
    fi=fopen(fname)
    i=0
    while 1
        i=i+1
        l=fgetl(fi)
        if l==-1, break, end
        [testid,l]=strtok(l)
        [runid,l]=strtok(l)
        [err,l]=strtok(l)
        r2(i,j)=str2num(err)
        [err,l]=strtok(l)
        slope(i,j)=str2num(err)
        [err,l]=strtok(l)
        eps(i,j)=str2num(err)
        [err,l]=strtok(l)
        bss(i,j)=str2num(err)
    end
    figure(4)
    subplot(3,3,j)
    plot(x,r2(:,j))
    title(varname{j});xlabel(sens);ylabel('r^2')
    figure(5)
    subplot(3,3,j)
    plot(x,slope(:,j))
    title(varname{j});xlabel(sens);ylabel('slope')
    figure(6)
    subplot(3,3,j)
    plot(x,eps(:,j))
    title(varname{j});xlabel(sens);ylabel('\epsilon')
    figure(7)
    subplot(3,3,j)
    plot(x,bss(:,j))
    title(varname{j});xlabel(sens);ylabel('bss')
end
figure(4)
subplot(3,3,j+1)
plot(x,mean(r2,2))
title('MEAN');xlabel(sens);ylabel('r^2')
figure(5)
subplot(3,3,j+1)
plot(x,mean(slope,2))
title('MEAN');xlabel(sens);ylabel('slope')
figure(6)
subplot(3,3,j+1)
plot(x,mean(eps,2))
title('MEAN');xlabel(sens);ylabel('\epsilon')
figure(7)
subplot(3,3,j+1)
plot(x,mean(bss,2))
title('MEAN');xlabel(sens);ylabel('bss')