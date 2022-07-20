pragma circom 2.0.4;

include "../utils.circom";

/**
 * Define the degree for the transitions constraints.
 * 
 *
 * INPUTS:
 * - frame: Out Of Domain frame on which we will check the
 * the consistency with the channel.
 *
 * OUTPUTS:
 * - transition_degree : degree of the transition, will be used for degree
 *   adjustment. Should be set to the number of trace columns multiplied in
 *   during the transition.
 */
template AIRTransitions(trace_width) {
    signal output transition_degree[trace_width];

    // transition 0
    transition_degree[0] <== 1;

    // transition 1
    transition_degree[1] <== 1;
}

/**
 * Define the assertions that will tie your public inputs to the calculation.
 * These assertions will then be transformed into boundray constraints.
 * For now only single assertions are supported :
 * --> Assigning a value to a fixed step for a fixed trace column.
 *
 * INPUTS:
 * - public_inputs: inputs used for the calculation
 * - frame: Out Of Domain evaluation frame
 *
 * OUTPUTS:
 * - out: evaluation of the boundary constraints against each trace column
 * - divisor_degree: degree of the polynomial used as divisor, need for degree
 *   adjustment
 *
 * TODO:
 * - Add support for cyclic and sequence constraints.
 * - for now divisor_degree is always 1 as we only use signel constraints. See
 * https://docs.rs/winter-air/0.4.0/winter_air/struct.ConstraintDivisor.html for
 * for other types of divisors.
 */
template AIRAssertions(
    num_assertions,
    num_public_inputs,
    trace_length,
    trace_width
) {
    signal input frame[2][trace_width];
    signal input g_trace;
    signal input public_inputs[num_public_inputs];
    signal input z;

    signal output out[num_assertions];
    signal output divisor_degree[num_assertions];

    signal numerator[num_assertions];
    signal value[num_assertions];
    signal output step[num_assertions];
    signal register[num_assertions];

    /* HERE YOUR ASSERTIONS HERE */


    value[0] <== public_inputs[0];
    step[0] <== 0;
    register[0] <== 0;

    value[1] <== public_inputs[0];
    step[1] <== 0;
    register[1] <== 1;

    value[2] <== public_inputs[1];
    step[2] <== trace_length - 1;
    register[2] <== 1;

    /* ------------------------------------- */

    // boundary constraints evaluation
    component pow[num_assertions];
    component sel[num_assertions];
    for (var i = 0; i < num_assertions; i++) {
        sel[i] = Selector(trace_width);
        for (var j = 0; j < trace_width; j++) {
            sel[i].in[j] <== frame[0][j];
        }
        sel[i].index <== register[i];

        out[i] <== sel[i].out - value[i];
        divisor_degree[i] <== 1;
    }
}
