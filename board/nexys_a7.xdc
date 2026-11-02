## Nexys A7 (-100T and -50T share this pinout), ports of board/nexys_a7_top.vhd.
## Lines copied from Digilent's Nexys-A7-100T-Master.xdc (github.com/Digilent/digilent-xdc).

## 100 MHz oscillator
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports CLK100MHZ]

## Switches: SW6..0 = n, SW13..7 = r (SW8 and SW9 sit in a 1.8 V bank)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports SW[0]]
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports SW[1]]
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports SW[2]]
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports SW[3]]
set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports SW[4]]
set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports SW[5]]
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports SW[6]]
set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 } [get_ports SW[7]]
set_property -dict { PACKAGE_PIN T8    IOSTANDARD LVCMOS18 } [get_ports SW[8]]
set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS18 } [get_ports SW[9]]
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports SW[10]]
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports SW[11]]
set_property -dict { PACKAGE_PIN H6    IOSTANDARD LVCMOS33 } [get_ports SW[12]]
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports SW[13]]
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports SW[14]]
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports SW[15]]

## LEDs: LED13..0 mirror the switches, LED14 = busy, LED15 = overflow
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports LED[0]]
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports LED[1]]
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports LED[2]]
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports LED[3]]
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports LED[4]]
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports LED[5]]
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports LED[6]]
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports LED[7]]
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports LED[8]]
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports LED[9]]
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports LED[10]]
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports LED[11]]
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports LED[12]]
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports LED[13]]
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports LED[14]]
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports LED[15]]

## RGB LED16, green = debug mode
set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports LED16_G]

## Buttons: CPU_RESETN (active low) = reset, BTNC = run, BTNU = toggle debug mode
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports CPU_RESETN]
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports BTNC]
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports BTNU]

## USB-UART, named from the PC's side: UART_RXD_OUT is the FPGA's transmit line,
## UART_TXD_IN its receive line (the program loader of nexys_a7_cpu_top)
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports UART_RXD_OUT]
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports UART_TXD_IN]
