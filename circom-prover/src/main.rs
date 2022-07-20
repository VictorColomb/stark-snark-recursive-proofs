use std::fs::File;
use std::io::Write;
use winter_air::Air;
use winter_circom_prover::{generate_circom_main, proof_to_json};
use winter_crypto::hashers::Poseidon;
use winter_math::{fields::f256::BaseElement, FieldElement};
use winter_prover::{FieldExtension, HashFunction, ProofOptions, Prover};
use winter_verifier::verify;

mod prover;
use prover::WorkProver;

mod air;
use air::WorkAir;

fn main() {
    // BUILD PROOF
    // ===========================================================================

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
    let pub_inputs = prover.get_pub_inputs(&trace);
    let proof = prover.prove(trace).unwrap();

    // Serialize the proof into a "proof" file
    let mut file = File::create("proof").unwrap();
    file.write(&proof.to_bytes()).unwrap();

    // VERIFY PROOF
    // ===========================================================================

    assert!(
        verify::<WorkAir>(proof.clone(), pub_inputs.clone()).is_ok(),
        "invalid proof"
    );

    // BUILD JSON OUTPUTS
    // ===========================================================================

    // retrieve air and proof options
    let air = WorkAir::new(
        proof.get_trace_info(),
        pub_inputs.clone(),
        proof.options().clone(),
    );

    // convert proof to json object
    let mut fri_num_queries = Vec::new();
    let mut fri_tree_depths = Vec::new();
    let json = proof_to_json::<WorkAir, Poseidon<BaseElement>>(
        proof.clone(),
        &air,
        pub_inputs.clone(),
        &mut fri_num_queries,
        &mut fri_tree_depths,
    );

    // print json to file
    let json_string = format!("{}", json);
    let mut file = File::create("proof.json").unwrap();
    file.write(&json_string.into_bytes()).unwrap();

    // CIRCOM MAIN
    // ===========================================================================

    generate_circom_main::<BaseElement, WorkAir>(
        "verifier_main.circom",
        &air,
        &fri_num_queries,
        &fri_tree_depths,
        json["pub_coin_seed"].as_array().unwrap().len(),
    ).unwrap();
}
