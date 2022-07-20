use std::{env, path::Path, process::Command};

// TODO: switch to cargo binary dependency when available
// see https://rust-lang.github.io/rfcs/3028-cargo-binary-dependencies.html
pub fn main() {
    println!("cargo:rerun-if-changed=../iden3_circom/");
    let cargo = env::var("CARGO").unwrap();

    // initialize and update circom git submodule
    if ! Path::new("iden3_circom/.git").exists() {
        Command::new("git")
            .arg("submodule")
            .arg("update")
            .arg("--init")
            .arg("--recursive")
            .status()
            .unwrap();
    }

    println!("{:?}", std::str::from_utf8(&Command::new("pwd").output().unwrap().stdout).unwrap());

    // build circom
    Command::new(cargo)
        .arg("build")
        .arg("--release")
        .current_dir("../iden3_circom")
        .status()
        .unwrap();
}
