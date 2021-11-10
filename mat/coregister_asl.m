function file = coregister_asl(ref, src, opts)

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
    % Name-Value Arguments:
    % 
    % 'other' = Additional functional image to coregister along with source image
    %           (char | str)
    %
    % 'fwhm' = Full-width half max (default = [7 7])
    %          (single | double)
    %
    % 'interp' = Interpolation method (default = 7)
    %
    % 'prefix' = File prefix (default = 'r')
    %            (char | str)
    %
    % 'outdir' = Save path (default = /path/to/ref)
    %            (char | str)

    arguments
        ref {mustBeFile};
        src {mustBeFile};
        opts.other {mustBeTextScalar} = '';
        opts.fwhm (1,2) double {mustBeVector} = [7 7];
        opts.interp (1,1) {mustBeInteger, mustBeInRange(opts.interp, 1, 7)} = 7;
        opts.prefix {mustBeTextScalar} = 'r';
        opts.outdir {mustBeTextScalar} = '';
    end
    
    if ~isempty(opts.other)
        mustBeFile(opts.other);
    end
    
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(ref);
    else
        mustBeFolder(opts.outdir);
    end
    
    % spm batch
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;

    matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {char(strcat(ref, ',1'))};
    matlabbatch{1}.spm.spatial.coreg.estwrite.source = {char(strcat(src, ',1'))};
    if ~isempty(opts.other)
        matlabbatch{1}.spm.spatial.coreg.estwrite.other = {char(strcat(opts.other, ',1'))};
    end
    matlabbatch{1}.spm.spatial.coreg.estwrite.ecost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estwrite.esep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estwrite.etol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estwrite.efwhm = opts.fwhm;
    matlabbatch{1}.spm.spatial.coreg.estwrite.rinterp = opts.interp;
    matlabbatch{1}.spm.spatial.coreg.estwrite.rwrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.estwrite.rmask = 0;
    matlabbatch{1}.spm.spatial.coreg.estwrite.rprefix = opts.prefix;

    [source_path, ~, ~] = fileparts(src);
    if ~strcmp(opts.outdir, source_path)
        matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Coregister: Estimate & Reslice: Coregistered Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
        matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
        matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(opts.outdir)};
    end
    
    spm_jobman('run', matlabbatch)
    
    % return file name
    file = find_files_for_python_engine(opts.outdir, strcat(opts.prefix, '*'));
end