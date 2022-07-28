use winter_circom_prover::circom_prove;
use winter_circom_prover::utils::{LoggingLevel, WinterCircomError};
use winter_circom_prover::winterfell::math::{fields::f256::BaseElement, FieldElement};

mod air;
pub(crate) use air::PROOF_OPTIONS;

mod prover;
pub use prover::WorkProver;

fn main() -> Result<(), WinterCircomError> {
    // parameters
    let start = BaseElement::ONE;

    // build proof
    let options = PROOF_OPTIONS.get_proof_options();
    let prover = WorkProver::new(options.clone());
    let trace = prover.build_trace(start, PROOF_OPTIONS.trace_length);

    circom_prove(prover, trace, "sum", LoggingLevel::Default)
}
