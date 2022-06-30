#!/bin/bash

RED='\033[0;31m'

if [[ $# -lt 1 ]]
then
    echo -e "${RED}Usage: $0 <circuit_name (omit the extension)>"
    exit 1
fi

TARGET=$1

rm -f ${TARGET}{.r1cs,.sym} public.json proof.json witness.wtns verification_key.json
rm -rf ${TARGET}_cpp
find -type f -name '*.zkey' -delete
