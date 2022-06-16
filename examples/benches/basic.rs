use criterion::{criterion_group, criterion_main, Criterion};
use examples::basic::generate_proof;
use winterfell::math::fields::f128::BaseElement;
use std::time::Duration;
use examples::basic::verify_proof;


fn basic(c: &mut Criterion) {
    let mut group = c.benchmark_group("basic");
    group.sample_size(10);
    group.measurement_time(Duration::from_secs(30));


    group.bench_function("generate_proof", |bench| {
        bench.iter(|| generate_proof());
    });

    let (result, proof) = generate_proof();
    
    group.bench_function("verify_proof", |bench| {
        bench.iter(|| verify_proof(BaseElement::new(1), result, &proof));
    });

    group.finish();
}

criterion_group!(basic_group, basic);
criterion_main!(basic_group);
