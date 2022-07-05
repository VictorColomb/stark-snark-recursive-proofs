pragma circom 2.0.4;

include "ood_consistency_check.circom";
include "merkle.circom";

template Verify(
    ce_blowup_factor,
    folding_factor,
    lde_blowup_factor,
    num_assertions,
    num_constraint_degrees,
    num_draws,
    num_fri_layers,
    num_pub_coin_seed,
    num_public_inputs,
    num_queries,
    num_transition_constraints,
    trace_length,
    trace_width,
    tree_depth
) {
    signal input constraint_commitment;
    signal input constraint_evaluations[num_queries][trace_width];
    signal input constraint_query_proofs[num_queries][tree_depth];
    signal input fri_commitments[num_fri_layers];
    signal input fri_layer_proofs[num_fri_layers][num_queries][tree_depth];
    signal input fri_layer_queries[num_fri_layers][num_queries * folding_factor];
    signal input fri_remainder[(2 ** (trace_length * lde_blowup_factor)) \ (folding_factor ** num_fri_layers)];
    signal input ood_constraint_evaluations[ce_blowup_factor];
    signal input ood_trace_frame[2][trace_width];
    signal input pub_coin_seed[num_pub_coin_seed];
    signal input pow_nonce;
    signal input trace_commitment;
    signal input trace_query_proofs[num_queries][trace_width];
    signal input trace_evaluations[num_queries][tree_depth];

    component ood = OodConsistencyCheck(
        ce_blowup_factor,
        num_assertions,
        num_public_inputs,
        trace_generator,
        trace_length,
        trace_width
    );

    // Public coin init

    component pub_coin = PublicCoin(
        ce_blowup_factor,
        lde_blowup_size,
        num_fri_layers,
        num_assertions,
        num_draws,
        num_pub_coin_seed,
        num_queries,
        num_transition_constraints,
        trace_length,
        trace_width
    );
    for (var i = 0; i < num_pub_coin_seed; i++) {
        pub_coin.pub_coin_seed[i] <== pub_coin_seed[i];
    }
    pub_coin.trace_commitment <== trace_commitment;
    pub_coin.constraint_commitment <== constraint_commitment;

    for (var i = 0; i < trace_width; i++) {
        pub_coin.ood_trace_frame[0][i] <== ood_trace_frame[0][i];
        pub_coin.ood_trace_frame[1][i] <== ood_trace_frame[1][i];
    }

    for (var i = 0; i < ce_blowup_factor; i++) {
        pub_coin.ood_constraint_evaluations[i] <== ood_constraint_evaluations[i];
    }

    pub_coin.ood_constraint_evaluations_reduced <== ood_constraint_evaluations_reduced;
    pub_coin.pow_nonce <== pow_nonce;

    for (var i = 0; i < num_fri_layers; i++) {
        pub_coin.fri_commitments[i] = fri_commitments[i];
    }


    // 1 - Trace commitment
    // build random coefficients for the composition polynomial constraint_coeffs

    signal ood_transition_coefficients[num_transition_constraints];
    for (var i = 0; i < num_transition_constraints; i++) {
        for (var j = 0; j < 2; j++) {
            ood.transition_coeffs[i][j] <== transition_coeffs[i][j];
        }
    }

    signal ood_boundary_coefficients[num_assertions];
    for (var i = 0; i < num_assertions; i++) {
        for (var j = 0; j < 2; j++) {
            ood.boundary_coeffs[i][j] <== boundary_coeffs[i][j];
        }
    }

    // 2 - Constraint commitment


    // 3 - OOD consistency check :  evaluate_constraints(ood_trace_frame,constraint_coeffs)

    // get_transition_constraints(air, composition_coefficients) <== public input

    for (var i = 0; i < num_public_inputs; i++) {
        ood.public_inputs[i] <== public_inputs[i];
    }
    ood.z <== pub_coin.z;
    for (var i = 0; i < ce_blowup_factor; i++) {
        ood.channel_ood_evaluations[i] <== ood_constraint_evaluations[i];
    }
    for (var i = 0; i < 2; i){
        for (var j = 0; j < trace_width; j) {
            ood.frame[i][j] <== ood_trace_frame[i][j];
        }
    }


    // 4 - FRI commitment : generate DEEP coefficients

    signal deep_trace_coefficients[trace_width][3];
    for (var i = 0; i < trace_width; i++) {
        for (var j = 0; j < 3; j++) {
            deep_trace_coefficients[i][j] <== pub_coin.deep_trace_coefficients[i][j];
        }
    }

    signal deep_constraint_coefficients[ce_blowup_factor];
    for (var i = 0; i < ce_blowup_factor; i++) {
        deep_constraint_coefficients[i] <== pub_coin.deep_constraint_coefficients[i];
    }

    signal degree_adjustment_coefficients[2];
    for (var i = 0; i < 2; i++) {
        degree_adjustment_coefficients[i] <== pub_coin.degree_adjustment_coefficients[i];
    }


    // 5 - Trace and constraint queries : check POW, draw query positions

    component traceCommitmentVerifier = VerifyMerkleOpenings(num_queries, tree_depth);
    traceCommitmentVerifier.root <== trace_commitment;
    for (var i = 0; i < num_queries; i++) {
        traceCommitmentVerifier.indexes[i] <== pub_coin.query_indexes[i];
        for (var j = 0; j < tree_depth; j++) {
            traceCommitmentVerifier.openings[i][j] <== trace_query_proofs[i][j];
        }
    }

    component constraintCommitmentVerifier = VerifyMerkleOpenings(num_queries, tree_depth);
    constraintCommitmentVerifier.root <== constraint_commitment;
    for (var i = 0; i < num_queries; i++) {
        constraintCommitmentVerifier.indexes[i] <== pub_coin.query_indexes[i];
        for (var j = 0; j < tree_depth; j++) {
            constraintCommitmentVerifier.openings[i][j] <== constraint_query_proofs[i][j];
        }
    }


    // 6 - DEEP : compute DEEP at the queried positions

    // 7 - FRI verification

}