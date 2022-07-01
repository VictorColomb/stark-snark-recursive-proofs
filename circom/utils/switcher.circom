pragma circom 2.0.4;

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
