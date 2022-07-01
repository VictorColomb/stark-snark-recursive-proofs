pragma circom 2.0.4;

include "poseidon/poseidon.circom";
include "utils/switcher.circom";
include "utils/bitify.circom";


/**
 * Verify the validity of a Merkle opening, given the leaves,
 * the missing nodes and the expected root.
 */
template MerkleOpeningVerify(depth) {
    signal input index;
    signal input opening[depth + 1];
    signal input root;
    signal output out;

    component index_bits = Num2Bits(depth);
    component node_index_bits = Num2Bits(depth + 1);
    component switch[depth];
    component P[depth];

    var n = 2 ** depth;

    // turn index into LE bits
    index_bits.in <== index;
    node_index_bits.in <== index + n;

    // switch over index parity (1st bit)
    switch[0] = Switcher();
    switch[0].sel <== index_bits.out[0];
    switch[0].L <== opening[0];
    switch[0].R <== opening[1];

    // hash leaves
    P[0] = Poseidon(2);
    P[0].in[0] <== switch[0].outL;
    P[0].in[1] <== switch[0].outR;

    for (var i = 1; i < depth; i++) {
        // switch over (index >> i) parity (i-th bit)
        switch[i] = Switcher();
        switch[i].sel <== index_bits.out[i];
        switch[i].L <== P[i - 1].out;
        switch[i].R <== opening[i + 1];

        // hash previous hash and node
        P[i] = Poseidon(2);
        P[i].in[0] <== switch[i].outL;
        P[i].in[1] <== switch[i].outR;
    }

    P[depth - 1].out === root;
}

template MerkleOpeningsVerify(amount, depth) {
    signal input indexes[amount];
    signal input openings[amount][depth + 1];
    signal input root;

    component V[amount];

    for (var i = 0; i < amount; i++) {
        V[i] = MerkleOpeningVerify(depth);
        V[i].index <== indexes[i];
        V[i].root <== root;
        for (var j = 0; j <= depth; j++) {
            V[i].opening[j] <== openings[i][j];
        }
    }
}
