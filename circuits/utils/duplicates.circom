pragma circom 2.0.0;

include "arrays.circom";
include "comparators.circom";
include "powers.circom";

/**
 * Remove duplicates from an array, unknowingly of the output size.
 *
 * ARGUMENTS: input_len
 *
 * INPUTS:
 * - in[input_len]
 * - in_mask[input_len]: binary array, dictating which elements from the input to
 *                    consider (0 = discard element, as if it were a duplicate)
 *
 * OUTPUTS:
 * - amount: number of distinct elements found in the input array
 * - out[input_len]: array containing the distinct elements from the inputs
 *                   and zeroes as padding; order is preserved
 */
template RemoveDuplicatesUnknown(input_len) {
    signal input in[input_len];
    signal input in_mask[input_len];
    signal output out[input_len];
    signal output out_mask[input_len];

    signal dup[input_len - 1][input_len - 1];
    signal k[input_len];

    component add[input_len - 1];
    component duplicate[input_len - 1];
    component lt[input_len - 1];

    // find duplicates
    // duplicate[i].out = (in[i+1] is a duplicate) ? 1 : 0
    for (var i = 0; i < input_len - 1; i++) {
        dup[i][0] <== in[i + 1] - in[0];
        for (var j = 1; j <= i; j++) {
            dup[i][j] <== dup[i][j - 1] * (in[i + 1] - in[j]);
        }

        duplicate[i] = IsZero();
        duplicate[i].in <== dup[i][i] * in_mask[i];
    }

    // first element is never a duplicate
    k[0] <== 0;
    add[0] = SelectorAdd(input_len);
    add[0].in[0] <== in[0];
    for (var i = 1; i < input_len; i++) {
        add[0].in[i] <== 0;
    }

    // compute non-duplicates count and list
    for (var i = 1; i < input_len; i++) {
        k[i] <== k[i - 1] + (1 - duplicate[i - 1].out);

        add[i - 1].index <== k[i];
        add[i - 1].to_add <== in[i] * (1 - duplicate[i - 1].out);

        if (i == input_len - 1) {
            for (var j = 0; j < input_len; j++) {
                out[j] <== add[i - 1].out[j];
            }
        } else {
            add[i] = SelectorAdd(input_len);
            for (var j = 0; j < input_len; j++) {
                add[i].in[j] <== add[i - 1].out[j];
            }
        }
    }

    out_mask[0] <== 1;
    var log2_input_len = numbits(input_len) + 1;
    for (var i = 0; i < input_len - 1; i++) {
        lt[i] = LessThan(log2_input_len);
        lt[i].in[0] <== i + 1;
        lt[i].in[1] <== k[input_len - 1] + 1;

        out_mask[i + 1] <== lt[i].out;
    }
}


/**
 * Remove duplicates from a list with specified number of inputs.
 * This component takes the first output_len distinct elements of its input
 * but only proves that its output comes from the input. It DOES NOT PROVE
 * that the output elements are the first in the same order than in the input.
 * If there are not enough distinct elements in the input to fill the output,
 * the program will crash.
 * For example if used with output_len > input_len, the program will panic.
 *
 * ARGUMENTS:
 * - input_len: the length of the input list;
 * - output_len: the number of elements in the output;
 *
 * INPUTS:
 * - in: a list to remove duplicates from.
 *
 * OUTPUTS:
 * - out: a list of output_len distinct elements from the input
 */
template RemoveDuplicates(input_len, output_len) {
    signal input in[input_len];
    signal output out[output_len];
    var inter[output_len];

    // compute a list without duplicates
    var dup;
    var k = 0;
    for(var i = 0; i < input_len; i++){
        dup = 1;
        for (var j = 0; j < k; j++){
            dup *= in[i] - inter[j];
        }

        if(dup != 0 && k < output_len) {
            inter[k] = in[i];
            k += 1;
        }
    }

    // prove the elements of this list do come from the input
    // TODO: this only proves the elements are ok, implement the verification that the order is correct
    component mul[output_len - 1];
    out[0] <-- inter[0];
    out[0] === in[0];
    for (var i = 1; i < output_len; i++) {
        out[i] <-- inter[i];
        mul[i-1] = MultiplierN(input_len - 1);
        for (var j = 1; j < input_len; j++) {
            mul[i-1].in[j-1] <== out[i] - in[j];
        }
        mul[i-1].out === 0;
    }
}

template MultiplierN(N) {
    signal input in[N];
    signal output out;

    signal inter[N - 1];

    inter[0] <== in[0] * in[1];
    for(var i = 0; i < N - 2; i++){
        inter[i + 1] <== inter[i] * in[i + 2];
    }
    out <== inter[N - 2];
}
