-- Formal harness for muldiv (VHDL-2008 PSL, read by ghdl-yosys-plugin).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.muldiv_pkg.all;

entity muldiv_props is
  generic (W : positive := 8);
  port (
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;
    op    : in muldiv_op_t;
    a     : in unsigned(W-1 downto 0);
    b     : in unsigned(W-1 downto 0)
  );
end entity;

architecture formal of muldiv_props is
  signal hi, lo                 : unsigned(W-1 downto 0);
  signal busy, done, dz, ovf    : std_logic;
  signal op_l                   : muldiv_op_t := OP_MULTU;
  signal b_l                    : unsigned(W-1 downto 0) := (others => '0');
  signal dividend_l             : unsigned(2*W-1 downto 0) := (others => '0');
  signal product_l              : unsigned(2*W-1 downto 0) := (others => '0');
  signal launched               : std_logic := '0';
  signal hilo                   : unsigned(2*W-1 downto 0);
begin
  dut : entity work.muldiv
    generic map (W => W)
    port map (clk, rst, start, op, a, b, hi, lo, busy, done, dz, ovf);

  hilo <= hi & lo;

  -- Shadow copy of the operation the DUT accepted.
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        launched <= '0';
      elsif start = '1' and busy = '0' then
        op_l      <= op;
        b_l       <= b;
        product_l <= a * b;
        if op = OP_DIVHL then
          dividend_l <= hilo;
        else
          dividend_l <= resize(a, 2*W);
        end if;
        launched <= '1';
      end if;
    end if;
  end process;

  default clock is rising_edge(clk);

  assume_reset_first : assume rst = '1';
  assume_legal_op    : assume always (op /= "11");

  -- Checks are gated on rst = '0': DUT registers are undefined in the reset cycle.
  assert_mul : assert always
    ((rst = '0' and done = '1' and launched = '1' and op_l = OP_MULTU) ->
       hilo = product_l);

  assert_div : assert always
    ((rst = '0' and done = '1' and launched = '1' and op_l /= OP_MULTU
      and dz = '0' and ovf = '0') ->
       (resize(lo * b_l, 2*W) + resize(hi, 2*W) = dividend_l and hi < b_l));

  assert_dz  : assert always
    ((rst = '0' and done = '1' and launched = '1' and op_l /= OP_MULTU) ->
       ((dz = '1') = (b_l = 0)));

  assert_ovf : assert always
    ((rst = '0' and done = '1' and launched = '1' and op_l = OP_DIVHL and b_l /= 0) ->
       ((ovf = '1') = (dividend_l(2*W-1 downto W) >= b_l)));

  assert_done_only_from_busy : assert always ((rst = '0' and done = '1') -> launched = '1');

  -- Covers require rst = '0' at every step; otherwise they match in the undefined reset cycle.
  cover_mul_max : cover {rst = '0' and start = '1' and busy = '0' and op = OP_MULTU and a = 2**W - 1 and b = 2**W - 1;
                         (rst = '0' and done = '0')[*];
                         rst = '0' and done = '1'};
  cover_divhl   : cover {rst = '0' and start = '1' and busy = '0' and op = OP_DIVHL and hi /= 0 and hi < b;
                         (rst = '0' and done = '0')[*];
                         rst = '0' and done = '1' and ovf = '0'};
end architecture;
