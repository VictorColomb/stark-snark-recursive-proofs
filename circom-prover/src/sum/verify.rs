use std::fs;
use winter_air::{Air, EvaluationFrame};
use winter_math::{fields::f256::{U256, BaseElement}, FieldElement};
mod air;
use air::{WorkAir};


fn main() {

    let prog_name = "sum";


    // public.json parsing
    let data = fs::read_to_string(format!("target/circom/{}_verifier/public.json",prog_name))
        .expect("Unable to read file");
    let json: serde_json::Value = serde_json::from_str(&data)
        .expect("JSON does not have correct format.");

    let pub_inputs = json.as_array().unwrap();

    // public.json contains 3 * trace_width elements :
    //  - trace_width ood_constraint_evaluation
    //  - 2 * trace_width elements for the OOD trace frame 
    let trace_width = pub_inputs.len() / 3;


    let mut channel_ood_constraint_evaluation = Vec::<BaseElement>::with_capacity(trace_width);
    
    for i in 0..trace_width {
        channel_ood_constraint_evaluation.push(BaseElement::new(U256::from_str_radix(pub_inputs[i].as_str().unwrap(),10).unwrap()));
    }
    

    let mut frame = EvaluationFrame::new(trace_width);
    
    for i in 0..trace_width {
        frame.current_mut()[i] = BaseElement::new(U256::from_str_radix(pub_inputs[trace_width + i].as_str().unwrap(),10).unwrap());
    }
    
    for i in 0..trace_width {
        frame.next_mut()[i] = BaseElement::new(U256::from_str_radix(pub_inputs[2 * trace_width + i].as_str().unwrap(),10).unwrap());
    }

    // We only need to access the 'evaluate_constraints' method which doesn't depend on the air.
    // A default implementation of a Workair is sufficient here.
    let air = WorkAir::default();
    let mut ood_frame_constraint_evaluation = BaseElement::zeroed_vector(trace_width);
    air.evaluate_transition::<BaseElement>(&frame, &[], &mut ood_frame_constraint_evaluation);

    for i in 0..trace_width {
        assert!(ood_frame_constraint_evaluation[i] == channel_ood_constraint_evaluation[i]);
    }
        
}