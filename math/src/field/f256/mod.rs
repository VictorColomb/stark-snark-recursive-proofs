//! An implementation of a 256-bit STARK-friendly prime field with the modulus being the order of
//! the sub-group of curve BLS12-381 - namely 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001.
//!
//! Operations in this field are implemented using Barret reduction and are stored in their
//! canonical form using [U256](primitive_types::U256) as the backing type. However, this field was not chosen with any
//! significant thought given to performance, and the implementations of most operations are
//! sub-optimal as well.

use super::{ExtensibleField, FieldElement, StarkField};
use core::{
    fmt::{Display, Formatter},
    mem,
    ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Sub, SubAssign},
    slice,
};
use utils::{DeserializationError, Randomizable, AsBytes, Serializable, Deserializable};

mod u256;
pub use u256::U256;

#[cfg(test)]
mod tests;

// CONSTANTS
// ================================================================================================

// Field modulus = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
const M: U256 = U256([
    18446744069414584321,
    6034159408538082302,
    3691218898639771653,
    8353516859464449352,
]);

// 2^32 root of unity = 0x16a2a19edfe81f20d09b681922c813b4b63683508c2280b93829971f439f0d2b
const G: U256 = U256([
    4046931900703378731,
    13129826145616953529,
    15031722638446171060,
    1631043718794977056,
]);

// Number of bytes needed to represent field element
const ELEMENT_BYTES: usize = core::mem::size_of::<U256>();

// FIELD ELEMENT
// ================================================================================================

/// Represents a base field element.
///
/// Internal values are stored in their canonical form in the range [0, M). The backing type is [U256](primitive_types::U256).
#[derive(Copy, Clone, Debug, PartialEq, Eq, Default)]
pub struct BaseElement(U256);

impl BaseElement {
    /// Creates a new field element from a U256 value. If the value is greater or equal to
    /// the field modulus, modular reduction is silently performed.
    pub fn new(value: U256) -> Self {
        BaseElement(if value < M { value } else { value - M })
    }
}

impl FieldElement for BaseElement {
    type PositiveInteger = U256;
    type BaseField = Self;

    const ZERO: Self = BaseElement(U256([0, 0, 0, 0]));
    const ONE: Self = BaseElement(U256([1, 0, 0, 0]));

    const ELEMENT_BYTES: usize = ELEMENT_BYTES;

    const IS_CANONICAL: bool = true;

    fn inv(self) -> Self {
        todo!()
    }

    fn conjugate(&self) -> Self {
        BaseElement(self.0)
    }

    fn elements_as_bytes(elements: &[Self]) -> &[u8] {
        let p = elements.as_ptr();
        let len = elements.len() * Self::ELEMENT_BYTES;
        unsafe { slice::from_raw_parts(p as *const u8, len) }
    }

    unsafe fn bytes_as_elements(bytes: &[u8]) -> Result<&[Self], DeserializationError> {
        if bytes.len() % ELEMENT_BYTES != 0 {
            return Err(DeserializationError::InvalidValue(format!(
                "number of bytes({}) does not divide into whole number of field elements",
                bytes.len()
            )));
        }

        let p = bytes.as_ptr();
        let len = bytes.len() / ELEMENT_BYTES;

        if (p as usize) % mem::align_of::<U256>() != 0 {
            return Err(DeserializationError::InvalidValue(
                "slice memory alignment is not valid for this field element type".to_string(),
            ));
        }

        Ok(slice::from_raw_parts(p as *const Self, len))
    }

    fn as_base_elements(elements: &[Self]) -> &[Self::BaseField] {
        elements
    }
}

impl StarkField for BaseElement {
    const MODULUS: Self::PositiveInteger = M;

    const MODULUS_BITS: u32 = 256;

    const GENERATOR: Self = BaseElement(U256([7, 0, 0, 0]));

    const TWO_ADICITY: u32 = 32;
    const TWO_ADIC_ROOT_OF_UNITY: Self = BaseElement(G);

