-- Data memory: asynchronous read, write on the clock edge, word-addressed by addr(9 downto 2).
-- Starts all zero.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity dmem is
  port (
    clk  : in  std_logic;
    we   : in  std_logic;
    addr : in  word_t;
    wd   : in  word_t;
    rd   : out word_t
  );
end entity;

architecture rtl of dmem is
  signal ram : mem_t := (others => (others => '0'));
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        ram(to_integer(addr(9 downto 2))) <= wd;
      end if;
    end if;
  end process;

  rd <= ram(to_integer(addr(9 downto 2)));
end architecture;
