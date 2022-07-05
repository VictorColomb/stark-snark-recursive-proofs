pragma circom 2.0.4;

include "../air/basic.circom"

template OodConsistencyCheck(
    ce_blowup_factor,
    num_assertions,
    num_public_inputs,
    trace_generator,
    trace_length,
    trace_width
) {
    signal input boundary_coeffs[num_assertions][2];
    signal input channel_ood_evaluations[ce_blowup_factor];
    signal input frame[2][trace_width];
    signal input public_inputs[num_public_inputs];
    signal input transition_coeffs[trace_width][2];
    signal input z;

    // TRANSITION CONSTRAINT EVALUATIONS

    component evaluate_transitions = BasicTransitions(trace_width);
    evaluate_transitions.x <== z;
    for (var i = 0; i < 2; i){
        for (var j = 0; j < trace_width; j) {
            evaluate_transitions.frame[i][j] <== frame[i][j];
        }
    }


    /* TODO: add support for composition with different degrees

    acc = 0
    for degree in degrees {
        acc += sum((transition_coeffs[i].0 + transition_coeffs[i].1 * x ^ (eval_degree - degree)) * evaluate_transitions[i])
    }
    for now we only have transitions of degree
    */

    var evaluation_result = evaluate_transitions.result;

    component transition_deg_adjustment[trace_width];
    for (var i = 0; i < trace_width; i++) {
        transition_deg_adjustment[i] = Pow(trace_length * ce_blowup_factor - 1 - evaluation_result[i].transition_degree);
        transition_deg_adjustment[i].in <== z;
        evaluation_result += (transition_coeffs[i][0] + transition_coeffs[i][1] * transition_deg_adjustment[i].out) * evaluate_transitions.out[i];
    }


    // BOUNDARY CONSTRAINTS EVALUATIONS
    // TODO: add support for periodic values

    component evaluate_boundary_constraints = BasicAssertions(
        /*TODO: pass num_assertions from a config.circom*/
        3,
        trace_generator,
        trace_length,
        trace_width
    );

    for (var i = 0; i < num_public_inputs; i++) {
        evaluate_boundary_constraints.public_inputs[i] <== public_inputs[i];
    }
    for (var i = 0; i < 2; i){
        for (var j = 0; j < trace_width; j) {
            evaluate_boundary_constraints.frame <== frame[i][j];
        }
    }


    component boundary_deg_adjustment[trace_width];
    for (var i = 0; i < num_assertions; i++) {
        boundary_deg_adjustment[i] = Pow(trace_length * ce_blowup_factor - 1 + evaluate_boundary_constraints[i].divisor_degree - (trace_length - 1));
        boundary_deg_adjustment[i].in <== z;
        evaluation_result += (boundary_coeffs[i][0] + boundary_coeffs[i][1] * boundary_deg_adjustment[i].out) * evaluate_boundary_constraints.out[i];
    }

    var channel_result = 0
    component channel_ood_pow[ce_blowup_factor];
    for (var i = 0; i < ce_blowup_factor; i++) {
        channel_ood_pow[i] = Pow(i);
        channel_ood_pow[i].in <== z;
        channel_result += channel_ood_evaluations[i] * channel_ood_pow[i].out;
    }

    channel_result === evaluation_result;
}