-- Runs tb/cpu_test.s (rtl/program_pkg.vhd) on the CPU and checks every data-memory store,
-- in order, then that the program reaches its halt loop.
-- Prints "TB PASS <stores>" on success.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity tb_cpu is
  generic (MAX_CYCLES : natural := 50000);
end entity;

architecture sim of tb_cpu is
  type store_t is record
    addr : natural;
    data : word_t;
  end record;
  type stores_t is array (natural range <>) of store_t;

  constant EXPECTED : stores_t := (
    (0,  x"0000000A"),    -- C(5, 2)
    (4,  x"0000000F"),    -- add
    (8,  x"0000000D"),    -- sub
    (12, x"0000000D"),    -- and
    (16, x"0000000F"),    -- or
    (20, x"00000001"),    -- slt true
    (24, x"00000000"),    -- slt false
    (28, x"00000007"),    -- lw, addi -3
    (32, x"00000000"),    -- $zero stays 0
    (36, x"FFFFFFFE"),    -- multu HI
    (40, x"00000001"),    -- multu LO
    (68, x"00000001"),    -- slt signed: -1 < 2
    (44, x"0000000E"),    -- divu quotient
    (48, x"00000002"),    -- divu remainder
    (52, x"FFFFFFFF"),    -- C(67, 33) saturates
    (56, x"00000000"),    -- C(33, 67)
    (60, x"8B18014C"),    -- C(34, 17)
    (64, x"00000400"),    -- sum of C(10, k)
    (72, x"0000002A"));   -- jal / jr round trip
  constant HALT_PC : word_t := to_unsigned(59 * 4, 32);

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal pc        : word_t;
  signal mem_we    : std_logic;
  signal mem_addr  : word_t;
  signal mem_wdata : word_t;
begin
  clk <= not clk after 5 ns;

  dut : entity work.cpu
    port map (clk => clk, rst => rst, pc => pc, mem_we => mem_we, mem_addr => mem_addr,
              mem_wdata => mem_wdata);

  process
    variable seen   : natural := 0;
    variable failed : natural := 0;
    variable cycle  : natural := 0;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    while cycle < MAX_CYCLES and not (seen = EXPECTED'length and pc = HALT_PC) loop
      wait until falling_edge(clk);
      if mem_we = '1' then
        if seen = EXPECTED'length then
          report "unexpected store to " & to_hstring(mem_addr) severity error;
          failed := failed + 1;
        elsif to_integer(mem_addr) /= EXPECTED(seen).addr or
              mem_wdata /= EXPECTED(seen).data then
          report "store " & integer'image(seen) & ": got [" & to_hstring(mem_addr) & "] = " &
                 to_hstring(mem_wdata) & ", want [" & integer'image(EXPECTED(seen).addr) &
                 "] = " & to_hstring(EXPECTED(seen).data) severity error;
          failed := failed + 1;
        end if;
        if seen < EXPECTED'length then
          seen := seen + 1;
        end if;
      end if;
      wait until rising_edge(clk);
      cycle := cycle + 1;
    end loop;
    if seen /= EXPECTED'length or pc /= HALT_PC then
      report "stopped after " & integer'image(cycle) & " cycles: " & integer'image(seen) &
             " stores, pc = " & to_hstring(pc) severity error;
      failed := failed + 1;
    end if;
    if failed = 0 then
      report "TB PASS " & integer'image(seen) & " (" & integer'image(cycle) & " cycles)"
        severity note;
    else
      report "TB FAIL " & integer'image(failed) severity failure;
    end if;
    std.env.finish;
  end process;
end architecture;
