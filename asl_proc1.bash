#!/usr/bin/env bash

#Set path to scripts first
#change as needed
#PATH=$PATH:~"Box/Data_Analysis_Transforms/asl"

SECONDS=0

ANALYSIS="asl_proc1"

echo "Beginning $ANALYSIS on $(date)"

read -p "Enter last four digits of study number (i.e. IRB number): " STUDY

#sets up directory structure in folders
dir_setup.bash "$STUDY"

#changes the raw image filenames and moves them appropriately
dcm_ext.bash "$STUDY"

#.dcm to .nii conversion
dcm_import.bash "$STUDY"

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