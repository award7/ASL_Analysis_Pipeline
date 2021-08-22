#!/usr/bin/env bash

### .dcm to .nii conversion
function runDCM2nii() {
    echo; echo "DICOM to .nii conversion of T1 images..."
    for subject in "${subject_array[@]}"; do
            dcm_count="$(find ${subject}/t1/raw -name '*.dcm' | wc -l)"
            if ! (( $dcm_count == 50 )); then # change for each study
		delete=("$subject")
		for del in "${delete[@]}"; do
			subject_array=("${subject_array[@]/$del}")
		done
		break
            fi
            local subject_condensed="$(rm_underscores $subject)"
            if [ -e "${subject}/t1/proc/t1_${subject_condensed}.nii" ]; then
                rm "${subject}/t1/proc/t1_${subject_condensed}.nii"
                rm "${subject}/t1/proc/t1_${subject_condensed}.json"
            fi
            dcm2niix_afni -f "t1_${subject_condensed}" -o "${subject}/t1/proc" "${subject}/t1/raw" || error 44 "dcm2nii" "$LINENO"
    done
}

runDCM2nii "$1"