#!/bin/bash

path="$1";
subject="$2"
outdir="$3"

nt="$(ls "$path" | wc -l | xargs -n 1 bash -c 'echo $(($1 / 2))' args)";
tr=1000

to3d -prefix "zt_${subject}" -fse -time:zt $nt 2 $tr seq+z "$path"/*;

file="$(find . -maxdepth 1 -type f -name zt_${subject}*.BRIK -exec basename {} \)";

mv zt* -t "$outdir";