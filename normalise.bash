#!/usr/bin/env bash

#normalize the coregistered images

SECONDS=0
COUNTER=0

ANALYSIS="Normilization"

echo "Beginning $ANALYSIS on $(date)"

#subject files
for SUBJECT in "$1"*; do
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}"
		DEFORM_FIELD="$(find ./t1/proc -name y_raw_t1.nii)" #deformation field of t1
		BIAS_T1="$(find ./t1/proc -name mraw_t1.nii)" #bias corrected t1
		for FOLDER in asl*; do #look for ASL subdirectories
			COREG_FMAP="/${FOLDER}/proc/coreg_${SUBJECT}_${FOLDER}_fmap.nii"
			COREG_PDMAP="/${FOLDER}/proc/coreg_${SUBJECT}_${FOLDER}_PDmap.nii"
			matlab -nodesktop -nosplash -wait -r "normalise('$DEFORM_FIELD','$BIAS_T1','$COREG_FMAP','$COREG_PDMAP'); exit"
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
