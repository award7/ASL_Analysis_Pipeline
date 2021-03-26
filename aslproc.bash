#!/usr/bin/env bash

# aslproc.bash
# version 1.0
# 2020/03/25 - ATW

#################
### Functions ###
#################

### setup directory structure in folders
function dirSetup() {
    for subject in "${subject_array[@]}"; do
        # get and list all asl folders
        get_subfolders "$subject"
        for folder in "${subfolders_array[@]}"; do
            if [[ "$folder" == *contrast* || "$folder" == [Aa]sl* ]]; then
                rename_directory "$subject" "$folder"
            elif [[ "$folder" == T1* ]]; then
                runMakeMove "$subject" "$folder" "t1"
            else
                mkdir "${subject}/${folder}/raw" 2>/dev/null
                find "${subject}/${folder}" -name '*' -type f -exec mv -t "${subject}/${folder}/raw" {} + 2>/dev/null
            fi
        done
        mkdir -p "${subject}/masks/"{aal,lobes,territories}/{invwarp,invwarpXgm} 2>/dev/null
        unset subfolders_array
    done
}

### error handler
function error() {
    case $1 in
        bad_arg)
            runError "Error: Unrecognized argument...";
            usage;
            exit 31;
            ;;
        invalid_coreg_method)
            runError "Error: Invalid coregistration method";
            usage;
            echo;
            exit 43;
            ;;
        44)
            runError "Error: ${2} execution failed (line ${3})";
            echo;
            exit 44;
            ;;
        no_subject)
            runError "Error: No subjects selected";
            usage;
            echo;
            exit 45;
            ;;
        invalid_rename_option)
            runError "Error: Invalid rename option"
            usage;
            echo;
            exit 46;
            ;;
        *)
            runError "Unknown error occured. Exiting...";
            echo;
            exit 99;
            ;;
    esac
}

