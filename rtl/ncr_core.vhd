-- nCr FSMD: res <- res * (n-k+i) / i for i = 1..k, k = min(r, n-r).
-- Every division is exact, so no fractions and no floating point.
-- One shared muldiv unit: MULTU leaves the 2W-bit product in HI:LO, then
-- DIVHL divides that HI:LO by i in place, with no copy between them.
-- Structural top: ncr_engine (control unit + datapath) with its own muldiv unit.
-- Pulse start while busy = '0'; n and r are latched on that cycle.
-- result is valid while done = '1'. If C(n, r) does not fit in W bits, result is all ones
-- and ovf = '1'; the loop stops at the first quotient that does not fit.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

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
  signal md_start          : std_logic;
  signal md_op             : muldiv_op_t;
  signal md_a, md_b, md_lo : unsigned(W-1 downto 0);
  signal md_done, md_ovf   : std_logic;
begin
  u_engine : entity work.ncr_engine
    generic map (W => W)
    port map (
      clk      => clk,
      rst      => rst,
      start    => start,
      n        => n,
      r        => r,
      result   => result,
      busy     => busy,
      done     => done,
      ovf      => ovf,
      md_start => md_start,
      md_op    => md_op,
      md_a     => md_a,
      md_b     => md_b,
      md_lo    => md_lo,
      md_done  => md_done,
      md_ovf   => md_ovf
    );

  md : entity work.muldiv
    generic map (W => W)
    port map (
      clk   => clk,
      rst   => rst,
      start => md_start,
      op    => md_op,
      a     => md_a,
      b     => md_b,
      hi    => open,
      lo    => md_lo,
      busy  => open,
      done  => md_done,
      dz    => open,
      ovf   => md_ovf
    );
end architecture;
