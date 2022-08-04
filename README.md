# STARK - SNARK recursive proofs

The point of this library is to combine the SNARK and STARK computation arguments of knowledge, namely the [Winterfell](https://github.com/novifinancial/winterfell) library for the generation of STARKs and the [Circom](https://docs.circom.io/) language, combined with the Groth16 protocol for SNARKs.

They allow the combinaison of advantages of both proof systems:

- Groth16 (SNARK): constant-time proofs, constant-time verification, etc.
- Winterfell: flexibility of the AIR construct

## 🗝️ Powers of tau phase 1 transcript

Before anything, a powers of tau phase 1 transcript must be placed in the root of the workspace, named `final.ptau`.

You can download the ones from the Hermez ceremony [here](https://www.dropbox.com/sh/mn47gnepqu88mzl/AACaJkBU7mmCq8uU8ml0-0fma?dl=0). Hopefully this link will not die.

## ⚙️ Example Executables

A few example crates are provided as proof-of-concept and usage examples, located in the `examples` folder.

- `sum` : Computation of the sum of integers from 0 to n.

Each crate contains three executables:

- `compile`: generates and compile Circom code, and generates the circuit-specific keys.  
  This must be run once before the the other two executables, and every time the proof options are changed.
- `prove`: generate a STARK - SNARK recursive proof.
- `verify`: verify the previously generated proof.

Therefore, the complete execution of the example `sum` is as follows:

```bash
cargo build --release -p example-sum
cargo run --release -p example-sum --bin compile
cargo run --release -p example-sum --bin prove
cargo run --release -p example-sum --bin verify
```

## 🪛 Implementing an algorithm
<details style="margin: 10px 0 20px 0;">
<summary style="padding:5px;">Click to show/hide</summary>

This example is available fully-functional in the `examples/sum` folder.

1. Define a constant instance of `WinterCircomProofOptions`, using its `new` method (see the documentation of this method for what the arguments correspond to).

```rust
const PROOF_OPTIONS: WinterCircomProofOptions<2> =
   WinterCircomProofOptions::new(128, 2, 3, [1, 1], 32, 8, 0, 8, 128);
```

2. Implement `WinterPublicInputs`.

```rust
use serde::{ser::SerializeTuple, Serialize};
use winter_circom_prover::winterfell::math::fields::f256::BaseElement;

#[derive(Clone, Default)]
pub struct PublicInputs {
    pub start: BaseElement,
    pub start: BaseElement,
}

impl WinterPublicInputs for PublicInputs {
    const NUM_PUB_INPUTS: usize = 2;
}

impl Serialize for PublicInputs {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let mut state  = serializer.serialize_tuple(2)?;
        state.serialize_element(&self.start)?;
        state.serialize_element(&self.end)?;
        state.end()
    }
}

impl Serializable for PublicInputs {
    fn write_into<W: ByteWriter>(&self, target: &mut W) {
        target.write(self.start);
        target.write(self.result);
    }
}
```

3. Implement Winterfell `Air` trait. See their [documentation](https://docs.rs/winterfell/latest/) for instructions. \
While writing methods, make sure to use the [WinterCircomProofOptions] constant you previously defined, instead of hard coded values. \
Also implement the `Default` trait for your `Air` implementation.

```rust
use winter_circom_prover::{winterfell::{
    math::{fields::f256::BaseElement, FieldElement},
    Air, AirContext, Assertion, EvaluationFrame, FieldExtension, HashFunction,
    ProofOptions, TraceInfo}};

pub struct WorkAir {
    context: AirContext<BaseElement>,
    start: BaseElement,
    result: BaseElement,
}

impl Air for WorkAir {
    type BaseField = BaseElement;
    type PublicInputs = PublicInputs;

    fn new(trace_info: TraceInfo, pub_inputs: PublicInputs, options: ProofOptions) -> Self {
        let degrees = PROOF_OPTIONS.transition_constraint_degrees();

        let num_assertions = PROOF_OPTIONS.num_assertions();

        WorkAir {
            context: AirContext::new(trace_info, degrees, num_assertions, options),
            start: pub_inputs.start,
            result: pub_inputs.result,
        }
    }

    fn evaluate_transition<E: FieldElement + From<Self::BaseField>>(
        &self,
        frame: &EvaluationFrame<E>,
        _periodic_values: &[E],
        result: &mut [E],
    ) {
        let current = &frame.current();
        let next = &frame.next();

        result[0] = next[0] - (current[0] + E::ONE);
        result[1] = next[1] - (current[1] + current[0] + E::ONE);
    }

    fn get_assertions(&self) -> Vec<Assertion<Self::BaseField>> {
        let last_step = self.trace_length() - 1;
        vec![
            Assertion::single(0, 0, self.start),
            Assertion::single(1, 0, self.start),
            Assertion::single(1, last_step, self.result),
        ]
    }

    fn context(&self) -> &AirContext<Self::BaseField> {
        &self.context
    }
}

impl Default for WorkAir {
    fn default() -> Self {
        WorkAir::new(
            TraceInfo::new(0, 0),
            PublicInputs::default(),
            ProofOptions::new(
                32,
                8,
                0,
                HashFunction::Poseidon,
                FieldExtension::None,
                8,
                128,
            ),
        )
    }
}
```

4. Implement the Winterfell `Prover` trait. See their [documentation](https://docs.rs/winterfell/latest/) for instructions. \
Also implement a method to build the trace.

```rust
use winter_circom_prover::winterfell::{
    math::{fields::f256::BaseElement, FieldElement},
    ProofOptions, Prover, Trace, TraceTable,
};

pub struct WorkProver {
    options: ProofOptions,
}

impl WorkProver {
    pub fn new(options: ProofOptions) -> Self {
        Self { options }
    }

    pub fn build_trace(&self, start: BaseElement, n: usize) -> TraceTable<BaseElement> {
        let trace_width = PROOF_OPTIONS.trace_width;
        let mut trace = TraceTable::new(trace_width, n);

        trace.fill(
            |state| {
                state[0] = start;
                state[1] = start;
            },
            |_, state| {
                state[0] += BaseElement::ONE;
                state[1] += state[0];
            },
        );

        trace
    }
}

impl Prover for WorkProver {
    type BaseField = BaseElement;
    type Air = WorkAir;
    type Trace = TraceTable<Self::BaseField>;

    fn get_pub_inputs(&self, trace: &Self::Trace) -> PublicInputs {
        let last_step = trace.length() - 1;
        PublicInputs {
            start: trace.get(0, 0),
            result: trace.get(1, last_step),
        }
    }

    fn options(&self) -> &ProofOptions {
        &self.options
    }
}
```

5. Define `AIRTransitions` and `AIRAssertions` Circom templates

Choose a circuit name, for instance: *sum*.

Create a file named `<circuit_name>.circom` in the `circuits/air/` directory
(replace `<circuit-name>` with the actual circuit name, naturally).

In this file, define two Circom templates:

- **`AIRTransitions`** - template with a single array output. Hardcode the transition constrait degrees here.
  In this example, we defined `PROOF_OPTIONS` with `[1, 1]` as transition constraint degrees. The template defined below therefore returns `[1, 1]` as well.

- **`AIRAssertions`** - template that replicates the `get_assertions` method of the `Air` implementation for Winterfell.

Copy the template below and replace the section between `/* HERE YOUR ASSERTIONS HERE */` and `/* -------------- */` with your own assertions.

For all `i` between 0 and `num_assertions`, define `value[i]`, `step[i]` and `register[i]` such as the assertion is `register[i]` at `step[i]` equals `value[i]` (a register is a column of the trace).

```c++
pragma circom 2.0.0;

include "../utils/comparators.circom";

template AIRTransitions(num_transition_constraints) {
    signal output transition_degree[num_transition_constraints];

    /* === EDIT FROM HERE === */

    // Hardcode transition degrees, as you did in your implementation
    // of WinterCircomProofOptions.
    transition_degree[0] <== 1;
    transition_degree[1] <== 1;

    /* ====== TO HERE ====== */
}


template AIRAssertions(num_assertions, num_public_inputs, trace_length, trace_width) {
    signal input public_inputs[num_public_inputs];
    signal input g_trace;

    signal output evaluations[num_assertions];
    signal output number_of_steps[num_assertions];
    signal output registers[num_assertions];
    signal output step_offsets[num_assertions];
    signal output strides[num_assertions];

    component assertions[num_assertions];

    /* === EDIT FROM HERE === */

    // Hardcode the number of assertions (this is a precaution).

    assert(num_assertions == 3);

    // Define your assertions here, using the SingleAssertion, PeriodicAssertion
    // and SequenceAssertion templates.

    assertions[0] = SingleAssertion();
    assertions[0].column <== 0;
    assertions[0].step <== 0;
    assertions[0].value <== public_inputs[0];

    assertions[1] = SingleAssertion();
    assertions[1].column <== 1;
    assertions[1].step <== 0;
    assertions[1].value <== public_inputs[0];

    assertions[2] = SingleAssertion();
    assertions[2].column <== 1;
    assertions[2].step <== trace_length - 1;
    assertions[2].value <== public_inputs[1];

    /* ====== TO HERE ====== */

    for (var i = 0; i < num_assertions; i++) {
        evaluations[i] <== assertions[i].evaluation;
        number_of_steps[i] <== assertions[i].number_of_steps;
        registers[i] <== assertions[i].register;
        step_offsets[i] <== assertions[i].step_offset;
        strides[i] <== assertions[i].stride_out;
    }
}
```

There are three types of assertions in Winterfell: single, periodic and sequence. There is a Circom template for each of these as well, that are used as follows (replace each instance of `???` to actually define your assertions):

```c++
assertions[i] = SingleAssertion();
assertions[i].column <== ???;
assertions[i].step <== ???;
assertions[i].value <== ???;

assertions[j] = PeriodicAssertion(trace_length);
assertions[j].column <== ???;
assertions[j].first_step <== ???;
assertions[j].stride <== ???;
assertions[j].value <== ???;

// replace value_length with the length of your sequence
assertions[k] = SequenceAssertion(addicity, trace_length, value_length);
assertions[k].column <== ???;
assertions[k].first_step <== ???;
assertions[k].stride <== ???;
for (var l = 0; l < value_length; l++) {
    assertions[k].values[l] <== ???;
}
// do not modify the three following inputs
assertions[k].addicity_root <== addicity_root;
assertions[k].g_trace <== g_trace;
assertions[k].z <== z;
```

6. Define executables for compilation, proving and verifying.

See [cargo documentation](https://doc.rust-lang.org/cargo/reference/cargo-targets.html#binaries)
for how to define multiple binaries in a single cargo crate.

All functions are called with a string argument, which should be the circuit name
chosen in the previous step.

**Compile executable**

```rust
use winter_circom_prover::{circom_compile, utils::{LoggingLevel, WinterCircomError}};

fn main() -> Result<(), WinterCircomError> {
    circom_compile::<WorkProver, 2>(PROOF_OPTIONS, "sum", LoggingLevel::Default)
}
```

**Prove executable**

```rust
use winter_circom_prover::{
    circom_prove,
    utils::{LoggingLevel, WinterCircomError},
    winterfell::math::{fields::f256::BaseElement, FieldElement},
};

fn main() -> Result<(), WinterCircomError> {
    // parameters
    let start = BaseElement::ONE;

    // build proof
    let options = PROOF_OPTIONS.get_proof_options();
    let prover = WorkProver::new(options.clone());
    let trace = prover.build_trace(start, PROOF_OPTIONS.trace_length);

    circom_prove(prover, trace, "sum", LoggingLevel::Default)
}
```

**Verify executable**

```rust
use winter_circom_prover::{
    check_ood_frame, circom_verify,
    utils::{LoggingLevel, WinterCircomError},
};

fn main() -> Result<(), WinterCircomError> {
    check_ood_frame::<WorkAir>("sum");
    circom_verify("sum", LoggingLevel::Verbose)?;

    Ok(())
}
```
</details>

## 📖 Library

This repo provides a library for the easy generation of STARK - SNARK recursive proofs.

The main components of its API are:

- The `circom_compile` function, for generating a Circom circuit capable of verifying a Winterfell proof, compiling it and generating circuit-specific keys.
- The `circom_prove` function, for generating a SNARK - Groth16 proof of the verification of the Winterfell proof.
- The `circom_verify` function, for verifying the proof generated by the previous function.

## Completeness and soundness

The completeness and soundness of arguments of knowledge generated by this crate naturally depends on the completeness and soundness of those generated by the Winterfell library and the Circom language, using the Groth16 protocol.

The generated proofs are complete and sound, assuming the following:

- `n * lde_blowup_factor < 2^253` where `n` is the length of the trace.
- The Poseidon hash function is used to generate the Winterfell proof.
- No field extensions are used.

The generated proofs are composed of a Groth16 proof and a set of public inputs, which are the out-of-domain (OOD) trace frame and the OOD constraint evaluations.

<details style="padding-bottom: 10px;">
<summary><h3 style="display: inline-block;padding: 5px;">Out-of-domain consistency check</h3></summary>

To preserve the flexibility of STARKs compared to the constrained arithmetization of STARKs and especially the Groth16 protocol, the out-of-domain (OOD) consistency check, which requires the evaluations of a user-defined arbitrary function, is done alongside the Circom verification circuit.

The fact that the out-of-domain trace frame and constraint evaluations are consistent is therefore not guaranteed by the Groth16 proof. This is why this crate provides a [check_ood_frame] function, that must be used alongside the [circom_verify] function and which takes the Groth16 public inputs and performs the OOD consistency check.

The [check_ood_frame] verifies that the the OOD trace frame and constraint evaluations correspond to one-another, using the transition constraints defined by the user in their implementation of the [Air](winterfell::Air) trait. On top of that, the OOD trace frame is used to reseed the pseudo-random generator. Therefore, modifying the OOD trace frame given as public input to the Groth16 verifier will result in the generation of different query positions, which will result in the failure of Merkle tree commitment checks, with probability at least `(1 / trace_width * lde_domain_size) ^ num_queries` (the probability that all picked query positions are the same).

This means that verifying the Groth16 proof and the OOD consistency guarantees that the proof is correct. We refer you to the Winterfell and Circom documentations for more details about their respective soundness.
</details>

## 🚀 To-Do

- Add support for Winterfell's cyclic assertions.
- Implement additional proof-of-concept examples.
- Add support for global public inputs, alongside the OOD trace frame and constraint evaluations.
- Automate generation of `AIRTransitions` and `AIRAssertions` templates.

## ⚠️ Disclaimer

This library is a research project, has not been audited for safety and should not be used in production.

The circuit-specific keys, generated by the `compile` executable, do not contain contributions and are therefore unsafe to use in production.

## ⚖️ License

This work is licensed under the [MIT License](./LICENSE).

The Winterfell library is licensed under the [MIT License](./winterfell/LICENSE).

The Circom and SnarkJS libraries are both licensed under the GNU General Public License v3.0 (see [here](https://github.com/iden3/circom/blob/master/COPYING) and [here](https://github.com/iden3/snarkjs/blob/master/COPYING) respectively).
