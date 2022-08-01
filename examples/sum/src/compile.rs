#[path ="prove.rs"]
#[allow(dead_code)]
mod prove;

use prove::{PROOF_OPTIONS, WorkProver};
use winter_circom_prover::{circom_compile, utils::{LoggingLevel, WinterCircomError}};

fn main() -> Result<(), WinterCircomError> {
    circom_compile::<WorkProver, 2>(PROOF_OPTIONS, "sum", LoggingLevel::Default)
}