    fn get_modulus_le_bytes() -> Vec<u8> {
        let mut bytes = Vec::with_capacity(BaseElement::ELEMENT_BYTES);
        Self::MODULUS.to_little_endian(&mut bytes);
        bytes.to_vec()
    }

    fn as_int(&self) -> Self::PositiveInteger {
        self.0
    }
}

impl Randomizable for BaseElement {
    const VALUE_SIZE: usize = ELEMENT_BYTES;

    fn from_random_bytes(bytes: &[u8]) -> Option<Self> {
        Self::try_from(bytes).ok()
    }
}

impl Display for BaseElement {
    fn fmt(&self, f: &mut Formatter) -> core::fmt::Result {
        write!(f, "{}", self.0)
    }
}

// OVERLOADED OPERATORS
// ================================================================================================

impl Add for BaseElement {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Self(add(self.0, rhs.0))
    }
}

impl AddAssign for BaseElement {
    fn add_assign(&mut self, rhs: Self) {
        *self = *self + rhs
    }
}

impl Sub for BaseElement {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        Self(sub(self.0, rhs.0))
    }
}

impl SubAssign for BaseElement {
    fn sub_assign(&mut self, rhs: Self) {
        *self = *self - rhs
    }
}

impl Mul for BaseElement {
    type Output = Self;

    fn mul(self, rhs: Self) -> Self {
        Self(mul(self.0, rhs.0))
    }
}

impl MulAssign for BaseElement {
    fn mul_assign(&mut self, rhs: Self) {
        *self = *self * rhs
    }
}

impl Div for BaseElement {
    type Output = Self;

    fn div(self, rhs: Self) -> Self {
        Self(mul(self.0, inv(rhs.0)))
    }
}

impl DivAssign for BaseElement {
    fn div_assign(&mut self, rhs: Self) {
        *self = *self / rhs
    }
}

impl Neg for BaseElement {
    type Output = Self;

    fn neg(self) -> Self {
        Self(sub(U256::zero(), self.0))
    }
}

// QUADRATIC EXTENSION
// ================================================================================================

/// Quadratic extension for this field is not implemented.
impl ExtensibleField<2> for BaseElement {
    #[inline(always)]
    fn mul(_a: [Self; 2], _b: [Self; 2]) -> [Self; 2] {
        unimplemented!()
    }

    #[inline(always)]
    fn mul_base(_a: [Self; 2], _b: Self) -> [Self; 2] {
        unimplemented!()
    }

    #[inline(always)]
    fn frobenius(_x: [Self; 2]) -> [Self; 2] {
        unimplemented!()
    }

    fn is_supported() -> bool {
        false
    }
}

// CUBIC EXTENSION
// ================================================================================================

/// Cubic extension for this field is not implemented as quadratic extension already provides
/// sufficient security level.
impl ExtensibleField<3> for BaseElement {
    fn mul(_a: [Self; 3], _b: [Self; 3]) -> [Self; 3] {
        unimplemented!()
    }

    #[inline(always)]
    fn mul_base(_a: [Self; 3], _b: Self) -> [Self; 3] {
        unimplemented!()
    }

    #[inline(always)]
    fn frobenius(_x: [Self; 3]) -> [Self; 3] {
        unimplemented!()
    }

    fn is_supported() -> bool {
        false
    }
}

// TYPE CONVERSIONS
// ================================================================================================

impl From<U256> for BaseElement {
    /// Converts 256-bit value into field element. If the value is greater than or equal to
    /// the field modulus, modular reduction is silently applied.
    fn from(value: U256) -> Self {
        BaseElement::new(value)
    }
}

impl From<u128> for BaseElement {
    /// Converts a 128-bit integer into a field element.
    fn from(value: u128) -> Self {
        BaseElement::new(U256::from(value))
    }
}

