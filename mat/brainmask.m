function file = brainmask(img, mask, opts)
    % BRAINMASK Apply mask to ASL image
    %
    % Required arguments:
    %
    % img (str | char): Image to apply mask (e.g. CoregFmap)
    %
    % mask (str | char): Mask to apply (e.g. ICVMask)
    %
    % Name-Value arguments:
    %
    % 'expr' (str | char): Expression to apply (Default = 'i1.*i2')
    %
    % 'interp' (int): Interpolation method (Default = -7)
    %            -1 | Nearest-Neighbor
    %            -2 |
    %            -3 | 3rd-Degree Polynomial
    %            -4 | 4th-Degree Polynomial
    %            -5 | 5th-Degree Polynomial
    %            -6 | 6th-Degree Polynomial
    %            -7 | 7th-Degree Polynomial
    %
    % 'outdir' (char | str): Save path (default = base path for img)
    % 
    % 'subject' (char | str): Subject ID (default = current date YYYYMMDD)
    %
    % 'time' (char | str): Time Point (default = current time HHMMSS)
    %
    % 'prefix': (str | char): Prefix to apply to file name (default = 'bmask')
    
    arguments
        img {mustBeFile, mustBeTextScalar};
        mask {mustBeFile, mustBeTextScalar};
        opts.expr {mustBeTextScalar} = 'i1.*i2';
        opts.interp {mustBeInteger, mustBeInRange(opts.interp, -7, -1)} = -7;
        opts.outdir {mustBeTextScalar} = '';
        opts.subject {mustBeTextScalar} = datestr(date, 'yyyymmdd');
        opts.time {mustBeTextScalar} = datestr(now, 'HHMMSS');
        opts.suffix {mustBeTextScalar} = 'bmasked';
    end
    
    % set default outdir here since we can't access `img` in the arguments
    % block
    if isempty(opts.outdir)
        [opts.outdir, ~, ~] = fileparts(img);
    else
        mustBeFolder(opts.outdir);
    end

    % construct the output file name
    outname = strcat(opts.subject, '_', opts.time, '_', opts.suffix, '.nii');

    % spm batch
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;

    matlabbatch{1}.spm.util.imcalc.input = {
                                            char(strcat(mask, ',1'))
                                            char(strcat(img, ',1'))
                                            };
    matlabbatch{1}.spm.util.imcalc.output = char(outname);
    matlabbatch{1}.spm.util.imcalc.outdir = {char(opts.outdir)};
    matlabbatch{1}.spm.util.imcalc.expression = char(opts.expr);
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.mask = 0;
    matlabbatch{1}.spm.util.imcalc.interp = opts.interp;
    matlabbatch{1}.spm.util.imcalc.dtype = 4;

    spm_jobman('run', matlabbatch)
    
    file = fullfile(opts.outdir, outname);
end