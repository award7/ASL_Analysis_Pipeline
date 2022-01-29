classdef AslPipeline < handle
    % Arterial spin labeling (ASL) MRI preprocessing pipeline methods
    % implemented with SPM.
    %% Pipeline Overview
    %   1. Convert raw DICOM images to Nifti.
    %   2. Coregister the structural image with the ASL image.
    %   3. Segment the coregistered image.
    %   4. Smooth the segmented tissue.
    %   5. Normalize the image into MNI space.
    %   6. Create a mask
    %% Methods
    %% dcm2nii
    %   *Description*
    %       Convert raw DICOM images to NIFTI format via SPM DICOM Import tool.
    %   *Parameters* (Name-Value Pairs)
    %       Required
    %           _Source_ (string): Absolute path to directory with raw DICOM images
    %       Optional
    %           _OutName_ (string): New name of file (default = 'image').
    %           _Target_ (string): Absolute path to save new file (default
    %           = current directory)
    %% coregister
    %   *Description*
    %       Coregister reference image with ASL image.
    %   *Parameters* (Name-Value Pairs)
    %       Required
                
    
    methods (Access = public, Static)

        function files = dcm2nii(args)
            arguments
                args.Source     {mustBeFolder};
                args.OutName    {mustBeTextScalar} = 'image';
                args.Target     {mustBeFolder} = pwd;
            end
            
            timestamp = datetime('now');
            
            dir_struct = dir(args.Source);
            dir_struct(1:2) = [];
            files = cell(length(dir_struct),1);
            for i = 1:length(dir_struct)
                files{i} = fullfile(dir_struct(i).folder, dir_struct(i).name);
            end
            
            %% do spm processing
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            % conver dcm to nii
            matlabbatch{1}.spm.util.import.dicom.data = files;
            matlabbatch{1}.spm.util.import.dicom.root = 'flat';
            matlabbatch{1}.spm.util.import.dicom.outdir = {''};
            matlabbatch{1}.spm.util.import.dicom.protfilter = '.*';
            matlabbatch{1}.spm.util.import.dicom.convopts.format = 'nii';
            matlabbatch{1}.spm.util.import.dicom.convopts.meta = 0;
            matlabbatch{1}.spm.util.import.dicom.convopts.icedims = 0;
            
            % move files
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('DICOM Import: Converted Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.moveto = {args.Target};
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.patrep.pattern = '.*';
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.patrep.repl = char(args.OutName);
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.unique = false;
            
            spm_jobman('run', matlabbatch);
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end
        
        function files = coregister(args)
            arguments
                args.ReferenceImage {mustBeFile};
                args.SourceImage    {mustBeFile};
                args.Target         {mustBeFolder};
            end
            
            timestamp = datetime('now');
            
            %% do spm processing
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            % coregister
            matlabbatch{1}.spm.spatial.coreg.estwrite.ref = char(args.ReferenceImage);
            matlabbatch{1}.spm.spatial.coreg.estwrite.source = char(args.SourceImage);
            matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
            
            % move files
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Coregister: Estimate & Reslice: Coregistered Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {args.Target};

            spm_jobman('run', matlabbatch);
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end
        
        function files = segment(args)
            arguments
                args.Image  {mustBeFile};
                args.Map    {mustBeFile} = '';
                args.Target {mustBeFolder} = pwd;
            end
            
            timestamp = datetime('now');
            
            if isempty(args.Map)
                matlab_path_in_parts = strsplit(matlabroot, filesep);
                args.Map = fullfile(matlab_path_in_parts{1:end-1}, "spm12/tpm/TPM.nii");
            end
            
            %% do spm processing
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            % segment into gm, wm, csf
            % get deform field, bias correction, and seg parameters
            matlabbatch{1}.spm.spatial.preproc.channel.vols = char(args.Image);
            matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
            matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
            matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];
            matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {char(strcat(args.Map, ',1'))};
            matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
            matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {char(strcat(args.Map, ',2'))};
            matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
            matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {char(strcat(args.Map, ',3'))};
            matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
            matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
            matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
            matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
            matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
            matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
            matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
            matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
            matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1];
            
            % move files
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Segment: Seg Params', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','param', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Segment: Bias Corrected (1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','channel', '()',{1}, '.','biascorr', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(3) = cfg_dep('Segment: c1 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{1}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(4) = cfg_dep('Segment: c2 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(5) = cfg_dep('Segment: c3 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{3}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(6) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {args.Target};
            
            spm_jobman('run', matlabbatch);
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end
        
        function files = smooth(args)
            arguments
                args.Image  {mustBeFile};
                args.Target {mustBeFolder} = pwd;
            end
            
            timestamp = datetime('now');
            
            %% do spm processing
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            % smooth image
            matlabbatch{1}.spm.spatial.smooth.data = char(args.Image);
            matlabbatch{1}.spm.spatial.smooth.fwhm = [8 8 8];
            matlabbatch{1}.spm.spatial.smooth.dtype = 0;
            matlabbatch{1}.spm.spatial.smooth.im = 0;
            matlabbatch{1}.spm.spatial.smooth.prefix = 's';
            
            % move files
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {args.Target};
            
            spm_jobman('run', matlabbatch);
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end

        function files = brainMask(args)
            arguments
                args.DeformationField   {mustBeFile};
                args.Mask               {mustBeFile} = '';
                args.Target             {mustBeFolder} = pwd;
            end
            
            timestamp = datetime('now');
            
            if isempty(args.Map)
                args.Map = AslPipeline.getTpmPath('File', 'mask_ICV.nii');
            end
            
            %% do spm processing
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            % forward deform
            matlabbatch{1}.spm.util.defs.comp{1}.def(1) = char(args.DeformationField);
            matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {args.Map};
            matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
            matlabbatch{1}.spm.util.defs.out{1}.push.savedir.savepwd = 1;
            matlabbatch{1}.spm.util.defs.out{1}.push.fov.file(1) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{8}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
            matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
            matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = [0 0 0];
            matlabbatch{1}.spm.util.defs.out{1}.push.prefix = '';

            % move and rename forward deform img
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Deformations: Warped Images', substruct('.','val', '{}',{10}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','warped'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.moveto(1) = cfg_dep('Make Directory: Make Directory ''<UNDEFINED>''', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','dir'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.patrep.pattern = '(w)';
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.patrep.repl = 'fwd_';
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveren.unique = false;
            
            spm_jobman('run', matlabbatch);
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end
        
        function files = perfusionImage(args)
            arguments
                args.Image  {mustBeFile};
                args.Mask   {mustBeFile};
                args.Target {mustBeFolder} = pwd;
            end
            
            timestamp = datetime('now');
            
            %% do spm processing
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            % image calculation
            matlabbatch{1}.spm.util.imcalc.input(1) = char(args.Image);
            matlabbatch{1}.spm.util.imcalc.input(2) = char(args.Mask);
            matlabbatch{1}.spm.util.imcalc.output = 'perfusion_image';
            matlabbatch{1}.spm.util.imcalc.outdir(1) = char(args.Target);
            matlabbatch{1}.spm.util.imcalc.expression = 'i1.*i2';
            matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = -7;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
            
            spm_jobman('run', matlabbatch);
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end
        
        function files = quantPerfusion(args)
            arguments
                args.Image  {mustBeFile};
                args.Target {mustBeFolder};
            end
            
            timestamp = datetime('now');
            
            volume = spm_vol(args.Image);
            value = spm_global(volume);
            
            writematrix(value, fullfile(args.Target, "perfusion.txt"));
            
            % get files
            files = AslPipeline.getFilesAsl('Target', args.Target, 'Timestamp', timestamp);
        end
        
    end
    
    % helper methods
    methods (Access = public, Static)

        function files = getFilesAsl(args)
            % return the newly created files
            arguments
                args.Target     {mustBeFolder};
                args.Timestamp  {mustBeA(args.Timestamp, 'datetime')};
            end
            
            s = dir(args.Target);
            s(1:2) = [];
            tbl = struct2table(s);
            tbl.date = datetime(tbl.date);
            records = tbl((tbl.date > args.Timestamp), 1:2);
            files = fullfile(records.folder, records.name);
        end
        
        function fpath = getTpmPath(args)
            % return absolute path to file in [root]/MATLAB/spm12/tpm
            arguments
                args.File {mustBeTextScalar};
            end
            
            matlab_path_in_parts = strsplit(matlabroot, filesep);
            fpath = fullfile(matlab_path_in_parts{1:end-1}, "spm12/tpm", args.File);
            
            % do a validation that the file exists
            try 
                mustBeFile(fpath);
            catch me
                switch me.identifier
                    case 'MATLAB:validators:mustBeFile'
                        error("Error: Could not find file '%s'", fpath);
                end
            end
        end
       

        
    end
    
end