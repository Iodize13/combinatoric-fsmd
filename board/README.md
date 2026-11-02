# Nexys A7 nCr calculator

Two designs share the pins in `nexys_a7.xdc` and the same controls, so try them in order:

| Top | What computes | Clock |
|---|---|---|
| `nexys_a7_top` | `ncr_core` alone; `ncr_report` formats the text in hardware | 25 MHz |
| `nexys_a7_cpu_top` | the single-cycle CPU running `calc.s`: `ncr` instruction, decimal printing in software (`divu` by 10) | 12.5 MHz |

## Controls

- `SW6..0` = n, `SW13..7` = r (0..127 each). `LED13..0` mirror them.
- `BTNC`: compute C(n, r) and print `C(n,r) = <decimal>` or `C(n,r) = overflow`.
- `BTNU`: toggle debug mode (`LED16` green). In debug mode every switch change prints by
  itself once the switches have been still for 10 ms. Unchanged switches print nothing.
- `CPU_RESETN`: reset; prints the banner again and leaves debug mode.
- `LED15`: the last result overflowed (more than 32 bits). `LED14`: busy (`nexys_a7_top`)
  or a run is waiting for the CPU (`nexys_a7_cpu_top`).

## Build and load

Build inside the openXC7 shell (the first build also makes the chip database, once):

```
nix --extra-experimental-features 'nix-command flakes' develop github:openxc7/toolchain-nix
scripts/verify.sh bitstream nexys_a7_top        # or nexys_a7_cpu_top
```

For a -50T board, prefix `NEXYS_PART=xc7a50tcsg324-1` on both `bitstream` and `program`.
The `.bit` lands in `evidence/<RUN_ID>/board/<top>.bit`.

Load and watch (no nix shell needed; the bitstream is in SRAM, so reload after power-off):

```
scripts/verify.sh program nexys_a7_top          # newest .bit of that top
screen /dev/ttyUSB1 115200                      # ttyUSB0 on some machines; quit: Ctrl-A k
```

Press `CPU_RESETN` once the terminal is open to see the banner.

## When it does not work

| Symptom | Look at |
|---|---|
| no banner, LEDs follow switches | wrong tty (try the other `ttyUSB`), or baud not 115200 |
| no banner, LEDs dead | bitstream not loaded: `program` output; `board-pnr-<top>.log` errors |
| garbled characters | clock or baud: check `create_clock` was applied in `board-pnr-<top>.log` |
| `nexys_a7_top` works, CPU top prints wrong numbers | timing: rebuild with a slower clock, `CLK_DIV_LOG2 => 4` and `CLKS_PER_BIT => 54` in `nexys_a7_cpu_top` (6.25 MHz) |

Before the board, `scripts/verify.sh sim` runs `tb_board` against both tops (`tb_board` and
`tb_board_cpu`): it presses the buttons and decodes the UART line bit by bit.

## Changing the CPU program

Programs are assembled by [customasm](https://github.com/hlorenzi/customasm)
(`cargo install customasm`) with the rules in `asm/cpu.asm`; it rejects any instruction the
CPU does not implement. Comments start with `;`. I/O registers are listed in `cpu_io.vhd`.

Without rebuilding the bitstream, send a program to the running `nexys_a7_cpu_top` over the
same USB-UART (close `screen` first, it holds the tty):

```
scripts/load.py board/calc.s --tty /dev/ttyUSB1      # a .s is assembled first; a .bin is sent as is
```

The CPU is held while the frame arrives and restarts at pc 0 after the board answers `K`.
`E` (bad checksum, or a stalled transfer) keeps the CPU held until a good load.
`CPU_RESETN` restarts the loaded program; reloading the bitstream brings back `calc.s`.
Programs are at most 256 words.

To change the program built into the bitstream, edit `calc.s` and run `scripts/verify.sh asm`
to regenerate `rtl/program_pkg.vhd`; `verify.sh sim` refuses a stale one.
