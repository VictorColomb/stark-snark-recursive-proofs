pragma circom 2.0.0;

include "arrays.circom";
include "bits.circom";
include "comparators.circom";
include "powers.circom";
include "polynoms.circom";


template SingleAssertion() {
    signal input column;
    signal input step;
    signal input value;

    signal output evaluation;
    signal output number_of_steps;
    signal output register;
    signal output step_offset;
    signal output stride_out;

    evaluation <== value;
    number_of_steps <== 1;
    register <== column;
    step_offset <== step;
    stride_out <== 0;
}


template PeriodicAssertion(trace_length) {
    signal input column;
    signal input first_step;
    signal input stride;
    signal input value;

    signal output evaluation;
    signal output number_of_steps;
    signal output register;
    signal output step_offset;
    signal output stride_out;

    number_of_steps <-- trace_length \ stride;
    number_of_steps * stride === trace_length;

    evaluation <== value;
    register <== column;
    step_offset <== first_step;
    stride_out <== stride;
}


template SequenceAssertion(addicity, trace_length, values_length) {
    signal input addicity_root;
    signal input column;
    signal input first_step;
    signal input g_trace;
    signal input stride;
    signal input values[values_length];
    signal input z;

    signal output evaluation;
    signal output number_of_steps;
    signal output register;
    signal output step_offset;
    signal output stride_out;

    signal g_trace_inv;

    component eval = Evaluate(values_length);
    component fft = FFTInterpolate(addicity, values_length);
    component pow = Pow_signal(numbits(trace_length));

    number_of_steps <== values_length;
    register <== column;
    step_offset <== first_step;

    if (values_length == 1) {
        stride_out <== 0;
    } else {
        stride_out <== stride;
    }

    // calculate FFT-1(values)(z * g_trace^(-first_step))

    fft.addicity_root <== addicity_root;
    for (var i = 0; i < values_length; i++) {
        fft.ys[i] <== values[i];
    }

    g_trace_inv <-- 1 / g_trace;
    g_trace * g_trace_inv === 1;

    pow.in <== g_trace_inv;
    pow.exp <== first_step;

    eval.x <== z * pow.out;
    for (var i = 0; i < values_length; i++) {
        eval.in[i] <== fft.out[i];
    }

    evaluation <== eval.out;
}


/**
 * Sort assertions by stride, then step offset, then register.
 * Maintains the initial order should two assertions be equal.
 *
 * TODO: this can most likely be optimized
 */
