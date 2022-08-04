pragma circom 2.0.0;

/**
 * Convert a field element into binary representation.
 *
 * ARGUMENTS:
 * - n: buffer size. must be greater than log2 of the input
 */
template Num2Bits(n) {
    signal input in;
    signal output out[n];
    var lc1 = 0;

    var e2 = 1;
    for (var i = 0; i < n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] - 1) === 0;
        lc1 += out[i] * e2;
        e2 = e2 + e2;
    }

    lc1 === in;
}

/**
 * Convert a binary representation into a field element.
 *
 * ARGUMENTS:
 * - n: input length (number of bits)
 */
template Bits2Num(n) {
    signal input in[n];
    signal output out;
    var lc1=0;

    var e2 = 1;
    for (var i = 0; i < n; i++) {
        lc1 += in[i] * e2;
        e2 = e2 + e2;
    }

    lc1 ==> out;
}
