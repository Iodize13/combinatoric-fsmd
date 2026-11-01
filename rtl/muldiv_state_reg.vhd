-- State register of the "Control test" box of w03c_mult: the phase and the registered done.
library ieee;
use ieee.std_logic_1164.all;
use work.muldiv_pkg.all;

entity muldiv_state_reg is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    next_phase : in  phase_t;
    finish     : in  std_logic;
    phase      : out phase_t;
    busy       : out std_logic;
    done       : out std_logic
  );
end entity;

architecture rtl of muldiv_state_reg is
  signal phase_r : phase_t;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        phase_r <= P_IDLE;
        done    <= '0';
      else
        phase_r <= next_phase;
        done    <= finish;
      end if;
    end if;
  end process;

  phase <= phase_r;
  busy  <= '0' when phase_r = P_IDLE else '1';
end architecture;
