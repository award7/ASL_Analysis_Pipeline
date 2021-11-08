#!/usr/bin/env bash

### make fmap and pdmap
function runFmapMake() {
    echo; echo "Making ASL fmap and PDmap images..."
    
    for subject in "${subject_array[@]}"; do
      get_subfolders "$subject"
        for folder in "${subfolders_array[@]}"; do

            if [[ "$folder" == asl* ]]; then
                subject_condensed="$(rm_underscores $subject)"

                if [ -e "${subject}/${folder}/proc/zt_${subject_condensed}_${folder}+orig.BRIK" ]; then
                    rm "${subject}/${folder}/proc/zt_${subject_condensed}_${folder}+orig"*
                fi
                
                if [ -e "${subject}/${folder}/proc/zt_${subject_condensed}_${folder}_fmap+orig.BRIK" ]; then
                    rm "${subject}/${folder}/proc/zt_${subject_condensed}_${folder}_fmap+orig"*
                fi
                
                if [ -e "${subject}/${folder}/proc/asl_fmap_${subject_condensed}_${folder}.nii" ]; then
                    rm "${subject}/${folder}/proc/asl_fmap_${subject_condensed}_${folder}.nii"
                fi
                
                if [ -e "${subject}/${folder}/proc/pdmap_${subject_condensed}_${folder}.nii" ]; then
                    rm "${subject}/${folder}/proc/pdmap_${subject_condensed}_${folder}.nii"
                fi
                
                dcm_count="$(find ${subject}/${folder}/raw -name '*.dcm' | wc -l)"
                nt=$(($dcm_count/2))
                tr=1000
                
                if ! (( $dcm_count == 80 )); then # change for each study
	                break
                fi
                
                # transform raw asl images into AFNI format
                # produces a .HEAD and .BRIK file
                # set prefix to a filename that will be appended by "+orig.BRIK"
                to3d -prefix "zt_${subject_condensed}_${folder}" -fse -time:zt $nt 2 $tr seq+z "${subject}/${folder}/raw/"*.dcm || error 44 "to3d" "$LINENO"
                
                # Generate quantitative CBF images using GE's 3df_pcasl 32-bit binary program
                # make fmap .BRIK and .HEAD files
                # filename should be the same prefix used in the to3d command
                # two files will be appended by "fmap_+orig.BRIK" and "fmap_+orig.HEAD"
                3df_pcasl -nex 3 -odata "zt_${subject_condensed}_${folder}" # || error 44 "3df_pcasl" "$LINENO"

                # make a fmap
                # filename should be the output from the 3df_pcasl command
                3dcalc -a "zt_${subject_condensed}_${folder}_fmap+orig.[0]" -datum float -expr 'a' -prefix "asl_fmap_${subject_condensed}_${folder}.nii" || error 44 "3dcalc" "$LINENO"

                # make a proton density map
                # filename should be the output from the 3df_pcasl command
                3dcalc -a "zt_${subject_condensed}_${folder}+orig.[1]" -datum float -expr 'a' -prefix "pdmap_${subject_condensed}_${folder}.nii" || error 44 "3dcalc" "$LINENO"

                mv zt* *.nii -t "${subject}/${folder}/proc"
                runConfirmation "Completed fmap_make for ${subject} ${folder}"
            fi
        done
        unset 'subfolders_array[@]'
    done
    echo "Completed making ASL fmap and PDmap images..."
}

runFmapMake "$1"