function [s] = file_array_builder(passed_subject_array)
    subjects_array = split(passed_subject_array, ",");
    s.subjects_array = string(subjects_array(:,1));
    
    s.aal_masks = vertcat("/usr/local/MATLAB/spm12/aal_for_SPM12/aal_for_SPM12/ROI_MNI_V4.nii", string(append("/usr/local/bin/masks/aal/", {dir('/usr/local/bin/masks/aal/*.nii').name}))');
    s.lobe_masks = string(append("/usr/local/bin/masks/lobes/", {dir('/usr/local/bin/masks/lobes/*.nii').name}))';
    
    asl_folder_array = cell(1,100); % initialize array; 100 is arbitrary for preallocation of memory
    asl_proc_dir_path = cell(1,100);
    asl_data_dir_path = cell(1,100);
    asl_fmap_filename = cell(1,100);
    pdmap_filename = cell(1,100);
    coreg_fmap_filename = cell(1,100);
    coreg_pdmap_filename = cell(1,100);
    normalized_coreg_fmap_filename = cell(1,100);
    normalized_coreg_pdmap_filename = cell(1,100);
    smooth_normalized_coreg_fmap_filename = cell(1,100);
    smooth_normalized_coreg_pdmap_filename = cell(1,100);
    brainmask_asl_filename = cell(1,100);
    
    aggregated_asl_folder_array = {};
    aggregated_asl_proc_dir_path = {};
    aggregated_asl_data_dir_path = {};
    aggregated_asl_fmap_filename = {};
    aggregated_pdmap_filename = {};
    aggregated_coreg_fmap_filename = {};
    aggregated_coreg_pdmap_filename = {};
    aggregated_normalized_coreg_fmap_filename = {};
    aggregated_normalized_coreg_pdmap_filename = {};
    aggregated_smooth_normalized_coreg_fmap_filename = {};
    aggregated_smooth_normalized_coreg_pdmap_filename = {};
    aggregated_brainmask_asl_filename = {};
    
    s.subject_directory = append(pwd, '/', s.subjects_array); % array of subject directory paths
    s.t1_proc_dir_path = strcat(s.subject_directory, '/t1/proc'); % array of t1/proc paths
    s.t1_data_dir_path = strcat(s.subject_directory, '/t1/data'); % array of t1/data paths
    s.aal_invwarp_path = strcat(s.subject_directory, '/t1/masks/aal/invwarp'); % array of masks/aal/invwarp paths
    s.aal_invwarpXgm_path = strcat(s.subject_directory, '/t1/masks/aal/invwarpXgm'); % array of masks/aal/invwarpXgm paths
    s.lobes_invwarp_path = strcat(s.subject_directory, '/t1/masks/lobes/invwarp'); % array of masks/lobes/invwarp paths
    s.lobes_invwarp_path = strcat(s.subject_directory, '/t1/masks/lobes/invwarpXgm'); % array of masks/lobes/invwarpXgm paths
    s.t1_filename = strcat(s.t1_proc_dir_path, '/t1_', erase(s.subjects_array, '_'), '.nii'); % array of t1.nii paths
    s.gm_filename = strcat(s.t1_proc_dir_path, '/c1t1_', erase(s.subjects_array, '_'), '.nii'); % array of segmented gm.nii paths
    s.wm_filename = strcat(s.t1_proc_dir_path, '/c2t1_', erase(s.subjects_array, '_'), '.nii'); % array of segmented wm.nii paths
    s.t1_bias_corrected_filename = strcat(s.t1_proc_dir_path, '/mt1_', erase(s.subjects_array, '_'), '.nii'); % array of bias corrected .nii paths
    s.t1_deformation_field_filename = strcat(s.t1_proc_dir_path, '/y_t1_', erase(s.subjects_array, '_'), '.nii'); % array of t1 deformation field .nii paths
    s.t1_seg8mat_filename = strcat(s.t1_proc_dir_path, '/t1_', erase(s.subjects_array, '_'), '_seg8.mat'); % array of t1 segmentation matrices paths
    s.smoothed_gm_filename = strcat(s.t1_proc_dir_path, '/sc1t1_', erase(s.subjects_array, '_'), '.nii'); % array of smoothed gm.nii paths
    s.normalized_gm_filename = strcat(s.t1_proc_dir_path, '/wmt1_', erase(s.subjects_array, '_'), '.nii'); % array of normalized .nii paths
    s.smooth_normalized_gm_filename = strcat(s.t1_proc_dir_path, '/swmt1_', erase(s.subjects_array, '_'), '.nii'); % array of smooth normalized .nii paths
    s.brainmask_icv = strcat(s.t1_proc_dir_path, '/wt1_', erase(s.subjects_array, '_'), '_mask_icv.nii'); % array of "brainmask" .nii paths

    for subject = s.subjects_array'
        asl_folders = {dir(fullfile(subject, "asl*")).name};
        
        for i = 1:length(asl_folders)
            asl_folder_array{1,i} = asl_folders{1,i}; % tmp array
            asl_proc_dir_path{1,i} = strcat(pwd, '/', subject, '/', string(asl_folder_array{1,i}), '/proc'); % tmp array
            asl_data_dir_path{1,i} = strcat(subject, '/', string(asl_folder_array{1,i}), '/data'); % tmp array
            asl_fmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/asl_fmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            pdmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/pdmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            coreg_fmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/rasl_fmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            coreg_pdmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/rpdmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            normalized_coreg_fmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/wrasl_fmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            normalized_coreg_pdmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/wrpdmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            smooth_normalized_coreg_fmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/swrasl_fmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array
            smooth_normalized_coreg_pdmap_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/swrpdmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'.nii'); % tmp array           
            brainmask_asl_filename{1,i} = strcat(asl_proc_dir_path{1,i}, '/rasl_fmap_', erase(subject, '_'), '_', asl_folder_array{1,i},'_bmasked.nii'); % tmp array
            
       end
        
        aggregated_asl_folder_array = vertcat(aggregated_asl_folder_array, asl_folder_array); % array of subject asl folder names
        aggregated_asl_proc_dir_path = vertcat(aggregated_asl_proc_dir_path, asl_proc_dir_path); % array of subject asl folder paths
        aggregated_asl_data_dir_path = vertcat(aggregated_asl_data_dir_path, asl_data_dir_path); % array of subject asl data folder paths
        aggregated_asl_fmap_filename = vertcat(aggregated_asl_fmap_filename, asl_fmap_filename); % array of subject asl_fmap file paths
        aggregated_pdmap_filename = vertcat(aggregated_pdmap_filename, pdmap_filename); % array of subject pdmap file paths
        aggregated_coreg_fmap_filename = vertcat(aggregated_coreg_fmap_filename, coreg_fmap_filename); % array of subject coreg fmaps file paths
        aggregated_coreg_pdmap_filename = vertcat(aggregated_coreg_pdmap_filename, coreg_pdmap_filename); % array of subject coreg pdmaps file paths
        aggregated_normalized_coreg_fmap_filename = vertcat(aggregated_normalized_coreg_fmap_filename, normalized_coreg_fmap_filename); % array of subject normalized coreg fmaps file paths
        aggregated_normalized_coreg_pdmap_filename = vertcat(aggregated_normalized_coreg_pdmap_filename, normalized_coreg_pdmap_filename); % array of subject normalized coreg pdmaps file paths
        aggregated_smooth_normalized_coreg_fmap_filename = vertcat(aggregated_smooth_normalized_coreg_fmap_filename, smooth_normalized_coreg_fmap_filename); % array of subject smoothed normalized coreg fmap file paths
        aggregated_smooth_normalized_coreg_pdmap_filename = vertcat(aggregated_smooth_normalized_coreg_pdmap_filename, smooth_normalized_coreg_pdmap_filename); % array of subject smoothed normalized coreg pdmaps file paths
        aggregated_brainmask_asl_filename = vertcat(aggregated_brainmask_asl_filename, brainmask_asl_filename); % array of subject asl brainmask file paths
    
    end
    
    % delete empty columns
    keep_non_empty = any(~cellfun('isempty',aggregated_asl_folder_array), 1);
    s.aggregated_asl_folder_array = string(aggregated_asl_folder_array(:,keep_non_empty));
    s.aggregated_asl_proc_dir_path = string(aggregated_asl_proc_dir_path(:,keep_non_empty));
    s.aggregated_asl_data_dir_path = string(aggregated_asl_data_dir_path(:,keep_non_empty));
    s.aggregated_asl_fmap_filename = string(aggregated_asl_fmap_filename(:,keep_non_empty));
    s.aggregated_pdmap_filename = string(aggregated_pdmap_filename(:,keep_non_empty));
    s.aggregated_coreg_fmap_filename = string(aggregated_coreg_fmap_filename(:,keep_non_empty));
    s.aggregated_coreg_pdmap_filename = string(aggregated_coreg_pdmap_filename(:,keep_non_empty));
    s.aggregated_normalized_coreg_fmap_filename = string(aggregated_normalized_coreg_fmap_filename(:,keep_non_empty));
    s.aggregated_normalized_coreg_pdmap_filename = string(aggregated_normalized_coreg_pdmap_filename(:,keep_non_empty));
    s.aggregated_smooth_normalized_coreg_fmap_filename = string(aggregated_smooth_normalized_coreg_fmap_filename(:,keep_non_empty));
    s.aggregated_smooth_normalized_coreg_pdmap_filename = string(aggregated_smooth_normalized_coreg_pdmap_filename(:,keep_non_empty));
    s.aggregated_brainmask_asl_filename = string(aggregated_brainmask_asl_filename(:,keep_non_empty));
    
end


