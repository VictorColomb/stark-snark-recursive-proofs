pragma circom 2.0.4;

include "ood_consistency_check.circom"

template verify(num_transition_constraints, num_assertions, trace_width, num_constraint_degrees, ce_blowup_factor) {
    signal input constraint_commitment;
    signal input constraint_query_proofs[];
    signal input constraint_evaluations[];
    signal input fri_commitments[];
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

    // 1 - Trace commitment
    
    // reseed coin with trace_commitment

    // build random coefficients for the composition polynomial constraint_coeffs

    signal ood_transition_coefficients[num_transition_constraints];
    for (var i = 0; i < num_transition_constraints; i++) {
        // public_coin draw pair --> FIXME: into ood
    }

    signal ood_boundary_coefficients[num_assertions];
    for (var i = 0; i < num_assertions; i++) {
        // public_coin draw pair --> FIXME: into ood
    }


    // 2 - Constraint commitment 
    
    // reseed coin with constraint_commitment


    signal z;
    z <== public_coin.draw();


    // 3 - OOD consistency check :  evaluate_constraints(ood_trace_frame,constraint_coeffs)

    // get_transition_constraints(air, composition_coefficients) <== public input

    ood.result <== result
    ood.x <== z;
    for (var i = 0; i < ce_blowup_factor; i++) {
        ood.channel_ood_evaluations <== ood_constraint_evaluations;
    }
    for (var i = 0; i < 2; i){
        for (var j = 0; j < trace_width; j) {
            ood.frame <== ood_trace_frame[i][j];
        }
    }

    // reseed with ood_constraint_evaluations




    // 4 - FRI commitment : generate DEEP coefficients
    
    signal deep_trace_coefficients[trace_width];
    for (var i = 0; i < trace_width; i++) {
        // public_coin draw pair --> deep_trace_coefficients
    }

    signal deep_constraint_coefficients[ce_blowup_factor];
    for (var i = 0; i < ce_blowup_factor; i++) {
        // public_coin draw pair --> deep_constraint_coefficients
    }

    signal degree_adjustment_coefficients[2];
    // public_coin draw pair --> degree_adjustment_coefficients


    // 5 - Trace and constraint queries : check POW, draw query positions
    // read evaluations of trace and constraint composition polynomials at the queried positions;

    // 6 - DEEP : compute DEEP at the queried positions

    // 7 - FRI verification 


}