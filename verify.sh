#!/bin/bash

RED='\033[31m'
YELLOW='\033[33m'
NORMAL='\033[0m'

POSITIONAL=()

# PARSE ARGUMENTS
while [[ $# -gt 0 ]]
do
	case $1 in
		-h|--help)
			HELP=1
			shift
			;;
		-v|--verbose)
			VERBOSE="-v"
			shift
			;;
		*)
			POSITIONAL+=("$1")
			shift
			;;
	esac
done

set -- "${POSITIONAL[@]}"

if [[ $1 == "*.circom" ]]
then
	TARGET_INPUT=${1::-7}
else
	TARGET_INPUT=$1
fi
TARGET=${TARGET_INPUT##*/}

# HELP MESSAGE
if [[ HELP -eq 1 || $# -lt 1 ]]
then
	if [[ HELP -ne 1 && $# -lt 1 ]]
	then
		echo -e "${RED}[!] Missing circuit_name required argument!${NORMAL}"
		EXIT=1
	fi
	echo "${YELLOW}Usage: $0 [-h] [-v] <circuit_name>${NORMAL}"
	echo
	echo "ARGUMENTS:"
	echo "	circuit_name	Name of circuit to prove (.circom extension optional)"
	echo
	echo "OPTIONS:"
	echo "	-h|--help		Show this help message and exit"
	echo "	-v|--verbose	Show verbose output"
	exit ${EXIT:-0}
fi

# GO TO BUILD DIR
[ ! -d build ] && echo -e "${RED}[!] build directory not found!" && exit 1
cd build
[ ! -d $TARGET ] && echo -e "${RED}[!]build/$TARGET directory not found!" && exit 1
cd $TARGET

# VERIFY PROOF
if [[ -e "verification_key.json" ]]; then
	if [[ -e "public.json" ]]; then
		if [[ -e "proof.json" ]]; then
			snarkjs groth16 verify verification_key.json public.json proof.json $VERBOSE
		else
			echo -e "${RED}[!] proof.json not found${NORMAL}"
		fi
	else
		echo -e "${RED}[!] public.json not found${NORMAL}"
	fi
else
	echo -e "${RED}[!] verification_key not found${NORMAL}"
fi
