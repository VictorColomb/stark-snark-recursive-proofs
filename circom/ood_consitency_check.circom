pragma circom 2.0.4;

include "../air/basic.circom"


/**
 * Checks that the evaluations of composition polynomials sent by the prover 
 * are consistent with valuations obtained by evaluating constraints over the
 * out-of-domain frame. This template does not return any signal, its purpose is
 * just to create the 'channel_result === evaluation_result' constraint
 * 
 * ARGUMENTS:
 * - See verify.circom
 * 
 * INPUTS:
 * - boundary_coeffs: Fiat-Shamir coefficients for the boundary constraints.
 * - channel_ood_evaluations: Out Of Domain evaluations given in the proof.
 * - frame: the Out Of Domain frame over which the constraints will be evaluated.
 * - public_inputs: inputs used for the calculation
 * - transition_coeffs: Fiat-Shamir coefficients for the transition constraints.
 * - z: Out Of Domain point of evaluation, generated in the public coin.
 *
 * TODO: 
 * - add support for composition with different degrees
 * - add support for periodic values
 * - group transitions by degree to reduce the number of degree adjustment
 */
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


    var evaluation_result = 0;

    component transition_deg_adjustment[trace_width];
    for (var i = 0; i < trace_width; i++) {
        transition_deg_adjustment[i] = Pow(trace_length * ce_blowup_factor - 1 - evaluate_transitions.transition_degree[i]);
        transition_deg_adjustment[i].in <== z;
        evaluation_result += (transition_coeffs[i][0] + transition_coeffs[i][1] * transition_deg_adjustment[i].out) * evaluate_transitions.out[i];
    }


    // BOUNDARY CONSTRAINTS EVALUATIONS

    component evaluate_boundary_constraints = BasicAssertions(
        num_assertions,
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
        boundary_deg_adjustment[i] = Pow(trace_length * ce_blowup_factor - 1 + evaluate_boundary_constraints.divisor_degree[i] - (trace_length - 1));
        boundary_deg_adjustment[i].in <== z;
        evaluation_result += (boundary_coeffs[i][0] + boundary_coeffs[i][1] * boundary_deg_adjustment[i].out) * evaluate_boundary_constraints.out[i];
    }

    // reduce evaluations of composition polynomial columns sent by the prover into
    // a single value by computing sum(z^i * value_i), where value_i is the evaluation of the ith
    // column polynomial at z^m, where m is the total number of column polynomials

    var channel_result = 0
    component channel_ood_pow[ce_blowup_factor];
    for (var i = 0; i < ce_blowup_factor; i++) {
        channel_ood_pow[i] = Pow(i);
        channel_ood_pow[i].in <== z;
        channel_result += channel_ood_evaluations[i] * channel_ood_pow[i].out;
    }

    channel_result === evaluation_result;
}