# synth: the design synthesizes

Yosys (with ghdl-yosys-plugin) must accept the RTL as synthesizable, and the cell count shows that only one ALU exists.

## Sub-features

- `synth.ok`: generic `synth -top ncr_core` and `synth -top cpu` finish without errors.
- `synth.stat`: the cell and flip-flop counts appear in the log.

## How to get to it (user POV)

- The top-level entities are `ncr_core` at W=32 and `cpu`.

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Synthesize.** Run `scripts/verify.sh synth`. `evidence/$RUN_ID/synth-<top>.exit` must be `0` for both tops, and each `synth-<top>.log` must contain `Number of cells`. Compare against the previous run's counts. A large jump usually means an accidental `*` or `/` operator was inferred.

## Gotchas

- This is generic Yosys synthesis, not Vivado or Quartus. For FPGA resources (LUT and DSP counts) use the vendor tool or `synth_xilinx` / `synth_intel`.
- The CPU's data RAM and register file become flip-flops (about 9200) under generic synth. On an FPGA they map to distributed (LUT) RAM, since both are read asynchronously.
- Schematics come from `scripts/verify.sh schematic` (netlistsvg), not from this recipe.
