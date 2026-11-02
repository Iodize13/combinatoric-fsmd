-- Nexys A7 board top: nCr calculator. n = SW6..0, r = SW13..7, BTNC computes C(n, r) and
-- the result is printed in decimal on the USB-UART (115200 8N1). BTNU toggles debug mode
-- (LED16 green): every switch change, once settled, is computed and printed without BTNC.
-- LED13..0 mirror the switches, LED14 = busy, LED15 = the last result overflowed.
-- CPU_RESETN resets (and leaves debug mode).
-- The 100 MHz board clock is divided by 2**CLK_DIV_LOG2 (25 MHz by default) for timing margin.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nexys_a7_top is
  generic (
    CLK_DIV_LOG2 : positive := 2;
    CLKS_PER_BIT : positive := 217;       -- 25 MHz / 115200
    DEBOUNCE     : positive := 250000     -- 10 ms at 25 MHz
  );
  port (
    CLK100MHZ    : in  std_logic;
    CPU_RESETN   : in  std_logic;
    BTNC         : in  std_logic;
    BTNU         : in  std_logic;
    SW           : in  std_logic_vector(15 downto 0);
    LED          : out std_logic_vector(15 downto 0);
    LED16_G      : out std_logic;
    UART_RXD_OUT : out std_logic;         -- named from the PC's side: FPGA transmit
    UART_TXD_IN  : in  std_logic := '1'   -- unused here; nexys_a7.xdc pins it for the CPU top
  );
end entity;

architecture rtl of nexys_a7_top is
  constant NW : positive := 7;

  signal div        : unsigned(CLK_DIV_LOG2-1 downto 0) := (others => '0');
  signal clk        : std_logic;
  signal rst_sync   : std_logic_vector(1 downto 0) := "11";
  signal rst        : std_logic;
  signal press      : std_logic;
  signal toggle     : std_logic;
  signal debug      : std_logic;
  signal sw_now     : std_logic_vector(2*NW-1 downto 0);
  signal request    : std_logic;
  signal take       : std_logic;
  signal n_l, r_l   : unsigned(NW-1 downto 0) := (others => '0');
  signal start      : std_logic := '0';
  signal result     : unsigned(31 downto 0);
  signal ncr_busy   : std_logic;
  signal ncr_done   : std_logic;
  signal ncr_ovf    : std_logic;
  signal ovf_led    : std_logic := '0';
  signal rep_busy   : std_logic;
  signal tx_start   : std_logic;
  signal tx_data    : std_logic_vector(7 downto 0);
  signal tx_busy    : std_logic;
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

  take <= '1' when request = '1' and ncr_busy = '0' and rep_busy = '0' and start = '0'
          else '0';

  -- latch n, r and start only when both the core and the printer are idle
  process (clk)
  begin
    if rising_edge(clk) then
      start <= '0';
      if rst = '1' then
        ovf_led <= '0';
      else
        if take = '1' then
          n_l   <= unsigned(sw_now(NW-1 downto 0));
          r_l   <= unsigned(sw_now(2*NW-1 downto NW));
          start <= '1';
        end if;
        if ncr_done = '1' then
          ovf_led <= ncr_ovf;
        end if;
      end if;
    end if;
  end process;

  core : entity work.ncr_core
    generic map (W => 32)
    port map (
      clk    => clk,
      rst    => rst,
      start  => start,
      n      => resize(n_l, 32),
      r      => resize(r_l, 32),
      result => result,
      busy   => ncr_busy,
      done   => ncr_done,
      ovf    => ncr_ovf
    );

  report_i : entity work.ncr_report
    generic map (NW => NW)
    port map (
      clk      => clk,
      rst      => rst,
      go       => ncr_done,
      n        => n_l,
      r        => r_l,
      result   => result,
      ovf      => ncr_ovf,
      busy     => rep_busy,
      tx_start => tx_start,
      tx_data  => tx_data,
      tx_busy  => tx_busy
    );

  tx : entity work.uart_tx
    generic map (CLKS_PER_BIT => CLKS_PER_BIT)
    port map (clk => clk, rst => rst, start => tx_start, data => tx_data, busy => tx_busy,
              tx => UART_RXD_OUT);

  LED(13 downto 0) <= SW(13 downto 0);
  LED(14)          <= ncr_busy or rep_busy;
  LED(15)          <= ovf_led;
  LED16_G          <= debug;
end architecture;
