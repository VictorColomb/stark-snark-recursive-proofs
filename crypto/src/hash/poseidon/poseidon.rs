use crate::hash::ByteDigest;

//padding with 0s and a single one
use super::param::*;
use math::{fields::f256::BaseElement, FieldElement};
use std::vec::Vec;

pub fn digest(input: &[u8]) -> ByteDigest<32> {
    let mut formatted_input = [BaseElement::ZERO; T];

    for (i, chunk) in input.chunks(32).enumerate() {
        // convert the bytes into a field element and absorb it into the rate portion of the
        // state; if the rate is filled up, apply the Rescue permutation and start absorbing
        // again from zero index.
        formatted_input[i] = BaseElement::from_le_bytes(chunk);
    }

    let mut output = formatted_input.clone().to_vec();

    padder(&mut output);

    ByteDigest(hash(&mut output))
}

pub fn padder(input: &mut Vec<BaseElement>) {
    let l = input.len();
    assert_eq!(l, T);
    let padded_length = (l / RATE + 1) * RATE;

    if l != padded_length {
        input.push(BaseElement::ONE);

        for _i in l + 1..padded_length {
            input.push(BaseElement::ZERO)
        }
    }
}

pub fn hash(input: &mut Vec<BaseElement>) -> [u8; 32 * RATE] {
    let ref mut state = [BaseElement::ZERO; T].to_vec();

    for i in 0..input.len() / RATE {
        //absorbtion
        for j in 0..RATE {
            state[j] += input[i * RATE + j]
        }

        permutation(state);
    }

    let mut output = [0_u8; 32 * RATE];
    for i in 0..RATE {
        output[i..i + 32].copy_from_slice(&state[i].to_le_bytes())
    }

    output
}

pub fn permutation(input: &mut Vec<BaseElement>) {
    let ref mut state = input.clone()[..T].to_vec();

    for j in 0..R_F / 2 {
        full_round(state, j);
    }

    for j in 0..R_P {
        partial_round(state, j + R_F / 2);
    }

    for j in 0..R_F / 2 {
        full_round(state, j + R_F / 2 + R_P);
    }

    input[..T].copy_from_slice(&state);
}

#[inline(always)]
pub fn full_round(state: &mut Vec<BaseElement>, i: usize) {
    add_constants(state, i * T);
    apply_sbox(state);
    apply_mds(state);
}

#[inline(always)]
pub fn partial_round(state: &mut Vec<BaseElement>, i: usize) {
    add_constants(state, i * T);
    state[0] = state[0].exp(ALPHA.into());
    apply_mds(state);
}

#[inline(always)]
pub fn add_constants(state: &mut [BaseElement], offset: usize) {
    for i in 0..T {
        state[i] += ROUND_CONSTANTS[offset + i];
    }
}

#[inline(always)]
pub fn apply_sbox<E: FieldElement>(state: &mut [E]) {
    for i in 0..T {
        state[i] = state[i].exp(ALPHA.into());
    }
}

#[inline(always)]
pub fn apply_mds<E: FieldElement + From<BaseElement>>(state: &mut [E]) {
    let mut result = [E::ZERO; T];
    let mut temp = [E::ZERO; T];
    for i in 0..T {
        for j in 0..T {
            temp[j] = E::from(MDS[i][j]) * state[j];
        }

        for j in 0..T {
            result[i] += temp[j];
        }
    }
    state.copy_from_slice(&result);
}
