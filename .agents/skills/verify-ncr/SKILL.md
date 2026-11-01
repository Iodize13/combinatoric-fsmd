---
name: verify-ncr
description: Verify the VHDL nCr FSMD and its shared 32-bit multiply/divide unit (rtl/muldiv.vhd, rtl/ncr_core.vhd) with GHDL simulation, SymbiYosys + PSL formal checks, a TLA+ control model, and a Yosys synth check. Use after any change under rtl/, tb/, formal/, or spec/, or before claiming the hardware computes nCr / MULTU / DIVU / DIVHL correctly.
---

# verify-ncr

The "app" is hardware with no UI. A user "drives" it by giving inputs on
`start`/`op`/`a`/`b` (muldiv) or `start`/`n`/`r` (ncr_core) and reading
`hi`/`lo`/`result`/`done`/`ovf`/`dz`. Proof means one of these: a testbench that compares
against a reference, a solver run that returns PASS, or a TLC run with no error.
Everything goes through one script: `scripts/verify.sh`.

## Layout

| Path | What |
|---|---|
| `rtl/muldiv.vhd` | shared unsigned MULTU / DIVU / DIVHL unit, "approach 2" (one W-bit ALU, 2W-bit HI:LO), W cycles per op |
| `rtl/ncr_core.vhd` | nCr FSMD: `res = res*(n-k+i)/i` using MULTU then DIVHL on HI:LO |
| `tb/tb_muldiv.vhd` | W=32 edge + random (2000) checks, including MULTU→DIVHL |
| `tb/tb_ncr.vhd` | W=32 exhaustive n=0..N_MAX, r=0..n+1 against Pascal |
| `formal/*_props.vhd` | PSL harnesses (assume/assert/cover, VHDL-2008) |
| `formal/muldiv.sby` | tasks `prove` (PDR, W=4), `bmc` (W=6, depth 18), `cover` (W=8) |
| `formal/ncr.sby` | tasks `bmc` (W=6, N_MAX=6, depth 80), `cover` |
| `spec/NcrFsm.tla` + `.cfg` | control-level model: LoopInv, ExactDivision, NoQuotOverflow, FinCorrect, Terminates |

## Launch

Tools live outside the repo, in `~/.local/opt/oss-cad-suite` (ghdl, yosys,
ghdl-yosys-plugin, sby, yices, abc) and `~/.local/opt/tla/tla2tools.jar` (Java 21 is at
`/usr/sbin/java`). The script adds them to PATH itself. Override them with `OSS_CAD_SUITE=`
and `TLA2TOOLS=`. If they are missing, reinstall without sudo:

```sh
U=$(curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest | python3 -c 'import json,sys;print([a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if "linux-x64" in a["name"] and a["name"].endswith(".tgz")][0])')
mkdir -p ~/.local/opt && curl -sL "$U" | tar -xz -C ~/.local/opt
mkdir -p ~/.local/opt/tla && curl -sL -o ~/.local/opt/tla/tla2tools.jar https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar
```

You start nothing long-running. Each command builds what it needs in `build/<RUN_ID>/`
and then exits.

## Doctor

```sh
scripts/verify.sh doctor     # exit 0 = every tool + source file present
```

Run this first, and again whenever a command fails before reaching the solver or simulator.
Each line shows `ok` or `MISS`. The `ghdl-yosys-plugin` line is the most common miss. If it
is missing, sby fails with `No such command: ghdl`.

## Drive

```sh
RUN_ID=<tag> scripts/verify.sh sim [N_MAX]                  # both testbenches (~30 s)
scripts/verify.sh ncr N R                                   # one C(N,R) at W=32: prints value + cycles, no evidence files
RUN_ID=<tag> scripts/verify.sh formal [muldiv|ncr] [task]   # default: all designs/tasks
RUN_ID=<tag> scripts/verify.sh tla
RUN_ID=<tag> scripts/verify.sh synth                        # yosys synth -top ncr_core; stat
RUN_ID=<tag> scripts/verify.sh all                          # doctor, then all of the above
```

Measured runtimes (2026-11-01, this machine):

| Job | Time |
|---|---|
| sim | ~30 s |
| muldiv prove | 19 s |
| muldiv bmc | 105 s |
| muldiv cover | 1 s |
| ncr cover | 14 s |
| tla | ~5 s |

`ncr bmc` is the slowest job. Run it in the background, or alone, with a generous timeout
(≥ 25 min).

Each job is isolated by `RUN_ID`, so parallel runs with different RUN_IDs never share
files. Jobs with the same RUN_ID can also run in parallel, because their log names differ.

## Evidence

Everything lands in `evidence/<RUN_ID>/`:

- `<job>.log`: the command (first line) plus full stdout/stderr. `<job>.exit`: the exit code.
- `sim-run-tb_*.log`: must contain `TB PASS <count>`. A run without that line has failed,
  even if it exits 0.
- `formal-<design>-<task>.status`: the sby `DONE (PASS|FAIL, rc=…)` line.
  `formal-*-traces/`: counterexample or cover VCDs. Open them in GTKWave
  (`gtkwave <file>.vcd`).
- `tla-tlc.log`: must contain `No error has been found`. A failure shows
  `Invariant X is violated` followed by the trace.
- `tb_*.ghw`: simulation waveforms.

Proof standards:

- Report the exact command, the RUN_ID, and the PASS line from the log. Do not
  paraphrase.
- A **bounded** result (bmc/cover) is not a proof for all time. Say "no failure within depth
  D at W=w".
- The muldiv `prove` result is an unbounded proof at W=4 only. W=32 rests on simulation
  plus the width-generic RTL.
- Formal checks run at a small W. Only simulation runs at W=32. Never claim "formally
  proven at 32-bit".
- After an RTL change, rerun everything that reads that file. A pass from before the edit
  is stale.

## Cleanup

```sh
scripts/verify.sh clean <RUN_ID>   # removes build/<RUN_ID> only
scripts/verify.sh clean            # removes all of build/
```

`clean` never touches `evidence/`. A timed-out sby job can leave `yosys-abc` or `yices`
children running. Find them with `pgrep -af 'build/<RUN_ID>'` and kill those PIDs. Never
use `pkill -f` with a pattern that also matches your own shell's command line.

## Gotchas

- sby resolves `[files]` relative to the cwd, not the .sby file. The script `cd`s into
  `formal/` first, so do not call sby from elsewhere without `cd`-ing there.
- Every `.sby` needs `plugin -i ghdl` in `[script]`.
- PSL checks must be gated on `rst = '0'`. DUT registers are undefined in the reset cycle,
  and PDR finds that at step 0.
- PDR (`abc pdr`) cannot close the multiplier at W=8 (>260 s), and it hit the 500 s timeout
  on a ~100-step-deep ncr bug. Use BMC for anything deep.
- A cover reached at a step shorter than one operation (< W+1 for muldiv) is vacuous. Check the `reached cover statement … at step N` lines. Covers must hold `rst = '0'` at every step.
- DIVHL requires HI < divisor (quotient fits in W bits). Otherwise `ovf=1` and HI:LO stays
  unchanged. MIPS `div` has no such check.

## Features

See [features/README.md](features/README.md).
