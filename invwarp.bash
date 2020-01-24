#!/usr/bin/env bash

SECONDS=0
COUNTER=0

ANALYSIS="invwarp (Inverse Warp MNI --> Subject Space)"

echo "Beginning $ANALYSIS on $(date)" 

#each subject folder
for SUBJECT in "$1"*; do
	echo "Beginning ---- ${SUBJECT}"
	(
		cd "${SUBJECT}/t1/proc"
		DEFORM_FIELD="$(find . -name y*)"
		SMOOTH_GM="$(find . -name smoothed_c1*)"
		matlab -nodesktop -nosplash -wait -r "invwarp('$DEFORM_FIELD','$SMOOTH_GM'); exit"
	)
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