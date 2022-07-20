use serde::Serialize;

mod json;
pub use json::proof_to_json;

mod circom_main;
pub use circom_main::generate_circom_main;

pub trait WinterPublicInputs: Serialize + Clone {
    const NUM_PUB_INPUTS: usize;
}
