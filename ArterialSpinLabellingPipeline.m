classdef ArterialSpinLabellingPipeline < handle
    % Class of spm functions to perform asl preprocessing in spm
    % 
    % These steps follow the University of Wisconsin's Alzheimers
    % Disease Research Center's procedure

    % Typical workflow is:
        % * segment
        % * smooth
        % * coregister
        % * normalize
        % * smooth
        % * apply icv mask
        % * apply brain mask
        % * inverse warp
        % * inverse warp gm
        % * calculate brain volumes
        % * calculate global ASL value

    % Dependencies: 
        % R2020b or newer
        % spm12

    % Assumptions:
        % Raw t1 files have been converted to .nii (e.g. via dcm2niix)
        % file has undergone afni to3d transformations and 3df_pcasl
        % (proprietary GE binary) that produces fmap.nii and pdmap.nii
        % images
            % Note: other images processed without these steps may be
            % acceptable as well, however, this is not tested for such
            % cases
        %
        % File directories are setup as:
            % asl/{data,raw,proc}
            % t1/{data,raw,proc}
            % masks/{aal,lobes}/{invwarp,invwarpXgm}
        % with any processed files placed in the 'proc' directory
        %
        % Mask templates 
    
    properties(Access = public)
        ASLPath;
        SubjectDir;
        SubjectID;
        T1Path;
    end
    
    properties(Dependent)
        AALInvwarpDir;
        AALInvwarpXgmDir;
        AALMasks;
        ASLDataDir;
        ASLMask;
        ASLProcessedDir;
        CoregFmap;
        CoregPDmap;
        Fmap;
        GMImage  
        GlobalASL;
        ICVMask;
        ICVMaskTemplate;
        LobeInvwarpDir;
        LobeInvwarpXgmDir;
        LobeMasks;
        NormalizedCoregFmap;
        NormalizedCoregPDmap;
        NormalizedGMImage;
        PDmap;
        SmoothedGMImage;
        SmoothedNormalizedCoregFmap;
        SmoothedNormalizedCoregPDmap;
        SmoothedNormalizedGMImage;
        T1BiasCorrected;
        T1DataDir;
        T1DeformationField;
        T1Image;
        T1ProcessedDir;
        T1Seg8Mat;
        TPMMaskTemplate;
    end
    
    methods(Access = public)
        
        function self = ArterialSpinLabellingPipeline(subject, subjDir, aslDir, t1Dir)
            % ARTERIALSPINLABELLINGPIPELINE Instantiate ArterialSpinLabellingPipeline class object
            %
            % Required arguments:
            %
            % subjDirectory = subject directory
            %                 (char | str)
            %
            % aslDirectory = ASL directory
            %                (char | str)
            %
            % t1Directory = T1 directory
            %               (char | str)
            
            arguments
                subject     {mustBeTextScalar};
                subjDir     {mustBeFolder};
                aslDir      {mustBeFolder};
                t1Dir       {mustBeFolder};
            end
            
            self.SubjectID = subject;
            self.SubjectDir = subjDir;
            self.ASLPath = aslDir;
            self.T1Path = t1Dir;
        end
        
    end
    
    methods(Access = public)
        
        function segment(self, img, options)
            % SEGMENT Segments image into different volumes using the SPM
            % TPM mask
            %
            % Required arguments:
            %
            % img = image to segment
            %       (char | str)
            %
            % Optional arguments (name-value pairs)
            % 
            % 'output' = Save path (default = T1ProcessedDir)
            %            (char | str)
            
            arguments
                self            ArterialSpinLabellingPipeline;
                img             {mustBeFile} = self.T1Image;
                options.output  {mustBeFolder} = self.T1ProcessedDir;
            end
            
            fprintf('--segmenting image...\n');
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;

            tpmMask = char(self.TPMMaskTemplate);

            matlabbatch{1}.spm.spatial.preproc.channel.vols = {char(strcat(img, ',1'))};
            matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
            matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
            matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];

            matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {strcat(tpmMask, ',1')};
            matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
            matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];

            matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {strcat(tpmMask, ',2')};
            matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
            matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];

            matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {strcat(tpmMask, ',3')};
            matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
            matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];

            matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {strcat(tpmMask, ',4')};
            matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
            matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];

            matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {strcat(tpmMask, ',5')};
            matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
            matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];

            matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {strcat(tpmMask, ',6')};
            matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
            matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
            matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];

            matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
            matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
            matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
            matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
            matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
            matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
            matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1];
            matlabbatch{1}.spm.spatial.preproc.warp.vox = NaN;
            matlabbatch{1}.spm.spatial.preproc.warp.bb = [NaN NaN NaN
                                                          NaN NaN NaN];

            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Segment: Seg Params', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','param', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Segment: Bias Corrected (1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','channel', '()',{1}, '.','biascorr', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(3) = cfg_dep('Segment: c1 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{1}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(4) = cfg_dep('Segment: c2 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(5) = cfg_dep('Segment: c3 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{3}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(6) = cfg_dep('Segment: c4 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{4}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(7) = cfg_dep('Segment: c5 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{5}, '.','c', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(8) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(options.output)}; % {char(self.T1ProcessedDir)};

            spm_jobman('run', matlabbatch);
        end
        
        function smooth(self, img, options)
            % SMOOTH Smooth MRI image
            %
            % Required arguments:
            %
            % img = Image to smooth 
            %       (char | str)
            %
            % Optional arguments (name-value pairs):
            % 
            % 'fwhm' = Full-width half max (default = [5 5 5])
            %          (single | double)
            % 
            % 'prefix' = File prefix (default = 's')
            %            (char | str)
            % 
            % 'output' = Save path (default = T1ProcessedDir)
            %            (char | str)
            
            arguments
                self            ArterialSpinLabellingPipeline;
                img             {mustBeFile} = self.GMImage;
                options.fwhm    (1,3) double {mustBeReal} = [5 5 5];
                options.prefix  {mustBeTextScalar} = 's';
                options.output  {mustBeTextScalar, mustBeFolder} = self.T1ProcessedDir;
            end
            
            fprintf('--Smoothing image: %s...\n', img);
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            matlabbatch{1}.spm.spatial.smooth.data = {char(strcat(img, ',1'))};
            matlabbatch{1}.spm.spatial.smooth.fwhm = options.fwhm;
            matlabbatch{1}.spm.spatial.smooth.dtype = 0;
            matlabbatch{1}.spm.spatial.smooth.im = 0;
            matlabbatch{1}.spm.spatial.smooth.prefix = options.prefix;
            
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(options.output)};

            spm_jobman('run', matlabbatch)
        end
        
        function coregister(self, ref, source, options)
            % COREGISTER Coregister MRI images
            %
            % Required arguments:
            %
            % ref = Reference image to coregister functional images to (Default = SmoothedGMImage)
            %       (char, str)
            %
            % source = Functional image that is moved during coregistration (Default = Fmap)
            %          (char | str)
            % 
            % Optional arguments (name-value pairs):
            % 
            % 'other' = Additional functional image to coregister along with source image
            %           (char | str)
            %
            % 'fwhm' = Full-width half max (default = [7 7])
            %          (single | double)
            % 
            % 'prefix' = File prefix (default = 'r')
            %            (char | str)
            %
            % 'output' = Save path (default = ASLProcessedDir)
            %            (char | str)
            
            arguments
                self                ArterialSpinLabellingPipeline;
                ref                 {mustBeFile} = self.SmoothedGMImage;
                source              {mustBeFile} = self.Fmap;
                options.other       {mustBeFile} % = self.PDmap;
                options.fwhm        (1,2) double {mustBeReal} = [7 7];
                options.interp      double {mustBeInteger, mustBeInRange(options.interp, 1, 7)} = 7;
                options.prefix      {mustBeTextScalar} = 'r';
                options.ouptut      {mustBeFolder} = self.ASLProcessedDir;
            end
            
            fprintf('--coregistering images...\n');
            fprintf('----reference image: %s...\n', ref);
            fprintf('----source image: %s...\n', source);
            if isfiled(options, 'otherImg')
                fprintf('----other image: %s...\n', options.otherImg);
            end
            
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;

            matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {char(strcat(ref, ',1'))};
            matlabbatch{1}.spm.spatial.coreg.estwrite.source = {char(strcat(source, ',1'))};
            if ~isempty(options.otherImg)
                matlabbatch{1}.spm.spatial.coreg.estwrite.other = {char(strcat(options.otherImg, ',1'))};
            end
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = options.fwhm;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = options.interp;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = options.prefix;
            
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Coregister: Estimate & Reslice: Coregistered Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','cfiles'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(options.output)};

            spm_jobman('run', matlabbatch)
        end
        
        function normalize(self, deformField, bias, img, options)
            % NORMALIZE Normalize image to new space
            % 
            % Required arguments:
            %
            % deformationField = deformation field file (Default = T1DeformationField)
            %                    (char | str)
            %
            % bias = bias-corrected image (Default = T1BiasCorrected)
            %        (char | str)
            %
            % img = image to normalize (Default = CoregFmap)
            %       (char | str)
            % 
            % Optional arguments (name-value pairs):
            % 
            % 'other' = Additional image to normalize
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
            % 'output' = Save path (default = T1ProcessedDir)
            %            (char | str)
            
            arguments
                self                ArterialSpinLabellingPipeline;
                deformField         {mustBeFile} = self.T1DeformationField;
                bias                {mustBeFile} = self.T1BiasCorrected;
                img                 {mustBeFile} = self.CoregFmap;
                options.other       {mustBeFile} % = self.CoregPDmap;
                options.interp      {mustBeInteger, mustBeInRange(options.interp, 1, 7)} = 7;
                options.prefix      {mustBeTextScalar} = 'w';
                options.output      {mustBeFolder} = self.T1ProcessedDir;
            end

            % fprintf('--normalizing and smoothing coregistered images...\n');
            fprintf('--normalizing images...\n');
            fprintf('----deformation field: %s\n', deformField);
            fprintf('----bias-corrected image: %s\n', bias);
            fprintf('----image: %s\n', img);
            
            resampleArr = {char(strcat(bias, ',1'))
                            char(strcat(img, ',1'))};

            if isfield(options, 'other')
                fprintf('----image: %s\n', options.other);
                resampleArr{end + 1} = char(strcat(options.other, ',1'));
            end
            
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            matlabbatch{1}.spm.spatial.normalise.write.subj.def = {char(deformField)};
            matlabbatch{1}.spm.spatial.normalise.write.subj.resample = resampleArr;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
                                                                      78 76 85];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
            matlabbatch{1}.spm.spatial.normalise.write.woptions.interp = options.interp;
            matlabbatch{1}.spm.spatial.normalise.write.woptions.prefix = options.prefix;
            
