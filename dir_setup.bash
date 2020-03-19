#!/usr/bin/env bash

# creates directory tree for t1 and asl processing pipeline

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

# get list of subjects
shopt -s nullglob
arr_subj=(*"$1"*)
for SUBJECT in "${arr_subj[@]}"; do
    # get and list all asl folders
    arr_asl=("${SUBJECT}"/*contrast*)
    if [ "${#arr_asl[@]}" -gt 0 ]; then
        echo
        echo "ASL folders:"
        printf "%s\n" "${arr_asl[@]}"
        echo
        prompt1
        # loop through asl folders
        for FOLDER in "${arr_asl[@]}"; do
            # get input from user
            TIMEPOINT=$(prompt2)
            # change name of folder, make subdirectories
            mv "$FOLDER" "./${SUBJECT}/asl_${TIMEPOINT}_mins"
            mkdir -p "./${SUBJECT}/asl_${TIMEPOINT}_mins"/{raw,proc}
        done
    fi
    # rename t1 folder, make sub directories
    arr_t1=("${SUBJECT}"/*T1*)
    if [ "${#arr_t1[@]}" -gt 0 ]; then
        mv "${arr_t1[-1]}" "./${SUBJECT}/t1"
        mkdir -p "./${SUBJECT}/t1"/{raw,proc}
    fi
    echo
    echo "Completed ---- ${SUBJECT}"
    echo "-----------------------------------------------------"
done
