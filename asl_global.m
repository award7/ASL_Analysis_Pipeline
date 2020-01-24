function asl_global(bmask,output)

% Run spm_global on input image
vol = spm_vol(bmask);
globalvol = spm_global(vol);

outfile = strcat('global_',output,'.csv');

% Save result in global .csv %.txt
% save('global.txt', 'globalvol', '-ascii')
dlmwrite(outfile, globalvol, 'precision', '%f');

end