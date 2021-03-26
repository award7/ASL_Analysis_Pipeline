#!/bin/bash

runDocker() {
    docker run -t -d \
    -v "$1":"$2" \
    -w="$2" \
    --name "dcm2niix_container" \
    dcm2niix_img \
    /bin/bash
}

# make container
runDocker

# get basename of subject folder


# run bash commands in the container
docker exec "dcm2niix_container" dcm2niix -f "$fname" "$target"
