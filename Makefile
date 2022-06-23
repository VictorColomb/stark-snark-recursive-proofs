T=poseidon
bls12-381 := 52435875175126190479447740508185965837690552500527637822603658699938581184513
bn-128 := 21888242871839275222246405745257275088548364400416034343698204186575808495617
dbg_p := 18446744073709551359



.PHONY: all clean verify sym parameters

all: cat verification_key.json

clean:
	rm -rf $T_cpp
	rm -f $T.r1cs
	rm -f $T.sym
	rm -f public.json
	rm -f proof.json
	rm -f witness.wtns
	rm -f verification_key.json
	find -type f -name '*.zkey' -delete

sym: $T.sym



### circom compile
compile: $T_cpp

$T_cpp: $T.circom
	circom -p bls12381 $< --c --r1cs --sym

$T.sym: $T_cpp

$T.r1cs: $T_cpp

witness.wtns: input.json $T_cpp
	cd $T_cpp && make
	$T_cpp/$T $< $@


### powersoftau generic ceremony

pot12_0000.ptau:
	snarkjs powersoftau new bls12-381 12 $@

pot12_0001.ptau: pot12_0000.ptau
	snarkjs powersoftau contribute $< $@

pot12_final.ptau: pot12_0001.ptau
	snarkjs powersoftau prepare phase2 $< $@


### zkey, verifkey and proof generation

$T_0000.zkey: $T.r1cs pot12_final.ptau
	snarkjs groth16 setup $^ $@

$T_0001.zkey: $T_0000.zkey
	snarkjs zkey contribute $< $@

verification_key.json: $T_0001.zkey
	snarkjs zkey export verificationkey $< $@

proof.json: witness.wtns $T_0001.zkey
	snarkjs groth16 prove $T_0001.zkey witness.wtns proof.json public.json

public.json: proof.json

cat: public.json
	echo && cat public.json && echo && echo

verify: verification_key.json public.json proof.json
	snarkjs groth16 verify $^

bn_constants:
	python3 generate_parameters_grain.sage.py 1 0 254 5 8 60 ${bn-128} > param.circom

bls_constants:
	python3 generate_parameters_grain.sage.py 1 0 255 5 8 60 ${bls12-381} > param.circom

dbg:
	python3 generate_parameters_grain.sage.py 1 0 64 24 8 42 ${dbg_p} > dbg_param.circom