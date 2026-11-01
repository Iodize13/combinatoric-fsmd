-- Lockstep simulation at W = 32: rtl muldiv/ncr_core against the frozen references in
-- formal/ref/, fed the same random stimulus, compared every cycle.
-- Prints "TB PASS <cycles>" on success.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.muldiv_pkg.all;

entity tb_equiv is
  generic (N_CYCLES : natural := 200000);
end entity;

architecture sim of tb_equiv is
  constant W : positive := 32;
  subtype word is unsigned(W-1 downto 0);

  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal start : std_logic := '0';
  signal op    : muldiv_op_t := OP_MULTU;
  signal a, b  : word := (others => '0');
  signal n, r  : word := (others => '0');

  signal hi_n, lo_n, hi_o, lo_o       : word;
  signal busy_n, done_n, dz_n, ovf_n  : std_logic;
  signal busy_o, done_o, dz_o, ovf_o  : std_logic;
  signal res_n, res_o                 : word;
  signal nbusy_n, ndone_n, novf_n     : std_logic;
  signal nbusy_o, ndone_o, novf_o     : std_logic;
begin
  clk <= not clk after 5 ns;

  md_new : entity work.muldiv
    generic map (W => W)
    port map (clk, rst, start, op, a, b, hi_n, lo_n, busy_n, done_n, dz_n, ovf_n);
  md_ref : entity work.muldiv_ref
    generic map (W => W)
    port map (clk, rst, start, op, a, b, hi_o, lo_o, busy_o, done_o, dz_o, ovf_o);

  nc_new : entity work.ncr_core
    generic map (W => W)
    port map (clk, rst, start, n, r, res_n, nbusy_n, ndone_n, novf_n);
  nc_ref : entity work.ncr_core_ref
    generic map (W => W)
    port map (clk, rst, start, n, r, res_o, nbusy_o, ndone_o, novf_o);

  process
    variable s1, s2  : positive := 11;
    variable rnd     : real;
    variable failed  : natural := 0;
    variable x       : natural;

    impure function rand_nat(limit : natural) return natural is
    begin
      uniform(s1, s2, rnd);
      return integer(trunc(rnd * real(limit))) mod limit;
    end function;

    impure function rand_word return word is
      variable v : word;
    begin
      v(31 downto 16) := to_unsigned(rand_nat(65536), 16);
      v(15 downto 0)  := to_unsigned(rand_nat(65536), 16);
      return v;
    end function;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    for t in 1 to N_CYCLES loop
      -- Random inputs every cycle, including start while busy and rare mid-run resets.
      start <= '1' when rand_nat(8) = 0 else '0';
      x := rand_nat(3);
      op <= OP_MULTU when x = 0 else OP_DIVU when x = 1 else OP_DIVHL;
      a <= rand_word;
      b <= (others => '0') when rand_nat(16) = 0 else rand_word;
      x := rand_nat(70);
      n <= to_unsigned(x, W);
      r <= to_unsigned(rand_nat(x + 2), W);
      rst <= '1' when rand_nat(5000) = 0 else '0';
      wait until rising_edge(clk);
      if rst = '0' and
         (hi_n /= hi_o or lo_n /= lo_o or busy_n /= busy_o or done_n /= done_o or
          dz_n /= dz_o or ovf_n /= ovf_o or res_n /= res_o or nbusy_n /= nbusy_o or
          ndone_n /= ndone_o or novf_n /= novf_o) then
        report "DIVERGED at cycle " & integer'image(t) severity error;
        failed := failed + 1;
      end if;
    end loop;
    if failed = 0 then
      report "TB PASS " & integer'image(N_CYCLES) severity note;
    else
      report "TB FAIL " & integer'image(failed) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
