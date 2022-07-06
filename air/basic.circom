pragma circom 2.0.4;

include "../circom/utils.circom"

/**
 * Define how your computation transitions from one step
 * to the next one.
 * 
 * INPUTS:
 * - frame: Out Of Domain frame on which we will check the
 * the consistency with the channel.
 * 
 * OUTPUTS:
 * - out: Out Of Domain transition evaluation for each trace column
 * - transition_degree : degree of the transition, will be used for degree 
 *   adjustment. Should be set to the number of trace columns multiplied in
 *   during the transition.
 */
template BasicTransitions(trace_width) {
    signal input frame[2][2];
    signal output out[trace_width];
    signal output transition_degree[trace_width];

    // frame[0] = current | frame[1] = next

    // transition 0
    out[0] <== frame[1][0] - (frame[0][0] + 1)
    transition_degree[0] <== 1;

    // transition 1
    out[1] <== frame[1][1] - (frame[0][1] + frame[0][0] + 1)
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
 */
template BasicAssertions(
    num,assertions,
    trace_generator,
    trace_length,
    trace_width
) {

    signal input public_inputs[num_public_inputs];
    signal input frame[2][trace_width];
    signal output out[num_assertions];
    signal output divisor_degree[num_assertions];

    signal numerator[num_assertions];
    signal value[num_assertions];
    signal step[num_assertions];
    signal register[num_assertions];

    /* HERE YOUR ASSERTIONS HERE */


    value[0] <== public_inputs[0];
    step[0] <== 0;
    register[0] <== 0;

    value[1] <== public_inputs[0];
    step[1] <== 0;
    register[0] <== 1;

    value[2] <== public_inputs[1];
    step[2] <== trace_length - 1;
    register[0] <== 1;

    /* ------------------------------------- */

    // boundary constraints evaluation
    component pow[num_assertions];
    for (int i = 0; i < num_assertions; i++) {
        numerator[i] <== frame[0][register[i]] - value[i];
        pow[i] = Pow(step[i]);
        pow[i].in <== trace_generator;
        out[i] <== numerator[i] / (x - pow[i].out)
        divisor_degree[i] <== step[i];
    }
}