impl From<u64> for BaseElement {
    /// Converts a 64-bit value into a field element.
    fn from(value: u64) -> Self {
        BaseElement::new(U256::from(value))
    }
}

impl From<u32> for BaseElement {
    /// Converts a 32-bit value into a field element.
    fn from(value: u32) -> Self {
        BaseElement::new(U256::from(value))
    }
}

impl From<u16> for BaseElement {
    /// Converts a 16-bit value into a field element.
    fn from(value: u16) -> Self {
        BaseElement::new(U256::from(value))
    }
}

impl From<u8> for BaseElement {
    /// Converts an 8-bit value into a field element.
    fn from(value: u8) -> Self {
        BaseElement::new(U256::from(value))
    }
}

impl From<[u8; 32]> for BaseElement {
    /// Converts the value encoded in an array of 32 bytes into a field element. The bytes
    /// are assumed to be in little-endian byte order. If the value is greater than or equal
    /// to the field modulus, modular reduction is silently performed.
    fn from(bytes: [u8; 32]) -> Self {
        let value = U256::from_little_endian(&bytes);
        BaseElement::from(value)
    }
}

impl From<[u64; 4]> for BaseElement {
    /// Converts the value encoded in an array of 4 least significant first 64-bit integers.
    fn from(value: [u64; 4]) -> Self {
        BaseElement::new(U256(value))
    }
}

impl<'a> TryFrom<&'a [u8]> for BaseElement {
    type Error = String;

    fn try_from(bytes: &[u8]) -> Result<Self, Self::Error> {
        let value = bytes
            .try_into()
            .map(U256::from_little_endian)
            .map_err(|error| format!("{}", error))?;
        if value >= M {
            return Err(format!(
                "cannot convert bytes into a field element: \
                value {} is greater or equal to the field modulus",
                value
            ));
        }
        Ok(BaseElement::new(value))
    }
}

impl AsBytes for BaseElement {
    fn as_bytes(&self) -> &[u8] {
        let self_ptr: *const BaseElement = self;
        unsafe { slice::from_raw_parts(self_ptr as *const u8, ELEMENT_BYTES) }
    }
}

// SERIALIZATION / DESERIALIZATION
// ================================================================================================

impl Serializable for BaseElement {
    fn write_into<W: utils::ByteWriter>(&self, target: &mut W) {
        let mut bytes= Vec::with_capacity(ELEMENT_BYTES);
        self.0.to_little_endian(&mut bytes);
        target.write_u8_slice(&bytes);
    }
}

impl Deserializable for BaseElement {
    fn read_from<R: utils::ByteReader>(source: &mut R) -> Result<Self, DeserializationError> {
        let value = U256::from_little_endian(&source.read_u8_array::<32>()?);
        if value >= M {
            return Err(DeserializationError::InvalidValue(format!(
                "invalid field element: value {} is greater than or equal to the field modulus",
                value
            )));
        }
        Ok(BaseElement(value))
    }
}

impl BaseElement{
    pub fn to_le_bytes(&self) -> [u8; 32] {
        let mut bytes = [0u8; 32];
        self.0.to_little_endian(&mut bytes);
        bytes
    }

    pub fn from_le_bytes(bytes: &[u8]) -> Self {
        Self(U256::from_little_endian(bytes))
    }
}

// FINITE FIELD ARITHMETIC
// ================================================================================================

/// Computes (a + b) % m. a and b are assumed to be valid field elements.
fn add(a: U256, b: U256) -> U256 {
    let z = M - b;
    if a < z {
        M - z + a
    } else {
        a - z
    }
}

/// Computes (a - b) % m; a and b are assumed to be valid field elements.
fn sub(a: U256, b: U256) -> U256 {
    if a < b {
        M - b + a
    } else {
        a - b
    }
}

