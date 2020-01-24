#!/usr/bin/env bash

#adds .dcm extension to raw image files and moves them to associated
#raw directories for proper import and organization during processing

SECONDS=0

ANALYSIS="dcm extension"

echo "Beginning $ANALYSIS on $(date)"

#loop into each subject's raw asl folder
for SUBJECT in "${1}"*; do 
	#give a status update
	echo "Beginning ---- $SUBJECT"
	(
		cd ./"${SUBJECT}"
		for FOLDER in *; do
			if [[ -d "$FOLDER" && "$FOLDER" = asl* || "$FOLDER" = "t1" ]]; then	
				(
					cd ./"$FOLDER"
					for IMG in *; do
						if [ -f "$IMG" ]; then
							#replace any spaces with an underscore
							#add the .dcm extension to the filename
							#move raw file to raw directory
							mv "$IMG" ./"raw/${IMG// /_}.dcm"
						fi
					done
				)
			fi
		done	
	)
	echo "Completed ---- $SUBJECT"
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