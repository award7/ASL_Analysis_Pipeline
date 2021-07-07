#!/usr/bin/env bash

### run FSLstats and FSLeyes
function runFSL() {
    # opening message and setup table
    echo; echo "Running FSL for ASL perfusion of ROIs..."
    divider="======================================="
    divider="${divider}${divider}"
    header="\n %-15s %-15s %-30s %-10s\n"
    format=" %-15s %-15s %-30s %-10s\n"
    width=75
    printf "$header" "SUBJECT ID" "TIME POINT" "ROI" "PERFUSION"
    printf "%$width.${width}s\n" "$divider"

    # main function
    success_message_array=()
    for subject in "${subject_array[@]}"; do
        get_subfolders "$subject"
        subject_condensed="$(rm_underscores $subject)"
        masks_array=("${subject}/masks/aal/invwarpXgm"/*)
        masks_array+=("${subject}/masks/lobes/invwarpXgm"/*)
        masks_array+=("${subject}/masks/vascular_territories/invwarpXgm"/*)
        for folder in "${subfolders_array[@]}"; do
            if [[ "$folder" == [Aa]sl* ]]; then
                (
                    data_dir="${subject}/${folder}/data"
                    global_csv_file="${data_dir}/global_${subject_condensed}_${folder}_bmasked.csv"
                    roi_csv_file="${data_dir}/ASL_ROIs_${subject_condensed}_${folder}_invwarpXgm.csv"
                    
                    # insert global value
                    printf "%s\n" "Global_ASL" | tr "\n" "," >> "${subject_condensed}_${folder}_header.csv"

                    while IFS=, read -r col1; do
                        global_value="$col1"
                        printf "%s\n" "$global_value" | tr "\n" "," >> "${subject_condensed}_${folder}_values.csv"
                    done < "$global_csv_file"
                    
                    # Calculate mean ROI values and add to csv
                    rasl_fmap="${subject}/${folder}/proc/rasl_fmap_${subject_condensed}_${folder}_bmasked.nii"

                    for mask in "${masks_array[@]}"; do
                        GM_mask_name="$(basename ${mask//.nii/})" # remove file extension
                        GM_mask_name="${GM_mask_name//w${subject_condensed}_/}" # remove subject ID
                        printf "%s\n" "$GM_mask_name" | tr "\n" "," >> "${subject_condensed}_${folder}_header.csv"
                        GM_mask_name_value="$(fslstats """$rasl_fmap""" -n -k $mask -M)"
                        printf "%s\n" "$GM_mask_name_value" | tr "\n" "," >> "${subject_condensed}_${folder}_values.csv"
                        printf "$format" "$subject" "$folder" "$GM_mask_name" "$GM_mask_name_value"
                    done
                    
                    cat "${subject_condensed}_${folder}_header.csv" <(echo) "${subject_condensed}_${folder}_values.csv" > "$roi_csv_file"
                    rm "${subject_condensed}_${folder}_header.csv" "${subject_condensed}_${folder}_values.csv"
                ) &
            
                if [[ $(jobs -r -p | wc -l) -gt $cores ]]; then 
                    wait -n
                fi
            fi
        done
        wait
        unset 'subfolders_array[@]'
    done
    
    
    # for subject in "${subject_array[@]}"; do
        # for FOLDER in "${arr_folders[@]}"; do
            # # TODO: get mri img files as inputs
                # # do for all mri imgs for QC purposes
                # # raw t1, segmented t1 imgs, smoothed gm, normalized, etc.
            # # TODO: replace "file [display0pts]" with img file name and display options
        
            # name_outfile_ortho="${subject}_${FOLDER}_ortho"
            # fsleyes render -sortho -of "$name_outfile_ortho" file [display0pts]
            
            # name_outfile_lb="${subject}_${FOLDER}_lightbox"
            # fsleyes render -slightbox -of "$name_outfile_lb" file [display0pts]
            
            # name_outfile_3d="${subject}_${FOLDER}_3d"
            # fsleyes render -s3d -of "$name_outfile_3d" file [display0pts]
        # done
    # done
}

runFSL "$1"