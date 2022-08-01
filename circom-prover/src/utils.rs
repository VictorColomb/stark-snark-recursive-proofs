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

/// Enumeration of the possible error types for this crate.
pub enum WinterCircomError {
    /// This error type is triggered when a function of this crate resulted
    /// in a [std::io::Error].
    IoError {
        io_error: io::Error,
        comment: Option<String>,
    },

    /// This error is triggered after a function of this crate failed to
    /// generate a file it further needs.
    FileNotFound {
        file: String,
        comment: Option<String>,
    },

    /// This error type is triggered when an underlying command called by a
    /// function of this crate failed (returned a non-zero exit code).
    ExitCodeError {
        executable: String,
        code: i32,
    },

    /// This error is triggered, when the generated Winterfell proof could not
    /// be verified. This only happens in debug mode.
    InvalidProof(Option<VerifierError>),

    /// This error is triggered when the Winterfell proof generation failed.
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

pub(crate) fn canonicalize<P: AsRef<Path>>(path: P) -> Result<PathBuf, WinterCircomError> {
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

/// Logging level selector for functions of this crate.
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
    /// Returns whether the logging level is set to [Default](LoggingLevel::Default)
    /// or above.
    ///
    /// This is used to trigger the printing of big step announcements in the functions
    /// of this crate.
    pub(crate) fn print_big_steps(&self) -> bool {
        match self {
            Self::Quiet => false,
            _ => true,
        }
    }

    /// Returns whether the logging level is set to [Verbose](LoggingLevel::Verbose)
    /// or above.
    ///
    /// This is used to trigger the printing of underlying commands stdout in the
    /// functions of this crate.
    pub(crate) fn print_command_output(&self) -> bool {
        match self {
            Self::Quiet => false,
            Self::Default => false,
            _ => true,
        }
    }

    /// Returns whether the logging level is set to
    /// [VeryVerbose](LoggingLevel::VeryVerbose).
    ///
    /// This is used to trigger verbose mode of the underlying commands of the
    /// functions in this crate.
    pub(crate) fn verbose_commands(&self) -> bool {
        match self {
            Self::VeryVerbose => true,
            _ => false,
        }
    }
}
