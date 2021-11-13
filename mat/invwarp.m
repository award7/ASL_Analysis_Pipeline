function new_file = invwarp(mask, deform_field, fov, opts)
    % INVWARP Apply inverse warp
    % 
    % Required arguments:
    %
    % mask = Mask to apply
    %        (char | str)
    %
    % deform_field = Deformation field (Default = T1DeformationField)
    %               (char | str)
    %
    % fov = Field of view (Default = SmoothedGMImage)
    %       (char | str)
    %
    % Optional arguments:
    %
    % 'fwhm'
    %
    % 'prefix' = File prefix (Default = 'w')
    %            (char | str)
    %
    % 'outdir' = Save path (Default = AALInvwarpDir)
    %            (char | str)
    %
    % 'subj'
    %
    % 'time'
    
    arguments
        mask {mustBeFile};
        deform_field {mustBeFile};
        fov {mustBeFile};
        opts.fwhm (1,3) double {mustBeVector} = [0 0 0];
        opts.prefix {mustBeTextScalar} = 'w';
        opts.outdir {mustBeTextScalar} = '';
        opts.subject {mustBeTextScalar} = datestr(date, 'YYYYmmDD');
        opts.time {mustBeTextScalar} = datestr(now, 'HHMMSS');
    end

    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(mask);
    else
        mustBeFolder(opts.outdir);
    end
    
    [~, mask_name, ~] = fileparts(mask);

    % spm batch
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;

    matlabbatch{1}.spm.util.defs.comp{1}.def = {char(deform_field)};
    matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {char(mask)};
    matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
    matlabbatch{1}.spm.util.defs.out{1}.push.savedir.saveusr = {char(opts.outdir)};
    matlabbatch{1}.spm.util.defs.out{1}.push.fov.file = {char(fov)};
    matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
    matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = opts.fwhm;
    matlabbatch{1}.spm.util.defs.out{1}.push.prefix = opts.prefix;

    spm_jobman('run', matlabbatch)

    % spm doesn't allow dependency IO for this method
    % need to do it ourself
    old_file = fullfile(opts.outdir, strcat(opts.prefix, mask_name, '.nii'));
    new_file = fullfile(opts.outdir, strcat(opts.prefix, '_', opts.subject, '_', mask_name, '.nii'));
    movefile(old_file, new_file);
end