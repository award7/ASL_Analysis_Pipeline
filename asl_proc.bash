#!/usr/bin/env bash

#### Constants
ANALYSIS="asl_proc"
progname="asl_proc"
usr="$(whoami)"
dir=$(pwd)
shopt -s globstar
shopt -s nullglob
# Set path to scripts
# change as needed
src_path="/usr/local/bin"
log_path="/var/log/asl.log"


#### Functions

# error handler
function err(){
	case "$1" in
		1)
			printf "ERROR: Unknown argument \'%s'\n" "$2";
			usage;
			;;
		2)
			arr=("$@")
			printf "ERROR: The following directories are empty:\n";
			printf "%s\n" "${arr[@]}";
			printf "Please rectify.\n";
			;;
	esac
	exit
}

# logger
function logger(){
    duration="$(timer)"
    printf '%s: %s Successful on %s %s (duration: %s)\n' "$usr" "$ANALYSIS" `date "+%Y-%m-%d %H:%M:%S"` "$duration" >> "$log_path"
}

# timer
function timer(){
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

function prompt1(){
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

function prompt2(){
    TIMEPOINT=""
    until [ "${#TIMEPOINT}" -eq 3 ]; do    
        local prompt="Enter timepoint for ${FOLDER}: "
        read -p "${prompt}" TIMEPOINT
    done
    echo "$TIMEPOINT"
}

# usage function
function usage(){
   echo "
    Usage: $progname [OPTION]
    Analyze ASL files
   
    Required Arguments:
     -f, --files          Subject files to analyze
     -a, -all			  Analyze all files in current directory. Supercedes any -f options
	    
    Optional Arguments:
     -h, --help           Show this help message and exit
	"
	exit
}


#### Main

printf "%s: Beginning %s on %s" "$usr" "$ANALYSIS" "$(date)"
# read -p "Enter last four digits of study number (i.e. IRB number; press ENTER for all files): " STUDY


arr_subj=()
while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		-a|--all)
        file_arr=(*);
        break;
        ;;
		-f|--files)
			arr_subj+=("$2"); # make array of subject files
			shift 2;
			;;
		-h|--help)
			usage;
			;;
		*)
			err 1 "$key";
			;;
	esac
done


# checks for empty subject directories
echo "Checking for empty directories..."
arr_empty_dir=()
for subject in "${arr_subj[@]}"; do
	empty_dir=$(find '$subject' -type d -empty 2>/dev/null)
	if [ -n "$empty_dir" ]; then
		arr_empty_dir+=("$empty_dir")
	fi
done
err 2 "${arr_empty_dir[@]}"


