use serde_json::json;
use std::fs::File;
use std::io::Write;
use winter_air::Air;
use winter_circom_prover::proof_to_json;
use winter_crypto::hashers::Poseidon;
use winter_math::{fields::f256::BaseElement, FieldElement};
use winter_prover::{FieldExtension, HashFunction, ProofOptions, Prover};

mod prover;
use prover::WorkProver;

mod air;
use air::WorkAir;

#[cfg(test)]
mod tests;

fn main() {
    // PROOF
    // ===========================================================================

    // computation parameters
    let start = BaseElement::ONE;
    let n = 256;

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
    let prover = WorkProver::new(options);
    let trace = prover.build_trace(start, n);
    let public_inputs = prover.get_pub_inputs(&trace);
    let (proof, query_positions) = prover.prove(trace).unwrap();

    // BUILD JSON OUTPUTS
    // ===========================================================================

    // retrieve air and proof options
    let air = WorkAir::new(
        proof.get_trace_info(),
        public_inputs.clone(),
        proof.options().clone(),
    );

    let mut fri_num_queries = Vec::new();
    let mut fri_tree_depths = Vec::new();
    let mut json = proof_to_json::<WorkAir, Poseidon<BaseElement>>(
        proof,
        &air,
        &query_positions,
        public_inputs.clone(),
        &mut fri_num_queries,
        &mut fri_tree_depths,
    );

    json["public_inputs"] = json!([
        public_inputs.start,
        public_inputs.result
    ]);

    // PRINT TO FILE
    // ===========================================================================

    let json_string = format!("{}", json);
    let mut file = File::create("proof.json").unwrap();
    file.write(&json_string.into_bytes()).unwrap();

    // DEBUG INFORMATION
    // ===========================================================================

    println!("trace_length = {}", air.trace_info().length());
    println!("ce_blowup_factor = {}", air.ce_blowup_factor());
    println!("fri_num_queries = {:?}", fri_num_queries);
    println!("fri_tree_depths = {:?}", fri_tree_depths);
}
