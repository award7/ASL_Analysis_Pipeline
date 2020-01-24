#!/usr/bin/env bash

#coregister (i.e. slap together) the asl and t1 images

SECONDS=0
COUNTER=0

ANALYSIS="Coregistration"

echo "Beginning $ANALYSIS on $(date)" 

for SUBJECT in "$1"*; do #subject files
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}"
		T1_IMG="$(find ./t1/proc/ -name smoothed*.nii)"
		for FOLDER in asl*; do #look for ASL subdirectories
			FMAP="${FOLDER}/proc/${SUBJECT}_${FOLDER}_fmap.nii"
			PDMAP="${FOLDER}/proc/${SUBJECT}_${FOLDER}_PDmap.nii"
			matlab -nodesktop -nosplash -wait -r "coreg('$T1_IMG','$FMAP','$PDMAP'); exit"
			COUNTER=$((COUNTER+1))
			PROG=$((100*COUNTER/$2))
			echo "Completed ---- ${FOLDER} ---- ${PROG}"
		done
	)
	echo "Completed ---- ${SUBJECT}"
done

###################################

if (( $SECONDS > 3600 )) ; then
	let "HOURS=SECONDS/3600"
	let "MINUTES=(SECONDS%3600)/60"
	let "SECONDS=(SECONDS%3600)%60"
	echo "Completed $ANALYSIS in $HOURS hour(s), $MINUTES minute(s) and $SECONDS second(s)" 
elif (( $SECONDS > 60 )) ; then
	let "MINUTES=(SECONDS%3600)/60"
	let "SECONDS=(SECONDS%3600)%60"
	echo "Completed $ANALYSIS in $MINUTES minute(s) and $SECONDS second(s)"
else
	echo "Completed $ANALYSIS in $SECONDS seconds"
fi
