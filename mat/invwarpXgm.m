function file = invwarpXgm(img, mask, opts)
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
    % 'expr' = Expression to apply (Default = 'i2.*(i1>0.3)')
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

    arguments
        img {mustBeFile};
        mask {mustBeFile};
        opts.expr {mustBeTextScalar} = 'i2.*(i1>0.3)';
        opts.interp {mustBeInteger, mustBeInRange(opts.interp, -7, -1)} = -7;
        opts.prefix {mustBeTextScalar} = 'w';
        opts.outdir {mustBeFolder} = '';
        opts.subject {mustBeTextScalar} = datestr(date, 'YYYYmmDD');
        opts.time {mustBeTextScalar} = datestr(now, 'HHMMSS');
    end
    
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(img);
    else
        mustBeFolder(opts.outdir);
    end
    
    % construct output file name
    [~, mask_name, ~] = fileparts(mask);
    mask_name = extractAfter(mask_name, '_');
    outname = strcat(opts.prefix, '_', opts.subject, '_gm_', mask_name, '.nii');

    % spm batch
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;

    matlabbatch{1}.spm.util.imcalc.input = {
                                            char(strcat(img,',1'))
                                            char(strcat(mask,',1'))
                                            };
    matlabbatch{1}.spm.util.imcalc.outdir = char(outname);
    matlabbatch{1}.spm.util.imcalc.outdir = {char(opts.outdir)};
    matlabbatch{1}.spm.util.imcalc.expression = opts.expr;
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.mask = 0;
    matlabbatch{1}.spm.util.imcalc.interp = opts.interp;
    matlabbatch{1}.spm.util.imcalc.dtype = 4;

    spm_jobman('run', matlabbatch)
    
    file = fullfile(opts.outdir, outname);
end