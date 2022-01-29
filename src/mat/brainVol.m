% BRAINVOL calculate segmented brain volumes
% 
% Required arguments:
%
% seg8mat = .mat file created following segmentation
%
% Optional arguments:
%
% mask = mask to apply (default = ICV mask template)
%
% 'prefix'
%
% 'outdir'
%
% 'subj'
    
% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
seg8mat = inputs{1};

% set default values for optional arguments
mask = '/opt/spm12-r7771/spm12_mcr/spm12/tpm/mask_ICV.nii';
prefix = 'segvolumes_t1';
[outdir, ~, ~] = fileparts(seg8mat);
subj = datestr(now, 'YYYYDDmmHHMMSS'); % time stamp

% parse name-value args
for k = 2:num_args
    % names are passed on the even index
    if ~mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'mask'
                mask = inputs{k+1};
                if ~isfile(mask)
                    error('brainVol: %s is not a valid file', mask);
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('brainVol: %s is not a valid directory', outdir);
                end
            case 'subj'
                subj = inputs{k+1};
            otherwise
                error('brainVol: unknown argument %s', arg_name);
        end
    end
end

% status messages
fprintf('--Calculating segmented brain volumes for %s...\n', seg8mat);

% spm batch
spm('defaults', 'FMRI');
spm_jobman('initcfg');
clear matlabbatch;

matlabbatch{1}.spm.util.tvol.matfiles = {char(seg8mat)};
matlabbatch{1}.spm.util.tvol.tmax = 3;
matlabbatch{1}.spm.util.tvol.mask = {char(strcat(mask, ',1'))};
matlabbatch{1}.spm.util.tvol.outf = 'vol';

spm_jobman('run', matlabbatch)

% change variable names
data = readtable('vol.csv');
data.Properties.VariableNames{'Volume1'} = 'gm_(L)';
data.Properties.VariableNames{'Volume2'} = 'wm_(L)';
data.Properties.VariableNames{'Volume3'} = 'csf_(L)';
writetable(data, 'vol.csv');

% custom IO
% this method auto saves it to the pwd, so need to move it to the target dir
newFile = fullfile(outdir, strcat(prefix, '_', subj, '.csv'));
movefile('vol.csv', newFile);