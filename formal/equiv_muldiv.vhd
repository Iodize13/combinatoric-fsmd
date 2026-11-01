-- Equivalence miter: rtl/muldiv against the frozen formal/ref/muldiv_ref.
-- Both get the same inputs; every output must match in every cycle after reset.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

entity equiv_muldiv is
  generic (W : positive := 4);
  port (
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;
    op    : in muldiv_op_t;
    a     : in unsigned(W-1 downto 0);
    b     : in unsigned(W-1 downto 0)
  );
end entity;

architecture formal of equiv_muldiv is
  signal hi_n, lo_n, hi_o, lo_o : unsigned(W-1 downto 0);
  signal busy_n, done_n, dz_n, ovf_n : std_logic;
  signal busy_o, done_o, dz_o, ovf_o : std_logic;
begin
  dut : entity work.muldiv
    generic map (W => W)
    port map (clk, rst, start, op, a, b, hi_n, lo_n, busy_n, done_n, dz_n, ovf_n);

  ref : entity work.muldiv_ref
    generic map (W => W)
    port map (clk, rst, start, op, a, b, hi_o, lo_o, busy_o, done_o, dz_o, ovf_o);

  default clock is rising_edge(clk);

  assume_reset_first : assume rst = '1';

  -- Outputs are undefined in the reset cycle itself, so compare only when rst = '0'.
  assert_same : assert always
    (rst = '0' ->
       (hi_n = hi_o and lo_n = lo_o and busy_n = busy_o and done_n = done_o and
        dz_n = dz_o and ovf_n = ovf_o));
end architecture;
