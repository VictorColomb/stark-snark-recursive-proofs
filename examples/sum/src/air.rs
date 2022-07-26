use serde::{ser::SerializeTuple, Serialize};
use winter_circom_prover::WinterPublicInputs;
use winter_circom_prover::winterfell::{
    math::{fields::f256::BaseElement, FieldElement},
    Air, AirContext, Assertion, ByteWriter, EvaluationFrame, FieldExtension, HashFunction,
    ProofOptions, TraceInfo, TransitionConstraintDegree, Serializable
};

#[derive(Clone, Default)]
pub struct PublicInputs {
    pub start: BaseElement,
    pub result: BaseElement,
}

impl WinterPublicInputs for PublicInputs {
    const NUM_PUB_INPUTS: usize = 2;
}

impl Serialize for PublicInputs {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let mut state = serializer.serialize_tuple(2)?;
        state.serialize_element(&self.start)?;
        state.serialize_element(&self.result)?;
        state.end()
    }
}

impl Serializable for PublicInputs {
    fn write_into<W: ByteWriter>(&self, target: &mut W) {
        target.write(self.start);
        target.write(self.result);
    }
}

pub struct WorkAir {
    context: AirContext<BaseElement>,
    start: BaseElement,
    result: BaseElement,
}

impl Air for WorkAir {
    type BaseField = BaseElement;
    type PublicInputs = PublicInputs;

    fn new(trace_info: TraceInfo, pub_inputs: PublicInputs, options: ProofOptions) -> Self {
        let degrees = vec![
            TransitionConstraintDegree::new(1),
            TransitionConstraintDegree::new(1),
        ];

        let num_assertions = 3;

        WorkAir {
            context: AirContext::new(trace_info, degrees, num_assertions, options),
            start: pub_inputs.start,
            result: pub_inputs.result,
        }
    }

    fn evaluate_transition<E: FieldElement + From<Self::BaseField>>(
        &self,
        frame: &EvaluationFrame<E>,
        _periodic_values: &[E],
        result: &mut [E],
    ) {
        let current = &frame.current();
        let next = &frame.next();

        result[0] = next[0] - (current[0] + E::ONE);
        result[1] = next[1] - (current[1] + current[0] + E::ONE);
    }

    fn get_assertions(&self) -> Vec<Assertion<Self::BaseField>> {
        let last_step = self.trace_length() - 1;
        vec![
            Assertion::single(0, 0, self.start),
            Assertion::single(1, 0, self.start),
            Assertion::single(1, last_step, self.result),
        ]
    }

    fn context(&self) -> &AirContext<Self::BaseField> {
        &self.context
    }
}

impl Default for WorkAir {
    fn default() -> Self {
        WorkAir::new(
            TraceInfo::new(1, 8),
            PublicInputs::default(),
            ProofOptions::new(
                32,
                8,
                0,
                HashFunction::Poseidon,
                FieldExtension::None,
                8,
                256,
            ),
        )
    }
}
