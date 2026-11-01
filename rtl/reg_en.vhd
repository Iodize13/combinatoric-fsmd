-- W-bit register with load enable and synchronous reset to 0 (M register, n/r/k registers).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_en is
  generic (W : positive);
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    en  : in  std_logic;
    d   : in  unsigned(W-1 downto 0);
    q   : out unsigned(W-1 downto 0)
  );
end entity;

architecture rtl of reg_en is
  signal q_r : unsigned(W-1 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q_r <= (others => '0');
      elsif en = '1' then
        q_r <= d;
      end if;
    end if;
  end process;

  q <= q_r;
end architecture;
