#!/usr/bin/env bash

for SUBJECT in 0197*; do
	(
	cd "$SUBJECT"
	for FOLDER in asl*; do
		SUBJECT_ID="${SUBJECT:0:8}"
		CONDITION="${SUBJECT: -1}"
		LEN=$( expr length "$FOLDER" )
		case "$LEN" in
			10)
				k="${FOLDER:4:1}" ;;
			11)
				k="${FOLDER:4:2}" ;;
			12)
				k="${FOLDER:4:3}" ;;
			*) ;;
		esac
		TIMEPOINT="$LEN"
		read -p "Enter subject's SEX as M or F" SEX
		case "$SEX" in
			m | M | male | Male)
				SEX="M"
			f | F | female | Female)
				SEX="F"
			*) ;;
		esac
		read -p "Enter subject's GROUP as C or M" GROUP
		case "$GROUP" in
			c | C)
				GROUP="C"
			m | M)
				GROUP="M"
			*) ;;
		esac
		#add subject ID, sex, group, condition and ASL time point into .txt file
		{ echo -n "$SUBJECT_ID" "$SEX" "$GROUP" "$CONDITION" "${TIMEPOINT} "; cat "${FOLDER}/data/${SUBJECT}_${FOLDER}_global.txt"; } > "${FOLDER}/data/tmpfile.txt"
		mv tmpfile.txt "${SUBJECT}_${FOLDER}_global.txt"
		{ echo -n "$SUBJECT_ID" "$SEX" "$GROUP" "$CONDITION" "${TIMEPOINT} "; cat "${FOLDER}/data/${SUBJECT}_${FOLDER}_roi.txt"; } > "${FOLDER}/data/tmpfile.txt"
		mv tmpfile.txt "${i}_${j}_roi.txt"
	done
	)
done
