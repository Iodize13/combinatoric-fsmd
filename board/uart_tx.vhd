-- UART transmitter, 8N1, LSB first. Pulse start with busy = '0'; data is sampled then.
-- CLKS_PER_BIT = clock frequency / baud rate.
library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
  generic (CLKS_PER_BIT : positive);
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    data  : in  std_logic_vector(7 downto 0);
    busy  : out std_logic;
    tx    : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  signal frame : std_logic_vector(9 downto 0) := (others => '1');    -- stop & data & start
  signal bits  : natural range 0 to 10 := 0;                          -- bits still to send
  signal tick  : natural range 0 to CLKS_PER_BIT - 1 := 0;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        frame <= (others => '1');
        bits  <= 0;
        tick  <= 0;
      elsif bits = 0 then
        if start = '1' then
          frame <= '1' & data & '0';
          bits  <= 10;
          tick  <= 0;
        end if;
      elsif tick = CLKS_PER_BIT - 1 then
        frame <= '1' & frame(9 downto 1);
        bits  <= bits - 1;
        tick  <= 0;
      else
        tick <= tick + 1;
      end if;
    end if;
  end process;

  tx   <= frame(0) when bits /= 0 else '1';
  busy <= '0' when bits = 0 else '1';
end architecture;
