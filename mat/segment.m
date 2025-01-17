% SEGMENT segment T1 image
%
% Requried arguments:
%
% img = T1 image
%
% Optional arguments:
%
% 'outdir' = save directory (default = /path/to/img)

% spm uses assignin to take variables from the command line into the 
% matlab workspace and places them into a cell array called 'inputs'
% by passing the arguments and indexing appropriately, we can get the args
% needed for analysis

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
img = inputs{1};

% set default values for optional args
[fpath, ~, ~] = fileparts(img);
outdir = fpath;

% parse name-value pairs
for k = 2:num_args
    % names are passed on the even index
    if ~mod(k, 2)
        arg_name = inputs{k};
        switch arg_name
            case 'outdir'
                outdir = inputs{k};
            otherwise
                error('segment: unknown argument %s', arg_name);
        end
    end
end

% path is within the docker container
tpmMask = '/opt/spm12-r7771/spm12_mcr/spm12/tpm/TPM.nii';

% start spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.preproc.channel.vols = {char(strcat(img, ',1'))};
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];

matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {strcat(tpmMask, ',1')};
matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {strcat(tpmMask, ',2')};
matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {strcat(tpmMask, ',3')};
matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {strcat(tpmMask, ',4')};
matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {strcat(tpmMask, ',5')};
matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {strcat(tpmMask, ',6')};
matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];

matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1];
matlabbatch{1}.spm.spatial.preproc.warp.vox = NaN;
matlabbatch{1}.spm.spatial.preproc.warp.bb = [NaN NaN NaN
                                                NaN NaN NaN];

matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Segment: Seg Params', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','param', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Segment: Bias Corrected (1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','channel', '()',{1}, '.','biascorr', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(3) = cfg_dep('Segment: c1 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{1}, '.','c', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(4) = cfg_dep('Segment: c2 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','c', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(5) = cfg_dep('Segment: c3 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{3}, '.','c', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(6) = cfg_dep('Segment: c4 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{4}, '.','c', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(7) = cfg_dep('Segment: c5 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{5}, '.','c', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(8) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(outdir)}; 

spm_jobman('run', matlabbatch);