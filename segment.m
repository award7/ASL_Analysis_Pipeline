function segment(passed_arr_subject)

	[arr_subject] = split(string(passed_arr_subject));

	ANALYSIS = 'Segmentation';
	subfolder = "t1/proc";
	fname = "raw_t1.nii";
	for i = 1:length(arr_subject)
		src_dir = fullfile(pwd, arr_subject(i), subfolder, fname);
		if isfile(fullfile(src_dir, fname))
			spm_segment(src_dir, fname);
		end
		completed = (i/length(arr_subject))*100;
		fprintf('%s: Completed %.0f%%\n', ANALYSIS, completed);
	end
end

function spm_segment(src_dir, fname)
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    clear matlabbatch;
    tpm_img = '/usr/local/MATLAB/spm12/tpm/TPM.nii';
	matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_cd.dir = {[src_dir]};
	
    matlabbatch{2}.spm.spatial.preproc.channel.vols = {[fname,',1']}; % analyze raw t1 img
    matlabbatch{2}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{2}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{2}.spm.spatial.preproc.channel.write = [0 1]; % save bias corrected
    matlabbatch{2}.spm.spatial.preproc.tissue(1).tpm = {[tpm_img, ',1']}; %
    matlabbatch{2}.spm.spatial.preproc.tissue(1).ngaus = 1;
    matlabbatch{2}.spm.spatial.preproc.tissue(1).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(1).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(2).tpm = {[tpm_img, ',2']};
    matlabbatch{2}.spm.spatial.preproc.tissue(2).ngaus = 1;
    matlabbatch{2}.spm.spatial.preproc.tissue(2).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(2).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(3).tpm = {[tpm_img, ',3']};
    matlabbatch{2}.spm.spatial.preproc.tissue(3).ngaus = 2;
    matlabbatch{2}.spm.spatial.preproc.tissue(3).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(3).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(4).tpm = {[tpm_img, ',4']};
    matlabbatch{2}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{2}.spm.spatial.preproc.tissue(4).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(4).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(5).tpm = {[tpm_img, ',5']};
    matlabbatch{2}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{2}.spm.spatial.preproc.tissue(5).native = [1 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(5).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(6).tpm = {[tpm_img, ',6']};
    matlabbatch{2}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{2}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{2}.spm.spatial.preproc.tissue(6).warped = [0 0];
    matlabbatch{2}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{2}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{2}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{2}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{2}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{2}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{2}.spm.spatial.preproc.warp.write = [0 1]; % save forward deformation
	
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(1) = cfg_dep('Segment: Seg Params', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','param', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(2) = cfg_dep('Segment: Bias Corrected (1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','channel', '()',{1}, '.','biascorr', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(3) = cfg_dep('Segment: c1 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{1}, '.','c', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(4) = cfg_dep('Segment: c2 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','c', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(5) = cfg_dep('Segment: c3 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{3}, '.','c', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(6) = cfg_dep('Segment: c4 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{4}, '.','c', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(7) = cfg_dep('Segment: c5 Images', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{5}, '.','c', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.files(8) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
	matlabbatch{3}.cfg_basicio.file_dir.file_ops.file_move.action.moveto = {'/home/atward/Desktop'}; %%%TODO: change
    
	spm_jobman('run', matlabbatch);
end
