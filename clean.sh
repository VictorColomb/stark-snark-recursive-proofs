#!/bin/bash

RED='\033[31m'
NORMAL='\033[0m'

if [[ $# -lt 1 ]]
then
    echo -e "${RED}Usage: $0 <circuit_name>"
    exit 1
fi

if [[ $1 == "*.circom" ]]
then
	TARGET_INPUT=${1::-7}
else
	TARGET_INPUT=$1
fi
TARGET=${TARGET_INPUT##*/}

# GO TO BUILD DIR
[ ! -d build ] && echo "${RED} build directory not found!${NORMAL}"
cd build

# DELETE DIRECTORY
rm -rf $TARGET
