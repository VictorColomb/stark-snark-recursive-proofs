pragma circom 2.0.0;

include "poseidon/poseidon.circom";
include "utils.circom";


/**
 * Verify the validity of a Merkle opening, given the leaves,
 * the missing nodes and the expected root.
 *
 * INPUTS
 * - index: the index of the leaf to check in the original tree
 * - opening[depth + 1]: the authentication path to verify. the first element being the leaf
 * - root: the expected root of the tree
 */
template MerkleOpeningVerify(depth, leaf_size) {
    signal input index;
    signal input leaf[leaf_size];
    signal input opening[depth];
    signal input root;

    component index_bits = Num2Bits(depth);
    component node_index_bits = Num2Bits(depth + 1);
    component switch[depth];
    component P[depth];
    component P_leaf = Poseidon(leaf_size);

    var n = 2 ** depth;

    // hash leaf
    for (var i = 0; i < leaf_size; i++) {
        P_leaf.in[i] <== leaf[i];
    }

    // turn index into LE bits
    index_bits.in <== index;
    node_index_bits.in <== index + n;

    // switch over index parity (1st bit)
    switch[0] = Switcher();
    switch[0].sel <== index_bits.out[0];
    switch[0].L <== P_leaf.out;
    switch[0].R <== opening[0];

    // hash leaves
    P[0] = Poseidon(2);
    P[0].in[0] <== switch[0].outL;
    P[0].in[1] <== switch[0].outR;

    for (var i = 1; i < depth; i++) {
        // switch over (index >> i) parity (i-th bit)
        switch[i] = Switcher();
        switch[i].sel <== index_bits.out[i];
        switch[i].L <== P[i - 1].out;
        switch[i].R <== opening[i];

        // hash previous hash and node
        P[i] = Poseidon(2);
        P[i].in[0] <== switch[i].outL;
        P[i].in[1] <== switch[i].outR;
    }

    P[depth - 1].out === root;
}

/**
 * Verify the validity of a number of Merkle openings, against a given root.
 *
 * INPUTS:
 * - root: the expected root of the tree
 * - openings[amount][depth + 1]: the authentication paths to verify, the
                                  first element of each being the leaf
 * - indexes[amount]: the indexes of the authentication paths
 */
template MerkleOpeningsVerify(amount, depth, leaf_size) {
    signal input indexes[amount];
    signal input leaves[amount][leaf_size];
    signal input openings[amount][depth];
    signal input root;

    component V[amount];

    for (var i = 0; i < amount; i++) {
        V[i] = MerkleOpeningVerify(depth, leaf_size);
        V[i].index <== indexes[i];
        V[i].root <== root;
        for (var j = 0; j < leaf_size; j++) {
            V[i].leaf[j] <== leaves[i][j];
        }
        for (var j = 0; j < depth; j++) {
            V[i].opening[j] <== openings[i][j];
        }
    }
}

/**
 * Compute the layer of a Poseidon-based Merkle tree.
 *
 * ARGUMENTS:
 * - N: number of children nodes (must be even)
 *
 * INPUTS: children[N]
 * OUTPUTS: parents[N \ 2]
 */
template MerkleTreeLayer(N) {
    signal input children[N];
    signal output parents[N \ 2];

    component hash[N \ 2];

    assert(N & 1 == 0);

    for (var i = 0; i < N\2; i++) {
        hash[i] = Poseidon(2);
        hash[i].in[0] <== children[2 * i];
        hash[i].in[1] <== children[2 * i + 1];
        parents[i] <== hash[i].out;
    }
}

/**
 * Compute a Merkle tree root.
 *
 * ARGUMENTS:
 * - N: number of leaves. It must be a power of two.
 *
 * INPUTS: leaves[N]
 * OUTPUTS: root
 */
template MerkleTree(N) {
    signal input leaves[N];
    signal output root;

    var size = N;
    var depth = 0;
    while (2 ** depth < N) {
        depth += 1;
    }

    component layer[depth];

    // build first layer
    layer[0] = MerkleTreeLayer(N);
    for (var j = 0; j < N; j++) {
        layer[0].children[j] <== leaves[j];
    }
    size \= 2;

    // build all subsequent layers
    for (var i = 1; i < depth; i++) {
        layer[i] = MerkleTreeLayer(size);
        for (var j = 0; j < size; j++) {
            layer[i].children[j] <== layer[i - 1].parents[j];
        }
        size \= 2;
    }

    // check that we have reached the root
    // TODO: remove check (if the code is correct the check is useless)
    assert(size == 1);

    root <== layer[depth - 1].parents[0];
}
