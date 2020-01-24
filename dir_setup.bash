#!/usr/bin/env bash

#creates directory tree for t1 and asl processing pipeline

read -rsp $'Be sure the current working directory is in the listing of subject files. 
Press any key to continue or ctrl+C to exit...\n' -n1 key

#checks that all raw files exist
#if not, list them

find . -type d -empty

read -rsp $'If any directories are empty, press ctrl+C to quit and rectify. 
Otherwise, press any key to continue...\n' -n1 key

#for subject file
for SUBJECT in "${1}"*; do
	#print the subject folder name in the terminal
	echo "Beginning ---- $SUBJECT" 
	(
		cd ./"${SUBJECT}"
		#list all asl folders
		ls -d *contrast* -1 
		#for files in subject dir
		for FOLDER in *; do
			#check if $FOLDER is a directory and its name contains a particular word/phrase
			if [[ -d "$FOLDER" && "$FOLDER" = *contrast** ]]; then 
				#get input from user
				read -p "Enter timepoint for ${FOLDER}:
				0- Baseline
				10- 10 mins
				15- 15 mins
				20- 20 mins
				25- 25 mins
				30- 30 mins
				35- 35 mins
				45- 45 mins
				50- 50 mins
				55- 55 mins
				60- 60 mins
				75- 75 mins
				90- 90 mins
				105- 105 mins
				120- 120 mins
				" TIMEPOINT 
				#create new name of folder
				NEWNAME="asl_${TIMEPOINT}_mins" 
				#change name of folder
				mv "$FOLDER" "$NEWNAME" 
			#check if $FOLDER is a directory and its name contains a particular word/phrase
			elif [[ -d "$FOLDER" && "$FOLDER" = *T1** ]]; then 
				#create new name of folder
				NEWNAME="t1" 
				#change name of folder
				mv "$FOLDER" "$NEWNAME" 
			fi
			(
				#make subshell to cd
				cd ./"$NEWNAME" 	
				#check if subdirectory exists; if not, create it
				if [ ! -d "raw" ]; then 
					mkdir "raw"
				fi
				#check if subdirectory exists; if not, create it
				if [ ! -d "proc" ]; then 
					mkdir "proc"
				fi				
			)
		done
	)
	echo "Completed ---- $SUBJECT"
done