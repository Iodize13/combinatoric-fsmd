# muldiv: shared multiply/divide unit

One W+1-bit ALU and one 2W+1-bit register (HI:LO plus a carry bit) serve both unsigned multiply and divide, following "approach 2" from `slides/w03c_mult.pdf`. A user pulses `start` with `op`, `a`, and `b` while `busy = '0'`. `done` pulses W+1 cycles after a MULTU start, 2W+3 cycles after a divide start, or 1 cycle later on `dz` or `ovf`.

## Sub-features

- `mul.multu`: OP_MULTU sets HI:LO = a * b (64-bit result from 32-bit inputs).
- `div.divu`: OP_DIVU sets LO = a / b and HI = a mod b.
- `div.divhl`: OP_DIVHL divides the current HI:LO by b. This is the nCr access pattern, a MULTU followed directly by a DIVHL.
- `div.dz`: b = 0 sets `dz = 1` and pulses `done` without dividing.
- `div.ovf`: OP_DIVHL with HI >= b sets `ovf = 1`, and HI:LO stays unchanged.
- Edge operands: 0, 1, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF, and the half-word masks.

## How to get to it (user POV)

- Ports of `entity muldiv` in `rtl/muldiv.vhd` (a structural top over `muldiv_ctrl` and `muldiv_dp`), with op codes from `muldiv_pkg`.
- Indirectly through `ncr_core`, which issues MULTU then DIVHL.

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Simulate at W=32.** Run `scripts/verify.sh sim`. `evidence/$RUN_ID/sim-run-tb_muldiv.log` must contain `TB PASS 8363` (121 edge pairs × 3 + 2000 random × 4). Any mismatch is logged with the hex operands.
- **Unbounded proof at W=4.** Run `scripts/verify.sh formal muldiv prove`. `formal-muldiv-prove.status` must read `DONE (PASS, rc=0)`. This covers every reachable sequence of ops, for all time, at W=4.
- **Bounded check at W=6.** Run `scripts/verify.sh formal muldiv bmc`. The result must be `DONE (PASS, rc=0)`, which means no failure in the first 28 cycles (a MULTU followed by a divide).
- **Reachability.** Run `scripts/verify.sh formal muldiv cover`. The result must be PASS, and the `formal-muldiv-cover-traces/` directory must hold VCDs for `cover_mul_max` and `cover_divhl`.

## Gotchas

- `tb_muldiv` checks DIVHL only after a MULTU. A DIVHL issued after a DIVU (remainder in HI) is covered only by formal, at small W.
- Signed MULT and DIV are not implemented. The slides' signed examples (0xFFFFFFFB × 2) will show the unsigned result.
- The PASS count changes if `N_RANDOM` or `EDGES` changes. Update the number above at the same time.
