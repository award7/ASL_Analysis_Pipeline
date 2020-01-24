#!/usr/bin/env bash

#unzips image files to for processing

find . -type f -name "*.gz" -exec gunzip {} \;