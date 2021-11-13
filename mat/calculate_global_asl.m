function file = calculate_global_asl(mask, opts)
    % CALCULATEGLOBALASL Calculate global ASL value
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
    % 'subject'
    %
    % 'time'

    % set default values for optional args
    
    arguments
        mask {mustBeFile, mustBeTextScalar};
        opts.outdir {mustBeTextScalar} = '';
        opts.prefix {mustBeTextScalar} = 'global';
        opts.subject {mustBeTextScalar} = datestr(now, 'YYYYDDmm');
        opts.time {mustBeTextScalar} = datestr(now, 'HHMMSS');
    end
    
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(mask);
    else
        mustBeFolder(opts.outdir);
    end

    % construct the output file name
    outname = strcat(opts.prefix, '_', opts.subject, '_', opts.time, '_bmasked.csv');

    vol = spm_vol(char(mask));
    globalValue = spm_global(vol);
    file = fullfile(opts.outdir, outname);
    writematrix(globalValue, file);
end