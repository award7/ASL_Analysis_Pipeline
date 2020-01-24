#!/usr/bin/env bash

#Set path to scripts first
#change as needed
#PATH=$PATH:~"Box/Data_Analysis_Transforms/asl"

SECONDS=0

ANALYSIS="asl_proc2"

echo "Beginning $ANALYSIS on $(date)"

read -p "Enter last four digits of study number (i.e. IRB number): " STUDY

SUBJECT_COUNT=$(find ${STUDY}* -maxdepth 0 -type d | wc -l) #count number of subject folders
ASL_COUNT=$(find ${STUDY}*/asl* -maxdepth 0 -type d | wc -l) #count number of asl folders

#segment t1 image
segment.bash "$STUDY" "$SUBJECT_COUNT"

#smooth gm image
smooth.bash "$STUDY" "$SUBJECT_COUNT"

#coregister images
coreg.bash "$STUDY" "$ASL_COUNT"

#normalise and smooth images
normalise.bash "$STUDY" "$ASL_COUNT"

#pushforward deformation
pushfwd.bash "$STUDY" "$SUBJECT_COUNT"

#bmasking of image
bmask.bash "$STUDY" "$ASL_COUNT"

#calculate and output global asl value
asl_global.bash "$STUDY" "$ASL_COUNT"

#Note to self: python script to agg asl global values
#call python script that will group all the mean global
#asl values into a master
#python script.py

#get brain volumes
brain_vol.bash "$STUDY" "$SUBJECT_COUNT"

#inverse warp MNI --> subject space for ROI analysis
invwarp.bash "$STUDY" "$SUBJECT_COUNT"

#create aal mask
aal_mask.bash "$STUDY" "$SUBJECT_COUNT"

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