-- One-shot runner: computes C(N, R) on ncr_core and prints the result and cycle count.
--   ghdl -r --std=08 ncr_run -gN=10 -gR=3
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ncr_run is
  generic (W : positive := 32; N : natural := 5; R : natural := 2);
end entity;

architecture sim of ncr_run is
  -- integer'image cannot print a full W-bit unsigned, so format it digit by digit.
  function to_dec(u : unsigned) return string is
    variable v : unsigned(u'length-1 downto 0) := u;
    variable d : natural;
  begin
    if v < 10 then
      return integer'image(to_integer(v));
    end if;
    d := to_integer(v mod 10);
    return to_dec(v / 10) & integer'image(d);
  end function;

  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal start  : std_logic := '0';
  signal n_s    : unsigned(W-1 downto 0) := to_unsigned(N, W);
  signal r_s    : unsigned(W-1 downto 0) := to_unsigned(R, W);
  signal result : unsigned(W-1 downto 0);
  signal busy, done, ovf : std_logic;
  signal stop   : boolean := false;
begin
  clk <= not clk after 5 ns when not stop;

  dut : entity work.ncr_core
    generic map (W => W)
    port map (clk, rst, start, n_s, r_s, result, busy, done, ovf);

  process
    variable cycles : natural := 0;
  begin
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst   <= '0';
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    loop
      wait until rising_edge(clk);
      cycles := cycles + 1;
      exit when done = '1';
    end loop;
    if ovf = '1' then
      report "C(" & integer'image(N) & ", " & integer'image(R) & ") overflows " &
             integer'image(W) & " bits (" & integer'image(cycles) & " cycles)";
    else
      report "C(" & integer'image(N) & ", " & integer'image(R) & ") = " & to_dec(result) &
             " (" & integer'image(cycles) & " cycles)";
    end if;
    stop <= true;
    wait;
  end process;
end architecture;
