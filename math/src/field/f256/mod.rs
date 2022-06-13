//! An implementation of a 256-bit STARK-friendly prime field with the modulus being the order of
//! the sub-group of curve BLS12-381 - namely 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001.
//!
//! Operations in this field are implemented using Barret reduction and are stored in their
//! canonical form using [U256] as the backing type. However, this field was not chosen with any
//! significant thought given to performance, and the implementations of most operations are
//! sub-optimal as well.

use super::{ExtensibleField, FieldElement, StarkField};
use core::{
    fmt::{Display, Formatter},
    mem,
    ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Neg, Sub, SubAssign},
    slice,
};
use utils::{AsBytes, Deserializable, DeserializationError, Randomizable, Serializable};

mod u256;
pub use u256::U256;

mod u512;
pub use u512::U512;

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
/// Internal values are stored in their canonical form in the range [0, M). The backing type is [U256].
#[derive(Copy, Clone, Debug, PartialEq, Eq, Default)]
pub struct BaseElement(pub U256);

impl BaseElement {
    /// Creates a new field element from a U256 value. If the value is greater or equal to
    /// the field modulus, modular reduction is silently performed.
    pub fn new<T>(value: T) -> Self
    where
        T: Into<U256>,
    {
        let mut v: U256 = value.into();
        while v >= M {
            v -= M;
        }
        BaseElement(v)
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
        BaseElement::from(inv(self.0))
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
        Self::new(add(self.0, rhs.0))
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
        Self::new(sub(self.0, rhs.0))
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
        Self::new(mul(self.0, rhs.0))
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
        Self::new(mul(self.0, inv(rhs.0)))
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
        Self::new(sub(U256::zero(), self.0))
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
        let mut bytes = Vec::with_capacity(ELEMENT_BYTES);
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
        Self::new(U256::from_little_endian(bytes))
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
    let t = U512::from(a) * U512::from(b);
    (t % U512::from(M)).low_u256()
}

/// Computes y such that (x * y) % m = 1 except for when x = 0. In that case,
/// 0 is returned. x is assumed to be a valid field element.
fn inv(x: U256) -> U256 {
    xgcd(x, M).0 % M
}

// HELPER FUNCTIONS

/// Extended Euclidean Algorithm for unsigned integers. Returns the Bézout coefficients.
pub fn xgcd(a: U256, b: U256) -> (U256, U256) {
    let mut r0 = a.clone();
    let mut r1 = b.clone();
    let mut s0 = U256::one();
    let mut s1 = U256::zero();
    let mut t0 = U256::zero();
    let mut t1 = U256::one();
    let mut n = 0;

    while r1 != U256::zero() {
        let q = r0 / r1;
        r0 = if r0 > q * r1 {r0 - q*r1} else {q*r1 - r0};
        mem::swap(&mut r0, &mut r1);

        s0 = s0 + q*s1;
        mem::swap(&mut s0, &mut s1);

        t0 = t0 + q*t1;
        mem::swap(&mut t0, &mut t1);

        n += 1;
    }

    if n % 2 != 0 {
        s0 = b - s0;
    } else {
        t0 = a - t0;
    }

    (s0, t0)
}
