#!/usr/bin/env bash

#DOESNT WORK

#performs asl roi analysis 

SECONDS=0

ANALYSIS="FSL Stats"

echo "Beginning $ANALYSIS on $(date)" 
read -p "Enter last four digits of study number (i.e. IRB number): " STUDY
ASL_COUNT=$(find ${STUDY}*/asl* -maxdepth 0 -type d | wc -l) #count number of asl folders
COUNTER=0

for SUBJECT in "$STUDY"*; do   #each subject folder
	echo "Beginning ---- $SUBJECT"
		(
			cd "${SUBJECT}"
			AAL_MASK="$(find ./t1/proc/ -name aal_mask.nii)" #find aal mask
			AAL_MASK=$(pwd)/"$AAL_MASK"
			for FOLDER in asl*; do
				(
					cd "${FOLDER}/proc"
					COREG_FMAP="$(find . -name coreg*fmap.nii)"
					
					#How to make sure things are working like you expect them to by creating a single ROI 
					#and making sure it looks good visually and also matches its corresponding output value from above:
					#fslmaths $aalfile -thr 36.5 -uthr 37.5 Hippocampus_L #change to subject's waal.nii img #do for each aal region
					#fsleyes $t1file Hippocampus_L.nii.gz #change first file to subject's T1 
					#fslstats $rASL_fmap -k Hippocampus_L -M #change to subject's rASL_fmap.nii img
					#####
					
					#What you will actually want to run for everyone:
					fslstats  -K "$AAL_MASK" "$COREG_FMAP" -n -M > roi.txt
					mv "roi.txt" ../data
					
					COUNTER=$((COUNTER+1))
					PROG=$((100*COUNTER/ASL_COUNT))
					echo "Completed ---- ${FOLDER} ---- ${PROG}%"

				)
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