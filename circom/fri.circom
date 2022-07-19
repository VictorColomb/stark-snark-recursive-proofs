pragma circom 2.0.4;

include "utils.circom";
include "merkle.circom";

template FriVerifier(
    addicity,
    domain_offset,
    folding_factor,
    fri_num_queries,
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
    component layer_queries_lookups[num_fri_layers][num_queries];
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
            folded_positions[0] = RemoveDuplicates(num_queries, fri_num_queries[0]);

            for (var j = 0; j < num_queries; j++) {
                folded_position_modulos[0][j] = IntegerDivision(target_domain_size, tree_depth);
                folded_position_modulos[0][j].in <== query_positions[j];
                folded_positions[depth].in[j] <== folded_position_modulos[depth][j].remainder;
            }
        } else {
            // for all consequent FRI layers, fold previous folded_positions
            folded_positions[depth] = RemoveDuplicates(fri_num_queries[depth - 1], fri_num_queries[depth]);

            for (var j = 0; j < fri_num_queries[depth - 1]; j++) {
                folded_position_modulos[depth][j] = IntegerDivision(target_domain_size, tree_depth);
                folded_position_modulos[depth][j].in <== folded_positions[depth - 1].out[j];
                folded_positions[depth].in[j] <== folded_position_modulos[depth][j].remainder;
            }
        }

        // VERIFY FRI LAYER COMMITMENT
        layer_commitment_verifiers[depth] = MerkleOpeningsVerify(fri_num_queries[depth], fri_tree_depths[depth], folding_factor);
        layer_commitment_verifiers[depth].root <== fri_commitments[depth];
        for (var i = 0; i < fri_num_queries[depth]; i++) {
            layer_commitment_verifiers[depth].indexes[i] <== folded_positions[depth].out[i];
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
            layer_query_selectors[0] = MultiSelector(fri_num_queries[0] * folding_factor, num_queries);
            for (var i = 0; i < fri_num_queries[0] * folding_factor; i++) {
                layer_query_selectors[0].in[i] <== fri_layer_queries[0][i];
            }
            for (var i = 0; i < num_queries; i++) {
                // integer division of position (query_positions[i]) by row_length
                layer_queries_divisions[0][i] = IntegerDivision(row_length, tree_depth);
                layer_queries_divisions[0][i].in <== query_positions[i];

                // find index of position % row_length in query_positions
                layer_queries_lookups[0][i] = IndexLookup(fri_num_queries[0]);
                layer_queries_lookups[0][i].lookup <== layer_queries_divisions[0][i].remainder;
                for (var j = 0; j < fri_num_queries[0]; j++) {
                    layer_queries_lookups[0][i].in[j] <== folded_positions[0].out[j];
                }

                // pick fri_layer_queries[depth][idx * folding_factor + position \ row_length]
                // (where idx = layer_queries_lookups[depth][i].out)
                layer_query_selectors[0].indexes[i] <== layer_queries_lookups[0][i].out * folding_factor + layer_queries_divisions[0][i].quotient;
            }
            for (var i = 0; i < num_queries; i++) {
                // verify that query_values == deep_evaluations
                // (where query_values = layer_query_selectors[depth][?].out)
                layer_query_selectors[0].out[i] === deep_evaluations[i];
            }
        } else {
            // handle subsequent layers
            layer_query_selectors[depth] = MultiSelector(fri_num_queries[depth] * folding_factor, fri_num_queries[depth - 1]);
            for (var i = 0; i < fri_num_queries[depth] * folding_factor; i++) {
                layer_query_selectors[depth].in[i] <== fri_layer_queries[depth][i];
            }
            for (var i = 0; i < fri_num_queries[depth - 1]; i++) {
                // integer division of position (folded_positions[depth - 1].out[i]) by row_length
                layer_queries_divisions[depth][i] = IntegerDivision(row_length, fri_tree_depths[depth - 1]);
                layer_queries_divisions[depth][i].in <== folded_positions[depth - 1].out[i];

                // find index of position % row_length in folded_positions[depth]
                layer_queries_lookups[depth][i] = IndexLookup(fri_num_queries[depth]);
                layer_queries_lookups[depth][i].lookup <== layer_queries_divisions[depth][i].remainder;
                for (var j = 0; j < fri_num_queries[depth]; j++) {
                    layer_queries_lookups[depth][i].in[j] <== folded_positions[depth].out[j];
                }

                // pick fri_layer_queries[depth][idx * folding_factor + position \ row_length]
                // (where idx = layer_queries_lookups[depth][i].out)
                layer_query_selectors[depth].indexes[i] <== layer_queries_lookups[depth][i].out * folding_factor + layer_queries_divisions[depth][i].quotient;
            }
            for (var i = 0; i < fri_num_queries[depth - 1]; i++) {
                layer_query_selectors[depth].out[i] === evaluations[depth - 1][i].out;
            }
        }

        // BUILD A SET OF COORDINATES FOR EACH ROW POLYNOMIAL
        // AND INTERPOLATE INTO ROW POLYNOMIALS
        coordinate_interpolators[depth] = BatchInterpolate(fri_num_queries[depth], folding_factor);
        coordinate_pow_selectors[depth] = MultiSelector(lde_domain_size, fri_num_queries[depth]);
        for (var i = 0; i < lde_domain_size; i++) {
            coordinate_pow_selectors[depth].in[i] <== x_pow[i];
        }
        for (var i = 0; i < fri_num_queries[depth]; i++) {
            coordinate_pow_selectors[depth].indexes[i] <== folded_positions[depth].out[i] * domain_generator_offset;
        }
        for (var i = 0; i < fri_num_queries[depth]; i++) {
            coordinates_xe[depth][i] <== coordinate_pow_selectors[depth].out[i] * domain_offset;

            for (var j = 0; j < folding_factor; j++) {
                coordinate_interpolators[depth].xs[i][j] <== coordinates_xe[depth][i] * folding_roots.out[j];
                coordinate_interpolators[depth].ys[i][j] <== fri_layer_queries[depth][i * folding_factor + j];
            }
        }

        for (var i = 0; i < fri_num_queries[depth]; i++) {
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
    remainder_selectors = MultiSelector(remainder_size, fri_num_queries[num_fri_layers - 1]);
    for (var i = 0; i < remainder_size; i++) {
        remainder_selectors.in[i] <== fri_remainder[i];
    }
    for (var i = 0; i < fri_num_queries[num_fri_layers - 1]; i++) {
        remainder_selectors.indexes[i] <== folded_positions[num_fri_layers - 1].out[i];
    }
    for (var i = 0; i < fri_num_queries[num_fri_layers - 1]; i++) {
        remainder_selectors.out[i] === evaluations[num_fri_layers - 1][i].out;
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
    remainder_interpolation = FFTInterpolate(remainder_size, addicity);
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

/**
 * Interpolate a polynomial, using Lagrange interpolation.
 *
 * ARGUMENTS: N
 * INPUTS: xs[N], ys[N]
 * OUPTUTS: out[N]
 */
template Interpolate(N) {
    signal input xs[N];
    signal input ys[N];
    signal output out[N];

    signal denominators[N];
    signal numerators[N][N];
    signal res[N - 1][N];
    signal roots[N + 1];
    signal roots_temp[N - 1][N];
    signal y_inv[N];

    component to_inverse[N];

    assert(N > 1);

    // ROOTS
    // first row
    var n = N - 1;
    roots_temp[0][n] <== - xs[0];

    // middle rows
    for (var i = 1; i < N - 1; i++) {
        n -= 1;
        roots_temp[i][n] <== - roots_temp[i - 1][n + 1] * xs[i];
        for (var j = n + 1; j < N - 1; j++) {
            roots_temp[i][j] <== roots_temp[i - 1][j] - roots_temp[i - 1][j + 1] * xs[i];
        }
        roots_temp[i][N - 1] <== roots_temp[i - 1][N - 1] - xs[i];
    }

    // last row (i = N - 1)
    roots[0] <== - roots_temp[N - 2][1] * xs[N - 1];
    for (var j = 1; j < N - 1; j++) {
        roots[j] <== roots_temp[N - 2][j] - roots_temp[N - 2][j + 1] * xs[N - 1];
    }
    roots[N - 1] <== roots_temp[N - 2][N - 1] - xs[N - 1];

    // NUMERATORS
    for (var i = 0; i < N; i++) {
        numerators[i][N - 1] <== 1;
        for (var j = N - 2; j >= 0; j--) {
            numerators[i][j] <== roots[j + 1] + xs[i] * numerators[i][j + 1];
        }
    }

    // DENOMINATORS
    for (var i = 0; i < N; i++) {
        to_inverse[i] = Evaluate(N);
        to_inverse[i].x <== xs[i];
        for (var j = 0; j < N; j++) {
            to_inverse[i].p[j] <== numerators[i][j];
        }

        denominators[i] <-- 1 / to_inverse[i].out;
        denominators[i] * to_inverse[i].out === 1;
    }

    // RESULT
    for(var i = 0; i < N; i++) {
        y_inv[i] <== ys[i] * denominators[i];
    }

    for (var j = 0; j < N; j++) { // first row (i = 0)
        res[0][j] <== numerators[0][j] * y_inv[0];
    }
    for(var i = 1; i < N - 1; i++) { // middle rows
        for (var j = 0; j < N; j++) {
            res[i][j] <== res[i - 1][j] + numerators[i][j] * y_inv[i];
        }
    }
    for (var j = 0; j < N; j++) { // last row (i = N - 1)
        out[j] <== res[N - 2][j] + numerators[N - 1][j] * y_inv[N - 1];
    }
}

/**
 * Interpolate a batch of polynomials, using Lagrange interpolation.
 *
 * INPUTS:
 * - xs: positions of interpolation for each polynomial
 * - ys: values of interpolation for each polynomial
 *
 * OUTPUTS: out
 */
template BatchInterpolate(amount, N) {
    signal input xs[amount][N];
    signal input ys[amount][N];
    signal output out[amount][N];

    component interpolations[amount];

    for (var i = 0; i < amount; i++) {
        interpolations[i] = Interpolate(N);
        for (var j = 0; j < N; j++) {
            interpolations[i].xs[j] <== xs[i][j];
            interpolations[i].ys[j] <== ys[i][j];
        }
        for (var j = 0; j < N; j++) {
            out[i][j] <== interpolations[i].out[j];
        }
    }
}

/**
 * Evaluate a polynomial, using Horner evaluation.
 *
 * INPUTS:
 * - p: coefficients of the polynomial to evaluate
 * - x: evaluation position
 *
 * OUTPUTS: out
 */
template Evaluate(N) {
    signal input p[N];
    signal input x;
    signal output out;

    signal t[N];

    for (var i = N - 1; i >= 0; i--) {
        if (i == N - 1) {
            t[i] <== p[i];
        } else {
            t[i] <== t[i + 1] * x + p[i];
        }
    }

    out <== t[0];
}

/**
 * Calculate half of the n-th roots of unity.
 *
 * ARGUMENTS:
 * - n: order of the required roots of unity
 * - addicity: log2 of the order of the largest multiplicative sub-group
 *
 * INPUTS:
 * - addicity_root: 2**addicity root of unity
 *
 * OUTPUTS:
 * - out[n\2]: first half of the n-th roots of unity
 */
template GetInvTwiddles(n, addicity) {
    signal input addicity_root;
    signal output out[n \ 2];

    component root;
    component inv_root;
    component powers[n \ 2 - 1];

    // calculate inverse twiddles
    var log2_n = numbits(n) - 1;
    assert(log2_n <= addicity);

    root = Pow(2 ** (addicity - log2_n));
    root.in <== addicity_root;

    inv_root = Pow(n - 1);
    inv_root.in <== root.out;

    out[0] <== 1;
    out[1] <== inv_root.out;
    for (var i = 2; i < n\2; i++) {
        out[i] <== out[i - 1] * inv_root.out;
    }
}

/**
 * Interpolate values on roots of unity.
 */
template FFTInterpolate(N, addicity) {
    signal input addicity_root;
    signal input ys[N];
    signal output out[N];

    assert(N % 2 == 0);

    component twiddles = GetInvTwiddles(N, addicity);
    twiddles.addicity_root <== addicity_root;

    component I = Interpolate(N);
    for (var i = 0; i < N; i++) {
        I.ys[i] <== ys[i];
    }
    for(var i = 0; i < N\2; i++) {
        I.xs[i] <== twiddles.out[i];
        I.xs[N\2 + i] <== - twiddles.out[i];
    }

    out[0] <== I.out[0];
    for (var i = 1; i < N; i++) {
        out[i] <== I.out[N - i];
    }
}

/**
 * Get the degree of a polynomial, aka. count the number of leading zeroes and
 * substract that from N - 1.
 */
template PolynomialDegree(N) {
    signal input in[N];
    signal output out;

    signal a[N];

    component lt[N];

    // check if each coefficient is zero, reversing the order
    for (var i = 0; i < N; i++) {
        lt[i] = IsZero();
        lt[i].in <== in[N - i - 1];
    }

    // get leading zeroes
    // b[i] <== b[i - 1] * a[i] so if at any point a coefficient is not zero, all subsequent
    // b[j] will be zeroes. at the end, there will be as many b[j] == 1 as leading zeroes
    a[0] <== lt[0].out;
    for (var i = 1; i < N; i++) {
        a[i] <== a[i - 1] * lt[i].out;
    }

    // sum b elements and return
    var result = 0;
    for (var i = 0; i < N; i++) {
        result += a[i];
    }
    out <== N - result - 1;
}

// /**
//  * Permutation, for twiddles before and result after FFT.
//  */
// template Permute(N) {
//     signal input in[N];
//     signal output out[N];
//
//     var N2 = N \ 2;
//     var log2_N = numbits(N);
//
//     out[0] <== in[0];
//     out[1] <== in[N \ 2];
//
//     var k = 2;
//     for (var i = 1; i < log2_N; i++) {
//         for (var j = 1; j < 2**i; j += 2) {
//             out[k] <== in[N2 \ (2**i) * j];
//             out[k + 1] <== in[N2 + N2 \ (2**i) * j];
//         }
//     }
// }
