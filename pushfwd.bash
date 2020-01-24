#!/usr/bin/env bash

#performs pushforward deformation

SECONDS=0
COUNTER=0

ANALYSIS="deformation"

echo "Beginning $ANALYSIS on $(date)"

#subject folder
for SUBJECT in "$1"*; do 
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}/t1/proc"
		
		#deformation field of t1
		DEFORM_FIELD="/y_raw_t1.nii" 
		
		#smoothed gm image
		SMOOTHED_GM="/smoothed_c1raw_t1.nii" 
		
		matlab -nodesktop -nosplash -wait -r "pushfwd('$DEFORM_FIELD','$SMOOTHED_GM'); exit"
	)
	COUNTER=$((COUNTER+1))
	PROG=$((100*COUNTER/$2))
	echo "Completed ---- ${SUBJECT} ---- ${PROG}%"
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

