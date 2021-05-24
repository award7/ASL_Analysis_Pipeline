% APPLYICVMASK Apply intracranial vault mask to image
%
% Required arguments:
%
% deform_field = deformation field file (e.g. T1DeformationField)
%                    (char | str)
%
% fov = Field of view (e.g. SmoothedGmImage)
%
% Optional arguments:
%
% 'fwhm' = Full-width half max (default = [0 0 0])
%          (single | double)
% 
% 'prefix' = File prefix (default = 'wt1_[subjectID]')
%            (char | str)
%
% 'outdir' = Save path (default = same as /path/to/fov)
%            (char | str)

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
deform_field = inputs{1};
fov = inputs{2};
% path within docker container
mask = '/opt/spm12-r7771/spm12_mcr/spm12/tpm/mask_ICV.nii';

% set default values for optional args
fwhm = [0 0 0];
prefix = 'wt1_';
[fpath, ~, ~] = fileparts(fov);
outdir = fpath;

% parse name-value pairs
for k = 3:num_args
    % names are passed on the odd index
    if mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'fwhm'
                fwhm = str2num(inputs{k+1});
                if size(fwhm, 2) ~= 3
                    error('maskICV: fwhm value should be a 1x3 vector');
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('maskICV:outdir: %s is not a valid directory', outdir);
                end
            otherwise
                error('maskICV: unknown argument %s', arg_name);
        end
    end
end


fprintf('--brain masking ICV...\n');
fprintf('--deformation field: %s\n', deform_field);
fprintf('--field of view: %s\n', fov);

% spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.defs.comp{1}.def = {char(deform_field)};
matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {char(mask)};
matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
matlabbatch{1}.spm.util.defs.out{1}.push.savedir.saveusr = {char(outdir)};
matlabbatch{1}.spm.util.defs.out{1}.push.fov.file = {char(fov)};
matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = fwhm;
matlabbatch{1}.spm.util.defs.out{1}.push.prefix = prefix;

spm_jobman('run', matlabbatch)

% spm doesn't allow dependency-file I/O for deformation utility,
% so need to move and rename ourself
oldFile = fullfile(outdir, 'wmask_ICV.nii');
newFile = fullfile(outdir, strcat(prefix, '_mask_icv.nii'));
movefile(oldFile, newFile);