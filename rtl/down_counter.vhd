-- Iteration counter of w03c_mult: load W, count down, last = '1' when the count is 1.
-- Load wins over dec; synchronous reset to 0.
library ieee;
use ieee.std_logic_1164.all;

entity down_counter is
  generic (W : positive);
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    load : in  std_logic;
    dec  : in  std_logic;
    last : out std_logic
  );
end entity;

architecture rtl of down_counter is
  signal cnt_r : natural range 0 to W;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt_r <= 0;
      elsif load = '1' then
        cnt_r <= W;
      elsif dec = '1' then
        cnt_r <= cnt_r - 1;
      end if;
    end if;
  end process;

  last <= '1' when cnt_r = 1 else '0';
end architecture;
