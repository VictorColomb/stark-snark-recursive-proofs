use serde::Serialize;

mod json;

mod circom;
pub use circom::{circom_compile, circom_prove, circom_verify};

mod verification;
pub use verification::check_ood_frame;

pub mod utils;

// re-export winterfell to simplify dependencies
pub use winterfell;
use winterfell::{HashFunction, ProofOptions, TransitionConstraintDegree};

/// Trait for compatibility between implementations of [winter_air::Air::PublicInputs]
/// and the [prepare_circom_verification] function.
pub trait WinterPublicInputs: Serialize + Clone {
    const NUM_PUB_INPUTS: usize;
}

/// Proof options for a input-independant circuit.
///
/// ## Transition constraints
///
/// Generic parameter `N` is the number of transition constraints.
///
/// Element `transition_constraint_degree` is a usize array that will be mapped to
/// an array of [TransitionConstraintDegree] through its `new()` method.
pub struct WinterCircomProofOptions<const N: usize> {
    pub trace_length: usize,
    pub trace_width: usize,
    num_assertions: usize,
    transition_constraint_degrees: [usize; N],
    num_queries: usize,
    lde_blowup_factor: usize,
    grinding_factor: u32,
    fri_folding_factor: usize,
    fri_max_remainder_size: usize,
}

impl<const N: usize> WinterCircomProofOptions<N> {
    pub const fn new(
        trace_length: usize,
        trace_width: usize,
        num_assertions: usize,
        transition_constraint_degrees: [usize; N],
        num_queries: usize,
        lde_blowup_factor: usize,
        grinding_factor: u32,
        fri_folding_factor: usize,
        fri_max_remainder_size: usize,
    ) -> Self {
        Self {
            trace_length,
            trace_width,
            num_assertions,
            transition_constraint_degrees,
            num_queries,
            lde_blowup_factor,
            grinding_factor,
            fri_folding_factor,
            fri_max_remainder_size,
        }
    }

    pub fn get_proof_options(&self) -> ProofOptions {
        assert!(self.trace_length * self.lde_blowup_factor > self.fri_max_remainder_size,
            "trace_length * lde_blowup_factor must be greater than fri_max_remainder_size for the Circom circuit to work");

        ProofOptions::new(
            self.num_queries,
            self.lde_blowup_factor,
            self.grinding_factor,
            HashFunction::Poseidon,
            winterfell::FieldExtension::None,
            self.fri_folding_factor,
            self.fri_max_remainder_size,
        )
    }

    pub fn fri_folding_factor(&self) -> usize {
        self.fri_folding_factor
    }

    pub fn grinding_factor(&self) -> u32 {
        self.grinding_factor
    }

    pub fn lde_blowup_factor(&self) -> usize {
        self.lde_blowup_factor
    }

    pub fn num_queries(&self) -> usize {
        self.num_queries
    }

    pub fn transition_constraint_degrees(&self) -> Vec<TransitionConstraintDegree> {
        self.transition_constraint_degrees
            .iter()
            .map(|d| TransitionConstraintDegree::new(*d))
            .collect::<Vec<_>>()
    }

    pub fn num_assertions(&self) -> usize {
        self.num_assertions
    }
}
