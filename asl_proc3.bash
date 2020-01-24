#!/usr/bin/env bash

#Set path to scripts first
#change as needed
#CHANGE FOR LINUX!!!
PATH=$PATH:~"Box/Data_Analysis_Transforms/asl"

SECONDS=0

ANALYSIS="asl_proc3"

echo "Beginning $ANALYSIS on $(date)"

roi.bash #calculate and output roi asl values

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