#!/bin/bash

RED='\033[0;31m'

if [[ $# -lt 1 ]]; then
    echo -e "${RED}[!] Usage: $0 <circuit_name (omit the extension)> [phase1_key: final.ptau]"
    exit 1
fi

TARGET=$1
FINAL=${2:-"final.ptau"}

if [[ ! -f "input.json" ]]
then
    echo -e "${RED}[!] input.json not found"
    exit 1
fi
if [[ ! -f "${FINAL}" ]]
then
    echo -e "${RED}[!] phase 1 powers of tau transcript (${FINAL}) not found"
    exit 1
fi

if [[ ! (-f "witness.wtns" && -f "${TARGET.r1cs}") ]]
then
    ./compile.sh ${TARGET} || exit 1
fi

# generate circuit keys
snarkjs groth16 setup ${FINAL} ${TARGET}_0000.zkey
snarkjs zkey contribute ${TARGET}_0000.zkey ${TARGET}_0001.zkey
snarkjs zkey export verificationkey ${TARGET}_0001.zkey verification_key.json

# prove
snarkjs groth16 prove ${TARGET}_0001.zkey witness.wtns proof.json public.json ||exit 1

# echo
echo && cat public.json && echo && echo
