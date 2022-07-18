use serde_json::{json, Value};
use winter_air::Air;
use winter_crypto::{Digest, ElementHasher};
use winter_fri::folding::fold_positions;
use winter_math::{fields::f256::BaseElement, log2, FieldElement, StarkField};
use winter_prover::{Serializable, StarkProof};

/// Parse a [StarkProof] into a Circom-usable JSON object.
///
/// ## Padding
///
/// To ensure constant size arrays and therefore Circom compatibility, elements
/// of `fri_layer_proofs` and `fri_layer_queries` arrays are padded with zeroes.
///
/// The `fri_num_queries` and `fri_tree_depths` arguments are populated so that:
///
/// ```text
/// fri_layer_proofs[i].len() = fri_num_queries[i]
/// fri_layer_proofs[i][j].len() = fri_tree_depths[i]
/// fri_layer_queries[i].len() = fri_num_queries[i] * folding_factor
/// ```
///
/// ## JSON structure
///
/// ```json
/// {
///     "addicity": _,
///     "constraint_commitment": _,
///     "constraint_evaluations": [[_; trace_width]; num_queries],
///     "constraint_query_proofs": [[_; tree_depth]; num_queries],
///     "fri_commitments": [num_fri_layers + 1],
///     "fri_layer_proofs": [[[_; tree_depth + 1]; num_queries]; num_fri_layers],
///     "fri_layer_queries": [[_; num_queries * folding_factor]; num_fri_layers],
///     "fri_remainder": [_; lde_domain_size / (folding_factor ** num_fri_layers)],
///     "ood_constraint_evaluations": [_; ce_blowup_factor],
///     "ood_trace_frame": [[_; trace_width]; 2],
///     "pow_nonce": _,
///     "pub_coin_seed": [_; num_pub_coin_seed]
///     "trace_commitment": _,
///     "trace_evaluations": [[_; trace_width]; num_queries],
///     "trace_query_proofs": [[tree_depth]; num_queries],
/// }
/// ```
pub fn proof_to_json<AIR, H>(
    proof: StarkProof,
    air: &AIR,
    query_positions: &Vec<usize>,
    pub_inputs: AIR::PublicInputs,
    fri_num_queries: &mut Vec<usize>,
    fri_tree_depths: &mut Vec<usize>,
) -> Value
where
    AIR: Air,
    H: ElementHasher<BaseField = BaseElement>,
{
    let StarkProof {
        context,
        commitments,
        mut trace_queries,
        constraint_queries,
        ood_frame,
        fri_proof,
        pow_nonce,
    } = proof;

    let num_trace_segments = air.trace_layout().num_segments();
    let main_trace_width = air.trace_layout().main_trace_width();
    let aux_trace_width = air.trace_layout().aux_trace_width();
    let lde_domain_size = air.lde_domain_size();
    let fri_options = air.options().to_fri_options();
    let num_queries = air.options().num_queries();
    let folding_factor = fri_options.folding_factor();

    // enforce only one trace segment to ensure compatibility with the Circom code
    assert_eq!(num_trace_segments, 1);

    // PUBLIC COIN SEED
    // ===========================================================================

    // serialize public inputs and context
    let mut pub_coin_seed = Vec::new();
    pub_inputs.write_into(&mut pub_coin_seed);
    context.write_into(&mut pub_coin_seed);

    // turn into f256 field elements
    while pub_coin_seed.len() % BaseElement::ELEMENT_BYTES != 0 {
        pub_coin_seed.push(0);
    }
    let pub_coin_seed = pub_coin_seed
        .as_slice()
        .chunks(BaseElement::ELEMENT_BYTES)
        .map(|bytes| BaseElement::from_le_bytes(bytes))
        .collect::<Vec<_>>();

    // COMMITMENTS
    // ===========================================================================

    // retreive commitments
    let (trace_commitments, constraint_commitment, fri_commitments) = commitments
        .parse::<H>(
            num_trace_segments,
            fri_options.num_fri_layers(lde_domain_size),
        )
        .unwrap();

    // map commitments to BaseElements
    let trace_commitment = trace_commitments
        .iter()
        .map(|c| BaseElement::from_le_bytes(&c.as_bytes()))
        .collect::<Vec<_>>()
        .remove(0);
    let constraint_commitment: BaseElement =
        BaseElement::from_le_bytes(&constraint_commitment.as_bytes());

    // there are fri_num_queries + 1 fri_commitments because
    // of the commitment for the remainder
    let fri_commitments = fri_commitments
        .iter()
        .map(|c| BaseElement::from_le_bytes(&c.as_bytes()))
        .collect::<Vec<_>>();

    // TRACE QUERIES
    // ===========================================================================

    // pick out trace queries first element (the one that corresponds to the
    // main trace segment) and parse it into a Merkle proof and trace states
    let (trace_query_proofs, trace_evaluations) = trace_queries
        .remove(0)
        .parse::<H, BaseElement>(lde_domain_size, num_queries, main_trace_width)
        .unwrap();

    // convert the batch Merkle proof into authentication paths
    // and map hash digests to BaseElements
    let trace_query_proofs = trace_query_proofs
        .to_paths(&query_positions)
        .unwrap()
        .iter()
        .map(|path| {
            path.iter()
                .map(|digest| BaseElement::from_le_bytes(&digest.as_bytes()))
                .collect::<Vec<_>>()
        })
        .collect::<Vec<Vec<_>>>();

    // map constraint states table into a matrix of BaseElements
    let trace_evaluations = trace_evaluations.rows().fold(vec![], |mut e, row| {
        e.push(row.to_vec());
        e
    });

    // CONSTRAINT QUERIES
    // ===========================================================================

    // parse constraint queries back into a Merkle proof and a vector of states
    let (constraint_query_proofs, constraint_evaluations) = constraint_queries
        .parse::<H, BaseElement>(lde_domain_size, num_queries, air.ce_blowup_factor())
        .unwrap();

    // convert the batch Merkle proof into authentication paths
    // and map hash digests to BaseElements
    let constraint_query_proofs = constraint_query_proofs
        .to_paths(&query_positions)
        .unwrap()
        .iter()
        .map(|path| {
            path.iter()
                .map(|digest| BaseElement::from_le_bytes(&digest.as_bytes()))
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();

    // map constraint states table into a matrix of BaseElements
    let constraint_evaluations = constraint_evaluations.rows().fold(vec![], |mut e, row| {
        e.push(row.to_vec());
        e
    });

    // OOD FRAME
    // ===========================================================================

    // parse ood_frame, ignoring the ood_aux_trace_frame
    let (ood_trace_frame, _, ood_constraint_evaluations) = ood_frame
        .parse::<BaseElement>(main_trace_width, aux_trace_width, air.ce_blowup_factor())
        .unwrap();
    let ood_trace_frame = (ood_trace_frame.current(), ood_trace_frame.next());

    // FRI PROOF
    // ===========================================================================

    // only accept a fri proof with a single partition
    assert_eq!(fri_proof.num_partitions(), 1);

    // parse fri proof into Merkle proofs and queries for each layer
    let fri_remainder = fri_proof.parse_remainder::<BaseElement>().unwrap();
    let (mut fri_layer_queries, fri_layer_proofs) = fri_proof
        .parse_layers::<H, BaseElement>(lde_domain_size, folding_factor)
        .unwrap();

    // convert batch merkle proofs into authentication paths
    // and map digests to BaseElements
    let mut indexes = query_positions.clone();
    let mut domain_size = lde_domain_size;
    let mut fri_layer_proofs = fri_layer_proofs
        .iter()
        .map(|merkle_proof| {
            indexes = fold_positions(&indexes, domain_size, folding_factor);
            domain_size /= folding_factor;

            merkle_proof
                .to_paths(&indexes)
                .unwrap()
                .iter()
                .map(|path| {
                    path.iter()
                        .map(|digest| BaseElement::from_le_bytes(&digest.as_bytes()))
                        .collect::<Vec<_>>()
                })
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();

    // pad fri_query_proofs with zeroes to ensure constant size arrays
    let tree_depth = log2(lde_domain_size) as usize;
    let fri_layer_proofs = fri_layer_proofs
        .iter_mut()
        .map(|paths| {
            fri_num_queries.push(paths.len());
            fri_tree_depths.push(paths[0].len());

            for path in paths.iter_mut() {
                while path.len() <= tree_depth {
                    path.push(BaseElement::ZERO);
                }
            }
            while paths.len() < num_queries {
                paths.push(vec![BaseElement::ZERO; tree_depth + 1]);
            }
            paths
        })
        .collect::<Vec<_>>();

    // pad fri layer queries with zeroes to ensure constant size arrays
    for queries in fri_layer_queries.iter_mut() {
        while queries.len() < num_queries * folding_factor {
            queries.push(BaseElement::ZERO);
        }
    }

    json!({
        "addicity_root": BaseElement::TWO_ADIC_ROOT_OF_UNITY,
        "constraint_commitment": constraint_commitment,
        "constraint_evaluations": constraint_evaluations,
        "constraint_query_proofs": constraint_query_proofs,
        "fri_commitments": fri_commitments,
        "fri_layer_proofs": fri_layer_proofs,
        "fri_layer_queries": fri_layer_queries,
        "fri_remainder": fri_remainder,
        "ood_constraint_evaluations": ood_constraint_evaluations,
        "ood_trace_frame": ood_trace_frame,
        "pow_nonce": pow_nonce,
        "pub_coin_seed": pub_coin_seed,
        "trace_commitment": trace_commitment,
        "trace_evaluations": trace_evaluations,
        "trace_query_proofs": trace_query_proofs,
    })
}
