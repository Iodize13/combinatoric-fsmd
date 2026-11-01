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
    variable checked, failed : natural := 0;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    for a in 0 to N_MAX loop
      for b in 0 to a + 1 loop
        n     <= to_unsigned(a, W);
        r     <= to_unsigned(b, W);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';
        wait until rising_edge(clk) and done = '1';
        if result /= to_unsigned(REF(a)(b), W) or ovf /= '0' then
          report "MISMATCH n=" & integer'image(a) & " r=" & integer'image(b) &
                 " got=" & integer'image(to_integer(result)) &
                 " want=" & integer'image(REF(a)(b)) &
                 " ovf=" & std_logic'image(ovf) severity error;
          failed := failed + 1;
        end if;
        checked := checked + 1;
      end loop;
    end loop;
    if failed = 0 then
      report "TB PASS " & integer'image(checked) severity note;
    else
      report "TB FAIL " & integer'image(failed) & "/" & integer'image(checked) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
