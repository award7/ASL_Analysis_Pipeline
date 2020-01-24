#!/usr/bin/env bash

SECONDS=0

ANALYSIS="agg roi"

echo "Beginning $ANALYSIS on $(date)" 

#find . -type f -name -printf '%p \n' 'global*.csv' -exec cat {} \; > agg_global.txt

#add subject ID and ASL time point into roi.txt file
{ echo -n "$SUBJECT" "${FOLDER} "; cat *roi.txt; } > tmpfile.txt
mv tmpfile.txt "${i}_${j}_roi.txt"

#insert header into each .txt file
for txt in *roi.txt; do
	cat $header <(echo) $txt > tmpfile.txt
	mv tmpfile.txt $txt
done

#agg .txt files then add header
for txt in *roi.txt; do
	cat $header <(echo) $txt > tmpfile.txt
	mv tmpfile.txt $txt
done

for i in 0197*; do
	(
	cd "$i"
	for j in asl*; do
		{ echo -n "$i" "${j} "; cat "${j}/data/${i}_${j}_roi.txt"; } > "${j}/data/tmpfile.txt"
		mv "${j}/data/tmpfile.txt" "${j}/data/${i}_${j}_roi.txt"
	done
	)
done


for SUBJECT in 0197*; do
	echo "Beginning ---- $SUBJECT"
	(
	cd "$SUBJECT"
	for FOLDER in asl*; do
		(
		echo "Beginning ---- $FOLDER"
		cd "${FOLDER}/data"
		printf "%s\n" "$(<HEADER)" "$(<roi.txt)" > tmpfile.txt
		mv "tmpfile.txt" "roi.txt"
		)
	done
	)
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