template SortAssertions(num_assertions, trace_length, trace_width) {
    signal input evaluations_in[num_assertions];
    signal input number_of_steps_in[num_assertions];
    signal input registers_in[num_assertions];
    signal input step_offsets_in[num_assertions];
    signal input strides_in[num_assertions];

    signal output evaluations[num_assertions];
    signal output number_of_steps[num_assertions];
    signal output registers[num_assertions];
    signal output step_offsets[num_assertions];

    signal begin[num_assertions - 1][num_assertions];
    signal pick[num_assertions - 1][num_assertions - 1];
    signal pick_temp[num_assertions - 1][num_assertions - 1];
    signal smallest_stride[num_assertions][num_assertions];
    signal smallest_stride_temp[num_assertions][num_assertions - 1];
    signal smallest_offset[num_assertions][num_assertions];
    signal smallest_offset_temp[num_assertions][num_assertions - 1];
    signal smallest_register[num_assertions][num_assertions];
    signal smallest_register_temp[num_assertions][num_assertions - 1];
    signal smallest_idx[num_assertions][num_assertions];
    signal smallest_idx_temp[num_assertions][num_assertions - 1];

    component already[num_assertions - 1][num_assertions];
    component lt[num_assertions][num_assertions - 1];
    component evaluations_sel;
    component number_of_steps_sel;
    component registers_sel;
    component step_offsets_sel;


    if (num_assertions == 1) {
        for (var i = 0; i < num_assertions; i++) {
            evaluations[i] <== evaluations_in[i];
            number_of_steps[i] <== number_of_steps_in[i];
            registers[i] <== registers_in[i];
            step_offsets[i] <== step_offsets_in[i];
        }
    } else {
        var numbits_trace_length = numbits(trace_length);
        var numbits_trace_width = numbits(trace_width);

        // FIND SMALLEST ASSERTION

        // at the beginning, the first assertion is the smallest
        smallest_stride[0][0] <== strides_in[0];
        smallest_offset[0][0] <== step_offsets_in[0];
        smallest_register[0][0] <== registers_in[0];
        smallest_idx[0][0] <== 0;

        // compare each assertion with the current smallest
        for (var j = 1; j < num_assertions; j++) {
            lt[0][j - 1] = AssertionsLessThan(numbits_trace_length, numbits_trace_width);
            lt[0][j - 1].stride0 <== strides_in[j];
            lt[0][j - 1].stride1 <== smallest_stride[0][j - 1];
            lt[0][j - 1].offset0 <== step_offsets_in[j];
            lt[0][j - 1].offset1 <== smallest_offset[0][j - 1];
            lt[0][j - 1].register0 <== registers_in[j];
            lt[0][j - 1].register1 <== smallest_register[0][j - 1];

            smallest_stride_temp[0][j - 1] <== smallest_stride[0][j - 1] * (1 - lt[0][j - 1].out);
            smallest_stride[0][j] <== strides_in[j] * lt[0][j - 1].out + smallest_stride_temp[0][j - 1];
            smallest_offset_temp[0][j - 1] <== smallest_offset[0][j - 1] * (1 - lt[0][j - 1].out);
            smallest_offset[0][j] <== step_offsets_in[j] * lt[0][j - 1].out + smallest_offset_temp[0][j - 1];
            smallest_register_temp[0][j - 1] <== smallest_register[0][j - 1] * (1 - lt[0][j - 1].out);
            smallest_register[0][j] <== registers_in[j] * lt[0][j - 1].out + smallest_register_temp[0][j - 1];
            smallest_idx_temp[0][j - 1] <== smallest_idx[0][j - 1] * (1 - lt[0][j - 1].out);
            smallest_idx[0][j] <== j * lt[0][j - 1].out + smallest_idx_temp[0][j - 1];
        }

        // FIND THE SMALLEST ASSERTION, discarding those already picked

        for (var i = 1; i < num_assertions; i++) {
            smallest_stride[i][0] <== strides_in[0];
            smallest_offset[i][0] <== step_offsets_in[0];
            smallest_register[i][0] <== registers_in[0];
            smallest_idx[i][0] <== 0;

            already[i - 1][0] = AlreadyPicked(i);
            already[i - 1][0].index <== 0;
            for (var j = 0; j < i; j++) {
                already[i - 1][0].already_picked[j] <== smallest_idx[j][num_assertions - 1];
            }
            begin[i - 1][0] <== already[i - 1][0].out;

            for (var j = 1; j < num_assertions; j++) {
                lt[i][j - 1] = AssertionsLessThan(numbits_trace_length, numbits_trace_width);
                lt[i][j - 1].stride0 <== strides_in[j];
                lt[i][j - 1].stride1 <== smallest_stride[i][j - 1];
                lt[i][j - 1].offset0 <== step_offsets_in[j];
                lt[i][j - 1].offset1 <== smallest_offset[i][j - 1];
                lt[i][j - 1].register0 <== registers_in[j];
                lt[i][j - 1].register1 <== smallest_register[i][j - 1];

                already[i - 1][j] = AlreadyPicked(i);
                already[i - 1][j].index <== j;
                for (var k = 0; k < i; k++) {
                    already[i - 1][j].already_picked[k] <== smallest_idx[k][num_assertions - 1];
                }

                pick_temp[i - 1][j - 1] <== lt[i][j - 1].out * (1 - already[i - 1][j].out);
                pick[i - 1][j - 1] <== begin[i - 1][j - 1] + (1 - begin[i - 1][j - 1]) * pick_temp[i - 1][j - 1];
                if (j != num_assertions - 1) {
                    begin[i - 1][j] <== begin[i - 1][j - 1] * already[i - 1][j].out;
                }

                smallest_stride_temp[i][j - 1] <== smallest_stride[i][j - 1] * (1 - pick[i - 1][j - 1]);
                smallest_stride[i][j] <== strides_in[j] * pick[i - 1][j - 1] + smallest_stride_temp[i][j - 1];
                smallest_offset_temp[i][j - 1] <== smallest_offset[i][j - 1] * (1 - pick[i - 1][j - 1]);
                smallest_offset[i][j] <== step_offsets_in[j] * pick[i - 1][j - 1] + smallest_offset_temp[i][j - 1];
                smallest_register_temp[i][j - 1] <== smallest_register[i][j - 1] * (1 - pick[i - 1][j - 1]);
                smallest_register[i][j] <== registers_in[j] * pick[i - 1][j - 1] + smallest_register_temp[i][j - 1];
                smallest_idx_temp[i][j - 1] <== smallest_idx[i][j - 1] * (1 - pick[i - 1][j - 1]);
                smallest_idx[i][j] <== j * pick[i - 1][j - 1] + smallest_idx_temp[i][j - 1];
            }
        }

        // SELECT OUTPUTS

        evaluations_sel = MultiSelector(num_assertions, num_assertions);
        number_of_steps_sel = MultiSelector(num_assertions, num_assertions);
        registers_sel = MultiSelector(num_assertions, num_assertions);
        step_offsets_sel = MultiSelector(num_assertions, num_assertions);
        for (var i = 0; i < num_assertions; i++) {
            evaluations_sel.in[i] <== evaluations_in[i];
            evaluations_sel.indexes[i] <== smallest_idx[i][num_assertions - 1];
            number_of_steps_sel.in[i] <== number_of_steps_in[i];
            number_of_steps_sel.indexes[i] <== smallest_idx[i][num_assertions - 1];
            registers_sel.in[i] <== registers_in[i];
            registers_sel.indexes[i] <== smallest_idx[i][num_assertions - 1];
            step_offsets_sel.in[i] <== step_offsets_in[i];
            step_offsets_sel.indexes[i] <== smallest_idx[i][num_assertions - 1];
        }
        for (var i = 0; i < num_assertions; i++) {
            evaluations[i] <== evaluations_sel.out[i];
            number_of_steps[i] <== number_of_steps_sel.out[i];
            registers[i] <== registers_sel.out[i];
            step_offsets[i] <== step_offsets_sel.out[i];
        }
    }
}

