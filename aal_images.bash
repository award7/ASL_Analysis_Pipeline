#!/usr/bin/env bash

SECONDS=0

ANALYSIS="aal images"

echo "Beginning $ANALYSIS on $(date)" 

#place the roi.txt in a common path
#be sure to set the path for the .txt file
mapfile -t REGIONS < roi.txt 

#array length
LEN=${#REGIONS[@]} 

for SUBJECT in 0197*; do   #each subject folder
	(
		echo "Beginning ---- $SUBJECT"
		cd "${SUBJECT}/ASL_Data"
		t1_file="$(find ./t1/proc -name *t1_raw.nii)" #check name
		for FOLDER in asl*; do   #each ASL folder
			echo "timepoint-----$FOLDER"
			aal_mask="$(find . -name ${FOLDER}/*aal_mask.nii)" #check name

			#loop
			COUNTER=1
			until [ "$COUNTER" -gt "$LEN" ]; do
				ROI="${REGIONS[$COUNTER]}"
				fslmaths "$aal_mask" -thr 36.5 -uthr 37.5 "$ROI"
				#call fsleyes script to take screenshot of the roi overlayed on the t1
				fsleyes_screenshots.bash "$t1_file" "$ROI"
				((COUNTER++))
			done
		done
	)
	echo
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