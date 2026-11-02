-- Push button to one-cycle pulse: two-flop synchronizer, then the level must stay the same
-- for DEBOUNCE cycles before it counts; pulse on each debounced press.
library ieee;
use ieee.std_logic_1164.all;

entity btn_pulse is
  generic (DEBOUNCE : positive);
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    btn   : in  std_logic;
    pulse : out std_logic
  );
end entity;

architecture rtl of btn_pulse is
  signal sync   : std_logic_vector(1 downto 0) := "00";
  signal stable : std_logic := '0';
  signal count  : natural range 0 to DEBOUNCE := 0;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      sync  <= sync(0) & btn;
      pulse <= '0';
      if rst = '1' then
        stable <= '0';
        count  <= 0;
      elsif sync(1) = stable then
        count <= 0;
      elsif count = DEBOUNCE then
        stable <= sync(1);
        count  <= 0;
        pulse  <= sync(1);
      else
        count <= count + 1;
      end if;
    end if;
  end process;
end architecture;
