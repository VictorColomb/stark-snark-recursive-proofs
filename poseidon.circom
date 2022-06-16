pragma circom 2.0.4;

include "param.circom";
include "power5.circom";

template PoseidonHashWrapper(l, c) {
    signal input in[l];
    var m = m();
    var rate = m - c;
    signal output out[rate];

    var padded_l = (l\rate + 1) * rate;
    component rescue = PoseidonHash(padded_l, m, c);

    // input l elements
    for (var i = 0; i < l; i++) {
        rescue.in[i] <== in[i];
    }
    // add a single 1
    rescue.in[l] <== 1;
    // pad with zeroes
    for (var i = l+1; i < padded_l; i++) {
        rescue.in[i] <== 0;
    }

    // output
    for (var j = 0; j < rate; j++) {
        out[j] <== rescue.out[j];
    }
}

/*
 * Poseidon hash.
 *
 * Input size has to be a multiple of rate = m-c !!
 */
template PoseidonHash(l, m, c) {
    signal input in[l];
    var rate = m - c;
    signal output out[rate];

    assert(l % rate == 0);

    component permutation[l \ rate];
    signal state[2*(l\rate) + 1][m];

    var Rf = Rf();
    var Rp = Rp();
    var round_constants[(2*Rf+Rp)*m] = get_round_constants();
    var MDS[m][m] = get_mds();

    for (var i = 0; i < m; i++) {
        state[0][i] <== 0;
    }

    // absorbing and permutation
    for (var i = 0; i < l\rate; i++) {
        // absorb rate elements into the state
        for (var j = 0; j < rate; j++) {
            state[2*i+1][j] <== state[2*i][j] + in[i*rate+j];
        }
        // copy the other elements
        for (var j = rate; j < m; j++) {
            state[2*i+1][j] <== state[2*i][j];
        }

        // apply the permutation
        permutation[i] = PoseidonPermutation(m, Rf, Rp, MDS, round_constants);
        for (var j = 0; j < m; j++) {
            permutation[i].in[j] <== state[2*i+1][j];
        }
        for (var j = 0; j < m; j++) {
            state[2*i+2][j] <== permutation[i].out[j];
        }
    }

    // output
    for (var k = 0; k < rate; k++) {
        out[k] <== state[2*(l/rate)][k];
    }
}


/*
 * Poseidon permutation (Rf full rounds, Rp partial rounds and Rf full rounds again).
 */
template PoseidonPermutation(m, Rf, Rp, MDS, round_constants) {
    signal input in[m];
    signal inter[2*Rf + Rp - 1][m];
    signal output out[m];

    component fullPerm[2*Rf];
    component partialPerm[Rp];

    // first permutation (full)
    fullPerm[0] = PoseidonPermutationFullRound(m, 0, MDS, round_constants);
    for (var j = 0; j < m; j++) {
        fullPerm[0].in[j] <== in[j];
    }
    for (var j = 0; j < m; j++) {
        inter[0][j] <== fullPerm[0].out[j];
    }

    // full permutations
    for (var i = 1; i < Rf; i++) {
        fullPerm[i] = PoseidonPermutationFullRound(m, i, MDS, round_constants);
        for (var j = 0; j < m; j++) {
            fullPerm[i].in[j] <== inter[i-1][j];
        }
        for (var j = 0; j < m; j++) {
            inter[i][j] <== fullPerm[i].out[j];
        }
    }

    //first round of partial permutations

    for (var j = 0; j < m; j++) {
        inter[Rf] <== in[j] + round_constants[i*m + j];
    }

     /* FIXME: INSERT MATRIX MUL BY MP */

    // partial permutations
    for (var i = 1 ; i < Rp - 1; i++) {
        partialPerm[i] = PoseidonPermutationPartialRound(m, Rf+i, MDS, round_constants);
        for (var j = 0; j < m; j++) {
            partialPerm[i].in[j] <== inter[Rf + i-1][j];
        }
        for (var j = 0; j < m; j++) {
            inter[Rf + i][j] <== partialPerm[i].out[j];
        }
    }

    //last partial permutation
    //TODO: passage de seulement une valeur - nom pour que les indices de inter restent relevants.
    component p = pow5();
    p.in <== inter[Rf + Rp -2][0];
    p.out ==> inter[Rf + Rp - 1][0];

    for(var p = 1; p < m; p+=1){ 
         inter[Rf + Rp - 1][p] <== inter[Rf + Rp - 2][p];
    }

    component m_ms = SparseMatrixMul();
    for(var i = 0; i < m; i +=1){ 
        m_ms.in[i] <== inter[Rf + Rp - 1][i];
    }
    for(var i = 0; i < m; i +=1){ 
        m_ms.out[i] ==> inter[Rf + Rp][i];
    }


    // full permutations
    for (var i = 0; i < Rf-1; i++) {
        fullPerm[Rf + i] = PoseidonPermutationFullRound(m, Rf+Rp+i, MDS, round_constants);
        for (var j = 0; j < m; j++) {
            fullPerm[Rf + i].in[j] <== inter[Rf+Rp + i-1][j];
        }
        for (var j = 0; j < m; j++) {
            inter[Rf+Rp + i][j] <== fullPerm[Rf + i].out[j];
        }
    }

    // last permutation (full)
    fullPerm[2*Rf - 1] = PoseidonPermutationFullRound(m, 2*Rf+Rp-1, MDS, round_constants);
    for (var j = 0; j < m; j++) {
        fullPerm[2*Rf - 1].in[j] <== inter[2*Rf+Rp - 2][j];
    }
    for (var j = 0; j < m; j++) {
        out[j] <== fullPerm[2*Rf - 1].out[j];
    }
}

