# cpu: programs run on the single-cycle CPU

The CPU executes a MIPS subset (`add sub and or slt addi lw sw beq j multu divu mfhi mflo`) plus `ncr rd, rs, rt` (opcode 0x1C, funct 0x1C). multu, divu and ncr share one muldiv unit and stall the PC until done; ncr clobbers HI/LO.

## Sub-features

- `cpu.alu`: add, sub, and, or, signed slt, addi with a negative immediate.
- `cpu.mem`: sw then lw of the same word; writes to `$zero` are dropped.
- `cpu.muldiv`: multu 0xFFFFFFFF^2 and divu 100/7 read back through mfhi/mflo.
- `cpu.ncr`: C(5,2), C(34,17) = 0x8B18014C, C(67,33) saturates to 0xFFFFFFFF, C(33,67) = 0.
- `cpu.control`: beq taken and not taken, j, back-to-back ncr in a loop (sum of C(10,k) = 1024), halt loop.
- `cpu.handshake` (formal, every instruction word): mem_we only on sw; no register write on sw/beq/j; one PC source; stall only on multu/divu/ncr, with no writes while stalled; each long op starts its unit once, only into an idle unit, and retires on its own unit's done (muldiv's done also pulses inside ncr); stalls last at most MAX_LAT+1 cycles; nothing is written or started during reset.
- `cpu.regfile` (formal): `$0` reads 0; a write to a nonzero register is read back next cycle.

## How to get to it (user POV)

- The program is `tb/cpu_test.s`, hand-assembled into `rtl/program_pkg.vhd` (the assembly is in a comment next to each word). Changing the program means editing both and the `EXPECTED` table in `tb/tb_cpu.vhd`.

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Prove the control unit.** Run `scripts/verify.sh formal cpu`. `evidence/$RUN_ID/formal-cpu-prove.status` must read `DONE (PASS, rc=0)`, and `formal-cpu-cover.log` must list 5 `reached cover statement` lines.
- **Run the program.** Run `scripts/verify.sh sim`. `evidence/$RUN_ID/sim-run-tb_cpu.log` must contain `TB PASS 18`. A wrong store prints `store <i>: got [...] = ..., want [...] = ...`.

## Gotchas

- The formal check covers `cpu_ctrl` and `regfile` only. The real muldiv and ncr engine are replaced by models whose done arrives 1..MAX_LAT cycles after start; their own correctness is in `muldiv.sby` / `ncr.sby`. Datapath wiring (`cpu_dp`) is checked by `tb_cpu` alone.

- `add`/`sub`/`addi` never trap on overflow; they behave like the `u` variants.
- Memories are 256 words each and addresses wrap at 1 KiB. Instruction and data memory are separate (Harvard), so `lw` cannot read the program.
- `divu` by 0 leaves HI/LO holding the dividend (muldiv's dz behavior); MIPS leaves it undefined.
