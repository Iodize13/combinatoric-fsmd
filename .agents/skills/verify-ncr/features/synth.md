# synth: the design synthesizes

Yosys (with ghdl-yosys-plugin) must accept the RTL as synthesizable, and the cell count shows that only one ALU exists.

## Sub-features

- `synth.ok`: generic `synth -top ncr_core` finishes without errors.
- `synth.stat`: the cell and flip-flop counts appear in the log.

## How to get to it (user POV)

- The top-level entity is `ncr_core` at W=32.

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Synthesize.** Run `scripts/verify.sh synth`. `evidence/$RUN_ID/synth.exit` must be `0`, and `synth.log` must contain `Number of cells`. Compare against the previous run's counts. A large jump usually means an accidental `*` or `/` operator was inferred.

## Gotchas

- This is generic Yosys synthesis, not Vivado or Quartus. For FPGA resources (LUT and DSP counts) use the vendor tool or `synth_xilinx` / `synth_intel`.
- Waveforms and schematics can come from `netlistsvg`. It is not installed and not part of this recipe.
