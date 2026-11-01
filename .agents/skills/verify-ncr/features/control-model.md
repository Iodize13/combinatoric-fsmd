# control-model: TLA+ model of the nCr FSM

`spec/NcrFsm.tla` models ncr_core's state machine with each muldiv operation abstracted to one step. TLC explores every start with n in 0..MaxN and r in 0..MaxN+1.

## Sub-features

- `LoopInv`: in CHECK, res = C(nmr + i - 1, i - 1).
- `ExactDivision`: in DIV, prod % i = 0, which shows that integer division is exact and no floating point is needed.
- `NoQuotOverflow`: in DIV, prod div 2^Width < i, which is the DIVHL precondition.
- `FinCorrect`: in FIN, res = C(n, r).
- `Terminates`: INIT leads to FIN (liveness, under weak fairness).

## How to get to it (user POV)

- `spec/NcrFsm.tla` and `spec/NcrFsm.cfg` (MaxN = 8, Width = 16).

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Model-check.** Run `scripts/verify.sh tla`. `evidence/$RUN_ID/tla-tlc.log` must contain `No error has been found`. Record the `distinct states found` line (47,808 on 2026-11-01).
- **Regression proof.** Changing `nmr' = n - Min(r, n - r)` to `nmr' = n - r` must make TLC report `Invariant FinCorrect is violated`. This was observed on 2026-11-01.

## Gotchas

- The model is hand-kept in sync with `rtl/ncr_core.vhd`. A change to the FSM in VHDL that is not mirrored here makes this proof about a different machine.
- TLC integers are 32-bit signed, so `Width = 32` aborts with `Overflow when computing 2^32`. Width = 16 is ample for MaxN = 8.
- Raising MaxN past ~12 makes Fact() slow. Prefer small MaxN, because sim covers range.
