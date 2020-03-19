#!/usr/bin/env bash

ANALYSIS="asl_proc"
usr="$(whoami)"
echo "${usr}: Beginning ${ANALYSIS} on $(date)"

# Set path to scripts first
 #change as needed
src_path="C:/Users/atward/Box/Data_Analysis_Transforms/asl/ASL_Analysis_Pipeline"
log_path="C:/Users/atward/Box/Data_Analysis_Transforms/asl/ASL_Analysis_Pipeline/log.txt"

# logging function
logger() {
    duration="$(timer)"
    printf '%s: %s Successful on %s %s (duration: %s)\n' "$usr" "$ANALYSIS" `date "+%Y-%m-%d %H:%M:%S"` "$duration" >> "$log_path"
}

timer() {
    if (( $SECONDS > 3600 )) ; then
        let "HOURS=SECONDS/3600"
        let "MINUTES=(SECONDS%3600)/60"
        let "SECONDS=(SECONDS%3600)%60"
        # echo "Completed $ANALYSIS in $HOURS hour(s), $MINUTES minute(s) and $SECONDS second(s)"
        echo "${HOURS} hours(s), ${MINUTES} minute(s), ${SECONDS} second(s)"
    elif (( $SECONDS > 60 )) ; then
        let "MINUTES=(SECONDS%3600)/60"
        let "SECONDS=(SECONDS%3600)%60"
        # echo "Completed $ANALYSIS in $MINUTES minute(s) and $SECONDS second(s)"
        echo "{$MINUTES} minute(s), ${SECONDS} second(s)"
    else
        # echo "Completed $ANALYSIS in $SECONDS seconds"
        echo "${SECONDS} second(s)"
    fi
}

prompt1() {
    declare -a arr_time=(
    'Time Points:'
    '000- Baseline' 
    '010- 10 mins' 
    '015- 15 mins'
    '020- 20 mins'
    '025- 25 mins'
    '030- 30 mins'
    '035- 35 mins'
    '045- 45 mins'
    '050- 50 mins'
    '055- 55 mins'
    '060- 60 mins'
    '075- 75 mins'
    '090- 90 mins'
    '105- 105 mins'
    '120- 120 mins')
    for i in "${arr_time[@]}"; do
        printf "%s\n" "$i"
    done
}

prompt2() {
    TIMEPOINT=""
    until [ "${#TIMEPOINT}" -eq 3 ]; do    
        local prompt="Enter timepoint for ${FOLDER}: "
        read -p "${prompt}" TIMEPOINT
    done
    echo "$TIMEPOINT"
}


read -p "Enter last four digits of study number (i.e. IRB number; press ENTER for all files): " STUDY


# checks that all raw files exist
empty_dir=$(find . -name '*${STUDY}*' -type d -empty)
if [ -n "$empty_dir" ]; then
    echo -e "ERROR: The following directories are empty: \n\n ${empty_dir} \n\n Please rectify. \n Canceling."
    exit 1
fi


# create subject file array
shopt -s nullglob
arr_subj=(*"$STUDY"*)


