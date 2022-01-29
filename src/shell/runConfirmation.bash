#!/usr/bin/env bash

### highlights green in stdout
function runConfirmation() {
    echo "$(tput smso; tput setaf 2)$1$(tput sgr 0)"; echo
}

runConfirmation "$1"