pragma circom 2.0.0;

include "bits.circom";


template IsZero() {
    signal input in;
    signal output out;

    signal inv;

    inv <-- in != 0 ? 1/in : 0;

    out <== - in*inv + 1;
    in * out === 0;
}

template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();

    in[1] - in[0] ==> isz.in;

    isz.out ==> out;
}

/**
 * Compare two field elements.
 *
 * INPUTS:
 * - in[2]: the two field elements to compare
 *
 * OUTPUTS:
 * - out: 1 if the first input is smaller, 0 otherwise
 */
template LessThan(n) {
    assert(n <= 254);
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n+1);

    n2b.in <== in[0] + (1<<n) - in[1];

    out <== 1 - n2b.out[n];
}

/**
 * If sel == 0 then outL = L and outR = R
 * If sel == 1 then outL = R and outR = L
 */
template Switcher() {
    signal input sel;
    signal input L;
    signal input R;
    signal output outL;
    signal output outR;

    signal aux;

    aux <== (R - L) * sel;
    outL <== L + aux;
    outR <== R - aux;
}
