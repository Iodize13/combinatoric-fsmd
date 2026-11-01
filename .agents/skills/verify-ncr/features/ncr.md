# ncr: C(n, r) end to end

The user pulses `start` with `n` and `r`. Once `done` pulses, `result` holds C(n, r), with `result = 0` when r > n. `ovf = 1` (with `result` = all ones) means an intermediate quotient did not fit in W bits.

## Sub-features

- `ncr.small-k`: r <= n/2 loops r times.
- `ncr.large-r`: r > n/2 loops n-r times and uses nmr = r. A regression here is the original bug, where C(3,2) returned 2.
- `ncr.r-gt-n`: r > n gives result 0 without entering the loop.
- `ncr.zero`: r = 0 or n = 0 gives result 1 (or 0 when r > n).
- `ncr.ovf`: n large enough that C(n, k) > 2^W - 1 sets ovf, saturates `result` to all ones, and stops the loop early.

## How to get to it (user POV)

- Ports of `entity ncr_core` in `rtl/ncr_core.vhd` (a structural top over `ncr_ctrl` and `ncr_dp`).
- One-shot runner `tb/ncr_run.vhd`, through `scripts/verify.sh ncr N R`.

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Exhaustive at W=32.** Run `scripts/verify.sh sim` (default N_MAX=30). `sim-run-tb_ncr.log` must contain `TB PASS 532` (527 exhaustive + C(34,17) exact + 3 saturating cases + C(5,2) after an overflow; the run also checks that C(67,33) finishes in fewer cycles than C(34,17)). For a different range run `scripts/verify.sh sim <N_MAX>`, where N_MAX <= 33 because the Pascal reference uses VHDL `natural`.
- **Bounded formal at W=5, N_MAX=7.** Run `scripts/verify.sh formal ncr bmc` (slow, so run it alone or in the background). The result must be `DONE (PASS, rc=0)` within depth 100, which exceeds one worst-case computation (LATENCY_BOUND = 96). `assert_correct` and `assert_bounded_latency` must hold.
- **Reachability.** Run `scripts/verify.sh formal ncr cover`. The result must be PASS for `cover_exact` (C(6,3), step 71), `cover_ovf` (C(7,3), step 58, before the exact one) and `cover_r_gt_n`.

- **Single value.** Run `scripts/verify.sh ncr 34 17`. It must print `C(34, 17) = 2333606220 (1755 cycles)` (observed on 2026-11-02). `scripts/verify.sh ncr 67 33` must print `overflows 32 bits` (1070 cycles). The output goes to stdout only, so copy it into your report.

## Gotchas

- Overflow is asserted by `tb_ncr` (W=32) and `ncr_props` (W=5). Its cycle count is data-dependent, because the loop stops at the first overflowing iteration.
- `done` pulses one cycle after the FSM reaches FIN, and `busy` is already '0' in that cycle.
- `nmr + i` is computed in W bits. With n near 2^W it wraps, which is out of contract and not checked.
- `scripts/verify.sh ncr` leaves `build/<timestamp>-<pid>/` behind on every call. Run `scripts/verify.sh clean` afterwards.
