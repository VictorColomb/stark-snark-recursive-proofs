pragma circom 2.0.4;

include "circom/verify.circom";


component main = Verify(
    32, //addicity
    2, //ce_blowup_factor
    7, //domain_offset
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