/// Computes (a * b) % m. a and b are assumed to be valid field elements.
fn mul(a: U256, b: U256) -> U256 {
    let (x0, x1, x2) = mul_256x128(a, (b >> 128).low_u128()); // x = a * b_hi
    let (mut x0, mut x1, x2) = mul_reduce(x0, x1, x2); // x = x - (x >> 256) * m
    if x2 == 1 {
        // if overflow, substract modulus
        let (t0, t1) = sub_modulus(x0, x1); // x = x - m
        x0 = t0;
        x1 = t1;
    }

    let (y0, y1, y2) = mul_256x128(a, b.low_u128()); // y = a * b_lo

    let (mut y1, carry) = add128_with_carry(y1, x0, 0);
    let (mut y2, y3) = add128_with_carry(y2, x1, carry); // y = y + (x << 128)
    if y3 == 1 {
        // if overflow, substract modulus
        let (t0, t1) = sub_modulus(y1, y2);
        y1 = t0;
        y2 = t1;
    }

    let (mut z0, mut z1, z2) = mul_reduce(y0, y1, y2); // z = y - (y >> 256) * m

    // make sure z is smaller than m
    if z2 == 1 || (z1 == (M >> 128).low_u128() && z0 >= M.low_u128()) {
        let (t0, t1) = sub_modulus(z0, z1);
        z0 = t0;
        z1 = t1;
    }

    (U256::from(z1) << 128) + U256::from(z0)
}

/// Computes y such that (x * y) % m = 1 except for when x = 0. In that case,
/// 0 is returned. x is assumed to be a valid field element.
fn inv(x: U256) -> U256 {
    if x == U256::zero() {
        return U256::zero();
    }

    let mut v = M;
    let (mut a0, mut a1, mut a2) = (0, 0, 0);
    let (mut u0, mut u1, mut u2) = if x & U256::one() == U256::one() {
        // u = x
        (x.low_u128(), (x >> 128).low_u128(), 0)
    } else {
        // u = x + m
        add_384x384(x.low_u128(), (x >> 128).low_u128(), 0, M.low_u128(), (M >> 128).low_u128(), 0)
    };
    // d = m - 1
    let (mut d0, mut d1, mut d2) = (M.low_u128() - 1, (M >> 128).low_u128(), 0);

    // compute the inverse
    while v != U256::one() {
        while u2 > 0 || (U256::from(u0) + (U256::from(u1) << 128)) > v {
            // u > v
            // u = u - v
            let (t0, t1, t2) = sub_384x384(u0, u1, u2, v.low_u128(), (v >> 128).low_u128(), 0);
            u0 = t0;
            u1 = t1;
            u2 = t2;

            // d = d + 1
            let (t0, t1, t2) = add_384x384(d0, d1, d2, a0, a1, a2);
            d0 = t0;
            d1 = t1;
            d2 = t2;

            while u0 & 1 == 0 {
                if d0 & 1 == 1 {
                    // d = d + m
                    let (t0, t1, t2) = add_384x384(d0, d1, d2, M.low_u128(), (M >> 128).low_u128(), 0);
                    d0 = t0;
                    d1 = t1;
                    d2 = t2;
                }

                // u = u >> 1
                u0 = (u0 >> 1) | ((u1 & 1) << 127);
                u1 = (u1 >> 1) | ((u2 & 1) << 127);
                u2 >>= 1;

                // d = d >> 1
                d0 = (d0 >> 1) | ((d1 & 1) << 127);
                d1 = (d1 >> 1) | ((d2 & 1) << 127);
                d2 >>= 1;
            }
        }

        // v = v - u
        v -= U256::from(u0) + (U256::from(u1) << 128);

        // a = a + d
        let (t0, t1, t2) = add_384x384(a0, a1, a2, d0, d1, d2);
        a0 = t0;
        a1 = t1;
        a2 = t2;

        while v & U256::one() == U256::zero() {
            if a0 & 1 == 1 {
                // a = a + m
                let (t0, t1, t2) = add_384x384(a0, a1, a2, M.low_u128(), (M >> 128).low_u128(), 0);
                a0 = t0;
                a1 = t1;
                a2 = t2;
            }

            v >>= 1;

            // a = a >> 1
            a0 = (a0 >> 1) | ((a1 & 1) << 63);
            a1 = (a1 >> 1) | ((a2 & 1) << 63);
            a2 >>= 1;
        }
    }

    let mut a = U256::from(a0) + (U256::from(a1) << 128);
    while a2 > 0 || a >= M {
        let (t0, t1, t2) = sub_384x384(a0, a1, a2, M.low_u128(), (M >> 128).low_u128(), 0);
        a0 = t0;
        a1 = t1;
        a2 = t2;
        a = U256::from(a0) + (U256::from(a1) << 128);
    }

    a
}

