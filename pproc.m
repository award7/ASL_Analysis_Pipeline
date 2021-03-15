function pproc(passed_subject_array, passed_analysis_array, coreg_method)
    tic();
    fprintf('\n#### SPM ASL Preprocessing ####\n');

    s = file_array_builder(passed_subject_array);
    analysis_array = string(split(passed_analysis_array, ","))';
    % analysis_array = string(analysis_array(:,1));
    
    
    for subject = 1:length(s.subjects_array)
        if isempty(s.subjects_array(subject))
            break;
        end
		fprintf('Analyzing subject: %s...\n', s.subjects_array(subject));
        
        for analysis = 1:length(analysis_array(:,1))
            return_code = 0;
            switch analysis_array(analysis)
                case 'segment'
                    return_code = segment_local(subject, s);
                case 'smooth'
                    return_code = smooth_local(subject, s);
                case 'coreg'
                    return_code = coreg_local(subject, s, coreg_method);
                case 'normalize'
                    return_code = normalize_local(subject, s);
                case 'mask_icv'
                    return_code = brainmask_icv_local(subject, s);
                case 'mask_asl'
                    return_code = brainmask_asl(subject, s);
                case 'get_global'
                    return_code = get_global_local(subject, s);
                case 'invwarp'
                    return_code = invwarp_local(subject, s);
                case 'invwarpXgm'
                    return_code = invwarpXgm_local(subject, s);
                case 'brain_volumes'
                    return_code = brain_volumes_local(subject, s);
            end
            if return_code ~= 0
                break;
            end
        end
    end
    toc();
end

function completion_message(count, total_count)
    completed = (count/total_count)*100;
    fprintf('Completed %.0f%%\n\n', completed);
end

function err(code, msg)
    switch code
        case 2
            fprintf('ERROR %s: file not found-- %s\n', num2str(code), msg);
    end
end

function return_code = segment_local(subject, s)
    if ~isfile(s.t1_filename(subject)) % check for t1 file
        err(2, s.t1_filename(subject));
        return_code = 2;
        return;
    end

    fprintf('--segmenting T1 image...\n');
    t1_file = s.t1_filename(subject);
    t1_proc_directory = s.t1_proc_dir_path(subject);
    sl_segment(t1_file, t1_proc_directory);
    completion_message(subject, length(s.t1_filename));
    return_code = 0;
end

function return_code = smooth_local(subject, s)
    if ~isfile(s.gm_filename(subject)) % check for gm file
        err(2, s.gm_filename(subject));
        return_code = 2;
        return;
    end

    fprintf('--smoothing GM image...\n');
    gm_file = s.gm_filename(subject);
    t1_proc_directory = s.t1_proc_dir_path(subject);
    sl_smooth(gm_file, t1_proc_directory);
    completion_message(subject, length(s.gm_filename));
    return_code = 0;
end

function return_code = coreg_local(subject, s, coreg_method)
    if ~isfile(s.smoothed_gm_filename(subject)) % check for smooth gm file
        err(2, s.smoothed_gm_filename(subject));
        return_code = 2;
        return;
    end
    
    fprintf('--coregistering images...\n');
    smooth_gm_file = s.smoothed_gm_filename(subject);

    for asl_folder = 1:length(s.aggregated_asl_folder_array(1,:))

        if ~cellfun('isempty', s.aggregated_asl_folder_array(1, asl_folder)) == 0 % check for asl folder
            continue;
        end

        if ~isfile(s.aggregated_asl_fmap_filename(subject, asl_folder)) % check for asl_fmap file
            err(2, s.aggregated_asl_fmap_filename(subject, asl_folder));
            continue;
        end

        if ~isfile(s.aggregated_pdmap_filename(subject, asl_folder)) % check for pdmap file
            err(2, s.aggregated_pdmap_filename(subject, asl_folder));
            continue;
        end
        
        if coreg_method == 'A'
            source_img = s.aggregated_pdmap_filename(subject, asl_folder);
            other_img = s.aggregated_asl_fmap_filename(subject, asl_folder);
        else % defaults to this is no option provided
            source_img = s.aggregated_asl_fmap_filename(subject, asl_folder);
            other_img = s.aggregated_pdmap_filename(subject, asl_folder);
        end
        
        asl_proc_dir_path = s.aggregated_asl_proc_dir_path(subject, asl_folder);
        sl_coreg(smooth_gm_file, source_img, other_img, asl_proc_dir_path);
        completion_message(asl_folder, length(s.aggregated_asl_folder_array(1,:)));
    end
    return_code = 0;
