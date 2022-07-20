use std::{fs::File, io::Write};

use serde::Serialize;
use winter_air::{Air, HashFunction};
use winter_crypto::hashers::Poseidon;
use winter_math::fields::f256::BaseElement;
use winter_prover::Prover;

mod json;
use json::proof_to_json;

mod circom_main;
use circom_main::generate_circom_main;

/// Trait for compatibility between implementations of [winter_air::Air::PublicInputs]
/// and the [prepare_circom_verification] function.
pub trait WinterPublicInputs: Serialize + Clone {
    const NUM_PUB_INPUTS: usize;
}

/// Prepare verification of a Winterfell proof by a Circom circuit.
///
/// - Generate the proof
/// - (Not in release mode) Verify the proof
/// - Parse the proof into a Circom-compatible JSON object
/// - Print the JSON proof to a file
/// - Generate Circom code containing the parameters of the verification
pub fn prepare_circom_verification<P>(prover: P, trace: <P as Prover>::Trace, circom_filename: &str)
where
    P: Prover<BaseField = BaseElement>,
    <<P as Prover>::Air as Air>::PublicInputs: WinterPublicInputs,
{
    // BUILD PROOF
    // ===========================================================================

    assert_eq!(prover.options().hash_fn(), HashFunction::Poseidon);

    let pub_inputs = prover.get_pub_inputs(&trace);
    let proof = prover.prove(trace).unwrap();

    // VERIFY PROOF
    // ===========================================================================

    #[cfg(debug_assertions)]
    assert!(
        winter_verifier::verify::<P::Air>(proof.clone(), pub_inputs.clone()).is_ok(),
        "invalid proof"
    );

    // BUILD JSON OUTPUTS
    // ===========================================================================

    // retrieve air and proof options
    let air = P::Air::new(
        proof.get_trace_info(),
        pub_inputs.clone(),
        proof.options().clone(),
    );

    // convert proof to json object
    let mut fri_num_queries = Vec::new();
    let mut fri_tree_depths = Vec::new();
    let json = proof_to_json::<P::Air, Poseidon<BaseElement>>(
        proof,
        &air,
        pub_inputs.clone(),
        &mut fri_num_queries,
        &mut fri_tree_depths,
    );

    // print json to file
    let json_string = format!("{}", json);
    let mut file = File::create("stark.json").unwrap();
    file.write(&json_string.into_bytes()).unwrap();

    // CIRCOM MAIN
    // ===========================================================================

    generate_circom_main::<P::BaseField, P::Air>(
        circom_filename,
        &air,
        &fri_num_queries,
        &fri_tree_depths,
        json["pub_coin_seed"].as_array().unwrap().len(),
    )
    .unwrap();
}
