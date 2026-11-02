-- UART receiver, 8N1, LSB first. rx passes a 2-FF synchronizer; each bit is sampled in its
-- middle, timed from the start bit's falling edge. valid pulses for one cycle with data
-- once a byte with a good stop bit is in; a bad stop bit drops the byte.
-- CLKS_PER_BIT = clock frequency / baud rate.
library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
  generic (CLKS_PER_BIT : positive);
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    rx    : in  std_logic;
    valid : out std_logic;
    data  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of uart_rx is
  signal sync  : std_logic_vector(1 downto 0) := "11";
  signal shift : std_logic_vector(7 downto 0) := (others => '0');   -- data bits, LSB first
  signal bits  : natural range 0 to 10 := 0;                         -- bits still to sample
  signal tick  : natural range 0 to CLKS_PER_BIT - 1 := 0;
  signal done  : std_logic := '0';
begin
  process (clk)
  begin
    if rising_edge(clk) then
      sync <= sync(0) & rx;
      done <= '0';
      if rst = '1' then
        bits <= 0;
        tick <= 0;
      elsif bits = 0 then
        if sync(1) = '0' then
          bits <= 10;
          tick <= CLKS_PER_BIT / 2;
        end if;
      elsif tick = CLKS_PER_BIT - 1 then
        tick <= 0;
        bits <= bits - 1;
        if bits = 10 and sync(1) = '1' then
          bits <= 0;
        elsif bits = 1 then
          done <= sync(1);
        elsif bits /= 10 then
          shift <= sync(1) & shift(7 downto 1);
        end if;
      else
        tick <= tick + 1;
      end if;
    end if;
  end process;

  valid <= done;
  data  <= shift;
end architecture;