/*
 * Poseidon permutation full S-box round:
 * all state elements go through an S-box.
 */
template PoseidonPermutationFullRound(m, i, MDS, round_constants) {
    signal input in[m];
    signal inter[m];
    signal output out[m];

    component pow5[m];
    component m_mds = MultiplyMatrix(m, MDS);

    // + round constants * alpha
    for (var j = 0; j < m; j++) {
        pow5[j] = Pow5();
        pow5[j].in <== in[j] + round_constants[i*m + j];
    }

    // * MDS
    for (var j = 0; j < m; j++) {
        m_mds.in[j] <== pow5[j].out;
    }
    for (var j = 0; j < m; j++) {
        out[j] <== m_mds.out[j];
    }
}


/*
 * Poseidon permutation partial S-box round:
 * only the last state element goes through an S-box.
 */
template PoseidonPermutationPartialRound(m, i, Mp, round_constants) {
    signal input in[m];
    signal output out[m];

    component pow5 = Pow5();
    component m_ms = SparseMatrixMul(m,i);

    // + round constants * alpha (only the first state element)
    pow5.in <== in[0] + round_constants[i*m];
    m_ms.in[0] <== pow5.out;

    // FIXME: round constants tableau / liste
    // + round constants (all but first) * M" (ms here)
    for (var j = 1; j < m; j++) {
        m_ms.in[j] <== in[j] + round_constants[i*m + j];
    }
    for (var j = 0; j < m; j++) {
        out[j] <== m_ms.out[j];
    }
}





/*
 * Multiplies input with giben matrix (matrix mutiplication, both size m).
 */
template MultiplyMatrix(m, matrix) {
    signal input in[m];
    signal output out[m];

    for (var i = 0; i < m; i++) {
        var temp = in[0] * matrix[i][0];
        for (var j = 1; j < m; j++) {
            temp += in[j] * matrix[i][j];
        }
        out[i] <== temp;
    }
}

template SparseMatrixMul(m,i){
    signal input in[m];
    signal output out[m];
    signal s0[m];
    s0[0] <==  in[0] * M_0_0();

    for(var j = 1; j < m; j +=1){ 
        s0[j] <== s0[j-1] + W_HAT_COLLECTION()[i][j-1] * in [j];
    }

    out[0] <== s0[m-1]; 

    for(var j = 1; j < m; j +=1){ 
        out[j] <== s0[m-1] + V_COLLECTION()[i][j-1] * in [j];
    }


}




component main = PoseidonHashWrapper(3, 2);
