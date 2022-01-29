#!/usr/bin/env bash

### change the raw image filenames
function runDCMext() {
    echo; echo "Adding .dcm extension to image files..."
    for subject in "${subject_array[@]}**"; do
            find $subject -mindepth 1 ! -name '*.*' -type f -execdir bash -c 'mv -i -- "$1" "${1// /_}.dcm"' Mover {} \;
    done
}

runDCMext "$1"