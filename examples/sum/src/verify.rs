use winter_circom_prover::{
    check_ood_frame, circom_verify,
    utils::{LoggingLevel, WinterCircomError},
};

mod air;
use air::WorkAir;

fn main() -> Result<(), WinterCircomError> {
    check_ood_frame::<WorkAir>("sum");
    circom_verify("sum", LoggingLevel::Verbose)?;

    Ok(())
}
