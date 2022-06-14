use super::poseidon;

use super::param::*;
use math::fields::f256::{BaseElement, U256};
use math::FieldElement;
use rand_utils::rand_array;

#[test]
fn test_sbox() {
    let state: [BaseElement; T] = rand_array();

    let mut expected = state.clone();
    expected.iter_mut().for_each(|v| *v = v.exp(ALPHA.into()));

    let mut actual = state;
    poseidon::apply_sbox(&mut actual);
    println!("{:?}", actual);
    assert_eq!(expected, actual);
}

#[test]
fn test_mds() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(2u8),
        BaseElement::from(0u8),
    ]
    .to_vec();

    poseidon::apply_mds(&mut state);

    // expected values are obtained by executing sage reference implementation code

    println!("Permuted state = {:?}", state)
}

#[test]
fn test_constants() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),
    ]
    .to_vec();

    poseidon::add_constants(&mut state, 0);

    // expected values are obtained by executing sage reference implementation code

    println!("Permuted state = {:?}", state)
}

#[test]
fn test_permutation() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),
    ]
    .to_vec();

    let expected = [
        BaseElement(U256::from(
            "0x28ce19420fc246a05553ad1e8c98f5c9d67166be2c18e9e4cb4b4e317dd2a78a",
        )),
        BaseElement(U256::from(
            "0x51f3e312c95343a896cfd8945ea82ba956c1118ce9b9859b6ea56637b4b1ddc4",
        )),
        BaseElement(U256::from(
            "0x3b2b69139b235626a0bfb56c9527ae66a7bf486ad8c11c14d1da0c69bbe0f79a",
        )),
    ];

    poseidon::permutation(&mut state);

    // expected values are obtained by executing sage reference implementation code
    assert_eq!(state, expected);
}

#[test]
fn test_hash() {
    let mut state = [
        BaseElement::from(0u8),
        BaseElement::from(1u8),
        BaseElement::from(2u8),
    ]
    .to_vec();

    poseidon::hash(&mut state);

    // expected values are obtained by executing sage reference implementation code

    println!("Hash state = {:?}", state)
}