# set up directory structure in folders
SECONDS=0
ANALYSIS="dir_setup.bash"
for subject in "${arr_subj[@]}"; do
    # get and list all asl folders
    arr_folders=("$subject}"/*)
    for FOLDER in "${arr_folders[@]}"; do
        if [[ "$FOLDER"==*"contrast"* ]]; then        
            printf "ASL folders:\n" 
            printf "${arr_asl[@]}"
            prompt1
            # get input from user
            TIMEPOINT=$(prompt2)
            # change name of folder, make subdirectories, move files to raw dir
            mv "$FOLDER" "${subject}/asl_${TIMEPOINT}_mins"
            mkdir "${subject}/asl_${TIMEPOINT}_mins"/{raw,proc}
            find "${subject}/asl_${TIMEPOINT}_mins" -name '*' -type f -exec mv -t "${subject}/asl_${TIMEPOINT}_mins/raw" {} +
        elif [[ "$FOLDER"==*"T1*" ]]; then
            mv "$FOLDER" "./${subject}/t1"
            mkdir "./${subject}/t1"/{raw,proc}
            find "${subject}/t1" -name '*' -type f -exec mv -t "${subject}/t1/raw" {} +
        else
            mkdir "${subject}/${FOLDER}"/{raw,proc}
            find "${subject}/${FOLDER}" -name '*' -type f -exec mv -t "${subject}/${FOLDER}/raw" {} +
        fi
    done    
    printf "Completed ---- %s \n%s \n" "$subject" "-----------------------------------------------------"
done
# logger "${usr}" "$log_path" "${ANALYSIS}" "$SECONDS"
logger "${usr}" "${ANALYSIS}"


# change the raw image filenames
SECONDS=0
ANALYSIS = "dcm_ext.bash"
echo "Adding .dcm extension to image files..."
for subject in "${arr_subj[@]}**"; do
    find $subject -mindepth 1 ! -name '*.*' -type f -execdir bash -c 'mv -i -- "$1" "${1// /_}.dcm"' Mover {} \;
done
logger "${usr}" "${ANALYSIS}"


# unzip files if needed
echo "Unzipping files..."
for subject in "${arr_subj[@]}"; do
    find $subject -name '*.gz' -type f -exec gunzip -f {} \;
done


# .dcm to .nii conversion
SECONDS=0
ANALYSIS="dcm_import.bash"
echo "DICOM to .nii conversion of T1 images..."
for subject in "${arr_subj[@]}"; do
    dcm2niix -f "t1_raw" -o "{subject}/t1/proc" "${subject}/t1/raw"
done
logger "${usr}" "${ANALYSIS}"


# afni fmap and pdmap
SECONDS=0
ANALYSIS="brik.bash"
echo "Making fmap and pdmap of ASL images..."
for subject in "${arr_subj[@]}"; do
	arr_folders=("$subject}"/asl*)
	for FOLDER in "${arr_folders[@]}"; do
		#transform raw asl images into AFNI 4D format
		#produces a .HEAD and .BRIK file
		#set prefix to a filename that will be appended by "+orig.BRIK"
		to3d -prefix "${subject}_${FOLDER}" -fse -time:zt 40 2 1000 seq+z *.dcm

		#Generate quantitative CBF images
		#make fmap .BRIK and .HEAD files
		#filename should be the same prefix used in the to3d command
		#will be appended by "_fmap+orig.BRIK"
		3df_pcasl -nex 3 -odata "${subject}_${FOLDER}"

		#Write out the ASL CBF image in .nii format
		#make a fmap
		#filename should be the output from the 3df_pcasl command
		3dcalc -a "${subject}_${FOLDER}_fmap+orig.[0]" -datum float -expr 'a' -prefix "${subject}_${FOLDER}_fmap.nii"

		#Write out the ASL CBF image in .nii format
		#make a proton density map
		#filename should be the output from the 3df_pcasl command
		3dcalc -a "${subject}_${FOLDER}_fmap+orig.[1]" -datum float -expr 'a' -prefix "${subject}_${FOLDER}_pdmap.nii"
		
		#move created files into proc folder
		mv "${subject}/${FOLDER}/"*.nii "${subject}/${FOLDER}/"*.BRIK "${subject}/${FOLDER}/"*.HEAD -t "${subject}/${FOLDER}/proc"
	done
done


# call spm functions
# TODO: pass pwd as argument to matlab
    # assing pwd to a string then pass it in??
echo "Calling MATLab for SPM functions..."
# pass arr_subj to matlab by 'unraveling' the array into a delimited string
printf -v arr_subj_matlab '%s ' "${arr_subj[@]}"
matlab -nodesktop -nodisplay -nojvm -r "spm_functions('$arr_subj_matlab', '$dir'); exit;"


# TODO: fsl functions
echo "Making images in FSL..."
# for subject in "${arr_subj[@]}"; do
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


# zip files
echo "Zipping files..."
for subject in "${arr_subj[@]}"; do
    find $subject ! \( -name "*.nii" -o -name "*.dcm" -o -name "*.BRIK" -o -name "*.HEAD" \) -type f -exec gzip {} \;
done

printf "%s completed on %s" "$progname" `date "+%Y-%m-%d %H:%M:%S"`
