-- When should the board compute? A BTNC press requests a run; in debug mode (toggled by
-- BTNU) any switch change, once the switches have been still for SETTLE cycles, requests
-- one too. The consumer pulses take when it starts the run: that clears a press and records
-- the switches, so debug mode asks again only after they change. sw_now is the synchronized
-- switch value to compute with.
library ieee;
use ieee.std_logic_1164.all;

entity run_request is
  generic (
    W      : positive;
    SETTLE : positive
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    press   : in  std_logic;
    toggle  : in  std_logic;
    sw      : in  std_logic_vector(W-1 downto 0);
    take    : in  std_logic;
    sw_now  : out std_logic_vector(W-1 downto 0);
    debug   : out std_logic;
    request : out std_logic
  );
end entity;

architecture rtl of run_request is
  signal meta, now, last : std_logic_vector(W-1 downto 0) := (others => '0');
  signal age             : natural range 0 to SETTLE := 0;
  signal debug_r         : std_logic := '0';
  signal pressed         : std_logic := '0';
  signal taken           : std_logic := '0';    -- last holds the switches of a run
begin
  process (clk)
  begin
    if rising_edge(clk) then
      meta <= sw;
      now  <= meta;
      if now /= meta then
        age <= 0;
      elsif age /= SETTLE then
        age <= age + 1;
      end if;
      if rst = '1' then
        debug_r <= '0';
        pressed <= '0';
        taken   <= '0';
      else
        if toggle = '1' then
          debug_r <= not debug_r;
        end if;
        if take = '1' then
          pressed <= '0';
          taken   <= '1';
          last    <= now;
        elsif press = '1' then
          pressed <= '1';
        end if;
      end if;
    end if;
  end process;

  sw_now  <= now;
  debug   <= debug_r;
  request <= '1' when pressed = '1' or
                      (debug_r = '1' and age = SETTLE and (taken = '0' or now /= last))
             else '0';
end architecture;
