pragma circom 2.0.0;

include "utils/assertions.circom";
include "utils/powers.circom";


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
 */
template OodConsistencyCheck(
    addicity,
    ce_blowup_factor,
    num_assertions,
    num_public_inputs,
    num_transition_constraints,
    trace_length,
    trace_width
) {
    signal input addicity_root;
    signal input boundary_coeffs[num_assertions][2];
    signal input channel_ood_evaluations[ce_blowup_factor];
    signal input frame[2][trace_width];
    signal input ood_frame_constraint_evaluation[num_transition_constraints];
    signal input g_trace;
    signal input public_inputs[num_public_inputs];
    signal input transition_coeffs[num_transition_constraints][2];
    signal input z;

    signal assertions_temp[num_assertions][2];
    signal channel_ood_pow[ce_blowup_factor];
    signal evaluation_result[num_transition_constraints + num_assertions];
    signal transition_divisor;
    signal transition_result;
    signal transition_temp[num_transition_constraints];

    component AIR;
    component assertions;
    component assertions_frame;
    component assertions_user;
    component divisor_term[num_assertions][2];
    component gp_trace_len;
    component transition_deg_adjustment[num_transition_constraints];
    component xpn;
    component zp[num_assertions];



    // BUILDING TRANSITION DIVISOR
    // for transition constraints, it is always the same : div(x) = (x**n) / (product i : 1 --> k : (x - g ** (n - i)))
    // The above divisor specifies that transition constraints must hold on all steps of the execution trace except for the last k steps.
    // The default value for k is 1. n represents the trace length

    gp_trace_len = Pow(trace_length - 1);
    gp_trace_len.in <== g_trace;

    xpn = Pow(trace_length);
    xpn.in <== z;
    transition_divisor <-- (xpn.out - 1) / (z - gp_trace_len.out);
    transition_divisor * (z - gp_trace_len.out) === xpn.out - 1;

    var numbits_transition_deg = numbits((ce_blowup_factor + 1) * trace_length);
    AIR = AIRTransitions(num_transition_constraints);
    for (var i = 0; i < num_transition_constraints; i++) {
        transition_deg_adjustment[i] = Pow_signal(numbits_transition_deg);
        transition_deg_adjustment[i].in <== z;
        transition_deg_adjustment[i].exp <== (ce_blowup_factor + 1) * trace_length - 2 - AIR.transition_degree[i] * (trace_length - 1);
        transition_temp[i] <== transition_coeffs[i][0] + transition_coeffs[i][1] * transition_deg_adjustment[i].out;

        if (i == 0) {
            evaluation_result[i] <== transition_temp[i] * ood_frame_constraint_evaluation[i];
        } else {
            evaluation_result[i] <== evaluation_result[i-1] +  transition_temp[i] * ood_frame_constraint_evaluation[i];
        }
    }

    transition_result <-- evaluation_result[num_transition_constraints - 1] / transition_divisor;
    transition_result * transition_divisor ===  evaluation_result[num_transition_constraints - 1];

    // BOUNDARY CONSTRAINTS EVALUATIONS

    // retrieve user-defined assertions
    assertions_user = AIRAssertions(addicity, num_assertions, num_public_inputs, trace_length, trace_width);
    assertions_user.addicity_root <== addicity_root;
    assertions_user.g_trace <== g_trace;
    for (var i = 0; i < num_public_inputs; i++) {
        assertions_user.public_inputs[i] <== public_inputs[i];
    }

    // sort assertions by stride, step offset and register (in that order)
    assertions = SortAssertions(num_assertions, trace_length, trace_width);
    for (var i = 0; i < num_assertions; i++) {
        assertions.evaluations_in[i] <== assertions_user.evaluations[i];
        assertions.number_of_steps_in[i] <== assertions_user.number_of_steps[i];
        assertions.registers_in[i] <== assertions_user.registers[i];
        assertions.step_offsets_in[i] <== assertions_user.step_offsets[i];
        assertions.strides_in[i] <== assertions_user.strides[i];
    }

    assertions_frame = MultiSelector(trace_width, num_assertions);
    for (var i = 0; i < trace_width; i++) {
        assertions_frame.in[i] <== frame[0][i];
    }
    for (var i = 0; i < num_assertions; i++) {
        assertions_frame.indexes[i] <== assertions.registers[i];
    }

    var numbits_trace_length = numbits(trace_length);
    var numbits_ce_domain = numbits(ce_blowup_factor * trace_length);
    for (var i = 0; i < num_assertions; i++) {
        zp[i] = Pow_signal(numbits_ce_domain);
        zp[i].in <== z;
        zp[i].exp <== (ce_blowup_factor - 1) * trace_length + assertions.number_of_steps[i];

        divisor_term[i][0] = Pow_signal(trace_length);
        divisor_term[i][0].in <== z;
        divisor_term[i][0].exp <== assertions.number_of_steps[i];
        divisor_term[i][1] = Pow_signal(trace_length + 1);
        divisor_term[i][1].in <== g_trace;
        divisor_term[i][1].exp <== assertions.step_offsets[i] * assertions.number_of_steps[i];

        assertions_temp[i][0] <== boundary_coeffs[i][0] + boundary_coeffs[i][1] * zp[i].out;
        assertions_temp[i][1] <== (assertions_frame.out[i] - assertions.evaluations[i]) * assertions_temp[i][0];

        if (i == 0) {
            evaluation_result[num_transition_constraints] <-- transition_result + assertions_temp[i][1] / (divisor_term[i][0].out - divisor_term[i][1].out);
            (evaluation_result[num_transition_constraints] - transition_result) * (divisor_term[i][0].out - divisor_term[i][1].out) === assertions_temp[i][1];
        } else {
            evaluation_result[num_transition_constraints + i] <-- evaluation_result[num_transition_constraints + i - 1] + assertions_temp[i][1] / (divisor_term[i][0].out - divisor_term[i][1].out);
            (evaluation_result[num_transition_constraints + i] - evaluation_result[num_transition_constraints + i - 1]) * (divisor_term[i][0].out - divisor_term[i][1].out) === assertions_temp[i][1];
        }
    }


    // reduce evaluations of composition polynomial columns sent by the prover into
    // a single value by computing sum(z^i * value_i), where value_i is the evaluation of the ith
    // column polynomial at z^m, where m is the total number of column polynomials

    channel_ood_pow[0] <== 1;
    var channel_result = channel_ood_evaluations[0];
    for (var i = 1; i < ce_blowup_factor; i++) {
        channel_ood_pow[i] <== z * channel_ood_pow[i-1];
        channel_result += channel_ood_evaluations[i] * channel_ood_pow[i];
    }

    channel_result === evaluation_result[num_transition_constraints + num_assertions - 1];
}
