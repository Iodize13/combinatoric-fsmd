# board: the Nexys A7 calculator

Switches set n and r, BTNC (or a settled switch change in debug mode, toggled by BTNU) runs C(n, r), and the result is printed as `C(n,r) = <decimal>` or `C(n,r) = overflow` on the USB-UART. Two tops share pins and controls: `nexys_a7_top` (ncr_core plus a hardware formatter) and `nexys_a7_cpu_top` (the CPU running `board/calc.s`).

## Sub-features

- `board.banner`: after reset the banner line prints.
- `board.button`: BTNC prints the right line for C(34,17), C(67,33) and C(40,20) (overflow, LED15 on), C(5,2), C(3,5) = 0, C(0,0), C(127,1), C(33,16).
- `board.debug`: after BTNU, switch changes alone print; settled switches print nothing more; a second BTNU leaves debug mode.

## How to get to it (user POV)

- On the board: `board/README.md` (build with `scripts/verify.sh bitstream <top>` inside the openXC7 nix shell, load with `scripts/verify.sh program <top>`, read with `screen /dev/ttyUSB1 115200`).

## Driving it with scripts/verify.sh

Preconditions: baseline from README.

- **Simulate both tops.** Run `scripts/verify.sh sim`. `sim-run-tb_board.log` and `sim-run-tb_board_cpu.log` must each contain `TB PASS 12` (banner + 8 button lines + 3 debug lines). A mismatch prints `got "...", want "..."`.
- **Map to Artix-7.** Run `scripts/verify.sh board-synth`. Both `board-synth-<top>.exit` must be `0`. The CPU top should show `RAM32M` (register file) and `RAM256X1S` (data RAM) cells.
- **Bitstream.** Inside the openXC7 shell, `scripts/verify.sh bitstream <top>` must leave `evidence/$RUN_ID/board/<top>.bit`.

## Gotchas

- The testbench uses fast UART (`CLKS_PER_BIT = 8`) and debounce (`4`) generics with the real clock divider. On the board the defaults are 115200 baud and 10 ms.
- The only check on the real board is a person reading the terminal; nothing here proves pin assignments beyond matching Digilent's master XDC.
