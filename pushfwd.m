function pushfwd(deform_field,smoothed_gm)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.defs.comp{1}.def = {[deform_field]}; %deformation field (e.g. y file)
matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {'C:\Users\atward\Documents\MATLAB\spm12\tpm\mask_ICV.nii'}; %hard coded right now; make dynamic
matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
matlabbatch{1}.spm.util.defs.out{1}.push.savedir.savepwd = 1; %save to pwd
matlabbatch{1}.spm.util.defs.out{1}.push.fov.file = {[smoothed_gm]}; %smoothed gm file
matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = [0 0 0];
matlabbatch{1}.spm.util.defs.out{1}.push.prefix = 'pushfwd_';

spm_jobman('run', matlabbatch)