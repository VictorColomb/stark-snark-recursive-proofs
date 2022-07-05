pragma circom 2.0.4;

include "./poseidon/poseidon.circom";
include "./utils.circom";

template PublicCoin(num_fri_layers, trace_width, trace_length, ce_blowup_factor, num_draws, num_queries, lde_blowup_size, num_transition_constraints, num_assertions) {
    signal input context_pub_inputs;
    signal input trace_commitment;
    signal input constraint_commitment;
    signal input ood_trace_frame[2][trace_width];
    signal input ood_constraint_evaluations[ce_blowup_factor];
    signal input pow_nonce;

    signal output transition_coeffs[num_transition_constraints][2];
    signal output boundary_coeffs[num_assertions][2];
    signal output deep_trace_coefficients[trace_width][3];
    signal output deep_constraint_coefficients[ce_blowup_factor];
    signal output degree_adjustment_coefficients[2];
    signal output layer_alphas[num_fri_layers];
    signal output query_positions[num_queries];
    signal output z;

    var num_seeds = 7;
    component reseed[num_seeds];
    
    // TODO: initial context seed
    var k = 0;

    reseed[k] = Poseidon(1);
    reseed[k].in[0] <== context_pub_inputs;
    
    // 1 - Reseeding with trace commitment

    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== trace_commitment;
    
    component trace_coin[num_transition_constraints + num_assertions][2] = Poseidon(2);
    
    for (var i = 0; i < num_transition_constraints; i++) {
        for (var j = 0; j < 2; j++){
            trace_coin[i][j].in[0] <== reseed[k].out;
            trace_coin[i][j].in[1] <== 2 * i + j + 1;
            transition_coeffs[i][j] <== trace_coin[i][j].out;
        }
    } 


    for (var i = 0; i < num_assertions; i++) {
        for (var j = 0; j < 2; j++){
            trace_coin[i + num_transition_constraints][j].in[0] <== reseed[k].out;
            trace_coin[i + num_transition_constraints][j].in[1] <== 2 * (i + num_transition_constraints) + j + 1;
            boundary_coeffs[i] <== trace_coin[i + num_transition_constraints][j].out;
        }
    }


    // 2 - Reseeding with constraint commitment

    k += 1;
    reseed[k] = Poseidon(2);
    reseed[k].in[0] <== reseed[k-1].out;
    reseed[k].in[1] <== constraint_commitment;

    component constraint_coin = Poseidon(2);
    constraint_coin.in[0] <== reseed[k].out;
    constraint_coin.in[1] <== 1;
    z <== constraint_coin.out;


    // 3 - Reseeding with ood_trace_frame

    k += 1;
    reseed[k] = Poseidon(1 + trace_width);
    reseed[k].in[0] <== reseed[k-1].out;
    for (var i = 0; i < trace_width; i++){
        reseed[k].in[i + 1] <== ood_trace_frame[0][i];
    }

    k += 1;
    reseed[k] = Poseidon(1 + trace_width);
    reseed[k].in[0] <== reseed[k-1].out;
    for (var i = 0; i < trace_width; i++){
        reseed[k].in[i + 1] <== ood_trace_frame[1][i];
    }

    
    component ood_coin[3 * trace_width + ce_blowup_factor + 2] = Poseidon(2);
    for (var i = 0; i < trace_width; i++){
        for (var j = 0; j < 3; j++){
        ood_coin[3 * i + j].in[0] <== reseed[k].out;
        ood_coin[3 * i + j].in[1] <== 3 * i + j + 1;
        deep_trace_coefficients[i][j] <== ood_coin[3 * i + j].out;
        }
    }

    for (var i = 0; i < trace_width; i++){
        ood_coin[i + 3 * trace_width].in[0] <== reseed[k].out;
        ood_coin[i + 3 * trace_width].in[1] <== i + 1;
        deep_constraint_coefficients[i] <== ood_coin[i + 3 * trace_width].out ;
    }

    for (var i = 0; i < 2; i++){
        ood_coin[i + 3 * trace_width + ce_blowup_factor].in[0] <== reseed[k].out;
        ood_coin[i + 3 * trace_width + ce_blowup_factor].in[1] <== i + 1;
        degree_adjustment_coefficients[i] <== ood_coin[i + 3 * trace_width + ce_blowup_factor].out ;
    }


    // 4 - Reseeding with OOD constraint evaluations

    k += 1;
    reseed[k] = Poseidon(1 + ce_blowup_factor);
    reseed[k].in[0] <== reseed[k-1].out;
    for (var i = 0; i < ce_blowup_factor; i++) {
        reseed[k].in[i+1] <== ood_constraint_evaluations[i];
    }
    

    // FIXME: num_fri_layers | + 1 | ??
    component fri_coin[num_fri_layers + 1] = Poseidon(2);
    for (var i = 0; i < num_fri_layers; i++) {
        fri_coin.in[0] <== reseed[k].out;
        fri_coin.in[1] <== i + 1;
        layer_alphas[i] <== fri_coin[i].out;
    }


    // 5 - Reseeding with proof of work

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
        query_positions[i] <== bits2num[i].out;
    }
}