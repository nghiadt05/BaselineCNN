%%
clc; close all; clear all;

%% Load weight values
load 'conv0.mat';
load 'conv1.mat';
load 'conv2.mat';

%%
conv_size = size(paW0);
f_conv = fopen('conv0.txt','w');
for h = 1:conv_size(1,3)
    for k = 1:conv_size(1,4)
        for i=1:conv_size(1,1)
            for j=1:conv_size(1,2)
                fprintf(f_conv,'%0.5f\n',paW0(i,j,h,k));
            end
        end
    end
end
fclose(f_conv);

conv_size = size(paW6);
f_conv = fopen('conv1.txt','w');
for h = 1:conv_size(1,3)
    for k = 1:conv_size(1,4)
        for i=1:conv_size(1,1)
            for j=1:conv_size(1,2)
                fprintf(f_conv,'%0.5f\n',paW6(i,j,h,k));
            end
        end   
    end
end
fclose(f_conv);

conv_size = size(paW12);
f_conv = fopen('conv2.txt','w');
for h = 1:conv_size(1,3)
    for k = 1:conv_size(1,4)
        for i=1:conv_size(1,1)
            for j=1:conv_size(1,2)
                fprintf(f_conv,'%0.5f\n',paW12(i,j,h,k));
            end
        end
    end
end
fclose(f_conv);
        