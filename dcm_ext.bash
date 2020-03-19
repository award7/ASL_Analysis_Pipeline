#!/usr/bin/env bash

#adds .dcm extension to raw image files and moves them to associated
#raw directories for proper import and organization during processing

ANALYSIS="dcm extension"

adddate() {
	printf '%s %s: %s completed successfully\n' `date "+%Y-%m-%d %H:%M:%S"` "$1";
}

find . -type f -name '*' -execdir bash -c 'mv -i -- "$1" "${1// /_}.dcm"' Mover {} \;
adddate "${ANALYSIS} Completed"
