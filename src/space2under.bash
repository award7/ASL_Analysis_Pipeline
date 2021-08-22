#!/usr/bin/env bash

# input: string
# output: string

### remove spaces
function space2under() {
    local new_str="${1// /_}"
    eval "$2='$new_str'"
}

res=''
space2under "a b c" res
echo "$res"