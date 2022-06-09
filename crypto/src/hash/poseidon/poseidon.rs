//padding with 0s and a single one
use super::param::*;
use super::digest::ElementDigest;
use std::vec::Vec;
//FIXME: f64 to f256
use math::{fields::f64::BaseElement,FieldElement};

pub fn digest(input: &[u8]) -> ElementDigest{

    /* let num_chunks = if input.len() % 32 == 0 {
        input.len() / 32
    } else {
        input.len() / 32 + 1
    }; */

    let mut formatted_input = [BaseElement::ZERO;T];

    for (i,chunk) in input.chunks(32).enumerate() {

        // convert the bytes into a field element and absorb it into the rate portion of the
        // state; if the rate is filled up, apply the Rescue permutation and start absorbing
        // again from zero index.
        let mut buf = [0_u8; 8];
        buf.copy_from_slice(chunk);
        formatted_input[i] = BaseElement::new(u64::from_le_bytes(buf));

    }

    let mut output = formatted_input.clone().to_vec();

    padder(&mut output);
    hash(&mut output);

    ElementDigest::new(vec_to_array(output))


}

pub fn elements_digest(input: &[BaseElement]) -> ElementDigest{

    let mut temp = input.clone().to_vec();
    padder(&mut temp); 

    ElementDigest::new(hash(&mut temp))
    

}

pub fn padder(input: &mut Vec<BaseElement>){

    let l = input.len();
    assert_eq!(l,T);
    let padded_length = (l/RATE +1) * RATE;

    if l != padded_length {

        input.push(BaseElement::new(1));

        for _i in l+1..padded_length {
            input.push(BaseElement::new(0))
        }
        
    }

}


pub fn hash(input: &mut Vec<BaseElement>) -> [BaseElement;RATE] {

    let ref mut state = [BaseElement::new(0);T].to_vec(); 
    
    for i in 0..input.len()/RATE {

        //absorbtion
        for j in 0..RATE {
            state[j] = state[j] + input[i*RATE+j]
        }

        permutation(state);

    }

    state[..RATE].try_into().unwrap()

}

pub fn permutation(state: &mut Vec<BaseElement>) {

    let ref mut temp = state.clone()[..T].to_vec();

    for j in 0..R_F/2 {
        full_permutation(temp,j);
    }

    for j in 0..R_P {
        partial_permutation(temp,j+R_F/2);
    }

    for j in 0..R_F/2 {
        full_permutation(temp,j + R_F/2 + R_P);
    }

    state[..T].copy_from_slice(&temp);
    
}

pub fn full_permutation(state: &mut Vec<BaseElement>, i : usize) {

    add_constants(state,i * T);
    apply_sbox(state);
    apply_mds(state);

}

pub fn partial_permutation(state: &mut Vec<BaseElement>, i : usize) {

    add_constants(state,i * T);
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
            temp[j] = E::from(MDS[i * T + j]) * state[j];
        }
            
        for j in 0..T {
            result[i] += temp[j];
        }
    }
    state.copy_from_slice(&result);
}


//HELPER FUNCTION

pub fn vec_to_array<T, const N: usize>(v: Vec<T>) -> [T; N] {
    v.try_into()
        .unwrap_or_else(|v: Vec<T>| panic!("Expected a Vec of length {} but it was {}", N, v.len()))
}