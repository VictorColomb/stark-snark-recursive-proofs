use winter_circom_prover::{circom_compile, utils::{LoggingLevel, WinterCircomError}};

#[allow(dead_code)]
mod prover;
use prover::WorkProver;

mod air;
use air::PROOF_OPTIONS;

fn main() -> Result<(), WinterCircomError> {
    circom_compile::<WorkProver, 2>(PROOF_OPTIONS, "sum", LoggingLevel::Default)
}
