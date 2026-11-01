# ncr: C(n, r) end to end

The user pulses `start` with `n` and `r`. Once `done` pulses, `result` holds C(n, r), with `result = 0` when r > n. `ovf = 1` means an intermediate quotient did not fit in W bits.

## Sub-features

- `ncr.small-k`: r <= n/2 loops r times.
- `ncr.large-r`: r > n/2 loops n-r times and uses nmr = r. A regression here is the original bug, where C(3,2) returned 2.
- `ncr.r-gt-n`: r > n gives result 0 without entering the loop.
- `ncr.zero`: r = 0 or n = 0 gives result 1 (or 0 when r > n).
- `ncr.ovf`: n large enough that C(n, k) > 2^W - 1 sets ovf.

## How to get to it (user POV)

- Ports of `entity ncr_core` in `rtl/ncr_core.vhd`.
- One-shot runner `tb/ncr_run.vhd`, through `scripts/verify.sh ncr N R`.

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Exhaustive at W=32.** Run `scripts/verify.sh sim` (default N_MAX=30). `sim-run-tb_ncr.log` must contain `TB PASS 527`. For a different range run `scripts/verify.sh sim <N_MAX>`, where N_MAX <= 33 because the Pascal reference uses VHDL `natural`.
- **Bounded formal at W=6, N_MAX=6.** Run `scripts/verify.sh formal ncr bmc` (slow, so run it alone or in the background). The result must be `DONE (PASS, rc=0)` within depth 80, which exceeds one worst-case computation (LATENCY_BOUND = 72). `assert_correct` and `assert_bounded_latency` must hold.
- **Reachability.** Run `scripts/verify.sh formal ncr cover`. The result must be PASS for `cover_largest` (C(6,3)) and `cover_r_gt_n`.

- **Single value.** Run `scripts/verify.sh ncr 34 17`. It must print `C(34, 17) = 2333606220 (1177 cycles)` (observed on 2026-11-01). The output goes to stdout only, so copy it into your report.

## Gotchas

- `ncr.ovf` is reachable by hand with `scripts/verify.sh ncr 40 20` but no recipe asserts it. `tb_ncr` stops at N_MAX=30, where nothing overflows 32 bits. This is an explicit gap.
- `done` pulses one cycle after the FSM reaches FIN, and `busy` is already '0' in that cycle.
- `nmr + i` is computed in W bits. With n near 2^W it wraps, which is out of contract and not checked.
- `scripts/verify.sh ncr` leaves `build/<timestamp>-<pid>/` behind on every call. Run `scripts/verify.sh clean` afterwards.
