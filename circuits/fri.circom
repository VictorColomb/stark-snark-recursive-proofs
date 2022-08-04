pragma circom 2.0.0;

include "merkle.circom";
include "utils/arithmetic.circom";
include "utils/arrays.circom";
include "utils/bits.circom";
include "utils/comparators.circom";
include "utils/duplicates.circom";
include "utils/polynoms.circom";


template FriVerifier(
    addicity,
    domain_offset,
    folding_factor,
    fri_tree_depths,
    lde_blowup_factor,
    num_fri_layers,
    num_queries,
    trace_length,
    tree_depth
) {
    var remainder_size = (trace_length * lde_blowup_factor) \ (folding_factor ** num_fri_layers);
    var lde_domain_size = trace_length * lde_blowup_factor;

    signal input addicity_root;
    signal input deep_evaluations[num_queries];
    signal input fri_commitments[num_fri_layers + 1];
    signal input fri_layer_proofs[num_fri_layers][num_queries][tree_depth];
    signal input fri_layer_queries[num_fri_layers][num_queries * folding_factor];
    signal input fri_remainder[remainder_size];
    signal input g_lde;
    signal input layer_alphas[num_fri_layers];
    signal input query_positions[num_queries];

    signal coordinates_xe[num_fri_layers][num_queries];
    signal max_degree_plus_1[num_fri_layers + 1];
    signal query_values[num_fri_layers][num_queries];
    signal t1[folding_factor];
    signal t2[folding_factor];
    signal x_pow[lde_domain_size];

    component coordinate_pow_selectors[num_fri_layers];
    component coordinate_interpolators[num_fri_layers];
    component evaluations[num_fri_layers][num_queries];
    component folded_positions[num_fri_layers];
    component folded_position_modulos[num_fri_layers][num_queries];
    component folding_roots;
    component layer_commitment_verifiers[num_fri_layers];
    component layer_queries_divisions[num_fri_layers][num_queries];
    component layer_queries_lookups[num_fri_layers];
    component layer_query_selectors[num_fri_layers];
    component remainder_degree;
    component remainder_length_lt;
    component remainder_degree_lt;
    component remainder_hashers[remainder_size];
    component remainder_interpolation;
    component remainder_merkle_tree;
    component remainder_selectors;


    // PRE-COMPUTE ROOTS OF UNITY
    // ==========================================================================

    // calculate all powers of g_lde
    x_pow[0] <== 1;
    for (var i = 1; i < lde_domain_size; i++) {
        x_pow[i] <== x_pow[i - 1] * g_lde;
    }

    folding_roots = MultiSelector(lde_domain_size, folding_factor);
    for (var i = 0; i < lde_domain_size; i++) {
        folding_roots.in[i] <== x_pow[i];
    }
    for (var i = 0; i < folding_factor; i++) {
        // t2 = lde_domain_size / N * i
        t1[i] <-- lde_domain_size \ folding_factor;
        t1[i] * folding_factor === lde_domain_size;
        t2[i] <== t1[i] * i;

        // folding_roots[i] = g_lde ** t2;
        folding_roots.indexes[i] <== t2[i];
    }

    // 1 - VERIFY RECURSIVE COMPONENTS OF THE FRI PROOF
    // ==========================================================================

    var domain_size = lde_domain_size;
    var domain_generator_offset = 1;
    var extended_num_queries[num_fri_layers + 1];
    max_degree_plus_1[0] <== trace_length;

    for (var depth = 0; depth < num_fri_layers; depth++) {
        // CALCULATE FOLDED POSITIONS
        var target_domain_size = domain_size \ folding_factor;
        if (depth == 0) {
            // for the first FRI layers, fold query_positions
            folded_positions[0] = RemoveDuplicatesUnknown(num_queries);

            for (var j = 0; j < num_queries; j++) {
                folded_position_modulos[0][j] = IntegerDivision(target_domain_size, tree_depth);
                folded_position_modulos[0][j].in <== query_positions[j];

                folded_positions[0].in[j] <== folded_position_modulos[0][j].remainder;
                folded_positions[0].in_mask[j] <== 1;
            }
        } else {
            // for all consequent FRI layers, fold previous folded_positions
            folded_positions[depth] = RemoveDuplicatesUnknown(num_queries);

            for (var j = 0; j < num_queries; j++) {
                folded_position_modulos[depth][j] = IntegerDivision(target_domain_size, tree_depth);
                folded_position_modulos[depth][j].in <== folded_positions[depth - 1].out[j];

                folded_positions[depth].in[j] <== folded_position_modulos[depth][j].remainder;
                folded_positions[depth].in_mask[j] <== folded_positions[depth - 1].out_mask[j];
            }
        }

        // VERIFY FRI LAYER COMMITMENT
        layer_commitment_verifiers[depth] = MerkleOpeningsVerifyMasked(num_queries, fri_tree_depths[depth], folding_factor);
        layer_commitment_verifiers[depth].root <== fri_commitments[depth];
        for (var i = 0; i < num_queries; i++) {
            layer_commitment_verifiers[depth].indexes[i] <== folded_positions[depth].out[i];
            layer_commitment_verifiers[depth].mask[i] <== folded_positions[depth].out_mask[i];
            for (var j = 0; j < folding_factor; j++) {
                layer_commitment_verifiers[depth].leaves[i][j] <== fri_layer_queries[depth][i * folding_factor + j];
            }
            for (var j = 0; j < fri_tree_depths[depth]; j++) {
                layer_commitment_verifiers[depth].openings[i][j] <== fri_layer_proofs[depth][i][j];
            }
        }

        // VERIFY LAYER QUERIES
        var row_length = domain_size \ folding_factor;
        if (depth == 0) {
            // handle the first FRI layer with query_values
            layer_queries_lookups[0] = MultiIndexLookup(num_queries, num_queries);
            for (var j = 0; j < num_queries; j++) {
                layer_queries_lookups[0].in[j] <== folded_positions[0].out[j];
                layer_queries_lookups[0].mask[j] <== folded_positions[0].out_mask[j];
            }

            layer_query_selectors[0] = MultiSelector(num_queries * folding_factor, num_queries);
            for (var i = 0; i < num_queries * folding_factor; i++) {
                layer_query_selectors[0].in[i] <== fri_layer_queries[0][i];
            }

            for (var i = 0; i < num_queries; i++) {
                // integer division of position (query_positions[i]) by row_length
                layer_queries_divisions[0][i] = IntegerDivision(row_length, tree_depth);
                layer_queries_divisions[0][i].in <== query_positions[i];

                // find index of position % row_length in query_positions
                layer_queries_lookups[0].lookup[i] <== layer_queries_divisions[0][i].remainder;
            }
            for (var i = 0; i < num_queries; i++) {
                // pick fri_layer_queries[depth][idx * folding_factor + position \ row_length]
                // (where idx = layer_queries_lookups[depth][i].out)
                layer_query_selectors[0].indexes[i] <== layer_queries_lookups[0].out[i] * folding_factor + layer_queries_divisions[0][i].quotient;
            }
            for (var i = 0; i < num_queries; i++) {
                // verify that query_values == deep_evaluations
                // (where query_values = layer_query_selectors[depth].out)
                layer_query_selectors[0].out[i] === deep_evaluations[i];
            }
        } else {
            // handle subsequent layers
            layer_queries_lookups[depth] = MultiIndexLookup(num_queries, num_queries);
            for (var j = 0; j < num_queries; j++) {
                layer_queries_lookups[depth].in[j] <== folded_positions[depth].out[j];
                layer_queries_lookups[depth].mask[j] <== folded_positions[depth].out_mask[j];
            }

            layer_query_selectors[depth] = MultiSelector(num_queries * folding_factor, num_queries);
            for (var i = 0; i < num_queries * folding_factor; i++) {
                layer_query_selectors[depth].in[i] <== fri_layer_queries[depth][i];
            }

            for (var i = 0; i < num_queries; i++) {
                // integer division of position (folded_positions[depth - 1].out[i]) by row_length
                layer_queries_divisions[depth][i] = IntegerDivision(row_length, fri_tree_depths[depth - 1]);
                layer_queries_divisions[depth][i].in <== folded_positions[depth - 1].out[i];

                // find index of position % row_length in folded_positions[depth]
                layer_queries_lookups[depth].lookup[i] <== layer_queries_divisions[depth][i].remainder;
            }
            for (var i = 0; i < num_queries; i++) {
                // pick fri_layer_queries[depth][idx * folding_factor + position \ row_length]
                // (where idx = layer_queries_lookups[depth][i].out)
                layer_query_selectors[depth].indexes[i] <== layer_queries_lookups[depth].out[i] * folding_factor + layer_queries_divisions[depth][i].quotient;
            }
            for (var i = 0; i < num_queries; i++) {
                // verify that query_values == deep_evaluations
                // (where query_values = layer_query_selectors[depth].out)
                // the mask is used to rule out values beyond the actual folded positions
                (layer_query_selectors[depth].out[i] - evaluations[depth - 1][i].out) * folded_positions[depth - 1].out_mask[i] === 0;
            }
        }

        // BUILD A SET OF COORDINATES FOR EACH ROW POLYNOMIAL
        // AND INTERPOLATE INTO ROW POLYNOMIALS
        coordinate_interpolators[depth] = BatchInterpolate(num_queries, folding_factor);
        coordinate_pow_selectors[depth] = MultiSelector(lde_domain_size, num_queries);
        for (var i = 0; i < lde_domain_size; i++) {
            coordinate_pow_selectors[depth].in[i] <== x_pow[i];
        }
        for (var i = 0; i < num_queries; i++) {
            coordinate_pow_selectors[depth].indexes[i] <== folded_positions[depth].out[i] * domain_generator_offset;
        }
        for (var i = 0; i < num_queries; i++) {
            coordinates_xe[depth][i] <== coordinate_pow_selectors[depth].out[i] * domain_offset;

            for (var j = 0; j < folding_factor; j++) {
                coordinate_interpolators[depth].xs[i][j] <== coordinates_xe[depth][i] * folding_roots.out[j];
                coordinate_interpolators[depth].ys[i][j] <== fri_layer_queries[depth][i * folding_factor + j];
            }
        }

        for (var i = 0; i < num_queries; i++) {
            evaluations[depth][i] = Evaluate(folding_factor);
            evaluations[depth][i].x <== layer_alphas[depth];
            for (var j = 0; j < folding_factor; j++) {
                evaluations[depth][i].p[j] <== coordinate_interpolators[depth].out[i][j];
            }
        }

        // make sure the next degree reduction does not result in truncation
        max_degree_plus_1[depth + 1] <-- max_degree_plus_1[depth] \ folding_factor;
        max_degree_plus_1[depth + 1] * folding_factor === max_degree_plus_1[depth];

        // prepare next layer
        domain_size = target_domain_size;
        domain_generator_offset *= folding_factor;
    }


    // 2 - VERIFY THE REMAINDER OF THE FRI PROOF
    // ==========================================================================

    // check remainder values against last level evaluations
    remainder_selectors = MultiSelector(remainder_size, num_queries);
    for (var i = 0; i < remainder_size; i++) {
        remainder_selectors.in[i] <== fri_remainder[i];
    }
    for (var i = 0; i < num_queries; i++) {
        remainder_selectors.indexes[i] <== folded_positions[num_fri_layers - 1].out[i];
    }
    for (var i = 0; i < num_queries; i++) {
        (remainder_selectors.out[i] - evaluations[num_fri_layers - 1][i].out) * folded_positions[num_fri_layers - 1].out_mask[i] === 0;
    }

    // transpose remainder into a matrix of width folding_factor and hash each line
    var remainder_leaves_size = remainder_size \ folding_factor;
    for (var i = 0; i < remainder_leaves_size; i++) {
        remainder_hashers[i] = Poseidon(folding_factor);
    }
    for (var i = 0; i < remainder_leaves_size; i++) {
        for (var j = 0; j < folding_factor; j++) {
            remainder_hashers[i].in[j] <== fri_remainder[i + j * remainder_leaves_size];
        }
    }

    // verify remainder commitment
    remainder_merkle_tree = MerkleTree(remainder_leaves_size);
    for (var i = 0; i < remainder_leaves_size; i++) {
        remainder_merkle_tree.leaves[i] <== remainder_hashers[i].out;
    }
    remainder_merkle_tree.root === fri_commitments[num_fri_layers];

    // VERIFY REMAINDER DEGREE

    // make sure that remainder max degree < remainder length - 1
    // remainder max degree is max_degree_plus_1[num_fri_layers] - 1
    remainder_length_lt = LessThan(tree_depth);
    remainder_length_lt.in[0] <== max_degree_plus_1[num_fri_layers];
    remainder_length_lt.in[1] <== remainder_size;
    remainder_length_lt.out === 1;

    // interpolate fri_remainder
    remainder_interpolation = FFTInterpolate(addicity, remainder_size);
    remainder_interpolation.addicity_root <== addicity_root;
    for (var i = 0; i < remainder_size; i++) {
        remainder_interpolation.ys[i] <== fri_remainder[i];
    }

    // calculate the degree of the remainder
    remainder_degree = PolynomialDegree(remainder_size);
    for (var i = 0; i < remainder_size; i++) {
        remainder_degree.in[i] <== remainder_interpolation.out[i];
    }

    // make sure that remainder degree <= max degree (max_degree_plus_1[num_fri_layers] - 1)
    remainder_degree_lt = LessThan(tree_depth);
    remainder_degree_lt.in[0] <== remainder_degree.out;
    remainder_degree_lt.in[1] <== max_degree_plus_1[num_fri_layers];
    remainder_degree_lt.out === 1;
}
