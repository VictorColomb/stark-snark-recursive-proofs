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

template Num2Bits(n) {
    signal input in;
    signal output out[n];
    var lc1=0;

    var e2=1;
    for (var i = 0; i<n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] -1 ) === 0;
        lc1 += out[i] * e2;
        e2 = e2+e2;
    }

    lc1 === in;
}


component main = Pow(100000);