// HELPER FUNCTIONS
// ================================================================================================

/// Multiplies a 256-bit number with a 128-bit. Returns the result as a least significant first u128 3-tuple.
#[inline]
fn mul_256x128(a: U256, b: u128) -> (u128, u128, u128) {
    let z_lo = (U256::from(a.low_u128())) * U256::from(b);
    let z_hi = (a >> 128) * (U256::from(b));
    let z_hi = z_hi + (z_lo >> 128);
    (z_lo.low_u128(), z_hi.low_u128(), (z_hi >> 128).low_u128())
}

#[inline]
fn mul_reduce(z0: u128, z1:u128, z2: u128) -> (u128, u128, u128) {
    let (q0, q1, q2) = mul_by_modulus(z2);
    let (z0, z1, z2) = sub_384x384(z0, z1, z2, q0, q1, q2);
    (z0, z1, z2)
}

/// Multiples a 128-bit number with the field modulus `M`.
///
/// Returns the result as a least significant first u128 3-tuple.
#[inline]
fn mul_by_modulus(a: u128) -> (u128, u128, u128) {
    let (a_lo, _) = (U256::from(a)).overflowing_mul(M);
    let a_hi = if a == 0 { 0 } else { a - 1 };
    (a_lo.low_u128(), (a_lo >> 128).low_u128(), a_hi)
}

/// Substracts the modulus `M` from the 256-bit input value encoded as a least significant first u128 2-tuple.
#[inline]
fn sub_modulus(a_lo: u128, a_hi: u128) -> (u128, u128) {
    let (mut z, _) = U256::zero().overflowing_sub(M);
    (z, _) = z.overflowing_add(U256::from(a_lo));
    (z, _) = z.overflowing_add(U256::from(a_hi) << 128);
    (z.low_u128(), (z >> 128).low_u128())
}

#[inline]
fn sub_384x384(a0: u128, a1: u128, a2: u128, b0: u128, b1: u128, b2: u128) -> (u128, u128, u128) {
    let (z0, _) = U256::from(a0).overflowing_sub(U256::from(b0));
    let (z1, _) = U256::from(a1).overflowing_sub(U256::from(b1).overflowing_add(z0 >> 255).0);
    let (z2, _) = U256::from(a2).overflowing_sub(U256::from(b2).overflowing_add(z1 >> 255).0);
    (z0.low_u128(), z1.low_u128(), z2.low_u128())
}

#[inline]
fn add_384x384(a0: u128, a1: u128, a2: u128, b0: u128, b1: u128, b2: u128) -> (u128, u128, u128) {
    let z0 = U256::from(a0) + U256::from(b0);
    let z1 = U256::from(a1) + U256::from(b1) + (z0 >> 255);
    let z2 = U256::from(a2) + U256::from(b2) + (z1 >> 255);
    (z0.low_u128(), z1.low_u128(), z2.low_u128())
}

#[inline]
fn add128_with_carry(a: u128, b: u128, carry: u128) -> (u128, u128) {
    let ret = U256::from(a) + U256::from(b) + U256::from(carry);
    (ret.low_u128(), (ret >> 128).low_u128())
}
