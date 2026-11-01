-- Status tests of the "Control test" inputs in w03c_mult: divisor zero, HI >= divisor,
-- Product0, and the sign bit of the left half.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity muldiv_status is
  generic (W : positive);
  port (
    b        : in  unsigned(W-1 downto 0);
    rem_q    : in  unsigned(2*W downto 0);
    b_zero   : out std_logic;
    hi_ge_b  : out std_logic;
    rem_lsb  : out std_logic;
    rem_sign : out std_logic
  );
end entity;

architecture rtl of muldiv_status is
begin
  b_zero   <= '1' when b = 0 else '0';
  hi_ge_b  <= '1' when rem_q(2*W-1 downto W) >= b else '0';
  rem_lsb  <= rem_q(0);
  rem_sign <= rem_q(2*W);
end architecture;
