#!/usr/bin/env bash

#creates a .nii file from the raw .dcm files
#average duration < 1s/file

SECONDS=0

ANALYSIS="dcm import"

echo "Beginning $ANALYSIS on $(date)"

#setup dcm2niix path
#change this as needed
PATH=$PATH:~/Documents/mricrogl

#loop into each subject's raw asl folder
for SUBJECT in "${1}"*; do 
	#give a status update
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}/t1/raw"
		dcm2niix -f "raw_t1" -o ../"proc" "$(pwd)"
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