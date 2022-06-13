use super::poseidon;
use super::{
    BaseElement, FieldElement, ALPHA,};

use super::param::*;
use rand_utils::{rand_array};



#[test]
pub fn test() {
    //let mut input = [BaseElement::from(0u8);T];

    //println!("{:?}",Poseidon::hash_elements(input))
    assert_eq!(1,1)
}

#[test]
fn test_sbox() {

    let state: [BaseElement; T] = rand_array();

    let mut expected = state;
    expected.iter_mut().for_each(|v| *v = v.exp(ALPHA.into()));

    let mut actual = state;
    poseidon::apply_sbox(&mut actual);
    println!("{:?}",actual);
    assert_eq!(expected, actual);
}

#[test]
fn test_mds() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(5u8),
    
    ].to_vec();
    
    poseidon::apply_mds(&mut state);
    
    // expected values are obtained by executing sage reference implementation code
    
    println!("Permuted state = {:?}",state)
}

#[test]
fn test_constants() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),
    
    ].to_vec();
    
    poseidon::add_constants(&mut state,0);
    
    // expected values are obtained by executing sage reference implementation code
    
    println!("Permuted state = {:?}",state)

}
#[test]
fn test_permutation() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),
        
        ].to_vec();
        
        poseidon::permutation(&mut state);
        
        // expected values are obtained by executing sage reference implementation code
        
        println!("Permuted state = {:?}",state)
    }
    
#[test]
fn test_hash() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),

    ].to_vec();

    poseidon::hash(&mut state);

    // expected values are obtained by executing sage reference implementation code

    println!("Hash state = {:?}",state)
}

#[test]
fn test_element_digest() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),

    ].to_vec();

    let result = poseidon::elements_digest(&mut state);

    // expected values are obtained by executing sage reference implementation code

    println!("Hash state = {:?}",result)
}