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

    pub_coin.pow_nonce <== pow_nonce;

    for (var i = 0; i < num_fri_layers; i++) {
        pub_coin.fri_commitments[i] = fri_commitments[i];
    }


    /* 1 - Trace commitment */
    // build random coefficients for the composition polynomial constraint_coeffs

    for (var i = 0; i < num_transition_constraints; i++) {
        for (var j = 0; j < 2; j++) {
            ood.transition_coeffs[i][j] <== pub_coin.transition_coeffs[i][j];
        }
    }

    for (var i = 0; i < num_assertions; i++) {
        for (var j = 0; j < 2; j++) {
            ood.boundary_coeffs[i][j] <== pub_coin.boundary_coeffs[i][j];
        }
    }

    /* 2 - Constraint commitment */

    // Nothing to do here : z is drawn in the public coin and is used as pub_coin.z;

    /* 3 - OOD consistency check :  evaluate_constraints(ood_trace_frame,constraint_coeffs) */


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


    /* 4 - FRI commitment : generate DEEP coefficients */

    // Everything is generated in the public coin 

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

    signal deep_composition[num_queries];
    signal deep_evaluations[num_queries];
    signal x_coordinates[num_queries];
    component z_m = Pow(ce_blowup_factor);
    z_m.in <== pub_coin.z;

    // domain offset is hardcoded 7 to match our Winterfell config
    signal x_pow[trace_length * lde_blowup_size];
    component x_pow_domain_offset = Pow(7);
    x_pow_domain_offset.in <== g_lde;
    x_pow[0] <== 1;

    for (var i = 1; i < trace_length * lde_blowup_size){
        x_pow[i] <== x_pow[i-1] * x_pow_domain_offset;
    }

    component sel[num_queries];
    signal trace_div[num_queries][trace_width][2];
    signal constraint_div[num_queries][trace_width][2];

    for (var i = 0; i < num_queries; i++) {

        sel[i] = Selector(trace_length * lde_blowup_size);

        for (var j = 0; j < trace_length * lde_blowup_size) {
            sel[i].in[j] <== x_pow[j];
        }

        sel[i].index <== query_positions[i];


        var result = 0;
        for (var j = 0; j < trace_width; j++) {

            // DEEP trace composition
            trace_div[i][j][0] <-- (queried_trace_evaluations[i] - ood_trace_frame[0][i]) / (sel[i].out - pub_coin.z);
            trace_div[i][j][0] * (sel[i].out - pub_coin.z) === queried_trace_evaluations[i] - ood_trace_frame[0][i];

            trace_div[i][j][1] <-- (queried_trace_evaluations[i] - ood_trace_frame[1][i]) / (sel[i].out - pub_coin.z * g_trace);
            trace_div[i][j][1] * (sel[i].out - pub_coin.z) === queried_trace_evaluations[i] - ood_trace_frame[1][i];

            // DEEP constraint composition
            constraint_div[i] <-- (constraint_evaluations[i] - ood_constraint_evaluations[i]) / (sel[i].out - z_m);
            constraint_div[i]  * (sel[i].out - z_m) ===  constraint_evaluations[i] - ood_constraint_evaluations[i];

            result += pub_coin.deep_trace_coefficients[j][0] * trace_div[i][j][0] + pub_coin.deep_trace_coefficients[j][1] * trace_div[i][j][1] + constraint_div[i] * pub_coin.deep_constraint_coefficients[i];
        }

        deep_composition[i] <== result;

        // final composition

        deep_evaluations[i] <== (deep_composition[i] + constraint_deep_composition[i]) * (pub_coin.degree_adjustment_coefficients[0] + sel[i].out * pub_coin.degree_adjustment_coefficients[1]);



    }


    // 7 - FRI verification

}