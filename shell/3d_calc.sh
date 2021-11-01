#!/bin/bash

# make a fmap[0] or proton density map[1]
input="$1";
subject="$2"
timepoint="$3"
outdir="$4"
map=$5;

if [[ $map -eq 0 ]]; then
  prefix="asl_fmap";
else
  prefix="pdmap"
fi

# filename should be the output from the 3df_pcasl command
3dcalc -a "$1/zt_${subject_condensed}_${folder}_fmap+orig.[${map}]" -datum float -expr 'a' -prefix "${prefix}_${subject}_${timepoint}.nii"

file="$(find . -maxdepth 1 -type f -name ${prefix}*.nii -exec basename {} \)";
echo "$file";

mv "$file" -t "$outdir"