-- nCr FSMD: res <- res * (n-k+i) / i for i = 1..k, k = min(r, n-r).
-- Every division is exact, so no fractions and no floating point.
-- One shared muldiv unit: MULTU leaves the 2W-bit product in HI:LO, then
-- DIVHL divides that HI:LO by i in place, with no copy between them.
-- Structural top: ncr_ctrl (control unit) drives ncr_dp (datapath, with the muldiv unit).
-- Pulse start while busy = '0'; n and r are latched on that cycle.
-- result is valid while done = '1'. If C(n, r) does not fit in W bits, result is all ones
-- and ovf = '1'; the loop stops at the first quotient that does not fit.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ncr_pkg.all;

entity ncr_core is
  generic (W : positive := 32);
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    start  : in  std_logic;
    n      : in  unsigned(W-1 downto 0);
    r      : in  unsigned(W-1 downto 0);
    result : out unsigned(W-1 downto 0);
    busy   : out std_logic;
    done   : out std_logic;
    ovf    : out std_logic
  );
end entity;

architecture rtl of ncr_core is
  signal ctrl   : ncr_ctrl_t;
  signal status : ncr_status_t;
begin
  u_ctrl : entity work.ncr_ctrl
    port map (
      clk    => clk,
      rst    => rst,
      start  => start,
      status => status,
      ctrl   => ctrl,
      busy   => busy,
      done   => done
    );

  u_dp : entity work.ncr_dp
    generic map (W => W)
    port map (
      clk    => clk,
      rst    => rst,
      ctrl   => ctrl,
      n      => n,
      r      => r,
      status => status,
      result => result,
      ovf    => ovf
    );
end architecture;
