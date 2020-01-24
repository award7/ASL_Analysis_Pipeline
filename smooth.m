function smooth(IMG)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.smooth.data = {[IMG,',1']} %image to smooth
matlabbatch{1}.spm.spatial.smooth.fwhm = [5 5 5];
matlabbatch{1}.spm.spatial.smooth.dtype = 0;
matlabbatch{1}.spm.spatial.smooth.im = 0;
matlabbatch{1}.spm.spatial.smooth.prefix = 'smoothed_';

spm_jobman('run', matlabbatch)