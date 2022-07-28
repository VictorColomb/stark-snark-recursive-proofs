use std::{env, path::Path, process::Command};

// TODO: switch to cargo binary dependency when available
// see https://rust-lang.github.io/rfcs/3028-cargo-binary-dependencies.html
pub fn main() {
    println!("cargo:rerun-if-changed=../iden3/circom/");
    println!("cargo:rerun-if-changed=../iden3/snarkjs/build/");
    let cargo = env::var("CARGO").unwrap();

    // initialize and update git submodules
    if !(Path::new("iden3/circom/.git").exists() && Path::new("iden3/snarkjs/.git").exists()) {
        assert!(
            Command::new("git")
                .arg("submodule")
                .arg("update")
                .arg("--init")
                .arg("--recursive")
                .status()
                .unwrap()
                .success(),
            "Git submodule initialization failed."
        );
    }

    // build circom
    assert!(
        Command::new(cargo)
            .arg("build")
            .arg("--release")
            .current_dir("../iden3/circom")
            .status()
            .unwrap()
            .success(),
        "Circom build failed."
    );

    // npm clean install
    assert!(
        Command::new("npm")
            .arg("ci")
            .current_dir("../iden3/snarkjs")
            .status()
            .unwrap()
            .success(),
        "Npm SnarkJS clean install failed."
    );
}
