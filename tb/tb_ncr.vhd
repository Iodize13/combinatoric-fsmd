-- Exhaustive simulation: every (n, r) with 0 <= n <= N_MAX, 0 <= r <= n + 1,
-- checked against a Pascal's-triangle reference. Prints "TB PASS <count>" on success.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ncr is
  generic (W : positive := 32; N_MAX : natural := 30);
end entity;

architecture sim of tb_ncr is
  type row_t is array (0 to N_MAX + 1) of natural;
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

  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal start  : std_logic := '0';
  signal n, r   : unsigned(W-1 downto 0) := (others => '0');
  signal result : unsigned(W-1 downto 0);
  signal busy, done, ovf : std_logic;
begin
  clk <= not clk after 5 ns;

  dut : entity work.ncr_core
    generic map (W => W)
    port map (clk, rst, start, n, r, result, busy, done, ovf);

  process
    constant SATURATED : unsigned(W-1 downto 0) := (others => '1');
    variable checked, failed : natural := 0;
    variable cycles          : natural;
    variable cycles_exact    : natural;

    -- Runs one C(a, b) and returns the start-to-done cycle count.
    procedure check(a, b : natural; want : unsigned; want_ovf : std_logic) is
    begin
      n     <= to_unsigned(a, W);
      r     <= to_unsigned(b, W);
      start <= '1';
      wait until rising_edge(clk);
      start  <= '0';
      cycles := 0;
      loop
        wait until rising_edge(clk);
        cycles := cycles + 1;
        exit when done = '1';
      end loop;
      if result /= want or ovf /= want_ovf then
        report "MISMATCH n=" & integer'image(a) & " r=" & integer'image(b) &
               " got=" & to_hstring(result) & " ovf=" & std_logic'image(ovf) &
               " want=" & to_hstring(want) & " ovf=" & std_logic'image(want_ovf)
          severity error;
        failed := failed + 1;
      end if;
      checked := checked + 1;
    end procedure;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    for a in 0 to N_MAX loop
      for b in 0 to a + 1 loop
        check(a, b, to_unsigned(REF(a)(b), W), '0');
      end loop;
    end loop;

    -- Largest exact value below 2^32, then results that do not fit: saturate to all ones.
    check(34, 17, x"8B18014C", '0');  -- 2333606220
    cycles_exact := cycles;
    check(35, 17, SATURATED, '1');
    check(40, 20, SATURATED, '1');
    check(67, 33, SATURATED, '1');
    -- Overflow at iteration 11 of 33 must stop the loop, so it beats a 17-iteration exact run.
    if cycles >= cycles_exact then
      report "OVF DID NOT STOP: C(67,33) took " & integer'image(cycles) &
             " cycles, C(34,17) took " & integer'image(cycles_exact) severity error;
      failed := failed + 1;
    end if;
    -- A computation after an overflow must start clean.
    check(5, 2, to_unsigned(10, W), '0');
    if failed = 0 then
      report "TB PASS " & integer'image(checked) severity note;
    else
      report "TB FAIL " & integer'image(failed) & "/" & integer'image(checked) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
