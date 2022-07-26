use serde::Serialize;

mod json;

mod circom;
pub use circom::{circom_prove, circom_verify};

mod verification;
pub use verification::check_ood_frame;

// re-export winterfell to simplify dependencies
pub use winterfell;

/// Trait for compatibility between implementations of [winter_air::Air::PublicInputs]
/// and the [prepare_circom_verification] function.
pub trait WinterPublicInputs: Serialize + Clone {
    const NUM_PUB_INPUTS: usize;
}
