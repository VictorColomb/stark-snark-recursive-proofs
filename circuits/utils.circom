pragma circom 2.0.0;

include "poseidon/poseidon.circom";


/**
 * Exponentiation where the exponent is not a signal.
 *
 * Usable whenever the exponent only depends on circuit parameters but not the input.
 * Always use this when possible as it will generate ~log2(exp) constraints, which is
 * much less than the exponentiation with signal.
 *
 * ARGUMENTS:
 * - exp: the exponent to raise the input to.
 *
 * INPUTS:
 * - in: x
 *
 * OUTPUTS:
 * - out: x**exp
 */
template Pow(exp) {
    signal input in;

    signal output out;

    // converting exponent to bits
    var buffer_size = 0;
    var bits[255];
    var c = exp;

    while (c != 0) {
        bits[buffer_size] = c & 1;
        c \= 2;
        buffer_size += 1;
    }

    signal pow[buffer_size];
    signal inter[buffer_size];
    signal temp[buffer_size-1];

    pow[0] <== in;
    inter[0] <== pow[0] * bits[0] + (1 - bits[0]);

    for (var i = 1; i < buffer_size; i++) {
        pow[i] <== pow[i-1] * pow[i-1];
        temp[i-1] <== pow[i] * bits[i] + (1 - bits[i]);
        inter[i] <==  inter[i-1] * temp[i-1];
    }

    out <== inter[buffer_size - 1];
}


/**
 * Exponentiation with a signal as exponent.
 *
 * ARGUMENTS:
 * - n: buffer size needed to convert exp in bits
 *
 * INPUTS:
 * - in: x
 * - exp: exponent
 *
 * OUTPUTS:
 * - out: x**exp
 */
template Pow_signal(n) {
    signal input in;
    signal input exp;

    signal output out;

    component n2b = Num2Bits(n);
    n2b.in <== exp;
    signal pow[n];
    signal inter[n];
    signal temp[n];

    pow[0] <== in;
    temp[0] <== pow[0] * n2b.out[0] + (1 - n2b.out[0]);
    inter[0] <== temp[0];

    for (var i = 1; i < n; i++) {
        pow[i] <== pow[i-1] * pow[i-1];
        temp[i] <== pow[i] * n2b.out[i] + (1 - n2b.out[i]);
        inter[i] <==  inter[i-1] * temp[i];
    }

    out <== inter[n-1];
}


/**
 * Number of bits of an field element.
 */
function numbits(n) {
    var k = 0;
    while (n != 0) {
        n \= 2;
        k += 1;
    }
    return k;
}


/**
 * Convert a field element into binary representation.
 *
 * ARGUMENTS:
 * - n: buffer size. must be greater than log2 of the input
 */
template Num2Bits(n) {
    signal input in;
    signal output out[n];
    var lc1 = 0;

    var e2 = 1;
    for (var i = 0; i < n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] - 1) === 0;
        lc1 += out[i] * e2;
        e2 = e2 + e2;
    }

    lc1 === in;
}

/**
 * Convert a binary representation into a field element.
 *
 * ARGUMENTS:
 * - n: input length (number of bits)
 */
template Bits2Num(n) {
    signal input in[n];
    signal output out;
    var lc1=0;

    var e2 = 1;
    for (var i = 0; i < n; i++) {
        lc1 += in[i] * e2;
        e2 = e2 + e2;
    }

    lc1 ==> out;
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

template IsZero() {
    signal input in;
    signal output out;

    signal inv;

    inv <-- in!=0 ? 1/in : 0;

    out <== -in*inv +1;
    in*out === 0;
}

template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();

    in[1] - in[0] ==> isz.in;

    isz.out ==> out;
}

/**
 * Compare two field elements.
 *
 * INPUTS:
 * - in[2]: the two field elements to compare
 *
 * OUTPUTS:
 * - out: 1 if the first input is smaller, 0 otherwise
 */
template LessThan(n) {
    assert(n <= 254);
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n+1);

    n2b.in <== in[0] + (1<<n) - in[1];

    out <== 1 - n2b.out[n];
}

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
 * - lookup[num_lookup]: elements whose indexes we are looking for
 *
 * OUTPUTS: out[num_lookup]
 *
 * TODO: make the template work if an element appears multiple times
 */
template MultiIndexLookup(input_len, num_lookup) {
    signal input in[input_len];
    signal input lookup[num_lookup];
    signal output out[num_lookup];

    component eq[num_lookup][input_len];

    for (var i = 0; i < num_lookup; i++) {
        var index = 0;

        for (var j = 0; j < input_len; j++) {
            eq[i][j] = IsEqual();
            eq[i][j].in[0] <== lookup[i];
            eq[i][j].in[1] <== in[j];

            index += j * eq[i][j].out;
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
 * Perform an integer division on a field element, providing the quotient and
 * the remainder.
 *
 * ARGUMENTS:
 * - M: modulo
 * - n: the number of bits of the field element.
 *
 * INPUTS: in
 * OUTPUTS: quotient, remainder
 */
template IntegerDivision(M, n) {
    signal input in;
    signal output quotient;
    signal output remainder;

    component lt = LessThan(n);

    remainder <-- in % M;
    quotient <-- in \ M;

    in === quotient * M + remainder;
    lt.in[0] <== remainder;
    lt.in[1] <== M;
    lt.out === 1;
}
