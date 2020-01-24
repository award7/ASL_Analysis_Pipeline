function normalise(deform_field, bias_t1, coreg_fmap, coreg_pdmap)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.normalise.write.subj.def = {[deform_field]};
matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {
                                                            [bias_t1,',1'];
                                                            [coreg_fmap,',1'];
															[coreg_pdmap,',1']
															};
matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
                                                          78 76 85];
matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = 7;
matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
matlabbatch{2}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
matlabbatch{2}.spm.spatial.smooth.fwhm = [8 8 8];
matlabbatch{2}.spm.spatial.smooth.dtype = 0;
matlabbatch{2}.spm.spatial.smooth.im = 0;
matlabbatch{2}.spm.spatial.smooth.prefix = 'smoothed_';

spm_jobman('run', matlabbatch)