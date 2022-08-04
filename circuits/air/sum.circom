pragma circom 2.0.0;

include "../utils/comparators.circom";


template AIRTransitions(num_transition_constraints) {
    signal output transition_degree[num_transition_constraints];

    /* === EDIT FROM HERE === */

    // Hardcode transition degrees, as you did in your implementation
    // of WinterCircomProofOptions.
    transition_degree[0] <== 1;
    transition_degree[1] <== 1;

    /* ====== TO HERE ====== */
}


template AIRAssertions(addicity, num_assertions, num_public_inputs, trace_length, trace_width) {
    signal input addicity_root;
    signal input public_inputs[num_public_inputs];
    signal input g_trace;

    signal output evaluations[num_assertions];
    signal output number_of_steps[num_assertions];
    signal output registers[num_assertions];
    signal output step_offsets[num_assertions];
    signal output strides[num_assertions];

    component assertions[num_assertions];

    /* === EDIT FROM HERE === */

    // Hardcode the number of assertions (this is a precaution).

    assert(num_assertions == 3);

    // Define your assertions here, using the SingleAssertion, PeriodicAssertion
    // and SequenceAssertion templates.

    assertions[0] = SingleAssertion();
    assertions[0].column <== 0;
    assertions[0].step <== 0;
    assertions[0].value <== public_inputs[0];

    assertions[1] = SingleAssertion();
    assertions[1].column <== 1;
    assertions[1].step <== 0;
    assertions[1].value <== public_inputs[0];

    assertions[2] = SingleAssertion();
    assertions[2].column <== 1;
    assertions[2].step <== trace_length - 1;
    assertions[2].value <== public_inputs[1];

    /* ====== TO HERE ====== */

    for (var i = 0; i < num_assertions; i++) {
        evaluations[i] <== assertions[i].evaluation;
        number_of_steps[i] <== assertions[i].number_of_steps;
        registers[i] <== assertions[i].register;
        step_offsets[i] <== assertions[i].step_offset;
        strides[i] <== assertions[i].stride_out;
    }
}
