# opening message and setup table
echo; echo "Running FSL for ASL perfusion of ROIs..."
divider="======================================="
divider="${divider}${divider}"
header="\n %-15s %-15s %-30s %-10s\n"
format=" %-15s %-15s %-30s %-10s\n"
width=75
printf "$header" "SUBJECT ID" "TIME POINT" "ROI" "PERFUSION"
printf "%$width.${width}s\n" "$divider"
cores=4
masks_array=("${subject}/t1/masks/aal/invwarpXgm"/*)
masks_array+=("${subject}/t1/masks/lobes/invwarpXgm"/*)
masks_array+=("${subject}/t1/masks/territories/invwarpXgm"/*)
for folder in "$(pwd)"; do
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