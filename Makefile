T=poseidon

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


### compute parameters
parameters.circom: compute_parameters.sage
	sage compute_parameters.sage 1 0 254 3 8 57 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001 parameters.circom
	rm -f compute_parameters.sage.py


### circom compile

$T_cpp: $T.circom parameters.circom
	circom $< --c --r1cs --sym

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