%             matlabbatch{2}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
%             matlabbatch{2}.spm.spatial.smooth.fwhm = [8 8 8];
%             matlabbatch{2}.spm.spatial.smooth.dtype = 0;
%             matlabbatch{2}.spm.spatial.smooth.im = 0;
%             matlabbatch{2}.spm.spatial.smooth.prefix = 's';
            
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Normalise: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
%             matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Smooth: Smoothed Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
            matlabbatch{2}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {char(options.output)};

            spm_jobman('run', matlabbatch)
        end
        
        function applyIcvMask(self, deformField, fov, options)
            % APPLYICVMASK Apply intracranial vault mask to image
            %
            % Required arguments:
            %
            % deformationField = deformation field file (Default = T1DeformationField)
            %                    (char | str)
            %
            % fov = Field of view (Default = SmoothedGmImage)
            %
            % Optional arguments:
            %
            % 'fwhm' = Full-width half max (default = [0 0 0])
            %          (single | double)
            % 
            % 'prefix' = File prefix (default = 'wt1_[subjectID]')
            %            (char | str)
            %
            % 'output' = Save path (default = T1ProcessedDir)
            %            (char | str)
            
            arguments
                self                ArterialSpinLabellingPipeline;
                deformField         {mustBeFile} = self.T1DeformationField;
                fov                 {mustBeFile} = self.SmoothedGMImage;
                options.fwhm        (1,3) {mustBeReal, mustBeA(options.fwhm, {'single', 'double'})} = [0 0 0];
                options.prefix      {mustBeTextScalar} = strcat('wt1_', self.getCondensedSubjectID);
                options.output      {mustBeFolder} = self.T1ProcessedDir;
            end
            
            fprintf('--brain masking ICV...\n');
            fprintf('--deformation field: %s\n', deformField);
            fprintf('--field of view: %s\n', fov);

            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;

            matlabbatch{1}.spm.util.defs.comp{1}.def = {char(deformField)};
            matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {char(self.ICVMaskTemplate)};
            matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
            matlabbatch{1}.spm.util.defs.out{1}.push.savedir.saveusr = {char(options.output)};
            matlabbatch{1}.spm.util.defs.out{1}.push.fov.file = {char(fov)};
            matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
            matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = options.fwhm;
            matlabbatch{1}.spm.util.defs.out{1}.push.prefix = 'w';

            spm_jobman('run', matlabbatch)
            
            % spm doesn't allow dependency-file I/O for deformation utility,
            % so need to move and rename ourself
            [folder, ~, ~] = options.output;
            oldFile = fullfile(folder, 'wmask_ICV.nii');
            newFile = fullfile(options.output, strcat(options.prefix, '_mask_icv.nii'));
            movefile(oldFile, newFile);
        end
        
        function applyBrainMask(self, mask, img, options)
            % APPLYBRAINMASK Apply mask to ASL image
            %
            % Required arguments:
            %
            % mask = Mask to apply (Default = ICVMask)
            %        (char | str)
            %
            % img = Image to apply mask (Default = CoregFmap)
            %       (char | str)
            %
            % Optional arguments:
            %
            % 'expr' = Expression to apply (Default = 'i1.*i2')
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
            % 'output' = Save path (default = ASLProcessedDir)
            %            (char | str)
            
            arguments
                self                ArterialSpinLabellingPipeline;
                mask                {mustBeFile} = self.ICVMask;
                img                 {mustBeFile} = self.CoregFmap;
                options.expr        {mustBeTextScalar} = 'i1.*i2';
                options.interp      {mustBeInteger, mustBeInRange(options.interp, -7, -1)} = -7;
                % options.prefix      {mustBeTextScalar};
                options.output      {mustBeFolder} = self.ASLProcessedDir;
            end
            
            fprintf('--applying brainmask to ASL image...\n');
            fprintf('----brainmask image: %s\n', mask);
            fprintf('----image: %s\n', img);
           
            subjectID = self.getCondensedSubjectID();
            [~, timePoint, ~] = fileparts(self.ASLPath);
            outname = strcat('rasl_fmap_', subjectID, '_', timePoint, '_bmasked.nii');
            
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            matlabbatch{1}.spm.util.imcalc.input = {
                                                    char(strcat(mask, ',1'))
                                                    char(strcat(img, ',1'))
                                                    };
            matlabbatch{1}.spm.util.imcalc.output = char(outname);
            matlabbatch{1}.spm.util.imcalc.outdir = {char(options.output)};
            matlabbatch{1}.spm.util.imcalc.expression = char(options.expr);
            matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = options.interp;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

            spm_jobman('run', matlabbatch)
        end
        
        function calcAslGlobal(self, mask, options)
            % CALCASLGLOBAL Calculate global ASL value
            %
            % Required arguments:
            % mask = ASL mask (Default = ASLMask)
            %        (char | str)
            %
            % Optional arguments:
            %
            % 'output' = Save path (Default = ASLDataDir)
            %            (char | str)
            
            arguments
                self            ArterialSpinLabellingPipeline;
                mask            {mustBeFile} = self.ASLMask;
                options.output  {mustBeFolder} = self.ASLDataDir;
            end
            
            fprintf('--calculating global ASL value...\n');
            vol = spm_vol(char(mask));
            globalValue = spm_global(vol);
            subjectID = self.getCondensedSubjectID();
            [~, timePoint, ~] = fileparts(self.ASLPath);
            outname = strcat('global_', subjectID, '_', timePoint, '_bmasked.csv');
            writematrix(globalValue, fullfile(options.output, outname));
        end
        
        function invwarp(self, mask, deformField, fov, options)
            % INVWARP Apply inverse warp
            % 
            % Required arguments:
            %
            % mask = Mask to apply
            %        (char | str)
            %
            % Optional arguments:
            %
            % deformField = Deformation field (Default = T1DeformationField)
            %               (char | str)
            %
            % fov = Field of view (Default = SmoothedGMImage)
            %       (char | str)
            %
            % Name-Value arguments:
            %
            % 'prefix' = File prefix (Default = 'w')
            %            (char | str)
            %
            % 'output' = Save path (Default = AALInvwarpDir)
            %            (char | str)
            
            arguments
                self                ArterialSpinLabellingPipeline;
                mask                {mustBeFile};
                deformField         {mustBeFile} = self.T1DeformationField;
                fov                 {mustBeFile} = self.SmoothedGMImage;
                options.prefix      {mustBeTextScalar} = 'w';
                options.output      {mustBeFolder} = self.AALInvwarpDir;
            end

            [~, maskName, ~] = fileparts(mask);
            
            fprintf('--applying deformation field to %s...\n', maskName);
            fprintf('--deformation field: %s\n', deformField);
            fprintf('--fov: %s\n', fov);

            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;

            matlabbatch{1}.spm.util.defs.comp{1}.def = {char(deformField)};
            matlabbatch{1}.spm.util.defs.out{1}.push.fnames = {char(mask)};
            matlabbatch{1}.spm.util.defs.out{1}.push.weight = {''};
            matlabbatch{1}.spm.util.defs.out{1}.push.savedir.saveusr = {char(options.output)};
            matlabbatch{1}.spm.util.defs.out{1}.push.fov.file = {char(fov)};
            matlabbatch{1}.spm.util.defs.out{1}.push.preserve = 0;
            matlabbatch{1}.spm.util.defs.out{1}.push.fwhm = [0 0 0];
            matlabbatch{1}.spm.util.defs.out{1}.push.prefix = options.prefix;

            spm_jobman('run', matlabbatch)

            subjectID = self.getCondensedSubjectID();
            oldFile = fullfile(options.output, strcat(options.prefix, maskName, '.nii'));
            newFile = fullfile(options.output, strcat(options.prefix, subjectID, '_', maskName, '.nii'));
            movefile(oldFile, newFile);
        end
        
        function invwarpXgm(self, mask, img, options)
            % INVWARPXGM Restrict mask to gray matter image
            %
            % Required arguments:
            %
            % mask = Mask to apply
            %        (char | str)
            %
            % Optional arguments:
            %
            % img = Image to multiply (Default = GMImage)
            %       (char | str)
            %
            % Name-Value arguments:
            %
            % 'expr' = Expression to apply (Default = 'i2.*(i1>0/3)')
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
            % 'output' = Save path (default = AALInvwarpXgmDir)
            %            (char | str)
            
            arguments
                self            ArterialSpinLabellingPipeline;
                mask            {mustBeFile};
                img             {mustBeFile} = self.GMImage;
                options.expr    {mustBeTextScalar} = 'i2.*(i1>0.3)';
                options.interp  {mustBeInteger, mustBeInRange(options.interp, -7, -1)} = -7;
                options.prefix  {mustBeTextScalar} = 'w';
                options.output  {mustBeFolder} = self.AALInvwarpXgmDir;
            end

            [~, maskName, ~] = fileparts(mask);
            fprintf('--Restricting %s to gray matter...\n', maskName);

            maskName = extractAfter(maskName, '_');
            subjectID = self.getCondensedSubjectID;
            outname = strcat(options.prefix, subjectID, '_GM_', maskName, '.nii');

            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;

            matlabbatch{1}.spm.util.imcalc.input = {
                                                    char(strcat(img,',1'))
                                                    char(strcat(mask,',1'))
                                                    };
            matlabbatch{1}.spm.util.imcalc.output = char(outname);
            matlabbatch{1}.spm.util.imcalc.outdir = {char(options.output)};
            matlabbatch{1}.spm.util.imcalc.expression = options.expr;
            matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
            matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
            matlabbatch{1}.spm.util.imcalc.options.mask = 0;
            matlabbatch{1}.spm.util.imcalc.options.interp = options.interp;
            matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

            spm_jobman('run', matlabbatch)
        end
        
        function calcBrainVols(self, mask, seg8Mat, options)
            % "mask" is typically the icv mask template
            
            arguments
                self            ArterialSpinLabellingPipeline;
                mask            {mustBeFile} = self.ICVMaskTemplate;
                seg8Mat         {mustBeFile} = self.T1Seg8Mat;
                options.prefix  {mustBeTextScalar} = 'segvolumes_t1';
                options.output  {mustBeFolder} = self.T1DataDir;
            end
            
            fprintf('--Calculating segmented brain volumes for %s...\n', seg8Mat);
            spm('defaults', 'FMRI');
            spm_jobman('initcfg');
            clear matlabbatch;
            
            matlabbatch{1}.spm.util.tvol.matfiles = {char(seg8Mat)};
            matlabbatch{1}.spm.util.tvol.tmax = 3;
            matlabbatch{1}.spm.util.tvol.mask = {char(strcat(mask, ',1'))};
            matlabbatch{1}.spm.util.tvol.outf = 'vol';
            
            spm_jobman('run', matlabbatch)
            
            % change variable names
            data = readtable('vol.csv');
            data.Properties.VariableNames{'Volume1'} = 'gm_(L)';
            data.Properties.VariableNames{'Volume2'} = 'wm_(L)';
            data.Properties.VariableNames{'Volume3'} = 'csf_(L)';
            writetable(data, 'vol.csv');

            subjectID = self.getCondensedSubjectID();
            newFile = fullfile(options.output, strcat(options.prefix, '_', subjectID, '.csv'));
            movefile('vol.csv', newFile);
        end
        
    end
    
    methods(Access = private)
        
        function value = getCondensedSubjectID(self)
            value = erase(self.SubjectID, '_');
        end
        
    end
    
    % getters
    methods
        
        function value = get.AALInvwarpDir(self)
            value = fullfile(self.SubjectDir, 'masks', 'aal', 'invwarp');
        end
        
        function value = get.AALInvwarpXgmDir(self)
            value = fullfile(self.SubjectDir, 'masks', 'aal', 'invwarpXgm');
        end
        
        function value = get.AALMasks(self)
            if ispc()
                % TODO: move the masks into the shared server
                % temporary!!!
                files = dir(fullfile("C:/Users/atward/Desktop/aal_stuff/ROI_MNI_V4.nii"));
                files = vertcat(files, dir(fullfile("C:/Users/atward/Desktop/aal_stuff/aal", "*.nii")));
            else
                % TODO: build path for MacOS, Linux, Docker, etc...
            end
            
            value = strings(size(files, 1), 1);
            for k = 1:size(files, 1)
                value(k) = fullfile(files(k).folder, files(k).name);
            end
        end
        
        function value = get.ASLDataDir(self)
            value = fullfile(self.ASLPath, 'data');
        end
        
        function value = get.ASLMask(self)
            files = dir(fullfile(self.ASLProcessedDir, 'rasl*bmasked.nii'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.ASLProcessedDir(self)
            value = fullfile(self.ASLPath, 'proc');
        end
          
        function value = get.CoregFmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'rasl*'));
            files = files(~contains({files.name}, '_bmasked'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.CoregPDmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'rpdmap*'));
            value = fullfile(files.folder, files.name);
        end

        function value = get.Fmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'asl*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.GMImage(self)
            files = dir(fullfile(self.T1ProcessedDir, 'c1t1*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.GlobalASL(self)
            value = self.GlobalASL;
        end
        
        function value = get.ICVMask(self)
            files = dir(fullfile(self.T1ProcessedDir, 'wt1*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.ICVMaskTemplate(self)
            % TODO: set paths
            if ispc()
                files = dir("C:/Program Files/MATLAB/spm12/tpm/mask_ICV.nii");
            else
                % TODO: build path for MacOS, Linux, Docker, etc...
            end
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.LobeInvwarpDir(self)
            value = fullfile(self.SubjectDir, 'masks', 'lobes', 'invwarp');
        end
        
        function value = get.LobeInvwarpXgmDir(self)
            value = fullfile(self.SubjectDir, 'masks', 'lobes', 'invwarpXgm');
        end
        
        function value = get.LobeMasks(self)
            % Temporary!!!
            if ispc()
                files = dir(fullfile("C:/Users/atward/Desktop/aal_stuff/lobes", "*.nii"));
            else
                % TODO: build path for MacOS, Linux, Docker, etc...
            end
            
            value = strings(size(files, 1), 1);
            for k = 1:size(files, 1)
                value(k) = fullfile(files(k).folder, files(k).name);
            end
        end
        
        function value = get.NormalizedCoregFmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'wrasl*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.NormalizedCoregPDmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'wrpdmap*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.NormalizedGMImage(self)
            files = dir(fullfile(self.T1ProcessedDir, 'wmt1*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.PDmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'pdmap*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.SmoothedGMImage(self)
            files = dir(fullfile(self.T1ProcessedDir, 'sc1t1*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.SmoothedNormalizedCoregFmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'swrasl*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.SmoothedNormalizedCoregPDmap(self)
            files = dir(fullfile(self.ASLProcessedDir, 'swrpdmap*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.SmoothedNormalizedGMImage(self)
            files = dir(fullfile(self.T1ProcessedDir, 'swmt1*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.T1BiasCorrected(self)
            files = dir(fullfile(self.T1ProcessedDir, 'mt1*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.T1DataDir(self)
            value = fullfile(self.T1Path, 'data');
        end
        
        function value = get.T1DeformationField(self)
            files = dir(fullfile(self.T1ProcessedDir, 'y*'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.T1Image(self)
            files = dir(fullfile(self.T1ProcessedDir, 't1*.nii'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.T1ProcessedDir(self)
            value = fullfile(self.T1Path, 'proc');
        end
        
        function value = get.T1Seg8Mat(self)
            files = dir(fullfile(self.T1ProcessedDir, 't1*.mat'));
            value = fullfile(files.folder, files.name);
        end
        
        function value = get.TPMMaskTemplate(self)
            % TODO: change path
            if ispc()
                files = dir("C:/Program Files/MATLAB/spm12/tpm/TPM.nii");
            else
                % TODO: build path for MacOS, Linux, Docker, etc...
            end
            value = fullfile(files.folder, files.name);
        end
        
    end

end