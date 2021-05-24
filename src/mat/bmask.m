% APPLYBRAINMASK Apply mask to ASL image
%
% Required arguments:
%
% img = Image to apply mask (e.g. CoregFmap)
%       (char | str)
%
% mask = Mask to apply (e.g. ICVMask)
%        (char | str)
%
% Optional arguments:
%
% 'expr' = Expression to apply (Default = 'i1.*i2')
%          (char | str)
%
% 'interp' = Interpolation method (Default = -7)
%            (int)
%            1 | Nearest-Neighbor
%            2 | 
%            3 | 3rd-Degree Polynomial
%            4 | 4th-Degree Polynomial
%            5 | 5th-Degree Polynomial
%            6 | 6th-Degree Polynomial
%            7 | 7th-Degree Polynomial
%
% 'outdir' = Save path (default = /path/to/img)
%            (char | str)
%
% 'subj' = Subject ID (default = current date YYYYMMDD)
%
% 'time' = Time Point (default = current time HHMMSS)

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
img = inputs{1};
mask = inputs{2};

% set default values for optional args
expr = 'i1.*i2';
interp = -7;
[fpath, ~, ~] = fileparts(img);
outdir = fpath;
prefix = 'rasl_fmap';
subj = datestr(now, 'YYYYDDmm'); % date stamp
time = datestr(now, 'HHMMSS'); % time stamp
    
% parse name-value args
for k = 3:num_args
    % names are passed on the odd index
    if mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'expr'
                expr = inputs{k+1};
            case 'interp'
                interp = inputs{k+1};
                if ~ge(interp, -7) || ~le(interp, -1)
                    error('Brainmask: interp value must be in range of -7:-1');
                end
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('Brainmask: %s is not a valid directory', outdir);
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'subj'
                subj = inputs{k+1};
            case 'time'
                time = inputs{k+1};
            otherwise
                error('bmask: unknown argument %s', arg_name);
        end
    end
end

% construct the output file name
outname = strcat(prefix, '_', subjectID, '_', timePoint, '_bmasked.nii');

% status messages
fprintf('--applying brainmask to ASL image...\n');
fprintf('----brainmask image: %s\n', mask);
fprintf('----image: %s\n', img);

% spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.imcalc.input = {
                                        char(strcat(mask, ',1'))
                                        char(strcat(img, ',1'))
                                        };
matlabbatch{1}.spm.util.imcalc.output = char(outname);
matlabbatch{1}.spm.util.imcalc.outdir = {char(output)};
matlabbatch{1}.spm.util.imcalc.expression = char(expr);
matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
matlabbatch{1}.spm.util.imcalc.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.mask = 0;
matlabbatch{1}.spm.util.imcalc.interp = interp;
matlabbatch{1}.spm.util.imcalc.dtype = 4;

spm_jobman('run', matlabbatch)