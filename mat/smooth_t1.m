function file = smooth_t1(img, opts)
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

    arguments
        img {mustBeFile};
        opts.fwhm (1,3) double {mustBeVector} = [5 5 5];
        opts.prefix {mustBeTextScalar} = 's';
        opts.outdir {mustBeTextScalar} = '';
    end
    
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(img);
    else
        mustBeFolder(opts.outdir);
    end
    
    % spm batch
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;

    matlabbatch{1}.spm.spatial.smooth.data = {char(strcat(img, ',1'))};
    matlabbatch{1}.spm.spatial.smooth.fwhm = opts.fwhm;
    matlabbatch{1}.spm.spatial.smooth.dtype = 0;
    matlabbatch{1}.spm.spatial.smooth.im = 0;
    matlabbatch{1}.spm.spatial.smooth.prefix = opts.prefix;

    [source_path, ~, ~] = fileparts(img);
    if ~strcmp(opts.outdir, source_path)
        matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
        matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(opts.outdir)};
    end

    spm_jobman('run', matlabbatch);

    % return file
    file = find_files_for_python_engine(opts.outdir, strcat(opts.prefix, '*'));

end