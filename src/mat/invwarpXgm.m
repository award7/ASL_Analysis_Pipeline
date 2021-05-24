% INVWARPXGM Restrict mask to gray matter image
%
% Required arguments:
%
% img = Image to multiply (Default = GMImage)
%       (char | str)
%
% mask = Mask to apply
%        (char | str)
%
% Optional arguments:
%
% 'expr' = Expression to apply (Default = 'i2.*(i1>0/3)')
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
% 'prefix' = File prefix (Default = 'w')
%            (char | str)
% 
% 'outdir' = Save path (default = AALInvwarpXgmDir)
%            (char | str)
%
% 'subj'
%
% 'time'

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
img = inputs{1};
mask = inputs{2};

% set default values for optional args
expr = 'i2.*(i1>0.3)';
interp = -7;
prefix = 'w';
[outdir, ~, ~] = fileparts(img);
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
                    error('invwarpXgm: interp value must be in range of -7:-1');
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('invwarpXgm: %s is not a valid directory', outdir);
                end
            case 'subj'
                subj = inputs{k+1};
            case 'time'
                time = inputs{k+1};
            otherwise
                error('inwarpXgm: unknown argument %s', arg_name);
        end
    end
end

% construct output file name
[~, maskName, ~] = fileparts(mask);
maskName = extractAfter(maskName, '_');
outname = strcat(prefix, '_', subj, '_GM_', maskName, '.nii');

% status messages
fprintf('--Restricting %s to gray matter...\n', maskName);

% spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.imcalc.input = {
                                        char(strcat(img,',1'))
                                        char(strcat(mask,',1'))
                                        };
matlabbatch{1}.spm.util.imcalc.outdir = char(outname);
matlabbatch{1}.spm.util.imcalc.outdir = {char(outdir)};
matlabbatch{1}.spm.util.imcalc.expression = expr;
matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
matlabbatch{1}.spm.util.imcalc.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.mask = 0;
matlabbatch{1}.spm.util.imcalc.interp = interp;
matlabbatch{1}.spm.util.imcalc.dtype = 4;

spm_jobman('run', matlabbatch)