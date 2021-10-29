function normalize_t1(img, deform_field, bias, opts)
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
    
    arguments
        img {mustBeFile};
        deform_field {mustBeFile};
        bias {mustBeFile};
        opts.other {mustBeTextScalar} = '';
        opts.interp {mustBeInteger, mustBeInRange(opts.interp, 1, 7)} = 7;
        opts.prefix {mustBeTextScalar} = 'w';
        opts.outdir {mustBeFolder} = '';
    end
    
    if ~isempty(opts.other)
        mustBeFile(opts.other)
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

    matlabbatch{1}.spm.spatial.normalise.write.subj.def = {char(deform_field)};
    matlabbatch{1}.spm.spatial.normalise.write.subj.resample = {char(strcat(bias, ',1'))
                                                                char(strcat(img, ',1'))
                                                                char(strcat(opts.other, ',1'))};
    matlabbatch{1}.spm.spatial.normalise.write.wbb = [-78 -112 -70
                                                              78 76 85];
    matlabbatch{1}.spm.spatial.normalise.write.wvox = [2 2 2];
    matlabbatch{1}.spm.spatial.normalise.write.winterp = opts.interp;
    matlabbatch{1}.spm.spatial.normalise.write.wprefix = opts.prefix;

    % matlabbatch{2}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    % matlabbatch{2}.spm.spatial.smooth.fwhm = fwhm;
    % matlabbatch{2}.spm.spatial.smooth.dtype = 0;
    % matlabbatch{2}.spm.spatial.smooth.im = 0;
    % matlabbatch{2}.spm.spatial.smooth.prefix = 's';

    % matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    % matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
    % matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(opts.outdir)};

    spm_jobman('run', matlabbatch);
    
    % TODO: move file, return file path
end