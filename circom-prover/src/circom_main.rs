use std::{
    collections::HashMap,
    fs::File,
    io::{Error, Write},
};

use rug::{ops::Pow, Float};
use winter_air::Air;
use winter_math::{log2, StarkField};

use crate::WinterPublicInputs;

/**
 * Generate a circom main file that defines the parameters for verifying a proof.
 */
pub fn generate_circom_main<E, AIR>(
    circuit_name: &str,
    air: &AIR,
    fri_num_queries: &Vec<usize>,
    fri_tree_depths: &Vec<usize>,
    pub_coin_seed_len: usize,
) -> Result<(), Error>
where
    E: StarkField,
    AIR: Air,
    AIR::PublicInputs: WinterPublicInputs,
{
    let fri_num_queries = format!(
        "[{}]",
        fri_num_queries
            .iter()
            .map(|x| format!("{}", x))
            .collect::<Vec<_>>()
            .join(", ")
    );
    let fri_tree_depths = format!(
        "[{}]",
        fri_tree_depths
            .iter()
            .map(|x| format!("{}", x))
            .collect::<Vec<_>>()
            .join(", ")
    );

    let mut file = File::create(format!("target/circom/{}/verifier.circom", circuit_name))?;

    file.write("pragma circom 2.0.0;\n\n".as_bytes())?;
    file.write("include \"../../../circuits/verify.circom\";\n".as_bytes())?;
    file.write(format!("include \"../../../circuits/air/{}.circom\";\n\n", circuit_name).as_bytes())?;
    file.write("component main {public [ood_frame_constraint_evaluation, ood_trace_frame]}= Verify(\n".as_bytes())?;
    file.write(
        format!(
            "    {}, // addicity\n    {}, // ce_blowup_factor\n    {}, // domain_offset\n    {}, // folding_factor\n    {}, // fri_num_queries\n    {}, // fri_tree_depth\n    {}, // grinding_factor\n    {}, // lde_blowup_factor\n    {}, // num_assertions\n    {}, // num_draws\n    {}, // num_fri_layers\n    {}, // num_pub_coin_seed\n    {}, // num_public_inputs\n    {}, // num_queries\n    {}, // num_transition_constraints\n    {}, // trace_length\n    {},  // trace_length\n    {} // tree_depth\n);\n",
            E::TWO_ADICITY,
            air.ce_blowup_factor(),
            air.domain_offset(),
            air.options().to_fri_options().folding_factor(),
            fri_num_queries,
            fri_tree_depths,
            air.options().grinding_factor(),
            air.options().blowup_factor(),
            air.context().num_assertions(),
            number_of_draws(air.options().num_queries() as u128, air.lde_domain_size() as u128,128),
            air.options().to_fri_options().num_fri_layers(air.lde_domain_size()),
            pub_coin_seed_len,
            AIR::PublicInputs::NUM_PUB_INPUTS,
            air.options().num_queries(),
            air.context().num_transition_constraints(),
            air.trace_length(),
            air.trace_info().width(),
            log2(air.lde_domain_size()),
        )
        .as_bytes(),
    )?;

    Ok(())
}

// HELPER FUNCTIONS
// ===========================================================================

fn number_of_draws(num_queries: u128, lde_domain_size: u128, security: i32) -> u128 {
    let mut num_draws: u128 = 0;
    let precision: u32 = security as u32 + 2;

    while {
        let st = step(
            0,
            num_draws,
            &mut HashMap::new(),
            num_queries,
            lde_domain_size,
            security,
        );
        num_draws += 1;
        1 - st > Float::with_val(precision, 2_f64).pow(-security)
    } {}

    num_draws
}

fn step(
    x: u128,
    n: u128,
    memo: &mut HashMap<(u128, u128), Float>,
    num_queries: u128,
    lde_domain_size: u128,
    security: i32,
) -> Float {
    let precision: u32 = security as u32 + 2;
    match memo.get(&(x, n)) {
        Some(val) => val.clone(),
        None => {
            let num: Float;
            if x == num_queries {
                num = Float::with_val(precision, 1f64);
            } else if n == 0 {
                num = Float::with_val(precision, 0f64);
            } else {
                let a = step(x + 1, n - 1, memo, num_queries, lde_domain_size, security);
                let b = step(x, n - 1, memo, num_queries, lde_domain_size, security);
                num = Float::with_val(precision, lde_domain_size - x)
                    / (Float::with_val(precision, lde_domain_size))
                    * a
                    + Float::with_val(precision, x) / (Float::with_val(precision, lde_domain_size))
                        * b;
            }
            memo.insert((x, n), num.clone());
            num
        }
    }
}
