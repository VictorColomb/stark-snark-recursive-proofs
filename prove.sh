#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[33m'
NORMAL='\033[0m'

# PARSE ARGUMENTS
POSITIONAL=()

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
		-w|--witness)
			WITNESS=1
			shift
			;;
		-c|--compile)
			COMPILE=1
			shift
			;;
		-p|--prove)
			PROVE=1
			shift
			;;
		-e|--echo)
			PRINT=1
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
FINAL=${2:-"final.ptau"}

if [[ ! (COMPILE -eq 1 || WITNESS -eq 1 || PROVE -eq 1 || PRINT -eq 1) ]]
then
	COMPILE=1
	WITNESS=1
	PROVE=1
	PRINT=1
fi

# HELP MESSAGE
if [[ $# -lt 1 || $HELP -eq 1 ]]
then
	if [[ $HELP -ne 1 && $# -lt 1 ]]
	then
		echo -e "${RED}[!] Missing circuit_name required argument!${NORMAL}"
		EXIT=1
	fi
	echo -e "${YELLOW}Usage: $0 [-h] [-v] [-w] [-c] [-p] <circuit_name> [phase1_key]${NORMAL}"
	echo
	echo "ARGUMENTS:"
	echo "	circuit_name	Name of circuit to prove (.circom extension optional)"
	echo "	phase1_key		Phase 1 final key to use. Optional, default is final.ptau"
	echo
	echo "OPTIONS:"
	echo "	-h|--help		Show this help message and exit"
	echo "	-v|--verbose	Show verbose output"
	echo "	-w|--witness	Compute witness (done anyway if no witness found)"
	echo "	-c|--compile	Compile circuit (done anyway if no R1CS found)"
	echo "	-p|--prove		Prove the circuit with the provided inputs in input.json"
	echo "	-e|--echo		Print public inputs and outputs after the proof is completed"
	echo
	echo "If the flags -w, -c, -p and -e are all absent, the complete process will be carried out (compilation, witness, proving and printing)."
	exit ${EXIT:-0}
fi

# CHECK FINAL.PTAU
if [[ ! -f "${FINAL}" ]]
then
	echo -e "${RED}[!] phase 1 powers of tau transcript (${FINAL}) not found${NORMAL}"
	exit 1
fi

# GO TO BUILD DIR
[ ! -d build ] && mkdir build
cd build
[ ! -d "$TARGET" ] && mkdir "$TARGET"
cd "$TARGET"

# WITNESS AND/OR COMPILE IF FLAGS
if [[ (! (-f witness.wtns && -f "${TARGET}.r1cs")) || WITNESS -eq 1 || COMPILE -eq 1 ]]
then
	# compile
	if [[ COMPILE -eq 1 || ((WITNESS -eq 1 || PROVE -eq 1) && ! (-f "${TARGET}.r1cs" && -d "${TARGET}_cpp")) ]]
	then
		rm -rf "${TARGET}_cpp"
		rm -f "${TARGET}.r1cs"
		if [[ $VERBOSE == "-v" ]]
		then
			VERBOSE_CIRCOM="--verbose"
		fi
		circom "../../${TARGET_INPUT}.circom" --r1cs --sym --c $VERBOSE_CIRCOM
		[ ! -f ${TARGET}.r1cs ] && exit 1
		[ ! -d ${TARGET}_cpp ] && exit 1
	fi

	# witness
	if [[ WITNESS -eq 1 || (PROVE -eq 1 && ! -f witness.wtns) || (PROVE -eq 1 && COMPILE -eq 1) ]]
	then
		rm -f witness.wtns
		cd "${TARGET}_cpp"
		make
		cd ..
		"${TARGET}_cpp/${TARGET}" ../../input.json witness.wtns
		[ ! -f witness.wtns ] && exit 1
		[ ! -f "${TARGET}.r1cs" ] && exit 1
	fi
fi

# GENERATE PROOF
if [[ PROVE -eq 1 ]]
then
	# check input.json
	if [[ ! -f ../../input.json ]]
	then
		echo -e "${RED}[!] input.json not found${NORMAL}"
		exit 1
	fi

	# generate circuit keys
	snarkjs groth16 setup ${TARGET}.r1cs ../../$FINAL ${TARGET}_0000.zkey $VERBOSE
	[ ! -f ${TARGET}_0000.zkey ] && exit 1
	snarkjs zkey contribute ${TARGET}_0000.zkey ${TARGET}_0001.zkey -e="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)" $VERBOSE
	[ ! -f ${TARGET}_0001.zkey ] && exit 1
	snarkjs zkey export verificationkey ${TARGET}_0001.zkey verification_key.json $VERBOSE

	# prove
	snarkjs groth16 prove ${TARGET}_0001.zkey witness.wtns proof.json public.json $VERBOSE || exit 1
	[ ! -f proof.json ] && exit 1
	[ ! -f public.json ] && exit 1
fi

# PRINT PUBLIC IF FLAGS
if [[ PRINT -eq 1 ]]
then
	if [[ ! -f public.json ]]
	then
		echo -e "${RED}[!] public.json not found, cannot echo!${NORMAL}"
		exit 1
	fi
	echo
	cat public.json
	echo
	echo
fi
