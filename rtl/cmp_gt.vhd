-- Unsigned comparator: gt = '1' when a > b.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmp_gt is
  generic (W : positive);
  port (
    a  : in  unsigned(W-1 downto 0);
    b  : in  unsigned(W-1 downto 0);
    gt : out std_logic
  );
end entity;

architecture rtl of cmp_gt is
begin
  gt <= '1' when a > b else '0';
end architecture;
