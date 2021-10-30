function newFile = brain_volumes(seg8mat, opts)

    % BRAINVOL calculate segmented brain volumes
    % 
    % Required arguments:
    %
    % seg8mat (char | str): `.mat` file created following segmentation
    %
    % Name-Value arguments:
    %
    % 'mask' (char | str): mask to apply (default = ICV mask template)
    %
    % 'prefix' (char | str)
    %
    % 'outdir' (char | str): Output path (default = base path for seg8mat)
    %
    % 'subject' (char | str): Subject ID (default = current date YYYYmmDD)
    
    % set default values for optional arguments
    arguments
        seg8mat {mustBeFile};
        % TODO: set the file path
        opts.mask {mustBeFile} = '/usr/local/MATLAB/R2021a/spm12/tpm/mask_ICV.nii';
        opts.prefix {mustBeTextScalar} = 'seg_volumes_t1';
        opts.outdir {mustBeTextScalar} = '';
        opts.subject {mustBeTextScalar} = datestr(now, 'YYYYDDmmHHMMSS');
    end
    
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(seg8mat);
    else
        mustBeFolder(opts.outdir);
    end
    
    % spm batch
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;

    matlabbatch{1}.spm.util.tvol.matfiles = {char(seg8mat)};
    matlabbatch{1}.spm.util.tvol.tmax = 3;
    matlabbatch{1}.spm.util.tvol.mask = {char(strcat(opts.mask, ',1'))};
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
    newFile = fullfile(opts.outdir, strcat(opts.prefix, '_', opts.subject, '.csv'));
    movefile('vol.csv', newFile);
end