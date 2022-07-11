pragma circom 2.0.4;

include "./circom/public_coin.circom";
include "./circom/ood_consistency_check.circom";
include "./circom/merkle.circom";
include "./circom/utils.circom";


template Verify(
    ce_blowup_factor,
    folding_factor,
    lde_blowup_factor,
    num_assertions,
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
    signal input constraint_query_proofs[num_queries][tree_depth + 1];
    signal input fri_commitments[num_fri_layers+1];
    signal input fri_layer_proofs[num_fri_layers][num_queries][tree_depth + 1];
    signal input fri_layer_queries[num_fri_layers][num_queries * folding_factor];
    signal input fri_remainder[(trace_length * lde_blowup_factor) \ (folding_factor ** num_fri_layers)];
    signal input g_lde;
    signal input g_trace;
    signal input ood_constraint_evaluations[ce_blowup_factor];
    signal input ood_trace_frame[2][trace_width];
    signal input pub_coin_seed[num_pub_coin_seed];
    signal input public_inputs[num_public_inputs];
    signal input pow_nonce;
    signal input trace_commitment;
    signal input trace_evaluations[num_queries][trace_width];
    signal input trace_query_proofs[num_queries][tree_depth + 1];


    // Public coin initialization

    component pub_coin = PublicCoin(
        ce_blowup_factor,
        lde_blowup_factor,
        num_assertions,
        num_draws,
        num_fri_layers,
        num_pub_coin_seed,
        num_queries,
        num_transition_constraints,
        trace_length,
        trace_width
    );

    pub_coin.constraint_commitment <== constraint_commitment;
 
    for (var i = 0; i < num_fri_layers + 1; i++) {
        pub_coin.fri_commitments[i] <== fri_commitments[i];
    }

    for (var i = 0; i < ce_blowup_factor; i++) {
        pub_coin.ood_constraint_evaluations[i] <== ood_constraint_evaluations[i];
    }
    
    for (var i = 0; i < trace_width; i++) {
        pub_coin.ood_trace_frame[0][i] <== ood_trace_frame[0][i];
        pub_coin.ood_trace_frame[1][i] <== ood_trace_frame[1][i];
    }

    pub_coin.pow_nonce <== pow_nonce;
    
    for (var i = 0; i < num_pub_coin_seed; i++) {
        pub_coin.pub_coin_seed[i] <== pub_coin_seed[i];
    }

    pub_coin.trace_commitment <== trace_commitment;
 

    /* 1 - Trace commitment */
    // build random coefficients for the composition polynomial constraint coeffiscients

   component ood = OodConsistencyCheck(
        ce_blowup_factor,
        num_assertions,
        num_public_inputs,
        trace_length,
        trace_width
    );

    ood.g_trace <== g_trace;

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

    // Nothing to do here: z is drawn in the public coin and is used as pub_coin.z;


    /* 3 - OOD consistency check: check that the given out of domain evaluation
       are consistent when reevaluating them.
     */


    for (var i = 0; i < num_public_inputs; i++) {
        ood.public_inputs[i] <== public_inputs[i];
    }
    ood.z <== pub_coin.z;
    for (var i = 0; i < ce_blowup_factor; i++) {
        ood.channel_ood_evaluations[i] <== ood_constraint_evaluations[i];
    }
    for (var i = 0; i < 2; i++){
        for (var j = 0; j < trace_width; j++) {
            ood.frame[i][j] <== ood_trace_frame[i][j];
        }
    }

 
}

component main = Verify(
    2, //ce_blowup_factor
    8, //folding_factor
    8, //lde_blowup_factor
    3, //num_assertions
    111, //num_draws
    2, //num_fri_layers
    4, //num_pub_coin_seed
    2, //num_public_inputs
    32, //num_queries
    2, //num_transition_constraints
    256, //trace_length
    2, //trace_width
    11 //tree_depth
);

