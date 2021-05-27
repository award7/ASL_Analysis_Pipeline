% SMOOTH Smooth MRI image
%
% Required arguments:
%
% img = Image to smooth 
%       (char | str)
%
% Optional arguments:
%
% 'outdir' = Save path (default = T1ProcessedDir)
%            (char | str)
% 
% 'fwhm' = Full-width half max (default = [5 5 5])
%          (single | double)
% 
% 'prefix' = File prefix (default = 's')
%            (char | str)

% one limitation of using optional args in a script context is the lack
% of good name-value argument parsing. All args from 1..n where n is the 
% index of the last optional arg being passed, must be given for this to 
% work.
% e.g. suppose I just wanted to change the fwhm but keep the default prefix
% i'd still need to pass the default prefix like such
% smooth /path/to/img.nii /path/to/dir s [8 8 8]

num_args = evalin('base', 'numel(inputs)');

% set required args
img = inputs{1};

% set default values for optional args
[outdir, ~, ~] = fileparts(img);
prefix = 's';
fwhm = [5 5 5];

% parse name-value pairs
for k = 2:num_args
    % names are passed on the even index
    if ~mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'outdir'
                outdir = inputs{k+1};
            case 'prefix'
                prefix = inputs{k+1};
            case 'fwhm'
                fwhm = inputs{k+1};
                if size(fwhm, 2) ~= 3
                    error('Smooth: fwhm value should be a 1x3 vector');
                end
            otherwise
                error('smooth: unknown argument %s', arg_name);
        end
    end
end

fprintf('--Smoothing image: %s...\n', img);
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.smooth.data = {char(strcat(img, ',1'))};
matlabbatch{1}.spm.spatial.smooth.fwhm = fwhm;
matlabbatch{1}.spm.spatial.smooth.dtype = 0;
matlabbatch{1}.spm.spatial.smooth.im = 0;
matlabbatch{1}.spm.spatial.smooth.prefix = prefix;

matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(outdir)};

spm_jobman('run', matlabbatch)