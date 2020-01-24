#!/usr/bin/env bash

#gzips image files to save space

#zip .dcm files
find . -type f -name "*.dcm" -exec gzip {} \;

#zip .nii files
#find . -type f -name "*.nii" -exec gzip {} \;