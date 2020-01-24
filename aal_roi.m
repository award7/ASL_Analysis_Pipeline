function bmask(gm_img,aal_img,DIR)

spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.imcalc.input = {
                                        [gm_img,',1'];
                                        [aal_img,',1']
                                        };
matlabbatch{1}.spm.util.imcalc.output = 'roi_';
matlabbatch{1}.spm.util.imcalc.outdir = {[DIR]};
matlabbatch{1}.spm.util.imcalc.expression = 'i2.*(i1>0.3)';
matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = -7;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

spm_jobman('run', matlabbatch)