### get array of subfolders
function get_subfolders() {
    subfolders=("$1"/*)
    for subfolder in "${subfolders[@]}"; do
        subfolders_array+=("$(basename $subfolder)")
    done
}

### Display manual
function manual() {
    echo
    echo "$(basename $0)"
    echo "Version: $version"
    echo "Modified: ${versoin_date} by ${version_author}"; echo
    echo "Function: ASL preprocessing pipeline with AFNI, SPM12, and FSL."; echo
    usage
    echo "Examples:"
    echo "1. Run main preprocessing stream on a specified subject:"; echo
    echo "    ${0} --brain 0197_C02_L --run_pproc"; echo
    echo "2. Segment T1 image and smooth the resulting GM image for all subjects in the directory:"; echo 
    echo "    ${0} -a --segment --smooth"; echo
    echo "3. Use coregistration method A (ASL-to-GMseg) instead of method B (PD-to-GMseg)"; echo
    echo "    ${0} -a -c --coreg_method A"
    echo
}

### remove underscores for simpler file naming
function rm_underscores() {
    local fname="${1//_/}"
    echo "$fname"
}

### renaming function for ASL folders
function rename_directory() {
    # $1 = subject id
    # $2 = asl folder name
    echo; echo "===== ASL Time Points ====="
    echo "----- Subject ${1} -----"
    PS3="Please enter your choice to rename \"${2}\": "; echo
    options=(
        'Baseline' 
        '10 mins' 
        '15 mins'
        '20 mins'
        '25 mins'
        '30 mins'
        '35 mins'
        '45 mins'
        '50 mins'
        '55 mins'
        '60 mins'
        '75 mins'
        '90 mins'
        '105 mins'
        '120 mins'
        'Do not rename'
    )
    select opt in "${options[@]}"
    do
        case $opt in
            "Baseline")
                new_folder_name="asl000";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "10 mins")
                new_folder_name="asl010";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "15 mins")
                new_folder_name="asl015";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "20 mins")
                new_folder_name="asl020";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "25 mins")
                new_folder_name="asl025";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "30 mins")
                new_folder_name="asl030";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "35 mins")
                new_folder_name="asl035";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";                
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "40 mins")
                new_folder_name="asl040";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "45 mins")
                new_folder_name="asl045";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "50 mins")
                new_folder_name="asl050";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "55 mins")
                new_folder_name="asl055";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "60 mins")
                new_folder_name="asl060";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "75 mins")
                new_folder_name="asl075";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "90 mins")
                new_folder_name="asl090";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "105 mins")
                new_folder_name="asl105";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "120 mins")
                new_folder_name="asl120";
                runConfirmation "Renaming \"${2}\" ---> \"${opt}\"";
                runMakeMove "$1" "$2" "$new_folder_name";
                break;
                ;;
            "Do not rename")
                runConfirmation "Not renaming \"${2}\""
                break;
                ;;
            *)
                runError "Invalid option \"${REPLY}\"";
                ;;
        esac
    done
}

### highlights green in stdout
function runConfirmation() {
    echo "$(tput smso; tput setaf 2)$1$(tput sgr 0)"; echo
}

### change the raw image filenames
function runDCMext() {
    echo; echo "Adding .dcm extension to image files..."
    for subject in "${subject_array[@]}**"; do
            find $subject -mindepth 1 ! -name '*.*' -type f -execdir bash -c 'mv -i -- "$1" "${1// /_}.dcm"' Mover {} \;
    done
}

### .dcm to .nii conversion
function runDCM2nii() {
    echo; echo "DICOM to .nii conversion of T1 images..."
    for subject in "${subject_array[@]}"; do
            local subject_condensed="$(rm_underscores $subject)"
            if [ -e "${subject}/t1/proc/t1_${subject_condensed}.nii" ]; then
                rm "${subject}/t1/proc/t1_${subject_condensed}.nii"
                rm "${subject}/t1/proc/t1_${subject_condensed}.json"
            fi
            dcm2niix_afni -f "t1_${subject_condensed}" -o "${subject}/t1/proc" "${subject}/t1/raw" || error 44 "dcm2nii" "$LINENO"
    done
}

### highlights red in stdout
function runError() {
    echo; echo "$(tput smso; tput setaf 1)$1$(tput sgr 0)"
}

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
                
                if ! (( $dcm_count > 0 )); then
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
        # masks_array+=("${subject}/masks/territories/invwarpXgm"/*)
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

### wrapper to rename dir, create subdir, and move raw files
function runMakeMove() {
    # $1 = subject id
    # $2 = original asl folder name
    # $3 = new asl folder name
    mv "${1}/${2}" "${1}/${3}"; mkdir -p $_/{raw,proc,data,images} 2>/dev/null
    find "${1}/${3}" -name '*' -type f -exec mv -t "${1}/raw" {} + 2>/dev/null
}

### wrapper to execute .m functions easier
function runMatlab() {
    matlab -nodesktop -nodisplay -nojvm -r "try $1; catch exception; display(getReport(exception)); pause(1); end; exit;"
}

### Run T1 and ASL preprocessing pipeline in SPM
# Portion of pipeline is written in .m for faster performance vs. individual calls to MATLAB for each step
function runPproc() {
  echo; echo "##### T1 and ASL preprocessing in SPM..."
  runMatlab "pproc('$arr_subj_matlab','$analysis_array_matlab','$coreg_method')"
}

### usage function
function usage() {
    format1="       %5s %s\n"
    format2="\t%-30s %s\n"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo "Analyze ASL files"; echo
    
    printf "$format1"  "Required: " 
    printf "$format2"  "-b, --brain [SUBJECT_ID]"     "Subject to process"
    printf "$format2"  "-a, --all"              "Analyze all files in current directory. Supercedes any -b options"

    printf "$format1"  "Processing Stream Options: "
    printf "$format1"  "NOTE: options are presented in processing hierachy."
    printf "$format2"  "-p, --pproc"           "Run full preprocessing pipeline. Supercedes any other processing options."
    printf "$format2"  "-f, --fmap_make"        "Make ASL fmap and PDmap"
    printf "$format2"  "--segment"            "Segment T1 image"
    printf "$format2"  "--smooth"             "Smooth GM image"
    printf "$format2"  "-c, --coreg"           "Coregister FMRI image(s) and structural image"
    printf "$format2"  "-n, --normalize"        "Normalize and smooth coregeistered image"
    printf "$format2"  "--mask_icv"            "Create ICV brain mask in MNI space"
    printf "$format2"  "--mask_asl"            "Create ASL brain mask in MNI space"
    printf "$format2"  "-g, --global"          "Calculate global ASL value from \"brainmasked\" ASL image"
    printf "$format2"  "-i, --invwarp"         "Apply masks in subject-space"
    printf "$format2"  "-ix, --invwarpXgm"      "Restrict masks to gray matter in subject-space"
    printf "$format2"  "-v, --volumes"         "Calculate segmented brain volumes"
    
    printf "$format1"  "Other:"
    printf "$format2"  "--coreg_method [METHOD]"  "Specify coregistration method. A = PDmap as reference, fmap as other; B = fmap as reference, PDmap as other (default is method B)"
    printf "$format2"  "--rename [T/F]"         "Rename ASL and T1 folders, and add necessary subfolders. Default is TRUE"
    printf "$format2"  "-h, --help"            "Prints manual entry"
    echo
}


##########################
### Static variable(s) ###
##########################
progname="$(basename $0)"
version="1.0"
usr="$(id -un)"
dir="$(pwd)"
cores=4
shopt -s globstar
shopt -s nullglob
datestamp=$(date +"%Y%m%d")
# logfile_central="/var/log/${datestamp}_aslproc.log"

###########################
### Dynamic variable(s) ###
###########################
logfile_local="${dir}/logs/${datestamp}_aslproc.log"


#######################
### Default Options ###
#######################
all_subjects=0
coreg_method=B
rename="TRUE"


####################################
### Parse Command-line Arguments ###
####################################
if [ $# -eq 0 ]; then
    usage; 
    exit 0
fi

subject_array=()
declare -A analysis_array
while [[ $# -gt 0 ]]; do
	case $1 in
        -b | --brain)
            subject_array+=("$2"); # make array of subject files
            shift 2;
            ;;
        -a | --all)
            all_subjects=1;
            shift;
            ;;
        -p | --pproc)
            analysis_array[0]=pproc;
            shift;
            ;;
        --dcm2nii)
            analysis_array[1]=dcm2nii;
            shift;
            ;;
        -f | --fmap_make)
            analysis_array[2]=fmap_make;
            shift;
            ;;
        --segment)
            analysis_array[3]=segment;
            shift;
            ;;
        --smooth)
            analysis_array[4]=smooth;
            shift;
            ;;
        -c | --coreg)
            analysis_array[5]=coreg;
            shift;
            ;;
        -n | --normalize)
            analysis_array[6]=normalize;
            shift;
            ;;
        --mask_icv)
            analysis_array[7]=brainmask_icv;
            shift;
            ;;
        --mask_asl)
            analysis_array[8]=brainmask_asl;
            shift;
            ;;
        -g | --global)
            analysis_array[9]=get_global;
            shift;
            ;;
        -i | --invwarp)
            analysis_array[10]=invwarp;
            shift;
            ;;
        -ix | --invwarpXgm)
            analysis_array[11]=invwarpXgm;
            shift;
            ;;
        -v | --volumes)
            analysis_array[12]=brain_volumes;
            shift;
            ;;
        -fsl)
            analysis_array[13]=fsl;
            shift;
            ;;
        --coreg_method)
            coreg_method=$2;
            shift 2;
            ;;
        --rename)
            rename=$2;
            shift 2;
            ;;
        -h | --help)
            manual;
            exit 0;
            ;;
        *)
            error bad_arg;
            ;;
	esac
done


######################
# Setup Verification #
######################
echo; echo "Verifying setup..."

if ! [ -d "${dir}/logs" ]; then
    mkdir -p "${dir}/logs" 2>/dev/null
fi

if [[ "${#subject_array[@]}" == 0 && "$all_subjects" == 0 ]]; then
    error "no_subject"
fi

if (( $all_subjects )); then
    subject_array=(*)
fi

if [[ "${analysis_array[@]}" =~ "pproc" ]]; then
    delete=("dcm2nii" "fmap_make" "pproc" "segment" "smooth" "normalize" "mask_icv" "mask_asl" "get_global" "invwarp" "invwarpXgm" "brain_volumes")
    for del in "${delete[@]}"; do
        analysis_array="${analysis_array[@]/$del}"
    done
    unset 'delete[@]'
    analysis_array+=( [0]="dcm2nii" [1]="fmap_make" [2]="segment" [3]="smooth" [4]="coreg" [5]="normalize" [6]="mask_icv" [7]="mask_asl" [8]="get_global" [9]="invwarp" [10]="invwarpXgm" [11]="brain_volumes" [12]="fsl")
fi

# IFS=$'\n' analysis_array_sorted=($(sort -k 2n <<<"${analysis_array[*]}"))
# unset IFS
# readarray -t analysis_array_sorted < <(printf '%s\0' "${analysis_array[@]}" | sort -k 1n | xargs -0n1)
# mapfile -d '' analysis_array_sorted < <(printf '%s\0' "${!analysis_array[@]}" | sort -k 2n)

if ! [[ "$coreg_method" == [Aa] || "$coreg_method" == [Bb] ]]; then
    error "invalid_coreg_method"
else
    coreg_method="${coreg_method^^}"
fi


######################
### Main Procedure ###
######################

### Start logs
# exec 3>&1 > >(tee -a $logfile_local)
# exec 3>&1 > >(tee -a $logfile_central)

### Welcome message
echo; echo "============= Begin ASL Processing ============="
echo "##### User $(id -un) on $(date +'%D %T')"
echo; echo "##### AslProc v.${version}"
echo "$(basename $0) options:"
echo; echo "  Subject(s):"
printf "    %s\n" "${subject_array[@]}"
echo; printf "  Analyses:\n"
for key in "${!analysis_array[@]}"; do
    printf "    %s) %s\n" "$key" "${analysis_array[$key]}"
done | sort -t : -k 1n
if [[ "${analysis_array[@]}" =~ "coreg" ]]; then
    printf "    --coreg_method: %s\n" "$coreg_method"
fi

### pass arrays to matlab by first 'unraveling' the array into a delimited string
printf -v arr_subj_matlab '%s,' "${subject_array[@]}"
printf -v analysis_array_matlab '%s,' "${analysis_array[@]}"

echo; echo "Unzipping files..."
for subject in "${subject_array[@]}"; do
    (
        find ${subject}/asl* -name '*.gz' -type f -exec gunzip -f {} \;
        find ${subject}/t1 -name '*.gz' -type f -exec gunzip -f {} \;
    ) &
    
    if [[ $(jobs -r -p | wc -l) -gt $cores ]]; then 
        wait -n
    fi
done
wait 

if [[ "${analysis_array[@]}" =~ "dcm2nii" ]]; then
    # delete_files
    runDCM2nii
fi

if [[ "${analysis_array[@]}" =~ "fmap_make" ]]; then
    # delete_files
    runFmapMake
fi

spm_fcn_array=("segment" "smooth" "normalize" "mask_icv" "mask_asl" "get_global" "invwarp" "invwarpXgm" "brain_volumes")
for element in "${spm_fcn_array[@]}"; do
    if [[ "${analysis_array[@]}" =~ "$element" ]] ; then
        runPproc "${arr_subj_matlab[@]}" "${analysis_array_matlab[@]}" "$coreg_method"
        break
    fi
done

if [[ "${analysis_array[@]}" =~ "fsl" ]]; then
    runFSL
fi

echo; echo "Zipping files..."
for subject in "${subject_array[@]}"; do
    (
        find ${subject}/asl* \( -name "*.nii" -o -name "*.dcm" -o -name "*.BRIK" -o -name "*.HEAD" \) -type f -exec gzip {} \;
        find ${subject}/t1 \( -name "*.nii" -o -name "*.dcm" \) -type f -exec gzip {} \;
    ) &
    
    if [[ $(jobs -r -p | wc -l) -gt $cores ]]; then 
        wait -n
    fi
done
wait 

### Exit message
echo; echo "============= Processing completed in $(( $SECONDS / 60 )) minutes $(( $SECONDS % 60 )) seconds ============="
echo

### End Log
# exec 1>&3 3>&-
exit 0

