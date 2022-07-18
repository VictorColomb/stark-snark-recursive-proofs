mod json;
pub use json::proof_to_json;
use std::collections::HashMap;

mod prover;
pub use prover::WorkProver;

mod air;
pub use air::WorkAir;

use rug::{Float, ops::Pow};

// TODO: calculate query_positions

// TODO: print parameters to file/console

// TODO: convert assertions to Circom template

// TODO: convert transition constraints to Circom template

pub fn number_of_draws(num_queries: u128, lde_domain_size: u128, security: i32) -> u128 {
    let mut num_draws: u128 = 0;
    let precision: u32 = security as u32 + 2;
    
    while {
        let st = step(0,num_draws,&mut HashMap::new(),num_queries,lde_domain_size, security);
        num_draws += 1;
        1 - st> Float::with_val(precision, 2_f64).pow(-security)
        
    } {}
    
    num_draws
}

fn step(
    x: u128,
    n: u128,
    memo: &mut HashMap<(u128, u128), Float>,
    num_queries: u128,
    lde_domain_size: u128,
    security: i32
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
                let a = step(x + 1, n - 1, memo, num_queries, lde_domain_size,security);
                let b = step(x, n - 1, memo, num_queries, lde_domain_size,security);
                num = Float::with_val(precision , lde_domain_size - x) /(Float::with_val(precision , lde_domain_size)) * a
                    + Float::with_val(precision , x) / (Float::with_val(precision , lde_domain_size)) * b;

            }
            memo.insert((x, n), num.clone());
            num
        }
    }
}
