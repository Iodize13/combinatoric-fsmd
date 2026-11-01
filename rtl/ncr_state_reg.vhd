-- State register of the nCr control unit: the state and the registered done.
library ieee;
use ieee.std_logic_1164.all;
use work.ncr_pkg.all;

entity ncr_state_reg is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    next_state : in  state_t;
    finish     : in  std_logic;
    state      : out state_t;
    busy       : out std_logic;
    done       : out std_logic
  );
end entity;

architecture rtl of ncr_state_reg is
  signal state_r : state_t;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state_r <= S_IDLE;
        done    <= '0';
      else
        state_r <= next_state;
        done    <= finish;
      end if;
    end if;
  end process;

  state <= state_r;
  busy  <= '0' when state_r = S_IDLE else '1';
end architecture;
