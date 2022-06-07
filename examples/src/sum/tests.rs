// Copyright (c) Facebook, Inc. and its affiliates.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

pub fn build_proof_options(use_extension_field: bool) -> winterfell::ProofOptions {
    use winterfell::{FieldExtension, HashFunction, ProofOptions};

    let extension = if use_extension_field {
        FieldExtension::Quadratic
    } else {
        FieldExtension::None
    };
    ProofOptions::new(28, 8, 0, HashFunction::Blake3_256, extension, 4, 256)
}

#[test]
fn fib2_test_basic_proof_verification() {
    let fib = Box::new(super::SumExample::new(16, build_proof_options(false)));
    crate::tests::test_basic_proof_verification(fib);
}

#[test]
fn fib2_test_basic_proof_verification_extension() {
    let fib = Box::new(super::SumExample::new(16, build_proof_options(true)));
    crate::tests::test_basic_proof_verification(fib);
}

#[test]
fn fib2_test_basic_proof_verification_fail() {
    let fib = Box::new(super::SumExample::new(16, build_proof_options(false)));
    crate::tests::test_basic_proof_verification_fail(fib);
}
