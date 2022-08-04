pragma circom 2.0.0;

include "bits.circom";


/**
 * Exponentiation where the exponent is not a signal.
 *
 * Usable whenever the exponent only depends on circuit parameters but not the input.
 * Always use this when possible as it will generate ~log2(exp) constraints, which is
 * much less than the exponentiation with signal.
 *
 * ARGUMENTS:
 * - exp: the exponent to raise the input to.
 *
 * INPUTS:
 * - in: x
 *
 * OUTPUTS:
 * - out: x**exp
 */
template Pow(exp) {
    signal input in;

    signal output out;

    // converting exponent to bits
    var buffer_size = 0;
    var bits[255];
    var c = exp;

    while (c != 0) {
        bits[buffer_size] = c & 1;
        c \= 2;
        buffer_size += 1;
    }

    signal pow[buffer_size];
    signal inter[buffer_size];
    signal temp[buffer_size-1];

    pow[0] <== in;
    inter[0] <== pow[0] * bits[0] + (1 - bits[0]);

    for (var i = 1; i < buffer_size; i++) {
        pow[i] <== pow[i-1] * pow[i-1];
        temp[i-1] <== pow[i] * bits[i] + (1 - bits[i]);
        inter[i] <==  inter[i-1] * temp[i-1];
    }

    out <== inter[buffer_size - 1];
}


/**
 * Exponentiation with a signal as exponent.
 *
 * ARGUMENTS:
 * - n: buffer size needed to convert exp in bits
 *
 * INPUTS:
 * - in: x
 * - exp: exponent
 *
 * OUTPUTS:
 * - out: x**exp
 */
template Pow_signal(n) {
    signal input in;
    signal input exp;

    signal output out;

    component n2b = Num2Bits(n);
    n2b.in <== exp;
    signal pow[n];
    signal inter[n];
    signal temp[n];

    pow[0] <== in;
    temp[0] <== pow[0] * n2b.out[0] + (1 - n2b.out[0]);
    inter[0] <== temp[0];

    for (var i = 1; i < n; i++) {
        pow[i] <== pow[i-1] * pow[i-1];
        temp[i] <== pow[i] * n2b.out[i] + (1 - n2b.out[i]);
        inter[i] <==  inter[i-1] * temp[i];
    }

    out <== inter[n-1];
}


/**
 * Number of bits of an field element.
 */
function numbits(n) {
    var k = 0;
    while (n != 0) {
        n \= 2;
        k += 1;
    }
    return k;
}
