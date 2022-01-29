% NORMALIZE Normalize image to new space
% 
% Required arguments:
%
% img = image to normalize (e.g. CoregFmap)
%       (char | str)
%
% deform_field = deformation field file (e.g. T1DeformationField)
%                (char | str)
%
% bias = bias-corrected image (e.g. T1BiasCorrected)
%        (char | str)
%
% Optional arguments (name-value pairs):
% 
% 'other' = Additional image to normalize (e.g. coregPDMap)
%           (char | str)
%
% 'interp' = Interpolation method (Default = 7)
%            (int)
%            1 | Nearest-Neighbor
%            2 | 
%            3 | 3rd-Degree Polynomial
%            4 | 4th-Degree Polynomial
%            5 | 5th-Degree Polynomial
%            6 | 6th-Degree Polynomial
%            7 | 7th-Degree Polynomial
%
% 'prefix' = File prefix (Default = 'w')
%            (char | str)
%
% 'outdir' = Save path (default = T1ProcessedDir)
%            (char | str)

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');
    
% set required args
img = inputs{1};
deform_field = inputs{2};
bias = inputs{3};

% set default values for optional args
other = '';
interp = 7;
prefix = 'w';
[outdir, ~, ~] = fileparts(img);

% parse name-value args
for k = 4:num_args
    % names are passed on the even index
    if ~mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'other'
                other = inputs{k+1};
            case 'interp'
                interp = inputs{k+1};
                if ~ge(interp, 1) || ~le(interp, 7)
                    error('Normalize: interp value should be in range 1:7');
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('Normalize:outdir: %s is not a valid directory', outdir);
                end
            otherwise
                error('Normalize: unknown argument %s', arg_name);
        end     
    end
end

fprintf('--normalizing images...\n');
fprintf('----image: %s\n', img);

resampleArr = {char(strcat(bias, ',1'))
                char(strcat(img, ',1'))};

if ~isempty(other)
    fprintf('----image: %s\n', other);
    resampleArr{end + 1} = char(strcat(other, ',1'));
end

fprintf('----deformation field: %s\n', deform_field);
fprintf('----bias-corrected image: %s\n', bias);

% spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.spatial.normalise.write.subj.def = {char(deform_field)};
matlabbatch{1}.spm.spatial.normalise.write.subj.resample = resampleArr;
matlabbatch{1}.spm.spatial.normalise.write.wbb = [-78 -112 -70
                                                          78 76 85];
matlabbatch{1}.spm.spatial.normalise.write.wvox = [2 2 2];
matlabbatch{1}.spm.spatial.normalise.write.winterp = interp;
matlabbatch{1}.spm.spatial.normalise.write.wprefix = prefix;

% matlabbatch{2}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
% matlabbatch{2}.spm.spatial.smooth.fwhm = fwhm;
% matlabbatch{2}.spm.spatial.smooth.dtype = 0;
% matlabbatch{2}.spm.spatial.smooth.im = 0;
% matlabbatch{2}.spm.spatial.smooth.prefix = 's';

matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
% matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(outdir)};

spm_jobman('run', matlabbatch)