end

function return_code = normalize_local(subject, s)
    if ~isfile(s.t1_deformation_field_filename(subject)) % check for pdmap file
        err(2, s.t1_deformation_field_filename(subject));
        return_code = 2;
        return;
    end
    
    if ~isfile(s.t1_bias_corrected_filename(subject)) % check for t1 bias corrected image file
        err(2, s.t1_bias_corrected_filename(subject));
        return_code = 2;
        return;
    end

    fprintf('--normalizing and smoothing coregistered images...\n');
    deformation_field = s.t1_deformation_field_filename(subject);
    bias_corrected = s.t1_bias_corrected_filename(subject);

    for asl_folder = 1:length(s.aggregated_asl_folder_array(1,:))

        if ~cellfun('isempty', s.aggregated_asl_folder_array(1, asl_folder)) == 0 % check for asl folder
            continue;
        end

        if ~isfile(s.aggregated_coreg_fmap_filename(subject, asl_folder)) % check for coreg asl_fmap file
            err(2, s.aggregated_coreg_fmap_filename(subject, asl_folder));
            continue;
        end

        if ~isfile(s.aggregated_coreg_pdmap_filename(subject, asl_folder)) % check for coreg pdmap file
            err(2, s.aggregated_coreg_pdmap_filename(subject, asl_folder));
            continue;
        end
        
        coreg_asl_fmap = s.aggregated_coreg_fmap_filename(subject, asl_folder);
        coreg_pdmap = s.aggregated_coreg_pdmap_filename(subject, asl_folder);
        asl_proc_dir_path = s.aggregated_asl_proc_dir_path(subject, asl_folder);
        sl_normalize(deformation_field, bias_corrected, coreg_asl_fmap, coreg_pdmap, asl_proc_dir_path);
        completion_message(asl_folder, length(s.aggregated_asl_folder_array(1,:)));
    end
    return_code = 0;
end

function return_code = brainmask_icv_local(subject, s)
    if ~isfile(s.t1_deformation_field_filename(subject)) % check for t1 deformation field file
        err(2, s.t1_deformation_field_filename(subject));
        return_code = 2;
        return;
    end
    
    if ~isfile(s.smoothed_gm_filename(subject)) % check for smooth gm file
        err(2, s.smoothed_gm_filename(subject));
        return_code = 2;
        return;
    end

    fprintf('--brain masking ICV...\n');
    deformation_field = s.t1_deformation_field_filename(subject);
    smooth_gm_file = s.smoothed_gm_filename(subject);
    sl_brainmask_icv(deformation_field, smooth_gm_file);
    t1_proc_directory = s.t1_proc_dir_path(subject);
    subjectID = erase(s.subjects_array(subject), '_');
    movefile('wmask_ICV.nii', strcat(t1_proc_directory, '/wt1_', subjectID, '_mask_icv.nii'))
    completion_message(subject, length(s.t1_deformation_field_filename));
    return_code = 0;
end

