-- Nexys A7 board top: the single-cycle CPU running board/calc.s as an nCr calculator.
-- Same ports, pins (board/nexys_a7.xdc) and controls as nexys_a7_top: n = SW6..0,
-- r = SW13..7, BTNC runs, BTNU toggles debug mode (LED16 green: settled switch changes run
-- by themselves), results print in decimal on the USB-UART (115200 8N1). Here the CPU
-- does the work in software through the I/O registers of cpu_io. LED13..0 mirror the
-- switches, LED14 = a run is waiting for the CPU, LED15 = the last result overflowed.
-- The 100 MHz clock is divided by 2**CLK_DIV_LOG2 (12.5 MHz by default): the single-cycle
-- path (ROM, register file, ALU, RAM, write-back) is long and openXC7 timing is approximate.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;
use work.program_pkg.all;

entity nexys_a7_cpu_top is
  generic (
    CLK_DIV_LOG2 : positive := 3;
    CLKS_PER_BIT : positive := 109;       -- 12.5 MHz / 115200 = 108.5
    DEBOUNCE     : positive := 125000     -- 10 ms at 12.5 MHz
  );
  port (
    CLK100MHZ    : in  std_logic;
    CPU_RESETN   : in  std_logic;
    BTNC         : in  std_logic;
    BTNU         : in  std_logic;
    SW           : in  std_logic_vector(15 downto 0);
    LED          : out std_logic_vector(15 downto 0);
    LED16_G      : out std_logic;
    UART_RXD_OUT : out std_logic          -- named from the PC's side: FPGA transmit
  );
end entity;

architecture rtl of nexys_a7_cpu_top is
  constant NW : positive := 7;

  signal div       : unsigned(CLK_DIV_LOG2-1 downto 0) := (others => '0');
  signal clk       : std_logic;
  signal rst_sync  : std_logic_vector(1 downto 0) := "11";
  signal rst       : std_logic;
  signal press     : std_logic;
  signal toggle    : std_logic;
  signal debug     : std_logic;
  signal sw_now    : std_logic_vector(2*NW-1 downto 0);
  signal request   : std_logic;
  signal take      : std_logic;
  signal mem_we    : std_logic;
  signal mem_addr  : word_t;
  signal mem_wdata : word_t;
  signal io_rdata  : word_t;
  signal tx_start  : std_logic;
  signal tx_data   : std_logic_vector(7 downto 0);
  signal tx_busy   : std_logic;
  signal led_ovf   : std_logic;
begin
  process (CLK100MHZ)
  begin
    if rising_edge(CLK100MHZ) then
      div <= div + 1;
    end if;
  end process;
  clk <= div(CLK_DIV_LOG2-1);

  -- asynchronous assert, synchronous release
  process (clk, CPU_RESETN)
  begin
    if CPU_RESETN = '0' then
      rst_sync <= "11";
    elsif rising_edge(clk) then
      rst_sync <= rst_sync(0) & '0';
    end if;
  end process;
  rst <= rst_sync(1);

  btn : entity work.btn_pulse
    generic map (DEBOUNCE => DEBOUNCE)
    port map (clk => clk, rst => rst, btn => BTNC, pulse => press);

  dbg_btn : entity work.btn_pulse
    generic map (DEBOUNCE => DEBOUNCE)
    port map (clk => clk, rst => rst, btn => BTNU, pulse => toggle);

  req : entity work.run_request
    generic map (W => 2*NW, SETTLE => DEBOUNCE)
    port map (clk => clk, rst => rst, press => press, toggle => toggle,
              sw => SW(2*NW-1 downto 0), take => take, sw_now => sw_now, debug => debug,
              request => request);

  core : entity work.cpu
    generic map (ROM => CALC_PROGRAM)
    port map (clk => clk, rst => rst, pc => open, mem_we => mem_we, mem_addr => mem_addr,
              mem_wdata => mem_wdata, io_rdata => io_rdata);

  io : entity work.cpu_io
    generic map (NW => NW)
    port map (
      clk       => clk,
      rst       => rst,
      mem_we    => mem_we,
      mem_addr  => mem_addr,
      mem_wdata => mem_wdata,
      io_rdata  => io_rdata,
      n         => sw_now(NW-1 downto 0),
      r         => sw_now(2*NW-1 downto NW),
      request   => request,
      tx_busy   => tx_busy,
      take      => take,
      tx_start  => tx_start,
      tx_data   => tx_data,
      led_ovf   => led_ovf
    );

  tx : entity work.uart_tx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (clk => clk, rst => rst, start => tx_start, data => tx_data, busy => tx_busy,
              tx => UART_RXD_OUT);

  LED(13 downto 0) <= SW(13 downto 0);
  LED(14)          <= request;
  LED(15)          <= led_ovf;
  LED16_G          <= debug;
end architecture;
