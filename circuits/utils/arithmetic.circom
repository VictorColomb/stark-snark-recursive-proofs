pragma circom 2.0.0;

include "comparators.circom";


/**
 * Perform an integer division on a field element, providing the quotient and
 * the remainder.
 *
 * ARGUMENTS:
 * - M: modulo
 * - n: the number of bits of the field element.
 *
 * INPUTS: in
 * OUTPUTS: quotient, remainder
 */
template IntegerDivision(M, n) {
    signal input in;
    signal output quotient;
    signal output remainder;

    component lt = LessThan(n);

    remainder <-- in % M;
    quotient <-- in \ M;

    in === quotient * M + remainder;
    lt.in[0] <== remainder;
    lt.in[1] <== M;
    lt.out === 1;
}
