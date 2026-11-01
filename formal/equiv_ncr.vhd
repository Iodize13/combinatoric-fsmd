-- Equivalence miter: rtl/ncr_core against the frozen formal/ref/ncr_core_ref.
-- Both get the same inputs; every output must match in every cycle after reset.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity equiv_ncr is
  generic (W : positive := 4);
  port (
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;
    n     : in unsigned(W-1 downto 0);
    r     : in unsigned(W-1 downto 0)
  );
end entity;

architecture formal of equiv_ncr is
  signal result_n, result_o : unsigned(W-1 downto 0);
  signal busy_n, done_n, ovf_n : std_logic;
  signal busy_o, done_o, ovf_o : std_logic;
begin
  dut : entity work.ncr_core
    generic map (W => W)
    port map (clk, rst, start, n, r, result_n, busy_n, done_n, ovf_n);

  ref : entity work.ncr_core_ref
    generic map (W => W)
    port map (clk, rst, start, n, r, result_o, busy_o, done_o, ovf_o);

  default clock is rising_edge(clk);

  assume_reset_first : assume rst = '1';

  assert_same : assert always
    (rst = '0' ->
       (result_n = result_o and busy_n = busy_o and done_n = done_o and ovf_n = ovf_o));
end architecture;
