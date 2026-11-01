-- Loop counter i of the nCr datapath: load 1, count up; synchronous reset to 0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity up_counter is
  generic (W : positive);
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    load : in  std_logic;
    inc  : in  std_logic;
    q    : out unsigned(W-1 downto 0)
  );
end entity;

architecture rtl of up_counter is
  signal q_r : unsigned(W-1 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        q_r <= (others => '0');
      elsif load = '1' then
        q_r <= to_unsigned(1, W);
      elsif inc = '1' then
        q_r <= q_r + 1;
      end if;
    end if;
  end process;

  q <= q_r;
end architecture;
