#!/bin/bash

RED='\033[0;31m'

if [[ -e "verification_key" ]]; then
    if [[ -e "public.json" ]]; then
        if [[ -e "proof.json" ]]; then
            snarkjs groth16 verify verification_key.json proof.json public.json
        else
            echo -e "${RED}[!] proof.json not found"
        fi
    else
        echo -e "${RED}[!] public.json not found"
    fi
else
    echo -e "${RED}[!] verification_key not found"
fi
