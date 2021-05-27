% CALCASLGLOBAL Calculate global ASL value
%
% Required arguments:
% mask = ASL mask (e.g. ASLMask)
%        (char | str)
%
% Optional arguments:
%
% 'outdir' = Save path (Default = ASLDataDir)
%            (char | str)
%
% 'prefix'
%
% 'subj'
%
% 'time'

% get total number of args passed
num_args = evalin('base', 'numel(inputs)');

% set required args
mask = inputs{1};

% set default values for optional args
[fpath, ~, ~] = fileparts(mask);
outdir = fpath;
prefix = 'global';
subj = datestr(now, 'YYYYDDmm'); % date stamp
time = datestr(now, 'HHMMSS'); % time stamp


% parse name-value args
for k = 2:num_args
    % names are passed on the even index
    if ~mod(k,2)
        arg_name = inputs{k};
        switch arg_name
            case 'outdir'
                outdir = inputs{k+1};
                if ~isfolder(outdir)
                    error('CalcGlobal: %s is not a valid directory', outdir);
                end
            case 'prefix'
                prefix = inputs{k+1};
            case 'subj'
                subj = inputs{k+1};
            case 'time'
                time = inputs{k+1};
            otherwise
                error('CalcGlobal: unknown argument %s', arg_name);
        end
    end
end

% construct the output file name
outname = strcat(prefix, '_', subj, '_', time, '_bmasked.csv');

fprintf('--calculating global ASL value...\n');
vol = spm_vol(char(mask));
globalValue = spm_global(vol);
writematrix(globalValue, fullfile(outdir, outname));
