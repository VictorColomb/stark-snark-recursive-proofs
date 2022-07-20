pragma circom 2.0.0;

include "circuits/verify.circom";
include "circuits/air/sum.circom";

component main {public [ood_frame_constraint_evaluation, ood_trace_frame]}= Verify(
    28, // addicity
    2, // ce_blowup_factor
    5, // domain_offset
    8, // folding_factor
    [30, 20], // fri_num_queries
    [8, 5], // fri_tree_depth
    0, // grinding_factor
    8, // lde_blowup_factor
    3, // num_assertions
    59, // num_draws
    2, // num_fri_layers
    4, // num_pub_coin_seed
    2, // num_public_inputs
    32, // num_queries
    2, // num_transition_constraints
    256, // trace_length
    2,  // trace_length
    11 // tree_depth
);
