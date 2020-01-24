#!/usr/bin/env bash

counter=0	
for i in {0..9}; do
	counter=$((counter+1))
	prog=$((100*counter/$2))
	echo "${prog}%"
done