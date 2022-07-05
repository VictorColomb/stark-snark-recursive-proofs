pragma circom 2.0.4;

include "ood_consistency_check.circom"

template verify(num_transition_constraints, num_assertions, trace_width, num_constraint_degrees, ce_blowup_factor) {
    signal input constraint_commitment;
    signal input constraint_query_proofs[];
    signal input constraint_evaluations[];
    signal input fri_commitments[num_fri_layers];
    signal input fri_layer_proofs[][];
    signal input fri_layer_queries[][];
    signal input fri_num_partitions;
    signal input fri_remainder[];
    signal input ood_constraint_evaluations[ce_blowup_factor];
    signal input ood_trace_frame[2][trace_width];
    signal input pow_nonce;
    signal input result;
    signal input trace_commitment;
    signal input trace_query_proofs[];
    signal input trace_sevaluations[];
    component ood = OodConsistencyCheck(transition_constraints, num_constraint_degrees);

    // Public coin init

    component pub_coin = PublicCoin(num_fri_layers, trace_width, trace_length, ce_blowup_factor, num_draws, num_queries, lde_blowup_size, num_transition_constraints, num_assertions);
    pub_coin.context_pub_inputs <== FIXME: ??;
    pub_coin.trace_commitment <== trace_commitment;
    pub_coin.constraint_commitment <== constraint_commitment;
    
    for (var i = 0; i < trace_width; i++) {
        pub_coin.ood_trace_frame[0][i] <== ood_trace_frame[0][i];
        pub_coin.ood_trace_frame[1][i] <== ood_trace_frame[1][i];
    }
    
    for (var i = 0; i < ce_blowup_factor; i++) {
        pub_coin.ood_constraint_evaluations[i] <== ood_constraint_evaluations[i];
    }
    
    pub_coin.ood_constraint_evaluations_reduced <== ood_constraint_evaluations_reduced; ;
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
    
    signal z;
    z <== pub_coin.z;

    // 3 - OOD consistency check :  evaluate_constraints(ood_trace_frame,constraint_coeffs)

    // get_transition_constraints(air, composition_coefficients) <== public input

    ood.result <== result
    ood.x <== pub_coin.z;
    for (var i = 0; i < ce_blowup_factor; i++) {
        ood.channel_ood_evaluations[i] <== ood_constraint_evaluations[i];
    }
    for (var i = 0; i < 2; i){
        for (var j = 0; j < trace_width; j) {
            ood.frame <== ood_trace_frame[i][j];
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

    component MerkleOpeningsVerify(amount, depth);



    // 6 - DEEP : compute DEEP at the queried positions

    // 7 - FRI verification 
    

}