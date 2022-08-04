pragma circom 2.0.0;

include "comparators.circom";


/**
 * Find the indexes of multiple elements in an array.
 * Only works if each looked up element appears only once in the list!
 *
 * ARGUMENTS:
 * - input_len: length of the array
 * - num_lookup: number of indexes to look for
 *
 * INPUTS:
 * - in[input_len]: array to look into
 * - mask[input_len]: binary array that defines which values to consider 0 =
                discard element, as if it were not in the array to begin with
 * - lookup[num_lookup]: elements whose indexes we are looking for
 *
 * OUTPUTS: out[num_lookup]
 */
template MultiIndexLookup(input_len, num_lookup) {
    signal input in[input_len];
    signal input mask[input_len];
    signal input lookup[num_lookup];
    signal output out[num_lookup];

    signal temp[num_lookup][input_len];

    component eq[num_lookup][input_len];

    for (var i = 0; i < num_lookup; i++) {
        var index = 0;

        for (var j = 0; j < input_len; j++) {
            eq[i][j] = IsEqual();
            eq[i][j].in[0] <== lookup[i];
            eq[i][j].in[1] <== in[j];

            temp[i][j] <== mask[j] * eq[i][j].out;
            index += temp[i][j] * j;
        }

        out[i] <== index;
    }
}


/**
 * Select a element in an array with a signal as index.
 *
 * ARGUMENTS: input_len
 *
 * INPUTS:
 * - in[input_len]: array to look into
 * - index
 *
 * OUTPUTS: out
 */
template Selector(input_len) {
    signal input in[input_len];
    signal input index;
    signal output out;

    signal sum[input_len];
    component eqs[input_len];
    // For each item, check whether its index equals the input index.
    for (var i = 0; i < input_len; i ++) {
        eqs[i] = IsEqual();
        eqs[i].in[0] <== i;
        eqs[i].in[1] <== index;

        // eqs[i].out is 1 if the index matches. As such, at most one input to
        // calcTotal is not 0.
        if (i == 0) {
            sum[i] <== eqs[i].out * in[i];
        } else {
            sum[i] <== sum[i - 1] + eqs[i].out * in[i];
        }
    }

    // Returns 0 + 0 + 0 + item
    out <== sum[input_len - 1];
}

/**
 * Select multiple elements in an array, with signals as indexes.
 *
 * ARGUMENTS:
 * - input_len
 * - num_indexes
 *
 * INPUTS:
 * - in[input_len]: array to look into
 * - indees[num_indexes]
 *
 * OUTPUTS: out[num_indexes]
 */
template MultiSelector(input_len, num_indexes) {
    signal input in[input_len];
    signal input indexes[num_indexes];
    signal output out[num_indexes];

    signal sum[num_indexes][input_len];
    component eqs[num_indexes][input_len];

    for(var k = 0; k < num_indexes; k++) {
        // For each item, check whether its index equals the input index.
        for (var i = 0; i < input_len; i ++) {
            eqs[k][i] = IsEqual();
            eqs[k][i].in[0] <== i;
            eqs[k][i].in[1] <== indexes[k];

            // eqs[k][i].out is 1 if the index matches. As such, at most one input to
            // calcTotal is not 0.
            if (i == 0) {
                sum[k][i] <== eqs[k][i].out * in[i];
            } else {
                sum[k][i] <== sum[k][i - 1] + eqs[k][i].out * in[i];
            }
        }

        // Returns 0 + 0 + 0 + item
        out[k] <== sum[k][input_len - 1];
    }
}


/**
 * Add to a given array element, using a signal as index.
 */
template SelectorAdd(input_len) {
    signal input in[input_len];
    signal input index;
    signal input to_add;
    signal output out[input_len];

    component eq[input_len];

    for (var i = 0; i < input_len; i++) {
        eq[i] = IsEqual();
        eq[i].in[0] <== index;
        eq[i].in[1] <== i;

        out[i] <== in[i] + to_add * eq[i].out;
    }
}
