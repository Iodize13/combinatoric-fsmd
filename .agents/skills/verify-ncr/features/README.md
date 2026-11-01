# nCr FSMD verification map

This directory is the maintained verification source for the hardware's user-visible behavior. A "user" here is whatever drives the ports: a testbench, a CPU that issues the instruction, or switches on the board. Read this index first, then use the matching feature file as the recipe.

## Baseline preconditions

- `scripts/verify.sh doctor` exits 0.
- A unique `RUN_ID` is exported, for example `RUN_ID=$(date +%s)-feature`.
- The working tree's `rtl/` is the revision under test. Record `git rev-parse HEAD` together with whether the tree is dirty.

## Driving conventions

- Drive only through `scripts/verify.sh`. Do not hand-run ghdl or sby with different flags, because the logs would not match this map.
- Read the PASS signal from the evidence file each recipe names. Do not trust the exit code alone.

## Proof and skip reporting

- Report the feature ID, the command, the RUN_ID, and the PASS or FAIL line.
- State the width and the depth or bound for every formal result.
- If a job times out, report it as "timed out at T s". Do not report it as a pass.

## Features

| ID | File | What |
|---|---|---|
| muldiv | [muldiv.md](muldiv.md) | MULTU / DIVU / DIVHL on the shared unit |
| ncr | [ncr.md](ncr.md) | C(n, r) end to end through ncr_core |
| control-model | [control-model.md](control-model.md) | TLA+ model of the FSM: exactness, no quotient overflow, termination |
| cpu | [cpu.md](cpu.md) | a program with the ncr instruction runs on the single-cycle CPU |
| board | [board.md](board.md) | the Nexys A7 calculator (both tops) from switches and buttons to UART text |
| synth | [synth.md](synth.md) | the design synthesizes and its resource count |
