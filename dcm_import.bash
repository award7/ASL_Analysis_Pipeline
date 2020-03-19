#!/usr/bin/env bash

#creates a .nii file from the raw .dcm files

#setup dcm2niix path
#change this as needed
PATH=$PATH:~/Documents/mricrogl

# get list of subjects
shopt -s nullglob
arr_subj=(*"$1"*)
for SUBJECT in "${arr_subj[@]}"*; do 
    dcm2niix -f "t1_raw" -o "./${SUBJECT}/t1/proc" "./${SUBJECT}/t1/raw"
    echo "Completed ---- $SUBJECT"
done
