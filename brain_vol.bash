#!/usr/bin/env bash

SECONDS=0
COUNTER=0

analysis="brain_vol"

echo "Beginning $analysis on $(date)" 

for SUBJECT in "$1"*; do #subject ID
	echo "Beginning ---- $SUBJECT"
	(
		cd "${SUBJECT}/t1/proc" #enter into specific directory
		IMG="$(find . -name *.mat)"
		matlab -nodesktop -nosplash -wait -r "brain_vol('$IMG'); exit"
	)
	COUNTER=$((COUNTER+1))
	PROG=$((100*COUNTER/$2))
	echo "Completed ---- ${SUBJECT} ---- ${PROG}%"
done

###################################

if (( $SECONDS > 3600 )) ; then
	let "hours=SECONDS/3600"
	let "minutes=(SECONDS%3600)/60"
	let "seconds=(SECONDS%3600)%60"
	echo "Completed $analysis in $hours hour(s), $minutes minute(s) and $seconds second(s)" 
elif (( $SECONDS > 60 )) ; then
	let "minutes=(SECONDS%3600)/60"
	let "seconds=(SECONDS%3600)%60"
	echo "Completed $analysis in $minutes minute(s) and $seconds second(s)"
else
	echo "Completed $analysis in $SECONDS seconds"
fi