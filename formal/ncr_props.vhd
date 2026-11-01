-- Formal harness for ncr_core (VHDL-2008 PSL, read by ghdl-yosys-plugin).
-- Small W and N_MAX keep the state space tractable; the RTL is generic, so
-- the same logic is what runs at W = 32.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ncr_props is
  generic (W : positive := 6; N_MAX : natural := 6);
  port (
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;
    n     : in unsigned(W-1 downto 0);
    r     : in unsigned(W-1 downto 0)
  );
end entity;

architecture formal of ncr_props is
  type row_t is array (0 to 2**W - 1) of natural;
  type tri_t is array (0 to N_MAX) of row_t;

  function pascal return tri_t is
    variable t : tri_t := (others => (others => 0));
  begin
    for a in 0 to N_MAX loop
      t(a)(0) := 1;
      for b in 1 to a loop
        t(a)(b) := t(a-1)(b-1) + t(a-1)(b);
      end loop;
    end loop;
    return t;
  end function;

  constant REF : tri_t := pascal;

  -- Worst case: k = N_MAX/2 iterations of CHECK, MUL_START, W mul steps, MUL_WAIT, DIV_START, W div steps, DIV_WAIT.
  constant LATENCY_BOUND : natural := 4 + (N_MAX / 2 + 1) * (2 * W + 5);

  signal result          : unsigned(W-1 downto 0);
  signal busy, done, ovf : std_logic;
  signal n_l, r_l        : unsigned(W-1 downto 0) := (others => '0');
  signal launched        : std_logic := '0';
  signal age             : natural range 0 to LATENCY_BOUND + 1 := 0;
begin
  dut : entity work.ncr_core
    generic map (W => W)
    port map (clk, rst, start, n, r, result, busy, done, ovf);

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        launched <= '0';
        age      <= 0;
      elsif start = '1' and busy = '0' then
        n_l      <= n;
        r_l      <= r;
        launched <= '1';
        age      <= 0;
      elsif busy = '1' and age <= LATENCY_BOUND then
        age <= age + 1;
      end if;
    end if;
  end process;

  default clock is rising_edge(clk);

  assume_reset_first : assume rst = '1';
  assume_n_small     : assume always (n <= N_MAX);

  assert_correct : assert always
    ((rst = '0' and done = '1' and launched = '1') ->
       (result = to_unsigned(REF(to_integer(n_l))(to_integer(r_l)), W) and ovf = '0'));

  assert_bounded_latency : assert always (age <= LATENCY_BOUND);

  -- Covers require rst = '0' at every step; otherwise they match in the undefined reset cycle.
  cover_largest : cover {rst = '0' and start = '1' and busy = '0' and n = N_MAX and r = N_MAX / 2;
                         (rst = '0' and done = '0')[*];
                         rst = '0' and done = '1'};
  cover_r_gt_n  : cover {rst = '0' and start = '1' and busy = '0' and n = 3 and r = 5;
                         (rst = '0' and done = '0')[*];
                         rst = '0' and done = '1' and result = 0};
end architecture;
