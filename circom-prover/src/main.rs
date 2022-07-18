use serde_json::json;
use std::fs::File;
use std::io::Write;
use winter_air::Air;
use winter_circom_prover::{number_of_draws, proof_to_json, WorkAir, WorkProver};
use winter_crypto::hashers::Poseidon;
use winter_math::fields::f256;
use winter_math::{fields::f256::BaseElement, FieldElement};
use winter_math::{log2, StarkField};
use winter_prover::{FieldExtension, HashFunction, ProofOptions, Prover};
use winter_verifier::verify;

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
    let prover = WorkProver::new(options.clone());
    let trace = prover.build_trace(start, n);
    let pub_inputs = prover.get_pub_inputs(&trace);
    let (proof, query_positions) = prover.prove(trace).unwrap();

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

    let mut fri_num_queries = Vec::new();
    let mut fri_tree_depths = Vec::new();
    let mut json = proof_to_json::<WorkAir, Poseidon<BaseElement>>(
        proof.clone(),
        &air,
        &query_positions,
        pub_inputs.clone(),
        &mut fri_num_queries,
        &mut fri_tree_depths,
    );

    json["public_inputs"] = json!([pub_inputs.start, pub_inputs.result]);

    // PRINT TO FILE
    // ===========================================================================

    let json_string = format!("{}", json);
    let mut file = File::create("proof.json").unwrap();
    file.write(&json_string.into_bytes()).unwrap();

    // CIRCOM MAIN
    // ===========================================================================

    let mut file = File::create("verifier_main.circom").unwrap();

    file.write("pragma circom 2.0.4;\n\n".as_bytes()).unwrap();
    file.write("include \"circom/verify.circom\";\n".as_bytes())
        .unwrap();
    file.write("component main = Verify(\n".as_bytes()).unwrap();
    file.write(
        format!(
            "    {}, // addicity\n    {}, // ce_blowup_factor\n    {}, // domain_offset\n    {}, // folding_factor\n    {}, // grinding_factor\n    {}, // lde_blowup_factor\n    {}, // num_assertions\n    {}, // num_draws\n    {}, // num_fri_layers\n    {}, // num_pub_coin_seed\n    {}, // num_public_inputs\n    {}, // num_queries\n    {}, // num_transition_constraints\n    {}, // trace_length\n    {},  // trace_length\n    {}, // tree_depth\n);",
            f256::BaseElement::TWO_ADICITY,
            air.ce_blowup_factor(),
            air.domain_offset(),
            air.options().to_fri_options().folding_factor(),
            air.options().grinding_factor(),
            air.options().blowup_factor(),
            air.context().num_assertions(),
            number_of_draws(options.num_queries() as u128, air.lde_domain_size() as u128,128),
            air.options().to_fri_options().num_fri_layers(proof.lde_domain_size()),
            json["pub_coin_seed"].as_array().unwrap().len(),
            WorkProver::NUM_PUB_INPUTS,
            air.options().num_queries(),
            air.context().num_transition_constraints(),
            air.trace_length(),
            air.trace_info().width(),
            log2(proof.lde_domain_size()),
        )
        .as_bytes(),
    )
    .unwrap();
}
