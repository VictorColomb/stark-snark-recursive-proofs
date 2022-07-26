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
		--verbose)
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
		-v|--verify)
			VERIFY=1
			shift
			;;
		--clean)
			CLEAN=1
			shift
			;;
		*)
			POSITIONAL+=("$1")
			shift
			;;
	esac
done

set -- "${POSITIONAL[@]}"

TARGET=$1
FINAL=${2:-"final.ptau"}

if [[ ! (COMPILE -eq 1 || WITNESS -eq 1 || PROVE -eq 1 || PRINT -eq 1 || VERIFY -eq 1 || CLEAN -eq 1) ]]
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
	echo "	circuit_name	Name of circuit to prove"
	echo "	phase1_key		Phase 1 final key to use. Optional, default is final.ptau"
	echo
	echo "OPTIONS:"
	echo "	-h|--help		Show this help message and exit"
	echo "	   --verbose	Show verbose output"
	echo "	-w|--witness	Compute witness (done anyway if no witness found)"
	echo "	-c|--compile	Compile circuit (done anyway if no R1CS found)"
	echo "	-p|--prove		Prove the circuit with the provided inputs in stark.json"
	echo "	-e|--echo		Print public inputs and outputs after the proof is completed"
	echo "	-v|--verify		Verify the proof with the provided inputs in stark.json"
	echo "	   --clean		Clean up build files"
	echo
	echo "If the flags -w, -c, -p, -e, -v, --clean are all absent, the complete proving process will be carried out (compilation, witness, proving and printing)."
	exit ${EXIT:-0}
fi

# CHECK FINAL.PTAU
if [[ ! -f "${FINAL}" ]]
then
	echo -e "${RED}[!] phase 1 powers of tau transcript (${FINAL}) not found${NORMAL}"
	exit 1
fi

# GO TO BUILD DIR
[ ! -d target ] && mkdir target
cd target
[ ! -d circom ] && mkdir circom
cd circom
[ ! -d "$TARGET" ] && echo -e "${RED}[!] Circuit ${TARGET} not found${NORMAL}" && exit 1
cd "$TARGET"

# WITNESS AND/OR COMPILE IF FLAGS
if [[ (! (-f witness.wtns && -f "verifier.r1cs")) || WITNESS -eq 1 || COMPILE -eq 1 ]]
then
	# compile
	if [[ COMPILE -eq 1 || ((WITNESS -eq 1 || PROVE -eq 1) && ! (-f "verifier.r1cs" && -d "verifier_cpp")) ]]
	then
		rm -rf "verifier_cpp"
		rm -f "verifier.r1cs"
		if [[ $VERBOSE == "-v" ]]
		then
			VERBOSE_CIRCOM="--verbose"
		fi
		../../../iden3_circom/target/release/circom "verifier.circom" --r1cs --sym --c $VERBOSE_CIRCOM
		[ ! -f verifier.r1cs ] && exit 1
		[ ! -d verifier_cpp ] && exit 1
	fi

	# witness
	if [[ WITNESS -eq 1 || (PROVE -eq 1 && ! -f witness.wtns) || (PROVE -eq 1 && COMPILE -eq 1) ]]
	then
		rm -f witness.wtns
		cd "verifier_cpp"
		make
		cd ..
		"verifier_cpp/verifier" input.json witness.wtns
		[ ! -f witness.wtns ] && exit 1
		[ ! -f "verifier.r1cs" ] && exit 1
	fi
fi

# GENERATE PROOF
if [[ PROVE -eq 1 ]]
then
	# check stark.json
	if [[ ! -f input.json ]]
	then
		echo -e "${RED}[!] input.json not found${NORMAL}"
		exit 1
	fi

	# generate circuit keys
	snarkjs groth16 setup verifier.r1cs ../../../$FINAL verifier_0000.zkey $VERBOSE
	[ ! -f verifier_0000.zkey ] && exit 1
	snarkjs zkey contribute verifier_0000.zkey verifier_0001.zkey -e="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)" $VERBOSE
	[ ! -f verifier_0001.zkey ] && exit 1
	snarkjs zkey export verificationkey verifier_0001.zkey verification_key.json $VERBOSE

	# prove
	snarkjs groth16 prove verifier_0001.zkey witness.wtns proof.json public.json $VERBOSE || exit 1
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

# VERIFY PROOF IF FLAGS
if [[ VERIFY -eq 1 ]]
then
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
fi

# CLEAN UP IF FLAGS
if [[ CLEAN -eq 1 ]]
then
	cd ..
	rm -rf "$TARGET"
fi
