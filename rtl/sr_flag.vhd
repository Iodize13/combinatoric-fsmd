-- Set/clear flag register (dz, ovf): set wins over clear; synchronous reset to '0'.
library ieee;
use ieee.std_logic_1164.all;

entity sr_flag is
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    clr : in  std_logic;
    set : in  std_logic;
    q   : out std_logic
  );
end entity;

architecture rtl of sr_flag is
  signal q_r : std_logic;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q_r <= '0';
      elsif set = '1' then
        q_r <= '1';
      elsif clr = '1' then
        q_r <= '0';
      end if;
    end if;
  end process;

  q <= q_r;
end architecture;
