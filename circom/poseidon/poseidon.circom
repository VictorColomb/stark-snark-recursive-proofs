pragma circom 2.0.4;

include "param.circom";


template Sigma() {
    signal input in;
    signal output out;

    signal in2;
    signal in4;

    in2 <== in * in;
    in4 <== in2 * in2;

    out <== in4 * in;
}


template Ark(t, C, r) {
    signal input in[t];
    signal output out[t];

    for (var i = 0; i < t; i++) {
        out[i] <== in[i] + C[i + r];
    }
}


template Mix(t, M) {
    signal input in[t];
    signal output out[t];

    var lc;
    for (var i = 0; i < t; i++) {
        lc = 0;
        for (var j = 0; j < t; j++) {
            lc += M[i][j] * in[j];
        }
        out[i] <== lc;
    }
}


template MixS(t, S, r) {
    signal input in[t];
    signal output out[t];


    var lc = 0;
    for (var i = 0; i < t; i++) {
        lc += S[(t*2 - 1) * r + i] * in[i];
    }

    out[0] <== lc;
    for (var i = 1; i < t; i++) {
        out[i] <== in[i] +  in[0] * S[(t*2 - 1) * r + t + i -1];
    }
}


template PoseidonPerm(t) {
    signal input in[t];
    signal output out[t];

    var n_f_rounds = R_F();
    var n_p_rounds = R_P();
    var C[t*(n_f_rounds + 1) + n_p_rounds - 1] = POSEIDON_C(t);
    var S[n_p_rounds * (t*2-1)]  = POSEIDON_S(t);
    var M[t][t] = POSEIDON_M(t);
    var P[t][t] = POSEIDON_P(t);

    component ark[n_f_rounds + 1];
    component sigmaF[n_f_rounds][t];
    component sigmaP[n_p_rounds];
    component mix[n_f_rounds + 1];
    component mixS[n_p_rounds];

    //first full rounds
    for (var r = 0; r < n_f_rounds/2; r++) {
        //add round constants
        ark[r] = Ark(t, C, r * t);
        for (var j = 0; j < t; j++) {
            if (r == 0) {
                ark[r].in[j] <== in[j];
            } else {
                ark[r].in[j] <== mix[r-1].out[j];
            }
        }

        // apply sbox
        for (var j=0; j<t; j++) {
            sigmaF[r][j] = Sigma();
            sigmaF[r][j].in <== ark[r].out[j];
        }

        mix[r] = Mix(t,M);
        for (var j = 0; j < t; j++) {
            mix[r].in[j] <== sigmaF[r][j].out;
        }
    }


    // first part of the first partial round
    ark[n_f_rounds / 2] = Ark(t, C, (n_f_rounds/2) * t );
    for (var j = 0; j < t; j++) {
        ark[n_f_rounds / 2].in[j] <== mix[n_f_rounds/2 - 1].out[j];
    }

    mix[n_f_rounds / 2] = Mix(t,P);
    for (var j = 0; j < t; j++) {
        mix[n_f_rounds / 2].in[j] <== ark[n_f_rounds / 2].out[j];
    }

    // partial rounds
    for (var r = 0; r < n_p_rounds - 1; r++) {
        sigmaP[r] = Sigma();
        if (r==0) {
            sigmaP[r].in <== mix[n_f_rounds/2].out[0];
        } else {
            sigmaP[r].in <== mixS[r-1].out[0];
        }

        mixS[r] = MixS(t, S, n_p_rounds - 1 - r);
        for (var j=0; j<t; j++) {
            if (j==0) {
                mixS[r].in[j] <== sigmaP[r].out + C[(n_f_rounds/2+1)*t + r];
            } else {
                if (r==0) {
                    mixS[r].in[j] <== mix[n_f_rounds/2].out[j];
                } else {
                    mixS[r].in[j] <== mixS[r-1].out[j];
                }
            }
        }
    }

    //last partial round (no constants)
    sigmaP[n_p_rounds - 1] = Sigma();
    sigmaP[n_p_rounds - 1].in <== mixS[n_p_rounds-2].out[0];

    mixS[n_p_rounds - 1] = MixS(t, S, 0);
    mixS[n_p_rounds - 1].in[0] <== sigmaP[n_p_rounds - 1].out;
    for (var i = 1; i < t; i++) {
        mixS[n_p_rounds - 1].in[i] <== mixS[n_p_rounds - 2].out[i];
    }

    //second round of full rounds
    for (var r = n_f_rounds/2 ; r < n_f_rounds; r++) {
        //add round constants
        ark[r+1] = Ark(t, C, n_p_rounds - 1 + (r+1) * t);
        for (var j=0; j<t; j++) {
            if (r==n_f_rounds/2) {
                ark[r+1].in[j] <== mixS[n_p_rounds - 1].out[j];
            } else {
                ark[r+1].in[j] <== mix[r].out[j];
            }
        }

        // apply sbox
        for (var j=0; j<t; j++) {
            sigmaF[r][j] = Sigma();
            sigmaF[r][j].in <== ark[r + 1].out[j];
        }

        mix[r+1] = Mix(t,M);
        for (var j=0; j<t; j++) {
            mix[r+1].in[j] <== sigmaF[r][j].out;
        }
    }

    for (var j=0; j<t; j++) {
        out[j] <== mix[n_f_rounds].out[j];
    }
}


template PoseidonHash(l, t, c) {
    signal input in[l];
    var rate = t - c;
    signal output out[rate];

    var padded_l = (l\rate + 1) * rate;
    component poseidon = Sponge(padded_l, t,c);

    // input l elements
    for (var i = 0; i < l; i++) {
        poseidon.in[i] <== in[i];
    }

    // add a single 1
    poseidon.in[l] <== 1;

    // pad with zeroes
    for (var i = l+1; i < padded_l; i++) {
        poseidon.in[i] <== 0;
    }

    // output
    for (var j = 0; j < rate; j++) {
        out[j] <== poseidon.out[j];
    }

}


template Sponge(l, t, c) {
    signal input in[l];
    var rate = t - c;
    signal output out[rate];
    assert(l % rate == 0);

    component permutation[l \ rate];
    signal state[2*(l\rate) + 1][t];

    for (var i = 0; i < t; i++) {
        state[0][i] <== 0;
    }

    // absorbing and permutation
    for (var i = 0; i < l\rate; i++) {
        // absorb rate elements into the state
        for (var j = 0; j < rate; j++) {
            state[2*i+1][j] <== state[2*i][j] + in[i*rate+j];
        }
        // copy the other elements
        for (var j = rate; j < t; j++) {
            state[2*i+1][j] <== state[2*i][j];
        }

        // apply the permutation
        permutation[i] = PoseidonPerm(t);
        for (var j = 0; j < t; j++) {
            permutation[i].in[j] <== state[2*i+1][j];
        }
        for (var j = 0; j < t; j++) {
            state[2*i+2][j] <== permutation[i].out[j];
        }
    }

    // output
    for (var k = 0; k < rate; k++) {
        out[k] <== state[2*(l/rate)][k];
    }
}


template Poseidon(n_inputs) {
    signal input in[n_inputs];
    signal output out;

    var state_width = T();
    var capacity = 1;

    component h = PoseidonHash(n_inputs, state_width, capacity);
    for (var i=0; i<n_inputs; i++) {
        h.in[i] <== in[i];
    }
    out <== h.out[0];
}
