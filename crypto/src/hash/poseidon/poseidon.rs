//padding with 0s and a single one
use super::param::*;
use std::vec::Vec;
use math::{fields::f128::BaseElement,FieldElement};


pub fn digest(input: &[u8]) {

    let state  = vec![BaseElement::from(input)];
    padder(state);
    
    ElementDigest::new(state[DIGEST_RANGE].try_into().unwrap())

}

fn padder(state: &mut Vec<BaseElement>){

    let l = state.len();
    assert_eq!(l,T);
    let padded_length = (l/RATE +1) * RATE;

    if l != padded_length {

        state.push(BaseElement::new(1));

        for _i in l+1..padded_length {
            state.push(BaseElement::new(0))
        }
        
    }

}

fn _hash(state: &mut Vec<BaseElement>) {
    
    for i in 0..state.len()/RATE {

        //absorbtion
        for j in 0..RATE {
            state[j] = state[j] + state[i*RATE+j]
        }

        permutation(state);

    }

}

fn permutation(state: &mut Vec<BaseElement>) {

    for j in 0..R_F {
        full_permutation(state,j);
    }

    for j in 0..RATE {
        partial_permutation(state,j+R_F);
    }

    for j in 0..R_F {
        full_permutation(state,j + R_F + R_P);
    }
    
}

fn full_permutation(state: &mut Vec<BaseElement>, i : usize) {

    add_constants(state,i * T);
    apply_sbox(state);
    apply_mds(state);

}

fn partial_permutation(state: &mut Vec<BaseElement>, i : usize) {

    add_constants(state,i * T);
    state[0] = state[0].exp(ALPHA.into());
    apply_mds(state);

}

#[inline(always)]
#[allow(clippy::needless_range_loop)]
fn add_constants(state: &mut [BaseElement], offset: usize) {
    for i in 0..T {
        state[i] += ROUND_CONSTANTS[offset + i];
    }
}

#[inline(always)]
#[allow(clippy::needless_range_loop)]
fn apply_sbox<E: FieldElement>(state: &mut [E]) {
    for i in 0..T {
        state[i] = state[i].exp(ALPHA.into());
    }
}

#[inline(always)]
#[allow(clippy::needless_range_loop)]
fn apply_mds<E: FieldElement + From<BaseElement>>(state: &mut [E]) {
    let mut result = [E::ZERO; T];
    let mut temp = [E::ZERO; T];
    for i in 0..T {
        for j in 0..T {
            temp[j] = E::from(MDS[i * T + j]) * state[j];
        }

        for j in 0..T {
            result[i] += temp[j];
        }
    }
    state.copy_from_slice(&result);
}
