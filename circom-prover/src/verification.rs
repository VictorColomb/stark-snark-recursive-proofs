use std::fs;

use winter_air::{Air, EvaluationFrame};
use winter_math::{
    fields::f256::{BaseElement, U256},
    FieldElement,
};

/// Check that the OOD trace frame corresponds to the given Air and the OOD
/// constraint evaluations.
///
/// The OOD trace frame is garanteed correct by the Circom SNARK proof. Indeed,
/// should it have been modified, the pseudo-randomly generated query positions
/// would be different and the Merkle commitment verifications would fail. This
/// function therefore garanties that the OOD constraint evaluations are
/// correct.
///
/// Requires the `public.json` file in the `target/circom/<circuit_name>/`
/// directory to contain `t` ood constraint evaluations and 2`t` ood trace frame
/// elements, in that order, where `t` is the trace width. This should be correct if the Circom proof was
/// generated with the [circom_prove](crate::circom_prove) function.
pub fn check_ood_frame<AIR>(circuit_name: &str)
where
    AIR: Air<BaseField = BaseElement> + Default,
{
    // public.json parsing
    let data = fs::read_to_string(format!("target/circom/{}/public.json", circuit_name))
        .expect("Unable to read file");
    let json: serde_json::Value =
        serde_json::from_str(&data).expect("public.json format incorrect!");

    let pub_inputs = json.as_array().unwrap();

    // public.json contains 3 * trace_width elements :
    //  - trace_width ood_constraint_evaluation
    //  - 2 * trace_width elements for the OOD trace frame
    let trace_width = pub_inputs.len() / 3;

    let mut channel_ood_constraint_evaluation = Vec::<BaseElement>::with_capacity(trace_width);

    for i in 0..trace_width {
        channel_ood_constraint_evaluation.push(BaseElement::new(
            U256::from_str_radix(pub_inputs[i].as_str().unwrap(), 10).unwrap(),
        ));
    }

    let mut frame = EvaluationFrame::new(trace_width);

    for i in 0..trace_width {
        frame.current_mut()[i] = BaseElement::new(
            U256::from_str_radix(pub_inputs[trace_width + i].as_str().unwrap(), 10).unwrap(),
        );
        frame.next_mut()[i] = BaseElement::new(
            U256::from_str_radix(pub_inputs[2 * trace_width + i].as_str().unwrap(), 10).unwrap(),
        );
    }

    // We only need to access the 'evaluate_constraints' method which doesn't depend on the air.
    // A default implementation of a Workair is sufficient here.
    let air = AIR::default();
    let mut ood_frame_constraint_evaluation = BaseElement::zeroed_vector(trace_width);
    air.evaluate_transition::<BaseElement>(&frame, &[], &mut ood_frame_constraint_evaluation);

    for i in 0..trace_width {
        assert!(
            ood_frame_constraint_evaluation[i] == channel_ood_constraint_evaluation[i],
            "\x1b[33m{}\x1b[0m",
            "Proof invalid: OOD not correct!"
        );
    }

    println!("\x1b[32m{}\x1b[0m", "OOD constraint evaluations are correct!");
}
