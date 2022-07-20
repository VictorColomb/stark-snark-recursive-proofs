use winter_circom_prover::prepare_circom_verification;
use winter_math::{fields::f256::BaseElement, FieldElement};
use winter_prover::{FieldExtension, HashFunction, ProofOptions};

mod air;

mod prover;
use prover::WorkProver;

fn main() {
    // computation parameters
    let start = BaseElement::ONE;
    let trace_length = 256;

    // Define proof options; these will be enough for ~96-bit security level.
    let options = ProofOptions::new(
        32, // number of queries
        8,  // lde blowup factor
        0,  // grinding factor
        HashFunction::Poseidon,
        FieldExtension::None,
        8,   // FRI folding factor
        128, // FRI max remainder length
    );

    // build proof
    let prover = WorkProver::new(options.clone());
    let trace = prover.build_trace(start, trace_length);

    prepare_circom_verification(prover, trace, "sum");
}
