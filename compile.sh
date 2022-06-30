#!/bin/bash

RED='\033[0;31m'

if [[ $# -lt 1 ]]
then
    echo -e "${RED}[!] Usage: $0 <circuit_name (omit the extension)>"
    exit 1
fi
TARGET=$1

# compile circom
rm -rf ${TARGET}_cpp
rm -f ${TARGET}.r1cs
circom ${TARGET}.circom --r1cs --sym --c
[ ! -f ${TARGET}.r1cs ] && exit 1
[ ! -d ${TARGET}_cpp ] && exit 1

# generate witness
rm -f witness.wtns
cd ${TARGET}_cpp
make
cd ..
${TARGET}_cpp/${TARGET} input.json witness.wtns
[ ! -f witness.wtns ] && exit 1
