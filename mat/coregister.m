% COREGISTER Coregister MRI images
%
% Required arguments:
%
% ref = Reference image to coregister functional images to (Default = SmoothedGMImage)
%       (char, str)
%
% src = Functional image that is moved during coregistration (Default = Fmap)
%          (char | str)
%
% Optional arguments (name-value pairs):
% 
% 'other' = Additional functional image to coregister along with source image
%           (char | str)
%
% 'fwhm' = Full-width half max (default = [7 7])
%          (single | double)
%          Must pass the vector as a single string on the command line
%
% 'interp' = Interpolation method (default = 7)
%
% 'prefix' = File prefix (default = 'r')
%            (char | str)
%
% 'outdir' = Save path (default = /path/to/ref)
%            (char | str)


% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
ref = inputs{1};
src = inputs{2};

% set default values for optional args
other = '';
fwhm = [7 7];
interp = 7;
prefix = 'r';
[fpath, ~, ~] = fileparts(ref);
outdir = fpath;

% parse name-value pairs
for k = 3:num_args
    % names are passed on the odd index
    if mod(k, 2)
        arg_name = inputs{k};
        switch inputs{k}
            case 'other'
                other = inputs{k+1};
            case 'fwhm'
                fwhm = str2num(inputs{k+1});
                if size(fwhm, 2) ~= 2
                    error('Coregister: fwhm value should be a 1x2 vector');
                end
            case 'interp'
                interp = inputs{k+1};
                % check if interp val is appropriate
                if ~ge(interp, 1) || ~le(interp, 7)
                    error('Coregister: interp value should be in range 1:7');
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('Coregister:outdir: %s is not a valid directory', outdir);
                end
            otherwise
                error('coregister: unknown argument %s', arg_name);
        end
    end
end

fprintf('--coregistering images...\n');
fprintf('----reference image: %s...\n', ref);
fprintf('----source image: %s...\n', src);
if ~isempty(other)
    fprintf('----other image: %s...\n', other);
end

% spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {char(strcat(ref, ',1'))};
matlabbatch{1}.spm.spatial.coreg.estwrite.source = {char(strcat(src, ',1'))};
if ~isempty(other)
    matlabbatch{1}.spm.spatial.coreg.estwrite.other = {char(strcat(other, ',1'))};
end
matlabbatch{1}.spm.spatial.coreg.estwrite.ecost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estwrite.esep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estwrite.etol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estwrite.efwhm = fwhm;
matlabbatch{1}.spm.spatial.coreg.estwrite.rinterp = interp;
matlabbatch{1}.spm.spatial.coreg.estwrite.rwrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.estwrite.rmask = 0;
matlabbatch{1}.spm.spatial.coreg.estwrite.rprefix = prefix;

matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Coregister: Estimate & Reslice: Coregistered Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(outdir)};

spm_jobman('run', matlabbatch)