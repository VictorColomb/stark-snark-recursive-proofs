use winter_circom_prover::{check_ood_frame, circom_verify};

mod air;
use air::WorkAir;

fn main() {
    check_ood_frame::<WorkAir>("sum");
    circom_verify("sum");
}
