// TODO: find a faster exponentiation implementation

pragma circom 2.0.4;

include "./poseidon/poseidon.circom";

// b0 * a + (1 - b0)
template Pow(a) {
    signal input in;
    signal output out;

    signal inter[a - 1];

    if (a == 1) {
        out <== in;
    } else {
        inter[0] <== in * in;

        for (var i = 1; i < a - 1; i++) {
            inter[i] <== inter[i-1] * in;
        }


        out <== inter[a-2];
    }


}


component main = Pow(100000);