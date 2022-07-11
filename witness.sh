#!/bin/bash

RED='\033[0;31m'
if [[ $# -lt 1 ]]
then
    echo -e "${RED}[!] Usage: $0 <circuit_name (omit the extension)>"
    exit 1
fi
TARGET=$1


# generate witness
rm -f witness.wtns
cd ${TARGET}_cpp
make
cd ..
${TARGET}_cpp/${TARGET} input.json witness.wtns