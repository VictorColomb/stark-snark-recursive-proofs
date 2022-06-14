use super::air::{PublicInputs, WorkAir};
use winterfell::math::{fields::f128::BaseElement, FieldElement};
use winterfell::{ProofOptions, Prover, Trace, TraceTable};
// Our prover needs to hold STARK protocol parameters which are specified via ProofOptions
// struct.
pub struct WorkProver {
    options: ProofOptions,
}

impl WorkProver {
    pub fn new(options: ProofOptions) -> Self {
        Self { options }
    }

    pub fn build_trace(&self, start: BaseElement, n: usize) -> TraceTable<BaseElement> {
        // Instantiate the trace with a given width and length; this will allocate all
        // required memory for the trace
        let trace_width = 2;
        let mut trace = TraceTable::new(trace_width, n);

        // Fill the trace with data; the first closure initializes the first state of the
        // computation; the second closure computes the next state of the computation based
        // on its current state.
        trace.fill(
            |state| {
                state[0] = start;
                state[1] = start;
            },
            |_, state| {
                state[0] += BaseElement::ONE;
                state[1] += state[0];
            },
        );

        trace
    }
}

// When implementing Prover trait we set the `Air` associated type to the AIR of the
// computation we defined previously, and set the `Trace` associated type to `TraceTable`
// struct as we don't need to define a custom trace for our computation.
impl Prover for WorkProver {
    type BaseField = BaseElement;
    type Air = WorkAir;
    type Trace = TraceTable<Self::BaseField>;

    // Our public inputs consist of the first and last value in the execution trace.
    fn get_pub_inputs(&self, trace: &Self::Trace) -> PublicInputs {
        let last_step = trace.length() - 1;
        PublicInputs {
            start: trace.get(0, 0),
            result: trace.get(1, last_step),
        }
    }

    fn options(&self) -> &ProofOptions {
        &self.options
    }
}
