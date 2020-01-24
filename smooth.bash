#!/usr/bin/env bash

#smooth segmented gray matter image
#average duration ...

SECONDS=0
COUNTER=0

ANALYSIS="Smooth"

echo "Beginning $ANALYSIS on $(date)"

#subject files
for SUBJECT in "$1"*; do 
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}/t1/proc"
		IMG="$(find . -name c1raw_t1.nii)" #segmented img
		matlab -nodesktop -nosplash -wait -r "smooth('$IMG'); exit;"
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