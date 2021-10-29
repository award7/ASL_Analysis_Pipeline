function new_file = icv_mask(deform_field, fov, opts)
    % APPLYICVMASK Apply intracranial vault mask to image
    %
    % Required arguments:
    %
    % deform_field = deformation field file (e.g. T1DeformationField)
    %                    (char | str)
    %
    % fov = Field of view (e.g. SmoothedGmImage)
    %
    % Optional arguments:
    %
    % 'fwhm' = Full-width half max (default = [0 0 0])
    %          (single | double)
    % 
    % 'prefix' = File prefix (default = 'wt1')
    %            (char | str)
    %
    % 'outdir' = Save path (default = same as /path/to/fov)
    %            (char | str)

    arguments
        deform_field {mustBeFile};
        fov {mustBeFile};
        opts.fwhm (1,3) double {mustBeVector} = [0 0 0];
        opts.prefix {mustBeTextScalar} = 'wt1';
        opts.outdir {mustBeFolder} = '';
    end
    
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(deform_field);
    else
        mustBeFolder(opts.outdir);
    end
    
    % TODO: set path for vm
    % path within docker container
    mask = '/opt/spm12-r7771/spm12_mcr/spm12/tpm/mask_ICV.nii';

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

    % spm doesn't allow dependency-file I/O for deformation utility,
    % so need to move and rename ourself
    old_file = fullfile(outdir, 'wmask_ICV.nii');
    new_file = fullfile(outdir, strcat(opts.prefix, '_mask_icv.nii'));
    movefile(old_file, new_file);
end