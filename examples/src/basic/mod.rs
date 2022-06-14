#[cfg(test)]
mod tests;

mod air;
use air::{PublicInputs, WorkAir};

mod prover;
use prover::WorkProver;

use winterfell::math::fields::f128::BaseElement;

use winterfell::{ProofOptions, Prover};

use winterfell::{FieldExtension, HashFunction, StarkProof};

pub fn generate_proof() -> (BaseElement, StarkProof) {
    // We'll just hard-code the parameters here for this example.
    let start = BaseElement::new(1);
    let n = 2048;

    // Define proof options; these will be enough for ~96-bit security level.
    let options = ProofOptions::new(
        32, // number of queries
        8,  // blowup factor
        0,  // grinding factor
        HashFunction::Poseidon,
        FieldExtension::None,
        8,   // FRI folding factor
        128, // FRI max remainder length
    );

    // Instantiate the prover and generate the proof.
    let prover = WorkProver::new(options);

    // Build the execution trace and get the result from the last step.
    let trace = prover.build_trace(start, n);
    let result = trace.get(1, n - 1);
    let proof = prover.prove(trace);

    (result, proof.unwrap())
}

pub fn verify_proof(start: BaseElement, result: BaseElement, proof: &StarkProof) {
    // The number of steps and options are encoded in the proof itself, so we
    // don't need to pass them explicitly to the verifier.
    let pub_inputs = PublicInputs { start, result };
    match winterfell::verify::<WorkAir>(proof.clone(), pub_inputs) {
        Ok(_) => assert_eq!(1,1),
        Err(e) => {
            println!("{}", e);
            panic!("something went terribly wrong!");
        }
    }
}
