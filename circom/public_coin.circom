pragma circom 2.0.4;

include "./poseidon/poseidon.circom";
include "./utils.circom";

template PublicCoin(num_fri_layers, trace_width, trace_length, ce_blowup_factor, num_draws, num_queries, lde_blowup_size) {
    signal input trace_commitment;
    signal input constraint_commitment;
    signal input ood_constraint_evaluations_reduced;
    signal input fri_commitments[num_fri_layers];
    signal input pow_nonce;

    signal output transition_coeffs[num_transition_constraints];
    signal output boundary_coeffs[num_assertions];
    signal output deep_trace_coefficients[trace_width][3];
    signal output deep_constraint_coefficients[ce_blowup_factor];
    signal output degree_adjustment_coefficients[2];
    signal output layer_alphas[num_fri_layers];
    signal output query_positions[num_queries];

    var num_seeds = 1 + 1 + 1 + num_constraint_degrees;
    signal seed[num_seeds][2];
    component reseed[num_seeds];
    
    // TODO: initial context seed
    var k = 0;



    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== trace_commitment;
    
    component trace_coin[num_transition_constraints + num_assertions] = Poseidon(2);
    
    for (var i = 0; i < num_transition_constraints; i++) {
        trace_coin[i].in[0] <== reseed[k].out;
        trace_coin[i].in[1] <== i + 1;
        transition_coeffs[i] <== trace_coin[i].out;
    }

    for (var i = 0; i < num_assertions; i++) {
        trace_coin[i + num_transition_constraints].in[0] <== reseed[k].out;
        trace_coin[i + num_transition_constraints].in[1] <== i + num_transition_constraints + 1;
        boundary_coeffs[i] <== trace_coin[i + num_transition_constraints].out;
    }



    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== trace_commitment;

    component constraint_coin = Poseidon(2);
    constraint_coin.in[0] <== reseed[k].out;
    constraint_coin.in[1] <== 1;
    z <== constraint_coin.out;



    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== trace_commitment;
    
    component ood_coin[3 * trace_width + ce_blowup_factor + 2] = Poseidon(2);
    for (var i = 0; i < trace_width; i++){
        for (var j = 0; j < 3; j++){
        ood_coin[3 * i + j].in[0] <== reseed[k][0];
        ood_coin[3 * i + j].in[1] <== 3 * i + j + 1;
        deep_trace_coefficients[i][j] <== ood_coin[3 * i + j].out;
        }
    }

    for (var i = 0; i < trace_width; i++){
        ood_coin[i + 3 * trace_width].in[0] <== reseed[k][0];
        ood_coin[i + 3 * trace_width].in[1] <== i + 1;
        deep_trace_coefficients[i] <== ood_coin[i + 3 * trace_width].out ;
    }

    for (var i = 0; i < 2; i++){
        ood_coin[i + 3 * trace_width + ce_blowup_factor].in[0] <== reseed[k][0];
        ood_coin[i + 3 * trace_width + ce_blowup_factor].in[1] <== i + 1;
        degree_adjustment_coefficients[i] <== ood_coin[i + 3 * trace_width + ce_blowup_factor].out ;
    }



    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== trace_commitment;

    // FIXME: num_fri_layers | + 1 | ??
    component fri_coin[num_fri_layers + 1] = Poseidon(2);
    for (var i = 0; i < num_fri_layers; i++) {
        fri_coin.in[0] <== reseed[k].out;
        fri_coin.in[1] <== i + 1;
        layer_alphas[i] <== fri_coin[i].out;
    }



    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== pow_nonce;

    // TODO: check proof of work

    component query_coin[num_draws];
    component remove_duplicates = RemoveDuplicates(num_draws,num_queries)
    signal query_draws[num_draws];
    for (var i = 0; i < num_draws) {
        query_coin[i] <== reseed[k].out;
        query_coin[i] <== i + 1;
        remove_duplicates.in[i] <== query_coin[i].out;
    }


    // compute the size of the query elements in bits 

    var bit_mask = trace_length * lde_blowup_size;
    var mask_size = 0;
    while(bit_mask != 0) {
        bit_mask \= 2;
        mask_size += 1;
    }    

    component num2bits[num_queries];
    component bits2num[num_queries];
    for (var i = 0; i < num_queries; i++){
        num2bits[i] = Num2Bits(mask_size);
        num2bits[i].in <== remove_duplicates.out[i];
        bits2num[i] = Bits2Num(mask_size);
        for (var j = 0; j < mask_size; j++){
            bits2num[i].in[j] = num2bits[i].out[j]
        }
        query_positions[i] = bits2num[i].out;
    }
}