/**
 * Compare two assertions (by stride, then offset, then register).
 */
template AssertionsLessThan(numbits_trace_length, numbits_trace_width) {
    signal input stride0;
    signal input stride1;
    signal input offset0;
    signal input offset1;
    signal input register0;
    signal input register1;

    signal output out;

    signal temp;

    component lt[3];
    component eq[2];

    lt[0] = LessThan(numbits_trace_width);
    lt[0].in[0] <== register0;
    lt[0].in[1] <== register1;

    lt[1] = LessThan(numbits_trace_length);
    lt[1].in[0] <== offset0;
    lt[1].in[1] <== offset1;

    lt[2] = LessThan(numbits_trace_length);
    lt[2].in[0] <== stride0;
    lt[2].in[1] <== stride1;

    eq[0] = IsEqual();
    eq[0].in[0] <== offset0;
    eq[0].in[1] <== offset1;

    eq[1] = IsEqual();
    eq[1].in[0] <== stride0;
    eq[1].in[1] <== stride1;

    temp <== lt[0].out * eq[0].out + lt[1].out;
    out <== temp * eq[1].out + lt[2].out;
}

/**
 * Determine whether an index has already been picked.
 */
template AlreadyPicked(N) {
    signal input index;
    signal input already_picked[N];
    signal output out;

    signal mul[N];
    component zero = IsZero();

    mul[0] <== index - already_picked[0];
    for (var i = 1; i < N; i++) {
        mul[i] <== mul[i - 1] * (index - already_picked[i]);
    }

    zero.in <== mul[N - 1];
    out <== zero.out;
}
