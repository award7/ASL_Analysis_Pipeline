function coreg(t1_img, fmap, pdmap)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {[t1_img,',1']}; %reference image = smoothed gray matter image
matlabbatch{1}.spm.spatial.coreg.estwrite.source = {[fmap,',1']}; %source image = asl fmap or pdmap
matlabbatch{1}.spm.spatial.coreg.estwrite.other = {[pdmap,',1']}; %other image = pdmap or asl fmap
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 7;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'coreg_';

spm_jobman('run', matlabbatch)