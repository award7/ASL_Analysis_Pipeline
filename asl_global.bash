#!/usr/bin/env bash

SECONDS=0
COUNTER=0

ANALYSIS="asl global"

echo "Beginning $ANALYSIS on $(date)" 

#subject ID
for SUBJECT in "$1"*; do
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}"
		for FOLDER in asl*; do
			(
				cd "${FOLDER}/proc" #enter into specific directory
				BMASK="$(find . -name bmask*.nii)"
				OUTPUT="asl_${SUBJECT}_${FOLDER}"
				matlab -nodesktop -nosplash -wait -r "asl_global('$BMASK','$OUTPUT'); exit"
				mv "$(find . -name global*.csv)" ../"data"
				COUNTER=$((COUNTER+1))
				PROG=$((100*COUNTER/$2))
				echo "Completed ---- ${FOLDER} ---- ${PROG}"
			)
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