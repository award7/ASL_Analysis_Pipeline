#!/usr/bin/env bash

#creates a brainmasked ASL image for calculating global perfusion

SECONDS=0
COUNTER=0

ANALYSIS="bmask"

echo "Beginning $ANALYSIS on $(date)"

#subject folder
for SUBJECT in "$1"*; do 
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}" #enter into specific directory
		PUSHFWD_DEFORM="$(find ./t1/proc/ -name pushfwd*)"
		for FOLDER in asl*; do
			COREG_FMAP="${FOLDER}/proc/smoothed_wcoreg_${SUBJECT}_${FOLDER}_fmap.nii"
			matlab -nodesktop -nosplash -wait -r "bmask('$COREG_FMAP','$PUSHFWD_DEFORM'); exit"
			mv bmask* ./"${FOLDER}/proc"
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
