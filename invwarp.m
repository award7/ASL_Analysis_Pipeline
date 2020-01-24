function invwarp(deform_field,smooth_gm,dir)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.defs.comp{1}.def = {[deform_field]};
matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {'C:\Users\atward\Documents\MATLAB\aal_for_SPM12\aal.nii'}; %hard coded right now; make dynamic
matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
matlabbatch{1}.spm.util.defs.out{1}.push.savedir.savepwd = 1; %save to pwd
matlabbatch{1}.spm.util.defs.out{1}.push.fov.file = {[smooth_gm]};
matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = [0 0 0];
matlabbatch{1}.spm.util.defs.out{1}.push.prefix = 'invwarp_';

spm_jobman('run', matlabbatch)