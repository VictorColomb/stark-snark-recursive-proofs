use std::{
    fmt::{Debug, Display},
    io,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use colored::Colorize;
use winterfell::{ProverError, VerifierError};

// ERRORS
// ===========================================================================

pub enum WinterCircomError {
    IoError {
        io_error: io::Error,
        comment: Option<String>,
    },
    FileNotFound {
        file: String,
        comment: Option<String>,
    },
    ExitCodeError {
        executable: String,
        code: i32,
    },
    InvalidProof(Option<VerifierError>),
    ProverError(ProverError),
}

impl Display for WinterCircomError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let error_string = match self {
            WinterCircomError::IoError { io_error, comment } => {
                if let Some(comment) = comment {
                    format!("IoError: {} ({}).", io_error, comment)
                } else {
                    format!("IoError: {}.", io_error)
                }
            }
            WinterCircomError::FileNotFound { file, comment } => {
                if let Some(comment) = comment {
                    format!("File not found: {} ({}).", file, comment)
                } else {
                    format!("File not found: {}.", file)
                }
            }
            WinterCircomError::ExitCodeError { executable, code } => {
                format!("Executable {} exited with code {}.", executable, code)
            }
            WinterCircomError::InvalidProof(verifier_error) => {
                if let Some(verifier_error) = verifier_error {
                    format!("Invalid proof: {}.", verifier_error)
                } else {
                    format!("Invalid proof.")
                }
            }
            WinterCircomError::ProverError(prover_error) => {
                format!("Prover error: {}.", prover_error)
            }
        };

        write!(f, "{}", error_string.yellow())
    }
}

impl Debug for WinterCircomError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        std::fmt::Display::fmt(&self, f)
    }
}

// COMMAND EXECUTION HELPERS
// ===========================================================================

pub(crate) enum Executable {
    Circom,
    SnarkJS,
    Make,
    Custom {
        path: String,
        verbose_argument: Option<String>,
    },
}

impl Executable {
    fn executable_path(&self) -> Result<PathBuf, WinterCircomError> {
        Ok(match self {
            Self::Circom => canonicalize("iden3/circom/target/release/circom")?,
            Self::SnarkJS => canonicalize("iden3/snarkjs/build/cli.cjs")?,
            Self::Make => "make".into(),
            Self::Custom { path, .. } => canonicalize(path)?,
        })
    }

    fn executable_name(&self) -> String {
        match self {
            Self::Circom => String::from("circom"),
            Self::SnarkJS => String::from("snarkjs"),
            Self::Make => String::from("make"),
            Self::Custom { path, .. } => Path::new(path)
                .file_name()
                .unwrap()
                .to_str()
                .unwrap()
                .to_string(),
        }
    }
}

pub fn canonicalize<P: AsRef<Path>>(path: P) -> Result<PathBuf, WinterCircomError> {
    let path = path.as_ref();
    std::fs::canonicalize(path).map_err(|io_error| WinterCircomError::IoError {
        io_error,
        comment: Some(format!(
            "Could not canonicalize path: {}",
            path.to_string_lossy()
        )),
    })
}

/// Execute a system command, returning an error on failure.
pub(crate) fn command_execution(
    executable: Executable,
    args: &[&str],
    current_dir: Option<&str>,
    logging_level: &LoggingLevel,
) -> Result<(), WinterCircomError> {
    let mut command = Command::new(executable.executable_path()?);

    // set arguments and current directory
    for arg in args {
        command.arg(arg);
    }
    if let Some(dir) = current_dir {
        command.current_dir(dir);
    }

    // set verbose flag if logging level is very verbose
    if logging_level.verbose_commands() {
        match executable {
            Executable::Circom => {
                command.arg("--verbose");
            }
            Executable::SnarkJS => {
                command.arg("--verbose");
            }
            Executable::Custom {
                ref verbose_argument,
                ..
            } => {
                if let Some(verbose_argument) = verbose_argument {
                    command.arg(verbose_argument);
                }
            }
            _ => {}
        }
    };

    // do not print command stdout if logging level is below verbose
    if !logging_level.print_command_output() {
        command.stdout(Stdio::null());
    }

    match command.status() {
        Ok(status) => {
            if !status.success() {
                return Err(WinterCircomError::ExitCodeError {
                    executable: executable.executable_name(),
                    code: status.code().unwrap_or(-1),
                });
            }
        }
        Err(e) => {
            return Err(WinterCircomError::IoError {
                io_error: e,
                comment: Some(format!(
                    "during execution of: {}",
                    executable.executable_name()
                )),
            })
        }
    }

    Ok(())
}

/// Verify that a file exists, returning an error on failure.
pub(crate) fn check_file(path: String, comment: Option<&str>) -> Result<(), WinterCircomError> {
    if !Path::new(&path).exists() {
        return Err(WinterCircomError::FileNotFound {
            file: Path::new(&path)
                .file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("unknown")
                .to_owned(),
            comment: comment.map(|s| s.to_owned()),
        });
    }
    Ok(())
}

pub(crate) fn delete_file(path: String) {
    let _ = std::fs::remove_file(&path);
}

pub(crate) fn delete_directory(path: String) {
    let _ = std::fs::remove_dir_all(&path);
}

// LOGGING
// ===========================================================================

/// Logging level.
///
/// - [Quiet](LoggingLevel::Quiet): nothing is printed to stdout (errors are still printed to stderr)
/// - [Default](LoggingLevel::Default): minimal logging (only major steps are logged to stdout)
/// - [Verbose](LoggingLevel::Verbose): output of underlying executables is printed as well
/// - [VeryVerbose](LoggingLevel::VeryVerbose): underlying executables are set to verbose mode, and their
/// output is printed as well
pub enum LoggingLevel {
    /// Nothing is printed to stdout (errors are still printed to stderr)
    Quiet,

    /// Minimal logging (only major steps are logged to stdout)
    Default,

    /// Output of underlying executables is printed as well
    Verbose,

    /// Underlying executables are set to verbose mode, and their output is printed as well
    VeryVerbose,
}

impl LoggingLevel {
    pub fn print_big_steps(&self) -> bool {
        match self {
            Self::Quiet => false,
            _ => true,
        }
    }

    pub fn print_command_output(&self) -> bool {
        match self {
            Self::Quiet => false,
            Self::Default => false,
            _ => true,
        }
    }

    pub fn verbose_commands(&self) -> bool {
        match self {
            Self::VeryVerbose => true,
            _ => false,
        }
    }
}
