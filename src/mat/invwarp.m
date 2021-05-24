% INVWARP Apply inverse warp
% 
% Required arguments:
%
% mask = Mask to apply
%        (char | str)
%
% deform_field = Deformation field (Default = T1DeformationField)
%               (char | str)
%
% fov = Field of view (Default = SmoothedGMImage)
%       (char | str)
%
% Optional arguments:
%
% 'fwhm'
%
% 'prefix' = File prefix (Default = 'w')
%            (char | str)
%
% 'outdir' = Save path (Default = AALInvwarpDir)
%            (char | str)
%
% 'subj'
%
% 'time'

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
mask = inputs{1};
deform_field = inputs{2};
fov = inputs{3};

% set default values for optional args
prefix = 'w';
[fpath, ~, ~] = fileparts(fov);
outdir = fpath;
subj = datestr(now, 'YYYYDDmm'); % date stamp
time = datestr(now, 'HHMMSS'); % time stamp
fwhm = [0 0 0];

% parse name-value args
for k = 4:num_args
    % names are passed on the even index
    if ~mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'prefix'
                prefix = inputs{k+1};
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('invwarp: %s is not a valid directory', outdir);
                end
            case 'subj'
                subj = inputs{k+1};
            case 'time'
                time = inputs{k+1};
            case 'fwhm'
                fwhm = str2num(inputs{k+1});
                if size(fwhm, 2) ~= 3
                    error('invwarp: fwhm should be a 1x3 vector');
                end
            otherwise
                error('inwarp: unknown argument %s', arg_name);
        end
    end
end

[~, maskName, ~] = fileparts(mask);

% status messages
fprintf('--applying deformation field to %s...\n', maskName);
fprintf('--deformation field: %s\n', deform_field);
fprintf('--fov: %s\n', fov);

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

% spm doesn't allow dependency IO for this method
% need to do it ourself
oldFile = fullfile(outdir, strcat(prefix, maskName, '.nii'));
newFile = fullfile(outdir, strcat(prefix, '_', subj, '_', maskName, '.nii'));
movefile(oldFile, newFile);