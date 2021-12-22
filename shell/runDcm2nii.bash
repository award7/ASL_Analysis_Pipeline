#!/usr/bin/env bash

# .dcm to .nii conversion

# input args
# 1 = output directory
# 2 = input directory

dcm2niix -f "t1_%n" -o "$1" "$2"

# echo filename for xcom
shopt -s globstar nullglob
arr=("${1}/t1"*".nii")
len="${#arr[@]}"
if [[ $len -gt 1 ]]; then
  if [[ "${#arr[0]}" -lt "${#arr[1]}" ]]; then
    file="${arr[0]}"
  else
    file="${arr[1]}"
  fi
  else
    file="${arr[0]}"
fi

if [[ -f "${file}" ]]; then
  echo "${file}"
fi