#!/usr/bin/env bash

#set up array
declare -a regions=( \
'Subject_ID' \
'Sex' \
'Group' \
'Condition' \
'Time_Point' \
'Global')

printf "%s " "${regions[@]}" > global_header.txt