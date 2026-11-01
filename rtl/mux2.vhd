-- W-bit 2-input multiplexer: y = a1 when sel = '1', else a0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux2 is
  generic (W : positive);
  port (
    sel : in  std_logic;
    a0  : in  unsigned(W-1 downto 0);
    a1  : in  unsigned(W-1 downto 0);
    y   : out unsigned(W-1 downto 0)
  );
end entity;

architecture rtl of mux2 is
begin
  y <= a1 when sel = '1' else a0;
end architecture;
