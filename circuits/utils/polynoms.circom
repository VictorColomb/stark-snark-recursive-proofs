pragma circom 2.0.0;

include "comparators.circom";
include "powers.circom";


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
 * Interpolate values on roots of unity.
 */
template FFTInterpolate(addicity, N) {
    signal input addicity_root;
    signal input ys[N];
    signal output out[N];

    signal twiddles[N];
    component root;
    component inv_root;

    assert(N % 2 == 0);
    var N2 = N \ 2;


    // CALCULATE INVERSE TWIDDLES

    var log2_n = numbits(N) - 1;
    assert(log2_n <= addicity);

    root = Pow(2 ** (addicity - log2_n));
    root.in <== addicity_root;

    inv_root = Pow(N - 1);
    inv_root.in <== root.out;

    twiddles[0] <== 1;
    twiddles[1] <== inv_root.out;
    for (var i = 2; i < N2; i++) {
        twiddles[i] <== twiddles[i - 1] * inv_root.out;
    }
    for (var i = 0; i < N2; i++) {
        twiddles[N2 + i] <== - twiddles[i];
    }

    // INTERPOLATE
    component I = Interpolate(N);
    for(var i = 0; i < N; i++) {
        I.xs[i] <== twiddles[i];
    }
    for (var i = 0; i < N; i++) {
        I.ys[i] <== ys[i];
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
