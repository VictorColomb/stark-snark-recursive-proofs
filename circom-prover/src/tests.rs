use winter_air::{Air, FieldExtension, HashFunction, ProofOptions};
use winter_crypto::{hashers::Poseidon, MerkleTree};
use winter_math::{fields::f256::BaseElement, FieldElement};
use winter_prover::{Prover, StarkProof};

use super::{WorkAir, WorkProver};

type Hash = Poseidon<BaseElement>;

#[test]
fn trace_query_proofs() {
    // Build proof, reconstruct air and destructure proof
    let (proof, query_positions, public_inputs) = generate_proof();

    let air = WorkAir::new(
        proof.get_trace_info(),
        public_inputs,
        proof.options().clone(),
    );

    let StarkProof {
        context: _,
        commitments,
        mut trace_queries,
        constraint_queries: _,
        ood_frame: _,
        fri_proof: _,
        pow_nonce: _,
    } = proof;

    // get proof parameters
    let num_trace_segments = air.trace_layout().num_segments();
    let lde_domain_size = air.lde_domain_size();
    let fri_options = air.options().to_fri_options();
    let num_queries = air.options().num_queries();
    let main_trace_width = air.trace_layout().main_trace_width();

    // retreive trace root
    let trace_root = commitments
        .parse::<Hash>(
            num_trace_segments,
            fri_options.num_fri_layers(lde_domain_size),
        )
        .unwrap()
        .0
        .remove(0);

    // retreive trace queries
    let trace_proof = trace_queries
        .remove(0)
        .parse::<Hash, BaseElement>(lde_domain_size, num_queries, main_trace_width)
        .unwrap()
        .0;

    assert!(MerkleTree::verify_batch(&trace_root, &query_positions, &trace_proof).is_ok());

    let paths = trace_proof.to_paths(&query_positions).unwrap();
    for (path, index) in paths.iter().zip(&query_positions) {
        assert!(
            MerkleTree::<Hash>::verify(trace_root, *index, path).is_ok(),
            "Path of index {} is fucked.",
            index
        );
    }
}

// HELPER FUNCTIONS
// ===========================================================================

fn generate_proof() -> (StarkProof, Vec<usize>, <WorkAir as Air>::PublicInputs) {
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
    let prover = WorkProver::new(options);
    let trace = prover.build_trace(start, n);
    let public_inputs = prover.get_pub_inputs(&trace);
    let (proof, query_positions) = prover.prove(trace).unwrap();
    (proof, query_positions, public_inputs)
}
