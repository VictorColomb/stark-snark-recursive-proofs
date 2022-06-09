mod param;
use param::*;

mod poseidon;

#[cfg(test)]
mod tests;

use super::{Digest,ElementHasher, Hasher};
//FIXME: f64 -> f256
use math::{fields::f64::BaseElement, FieldElement, StarkField};

mod digest;
pub use digest::ElementDigest;

// POSEIDON WITH 256-BIT OUTPUT
// ===============================================================================================
/// Implementation of the [Hasher](super::Hasher) trait for POSEIDON hash function with 256-bit
/// output.
const DIGEST_SIZE : usize = 1;



pub struct Poseidon();

impl Hasher for Poseidon {
    // TODO: ByteDigest<32>; ?  See SHA3 / RESCUE
    type Digest = ElementDigest;

    fn hash(bytes: &[u8]) -> Self::Digest {
        // return the first [RATE] elements of the state as hash result
        poseidon::digest(bytes)
    }

    fn merge(values: &[Self::Digest; 2]) -> Self::Digest {
        poseidon::elements_digest(Self::Digest::digests_as_elements(values)).into()
    }

    fn merge_with_int(seed: Self::Digest, value: u64) -> Self::Digest {
        //FIXME: T+2??
        let mut state = [BaseElement::ZERO; T+2];
        state[0..T].copy_from_slice(seed.as_elements());
        state[T] = BaseElement::new(value);
        if value > BaseElement::MODULUS {
            state[T + 1] = BaseElement::new(value / BaseElement::MODULUS);
        }
        poseidon::elements_digest(&state)
    }
}

impl ElementHasher for Poseidon {
    type BaseField = BaseElement;

    fn hash_elements<E: FieldElement<BaseField = Self::BaseField>>(elements: &[E]) -> Self::Digest {
        // convert the elements into a list of base field elements
        let elements = E::as_base_elements(elements);

        poseidon::elements_digest(elements)

    }
}