# set up directory structure in folders
SECONDS=0
ANALYSIS="dir_setup.bash"
#source "${src_path}/${ANALYSIS}" "$STUDY"
for SUBJECT in "${arr_subj[@]}"; do
    # get and list all asl folders
    arr_folders=("$SUBJECT}"/*)
    for FOLDER in "${arr_folders[@]}"; do
        if [[ "$FOLDER"==*"contrast"* ]]; then        
            echo
            echo "ASL folders:"
            printf "%s\n" "${arr_asl[@]}"
            echo
            prompt1
            # get input from user
            TIMEPOINT=$(prompt2)
            # change name of folder, make subdirectories, move files to raw dir
            mv "$FOLDER" "./${SUBJECT}/asl_${TIMEPOINT}_mins"
            mkdir -p "./${SUBJECT}/asl_${TIMEPOINT}_mins"/{raw,proc}
            find ./"${SUBJECT}/asl_${TIMEPOINT}_mins" -name '*' -type f -exec mv -t ./"${SUBJECT}/asl_${TIMEPOINT}_mins/raw" {} +
        elif [[ "$FOLDER"==*"T1*" ]]; then
            mv "$FOLDER" "./${SUBJECT}/t1"
            mkdir -p "./${SUBJECT}/t1"/{raw,proc}
            find ./"${SUBJECT}/t1" -name '*' -type f -exec mv -t ./"${SUBJECT}/t1/raw" {} +
        else
            mkdir -p "./${SUBJECT}/${FOLDER}"/{raw,proc}
            find ./"${SUBJECT}/${FOLDER}" -name '*' -type f -exec mv -t ./"${SUBJECT}/${FOLDER}/raw" {} +
        fi
    done    
    echo
    echo "Completed ---- ${SUBJECT}"
    echo "-----------------------------------------------------"
done
logger "${usr}" "$log_path" "${ANALYSIS}" "$SECONDS"


# change the raw image filenames
SECONDS=0
ANALYSIS = "dcm_ext.bash"
find ./"$STUDY" -name '*' -type f -execdir bash -c 'mv -i -- "$1" "${1// /_}.dcm"' Mover {} \;
logger "${usr}" "$log_path" "${ANALYSIS}" "$SECONDS"

# install dcm2niix on linux vm
# .dcm to .nii conversion
SECONDS=0
ANALYSIS="dcm_import.bash"
# setup dcm2niix path
# change this as needed
for SUBJECT in "${arr_subj[@]}"; do
	dcm2niix -f "t1_raw" -o "./{SUBJECT}/t1/proc" "./${SUBJECT}/t1/raw"
done
logger "${usr}" "$log_path" "${ANALYSIS}" "$SECONDS"


# afni fmap and pdmap
# TODO: make afni path an environment variable
PATH=$PATH:/usr/local/afni
for SUBJECT in "${arr_subj[@]}"; do
	arr_folders=("$SUBJECT}"/asl*)
	for FOLDER in "${arr_folders[@]}"; do
		#transform raw asl images into AFNI 4D format
		#produces a .HEAD and .BRIK file
		#set prefix to a filename that will be appended by "+orig.BRIK"
		to3d -prefix "${SUBJECT}_${FOLDER}" -fse -time:zt 40 2 1000 seq+z *.dcm

		# TODO: install dependencies for 3df_pcasl, add path to environment variable
		PATH=$PATH:/usr/local/bin
		#Generate quantitative CBF images
		#make fmap .BRIK and .HEAD files
		#filename should be the same prefix used in the to3d command
		#will be appended by "_fmap+orig.BRIK"
		3df_pcasl -nex 3 -odata "${SUBJECT}_${FOLDER}"

		#Write out the ASL CBF image in .nii format
		#make a fmap
		#filename should be the output from the 3df_pcasl command
		3dcalc -a "${SUBJECT}_${FOLDER}_fmap+orig.[0]" -datum float -expr 'a' -prefix "${SUBJECT}_${FOLDER}_fmap.nii"

		#Write out the ASL CBF image in .nii format
		#make a proton density map
		#filename should be the output from the 3df_pcasl command
		3dcalc -a "${SUBJECT}_${FOLDER}_fmap+orig.[1]" -datum float -expr 'a' -prefix "${SUBJECT}_${FOLDER}_pdmap.nii"
		
		#move created files into proc folder
		mv *.nii *.BRIK *.HEAD -t "./${SUBJECT}/${FOLDER}/proc"
	done
done


# call spm functions
# TODO: pass pwd as argument to matlab
matlab -nodesktop -nodisplay -nojvm -r "spm_functions('$(pwd)'); exit;"


# TODO: fsl functions
# TODO: add fsl to environment variable
PATH=$PATH:/usr/local/fsl
for SUBJECT in "${arr_subj[@]}"; do
	for FOLDER in "${arr_folders[@]}"; do
		# TODO: get mri img files as inputs
			# do for all mri imgs for QC purposes
			# raw t1, segmented t1 imgs, smoothed gm, normalized, etc.
		# TODO: replace "file [display0pts]" with img file name and display options
	
		name_outfile_ortho="${SUBJECT}_${FOLDER}_ortho"
		fsleyes render -sortho -of "$name_outfile_ortho" file [display0pts]
		
		name_outfile_lb="${SUBJECT}_${FOLDER}_lightbox"
		fsleyes render -slightbox -of "$name_outfile_lb" file [display0pts]
		
		name_outfile_3d="${SUBJECT}_${FOLDER}_3d"
		fsleyes render -s3d -of "$name_outfile_3d" file [display0pts]
	done
done


# zip files
find . ! \( -name "*.nii" -o -name "*.dcm" \) -type f -exec gzip {} \;

# TODO: move subject dir out of 'unproc' dir
