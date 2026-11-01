-- N-bit adder/subtractor, the ALU box of w03c_mult (approach 2): y = a - b when sub = '1', else a + b.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
  generic (N : positive);
  port (
    a   : in  unsigned(N-1 downto 0);
    b   : in  unsigned(N-1 downto 0);
    sub : in  std_logic;
    y   : out unsigned(N-1 downto 0)
  );
end entity;

architecture rtl of alu is
begin
  y <= a - b when sub = '1' else a + b;
end architecture;
