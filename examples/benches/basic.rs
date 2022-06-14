// Copyright (c) Facebook, Inc. and its affiliates.
//
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};
use examples::basic::generate_proof;
use std::time::Duration;

const SIZES: [usize; 2] = [256, 512];

fn basic(c: &mut Criterion) {
    let mut group = c.benchmark_group("basic");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));

    for &size in SIZES.iter() {
        group.bench_function(BenchmarkId::from_parameter(size), |bench| {
            bench.iter(|| generate_proof());
        });
    }
    group.finish();
}

criterion_group!(basic_group, basic);
criterion_main!(basic_group);
