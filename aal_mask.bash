#!/usr/bin/env bash

#multiplies the aal inverse-warped mask by the gm

SECONDS=0
COUNTER=0

ANALYSIS="aal mask"

echo "Beginning $ANALYSIS on $(date)"

#subject folder
for SUBJECT in "$1"*; do 
	echo "Beginning ---- $SUBJECT"
	(
		#enter into specific directory
		cd "${SUBJECT}/t1/proc"
		
		#gray matter image
		GM_IMG="$(find . -name c1*.nii)"
		
		#inverse warped image
		INVWARP="$(find . -name invwarp*.nii)"
		
		#call matlab function
		matlab -nodesktop -nosplash -wait -r "aal_mask('$GM_IMG','$INVWARP'); exit"
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
