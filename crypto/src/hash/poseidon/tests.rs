use super::poseidon::{hash};
use math::fields::f128::BaseElement;

use super::param::*;



#[test]
pub fn test() {
    let mut input = vec![BaseElement::new(0);T];
    for i in 0..T {
        input[i] = BaseElement::new(i as u128);
    }
    hash(input);
    assert_eq!(1,1)
}
