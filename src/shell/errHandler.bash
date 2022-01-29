#!/usr/bin/env bash

### error handler
function error() {
    case "$1" in
        bad_arg)
            runError "Error: Unrecognized argument...";
            usage;
            exit 31;
            ;;
        invalid_coreg_method)
            runError "Error: Invalid coregistration method";
            usage;
            echo;
            exit 43;
            ;;
        44)
            runError "Error: ${2} execution failed (line ${3})";
            echo;
            exit 44;
            ;;
        no_subject)
            runError "Error: No subjects selected";
            usage;
            echo;
            exit 45;
            ;;
        invalid_rename_option)
            runError "Error: Invalid rename option"
            usage;
            echo;
            exit 46;
            ;;
        *)
            runError "Unknown error occured. Exiting...";
            echo;
            exit 99;
            ;;
    esac
}

### highlights red in stdout
function runError() {
    echo; echo "$(tput smso; tput setaf 1)$1$(tput sgr 0)"
}

error "$1"