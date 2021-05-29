#!/usr/bin/bash

while [[ $# -gt 0 ]]
do
    key = "$1"
    
    case "$key" in 
        -nex)
            NEX="$2"
            shift
            shift
            ;;
        -odata)
            ODATA="$2"
            shift
            shift
            ;;
    esac
done

/3df_pcasl/3df_pcasl -nex "$NEX" -odata "$ODATA"