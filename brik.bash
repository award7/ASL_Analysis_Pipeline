#!/usr/bin/env bash

#makes HEAD and BRIK files in AFNI

SECONDS=0

ANALYSIS="brik"

echo "Beginning $ANALYSIS on $(date)"

read -p "Enter last four digits of study number (i.e. IRB number): " STUDY
ASL_COUNT=$(find ${STUDY}*/asl* -maxdepth 0 -type d | wc -l) #count number of asl folders
COUNTER=0

#loop into each subject's raw asl folder
for SUBJECT in "$STUDY"*; do 
	#give a status update
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}"
		for FOLDER in *; do
			if [[ -d "$FOLDER" && "$FOLDER" = asl* ]]; then
			(
				cd "${FOLDER}/raw"
				#transform raw asl images into AFNI 4D format
				#produces a .HEAD and .BRIK file
				#set prefix to a filename that will be appended by "+orig.BRIK"
				to3d -prefix "${SUBJECT}_${FOLDER}" -fse -time:zt 40 2 1000 seq+z *.dcm

				#Generate quantitative CBF images
				#make fmap .BRIK and .HEAD files
				#filename should be the same prefix used in the to3d command
				#will be appended by "_fmap+orig.BRIK"
				3df_pcasl -nex 3 -odata "${SUBJECT}_${FOLDER}"

				#Write out the ASL CBF image in .nii format
				#make a fmap
				#filename should be the output from the 3df_pcasl command
				3dcalc -a "${SUBJECT}_${FOLDER}_fmap+orig.[0]" -datum float -expr 'a' -prefix "${SUBJECT}_${FOLDER}_fmap.nii"

				#Write out the ASL CBF image in .nii format
				#make a proton density map
				#filename should be the output from the 3df_pcasl command
				3dcalc -a "${SUBJECT}_${FOLDER}_fmap+orig.[1]" -datum float -expr 'a' -prefix "${SUBJECT}_${FOLDER}_PDmap.nii"
				
				#move created files into proc folder
				mv *.nii ../"proc"
			)
			fi
		COUNTER=$((COUNTER+1))
		PROG=$((100*COUNTER/ASL_COUNT))
		echo "Completed ---- ${FOLDER} ---- ${PROG}%"
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