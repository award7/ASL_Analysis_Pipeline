#!/usr/bin/env bash

### usage function
function usage() {
    # 1 = parent script name
    # 2 = version
    # 3 = version date
    # 4 = version author
    
    format1="       %5s %s\n"
    format2="\t%-30s %s\n"
    
    echo
    echo "$(basename "$1")"
    echo "Version: $2"
    echo "Modified: ${3} by ${4}"
    echo
    echo "ASL preprocessing pipeline with AFNI, SPM12, and FSL."
    echo
    echo "Usage: aslproc [OPTIONS]"
    echo
    
    printf "$format1"  "Required: " 
    printf "$format2"  "-b, --brain [SUBJECT_ID]"     "Subject to process"
    printf "$format2"  "-a, --all"              "Analyze all files in current directory. Supercedes any -b options"
    echo
    
    printf "$format1"  "Processing Stream Options: "
    printf "$format1"  "NOTE: options are presented in processing chronology."
    echo
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
    echo
    printf "$format1"  "Other:"
    printf "$format2"  "--coreg_method [METHOD]"  "Specify coregistration method. A = PDmap as reference, fmap as other; B = fmap as reference, PDmap as other (default is method B)"
    printf "$format2"  "--rename [T/F]"         "Rename ASL and T1 folders, and add necessary subfolders. Default is TRUE"
    printf "$format2"  "-h, --help"            "Prints this help entry"
    echo
    
    echo "Examples:"
    echo "1. Run main preprocessing stream on a specified subject:"; echo
    echo "    ${1} --brain 0197_C02_L --run_pproc"; echo
    echo "2. Segment T1 image and smooth the resulting GM image for all subjects in the directory:"; echo 
    echo "    ${0} -a --segment --smooth"; echo
    echo "3. Use coregistration method A (ASL-to-GMseg) instead of method B (PD-to-GMseg)"; echo
    echo "    ${1} -a -c --coreg_method A"
    echo
    
    
    
}

usage "$1" "$2" "$3" "$4"