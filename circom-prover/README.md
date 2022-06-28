# Winterfell Circom prover

This crate is designed to enable the verification of Winterfell STARK proofs using the SNARK prover system [Circom](https://github.com/iden3/circom).

## Lib

The crate library contains the function `proof_to_json` than converts a Winterfell StarkProof to a JSON object, usable as input to Circom.

## Tests

This crate also comes with a `main` test, acting as an example for the library functionalities.

Execute with `cargo test`.
