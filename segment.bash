#!/usr/bin/env bash

#segments raw t1 img into gm, wm, and csf
#average duration ~3 mins/file

SECONDS=0
COUNTER=0

ANALYSIS="Segmentation"

echo "Beginning $ANALYSIS on $(date)"

#subject files
for SUBJECT in "$1"*; do 
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}/t1/proc"
		IMG="$(find . -name raw_t1.nii)"
		matlab -nodesktop -nosplash -wait -r "segment('$IMG'); exit;"
	)
	COUNTER=$((COUNTER+1))
	PROG=$((100*COUNTER/$2))
	echo "Completed ---- ${SUBJECT} ---- ${PROG}%"
done