function return_code = brainmask_asl(subject, s)
    if ~isfile(s.brainmask_icv(subject)) % check for brainmask file
        err(2, s.brainmask_icv(subject));
        return_code = 2;
        return;
    end

    fprintf('--applying brainmask to ASL image...\n');
    brainmask_file = s.brainmask_icv(subject);

    for asl_folder = 1:length(s.aggregated_asl_folder_array(1,:))

        if ~cellfun('isempty', s.aggregated_asl_folder_array(1, asl_folder)) == 0 % check for asl folder
            continue;
        end

        if ~isfile(s.aggregated_coreg_fmap_filename(subject, asl_folder)) % check for coreg asl_fmap file
            err(2, s.aggregated_coreg_fmap_filename(subject, asl_folder));
            continue;
        end
        
        coreg_asl_fmap = s.aggregated_coreg_fmap_filename(subject, asl_folder);
        asl_proc_dir_path = s.aggregated_asl_proc_dir_path(subject, asl_folder);
        sl_brainmask_asl(brainmask_file, coreg_asl_fmap, asl_proc_dir_path);
        subjectID = erase(s.subjects_array(subject), '_');
        asl_timepoint = s.aggregated_asl_folder_array(subject, asl_folder);
        movefile(strcat(asl_proc_dir_path, '/output.nii') , strcat(asl_proc_dir_path, '/rasl_fmap_', subjectID, '_', asl_timepoint, '_bmasked.nii'));
        completion_message(asl_folder, length(s.aggregated_asl_folder_array(1,:)));
    end
    return_code = 0;
end

function return_code = get_global_local(subject, s)
    
    for asl_folder = 1:length(s.aggregated_asl_folder_array(1,:))

        if ~cellfun('isempty', s.aggregated_asl_folder_array(1, asl_folder)) == 0 % check for asl folder
            continue;
        end

        if ~isfile(s.aggregated_brainmask_asl_filename(subject, asl_folder)) % check for coreg asl_fmap file
            err(2, s.aggregated_brainmask_asl_filename(subject, asl_folder));
            continue;
        end
        
        fprintf('--calculating global ASL value...\n');
        vol = spm_vol(char(s.aggregated_brainmask_asl_filename(subject, asl_folder)));
        global_val = spm_global(vol);
        subjectID = erase(s.subjects_array(subject), '_');
        asl_timepoint = s.aggregated_asl_folder_array(subject, asl_folder);
        writematrix(global_val, strcat(s.aggregated_asl_data_dir_path(subject, asl_folder), '/global_', subjectID, '_', asl_timepoint, '_bmasked.csv'));
        completion_message(asl_folder, length(s.aggregated_asl_folder_array(1,:)));
    end
    return_code = 0;
end

function return_code = invwarp_local(subject, s)
    if ~isfile(s.t1_deformation_field_filename(subject)) % check for t1 deformation field file
        err(2, s.t1_deformation_field_filename(subject));
        return_code = 2;
        return;
    end
    
    if ~isfile(s.smoothed_gm_filename(subject)) % check for smooth gm file
        err(2, s.smoothed_gm_filename(subject));
        return_code = 2;
        return;
    end

    deformation_field = s.t1_deformation_field_filename(subject);
    smooth_gm_file = s.smoothed_gm_filename(subject);
    
    aal_invwarp_masks_directory = s.aggregated_asl_aal_invwarp_path(subject);
    lobes_invwarp_masks_directory = s.aggregated_asl_lobes_invwarp_path(subject);
    subjectID = erase(s.subjects_array(subject), '_');
        
    % loop through masks
    for mask = 1:length(s.aal_masks)
        [~, mask_name, ~] = fileparts(s.aal_masks(mask));
        fprintf('--Applying deformation field to %s...\n', mask_name);
        sl_invwarp(deformation_field, smooth_gm_file, s.aal_masks(mask));
        movefile(strcat('w', mask_name, '.nii'), strcat(aal_invwarp_masks_directory, '/w', subjectID, '_', mask_name, '.nii'));       
    end

    for mask = 1:length(s.lobe_masks)
        [~, mask_name, ~] = fileparts(s.lobe_masks(mask));
        fprintf('--Applying deformation field to %s...\n', mask_name);
        sl_invwarp(deformation_field, smooth_gm_file, s.lobe_masks(mask));
        movefile(strcat('w', mask_name, '.nii'), strcat(lobes_invwarp_masks_directory, '/w', subjectID, '_', mask_name, '.nii'));
    end

    completion_message(subject, length(s.t1_deformation_field_filename));
    return_code = 0;
