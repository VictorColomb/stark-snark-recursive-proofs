use std::{
    fs::{canonicalize, create_dir_all, File},
    io::Write,
    process::Command,
};

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
pub fn circom_verification<P>(prover: P, trace: <P as Prover>::Trace, circuit_name: &str)
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
    create_dir_all(format!("target/circom/{}", circuit_name)).unwrap();
    let mut file = File::create(format!("target/circom/{}/input.json", circuit_name)).unwrap();
    file.write(&json_string.into_bytes()).unwrap();

    // CIRCOM MAIN
    // ===========================================================================

    generate_circom_main::<P::BaseField, P::Air>(
        circuit_name,
        &air,
        &fri_num_queries,
        &fri_tree_depths,
        json["pub_coin_seed"].as_array().unwrap().len(),
    )
    .unwrap();

    // compile circom and generate witness
    assert!(
        Command::new(canonicalize("iden3_circom/target/release/circom").unwrap())
            .arg("--r1cs")
            .arg("--c")
            .arg("verifier.circom")
            .current_dir(format!("target/circom/{}", circuit_name))
            .status()
            .unwrap()
            .success()
    );

    assert!(Command::new("make")
        .current_dir(format!("target/circom/{}/verifier_cpp", circuit_name))
        .status()
        .unwrap()
        .success());

    assert!(Command::new(
        canonicalize(format!("target/circom/{}/verifier_cpp/verifier", circuit_name)).unwrap()
    )
    .arg("input.json")
    .arg("witness.wtns")
    .current_dir(format!("target/circom/{}", circuit_name))
    .status()
    .unwrap()
    .success());

    // generate circuit key
    assert!(Command::new("snarkjs")
        .arg("g16s")
        .arg("verifier.r1cs")
        .arg("../../../final.ptau")
        .arg("verifier_0000.zkey")
        .current_dir(format!("target/circom/{}", circuit_name))
        .status()
        .unwrap()
        .success());

    // TODO: make it work for Windows as well
    assert!(Command::new("snarkjs")
        .arg("zkc")
        .arg("verifier_0000.zkey")
        .arg("verifier_0001.zkey")
        .arg("$(head/dev/urandom | tr -dc a-zA-Z0-9 | head -c 25)")
        .current_dir(format!("target/circom/{}", circuit_name))
        .status()
        .unwrap()
        .success());

    assert!(Command::new("snarkjs")
        .arg("zkev")
        .arg("verifier_0001.zkey")
        .arg("verification_key.json")
        .current_dir(format!("target/circom/{}", circuit_name))
        .status()
        .unwrap()
        .success());

    // generate snark proof
    assert!(Command::new("snarkjs")
        .arg("g16p")
        .arg("verifier_0001.zkey")
        .arg("witness.wtns")
        .arg("proof.json")
        .arg("public.json")
        .current_dir(format!("target/circom/{}", circuit_name))
        .status()
        .unwrap()
        .success());

    println!("\x1b[32m{}\x1b[0m", "Proof generated successfully!");
    println!("Proof file:        {}", canonicalize(format!("target/circom/{}/proof.json", circuit_name)).unwrap().to_string_lossy());
    println!("Verification key:  {}", canonicalize(format!("target/circom/{}/verification_key.json", circuit_name)).unwrap().to_string_lossy());
    println!("Public in/outputs: {}", canonicalize(format!("target/circom/{}/public.json", circuit_name)).unwrap().to_string_lossy());
}
