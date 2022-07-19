pragma circom 2.0.4;

include "merkle.circom";
include "ood_consistency_check.circom";
include "public_coin.circom";

/**
 * A circom verifier for STARKs.
 *
 * ARGUMENTS:
 * - ce_blowup_factor: constraint evaluation domain blowup factor
 * - domain_offset: domain generator (7 for BLS12-381)
 * - folding_factor: FRI folding factor
 * - lde_blowup_factor: Low Degree Extention blowup factor
 * - num_assertions: number of assertions that will be turned into boundary constraints.
 * - num_draws: number of draws needed in order to have less than a 2**-128 probability
     to not get enough distinct elements for your queries
 * - num_fri_layers: number of fri folds
 * - num_pub_coin_seed: length of the serialized public inputs and context needed
     to initialize the public coin
 * - num_public_inputs: number of public inputs. Public inputs usually contain the
     inputs and the result of the calculation
 * - num_queries: number of decommitments for trace states and and constraint evaluations
     to be used in DEEP polynomial composition
 * - num_transition_constraints: number of transitions constraints defined in the AIR.
 * - trace_length: number of steps in the proven calculation
 * - trace_width: number of registers need to prove the calculations
 * - tree_depth: trace and commitments tree depth log2(lde_domain_size)
 *
 * INPUTS:
 * - constraint_commitment: root of the constraint merkle tree.
 * - constraint_evaluations: constraint polynomials evaluations
 * - constraint_query_proofs: merkle authentication paths to check consistency between
     the commitment and the queries at pseudo-random position
 * - fri_commitments: the root of the evaluations merkle tree for each FRI layer
 * - fri_layer_proofs: authentication paths of the aforementionned merkle tree at the
     query_positions for each FRI layer
 * - fri_layer_queries: folded DEEP polynomial evaluations at the folded query positions
     for each FRI layer
 * - fri_remainder: complete evaluation of the FRI remainder over the LDE domain
 * - ood_constraint_evaluations: constraint out of domain evaluations to be
     checked during the OOD consistency check
 * - ood_trace_frame: out of domain frame to evaluate constraints to check
     consitency with the ood_constraint_evaluations
 * - pub_coin_seed: serialized public inputs and context to initialize the public coin.
 * - pow_nonce: nonce for the proof of work determined by the grinding factor in
     the proof options
 * - trace_commitment: root of the trace merkle tree
 * - trace_evaluations: trace polynomial evaluations at the query positions
 * - trace_query_proofs: authentication paths of the aforementionned merkle tree at
     the query positions
 *
 * TODO:
 * -
 * -
 * -
 */template Verify(
    addicity,
    ce_blowup_factor,
    domain_offset,
    folding_factor,
    grinding_factor,
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
    var remainder_size = (((trace_length * lde_blowup_factor) \ (folding_factor ** num_fri_layers)) \ folding_factor) * folding_factor;

    signal input addicity_root;
    signal input constraint_commitment;
    signal input constraint_evaluations[num_queries][trace_width];
    signal input constraint_query_proofs[num_queries][tree_depth];
    signal input fri_commitments[num_fri_layers+1];
    signal input fri_layer_proofs[num_fri_layers][num_queries][tree_depth];
    signal input fri_layer_queries[num_fri_layers][num_queries * folding_factor];
    signal input fri_remainder[remainder_size];
    signal input ood_constraint_evaluations[trace_width];
    signal input ood_trace_frame[2][trace_width];
    signal input pub_coin_seed[num_pub_coin_seed];
    signal input public_inputs[num_public_inputs];
    signal input pow_nonce;
    signal input trace_commitment;
    signal input trace_evaluations[num_queries][trace_width];
    signal input trace_query_proofs[num_queries][tree_depth];

    signal constraint_div[num_queries][trace_width];
    signal constraint_evalxcoeff[num_queries][trace_width];
    signal deep_composition[num_queries];
    signal deep_deg_adjustment[num_queries];
    signal deep_evaluations[num_queries];
    signal deep_temp[num_queries][trace_width];
    signal g_lde;
    signal g_trace;
    signal trace_deep_composition[num_queries][trace_width][2];
    signal trace_div[num_queries][trace_width][2];
    signal x_coordinates[num_queries];
    signal x_pow[trace_length * lde_blowup_factor];

    component addicity_pow[3];
    component constraintCommitmentVerifier;
    component ood;
    component pub_coin;
    component sel[num_queries];
    component traceCommitmentVerifier;
    component x_pow_domain_offset;
    component z_m;


    // calculate lde domain and trace domain roots of unity
    addicity_pow[0] = Pow(2 ** addicity);
    addicity_pow[0].in <== addicity_root;
    addicity_pow[0].out === 1;

    var log2_trace_length = numbits(trace_length) - 1;
    assert(log2_trace_length <= addicity);
    addicity_pow[1] = Pow(2 ** (addicity - log2_trace_length));
    addicity_pow[1].in <== addicity_root;
    g_trace <== addicity_pow[1].out;

    var log2_lde_domain_size = numbits(trace_length * lde_blowup_factor) - 1;
    assert(log2_lde_domain_size <= addicity);
    addicity_pow[2] = Pow(2 ** (addicity - log2_lde_domain_size));
    addicity_pow[2].in <== addicity_root;
    g_lde <== addicity_pow[2].out;


    // Public coin initialization

    pub_coin = PublicCoin(
        ce_blowup_factor,
        grinding_factor,
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

    for (var i = 0; i < trace_width; i++) {
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

   ood = OodConsistencyCheck(
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
    for (var i = 0; i < trace_width; i++) {
        ood.channel_ood_evaluations[i] <== ood_constraint_evaluations[i];
    }
    for (var i = 0; i < 2; i++){
        for (var j = 0; j < trace_width; j++) {
            ood.frame[i][j] <== ood_trace_frame[i][j];
        }
    }


    /* 4 - FRI commitment: generate DEEP coefficients */

    // Everything is generated in the public coin



    // 5 - Trace and constraint queries: check POW, draw query positions

    traceCommitmentVerifier = MerkleOpeningsVerify(num_queries, tree_depth);
    traceCommitmentVerifier.root <== trace_commitment;
    for (var i = 0; i < num_queries; i++) {
        traceCommitmentVerifier.indexes[i] <== pub_coin.query_positions[i];
        for (var j = 0; j < tree_depth; j++) {
            traceCommitmentVerifier.openings[i][j] <== trace_query_proofs[i][j];
        }
    }

    constraintCommitmentVerifier = MerkleOpeningsVerify(num_queries, tree_depth);
    constraintCommitmentVerifier.root <== constraint_commitment;
    for (var i = 0; i < num_queries; i++) {
        constraintCommitmentVerifier.indexes[i] <== pub_coin.query_positions[i];
        for (var j = 0; j < tree_depth; j++) {
            constraintCommitmentVerifier.openings[i][j] <== constraint_query_proofs[i][j];
        }
    }


    // 6 - DEEP: compute DEEP at the queried positions

    z_m = Pow(ce_blowup_factor);
    z_m.in <== pub_coin.z;

    x_pow[0] <== 1;

    for (var i = 1; i < trace_length * lde_blowup_factor; i++){
        x_pow[i] <== x_pow[i-1] * g_lde;
    }

    for (var i = 0; i < num_queries; i++) {

        sel[i] = Selector(trace_length * lde_blowup_factor);

        for (var j = 0; j < trace_length * lde_blowup_factor; j++) {
            sel[i].in[j] <== x_pow[j] * domain_offset;
        }

        sel[i].index <== pub_coin.query_positions[i];


        for (var j = 0; j < trace_width; j++) {

            // DEEP trace composition
            trace_div[i][j][0] <-- (trace_evaluations[i][j] - ood_trace_frame[0][j]) / (sel[i].out - pub_coin.z);
            trace_div[i][j][0] * (sel[i].out - pub_coin.z) === trace_evaluations[i][j] - ood_trace_frame[0][j];


            deep_temp[i][j] <== sel[i].out - pub_coin.z * g_trace;
            trace_div[i][j][1] <-- (trace_evaluations[i][j] - ood_trace_frame[1][j]) / deep_temp[i][j];
            trace_div[i][j][1] * deep_temp[i][j] === trace_evaluations[i][j] - ood_trace_frame[1][j];

            trace_deep_composition[i][j][0] <== pub_coin.deep_trace_coefficients[j][0] * trace_div[i][j][0];

            // DEEP constraint composition
           
            if (j == 0) {

                trace_deep_composition[i][j][1] <== trace_deep_composition[i][j][0]+ pub_coin.deep_trace_coefficients[j][1] * trace_div[i][j][1];

                constraint_div[i][j] <-- (constraint_evaluations[i][j] - ood_constraint_evaluations[j]) / (sel[i].out - z_m.out);
                constraint_div[i][j]  * (sel[i].out - z_m.out) ===  constraint_evaluations[i][j] - ood_constraint_evaluations[j];
                constraint_evalxcoeff[i][j] <== constraint_div[i][j] * pub_coin.deep_constraint_coefficients[j];
                
            } else {

                trace_deep_composition[i][j][1] <== trace_deep_composition[i][j-1][1] + trace_deep_composition[i][j][0]+ pub_coin.deep_trace_coefficients[j][1] * trace_div[i][j][1];
                
                constraint_div[i][j] <-- (constraint_evaluations[i][j] - ood_constraint_evaluations[j]) / (sel[i].out - z_m.out);
                (constraint_div[i][j])  * (sel[i].out - z_m.out) ===  constraint_evaluations[i][j] - ood_constraint_evaluations[j];
                constraint_evalxcoeff[i][j] <== constraint_evalxcoeff[i][j-1] + constraint_div[i][j] * pub_coin.deep_constraint_coefficients[j];
                
            }

        }
        
        deep_composition[i] <== trace_deep_composition[i][trace_width -1][1] + constraint_evalxcoeff[i][trace_width -1];

        // final composition
        deep_deg_adjustment[i] <== pub_coin.degree_adjustment_coefficients[0] + sel[i].out * pub_coin.degree_adjustment_coefficients[1];
        deep_evaluations[i] <== deep_composition[i] * deep_deg_adjustment[i];

    }

 
    // 7 - FRI verification

}