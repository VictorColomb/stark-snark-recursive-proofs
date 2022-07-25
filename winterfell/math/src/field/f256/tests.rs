// BASIC ALGEBRA
// ================================================================================================

use num_bigint::BigUint;
use rand_utils::{rand_value, rand_vector};

use super::{AsBytes, BaseElement, FieldElement, StarkField, M};

#[test]
fn add() {
    // test identity
    let r: BaseElement = rand_value();
    assert_eq!(r, r + BaseElement::ZERO);

    // test addition within bounds
    assert_eq!(
        BaseElement::from(5u8),
        BaseElement::from(2u8) + BaseElement::from(3u8)
    );

    // test overflow
    let t = BaseElement::from(BaseElement::MODULUS - (1 as u64));
    assert_eq!(BaseElement::ZERO, t + BaseElement::ONE);
    assert_eq!(BaseElement::ONE, t + BaseElement::from(2u8));

    // test random values
    let r1: BaseElement = rand_value();
    let r2: BaseElement = rand_value();

    let mut bytes = [0u8; 32];
    M.to_little_endian(&mut bytes);
    let big_m = BigUint::from_bytes_le(&bytes);

    let expected = (r1.to_biguint() + r2.to_biguint()) % big_m;
    let expected = BaseElement::from_biguint(expected);
    assert_eq!(expected, r1 + r2);
}

#[test]
fn sub() {
    let r: BaseElement = rand_value();
    assert_eq!(r, r - BaseElement::ZERO);

    // test sub within bounds
    assert_eq!(
        BaseElement::from(2u8),
        BaseElement::from(5u8) - BaseElement::from(3u8)
    );

    // test underflow
    let expected = BaseElement::from(BaseElement::MODULUS - 2);
    assert_eq!(expected, BaseElement::from(3u8) - BaseElement::from(5u8));
}

#[test]
fn mul() {
    // identity
    let r: BaseElement = rand_value();
    assert_eq!(BaseElement::ZERO, BaseElement::ZERO * r);
    assert_eq!(r, r * BaseElement::ONE);

    // test multiplication within bounds
    assert_eq!(
        BaseElement::from(15u8),
        BaseElement::from(3u8) * BaseElement::from(5u8)
    );

    // test overflow
    let m = BaseElement::MODULUS;
    let t = BaseElement::from(m - 1);
    assert_eq!(BaseElement::ONE, t * t);
    assert_eq!(BaseElement::from(m - 2), t * BaseElement::from(2u8));
    assert_eq!(BaseElement::from(m - 4), t * BaseElement::from(4u8));

    let t = (m + 1) / 2;
    assert_eq!(
        BaseElement::ONE,
        BaseElement::from(t) * BaseElement::from(2u8)
    );
}

#[test]
fn inv() {
    // identity
    assert_eq!(BaseElement::ONE, BaseElement::inv(BaseElement::ONE));
    assert_eq!(BaseElement::ZERO, BaseElement::inv(BaseElement::ZERO));

    // test random values
    let x: Vec<BaseElement> = rand_vector(1000);
    for i in 0..x.len() {
        let y = BaseElement::inv(x[i]);
        assert_eq!(BaseElement::ONE, x[i] * y);
    }
}

// HELPER FUNCTIONS
// ================================================================================================

impl BaseElement {
    fn to_biguint(&self) -> BigUint {
        BigUint::from_bytes_le(self.as_bytes())
    }

    fn from_biguint(value: BigUint) -> Self {
        let bytes = value.to_bytes_le();
        let mut buffer = [0u8; 32];
        buffer[0..bytes.len()].copy_from_slice(&bytes);
        BaseElement::try_from(buffer).unwrap()
    }
}
