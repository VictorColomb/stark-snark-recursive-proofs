use winterfell::math::fields::f128::BaseElement;

use super::generate_proof;
use super::verify_proof;

#[test]
pub fn test() {
    let (result,proof) = generate_proof();
    verify_proof(BaseElement::new(1),result,proof);
}