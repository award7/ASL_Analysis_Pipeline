function brain_vol(IMG)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.tvol.matfiles = {[IMG]};
matlabbatch{1}.spm.util.tvol.tmax = 3;
matlabbatch{1}.spm.util.tvol.mask = {'C:\Users\atward\Documents\MATLAB\spm12\tpm\mask_ICV.nii,1'};
matlabbatch{1}.spm.util.tvol.outf = 'Brain_Volumes';

spm_jobman('run', matlabbatch)