end

function return_code = invwarpXgm_local(subject, s)
    if ~isfile(s.gm_filename(subject)) % check for gm file
        err(2, s.gm_filename(subject));
        return_code = 2;
        return;
    end    

    gm_file = s.gm_filename(subject);
    aal_invwarpXgm_directory = s.aggregated_asl_aal_invwarpXgm_path(subject);
    lobes_invwarpXgm_directory = s.aggregated_asl_lobes_invwarpXgm_path(subject);
    subjectID = erase(s.subjects_array(subject), '_');
    
    % aal masks
    s.roi_masks = fullfile(s.aggregated_asl_aal_invwarp_path(subject), {dir(fullfile(s.aggregated_asl_aal_invwarp_path(subject), "*.nii")).name});
    for roi_mask = 1:length(s.roi_masks)
        [~, mask_name, ~] = fileparts(s.roi_masks(roi_mask));
        fprintf('--Restricting %s to gray matter...\n', mask_name);
        mask_name = erase(mask_name, strcat('w', subjectID, '_'));
        outname = strcat('w', subjectID, '_GM_', mask_name, '.nii');
        sl_invwarpXgm(gm_file, s.roi_masks(roi_mask), aal_invwarpXgm_directory, outname);
        % movefile(strcat(t1_proc_directory, '/output.nii'), strcat(t1_proc_directory, '/wt1_', subjectID, '_gm_aal_roi.nii'))
    end
    
    % lobe masks
    s.roi_masks = fullfile(s.aggregated_asl_lobes_invwarp_path(subject), {dir(fullfile(s.aggregated_asl_lobes_invwarp_path(subject), "*.nii")).name});
    for roi_mask = 1:length(s.roi_masks)
        [~, mask_name, ~] = fileparts(s.roi_masks(roi_mask));
        fprintf('--Restricting %s to gray matter...\n', mask_name);
        mask_name = erase(mask_name, strcat('w', subjectID, '_'));
        outname = strcat('w', subjectID, '_GM_', mask_name, '.nii');
        sl_invwarpXgm(gm_file, s.roi_masks(roi_mask), lobes_invwarpXgm_directory, outname);
        % movefile(strcat(t1_proc_directory, '/output.nii'), strcat(t1_proc_directory, '/wt1_', subjectID, '_gm_aal_roi.nii'))
    end

    completion_message(subject, length(s.gm_filename));
    return_code = 0;
end

function return_code = brain_volumes_local(subject,s )
    if ~isfile(s.t1_seg8mat_filename(subject)) % check for seg8.mat file
        err(2, s.t1_seg8mat_filename(subject));
        return_code = 2;
        return;
    end 
    
    fprintf('--calculating segmented brain volumes...\n');
    seg8_file = s.t1_seg8mat_filename(subject);
    sl_brain_volumes(seg8_file);
    
    opts = detectImportOptions('vol.csv');
    opts.SelectedVariableNames = {'Volume1', 'Volume2', 'Volume3'};
    brain_volumes_data = readtable('vol.csv', opts);
    brain_volumes_data.Properties.VariableNames{'Volume1'} = 'gm';
    brain_volumes_data.Properties.VariableNames{'Volume2'} = 'wm';
    brain_volumes_data.Properties.VariableNames{'Volume3'} = 'csf';
    
    t1_data_directory = s.t1_data_dir_path(subject);
    subjectID = erase(s.subjects_array(subject), '_');
    movefile('vol.csv', strcat(t1_data_directory, '/segvolumes_t1_', subjectID, '.csv'));
    completion_message(subject, length(s.t1_seg8mat_filename));
    return_code = 0;
end