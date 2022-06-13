pragma circom 2.0.4;

/*
 * Compute power 5
 */
template Pow5() {
    signal input in;
    signal pow2;
    signal pow4;
    signal output out;

    pow2 <== in * in;
    pow4 <== pow2 * pow2;
    out <== pow4 * in;
}

/*
 * Compute 5th root
 */
template PowM5() {
    signal input in;
    signal output out;

    component pow5;
    pow5 = Pow5();
    pow5.in <-- in ** 17510594297471420177797124596205820070838691520332827474958563349260646796493;

    pow5.out === in;
    out <== pow5.in;
}
