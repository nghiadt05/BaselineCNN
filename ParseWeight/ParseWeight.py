#!/usr/bin/env python

#Read trained networks' configurations
#Author: Nghia Doan, nghia.doan@mail.mcgill.ca
#Date  : 2017, Nov 29, 11:14 AM

#%%
import numpy as np
import scipy.io

#%%
# weight file
dir = './nghia_CNN.npz'
print('Read from file: ' + dir +'\n')
npzFile = np.load(dir)
print ('All classes: ') 
print (npzFile.files) 
print ('\n')

#%%
# needed files
idx = 3
paW = npzFile['pareto_weights']
paW = paW[idx-1]
paW0 = paW[0]
paW6 = paW[6]
paW12 = paW[12]

#%%
scipy.io.savemat('./conv0.mat', mdict={'paW0': paW0})
scipy.io.savemat('./conv1.mat', mdict={'paW6': paW6})
scipy.io.savemat('./conv2.mat', mdict={'paW12': paW12})
#%%
